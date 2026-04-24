---
phase: 1013-ship-prebuilt-mex-binaries-for-macos-windows-linux-so-end-users-skip-compilation
plan: 01
subsystem: install / MEX build system
tags: [install, mex, stamp, prebuilt, test]
dependency_graph:
  requires: []
  provides: [mex_stamp fingerprint helper, install stamp-check logic, TestMexPrebuilt test suite]
  affects: [install.m, libs/FastSense/private/mex_stamp.m]
tech_stack:
  added: []
  patterns: [stamp-check build guard, TDD RED->GREEN, install shim for testability]
key_files:
  created:
    - libs/FastSense/private/mex_stamp.m
    - tests/suite/TestMexPrebuilt.m
    - tests/test_mex_prebuilt.m
  modified:
    - install.m
decisions:
  - mex_stamp uses system sha256 (shasum -a 256 / sha256sum / certutil) on a concatenated temp file, with a pure-MATLAB fprint: fallback when system call fails or unavailable
  - Stamp file format: single line 'sha256:<64hex>' stored at libs/FastSense/private/.mex-version
  - install shim pattern: function varargout=install(varargin) with '__probe_needs_build__' sentinel arg returns scalar logical for tests without exporting needs_build as top-level function
  - needs_build order: SKIP_BUILD -> binary probe -> stamp file absent -> stamp mismatch -> trust binary
  - mex_stamp input set: sorted *.c + *.h in mex_src/, then build_mex.m, then mksqlite.c
metrics:
  duration: 25min
  completed: 2026-04-22T14:21:00Z
  tasks_completed: 2
  files_modified: 4
---

# Phase 1013 Plan 01: MEX Stamp Check + TestMexPrebuilt Summary

**One-liner:** Stamp-based needs_build using SHA-256 fingerprint of MEX sources with shim-accessible test suite (6/6 green on Octave, full suite 76/76 pass).

## What Was Built

### Task 1: mex_stamp helper + test scaffolding (RED)

`libs/FastSense/private/mex_stamp.m` computes a deterministic fingerprint of all MEX source inputs:

- **Input set:** sorted `*.c` and `*.h` under `libs/FastSense/private/mex_src/`, plus `libs/FastSense/build_mex.m`, plus `libs/FastSense/mksqlite.c`
- **Primary path:** concatenates all file bytes into a temp file, runs `shasum -a 256` (macOS), `sha256sum` (Linux), or `certutil -hashfile SHA256` (Windows), returns `sha256:<hex>`
- **Fallback path:** pure-MATLAB `fprint:<name:bytes:firstHex:lastHex>` tokens joined by `|` — content-based (not mtime), works without any shell tool

`tests/suite/TestMexPrebuilt.m` (MATLAB class-based) and `tests/test_mex_prebuilt.m` (Octave function-based) each cover 6 cases: stamp stability, content-change detection, SKIP_BUILD env var short-circuit, stamp match/mismatch, and missing binary. Tests were committed RED (failing) before Task 2 added the shim.

### Task 2: install.m rewrite (GREEN)

`install.m` changes:

1. Signature changed to `function varargout = install(varargin)` — backward compatible; existing callers with no args are unaffected.
2. **Test shim:** `install('__probe_needs_build__')` adds paths (so `mex_stamp` is findable) then returns `needs_build(root)` as `varargout{1}` and exits early.
3. **`needs_build` rewritten** with stamp-check logic:
   - `FASTSENSE_SKIP_BUILD` non-empty → `false` (unchanged fast-path)
   - `binary_search_mex.<mexext()>` or `.mex` missing → `true` (rebuild)
   - `.mex-version` absent → `true` (cannot verify, rebuild)
   - `stamp_matches_()` compares `strtrim(fileread(.mex-version))` against `mex_stamp(root)` → `true` if mismatch
   - All conditions pass → `false` (trust shipped binary)
4. New private helper `stamp_matches_(root, mex_dir)` isolates the I/O + compare logic with try/catch guard.

**Backward compatibility gate:** On the current worktree (no `.mex-version` committed, binaries present but git-ignored), `needs_build` finds the binary → passes binary probe, then finds no `.mex-version` → returns `true` → `first_run` / `build_mex` runs exactly as before.

## Verification

- `test_mex_prebuilt.m` on Octave: **6/6 passed**
- Full test suite (`run_all_tests`): **76/76 passed, 0 failed**

## Stamp Formula (canonical)

For reproducibility by Plan 05 CI shell script:

```
Files (sorted, in order):
  1. All *.c files in libs/FastSense/private/mex_src/ (sorted by name)
  2. All *.h files in libs/FastSense/private/mex_src/ (sorted by name)
  3. libs/FastSense/build_mex.m
  4. libs/FastSense/mksqlite.c

Hash:
  Concatenate raw bytes of all files in that order into a single blob.
  Compute SHA-256 of the blob.
  Format: sha256:<64-hex-lowercase>

Shell equivalent (macOS/Linux):
  find libs/FastSense/private/mex_src -maxdepth 1 -name '*.c' | sort | xargs cat > /tmp/blob
  find libs/FastSense/private/mex_src -maxdepth 1 -name '*.h' | sort | xargs cat >> /tmp/blob
  cat libs/FastSense/build_mex.m >> /tmp/blob
  cat libs/FastSense/mksqlite.c  >> /tmp/blob
  sha256sum /tmp/blob | cut -d' ' -f1   # or: shasum -a 256 | cut -d' ' -f1
```

Plan 05 CI workflow must mirror this order exactly for bit-for-bit identical output with `mex_stamp(root)`.

## Deviations from Plan

None — plan executed exactly as written. Task 1 was committed RED (failing tests) as planned; Task 2 made all 6 tests GREEN.

## Known Stubs

None.

## Self-Check: PASSED

- `libs/FastSense/private/mex_stamp.m` exists: FOUND
- `tests/suite/TestMexPrebuilt.m` exists: FOUND
- `tests/test_mex_prebuilt.m` exists: FOUND
- `install.m` updated: FOUND
- Commit `70479cb` (Task 1 RED): FOUND
- Commit `aa4761d` (Task 2 GREEN): FOUND
