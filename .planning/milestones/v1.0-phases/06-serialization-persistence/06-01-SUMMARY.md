---
phase: 06-serialization-persistence
plan: 01
subsystem: testing
tags: [matlab, dashboard, serialization, json, multi-page, round-trip]

# Dependency graph
requires:
  - phase: 04-multi-page-navigation
    provides: DashboardPage, addPage, switchPage, widgetsPagesToConfig
  - phase: 05-detachable-widgets
    provides: DetachedMirrors property on DashboardEngine
provides:
  - Round-trip tests for multi-page JSON serialization (SERIAL-01)
  - Test confirming DetachedMirrors excluded from saved JSON (SERIAL-04)
  - Test confirming legacy single-page JSON loads cleanly (SERIAL-05)
  - Bug fix for single-named-page save routing
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Multi-page test: addPage + switchPage before addWidget to route to correct page"
    - "Legacy compat test: inline JSON string in test, no fixture file"

key-files:
  created: []
  modified:
    - tests/suite/TestDashboardSerializerRoundTrip.m
    - libs/Dashboard/DashboardEngine.m

key-decisions:
  - "Single non-default named page must serialize with widgetsPagesToConfig (pages field) not widgetsToConfig (widgets field)"
  - "switchPage() required before addWidget() to route widget to non-first page"

patterns-established:
  - "Pattern: test addPage/switchPage/addWidget sequence for multi-page widget routing"

requirements-completed: [SERIAL-01, SERIAL-04, SERIAL-05]

# Metrics
duration: 11min
completed: 2026-04-02
---

# Phase 6 Plan 1: Serialization Persistence Round-Trip Tests Summary

**Multi-page JSON save/load round-trip tests covering SERIAL-01, SERIAL-04, SERIAL-05 with a bug fix for single-named-page save routing to widgetsPagesToConfig**

## Performance

- **Duration:** ~11 min
- **Started:** 2026-04-02T06:27:13Z
- **Completed:** 2026-04-02T06:38:09Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added 4 new test methods to TestDashboardSerializerRoundTrip covering SERIAL-01, SERIAL-04, SERIAL-05
- Fixed DashboardEngine.save() bug: single non-default named page now uses widgetsPagesToConfig so page name/structure survives round-trip
- All 4 new tests pass; 9/9 TestDashboardMultiPage tests still pass (no regressions)

## Task Commits

Each task was committed atomically:

1. **Task 1+2: Multi-page, detached exclusion, and legacy tests** - `621518f` (feat)

**Plan metadata:** _pending_

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified
- `tests/suite/TestDashboardSerializerRoundTrip.m` - Added 4 new test methods (testMultiPageJsonRoundTrip, testMultiPageJsonWidgetTypesSurvive, testDetachedStateNotPersisted, testLegacyJsonBackwardCompat)
- `libs/Dashboard/DashboardEngine.m` - Fixed save() to route single non-default named page through widgetsPagesToConfig

## Decisions Made
- Single non-default named page must be saved with widgetsPagesToConfig (pages JSON field) not widgetsToConfig (widgets JSON field), so the page name and page structure are preserved through the round-trip
- switchPage() must be called before addWidget() when routing to a non-first page; addPage() only sets ActivePage on the first call

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed DashboardEngine.save() single-named-page routing**
- **Found during:** Task 2 (testMultiPageJsonWidgetTypesSurvive)
- **Issue:** When engine has exactly 1 non-default named page, save() fell through to `widgetsToConfig(..., obj.Widgets, ...)` which is always empty in multi-page mode, producing a JSON with 0 widgets
- **Fix:** Added `isSingleNamedPage` guard in save(): any page whose Name != 'Default' uses `widgetsPagesToConfig` so pages field is written to JSON
- **Files modified:** libs/Dashboard/DashboardEngine.m
- **Verification:** testMultiPageJsonWidgetTypesSurvive passes; testSaveLoadRoundTrip in TestDashboardMultiPage still passes
- **Committed in:** 621518f (Task 1+2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Bug fix required for SERIAL-01 test correctness. No scope creep.

## Issues Encountered
- Pre-existing failure in `testRoundTripPreservesWidgetSpecificProperties` (XData/YData row/column vector orientation after JSON decode). This was failing before plan 06-01 started. Deferred — not introduced by this plan.
- MATLAB `runtests()` requires the test class to be on path first; used `TestSuite.fromFile()` approach instead.

## Known Stubs
None.

## Next Phase Readiness
- SERIAL-01, SERIAL-04, SERIAL-05 requirements are verified by passing tests
- Plan 06-02 may address the pre-existing XData vector orientation issue (testRoundTripPreservesWidgetSpecificProperties)
- DashboardEngine.save() single-named-page fix ready; multi-page serialization path fully exercised

## Self-Check: PASSED

- tests/suite/TestDashboardSerializerRoundTrip.m: FOUND
- libs/Dashboard/DashboardEngine.m: FOUND
- .planning/phases/06-serialization-persistence/06-01-SUMMARY.md: FOUND
- commit 621518f: FOUND

---
*Phase: 06-serialization-persistence*
*Completed: 2026-04-02*
