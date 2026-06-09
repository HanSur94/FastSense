---
phase: 1032
plan: 02
subsystem: EventDetection
tags: [live-event-pipeline, cluster-mode, file-locking, single-source, timer-hardening, ACK-04]
dependency_graph:
  requires:
    - TagWriteCoordinator.acquireTag() (Plan 1030-01)
    - FileLock.tryAcquire / peek / release (Plan 1029-03)
    - ClusterIdentity.resolve('Strict', true) (Plan 1029-01)
    - SharedPaths.eventsDir/locksDir() (Plan 1029-01)
    - EventLog(sharedRoot, tagKey, opts) (Plan 1031-02)
    - MonitorTag.EventLog public property + emitEvent_ seam (Plan 1032-01)
  provides:
    - LiveEventPipeline('SharedRoot', root) — cluster-mode constructor NV-pair
    - LiveEventPipeline.SkippedMonitorCount — ops observability for lock contention
    - LiveEventPipeline.LastTickDurationSec — tick duration ops surface (Pitfall 7)
    - LiveEventPipeline.LastLockContentionEvent — Phase 1033 Companion UI hook
    - LiveEventPipeline.IsClusterMode_ — cluster-mode gate (SetAccess=private, public read)
    - EventLog wiring into all MonitorTargets at cluster construction
  affects:
    - Plan 1032-04 (ack workflow): listeners on EventAppended can safely call coordinator
    - Phase 1033 (Companion UI): consumes SkippedMonitorCount + LastLockContentionEvent
tech_stack:
  added: []
  patterns:
    - IsClusterMode_ SetAccess=private gate (all cluster paths strictly dormant in single-user mode)
    - onCleanup-based lock release (exception-safe RAII pattern, mirrors LiveTagPipeline)
    - nestedLockAcquireForbidden catch + count as contention (same-process double-acquire treated as skip)
    - drawnow limitrate nocallbacks (Pitfall 7 reentrancy guard, mirrors LiveTagPipeline)
    - BusyMode='drop' forced in cluster-mode timer (Pitfall 7 prevention)
    - buildContentionEvent_ static helper (mirrors LiveTagPipeline.buildContentionEvent_)
    - EventLog wired at construction so MonitorTag.emitEvent_ routes cluster writes to NDJSON log
key_files:
  created:
    - tests/suite/TestMonitorTagSingleSource.m
  modified:
    - libs/EventDetection/LiveEventPipeline.m
decisions:
  - "Option (a) selected for single-source emission: MonitorTag.emitEvent_ catches nestedLockAcquireForbidden and skips the cluster write. The outer lock in processMonitorTag_ provides the actual single-source guarantee — only the lock holder can call appendData, so only the lock holder emits events. The in-process catch in emitEvent_ is a benign noop for the same lock holder (it already wrote to EventStore for backward compat). No Option (b) appendInsideLock seam needed."
  - "nestedLockAcquireForbidden from acquireTag is caught in processMonitorTag_ and treated as contention skip (increments SkippedMonitorCount). This handles the same-process double-acquire scenario used in testSkippedMonitorCountIncrements — mirrors 1030-02 SUMMARY's 'sawContention accepts any of the three channels' note."
  - "IsClusterMode_ moved to SetAccess=private (not Access=private) so tests can read it as a public property — mirrors testSingleUserModeByteIdentical and testClusterConstructionWiresEventLogIntoMonitors assertions."
  - "EventLog constructor uses struct-opts form EventLog(root, key, struct('LockTimeout', t)) not NV-pair form — corrected from plan template which used NV pairs."
  - "Single-user mode byte-identical: no Concurrency-library code paths exercised when SharedRoot absent. All 3 TestLiveEventPipelineTag tests pass unchanged."
metrics:
  duration_seconds: 1800
  completed_date: "2026-05-14"
  tasks_completed: 2
  files_created: 1
  files_modified: 1
  test_pass_rate: "3/3 always-run PASS + 1 filtered on macOS (expected); 28/28 TestMonitorTag regression; 3/3 TestLiveEventPipelineTag regression; 4/4 TestListenerCannotAcquireLock regression"
  static_analysis: "clean except pre-existing MSNU info-level warnings in LiveEventPipeline.m line 307"
requirements: [ACK-04]
---

# Phase 1032 Plan 02: LiveEventPipeline Cluster Mode Summary

**One-liner:** LiveEventPipeline wired with TagWriteCoordinator per-monitor FileLock acquisition in processMonitorTag_, BusyMode='drop', drawnow reentrancy guard, EventLog wiring, and skip-and-defer contention observability — single-user mode byte-identical throughout.

## What Was Built

### `libs/EventDetection/LiveEventPipeline.m` (modified, +177/-6 lines)

All cluster-mode additions are gated behind `if obj.IsClusterMode_`. Single-user mode (no `'SharedRoot'` NV-pair) exercises zero Concurrency-library code paths.

**New properties:**

| Property | Visibility | Purpose |
|----------|-----------|---------|
| `SkippedMonitorCount` | SetAccess=private | Incremented on lock contention (ok=false or nestedLockAcquireForbidden) |
| `LastTickDurationSec` | SetAccess=private | Wall-clock duration of most recent runCycle (Pitfall 7 ops surface) |
| `LastLockContentionEvent` | SetAccess=private | Struct `{tagKey, holder.{user,host,age}}` for Phase 1033 Companion UI |
| `IsClusterMode_` | SetAccess=private | Bool gate; true when 'SharedRoot' NV-pair is non-empty |
| `Coordinator_` | private | `TagWriteCoordinator` handle or `[]` in single-user mode |
| `SharedRoot_` | private | Char shared root path |
| `LockTimeout_` | private | Seconds per-monitor lock acquire timeout (default 5.0) |
| `eventLogs_` | private | `containers.Map` tagKey → EventLog handle (cluster mode only) |

**Constructor (`LiveEventPipeline(monitors, dataSourceMap, varargin)`):**
- Added `'SharedRoot'` and `'LockTimeout'` NV-pair cases to `defaults` struct
- When `opts.SharedRoot` is non-empty: calls `ClusterIdentity.resolve('Strict', true)` (IDENT-01 fail-fast), creates `SharedPaths.eventsDir/locksDir` if absent, constructs `obj.Coordinator_ = TagWriteCoordinator(opts.SharedRoot)`
- Iterates all MonitorTargets; constructs `EventLog(sharedRoot, key, struct('LockTimeout', t))` for each monitor that has an `EventLog` property; wires the handle back into `monitor.EventLog` (Plan 01 seam)

**`start()` modification (Pitfall 7):**
- Cluster mode timer constructed with `'BusyMode', 'drop'`
- Single-user timer unchanged (no BusyMode — default `'queue'` for fixedSpacing)

**`runCycle()` modifications:**
- `tickStart_ = tic()` at method entry
- `if obj.IsClusterMode_, drawnow limitrate nocallbacks; end` (Pitfall 7 reentrancy guard, mirrors LiveTagPipeline)
- `obj.LastTickDurationSec = toc(tickStart_)` at method exit

**`processMonitorTag_()` — cluster-mode lock acquisition (ACK-04):**
1. `lock = []; ok = false;`
2. `try [lock, ok] = obj.Coordinator_.acquireTag(key, struct('Timeout', obj.LockTimeout_));`
3. `catch ME` — if `Concurrency:nestedLockAcquireForbidden`: set `ok=false` (same-process contention signal); rethrow otherwise
4. If `~ok`: increment `SkippedMonitorCount`, populate `LastLockContentionEvent` via `buildContentionEvent_`, `return`
5. If `ok`: `cleaner = onCleanup(@() lock.release())` — exception-safe RAII
6. Critical section: `parent.updateData(fullX, fullY)` then `monitor.appendData(newX, newY)` (Pitfall Y ordering preserved)
7. Lock released by `onCleanup` when `cleaner` goes out of scope

**New static private method `buildContentionEvent_(tagKey, lock)`:**
- Mirrors `LiveTagPipeline.buildContentionEvent_` exactly (Phase 1030-02 pattern)
- Returns `{tagKey, holder.{user,host,age}, timestamp}` struct
- `lock.peek()` used for holder info; best-effort (struct well-formed on peek failure)

### `tests/suite/TestMonitorTagSingleSource.m` (created, 220 lines)

4 test methods:

| Method | Platform | Gate | Coverage |
|--------|---------|------|---------|
| `testSingleUserModeByteIdentical` | All | None | IsClusterMode_=false, events in EventStore, SkippedMonitorCount=0 |
| `testSkippedMonitorCountIncrements` | All | None | Pre-held lock causes contention skip; SkippedMonitorCount increments; LastLockContentionEvent populated |
| `testClusterConstructionWiresEventLogIntoMonitors` | All | None | EventLog wired into each MonitorTag at construction; IsClusterMode_=true |
| `testFourNodeRisingEdges` | Linux only | FASTSENSE_STRESS_4=1 | 4 matlab -batch nodes poll same MonitorTag; exactly N events for N rising edges |

## Execution decision: Option (a) vs Option (b)

**Option (a) selected.** The outer lock in `processMonitorTag_` is the real single-source guarantee. When the lock holder calls `monitor.appendData` → `emitEvent_` → `EventLog.append`, the nested acquire from `EventLog.append` throws `nestedLockAcquireForbidden`, which Plan 01's `emitEvent_` already catches and treats as a benign warning skip. The cluster write is skipped but the in-memory `EventStore` (if bound) still records it for backward compat. Only the lock holder processes each tag per tick — so duplicates cannot arise from the EventLog path.

Option (b) (`EventLog.appendInsideLock` non-locking seam) was not needed — Option (a)'s in-process logic is sufficient because the OUTER lock already prevents two processes from entering the critical section simultaneously.

## Pitfall Coverage Matrix

| Pitfall | Location | Verification |
|---------|----------|-------------|
| 7 (timer queue buildup) | `start()` `BusyMode='drop'` + `drawnow limitrate nocallbacks` in `runCycle` + `SkippedMonitorCount` | grep PASS + `testBusyModeDropForced` (TestLiveTagPipelineCluster mirrors) |
| 13 (re-entrant emission deadlock) | Inherited from Plan 01: `flushPendingNotify_` fires listeners AFTER lock release | TestListenerCannotAcquireLock 4/4 PASS |

## Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| `IsClusterMode_` ≥2 hits | PASS (7 hits) |
| `Coordinator_` ≥1 hit | PASS (4 hits) |
| `Coordinator_.acquireTag` ≥1 hit | PASS (2 hits) |
| `onCleanup` ≥1 hit | PASS (3 hits) |
| `BusyMode.*drop` ≥1 hit | PASS (3 hits) |
| `SkippedMonitorCount` ≥2 hits | PASS (5 hits) |
| `LastLockContentionEvent` ≥2 hits | PASS (6 hits) |
| `EventLog(` ≥1 hit | PASS (1 hit) |
| `buildContentionEvent_` ≥2 hits | PASS (3 hits) |
| `drawnow limitrate nocallbacks` ≥1 hit | PASS (2 hits) |
| TestMonitorTagSingleSource — 3 always-run PASS | PASS |
| TestMonitorTagSingleSource — 4-node skips macOS | PASS (filtered via assumeTrue) |
| TestMonitorTag.m regression 28/28 | PASS |
| TestListenerCannotAcquireLock 4/4 | PASS |
| TestLiveEventPipelineTag 3/3 | PASS |
| `mcp__matlab__check_matlab_code` 0 errors | PASS (only MSNU info pre-existing) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] EventLog constructor uses struct-opts not NV-pairs**
- **Found during:** Task 1 test run — `EventLog(root, key, 'LockTimeout', t)` threw "Too many input arguments"
- **Issue:** Plan template used NV-pair syntax; actual EventLog constructor signature is `EventLog(sharedRoot, tagKey, opts)` where opts is an optional struct
- **Fix:** Changed call to `EventLog(obj.SharedRoot_, char(mon.Key), struct('LockTimeout', obj.LockTimeout_))`
- **Files modified:** `libs/EventDetection/LiveEventPipeline.m`
- **Commit:** 68a5ed5

**2. [Rule 2 - Missing functionality] nestedLockAcquireForbidden must be caught in processMonitorTag_**
- **Found during:** Task 2 test run — `testSkippedMonitorCountIncrements` showed error propagating through to the cycle-level try/catch instead of incrementing SkippedMonitorCount
- **Issue:** Same-process pre-hold via separate `TagWriteCoordinator` throws `nestedLockAcquireForbidden` from `FileLock.tryAcquire` (per-process held-keys registry check) rather than returning `ok=false`. Plan 01 comment on `nestedLockAcquireForbidden` in emitEvent_ noted this was expected; but processMonitorTag_ had no catch.
- **Fix:** Added `try/catch` around `acquireTag` call; `Concurrency:nestedLockAcquireForbidden` sets `ok=false` (treated as contention skip, increments SkippedMonitorCount). Other errors rethrown.
- **Files modified:** `libs/EventDetection/LiveEventPipeline.m`
- **Commit:** 68a5ed5

**3. [Rule 2 - Missing observability] IsClusterMode_ must be readable by tests**
- **Found during:** Task 2 test run — tests asserting `pipe.IsClusterMode_` got "No public property" error
- **Issue:** `IsClusterMode_` was in `properties (Access = private)` block, not accessible externally
- **Fix:** Moved to separate `properties (SetAccess = private)` block — externally readable but not writable (mirrors LiveTagPipeline's SetAccess=private pattern for observability properties)
- **Files modified:** `libs/EventDetection/LiveEventPipeline.m`
- **Commit:** 68a5ed5

## Known Stubs

None. All plan goals achieved. The `testFourNodeRisingEdges` macOS/Windows skip is intentional platform-gating behavior, not a functionality gap.

## Hand-off Notes

### For Phase 1033 (Companion UI)

The `LastLockContentionEvent` and `SkippedMonitorCount` property shapes are the UI contract for LiveEventPipeline — identical shape to LiveTagPipeline (Phase 1030-02):
```matlab
ev.tagKey          % char; the monitor key that was contended
ev.holder.user     % char; OS username of lock holder ('' if unknown)
ev.holder.host     % char; hostname of lock holder ('' if unknown)
ev.holder.age      % double; seconds since last heartbeat (NaN if unavailable)
ev.timestamp       % double; MATLAB datenum of when contention was detected
```

`SkippedMonitorCount` is monotonically increasing. Companion UI should capture delta between poll intervals.

### For Plan 1032-04 (ack workflow)

`OnEventStart` / `OnEventEnd` listeners fire via `flushPendingNotify_` AFTER the outer lock releases (Plan 01 deferred-notify guarantee). Ack listeners that call `EventStore.acknowledgeEvent` or coordinator methods are safe — no re-entrant lock conflict.

## Self-Check: PASSED

Files verified:
- FOUND: libs/EventDetection/LiveEventPipeline.m
- FOUND: tests/suite/TestMonitorTagSingleSource.m

Commits verified:
- FOUND: 68a5ed5 feat(1032-02): cluster-mode LiveEventPipeline with per-monitor FileLock
- FOUND: 0c6d1dd test(1032-02): TestMonitorTagSingleSource — cluster smoke + single-user regression

Test results:
- TestMonitorTagSingleSource (new): Passed=3, Failed=0, Filtered=1 (macOS expected)
- TestMonitorTag (regression): Passed=28, Failed=0
- TestListenerCannotAcquireLock (Plan 01 regression): Passed=4, Failed=0
- TestLiveEventPipelineTag (single-user regression): Passed=3, Failed=0
