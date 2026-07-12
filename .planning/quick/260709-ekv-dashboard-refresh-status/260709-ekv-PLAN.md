---
id: 260709-ekv
slug: dashboard-refresh-status
title: Dashboard UI refresh — status: fix all-red MultiStatus dots
status: in_progress
created: 2026-07-09
type: quick
---

# Quick Task 260709-ekv — Status: fix MultiStatus all-red dots

## Goal

The "status pills" step. Primary, visible win: MultiStatusWidget painted every
sensor dot alarm-red. It derived color via `tag.valueAt(now) >= 0.5 -> alarm`,
but that 0/1 mapping is only valid for monitor-kind tags — a plain SensorTag
returns its raw reading (e.g. 72.9), always >= 0.5, so all sensors showed red.

## Tasks

### Task 1 — Gate the alarm mapping on monitor-kind
- **files:** `libs/Dashboard/MultiStatusWidget.m`
- **action:** In both color paths (`deriveColor` bare-tag branch and
  `deriveColorFromTag_`), only apply `>= 0.5 -> alarm` when
  `tag.getKind() == 'monitor'` (polymorphic, Pitfall 1). Non-monitor tags with
  no threshold -> default OK color.
- **verify:** example MultiStatus dots render OK-green (not red); monitor tags
  still alarm; suites green.

## Deferred (with rationale)
- **StatusWidget status pill (OK/WARN/ALARM):** would only render in tall status
  cells — the dashboards here use ~11px status cells where a pill can't fit
  (falls back to the existing dot+label), so no visible change — and StatusWidget
  is resize-fragile (relayout_ SizeChangedFcn). Not worth the surface now; can add
  when there's a taller status widget to show it.

## Must-haves
- Sensor dots reflect real state (not universally red).
- Monitor-kind alarm behavior unchanged.
- Suites green (modulo the pre-existing stale `test_multistatus_widget_tag`).
