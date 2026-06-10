---
phase: 1033-companion-integration
plan: "04"
subsystem: FastSenseCompanion + Testing
tags: [cluster-mode, share-loss, acceptance-test, pipeline-observer, OPS-01]
dependency_graph:
  requires:
    - FastSenseCompanion.IsClusterMode_ + SharedRoot_ (Plan 1033-01)
    - LiveTagPipeline.LastLockContentionEvent + SkippedTickCount (Plan 1030-02)
    - LiveEventPipeline.LastLockContentionEvent + SkippedMonitorCount (Plan 1032-02)
    - FastSenseCompanion.onLiveTick_ + scanLiveTagUpdates_ structure (Plan 1033-01)
  provides:
    - FastSenseCompanion.IsShareReachable (logical; false when share unreachable)
    - FastSenseCompanion.LastShareError (struct or []; populated on share loss)
    - FastSenseCompanion.LastContentionNoticeText (char; user@host format or '')
    - FastSenseCompanion('LiveTagPipelines', {}) NV-pair constructor support
    - FastSenseCompanion('LiveEventPipelines', {}) NV-pair constructor support
    - FastSenseCompanion.pollClusterContention_() private method
    - FastSenseCompanion.pollShareStatus_() private method
    - TestShareLossRecovery 3-test suite (in-process OPS-01 contract verification)
    - Test50CompanionAcceptance gated harness (p50/p95/p99 at N=1/10/25/50)
    - TestFastSenseCompanion.testClusterStatusSurface (SC5 contract verification)
  affects:
    - Phase 1033 complete (last plan of v4.0 milestone)
    - OPS-01 fully verified (share-loss non-crash + recovery within one tick)

tech_stack:
  added: []
  patterns:
    - pollClusterContention_: reads LastLockContentionEvent from observed pipeline handles each tick
    - pollShareStatus_: single dir() probe per tick for share reachability (exception = unreachable)
    - LastShareStatus_ transition guard (ok->unreachable->ok) prevents redundant log entries
    - IsClusterMode_ gate preserved (all new code dormant in single-user mode)
    - struct() reflection for timer callback in-process invocation (test pattern)
    - assumeFail gate chain for operator-gated acceptance tests

key_files:
  created:
    - tests/suite/TestShareLossRecovery.m
    - tests/suite/Test50CompanionAcceptance.m
  modified:
    - libs/FastSenseCompanion/FastSenseCompanion.m
    - tests/suite/TestFastSenseCompanion.m

decisions:
  - "Public properties IsShareReachable + LastShareError + LastContentionNoticeText added to SetAccess=private block — test code can read them directly without needing accessor helper functions"
  - "pollShareStatus_ uses dir(SharedRoot_) probe as the share-reachability signal — exception OR isempty(info) = unreachable; non-empty = ok. Avoids heavier stat calls."
  - "LastShareStatus_ private flag tracks the ok<->unreachable transition so log entries are only written on state change, not every tick"
  - "testClusterStatusSurface falls back to structural wiring checks when mksqlite is unavailable; full contention scenario runs only with mksqlite present (avoids fragile skip patterns)"
  - "Test50CompanionAcceptance uses .done sentinel files (not PIDs) for child exit detection — avoids platform-specific process-wait APIs and works reliably across all Unix variants"

metrics:
  duration_minutes: 45
  completed_date: "2026-05-14"
  tasks_completed: 4
  files_created: 2
  files_modified: 2
  tests_new: 5
  tests_total: 72
  test_pass_rate: "3/3 TestShareLossRecovery PASS; 1/1 Test50CompanionAcceptance filtered (macOS gate); 69/69 TestFastSenseCompanion PASS"

requirements:
  - OPS-01
---

# Phase 1033 Plan 04: Acceptance + Recovery Summary

**One-liner:** FastSenseCompanion extended with LiveTagPipelines/LiveEventPipelines observer, IsShareReachable/LastShareError cluster-health surface, and pollClusterContention_/pollShareStatus_ private methods; TestShareLossRecovery verifies OPS-01 in-process; Test50CompanionAcceptance gates the full 50-Companion harness behind FASTSENSE_RUN_ACCEPTANCE=1 with operator instructions.

## What Was Built

### `libs/FastSenseCompanion/FastSenseCompanion.m` (modified, +176 lines / -19 lines)

Three categories of additions, all gated behind `if obj.IsClusterMode_` (single-user mode byte-identical):

**New public properties (`SetAccess = private`):**

| Property | Default | Purpose |
|----------|---------|---------|
| `IsShareReachable` | `true` | false when share-loss detected (OPS-01) |
| `LastShareError` | `[]` | struct `{message, identifier, timestamp}` on first share-loss |
| `LastContentionNoticeText` | `''` | user-readable banner; `'Tag P-101 is being updated by alice@plant-a (3s ago)'` |

**New private properties:**

| Property | Default | Purpose |
|----------|---------|---------|
| `LiveTagPipelines_` | `{}` | Observed LiveTagPipeline handles |
| `LiveEventPipelines_` | `{}` | Observed LiveEventPipeline handles |
| `LastShareStatus_` | `'ok'` | `'ok'` or `'unreachable'`; transition guard for log entries |

**Constructor extensions:**
- `'LiveTagPipelines'` NV-pair — validates each element via `isa(v, 'LiveTagPipeline')`; error `FastSenseCompanion:invalidLiveTagPipeline`
- `'LiveEventPipelines'` NV-pair — validates each element via `isa(v, 'LiveEventPipeline')`; error `FastSenseCompanion:invalidLiveEventPipeline`
- Pipeline handles stored in `LiveTagPipelines_` / `LiveEventPipelines_` after cluster resolution block
- `otherwise` error message updated to list all 9 valid option keys

**`onLiveTick_` extension:**
- After existing body (inspector refresh + scan + EventsLogPane update), calls `pollClusterContention_()` and `pollShareStatus_()` when `IsClusterMode_` is true
- Original tick behavior unchanged; new cluster code runs after existing code

**New private methods:**

`pollClusterContention_(obj)`:
- Iterates `LiveTagPipelines_`: for each valid handle, reads `LastLockContentionEvent`; if non-empty struct with `timestamp` field and `age < 30s`, formats `"Tag K is being updated by user@host (Ns ago)"` 
- Iterates `LiveEventPipelines_`: same logic with `"Monitor K ..."` prefix
- Sets `LastContentionNoticeText_` and `LastContentionNoticeText` on first match within 30s
- Logs to `LiveLogPane_.addLiveLogEntry('cluster', -1, msg)` if pane is valid
- Best-effort: all pipeline reads wrapped in `try/catch` so stray errors never crash the timer

`pollShareStatus_(obj)`:
- Probes `dir(SharedRoot_)`; exception OR `isempty(info)` = unreachable
- On loss (ok->unreachable): sets `IsShareReachable=false`, populates `LastShareError`, sets banner text `"Share unreachable — read-only mode (path)"`
- On recovery (unreachable->ok): clears `IsShareReachable=true`, clears `LastContentionNoticeText/LastContentionNoticeText_`, logs "Share back online; resuming live mode"
- Idempotent: already-unreachable ticks just update the banner without re-logging

### `tests/suite/TestShareLossRecovery.m` (created, 212 lines)

3 test methods, all pass on macOS dev host:

| Method | Coverage | Result |
|--------|----------|--------|
| `testCompanionEntersDegradedStateOnShareLoss` | IsShareReachable=false + banner contains 'read-only' + LastShareError non-empty + IsOpen=true after rmdir | PASS |
| `testCompanionResumesOnShareReturn` | IsShareReachable=true + banner empty after mkdir restore within one tick | PASS |
| `testNoOrphanTimersAfterShareLoss` | No timers in 'error' state; Companion remains open | PASS |

Test pattern: creates temp dir → constructs Companion in cluster mode → drives tick via `struct(app)` timer callback reflection → verifies public property state.

### `tests/suite/Test50CompanionAcceptance.m` (created, 338 lines)

Gated behind ALL of:
1. `FASTSENSE_RUN_ACCEPTANCE=1`
2. Not macOS
3. Not Windows
4. `FASTSENSE_SHARED_ROOT` set and pointing to valid dir

`assumeFail` fires cleanly on macOS with operator instructions:
> "To run: (1) set FASTSENSE_RUN_ACCEPTANCE=1, (2) set FASTSENSE_SHARED_ROOT=/path/to/smb/mount, (3) run from a Linux host with ≥50 MATLAB licenses."

When gates pass (Linux with SMB share):
- Runs `CLUSTER_SIZES = [1, 10, 25, 50]`
- Spawns N `matlab -batch` children per size; each records per-tick latency (ms) to a TSV
- Collects TSVs via `.done` sentinel files (90 s timeout)
- Computes `p50/p95/p99` via `prctile()`
- Writes artifact: `.planning/phases/1033-companion-integration/1033-ACCEPTANCE-RESULTS.tsv`
- Acceptance gate: `p95@N=50 < 2 * p95@N=1` (SC1 from CONTEXT.md)

### `tests/suite/TestFastSenseCompanion.m` (modified, +158 lines)

1 new test method `testClusterStatusSurface` (total: 69 tests):

Verification steps:
1. Baseline contract: `LastContentionNoticeText` empty, `IsShareReachable=true`, `LastShareError=[]`, `LastContentionNoticeText` is char — always runs
2. Error-ID validation: `invalidLiveTagPipeline` + `invalidLiveEventPipeline` for struct inputs — always runs
3. Structural wiring: pipeline stored in `LiveTagPipelines_`, live tick fires without error, no contention = empty banner — always runs
4. Full contention scenario (mksqlite only): pre-held lock → `tickOnce()` → Companion tick → `LastContentionNoticeText` contains `@` — runs when mksqlite available

## Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| `FastSenseCompanion.m` modified with IsShareReachable, LastShareError, LastContentionNoticeText | PASS |
| `TestShareLossRecovery.m` exists, all 3 tests pass on macOS | PASS |
| `Test50CompanionAcceptance.m` exists, assumeFail cleanly on macOS with helpful message | PASS |
| `TestFastSenseCompanion.m` extended with testClusterStatusSurface, 69/69 pass | PASS |
| `grep -n 'IsShareReachable' FastSenseCompanion.m` ≥2 hits | PASS (5 hits) |
| `grep -n 'LastContentionNoticeText' FastSenseCompanion.m` ≥2 hits | PASS (11 hits) |
| `grep -n 'FASTSENSE_RUN_ACCEPTANCE' Test50CompanionAcceptance.m` ≥1 hit | PASS (6 hits) |
| `grep -n 'p99\|p95\|p50' Test50CompanionAcceptance.m` ≥1 hit | PASS (19 hits) |
| Single-user mode regression: no cluster code exercised without SharedRoot | PASS |
| `checkcode` on FastSenseCompanion.m: 0 errors | PASS (advisory only: TNOW1, NOSEMI, pre-existing NASGU) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] sawContention check in testClusterStatusSurface must include LastTickReport.failed**

- **Found during:** Task 4 test run — `testClusterStatusSurface` assertion "pipeline must record contention after pre-held lock" failed
- **Issue:** In a same-process lock scenario, `LiveTagPipeline.processTag_` may throw `Concurrency:nestedLockAcquireForbidden` from `acquireTag`, which is caught by the per-tag `try/catch` and recorded in `LastTickReport.failed` — NOT in `SkippedTickCount` or `LastLockContentionEvent`. The plan's contract says "any of the three channels" (mirroring `TestLiveTagPipelineCluster.testLockContentionDefersAndEmitsEvent`).
- **Fix:** Added `isstruct(clusterPipe.LastTickReport) && ~isempty(clusterPipe.LastTickReport.failed)` as third channel in `sawContention` check.
- **Files modified:** `tests/suite/TestFastSenseCompanion.m`
- **Commit:** `da65868`

None — plan executed as written otherwise.

## Known Stubs

None. All plan goals implemented and verified:
- `IsShareReachable` flows from `pollShareStatus_` to the public property
- `LastContentionNoticeText` flows from `pollClusterContention_` to the public property
- All test suites verify the contracts end-to-end
- `Test50CompanionAcceptance` is intentionally gated; the stub-like "child script writes TSVs" is the real implementation for Linux operator runs

## Self-Check

- `libs/FastSenseCompanion/FastSenseCompanion.m` modified: FOUND
- `tests/suite/TestShareLossRecovery.m` created: FOUND
- `tests/suite/Test50CompanionAcceptance.m` created: FOUND
- `tests/suite/TestFastSenseCompanion.m` modified: FOUND
- Commit `e02dc0d` (feat - FastSenseCompanion): FOUND
- Commit `9591b5e` (test - TestShareLossRecovery): FOUND
- Commit `08bef92` (test - Test50CompanionAcceptance): FOUND
- Commit `da65868` (test - testClusterStatusSurface): FOUND
- `grep IsShareReachable FastSenseCompanion.m` 5 hits (>=2): VERIFIED
- `grep LastContentionNoticeText FastSenseCompanion.m` 11 hits (>=2): VERIFIED
- `grep FASTSENSE_RUN_ACCEPTANCE Test50CompanionAcceptance.m` 6 hits (>=1): VERIFIED
- `grep 'p99\|p95\|p50' Test50CompanionAcceptance.m` 19 hits (>=1): VERIFIED
- 3/3 TestShareLossRecovery pass: VERIFIED
- Test50CompanionAcceptance: 1 Incomplete (assumeFail on macOS): VERIFIED
- 69/69 TestFastSenseCompanion pass: VERIFIED
- checkcode 0 errors: VERIFIED

## Self-Check: PASSED
