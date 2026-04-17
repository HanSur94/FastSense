---
phase: 1006-monitortag-lazy-in-memory
verified: 2026-04-16T20:04:00Z
status: passed
score: 6/6 success criteria verified; 12/12 requirements satisfied; 9/9 pitfall gates PASS
re_verification: null
---

# Phase 1006: MonitorTag (lazy, in-memory) Verification Report

**Phase Goal:** Replace side-effect violation pipeline inside Sensor.resolve() with a first-class MonitorTag derived signal — lazy-by-default, parent-driven invalidated, debounce + hysteresis, no disk persistence.
**Verified:** 2026-04-16T20:04:00Z
**Status:** PASSED
**Re-verification:** No (initial verification)

## Goal Achievement

### Observable Truths / Success Criteria

| # | Success Criterion | Status | Evidence |
| - | ----------------- | ------ | -------- |
| 1 | MonitorTag(key, parent, fn) -> getXY returns lazy memoized binary 0/1 series | VERIFIED | MonitorTag.m:92-160 (constructor + getXY + recompute_); `recomputeCount_` SetAccess=private probe proves cache hit on 2nd read; `test_monitortag` + `TestMonitorTag` cover 26 methods incl. testLazyMemoize, testGetXYBinaryAlignedToParentGrid |
| 2 | parent.updateData() -> dependent MonitorTag cache invalidated observably | VERIFIED | SensorTag.m:170 addListener, :185 updateData, :197 notifyListeners_ (identical pattern in StateTag.m:140/153/170); MonitorTag constructor registers self via parentTag.addListener(obj); testParentUpdateDataInvalidates + testRecursiveMonitorInvalidation GREEN |
| 3 | MinDuration=5 -> violations <5s produce no events (debounce) | VERIFIED | MonitorTag.m:352 applyDebounce_ + :365 findRuns_; strict-less-than filter matches EventDetector.m:52; testMinDurationFiltersShortPulse (2-unit pulse -> 0 events) + testMinDurationKeepsLongPulse (7-unit pulse -> 1 event) GREEN |
| 4 | Alarm-on/alarm-off conditions -> no chatter at boundary (hysteresis) | VERIFIED | MonitorTag.m:333 applyHysteresis_ two-state FSM; testHysteresisSuppressesChatter reduces 10 raw edges to 1 on sinusoid at threshold; testHysteresisEmptyAlarmOffPreservesRaw covers no-hysteresis path |
| 5 | 0->1 transitions fire Event with TagKeys carriers (SensorName + ThresholdLabel pre-Phase-1010) | VERIFIED | MonitorTag.m:403 `Event(startT, endT, char(obj.Parent.Key), char(obj.Key), NaN, 'upper')`; :405 obj.EventStore.append(ev); testSingleRisingEdgeFiresEvent asserts SensorName=='p', ThresholdLabel=='m'; Event.m confirms TagKeys field does NOT exist yet (grep count 0) — carrier pattern is architecturally correct for Phase 1006 |
| 6 | Aggregation vs child StateTag uses ZOH only; pre-history drop | VERIFIED | `interp1.*'linear'` grep on MonitorTag.m returns 0; ALIGN-01..04 all documented in class header; valueAt uses ZOH via binary_search 'right'; NaN handling proven (ALIGN-04) |

**Score: 6/6 success criteria verified.**

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| libs/SensorThreshold/MonitorTag.m | concrete < Tag class with lazy-memoize + four-stage recompute_ + observer cascade + resolveRefs | VERIFIED | 500 lines; classdef MonitorTag < Tag (1 match); all 6 Tag contract methods present; 4 private helpers (applyHysteresis_, applyDebounce_, findRuns_, fireEventsOnRisingEdges_) wired into recompute_ |
| libs/SensorThreshold/SensorTag.m | additive listeners_ + addListener + updateData + notifyListeners_ | VERIFIED | listeners_={} at line 27; addListener at 170; updateData at 185; notifyListeners_ at 197; git diff shows ADDITIVE only (1 whitespace-alignment line recognized as non-semantic in Plan 01 SUMMARY) |
| libs/SensorThreshold/StateTag.m | same additive surface | VERIFIED | listeners_={} at line 42; addListener at 140; updateData at 153; notifyListeners_ at 170; additive only |
| libs/SensorThreshold/TagRegistry.m | case 'monitor' + updated error message | VERIFIED | TagRegistry.m:352-353 case 'monitor' -> MonitorTag.fromStruct(s); :356 "Valid kinds (Phase 1006): mock, sensor, state, monitor" |
| libs/FastSense/FastSense.m | addTag case 'monitor' via tag.getXY -> addLine | VERIFIED | FastSense.m:973-975 case 'monitor': [x,y]=tag.getXY(); obj.addLine(...); identical shape to sensor case; NO isa subclass checks anywhere (Pitfall 1 preserved) |
| tests/suite/TestMonitorTag.m | 26 unittest methods incl. grep gates | VERIFIED | 346 lines |
| tests/suite/TestMonitorTagEvents.m | 12 unittest methods for debounce/hysteresis/events | VERIFIED | 234 lines |
| tests/test_monitortag.m | Octave flat mirror | VERIFIED | 233 lines; runs GREEN |
| tests/test_monitortag_events.m | Octave flat mirror | VERIFIED | 180 lines; runs GREEN |
| benchmarks/bench_monitortag_tick.m | Pitfall 9 gate (12 x 10k x 50 x min-of-3) | VERIFIED | 104 lines; PASS with -70.2% overhead on live run (MonitorTag 3.4x FASTER than Sensor.resolve) |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| MonitorTag.m | Tag base class | classdef MonitorTag < Tag; obj@Tag(key, tagArgs{:}) first statement | WIRED | grep confirms 1 classdef match; obj@Tag super-call present |
| MonitorTag constructor | parent.addListener(obj) | parentTag.addListener(obj) after property assignment | WIRED | confirmed in MonitorTag.m ctor body |
| SensorTag.updateData | MonitorTag.invalidate | notifyListeners_ iterates listeners_{i}.invalidate() | WIRED | :185 updateData calls :197 notifyListeners_ which calls .invalidate on each listener; tested end-to-end |
| StateTag.updateData | MonitorTag.invalidate | same pattern | WIRED | tested via testParentUpdateDataInvalidates |
| MonitorTag.fireEventsOnRisingEdges_ | EventStore.append | obj.EventStore.append(ev) in rising-edge loop | WIRED | MonitorTag.m:405; testSingleRisingEdgeFiresEvent asserts events after getXY |
| MonitorTag.fireEventsOnRisingEdges_ | Event constructor (carrier pattern) | Event(startT, endT, char(obj.Parent.Key), char(obj.Key), NaN, 'upper') | WIRED | MonitorTag.m:403; SensorName + ThresholdLabel carriers since Event.TagKeys does not exist pre-Phase-1010 |
| FastSense.addTag | MonitorTag.getXY | case 'monitor': [x,y]=tag.getXY(); obj.addLine(x,y,'DisplayName',tag.Name,...) | WIRED | FastSense.m:973-975; smoke test `Lines: 1` confirms no throw |
| TagRegistry.instantiateByKind | MonitorTag.fromStruct | case 'monitor': tag = MonitorTag.fromStruct(s) | WIRED | TagRegistry.m:352-353; testRoundTripMonitorTag (forward + reverse) GREEN |
| TagRegistry.loadFromStructs Pass-2 | MonitorTag.resolveRefs | existing two-phase loader calls tag.resolveRefs(map) | WIRED | MonitorTag.resolveRefs override swaps dummy MockTag parent for the real registered handle + re-registers listener |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| MonitorTag.getXY cache.x / cache.y | obj.cache_ struct | obj.Parent.getXY() in recompute_; py -> ConditionFn(px, py) | YES — parent SensorTag.X/.Y via Sensor_, real user data | FLOWING |
| MonitorTag event emission | ev Event object | fireEventsOnRisingEdges_ called every recompute_ when EventStore/OnEventStart/OnEventEnd bound | YES — real timestamps (px(sI(k)) / px(eI(k))) in native parent-X units | FLOWING |
| FastSense.addTag monitor case | x, y for addLine | tag.getXY() on live MonitorTag | YES — 0/1 binary series from real recompute | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| test_monitortag + test_monitortag_events pass on live Octave | `octave --no-gui --eval "install(); cd tests; test_monitortag(); test_monitortag_events();"` | "All test_monitortag tests passed." + "All test_monitortag_events tests passed." | PASS |
| test_tag_registry includes monitor round-trip (14 tests) | `octave --no-gui --eval "install(); cd tests; test_tag_registry();"` | "All 14 test_tag_registry tests passed." | PASS |
| test_golden_integration still GREEN (Pitfall 11 lock) | `octave --no-gui --eval "install(); cd tests; test_golden_integration();"` | "All 9 golden_integration tests passed." | PASS |
| Pitfall 9 benchmark asserts overhead_pct <= 10 | `octave --no-gui --eval "install(); bench_monitortag_tick();"` | "Overhead: -70.2% ... PASS: <= 10% regression gate satisfied." | PASS |
| FastSense.addTag dispatches MonitorTag | `octave --no-gui --eval "... fp.addTag(m); fprintf('Lines: %d', numel(fp.Lines));"` | "Lines: 1" (no throw) | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description (from REQUIREMENTS.md) | Status | Evidence |
| ----------- | ----------- | ----------------------------------- | ------ | -------- |
| MONITOR-01 | 1006-01 | Binary 0/1 output via getXY on parent grid | SATISFIED | MonitorTag.m recompute_; testGetXYBinaryAlignedToParentGrid |
| MONITOR-02 | 1006-03 | isa Tag + getKind=='monitor' + FastSense plot + TagRegistry round-trip | SATISFIED | classdef < Tag; case 'monitor' in FastSense.addTag + TagRegistry.instantiateByKind; testRoundTripMonitorTag forward+reverse GREEN |
| MONITOR-03 | 1006-01 | Lazy memoize via dirty_ + cache_ | SATISFIED | recomputeCount_ probe proves single recompute on repeat getXY |
| MONITOR-04 | 1006-01 | Parent-driven invalidation | SATISFIED | addListener/notifyListeners_ on SensorTag + StateTag; recursive cascade proven |
| MONITOR-05 | 1006-02 | 0->1 Event with TagKeys carriers | SATISFIED | Event(... char(obj.Parent.Key), char(obj.Key), NaN, 'upper') — SensorName + ThresholdLabel carriers since Event.TagKeys does not exist pre-Phase-1010; Phase 1010 (EVENT-01) migrates to TagKeys |
| MONITOR-06 | 1006-02 | MinDuration debounce | SATISFIED | applyDebounce_ + findRuns_ + strict-less-than filter |
| MONITOR-07 | 1006-02 | Hysteresis | SATISFIED | applyHysteresis_ two-state FSM |
| MONITOR-10 | 1006-01 | No per-sample callbacks (only OnEventStart/OnEventEnd) | SATISFIED | grep PerSample/OnSample/onEachSample returns 0 |
| ALIGN-01 | 1006-01 | No interp1 linear | SATISFIED | grep interp1.*'linear' returns 0 |
| ALIGN-02 | 1006-01 | Single-parent grid | SATISFIED | recompute uses parent.getXY() directly |
| ALIGN-03 | 1006-01 | ZOH semantics | SATISFIED | valueAt uses binary_search 'right'; documented in header |
| ALIGN-04 | 1006-01 | NaN handling | SATISFIED | testNaNInParentY: NaN>threshold is false (IEEE 754 default) |

**12/12 requirements satisfied.**

### Pitfall Gate Summary

| Gate | Verdict | Evidence |
| ---- | ------- | -------- |
| Pitfall 1 (no isa subclass checks in FastSense.m) | PASS | `isa\s*\([^,]*,\s*'(SensorTag|StateTag|MonitorTag)'` count 0 |
| Pitfall 2 code (no FastSenseDataStore/storeMonitor/storeResolved in MonitorTag.m) | PASS | grep count 0 |
| Pitfall 2 doc ("lazy-by-default, no persistence" in MonitorTag.m header) | PASS | grep count 2 |
| Pitfall 5 file-count (<=12 files touched vs baseline 802a156) | PASS | 12/12 exactly (at cap; 0 margin) |
| Pitfall 5 legacy byte-for-byte unchanged (14 legacy + EventDetection files) | PASS | `git diff 802a156..HEAD -- <list>` returns 0 lines |
| Pitfall 5 no .TagKeys in MonitorTag.m | PASS | grep count 0 — carrier pattern (SensorName + ThresholdLabel) used instead |
| Pitfall 7 (super-call ordering in MonitorTag ctor) | PASS | NV parse via splitArgs_ BEFORE obj@Tag(key, tagArgs{:}) first statement |
| Pitfall 8 (two-phase loader order-insensitive for 'monitor' kind) | PASS | testRoundTripMonitorTag forward + reverse both GREEN |
| Pitfall 9 (MonitorTag tick <= 110% Sensor.resolve baseline) | PASS | live-run -70.2% overhead (MonitorTag 3.4x FASTER); gate has enormous margin |
| Pitfall 11 (golden integration locked) | PASS | test_golden_integration 9/9 GREEN on live run |
| MONITOR-10 (no per-sample callbacks) | PASS | grep count 0 |
| ALIGN-01 (no interp1 linear in MonitorTag) | PASS | grep count 0 |

### Anti-Patterns Found

None. Scan results:

| File | TODO/FIXME | Hardcoded empty | Console/printf only | Severity |
| ---- | ---------- | --------------- | ------------------- | -------- |
| libs/SensorThreshold/MonitorTag.m | 0 | 0 | 0 | clean |
| libs/SensorThreshold/SensorTag.m | 0 new (additive) | 0 | 0 | clean |
| libs/SensorThreshold/StateTag.m | 0 new (additive) | 0 | 0 | clean |
| libs/SensorThreshold/TagRegistry.m | 0 (2-line case extension + 1 message literal) | 0 | 0 | clean |
| libs/FastSense/FastSense.m | 0 (3-line case extension) | 0 | 0 | clean |
| benchmarks/bench_monitortag_tick.m | 0 | 0 | fprintf for benchmark report only | clean |

### Pre-Existing Unrelated Failure

`tests/test_to_step_function.m` (testAllNaN) — documented in Plan 03 SUMMARY as failing identically on the base tree (confirmed via git stash). Unrelated to Tag migration / MonitorTag / FastSense.addTag. Phase 1005-02 SUMMARY documented the same failure. Out of scope per executor report; NOT a Phase 1006 regression.

### Human Verification Required

None. All success criteria, requirements, and pitfall gates verified programmatically on live Octave runs. The Event.TagKeys carrier pattern is architecturally sound for Phase 1006:

- Event.m currently has ZERO TagKeys references (grep confirmed).
- The carrier pattern (SensorName=parent.Key, ThresholdLabel=monitor.Key) uses the existing stable Event constructor unchanged.
- Phase 1010 (EVENT-01) is explicitly the designated migration pivot — the single call site at MonitorTag.m:403 will update to the new constructor signature.
- The research/context documents explicitly document this deferral; Plan 02 SUMMARY captures the migration path; the .TagKeys grep gate enforces absence.

This is deliberate scope management, not a gap. No human verification is needed — the implementation matches the documented contract exactly.

### Gaps Summary

None. Phase 1006 achieved its full goal: MonitorTag is a first-class, lazy-by-default, parent-invalidated derived signal with debounce + hysteresis + event emission, no disk persistence, legacy pipeline fully untouched, and the Pitfall 9 performance gate passed with overwhelming margin (MonitorTag is 3.4x FASTER than legacy Sensor.resolve at 12-widget live-tick workload).

---

*Verified: 2026-04-16T20:04:00Z*
*Verifier: Claude (gsd-verifier)*
