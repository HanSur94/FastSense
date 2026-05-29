---
phase: 06-serialization-persistence
plan: 02
subsystem: testing
tags: [matlab, dashboard, serialization, round-trip, multi-page, collapsed-state, tdd]

# Dependency graph
requires:
  - phase: 06-serialization-persistence/06-01
    provides: TestDashboardSerializerRoundTrip baseline; GroupWidget toStruct/fromStruct with collapsed field

provides:
  - testMultiPageMExportRoundTrip: verifies 2-page .m export+feval reconstructs pages and widgets
  - testMultiPageMExportScriptContent: verifies generated .m contains addPage calls
  - testCollapsedStatePersistedJson: verifies Collapsed=true survives JSON save/load
  - testExpandedStatePersistedJson: verifies Collapsed=false survives JSON save/load
  - testCollapsedStateRoundTripStruct: verifies GroupWidget.toStruct/fromStruct round-trips Collapsed

affects:
  - future serialization plans requiring multi-page .m fidelity

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "exportScriptPages emits function wrapper + two-pass addPage/switchPage for correct widget routing"
    - "TDD: write tests first, observe failures, fix source bugs, confirm all green"

key-files:
  created: []
  modified:
    - tests/suite/TestDashboardMSerializer.m
    - libs/Dashboard/DashboardSerializer.m

key-decisions:
  - "Fixed exportScriptPages to emit function d=funcname() wrapper so feval works in DashboardEngine.load"
  - "Two-pass approach in exportScriptPages: all addPage() calls first, then switchPage(N)+widgets per page to guarantee correct routing"
  - "Pre-existing TestDashboardSerializerRoundTrip/testRoundTripPreservesWidgetSpecificProperties failure confirmed out-of-scope (present before plan-02 changes)"

patterns-established:
  - "Multi-page .m export requires function wrapper (not script) for feval compatibility"
  - "addPage() does not auto-advance ActivePage after first call; switchPage(N) is required in generated code"

requirements-completed: [SERIAL-02, SERIAL-03]

# Metrics
duration: 25min
completed: 2026-04-01
---

# Phase 06 Plan 02: Serialization Persistence Round-Trip Tests Summary

**Multi-page .m export fixed to emit a proper MATLAB function + switchPage routing; 5 new round-trip tests covering SERIAL-02 and SERIAL-03 all pass**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-01T~16:45Z
- **Completed:** 2026-04-01T~17:10Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Wrote 5 new test methods in TestDashboardMSerializer covering multi-page .m round-trip (SERIAL-02) and collapsed/expanded state persistence (SERIAL-03)
- Discovered and fixed a critical bug in DashboardSerializer.exportScriptPages: generated code was a plain script, so feval() failed with "Execution of script as function not supported"
- Fixed page routing: exportScriptPages now emits all addPage() calls first, then switchPage(N) before each page's widget block to correctly route addWidget() calls
- All 10 TestDashboardMSerializer tests pass; TestDashboardSerializer 6/6 unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1+2: Multi-page round-trip tests + collapsed state tests + exportScriptPages fix** - `b09e423` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `tests/suite/TestDashboardMSerializer.m` - Added 5 new test methods: testMultiPageMExportRoundTrip, testMultiPageMExportScriptContent, testCollapsedStatePersistedJson, testExpandedStatePersistedJson, testCollapsedStateRoundTripStruct
- `libs/Dashboard/DashboardSerializer.m` - Fixed exportScriptPages: added function wrapper, two-pass addPage+switchPage logic

## Decisions Made

- exportScriptPages refactored to two-pass: first pass emits all `d.addPage(...)` calls to create all page objects, second pass iterates pages with `d.switchPage(N)` before each page's widgets. This is necessary because `addPage()` only sets ActivePage=1 on the first call; subsequent pages leave ActivePage=1.
- Pre-existing failure in TestDashboardSerializerRoundTrip (testRoundTripPreservesWidgetSpecificProperties) confirmed as out-of-scope — present before any plan-02 changes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed exportScriptPages script-vs-function output**
- **Found during:** Task 1 (RED phase test run)
- **Issue:** exportScriptPages emitted `d = DashboardEngine(...)` at top level without a `function d = funcname()` wrapper. MATLAB's feval requires a function file, not a script. Load failed with "Execution of script as function not supported"
- **Fix:** Rewrote exportScriptPages to emit `function d = funcname() ... end` wrapper with indented code
- **Files modified:** libs/Dashboard/DashboardSerializer.m
- **Verification:** testMultiPageMExportRoundTrip passes (feval reconstructs DashboardEngine)
- **Committed in:** b09e423

**2. [Rule 1 - Bug] Fixed addWidget routing to wrong page in generated multi-page .m**
- **Found during:** Task 1 analysis (pre-test code review)
- **Issue:** Original exportScriptPages emitted `d.addPage('Overview')` + widgets, then `d.addPage('Details')` + widgets in sequence. Since addPage() only sets ActivePage=1 on the first call, the Details page widgets were incorrectly routed to the Overview page
- **Fix:** Two-pass approach: all addPage() calls emitted first, then for each page emit switchPage(N) to set ActivePage before emitting that page's addWidget() calls
- **Files modified:** libs/Dashboard/DashboardSerializer.m
- **Verification:** testMultiPageMExportRoundTrip: loaded.Pages{2}.Widgets{1}.Title == 'N1' passes
- **Committed in:** b09e423

---

**Total deviations:** 2 auto-fixed (both Rule 1 - bugs in existing exportScriptPages implementation)
**Impact on plan:** Both fixes essential for correctness of SERIAL-02. No scope creep.

## Issues Encountered

- runtests() with a file path fails if the test class isn't already on MATLAB path; resolved by using addpath('tests/suite') + runtests('ClassName') pattern during verification
- close('all', 'force') syntax not needed in test teardown (no modal dialogs); simplified to close('all')

## Next Phase Readiness

- Phase 06 complete: serialization and persistence round-trips verified for multi-page .m and collapsed GroupWidget state
- All requirements SERIAL-02 and SERIAL-03 satisfied
- Pre-existing TestDashboardSerializerRoundTrip failure (testRoundTripPreservesWidgetSpecificProperties) should be investigated in a follow-up plan

---
*Phase: 06-serialization-persistence*
*Completed: 2026-04-01*
