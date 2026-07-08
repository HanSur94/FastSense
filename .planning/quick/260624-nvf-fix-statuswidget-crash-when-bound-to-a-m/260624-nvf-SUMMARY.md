---
quick_id: 260624-nvf
title: Fix StatusWidget crash when bound to a MonitorTag via Tag
status: complete
date: 2026-06-24
commit: 14b3d529
---

# Quick Task 260624-nvf — Summary

**Status:** complete

## What changed

- `libs/Dashboard/StatusWidget.m` (constructor): if no `Threshold` is set and the
  bound Tag (`obj.Sensor`, the alias for `obj.Tag`) is monitor-kind, reroute it to
  `obj.Threshold` and clear `obj.Sensor`. `refresh()` then takes the existing
  `deriveStatusFromMonitorTag_` path instead of the SensorTag-only `obj.Sensor.Y`
  access that crashed on a MonitorTag.
- `tests/suite/TestStatusWidget.m`: added `testRefreshWithMonitorTag` — binds a
  MonitorTag via `'Tag'`, renders into an offscreen figure, asserts no render error
  and `CurrentStatus` == `'violation'` (last sample > 0.5) / `'ok'` (<= 0.5).

## Verification (fresh `matlab -batch`, `restoredefaultpath`, this worktree)

- **RED (before fix):** `testRefreshWithMonitorTag` errored with
  `Unrecognized ... 'Y' for class 'MonitorTag'` at `StatusWidget/refresh:119`;
  the other 10 TestStatusWidget tests passed.
- **GREEN (after fix):** `TestStatusWidget` + `TestMultiStatusWidget` +
  `TestMultiStatusWidgetTag` → **23/23**.
- **Regression:** `TestDashboardSerializerRoundTrip` + `TestDashboardBugFixes` +
  `TestDashboardPreview` + `TestInfoTooltip` → **68/68**.
- **End-to-end:** the README "Build a dashboard" snippet
  (`addWidget('status','Tag',alarm,...)` + `d.render()`) renders all 4 widgets,
  no error.

## Backward compatibility

SensorTag-bound (kind `sensor` → reroute guard false → unchanged) and Threshold-bound
(`obj.Threshold` already set → guard skips) status widgets are unchanged. Only the
previously-crashing Tag-bound MonitorTag case changes behaviour.

## Notes

- Code commit: `14b3d529`.
- Unblocks the README dashboard quickstart; the companion `'Label'` → `'Title'` doc
  fix landed earlier in `c0f0d949`.
- Originated from the `/first-run-check` loop (task_693ced52).
