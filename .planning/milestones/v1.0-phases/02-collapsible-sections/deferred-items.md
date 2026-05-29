# Deferred Items

## Pre-existing Test Failures (Out of Scope)

### TestGroupWidget/testFullDashboardIntegration
- **Discovered during:** 02-01 Task 2
- **Failure:** `Intermediate dot '.' indexing produced a comma-separated list with 0 values`
- **Root cause:** `DashboardSerializer.save()` always writes MATLAB function format (`.m` content) but `testFullDashboardIntegration` saves with a `.json` extension. `DashboardEngine.load()` checks extension: `.json` goes to the legacy JSON path which calls `jsondecode()` on MATLAB function code, causing a parse error.
- **Status:** Pre-existing before this plan's changes; not introduced by ReflowCallback wiring.
- **Fix needed:** Either `DashboardSerializer.save()` should detect the extension and write JSON format for `.json` files, or `testFullDashboardIntegration` should use a `.m` extension. Not in scope for plan 02-01.

### TestDashboardEngine/testTimerContinuesAfterError
- **Discovered during:** 02-01 Task 2
- **Failure:** `Undefined function 'isrunning' for input arguments of type 'timer'`
- **Root cause:** `isrunning()` is an Octave function, not available in MATLAB. The test uses it to check if `LiveTimer` is running.
- **Status:** Pre-existing before this plan's changes.
- **Fix needed:** Replace `isrunning(d.LiveTimer)` with `strcmp(d.LiveTimer.Running, 'on')` or check `d.IsLive`. Not in scope for plan 02-01.
