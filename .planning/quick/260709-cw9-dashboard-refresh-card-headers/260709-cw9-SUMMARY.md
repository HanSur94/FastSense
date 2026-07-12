---
id: 260709-cw9
slug: dashboard-refresh-card-headers
status: complete
date: 2026-07-09
commit: 9ec3b49e
---

# Quick Task 260709-cw9 — Summary

## What shipped

Phase 3 of the dashboard UI refresh — **title header band**. Widget titles no
longer overlap their plots. Chart widgets used to create a full-panel axes then
`title(ax, obj.Title)`, floating text just above the plot box with a ~10% margin,
so titles collided with the plot / clipped at the panel top. Now the title renders
as a bold header band above the plot area, matching the Pencil redesign.

## Changes

- **`DashboardWidget.m`** — new protected `drawPanelTitle_(parentPanel, theme)`:
  renders `obj.Title` as a bold centered `uicontrol('Style','text')` header band
  (`Position [0.03 0.80 0.94 0.18]`). A sibling uicontrol, so it's immune to the
  `newplot` title-clearing that forced the old in-`refresh` re-apply. Tagged
  `WidgetTitleHeader` and self-deleting so repeated `render()` never stacks dupes.
- **`BarChartWidget` / `HeatmapWidget` / `HistogramWidget` / `ScatterWidget` /
  `EventTimelineWidget`** — draw the header via the helper in `render`; drop the
  axes top to make room; remove the in-axes `title()` calls (both the render and,
  for BarChart/Histogram, the `newplot` re-apply in `refresh`).

## Verification (live MATLAB)

- `example_dashboard_all_widgets` (light): the four main chart titles now sit in
  clean headers above their plots — no overlap/clip (`scratchpad/phase3_headers_v3.png`
  vs the earlier `phase2_no_toolbars.png`).
- Suites green: `TestBarChartWidget` 5/5, `TestHistogramWidget` 6/6,
  `TestScatterWidget` 5/5, `TestHeatmapWidget` 5/5, `TestDashboardEngine` 18/18.

## Gotcha fixed mid-task

First cut used a `0.09`-normalized band → only ~9px in the short (~130px) dashboard
cells, smaller than the ~15px glyphs, so the header text clipped to nothing.
Widened to `0.18` + lowered the axes; renders correctly now.

## Known limitation / deferred

The 1-row-tall `EventTimelineWidget` is too short to show a header cleanly in this
example (its title is now hidden rather than overlapping). Deferred — needs a
min-height or inline title for degenerate cells (task chip filed). `FastSenseWidget`
core-drawn title left as-is (reads fine).

## Next

Phase 4 — KPI/status cards (big value + delta chip; status dot + pill). Then
toolbar refresh, color polish. Deferred: `X V A L` button-strip; timeline header.
