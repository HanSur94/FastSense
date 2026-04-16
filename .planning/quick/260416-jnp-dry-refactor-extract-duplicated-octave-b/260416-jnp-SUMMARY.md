---
phase: quick
plan: 260416-jnp
type: quick-task
tags: [ci, github-actions, dry-refactor, octave, mex]
completed: 2026-04-16
duration: ~5min
tasks_completed: 2
files_created: 1
files_modified: 3
commits:
  - a9158d6
  - 1ea9d14
---

# Quick Task 260416-jnp: DRY Refactor — Extract Duplicated Octave build-mex Job

**One-liner:** Extracted the 31-line Octave MEX build job inlined identically in 3 CI workflows into a single reusable workflow (`_build-mex-octave.yml`) with a parametric `artifact-name` input.

## Files Touched

| File | Change |
|------|--------|
| `.github/workflows/_build-mex-octave.yml` | **Created** — reusable workflow with `on: workflow_call:`, `artifact-name` input, single `build-mex` job (Octave 8.4.0 container, 4 steps) |
| `.github/workflows/tests.yml` | **Modified** — replaced 31-line inline `build-mex` with 5-line `uses:` caller; `if: github.event_name != 'schedule'` guard preserved |
| `.github/workflows/examples.yml` | **Modified** — replaced 31-line inline `build-mex` with 4-line `uses:` caller; `artifact-name: mex-linux-examples` |
| `.github/workflows/benchmark.yml` | **Modified** — replaced 31-line inline `build-mex` with 4-line `uses:` caller; `artifact-name: mex-linux-bench` |

## Line Delta

Before (inline jobs across 3 files): 3 x 31 = 93 lines of duplication  
After: 43-line reusable + 3 x ~4-line callers = ~55 lines total  
**Net reduction: ~38 lines across the 4 files combined** (93 - 43 - 12 = 38)

Confirmed by `wc -l`: tests.yml went from 219 to 193, examples.yml from 232 to 206, benchmark.yml from 79 to 53.

## GitHub Actions Constraints Honored

- Caller-side `uses:` jobs may NOT carry `timeout-minutes`, `runs-on`, `container`, `steps`, or `env` — all moved to the reusable.
- `if: github.event_name != 'schedule'` kept on the tests.yml caller (not the reusable), as reusable workflows don't evaluate event context meaningfully for this guard.
- Artifact names kept unique per caller (`mex-linux`, `mex-linux-examples`, `mex-linux-bench`) so `download-artifact` steps in downstream jobs resolve correctly.
- Caller job names remain `build-mex:` so `needs: build-mex` on `octave`, `smoke-test`, and `benchmark` jobs continue to resolve without any change.
- `_` filename prefix used per convention to mark workflow as internal/reusable.

## Verification Results

All verification commands passed:
- All 4 YAML files parse without error
- `grep -c 'needs: build-mex$'` returns 1 in each of the 3 caller files
- `grep -c 'uses: ./.github/workflows/_build-mex-octave.yml'` returns 1 in each of the 3 caller files
- tests.yml's `build-mex` retains `if: github.event_name != 'schedule'`
- No illegal keys (`timeout-minutes`, `runs-on`, `container`, `steps`, `env`) alongside `uses:` in any caller

## Commits

- `a9158d6` — `refactor(ci): extract reusable Octave MEX build workflow`
- `1ea9d14` — `refactor(ci): replace inline build-mex jobs with reusable workflow call`

## Deviations

None — plan executed exactly as written.
