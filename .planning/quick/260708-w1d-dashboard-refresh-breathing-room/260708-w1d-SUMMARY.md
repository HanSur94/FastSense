---
id: 260708-w1d
slug: dashboard-refresh-breathing-room
status: complete
date: 2026-07-08
commit: 2b6d44e3
---

# Quick Task 260708-w1d — Summary

## What shipped

Phase 1 of the dashboard UI refresh: **grid breathing room**. The dashboard grid
now has inter-widget gutters + outer canvas padding, so widgets read as separated
cards instead of a flush wall of panels. First and cheapest slice of the approved
Pencil redesign.

## Changes

- **`libs/Dashboard/DashboardTheme.m`** — added three additive shared theme fields:
  `WidgetGapH = 0.006`, `WidgetGapV = 0.010`,
  `DashboardPad = [0.008 0.010 0.008 0.010]` (normalized `[L B R T]`).
- **`libs/Dashboard/DashboardEngine.m`** — before `allocatePanels`, set
  `Layout.GapH/GapV/Padding` from the theme, `isfield`-guarded with fallbacks to
  the new defaults (so older serialized themes still get the spacing).
- **`DashboardLayout.m`** — untouched; `computePosition` already consumes these
  knobs and `allocatePanels` already draws the hairline cell border.

## Verification (live MATLAB)

- Rendered `example_dashboard_all_widgets` (light, 18 widgets): visible gutters +
  edge padding, widgets read as separated cards, no overlap, scrolling intact.
  Screenshot captured (`scratchpad/phase1_gutters.png`).
- Suites green: `TestDashboardLayout` 8/8, `TestDashboardEngine` 18/18,
  `TestDashboardTheme` 6/6.
- `TestDashboardDetach/testDetachButtonInjected` fails — **confirmed pre-existing**
  (fails identically on the clean baseline via git-stash A/B), not a regression.
  Tracked as a separate task.

## Backward compatibility

Additive theme fields only; no field renamed/removed. Dashboards built with a
directly-constructed `DashboardLayout` (no theme) keep `Gap=0`. Existing dashboards
still render — just spaced.

## Next (redesign roadmap)

Phase 2 — de-clutter widget chrome (hide axes toolbars + collapse the per-widget
`X V A L` button strip). Phases 3–6: card headers, KPI/status cards, toolbar
refresh, color polish. See the Pencil frames "FastSense — Current UI (as-is)" and
"FastSense — Redesigned UI".
