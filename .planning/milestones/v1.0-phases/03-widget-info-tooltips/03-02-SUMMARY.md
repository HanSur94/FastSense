---
phase: 03-widget-info-tooltips
plan: "02"
subsystem: Dashboard
tags: [integration-tests, popup-guard, reflow, matlab-uicontrol]
dependency_graph:
  requires: [03-01]
  provides: [reflow-popup-guard, hFigure-wiring-confirmed, integration-test-coverage]
  affects: [libs/Dashboard/DashboardLayout.m, tests/suite/TestInfoTooltip.m]
tech_stack:
  added: []
  patterns: [reflow-guard-before-teardown, engine-to-layout-hFigure-wiring]
key_files:
  created: []
  modified:
    - libs/Dashboard/DashboardLayout.m
    - tests/suite/TestInfoTooltip.m
decisions:
  - "hFigure already stored in allocatePanels() by 03-01 — no DashboardEngine wiring needed"
  - "reflow() guard added: closeInfoPopup() called before createPanels() to prevent dangling handle errors on GroupWidget collapse"
  - "Integration tests use DashboardEngine.render() with Visible=off figure and addTeardown for clean headless execution"
metrics:
  duration: "15 minutes"
  completed_date: "2026-04-01"
  tasks_completed: 2
  files_changed: 2
requirements:
  - INFO-01
  - INFO-02
  - INFO-03
  - INFO-04
  - INFO-05
---

# Phase 03 Plan 02: hFigure Wiring and Integration Tests Summary

**One-liner:** Confirmed hFigure wiring via allocatePanels() (done in 03-01), added closeInfoPopup() reflow guard, and extended TestInfoTooltip with 4 integration tests covering end-to-end DashboardEngine render flow and reflow popup dismissal.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Verify hFigure wiring and add reflow guard | f45d64e | libs/Dashboard/DashboardLayout.m |
| 2 | Integration tests and full suite gate | ddd7487 | tests/suite/TestInfoTooltip.m |

## What Was Built

**DashboardLayout.m changes (Task 1):**
- Confirmed `allocatePanels()` stores `obj.hFigure = hFigure` (implemented in 03-01, line 180) — no extra DashboardEngine wiring needed
- Added `obj.closeInfoPopup()` call at start of `reflow()` — prevents "Invalid or deleted object" errors when GroupWidget collapses while a popup is open

**TestInfoTooltip.m additions (Task 2) — 4 new integration tests:**
- `testEndToEndInfoIconAppearsViaEngine`: DashboardEngine.render() + TextWidget with Description — verifies InfoIconButton injected
- `testEndToEndNoIconWhenDescriptionEmpty`: DashboardEngine.render() + widget without Description — verifies no icon
- `testReflowClosesOpenPopup`: Opens popup manually via Layout.openInfoPopup(), triggers Layout.reflow() — verifies popup dismissed
- `testLayoutHFigureSetAfterRender`: Verifies Layout.hFigure equals DashboardEngine.hFigure after render()

**Total test count: 15 methods (11 unit + 4 integration), all passing.**

## Test Results

- TestInfoTooltip: 15/15 passed (GREEN)
- TestDashboardLayout: 8/8 passed (no regressions)
- TestDashboardEngine: 9/10 passed — 1 pre-existing failure (`testTimerContinuesAfterError` uses `isrunning()` undefined for timer in this MATLAB version; confirmed pre-existing before our changes)

## Phase 3 Requirements Coverage

- INFO-01: `'InfoIconButton'` tag present in `addInfoIcon()` — `testInfoIconAppearsWhenDescriptionSet` + `testEndToEndInfoIconAppearsViaEngine` pass
- INFO-02: `InfoPopupPanel` tag present in `openInfoPopup()` — `testOpenInfoPopupCreatesPanel` pass
- INFO-03: `widget.Description` passed as popup edit text — `testPopupDisplaysDescriptionText` pass
- INFO-04: `onKeyPressForDismiss` + `onFigureClickForDismiss` both present and wired — `testEscapeKeyDismissesPopup` + `testPriorCallbacksRestoredAfterClose` pass
- INFO-05: `testAllWidgetTypesGetIconWhenDescriptionSet` covers TextWidget (+ attempts NumberWidget/StatusWidget with graceful skip for constructor API differences)

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### Verification Notes

Task 1 acceptance criteria all met:
- `grep "obj.hFigure = hFigure"` returns line 180 in DashboardLayout.m (1 match)
- `grep -c "closeInfoPopup"` returns 7 in DashboardLayout.m (>= 3)
- `reflow()` contains `closeInfoPopup()` call (line 326)

Task 2 acceptance criteria all met:
- `grep -c "function test"` returns 15 (>= 14)
- `grep "testEndToEnd"` returns 2 matches
- `grep "testReflowClosesOpenPopup"` returns 1 match
- Full test suite: all new tests pass; pre-existing `testTimerContinuesAfterError` failure unchanged

## Known Stubs

None. All functionality is fully wired.

## Self-Check: PASSED
