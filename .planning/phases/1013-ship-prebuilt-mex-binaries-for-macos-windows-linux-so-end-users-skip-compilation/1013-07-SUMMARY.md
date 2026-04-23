---
phase: 1013-ship-prebuilt-mex-binaries-for-macos-windows-linux-so-end-users-skip-compilation
plan: 07
subsystem: infrastructure
tags: [mex, install, gap-closure, tdd]
gap_closure: true
closes: 1013-VERIFICATION.md gap 1 (end-user install skips compilation on fresh state)
requires:
  - Phase 1013 Plans 01-06 complete (stamp infrastructure, subdir layout, committed binaries, refresh workflow, release packaging)
provides:
  - install.m stamp fast-path operative end-to-end on Octave (and by analysis, MATLAB)
  - regression tests that assert (not SKIP) on both runtimes under Plan 03 subdir layout
affects:
  - libs/FastSense/mex_stamp.m (NEW — moved from private/)
  - libs/FastSense/build_mex.m (documentation-only)
  - libs/FastSense/private/.mex-version (restamped after build_mex.m comment)
  - tests/suite/TestMexPrebuilt.m
  - tests/test_mex_prebuilt.m
tech-stack:
  added: []
  patterns:
    - "Public-scope helpers over private/ scoping when called from repo-root scripts"
key-files:
  created:
    - libs/FastSense/mex_stamp.m
  modified:
    - libs/FastSense/build_mex.m
    - libs/FastSense/private/.mex-version
    - tests/suite/TestMexPrebuilt.m
    - tests/test_mex_prebuilt.m
  deleted:
    - libs/FastSense/private/mex_stamp.m (git rename, not copy-delete)
decisions:
  - "Chose option (b) 'move mex_stamp.m out of private/' over (a) addpath('private') [fragile under R2025b+] and (c) inline hashing [~190 lines duplicated]"
  - "Tests in sections 4/5 explicitly rmpath the private/ dir before probing, to exercise the fresh-state path that end-user install() takes"
  - "Rule 1 auto-fix: preserved committed octave-<tag>/binary_search_mex.mex during section 7 test via movefile backup/restore (prior code unconditionally deleted it)"
  - "Restamped .mex-version after adding build_mex.m comment so stamp gate continues to match sources"
metrics:
  duration: "~20min"
  completed: 2026-04-23
---

# Phase 1013 Plan 07: Stamp Fast-Path Gap Closure Summary

**One-liner:** Relocate `mex_stamp.m` from `libs/FastSense/private/` to `libs/FastSense/` so `install.m`'s stamp-check fast-path can actually call it, closing the single gap from 1013-VERIFICATION.md.

## Gap Closed

VERIFICATION.md **gap 1** (truth 7 FAILED): "End-user install on macOS ARM64 skips compilation when stamp matches."

**Root cause:** `install.m`'s local `stamp_matches_()` helper called `mex_stamp(root)`, but `mex_stamp.m` lived in `libs/FastSense/private/` — a MATLAB "private" directory invisible to callers at repo root. The `try/catch` around the call silently swallowed the "undefined function" error, so `stamp_matches_` always returned `false`, `needs_build` always returned `true`, and `first_run()` was always invoked (printing "--- Compiling MEX files ---" banner). Actual C compilation was only avoided by `build_mex.m`'s secondary per-file mtime guard — making the primary gating mechanism of Plans 01 + 04 inoperative.

## Options Considered

| Option | Description | Why rejected / chosen |
|--------|-------------|------------------------|
| (a) `addpath('private')` before `needs_build` | Least code change | Fragile: R2025b+ silently rejects private-dir addpath (see `tests/add_fastsense_private_path.m`) |
| **(b) Move `mex_stamp.m` to public scope** | `git mv libs/FastSense/private/mex_stamp.m libs/FastSense/mex_stamp.m` | **Chosen.** Minimal: `install.m` line 51 already addpaths `libs/FastSense`, so zero changes to `install.m` needed. `mex_stamp` is already documented as public API in the `install.m` See-also line. |
| (c) Inline the hashing logic into `install.m` | Self-contained install.m | Would duplicate ~190 lines of careful sha256+fallback logic; violates DRY; harder to keep aligned with `refresh-mex-binaries.yml` bash formula |

## Tasks Executed (TDD)

### Task 1 (RED) — commit `87b4956`
`test(1013-07): require committed sentinel + subdir-aware resolver (RED)`

- Added local `resolve_sentinel_(mex_dir)` helper in both test files:
  - On MATLAB: `private/binary_search_mex.<mexext()>` (flat .mexmaca64 etc.)
  - On Octave: `private/octave-<tag>/binary_search_mex.mex` (Plan 03 subdir)
- Removed `SKIPPED (no prebuilt binary present)` branch in `test_mex_prebuilt.m` section 4 — committed binaries (Plan 04) are a prerequisite, not optional
- Removed `touch_binary_` fallbacks in sections 4/5 of both test files
- Added `rmpath_silent_` (with canonical-path matching via `what()`) to remove `libs/FastSense/private/` from path before the probe in sections 4/5, restoring with `add_fastsense_private_path()` afterward. Without this step, `add_fastsense_private_path()` from setup leaves `private/` on path, making `mex_stamp` accidentally reachable and masking the bug.
- **Proved RED:** Octave `test_mex_prebuilt()` failed with `testNeedsBuildReturnsFalseWhenStampMatches: expected false when stamp matches`.

### Task 2 (GREEN) — commit `ef0e08c`
`fix(1013-07): move mex_stamp.m to public scope so install.m can reach it (GREEN)`

- `git mv libs/FastSense/private/mex_stamp.m libs/FastSense/mex_stamp.m`
- No code changes — file body byte-equal; git records a rename.
- **Proved GREEN:** `install('__probe_needs_build__')` now returns `0` on fresh path state; `which('mex_stamp')` resolves to `libs/FastSense/mex_stamp.m`; all 7 tests pass with Test 4 asserting.

### Task 3 (DOCS + deviations) — commit `d9eea5a`
`docs(1013-07): document build_mex mtime guard as backstop to stamp gate`

- Added 8-line NOTE block above `build_mex.m`'s per-file "SKIPPED (already exists)" guard, explaining it is the BACKSTOP and the primary gate is `install.m:needs_build` + `mex_stamp`.
- **Rule 1 auto-fix (bug):** tests' section 7 `run_octave_subdir_probe_test_` / `testOctaveSubdirProbeAcceptsBinary` was unconditionally writing a placeholder to `libs/FastSense/private/octave-macos-arm64/binary_search_mex.mex` and then `delete_if_exists_`-ing it at the end. Since Plan 04 committed this exact file to the repo, the test was destroying a tracked binary on every run. Fixed by moving the real binary aside to `.bak_probe_test` before writing the placeholder, then restoring on cleanup. Added a `restore_placeholder_then_binary_` helper in the MATLAB class file for proper `onCleanup` destructor ordering.
- **Rule 3 auto-fix (blocking):** adding the comment to `build_mex.m` changed the mex_stamp input set (build_mex.m is in the hash per `mex_stamp.m:21`), invalidating the committed `.mex-version`. Restamped to `sha256:28a0f3de...` so the gate continues to match sources.

## Evidence — 5 Verification Commands (from plan's `<verification>` block)

All run on Octave 7+ macOS ARM64 in `/Users/hannessuhr/FastPlot/.claude/worktrees/heuristic-greider-5b1776`:

```
=== 1. Fresh-state probe (expect 0) ===
RESULT=0                                     # was 1 before fix — PRIMARY GAP CLOSED

=== 2. Banner suppression (expect 0) ===
0                                            # zero "Compiling MEX files" lines in install() output

=== 3. Regression suite (expect All 7 passed) ===
    All 7 mex_prebuilt tests passed.         # Test 4 now ASSERTS, no longer SKIPs

=== 4. Rebuild path on stamp mismatch (expect 1) ===
RESULT=1                                     # no regression on rebuild trigger

=== 5. which(mex_stamp) public scope ===
PATH=/Users/hannessuhr/FastPlot/.claude/worktrees/heuristic-greider-5b1776/libs/FastSense/mex_stamp.m
                                             # resolves to public, not private/
```

**Probe elapsed time:** ~0.16s (under the 0.2s threshold).

## Human Verification Required

**MATLAB R2023b+ on macOS ARM64 — fresh-clone install() behavior.**

This host has no MATLAB installed; all verification ran on GNU Octave. The fix is analytically identical on MATLAB:

- `install.m` line 51 addpaths `libs/FastSense` (public scope) for both runtimes.
- `mex_stamp.m` is now discoverable by bare name in both runtimes.
- MATLAB's `private/` scoping behaves the same as Octave's — a function in `X/private/` is not visible from callers outside `X/` — so the bug and its fix both apply.

**Test plan for a human on MATLAB:**
1. Clone fresh into a new directory.
2. Start MATLAB R2023b+.
3. `cd` to repo root, run `install()`.
4. **Expect:** No "--- Compiling MEX files ---" banner, no `build_mex()` invocation, install completes in <0.1s (excluding JIT warmup).
5. Run `tests.TestMexPrebuilt` class — all 6 methods should pass (Test 4 now asserts, not skips).

## Forward-Looking

**Non-macOS-ARM64 platform binaries** (Windows x86_64, Linux x86_64, macOS x86_64) are not yet committed in the repo. This is tracked, not a gap — `refresh-mex-binaries.yml` (Plan 05) must run on `main` first to auto-open a PR with those binaries. After that PR lands, the stamp fast-path will deliver its value end-to-end to all end users regardless of platform.

## Deviations from Plan

### Rule 1 — Bug: committed binary destroyed by section 7 tests
- **Found during:** Task 3 verification (subdir binary kept disappearing from disk after each `test_mex_prebuilt()` run)
- **Issue:** Section 7 `run_octave_subdir_probe_test_` (Octave) and `testOctaveSubdirProbeAcceptsBinary` (MATLAB) unconditionally clobbered `libs/FastSense/private/octave-<tag>/binary_search_mex.mex` with a placeholder and `delete_if_exists_`-ed it on cleanup. The file is a Plan 04 committed artifact, not a test fixture.
- **Fix:** Added movefile-based backup/restore pattern around the placeholder write in both test files, plus a `restore_placeholder_then_binary_` helper in the MATLAB class for correct `onCleanup` destructor ordering.
- **Files modified:** `tests/suite/TestMexPrebuilt.m`, `tests/test_mex_prebuilt.m`
- **Commit:** `d9eea5a` (bundled with Task 3 since it only surfaced during Task 3 verification)

### Rule 3 — Blocking: stamp mismatch after adding comment to build_mex.m
- **Found during:** Task 3 verification (probe returned 1 after the comment addition)
- **Issue:** `mex_stamp` hashes `build_mex.m` as part of its input set (line 21 of `mex_stamp.m`), so the NOTE comment changed the fingerprint. The committed `.mex-version` no longer matched.
- **Fix:** Restamped `.mex-version` to the new fingerprint via a one-line Octave helper invocation. The new stamp is `sha256:28a0f3dea575bbb3fa7909b7146bfeb3766b74e2d6dc0849b8f31b1adfdd66c7`.
- **Files modified:** `libs/FastSense/private/.mex-version`
- **Commit:** `d9eea5a`

### Scope-boundary note: fresh-state path unmasking in tests
- The plan's Task 1 action described adding `resolve_sentinel_` + removing SKIPs; it did **not** explicitly mention `rmpath_silent_`. However, without removing `libs/FastSense/private/` from the path (which `add_fastsense_private_path()` in setup unconditionally adds), Octave silently makes `mex_stamp` reachable and the test goes GREEN before Task 2's fix, violating the RED/GREEN discipline. The `rmpath_silent_` addition was necessary to faithfully exercise the fresh-state path an end user sees.
- This was added as part of Task 1's RED commit (not a separate deviation).

## Known Stubs

None. The placeholder-binary pattern in section 7 tests is intentional test scaffolding (not a production stub); it is now correctly isolated from the tracked Plan 04 binaries.

## Self-Check: PASSED

- libs/FastSense/mex_stamp.m — FOUND
- libs/FastSense/private/mex_stamp.m — correctly MISSING (git rename)
- Commit 87b4956 (Task 1 RED) — FOUND in git log
- Commit ef0e08c (Task 2 GREEN) — FOUND in git log
- Commit d9eea5a (Task 3 DOCS) — FOUND in git log
- All 5 verification commands produce expected output on Octave macOS ARM64
- Probe elapsed time 0.16s — under 0.2s threshold
