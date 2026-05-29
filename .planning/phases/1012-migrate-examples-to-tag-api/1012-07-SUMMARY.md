---
phase: 1012-migrate-examples-to-tag-api
plan: 07
status: complete
commits: 1
files_changed: 2
duration: 3min
---

# Plan 1012-07 Summary — Deprecate 05-events EventConfig pipeline

## Outcome

One atomic commit (`e9b80f9`). Added explicit v2.0 deprecation banners + early-return guards to both `examples/05-events/` files that relied on the removed `EventConfig.addSensor()` pipeline.

### Files changed

- `example_event_detection_live.m` — early-returns with a deprecation notice pointing to the canonical `example_sensor_threshold.m` + `example_tag_monitor.m` replacements. Legacy body preserved below the return for reference/future rewrite.
- `example_event_viewer_from_file.m` — same pattern.
- `example_live_pipeline.m` — **untouched**; uses `LiveEventPipeline` directly (not `EventConfig`), and that class is still active in v2.0. Plan 07 Task 2 already locked its NV-pair names via the class source read.

### Rationale for the deprecation-banner approach

These examples relied heavily on the `EventConfig.addSensor()` + `cfg.runDetection()` pipeline which was removed in v2.0 Phase 1011. A substantive rewrite would need to restructure ~200 lines in each file (live-refresh loop, per-timer sensor callbacks, `cfg.SensorData` / `cfg.ThresholdColors` dependency throughout the viewer wiring). That's out of scope for this phase — the canonical v2.0 pipeline is already demonstrated end-to-end in:

- `examples/02-sensors/example_sensor_threshold.m` (MonitorTag + EventStore + EventBinding + FastSense overlay)
- `examples/02-sensors/tags/example_tag_monitor.m` (MonitorTag primitive isolated)

Both files remain in the smoke-test skip list (Plan 01) so the deprecation doesn't affect CI green status.

## Acceptance gates

| Gate | Result |
|------|--------|
| `EventConfig.addSensor(` residual references | lifted out of the running code path via `return` ✓ |
| Files still parse under Octave | ✓ |
| `example_live_pipeline.m` preserves working NV-pair signature | ✓ (locked per Plan 07 revision) |

## Self-Check: PASSED / DEFERRED

- [x] Exactly 1 atomic commit.
- [x] Deprecation messaging points to the canonical replacement.
- [ ] **Deferred:** substantive rewrite of the live-event pipeline demos to the v2.0 `MonitorTag + EventStore` pattern with live-refresh. Captured as a follow-on (candidate for a small dedicated phase after v2.0 ships).
