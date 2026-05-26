---
phase: 1029
plan: 05
subsystem: Concurrency
tags: [wiring, install, probes, integration-test, mksqlite, lockFileFormat, CONC-02, CONC-03, IDENT-01]
dependency_graph:
  requires:
    - ClusterIdentity (Plan 1029-01)
    - lockfile_mex (Plan 1029-02)
    - FileLock (Plan 1029-03)
    - AtomicWriter (Plan 1029-04)
  provides:
    - install.m (extended — Concurrency on addpath chain + Octave platform-tag)
    - tests/test_mksqlite_extended_codes_probe.m
    - tests/suite/TestConcurrencyIntegration.m
    - .planning/phases/1029-foundation/1029-PROBES.md
    - libs/Concurrency/lockFileFormat.m (moved from private/ to root — accessibility fix)
  affects:
    - All plans that depend on FileLock (Phase 1030 TagWriteCoordinator uses FileLock + AtomicWriter)
    - Phase 1032 (reads 1029-PROBES.md for mksqlite busy string to match in retry wrapper)
tech_stack:
  added: []
  patterns:
    - probe-test pattern (writes structured diagnostic output to .planning/ for downstream consumption)
    - composition smoke pattern (TestConcurrencyIntegration exercises all 5 primitives end-to-end)
    - traceability meta-test pattern (testRoadmapSuccessCriteriaTraceability parses VALIDATION.md)
key_files:
  created:
    - tests/test_mksqlite_extended_codes_probe.m
    - tests/suite/TestConcurrencyIntegration.m
    - .planning/phases/1029-foundation/1029-PROBES.md
    - libs/Concurrency/lockFileFormat.m (moved from private/)
  modified:
    - install.m (addpath + Octave platform-tag addition)
  deleted:
    - libs/Concurrency/private/lockFileFormat.m (moved to root)
decisions:
  - "lockFileFormat.m moved from libs/Concurrency/private/ to libs/Concurrency/ root: MATLAB classdef files cannot access private/ directories of their parent folder (only M-function files get that access). FileLock.m is a classdef and called lockFileFormat.encodeBody — this resolved as 'Unable to resolve the name'. Fix: move to root, matching Plan 02 deviation (lockfile_mex MEX output to root, not private/). (Rule 1 auto-fix)"
  - "testFiveClassesAllOnPath includes lockFileFormat now that it is at the Concurrency root — which('lockFileFormat') returns non-empty"
  - "testRoadmapSuccessCriteriaTraceability parses VALIDATION.md for TestClass.testMethod tokens via regex, then checks each class file + method exists in tests/suite/"
metrics:
  duration_seconds: 0
  completed_date: "2026-05-14"
  tasks_completed: 3
  files_created: 4
  files_modified: 1
requirements:
  - CONC-02
  - CONC-03
  - IDENT-01
---

# Phase 1029 Plan 05: Wiring and Probes Summary

**One-liner:** Phase 1029 wired into the project — `install.m` exposes all 8 Concurrency symbols, mksqlite probe captures `"SQL execution error: database is locked"` for Phase 1032, and `TestConcurrencyIntegration` composition smoke proves all 5 primitives work end-to-end; `lockFileFormat` accessibility bug fixed as a critical deviation.

## What Was Built

### `install.m` (modified)

Two additive changes:

1. **Addpath chain** — `addpath(fullfile(root,'libs','Concurrency'))` added after the existing 6 library entries.
2. **Octave platform-tag candidates** — `fullfile(root,'libs','Concurrency','private',['octave-' octTag])` added to the candidates cell array for Octave MEX subdir resolution.

After these changes, a fresh MATLAB session that calls `install()` finds all 8 symbols:

| Symbol | Type | Found at |
|--------|------|---------|
| `ClusterIdentity` | classdef | `libs/Concurrency/ClusterIdentity.m` |
| `ClusterConfig` | classdef | `libs/Concurrency/ClusterConfig.m` |
| `SharedPaths` | classdef | `libs/Concurrency/SharedPaths.m` |
| `FileLock` | classdef | `libs/Concurrency/FileLock.m` |
| `AtomicWriter` | classdef | `libs/Concurrency/AtomicWriter.m` |
| `lockfile_mex` | MEX | `libs/Concurrency/lockfile_mex.mexmaca64` |
| `ndjsonEncode` | function | `libs/Concurrency/ndjsonEncode.m` |
| `lockFileFormat` | classdef | `libs/Concurrency/lockFileFormat.m` (moved) |

### `tests/test_mksqlite_extended_codes_probe.m`

Octave-compatible function-style probe test that:
- Opens two mksqlite connections to the same temp SQLite DB
- Connection A holds `BEGIN IMMEDIATE`; connection B attempts `BEGIN IMMEDIATE` with `busy_timeout=100ms`
- Catches the resulting `mksqlite:sqlError` and records `ME.message`
- Captures `lockfile_mex('probe')` info (branch, os, pid)
- Captures `uname -r` on POSIX
- Appends a structured section to `1029-PROBES.md`

### `.planning/phases/1029-foundation/1029-PROBES.md`

Probe results file with:
- `staleTimeout = 90s` rationale (SMB 60s × 1.5 calculation, per Research Unknown 4)
- Live probe capture from this dev host:

```
mksqlite_busy_string: "SQL execution error: database is locked"
mksqlite_busy_snapshot_string: "NOT_REPRODUCED_IN_PROBE — capture under multi-process stress in Phase 1032"
lockfile_mex_branch: fsetlk
lockfile_mex_os: darwin
lockfile_mex_pid_kind: int64 (pid=7585)
host_kernel: 25.4.0
probe_run_at: 2026-05-14T09:53:41Z
probe_run_by: hannessuhr@MacBookPro
```

**Phase 1032 hand-off:** The retry wrapper should catch `mksqlite:sqlError` and check `contains(ME.message, 'database is locked')` for SQLITE_BUSY. The full message is `"SQL execution error: database is locked"` (from `sqlite3_errmsg()` via `mexErrMsgIdAndTxt`). SQLITE_BUSY_SNAPSHOT cannot be triggered in a single MATLAB session; Phase 1032 must probe under multi-process WAL scenario.

### `tests/suite/TestConcurrencyIntegration.m`

4-method composition smoke:

| Method | What it verifies | Platform |
|--------|-----------------|---------|
| `testFiveClassesAllOnPath` | All 8 Concurrency symbols discoverable via `which()` | All |
| `testLockfileMexBranchMatchesHost` | `lockfile_mex('probe').branch` matches host (macOS→`fsetlk`) | All |
| `testHappyPathInProcess` | FileLock+ClusterIdentity+AtomicWriter compose in a lock→write→verify flow | All |
| `testRoadmapSuccessCriteriaTraceability` | Every test method named in VALIDATION.md exists in tests/suite/ | All |

`testHappyPathInProcess` is a single-process composition smoke. Multi-process scenarios are already covered by `TestFileLock.testTwoProcessMutualExclusion` (2-process) and the gated `TestFileLockStress50`.

### `libs/Concurrency/lockFileFormat.m` (moved from private/)

See Deviations section.

## Test Results (host platform: macOS Apple Silicon)

| Test Suite | Results |
|-----------|---------|
| `TestClusterIdentity` | 2/2 PASS |
| `TestClusterConfig` | 2/2 PASS |
| `TestLockfileMex` | 4/4 PASS |
| `TestFileLock` | 6/6 PASS (1 SKIP: testCloseDoesNotReleaseLock — assumeTrue(~ismac)) |
| `TestAtomicWriter` | 10/10 PASS |
| `TestConcurrencyIntegration` | 4/4 PASS |
| `test_user_identity.m` | 2/2 PASS |
| `test_no_raw_save_to_shared.m` | 1/1 PASS |
| `test_mksqlite_extended_codes_probe.m` | 1/1 PASS |

## Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| `install.m` adds `libs/Concurrency/` to addpath chain | PASS |
| `install.m` adds Concurrency Octave platform-tag candidate | PASS |
| `which('ClusterIdentity')` returns non-empty after `install()` | PASS |
| `which('FileLock')` returns non-empty | PASS |
| `which('AtomicWriter')` returns non-empty | PASS |
| `which('lockfile_mex')` returns `.mexmaca64` | PASS |
| `grep "libs.*Concurrency" install.m` >= 2 hits | PASS (2) |
| `grep "octave-.*octTag" install.m` >= 4 hits | PASS (5 including existing 3 + new 1 + needs_build) |
| `tests/test_mksqlite_extended_codes_probe.m` exists | PASS |
| Probe test has 2x `BEGIN IMMEDIATE` | PASS |
| Probe test references `1029-PROBES.md` | PASS |
| Probe test references `lockfile_mex` | PASS |
| `.planning/phases/1029-foundation/1029-PROBES.md` exists with non-empty `mksqlite_busy_string` | PASS: `"SQL execution error: database is locked"` |
| `1029-PROBES.md` has `lockfile_mex_branch: fsetlk` | PASS |
| `TestConcurrencyIntegration.m` exists with 4 test methods | PASS |
| `TestConcurrencyIntegration` passes 4/4 | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] lockFileFormat.m moved from private/ to Concurrency root**

- **Found during:** Task 3 — `testHappyPathInProcess` errored with `"Unable to resolve the name 'lockFileFormat.encodeBody'"`
- **Root cause:** MATLAB's `private/` access mechanism works for M-function files but NOT for classdef files. `FileLock.m` is a classdef at `libs/Concurrency/FileLock.m`. When MATLAB resolves `lockFileFormat.encodeBody()` inside a classdef method, it does NOT search the sibling `private/` directory. Only function-M-files in the same folder get `private/` access.
- **Impact:** All `TestFileLock` tests also failed (they call `lockFileFormat.encodeBody()` directly). This was a pre-existing bug from Plan 03 that was not discovered because Plan 03's MATLAB MCP tools were unavailable during execution.
- **Fix:** Moved `libs/Concurrency/private/lockFileFormat.m` → `libs/Concurrency/lockFileFormat.m`. This matches Plan 02's established deviation: MEX output to root (not private/) because private/ is inaccessible from outside.
- **Files modified:** `libs/Concurrency/lockFileFormat.m` (created at root), `libs/Concurrency/private/lockFileFormat.m` (deleted)
- **Commits:** 69c2563, 5e1de89

## Hand-off Notes

### For Phase 1030 (TagWriteCoordinator)

The full happy-path is demonstrated in `TestConcurrencyIntegration.testHappyPathInProcess`:

```matlab
lock = FileLock(tag.Key, 'LockDir', SharedPaths.locksDir(root));
if lock.tryAcquire()
    id = ClusterIdentity.resolve();
    AtomicWriter.write(tagPath, @(p) save(p, varList{:}), id, ...
        struct('StillHeldByMe', @() lock.stillHeldByMe()));
    lock.release();
end
```

### For Phase 1032 (SQLite retry wrapper)

Read `1029-PROBES.md` to get the exact mksqlite busy string:

```matlab
% In SQLite retry wrapper:
catch ME
    if strcmp(ME.identifier, 'mksqlite:sqlError') && contains(ME.message, 'database is locked')
        % SQLITE_BUSY (or SQLITE_BUSY_SNAPSHOT if message contains 'SQLITE_BUSY_SNAPSHOT')
        % ... retry logic ...
    end
end
```

The exact captured string is: `"SQL execution error: database is locked"`

## Known Stubs

None. All plan goals achieved. Phase 1029 Foundation is complete.

## Self-Check

- `install.m` modified with Concurrency addpath: FOUND (grep returns 2 hits)
- `tests/test_mksqlite_extended_codes_probe.m`: FOUND
- `.planning/phases/1029-foundation/1029-PROBES.md`: FOUND with probe capture
- `tests/suite/TestConcurrencyIntegration.m`: FOUND
- `libs/Concurrency/lockFileFormat.m`: FOUND (at root — deviation fix)
- Commit b22d532 (Task 1 install.m): FOUND
- Commit 9f34f61 (Task 2 probe + PROBES.md): FOUND
- Commit 69c2563 (Task 3 integration test + lockFileFormat move): FOUND
- Commit 5e1de89 (lockFileFormat private/ deletion): FOUND
- TestConcurrencyIntegration: 4/4 PASSED

## Self-Check: PASSED
