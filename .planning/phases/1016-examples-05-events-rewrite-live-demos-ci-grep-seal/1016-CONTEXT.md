# Phase 1016: Examples 05-events rewrite (live demos + CI grep seal) - Context

**Gathered:** 2026-04-30
**Status:** Ready for planning
**Mode:** Auto-generated (smart discuss — all behavior locked in ROADMAP success criteria; no grey areas)

<domain>
## Phase Boundary

Rewrite the three `examples/05-events/*.m` scripts so each is a working v2.0 Tag-API demo (no `EventConfig` references, no Phase-1011-deleted-class references), and lock the cleanup forever via a CI grep seal in `.github/workflows/tests.yml` that fails on re-introduction of any of the 8 deleted classes.

**Independent of v2.1 phases 1013/1014/1015** — every replacement API ships in v2.0. Placement at end of milestone is so the CI grep gate seals the cumulative v2.1 cleanup.

</domain>

<decisions>
## Implementation Decisions

### Three demos — distinct pedagogical purposes (DEMO-07: no overlap with example_sensor_threshold.m which is the canonical 7-step end-to-end Tag pipeline)

**`example_event_detection_live.m` (DEMO-01, DEMO-02):**
- 3-sensor live demo with `SensorTag + MonitorTag + EventStore + LiveEventPipeline + DashboardEngine`
- Timer bounded: `TasksToExecute=5` + `onCleanup` cleanup wrapper
- Wires `NotificationService(DryRun=true)` for event → notification pedagogical parity with `example_live_pipeline.m`

**`example_event_viewer_from_file.m` (DEMO-03):**
- Batch-build → `EventStore.save` → `EventViewer.fromFile` → click-to-plot detail flow
- No live timer — file-based viewer demo

**`example_live_pipeline.m` (DEMO-04):**
- Existing file is half-broken: orphan comment blocks, `monitors` map keyed on `SensorTag` so `pipeline.runCycle()` doesn't fire events
- Rebuild `monitors` map with `MonitorTag` values
- Remove orphan blocks; restore working pipeline

### Common preamble for all 3 (DEMO-05, DEMO-06)

Each script starts with:
```matlab
TagRegistry.clear();
EventBinding.clear();
```

Octave-portable only — NO `datetime`, `table`, `categorical`, `duration`. Use POSIX timestamps + numeric arrays.

### Header documentation (DEMO-07)

Each file's header comment block must document its distinct pedagogical purpose — no duplication of `example_sensor_threshold.m` (which is the canonical end-to-end demo). Avoid copy-paste headers.

### Skip-list parity (DEMO-08)

`tests/test_examples_smoke.m` and `examples/run_all_examples.m` skip lists must have byte-identical entries for the 3 rewritten demos. Phase 1015's `scripts/check_skip_list_parity.sh` already in CI — will catch drift if either is updated without the other.

**Note:** `tests/test_examples_smoke.m` does not exist on this branch (Phase 1012 P02 lands it on main). Skip-list block additions must happen in `examples/run_all_examples.m`; a follow-up may add the parallel block to `tests/test_examples_smoke.m` once that file lands here. The parity script is defensive — vacuous PASS while smoke file is absent.

### Bounded timers (DEMO-09)

No rewritten demo holds `persistent` variables or unbounded MATLAB timers. `TasksToExecute` cap on every timer.

### CI grep seal (DIFF-01)

Add a step to `.github/workflows/tests.yml` `lint` job that fails CI if any of these 8 classes is referenced in `libs/`, `tests/`, `examples/`:
- `Threshold`
- `CompositeThreshold`
- `StateChannel`
- `ThresholdRule`
- `Sensor`
- `SensorRegistry`
- `ThresholdRegistry`
- `ExternalSensorRegistry`

Exact regex must use word-boundary or `[^.a-zA-Z_]` lookbehind to avoid matching legitimate API surface (e.g., `fp.addThreshold(...)` is the surviving FastSense plot-annotation API; `MonitorTag` references are fine).

### Plan structure

Recommend 2 plans:
1. **1016-01 — 3 demo rewrites + skip-list block.** Per-file commits (4-5 commits).
2. **1016-02 — CI grep seal + final phase verification.** Single CI step + acceptance gates + SUMMARY.

### Claude's Discretion
- Plan-split boundary (could be 1 plan or 2)
- Exact regex shape for the CI grep gate (must satisfy the success criterion's word-boundary intent)
- Detail of the 3-sensor scenario in `example_event_detection_live.m` (sensors, units, ranges) — pick reasonable industrial defaults

</decisions>

<code_context>
## Existing Code Insights

### Files to rewrite
- `examples/05-events/example_event_detection_live.m` (currently uses old API per `EventDetection` library reference)
- `examples/05-events/example_event_viewer_from_file.m` (currently 6-sensor, uses `auto-save to .mat` legacy path)
- `examples/05-events/example_live_pipeline.m` (half-broken — has orphan blocks and SensorTag-keyed monitors map)

### Reusable patterns (from earlier v2.0 / v2.1 work)
- `examples/02-sensors/example_sensor_threshold.m` — canonical 7-step Tag pipeline (DO NOT duplicate, but use as API reference)
- `libs/SensorThreshold/MonitorTag.m` — constructor signature: `MonitorTag(key, parent, conditionFn, ...)` (positional)
- `libs/EventDetection/LiveEventPipeline.m` — entry point for live demos
- `libs/EventDetection/EventViewer.m` — `EventViewer.fromFile(filepath)` static factory
- `libs/EventDetection/EventBinding.m` — singleton, requires `clear()` at top of demos
- `libs/EventDetection/NotificationService.m` — `NotificationService(DryRun=true)` for pedagogical parity
- `libs/SensorThreshold/TagRegistry.m` — `TagRegistry.clear()` at top of demos

### Established patterns
- Per-file commit discipline (Phase 1015 precedent)
- POSIX timestamps + numeric arrays (Octave-portable)
- `examples/run_all_examples.m` is auto-mode by default (Phase 1012 P01)

### Integration points
- `.github/workflows/tests.yml` lint job — already invokes `scripts/check_skip_list_parity.sh` (Phase 1015)
- `examples/run_all_examples.m` skip-list block (location: marker comments per Phase 1012 P01)

</code_context>

<specifics>
## Specific Ideas

- 3 industrial sensor scenario for `example_event_detection_live.m`: pressure (psi, threshold 100), temperature (°C, threshold 80), vibration (Hz, threshold 50) — picks something concrete without being the same as `example_sensor_threshold.m`
- `TasksToExecute=5` is the spec literal — preserve verbatim
- `NotificationService(DryRun=true)` is the spec literal — preserve verbatim

</specifics>

<deferred>
## Deferred Ideas

- Adding `tests/test_examples_smoke.m` parallel skip-list block — that file lands via main branch (Phase 1012 P02 elsewhere); follow-up only if user requests it
- Wider examples/ overhaul — out of v2.1 scope
- Test coverage for the demos beyond smoke runs — out of scope (smoke gate is sufficient)

</deferred>
