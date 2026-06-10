---
phase: "1029"
plan: "02"
subsystem: "Concurrency"
tags: [mex, file-locking, ofd-locks, cross-platform, concurrency]
dependency_graph:
  requires: []
  provides:
    - lockfile_mex (acquire/release/status/probe commands)
    - build_concurrency_mex (MEX build entry point)
  affects:
    - libs/FastSense/build_mex.m (extended to invoke build_concurrency_mex)
    - Plan 03 (FileLock.m) depends on lockfile_mex MEX kernel
tech_stack:
  added:
    - lockfile_mex.c (C MEX — cross-platform advisory file lock kernel)
    - build_concurrency_mex.m (MATLAB MEX build helper, mirrors build_mex.m pattern)
  patterns:
    - Static FD table (64-entry) for in-process lock tracking (Unknown 3 self-deadlock prevention)
    - Platform branching via #ifdef: _WIN32 → LockFileEx, __linux__+F_OFD_SETLK → OFD, else → F_SETLK
    - Build output to library root (MATLAB) or octave-<tag>/ (Octave), mirrors mksqlite pattern
key_files:
  created:
    - libs/Concurrency/private/mex_src/lockfile_mex.c
    - libs/Concurrency/build_concurrency_mex.m
    - tests/suite/TestLockfileMex.m
  modified:
    - libs/FastSense/build_mex.m
decisions:
  - "Build output dir is Concurrency root (not private/) for MATLAB: MATLAB private/ MEX is inaccessible to external callers; mirrors mksqlite output-to-rootDir pattern in build_mex.m"
  - "lockfile_mex uses static 64-entry FD table to prevent same-process self-deadlock (Unknown 3); second acquire of same path returns int64(-1) immediately"
  - "_GNU_SOURCE is defined at top of lockfile_mex.c (not only via build flag) to ensure F_OFD_SETLK is available when compiler passes -D_GNU_SOURCE on Linux"
metrics:
  duration_seconds: 499
  completed_date: "2026-05-13"
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 1
---

# Phase 1029 Plan 02: lockfile_mex MEX Kernel Summary

**One-liner:** Cross-platform advisory file lock MEX (`lockfile_mex.c`) with OFD/LockFileEx/F_SETLK branches, 64-entry static FD table for self-deadlock prevention, and `build_concurrency_mex.m` build integration wired into `build_mex.m`.

## What Was Built

### lockfile_mex.c
Cross-platform C MEX at `libs/Concurrency/private/mex_src/lockfile_mex.c` implementing four commands:
- `handle = lockfile_mex('acquire', lockPath, timeoutSec)` — non-blocking try-acquire with poll loop; returns int64 token or -1
- `ok = lockfile_mex('release', handle)` — releases lock, closes FD, removes from FD table
- `info = lockfile_mex('status', lockPath)` — best-effort struct with `held` field (uses F_OFD_GETLK on Linux)
- `info = lockfile_mex('probe')` — struct with `branch`, `os`, `pid` (int64), `kernel` (Linux only)

Platform branching:
- `_WIN32`: `LockFileEx(LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY)` with OVERLAPPED zero-offset 1-byte lock
- `__linux__ + F_OFD_SETLK`: OFD locks (`fcntl(F_OFD_SETLK)`) — open-file-description-scoped, requires `-D_GNU_SOURCE`
- Else (macOS / Linux < 3.15): plain `fcntl(F_SETLK)` with documented close-drops-lock caveat (dev-only)

Host platform result: `branch=fsetlk, os=darwin` (macOS Apple Silicon, as expected).

### build_concurrency_mex.m
Self-contained `libs/Concurrency/build_concurrency_mex.m` that:
- Outputs to `libs/Concurrency/` root for MATLAB (matching the `mksqlite` pattern in `build_mex.m`)
- Outputs to `libs/Concurrency/private/octave-<tag>/` for Octave (Pitfall E prevention)
- Passes `-D_GNU_SOURCE` on Linux (Pitfall A prevention)
- Wraps compilation in try/catch with informative warning (FileLock fallback documented)
- Skips if binary already exists (idempotent)

### build_mex.m extension
`libs/FastSense/build_mex.m` extended with best-effort Concurrency MEX dispatch at end of `build_mex()` body — wrapped in try/catch so failure doesn't abort FastSense MEX compilation.

### TestLockfileMex.m
`tests/suite/TestLockfileMex.m` with 4 test methods — all passing on macOS (host platform):
- `testProbeReportsBranch` — probe returns valid branch tag in `{'ofd','fsetlk','lockfileex'}` and int64 pid
- `testAcquireReleaseRoundTrip` — acquire returns int64 > 0; release returns true
- `testSelfReacquireReturnsNegative` — second acquire of same path returns int64(-1) (Unknown 3 confirmed)
- `testHandleIsInt64` — handle type verified as int64

## Host Platform

| Field | Value |
|-------|-------|
| Platform | macOS Apple Silicon (maca64) |
| Branch compiled | `fsetlk` (F_SETLK fallback — correct for macOS dev platform) |
| OS | `darwin` |
| MEX binary | `libs/Concurrency/lockfile_mex.mexmaca64` |
| Linux uname -r | N/A — macOS dev host (OFD branch requires Linux 3.15+ with -D_GNU_SOURCE) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] MEX output directory changed from `private/` to Concurrency root for MATLAB**
- **Found during:** Task 2 — `lockfile_mex` was not callable after compilation
- **Issue:** Plan specified output to `libs/Concurrency/private/` but MATLAB's `private/` mechanism only exposes MEX files to M-functions in the immediate parent directory, not to external callers. After `addpath('libs/Concurrency')`, calling `lockfile_mex` from a test would fail with "Undefined function".
- **Fix:** Changed `outDir` for MATLAB to `rootDir` (the Concurrency root), matching the `mksqlite` pattern in `build_mex.m` where `outDirMksql = rootDir`. Octave still uses platform-tagged subdirectory under `private/`.
- **Files modified:** `libs/Concurrency/build_concurrency_mex.m`, `tests/suite/TestLockfileMex.m`
- **Commit:** b57956e

**2. [Rule 1 - Bug] TestLockfileMex.m: removed invalid `addpath(private/)` for MATLAB**
- **Found during:** Task 2 — MATLAB warned "Private directories not allowed in MATLAB path"
- **Issue:** The test's `addPaths` called `addpath(fullfile(root,'libs','Concurrency','private'))`, which MATLAB rejects. This also masked the real path issue for the MEX binary.
- **Fix:** Removed the MATLAB-incompatible `addpath` for the private/ dir; kept only the Octave octave-\<tag\> path addition. Build-check also simplified to not re-add private/ after compilation.
- **Files modified:** `tests/suite/TestLockfileMex.m`
- **Commit:** b57956e

## Hand-off Notes for Plan 03 (FileLock.m)

`lockfile_mex` API contract:
- `handle = lockfile_mex('acquire', lockPath, timeoutSec)` — token is `int64`; `-1` means rejected (either same-process self-deadlock via FD table, or another holder)
- `ok = lockfile_mex('release', handle)` — pass the int64 token from acquire
- The MEX already prevents same-process re-acquire — `FileLock.acquire(key)` should detect int64(-1) and throw `Concurrency:nestedLockAcquireForbidden` instead of silently retrying
- Probe the MEX presence with `exist('lockfile_mex','file') == 3` before calling; if absent, fall back to pure-MATLAB sidecar-rename mode
- Add `addpath(fullfile(root,'libs','Concurrency'))` in FileLock's initialization (or ensure install.m handles this)

## Hand-off Notes for Plan 05 (install.m wiring)

- Add `addpath(fullfile(root, 'libs', 'Concurrency'))` to `install.m`
- For Octave: add the platform-tag `octave-<tag>/` path under `libs/Concurrency/private/` (mirroring the FastSense pattern at install.m lines 70-90)
- `build_concurrency_mex()` is already invoked by `build_mex()` (best-effort). For Octave CI, may need explicit call if the try/catch in build_mex swallows the build.

## Self-Check: PASSED

- `libs/Concurrency/private/mex_src/lockfile_mex.c` — FOUND
- `libs/Concurrency/build_concurrency_mex.m` — FOUND
- `libs/Concurrency/lockfile_mex.mexmaca64` — FOUND (compiled binary)
- `tests/suite/TestLockfileMex.m` — FOUND
- Commit 6201d18 (Task 1) — FOUND in git log
- Commit b57956e (Task 2) — FOUND in git log
- TestLockfileMex: 4/4 PASSED
