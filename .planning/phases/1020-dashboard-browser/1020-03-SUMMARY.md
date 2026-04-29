---
phase: "1020"
plan: "03"
subsystem: FastSenseCompanion
tags: [testing, dashboard-browser, browser-01, browser-02, browser-03, browser-04, browser-05]
dependency_graph:
  requires:
    - 1020-01  # DashboardEventData + filterDashboards
    - 1020-02  # DashboardListPane + FastSenseCompanion addDashboard/removeDashboard
  provides:
    - tests/suite/TestDashboardListPane.m
    - tests/suite/TestFastSenseCompanion.m (augmented)
  affects:
    - CI regression harness for all BROWSER-01..05
tech_stack:
  added: []
  patterns:
    - class-based MATLAB unittest with findall locators
    - feval callback invocation for headless UI driving
    - struct(app) private state inspection with warning suppression
    - pause(0.25)+drawnow for debounce timer accommodation
    - addTeardown cleanup pattern with TagRegistry.clear()
key_files:
  created:
    - tests/suite/TestDashboardListPane.m
  modified:
    - tests/suite/TestFastSenseCompanion.m
decisions:
  - findRowButtons helper filters by DashboardEngine.Name list rather than a fixed text; updated per-test after add/remove operations
  - testBROWSER03_eventPayloadCarriesEngineAndIndex uses nested function inside test method to capture event data (matches MATLAB scoping rules for nested functions)
  - testCrossCutting_noBannedHandlesInDashboardListPane comment avoids using literal gcf/gca to prevent self-matching grep hits
  - Task 2 addDashboard tests construct their own FastSenseCompanion instances (not the shared buildApp fixture) to control Dashboards baseline precisely
metrics:
  duration_minutes: 3
  completed_date: "2026-04-29"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 1020 Plan 03: Dashboard Browser Test Suite Summary

**One-liner:** Class-based MATLAB regression harness for DashboardListPane covering all five BROWSER requirements plus cross-cutting timer/listener cleanup.

## What Was Built

### Task 1 — TestDashboardListPane.m (new)

New class-based MATLAB test suite (`403 lines`, under 520 limit) at `tests/suite/TestDashboardListPane.m`.

Covers all five BROWSER requirement categories:

| Requirement | Test methods | What is verified |
|-------------|-------------|-----------------|
| BROWSER-01 | `testBROWSER01_rowsRenderForEachDashboard`, `testBROWSER01_widgetCountLabelPresent`, `testBROWSER01_statusDotPresent` | 3 row buttons + 3 Open buttons; `(0)` widget count labels; `char(9679)` status dot glyphs |
| BROWSER-02 | `testBROWSER02_openClickDoesNotCrashCompanion` | Open click does not throw; `app.IsOpen` remains true |
| BROWSER-03 | `testBROWSER03_rowClickChangesHighlight`, `testBROWSER03_eventPayloadCarriesEngineAndIndex` | Background color changes on click; `DashboardSelected` fires with correct Engine handle and Index |
| BROWSER-04 | `testBROWSER04_searchNarrowsRows`, `testBROWSER04_searchIsCaseInsensitive`, `testBROWSER04_clearButtonRestoresFullList` | Search narrows Open button count; case-insensitive; clear restores full list |
| BROWSER-05 | `testBROWSER05_addDashboardAppendsRow`, `testBROWSER05_addDashboardRejectsNonDashboardEngine`, `testBROWSER05_addDashboardRejectsDuplicateHandle`, `testBROWSER05_removeDashboardDropsRow`, `testBROWSER05_removeDashboardThrowsOnUnknown`, `testBROWSER05_removeSelectedDashboardResetsInspector` | Add/remove round-trips; all three namespaced error IDs; inspector reset on selected-dashboard removal |

Cross-cutting tests:

| Test | What is verified |
|------|-----------------|
| `testCrossCutting_noOrphanTimersAfterClose` | `timerfindall` count does not increase after triggering debounce + calling `close()` |
| `testCrossCutting_listenersClearedOnPaneDetach` | `Listeners_` cell is empty after `pane.detach()` (struct hack) |
| `testCrossCutting_noBannedHandlesInDashboardListPane` | `regexp(src, ...)` against DashboardListPane source finds zero gcf/gca hits |

### Task 2 — TestFastSenseCompanion.m (augmented)

Six new Phase 1020 test methods added to the existing Phase 1018 suite (289 total lines, under 520 limit). All existing `testCOMPSHELL*` and `testSetProject*` tests preserved without modification.

New methods:

| Method | Error ID verified | Pattern |
|--------|------------------|---------|
| `testAddDashboardAppendsToBrowser` | — | `nBefore` baseline; handle identity check in loop |
| `testAddDashboardRejectsNonDashboardEngine` | `FastSenseCompanion:invalidDashboard` | `verifyError` |
| `testAddDashboardRejectsDuplicateHandle` | `FastSenseCompanion:duplicateDashboard` | `verifyError` |
| `testRemoveDashboardDropsByName` | — | `nBefore`/`nAfter` diff |
| `testRemoveDashboardThrowsOnUnknown` | `FastSenseCompanion:dashboardNotFound` | `verifyError` |
| `testRemoveDashboardThrowsOnNonChar` | `FastSenseCompanion:dashboardNotFound` | `verifyError` (non-char input) |

## Deviations from Plan

### Auto-fixed Issues

None.

### Out-of-scope observations

- The pre-existing `testNoGcfGcaInSource` method in TestFastSenseCompanion.m (Phase 1018) contains the literal strings `gcf` and `gca` in comments and a `sprintf` call. This was present before this plan's changes and causes the grep counter for that file to return 4 rather than 0. The new additions in Task 2 add zero additional banned-pattern hits.

## Known Stubs

None — both test files are complete. All test methods exercise real production code paths; no stubs or TODOs left in test bodies.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `7e2bb86` | `test(1020-03): add TestDashboardListPane class-based test suite` |
| 2 | `8a2a63a` | `test(1020-03): augment TestFastSenseCompanion with addDashboard/removeDashboard tests` |

## Self-Check: PASSED
