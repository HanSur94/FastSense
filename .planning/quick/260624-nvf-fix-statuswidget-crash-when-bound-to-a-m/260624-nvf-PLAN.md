---
quick_id: 260624-nvf
title: Fix StatusWidget crash when bound to a MonitorTag via Tag
status: complete
date: 2026-06-24
---

# Quick Task 260624-nvf — Fix StatusWidget crash when bound to a MonitorTag via Tag

## Problem

`addWidget('status', 'Tag', monitorTag)` crashed at render with
`Unrecognized method, property, or field 'Y' for class 'MonitorTag'`
(`libs/Dashboard/StatusWidget.m` `refresh`). `DashboardWidget.Sensor` is a
backward-compat **alias for `Tag`**, so a `'Tag'`-bound MonitorTag is read back
through `obj.Sensor`, and the Sensor branch assumes a SensorTag-like `.Y` value
series. MonitorTags are 0/1 alarm signals with no `.Y`. The README
"Build a dashboard" quickstart binds `status` to an alarm MonitorTag and hit this.

## Approach

StatusWidget already supports MonitorTags through the **Threshold/monitor path**
(`deriveStatusFromMonitorTag_`, which reads `obj.Threshold.getXY()`), previously
reachable only when the monitor was passed via the `Threshold` property. Reroute a
monitor-kind Tag to `Threshold` in the constructor so `refresh()` (and the label,
asciiRender, and toStruct paths) use that existing handling. The sibling
`MultiStatusWidget` already supports Tag-bound MonitorTags — this brings StatusWidget
to parity.

## Tasks

1. `libs/Dashboard/StatusWidget.m` — constructor: after Threshold-key resolution,
   if no `Threshold` is set and the bound Tag is monitor-kind
   (`thresholdIsMonitorKind_(obj.Sensor)`), move it to `Threshold` and clear `Sensor`.
   - verify: `TestStatusWidget` passes; README dashboard repro renders without error.
   - done: a monitor-bound status widget renders and `CurrentStatus` reflects the
     monitor's latest 0/1 sample ('violation' / 'ok').
2. `tests/suite/TestStatusWidget.m` — add `testRefreshWithMonitorTag` covering the
   violation (last sample 1) and ok (last sample 0) cases.

## Constraints

Pure MATLAB, toolbox-free; backward compatible (SensorTag-bound and Threshold-bound
status widgets unchanged); pure-MATLAB MEX fallback intact; break no existing test.
