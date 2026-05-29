---
phase: 999.3-graph-data-export-mat-csv
plan: "02"
subsystem: FastSenseToolbar
tags: [export, toolbar, icon, pixel-art, octave-compat, ui]
dependency_graph:
  requires: [FastSense.exportData (Plan 01)]
  provides: [FastSenseToolbar.exportData, FastSenseToolbar.onExportData, exportdata icon, Export Data toolbar button]
  affects: [libs/FastSense/FastSenseToolbar.m, tests/test_toolbar.m]
tech_stack:
  added: []
  patterns: [uiputfile with cell array filters for csv/mat, regexp for extension guard (Octave-safe endsWith alternative), dual-API pattern matching exportPNG]
key_files:
  created: []
  modified:
    - libs/FastSense/FastSenseToolbar.m
    - tests/test_toolbar.m
decisions:
  - "exportData dual-API mirrors exportPNG: no-arg opens dialog, with-arg saves directly (extension determines format)"
  - "Used regexp(fname, '\\.csv$', 'once') instead of endsWith() — endsWith not available in Octave 7"
  - "onExportData uses uiputfile idx to determine format rather than re-parsing extension — cleaner intent"
  - "exportdata icon uses down-arrow-into-grid pixel art: 16x16x3, drawn with row/column repmat pattern"
metrics:
  duration: "2 minutes"
  completed_date: "2026-04-05"
  tasks_completed: 2
  files_modified: 2
requirements:
  - EXPORT-05
---

# Phase 999.3 Plan 02: Export Data Toolbar Button Summary

**One-liner:** Export Data toolbar button with uiputfile csv/mat dialog, dual-API exportData/onExportData callbacks, and 'exportdata' pixel-art icon wired to FastSense.exportData() from Plan 01.

## Tasks Completed

| Task | Name | Commit | Files Modified |
|------|------|--------|----------------|
| 1 | Add Export Data button, callbacks, and icon to FastSenseToolbar.m | 9cf997f | libs/FastSense/FastSenseToolbar.m |
| 2 | Update test_toolbar.m button count and icon test | b35e34e | tests/test_toolbar.m |

## What Was Built

### Task 1: Export Data button + callbacks + icon in FastSenseToolbar.m

Added to `libs/FastSense/FastSenseToolbar.m`:

- **`exportData(obj, filepath)`** (public) — dual-API: no-arg opens dialog via onExportData(), with-arg determines format from extension and delegates to FastSense.exportData(); uses getActiveTarget() with FastSenses{1} fallback
- **`onExportData(obj)`** (private) — opens uiputfile with `{'*.csv'; '*.mat'}` filter; uses idx (1=csv, 2=mat) to determine format; uses regexp for Octave-safe extension check; delegates to FastSense.exportData()
- **Export Data uipushtool button** — inserted in createToolbar after Export PNG button; uses makeIcon('exportdata') and onExportData callback
- **`case 'exportdata'`** in makeIcon — 16x16x3 pixel-art icon: down-arrow shaft (rows 3-9, col 8) with arrowhead (rows 8-9) pointing into a grid base (rows 10-13, cols 4/8/12)
- **Updated initIcons names** — 'exportdata' added between 'export' and 'refresh' in the cache pre-warm list
- **Updated class header comment** — 'Export Data' line added after 'Export PNG'

### Task 2: Test updates in test_toolbar.m

- **Button count assertion** — changed from `numel(children) == 11` to `numel(children) == 12`
- **testAllIconNames list** — added 'exportdata' between 'export' and 'violations'
- Test count remains 19 (no new tests added; test count was updated in Plan 01)

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| regexp for extension guard | `endsWith()` not available in Octave 7; `regexp(fname, '\.csv$', 'once')` is Octave-safe |
| uiputfile idx over re-parsing | Use dialog's filter index for format — cleaner than re-parsing extension after dialog |
| getActiveTarget + FastSenses{1} fallback | Consistent with existing toolbar design; always has a valid fp to delegate to |
| exportdata icon: down-arrow into grid | Distinct from camera (export PNG) — visually conveys "data going into grid/table" |

## Verification

```
grep 'onExportData' libs/FastSense/FastSenseToolbar.m
# -> 4 matches (call, button callback, function def, uiputfile line)

grep 'Export Data' libs/FastSense/FastSenseToolbar.m
# -> 3 matches (header comment, tooltip, dialog title)

grep 'exportdata' libs/FastSense/FastSenseToolbar.m
# -> 3 matches (button CData, case, initIcons)

octave --eval "install(); test_toolbar"
# -> All 19 toolbar tests passed.
```

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- `libs/FastSense/FastSenseToolbar.m` contains `function exportData(obj, filepath)` — FOUND at line 146
- `libs/FastSense/FastSenseToolbar.m` contains `function onExportData(obj)` — FOUND at line 954
- `libs/FastSense/FastSenseToolbar.m` contains `case 'exportdata'` — FOUND at line 1201
- `libs/FastSense/FastSenseToolbar.m` contains `'exportdata'` in initIcons names — FOUND at line 1312
- `libs/FastSense/FastSenseToolbar.m` contains `uiputfile({'*.csv'; '*.mat'}, 'Export Data')` — FOUND
- `libs/FastSense/FastSenseToolbar.m` contains `fp.exportData(fullpath, 'csv')` in onExportData — FOUND
- `libs/FastSense/FastSenseToolbar.m` contains `'TooltipString', 'Export Data'` — FOUND
- `tests/test_toolbar.m` contains `numel(children) == 12` — FOUND
- `tests/test_toolbar.m` contains `'exportdata'` in icon names list — FOUND
- Commits 9cf997f and b35e34e — FOUND in git log
- Octave test suite: All 19 toolbar tests passed — CONFIRMED
