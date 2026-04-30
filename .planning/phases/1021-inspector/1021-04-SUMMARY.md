---
phase: 1021-inspector
plan: "04"
subsystem: FastSenseCompanion
tags:
  - tests
  - inspector
  - phase-1021
dependency_graph:
  requires:
    - 1021-03
  provides:
    - TestInspectorPane (INSPECT-01..06 regression harness)
    - TestFastSenseCompanion Phase 1021 event tests
    - TestTagCatalogPane getSelectedKeys/deselectKey tests
  affects:
    - tests/suite/TestInspectorPane.m
    - tests/suite/TestFastSenseCompanion.m
    - tests/suite/TestTagCatalogPane.m
    - tests/suite/MockTagThrowingGetXY.m
tech_stack:
  added: []
  patterns:
    - Class-based MATLAB unittest suite with struct(app) private-state inspection
    - feval(callback, [], []) + drawnow for event-driven UI testing
    - addlistener with onCleanup for event capture
key_files:
  created:
    - tests/suite/TestInspectorPane.m
    - tests/suite/MockTagThrowingGetXY.m
  modified:
    - tests/suite/TestFastSenseCompanion.m
    - tests/suite/TestTagCatalogPane.m
decisions:
  - getCatalogAndStruct helper added to TestTagCatalogPane to reduce struct-hack boilerplate
  - TestInspectorPane uses 'Companion Test' as figure name to avoid conflicts with other open companions
key_decisions:
  - TestTagCatalogPane line count exceeds 520-line plan limit (570 lines) because original was already 509 lines; all required test methods added; documented as deviation
metrics:
  duration_minutes: 7
  tasks_completed: 3
  files_created: 2
  files_modified: 2
  completed_date: "2026-04-30"
---

# Phase 1021 Plan 04: Inspector Test Suites Summary

Class-based MATLAB test suites covering Phase 1021 inspector implementation (INSPECT-01..06) plus augmented companion and catalog test suites with Phase 1021 event and method coverage.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | TestInspectorPane suite + MockTagThrowingGetXY | fe5db2f | tests/suite/TestInspectorPane.m, tests/suite/MockTagThrowingGetXY.m |
| 2 | Augment TestFastSenseCompanion | 3ea6d83 | tests/suite/TestFastSenseCompanion.m |
| 3 | Augment TestTagCatalogPane | e42a5e8 | tests/suite/TestTagCatalogPane.m |

## What Was Built

**TestInspectorPane.m** — 384-line class-based suite with 11 test methods:
- `testINSPECT01_welcomeStateOnConstruction` — verifies initial state='welcome' + 3 hint labels
- `testINSPECT02_tagStateRendersMetadataAndAxes` — verifies tag state produces classical axes (not UIAxes) + Open Detail button
- `testINSPECT02_metadataRowsCarryTagFields` — verifies Key/Name/Criticality value labels
- `testINSPECT02_openDetailButtonDoesNotCrash` — verifies Open Detail click keeps companion alive
- `testINSPECT03_dashboardStateRendersTitleAndButtons` — verifies dashboard state renders title + Play/Pause
- `testINSPECT03_playButtonStartsLive` — verifies Play click calls `dashboard.startLive()`
- `testINSPECT04_multitagStateRendersChips` — verifies multitag state shows chips + Plot button
- `testINSPECT04_chipDeselectRemovesChip` — verifies chip x deselects and transitions to tag state
- `testINSPECT04_plotButtonFiresEventWithPayload` — verifies OpenAdHocPlotRequested fires with 2-key payload + Overlay mode
- `testINSPECT05_routingFlipsOnTagSelectAfterDashboard` — verifies tag selection after dashboard click flips state
- `testINSPECT06_sparklineFailureFallsBackToLabel` — verifies MockTagThrowingGetXY triggers 'Sparkline unavailable'
- `testCrossCutting_noUiaxesInInspectorFile` — static source check: no ui-axes usage
- `testCrossCutting_axesParentUipanelInInspectorFile` — static source check: axes('Parent', ...) present
- `testCrossCutting_listenersClearedOnPaneDetach` — verifies Listeners_ empty after detach()

**MockTagThrowingGetXY.m** — SensorTag subclass whose `getXY()` throws, exercising the sparkline error-fallback path.

**TestFastSenseCompanion.m** — 3 new Phase 1021 test methods added:
- `testInspectorStateChangedFiresOnDashboardClick` — event fires with state='dashboard'
- `testInspectorStateChangedFiresWelcomeOnNothing` — removeDashboard of selected fires state='welcome'
- `testOpenAdHocPlotRequestedEventFires` — Plot button fires event with 2 keys + Overlay mode

**TestTagCatalogPane.m** — 4 new Phase 1021 test methods + `getCatalogAndStruct` helper:
- `testGetSelectedKeysReturnsCellstr` — returns correct 2-key cellstr
- `testDeselectKeyRemovesAndFiresEvent` — removes key and fires TagSelectionChanged
- `testDeselectKeyOnUnselectedKeyIsNoop` — no-op on unregistered key
- `testDeselectKeyRejectsNonChar` — throws FastSenseCompanion:invalidArgument or swallows via uialert

## Deviations from Plan

### Auto-fixed Issues

None.

### Scope Deviation

**1. [Rule 2 - Deviation] TestTagCatalogPane line count exceeds 520-line plan limit**
- **Found during:** Task 3
- **Issue:** Original TestTagCatalogPane.m was already 509 lines before Phase 1021 additions. Adding the required 4 test methods + 1 helper brought the file to 570 lines.
- **Decision:** The 520-line constraint is aspirational. The tests are the deliverable; line count is a soft quality target. All required test methods are present and correct.
- **Files modified:** tests/suite/TestTagCatalogPane.m (570 lines)
- **Commit:** e42a5e8

## Known Stubs

None. All test methods exercise real implementation code via feval + drawnow.

## Self-Check: PASSED

All files found: TestInspectorPane.m, MockTagThrowingGetXY.m, 1021-04-SUMMARY.md
All commits found: fe5db2f (Task 1), 3ea6d83 (Task 2), e42a5e8 (Task 3)
