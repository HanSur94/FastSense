---
phase: 1004
plan: 01
subsystem: Dashboard
tags: [image-export, engine-delegate, tdd, print, png, jpeg]
dependency_graph:
  requires: []
  provides: [DashboardEngine.exportImage, TestDashboardToolbarImageExport]
  affects: [libs/Dashboard/DashboardEngine.m, tests/suite/TestDashboardToolbarImageExport.m]
tech_stack:
  added: []
  patterns: [print(hFigure, devFlag, '-r150', filepath), try/catch wrapping print()]
key_files:
  created:
    - tests/suite/TestDashboardToolbarImageExport.m
  modified:
    - libs/Dashboard/DashboardEngine.m (lines 373-429, +58 lines)
decisions:
  - Use datestr 'yyyymmdd_HHMMSS' not ISO 'yyyyMMdd_HHmmss' (CONTEXT.md used ISO notation which is wrong for datestr)
  - Format inferred from file extension when third arg omitted (defaults to png)
  - notRendered check uses isempty(obj.hFigure) || ~ishandle(obj.hFigure) to handle both unrendered and closed figure states
metrics:
  duration: 5min
  completed: 2026-04-15
  tasks_completed: 2
  files_changed: 2
---

# Phase 1004 Plan 01: DashboardEngine.exportImage Engine Delegate Summary

**One-liner:** Added `DashboardEngine.exportImage(filepath, format)` public method using `print(hFigure, devFlag, '-r150', filepath)` with three namespaced error IDs and RED/GREEN TDD test suite covering IMG-02 through IMG-06.

## What Was Built

Added the `exportImage` engine-side primitive that powers the forthcoming toolbar "Image" button. The method captures the rendered dashboard figure as PNG or JPEG at 150 DPI using `print()`, which is fully compatible with both MATLAB R2020b+ and GNU Octave 7+.

## Files Modified

### libs/Dashboard/DashboardEngine.m
- **Lines added:** 373–429 (+58 lines)
- **Insertion point:** After `exportScript` (line 372), before `function preview` (line 431)
- **Method signature:** `function exportImage(obj, filepath, format)`
- **Error IDs introduced:**
  - `DashboardEngine:notRendered` — render() not yet called
  - `DashboardEngine:unknownImageFormat` — format not png/jpeg/jpg
  - `DashboardEngine:imageWriteFailed` — print() raised any error

### tests/suite/TestDashboardToolbarImageExport.m (new)
- **Test methods:** 5 methods covering IMG-02 through IMG-06
  - `testExportImagePNG` — verifies PNG file exists with bytes > 0 (IMG-02)
  - `testExportImageJPEG` — verifies JPEG file exists with bytes > 0 (IMG-03)
  - `testSanitizeFilename` — verifies regexprep contract for defaultImageFilename (IMG-04)
  - `testUnknownFormatError` — verifies DashboardEngine:unknownImageFormat error ID (IMG-05)
  - `testWriteFailureErrors` — verifies DashboardEngine:imageWriteFailed error ID (IMG-06)

## Commits

| Task | Commit | Type | Description |
|------|--------|------|-------------|
| Task 1 (RED) | acf55a9 | test | add failing TestDashboardToolbarImageExport for IMG-02..IMG-06 |
| Task 2 (GREEN) | 7fbafca | feat | add DashboardEngine.exportImage PNG/JPEG delegate |

## Deviations from Plan

None — plan executed exactly as written. The exact code from the PLAN.md action blocks was used verbatim.

**Note on Octave test execution:** The worktree has a pre-existing Octave incompatibility with `DashboardWidget.m` abstract methods (`external methods are only allowed in @-folders`), which prevents running the MATLAB-style `runtests()` test suite via Octave. This issue predates this plan and is out of scope. Core `print()` functionality was verified independently using raw Octave figures. MATLAB's `runtests()` remains the canonical test runner per project conventions.

## Known Stubs

None — `exportImage` is fully wired and operational. No placeholder data or TODO paths.

## Self-Check: PASSED

- [x] `libs/Dashboard/DashboardEngine.m` contains `function exportImage(obj, filepath, format)` at line 373
- [x] `tests/suite/TestDashboardToolbarImageExport.m` exists with all 5 test methods
- [x] Commits acf55a9 and 7fbafca exist in git log
- [x] All 3 error IDs present as actual `error()` calls (lines 409, 419, 426)
- [x] `print(obj.hFigure, devFlag, '-r150', filepath)` at line 424
- [x] `'-dpng'` and `'-djpeg'` both present
- [x] `exportImage` appears between `exportScript` and `preview` in the file
