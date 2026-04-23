---
id: 260423-s4s
mode: quick
completed: 2026-04-23
---

# Quick 260423-s4s: Auto-trigger refresh-mex-binaries.yml on MEX source changes

## One-liner

Added `libs/FastSense/mex_stamp.m` to the `on.push.paths` filter in `refresh-mex-binaries.yml` so that changes to the stamp formula helper itself (not just its inputs) trigger a full 7-platform refresh.

## What was discovered during execution

The user's original request was broader — "auto-trigger after each CI run". Investigation of the current workflow state revealed that **Phase 1013-05 already shipped the push-on-main trigger with a path filter** covering the stamp's input files (`libs/FastSense/private/mex_src/**`, `build_mex.m`, `mksqlite.c`). The orchestrator had misremembered it as `workflow_dispatch`-only.

Only one defensive gap remained: the stamp formula helper `libs/FastSense/mex_stamp.m` itself wasn't in the path filter. If someone modifies the formula logic (e.g., changing concatenation order or adding inputs) without simultaneously updating the aggregator job's bash reimplementation of the same formula, the two can drift — the aggregator would compute a different hash than MATLAB/Octave's `mex_stamp(pwd)` call, breaking the stamp-match fast path. Adding the helper to the trigger paths ensures the auto-refresh fires whenever the formula source-of-truth changes, which is exactly when a full cross-platform rebuild is needed.

## Files modified

- `.github/workflows/refresh-mex-binaries.yml` — added 1 new path entry + 4-line defensive comment explaining the invariant

## Verification

- `grep -c "mex_stamp.m" .github/workflows/refresh-mex-binaries.yml` → 1 (in paths)
- `actionlint .github/workflows/refresh-mex-binaries.yml` → exit 0
- `on.push.paths` length → 4 (was 3)
- No other trigger semantics changed — `workflow_dispatch`, `concurrency`, job matrix untouched

## Rejected expansions (documented in PLAN.md)

- `libs/**/*.c` / `libs/**/*.h` globs — only one `mex_src/` directory exists; broader globs add no coverage
- `libs/SensorThreshold/private/mex_src/**` — no such directory; SensorThreshold binaries are built from FastSense sources

## Deviation from original plan

The user's initial ask implied a larger change (add push trigger + path filter from scratch). Investigation showed most of that was already shipped. The scope compressed from a full workflow rewrite to a single defensive path addition. SUMMARY documents the mismatch between initial mental model and actual state.
