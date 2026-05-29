---
phase: 01-dashboard-engine-code-review-fixes
plan: 03
subsystem: Dashboard/Serialization
tags: [serialization, bug-fix, tdd, refactor]
dependency_graph:
  requires: []
  provides: [FIX-06, FIX-07, FIX-08]
  affects: [libs/Dashboard/DashboardSerializer.m, tests/suite/TestDashboardBugFixes.m]
tech_stack:
  added: []
  patterns: [shared-helper, private-static-method, tdd-red-green]
key_files:
  created: []
  modified:
    - libs/Dashboard/DashboardSerializer.m
    - tests/suite/TestDashboardBugFixes.m
decisions:
  - "linesForWidget uses indent parameter so exportScript (no indent) and exportScriptPages (4-space indent) can share one implementation"
  - "save() and emitChildWidget() left unchanged — they use constructor-style widget creation for function-file generation, not d.addWidget() style"
metrics:
  duration: "4 minutes"
  completed_date: "2026-04-03"
  tasks_completed: 2
  files_modified: 2
---

# Phase 01 Plan 03: Serialization Robustness Fixes Summary

**One-liner:** fopen guard in loadJSON (FIX-06), exportScriptPages fidelity via shared linesForWidget helper consolidating widget dispatch (FIX-07 + FIX-08).

## What Was Done

Fixed two serialization robustness bugs and consolidated duplicated dispatch logic in DashboardSerializer.

### FIX-06: loadJSON fopen guard

`loadJSON()` previously called `fread()` on an invalid file descriptor when the file did not exist, producing a cryptic MATLAB error. Added `if fid == -1` guard immediately after `fopen()` that throws `DashboardSerializer:fileNotFound` with a descriptive message, consistent with the existing pattern in `saveJSON()` and `exportScript()`.

### FIX-07: exportScriptPages widget fidelity

`exportScriptPages()` had a stripped-down inline switch that only emitted `Title` + `Position`, dropping sensor bindings (`SensorRegistry.get`), number/gauge `Units`, gauge `Range`, and source callbacks. Fixed by delegating to the new `linesForWidget` helper (FIX-08).

### FIX-08: Shared linesForWidget helper

Extracted the per-widget code generation from `exportScript()` into a new `methods (Static, Access = private)` method `linesForWidget(ws, pos, indent)`. The `indent` parameter (empty string or `'    '`) allows both callers to reuse the same dispatch table. Both `exportScript()` and `exportScriptPages()` now call `linesForWidget`. The `save()` method and `emitChildWidget()` were intentionally left unchanged as they serve constructor-style file generation (not `d.addWidget()` style).

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add failing regression tests (TDD RED) | c99c1b4 | tests/suite/TestDashboardBugFixes.m |
| 2 | Fix loadJSON + shared linesForWidget (GREEN) | 85a58d8 | libs/Dashboard/DashboardSerializer.m |

## Deviations from Plan

None — plan executed exactly as written.

## Test Results

All three new regression tests pass:
- `testLoadJSONFileNotFound` — verifies `DashboardSerializer:fileNotFound` error
- `testExportScriptPagesPreservesSensorBinding` — verifies `SensorRegistry.get` in output
- `testExportScriptPagesPreservesNumberUnits` — verifies `'Units'` in number widget output

Pre-existing test failures (testKpiWidgetThemeOverrideMerge, testAddWidgetDefaultTitle, testExitEditModeAfterFigureClose, testSensorListenersMultiPage) are out of scope for this plan and tracked separately.

## Known Stubs

None.

## Self-Check: PASSED
