---
phase: quick-260416-j6e
plan: 01
subsystem: ci
tags: [ci, github-actions, matlab, mex]
dependency_graph:
  requires: []
  provides: [matlab-ci-every-push-pr]
  affects: [.github/workflows/tests.yml]
tech_stack:
  added: []
  patterns: [needs-based job chaining, artifact passing for MEX binaries]
key_files:
  modified:
    - .github/workflows/tests.yml
decisions:
  - "Removed continue-on-error outright (not commented out) per explicit task_specifics instruction"
  - "Cache prefix mex-matlab-linux- (not mex-linux-) to avoid collision with Octave cache"
  - "matlab job if-guard is != 'schedule' so weekly cron skips MATLAB but push/PR/workflow_dispatch all run it"
metrics:
  duration: "~3 minutes"
  completed: "2026-04-16"
  tasks: 1
  files: 1
---

# Quick Task 260416-j6e: Enable MATLAB CI on Every Push/PR Summary

**One-liner:** Added `build-mex-matlab` job compiling `.mexa64` artifacts and rewired `matlab` job to run on every push/PR with `setup-matlab@v3`, `cache: true`, and `FASTSENSE_SKIP_BUILD=1`.

## What Was Done

Two surgical edits to `.github/workflows/tests.yml`:

### Edit 1 — Insert `build-mex-matlab` job (after Octave `build-mex`, before `octave`)

New job added at lines 63-99:
- `runs-on: ubuntu-latest` (no Octave container — MATLAB action manages its own environment)
- `if: github.event_name != 'schedule'` (mirrors the Octave `build-mex` guard)
- `matlab-actions/setup-matlab@v3` with `cache: true`
- `actions/cache@v5` with key prefix `mex-matlab-linux-` (collision-safe vs Octave `mex-linux-`)
- Cache `path:` covers all three MEX output locations: `libs/FastSense/private/*.mexa64`, `libs/SensorThreshold/private/*.mexa64`, `libs/FastSense/mksqlite.mexa64`
- Compile step: `matlab-actions/run-command@v2` calling `install();` (guarded by cache-hit check)
- `actions/upload-artifact@v7` uploading artifact `mex-matlab-linux` with `retention-days: 1`

### Edit 2 — Replace `matlab` job (lines 232-265 in final file)

Changes from old job:
1. `if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'` → `if: github.event_name != 'schedule'` — job now runs on every push/PR/workflow_dispatch
2. `continue-on-error: true` — removed entirely (not commented out)
3. Added `needs: build-mex-matlab`
4. Added `env: FASTSENSE_SKIP_BUILD: "1"` — skips `build_mex.m` compilation in `install()`
5. `matlab-actions/setup-matlab@v2` → `@v3` with `with: cache: true`
6. New step: `actions/download-artifact@v8` downloading `mex-matlab-linux` (matching `@v8` used by Octave job)
7. Codecov upload preserved verbatim: `flags: matlab`, `fail_ci_if_error: false`, `CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}`

## Deviations from Plan

### Deviation 1 (explicit, user-directed): `continue-on-error` removed outright

The RESEARCH.md "What changed and why" table suggested commenting out `continue-on-error: true` for a 2-week trial period. The task instruction explicitly overrides this: "Remove `continue-on-error: true`". Applied as directed — the line is gone, not commented out.

No other deviations. All prescribed YAML was applied verbatim.

## Verification Results

All automated checks passed:

```
YAML structural checks passed
```

Cache key check confirmed two distinct prefixes:
- Line 47: `mex-linux-...` (Octave build-mex job — unchanged)
- Line 83: `mex-matlab-linux-...` (new build-mex-matlab job)

`actionlint` not installed — skipped (non-blocking per plan).

## Commit

**52d6524** — `ci: enable MATLAB tests on every push/PR with setup-matlab@v3 + cache`

Files changed: `.github/workflows/tests.yml` (+50 insertions, -3 deletions)

## CI Run Verification (Deferred)

Actual MATLAB job execution (public repo auto-licensing, `.mexa64` compile success, artifact path placement) will be verified on the next push to a PR or main. The plan's verification section explicitly deferred this to the first CI run.

## Self-Check: PASSED

- `.github/workflows/tests.yml` exists and is modified
- Commit `52d6524` exists in git log
- YAML parses without errors
- Structural assertions all pass
