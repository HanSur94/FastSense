---
phase: 1017
plan: 05
subsystem: demo/industrial_plant
tags: [demo-migration, registry-default, event-auto-wiring, tag-system]
dependency_graph:
  requires: ["1017-01", "1017-02", "1017-03", "1017-04"]
  provides: ["demo proves registry-default API is ergonomic end-to-end"]
  affects: ["demo/industrial_plant"]
tech_stack:
  added: []
  patterns: ["registry-default EventStore via TagRegistry.setEventStore"]
key_files:
  created: []
  modified:
    - demo/industrial_plant/private/registerPlantTags.m
    - demo/industrial_plant/private/buildEventsPage.m
decisions:
  - "Single TagRegistry.setEventStore(store) call after EventStore construction replaces four per-instance NV-pairs"
  - "buildEventsPage comment corrected to explain dual-key MonitorTag emission and registry-default fallback chain"
metrics:
  duration: "~5 minutes"
  completed: "2026-04-28"
  tasks_completed: 2
  files_modified: 2
---

# Phase 1017 Plan 05: Demo Industrial Plant Registry-Default Migration Summary

**One-liner:** Industrial plant demo migrated to registry-default pattern — single `TagRegistry.setEventStore(store)` call after `EventStore` construction replaces four per-instance `'EventStore', store` NV-pairs on `MonitorTag`, and `buildEventsPage.m` drops `'EventStoreObj', ctx.store` from `EventTimelineWidget` with the misleading "auto-discovers EventStore from any bound MonitorTag" comment corrected.

## Tasks Completed

| # | Task | Commit | Files Modified |
|---|------|--------|----------------|
| 1 | Migrate registerPlantTags.m to registry-default pattern | 31ca0b8 | demo/industrial_plant/private/registerPlantTags.m |
| 2 | Migrate buildEventsPage.m — drop EventStoreObj NV-pair, fix misleading comment | 270a3a9 | demo/industrial_plant/private/buildEventsPage.m |

## What Was Done

### Task 1: registerPlantTags.m

After `store = EventStore(eventFile);` (line 53), inserted:

```matlab
    % Phase 1017: register the EventStore as the registry default. Every
    % MonitorTag constructed below picks this up via the constructor
    % fallback, and every dashboard widget (FastSense, FastSenseWidget,
    % EventTimelineWidget, TableWidget) auto-discovers it on render.
    TagRegistry.setEventStore(store);
```

Removed `'EventStore', store, ...` from all four `MonitorTag` constructor calls:
- `mFeedlinePressureHigh`
- `mReactorPressureCritical`
- `mReactorTemperatureHigh`
- `mCoolingFlowLow`

Function signature `[store, plantHealthKey] = registerPlantTags(rawDir)` unchanged. `store` is still returned.

### Task 2: buildEventsPage.m

Dropped `'EventStoreObj', ctx.store, ...` from `EventTimelineWidget` construction and updated its `Description` NV-pair to reference the registry default.

Replaced the misleading comment block:

> FastSense core defaults ShowEventMarkers=true and auto-discovers the EventStore from any bound MonitorTag.

With an accurate explanation:

> FastSense.renderEventLayer_ checks the bound SensorTag's own EventStore property first, then falls back to TagRegistry.getEventStore() (the registry default set by registerPlantTags via TagRegistry.setEventStore). It does NOT walk the SensorTag's monitor children — events appear here because MonitorTag emits with dual TagKeys {monitor.Key, parent.Key}, so EventStore.getEventsForTag('reactor.pressure') finds the markers.

Updated function header comment and the EventTimelineWidget inline comment block to remove all references to `ctx.store` and `EventStoreObj`.

## Verification

All success criteria verified:

```
grep -c "'EventStore'" registerPlantTags.m   → 0
grep -c "TagRegistry.setEventStore" registerPlantTags.m  → 1
grep -c "'EventStoreObj'" buildEventsPage.m  → 0
grep -c "auto-discovers EventStore from any bound MonitorTag" buildEventsPage.m  → 0
grep -c "registry default" buildEventsPage.m  → 3
grep -c "InfoText:" buildEventsPage.m  → 5 (all preserved)
```

Octave end-to-end smoke (`registerPlantTags` + `TagRegistry.get('reactor.pressure.critical').EventStore == store`): **PASS**

Headless test suite (`test_demo_industrial_plant_smoke`): **Skipped — Octave lacks MATLAB timer primitive** (expected; not a failure).

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — both files are fully wired to the registry-default pattern.

## Self-Check: PASSED

- [x] `demo/industrial_plant/private/registerPlantTags.m` modified and committed at 31ca0b8
- [x] `demo/industrial_plant/private/buildEventsPage.m` modified and committed at 270a3a9
- [x] All acceptance criteria grep checks return expected values
- [x] Octave registry-default end-to-end test: PASS
