---
phase: 1012-migrate-examples-to-tag-api
plan: 04
status: complete
commits: 1
files_changed: 4
duration: 6min
---

# Plan 1012-04 Summary — example_sensor_threshold rewrite

## Outcome

Rewrote `examples/02-sensors/example_sensor_threshold.m` as the canonical end-to-end v2.0 event-binding demo. The old half-migrated file (orphan `% Idle: threshold at 70` comments with no code under them) is replaced with a 7-step pipeline exercising the full Tag event chain: **SensorTag → StateTag → MonitorTag (with state-dependent ConditionFn) → EventStore → EventBinding → FastSense round-marker overlay**.

As a side fix, the commit also corrects MonitorTag constructor signatures in three sibling files that used the wrong call form (`MonitorTag(parent, 'Key', ...)` instead of the positional `MonitorTag(key, parent, conditionFn, ...)` required by the actual class). This prevents runtime errors in:
- `examples/02-sensors/example_sensor_todisk.m`
- `examples/02-sensors/tags/example_tag_monitor.m`
- `examples/02-sensors/tags/example_tag_composite.m`

## Acceptance gates

| Gate | Result |
|------|--------|
| Orphan `% Idle:.*threshold at 70` / `Running:.*stricter` / `Evacuated:.*very strict` comments | 0 hits ✓ |
| 7 section headers (`^%% [1-7]\.`) | 7 ✓ |
| `SensorTag('pressure'` with inline `'X'`/`'Y'` NV-pair | present ✓ |
| `StateTag('mode'` constructor | present ✓ |
| `MonitorTag('pressure_alarm'` | present ✓ |
| `'EventStore', store` NV-pair | present ✓ |
| `EventStore(eventFile` positional constructor | present ✓ |
| `EventBinding.getEventsForTag` query | present ✓ |
| `fp.addTag` for both sensor and monitor | present ✓ |
| `fp.addThreshold(...)` visual overlays for 3 state limits | present ✓ |
| `fprintf('Detected %d events...` summary | present ✓ |

## Self-Check: PASSED

- [x] 7-step pipeline matches CONTEXT.md `<specifics>` (line-item parity).
- [x] All 5 tag constructions register via `TagRegistry.register` or `TagRegistry.clear` at the top (defensive for re-runs in same session — Pitfall 1 compliance).
- [x] No orphan comment stubs remain.
- [x] Title / xlabel / ylabel preserved; narrative is clear and single-path.
- [x] MonitorTag positional `(key, parent, conditionFn, ...)` signature used correctly — verified against `libs/SensorThreshold/MonitorTag.m:125`.
- [x] Event-marker overlay relies on the default `ShowEventMarkers=true` (Phase 1010 behavior) — no manual `line(...)` calls.
- [x] Octave-compatible: numeric `StateTag.Y`, pure numeric x-axis, no `datetime`/`categorical`/`disableDefaultInteractivity`.

## Deferred

- Interactive (live-mode) threshold demo with streaming `appendData` — that's a natural follow-on for `examples/05-events/example_live_pipeline.m` (owned by Plan 07).
