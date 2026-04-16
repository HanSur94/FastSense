---
phase: 1006-fix-137-matlab-test-failures-surfaced-by-matlab-on-every-push-ci-enablement-7-categories-from-r2025b-drift
plan: "01"
subsystem: ci
tags: [ci, matlab, pin, workflow]
dependency_graph:
  requires: []
  provides: [MATLABFIX-G]
  affects: [tests.yml, examples.yml]
tech_stack:
  added: []
  patterns: [release-pinning, cache-key-scoping]
key_files:
  created: []
  modified:
    - .github/workflows/tests.yml
    - .github/workflows/examples.yml
decisions:
  - "D-01 implemented: release: R2020b added to all three setup-matlab@v3 call-sites"
  - "MEX cache key scoped to r2020b (mex-matlab-linux-r2020b-) so future pin bumps invalidate stale binaries"
  - "D-03 honored: no matrix CI added"
  - "D-02 honored: CLAUDE.md unchanged"
metrics:
  duration: "5min"
  completed: "2026-04-16"
  tasks: 3
  files: 2
---

# Phase 1006 Plan 01: Pin MATLAB CI to R2020b Summary

**One-liner:** Pinned all three `matlab-actions/setup-matlab@v3` call-sites to `release: R2020b` and scoped the MEX cache key to prevent binary-ABI reuse across future pin bumps.

## What Was Built

Three YAML edits across two workflow files that implement user decision D-01 (pin R2020b, no matrix per D-03):

1. **tests.yml — `build-mex-matlab` job:** Added `release: R2020b` under `with:` in the `Setup MATLAB` step.
2. **tests.yml — MEX cache key:** Changed `mex-matlab-linux-${{ hashFiles(...) }}` to `mex-matlab-linux-r2020b-${{ hashFiles(...) }}` so a future pin bump naturally invalidates the cached R2020b binaries.
3. **tests.yml — `matlab` job:** Added `release: R2020b` under `with:` in the `Setup MATLAB` step.
4. **examples.yml — `matlab-examples` job:** Added `release: R2020b` under `with:` in the `Setup MATLAB` step.

## Tasks Completed

| Task | Name | Commit | Files Changed |
|------|------|--------|---------------|
| 1 | Pin tests.yml MATLAB jobs to R2020b + scope MEX cache key | cac7f75 | .github/workflows/tests.yml (+3/-1) |
| 2 | Pin examples.yml matlab-examples job to R2020b | 488dd83 | .github/workflows/examples.yml (+1/-0) |
| 3 | CI verification checkpoint | auto-approved | — |

## Verification Results

### Automated checks (pre-commit)

- `grep -c "release: R2020b" .github/workflows/tests.yml` → `2` (PASS)
- `grep -c "mex-matlab-linux-r2020b-" .github/workflows/tests.yml` → `1` (PASS)
- `grep -c "continue-on-error" .github/workflows/tests.yml` → `0` (PASS — no masking)
- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/tests.yml'))"` → exit 0 (PASS)
- `grep -c "release: R2020b" .github/workflows/examples.yml` → `1` (PASS)
- `grep -c "setup-matlab@v3" .github/workflows/examples.yml` → `1` (PASS — no accidental duplication)
- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/examples.yml'))"` → exit 0 (PASS)

### CI verification (Task 3 — pending)

Task 3 was auto-approved per wave-1 auto-advance mode. The actual CI run verification (confirming R2020b installs on ubuntu-latest and recording the post-pin failure count) is pending the push of branch `claude/nice-matsumoto` to remote and a CI run completion.

**Expected outcome:** Post-pin failure count should drop from 137 to approximately 75, as categories B (TestData migration), C (test-friend private access), and D (R2025b API changes) — totaling ~62 failures — should vanish under R2020b.

**Plans 1006-02/03/04** should use the actual post-pin failure count from the first CI run on this branch as their scope baseline. If R2020b fails to install on ubuntu-latest (rare but possible with older releases on newer Ubuntu images), fall back to `ubuntu-22.04` in the `runs-on` field.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — this plan contains only CI YAML changes with no MATLAB code stubs.

## Key Decisions Applied

- **D-01:** `release: R2020b` pinned on all three `setup-matlab@v3` call-sites in tests.yml (build-mex-matlab + matlab) and examples.yml (matlab-examples).
- **D-02:** CLAUDE.md unchanged (says "MATLAB R2020b+" — already aligned with the pin).
- **D-03:** No matrix CI added (single version only).
- **Cache key scoping:** Hardcoded `r2020b` in the MEX cache key (`mex-matlab-linux-r2020b-`) as specified in the plan's `<cache_key_contract>`. Cost of editing one line on a future bump is trivial.

## Self-Check: PASSED

- `.github/workflows/tests.yml` exists and contains `release: R2020b` (2 occurrences) and `mex-matlab-linux-r2020b-` (1 occurrence).
- `.github/workflows/examples.yml` exists and contains `release: R2020b` (1 occurrence).
- Commit `cac7f75` exists (Task 1).
- Commit `488dd83` exists (Task 2).
