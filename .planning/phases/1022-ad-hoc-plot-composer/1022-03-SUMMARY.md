---
phase: 1022-ad-hoc-plot-composer
plan: "03"
subsystem: FastSenseCompanion / Testing
tags: [testing, adhoc-plot, regression-harness, fixtures, integration-tests]
dependency_graph:
  requires:
    - 1022-01 (openAdHocPlot helper — unit under test)
    - 1022-02 (onOpenAdHocPlotRequested_ listener wiring — integration target)
  provides:
    - MockPlottableTag fixture (controllable getXY for unit and integration tests)
    - runOpenAdHocPlotTests unit runner (7 branches covering all openAdHocPlot paths)
    - test_companion_open_ad_hoc_plot delegating entry point
    - TestFastSenseCompanion ADHOC end-to-end tests (5 methods covering ADHOC-02..05)
  affects:
    - tests/suite/TestFastSenseCompanion.m (additive augmentation)
tech_stack:
  added: []
  patterns:
    - sibling-folder private/ test runner (same as Phase 1020)
    - MockPlottableTag fixture with switchable Behavior property
    - struct(app) hack for accessing private UI handles in tests
    - setdiff(postFigs, preFigs) pattern for spawned figure detection
key_files:
  created:
    - tests/suite/MockPlottableTag.m
    - libs/FastSenseCompanion/private/runOpenAdHocPlotTests.m
    - tests/test_companion_open_ad_hoc_plot.m
  modified:
    - tests/suite/TestFastSenseCompanion.m
decisions:
  - MockPlottableTag delegates to getXY@SensorTag for Default behavior (confirmed SensorTag.getXY is public)
  - findCompanionAdHocFigure_ returns value via output argument (MATLAB convention) rather than void; grep pattern in plan was incorrect (function has return value prefix)
  - runOpenAdHocPlotTests uses matlab.ui.Figure.empty as initial spawned array for type consistency
  - driveSelectAndPlot_ suppresses MATLAB:structOnObject warning via onCleanup-guarded state restoration
metrics:
  duration_seconds: 341
  completed_date: "2026-04-30"
  tasks_completed: 3
  tasks_total: 3
  files_created: 3
  files_modified: 1
---

# Phase 1022 Plan 03: ADHOC Regression Harness Summary

Two-layer regression harness for ad-hoc plot composer covering ADHOC-01..05: MockPlottableTag fixture + private runner unit tests + 5 ADHOC end-to-end integration tests in TestFastSenseCompanion.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | MockPlottableTag fixture | 5d5724d | tests/suite/MockPlottableTag.m |
| 2 | runOpenAdHocPlotTests + delegating entry point | b8d9086 | libs/FastSenseCompanion/private/runOpenAdHocPlotTests.m, tests/test_companion_open_ad_hoc_plot.m |
| 3 | Augment TestFastSenseCompanion with ADHOC tests | 52d8f21 | tests/suite/TestFastSenseCompanion.m |

## Deliverables

### tests/suite/MockPlottableTag.m
SensorTag subclass with a public `Behavior` property switching `getXY` between three modes:
- `Default`: delegates to `getXY@SensorTag(obj)` (returns stored X/Y)
- `ReturnEmpty`: returns `([], [])` triggering the "no data" skip path
- `Throw`: errors with `MockPlottableTag:intentionalGetXYError` triggering the failure-tolerance path

Used by both the unit runner (Task 2) and the integration tests (Task 3).

### libs/FastSenseCompanion/private/runOpenAdHocPlotTests.m
Function-based test runner living in `private/` for MATLAB private-folder visibility to `openAdHocPlot`. Seven branches:
- T1: invalid mode `'Foo'` — expects `FastSenseCompanion:invalidPlotMode`
- T2: too-few-tags (1 tag) — expects `FastSenseCompanion:invalidPlotMode`
- T3: Overlay happy path — 2 default tags, asserts classical figure, empty skipped, Visible=on
- T4: LinkedGrid happy path — 4 default tags, asserts classical figure handle
- T5: Partial-skip — 1 throwing + 2 default, asserts figure spawns and skipped has 1 entry with bad tag name
- T6: All-fail — 2 throwing tags, expects `FastSenseCompanion:plotSpawnFailed`
- T7: Empty-data tag — 1 ReturnEmpty + 2 default, asserts figure spawns and skipped entry contains "no data"

All spawned figures tracked in `spawned` array and closed via `onCleanup`. No `gcf`/`gca`/`uiaxes`/`timer(`.

### tests/test_companion_open_ad_hoc_plot.m
Thin delegating wrapper with Octave skip guard. Delegates to `runOpenAdHocPlotTests()`. <= 22 lines.

### tests/suite/TestFastSenseCompanion.m (augmented)
Five new `methods (Test)` ADHOC methods + private `methods (Access = private)` block with three helpers.

**Test methods:**
- `testADHOC02_overlayPlotSpawnsClassicalFigure`: drives catalog 2-tag selection + Overlay mode + Plot click; asserts classical figure with Name containing "FastSense Companion" spawns
- `testADHOC03_linkedGridPlotSpawnsClassicalFigure`: same flow with 4 tags in LinkedGrid mode
- `testADHOC04_companionCloseDoesNotCloseSpawnedFigure`: spawns figure, closes companion, asserts spawned `ishandle` and `Visible=on`
- `testADHOC04_closingSpawnedFigureDoesNotCloseCompanion` (reverse): spawns figure, `delete(adhocFig)`, asserts `app.IsOpen` remains true
- `testADHOC05_noOrphanTimersAfterPlotAndClose`: snapshots `timerfindall` before construct, spawns, closes all, asserts `setdiff(postTimers, preTimers)` is empty

**Private helpers:**
- `driveSelectAndPlot_(testCase, app, keys, mode)`: struct-hacks into CatalogPane_/InspectorPane_ to drive listbox selection + mode button + Plot button
- `findCompanionAdHocFigure_(~, candidateFigs)`: filters candidate figures by Name prefix "FastSense Companion"
- `cleanupAdHoc_(testCase, adhocFig)`: best-effort delete of spawned figure + `TagRegistry.clear()`

All ADHOC tests: skip on Octave via `assumeFalse`, call `TagRegistry.clear()` in setup, use local `app` variable (no class-wide App property added), use `addTeardown` for cleanup.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### Plan Observation (not a deviation)
The acceptance criterion `grep -c "function findCompanionAdHocFigure_"` -> 1 cannot match the actual MATLAB function definition `function adhocFig = findCompanionAdHocFigure_(~, candidateFigs)` because the grep pattern omits the return value prefix. The function IS defined correctly per MATLAB conventions and is callable at line 575. The broader grep `grep -c "findCompanionAdHocFigure_("` -> 5 confirms the function definition and its 4 call sites are all present.

## Known Stubs

None — all test infrastructure is fully wired. MockPlottableTag.Default delegates to real SensorTag.getXY, so inline X/Y data flows through the actual helper path without stubs.

## Self-Check: PASSED

All files found on disk. All task commits verified in git log:
- 5d5724d: test(1022-03): add MockPlottableTag fixture with controllable getXY
- b8d9086: test(1022-03): add runOpenAdHocPlotTests runner and delegating entry point
- 52d8f21: test(1022-03): augment TestFastSenseCompanion with 5 ADHOC end-to-end tests
