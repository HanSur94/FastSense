---
phase: 999.3-graph-data-export-mat-csv
plan: "01"
subsystem: FastSense
tags: [export, csv, mat, file-io, octave-compat]
dependency_graph:
  requires: []
  provides: [FastSense.exportData, CSV export, MAT export, export unit tests]
  affects: [libs/FastSense/FastSense.m, tests/test_toolbar.m]
tech_stack:
  added: []
  patterns: [fopen/fprintf/fclose for Octave-safe CSV, save() for MAT export, union/ismember for NaN-fill]
key_files:
  created: []
  modified:
    - libs/FastSense/FastSense.m
    - tests/test_toolbar.m
decisions:
  - "No render() required before exportData() — buildExportStruct_ accesses raw Lines/Thresholds directly"
  - "testExportCSVDatetime guarded with ~exist('OCTAVE_VERSION') since datetime is MATLAB-only"
  - "testExportNoLines does not call render() — exportData guards independently via buildExportStruct_"
metrics:
  duration: "3 minutes"
  completed_date: "2026-04-05"
  tasks_completed: 2
  files_modified: 2
requirements:
  - EXPORT-01
  - EXPORT-02
  - EXPORT-03
  - EXPORT-04
  - EXPORT-06
---

# Phase 999.3 Plan 01: exportData Method + Tests Summary

**One-liner:** `FastSense.exportData(filepath, format)` writes full-resolution CSV (union-X NaN-fill, datetime dual-column) and MAT (lines/thresholds struct arrays) via Octave-safe fopen/fprintf/save.

## Tasks Completed

| Task | Name | Commit | Files Modified |
|------|------|--------|----------------|
| 1 | Add exportData method + private helpers to FastSense.m | 307d97e | libs/FastSense/FastSense.m |
| 2 | Add export data tests to test_toolbar.m | 12e661f | tests/test_toolbar.m |

## What Was Built

### Task 1: exportData public method + private helpers

Added to `libs/FastSense/FastSense.m`:

- **`exportData(obj, filepath, format)`** (public) — validates format ('csv' or 'mat'), dispatches to private helpers
- **`buildExportStruct_(obj)`** (private) — extracts Lines/Thresholds into export struct; guards empty plot with `FastSense:exportData:noLines`
- **`writeExportCSV_(obj, filepath, S)`** (private) — union X, NaN-fill Y matrix, fopen/fprintf CSV; datetime mode adds `time_datenum`+`time_iso8601` columns; threshold comment lines appended
- **`writeExportMAT_(obj, filepath, S)`** (private) — save() with lines/thresholds struct arrays; `exported_datetime=true` flag when IsDatetime

### Task 2: 5 new export tests in test_toolbar.m

- **testExportCSV** (EXPORT-01): verifies CSV created with 'time' and DisplayName in header
- **testExportMAT** (EXPORT-02): verifies .mat with `S.lines`, `S.thresholds`, correct Name/Value/Direction
- **testExportCSVMismatchedX** (EXPORT-03): verifies 4-row union, NaN in column B at x=1 and column A at x=4
- **testExportCSVDatetime** (EXPORT-04): MATLAB-only guard, verifies `time_datenum`/`time_iso8601` headers
- **testExportNoLines** (EXPORT-06): verifies `FastSense:exportData:noLines` error without needing render()
- Test count updated from 14 to 19

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| No render() before exportData | exportData accesses `obj.Lines` directly; render() throws error when no lines present |
| OCTAVE_VERSION guard on datetime test | `datetime()` requires datatypes package not installed in Octave base |
| testExportNoLines skips render() | render() already errors on empty Lines; test should validate exportData's own guard |
| fopen/fprintf for CSV | Octave-safe; writematrix/writetable are MATLAB-only per RESEARCH.md |

## Verification

```
grep 'function exportData' libs/FastSense/FastSense.m
# -> 2136:        function exportData(obj, filepath, format)

grep 'FastSense:exportData:noLines' libs/FastSense/FastSense.m
# -> found

grep 'writetable\|writematrix' libs/FastSense/FastSense.m
# -> 0 matches

octave --eval "install(); test_toolbar"
# -> All 19 toolbar tests passed.
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] testExportCSVDatetime uses datetime() unavailable on Octave**

- **Found during:** Task 2 verification
- **Issue:** `datetime(2024, 1, 1) + hours(0:2)` fails on Octave 11.1.0 which lacks the datatypes package
- **Fix:** Wrapped test in `if ~exist('OCTAVE_VERSION', 'builtin')` guard; test still runs fully in MATLAB
- **Files modified:** tests/test_toolbar.m
- **Commit:** 12e661f

**2. [Rule 1 - Bug] testExportNoLines called render() before exportData()**

- **Found during:** Task 2 verification
- **Issue:** `fp.render()` throws `FastSense:noLines` error when no lines are added, so the test crashed before reaching exportData
- **Fix:** Removed `fp.render()` call and `close(fp.hFigure)` — exportData guards independently via buildExportStruct_; no figure handle needed
- **Files modified:** tests/test_toolbar.m
- **Commit:** 12e661f

## Self-Check: PASSED

- `libs/FastSense/FastSense.m` contains `function exportData` — FOUND at line 2136
- `libs/FastSense/FastSense.m` contains `buildExportStruct_` — FOUND
- `libs/FastSense/FastSense.m` contains `writeExportCSV_` — FOUND
- `libs/FastSense/FastSense.m` contains `writeExportMAT_` — FOUND
- `tests/test_toolbar.m` contains `testExportCSV` — FOUND
- `tests/test_toolbar.m` contains `All 19 toolbar tests passed` — FOUND
- Commits 307d97e and 12e661f — FOUND in git log
- Octave test suite passes — CONFIRMED
