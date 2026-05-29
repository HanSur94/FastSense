---
quick_id: 260513-ovt
description: Preserve Y-axis limits when Follow toggle is engaged
date: 2026-05-13
mode: quick
---

# Plan: Y limits stay untouched while Follow is on

## Problem

When the user enables the dashboard's Follow toggle, the chart's X axis snaps to the data tail (correct behavior). But on each subsequent live tick the Y axis silently rescales itself through `FastSenseWidget.refresh()` → `autoScaleY_(y)`. The user wants Y to stay exactly where it was when Follow engaged.

## Root cause

`libs/Dashboard/FastSenseWidget.m::autoScaleY_` (line 336) recomputes YLim from new sample data on every live tick. It already short-circuits when the user pinned `YLimits` or has manually zoomed Y (`UserZoomedY=true`). It does NOT short-circuit when the underlying `FastSense.LiveViewMode == 'follow'`.

## Fix

Add a third early-return guard in `autoScaleY_`: when `obj.FastSenseObj.LiveViewMode == 'follow'`, treat Follow-on as an implicit "keep Y where I have it." That way:

- Pre-Follow: autoScaleY_ tracks data range as it always has.
- Follow ON: Y axis frozen at whatever it was when user pressed Follow.
- Follow OFF (preserve): autoScaleY_ resumes (unless user manually zoomed Y).

This is the minimal correct change — the X-side Follow behavior (`snapToTail` + `applyViewMode('follow')`) already only touches XLim, so no FastSense change is needed.

## Scope expansion (after user feedback)

Original ask: "Y axis stays untouched when Follow is pressed" — fixed in commit 498a5f3.

Follow-up clarification (same task): the user wants Live mode itself to never mutate XLim or YLim on FastSenseWidgets. Live ticks should only append data; axis limits stay at whatever the user has set. Follow remains the explicit opt-in for "track tail in X."

So in addition to Task 1, two more code paths need to be cut from the live tick:

- `FastSenseWidget.refresh()` and `update()` call `autoScaleY_(y)` after each `updateData` — this is where Y gets re-rescaled to fit fresh samples.
- `DashboardEngine.onLiveTick()` calls `broadcastTimeRange(tStart, tEnd)` every tick — this forces every widget's XLim to the slider's current selection (which expands as data range grows), overriding the user's manual X view.

Removing those two paths keeps the slider's internal data-range tracking AND user-driven broadcast (slider drag, broadcastTimeRangeNow API, Sync-All button) wired up — only the *automatic per-tick override* of widget axes is removed.

## Tasks

### Task 1: Add LiveViewMode='follow' guard to autoScaleY_

- **files:** `libs/Dashboard/FastSenseWidget.m`
- **action:** In `autoScaleY_(obj, y)` (line ~336), after the existing `UserZoomedY` early-return, add:
  ```matlab
  if ~isempty(obj.FastSenseObj) && isvalid(obj.FastSenseObj) ...
          && strcmp(obj.FastSenseObj.LiveViewMode, 'follow')
      return;
  end
  ```
  Place it after the `UserZoomedY` check and before the `IsRendered` check so it short-circuits as early as possible.
- **verify:** `mcp__matlab__check_matlab_code` on the file returns no new warnings.
- **done:** With Follow ON, live ticks no longer change YLim on the FastSenseWidget axes.

### Task 2: Stop autoScaleY_ from running during Live ticks

- **files:** `libs/Dashboard/FastSenseWidget.m`
- **action:** Remove the `obj.autoScaleY_(y);` calls from both `refresh()` (line ~274) and `update()` (line ~300). Initial widget realization still calls `autoScaleY_(yInit)` from `rebuildForTag_` at line ~225, so first-render Y is unchanged.
- **verify:** `mcp__matlab__check_matlab_code` reports no new warnings; `mcp__matlab__run_matlab_test_file` on relevant FastSenseWidget tests still passes.
- **done:** Y axis on every FastSenseWidget is preserved across all live ticks unless the user explicitly pans/zooms.

### Task 3: Stop onLiveTick from broadcasting time range to widgets

- **files:** `libs/Dashboard/DashboardEngine.m`
- **action:** In `onLiveTick` (around line 1693), remove the single line `obj.broadcastTimeRange(tStart, tEnd);`. Keep the surrounding `setDataRange`, `getSelection`, and `updateTimeLabels` calls — they update the slider's internal display state, not widget axes. User-driven broadcast paths (slider drag debounce timer, `broadcastTimeRangeNow` public API, and the manual "Sync all" button) remain intact.
- **verify:** `mcp__matlab__check_matlab_code` reports no new warnings; existing tests `test_dashboard_range_selector_integration` and `test_dashboard_time_sync_all_pages` (which use `broadcastTimeRangeNow`) still pass.
- **done:** XLim on every FastSenseWidget is preserved across live ticks unless the user explicitly drags the slider or clicks Sync All.

## must_haves

- truths:
  - Follow toggle controls X-axis tail tracking only — Y must remain at whatever the user has set.
  - Live mode should append data, never silently mutate axis limits.
  - User-driven paths (manual pan, manual zoom, slider drag, explicit broadcast API) are the only legitimate sources of limit changes.
- artifacts:
  - Modified `libs/Dashboard/FastSenseWidget.m::autoScaleY_` (Task 1) and the two call sites in `refresh()` + `update()` (Task 2)
  - Modified `libs/Dashboard/DashboardEngine.m::onLiveTick` (Task 3)
- key_links:
  - `libs/Dashboard/FastSenseWidget.m:336` — autoScaleY_
  - `libs/Dashboard/FastSenseWidget.m:246` — refresh() called from onLiveTick
  - `libs/Dashboard/FastSenseWidget.m:288` — update() called from onLiveTick for FastSenseWidget
  - `libs/Dashboard/DashboardEngine.m:1601` — onLiveTick
  - `libs/Dashboard/DashboardEngine.m:1693` — broadcastTimeRange to remove
  - `libs/Dashboard/DashboardToolbar.m:288` — applyFollowToWidgets_ sets LiveViewMode='follow'
