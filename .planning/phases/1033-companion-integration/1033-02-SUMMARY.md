---
phase: 1033-companion-integration
plan: "02"
subsystem: Concurrency
tags: [event-log-consolidator, leader-election, ndjson, atomic-write, snapshot, dedup]
requirements: []

dependency_graph:
  requires:
    - 1031-02  # EventLog.append — per-tag NDJSON write path
    - 1031-03  # EventLogReader.readAll — NDJSON read path
    - 1029-03  # FileLock — leader-election primitive
    - 1029-04  # AtomicWriter.write — atomic snapshot write
    - 1029-01  # ClusterIdentity.resolve — identity stamp
  provides:
    - EventLogConsolidator class (consolidate() leader-elected NDJSON-to-snapshot merger)
  affects:
    - 1033-04  # Acceptance test / operator demo can call EventLogConsolidator on a timer

tech_stack:
  added: []
  patterns:
    - FileLock('events-consolidator') with Timeout=0 for non-blocking leader election
    - nestedLockAcquireForbidden catch-as-contention for same-process test harness compatibility
    - onCleanup RAII lock release (exception-safe; mirrors LiveTagPipeline Phase 1030-02)
    - AtomicWriter.write with StillHeldByMe predicate for lock-safe atomic snapshot rename
    - Static saveEvents_ helper accepting events by value (MATLAB anonymous-function limitation workaround)
    - dedupById_ with content-hash fallback for events without Id field
    - containers.Map as O(1) deduplication lookup table

key_files:
  created:
    - libs/Concurrency/EventLogConsolidator.m
    - tests/suite/TestEventLogConsolidator.m
  modified: []

decisions:
  - "saveEvents_ is a private static method that accepts 'events' as a parameter so save(p, 'events') resolves the local variable; MATLAB anonymous functions cannot use save-by-name for caller-scope variables"
  - "nestedLockAcquireForbidden is caught and treated as contention: semantically equivalent to cross-process contention; allows single-process test harness to validate leader-election without spawning a second MATLAB process"
  - "Teardown order in contention test: delete registered before release so LIFO execution runs release first, then delete — prevents Invalid-or-deleted-object errors on locked-then-released handles"
  - "Idempotency: prior snapshot merged-then-deduped on each run; same events.mat result regardless of how many times consolidate() is called on the same data"

metrics:
  duration_minutes: 7
  completed_date: "2026-05-14"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
  tests_passed: 5
  tests_total: 5
---

# Phase 1033 Plan 02: EventLogConsolidator Summary

**One-liner:** Leader-elected NDJSON-to-snapshot consolidator using FileLock('events-consolidator') + EventLogReader + AtomicWriter.write with dedup-by-Id, RAII lock release, and same-process nestedLock contention handling.

## What Was Built

### `libs/Concurrency/EventLogConsolidator.m`

Handle class implementing the full leader-elected consolidation cycle:

- **Constructor** `EventLogConsolidator(sharedRoot)`: validates sharedRoot exists; initialises `EventsDir_`, `LocksDir_`, `SnapshotPath_` via `SharedPaths`; creates missing subdirs (idempotent).
- **`consolidate()`**: Single consolidation pass:
  1. Creates `FileLock('events-consolidator', 'LockDir', LocksDir_)` and attempts `tryAcquire('Timeout', 0)` — non-blocking.
  2. Catches `Concurrency:nestedLockAcquireForbidden` (same-process contention) and treats it as a silent skip identical to cross-process `ok=false`.
  3. If `~ok`: populates `result.contendedBy` from `lock.peek()`, returns early, no snapshot touched.
  4. If `ok`: installs `onCleanup(@() lock.release())` for exception-safe RAII.
  5. Scans `events/*.events.ndjson` via `dir()`; reads each with `EventLogReader.readAll()`.
  6. Merges accumulated events with prior snapshot (load via `AtomicWriter.readWithRetry`) for cross-run history preservation.
  7. Deduplicates by `.Id` field (content-hash fallback when `Id` absent).
  8. Writes via `AtomicWriter.write(snapshotPath, @(p) saveEvents_(p, accumulated), identity, struct('StillHeldByMe', @() lock.stillHeldByMe()))`.
  9. Updates observability properties; returns populated result struct.
- **Observability properties** (SetAccess=private): `LastConsolidationDurationSec`, `LastEventCount`, `LastSkippedLineCount`, `TotalConsolidationCount`, `LastContendedHolder`, `LastSnapshotPath`.

**Key implementation note:** The `saveEvents_(p, events)` static method accepts `events` as a parameter and calls `builtin('save', p, 'events')`. This is the only reliable way to use `save-by-name` via an anonymous function in MATLAB — an anonymous function cannot save caller-scope variables by name.

### `tests/suite/TestEventLogConsolidator.m`

5 tests, all pass (1.14 seconds testing time):

| Test | Description | Result |
|------|-------------|--------|
| `testSingleTagRoundtrip` | 3 EventLog.append events → consolidate → events.mat has 3 | PASS |
| `testLeaderElectionContention` | Pre-hold 'events-consolidator' lock → consolidate skips silently | PASS |
| `testIdempotency` | Two consecutive consolidations → same event count, no duplication | PASS |
| `testMultiTagMerge` | 3 tags × 2 events each → events.mat has 6 events | PASS |
| `testEmptyEventsDirNoCrash` | No NDJSON files → acquiredLeader=true, eventCount=0, file written | PASS |

Regression tests also passed:
- `TestEventLogReader`: 9/9
- `TestAtomicWriter`: 10/10
- `TestFileLock`: 6/6 (1 macOS-expected skip via assumeTrue)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added nestedLockAcquireForbidden catch in consolidate()**
- **Found during:** Task 2 test execution (`testLeaderElectionContention` failure)
- **Issue:** In a single-process test, pre-holding the 'events-consolidator' FileLock and then calling `consolidate()` in the same MATLAB process causes `FileLock.tryAcquire` to throw `Concurrency:nestedLockAcquireForbidden` (Unknown 3 re-entrance guard). The plan's test design expected either `acquiredLeader=false` or this exception; `consolidate()` was not catching it.
- **Fix:** Wrapped `lock.tryAcquire()` in a try-catch; re-throws all exceptions except `Concurrency:nestedLockAcquireForbidden`, which is treated as a contention skip (`ok=false`). Cross-process contention semantics preserved.
- **Files modified:** `libs/Concurrency/EventLogConsolidator.m`
- **Commit:** d58421d

**2. [Rule 1 - Bug] Fixed teardown registration order in testLeaderElectionContention**
- **Found during:** Task 2 test execution (second failure: `Invalid or deleted object` on preheld.release)
- **Issue:** MATLAB `addTeardown` runs in LIFO order. The plan's test template registered `@() preheld.release()` before `@() delete(preheld)`, causing `delete()` to run first (LIFO), then `release()` on a deleted object.
- **Fix:** Swapped registration order: `delete` first (runs second in LIFO), `release` second (runs first in LIFO). Matches the lock lifecycle: release before delete.
- **Files modified:** `tests/suite/TestEventLogConsolidator.m`
- **Commit:** 5d3a3fb

**3. [Rule 2 - Missing functionality] saveEvents_ static helper for AtomicWriter.write payload**
- **Found during:** Task 1 implementation
- **Issue:** The plan's code example uses `@(p) save(p, 'events')` as the AtomicWriter payload callback. In MATLAB, `save(p, 'events')` inside an anonymous function resolves `'events'` as a variable name in the anonymous function's own workspace — not the caller's scope. The anonymous function's closure does not have an `events` variable.
- **Fix:** Created `saveEvents_(p, events)` as a `Static, Access = private` method. The anonymous function `@(p) EventLogConsolidator.saveEvents_(p, accumulated)` captures `accumulated` by value at closure-definition time. The static method's local parameter is named `events`, so `save(p, 'events')` works correctly.
- **Files modified:** `libs/Concurrency/EventLogConsolidator.m`
- **Commit:** cc52ae7

## Hand-off Notes for Plan 04

Phase 1033 Plan 04 (acceptance test / operator demo) can wire the consolidator into a timer-based periodic roll:

```matlab
% Example: periodic consolidation in Companion lifecycle
function startConsolidatorTimer_(obj)
    obj.ConsTimer_ = timer('Period', 60, 'ExecutionMode', 'fixedRate', ...
        'BusyMode', 'drop', ...   % drop ticks while a consolidation runs
        'TimerFcn', @(~,~) obj.consolidateOnce_());
    start(obj.ConsTimer_);
end

function consolidateOnce_(obj)
    try
        cons = EventLogConsolidator(obj.SharedRoot);
        result = cons.consolidate();
        if result.acquiredLeader && obj.Verbose
            fprintf('[Companion] Consolidated %d events\n', result.eventCount);
        end
    catch ME
        warning('Companion:consolidatorError', '%s', ME.message);
    end
end
```

- **No shared state** between consolidator runs — each `consolidate()` call is fully self-contained (reads from disk, writes to disk, releases lock).
- **Production wiring (where the timer lives)** is intentionally out of scope for Plan 02 — this is the primitive only. Plan 04 decides whether to host the timer in FastSenseCompanion or as a standalone operator script.
- The consolidator is **structurally optional** — nothing imports it yet. Plan 04 opts in.

## Known Stubs

None. All plan goals implemented and verified with live data. No placeholders.

## Self-Check: PASSED

- FOUND: libs/Concurrency/EventLogConsolidator.m
- FOUND: tests/suite/TestEventLogConsolidator.m
- FOUND: commit cc52ae7 feat(1033-02): add EventLogConsolidator leader-elected NDJSON-to-snapshot class
- FOUND: commit 5d3a3fb test(1033-02): add TestEventLogConsolidator 5-test suite
- FOUND: commit d58421d fix(1033-02): handle nestedLockAcquireForbidden as contention in consolidate()
- grep 'EventLogConsolidator' libs/Concurrency/EventLogConsolidator.m — 15 hits
- grep 'events-consolidator' libs/Concurrency/EventLogConsolidator.m — 2 hits
- grep 'AtomicWriter.write' libs/Concurrency/EventLogConsolidator.m — 3 hits
- grep 'EventLogReader' libs/Concurrency/EventLogConsolidator.m — 2 hits
- grep 'onCleanup' libs/Concurrency/EventLogConsolidator.m — 2 hits
- grep 'StillHeldByMe' libs/Concurrency/EventLogConsolidator.m — 1 hit
- 5/5 TestEventLogConsolidator tests pass
- 9/9 TestEventLogReader regression: PASS
- 10/10 TestAtomicWriter regression: PASS
- 6/6 TestFileLock regression: PASS (1 macOS skip expected)
