---
id: 260709-dcq
slug: dashboard-refresh-kpi-card
status: complete
date: 2026-07-09
commit: 642b704e
---

# Quick Task 260709-dcq — Summary

## What shipped

Phase 4 of the dashboard UI refresh — **adaptive KPI number card**. NumberWidget
now renders a proper card (title top-left muted, big left-aligned value + inline
unit, trend indicator top-right in the accent color) when the cell has real
height, matching the Pencil redesign.

## Adaptive pivot (important)

Dashboard KPI cells are frequently only 1–2 grid rows tall — in the all-widgets
example the number-widget content panel is **~11px**. A stacked card can't fit
there: the value/title font ends up taller than its band and clips to nothing
(same failure class as the Phase 3 header). So `render()` branches on panel pixel
height:

- **`pH >= 55`** → card layout (big value fs≈0.40·pH, inline unit, top trend).
- **`pH < 55`** → the proven compact single-row layout, restored verbatim — no
  regression for short cells.

`relayout_` clears + re-renders on resize, so the right branch is chosen for the
current size automatically.

## Verification (live MATLAB)

- Main example: KPI cells fall back to compact and still show their values
  (`72.9` / `56` present).
- A tall `[1 1 8 8]` number widget exercises the card: value `67.7` at fs=30 in a
  282px box (no clip), title / unit / `▲` trend laid out cleanly (verified via
  control geometry — the small test figure hit a known uifigure capture quirk).
- Suites green: `TestNumberWidget` 12/12, `TestDashboardEngine` 18/18.

## Scope note

StatusWidget / MultiStatusWidget already read acceptably (dot + value); left for a
later polish. `X V A L` button strip + EventTimeline header still deferred.

## Next

Phase 5 — toolbar refresh. Phase 6 — color polish.
