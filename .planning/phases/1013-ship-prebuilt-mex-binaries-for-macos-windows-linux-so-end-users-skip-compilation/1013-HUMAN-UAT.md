---
status: partial
phase: 1013-ship-prebuilt-mex-binaries-for-macos-windows-linux-so-end-users-skip-compilation
source: [1013-VERIFICATION.md]
started: 2026-04-23
updated: 2026-04-23
---

## Current Test

[awaiting human testing on MATLAB and non-macOS-ARM64 platforms]

## Tests

### 1. MATLAB R2023b+ macOS ARM64 fresh-clone install skips compilation

expected: On a fresh MATLAB session (no prior `addpath`), running `install()` from the repo root should NOT print `--- Compiling MEX files ---` when `.mex-version` matches `mex_stamp(pwd)`. The shipped `.mexmaca64` binaries should be loaded via `install.m`'s addpath chain without triggering `build_mex()`. Probe: `install('__probe_needs_build__')` returns `0`. Fix is analytically identical to the Octave path (same `addpath libs/FastSense` at install.m:51, same `private/` scoping issue now resolved by `git mv` to public scope) but has not been directly exercised on this host (no MATLAB installed).

result: [pending]

### 2. MATLAB R2023b+ macOS ARM64 stamp mismatch triggers rebuild

expected: Mutating `.mex-version` (or deleting it) on a fresh MATLAB session should cause `install()` to print `--- Compiling MEX files ---` and invoke `build_mex()`. The rebuild path must remain intact — the fix should not break the from-source build when the stamp doesn't match.

result: [pending]

### 3. Windows + Linux fresh-clone install skips compilation (after refresh-mex-binaries.yml runs)

expected: After the first run of `.github/workflows/refresh-mex-binaries.yml` adds Windows (`.mexw64` + `octave-windows-x86_64/*.mex`) and Linux (`.mexa64` + `octave-linux-x86_64/*.mex`) binaries via auto-PR, fresh-clone installs on those platforms should likewise skip compilation. Tracked as part of the phase goal but gated on the CI workflow's first run — no binaries committed for those platforms yet (Plan 04 scope was macOS ARM64 only).

result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
