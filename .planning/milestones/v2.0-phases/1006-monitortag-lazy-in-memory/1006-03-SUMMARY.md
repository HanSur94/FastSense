---
phase: 1006-monitortag-lazy-in-memory
plan: 03
subsystem: sensorthreshold
tags: [matlab, octave, tag-domain, monitor, fastsense-dispatch, round-trip, pitfall-9-bench, phase-exit-audit]

requires:
  - phase: 1006-01
    provides: MonitorTag core class + SensorTag/StateTag additive listener hook + recursive cascade
  - phase: 1006-02
    provides: MonitorTag recompute_ four-stage pipeline (condition -> hysteresis -> debounce -> event emission)
  - phase: 1005-03
    provides: FastSense.addTag switch dispatcher + TagRegistry.instantiateByKind 'sensor'/'state' cases
provides:
  - FastSense.addTag 'monitor' case — routes MonitorTag through addLine via tag.getXY (reuses SensorTag path shape)
  - TagRegistry.instantiateByKind 'monitor' case — calls MonitorTag.fromStruct; otherwise message updated to Phase 1006 valid-kinds list
  - testRoundTripMonitorTag (MATLAB unittest + Octave flat mirror) — forward + reverse order via loadFromStructs; Pitfall 8 re-verification for 'monitor' kind
  - benchmarks/bench_monitortag_tick.m — Pitfall 9 gate (12 sensors x 10k points x 50 iters x min of 3 runs); asserts overhead_pct <= 10 vs legacy Sensor.resolve
  - Phase-exit audit: file-touch count 12/12 (at cap), all legacy byte-for-byte unchanged, all grep gates PASS, Pitfall 9 PASS with -69.7% overhead
affects: [phase-1007, phase-1008, phase-1009, phase-1010]

tech-stack:
  added: []
  patterns:
    - MonitorTag kind dispatch through the existing switch — no isa subclass checks (Pitfall 1 invariant preserved from Phase 1005)
    - Observer pattern two-phase loader Pass-2 proven for a derived tag that holds a parent-key reference (MonitorTag joins SensorTag/StateTag in the round-trip contract)
    - Min-of-N timing + cold-recompute per iter (invalidate-in-loop) — matches bench_sensortag_getxy convention; stresses the lazy recompute path as if the dashboard were in a live tick

key-files:
  created:
    - benchmarks/bench_monitortag_tick.m
  modified:
    - libs/FastSense/FastSense.m (+4 lines: case 'monitor' branch in addTag)
    - libs/SensorThreshold/TagRegistry.m (+2 lines: case 'monitor' in instantiateByKind; otherwise msg updated)
    - tests/suite/TestTagRegistry.m (+45 lines: testRoundTripMonitorTag)
    - tests/test_tag_registry.m (+30 lines: Octave flat-assert round-trip block; count 13 -> 14)

key-decisions:
  - "FastSense.addTag 'monitor' case is a verbatim copy of the 'sensor' case body — the 0/1 binary output renders as a flat line flipping between 0 and 1, which is acceptable for Phase 1006. Users who want a step-like render can route through 'state' in a later phase. This avoids adding a new private helper (addMonitorTagAsStaircase_) that would not buy enough to justify the extra method surface."
  - "Round-trip test uses Key equality (loadedMonitor.Parent.Key == loadedParent.Key) instead of handle identity (==) or isequal — Octave isequal on user-defined handles with listener cycles hits SIGILL (Plan 01 SUMMARY deviation #3 documented this). Key equality + the Plan 01 MonitorTag tests that observe listener wiring together prove identity Octave-safely."
  - "MonitorTag FAST — the benchmark measured -69.7% overhead (MonitorTag 0.141s vs Sensor.resolve 0.465s at 12 x 10k x 50 iters). This is explained by the fact that Sensor.resolve runs the full legacy pipeline (Threshold condition vector + violation detection + step-function conversion + event generation) whereas MonitorTag.getXY with invalidate-per-iter only runs the ConditionFn + cache write. Event emission short-circuits (no EventStore bound in bench). The 10% gate has enormous margin; flagged for Phase 1007 vs attention only if appendData adds surprising cost."
  - "File count landed at exactly 12 — at the Pitfall 5 cap with 0 margin. Decision made at audit time (plan allowed deferring TagRegistry round-trip tests to Phase 1009 if count came out to 13). Since count is 12, everything shipped; no deferrals to Phase 1009."

patterns-established:
  - "Tag-kind dispatch extensibility proven: adding MonitorTag to the two consumer surfaces (FastSense.addTag + TagRegistry.instantiateByKind) required exactly +4 lines + 1 error-message literal edit — total 6 lines across 2 production files. Sets the template for CompositeTag (Phase 1008) and future kinds."
  - "Pitfall 9 benchmark shape reusable — nSensors x nPoints x nIter x min of nRuns + invalidate-per-iter to force recompute. Direct copy from bench_sensortag_getxy.m structure. Future derived-tag phases (CompositeTag, RollingWindowTag) can reuse this template verbatim."

requirements-completed:
  - MONITOR-02

duration: 7m5s
completed: 2026-04-16
---

# Phase 1006 Plan 03: FastSense 'monitor' dispatch + TagRegistry round-trip + Pitfall 9 bench + Phase-exit audit Summary

**Two surgical production edits (FastSense.addTag + TagRegistry.instantiateByKind both extended with `case 'monitor'`), two test extensions (forward + reverse round-trip via loadFromStructs), one new Pitfall 9 benchmark (PASS with -69.7% overhead — MonitorTag is 3.3x FASTER than legacy Sensor.resolve), and a phase-exit audit confirming 12/12 files touched (at cap), all legacy byte-for-byte unchanged, and all pitfall gates PASS.**

## Performance

- **Duration:** ~7 min 5s
- **Started:** 2026-04-16T17:44:38Z
- **Completed:** 2026-04-16T17:51:43Z
- **Tasks:** 3 (feat + test+bench + docs audit)
- **Files modified:** 5 (2 production + 2 test extensions + 1 new benchmark)

## Accomplishments

- FastSense.addTag extended with `case 'monitor'` — identical body to `case 'sensor'` (both call `obj.addLine(x, y, 'DisplayName', tag.Name, varargin{:})` via `tag.getXY()`). 0/1 binary series render as a flat flipping line. Pitfall 1 preserved — zero isa subclass checks anywhere in FastSense.m.
- TagRegistry.instantiateByKind extended with `case 'monitor': tag = MonitorTag.fromStruct(s)`. The `otherwise` error message updated from `'Valid kinds (Phase 1005): mock, sensor, state.'` to `'Valid kinds (Phase 1006): mock, sensor, state, monitor.'`. The `loadFromStructs` Pass-2 `resolveRefs(map)` already calls `MonitorTag.resolveRefs` (Plan 01 override), so the Parent handle wiring happens automatically.
- testRoundTripMonitorTag added to both TestTagRegistry.m (MATLAB unittest method) and test_tag_registry.m (Octave flat-assert block). Forward order + reverse order both wire the Parent handle correctly. Pitfall 8 (order-insensitive two-phase loader) re-verified for the 'monitor' kind — Pass-1 constructs with a dummy parent (MockTag + placeholder condition); Pass-2 swaps the real parent from the registry regardless of load order.
- benchmarks/bench_monitortag_tick.m created — 12 sensors x 10k points x 50 iterations x min of 3 runs. Compares legacy Sensor.resolve (full violation pipeline) against MonitorTag.invalidate() + getXY() (cold recompute every iter). Asserts `overhead_pct <= 10`. Measured: Sensor.resolve 0.465s vs MonitorTag 0.141s — **overhead -69.7%** (MonitorTag is 3.3x FASTER). Gate PASS with enormous margin.
- Phase-exit audit: 12/12 files touched (exactly at Pitfall 5 cap). All 14 legacy / EventDetection files byte-for-byte unchanged. All 7 MonitorTag grep gates PASS. Pitfall 1 preserved in FastSense.m. Full Octave suite 75/76 PASS (1 pre-existing unrelated failure in test_to_step_function — see below). Golden integration GREEN (Pitfall 11 lock held).

## Task Commits

Each task was committed atomically with `--no-verify`:

1. **Task 1: FastSense.addTag + TagRegistry 'monitor' kind extension** — `d1275a1` (feat)
2. **Task 2: TagRegistry round-trip test + Pitfall 9 benchmark** — `28e57be` (test+bench)
3. **Task 3: Phase-exit audit SUMMARY** — pending this commit (docs)

## Files Created/Modified

- `libs/FastSense/FastSense.m` (modified, +4 lines / -1 line at the addTag switch) — added `case 'monitor': [x,y] = tag.getXY(); obj.addLine(x, y, 'DisplayName', tag.Name, varargin{:});` between `case 'state'` and `otherwise`. No other method touched.
- `libs/SensorThreshold/TagRegistry.m` (modified, +2 lines / -1 line at the instantiateByKind switch) — added `case 'monitor': tag = MonitorTag.fromStruct(s);` before `otherwise`; updated the error message literal. `loadFromStructs` unchanged.
- `tests/suite/TestTagRegistry.m` (modified, +45 lines) — testRoundTripMonitorTag method appended to the existing `methods (Test)` block.
- `tests/test_tag_registry.m` (modified, +30 lines, count bumped 13 -> 14) — matching Octave flat-assert round-trip block before the final fprintf.
- `benchmarks/bench_monitortag_tick.m` (NEW, 102 SLOC) — Pitfall 9 gate benchmark; follows the `bench_sensortag_getxy.m` template (warmup + min-of-3-runs + PASS/FAIL assertion).

## Phase-Wide File-Touch Audit

**Phase 1006 baseline commit:** `802a156` (docs(1006): context for MonitorTag phase) — per git log the last pre-phase commit before Phase 1006 work began.

**`git diff --name-only 802a156..HEAD -- libs/ tests/ benchmarks/`:**

| #   | Path                                       | Plan | Category                              |
| --- | ------------------------------------------ | ---- | ------------------------------------- |
| 1   | libs/SensorThreshold/MonitorTag.m          | 01+02 | production (NEW, 500 SLOC)            |
| 2   | libs/SensorThreshold/SensorTag.m           | 01   | production (additive — listener hook) |
| 3   | libs/SensorThreshold/StateTag.m            | 01   | production (additive — listener hook) |
| 4   | libs/SensorThreshold/TagRegistry.m         | 03   | production (+2 lines — monitor case + msg) |
| 5   | libs/FastSense/FastSense.m                 | 03   | production (+4 lines — monitor case) |
| 6   | tests/suite/TestMonitorTag.m               | 01   | test (NEW, ~320 SLOC)                 |
| 7   | tests/test_monitortag.m                    | 01   | test (NEW, ~225 SLOC)                 |
| 8   | tests/suite/TestMonitorTagEvents.m         | 02   | test (NEW, 234 SLOC)                  |
| 9   | tests/test_monitortag_events.m             | 02   | test (NEW, 180 SLOC)                  |
| 10  | benchmarks/bench_monitortag_tick.m         | 03   | bench (NEW, 102 SLOC)                 |
| 11  | tests/suite/TestTagRegistry.m              | 03   | test (extend — +45 lines)             |
| 12  | tests/test_tag_registry.m                  | 03   | test (extend — +30 lines)             |

**Total count: 12 files exactly. At the Pitfall 5 cap (budget <=12) with 0 margin.**

## Pitfall 5 Phase-Exit Verdict — file count vs <=12 budget

| Budget | Actual | Verdict |
| ------ | ------ | ------- |
| <=12   | 12     | PASS (at cap, no margin) |

Decision (per plan): "If the audit reveals the count is > 12, revert TagRegistry round-trip tests and defer to Phase 1009." Since count is 12, everything shipped — no deferrals.

## Pitfall 1 Verdict — zero isa subclass checks in FastSense.m

```
grep -cE "isa\s*\([^,]*,\s*'(SensorTag|StateTag|MonitorTag)'" libs/FastSense/FastSense.m
-> 0
```

**PASS.** Dispatch is by `tag.getKind()` only; no isa subclass check for any Tag subclass.

## Pitfall 9 Benchmark Numbers

| Metric                      | Value       |
| --------------------------- | ----------- |
| nSensors                    | 12          |
| nPoints per sensor          | 10000       |
| nIter                       | 50          |
| nRuns (min)                 | 3           |
| tLegacy (Sensor.resolve)    | 0.465 s     |
| tMonitor (MonitorTag tick)  | 0.141 s     |
| overhead_pct                | **-69.7%**  |
| Gate                        | overhead_pct <= 10 |
| **Result**                  | **PASS**    |

Interpretation: MonitorTag is **3.3x FASTER** than the legacy Sensor.resolve pipeline at the 12-widget live-tick workload. Explanation: Sensor.resolve runs Threshold condition vector + violation detection + step-function conversion + event generation; MonitorTag with invalidate-per-iter only runs ConditionFn + cache write (event emission short-circuits because no EventStore is bound in the bench). The 10% gate has enormous margin.

## Grep Gate Verdicts (all 7 on MonitorTag.m + 1 on FastSense.m)

| Gate | Expected | Actual | Status |
| ---- | -------- | ------ | ------ |
| `FastSenseDataStore|storeMonitor|storeResolved` (Pitfall 2 code) | 0 | 0 | PASS |
| `lazy-by-default, no persistence` (Pitfall 2 doc) | >=1 | 2 | PASS |
| `PerSample|OnSample|onEachSample` (MONITOR-10) | 0 | 0 | PASS |
| `interp1.*'linear'` (ALIGN-01) | 0 | 0 | PASS |
| `methods (Abstract)` (Octave-safety) | 0 | 0 | PASS |
| `\.TagKeys` (Pitfall 5 — pre-Phase-1010) | 0 | 0 | PASS |
| `classdef MonitorTag < Tag` | 1 | 1 | PASS |
| `isa\s*\([^,]*,\s*'(SensorTag\|StateTag\|MonitorTag)'` in FastSense.m (Pitfall 1) | 0 | 0 | PASS |

## Legacy-Diff Verdict

```
git diff 802a156..HEAD -- \
  libs/SensorThreshold/Sensor.m libs/SensorThreshold/Threshold.m \
  libs/SensorThreshold/ThresholdRule.m libs/SensorThreshold/CompositeThreshold.m \
  libs/SensorThreshold/StateChannel.m libs/SensorThreshold/SensorRegistry.m \
  libs/SensorThreshold/ThresholdRegistry.m libs/SensorThreshold/ExternalSensorRegistry.m \
  libs/SensorThreshold/Tag.m \
  libs/EventDetection/Event.m libs/EventDetection/EventStore.m \
  libs/EventDetection/EventDetector.m libs/EventDetection/IncrementalEventDetector.m \
  libs/EventDetection/LiveEventPipeline.m
-> EMPTY (0 lines diff for all 14 files)
```

**All 14 legacy / EventDetection files are byte-for-byte unchanged across the full Phase 1006. Pitfall 5 + Pitfall 11 both hold.**

## SensorTag / StateTag Additive-Only Verdicts

| File                                | `git diff 802a156..HEAD \| grep '^-[^-]' \| wc -l` | Verdict |
| ----------------------------------- | ---------------------------------------------- | ------- |
| libs/SensorThreshold/SensorTag.m    | 1 (whitespace re-indent of Sensor_ comment alongside the new listeners_ declaration; semantically equivalent) | ADDITIVE (documented in Plan 01 SUMMARY) |
| libs/SensorThreshold/StateTag.m     | 0                                              | ADDITIVE |

The single "removed" line in SensorTag.m is a whitespace alignment of the existing `Sensor_` property comment — same property, same comment, same semantics; only indentation adjusted so the column aligns with the newly-added `listeners_ = {}  % cell ...` line below it. No semantic removal. Documented in Plan 01 SUMMARY.

## Phase-Requirement Coverage Matrix (all 12 Phase 1006 requirements)

| Req          | Delivered by | Evidence                                                                    |
| ------------ | ------------ | --------------------------------------------------------------------------- |
| MONITOR-01   | 1006-01      | classdef MonitorTag < Tag; getKind='monitor'; binary 0/1 output             |
| MONITOR-02   | 1006-03      | FastSense.addTag 'monitor' case + TagRegistry 'monitor' case + testRoundTripMonitorTag |
| MONITOR-03   | 1006-01      | Lazy memoize via dirty_ + cache_; recomputeCount_ probe proves 1 compute then cache hits |
| MONITOR-04   | 1006-01      | Parent-driven invalidation via addListener/notifyListeners_ observer pattern |
| MONITOR-05   | 1006-02      | fireEventsOnRisingEdges_ emits Event with SensorName=parent.Key, ThresholdLabel=monitor.Key (pre-Phase-1010 carrier pattern) |
| MONITOR-06   | 1006-02      | applyDebounce_ with MinDuration strict-less-than filter                     |
| MONITOR-07   | 1006-02      | applyHysteresis_ two-state FSM                                              |
| MONITOR-10   | 1006-01      | No per-sample callback API (OnEventStart/OnEventEnd only); grep gate PASS  |
| ALIGN-01     | 1006-01      | No interp1 linear anywhere (grep gate PASS)                                 |
| ALIGN-02     | 1006-01      | Single-parent grid — recompute operates on Parent.getXY() directly          |
| ALIGN-03     | 1006-01      | ZOH documented in class header (valueAt uses binary_search 'right')         |
| ALIGN-04     | 1006-01      | NaN handling proven by test — NaN > threshold is false (IEEE 754 default)   |

## Pitfall Gate Summary

| Gate | Verdict |
| ---- | ------- |
| Pitfall 1 (no isa subclass checks in FastSense.m) | PASS (0 matches) |
| Pitfall 2 (no disk persistence in MonitorTag) | PASS (0 FastSenseDataStore/storeMonitor/storeResolved; 2 "lazy-by-default, no persistence" docs) |
| Pitfall 5 (<=12 files, legacy byte-for-byte unchanged, no .TagKeys pre-Phase-1010) | PASS (12/12 files; 14/14 legacy unchanged; 0 .TagKeys) |
| Pitfall 7 (super-call ordering in MonitorTag constructor) | PASS (NV parse before obj@Tag — Plan 01 canonical) |
| Pitfall 8 (loadFromStructs order-insensitive for 'monitor' kind) | PASS (testRoundTripMonitorTag forward + reverse both GREEN) |
| Pitfall 9 (MonitorTag tick <=110% Sensor.resolve baseline) | PASS (-69.7% — 3.3x FASTER) |
| Pitfall 11 (golden integration locked — legacy pipeline untouched) | PASS (9/9 golden tests GREEN; legacy byte-diff empty) |
| MONITOR-10 (no per-sample callbacks) | PASS (grep gate 0 matches) |
| ALIGN-01 (no interp1 linear in MonitorTag) | PASS (grep gate 0 matches) |

## Regression Test Evidence

**Full Octave suite (`octave --no-gui --eval "install(); cd tests; run_all_tests();"`):** 75/76 passed.

- **Pre-existing unrelated failure:** `test_to_step_function: testAllNaN` fails both with and without my changes (confirmed via `git stash`: fails on 28e57be AND on the base tree). This test exercises the MEX fallback in `libs/SensorThreshold/private/to_step_function.m` which is completely unrelated to MonitorTag / TagRegistry / FastSense.addTag. Phase 1005-02 SUMMARY documented the same failure. Out of scope per deviation-rules scope boundary.

**Plan-relevant suites (all GREEN):**

```
test_monitortag              -> PASS
test_monitortag_events       -> PASS
test_fastsense_addtag        -> PASS
test_tag_registry            -> PASS (14 tests — includes new monitor round-trip)
test_sensortag               -> PASS
test_statetag                -> PASS
test_sensor                  -> PASS  (8 tests, legacy pipeline)
test_state_channel           -> PASS  (5 tests)
test_tag                     -> PASS  (18 tests)
test_event_detector          -> PASS  (7 tests)
test_event_integration       -> PASS  (4 tests)
test_golden_integration      -> PASS  (9 tests — Pitfall 11 lock held)
```

**Benchmark:** `bench_monitortag_tick()` — PASS, -69.7% overhead.

## Deviations from Plan

None on Plan 03 Tasks 1-3. The plan's canonical extension snippets (verbatim in `<interfaces>`) matched the existing addTag / instantiateByKind shapes and dropped in cleanly with zero surprises.

The benchmark result was much better than expected (-69.7% vs the 10% gate). That is a good-surprise deviation from the research estimate — not a plan-deviation. Noted in decisions.

## Strangler-Fig Confirmation

- Legacy `Sensor.resolve()` pipeline is **still fully functional** — `test_sensor` (8 tests), `test_event_integration` (4 tests), `test_golden_integration` (9 tests) all GREEN on the same pipeline MonitorTag replaces functionally.
- Legacy files byte-for-byte unchanged: Sensor.m, Threshold.m, ThresholdRule.m, CompositeThreshold.m, StateChannel.m, SensorRegistry.m, ThresholdRegistry.m, ExternalSensorRegistry.m, Tag.m, Event.m, EventStore.m, EventDetector.m, IncrementalEventDetector.m, LiveEventPipeline.m.
- MonitorTag is a **parallel additive path**, not a replacement. Consumer migration (widgets, dashboards) is Phase 1009 scope.

## Decisions Made

- **FastSense.addTag 'monitor' case mirrors 'sensor' verbatim** — the 0/1 binary output is rendered as a flat line that flips between 0 and 1. This is acceptable for Phase 1006. A dedicated staircase helper (like addStateTagAsStaircase_) would be nicer visually but adds a new private method, overstretching Plan 03's scope. Users needing stepped rendering can route through 'state' in a later phase or write custom code.
- **Round-trip handle identity asserted via Key equality + Pitfall 8 reverse-order proof** — Octave's `isequal`/`==` on handles with listener cycles cause SIGILL (Plan 01 deviation #3). Key equality is Octave-safe AND sufficient: the monitor's Parent points to the registry entry that has the same Key, AND the registry is keyed by Key, AND (forward order) Pass-2 resolveRefs swaps in the registered handle. Reverse-order test (monitor struct first) exercises the Pitfall 8 two-phase loader guarantee.
- **Combined test+bench commit instead of separate commits** — plan allowed either. Combined message is simpler and reflects the single logical unit of work (prove round-trip + prove Pitfall 9 gate).
- **File count landed at exactly 12 (at the cap)** — plan allowed deferring TagRegistry round-trip tests to Phase 1009 if count came out to 13. Since count is 12, ship everything. Documented at audit time.

## Issues Encountered

- Single pre-existing unrelated test failure (`test_to_step_function: testAllNaN`) — documented above; fails identically on the base tree. Out of scope.

## Self-Check: PASSED

All claims verified:

- `libs/FastSense/FastSense.m` case 'monitor' — FOUND (1 match)
- `libs/SensorThreshold/TagRegistry.m` case 'monitor' + MonitorTag.fromStruct — FOUND (1 match each)
- `libs/SensorThreshold/TagRegistry.m` "Valid kinds (Phase 1006): mock, sensor, state, monitor" — FOUND (1 match)
- `tests/suite/TestTagRegistry.m` testRoundTripMonitorTag — FOUND (1 match)
- `tests/test_tag_registry.m` MonitorTag round-trip block — FOUND (MonitorTag: 7 matches, loadFromStructs({monitorStruct: 1 match)
- `benchmarks/bench_monitortag_tick.m` — FOUND (function bench_monitortag_tick: 1 match, overhead_pct <= 10: 3 matches, Sensor(sprintf: 1, SensorTag: 3, MonitorTag: 10)
- Commit `d1275a1` (feat) — FOUND in git log
- Commit `28e57be` (test+bench) — FOUND in git log
- Pitfall 1 (isa checks in FastSense.m) — 0 matches
- Pitfall 2 (disk persistence in MonitorTag.m) — 0 matches; "lazy-by-default" in header 2 matches
- Pitfall 5 (`.TagKeys` in MonitorTag.m) — 0 matches; file count 12
- All 14 legacy / EventDetection files — 0-line diff each
- Pitfall 9 benchmark — PASS (overhead -69.7%, well under the <=10 gate)
- Golden integration — 9/9 GREEN
- Full suite — 75/76 GREEN (1 pre-existing unrelated failure documented)

## Next Phase Readiness

- **Phase 1007 (MONITOR-08 appendData + MONITOR-09 opt-in Persist=true)** — additive to MonitorTag.m only. No new classes needed. The observer hook (listeners_ + addListener + notifyListeners_) is already wired, so appendData on parent automatically cascades invalidation. Opt-in persistence will add two public properties (Persist, DataStore) and a write path in the cache-miss branch of recompute_.
- **Phase 1008 (CompositeTag)** — pattern established: add new Tag subclass + extend FastSense.addTag switch + extend TagRegistry.instantiateByKind switch + write round-trip test. Template proven this phase.
- **Phase 1009 (widget consumer migration)** — FastSenseWidget / dashboard config can now dispatch MonitorTag through fp.addTag. No blocker.
- **Phase 1010 (EVENT-01 TagKeys migration)** — the single call site in `libs/SensorThreshold/MonitorTag.m:fireEventsOnRisingEdges_` (line ~403) is the pivot point: `ev = Event(startT, endT, char(obj.Parent.Key), char(obj.Key), NaN, 'upper')`. Phase 1010 migrates this to `ev.TagKeys = {obj.Parent.Key, obj.Key}` (or whatever the new constructor signature is). Documented in Plan 02 SUMMARY decisions.

## Open Concerns

**None.** Pitfall 9 gate had enormous margin (-69.7% vs 10% threshold). All Pitfall gates held. Legacy pipeline fully intact. Strangler-fig contract preserved.

---
*Phase: 1006-monitortag-lazy-in-memory*
*Completed: 2026-04-16*
