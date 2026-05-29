---
phase: 1007-monitortag-streaming-persistence
plan: 01
subsystem: domain-model
tags: [matlab, monitortag, streaming, hysteresis, debounce, fsm, tdd]

# Dependency graph
requires:
  - phase: 1006-monitortag-lazy-in-memory
    provides: MonitorTag class with lazy 4-stage pipeline (recompute_, applyHysteresis_, applyDebounce_, fireEventsOnRisingEdges_), observer hook via SensorTag.addListener, EventStore carrier pattern (SensorName=Parent.Key, ThresholdLabel=obj.Key)
provides:
  - MonitorTag.appendData(newX, newY) public method with 4-stage streaming pipeline
  - 3 new private cache_ state fields (lastStateFlag_, lastHystState_, ongoingRunStart_) written at end of BOTH recompute_() and appendData()
  - applyHysteresis_ refactored to take initialState and return finalState (carry-in/carry-out FSM)
  - applyDebounce_ refactored to take carryStartX and return ongoingRunStart (X-native run-start carry)
  - fireEventsInTail_ private helper — emits events only for runs that CLOSE inside newX
  - MonitorTag:invalidData error ID
  - TestMonitorTagStreaming suite (7 boundary-correctness scenarios + 3 grep gates) MATLAB + Octave
affects: [1007-02, 1007-03, 1009-consumer-migration, LiveEventPipeline]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Stateful Cache Across Append Boundary (Pattern 1): stage FSMs accept initialState arg, return finalState; persistent cache_ fields carry state between recompute_/appendData calls"
    - "Prior-state snapshot before mutation: read priorLastFlag, priorHystState, priorOngoingStart from cache_ BEFORE extending — ensures fireEventsInTail_ sees correct boundary even after cache mutation"
    - "Open-run at cache end tracked even when MinDuration=0 — findRuns_ seeds newOngoing so appendData can merge carry correctly"

key-files:
  created:
    - tests/suite/TestMonitorTagStreaming.m (252 SLOC — MATLAB unittest, 7 scenarios + 3 grep gates)
    - tests/test_monitortag_streaming.m (154 SLOC — Octave flat-assert mirror)
  modified:
    - libs/SensorThreshold/MonitorTag.m (489 → 703 SLOC; +214 lines)

key-decisions:
  - "Chose cache_ struct for 3 state fields (not properties-block declarations). Cleaner — a single struct holds all cache-correlated state; no duplicate tracking between cache_ and separate private scalars. recompute_ rebuilds cache_ as a fresh struct with all 6 fields; appendData mutates cache_ in place. Rationale: one source of truth, natural invalidation semantics (clearing cache_ clears state too)."
  - "Prior-state snapshot pattern in appendData — read priorLastFlag/priorHystState/priorOngoingStart BEFORE mutating cache_. Prevents a subtle ordering bug where fireEventsInTail_ would see already-updated state."
  - "Open-run tracking when MinDuration=0 — even without debounce, recompute_ and appendData seed ongoingRunStart_ if the final run is still open at cache end. This lets future appendData calls find the correct effective start for events, regardless of whether MinDuration is enabled."
  - "Scenario 2 'double event' contract kept as-is per plan spec. Plan 02 recompute_ closes open-at-end runs (findRuns_ trailing-zero trick) and emits an event. Plan 03 appendData emits a SECOND event when the falling edge arrives in tail. Documented in both test suites as the Phase 1007 boundary contract (not a bug)."
  - "Cold-start fallback branch: if dirty_ OR cache_ empty OR cache_.x empty → recompute_() returns without processing newX/newY args. Caller responsibility: ensure parent already contains the new tail (parent.updateData) before calling appendData."

patterns-established:
  - "Pattern 1 (Stateful Cache Across Append Boundary): refactor private FSM helpers to accept carry-in initial state and return carry-out final state; persist carry state in cache_ struct fields; read prior state BEFORE mutating cache_"
  - "Pattern (Prior-state Snapshot): fireEventsInTail_ receives priorLastFlag and priorOngoingStart as explicit arguments, not via obj.cache_ lookup — prevents ordering bugs when cache_ is mutated mid-method"
  - "Streaming event-emission: fireEventsInTail_ walks findRuns_ on tail only; runs ending at numel(bin_new) are skipped (still open); runs that merge with a prior open run use priorOngoingStart as effective start (matches IncrementalEventDetector.openEvent pattern)"

requirements-completed: [MONITOR-08]

# Metrics
duration: 9m 24s
completed: 2026-04-16
---

# Phase 1007 Plan 01: MonitorTag.appendData streaming + boundary-state continuity Summary

**Streaming tail extension for MonitorTag via appendData(newX, newY) — preserves hysteresis FSM state, MinDuration run-start bookkeeping, and event-emission identity across the append boundary via 3 new cache_ state fields and carry-in/carry-out refactored applyHysteresis_/applyDebounce_ helpers.**

## Performance

- **Duration:** 9 min 24 s (2026-04-16T20:27:40Z → 2026-04-16T20:37:04Z)
- **Started:** 2026-04-16T20:27:40Z
- **Completed:** 2026-04-16T20:37:04Z
- **Tasks:** 2 (TDD: RED → GREEN)
- **Files modified:** 1 (MonitorTag.m)
- **Files created:** 2 (TestMonitorTagStreaming.m + test_monitortag_streaming.m)

## Accomplishments

- **MonitorTag.appendData(newX, newY) public API** ships with 4-stage pipeline (raw condition → hysteresis carry → debounce carry → event emission in tail) plus cold-start fallback to recompute_
- **7 boundary scenarios covered** by MATLAB unittest + Octave flat-assert mirror: append-no-hyst-no-debounce, ongoing-run-extends-into-tail, ongoing-run-extends-across-tail, hysteresis-boundary-no-chatter, MinDuration-spans-boundary-survives, MinDuration-short-run-spans-boundary-zeroed, cold-cache-fallback-to-recompute
- **Three grep gates** enforced in tests: `function appendData` ==1, cache-state fields >= 6 references, no FastSenseDataStore/storeMonitor/storeResolved references (Pitfall 2 preserved for Plan 01)
- **Phase 1006 regression clean** — test_monitortag + test_monitortag_events + test_golden_integration all green after refactor
- **Pitfall 5 preserved** — legacy SensorThreshold/EventDetection/FastSense files byte-for-byte unchanged (git diff HEAD~2 shows only MonitorTag.m + new test files)

## Task Commits

1. **Task 1 (RED): Write 7-scenario streaming tests + grep gates** — `1e77bda` (test)
2. **Task 2 (GREEN): Implement appendData + refactor helpers + add cache state fields + fireEventsInTail_** — `1c06a96` (feat)

_TDD: test-first (1e77bda failed as expected on the pre-GREEN MonitorTag.m with a non-functional appendData stub), then implementation made all 7 scenarios + 3 grep gates green (1c06a96)._

## Files Created/Modified

- `libs/SensorThreshold/MonitorTag.m` — refactored applyHysteresis_/applyDebounce_ to carry-in/carry-out state; added appendData public method (~82 SLOC); added fireEventsInTail_ private helper (~40 SLOC); expanded cache_ struct with lastStateFlag_/lastHystState_/ongoingRunStart_; updated recompute_ to write all 3 new fields at end; updated class header with appendData doc + MonitorTag:invalidData error ID. 489 → 703 SLOC (+214). Well under MISS_HIT 520-per-function ceiling (appendData is ~82 lines, longest function).
- `tests/suite/TestMonitorTagStreaming.m` — NEW (252 SLOC) — MATLAB unittest classdef with TestClassSetup addPaths, per-test TagRegistry.clear setup/teardown, exactly 7 Test methods matching the behavior spec, plus 3 grep-gate Test methods (testAppendDataMethodExists, testBoundaryStateFieldsPresent, testNoPersistenceReferencesStillHolds).
- `tests/test_monitortag_streaming.m` — NEW (154 SLOC) — Octave flat-assert mirror; runs all 7 scenarios + 3 grep gates; prints "All 7 streaming tests passed." on success.

## Decisions Made

1. **cache_ struct (not properties-block) for 3 new state fields.** Plan offered two options (properties-block vs cache_ struct); chose cache_ struct for single-source-of-truth semantics. Clearing cache_ clears state; recompute_ rebuilds atomically. Trade-off: slight verbosity on `cache_.lastStateFlag_` vs `obj.lastStateFlag_`, but eliminates dual-tracking bugs.
2. **Prior-state snapshot before mutation.** appendData reads priorLastFlag/priorHystState/priorOngoingStart into local vars BEFORE invoking helpers/extending cache_. fireEventsInTail_ takes these as explicit args — not via obj.cache_ lookup. Prevents ordering-sensitive bugs where fireEventsInTail_ might see already-updated state.
3. **Open-run tracked even without MinDuration.** recompute_ and appendData both seed newOngoing from findRuns_ when the final run is open at cache end, regardless of MinDuration. Ensures future appendData calls can merge correctly whether or not debounce is enabled.
4. **Scenario 2 "double event" documented as Phase 1007 boundary contract.** The plan's Scenario 2 assertion (2 events when open run at Plan-02-end has falling edge in tail) is intentional: Plan 02 closes runs at parent end via findRuns_'s trailing-zero trick; Plan 03 adds the continuation event when the tail closes the run. Test headers in both MATLAB and Octave files document this explicitly so future readers understand it's by design, not a bug.
5. **Cold-start caller responsibility.** appendData does NOT process newX/newY on the cold-start fallback; caller must ensure parent.updateData was called first so recompute_() sees the new tail. Documented in the method header.

## Deviations from Plan

None - plan executed exactly as written.

**Minor interpretation noted**: Plan offered two options for state-field storage (properties-block declarations vs cache_ struct only). Chose cache_ struct only (documented in Decisions §1). This was explicitly permitted by the plan ("Executor's choice — document which in the SUMMARY").

## Pitfall 2 Gate Verdict: PASS (with documented footnote)

- `grep -cE "FastSenseDataStore|storeMonitor|storeResolved"` on MonitorTag.m → **0** (strict)
- `grep -cE "\bPersist\b"` on MonitorTag.m → **0** (word-boundary)
- Naive `grep -cE "FastSenseDataStore|storeMonitor|Persist"` → **1** match, but it is the substring "Persistence" inside a Phase-1006 docstring comment at line 596: `% Persistence policy: NEVER calls EventStore.save (Pitfall 2).` Pre-existing comment; not added by Plan 01; documents event-emission persistence policy (unrelated to MONITOR-09 disk persistence). The in-test grep gate at line 247 of TestMonitorTagStreaming.m uses the strict regex (without Persist) and passes. **Gate intent satisfied.**

## Pitfall 5 Gate Verdict: PASS

`git diff HEAD~2 -- libs/SensorThreshold/{Sensor,Threshold,ThresholdRule,CompositeThreshold,StateChannel,SensorRegistry,ThresholdRegistry,ExternalSensorRegistry,Tag,SensorTag,StateTag,TagRegistry}.m libs/FastSense/FastSense.m libs/FastSense/FastSenseDataStore.m libs/EventDetection/ | wc -l` → **0 lines**. All legacy files byte-for-byte unchanged.

## File-Touch Audit

Phase 1007 running total after Plan 01:

| # | Path | Status |
|---|------|--------|
| 1 | libs/SensorThreshold/MonitorTag.m | edited (Plan 01) |
| 2 | tests/suite/TestMonitorTagStreaming.m | new (Plan 01) |
| 3 | tests/test_monitortag_streaming.m | new (Plan 01) |

**3 / 8 files** touched. 5 slots remaining for Plans 02 (persistence: FastSenseDataStore.m + 2 Persistence tests) and 03 (benchmark + any slack).

## Issues Encountered

None. TDD flow was clean: RED commit `1e77bda` failed as intended on the pre-GREEN MonitorTag.m (which had a stub appendData that didn't refactor helpers); GREEN commit `1c06a96` made all 7 scenarios + 3 grep gates pass. Phase 1006 regression (test_monitortag, test_monitortag_events, test_golden_integration) stayed green throughout.

## Verification Commands Run

```bash
# Octave-primary verification (matches plan's <automated> block)
octave --no-gui --eval "install(); cd tests; test_monitortag_streaming();"
# → "All 7 streaming tests passed."

octave --no-gui --eval "install(); cd tests; test_monitortag(); test_monitortag_events();"
# → "All test_monitortag tests passed." + "All test_monitortag_events tests passed."

octave --no-gui --eval "install(); cd tests; test_golden_integration();"
# → "All 9 golden_integration tests passed."

# Grep gates
grep -c "function appendData" libs/SensorThreshold/MonitorTag.m                             # → 1
grep -c "function \[bin, finalState\] = applyHysteresis_" libs/SensorThreshold/MonitorTag.m # → 1
grep -c "function \[bin, ongoingRunStart\] = applyDebounce_" libs/SensorThreshold/MonitorTag.m # → 1
grep -c "function fireEventsInTail_" libs/SensorThreshold/MonitorTag.m                      # → 1
grep -cE "lastStateFlag_|ongoingRunStart_|lastHystState_" libs/SensorThreshold/MonitorTag.m # → 16 (>= 10)
grep -cE "FastSenseDataStore|storeMonitor|storeResolved" libs/SensorThreshold/MonitorTag.m  # → 0
```

## User Setup Required

None — pure-code additive phase, no external services or configuration.

## Next Phase Readiness

**Ready for Plan 02 (MONITOR-09 Persist):**
- appendData ships as stable API; Plan 02 can hook `persistIfEnabled_()` into both entry points (recompute_ + appendData) without further refactor.
- cache_ struct now holds 3 boundary fields — when MonitorTag is serialized to disk via storeMonitor, the cache_.y vector is what gets persisted (derived 0/1); lastHystState_ and ongoingRunStart_ are NOT persisted (cold-reload scenario loses them safely — falls back to lastStateFlag_=Y(end) as documented in RESEARCH Example 2).
- Plan 02 file budget: 4 slots remain (FastSenseDataStore.m edit + TestMonitorTagPersistence.m + test_monitortag_persistence.m + 1 slack) — well within Pitfall 5 ceiling.

**Ready for Plan 03 (Pitfall 9 bench):**
- appendData implementation is efficient: O(|newX|) for Stage 1, O(|newX|) for Stage 2 (hysteresis loop), O(|newX|) for Stage 3 (findRuns_ on tail only), O(runs in tail) for Stage 4. Total O(N_tail) vs recompute_'s O(N_total). Benchmark should comfortably hit >= 5x at nWarmup >= 1M (per RESEARCH §6 calibration).

**No blockers. Phase 1007 track is on budget and on spec.**

## Self-Check: PASSED

- [x] File `libs/SensorThreshold/MonitorTag.m` exists and was modified (703 SLOC)
- [x] File `tests/suite/TestMonitorTagStreaming.m` exists (252 SLOC)
- [x] File `tests/test_monitortag_streaming.m` exists (154 SLOC)
- [x] Commit `1e77bda` exists in git log (Task 1 RED)
- [x] Commit `1c06a96` exists in git log (Task 2 GREEN)
- [x] All plan success criteria verified:
  - [x] appendData method count = 1
  - [x] applyHysteresis_ refactored signature = 1
  - [x] applyDebounce_ refactored signature = 1
  - [x] fireEventsInTail_ = 1
  - [x] cache-state field references >= 10 (actual: 16)
  - [x] FastSenseDataStore|storeMonitor|storeResolved references = 0 (Pitfall 2)
  - [x] Legacy byte-for-byte unchanged = 0 lines diff (Pitfall 5)
  - [x] test_monitortag_streaming → "All 7 streaming tests passed."
  - [x] test_monitortag → "All test_monitortag tests passed."
  - [x] test_monitortag_events → "All test_monitortag_events tests passed."
  - [x] test_golden_integration → "All 9 golden_integration tests passed."

---
*Phase: 1007-monitortag-streaming-persistence*
*Plan: 01*
*Completed: 2026-04-16*
