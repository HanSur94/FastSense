---
id: 260708-waf
slug: dashboard-refresh-hide-axes-toolbars
status: complete
date: 2026-07-08
commit: 20dd2559
---

# Quick Task 260708-waf — Summary

## What shipped

Phase 2 of the dashboard UI refresh — **de-clutter**. The redundant floating
MATLAB axes exploration toolbar (download / brush / datatips / pan / zoom-in /
zoom-out / home) no longer appears on dashboard plot widgets. It's pure noise —
the dashboard already has its own controls (widget button bar + time navigator),
and the Pencil redesign removed it.

## Change

- **`libs/Dashboard/DashboardLayout.m`**
  - `realizeWidget`: after each `widget.render(...)`, call the new private static
    helper `hideAxesToolbars_(widget.hCellPanel)`. Central point → covers all 14
    axes-bearing widget types and re-applies on scroll-realize.
  - `hideAxesToolbars_`: `findall(root,'Type','axes')` then set each
    `Toolbar.Visible='off'`, per-axes try/catch.

Scope: **axes-toolbar suppression only.** The `X V A L` axis-toggle + `^`/`+`
button-strip consolidation is deferred to its own phase (interaction-sensitive;
hover-hiding fights uifigure primitives).

## Verification (live MATLAB)

- `example_dashboard_all_widgets` (light, 18 widgets): before/after `exportapp`
  compare — the floating toolbars are gone from every visible plot
  (`scratchpad/phase2_no_toolbars.png` vs `phase1_gutters.png`).
- 3 axes still report `Toolbar.Visible='on'` but are `Visible='off'` overlay axes
  (recreated by resize-time relayout after the realize hook) — they render nothing,
  confirmed by the screenshot.
- Suites green: `TestDashboardLayout` 8/8, `TestDashboardEngine` 18/18,
  `TestScatterWidget` 5/5, `TestHeatmapWidget` 5/5.

## Backward compatibility / safety

Change confined to the central realize hook + one helper; no per-widget edits.
No functional regression — button bar, detach, zoom-via-scroll unaffected.
Standalone (non-dashboard) FastSense plots are untouched (the helper only runs in
the dashboard realize path).

## Next

Phase 3 — card headers & title hierarchy (fix titles overlapping plots; consistent
header row per widget). Then KPI/status cards, toolbar refresh, color polish.
Deferred: the `X V A L`/`^`/`+` button-strip consolidation.
