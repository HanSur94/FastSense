# Phase 1006: MonitorTag (lazy, in-memory) - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — new derived-signal Tag subclass)

<domain>
## Phase Boundary

Replace the side-effect violation pipeline buried inside `Sensor.resolve()` with a first-class `MonitorTag` derived signal that is **lazy-by-default**, parent-driven invalidated, and supports debounce + hysteresis. Pure in-memory — NO disk persistence this phase (that's Phase 1007).

**In scope:**
- `MonitorTag < Tag` class (full Tag contract — `getXY`, `valueAt`, `getTimeRange`, `getKind`, `toStruct`, `fromStruct`)
- Constructor: `MonitorTag(key, parentTag, conditionFn)` where parentTag is a `SensorTag` or `StateTag` (Phase 1005) or another `MonitorTag` (recursive), and conditionFn is a function handle `@(x, y) <logical>` returning a 0/1 column vector aligned to parent's grid
- Binary 0/1 output time series; `getKind() == 'monitor'`
- **Lazy evaluation with memoization** — first `getXY()` computes, caches in `cache_`; subsequent reads return cache; `invalidate()` clears cache
- Parent-driven invalidation — when parent's `updateData()` fires, all dependent MonitorTags get `invalidate()`
  - Implementation: observer pattern — parent maintains `listeners_` cell of MonitorTag handles; on `updateData()`, parent calls `m.invalidate()` on each listener
  - SensorTag/StateTag need a new public method `addListener(monitorTag)` (additive — doesn't break existing behavior)
- `MinDuration` (debounce) — violations shorter than MinDuration seconds don't fire events. Default 0 (no debounce). ISA-18.2 alarm suppression.
- Hysteresis / deadband — accept separate `alarmOnConditionFn` and `alarmOffConditionFn`. Default: same fn for both (no hysteresis). Prevents chattering at boundary.
- Event firing — on 0→1 transition AND MinDuration satisfied, emit Event with `TagKeys = {monitor.Key, parent.Key}`. Bound EventStore via `MonitorTag.EventStore` property.
- ALIGN-01..04 — ZOH alignment only (no `interp1('linear')`). Drop pre-history grid points (before `parent.X(1)`).
- MONITOR-10 (enforced): NO per-sample callback APIs — only event-level callbacks `OnEventStart`, `OnEventEnd`.

**Out of scope (later phases):**
- Streaming `appendData` (Phase 1007 — MONITOR-08)
- Disk persistence via `FastSenseDataStore.storeMonitor` (Phase 1007 — MONITOR-09)
- CompositeTag aggregation (Phase 1008)
- Widget consumer migration (Phase 1009)

**Verification gates (from ROADMAP):**
- Pitfall 2 (premature persistence): ZERO `FastSenseDataStore.storeMonitor` / `storeResolved` calls in MonitorTag.m. Class header says "lazy-by-default, no persistence" verbatim.
- Pitfall 5: ≤12 files touched. Legacy `Sensor.resolve()` still works untouched.
- Pitfall 9: Live-tick benchmark with one MonitorTag observed against legacy `Sensor.resolve` baseline → ≤10% regression at 12-widget tick.
- MONITOR-10 explicit: No per-sample callback APIs exposed. Only `OnEventStart`/`OnEventEnd`.
- ALIGN-01 explicit: No `interp1(..., 'linear')` in MonitorTag aggregation code.

</domain>

<decisions>
## Implementation Decisions

### File Organization
- NEW: `libs/SensorThreshold/MonitorTag.m` (~220 SLOC)
- EDIT: `libs/SensorThreshold/SensorTag.m` — add `addListener(monitorTag)` public method + `listeners_` private property + override `updateData()` to fire listeners (if updateData exists; if not, add one that just fires listeners for now — legacy Sensor has its own data-update semantics the delegate forwards to)
- EDIT: `libs/SensorThreshold/StateTag.m` — same `addListener` + `listeners_` pattern
- EDIT: `libs/SensorThreshold/TagRegistry.m` — extend `instantiateByKind` with `'monitor'` case
- EDIT: `libs/FastSense/FastSense.m` — extend `addTag` switch with `case 'monitor'` (line-render path with 0/1 binary — simple line is fine)

Tests (dual-style):
- NEW: `tests/suite/TestMonitorTag.m`
- NEW: `tests/test_monitortag.m`
- NEW: `tests/suite/TestMonitorTagEvents.m` (event firing + MinDuration + hysteresis)
- NEW: `tests/test_monitortag_events.m`
- NEW: `benchmarks/bench_monitortag_tick.m` (Pitfall 9 gate)
- EDIT: `tests/suite/TestTagRegistry.m` — add `testRoundTripMonitorTag`
- EDIT: `tests/test_tag_registry.m` — matching Octave assertion

Total: 10 files within ≤12 budget (17% margin).

### MonitorTag Class Design
```matlab
classdef MonitorTag < Tag

    properties
        Parent Tag
        ConditionFn function_handle
        AlarmOffConditionFn function_handle  % optional; empty → no hysteresis
        MinDuration double = 0  % seconds
        EventStore  % optional EventStore handle; events disabled if empty
        OnEventStart function_handle  % optional
        OnEventEnd function_handle    % optional
    end

    properties (Access = private)
        cache_ struct  % {x, y, computedAt} OR empty
        dirty_ logical = true
    end

    methods
        function obj = MonitorTag(key, parentTag, conditionFn, varargin)
            obj@Tag(key);  % super call
            obj.Parent = parentTag;
            obj.ConditionFn = conditionFn;
            % name-value pairs: 'MinDuration', 'AlarmOffConditionFn',
            %                    'EventStore', 'OnEventStart', 'OnEventEnd',
            %                    plus Tag props (Name, Units, Labels, ...)
            ...
            % Register as listener on parent
            parentTag.addListener(obj);
        end

        function [x, y] = getXY(obj)
            if obj.dirty_ || isempty(obj.cache_)
                obj.recompute_();
            end
            x = obj.cache_.x;
            y = obj.cache_.y;
        end

        function invalidate(obj)
            obj.dirty_ = true;
            obj.cache_ = struct([]);
        end

        function kind = getKind(~)
            kind = 'monitor';
        end
    end

    methods (Access = private)
        function recompute_(obj)
            [px, py] = obj.Parent.getXY();
            if isempty(px)
                obj.cache_ = struct('x', [], 'y', [], 'computedAt', now);
                obj.dirty_ = false;
                return;
            end
            % Evaluate ConditionFn at every parent sample → binary 0/1
            raw = logical(obj.ConditionFn(px, py));
            % Apply hysteresis if AlarmOffConditionFn specified
            if ~isempty(obj.AlarmOffConditionFn)
                raw = applyHysteresis_(px, py, raw, obj.AlarmOffConditionFn);
            end
            % Apply MinDuration debounce
            if obj.MinDuration > 0
                raw = applyDebounce_(px, raw, obj.MinDuration);
            end
            % Compute events on 0→1 transitions
            obj.fireEventsOnRisingEdges_(px, raw);
            obj.cache_ = struct('x', px(:), 'y', double(raw(:)), 'computedAt', now);
            obj.dirty_ = false;
        end
        ...
    end
end
```

### Parent updateData Hook
- Add `addListener(monitorTag)` public method on SensorTag AND StateTag
- Add `notifyListeners_()` private method that iterates `listeners_` and calls `invalidate()` on each
- Hook `notifyListeners_` into places where the delegate's data changes. For SensorTag: in `load()`, `toDisk()`, `toMemory()`, or a new `updateData(x, y)` method. For StateTag: in constructor's data setter (or a new setter).
- **IMPORTANT:** This is ADDITIVE to SensorTag/StateTag. Existing public API unchanged.

### Hysteresis Implementation
- When `AlarmOffConditionFn` is set, raw alarm state flip is two-state machine:
  - State OFF: flip to ON when `ConditionFn(x, y)` is true
  - State ON: flip to OFF when `AlarmOffConditionFn(x, y)` is true
- Implemented as a loop over samples (vectorized scan, 1 pass)

### MinDuration Debounce
- For each contiguous run of 1s in the raw signal, compute duration as `px(end_of_run) - px(start_of_run)`
- If duration < MinDuration, zero out that run
- Vectorized via `[startIdx, endIdx] = findRuns(raw, 1)` + `durations = px(endIdx) - px(startIdx)` + `keepMask = durations >= MinDuration`

### Event Firing (on 0→1 after debounce + hysteresis)
- After debounce + hysteresis resolved, find rising edges: `idx = find(diff([0; rawCol]) == 1)`
- For each rising-edge idx:
  - If `EventStore` is not empty, create Event with:
    - StartTime = px(idx)
    - EndTime = px(falling-edge-after-idx) or NaN if still on
    - TagKeys = {obj.Key, obj.Parent.Key}
    - Severity = default (from Tag.Criticality mapping)
  - Push to `EventStore.add(event)` (or equivalent — read actual Event/EventStore API)
  - If `OnEventStart` function_handle set, call it with the event
- On falling edges, call `OnEventEnd` if set

### ALIGN compliance
- No `interp1(..., 'linear')` calls anywhere in MonitorTag
- When aligning MonitorTag output against a child StateTag (relevant when parent IS a StateTag): use ZOH via `StateTag.valueAt(t)` (matches Phase 1005 ZOH semantics)
- Drop grid points before `max(child.X(1))` — standard industrial pattern

### TagRegistry.instantiateByKind extension
```matlab
case 'monitor'
    tag = MonitorTag.fromStruct(s, registry);  % needs registry to resolve Parent ref
```
- Note: `fromStruct` needs access to the TagRegistry to resolve the `Parent` field from its Key string back to a live Tag handle. This uses the two-phase loader's Pass-2 `resolveRefs(registry)` mechanism from Phase 1004 — MonitorTag overrides `resolveRefs(registry)` to look up its Parent from the registry.

### Error IDs
- `MonitorTag:invalidParent`, `MonitorTag:invalidCondition`, `MonitorTag:noPerSampleCallback`, `MonitorTag:unknownOption`

### Performance / Pitfall 9
- Baseline benchmark: `bench_monitortag_tick.m` creates 12 sensors (representing a 12-widget dashboard), each with 10k points of synthetic data, one threshold per sensor. Measures:
  - Legacy path: 12× `Sensor.resolve()` calls with threshold-rules
  - MonitorTag path: 12× `MonitorTag.getXY()` calls (first call = cold recompute; second = cache hit)
- Report `overhead_pct = (monitor_wall_time - legacy_wall_time) / legacy_wall_time * 100`
- Assert `overhead_pct <= 10`

### Claude's Discretion
- Exact Event struct/class shape — read `libs/EventDetection/Event.m` + `EventStore.m` to match existing API
- Where `notifyListeners_` is called on SensorTag (existing load/toDisk paths vs new updateData method)
- Whether `addListener` is public or a restricted "friend" pattern
- Run-finding algorithm for debounce (vectorized vs loop)
- Whether listeners are weak refs or strong refs (strong is simpler; MATLAB doesn't have weak refs natively)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 1005 `libs/SensorThreshold/SensorTag.m` — needs additive `addListener` + `listeners_` + `notifyListeners_`
- Phase 1005 `libs/SensorThreshold/StateTag.m` — same
- Phase 1005 `libs/FastSense/FastSense.m addTag` — extend switch with `'monitor'` case
- Phase 1004 `libs/SensorThreshold/Tag.m` — base class
- Phase 1004 `libs/SensorThreshold/TagRegistry.m instantiateByKind` — extend with `'monitor'` case
- `libs/SensorThreshold/Threshold.m` (LEGACY, NOT edited) — reference for condition evaluation pattern
- `libs/SensorThreshold/Sensor.m` resolve() method (LEGACY, NOT edited) — reference for the pipeline being REPLACED
- `libs/EventDetection/EventDetector.m` — reference for alarm-detection patterns (MinDuration, hysteresis)
- `libs/EventDetection/Event.m` — Event class structure; MonitorTag emits these
- `libs/EventDetection/EventStore.m` — storage API
- `libs/SensorThreshold/private/compute_violations.m` (or MEX equivalent) — reference for violation detection logic; may be reusable

### Established Patterns
- Handle class + name-value constructor
- Private properties with trailing underscore
- Observer pattern not yet used in repo — first introduction
- Event emission pattern: new Event() → EventStore.add(event)

### Integration Points
- SensorTag/StateTag get listener hooks (additive — existing behavior unchanged)
- FastSense.addTag extended with 'monitor' kind
- TagRegistry.instantiateByKind extended with 'monitor' kind
- EventStore receives MonitorTag-generated events (new consumer, no API changes to EventStore)

</code_context>

<specifics>
## Specific Ideas

- Bench baseline: `bench_monitortag_tick.m` must emulate a 12-widget live-tick. Reuse the existing `LiveEventPipeline` structure if simpler, else build standalone bench.
- Hysteresis test: a sinusoid near the threshold — raw `y > threshold` chatters; with `AlarmOffConditionFn = @(x,y) y < (threshold - 2)`, no chatter. Assert exactly 1 rising edge vs ≥5 without hysteresis.
- MinDuration test: square pulse of 2 seconds duration with MinDuration=5 → zero events fired. Raise duration to 6 seconds → 1 event fired.
- Recursive MonitorTag: MonitorTag wrapping another MonitorTag (for chained derivation). Invalidation must propagate. Add test case.
- MONITOR-10: Verify no per-sample callback API by grep — `grep -c "PerSample\|OnSample\|onEachSample" libs/SensorThreshold/MonitorTag.m` → 0

</specifics>

<deferred>
## Deferred Ideas

- Streaming `appendData` (Phase 1007 — MONITOR-08)
- Disk persistence `Persist=true` (Phase 1007 — MONITOR-09)
- CompositeTag (Phase 1008)
- Auto-discovery via parent listeners (parent auto-lists its derived MonitorTags) — nice-to-have, not required

</deferred>
