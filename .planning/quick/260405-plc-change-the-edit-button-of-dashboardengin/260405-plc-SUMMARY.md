---
phase: quick
plan: 260405-plc
subsystem: Dashboard
tags: [toolbar, editor, ux, DashboardToolbar]
dependency_graph:
  requires: []
  provides: [Edit button opens source file via MATLAB edit()]
  affects: [DashboardToolbar, DashboardBuilder]
tech_stack:
  added: []
  patterns: [warndlg for missing file path, MATLAB edit() command]
key_files:
  modified:
    - libs/Dashboard/DashboardToolbar.m
decisions:
  - Used warndlg for both empty FilePath and non-existent file cases to give user actionable feedback
  - Removed Builder property entirely — DashboardBuilder no longer referenced from DashboardToolbar
metrics:
  duration: 5min
  completed: 2026-04-05
  tasks: 1
  files: 1
---

# Quick Task 260405-plc: Change Edit Button to Open Source File in MATLAB Editor Summary

**One-liner:** Edit button in DashboardToolbar now calls MATLAB `edit()` on `Engine.FilePath` instead of toggling DashboardBuilder edit mode.

## What Was Done

Replaced the `onEdit` method in `DashboardToolbar.m` to open the dashboard's source `.m` or `.json` file directly in the MATLAB editor, replacing the old behavior that toggled the in-GUI DashboardBuilder edit mode.

Removed:
- `Builder = []` property
- All `DashboardBuilder` instantiation and toggle logic
- `hEditBtn` String toggle ('Edit' / 'Done')
- `hLiveBtn` enable/disable toggling during edit mode

Added:
- `edit(fp)` call when `Engine.FilePath` is valid and file exists
- `warndlg` when `FilePath` is empty — no source file associated
- `warndlg` when file path is set but file does not exist on disk

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Change Edit button to open source file in MATLAB editor | 5188b04 | libs/Dashboard/DashboardToolbar.m |

## Verification

- `grep 'DashboardBuilder' libs/Dashboard/DashboardToolbar.m` — no matches (PASS)
- `grep 'edit(fp)' libs/Dashboard/DashboardToolbar.m` — match found (PASS)
- `grep 'warndlg' libs/Dashboard/DashboardToolbar.m` — both warning cases present (PASS)

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- libs/Dashboard/DashboardToolbar.m: modified and committed at 5188b04
- Commit 5188b04 confirmed in git log
