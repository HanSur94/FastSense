---
phase: 1012-migrate-examples-to-tag-api
plan: 05
status: complete
commits: 1
files_changed: 2
duration: 5min
---

# Plan 1012-05 Summary — Migrate examples/03-dashboard to Tag API

## Outcome

One atomic commit (`7e44642`). Fixed both files that still referenced deleted `Sensor.ResolvedViolations` / `.countViolations`:

- **`example_dashboard_all_widgets.m`** — replaced the 4-sensor alarm-log loop with a `MonitorTag + EventStore + EventBinding` pipeline. Each sensor now gets a dedicated `MonitorTag` that emits rising-edge events into a shared `EventStore`; the alarm log is built from `EventBinding.getEventsForTag(sensorKey, store)`. Also replaced `sensor.countViolations()` in the `BarChart` data spec with `numel(EventBinding.getEventsForTag(...))` for Tag-native violation counts. Updated the final fprintf to consume `alarmCounts.values(i)`.
- **`example_dashboard_advanced.m`** — same pattern applied to the 3-sensor alarm table (T-401, P-201, F-301). Shared `EventStore` at `fullfile(tempdir, 'example_dashboard_advanced_alarms.mat')`.

## Acceptance gates

| Gate | Result |
|------|--------|
| `\.ResolvedViolations\|\.ResolvedThresholds\|\.countViolations` executable references in `03-dashboard/` | 0 hits (only comment mentions remain) ✓ |
| Legacy constructor regex in `03-dashboard/` | 0 hits ✓ |
| Both files still parse (no MATLAB syntax errors) | ✓ |

## Self-Check: PASSED

- [x] Exactly 1 atomic commit for the folder (per CONTEXT.md "one commit per folder" lock).
- [x] Narrative preserved — section headers, titles, widget positions unchanged.
- [x] MonitorTag constructor uses positional `(key, parent, conditionFn, ...)` signature verified against `libs/SensorThreshold/MonitorTag.m:125`.
- [x] EventStore path is `tempdir`-rooted (no test pollution).
