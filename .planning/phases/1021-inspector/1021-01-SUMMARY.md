---
phase: 1021-inspector
plan: "01"
subsystem: FastSenseCompanion
tags: [pure-helper, event-payload, state-machine, octave-compat, unit-tests]
dependency_graph:
  requires: []
  provides:
    - inspectorResolveState (pure routing function)
    - InspectorStateEventData (event.EventData subclass)
    - AdHocPlotEventData (event.EventData subclass)
  affects:
    - FastSenseCompanion (Plan 02 orchestrator consumes inspectorResolveState + InspectorStateEventData)
    - InspectorPane (Plan 03 consumes AdHocPlotEventData)
tech_stack:
  added: []
  patterns:
    - sibling-folder test runner (private/ visibility trick for testing private functions)
    - struct stub for TagRegistry in Octave-compatible tests
    - cell-valued struct fields with 1-element wrap to prevent array auto-expansion
key_files:
  created:
    - libs/FastSenseCompanion/private/inspectorResolveState.m
    - libs/FastSenseCompanion/InspectorStateEventData.m
    - libs/FastSenseCompanion/AdHocPlotEventData.m
    - libs/FastSenseCompanion/private/runInspectorResolveStateTests.m
    - tests/test_companion_inspector_resolve_state.m
  modified: []
decisions:
  - Tag-count routing (nTags >= 1) checked before dashboard click routing — tag selection always wins regardless of LastInteraction value
  - struct cell-valued fields use 1-element {cell} wrap in struct() constructor to prevent MATLAB struct array auto-expansion
  - Lightweight struct stubs used for TagRegistry/DashboardEngine in tests — avoids singleton instantiation and works on Octave
metrics:
  duration_seconds: 154
  completed_date: "2026-04-30"
  tasks_completed: 4
  tasks_total: 4
  files_created: 5
  files_modified: 0
---

# Phase 1021 Plan 01: Inspector Resolve State — Summary

Pure-logic state-routing helper inspectorResolveState plus two event payload classes (InspectorStateEventData, AdHocPlotEventData) with 13-case Octave-compatible unit test suite.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | inspectorResolveState pure helper | c25e5cd | libs/FastSenseCompanion/private/inspectorResolveState.m |
| 2 | InspectorStateEventData event payload class | 5c3c5ae | libs/FastSenseCompanion/InspectorStateEventData.m |
| 3 | AdHocPlotEventData event payload class | 1ec0961 | libs/FastSenseCompanion/AdHocPlotEventData.m |
| 4 | Function-based unit tests for inspectorResolveState | 350e79e | libs/FastSenseCompanion/private/runInspectorResolveStateTests.m, tests/test_companion_inspector_resolve_state.m |

## What Was Built

### inspectorResolveState.m

Pure function (58 lines, Octave-compatible) mapping the Inspector state machine inputs to a `(state, payload)` pair. Routing precedence:

1. `numel(selectedTagKeys) == 1` → `'tag'` state (tag count wins — checked before LastInteraction)
2. `numel(selectedTagKeys) >= 2` → `'multitag'` state
3. `lastInteraction == 'dashboard'` AND `selectedDashboardIdx > 0` → `'dashboard'` state
4. Otherwise → `'welcome'` state

Payload shapes:
- `welcome`: `struct('nTags', N, 'nDashboards', M)`
- `tag`: `struct('tag', tagHandle, 'tagKeys', {cellstr})`
- `multitag`: `struct('tags', {cellHandles}, 'tagKeys', {cellstr})`
- `dashboard`: `struct('dashboard', engineHandle)`

### InspectorStateEventData.m

`event.EventData` subclass (47 lines) carrying `State` (char) and `Payload` (struct) as immutable properties. Constructor validates state against `{'welcome','tag','multitag','dashboard'}` with `FastSenseCompanion:invalidEventData` error namespace.

### AdHocPlotEventData.m

`event.EventData` subclass (49 lines) carrying `TagKeys` (cellstr) and `Mode` (char) as immutable properties. Constructor validates mode against `{'Overlay','LinkedGrid'}` and checks each tagKeys element is char.

### Test Files

- `runInspectorResolveStateTests.m` (106 lines): 13 test cases with 23 asserts, struct stubs for TagRegistry/DashboardEngine, no `contains()`, covers all routing states + both event payload classes
- `test_companion_inspector_resolve_state.m` (17 lines): thin delegating wrapper mirroring Phase 1020 sibling pattern

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None — all files are complete implementations with no placeholder data.

## Self-Check: PASSED

Files verified:
- libs/FastSenseCompanion/private/inspectorResolveState.m: FOUND
- libs/FastSenseCompanion/InspectorStateEventData.m: FOUND
- libs/FastSenseCompanion/AdHocPlotEventData.m: FOUND
- libs/FastSenseCompanion/private/runInspectorResolveStateTests.m: FOUND
- tests/test_companion_inspector_resolve_state.m: FOUND

Commits verified:
- c25e5cd: feat(1021-01): add inspectorResolveState pure routing helper
- 5c3c5ae: feat(1021-01): add InspectorStateEventData event payload class
- 1ec0961: feat(1021-01): add AdHocPlotEventData event payload class
- 350e79e: test(1021-01): add inspectorResolveState unit tests (sibling-folder pattern)
