---
phase: 01-dashboard-engine-code-review-fixes
plan: "04"
subsystem: Dashboard
tags: [cleanup, encapsulation, performance, dead-code]
dependency_graph:
  requires: [01-01, 01-02, 01-03]
  provides: [FIX-09, FIX-11, FIX-12, FIX-13, FIX-14]
  affects: [DashboardLayout, DashboardWidget, DashboardEngine, HeatmapWidget, BarChartWidget, HistogramWidget, DashboardTheme]
tech_stack:
  added: []
  patterns: [in-place-graphics-update, encapsulation-via-accessors, dirty-flag-guard]
key_files:
  created: []
  modified:
    - libs/Dashboard/DashboardLayout.m
    - libs/Dashboard/DashboardWidget.m
    - libs/Dashboard/DashboardEngine.m
    - libs/Dashboard/HeatmapWidget.m
    - libs/Dashboard/BarChartWidget.m
    - libs/Dashboard/HistogramWidget.m
    - libs/Dashboard/DashboardTheme.m
decisions:
  - "markRealized/markUnrealized accessor methods added to DashboardWidget — Realized moved to SetAccess=private to enforce encapsulation"
  - "BarChartWidget YData in-place update uses try-catch for Octave compatibility on bar object property access"
  - "HistogramWidget uses Dirty guard instead of in-place bin updates — bin counts change with every data update making in-place unreliable"
  - "openInfoPopup saves figure callbacks before popup creation — restore pair is symmetric even if current popup opens its own figure"
metrics:
  duration: "2 minutes"
  completed: "2026-04-03T19:39:06Z"
  tasks_completed: 2
  files_modified: 7
---

# Phase 01 Plan 04: Dead Code, Callback Fix, Encapsulation, Graphics Optimization Summary

**One-liner:** Removed stripHtmlTags dead code, saved figure callbacks in openInfoPopup, encapsulated Realized with markRealized/markUnrealized, added in-place CData/YData updates and Dirty guard for HeatmapWidget/BarChartWidget/HistogramWidget, documented FastSenseTheme inherited fields in DashboardTheme header.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Dead code removal, callback fix, Realized encapsulation, theme docs | 2d53b03 | DashboardLayout.m, DashboardWidget.m, DashboardEngine.m, DashboardTheme.m |
| 2 | Optimize graphics widget refresh — in-place updates | 016d332 | HeatmapWidget.m, BarChartWidget.m, HistogramWidget.m |

## What Was Built

**FIX-11 — stripHtmlTags removed:** The private static `stripHtmlTags` method in DashboardLayout was dead code with zero callers. Removed entirely. The `methods (Static, Access = private)` block is retained since `anchorTopRight` remains there.

**FIX-12 — openInfoPopup callback save:** Added explicit save of `WindowButtonDownFcn` and `KeyPressFcn` from the dashboard figure before opening the info popup figure. The save/restore pair is now symmetric — the existing `closeInfoPopup` restore logic has a valid saved value to restore. Also removed the `isfield(theme, 'ForegroundColor')` defensive guard since `ForegroundColor` is guaranteed by FastSenseTheme on all presets.

**FIX-13 — Realized encapsulation:** Moved `Realized = false` from `properties (Access = public)` to a new `properties (SetAccess = private)` block. Added `markRealized()` and `markUnrealized()` public methods to DashboardWidget. Updated callers: `DashboardLayout.realizeWidget()` now calls `widget.markRealized()` and `DashboardEngine.rerenderWidgets()` now calls `w.markUnrealized()`.

**FIX-14 — DashboardTheme header docs:** Added explicit documentation of the FastSenseTheme inherited fields (`ForegroundColor`, `AxesColor`, `AxisColor`, `FontName`, `Background`, `LineColors`, `GridColor`, `GridAlpha`, `MinorGridColor`, `MinorGridAlpha`) as a guaranteed section, separate from the dashboard-specific fields.

**FIX-09a — HeatmapWidget in-place CData:** `refresh()` now checks `~isempty(obj.hImage) && ishandle(obj.hImage)` and calls `set(obj.hImage, 'CData', data)` instead of recreating the imagesc object. Colormap and colorbar are only set on first creation.

**FIX-09b — BarChartWidget in-place YData:** `refresh()` uses a try-catch block (Octave compatibility) to attempt `get(obj.hBars(1), 'YData')` size check and `set(obj.hBars(bi), 'YData', data)` for each series. Falls back to `cla + bar/barh` when dimensions change or bar objects are stale.

**FIX-09c — HistogramWidget Dirty guard:** Histogram bins change with every data update making in-place updates unreliable. Added `if ~obj.Dirty; return; end` early-exit guard at the top of `refresh()` and `obj.Dirty = false` at the end. Prevents redundant full redraws when data has not changed.

## Decisions Made

- **markRealized/markUnrealized pattern:** Chose accessor methods over direct property exposure to enforce the invariant that only the rendering pipeline can mark a widget as realized. This is a common encapsulation pattern for lifecycle state.
- **BarChartWidget try-catch:** Octave's bar objects may not support direct property access like MATLAB's. Used `get(obj.hBars(1), 'YData')` instead of `.YData` and wrapped in try-catch to fall back to full redraw on failure.
- **HistogramWidget no in-place update:** Bin edges depend on data distribution, so bin counts change size on every refresh. In-place update would require matching bin count across refreshes, which is unreliable. Dirty guard gives equivalent performance win for the common case (no change).

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED
