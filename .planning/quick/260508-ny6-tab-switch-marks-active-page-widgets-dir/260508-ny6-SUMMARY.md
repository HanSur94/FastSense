---
phase: quick-260508-ny6
plan: 01
subsystem: Dashboard
tags: [dashboard, switchPage, refresh, dirty-flag, GroupWidget, HistogramWidget, regression-test]
requirements_completed: [NY6-01, NY6-02, NY6-03]
dependency_graph:
  requires:
    - libs/Dashboard/DashboardEngine.m :: flattenWidgetsForPreview_
    - libs/Dashboard/DashboardWidget.m :: markDirty, Dirty
    - libs/Dashboard/GroupWidget.m :: refresh recursion into Children/Tabs
  provides:
    - DashboardEngine.switchPage refresh sweep
    - DashboardEngine:switchPageRefreshFailed warning ID
  affects:
    - HistogramWidget, HeatmapWidget, BarChartWidget, ScatterWidget (self-clearing Dirty widgets paint immediately on tab switch)
    - Nested widgets inside GroupWidget on a non-active page
tech-stack:
  added: []
  patterns:
    - "two-pass markDirty(flat) + refresh(top-level) over active page"
    - "DebugPreview_-gated warning for per-widget refresh failure isolation"
key-files:
  created:
    - tests/test_dashboard_switch_page_refresh.m
    - tests/fixtures/ThrowingTextWidget.m
  modified:
    - libs/Dashboard/DashboardEngine.m
    - .planning/STATE.md
decisions:
  - "Sweep block placed inside the `if ~isempty(obj.hFigure) && ishandle(obj.hFigure)` guard, immediately after the `if hasUnrealized; obj.realizeBatch(5); end` line — so widgets are realized before the refresh sweep runs."
  - "Sweep runs BEFORE broadcastTimeRange/computePreviewEnvelope/computeEventMarkers so existing assertions about marker/preview content remain valid (regression sweep confirms)."
  - "ThrowingTextWidget fixture added at tests/fixtures/ThrowingTextWidget.m (subclass of TextWidget) — first fixture under tests/fixtures/, so the test addpath both tests/ and tests/fixtures/."
  - "GroupWidget.Mode in this codebase is 'panel' / 'collapsible' / 'tabbed' (not 'vertical' as the plan suggested). Test uses Mode='panel'."
  - "Sensor binding via 'Sensor' NV pair maps to Tag in DashboardWidget; SensorTag('key', 'X', X, 'Y', Y) builds the sensor."
  - "Test 4 (repeated_marks_dirty) emptyies the axes via cla() before the second switchPage(2). Without that, all four cases pass even without the sweep — realizeBatch's first-time render leaves child handles on the axes that survive subsequent tab switches. The cla() step actually exercises the user-reported 'stuck after tab change' symptom."
metrics:
  duration_minutes: ~22
  tasks_completed: 1
  completed_at: 2026-05-08
---

# Quick Task 260508-ny6: switchPage refresh sweep on active-page widgets Summary

Two-pass markDirty(flat) + refresh(top-level) added to `DashboardEngine.switchPage` so widgets that self-clear `Dirty` (HistogramWidget, HeatmapWidget, BarChartWidget, ScatterWidget) repaint immediately on tab switch instead of staying empty until the next live tick.

## What Changed

### `libs/Dashboard/DashboardEngine.m` (lines 226-258)

Inserted a 33-line block immediately after the `if hasUnrealized; obj.realizeBatch(5); end` line (post-realize) and before the `LastSyncedTimeRange_` re-broadcast block. Block:

```matlab
% 260508-ny6: Force a refresh of every active-page widget (...)
activeWs = obj.Pages{obj.ActivePage}.Widgets;
flatWs = obj.flattenWidgetsForPreview_(activeWs);
for wi = 1:numel(flatWs)
    try
        flatWs{wi}.markDirty();
    catch
    end
end
for wi = 1:numel(activeWs)
    try
        activeWs{wi}.refresh();
    catch err
        if obj.DebugPreview_
            warning('DashboardEngine:switchPageRefreshFailed', ...
                'Widget "%s" refresh failed on tab switch: %s', ...
                activeWs{wi}.Title, err.message);
        end
    end
end
```

The two-pass design is required because `GroupWidget.refresh` recurses into Children/Tabs but does NOT cascade `markDirty` — without the flat sweep, a `HistogramWidget` inside a group whose `Dirty` flag had self-cleared would short-circuit on `if ~obj.Dirty, return; end`.

### `tests/test_dashboard_switch_page_refresh.m` (new, 4 cases)

- `case_switch_page_paints_histogram` — single HistogramWidget on page 2 paints after `switchPage(2)`.
- `case_switch_page_paints_group_children` — two HistogramWidgets inside a panel-mode `GroupWidget` both paint via the cascade.
- `case_switch_page_isolates_failing_widget` — a `ThrowingTextWidget` whose `refresh()` errors does NOT prevent siblings from painting and does NOT propagate.
- `case_switch_page_repeated_marks_dirty` — emptying the axes via `cla()` while `Dirty=false`, then switching pages and back, must repaint. This is the case that actually exercises the bug; tests 1-3 alone all pass even without the fix because realizeBatch's first-time render leaves child handles on the axes that survive subsequent tab switches.

### `tests/fixtures/ThrowingTextWidget.m` (new)

Minimal `TextWidget` subclass whose `refresh()` throws `ThrowingTextWidget:boom`. Used by the isolation test. First fixture under `tests/fixtures/` — the test adds both `tests/` and `tests/fixtures/` to the path.

## Verification Evidence

Single regression run: `matlab -batch "addpath(pwd); install(); test_dashboard_switch_page_refresh(); test_dashboard_preview_overlay(); test_dashboard_engine_event_markers(); test_dashboard_time_sync_all_pages(); test_dashboard_widget_button_bar()"`

| Test file | Result |
|---|---|
| test_dashboard_switch_page_refresh | All 4 tests passed |
| test_dashboard_preview_overlay | All 10 tests passed |
| test_dashboard_engine_event_markers | All 9 tests passed |
| test_dashboard_time_sync_all_pages | 5/5 tests passed |
| test_dashboard_widget_button_bar | 5 passed, 0 failed |

`mh_lint libs/Dashboard/DashboardEngine.m` → "1 file(s) analysed, everything seems fine" (no new lint warnings).

## TDD Cycle

- **RED commit:** `f398fdf` — added the new test file with case 4 explicitly emptying the axes; ran against unmodified DashboardEngine and confirmed `case_switch_page_repeated_marks_dirty` failed with `assert ... 'switchPage must repaint axes that were emptied while clean'`.
- **GREEN commit:** `31a7b94` — added the markDirty/refresh sweep to switchPage; all 4 cases pass; full regression sweep clean.

## Deviations from Plan

1. **Test 4 strengthening (Rule 1 — bug isolation):** The plan's case 4 only set `h.Dirty = false` and asserted axes children non-empty after `switchPage(2)`. That assertion passed even without the fix because realizeBatch's first-time render leaves child handles on the axes that persist across visibility toggles. To actually exercise the user-reported "stuck after tab change" symptom, the test now calls `cla(h.hAxes)` before resetting `Dirty`. With the cla, the test correctly fails on the unmodified engine and passes after the fix. Without this strengthening the regression test would silently pass on a broken engine.
2. **Plan said `Mode='vertical'` for the GroupWidget test (Rule 1 — bug):** Actual valid GroupWidget.Mode values are `'panel'` / `'collapsible'` / `'tabbed'`. Used `Mode='panel'`.
3. **Plan said `Markdown` property on TextWidget (Rule 1 — bug):** Actual TextWidget property is `Content`. Updated all four cases to use `'Content'`.
4. **Plan said `Sensor('Key', name, 'Name', name)` (Rule 3 — blocking):** The legacy `Sensor` class is gone in this codebase; `Sensor` is a backward-compat NV alias for the v2 `Tag` API. Test now uses `SensorTag(name, 'Name', name, 'X', X, 'Y', Y)`.

## Known Stubs

None. The fix is complete and exercised end-to-end by the regression test.

## Self-Check: PASSED

- libs/Dashboard/DashboardEngine.m exists with sweep at lines 226-258
- tests/test_dashboard_switch_page_refresh.m exists (4 cases)
- tests/fixtures/ThrowingTextWidget.m exists
- Commit f398fdf (RED) present in history
- Commit 31a7b94 (GREEN) present in history
- Regression sweep clean across 5 test files
