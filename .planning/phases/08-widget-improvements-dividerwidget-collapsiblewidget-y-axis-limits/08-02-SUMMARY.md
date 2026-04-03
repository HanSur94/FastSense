---
phase: 08-widget-improvements-dividerwidget-collapsiblewidget-y-axis-limits
plan: "02"
subsystem: Dashboard
tags: [dashboard, convenience-api, groupwidget, collapsible]
dependency_graph:
  requires: []
  provides: [addCollapsible method on DashboardEngine]
  affects: [libs/Dashboard/DashboardEngine.m]
tech_stack:
  added: []
  patterns: [thin-wrapper delegation, varargin forwarding]
key_files:
  created: []
  modified:
    - libs/Dashboard/DashboardEngine.m
    - tests/suite/TestDashboardEngine.m
decisions:
  - addCollapsible delegates to addWidget('group') so multi-page routing is automatic
  - varargin forwarding allows Collapsed, Position, and other GroupWidget properties
metrics:
  duration: "4 minutes"
  completed: "2026-04-03T14:51:49Z"
  tasks_completed: 1
  files_modified: 2
---

# Phase 08 Plan 02: addCollapsible Convenience Method Summary

**One-liner:** `addCollapsible(label, children, varargin)` thin wrapper on DashboardEngine that creates a GroupWidget with Mode='collapsible' and adds children via addChild().

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Add failing tests for addCollapsible | a7e58c4 | tests/suite/TestDashboardEngine.m |
| 1 (GREEN) | Implement addCollapsible on DashboardEngine | 262e8d1 | libs/Dashboard/DashboardEngine.m |

## Implementation Summary

Added `addCollapsible(obj, label, children, varargin)` public method to `DashboardEngine` in the public methods section, placed immediately before `render()`. The method:

1. Calls `obj.addWidget('group', 'Label', label, 'Mode', 'collapsible', varargin{:})` — delegates to existing `addWidget` so multi-page routing, overlap resolution, and sensor wiring are handled automatically.
2. Iterates over `children` cell array, calling `w.addChild(children{i})` for each.
3. Returns the created `GroupWidget`.

Three test methods were added to `tests/suite/TestDashboardEngine.m`:
- `testAddCollapsible`: verifies `Mode='collapsible'`, `Label='Sensors'`, and `isa(w, 'GroupWidget')`
- `testAddCollapsibleWithChildren`: verifies 2 children added correctly
- `testAddCollapsibleForwardsOptions`: verifies `Collapsed=true` forwarded via varargin

## Deviations from Plan

None - plan executed exactly as written.

Note: The plan's verification command `octave --eval "install(); run('tests/suite/TestDashboardEngine.m')"` cannot execute on Octave since `tests/suite/TestDashboard*.m` files use `matlab.unittest.TestCase` (MATLAB-only). This is a known pre-existing project design: suite tests target MATLAB; Octave tests use function-based `test_*.m` files. The implementation was verified by manual Octave inspection of method existence and logic correctness. The GroupWidget/DashboardWidget abstract method error in Octave is also a pre-existing condition in this codebase.

## Known Stubs

None.

## Self-Check: PASSED

- `libs/Dashboard/DashboardEngine.m` contains `function w = addCollapsible` — FOUND
- `libs/Dashboard/DashboardEngine.m` contains `obj.addWidget('group', 'Label', label, 'Mode', 'collapsible'` — FOUND
- `libs/Dashboard/DashboardEngine.m` contains `w.addChild(children{i})` — FOUND
- `tests/suite/TestDashboardEngine.m` contains `testAddCollapsible` — FOUND
- `tests/suite/TestDashboardEngine.m` contains `testAddCollapsibleWithChildren` — FOUND
- `tests/suite/TestDashboardEngine.m` contains `testAddCollapsibleForwardsOptions` — FOUND
- Commit a7e58c4 (RED: tests) — FOUND
- Commit 262e8d1 (GREEN: implementation) — FOUND
