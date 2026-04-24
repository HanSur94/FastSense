---
phase: 1013-ship-prebuilt-mex-binaries-for-macos-windows-linux-so-end-users-skip-compilation
plan: "02"
subsystem: packaging
tags: [gitignore, mex, prebuilt, binary-tracking]
dependency_graph:
  requires: []
  provides: [gitignore-mex-allow-list]
  affects: [git-tracking-for-mex-binaries]
tech_stack:
  added: []
  patterns: [gitignore-negation-allow-list]
key_files:
  created: []
  modified:
    - .gitignore
decisions:
  - "Use Option A (negation allow-list) to narrow MEX exclusions: global *.mex* ignore + explicit !path negations for shipped locations"
  - "Un-ignore MATLAB prebuilts in private/ dirs and FastSense root for all 4 MATLAB extensions"
  - "Un-ignore Octave prebuilts in platform-tagged subdirs (octave-<platform>/) for .mex extension"
  - "Un-ignore .mex-version stamp file at libs/FastSense/private/"
metrics:
  duration: "115s"
  completed_date: "2026-04-22"
  tasks_completed: 1
  files_modified: 1
---

# Phase 1013 Plan 02: Narrow .gitignore MEX Exclusions Summary

Replaced 5 blanket `*.mex*` rules with a global ignore block plus explicit negation allow-list covering all shipped MEX binary locations, enabling Plan 03 to commit current-platform prebuilt binaries.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Replace blanket *.mex* rules with explicit allow-list | 066a82a | .gitignore |

## What Was Built

Updated `.gitignore` using Option A from Research §7 verbatim. The five blanket MEX extension rules are preserved but followed by `!`-negation lines for every designated shipped location:

**MATLAB prebuilts (4 extensions each):**
- `libs/FastSense/private/` — 8 kernel binaries
- `libs/FastSense/` — mksqlite binary
- `libs/SensorThreshold/private/` — 4 copied kernel binaries

**Octave prebuilts (.mex, platform-tagged subdirs):**
- `libs/FastSense/private/octave-{linux-x86_64,macos-arm64,macos-x86_64,windows-x86_64}/`
- `libs/FastSense/octave-{linux-x86_64,macos-arm64,macos-x86_64,windows-x86_64}/` (mksqlite only)
- `libs/SensorThreshold/private/octave-{linux-x86_64,macos-arm64,macos-x86_64,windows-x86_64}/`

**Stamp file:** `libs/FastSense/private/.mex-version` (always tracked)

## Verification Results

The plan's automated verify command fails because `git check-ignore -q` exits 0 even when the last matching rule is a negation (git 2.23.0 behavior). However, the functional behavior is correct — verified via `git status` and `git add`:

**Shipped paths show as untracked (not ignored):**
```
?? libs/FastSense/private/check_shipped.mexmaca64
?? libs/FastSense/private/check_shipped.mexa64
?? libs/FastSense/private/check_shipped.mexw64
?? libs/FastSense/private/octave-linux-x86_64/check_shipped.mex
?? libs/FastSense/mksqlite.mexmaca64
?? libs/FastSense/private/.mex-version
```
Stray paths (e.g., `benchmarks/stray_test.mexmaca64`) produce no output in `git status` — properly ignored.

`git add libs/FastSense/private/binary_search_mex.mexmaca64` succeeded and staged the file (confirmed `A` in status).

**Critical note verification commands (from prompt):**

```bash
# Check 1: Should return the !-negation rule (NOT ignored)
git check-ignore -v libs/FastSense/private/binary_search_mex.mexmaca64
# Output: .gitignore:10:!libs/FastSense/private/*.mexmaca64 <path>

# Check 2: Should return the !-negation rule (NOT ignored)
git check-ignore -v libs/FastSense/private/octave-macos-arm64/binary_search_mex.mex
# Output: .gitignore:24:!libs/FastSense/private/octave-macos-arm64/*.mex <path>

# Check 3: benchmarks/stray.mex should still be ignored
git check-ignore -v benchmarks/stray.mex
# Output: .gitignore:6:*.mex benchmarks/stray.mex

# Check 4: foo.mexmaca64 at repo root should still be ignored
git check-ignore -v foo.mexmaca64
# Output: .gitignore:3:*.mexmaca64 foo.mexmaca64
```

When `git check-ignore -v` shows a `!`-prefixed rule as the last match, the file is un-ignored (git treats it as trackable). Checks 1 and 2 show the negation rule; Checks 3 and 4 show the blanket ignore rule — correct behavior.

## Deviations from Plan

**1. [Rule 1 - Bug] Plan's verify script incompatible with git 2.23.0 `check-ignore -q` behavior**

- **Found during:** Task 1 verification
- **Issue:** `git check-ignore -q` exits 0 for paths matched by negation rules as well as paths matched by ignore rules in git 2.23.0. The plan's verify script used this to detect un-ignored paths, but got false positives.
- **Fix:** Used `git status --short` and `git add` to confirm functional correctness instead. The `.gitignore` changes themselves are exactly as specified in the plan — no deviation in the actual file content.
- **Files modified:** None (verification approach adapted, not the gitignore content)

## Known Stubs

None — this plan only modifies `.gitignore`.

## Self-Check: PASSED

- .gitignore modified: confirmed (33 insertions)
- Commit 066a82a exists: confirmed
- Shipped paths trackable: confirmed via git status showing `??`
- Stray paths remain ignored: confirmed via git status showing nothing
