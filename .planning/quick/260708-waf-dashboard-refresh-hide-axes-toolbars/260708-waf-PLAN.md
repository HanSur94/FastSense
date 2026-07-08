---
id: 260708-waf
slug: dashboard-refresh-hide-axes-toolbars
title: Dashboard UI refresh — Phase 2 (de-clutter): hide per-axes MATLAB toolbars
status: in_progress
created: 2026-07-08
type: quick
---

# Quick Task 260708-waf — Phase 2: hide the floating axes toolbars

## Goal

De-clutter the dashboard by removing the redundant floating MATLAB axes
exploration toolbar (download / brush / datatips / pan / zoom-in / zoom-out /
home) that renders on every plot widget. The dashboard already provides its own
controls (per-widget button bar + time navigator), so the per-axes toolbar is
pure visual noise — the approved Pencil redesign removes it entirely.

Scope note: this phase is **only** the axes-toolbar suppression. The `X V A L`
axis-toggle + `^`/`+` button-strip consolidation (hover/overflow) is deferred to
its own phase — it is interaction-sensitive and hover-hiding fights MATLAB's
uifigure primitives, so it deserves separate, careful work.

## Tasks

### Task 1 — Central suppression hook
- **files:** `libs/Dashboard/DashboardLayout.m`
- **action:** In `realizeWidget` (the single central point every widget renders
  through), after `widget.render(...)` and before `widget.markRealized()`, call a
  new private static helper `hideAxesToolbars_(widget.hCellPanel)`. The helper does
  `findall(root,'Type','axes')` and sets each axes' `Toolbar.Visible = 'off'`,
  per-axes try/catch so a toolbar-less or stale axes never aborts the realize pass.
  Central placement covers all 14 axes-bearing widget types and re-applies on
  scroll-realize.
- **verify:** rendered dashboard shows no floating axes toolbars; widgets still
  render; no errors.
- **done:** toolbars gone across all plot widgets.

### Task 2 — Verify (MATLAB, orchestrator-run)
- **files:** none
- **action:** render `example_dashboard_all_widgets` (light), exportapp screenshot,
  confirm the 7-icon axes toolbars are gone from the plots. Run
  `TestDashboardEngine`, `TestDashboardLayout`, and a couple of plot-widget suites
  (`TestScatterWidget`/`TestHistogramWidget`) to confirm rendering still works.
- **done:** visual confirms toolbars gone; suites green (modulo known-env failures).

## Must-haves
- Floating axes toolbars no longer appear on dashboard plot widgets.
- All widgets still render; no functional regression (button bar, zoom via scroll,
  detach, etc. unaffected).
- Change confined to the central realize hook + one helper; no per-widget edits.
- Standalone (non-dashboard) FastSense plots are unaffected (helper only runs in
  the dashboard realize path).
