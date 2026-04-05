---
phase: 999.1-mushroom-cards-for-dashboard-engine
plan: "04"
subsystem: Dashboard
tags: [widgets, serialization, mushroom-cards, wiring]
dependency_graph:
  requires: [999.1-01, 999.1-02, 999.1-03]
  provides: [iconcard-engine-integration, chipbar-engine-integration, sparkline-engine-integration]
  affects: [DashboardEngine, DashboardSerializer, DetachedMirror, DashboardBuilder]
tech_stack:
  added: []
  patterns: [WidgetTypeMap-dispatch, createWidgetFromStruct-dispatch, linesForWidget-dispatch, emitChildWidget-dispatch, cloneWidget-dispatch]
key_files:
  created:
    - libs/Dashboard/IconCardWidget.m
    - libs/Dashboard/ChipBarWidget.m
    - libs/Dashboard/SparklineCardWidget.m
  modified:
    - libs/Dashboard/DashboardEngine.m
    - libs/Dashboard/DashboardSerializer.m
    - libs/Dashboard/DetachedMirror.m
    - libs/Dashboard/DashboardBuilder.m
    - tests/suite/TestDashboardSerializer.m
decisions:
  - "Wave 1 widget files copied from main repo (not yet merged to worktree); plan 04 is self-contained"
  - "DetachedMirror restoreLiveRefs handles ValueFcn generically via isprop — no per-type code needed beyond fromStruct dispatch"
  - "linesForWidget iconcard/sparkline emit Units and StaticValue if present; chipbar uses simple one-line form"
metrics:
  duration: "5min"
  completed: "2026-04-05T12:13:39Z"
  tasks_completed: 2
  files_modified: 5
  files_created: 3
---

# Phase 999.1 Plan 04: Infrastructure Wiring for Mushroom Card Widgets Summary

Wired all 3 Mushroom Card widget types (IconCardWidget, ChipBarWidget, SparklineCardWidget) into the complete dashboard infrastructure: DashboardEngine type dispatch map, DashboardSerializer (4 dispatch points), DetachedMirror cloneWidget, and DashboardBuilder palette with correct default sizes.

## What Was Built

### DashboardEngine.m
Added 3 new entries to `WidgetTypeMap_` containers.Map:
- `'iconcard'` -> `@IconCardWidget`
- `'chipbar'` -> `@ChipBarWidget`
- `'sparkline'` -> `@SparklineCardWidget`

### DashboardSerializer.m (4 dispatch points)
1. **createWidgetFromStruct**: Added `case 'iconcard'`, `case 'chipbar'`, `case 'sparkline'` dispatching to respective `fromStruct` static methods
2. **linesForWidget** (shared by exportScript/exportScriptPages): Added cases with property serialization (Units, StaticValue, StaticState for iconcard; Units, StaticValue for sparkline; simple form for chipbar)
3. **emitChildWidget**: Added cases for all 3 types as GroupWidget children via constructor syntax
4. **save() function**: Added cases generating `d.addWidget(...)` calls for all 3 types in .m script output

### DetachedMirror.m
Added `case 'iconcard'`, `case 'chipbar'`, `case 'sparkline'` to the `cloneWidget` static method's switch dispatch. Live reference restoration (ValueFcn, Sensor, Chips) is handled generically by `restoreLiveRefs` via `isprop` checks.

### DashboardBuilder.m
- `findNextSlot`: Added default sizes — iconcard [6,2], chipbar [12,1], sparkline [6,3]
- `createPalette`: Added 3 new buttons — `'Icon Card'`, `'Chip Bar'`, `'Sparkline'`

### TestDashboardSerializer.m (6 new test methods)
- `testFromStructIconCard`, `testFromStructChipBar`, `testFromStructSparkline` — verify createWidgetFromStruct dispatch
- `testJsonRoundTripIconCard`, `testJsonRoundTripChipBar`, `testJsonRoundTripSparkline` — verify JSON save/load round-trip preserves type and title

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1: Engine/Serializer/DetachedMirror wiring | 6a54ad2 | DashboardEngine.m, DashboardSerializer.m, DetachedMirror.m, 3 widget files |
| Task 2: Builder palette + serializer tests | ac64b08 | DashboardBuilder.m, TestDashboardSerializer.m |

## Deviations from Plan

**1. [Rule 3 - Blocking] Wave 1 widget files not yet in worktree**
- **Found during:** Task 1 — IconCardWidget.m, ChipBarWidget.m, SparklineCardWidget.m missing from worktree
- **Fix:** Copied widget files from main FastPlot repo (where they exist from Wave 1 work in another worktree)
- **Files modified:** 3 widget files added to worktree libs/Dashboard/
- **Commit:** 6a54ad2

No other deviations — plan executed as designed.

## Known Stubs

None — all wiring is complete. The widget classes are production-quality implementations from Wave 1.

## Self-Check: PASSED

Files created/modified:
- FOUND: libs/Dashboard/IconCardWidget.m
- FOUND: libs/Dashboard/ChipBarWidget.m
- FOUND: libs/Dashboard/SparklineCardWidget.m
- FOUND: libs/Dashboard/DashboardEngine.m
- FOUND: libs/Dashboard/DashboardSerializer.m
- FOUND: libs/Dashboard/DetachedMirror.m
- FOUND: libs/Dashboard/DashboardBuilder.m
- FOUND: tests/suite/TestDashboardSerializer.m

Commits:
- FOUND: 6a54ad2
- FOUND: ac64b08
