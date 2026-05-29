---
phase: 05-detachable-widgets
plan: "01"
subsystem: Dashboard
tags: [detachable-widgets, DetachedMirror, cloneWidget, TDD, handle-class]
dependency_graph:
  requires: []
  provides:
    - DetachedMirror handle class (libs/Dashboard/DetachedMirror.m)
    - TestDashboardDetach test scaffold (tests/suite/TestDashboardDetach.m)
  affects:
    - DashboardEngine (will use DetachedMirror in Plan 03)
    - DashboardLayout (will inject DetachButton in Plan 02)
tech_stack:
  added: []
  patterns:
    - "toStruct/fromStruct clone dispatch for all 15 widget types"
    - "CloseRequestFcn -> RemoveCallback() -> delete(hFigure) (Pitfall 2 safe)"
    - "TDD RED scaffold: 7 test stubs, 3 pass immediately, 4 fail with clear assertion errors"
key_files:
  created:
    - libs/Dashboard/DetachedMirror.m
    - tests/suite/TestDashboardDetach.m
  modified: []
decisions:
  - "DetachedMirror is NOT a DashboardWidget subclass — wraps one (avoids grid layout entanglement)"
  - "cloneWidget dispatch uses explicit 15-type switch rather than calling DashboardSerializer to keep DetachedMirror self-contained"
  - "Sensor constructor called with positional key arg (not name-value 'Key' pair) — discovered during test setup"
metrics:
  duration: "10min"
  completed: "2026-04-02"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
---

# Phase 05 Plan 01: DetachedMirror + Test Scaffold Summary

DetachedMirror handle class for standalone live-mirrored widget windows, cloning all 15 widget types via toStruct/fromStruct with FastSenseWidget Sensor rebind and UseGlobalTime=false.

## What Was Built

### Task 1: DetachedMirror.m (complete implementation)

`libs/Dashboard/DetachedMirror.m` is a new `handle` class (NOT a DashboardWidget subclass) that:

- **Properties (SetAccess = private):** `hFigure`, `hPanel`, `Widget`, `RemoveCallback`
- **Constructor:** Clones original widget via `cloneWidget()`, creates a figure with `CloseRequestFcn`, fills it with a uipanel, applies theme, and calls `cloned.render()`
- **`tick()` public method:** Refreshes the cloned widget with `ishandle()` guard and `try/catch` warning pattern (no drawnow)
- **`isStale()` public method:** Returns true when hFigure is empty or invalid
- **`cloneWidget()` static private method:** Dispatch switch across all 15 widget types; restores FastSenseWidget Sensor + sets `UseGlobalTime = false`; restores RawAxesWidget PlotFcn/DataRangeFcn
- **`onFigureClose()` private method:** Calls `RemoveCallback()` BEFORE `delete(hFigure)` to avoid double-close (Pitfall 2 from RESEARCH.md)

### Task 2: TestDashboardDetach.m (RED test scaffold)

`tests/suite/TestDashboardDetach.m` has 7 test methods covering DETACH-01 through DETACH-07:

| Test | DETACH-ID | Status |
|------|-----------|--------|
| testDetachButtonInjected | DETACH-01 | FAILS (Plan 02 needed) |
| testDetachOpensWindow | DETACH-02 | FAILS (Plan 03 needed) |
| testMirrorTickedOnLive | DETACH-03 | FAILS (Plan 03 needed) |
| testCloseRemovesFromRegistry | DETACH-04 | FAILS (Plan 03 needed) |
| testFastSenseIndependentZoom | DETACH-05 | **PASSES** |
| testNoExtraTimers | DETACH-06 | **PASSES** |
| testMirrorIsReadOnly | DETACH-07 | **PASSES** |

## Decisions Made

- DetachedMirror is NOT a DashboardWidget subclass — it wraps one, preventing it from being pulled into the grid layout system
- `cloneWidget()` uses an explicit 15-type dispatch switch rather than delegating to DashboardSerializer, so DetachedMirror is fully self-contained
- `onFigureClose()` order: `RemoveCallback()` then `delete(hFigure)` — prevents double-close that occurs if delete fires before bookkeeping

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Sensor constructor positional argument**
- **Found during:** Task 2 (testFastSenseIndependentZoom failing with "Unknown option")
- **Issue:** `Sensor('Key', '__detach_test__', 'Name', 'Test Sensor')` passed 'Key' as an unknown name-value option; actual constructor signature is `Sensor(key, 'Name', value, ...)`
- **Fix:** Changed to `Sensor('__detach_test__', 'Name', 'Test Sensor')` with key as first positional arg
- **Files modified:** `tests/suite/TestDashboardDetach.m`
- **Commit:** 4dffb0f (same commit as Task 2)

## Known Stubs

None — DetachedMirror is a complete implementation. Tests that currently fail do so because the engine/layout wiring (Plans 02/03) is not yet implemented, not because DetachedMirror is stubbed.

## Self-Check: PASSED

- `libs/Dashboard/DetachedMirror.m` — exists at correct path
- `tests/suite/TestDashboardDetach.m` — exists with 7 test methods
- Commit 0d8786f (feat 05-01: DetachedMirror) — verified
- Commit 4dffb0f (test 05-01: TestDashboardDetach) — verified
- 3 self-contained tests PASS; 4 wiring tests FAIL with clear assertion/method-missing errors
