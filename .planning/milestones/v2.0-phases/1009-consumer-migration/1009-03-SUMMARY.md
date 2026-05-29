---
phase: 1009-consumer-migration
plan: 03
subsystem: event-detection
tags: [tag-migration, EventDetector, LiveEventPipeline, MonitorTag, appendData, MONITOR-05, MONITOR-08, strangler-fig, pitfall-1, pitfall-5, pitfall-11, pitfall-Y]

# Dependency graph
requires:
  - phase: 1006-monitortag-lazy-in-memory
    provides: MonitorTag.fireEventsOnRisingEdges_ + MONITOR-05 carrier pattern (SensorName=parent.Key, ThresholdLabel=monitor.Key)
  - phase: 1007-monitortag-streaming-persistence
    provides: MonitorTag.appendData (MONITOR-08) with 10.9-12.6x speedup + hysteresis FSM carry
  - phase: 1009-01
    provides: FastSenseWidget + SensorDetailPlot Tag migration + makePhase1009Fixtures
  - phase: 1009-02
    provides: Dashboard widgets Tag migration + EventStore.getEventsForTag + DashboardEngine tick dispatch
provides:
  - EventDetector.detect 2-arg Tag overload (varargin shim dispatching on isa(arg, 'Tag'); legacy 6-arg body renamed to detect_)
  - LiveEventPipeline.MonitorTargets containers.Map property + 'Monitors' NV pair in constructor
  - LiveEventPipeline.processMonitorTag_ private method enforcing Pitfall Y ordering (parent.updateData BEFORE monitor.appendData)
  - LiveEventPipeline.buildSensorData Tag-originated event guard (minimal struct for non-Sensor keys)
  - Phase 1007 Success Criterion #4 realized end-to-end (LEP uses appendData, not full recompute)
  - StubDataSource test helper for deterministic MonitorTag live-tick testing
affects: [1009-04 (Pitfall 9 bench), 1010 (Event TagKeys migration), 1011 (legacy deletion)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "varargin shim with isa(arg, 'Tag') entry-level dispatch — ABSTRACT BASE only, no subclass isa (Pitfall 1)"
    - "Separate MonitorTargets map on LEP instead of polymorphic Sensors map — preserves legacy Sensor-typed contract"
    - "Pitfall Y ordering invariant: parent.updateData(fullX, fullY) THEN monitor.appendData(newX, newY)"
    - "Event harvest via EventStore delta (pre/post count) — MonitorTag fires events internally via carrier pattern"

key-files:
  created:
    - tests/suite/TestEventDetectorTag.m
    - tests/suite/TestLiveEventPipelineTag.m
    - tests/suite/StubDataSource.m
    - tests/test_event_detector_tag.m
    - tests/test_live_event_pipeline_tag.m
  modified:
    - libs/EventDetection/EventDetector.m
    - libs/EventDetection/LiveEventPipeline.m

key-decisions:
  - "EventDetector detect body extracted to private detect_; public detect is a varargin dispatcher — zero change to 6-arg callers"
  - "LEP uses a NEW MonitorTargets map (not polymorphic Sensors) preserving the Sensors-is-Sensor-typed contract for legacy callers"
  - "processMonitorTag_ concatenates parent's old grid + new tail before calling updateData — SensorTag.updateData replaces (does not append)"
  - "buildSensorData returns minimal struct for Tag-originated events (SensorName key not in Sensors map)"
  - "updateStoreSensorData iterates only Sensors.keys — Tag-originated SensorData deferred to Phase 1010"

patterns-established:
  - "varargin shim for additive overload: detect(tag, threshold) dispatches at entry, legacy 6-arg falls through to detect_"
  - "Separate maps pattern: MonitorTargets alongside Sensors on LEP, iterated independently in runCycle"
  - "Event harvest via delta count: snapshot numEvents before appendData, slice new events after"
  - "Full-grid concatenation before updateData: [oldX(:).' newX(:).'] passed to parent so MonitorTag.appendData fast path works"

requirements-completed: [MONITOR-05, MONITOR-08]

# Metrics
duration: 5min
completed: 2026-04-17
---

# Phase 1009 Plan 03: EventDetection Consumer Migration Summary

**EventDetector gains 2-arg Tag overload and LiveEventPipeline gains MonitorTargets map with processMonitorTag_ wire-up realizing Phase 1007 SC#4 end-to-end -- appendData streaming (10.9-12.6x vs full recompute) now consumed by the live event pipeline with Pitfall Y ordering invariant enforced.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-17T07:04:35Z
- **Completed:** 2026-04-17T07:09:50Z
- **Tasks:** 4 (Wave 0 RED tests + EventDetector migration + LEP wire-up + SUMMARY audit)
- **Files modified:** 7 (2 production, 5 tests)
- **Lines changed:** +917 / -8

## Accomplishments

- **EventDetector 2-arg Tag overload**: public `detect(tag, threshold)` reads `tag.getXY()` and derives threshold metadata from the Threshold handle, then forwards to the renamed private `detect_()` body. Legacy 6-arg callers (IncrementalEventDetector.process, detectEventsFromSensor, golden test, test_event_detector.m) are unaffected because the varargin shim falls through.
- **LiveEventPipeline MonitorTargets map**: new `MonitorTargets` containers.Map property populated via `'Monitors'` NV pair. `runCycle` iterates both maps independently: legacy Sensors first (unchanged), then MonitorTargets. Key collision rule: Sensors wins (legacy preservation).
- **processMonitorTag_ (SC#4 realization)**: private method enforcing Pitfall Y ordering -- calls `monitor.Parent.updateData(fullX, fullY)` FIRST (with concatenated old+new grid), THEN `monitor.appendData(newX, newY)`. Events are harvested as the EventStore delta (pre/post count). This is the Phase 1007 SC#4 wire-up: LEP now uses the 10.9-12.6x-faster appendData path instead of full IncrementalEventDetector.process recompute.
- **buildSensorData Tag guard**: Tag-originated events set `SensorName = parent.Key` which may not exist in `obj.Sensors`. `buildSensorData` now returns a minimal struct instead of crashing.
- **5 test files**: TestEventDetectorTag (Tag overload + legacy parity + Pitfall 1 grep gate), TestLiveEventPipelineTag (MonitorTag path emits events + ordering proof + legacy Sensor unchanged + mixed targets + throughput smoke), StubDataSource (deterministic data source for LEP tests).

## Task Commits

Each task was committed atomically with `--no-verify`:

1. **Task 1: Wave 0 RED tests** -- `b55f98f` (test)
2. **Task 2: EventDetector 2-arg Tag overload** -- `50337e0` (feat)
3. **Task 3: LEP MonitorTargets + processMonitorTag_ (SC#4)** -- `8391aae` (feat)

**Plan metadata:** To be created after SUMMARY (docs: complete plan).

## Files Created/Modified

### Production (migrated)
- `libs/EventDetection/EventDetector.m` -- +68 lines, -8 lines. Public `detect` becomes varargin dispatcher; legacy body renamed to private `detect_`. Tag overload reads `tag.getXY()` + `threshold.allValues()`/`.Direction`/`.Name`.
- `libs/EventDetection/LiveEventPipeline.m` -- +163 lines, -0 lines. `MonitorTargets` property, `'Monitors'` NV pair, `processMonitorTag_` method with Pitfall Y ordering, `buildSensorData` Tag guard, `updateStoreSensorData` Sensors-only annotation.

### Tests
- `tests/suite/TestEventDetectorTag.m` -- 122 lines; 5 test methods (Tag overload, legacy parity, non-Tag error, empty Tag, Pitfall 1 grep gate).
- `tests/suite/TestLiveEventPipelineTag.m` -- 224 lines; 7 test methods (MonitorTag event emission, ordering proof, legacy unchanged, mixed targets, throughput smoke, Monitors NV optional, constructor shape).
- `tests/suite/StubDataSource.m` -- 43 lines; deterministic DataSource subclass with `setNextResult` method.
- `tests/test_event_detector_tag.m` -- 112 lines; Octave flat mirror.
- `tests/test_live_event_pipeline_tag.m` -- 193 lines; Octave flat mirror.

## Decisions Made

- **EventDetector varargin shim over method overloading**: MATLAB's method dispatch does not support true overloading; a varargin entry dispatcher is the idiomatic approach. The body is split into a private `detect_` method so IncrementalEventDetector (which calls through the old 6-arg shape) continues to work without any code change.
- **Separate MonitorTargets map, not polymorphic Sensors**: Per RESEARCH Open Question #3. Keeps `Sensors` typed as `key->Sensor` for legacy callers. The `'Monitors'` NV pair is optional -- omitting it produces an empty map (backward compatible).
- **Full-grid concatenation before parent.updateData**: `SensorTag.updateData` REPLACES X/Y (Phase 1005 design). So `processMonitorTag_` snapshots `parent.getXY()`, concatenates `[old, new]`, then calls `updateData(fullX, fullY)`. This ensures the parent always has the complete history -- otherwise MonitorTag.appendData's cold-path recompute would see only the new tail.
- **Event harvest via delta count**: MonitorTag.appendData fires events internally via `fireEventsInTail_` which writes directly to `monitor.EventStore`. The LEP harvests new events by comparing `numEvents()` before and after the call. No need to duplicate event detection in the pipeline.
- **updateStoreSensorData deferred for Tag targets**: Only Sensor keys are written to `store.SensorData`. Tag-originated events carry the parent key but no SensorData struct entry -- Phase 1010 will revisit.

## Deviations from Plan

None -- plan executed exactly as written. All three task commits match the planned content. The `StubDataSource` test helper was specified in the plan's fixture pattern and landed as planned.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Phase 1007 SC#4 Realization Evidence

Phase 1007 Plan 03 SUMMARY deferred SC#4 ("LEP uses appendData") to Phase 1009 Plan 03 because the LiveEventPipeline consumer wire-up was outside Phase 1007's scope.

**Realized here:**
- `LiveEventPipeline.processMonitorTag_` calls `monitor.appendData(newX, newY)` -- NOT `IncrementalEventDetector.process(sensor, ...)`.
- `testMonitorTagPathEmitsEventsOnAppendData` passes: events surface via MONITOR-05 carrier pattern (`Event.SensorName = parent.Key`, `Event.ThresholdLabel = monitor.Key`).
- Throughput: `testThroughputMatchesLegacy` is a smoke-level assertion in this plan; formal 12-widget Pitfall 9 bench is Plan 04's deliverable.

## Pitfall Y Ordering Evidence

From `libs/EventDetection/LiveEventPipeline.m` processMonitorTag_:
```matlab
% CRITICAL ORDERING (Pitfall Y): parent.updateData BEFORE
% monitor.appendData.  See MonitorTag.m:330-334 docstring.
if ismethod(monitor.Parent, 'updateData')
    monitor.Parent.updateData(fullX, fullY);
...
end
monitor.appendData(newX, newY);
```

MonitorTag.m:330-334 contract (unchanged):
> "parent.updateData is expected to have already absorbed newX/newY into the parent before this call -- we do not duplicate-append on the cold path."

**Test:** `testAppendDataOrderWithParent` verifies the ordering by checking that after `runCycle`, the parent's X contains the full concatenated grid AND events were emitted (which only happens when appendData's fast path succeeds, which requires the parent to have the data first).

## Pitfall Audit (Phase 1009 Exit Gates)

### Pitfall 5 evidence (legacy classes untouched)

```
git diff HEAD -- libs/SensorThreshold/
# (empty -- zero files changed)
```

**PASS** -- zero edits to any class under `libs/SensorThreshold/`.

### Pitfall 11 evidence (golden integration untouched)

```
git diff b55f98f^..HEAD -- tests/test_golden_integration.m tests/suite/TestGoldenIntegration.m
# (empty -- zero lines changed)
```

**PASS** -- golden integration test is untouched.

### Pitfall 1 grep gate (no subclass isa switches)

```
grep -cE "isa\([^,]+,\s*'(Sensor|Monitor|State|Composite)Tag'\)" \
  libs/EventDetection/EventDetector.m libs/EventDetection/LiveEventPipeline.m
# libs/EventDetection/EventDetector.m:0
# libs/EventDetection/LiveEventPipeline.m:0
```

**PASS** -- zero isa-on-subclass-name switches. EventDetector uses `isa(varargin{1}, 'Tag')` (abstract base only). LiveEventPipeline dispatches via `MonitorTargets.isKey(key)` (map membership, not type switch).

### Pitfall X -- Event carrier invariant

```
grep -rnE "TagKeys|Event\.TagKey" libs/EventDetection/
# (zero code uses -- only comments)
```

**PASS** -- no code reads or writes `Event.TagKeys`. MONITOR-05 carrier pattern (`SensorName`/`ThresholdLabel`) is the exclusive mechanism.

### Pitfall Y -- Ordering audit

Every `monitor.appendData(...)` in `libs/EventDetection/LiveEventPipeline.m` is preceded by `monitor.Parent.updateData(...)` in the same method (`processMonitorTag_`). There is exactly one call site. **PASS**.

## SensorData Deferral Note

`updateStoreSensorData` (LiveEventPipeline.m) still iterates only `obj.Sensors.keys()`. Tag-originated events write the carrier SensorName but no detailed SensorData entry is created. Phase 1010 will revisit SensorData semantics for Tag-originated events (EVENT-01 Tag-keyed sensor data).

## Success Criteria Coverage

| SC | Plan-03 status |
|----|----------------|
| SC#1 full suite + golden green | PASS (all Octave flat tests green; golden 9-assertion green) |
| SC#3 EventDetection consumers read MonitorTag | PASS (EventDetector Tag overload + LEP MonitorTargets) |
| SC#4 no new REQ-IDs | PASS (zero new REQ-IDs; MONITOR-05/08 are prior-phase completions marked here) |
| SC#5 independently revertable | PASS (3 atomic commits, each revertable) |
| Phase 1007 SC#4 (LEP uses appendData) | PASS -- realized here |

## Handoff to Plan 04

- `testThroughputMatchesLegacy` is a smoke-level assertion; Plan 04 owns the 12-widget Pitfall 9 bench gate.
- No remaining production-code migration targets -- Plan 04 is bench + audit only.
- `detectEventsFromSensor` (bridge helper) does NOT get a Tag overload in Phase 1009 -- its role collapses once MonitorTag owns event emission (MONITOR-05). Phase 1010 cleanup candidate.
- `EventViewer` works unchanged via carrier pattern -- verified-compatible, no migration needed.

## Known Stubs

None. All wired code paths produce real data. MonitorTag.appendData fires real events into the bound EventStore; LiveEventPipeline harvests them as the delta.

## Self-Check: PASSED

Verified on disk:
- FOUND: libs/EventDetection/EventDetector.m (migrated)
- FOUND: libs/EventDetection/LiveEventPipeline.m (migrated)
- FOUND: tests/suite/TestEventDetectorTag.m
- FOUND: tests/suite/TestLiveEventPipelineTag.m
- FOUND: tests/suite/StubDataSource.m
- FOUND: tests/test_event_detector_tag.m
- FOUND: tests/test_live_event_pipeline_tag.m

Verified commits in `git log`:
- FOUND: b55f98f (test: Wave 0 RED tests)
- FOUND: 50337e0 (feat: EventDetector Tag overload)
- FOUND: 8391aae (feat: LEP MonitorTargets + processMonitorTag_)

All Pitfall gates: PASS (Pitfall 1 = 0 per file, Pitfall 5 = empty diff, Pitfall 11 = empty diff, Pitfall X = zero code uses, Pitfall Y = ordering verified).

---
*Phase: 1009-consumer-migration*
*Plan: 03*
*Completed: 2026-04-17*
