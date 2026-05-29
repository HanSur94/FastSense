---
phase: 999.1-mushroom-cards-for-dashboard-engine
plan: "03"
subsystem: Dashboard/Widgets
tags: [kpi, sparkline, widget, dashboard, tdd]
dependency_graph:
  requires: [DashboardWidget, DashboardTheme, NumberWidget pattern]
  provides: [SparklineCardWidget]
  affects: [DashboardEngine widget dispatch, DashboardSerializer]
tech_stack:
  added: []
  patterns: [TDD red-green, three-path data binding (Sensor/ValueFcn/StaticValue)]
key_files:
  created:
    - libs/Dashboard/SparklineCardWidget.m
    - tests/suite/TestSparklineCardWidget.m
  modified: []
decisions:
  - "Sparkline axes created at [0.02 0.02 0.96 0.35] (bottom 35%) with Visible=off and HitTest=off to prevent MATLAB interaction"
  - "Flat-data guard: yRange=0 replaced by yRange=1 before ylim calculation to prevent axis collapse"
  - "Delta color uses theme.StatusOkColor (positive) / theme.StatusAlarmColor (negative) / theme.ForegroundColor (flat)"
  - "hSparkAx created in render() with hold on; hSparkLine created lazily in refresh() so refresh-before-render guard works cleanly"
metrics:
  duration: "2 minutes"
  completed_date: "2026-04-05"
  tasks_completed: 2
  files_changed: 2
---

# Phase 999.1 Plan 03: SparklineCardWidget Summary

SparklineCardWidget — KPI card combining big-number display, mini sparkline chart, and delta indicator with three-path data binding and flat-data protection.

## What Was Built

`SparklineCardWidget` is the third mushroom-card archetype, combining:
- A large primary value in the middle band
- A title label (top-left) and delta indicator (top-right)
- A mini sparkline chart in the bottom 35% of the card

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (TDD RED) | Create TestSparklineCardWidget test scaffold | 5bfb6a9 | tests/suite/TestSparklineCardWidget.m |
| 2 (TDD GREEN) | Implement SparklineCardWidget class | addfba1 | libs/Dashboard/SparklineCardWidget.m |

## Key Implementation Details

**Sparkline rendering:**
- Bottom 35% axes with `Visible=off`, `HitTest=off`, and `PickableParts=none` (Octave-safe try/catch)
- `disableDefaultInteractivity` called via try/catch for cross-version safety
- Line handle stored as `hSparkLine`; created lazily in `refresh()`, updated in-place on subsequent calls

**Delta indicator:**
- `delta = ySnip(end) - ySnip(1)` — absolute change across visible sparkline window
- Positive: `sprintf(DeltaFormat, delta)` + ` char(9650)` (up arrow) in `StatusOkColor`
- Negative: `sprintf(DeltaFormat, delta)` + ` char(9660)` (down arrow) in `StatusAlarmColor`
- Flat: `sprintf(DeltaFormat, delta)` + ` char(9654)` (right arrow) in `ForegroundColor`

**Flat-data guard:**
```matlab
yRange = yMax - yMin;
if yRange == 0
    yRange = 1;
end
```

**Three-path data binding:**
1. `Sensor.Y` — live sensor history for both value and sparkline
2. `ValueFcn` — function returning scalar or `.value`/`.unit` struct
3. `StaticValue` + `SparkData` — static KPI with separate sparkline vector

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — SparklineCardWidget is fully wired with data binding, rendering, delta computation, and serialization.

## Self-Check: PASSED

- [x] `libs/Dashboard/SparklineCardWidget.m` exists
- [x] `tests/suite/TestSparklineCardWidget.m` exists with 9 test methods
- [x] Commit 5bfb6a9 exists (TDD RED)
- [x] Commit addfba1 exists (TDD GREEN)
- [x] `classdef SparklineCardWidget < DashboardWidget` present
- [x] `getType()` returns `'sparkline'`
- [x] `render()` creates sparkline axes at bottom 35%
- [x] `refresh()` has guard and flat-data protection
- [x] Delta computation with char(9650)/char(9660) arrows
- [x] `toStruct()`/`fromStruct()` serialization complete
