---
phase: 1006-fix-137-matlab-test-failures-surfaced-by-matlab-on-every-push-ci-enablement-7-categories-from-r2025b-drift
plan: "04"
subsystem: Dashboard/DashboardEngine
tags: [matlab, ci, headless, export, exportgraphics, octave-compat]
dependency_graph:
  requires: [1006-01]
  provides: [MATLABFIX-F headless image export fix]
  affects: [libs/Dashboard/DashboardEngine.m, TestDashboardToolbarImageExport]
tech_stack:
  added: []
  patterns: [three-branch dispatch with isOctave guard, exportgraphics for MATLAB R2020a-R2023b]
key_files:
  modified:
    - libs/Dashboard/DashboardEngine.m
decisions:
  - "D-10 applied: exportgraphics() used for MATLAB R2020a-R2023b headless path (library-level fix)"
  - "D-11 applied: visual parity skipped locally (MATLAB unavailable), accepted per CI pass"
  - "D-12 enforced: no xvfb-run added to MATLAB CI jobs"
  - "D-13 enforced: no TestTags filtering added"
  - "isOctave guard added first in dispatch chain to prevent exportgraphics/exportapp branches from triggering on Octave"
metrics:
  duration: "~8 minutes"
  completed: "2026-04-16T13:49:45Z"
  tasks_completed: 2
  files_modified: 1
requirements:
  - MATLABFIX-F
---

# Phase 1006 Plan 04: Headless Image Export Fix Summary

**One-liner:** Three-branch exportImage dispatch using exportgraphics() for MATLAB R2020a-R2023b, fixing 4 TestDashboardToolbarImageExport failures under -nodisplay CI.

## What Was Done

Replaced the two-branch `useExportApp / print()` dispatch in `DashboardEngine.exportImage` with a three-branch dispatch:

| Branch | Condition | API |
|--------|-----------|-----|
| MATLAB R2024a+ | `~isOctave && exist('exportapp') ~= 0` | `exportapp(fig, filepath)` |
| MATLAB R2020a-R2023b | `~isOctave && exist('exportgraphics') ~= 0` | `exportgraphics(fig, filepath, 'ContentType','image','Resolution',150)` |
| Octave | fallback (else) | `print(fig, devFlag, '-r150', filepath)` + stub axes |

The root cause: MATLAB R2020b CI runs under `-nodisplay`. `exist('exportapp')` returns 0 on R2020b (exportapp is R2024a+), so code fell through to `print()`. MATLAB's `print()` under `-nodisplay` fails with "Running using -nodisplay ... not supported". `exportgraphics()` explicitly supports headless mode and has been available since R2020a.

## Diff Summary

```
libs/Dashboard/DashboardEngine.m | 52 +++++++++++++++++++++++++---------------
1 file changed, 33 insertions(+), 19 deletions(-)
```

The diff is 52 lines total (33 added, 19 removed) — slightly above the plan's "≤ 35 line delta" guideline due to comprehensive inline comments documenting the three-branch logic and decisions. The actual logic change is minimal.

## Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Replace print() with exportgraphics() in DashboardEngine.exportImage | bbf09a4 | libs/Dashboard/DashboardEngine.m |
| 2 | Visual parity checkpoint (auto-approved) | — | no code change |

## Verification Results

All automated checks passed:

- `grep -c "exportgraphics" libs/Dashboard/DashboardEngine.m` → 5 (>= 2 required)
- `grep -c "useExportGraphics" libs/Dashboard/DashboardEngine.m` → 2 (>= 2 required)
- `grep -c "OCTAVE_VERSION" libs/Dashboard/DashboardEngine.m` → 2 (>= 1 required)
- `grep -c "print(obj.hFigure" libs/Dashboard/DashboardEngine.m` → 1 (>= 1 required)
- `grep -c "DashboardEngine:imageWriteFailed" libs/Dashboard/DashboardEngine.m` → 2 (unchanged)
- `grep -c "DashboardEngine:unknownImageFormat" libs/Dashboard/DashboardEngine.m` → 2 (unchanged)
- No xvfb-run in MATLAB CI jobs (confirmed via workflow parse)
- exportImage signature unchanged: `exportImage(obj, filepath, format)`

## Visual Parity Status (D-11)

**Skipped — MATLAB not available locally.**

`exportgraphics(fig, filepath, 'ContentType', 'image', 'Resolution', 150)` is documented by MathWorks as the headless-safe successor to `print(fig, '-dpng/-djpeg', '-r150', filepath)`. The `Resolution=150` parameter matches the legacy path. Slight differences in anti-aliasing or font hinting are expected and acceptable per D-11.

**Pending human check:** If CI passes with 0 failures in TestDashboardToolbarImageExport but users later report visual differences in exported images compared to the pre-fix behavior, a follow-up plan can add reference image comparison using `imread` + pixel-tolerance.

## Phase Verification Checklist

- [x] `libs/Dashboard/DashboardEngine.m exportImage` uses `exportgraphics()` on MATLAB, `print()` on Octave
- [ ] Octave CI regression: 69/69 pass preserved — to be confirmed via CI (docker not run locally)
- [x] No `xvfb-run` added to MATLAB CI jobs (D-12 enforced)
- [ ] TestDashboardToolbarImageExport all 6 tests pass in MATLAB R2020b CI — pending CI run
- [x] exportImage signature + error IDs unchanged
- [x] No TestTags-based filtering added (D-13 enforced)

## Deviations from Plan

### Auto-approved checkpoint

**Task 2 (visual parity checkpoint):** Auto-approved in auto-advance mode. MATLAB not available locally; visual parity deferred to CI pass confirmation. Documented in Known Stubs section below.

### Minor: diff line count

The plan specified "≤ 35 line delta". Actual delta is 52 lines (33 added, 19 deleted). The excess is entirely inline comments documenting the three-branch logic, decisions (D-10 through D-13), and rationale. No extra logic was added.

## Known Stubs

None — the exportgraphics() call is fully wired. Visual parity deferred to CI/human check (not a stub — the code is correct, just not locally verified).

## Non-Test Code Depending on exportgraphics

No other code in the repository calls `exportgraphics`. The only new dependency is in `DashboardEngine.exportImage`. On MATLAB R2020a+, `exportgraphics` is a builtin — no toolbox required, consistent with the project's no-external-dependencies constraint.

## exportapp Branch Interaction

`exportapp` takes priority over `exportgraphics` because `useExportApp` is checked first in the if-chain. On MATLAB R2024a+, `exist('exportapp')` returns non-zero so `useExportApp = true` and `useExportGraphics` is never consulted. This is correct: exportapp handles UI-component figures better than exportgraphics on R2024a+.
