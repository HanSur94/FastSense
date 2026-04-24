---
phase: 1004
plan: 03
subsystem: Dashboard
tags: [image-export, tests, octave, matlab-unittest, tdd, png, jpeg]
dependency_graph:
  requires: [1004-01, 1004-02]
  provides: [TestDashboardToolbarImageExport (9 methods), test_dashboard_toolbar_image_export (Octave)]
  affects:
    - tests/suite/TestDashboardToolbarImageExport.m
    - tests/test_dashboard_toolbar_image_export.m
tech_stack:
  added: []
  patterns:
    - verifyWarningFree for cancel no-op testing
    - dispatchImageExport direct call to bypass uiputfile dialog
    - function-based Octave test pattern with try/catch + nPassed/nFailed counters
key_files:
  created:
    - tests/test_dashboard_toolbar_image_export.m
  modified:
    - tests/suite/TestDashboardToolbarImageExport.m (extended from 5 to 9 methods)
decisions:
  - testCancelNoOp uses dispatchImageExport(0,'',1) directly to bypass uiputfile without mocking
  - testButtonPresent verifies position ordering using normalized x-coords (posImage > posSave and posImage < posExport)
  - Octave file skips IMG-01 (button verification) per RISK-1: Octave print() excludes uicontrols by default
  - IMG-05/06/08/09 omitted from Octave suite — MATLAB suite covers them; live timer semantics differ between runtimes
metrics:
  duration: 2min
  completed: 2026-04-15
  tasks_completed: 2
  files_changed: 2
---

# Phase 1004 Plan 03: Test Matrix Completion Summary

**One-liner:** Extended MATLAB unittest suite to 9 methods covering IMG-01/07/08/09 and created Octave parallel function-based test covering IMG-02/03/04/07.

## What Was Built

Completed the Phase 1004 test matrix by adding 4 new methods to the MATLAB suite and creating the Octave companion test file. Both test files together verify all 9 derived requirements (IMG-01 through IMG-09) for the dashboard image export feature.

## Files Modified

### tests/suite/TestDashboardToolbarImageExport.m (extended)
- **Before:** 5 test methods covering IMG-02 through IMG-06 (from Plan 01)
- **After:** 9 test methods covering IMG-01 through IMG-09

**New methods added (4):**
- `testButtonPresent` — IMG-01: verifies `hImageBtn` exists with label 'Image', tooltip 'Save dashboard as image (PNG/JPEG)', and is positioned between Save and Export in the toolbar strip
- `testCancelNoOp` — IMG-07: calls `d.Toolbar.dispatchImageExport(0, '', 1)` directly (bypassing uiputfile) and asserts no warnings thrown
- `testMultiPageActiveOnly` — IMG-08: creates 2-page dashboard, calls `switchPage(2)`, exports image, verifies file exists with bytes > 0
- `testLiveModeNoPause` — IMG-09: starts live timer, exports image, verifies `d.IsLive` remains true after export

### tests/test_dashboard_toolbar_image_export.m (new)
- Octave function-based parallel test covering 4 requirements
- Pattern: `try/catch` blocks with `nPassed`/`nFailed` counters, `assert()` for verification
- Helper: `add_dashboard_path()` calling `install()` for path setup

**Test blocks in Octave file:**
- `testExportImagePNG` (IMG-02): `d.exportImage(tmp, 'png')` then `exist(tmp,'file')==2` and `info.bytes>0`
- `testExportImageJPEG` (IMG-03): `d.exportImage(tmp, 'jpeg')` then same assertions
- `testSanitizeFilename` (IMG-04): direct `regexprep` contract check + `defaultImageFilename()` regex shape validation
- `testCancelNoOp` (IMG-07): `d.Toolbar.dispatchImageExport(0, '', 1)` must not throw

## IMG-ID → Test Coverage Map

| Req | Behavior | MATLAB Suite | Octave Suite |
|-----|----------|--------------|--------------|
| IMG-01 | hImageBtn present with correct label/tooltip/order | `testButtonPresent` | SKIPPED (RISK-1) |
| IMG-02 | PNG export writes non-empty file | `testExportImagePNG` | `testExportImagePNG` |
| IMG-03 | JPEG export writes non-empty file | `testExportImageJPEG` | `testExportImageJPEG` |
| IMG-04 | Filename sanitization regex | `testSanitizeFilename` | `testSanitizeFilename` |
| IMG-05 | Unknown format raises error ID | `testUnknownFormatError` | — |
| IMG-06 | Write failure raises error ID | `testWriteFailureErrors` | — |
| IMG-07 | Cancel (file==0) is silent no-op | `testCancelNoOp` | `testCancelNoOp` |
| IMG-08 | Multi-page active-only capture | `testMultiPageActiveOnly` | — |
| IMG-09 | Live mode: IsLive stays true after export | `testLiveModeNoPause` | — |

**Octave skip rationale for IMG-01:** Octave's `print()` excludes `uicontrol` objects by default (documented in [Octave Printing and Saving Plots docs](https://docs.octave.org/latest/Printing-and-Saving-Plots.html) — RISK-1 in RESEARCH.md). The button IS created by the same `uicontrol` call, but visual property verification is omitted from the Octave suite as Octave-specific output behavior is not guaranteed. MATLAB suite (`testButtonPresent`) provides full coverage for this requirement.

## Test Runner Commands

**MATLAB suite (9 tests):**
```bash
matlab -batch "cd tests; runtests('suite/TestDashboardToolbarImageExport.m')"
```
Expected: 9/9 passed (after Plan 02 is committed, which it is at 512268e).

**Octave suite (4 tests):**
```bash
cd /Users/hannessuhr/FastPlot && octave --no-gui --eval "cd tests; test_dashboard_toolbar_image_export()"
```
Expected: "4 passed, 0 failed." + exit 0.

## Commits

| Task | Commit | Type | Description |
|------|--------|------|-------------|
| Task 1 (MATLAB extend) | f8c8a20 | test | extend TestDashboardToolbarImageExport with IMG-01/07/08/09 |
| Task 2 (Octave create) | 0825d4c | test | add Octave parallel test_dashboard_toolbar_image_export |

## Deviations from Plan

None — plan executed exactly as written. Both files match the exact content specified in the PLAN.md action blocks.

## Known Stubs

None — all test assertions are concrete and operational.

## Self-Check: PASSED

- [x] `tests/suite/TestDashboardToolbarImageExport.m` exists with 9 test methods
- [x] Methods present: testButtonPresent, testCancelNoOp, testMultiPageActiveOnly, testLiveModeNoPause
- [x] `tests/test_dashboard_toolbar_image_export.m` exists with `function test_dashboard_toolbar_image_export()` and `function add_dashboard_path()`
- [x] Octave file contains `d.exportImage(tmp, 'png')`, `d.exportImage(tmp, 'jpeg')`, `regexprep(raw, '[/\\:*?"<>|\s]', '_')`, `d.Toolbar.dispatchImageExport(0, '', 1)`
- [x] Octave file does NOT attempt IMG-01 button verification
- [x] Commits f8c8a20 and 0825d4c exist in git log
- [x] Octave file raises `test_dashboard_toolbar_image_export:fail` error on any test failure
