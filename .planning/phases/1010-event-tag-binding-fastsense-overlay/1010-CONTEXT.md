# Phase 1010: Event ↔ Tag binding + FastSense overlay - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure + rendering — EventBinding registry + FastSense render layer)

<domain>
## Phase Boundary

Replace denormalized `SensorName`/`ThresholdLabel` carrier strings on `Event` with a proper many-to-many `Event.TagKeys` cell + separate `EventBinding` registry. Render bound events as toggleable round markers on FastSense plots — without polluting the existing line-rendering hot path.

**In scope:**
- `Event.TagKeys` (cell of strings) — replaces SensorName + ThresholdLabel carriers from Phase 1006
- `Event.Severity` numeric field (mapped to theme color via existing StatusOkColor/StatusWarnColor/StatusAlarmColor)
- `Event.Category` field (`'alarm'|'maintenance'|'process_change'|'manual_annotation'`)
- `EventBinding` registry — stores `(eventId, tagKey)` rows; single-write-side rule: only `EventBinding.attach` mutates
- `EventStore.eventsForTag(tagKey)` query — returns events bound via EventBinding
- `Tag.addManualEvent(tStart, tEnd, label, message)` — convenience method on Tag base; writes Event with `Category = 'manual_annotation'`
- `Tag.eventsAttached()` — query method (not stored property); delegates to EventStore
- `FastSense.ShowEventMarkers` property (logical, default true) — when true, `renderEventLayer()` draws round markers at event timestamps after renderLines()
- `renderEventLayer()` — separate render method called after `renderLines()`; single early-out at top if no events. Theme-driven color from `Event.Severity`.

**Critical design constraints:**
- **Event carries NO Tag handles; Tag carries NO Event handles** (Pitfall 4). Events reference tags via `TagKeys` (strings). Tags query events via EventStore (no stored references).
- **Single-write-side rule** — only `EventBinding.attach(eventId, tagKey)` mutates the binding. Convenience wrappers on Event/Tag DELEGATE to EventBinding.
- **Separate render layer** (Pitfall 10) — `renderEventLayer()` is its own method; zero conditionals added to the line-rendering loop in `renderLines()`.
- **0-event early-out** — `renderEventLayer()` starts with `if isempty(events), return; end` — no work when nothing to draw.

**Out of scope:**
- Legacy class deletion (Phase 1011)
- Custom event GUI (future milestone)

**Verification gates:**
- Pitfall 4: grep 0 `Event` properties of type `Tag`/`cell of Tag` and 0 `Tag` properties of type `Event`/`cell of Event`; `save → clear classes → load` round-trip test
- Pitfall 5: ≤12 files
- Pitfall 10: `renderEventLayer()` separate method; no new conditionals in `renderLines()` body; 0-event bench no regression
- EVENT-02: single-write-side `EventBinding.attach`

</domain>

<decisions>
## Implementation Decisions

### File Organization
- EDIT: `libs/EventDetection/Event.m` — add `TagKeys` cell property; add `Severity` numeric; add `Category` char; preserve legacy SensorName + ThresholdLabel as deprecated aliases
- NEW: `libs/EventDetection/EventBinding.m` — singleton registry mapping (eventId, tagKey) pairs; static methods like TagRegistry pattern
- EDIT: `libs/EventDetection/EventStore.m` — `eventsForTag(tagKey)` method now uses `EventBinding.getTagKeysForEvent(eventId)` instead of carrier pattern
- EDIT: `libs/SensorThreshold/Tag.m` — add `addManualEvent(tStart, tEnd, label, message)` convenience method; add `eventsAttached()` query; both delegate to EventStore
- EDIT: `libs/SensorThreshold/MonitorTag.m` — update `fireEventsOnRisingEdges_` to use `Event.TagKeys = {obj.Key, obj.Parent.Key}` and `EventBinding.attach` instead of carrier pattern. Backward-compatible: also set legacy SensorName + ThresholdLabel for any pre-migration consumers
- EDIT: `libs/FastSense/FastSense.m` — add `ShowEventMarkers` property + `renderEventLayer()` private method + call it after `renderLines()` in render()
- Tests: 3-4 new test files + extensions

Total: ~10-12 files.

### EventBinding Registry
```matlab
classdef EventBinding
    methods (Static)
        function attach(eventId, tagKey)
            % Add (eventId, tagKey) pair to binding table
            map = EventBinding.bindings_();
            if ~map.isKey(eventId)
                map(eventId) = {};
            end
            keys = map(eventId);
            if ~ismember(tagKey, keys)
                keys{end+1} = tagKey;
                map(eventId) = keys;
            end
        end
        
        function keys = getTagKeysForEvent(eventId)
            map = EventBinding.bindings_();
            if map.isKey(eventId)
                keys = map(eventId);
            else
                keys = {};
            end
        end
        
        function events = getEventsForTag(tagKey, eventStore)
            % Query eventStore for events bound to tagKey
            allEvents = eventStore.getAll();
            mask = false(numel(allEvents), 1);
            for i = 1:numel(allEvents)
                keys = EventBinding.getTagKeysForEvent(allEvents(i).Id);
                mask(i) = ismember(tagKey, keys);
            end
            events = allEvents(mask);
        end
        
        function clear()
            map = EventBinding.bindings_();
            remove(map, map.keys());
        end
    end
    
    methods (Static, Access = private)
        function map = bindings_()
            persistent bindings
            if isempty(bindings)
                bindings = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
            map = bindings;
        end
    end
end
```

### Event.TagKeys Migration
- Keep legacy `SensorName` and `ThresholdLabel` as regular properties (not removed — backward compat)
- Add `TagKeys` cell property (default `{}`)
- MonitorTag sets both: `event.TagKeys = {obj.Key, obj.Parent.Key}; event.SensorName = obj.Parent.Key; event.ThresholdLabel = obj.Key;`
- Phase 1011 deprecation notice on SensorName/ThresholdLabel in class header

### FastSense renderEventLayer
```matlab
function renderEventLayer(obj)
    % Early-out — no work if no events or rendering disabled
    if ~obj.ShowEventMarkers || isempty(obj.eventStore_)
        return;
    end
    % For each plotted tag, query attached events
    for i = 1:numel(obj.Tags_)
        tag = obj.Tags_{i};
        events = EventBinding.getEventsForTag(tag.Key, obj.eventStore_);
        if isempty(events), continue; end
        % Draw round markers at event start-times
        for j = 1:numel(events)
            ev = events(j);
            % Map severity → theme color
            color = obj.severityToColor_(ev.Severity);
            % Plot marker at (ev.StartTime, y-at-time) on the tag's line
            yVal = tag.valueAt(ev.StartTime);
            line(obj.Axes, ev.StartTime, yVal, 'Marker', 'o', ...
                 'MarkerSize', 8, 'MarkerFaceColor', color, ...
                 'MarkerEdgeColor', color, 'LineStyle', 'none', ...
                 'Tag', sprintf('event_%s_%d', tag.Key, j));
        end
    end
end
```

### Tag.addManualEvent Convenience
```matlab
function addManualEvent(obj, tStart, tEnd, label, message)
    if isempty(obj.EventStore_)
        error('Tag:noEventStore', 'Bind an EventStore before adding events');
    end
    ev = Event();
    ev.StartTime = tStart;
    ev.EndTime = tEnd;
    ev.Label = label;
    ev.Message = message;
    ev.Category = 'manual_annotation';
    ev.TagKeys = {obj.Key};
    ev.SensorName = obj.Key;  % backward compat carrier
    obj.EventStore_.add(ev);
    EventBinding.attach(ev.Id, obj.Key);
end
```

### Error IDs
- `EventBinding:duplicateAttach` (or silent idempotent — design choice)
- `Tag:noEventStore`
- `FastSense:invalidEventStore`

### Claude's Discretion
- Event.Id generation strategy (sequential integer? uuid? counter in EventStore?)
- Whether EventBinding.attach is idempotent (silent) or errors on duplicate
- `severityToColor_` helper implementation (read existing theme color map)
- `Tags_` tracking in FastSense (how addTag populates it — may need a new private property to track which Tags were added for event overlay lookup)
- How renderEventLayer interacts with post-render update path (live tick)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 1006 MonitorTag event emission via carrier (SensorName/ThresholdLabel) — REPLACES with TagKeys
- Phase 1009 EventStore.getEventsForTag (carrier-based) — REPLACES with EventBinding-based query
- Phase 1004 TagRegistry pattern (singleton + persistent containers.Map) — reuse for EventBinding
- libs/EventDetection/Event.m, EventStore.m (current shape — evolve)
- libs/FastSense/FastSense.m render() method (add renderEventLayer call after renderLines)

### Integration Points
- Event.m gains TagKeys + Severity + Category
- EventBinding.m new singleton
- EventStore.eventsForTag uses EventBinding instead of carrier grep
- MonitorTag.fireEventsOnRisingEdges_ uses Event.TagKeys + EventBinding.attach
- FastSense.render calls renderEventLayer after renderLines
- Tag.m gains addManualEvent + eventsAttached convenience methods

</code_context>

<specifics>
## Specific Ideas

- Round markers use MATLAB `line()` with Marker='o' — simple and performant
- severityToColor_ maps severity levels to existing theme colors (StatusOkColor → green, StatusWarnColor → yellow, StatusAlarmColor → red)
- ShowEventMarkers defaults true; users can disable for clean exports
- renderEventLayer must NOT add any conditional to renderLines (Pitfall 10 — grep verify)
- 0-event bench: render 12 lines with ShowEventMarkers=true but no attached events → timing must equal pre-Phase-1010 baseline

</specifics>

<deferred>
## Deferred Ideas

- Custom event GUI (click-drag region selection → label dialog) — future milestone
- Event versioning / definition history
- EventBinding persistence to SQLite (currently in-memory only)

</deferred>
