# Deferred Items — Phase 01 Infrastructure Hardening

## Pre-existing Test Failures (not caused by Phase 01 plans)

These failures existed before Plan 01-03 execution and are out of scope for this phase.

### TestGroupWidget/testFullDashboardIntegration
- **File:** tests/suite/TestGroupWidget.m line 231-238
- **Root cause:** Test generates temp file with `.json` extension via `tempname`, calls `d.save()` which writes `.m` function code (not JSON), then `DashboardEngine.load()` correctly dispatches to `loadJSON()` based on extension and fails to parse.
- **Fix needed:** Either the test should use a `.m` extension or use `saveJSON()` explicitly.

### TestDashboardEngine/testTimerContinuesAfterError
- **File:** tests/suite/TestDashboardEngine.m line 127
- **Root cause:** `onLiveTimerError` is a private method; test calls it directly from outside the class. MATLAB enforces `Access=private` on direct method calls even in tests.
- **Fix needed:** Either expose `onLiveTimerError` as `Access=?matlab.unittest.TestCase` or refactor the test to trigger error indirectly via timer invocation.

### TestDashboardBuilder/testAddWidgetFromPalette
- **File:** tests/suite/TestDashboardBuilder.m line 45
- **Root cause:** Test expects widget type to be `'kpi'` but DashboardEngine normalizes 'kpi' to 'number' with a deprecation warning; type is stored as 'number'.
- **Fix needed:** Update test expectation to match 'number'.

### TestDashboardBuilder/testDragSnapsToGrid
- **File:** tests/suite/TestDashboardBuilder.m
- **Root cause:** Numeric tolerance failure in drag-snap position verification; likely floating point/grid rounding discrepancy.

### TestDashboardBuilder/testResizeSnapsToGrid
- **File:** tests/suite/TestDashboardBuilder.m
- **Root cause:** Same numeric tolerance issue as testDragSnapsToGrid.
