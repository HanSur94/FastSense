---
phase: 1013-ship-prebuilt-mex-binaries-for-macos-windows-linux-so-end-users-skip-compilation
verified: 2026-04-23T12:00:00Z
status: human_needed
score: 7/7 must-haves verified (automated); 1 item needs MATLAB-side human verification
re_verification:
  previous_status: gaps_found
  previous_score: 6/7
  gaps_closed:
    - "End-user install on macOS ARM64 skips compilation when stamp matches (Octave verified; MATLAB analytically identical, deferred to human)"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Fresh clone on MATLAB R2023b+ macOS ARM64 — run install() and observe banner"
    expected: "No '--- Compiling MEX files ---' banner, no build_mex() invocation, install completes in <0.1s; TestMexPrebuilt suite asserts (not SKIPs) on Test 4"
    why_human: "No MATLAB installed on this host. Fix is analytically identical on MATLAB because install.m line 51 addpaths libs/FastSense for both runtimes and MATLAB private/ scoping behaves the same as Octave, but MATLAB binding was not directly exercised."
  - test: "Windows + Linux end-user install() — once refresh-mex-binaries.yml auto-PR lands committed binaries for those platforms"
    expected: "Same stamp fast-path behavior on non-macOS-ARM64 platforms"
    why_human: "Those binaries are not yet committed (Plan 05 workflow must run on main first). This is expected/tracked, not a gap."
---

# Phase 1013: Ship Prebuilt MEX Binaries Verification Report (Re-Verification)

**Phase Goal:** Ship prebuilt MEX binaries for macOS/Windows/Linux so end users skip compilation.

**Verified:** 2026-04-23 (re-verification after gap closure Plan 1013-07)
**Status:** human_needed — all automated checks pass on Octave macOS ARM64; MATLAB-side fresh-clone behavior deferred to human (no MATLAB on this host)
**Re-verification:** Yes — initial verification (2026-04-23 earlier) found 1 gap on truth #7; Plan 1013-07 landed (commits `87b4956`, `ef0e08c`, `d9eea5a`, `b34877a`). This re-verification confirms gap closure.

## Gap Closure Summary

Plan 1013-07 resolved the single gap from the initial verification by relocating `mex_stamp.m` from `libs/FastSense/private/` (MATLAB private scope, invisible to repo-root `install.m`) to `libs/FastSense/` (public scope, already addpath'd by `install.m:51`). Tests (`tests/suite/TestMexPrebuilt.m` and `tests/test_mex_prebuilt.m`) were updated with a subdir-aware `resolve_sentinel_` helper so Test 4 asserts (not SKIPs) under the Plan 1013-03 platform-tagged subdir layout. `.mex-version` was restamped after a documentation-only comment was added to `build_mex.m` (which is part of the stamp input set).

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `.gitignore` allow-list permits tracked MEX at designated locations, ignores elsewhere | ✓ VERIFIED | 27 binary artifacts tracked (`git ls-files` output); unchanged from initial verification. |
| 2 | `mex_stamp.m` helper exists and `install.m` uses stamp-check gating | ✓ VERIFIED (FIXED) | `libs/FastSense/mex_stamp.m` exists (5649 bytes); `libs/FastSense/private/mex_stamp.m` is gone (git rename in `ef0e08c`). `which('mex_stamp')` in Octave resolves to public-scope path. `install.m:stamp_matches_` reaches `mex_stamp(root)` successfully — no more silent try/catch fallthrough. |
| 3 | Octave platform-tagged subdir layout routing | ✓ VERIFIED | Unchanged from initial verification. Committed binaries present at `libs/FastSense/private/octave-macos-arm64/*.mex`. |
| 4 | macOS ARM64 binaries (13 MATLAB + 13 Octave) committed + `.mex-version` stamp | ✓ VERIFIED | 27 tracked artifacts. `.mex-version` content `sha256:28a0f3de…` matches `mex_stamp(pwd)` output byte-for-byte (restamped after build_mex.m comment). |
| 5 | `.github/workflows/refresh-mex-binaries.yml` exists with 7-platform matrix + auto-PR | ✓ VERIFIED | Unchanged from initial verification. |
| 6 | 5 existing CI workflows reuse committed binaries when stamp matches | ✓ VERIFIED | Unchanged from initial verification. |
| 7 | End-user install on macOS ARM64 skips compilation when stamp matches | ✓ VERIFIED (FIXED) | `install('__probe_needs_build__')` returns `0` on fresh path state (only `addpath(pwd)`). `install()` output contains zero occurrences of "Compiling MEX files". Rebuild path intact: mutating `.mex-version` → probe returns `1`. Regression test Test 4 asserts (not SKIPs). See behavioral spot-checks below. |

**Score:** 7/7 truths verified (automated, Octave macOS ARM64). MATLAB-side behavior flagged for human.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `libs/FastSense/mex_stamp.m` | Public-scope SHA-256 fingerprint helper | ✓ VERIFIED | Exists (5649 bytes); git rename from `private/mex_stamp.m` (commit `ef0e08c`). |
| `libs/FastSense/private/mex_stamp.m` | Must NOT exist (moved) | ✓ VERIFIED | `ls libs/FastSense/private/mex_stamp.m` returns "No such file". |
| `libs/FastSense/private/.mex-version` | Current stamp | ✓ VERIFIED | `sha256:28a0f3dea575bbb3fa7909b7146bfeb3766b74e2d6dc0849b8f31b1adfdd66c7` — matches live `mex_stamp(pwd)` byte-for-byte. |
| `install.m` needs_build stamp gate | Reachable & operative | ✓ VERIFIED (FIXED) | Installer line 51 addpaths `libs/FastSense`; mex_stamp now resolves by bare name; try/catch path no longer silently triggered. |
| `libs/FastSense/build_mex.m` mtime guard documentation | `BACKSTOP` comment block | ✓ VERIFIED | `grep -c "BACKSTOP, not"` returns 1. Comment only, no executable-logic change. |
| `tests/suite/TestMexPrebuilt.m` | Subdir-aware resolver + no SKIPs on Test 4 | ✓ VERIFIED | `resolve_sentinel_` appears 2× in file. |
| `tests/test_mex_prebuilt.m` | Subdir-aware resolver + no SKIPs on Test 4 | ✓ VERIFIED | `resolve_sentinel_` appears 2×; "SKIPPED (no prebuilt binary present)" removed (grep count = 0). |
| MATLAB `.mexmaca64` × 13 | Committed | ✓ VERIFIED | All 13 tracked. |
| Octave `.mex` × 13 (macos-arm64 subdir) | Committed | ✓ VERIFIED | All 13 tracked. |
| `.github/workflows/refresh-mex-binaries.yml` | 7-way matrix + auto-PR | ✓ VERIFIED | Unchanged from initial. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `install.m:stamp_matches_` | `libs/FastSense/mex_stamp.m` | direct bare-name call after `addpath(libs/FastSense)` at line 51 | ✓ WIRED (FIXED) | `which('mex_stamp')` on Octave after install returns the public path. try/catch is no longer hit. |
| `install.m` needs_build | `.mex-version` | `fileread(stamp_file)` + `strcmp(stored, current)` | ✓ WIRED | Probe returns 0 (match) → 1 (mismatch) correctly. |
| `TestMexPrebuilt`/`test_mex_prebuilt` Test 4 | `binary_search_mex.mex` (subdir) / `.mexmaca64` (flat) | `resolve_sentinel_(mex_dir)` helper | ✓ WIRED | Both test files contain helper; Octave run asserts result == false and passes. |
| `build_mex.m` mtime guard | Documented as backstop | comment block | ✓ WIRED | Comment present; no logic change. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `mex_stamp.m` | sha256 hex | sha256sum on concatenated .c/.h/build_mex.m/mksqlite.c | ✓ yes — byte-matches committed `.mex-version` | ✓ FLOWING |
| `install.m:stamp_matches_` | `current = mex_stamp(root)` | mex_stamp (public) | ✓ Reachable, returns real value | ✓ FLOWING (was DISCONNECTED) |
| `.mex-version` | sha256 string | committed | ✓ yes (restamped to `sha256:28a0f3de…`) | ✓ FLOWING |
| `install.m:needs_build` | `yes` boolean | `~stamp_matches_(root, mex_dir)` | ✓ 0 on match, 1 on mismatch | ✓ FLOWING |

### Behavioral Spot-Checks

All five verification commands from Plan 1013-07 executed on Octave 11.1.0 macOS ARM64 in `/Users/hannessuhr/FastPlot/.claude/worktrees/heuristic-greider-5b1776`.

| # | Behavior | Command | Result | Status |
|---|----------|---------|--------|--------|
| 1 | Fresh-state stamp probe returns 0 when stamp matches | `octave --eval "addpath(pwd); r = install('__probe_needs_build__'); disp(r)"` | `0` | ✓ PASS (was 1 before fix) |
| 2 | `install()` prints no "Compiling MEX files" banner | `octave --eval "addpath(pwd); install()" 2>&1 \| grep -c "Compiling MEX files"` | `0` | ✓ PASS (was 1 before fix) |
| 3 | Regression suite: all 7 tests assert (no SKIPs on Test 4) | `octave --eval "addpath(pwd); install(); cd tests; test_mex_prebuilt()"` | `All 7 mex_prebuilt tests passed.` | ✓ PASS |
| 4 | Rebuild path intact on stamp mismatch | `octave --eval "<mutate stamp to sha256:bad>; r = install('__probe_needs_build__'); disp(r)"` | `1` | ✓ PASS |
| 5 | `which('mex_stamp')` resolves to public scope | `octave --eval "addpath(pwd); install(); disp(which('mex_stamp'))"` | `…/libs/FastSense/mex_stamp.m` | ✓ PASS |
| 6 | `mex_stamp(pwd)` byte-matches committed `.mex-version` | `octave --eval "addpath(pwd); addpath('libs/FastSense'); disp(mex_stamp(pwd))"` vs `cat libs/FastSense/private/.mex-version` | Both `sha256:28a0f3dea575bbb3fa7909b7146bfeb3766b74e2d6dc0849b8f31b1adfdd66c7` | ✓ PASS |
| 7 | 27 tracked binary artifacts | `git ls-files libs/**/*.mexmaca64 libs/**/octave-macos-arm64/** .mex-version` | 27 files | ✓ PASS |

### Anti-Patterns Found

None blocking.

The prior-verification blockers are resolved:
- `install.m` `try/catch` around `mex_stamp` is no longer exercised on the happy path (mex_stamp resolves by bare name). It remains as defensive error handling only.
- `tests/test_mex_prebuilt.m` `SKIPPED (no prebuilt binary present)` branch has been removed (grep count: 0).

### Requirements Coverage

REQUIREMENTS.md does not exist in this project. Coverage assessed against phase goal only.

### Human Verification Required

1. **MATLAB R2023b+ macOS ARM64 fresh-clone `install()` behavior**
   **Test:** Clone fresh into new directory. Start MATLAB R2023b+. `cd` to repo root. Run `install()`. Then `runtests('tests/suite/TestMexPrebuilt.m')`.
   **Expected:** No `--- Compiling MEX files ---` banner, no `build_mex()` invocation. All TestMexPrebuilt methods pass with Test 4 asserting (not skipping).
   **Why human:** No MATLAB installed on this host. Fix is analytically identical on MATLAB because (a) `install.m` line 51 addpaths `libs/FastSense` for both runtimes, (b) `mex_stamp` is resolved by bare name, and (c) MATLAB `private/` scoping behaves the same as Octave. All automated Octave checks pass; MATLAB binding was not directly exercised.

2. **Non-macOS-ARM64 platform binaries (Windows/Linux)**
   **Test:** Run `install()` on Windows MATLAB and Linux Octave fresh clones.
   **Expected:** Stamp fast-path delivers value on those platforms once `refresh-mex-binaries.yml` has run on `main` and landed its auto-PR.
   **Why human:** Those binaries are not yet committed. This is expected/tracked (Plan 04 explicitly shipped only macOS ARM64; Plan 05 backfills via workflow). Not a gap.

### Gaps Summary

No gaps remain. The single gap from the initial verification — "end-user install on macOS ARM64 skips compilation when stamp matches" — is closed:

- `mex_stamp.m` is now reachable from `install.m` at repo root via public-scope placement in `libs/FastSense/`.
- The primary gating mechanism (stamp fast-path) is operative end-to-end on Octave macOS ARM64: fresh-state probe returns 0, `install()` prints no compile banner, rebuild path still triggers on stamp mutation.
- Regression tests now assert (not SKIP) under the Plan 03 subdir layout, preventing future silent regressions.
- Collateral: `.mex-version` restamped to `sha256:28a0f3de…` after the documentation-only change to `build_mex.m` (which is part of the stamp input set).

MATLAB-side fresh-clone behavior is flagged for human verification because this host has no MATLAB installation. The fix is analytically identical on MATLAB (same `addpath` sequence, same `private/` scoping rules), but the claim has not been directly exercised.

---

*Re-verified: 2026-04-23*
*Verifier: Claude (gsd-verifier)*
*Previous verification: 2026-04-23 (initial) — gaps_found, 6/7; this re-verification confirms gap 1 closure*
