---
phase: 1013-ship-prebuilt-mex-binaries-for-macos-windows-linux-so-end-users-skip-compilation
plan: 03
subsystem: install / MEX build system
tags: [install, mex, octave, platform-subdir, build_mex, prebuilt]
dependency_graph:
  requires: [1013-01 (mex_stamp + needs_build stamp check), 1013-02 (.gitignore allow-list)]
  provides: [Octave platform-tagged subdir layout, addpath routing in install.m, build_mex outDir redirection]
  affects: [install.m, libs/FastSense/build_mex.m, tests/test_mex_prebuilt.m, tests/suite/TestMexPrebuilt.m]
tech_stack:
  added: []
  patterns: [platform-tagged subdir routing, TDD RED->GREEN, self-contained local helper functions]
key_files:
  created: []
  modified:
    - install.m
    - libs/FastSense/build_mex.m
    - tests/test_mex_prebuilt.m
    - tests/suite/TestMexPrebuilt.m
decisions:
  - get_octave_platform_tag() added to install.m as local function; same logic inlined in build_mex.m as local_octave_tag_() for self-containment
  - needs_build probe extended to accept absolute subdir path as third candidate so it works even if addpath hasn't run yet for the subdir
  - test 6 (BinaryMissing) extended to hide both flat private/ binary AND octave-<tag>/ subdir binary on Octave so needs_build sees nothing
  - build_mex.m sensorPrivDir variable replaces hardcoded path so Octave copy_mex_to lands in correct subdir
metrics:
  duration: 21min
  completed: 2026-04-22T14:44:00Z
  tasks_completed: 2
  files_modified: 4
---

# Phase 1013 Plan 03: Octave Platform-Tagged MEX Subdir Layout Summary

**One-liner:** Octave binaries now route into `private/octave-<platform>/` subdirs via coordinated changes in install.m (addpath + probe) and build_mex.m (outDir redirection), eliminating filename collisions across Octave platforms.

## What Was Built

### Task 1 (TDD RED + GREEN): Octave platform addpath in install.m + extend needs_build probe

**RED commit** (`e7fc529`): Added test 7 to `test_mex_prebuilt.m` and `testOctaveSubdirProbeAcceptsBinary` to `TestMexPrebuilt.m`. Both tests create a temporary `private/octave-<tag>/binary_search_mex.mex` sentinel, add the subdir to path, and assert `needs_build` returns false. Confirmed failing before implementation.

**GREEN commit** (`a683559`): Extended `install.m` with:

1. `get_octave_platform_tag()` — local function deriving tag from `computer('arch')`:
   - darwin + aarch64/arm64 → `macos-arm64`
   - darwin (other) → `macos-x86_64`
   - linux → `linux-x86_64`
   - mingw/w64 → `windows-x86_64`
   - unrecognized → `''`
   - Returns `''` on MATLAB (no-op)

2. Octave addpath loop (before `needs_build`): iterates three candidate dirs, calls `addpath` only when `isfolder` is true:
   - `libs/FastSense/private/octave-<tag>/`
   - `libs/FastSense/octave-<tag>/`
   - `libs/SensorThreshold/private/octave-<tag>/`

3. Extended `needs_build` probe to add a third absolute-path candidate `fullfile(mex_dir, ['octave-' octTag], 'binary_search_mex.mex')`. This handles the edge case where the shim call order doesn't guarantee the subdir is on path before the probe runs. Uses `exist(...,'file') == 2 || == 3` to accept both placeholder (type 2) and real MEX (type 3) files in tests.

All 7 `test_mex_prebuilt` tests pass; full suite 76/76.

### Task 2: Redirect Octave outputs in build_mex.m into platform subdir

**Commit** (`531766c`): Extended `build_mex.m` with:

1. `isOctave` flag at top (already existed for compiler selection) → used to branch outDir computation:
   - Octave: `outDir = private/octave-<tag>/`, `outDirMksql = FastSense/octave-<tag>/`, `sensorPrivDir = SensorThreshold/private/octave-<tag>/`
   - MATLAB: unchanged flat `private/`, `rootDir`, `SensorThreshold/private/`
   - All three Octave subdirs are `mkdir`-created if missing.

2. `local_octave_tag_(arch_raw)` added at end of file — same derivation rules as `get_octave_platform_tag()` in install.m, keeping build_mex.m self-contained.

3. mksqlite skip-if-exists probe and compile target updated to use `outDirMksql` instead of hardcoded `rootDir`.

4. `copy_mex_to` now uses the `sensorPrivDir` variable (Octave-aware) instead of a hardcoded path.

5. Test 6 updated in both test files to hide the octave-<tag>/ subdir binary alongside the flat binary.

**Verified on macOS ARM (Octave 9.2.0):** After clean delete of all `.mex` files, `install()` produces:
- `libs/FastSense/private/octave-macos-arm64/` — 8 kernel `.mex` files
- `libs/SensorThreshold/private/octave-macos-arm64/` — 4 shared kernel copies
- `libs/FastSense/octave-macos-arm64/mksqlite.mex`

Full test suite: **76/76 passed, 0 failed**.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test 6 (BinaryMissing) broke after build_mex.m redirection**

- **Found during:** Task 2 verification
- **Issue:** `testNeedsBuildReturnsTrueWhenBinaryMissing` only hid the flat `private/binary_search_mex.mex` sentinel. After Task 2, the real binary lives in `octave-macos-arm64/` and is on path via Task 1's `addpath`. `needs_build` found the subdir binary and returned false, causing the "expected true" assertion to fail.
- **Fix:** Extended test 6 in both `test_mex_prebuilt.m` and `TestMexPrebuilt.m` to also `movefile` the octave-<tag>/ binary to a backup path when on Octave, restoring it in the cleanup path.
- **Files modified:** `tests/test_mex_prebuilt.m`, `tests/suite/TestMexPrebuilt.m`
- **Commit:** `531766c` (included in Task 2 commit)

## Known Stubs

None. All three output locations (FastSense/private/octave-<tag>/, FastSense/octave-<tag>/, SensorThreshold/private/octave-<tag>/) are created and populated by a real `install()` call. Plan 04 will commit the actual compiled binaries for each platform.

## Self-Check: PASSED

- `install.m` contains `get_octave_platform_tag`: FOUND
- `install.m` contains `octave-`: FOUND (addpath loop + needs_build probe)
- `libs/FastSense/build_mex.m` contains `local_octave_tag_`: FOUND
- `libs/FastSense/build_mex.m` contains `octave-`: FOUND (outDir derivation)
- `tests/test_mex_prebuilt.m` contains test 7: FOUND
- `tests/suite/TestMexPrebuilt.m` contains `testOctaveSubdirProbeAcceptsBinary`: FOUND
- Commit `e7fc529` (RED): FOUND
- Commit `a683559` (GREEN): FOUND
- Commit `531766c` (Task 2): FOUND
