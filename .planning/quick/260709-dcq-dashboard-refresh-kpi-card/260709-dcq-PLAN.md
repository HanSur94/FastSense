---
id: 260709-dcq
slug: dashboard-refresh-kpi-card
title: Dashboard UI refresh — Phase 4: KPI number card
status: in_progress
created: 2026-07-09
type: quick
---

# Quick Task 260709-dcq — Phase 4: KPI number card

## Goal

Replace the cramped horizontal `[Title | Value | Trend | Units]` strip in
NumberWidget with a clean KPI card: title top-left (muted), a big left-aligned
value with an inline unit, and a trend indicator top-right — matching the Pencil
redesign. NumberWidget.relayout_ clears + re-calls render() on resize, so
restructuring render() is relayout-safe.

## Tasks

### Task 1 — Card layout
- **files:** `libs/Dashboard/NumberWidget.m`
- **action:** In `render`, restructure the four uicontrols: title top-left muted
  left-aligned; big value left-aligned (bump adaptive cap 28→34); unit inline
  muted; trend top-right in the accent color. No logic change to refresh/trend.
- **done:** number widgets read as cards; value is the clear focal point.

### Task 2 — Verify (MATLAB)
- render `example_dashboard_all_widgets` (light), exportapp, confirm the
  Temperature/Pressure number widgets read as clean cards, value prominent, no
  clipping/overlap. Run `TestNumberWidget` + `TestDashboardEngine`.

## Must-haves
- Value is the visual focal point; title + unit are secondary/muted.
- Nothing clipped; resize (relayout_) still works.
- refresh()/trend logic unchanged; suites green.
