---
phase: 1030
plan: 01
subsystem: Concurrency
tags: [tag-write-coordinator, file-locking, facade, CONC-01]
dependency_graph:
  requires:
    - FileLock.tryAcquire() (Plan 1029-03)
    - SharedPaths.locksDir(root) (Plan 1029-01)
    - ClusterIdentity.clearCache() (Plan 1029-01, test isolation)
  provides:
    - TagWriteCoordinator(sharedRoot)
    - TagWriteCoordinator.acquireTag(tagKey)
    - TagWriteCoordinator.acquireTag(tagKey, opts)
  affects:
    - Plan 1030-02 (LiveTagPipeline cluster mode — uses acquireTag seam)
tech_stack:
  added: []
  patterns:
    - thin facade over FileLock with per-tag-key scope
    - opts struct with optGet_ local helper for default extraction
    - onCleanup-based lock release pattern for callers
key_files:
  created:
    - libs/Concurrency/TagWriteCoordinator.m
    - tests/suite/TestTagWriteCoordinator.m
  modified: []
decisions:
  - "acquireTag returns [lock, ok] where ok=false on contention — caller gates critical section on ok==true and skips release on ok==false"
  - "LocksDir derived once at construction via SharedPaths.locksDir(sharedRoot) and cached in private property — avoids repeated fullfile calls per acquire"
  - "FileLock constructed per acquireTag call (not cached) to ensure fresh in-process registry check per key per call"
  - "testTwoCoordinatorsContendOnSameTagKey uses verifyError for Concurrency:nestedLockAcquireForbidden — same-process double acquire on same lockPath is the expected in-process contention contract per FileLock design"
metrics:
  duration_seconds: 182
  completed_date: "2026-05-14"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
requirements:
  - CONC-01
---

# Phase 1030 Plan 01: TagWriteCoordinator Summary

**One-liner:** TagWriteCoordinator thin facade over FileLock with per-tag-key scope — derives `<sharedRoot>/locks/<tagKey>.lock` from SharedPaths, returns [lock, ok] pair, tested with 6 passing unit tests.

## What Was Built

### `libs/Concurrency/TagWriteCoordinator.m`

Handle class implementing the per-tag-key FileLock facade:

- **Constructor** `TagWriteCoordinator(sharedRoot)`: validates non-empty char, stores `SharedRoot` and caches `LocksDir = SharedPaths.locksDir(sharedRoot)`. Throws `TagWriteCoordinator:invalidSharedRoot` on empty/non-char.
- **`acquireTag(tagKey)`** / **`acquireTag(tagKey, opts)`**: validates tagKey (throws `TagWriteCoordinator:invalidTagKey` on empty/non-char), constructs `FileLock(tagKey, 'LockDir', LocksDir, ...)` with forwarded Timeout/StaleTimeout/HeartbeatInterval from opts struct, calls `lock.tryAcquire('Timeout', tSec)`, returns `[lock, ok]`.
- **`ok=false` contract**: on contention the FileLock handle is returned unheld — caller MUST NOT call `lock.release()` when `ok==false`.
- **Local helper** `optGet_(opts, name, default)`: extracts named field from opts struct with default fallback.

### `tests/suite/TestTagWriteCoordinator.m`

6 test methods:

| Method | Coverage |
|--------|----------|
| `testConstructorRejectsEmptySharedRoot` | `TagWriteCoordinator:invalidSharedRoot` (empty) |
| `testConstructorRejectsNonCharSharedRoot` | `TagWriteCoordinator:invalidSharedRoot` (numeric) |
| `testAcquireTagRejectsEmptyKey` | `TagWriteCoordinator:invalidTagKey` |
| `testAcquireTagReturnsFileLockAndLocksDirIsDerived` | lockPath derivation, isHeld=true, SharedPaths.locksDir match |
| `testTwoCoordinatorsContendOnSameTagKey` | same-process contention throws nestedLockAcquireForbidden; after release coord2 acquires |
| `testDifferentTagKeysDoNotContend` | alpha + beta both acquired from same coordinator simultaneously |

## Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| `classdef TagWriteCoordinator < handle` present | PASS |
| `function [lock, ok] = acquireTag` present | PASS |
| `SharedPaths.locksDir` present | PASS |
| `FileLock(` present | PASS |
| `TagWriteCoordinator:invalidSharedRoot` present | PASS |
| `TagWriteCoordinator:invalidTagKey` present | PASS |
| `LockDir` NV-pair passed to FileLock | PASS |
| MATLAB static check: 0 errors | PASS (verified via -batch run passing) |
| `classdef TestTagWriteCoordinator` present | PASS |
| `testConstructorRejectsEmptySharedRoot` present | PASS |
| `testAcquireTagReturnsFileLockAndLocksDirIsDerived` present | PASS |
| `testTwoCoordinatorsContendOnSameTagKey` present | PASS |
| `testDifferentTagKeysDoNotContend` present | PASS |
| `Concurrency:nestedLockAcquireForbidden` in test | PASS |
| All 6 tests pass via matlab -batch | PASS (6/6) |
| TestFileLock regression: no failures | PASS (6 passed, 1 skipped/macOS) |

## Deviations from Plan

None - plan executed exactly as written.

The plan's code template was implemented verbatim with minor additions (improved method documentation, local helper comment header).

## Hand-off Notes for Plan 1030-02 (LiveTagPipeline Cluster Mode)

The `acquireTag(tagKey)` signature returns `[lock, ok]`. Correct usage pattern in `processTag_`:

```matlab
% At start of processTag_ when IsClusterMode_ is true:
[lock, ok] = obj.Coordinator_.acquireTag(tag.Key);
if ~ok
    % Log skip-and-defer; do NOT call lock.release()
    return;
end
cleaner = onCleanup(@() lock.release());
% ... writeTagMat_() call goes here ...
```

Key rules:
- Gate the critical section on `ok==true`
- Use `onCleanup` for exception-safe release
- Skip-and-defer (return early) on `ok==false`
- Do NOT call `lock.release()` when `ok==false` — the lock is not held

## Known Stubs

None. All plan goals achieved.

## Self-Check: PASSED

Files verified:
- FOUND: libs/Concurrency/TagWriteCoordinator.m
- FOUND: tests/suite/TestTagWriteCoordinator.m

Commit verified:
- FOUND: dd0f18d feat(1030-01): add TagWriteCoordinator facade + TestTagWriteCoordinator suite

Test results:
- TestTagWriteCoordinator: Passed=6, Failed=0
- TestFileLock (regression): Passed=6, Failed=0, Skipped=1 (macOS expected)
