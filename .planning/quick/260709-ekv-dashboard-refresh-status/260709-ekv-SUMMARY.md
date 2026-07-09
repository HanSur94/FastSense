---
id: 260709-ekv
slug: dashboard-refresh-status
status: complete
date: 2026-07-09
commit: b43aa3a6
---

# Quick Task 260709-ekv — Summary

## What shipped

Fixed a real correctness/visual bug: **MultiStatusWidget painted every sensor dot
alarm-red.** Color was derived via `tag.valueAt(now) >= 0.5 -> alarm`, but that
binary 0/1 mapping is only valid for monitor-kind tags. A plain `SensorTag`
returns its raw reading (e.g. 72.9 °F), always `>= 0.5`, so all sensors showed red
regardless of state.

## Change

- **`libs/Dashboard/MultiStatusWidget.m`** — in both color paths (`deriveColor`
  bare-tag branch and `deriveColorFromTag_`), gate the `>= 0.5 -> alarm` mapping on
  `tag.getKind() == 'monitor'` (polymorphic; Pitfall 1 — no isa-on-subclass).
  Non-monitor tags with no threshold now fall to the default OK color.

## Verification (live MATLAB)

- `example_dashboard_all_widgets`: MultiStatus dots now **OK-green ×5, alarm-red ×0**
  (were all red).
- Monitor-kind alarm behavior preserved: `TestMultiStatusWidgetTag` 7/7,
  `test_multistatus_monitortag_bare` 4/4.
- Pre-existing unrelated failure noted: `test_multistatus_widget_tag` references the
  removed `Threshold` class (v2.0 Tag migration) and errors at setup — not touched
  by this change.

## Deferred

StatusWidget status pill (OK/WARN/ALARM): would only render in tall status cells,
but these dashboards use ~11px status cells (pill can't fit → falls back to the
existing dot+label, no visible change), and StatusWidget is resize-fragile. Left
for when there's a taller status widget to show it.

## Status of the UI refresh

Phases 1–4 + tab-contrast fix + this MultiStatus fix shipped on PR #375. Toolbar
restyle (Phase 5 cosmetic) and remaining deferred items (X V A L strip, EventTimeline
header, StatusWidget pill) still open.
