---
phase: 02-collapsible-sections
plan: "01"
subsystem: Dashboard
tags: [collapsible-groups, reflow-callback, tdd, GroupWidget, DashboardEngine]
dependency_graph:
  requires: [GroupWidget.collapse, GroupWidget.expand, DashboardEngine.addWidget, DashboardEngine.load, DashboardEngine.rerenderWidgets]
  provides: [LAYOUT-01-wired, LAYOUT-02-wired, GroupWidget.ReflowCallback, DashboardEngine.reflowAfterCollapse]
  affects: [libs/Dashboard/GroupWidget.m, libs/Dashboard/DashboardEngine.m, tests/suite/TestGroupWidget.m, tests/suite/TestDashboardEngine.m]
tech_stack:
  added: []
  patterns: [TDD-red-green, callback-injection, EngineRef-pattern]
key_files:
  created: []
  modified:
    - libs/Dashboard/GroupWidget.m
    - libs/Dashboard/DashboardEngine.m
    - tests/suite/TestGroupWidget.m
    - tests/suite/TestDashboardEngine.m
decisions:
  - Used EngineRef callback pattern (lambda injection) consistent with Phase 1 LiveTimer ErrorFcn pattern
  - reflowAfterCollapse() guards on hFigure validity to avoid errors when no figure is rendered
  - ReflowCallback injection in load() uses a second loop over obj.Widgets after the existing widgets loop
metrics:
  duration: "~25 minutes"
  completed: "2026-04-01T21:00:00Z"
  tasks_completed: 2
  files_modified: 4
---

# Phase 02 Plan 01: ReflowCallback Wiring for GroupWidget Summary

Wired the missing reflow callback into GroupWidget.collapse() and expand() so collapsing or expanding a GroupWidget triggers DashboardLayout recomputation via DashboardEngine.rerenderWidgets(). Implemented TDD with 7 new tests covering callback invocation and engine injection.

## What Was Implemented

### GroupWidget.ReflowCallback Property (LAYOUT-01, LAYOUT-02)

Added `ReflowCallback = []` as a public property on `GroupWidget`. The `collapse()` and `expand()` methods previously had TODO comments where the reflow call should go. These were replaced with:

```matlab
if ~isempty(obj.ReflowCallback)
    obj.ReflowCallback();
end
```

Both `collapse()` and `expand()` invoke the callback when set. Panel-mode GroupWidgets return early before reaching the callback site, so they are unaffected.

### DashboardEngine.reflowAfterCollapse() Private Method

Added a new private method that guards on figure validity and calls `rerenderWidgets()`:

```matlab
function reflowAfterCollapse(obj)
    if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
        return;
    end
    obj.rerenderWidgets();
end
```

### ReflowCallback Injection in addWidget()

After `obj.Widgets{end+1} = w;` in `addWidget()`, collapsible GroupWidgets receive the callback:

```matlab
if isa(w, 'GroupWidget') && strcmp(w.Mode, 'collapsible')
    w.ReflowCallback = @() obj.reflowAfterCollapse();
end
```

### ReflowCallback Injection in load() JSON Path

After the widgets-loading loop in `DashboardEngine.load()` (JSON path), a second loop injects the callback into any loaded collapsible GroupWidgets.

## Files Modified

- `libs/Dashboard/GroupWidget.m` — added `ReflowCallback = []` property; replaced TODO comments with callback invocation in `collapse()` and `expand()`
- `libs/Dashboard/DashboardEngine.m` — injection in `addWidget()`; injection loop in `load()` JSON path; new `reflowAfterCollapse()` private method
- `tests/suite/TestGroupWidget.m` — 4 new test methods for ReflowCallback behavior
- `tests/suite/TestDashboardEngine.m` — 3 new test methods for injection and grid reflow

## Test Results

| Test | Result |
|------|--------|
| testReflowCallbackDefaultsToEmpty | PASS |
| testCollapseCallsReflowCallback | PASS |
| testExpandCallsReflowCallback | PASS |
| testPanelModeCollapseDoesNotCallReflowCallback | PASS |
| testAddWidgetInjectsReflowCallbackForCollapsibleGroup | PASS |
| testAddWidgetDoesNotInjectReflowCallbackForPanelGroup | PASS |
| testCollapseGroupWidgetReflowsGrid | PASS |

All 7 new tests: 7 passed, 0 failed. RED->GREEN confirmed.

## Deviations from Plan

### Pre-existing Failures (Out of Scope)

**1. [Pre-existing] TestGroupWidget/testFullDashboardIntegration**
- **Found during:** Task 2 verification
- **Issue:** Test saves with `.json` extension but `DashboardSerializer.save()` always writes MATLAB function format. `DashboardEngine.load()` uses file extension to determine parsing strategy, so the `.json` path calls `jsondecode()` on MATLAB function code.
- **Status:** Pre-existing before plan 02-01 — confirmed by testing both with and without my production changes
- **Deferred to:** `deferred-items.md`

**2. [Pre-existing] TestDashboardEngine/testTimerContinuesAfterError**
- **Found during:** Task 2 verification
- **Issue:** Uses `isrunning()` which is Octave-only; not available in MATLAB R2025b
- **Status:** Pre-existing — tracked in `deferred-items.md`

## Known Stubs

None — all implemented functionality is wired end-to-end. ReflowCallback injection is active in both `addWidget()` and `load()`.

## Self-Check: PASSED
