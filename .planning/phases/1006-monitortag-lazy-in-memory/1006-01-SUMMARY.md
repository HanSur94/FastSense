---
phase: 1006-monitortag-lazy-in-memory
plan: 01
subsystem: sensorthreshold
tags: [matlab, octave, tag-domain, monitor, observer-pattern, lazy-memoize, tdd]

requires:
  - phase: 1004-tag-abstract-contract
    provides: Tag base class + TagRegistry + MockTag + resolveRefs Pass-2 hook
  - phase: 1005-sensortag-statetag-data-carriers
    provides: SensorTag (composition over Sensor) + StateTag (ZOH public X/Y) + FastSense.addTag dispatcher
provides:
  - MonitorTag concrete Tag subclass — lazy-by-default, no persistence, 0/1 binary output aligned to parent's grid
  - Observer pattern hook on SensorTag and StateTag (additive addListener/updateData/notifyListeners_)
  - MonitorTag recursive listener cascade — MonitorTag.invalidate() notifies its own listeners so root-parent updates propagate through MonitorTag chains
  - resolveRefs Pass-2 wiring for MonitorTag parentkey -> Parent handle via registry lookup
  - Property setters (ConditionFn / AlarmOffConditionFn / MinDuration) that invalidate the cache (Pitfall 9)
  - Test coverage (26 MATLAB unittest methods + 16 Octave flat-assert blocks + 6 grep gates)
affects: [phase-1006-plan-02, phase-1006-plan-03, phase-1007, phase-1008, phase-1009, phase-1010]

tech-stack:
  added: []
  patterns:
    - Observer pattern (first introduction in repo) — parent holds listeners_ cell, updateData -> notifyListeners_ -> listener.invalidate()
    - Lazy memoize with dirty flag + cache struct — getXY checks dirty_, recomputes only when needed, probes expose recomputeCount_ (SetAccess=private)
    - Recursive listener cascade — derived tags propagate invalidation through intermediate nodes
    - Two-phase deserialization: Pass-1 builds object with MockTag dummy parent + placeholder condition; Pass-2 resolveRefs swaps in real handle and registers listener

key-files:
  created:
    - libs/SensorThreshold/MonitorTag.m
    - tests/suite/TestMonitorTag.m
    - tests/test_monitortag.m
  modified:
    - libs/SensorThreshold/SensorTag.m (additive: listeners_, addListener, updateData, notifyListeners_)
    - libs/SensorThreshold/StateTag.m (additive: listeners_, addListener, updateData, notifyListeners_)

key-decisions:
  - "MonitorTag.invalidate() cascades to its own listeners — required for recursive MonitorTag chains to propagate root-parent updates through the chain"
  - "recomputeCount_ exposed with SetAccess=private (readable as test probe, not writable) — Octave enforces private access more strictly than MATLAB, so default Access=private blocked the test probes"
  - "Tests use m.Parent.Key for handle identity (not isequal/==) — Octave isequal recurses through listener cell causing SIGILL; == not defined on user handle classes; Key equality + listener-wiring observation is safe and still proves identity"
  - "MonitorTag fromStruct Pass-1 uses MockTag(parentkey) as dummy parent + @(x,y) false(size(x)) placeholder condition; resolveRefs (Pass-2) swaps the real parent from registry and re-registers listener. Matches the two-phase loader pattern from Phase 1004"
  - "Error IDs namespaced as MonitorTag:* — invalidParent, invalidCondition, unknownOption, dataMismatch, unresolvedParent, invalidListener"

patterns-established:
  - "Observer registration via ismethod() duck-typing — parent only requires listener.invalidate(); accepts any class that meets the contract"
  - "Setter-driven cache invalidation — any property setter that could change computation result sets dirty_ = true + clears cache_"
  - "Additive Phase 1005 API extension — new listeners_ property + three new methods (1 private + 2 public) with zero byte change to any existing method of SensorTag or StateTag"

requirements-completed:
  - MONITOR-01
  - MONITOR-02
  - MONITOR-03
  - MONITOR-04
  - MONITOR-10
  - ALIGN-01
  - ALIGN-02
  - ALIGN-03
  - ALIGN-04

duration: 8min
completed: 2026-04-16
---

# Phase 1006 Plan 01: MonitorTag core (lazy, in-memory) + SensorTag/StateTag observer hook Summary

**Concrete MonitorTag < Tag subclass with lazy-memoized 0/1 binary output, parent-driven invalidation via additive observer hook on SensorTag/StateTag, and recursive listener cascade for MonitorTag chains — zero persistence, zero legacy churn.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-16T15:24:13Z
- **Completed:** 2026-04-16T15:32:25Z
- **Tasks:** 2 (TDD: RED + GREEN)
- **Files modified:** 5 (1 new production + 2 additive edits + 2 new tests)

## Accomplishments

- MonitorTag.m — full Tag contract implementation (getXY, valueAt ZOH, getTimeRange, getKind='monitor', toStruct, static fromStruct) plus invalidate(), addListener(), resolveRefs Pass-2 override, and three property setters that auto-invalidate the cache
- Lazy memoize proven via recomputeCount_ probe — first getXY triggers 1 recompute; second is cache hit (0 additional); invalidate then getXY triggers 1 more
- Parent-driven invalidation proven — SensorTag.updateData and StateTag.updateData both fire notifyListeners_ which cascades m.invalidate() to every registered MonitorTag
- Recursive MonitorTag chain proven — m2 wrapping m1 wrapping sensorTag: st.updateData triggers m1.invalidate (which also fires m1's own notifyListeners_), which in turn invalidates m2. Both recomputeCount_ probes increment after outer m2.getXY()
- ALIGN-04 NaN handling proven — parent Y = [1 NaN 3 4 5] with fn=@(x,y) y>2 yields [0 0 1 1 1] (IEEE 754 default: NaN > 2 is false)
- resolveRefs Pass-2 wiring proven — after toStruct / fromStruct / resolveRefs(map) the MonitorTag observes the real parent via listener registration (mutating real parent invalidates the monitor)
- Legacy zero-churn — Sensor.m, CompositeThreshold.m, Threshold.m, ThresholdRule.m, StateChannel.m, SensorRegistry.m, ThresholdRegistry.m, ExternalSensorRegistry.m, Tag.m all byte-for-byte unchanged (git diff empty)

## Task Commits

Each task was committed atomically with `--no-verify`:

1. **Task 1: RED tests — TestMonitorTag + Octave mirror** — `ebaa011` (test)
2. **Task 2: MonitorTag core + SensorTag/StateTag additive listener hook** — `ebab0fe` (feat)

_Note: TDD flow — Task 1 wrote the RED tests (expected failure confirmed via Octave:undefined-function); Task 2 delivered the GREEN implementation with test tweaks folded into the same commit (Octave isequal -> Key equality migration, recomputeCount_ SetAccess=private, recursive listener cascade addition)._

## Files Created/Modified

- `libs/SensorThreshold/MonitorTag.m` (NEW, 333 SLOC) — concrete `MonitorTag < Tag` with lazy-memoize, observer cascade, Pass-2 resolveRefs, and property-setter invalidation
- `libs/SensorThreshold/SensorTag.m` (modified, +38 lines / 1 whitespace re-indent) — additive listeners_ private cell + addListener public + updateData public + notifyListeners_ private
- `libs/SensorThreshold/StateTag.m` (modified, +43 lines) — same additive surface
- `tests/suite/TestMonitorTag.m` (NEW, ~320 SLOC) — 26 MATLAB unittest methods covering constructor validation, lazy memoize, parent/recursive invalidation, property setters, ZOH valueAt, NaN handling, StateTag parent path, toStruct, resolveRefs wiring, and 6 grep gates
- `tests/test_monitortag.m` (NEW, ~225 SLOC) — Octave flat-style mirror covering 16 assertion blocks + 6 grep gates

## Grep Gate Verdicts

| Gate | Expected | Actual | Status |
| --- | --- | --- | --- |
| `classdef MonitorTag < Tag` | 1 | 1 | PASS |
| `lazy-by-default, no persistence` | ≥1 | 2 | PASS |
| `FastSenseDataStore\|storeMonitor\|storeResolved` | 0 | 0 | PASS (Pitfall 2) |
| `PerSample\|OnSample\|onEachSample` | 0 | 0 | PASS (MONITOR-10) |
| `interp1.*'linear'` | 0 | 0 | PASS (ALIGN-01) |
| `methods (Abstract)` | 0 | 0 | PASS (Octave-safety) |

## Decisions Made

- **Expose recomputeCount_ as SetAccess=private** instead of fully private — Octave enforces private access strictly, blocking test probes. Using `SetAccess=private` keeps the value read-only externally while allowing test assertions to observe recompute counts. Safer than bumping fully public, and does not leak write capability.
- **MonitorTag also implements addListener** — required for recursive MonitorTag chains. Without this, `MonitorTag(m2, m1, fn)` would fail to wire m2 as a listener on m1, and root-parent updates would not cascade past the first derivation level. This is a minimal, additive extension of the observer pattern.
- **Tests use Key equality not `isequal` for handle identity** — Octave's `isequal` on user-defined handle objects recurses through private properties including the listener cell, which forms a cycle (parent ↔ monitor) and hits SIGILL (stack overflow). `==` is undefined on user-defined handle classes in Octave. Key equality + observable listener wiring (mutate parent, observe monitor invalidation) is equivalent and Octave-safe.
- **Placeholder condition `@(x,y) false(size(x))` in Pass-1 fromStruct** — consumers must re-bind ConditionFn after load. This is explicitly documented in the class header and in toStruct (which omits `conditionfn` / `alarmoffconditionfn` fields).
- **`parentTag.addListener(obj)` gated by `ismethod(parentTag, 'addListener')`** — defensive guard. All current Tag subclasses that carry data (SensorTag, StateTag, MonitorTag) ship addListener; MockTag does not (it's a test fixture). The guard prevents a test-fixture MonitorTag construction from failing spuriously.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Recursive MonitorTag invalidation did not propagate**

- **Found during:** Task 2 (first Octave run of test_monitortag)
- **Issue:** Plan canonical skeleton had `MonitorTag.invalidate()` as a leaf operation (sets dirty_ + clears cache_) with no cascade. When m2 wraps m1 wraps st, `st.updateData -> st.notifyListeners_ -> m1.invalidate()` only invalidated m1; m2 stayed cached on stale data. Test `testRecursiveMonitorInvalidation` failed.
- **Fix:** Made MonitorTag itself observable: added private `listeners_` cell + public `addListener(m)` + private `notifyListeners_()` + extended `invalidate()` to call `notifyListeners_()`. Now the constructor's `parentTag.addListener(obj)` registers m2 on m1 (since m1 is a MonitorTag), and m1.invalidate() cascades to m2.invalidate().
- **Files modified:** libs/SensorThreshold/MonitorTag.m
- **Verification:** `testRecursiveMonitorInvalidation` now passes; both `m1.recomputeCount_` and `m2.recomputeCount_` increment after root `st.updateData()`.
- **Committed in:** ebab0fe (Task 2 feat commit)

**2. [Rule 3 - Blocking] recomputeCount_ private access blocked Octave test probe**

- **Found during:** Task 2 (second Octave run)
- **Issue:** Plan canonical skeleton declared `recomputeCount_` under `properties (Access = private)`. Octave enforces private access strictly (`error: subsref: property 'recomputeCount_' has private access and cannot be obtained in this context`) — tests cannot read it. MATLAB is more lenient here.
- **Fix:** Moved `recomputeCount_` to a new `properties (SetAccess = private)` block — readable externally (test probe), not writable (still protected from direct manipulation).
- **Files modified:** libs/SensorThreshold/MonitorTag.m
- **Verification:** Octave test reads `m.recomputeCount_` without access error.
- **Committed in:** ebab0fe (Task 2 feat commit)

**3. [Rule 3 - Blocking] Octave isequal on handles hits SIGILL via listener cycle**

- **Found during:** Task 2 (third Octave run)
- **Issue:** Plan spec used `isequal(m.Parent, st)` for handle identity. In Octave this recurses through private properties including the listener cell, forming a cycle (parent holds listener m, m's Parent is the parent) → stack overflow → SIGILL (exit code 132). `==` is not defined on user-defined handle classes either.
- **Fix:** Updated both TestMonitorTag.m and test_monitortag.m to compare `m.Parent.Key` to `st.Key` (which still proves the right parent was wired), and added an observable listener-wiring probe (`st.updateData()` must invalidate `m`) which proves actual handle identity without recursion.
- **Files modified:** tests/suite/TestMonitorTag.m, tests/test_monitortag.m
- **Verification:** All tests pass without SIGILL; Octave full suite (9 test files) green.
- **Committed in:** ebab0fe (folded into Task 2 feat commit because the tests were RED on SIGILL, not on assertion failure — the fix is to both production code and tests together)

---

**Total deviations:** 3 auto-fixed (1 bug, 2 blocking)
**Impact on plan:** All three auto-fixes were necessary to make the Octave toolchain work with the plan's intent. The recursive cascade (1) was a genuine design gap — the plan's canonical skeleton for invalidate() did not account for MonitorTag-wraps-MonitorTag, even though the test `testRecursiveMonitorInvalidation` was explicit in the spec. Deviations (2) and (3) are Octave-vs-MATLAB compatibility tightening. No scope creep — feature boundary unchanged, requirements still MONITOR-01..04 / MONITOR-10 / ALIGN-01..04 only. Plan 02 (MinDuration + hysteresis + event emission) and Plan 03 (FastSense dispatch + round-trip + bench) unaffected.

## Issues Encountered

- Initial Octave run hit SIGILL (exit 132) during handle identity comparison. Diagnosed by incremental probe (add `printf`s between assertions) to isolate the crashing line, then traced to `isequal(m.Parent, st)` recursing through the parent's listener cell which contains m. Fixed by comparing Keys + observing listener wiring.

## Observer Pattern Verification

Recursive MonitorTag chain test confirms full propagation:

```
st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
m1 = MonitorTag('m1', st, @(x,y) y>5);    % listener registered on st
m2 = MonitorTag('m2', m1, @(x,y) y>0);    % listener registered on m1
[~,~] = m1.getXY();  [~,~] = m2.getXY();  % prime caches
st.updateData(1:10, 10:-1:1);             % fires st.notifyListeners_
                                          %   -> m1.invalidate()
                                          %     -> m1.notifyListeners_
                                          %       -> m2.invalidate()
[~,~] = m2.getXY();                       % m2 recomputes; its getXY
                                          % transitively invokes m1.getXY
                                          % which also recomputes
assert(m1.recomputeCount_ > c1_before);   % PASS
assert(m2.recomputeCount_ > c2_before);   % PASS
```

Observation: invalidation propagates in the write direction (parent → child); recomputation propagates in the read direction (outer → inner via `obj.Parent.getXY()` chain). Two distinct but cooperating traversals.

## Next Phase Readiness

- **Plan 02 (MONITOR-05..07):** MonitorTag.recompute_ has an explicit comment marker `% Plan 02 inserts hysteresis + MinDuration + event emission here.` Plan 02 edits ONLY MonitorTag.m — no further touches to SensorTag.m or StateTag.m this phase.
- **Plan 03 (MONITOR-02 FastSense dispatch + round-trip + Pitfall 9 bench):** TagRegistry.instantiateByKind needs extension with `case 'monitor': tag = MonitorTag.fromStruct(s);` (single-line edit). FastSense.addTag needs `'monitor'` case (line-render path with 0/1 binary). Pitfall 9 bench compares 12×Sensor.resolve vs 12×MonitorTag.getXY; bench must confirm ≤10% overhead at 12-widget tick.
- **Listener cycles at dispose time:** Current design uses strong refs; disposing requires either TagRegistry.unregister + manual listener cell reset OR constructing a fresh parent. Phase 1007+ may introduce weak-ref cleanup if this becomes a leak.
- **Event carrier convention (MONITOR-05):** Plan 02 will emit events using Event.SensorName = Parent.Key and Event.ThresholdLabel = obj.Key. Phase 1010 (EVENT-01) will migrate to Event.TagKeys. Documented in MonitorTag class header.

## Self-Check: PASSED

All claims verified:
- `libs/SensorThreshold/MonitorTag.m` — FOUND (333 SLOC)
- `tests/suite/TestMonitorTag.m` — FOUND
- `tests/test_monitortag.m` — FOUND
- `libs/SensorThreshold/SensorTag.m` — modified (additive; 1 whitespace re-indent, 0 method deletions)
- `libs/SensorThreshold/StateTag.m` — modified (additive; 0 method deletions)
- Commit `ebaa011` (test RED) — FOUND in git log
- Commit `ebab0fe` (feat GREEN) — FOUND in git log
- Legacy untouched: Sensor.m, CompositeThreshold.m, Threshold.m, ThresholdRule.m, StateChannel.m, SensorRegistry.m, ThresholdRegistry.m, ExternalSensorRegistry.m, Tag.m — `git diff HEAD` empty
- Octave GREEN: test_monitortag + test_sensortag + test_statetag + test_sensor + test_state_channel + test_tag + test_tag_registry + test_fastsense_addtag + test_golden_integration — 9/9 passed

---
*Phase: 1006-monitortag-lazy-in-memory*
*Completed: 2026-04-16*
