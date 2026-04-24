---
phase: 999.1-mushroom-cards-for-dashboard-engine
plan: "02"
subsystem: Dashboard
tags: [widget, chipbar, status, horizontal-chips, tdd]
dependency_graph:
  requires: [DashboardWidget, DashboardTheme]
  provides: [ChipBarWidget]
  affects: [DashboardEngine widget dispatch]
tech_stack:
  added: []
  patterns: [fill-circle chip pattern, single-shared-axes multi-icon, statusFcn closure pattern]
key_files:
  created:
    - libs/Dashboard/ChipBarWidget.m
    - tests/suite/TestChipBarWidget.m
  modified: []
decisions:
  - "containers.Map used in testChipColorUpdate so anonymous function closure sees state mutation (cell array captures by value in MATLAB)"
  - "Single shared axes with XLim=[0 nChips] and evenly-spaced xc=i-0.5 centers provides clean chip layout"
  - "resolveChipColor private method consolidates iconColor override + statusFcn + sensor state resolution"
metrics:
  duration: "~3 min"
  completed_date: "2026-04-05"
  tasks_completed: 2
  files_changed: 2
requirements: [MUSH-03]
---

# Phase 999.1 Plan 02: ChipBarWidget Summary

ChipBarWidget horizontal chip bar with N colored circle icons and labels in a single shared axes, driven by statusFcn/sensor state for live color updates.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Create TestChipBarWidget test scaffold | 5116d52 | tests/suite/TestChipBarWidget.m |
| 2 (GREEN) | Implement ChipBarWidget class | 68eb57c | libs/Dashboard/ChipBarWidget.m, tests/suite/TestChipBarWidget.m |

## What Was Built

`ChipBarWidget` is a compact horizontal status strip for multi-sensor overview:

- **Single shared axes**: All N chips render into one `axes` object with `XLim=[0 nChips]`, chip centers at `xc = i - 0.5`. Verified by `testSingleAxes`.
- **Circle pattern**: `fill(hAx, xc + r*cos(theta), 0.60 + r*sin(theta), ...)` with `r=0.20` and 60-point circle.
- **Color resolution** via `resolveChipColor` private method:
  1. `chip.iconColor` (numeric `[r g b]`) — direct override
  2. `chip.statusFcn()` returning `'ok'|'warn'|'alarm'|'info'|'inactive'`
  3. `chip.sensor` — derives state from last value vs threshold rules
  4. Default gray `[0.5 0.5 0.5]`
- **refresh() guard**: Returns immediately if `hPanel` is empty or invalid.
- **Serialization**: `toStruct` emits `type='chipbar'` + `chips` cell array (label + iconColor only; statusFcn/sensor not serializable). `fromStruct` handles both cell array and struct array from `jsondecode`.
- **TDD cycle**: RED commit (7 failing tests) → GREEN commit (all 7 pass) in ~3 minutes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed testChipColorUpdate using containers.Map for mutable closure**
- **Found during:** Task 2 GREEN verification
- **Issue:** Test used `state = {'ok'}` cell array then `state{1} = 'alarm'` to mutate state — but MATLAB anonymous functions capture value-type variables at creation time, so `@() state{1}` never saw the mutation.
- **Fix:** Changed test to use `stateMap = containers.Map(...)` (a handle class) so the closure captures the map reference and sees subsequent mutations.
- **Files modified:** tests/suite/TestChipBarWidget.m
- **Commit:** 68eb57c

## Known Stubs

None — ChipBarWidget renders live color from statusFcn/sensor; no placeholder data wired to UI.

## Self-Check: PASSED
