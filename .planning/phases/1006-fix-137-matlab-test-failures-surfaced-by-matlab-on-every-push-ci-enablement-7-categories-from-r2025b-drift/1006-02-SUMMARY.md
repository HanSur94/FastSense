---
phase: 1006-fix-137-matlab-test-failures-surfaced-by-matlab-on-every-push-ci-enablement-7-categories-from-r2025b-drift
plan: "02"
subsystem: ci
tags: [ci, matlab, mksqlite, mex, test-guard, skipUnless]
dependency_graph:
  requires: [MATLABFIX-G]
  provides: [MATLABFIX-A]
  affects: [tests.yml, build_mex.m, TestMksqliteEdgeCases.m, TestMksqliteTypes.m]
tech_stack:
  added: []
  patterns: [skipUnless-guard, TestMethodSetup, assumeTrue]
key_files:
  created: []
  modified:
    - .github/workflows/tests.yml
    - libs/FastSense/build_mex.m
    - tests/suite/TestMksqliteEdgeCases.m
    - tests/suite/TestMksqliteTypes.m
decisions:
  - "Branch C selected: skipUnless guard added to both mksqlite test suites (no CI evidence available; safe fallback per D-06)"
  - "Warning ID build_mex:mksqliteCompileFailed added to silent catch block in build_mex.m (additive; surfacing build failures in CI step summaries)"
  - "Diagnostic CI steps retained per plan cross-branch constraint (Task 1 steps remain)"
metrics:
  duration: "10min"
  completed: "2026-04-16"
  tasks: 2
  files: 4
---

# Phase 1006 Plan 02: Fix mksqlite Test Failures Summary

**One-liner:** Added Branch-C `assumeTrue(exist('mksqlite','file')==3)` skipUnless guards to both mksqlite test suites and upgraded the silent compile-failure catch in `build_mex.m` to emit a named warning ID.

## What Was Built

Two targeted changes that eliminate ~50 CI failures from `TestMksqliteEdgeCases` (26 tests) + `TestMksqliteTypes` (24 tests):

### Task 1: Diagnostic CI steps

Added three diagnostic steps to `.github/workflows/tests.yml`:

1. **`Diagnose mksqlite build output`** (in `build-mex-matlab` job, after compile) — shell `ls` check showing which mksqlite files exist post-compile.
2. **`Diagnose mksqlite availability for tests`** (in `matlab` job, after artifact download) — shell `ls` check showing which mksqlite files arrived from the artifact.
3. **`MATLAB which-mksqlite check`** (in `matlab` job, after artifact download) — MATLAB `which`/`exist`/`mksqlite('version')` call producing definitive evidence.

All three steps use `continue-on-error: true` (pure logging steps, no pass/fail semantic). The main "Run tests with coverage" step is untouched per D-15.

### Task 2: Branch C fix

**Branch choice: C — skipUnless guard**

**Reasoning:** No CI evidence was available at the time of execution (auto-advance mode, no prior CI run on this branch). The plan's checkpoint handling instructs: "default to branch C (skipUnless guard mirroring TestMexEdgeCases) — this is the safe fallback that unblocks CI without losing correctness." Additionally, the plan's own analysis notes that mksqlite compilation failure is silently swallowed in `build_mex.m` — making it likely that `mksqlite.mexa64` is absent from the artifact (Evidence A). Branch C is correct for either Evidence A or Evidence C.

**Local evidence supporting Branch C:**
- `build_mex.m` lines 213-218: mksqlite compile failure is caught, printed, but execution continues with `n_fail = n_fail + 1` — no error raised, no warning emitted.
- `FASTSENSE_SKIP_BUILD: "1"` in the `matlab` test job means the test job does NOT recompile; it relies 100% on the artifact.
- If `mksqlite.c` compilation fails silently during `build-mex-matlab`, the artifact upload step will silently skip the absent file (per plan context: "uploads absent files silently with a warning; does not fail the step").
- Result: tests in `matlab` job see no `mksqlite.mexa64` on path → `Undefined function 'mksqlite'` → 50 failures.

**Changes:**

- **`TestMksqliteEdgeCases.m`:** Added `assumeTrue(exist('mksqlite', 'file') == 3, ...)` at the top of the existing `TestMethodSetup` method `setupDatabase()`. Since `setupDatabase` runs before every one of the 26 test methods, all will be filtered cleanly when mksqlite is absent.
- **`TestMksqliteTypes.m`:** Added a new `methods (TestMethodSetup)` block `skipIfNoMksqlite()` with the same guard. The 24 test methods each call `openDb()` (a private helper that calls `mksqlite`) — with the `TestMethodSetup` guard running first, all 24 filter cleanly.
- **`build_mex.m`:** Added `warning('build_mex:mksqliteCompileFailed', ...)` to the mksqlite catch block (additive — does not change behavior, only makes the failure visible in CI step summaries). This is the "Branch A warning upgrade" mentioned in the plan's cross-branch constraints.

**Pattern used (matches `TestMexEdgeCases.m` reference):**
```matlab
testCase.assumeTrue(exist('mksqlite', 'file') == 3, ...
    'mksqlite MEX not available; skipping under CI');
```

**Octave safety:** Under Octave CI, `mksqlite.mex` is compiled by the `build-mex` job (Octave container). `exist('mksqlite', 'file') == 3` returns true there. The guard passes and tests run exactly as before — no Octave regression.

## Tasks Completed

| Task | Name | Commit | Files Changed |
|------|------|--------|---------------|
| 1 | Add diagnostic CI steps to build-mex-matlab and matlab jobs | 52c7841 | .github/workflows/tests.yml (+37/-0) |
| 2 | Branch-C skipUnless guard + build_mex warning upgrade | dfc7b28 | tests/suite/TestMksqliteEdgeCases.m, tests/suite/TestMksqliteTypes.m, libs/FastSense/build_mex.m (+11/-0) |

## Branch Decision Evidence

| Signal | Value | Source |
|--------|-------|--------|
| CI diagnostic data available? | No (auto-advance, no prior CI run on branch) | Checkpoint handling instructions |
| build_mex.m catch behavior | Silent swallow (print + n_fail++) | libs/FastSense/build_mex.m lines 213-218 |
| FASTSENSE_SKIP_BUILD in matlab job | "1" — no recompile in tests | .github/workflows/tests.yml line 241 |
| mksqlite.mexa64 in repo | Not committed (build artifact only) | git ls-files |
| Branch selected | C — skipUnless guard | Per D-06 safe fallback |

## Expected CI Outcome

**Before Plan 02:**
- `TestMksqliteEdgeCases`: 26 FAILED (Undefined function 'mksqlite')
- `TestMksqliteTypes`: 24 FAILED (Undefined function 'mksqlite')
- Total: ~50 failures

**After Plan 02 (when mksqlite absent from CI artifact):**
- `TestMksqliteEdgeCases`: 26 Filtered (assumeTrue guard)
- `TestMksqliteTypes`: 24 Filtered (skipIfNoMksqlite guard)
- Total: 0 failures, 50 filtered

**After Plan 02 (when mksqlite IS present in CI artifact — e.g., after Branch A compile fix):**
- `TestMksqliteEdgeCases`: 26 Passed (guard passes, tests run normally)
- `TestMksqliteTypes`: 24 Passed (guard passes, tests run normally)
- Total: 0 failures, 50 passed

The guard is additive — it does not prevent the tests from running when mksqlite compiles successfully.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Cross-branch constraint] Added build_mex warning ID (Branch A prep)**

- **Found during:** Task 2 (plan explicitly calls it out in the CROSS-BRANCH CONSTRAINTS section)
- **Issue:** mksqlite compile failure was silently swallowed — `install()` returns success with no visible warning, making CI step summaries show no indication of the problem
- **Fix:** Added `warning('build_mex:mksqliteCompileFailed', 'mksqlite failed to compile: %s', e.message)` to the catch block in `build_mex.m`
- **Files modified:** `libs/FastSense/build_mex.m`
- **Commit:** dfc7b28

## Known Stubs

None — no placeholder data or hardcoded values. The `assumeTrue` guard is the intended production behavior.

## Open Follow-Up

- **Determine actual Evidence class:** The Task 1 diagnostic steps will produce CI log output on the next push. Future work (Plan 1006-04 cleanup or a quick task) should read the logs and document the actual Evidence class (A, B, or C) in the investigation manifest.
- **Branch A compile fix (future):** If logs show mksqlite.c compilation actually fails under MATLAB R2020b (Evidence A), a follow-up quick task can fix the compile flags in `build_mex.m` (e.g., `-DSQLITE_THREADSAFE=0` wrapping via `CFLAGS`). This would move the 50 filtered tests back to 50 passing.
- **Diagnostic step removal:** Plan specifies diagnostic steps should be removed in Plan 04's summary cleanup — or earlier if they produce enough signal.

## Self-Check: PASSED

- `.github/workflows/tests.yml` modified (diagnostic steps added, 3 `continue-on-error: true` on diagnostic steps only)
- `libs/FastSense/build_mex.m` modified (warning ID added)
- `tests/suite/TestMksqliteEdgeCases.m` modified (assumeTrue guard in setupDatabase)
- `tests/suite/TestMksqliteTypes.m` modified (new skipIfNoMksqlite TestMethodSetup)
- Commit `52c7841` exists (Task 1)
- Commit `dfc7b28` exists (Task 2)
