# Phase 1009: Consumer migration (one widget at a time) - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning
**Mode:** Auto-generated (plumbing migration phase — additive Tag property on each consumer; legacy paths preserved)

<domain>
## Phase Boundary

Migrate every existing consumer of `Sensor` / `Threshold` / `StateChannel` / `CompositeThreshold` to the new Tag API — ADDITIVELY. Each widget gets an additional `Tag` property that routes through the Tag API when set, while the existing legacy property (Sensor/Threshold/etc.) continues to work through an `isa(input, 'Tag')` branch or analog.

**Per-consumer migration pattern:**
```matlab
% In each widget's refresh or render method:
if ~isempty(obj.Tag)          % NEW Tag-based path
    [x, y] = obj.Tag.getXY();
    ...
elseif ~isempty(obj.Sensor)    % LEGACY path (unchanged)
    [x, y] = obj.Sensor.getXY();
    ...
end
```

**Consumers to migrate (in priority order):**

1. **FastSenseWidget** (`libs/Dashboard/FastSenseWidget.m`) — add `Tag` property; refresh() dispatches by Tag when set; also accept MonitorTag / CompositeTag as Tag (not just SensorTag).
2. **MultiStatusWidget** (`libs/Dashboard/MultiStatusWidget.m`) — items can now reference Tag.Key instead of Threshold.Key; status read via tag.valueAt(now) for MonitorTag/CompositeTag.
3. **IconCardWidget** (`libs/Dashboard/IconCardWidget.m`) — Threshold→Tag route: if Tag is MonitorTag/CompositeTag, derive status from valueAt(now).
4. **EventTimelineWidget** (`libs/Dashboard/EventTimelineWidget.m`) — event lookup via tag-key (MONITOR-05 carrier pattern: Event.SensorName = parent.Key, Event.ThresholdLabel = monitor.Key).
5. **SensorDetailPlot** (`libs/FastSense/SensorDetailPlot.m`) — accept Tag input (renders via getXY instead of Sensor.X/Y).
6. **DashboardWidget base** (`libs/Dashboard/DashboardWidget.m`) — add optional `Tag` property on base class (allows uniform serialization).
7. **EventDetection consumers:**
   - `EventDetector.m` — can operate on SensorTag (not just Sensor) via getXY
   - `LiveEventPipeline.m` — tick path calls `monitor.appendData(newX, newY)` instead of full recompute (Phase 1007 Success Criterion #4 realized here!)
8. **Other widgets** — GaugeWidget, StatusWidget already got Threshold support in Phase 1001-1002. Check if they need additional Tag routing or if existing Threshold binding suffices.

**Out of scope:**
- Deleting legacy classes (Phase 1011)
- Event binding rewrite (Phase 1010)
- Any new REQ-IDs

**Verification gates:**
- Pitfall 5: NO legacy classes deleted. Legacy `addSensor`/`addThreshold` paths alive. All per-commit CIs green.
- Pitfall 9: 12-widget live-tick ≤10% regression vs baseline.
- Pitfall 11: Golden integration test UNTOUCHED (still tests legacy API).
- Every commit independently revertable.

</domain>

<decisions>
## Implementation Decisions

### File Organization (one plan per consumer group)
Structure as 4-5 plans, one per consumer cluster, with each plan being one atomic commit:
- Plan 01: FastSenseWidget + SensorDetailPlot (FastSense-layer consumers)
- Plan 02: Dashboard widgets (MultiStatusWidget + IconCardWidget + EventTimelineWidget; DashboardWidget base Tag property)
- Plan 03: EventDetection consumers (EventDetector + LiveEventPipeline — wire appendData from Phase 1007)
- Plan 04: Pitfall 9 12-widget live-tick benchmark + phase audit

### Migration Pattern (uniform across all consumers)
```matlab
properties
    Tag              % NEW — v2.0 Tag API (any kind)
    Sensor           % LEGACY — still works
    Threshold        % LEGACY (if applicable)
end

methods
    function refresh(obj)
        % Prefer Tag if set
        if ~isempty(obj.Tag)
            if ~isa(obj.Tag, 'Tag')
                error('WidgetName:invalidTag', 'Expected Tag subclass');
            end
            % ... use obj.Tag.getXY() / valueAt() ...
            return;
        end
        % Legacy path (UNCHANGED)
        if ~isempty(obj.Sensor)
            % ... existing code ...
        end
    end
end
```

### FastSenseWidget Changes
- Add `Tag` property (optional, default empty)
- `refresh()` routing: if Tag set, call `obj.FastSense_.addTag(obj.Tag)` on realize, then `obj.FastSense_.updateLineForTag(...)` on tick
- Internal: map Tag.Key → line index for update path
- Round-trip via toStruct/fromStruct: persist Tag.Key if set (on load, look up via TagRegistry.get)

### MultiStatusWidget Changes
- Items struct: allow `tag` field (Tag handle or key string) in addition to existing `threshold`/`sensor` fields
- `refresh()`: if item.tag set, derive status from `tag.valueAt(now)` (0=ok, 1=alarm) with criticality → theme color mapping
- If tag is CompositeTag, traverse children for "expand" view (similar to CompositeThreshold Phase 1003 behavior)

### IconCardWidget Changes
- Add optional `Tag` property
- Route by presence: Tag > Threshold > Sensor (existing order)
- `tag.valueAt(now)` → status boolean

### EventTimelineWidget Changes
- Query events by tag-key: `EventStore.getEventsForTag(tagKey)` — add this method to EventStore if not present, lookup via `SensorName == tagKey OR ThresholdLabel == tagKey` (carrier pattern)
- Display events on timeline with tag-keyed grouping

### SensorDetailPlot Changes
- Accept Tag constructor input (additional overload)
- Internal rendering calls `tag.getXY()` instead of `sensor.X`, `sensor.Y`

### DashboardWidget Base
- Add optional `Tag` property on base (so all subclasses can use uniform serialization)
- toStruct includes Tag.Key if set
- fromStruct resolves via TagRegistry.get in Pass 2 (register all widgets as resolveRefs candidates, or do manual resolution in dashboard load)

### EventDetection Consumers

**EventDetector.m:**
- Add overload: `EventDetector.detect(tagOrSensor, threshold)` — if input isa Tag, call tag.getXY() instead of sensor.getXY()
- No architecture change — just an extra isa branch at entry

**LiveEventPipeline.m:** (realizes Phase 1007 Success Criterion #4)
- Live-tick path: when target is a MonitorTag, call `monitor.appendData(new_x, new_y)` (from Phase 1007) instead of full recompute
- Preserves all existing behavior for Sensor-based targets
- Document tick throughput in Plan 03 SUMMARY (≥ legacy throughput gate)

### Pitfall 9 Bench (Plan 04)
- 12-widget dashboard (mix of FastSenseWidget, MultiStatusWidget, IconCardWidget, etc.)
- 6 widgets bound to Tags (new path), 6 widgets bound to legacy Sensors (baseline)
- Measure tick time for both halves
- Assert `tag_tick_time <= 1.10 × legacy_tick_time`
- Report median of 3 runs

### Claude's Discretion
- Exact order of per-consumer commits (Plan 01-03 are per-cluster; within a cluster, planner picks order)
- Whether SensorDetailPlot gets a new constructor or an opt-in method
- EventStore.getEventsForTag method signature (if it already exists, reuse; else add)
- How much existing Sensor→Tag test infrastructure to reuse vs create new

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 1004-1008 Tag + TagRegistry + SensorTag + StateTag + MonitorTag + CompositeTag
- Phase 1005 FastSense.addTag dispatch (used by widgets)
- Phase 1007 MonitorTag.appendData (used by LiveEventPipeline)
- Phase 1001-1003 Threshold + CompositeThreshold widget binding — pattern to follow for Tag

### Integration Points
- Every widget gets an additional Tag property (additive; legacy properties unchanged)
- Dashboard serialization gains Tag.Key round-trip
- EventDetector + LiveEventPipeline gain Tag awareness

### Strangler-fig Discipline
- Legacy Sensor.m, Threshold.m, CompositeThreshold.m, StateChannel.m STAY
- SensorRegistry, ThresholdRegistry, ExternalSensorRegistry STAY
- Legacy consumer paths (widget.Sensor, widget.Threshold) STAY functional

</code_context>

<specifics>
## Specific Ideas

- LiveEventPipeline.appendData wire-up is the critical Phase 1007 SC#4 realization — include an end-to-end test
- Per-commit revertability: each plan commits to one consumer cluster + its tests in ONE commit
- Golden integration test MUST stay green throughout (Pitfall 11)
- 12-widget bench target: reuse existing bench patterns from Phase 1006 (bench_monitortag_tick.m)

</specifics>

<deferred>
## Deferred Ideas

- Event↔Tag binding rewrite via EventBinding registry (Phase 1010)
- Legacy-class deletion (Phase 1011)
- Asset hierarchy (future milestone)

</deferred>
