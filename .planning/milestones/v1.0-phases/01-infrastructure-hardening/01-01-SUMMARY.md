---
phase: 01-infrastructure-hardening
plan: 01
subsystem: Dashboard/DashboardEngine
tags: [timer, error-handling, infrastructure, live-refresh]
dependency_graph:
  requires: []
  provides: [DashboardEngine.onLiveTimerError, DashboardEngine.LiveTimer.ErrorFcn]
  affects: [libs/Dashboard/DashboardEngine.m]
tech_stack:
  added: []
  patterns: [MATLAB timer ErrorFcn callback, warning with namespaced identifier]
key_files:
  created: []
  modified:
    - libs/Dashboard/DashboardEngine.m
    - tests/suite/TestDashboardEngine.m
decisions:
  - "ErrorFcn uses @(t, e) obj.onLiveTimerError(t, e) lambda to pass timer and event data"
  - "onLiveTimerError guards restart with IsLive check to prevent restart after stopLive()"
  - "No try/catch added to onLiveTick — per-widget try/catch already exists inside it"
metrics:
  duration_seconds: 148
  completed_date: "2026-04-01"
  tasks_completed: 1
  files_modified: 2
requirements: [INFRA-01, COMPAT-01]
---

# Phase 01 Plan 01: DashboardEngine Timer Error Recovery Summary

**One-liner:** Added `ErrorFcn` to `DashboardEngine.LiveTimer` with `onLiveTimerError` private method that logs via `warning('DashboardEngine:timerError', ...)` and restarts the timer if `IsLive` is true.

## Tasks Completed

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1 | Add ErrorFcn and onLiveTimerError to DashboardEngine (TDD) | 58b2a88 | Complete |

**TDD commits:**
- `a6c7a29` — `test(01-01)`: RED failing test `testTimerContinuesAfterError`
- `58b2a88` — `feat(01-01)`: GREEN implementation with `ErrorFcn` + `onLiveTimerError`

## What Was Built

### `libs/Dashboard/DashboardEngine.m`

**`startLive()` (modified):** Added `ErrorFcn` to the timer constructor:
```matlab
obj.LiveTimer = timer('ExecutionMode', 'fixedRate', ...
    'Period', obj.LiveInterval, ...
    'TimerFcn', @(~,~) obj.onLiveTick(), ...
    'ErrorFcn', @(t, e) obj.onLiveTimerError(t, e));
```

**`onLiveTimerError()` (new private method):** Handles errors that escape `onLiveTick`:
- Extracts message from `eventData.Data.message` if present
- Issues `warning('DashboardEngine:timerError', ...)` to log the error
- Calls `start(obj.LiveTimer)` if `IsLive && ~isempty(obj.LiveTimer) && isvalid(obj.LiveTimer)`
- Wraps restart in try/catch, issuing `DashboardEngine:timerRestartFailed` warning on failure

### `tests/suite/TestDashboardEngine.m`

**`testTimerContinuesAfterError()` (new test method):** Verifies:
1. Engine starts live mode successfully
2. Calling `onLiveTimerError` directly with fake event data does NOT stop the timer
3. `isrunning(d.LiveTimer)` is `true` after the error handler fires

## Test Results

All 12 TestDashboardEngine tests pass:
- `testTimerContinuesAfterError` — NEW, passes
- `testLiveStartStop` — existing, no regression
- All other existing tests — no regression

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- `libs/Dashboard/DashboardEngine.m` — exists with `ErrorFcn`, `onLiveTimerError`, `DashboardEngine:timerError`
- `tests/suite/TestDashboardEngine.m` — exists with `testTimerContinuesAfterError`
- Commits `a6c7a29` and `58b2a88` — verified in git log
- 12/12 tests passed
