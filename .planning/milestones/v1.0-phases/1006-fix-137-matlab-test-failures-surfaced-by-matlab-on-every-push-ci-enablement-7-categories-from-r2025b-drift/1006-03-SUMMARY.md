---
phase: 1006-fix-137-matlab-test-failures-surfaced-by-matlab-on-every-push-ci-enablement-7-categories-from-r2025b-drift
plan: "03"
subsystem: test-suite
tags: [test-drift, bug-fix, dashboard-builder, notifications, event-timeline, composite-threshold]
dependency_graph:
  requires: [1006-01]
  provides: [MATLABFIX-E test fixes — all 21 stale expectations resolved]
  affects: [tests/suite/TestDashboard*, tests/suite/TestNotification*, tests/suite/TestEventTimeline*, tests/suite/TestCompositeThreshold*]
tech_stack:
  added: []
  patterns: [test-delegation-to-library, mock-aware-mouse-position, ghost-panel-preview]
key_files:
  created: [.planning/phases/1006-.../1006-03-E10-DIAGNOSTIC.md]
  modified:
    - tests/suite/TestDashboardEngine.m
    - tests/suite/TestDashboardBugFixes.m
    - tests/suite/TestDashboardBuilder.m
    - tests/suite/TestDashboardBuilderInteraction.m
    - tests/suite/TestDashboardDirtyFlag.m
    - tests/suite/TestCompositeThreshold.m
    - tests/suite/TestNotificationRule.m
    - tests/suite/TestNotificationService.m
    - tests/suite/TestEventTimelineWidget.m
    - libs/Dashboard/DashboardBuilder.m
decisions:
  - "E10: classified TEST-DRIFT (3 root causes), library fix only for dead-code mock infrastructure (getMousePosition wired into computeSnappedGrid)"
  - "E5: testToolbarEditToggle rewritten as testToolbarEditButton — onEdit opens file not toggle"
  - "testResizeMarksDirty renamed testResizeRepositionsPanels — markDirty intentionally removed from resize path in Phase 1000-02"
metrics:
  duration: 35min
  completed: 2026-04-16
  tasks: 3
  files: 10
---

# Phase 1006 Plan 03: Fix ~21 MATLABFIX-E Stale Test Expectations Summary

**One-liner:** Fixed 21 stale MATLAB test expectations across 9 files by aligning tests with completed library renames (kpi→number, KpiWidget removed, warning ID rename) plus a dead-code mock infrastructure fix in DashboardBuilder drag/resize.

---

## Tasks Completed

| Task | Name | Commit | Key Changes |
|------|------|--------|-------------|
| 1 | E1-E9 stale expectations | dccd7f4 | 7 test files, 9 sub-categories |
| 2 | E10 diagnostic | 9b14dcc | 1006-03-E10-DIAGNOSTIC.md |
| 3 | E10 fix (mixed: test + library) | b340855 | DashboardBuilder.m + 3 test files |

---

## Per E-Sub-Category Outcomes

| Sub | Category | File | Change | Expected Result |
|-----|----------|------|--------|-----------------|
| E1 | Constructor call fix | TestDashboardEngine.m | `DashboardEngine('Name','Test')` → `DashboardEngine('Test')` (3 sites) | PASS |
| E2 | isrunning() fix | TestDashboardEngine.m | `isrunning(t)` → `strcmp(t.Running,'on')` | PASS |
| E3 | DELETE testKpiWidgetThemeOverrideMerge | TestDashboardBugFixes.m | Test deleted per D-09 (KpiWidget removed) | N/A — deleted |
| E4 | Default title update | TestDashboardBugFixes.m | `'New KPI'` → `'New Widget'` | PASS |
| E5 | Toolbar behavior change | TestDashboardBuilder.m | Rewrote test; onEdit opens file not toggles button | PASS |
| E6 | Type rename update | TestDashboardBuilder.m | Expected `'kpi'` → `'number'` | PASS |
| E7 | Warning ID update | TestCompositeThreshold.m | `loadChildFailed` → `unknownChildKey` | PASS |
| E8 | Recipients double-wrap | TestNotificationRule.m + TestNotificationService.m | 7 sites: `{{'a@b.com'}}` → `{'a@b.com'}` | PASS |
| E9 | FilterSensors double-wrap | TestEventTimelineWidget.m | 3 sites: `{{'S1'}}` → `{'S1'}` | PASS |
| E10a | Ghost preview drift | TestDashboardBuilder.m | Assert after `onMouseUp()` not `onMouseMove()` | PASS |
| E10b | Dead mock infrastructure | DashboardBuilder.m | Wire `getMousePosition()` into 3 methods | PASS |
| E10c | gridStepSize helper drift | TestDashboardBuilderInteraction.m | Delegate to `layout.canvasStepSizes()` | PASS |
| E10d | markDirty removed from resize | TestDashboardDirtyFlag.m | Updated assertion; verifies no-dirty and panel validity | PASS |

---

## E5 Disposition

E5 was NOT a no-op. `onEdit()` in DashboardToolbar.m no longer toggles button text between 'Edit' and 'Done'. Since quick task `260405-plc`, it opens the dashboard source file in the MATLAB editor (or shows a `warndlg` if no file is set). The test `testToolbarEditToggle` was rewritten as `testToolbarEditButton` to verify:
1. Button label is 'Edit' before and after calling `onEdit()`
2. No toggle behavior remains
3. Warning dialogs created by the test are cleaned up

---

## E10 Classification

**Classification: TEST-DRIFT (3 root causes, 1 library fix)**

| E10 sub | Root Cause | Type | Fix Location |
|---------|-----------|------|-------------|
| testDragSnapsToGrid, testResizeSnapsToGrid | Ghost preview (commit 8fb72f3) moved panel-move from onMouseMove to onMouseUp | TEST-DRIFT | tests only |
| testDragMovesWidgetPosition, testResizeChangesWidthHeight, testDragSnapsToGrid (Interaction) | getMousePosition() defined but never called (dead mock infrastructure) | LIBRARY-BUG | DashboardBuilder.m + tests |
| testResizeMarksDirty | markDirty removed from resize in Phase 1000-02 | TEST-DRIFT | tests only |

Library change: `DashboardBuilder.m` — 3 sites, 9 lines changed — wired `getMousePosition()` into `onDragStart`, `onResizeStart`, `computeSnappedGrid`. Octave-safe (pure property check, no MATLAB-specific API).

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] E10 mock infrastructure wired into library**
- **Found during:** Task 3
- **Issue:** `getMousePosition()` was defined with full MockCurrentPoint logic but never called. `onDragStart`, `onResizeStart`, and `computeSnappedGrid` all used `get(hFig, 'CurrentPoint')` directly. Tests in TestDashboardBuilderInteraction set `MockCurrentPoint` expecting it to be honored.
- **Fix:** Replaced `get(hFig, 'CurrentPoint')` with `obj.getMousePosition()` at 3 call sites in DashboardBuilder.m
- **Files modified:** `libs/Dashboard/DashboardBuilder.m`
- **Commit:** b340855

**2. [Rule 1 - Bug] testFilterSensors in TestEventTimelineWidget had double-wrapped FilterSensors too**
- **Found during:** Task 1 E9 verification check
- **Issue:** Investigation doc mentioned lines 91 and 109, but line 75 (`testFilterSensors`) also used `{{'Pump-101'}}` double-wrap
- **Fix:** Applied same single-wrap fix to line 75
- **Files modified:** `tests/suite/TestEventTimelineWidget.m`
- **Commit:** dccd7f4

---

## Known Stubs

None — all changes are test/fix work, no stub patterns introduced.

---

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| FOUND: TestDashboardEngine.m | PASSED |
| FOUND: TestDashboardBugFixes.m | PASSED |
| FOUND: TestDashboardBuilder.m | PASSED |
| FOUND: DashboardBuilder.m | PASSED |
| FOUND: E10-DIAGNOSTIC.md | PASSED |
| commit dccd7f4 exists | PASSED |
| commit 9b14dcc exists | PASSED |
| commit b340855 exists | PASSED |
| grep DashboardEngine('Name','Test') = 0 | PASSED |
| grep isrunning = 0 | PASSED |
| grep testKpiWidgetThemeOverrideMerge = 0 | PASSED |
| grep 'New KPI' = 0 | PASSED |
| grep loadChildFailed = 0 | PASSED |
| grep unknownChildKey >= 2 | PASSED (2) |
| getMousePosition wired in DashboardBuilder = 4 | PASSED |
| canvasStepSizes in TestDashboardBuilderInteraction >= 2 | PASSED (2) |
