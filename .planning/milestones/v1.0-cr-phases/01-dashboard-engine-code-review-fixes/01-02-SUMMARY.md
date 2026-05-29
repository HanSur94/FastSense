---
phase: 01-dashboard-engine-code-review-fixes
plan: "02"
subsystem: Dashboard/GroupWidget
tags: [bugfix, groupwidget, refresh, getTimeRange, tdd]
dependency_graph:
  requires: []
  provides: [GroupWidget.getTimeRange, collapsed-refresh-guard]
  affects: [DashboardEngine.updateGlobalTimeRange, live-refresh-performance]
tech_stack:
  added: []
  patterns: [TDD red-green, collapsed-guard, override-base-method]
key_files:
  created: []
  modified:
    - libs/Dashboard/GroupWidget.m
    - tests/suite/TestDashboardBugFixes.m
decisions:
  - "Collapsed refresh guard placed in else branch of refresh() before the children loop — tabbed mode is unaffected"
  - "getTimeRange() iterates both Children and Tabs{i}.widgets using same double-loop pattern as setTimeRange()"
metrics:
  duration: "2 minutes"
  completed: "2026-04-03T19:22:52Z"
  tasks_completed: 2
  files_modified: 2
---

# Phase 01 Plan 02: GroupWidget Collapsed Refresh Guard and getTimeRange Override Summary

GroupWidget gains a collapsed-state refresh guard (zero CPU cost for hidden widgets) and a getTimeRange() override that aggregates time extents from all children and tabs.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add regression tests for GroupWidget bugs 2 and 5 (TDD RED) | ab5f2da | tests/suite/TestDashboardBugFixes.m |
| 2 | Fix GroupWidget collapsed refresh guard and getTimeRange override | 4b382fc | libs/Dashboard/GroupWidget.m |

## What Was Built

### Fix 1 — Collapsed refresh guard (FIX-02)

`GroupWidget.refresh()` now returns early in the non-tabbed branch when `obj.Collapsed` is true. Before this fix, the method iterated all children on every live timer tick even when they were invisible. This was pure wasted CPU proportional to the number of hidden children.

The guard is placed in the `else` branch only (tabbed mode is separate and does not have a collapsed state).

### Fix 2 — getTimeRange override (FIX-05)

`GroupWidget.getTimeRange()` now overrides the base class no-op and aggregates `[tMin, tMax]` from:
- All direct `Children` (panel/collapsible mode)
- All widgets in all `Tabs{i}.widgets` (tabbed mode)

This uses the same double-loop pattern already established in `setTimeRange()`. Without this override, `DashboardEngine.updateGlobalTimeRange()` could not see data time extents from any widget nested inside a GroupWidget, making the global time panel inoperable for grouped layouts.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- `libs/Dashboard/GroupWidget.m` — FOUND: collapsed guard at line 148, getTimeRange at line 157
- `tests/suite/TestDashboardBugFixes.m` — FOUND: testGroupWidgetCollapsedRefreshSkipsChildren and testGroupWidgetGetTimeRange
- Commits ab5f2da and 4b382fc — FOUND in git log
