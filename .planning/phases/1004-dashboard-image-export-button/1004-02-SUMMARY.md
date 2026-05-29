---
phase: 1004
plan: 02
subsystem: Dashboard
tags: [image-export, toolbar, uiputfile, png, jpeg, sanitization]
dependency_graph:
  requires: [DashboardEngine.exportImage (from 1004-01)]
  provides: [DashboardToolbar.hImageBtn, DashboardToolbar.onImage, DashboardToolbar.dispatchImageExport, DashboardToolbar.defaultImageFilename]
  affects: [libs/Dashboard/DashboardToolbar.m]
tech_stack:
  added: []
  patterns: [uiputfile 3-output form for filter-index dispatch, regexprep filename sanitization, try/catch + warndlg error surfacing]
key_files:
  created: []
  modified:
    - libs/Dashboard/DashboardToolbar.m (lines 4, 17, 74-81, 167-216, +62 lines total)
decisions:
  - Button inserted between Export and Save in right-to-left layout: Export declared first (rightmost), Image second, Save third
  - dispatchImageExport extracted as separate method to allow unit testing cancel-no-op (IMG-07) without a real uiputfile dialog
  - datestr format 'yyyymmdd_HHMMSS' used (not ISO 'yyyyMMdd_HHmmss' from CONTEXT.md — CONTEXT notation is wrong for datestr)
  - Empty Engine.Name falls back to 'Dashboard' in defaultImageFilename to avoid leading-underscore filenames
metrics:
  duration: 8min
  completed: 2026-04-15
  tasks_completed: 2
  files_changed: 1
---

# Phase 1004 Plan 02: DashboardToolbar Image Button Summary

**One-liner:** Added "Image" toolbar button to DashboardToolbar between Save and Export, wired via uiputfile PNG/JPEG filter dispatch to Engine.exportImage with cancel no-op, try/catch warndlg error surfacing, and regexprep+datestr default filename generation.

## What Was Built

Added the user-facing Image export button to `DashboardToolbar` as pure UI plumbing over the `DashboardEngine.exportImage` delegate from Plan 01. Users now see an "Image" button in the toolbar between Save and Export; clicking it opens a save dialog with PNG and JPEG filters. Cancel is a silent no-op. Engine errors surface via warndlg.

## Files Modified

### libs/Dashboard/DashboardToolbar.m
- **Line 4:** Class header comment updated — "Image" listed between "Save" and "Export"
- **Line 17:** `hImageBtn = []` property added in `properties (SetAccess = private)` block after `hExportBtn`
- **Lines 74-81:** Image button uicontrol inserted between Export (line 67) and Save (line 84) in right-to-left layout
  - `'String', 'Image'`
  - `'TooltipString', 'Save dashboard as image (PNG/JPEG)'`
  - `'Callback', @(~,~) obj.onImage()`
- **Lines 167-216:** Three new methods inserted after `onExport` and before `onInfo`:
  - `onImage(obj)` — opens uiputfile, delegates to dispatchImageExport
  - `dispatchImageExport(obj, file, path, idx)` — post-dialog dispatcher; silent no-op on cancel (file==0 or empty); fmt='png' for idx==1, fmt='jpeg' for idx==2
  - `defaultImageFilename(obj)` — returns `{safeName}_{yyyymmdd_HHMMSS}.png` using regexprep sanitization

## Button Order Verification

File declaration order (right-to-left = rightmost declared first):
1. `obj.hExportBtn` — line 67 (rightmost in strip)
2. `obj.hImageBtn` — line 75 (second from right)
3. `obj.hSaveBtn` — line 84 (third from right)

Visual left-to-right strip: `... Sync | Live | Edit | Save | Image | Export`

## Key Implementation Details

### datestr Format Correction
CONTEXT.md specified `yyyyMMdd_HHmmss` (ISO/datetime notation) — this is WRONG for `datestr()`. In datestr, lowercase `mm` = minutes and `MM` is not a valid token for month. The correct format is **`yyyymmdd_HHMMSS`** matching the in-codebase precedent at `libs/EventDetection/generateEventSnapshot.m:28`.

### Filename Sanitization
```matlab
safeName = regexprep(rawName, '[/\\:*?"<>|\s]', '_');
```
Double-backslash for `\` because MATLAB regex strings require escaping. Covers all filesystem-unsafe chars plus whitespace.

### Cancel Guard
```matlab
if isequal(file, 0) || isempty(file)
    return;  % user cancelled — silent no-op (IMG-07)
end
```
Uses `isequal` (not `==`) for Octave compatibility when file is a char string vs numeric 0.

## Commits

| Task | Commit | Type | Description |
|------|--------|------|-------------|
| Task 1 | 512268e | feat | add hImageBtn property and Image button uicontrol to DashboardToolbar |
| Task 2 | 059c21c | feat | add onImage/dispatchImageExport/defaultImageFilename methods to DashboardToolbar |

## Deviations from Plan

None — plan executed exactly as written. All three edits for Task 1 and three method insertions for Task 2 followed the plan action blocks verbatim.

## Known Stubs

None — Image button is fully wired end-to-end. `onImage` → `dispatchImageExport` → `Engine.exportImage` → `print(hFigure, devFlag, '-r150', filepath)`.

## Self-Check: PASSED

- [x] `libs/Dashboard/DashboardToolbar.m` line 4 lists "Image" between "Save" and "Export"
- [x] `hImageBtn = []` at line 17 in properties block
- [x] `obj.hImageBtn = uicontrol(` at line 75
- [x] `'String', 'Image'` at line 80
- [x] `'TooltipString', 'Save dashboard as image (PNG/JPEG)'` at line 81
- [x] `function onImage(obj)` at line 167
- [x] `function dispatchImageExport(obj, file, path, idx)` at line 181
- [x] `function fname = defaultImageFilename(obj)` at line 201
- [x] `datestr(now, 'yyyymmdd_HHMMSS')` at line 214
- [x] `regexprep(rawName, '[/\\:*?"<>|\s]', '_')` at line 213
- [x] `obj.Engine.exportImage(fullfile(path, file), fmt)` at line 195
- [x] `warndlg(ME.message, 'Image Export')` at line 197
- [x] `if isequal(file, 0) || isempty(file)` at line 186
- [x] `{'*.png', 'PNG image (*.png)';` and `'*.jpg', 'JPEG image (*.jpg)'}` in filter spec
- [x] hExportBtn (line 67) < hImageBtn (line 75) < hSaveBtn (line 84)
- [x] Commits 512268e and 059c21c exist in git log
- [x] No line exceeds 160 characters
