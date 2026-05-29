# Phase 1010: Event ↔ Tag binding + FastSense overlay - Research

**Researched:** 2026-04-17
**Domain:** Event-Tag many-to-many binding (MATLAB singleton registry) + FastSense render overlay
**Confidence:** HIGH

## Summary

This phase replaces the denormalized `SensorName`/`ThresholdLabel` carrier strings on `Event` with a proper `TagKeys` cell-of-strings property and a separate `EventBinding` singleton registry. The binding pattern reuses the proven `TagRegistry` singleton approach (persistent `containers.Map`). Event rendering on FastSense plots is implemented as a separate `renderEventLayer()` private method called after the existing line-rendering loop in `render()`, with a single early-out for zero events.

The primary technical challenge is that `FastSense.addTag()` currently does NOT store Tag handles -- it immediately extracts `(X, Y)` and delegates to `addLine()`. A new private cell `Tags_` must be added to track which Tags were added, so `renderEventLayer()` can query their bound events. The second challenge is that `Event.m` currently has a mandatory 6-argument constructor and `SetAccess = private` on all properties -- both must be relaxed to support the new optional fields (`TagKeys`, `Severity`, `Category`, `Id`).

**Primary recommendation:** Implement EventBinding as a static-methods-only class with a persistent `containers.Map` (identical to TagRegistry pattern). Add `Event.Id` as an auto-incrementing counter inside `EventStore.append()`. Keep `FastSenseTheme` unchanged -- severity-to-color mapping reads from `DashboardTheme` status colors via the FastSense `Theme` struct (which may or may not have the status fields depending on context).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- EDIT: `libs/EventDetection/Event.m` -- add `TagKeys` cell property; add `Severity` numeric; add `Category` char; preserve legacy SensorName + ThresholdLabel as deprecated aliases
- NEW: `libs/EventDetection/EventBinding.m` -- singleton registry mapping (eventId, tagKey) pairs; static methods like TagRegistry pattern
- EDIT: `libs/EventDetection/EventStore.m` -- `eventsForTag(tagKey)` method now uses `EventBinding.getTagKeysForEvent(eventId)` instead of carrier pattern
- EDIT: `libs/SensorThreshold/Tag.m` -- add `addManualEvent(tStart, tEnd, label, message)` convenience method; add `eventsAttached()` query; both delegate to EventStore
- EDIT: `libs/SensorThreshold/MonitorTag.m` -- update `fireEventsOnRisingEdges_` to use `Event.TagKeys = {obj.Key, obj.Parent.Key}` and `EventBinding.attach` instead of carrier pattern. Backward-compatible: also set legacy SensorName + ThresholdLabel for any pre-migration consumers
- EDIT: `libs/FastSense/FastSense.m` -- add `ShowEventMarkers` property + `renderEventLayer()` private method + call it after line rendering in render()
- Tests: 3-4 new test files + extensions
- Total: ~10-12 files

### EventBinding Registry Design
- Singleton with persistent `containers.Map` (identical to TagRegistry/ThresholdRegistry pattern)
- Static methods: `attach(eventId, tagKey)`, `getTagKeysForEvent(eventId)`, `getEventsForTag(tagKey, eventStore)`, `clear()`
- Single-write-side rule: only `EventBinding.attach` mutates the binding
- `containers.Map('KeyType', 'char', 'ValueType', 'any')` for the persistent store

### Error IDs
- `EventBinding:duplicateAttach` (or silent idempotent -- Claude's discretion)
- `Tag:noEventStore`
- `FastSense:invalidEventStore`

### Claude's Discretion
- Event.Id generation strategy (sequential integer? uuid? counter in EventStore?)
- Whether EventBinding.attach is idempotent (silent) or errors on duplicate
- `severityToColor_` helper implementation (read existing theme color map)
- `Tags_` tracking in FastSense (how addTag populates it)
- How renderEventLayer interacts with post-render update path (live tick)

### Deferred Ideas (OUT OF SCOPE)
- Custom event GUI (click-drag region selection -> label dialog) -- future milestone
- Event versioning / definition history
- EventBinding persistence to SQLite (currently in-memory only)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EVENT-01 | `Event.TagKeys` cell replaces SensorName/ThresholdLabel | Event.m shape analysis; constructor must support optional TagKeys; SetAccess relaxation needed |
| EVENT-02 | Separate `EventBinding` registry; no bidirectional handles | EventBinding singleton design; TagRegistry pattern proven; persistent containers.Map |
| EVENT-03 | `EventStore.eventsForTag(key)` query via EventBinding | Current getEventsForTag uses carrier grep; migrate to EventBinding.getEventsForTag |
| EVENT-04 | `Event.Severity` -> theme color mapping | DashboardTheme has StatusOkColor/StatusWarnColor/StatusAlarmColor; FastSenseTheme does NOT |
| EVENT-05 | `Event.Category` field | Simple char property; drives EventTimelineWidget filter + FastSense overlay style |
| EVENT-06 | `tag.addManualEvent` convenience | Tag base has no EventStore_ property; must add one; MonitorTag already has EventStore |
| EVENT-07 | FastSense round-marker overlay, toggleable, separate render layer | render() has no renderLines method -- lines are inline in render(); renderEventLayer goes after line loop at ~line 1237; Tags_ tracking needed |
</phase_requirements>

## Architecture Patterns

### Critical Finding 1: Event.m Constructor is Mandatory 6-arg

**Confidence: HIGH (verified from source)**

`Event.m` (line 28) has a mandatory constructor: `Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)`. All properties are `SetAccess = private` (line 6).

**Impact:** Cannot simply add `TagKeys`/`Severity`/`Category` as writable properties without changing `SetAccess`. Two options:
1. Change `SetAccess = private` to `SetAccess = public` on the new properties only (split property blocks)
2. Accept them as NV pairs in the constructor

**Recommendation:** Split properties into two blocks: keep existing 14 properties as `SetAccess = private` (backward compat); add new block with `TagKeys`, `Severity`, `Category`, `Id` as public-settable. This is the least-disruptive approach -- existing constructor callers are untouched, new fields are set after construction.

### Critical Finding 2: Event.m Has No Id Property

**Confidence: HIGH (verified by grep)**

`Event.m` has no `Id` property. The CONTEXT.md design requires `EventBinding.attach(eventId, tagKey)` where `eventId` is a char key into the binding map.

**Recommendation (Claude's Discretion):** Use a sequential integer counter inside `EventStore.append()`. When `EventStore.append(ev)` is called:
1. Increment a private counter `nextId_` (initialized to 1)
2. Set `ev.Id = sprintf('evt_%d', obj.nextId_)`
3. This gives each event a unique string ID within its store

Why not UUID: MATLAB has no built-in UUID generator (Octave-portable). Why not construction-time: events created outside an EventStore context would need ad-hoc IDs. Assigning at `append()` time ensures uniqueness within a store.

### Critical Finding 3: FastSense.addTag Does NOT Store Tag Handles

**Confidence: HIGH (verified from source)**

`addTag()` (lines 943-985) immediately calls `tag.getXY()` and delegates to `addLine(x, y, ...)`. The Tag handle is not stored anywhere. For `renderEventLayer()` to query events bound to plotted tags, FastSense needs a new private property `Tags_` (cell array of Tag handles).

**Recommendation:** Add `Tags_ = {}` as a private property. In `addTag()`, after the switch block, append `obj.Tags_{end+1} = tag`. This is additive -- no change to existing line rendering.

### Critical Finding 4: FastSense.render() Has No renderLines Method

**Confidence: HIGH (verified from source)**

The render method is one large function (lines 1016-~1530). Line rendering happens inline in a `for i = 1:numel(obj.Lines)` loop at lines 1161-1237. There is no separate `renderLines()` method.

**Impact on CONTEXT.md design:** The CONTEXT.md says "call renderEventLayer after renderLines". Since renderLines doesn't exist, `renderEventLayer()` should be called after the line rendering loop ends (line 1237) and before threshold rendering begins (line 1251). Or more conservatively, after all rendering is complete but before listener installation (around line 1460).

**Recommendation:** Insert `obj.renderEventLayer_()` call right after the custom markers loop (after line 1389, before axis limits computation at line 1392). This ensures event markers are drawn on top of all data lines and threshold markers, but before axis limits are set (so they don't affect Y limits). Actually -- event markers should NOT affect Y limits (they sit on existing data points), so placement after line 1389 is ideal.

### Critical Finding 5: DashboardTheme Has Status Colors, FastSenseTheme Does NOT

**Confidence: HIGH (verified from source)**

`FastSenseTheme.m` contains NO `StatusOkColor`/`StatusWarnColor`/`StatusAlarmColor` fields. These live in `DashboardTheme.m` (lines 136-138):
```matlab
d.StatusOkColor    = [0.31 0.80 0.64];  % green
d.StatusWarnColor  = [0.91 0.63 0.27];  % yellow/orange
d.StatusAlarmColor = [0.91 0.27 0.38];  % red
```

When FastSense is used inside a `FastSenseWidget` (dashboard context), the widget passes the DashboardTheme which DOES have these fields. When FastSense is used standalone, the theme is a `FastSenseTheme` struct which does NOT.

**Recommendation:** `severityToColor_()` should check `isfield(obj.Theme, 'StatusAlarmColor')` and fall back to hardcoded defaults if the fields are absent:
```matlab
function c = severityToColor_(obj, severity)
    if severity >= 3
        if isfield(obj.Theme, 'StatusAlarmColor')
            c = obj.Theme.StatusAlarmColor;
        else
            c = [0.91 0.27 0.38];  % alarm red
        end
    elseif severity >= 2
        if isfield(obj.Theme, 'StatusWarnColor')
            c = obj.Theme.StatusWarnColor;
        else
            c = [0.91 0.63 0.27];  % warn yellow
        end
    else
        if isfield(obj.Theme, 'StatusOkColor')
            c = obj.Theme.StatusOkColor;
        else
            c = [0.31 0.80 0.64];  % ok green
        end
    end
end
```

### Critical Finding 6: Tag Base Has No EventStore Property

**Confidence: HIGH (verified from source)**

`Tag.m` has 8 properties: Key, Name, Units, Description, Labels, Metadata, Criticality, SourceRef. No `EventStore_` or `EventStore` property. `MonitorTag` has `EventStore` as a public property.

For `Tag.addManualEvent()` to work, Tag needs an `EventStore_` private property (or public). The CONTEXT.md design shows `addManualEvent` checking `isempty(obj.EventStore_)`.

**Recommendation:** Add `EventStore_ = []` as a `SetAccess = private` property on Tag base, with a public setter `setEventStore(obj, store)`. This keeps the Tag API clean. MonitorTag already has its own `EventStore` public property -- the Tag base one is for non-MonitorTag subclasses (SensorTag, StateTag, CompositeTag) that want manual events.

**Important consideration:** MonitorTag's `EventStore` (public) and Tag's `EventStore_` (private) could conflict. The simplest approach: add `EventStore_` to Tag base and in `addManualEvent`, check `obj.EventStore_` first. MonitorTag's `addManualEvent` override (or the base implementation) should also check `obj.EventStore` for backward compat. Actually -- simpler: just use a public `EventStore` property on Tag base. MonitorTag already declares it and will shadow the base. SensorTag/StateTag/CompositeTag inherit it.

Wait -- MATLAB classdef property inheritance: if Tag declares `EventStore` and MonitorTag also declares `EventStore`, that's a redefinition error. MonitorTag already declares `EventStore = []` in its own properties block. So we CANNOT add `EventStore` to Tag base without removing it from MonitorTag.

**Revised recommendation:** Rename MonitorTag's `EventStore` to inherit from Tag. In Phase 1010: add `EventStore = []` to Tag base class. Remove the `EventStore = []` declaration from MonitorTag (it inherits from Tag). MonitorTag constructor NV parsing for `'EventStore'` still works -- it writes to the inherited property. This is the cleanest path.

### Critical Finding 7: EventStore.getEventsForTag Current Implementation

**Confidence: HIGH (verified from source)**

`EventStore.getEventsForTag(tagKey)` (lines 40-73) currently uses the carrier pattern: it checks `ev.SensorName == tagKey || ev.ThresholdLabel == tagKey`. This was added in Phase 1009.

**Migration path:** Replace the carrier-grep loop with EventBinding lookup. The new implementation:
```matlab
function events = getEventsForTag(obj, tagKey)
    events = EventBinding.getEventsForTag(tagKey, obj);
end
```
This delegates to `EventBinding.getEventsForTag(tagKey, eventStore)` which iterates all events, checks `EventBinding.getTagKeysForEvent(ev.Id)`, and returns matches.

**Backward compat concern:** Events created BEFORE Phase 1010 (by MonitorTag's carrier pattern) have no Id and no EventBinding entries. The updated `getEventsForTag` must also fall back to carrier-field matching for events without an Id.

### Critical Finding 8: EventTimelineWidget Uses getEventsForTag

**Confidence: HIGH (verified from source)**

`EventTimelineWidget.resolveEvents()` (line 252) calls `obj.EventStoreObj.getEventsForTag(obj.FilterTagKey)`. Since we're updating `EventStore.getEventsForTag` to use EventBinding, this will automatically work for new events. For pre-Phase-1010 events (no Id), the fallback carrier check ensures backward compatibility.

### Critical Finding 9: MonitorTag Event Emission Sites

**Confidence: HIGH (verified from source)**

MonitorTag has TWO event emission methods:
1. `fireEventsOnRisingEdges_()` (line 696) -- called during full `recompute_()`
2. `fireEventsInTail_()` (line 580) -- called during `appendData()` streaming

Both create events as: `ev = Event(startT, endT, char(obj.Parent.Key), char(obj.Key), NaN, 'upper')` and then call `obj.EventStore.append(ev)`.

**Both must be updated** to:
1. After construction, set `ev.TagKeys = {char(obj.Key), char(obj.Parent.Key)}`
2. After `obj.EventStore.append(ev)` (which assigns ev.Id), call `EventBinding.attach(ev.Id, char(obj.Key))` and `EventBinding.attach(ev.Id, char(obj.Parent.Key))`
3. Keep the existing constructor args (SensorName, ThresholdLabel) for backward compat

### Critical Finding 10: MATLAB `line()` for Round Markers

**Confidence: HIGH (MATLAB built-in)**

The CONTEXT.md design uses `line(ax, x, y, 'Marker', 'o', ...)` for round markers. This is the standard MATLAB approach and is already used extensively in FastSense (violation markers use `line()` with `'Marker', '.'`).

For performance on live tick: markers should be drawn as a SINGLE `line()` call per severity level (batch all x/y coordinates), not one `line()` per event. This avoids creating N graphics objects.

**Recommendation:** Collect all event marker coordinates per severity level, then draw one `line()` per level:
```matlab
line(ax, allX_alarm, allY_alarm, 'Marker', 'o', 'MarkerSize', 8, ...
     'MarkerFaceColor', alarmColor, 'MarkerEdgeColor', alarmColor, ...
     'LineStyle', 'none', 'HandleVisibility', 'off');
```

### Tag.valueAt Availability

**Confidence: HIGH (verified from source)**

The CONTEXT.md design has `renderEventLayer` calling `tag.valueAt(ev.StartTime)` to get the Y coordinate for placing event markers. All Tag subclasses implement `valueAt(t)`:
- SensorTag: binary search + interpolation
- StateTag: ZOH lookup
- MonitorTag: ZOH lookup into cached 0/1
- CompositeTag: aggregated valueAt

This works correctly. The marker will appear at the correct Y position on the tag's line.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Singleton registry | Custom global variable | `containers.Map` in persistent var (TagRegistry pattern) | Proven Octave-portable; garbage-collected; thread-safe enough for MATLAB |
| Event Id generation | UUID / random | Sequential counter in EventStore.append | Simple, deterministic, Octave-portable; no external deps |
| Graphics markers | Per-event `line()` calls | Batched single `line()` per severity | 100x fewer graphics objects; critical for live tick performance |

## Common Pitfalls

### Pitfall 1: MonitorTag EventStore Property Shadowing
**What goes wrong:** Adding `EventStore` to Tag base while MonitorTag already declares it causes a MATLAB redefinition error.
**Why it happens:** MATLAB does not allow a subclass to redeclare a property that exists on the base class.
**How to avoid:** Add `EventStore = []` to Tag.m AND remove the `EventStore = []` line from MonitorTag.m's properties block. MonitorTag's constructor NV parsing for `'EventStore'` continues to work -- it writes to the inherited property.
**Warning signs:** `?? Error using MonitorTag` at class load time.

### Pitfall 2: Event Constructor Backward Compatibility
**What goes wrong:** Changing Event's constructor signature breaks all existing callers (EventDetector, MonitorTag, tests).
**Why it happens:** Event has a strict 6-arg constructor.
**How to avoid:** Keep the existing 6-arg constructor. Add new properties (TagKeys, Severity, Category, Id) in a separate properties block with `Access = public`. Set them AFTER construction.
**Warning signs:** Errors in `EventDetector.detect_()` or `MonitorTag.fireEventsOnRisingEdges_()`.

### Pitfall 3: EventBinding.getEventsForTag Performance
**What goes wrong:** Iterating all events in EventStore for every tag query is O(N*M) where N=events, M=bindings.
**Why it happens:** EventBinding stores (eventId -> tagKeys), not (tagKey -> eventIds).
**How to avoid:** Add a reverse index (`containers.Map` from tagKey -> cell of eventIds) in EventBinding. Maintain it in `attach()`. Query is O(1) lookup + O(K) filter where K = events for that tag.
**Warning signs:** Slow dashboard refresh with many events.

### Pitfall 4: Pre-Phase-1010 Events Have No Id
**What goes wrong:** Events created before Phase 1010 have no Id property, so EventBinding queries return nothing.
**Why it happens:** Old events were created with the legacy constructor; Id was not assigned.
**How to avoid:** In `EventStore.getEventsForTag()`, fall back to carrier-field matching (`SensorName`/`ThresholdLabel`) for events where `Id` is empty or the property doesn't exist.
**Warning signs:** EventTimelineWidget shows no events after Phase 1010 upgrade.

### Pitfall 5: renderEventLayer in Live Tick Path
**What goes wrong:** `renderEventLayer()` is called only in `render()` but not during live updates, so new events from `appendData()` don't show markers.
**Why it happens:** The live tick path uses `updateData()` which re-downsamples lines but doesn't call `renderEventLayer()`.
**How to avoid:** Store event marker handles in a private property (e.g., `EventMarkerHandles_ = []`). In `renderEventLayer()`, delete old handles before creating new ones. Call `renderEventLayer()` from the live update path as well (or expose a separate `refreshEventMarkers()` method).
**Warning signs:** Event markers appear on initial render but not after live data arrives.

### Pitfall 6: Tag.EventStore Needs a Setter for Event Id Assignment
**What goes wrong:** `Tag.addManualEvent()` creates an Event and calls `EventStore.append(ev)`, but `append()` modifies `ev.Id` on its copy, not the caller's copy (MATLAB value/handle semantics).
**Why it happens:** If Event is a handle class (it IS -- `classdef Event < handle`), then `append(ev)` CAN modify the original. But EventStore.append currently does NOT set Id.
**How to avoid:** EventStore.append must set `ev.Id` on the handle before returning. Since Event < handle, the caller's reference sees the updated Id. Then `EventBinding.attach(ev.Id, tagKey)` works.
**Warning signs:** `ev.Id` is empty after `EventStore.append(ev)`.

## File-Touch Inventory (Pitfall 5 gate: <= 12 files)

| # | File | Action | Reason |
|---|------|--------|--------|
| 1 | `libs/EventDetection/Event.m` | EDIT | Add TagKeys, Severity, Category, Id properties |
| 2 | `libs/EventDetection/EventBinding.m` | NEW | Singleton registry (eventId, tagKey) |
| 3 | `libs/EventDetection/EventStore.m` | EDIT | Auto-assign Id in append(); update getEventsForTag |
| 4 | `libs/SensorThreshold/Tag.m` | EDIT | Add EventStore property + addManualEvent + eventsAttached |
| 5 | `libs/SensorThreshold/MonitorTag.m` | EDIT | Update fireEventsOnRisingEdges_ and fireEventsInTail_ |
| 6 | `libs/FastSense/FastSense.m` | EDIT | Add ShowEventMarkers, Tags_, eventStore_, renderEventLayer_ |
| 7 | `tests/test_event_binding.m` | NEW | EventBinding unit tests |
| 8 | `tests/test_event_tag_binding.m` | NEW | Event.TagKeys + EventStore.eventsForTag integration |
| 9 | `tests/test_tag_manual_event.m` | NEW | Tag.addManualEvent + eventsAttached |
| 10 | `tests/test_fastsense_event_overlay.m` | NEW | FastSense renderEventLayer (headless-safe) |
| 11 | `tests/test_event.m` | EDIT | Add tests for new properties (TagKeys, Severity, Category, Id) |

**Total: 11 files (within <= 12 budget)**

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Octave-style function-based tests + MATLAB suite tests |
| Config file | `tests/run_all_tests.m` |
| Quick run command | `cd tests && octave --eval "test_event_binding"` |
| Full suite command | `cd tests && octave --eval "run_all_tests"` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EVENT-01 | Event.TagKeys cell property works | unit | `octave --eval "test_event"` | Extend existing |
| EVENT-02 | EventBinding attach/getTagKeysForEvent/getEventsForTag | unit | `octave --eval "test_event_binding"` | Wave 0 |
| EVENT-03 | EventStore.eventsForTag uses EventBinding | integration | `octave --eval "test_event_tag_binding"` | Wave 0 |
| EVENT-04 | Event.Severity maps to theme color | unit | `octave --eval "test_fastsense_event_overlay"` | Wave 0 |
| EVENT-05 | Event.Category field | unit | `octave --eval "test_event"` | Extend existing |
| EVENT-06 | tag.addManualEvent writes Event with manual_annotation | unit | `octave --eval "test_tag_manual_event"` | Wave 0 |
| EVENT-07 | FastSense renders event markers, toggleable | smoke | `octave --eval "test_fastsense_event_overlay"` | Wave 0 |

### Sampling Rate
- **Per task commit:** quick run of the specific test file
- **Per wave merge:** full suite via `run_all_tests.m`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_event_binding.m` -- covers EVENT-02
- [ ] `tests/test_event_tag_binding.m` -- covers EVENT-01, EVENT-03
- [ ] `tests/test_tag_manual_event.m` -- covers EVENT-06
- [ ] `tests/test_fastsense_event_overlay.m` -- covers EVENT-04, EVENT-07

## Code Examples

### Event.m New Properties Block (after existing SetAccess = private block)
```matlab
properties
    TagKeys   = {}   % cell of char: tag keys bound to this event (EVENT-01)
    Severity  = 1    % numeric: 1=ok, 2=warn, 3=alarm (EVENT-04)
    Category  = ''   % char: 'alarm'|'maintenance'|'process_change'|'manual_annotation' (EVENT-05)
    Id        = ''   % char: unique id assigned by EventStore.append (EVENT-02)
end
```

### EventStore.append with Auto-Id
```matlab
function append(obj, newEvents)
    if isempty(newEvents); return; end
    for i = 1:numel(newEvents)
        obj.nextId_ = obj.nextId_ + 1;
        newEvents(i).Id = sprintf('evt_%d', obj.nextId_);
        if isempty(obj.events_)
            obj.events_ = newEvents(i);
        else
            obj.events_(end+1) = newEvents(i);
        end
    end
end
```

### EventBinding.attach with Idempotent Check
```matlab
function attach(eventId, tagKey)
    fwdMap = EventBinding.bindings_();
    revMap = EventBinding.reverseIndex_();
    % Forward: eventId -> {tagKey1, tagKey2, ...}
    if fwdMap.isKey(eventId)
        keys = fwdMap(eventId);
        if ismember(tagKey, keys), return; end  % idempotent
        keys{end+1} = tagKey;
        fwdMap(eventId) = keys;
    else
        fwdMap(eventId) = {tagKey};
    end
    % Reverse: tagKey -> {eventId1, eventId2, ...}
    if revMap.isKey(tagKey)
        ids = revMap(tagKey);
        ids{end+1} = eventId;
        revMap(tagKey) = ids;
    else
        revMap(tagKey) = {eventId};
    end
end
```

### FastSense.addTag with Tag Handle Tracking
```matlab
function addTag(obj, tag, varargin)
    % ... existing switch block ...
    % After the switch:
    obj.Tags_{end+1} = tag;
end
```

### FastSense.renderEventLayer_
```matlab
function renderEventLayer_(obj)
    if ~obj.ShowEventMarkers || isempty(obj.Tags_) || isempty(obj.eventStore_)
        return;
    end
    % Delete old markers
    for i = 1:numel(obj.EventMarkerHandles_)
        if ishandle(obj.EventMarkerHandles_{i})
            delete(obj.EventMarkerHandles_{i});
        end
    end
    obj.EventMarkerHandles_ = {};
    % Collect markers by severity
    xBySev = {[], [], []};  % ok, warn, alarm
    yBySev = {[], [], []};
    for i = 1:numel(obj.Tags_)
        tag = obj.Tags_{i};
        events = obj.eventStore_.getEventsForTag(tag.Key);
        if isempty(events), continue; end
        for j = 1:numel(events)
            ev = events(j);
            sev = max(1, min(3, ev.Severity));
            yVal = tag.valueAt(ev.StartTime);
            xBySev{sev}(end+1) = ev.StartTime;
            yBySev{sev}(end+1) = yVal;
        end
    end
    colors = {obj.severityToColor_(1), obj.severityToColor_(2), obj.severityToColor_(3)};
    for s = 1:3
        if ~isempty(xBySev{s})
            h = line(obj.hAxes, xBySev{s}, yBySev{s}, ...
                'Marker', 'o', 'MarkerSize', 8, ...
                'MarkerFaceColor', colors{s}, 'MarkerEdgeColor', colors{s}, ...
                'LineStyle', 'none', 'HandleVisibility', 'off');
            obj.EventMarkerHandles_{end+1} = h;
        end
    end
end
```

## Open Questions

1. **EventStore binding on FastSense**
   - What we know: FastSense needs an eventStore_ property to pass to renderEventLayer_. Users must bind it somehow.
   - What's unclear: Should it be a public property `EventStore` (like MonitorTag)? Or inferred from Tags_ (each MonitorTag has its own EventStore)?
   - Recommendation: Add a public `EventStore` property on FastSense. If not set, try to read it from the first MonitorTag in Tags_ (convenience auto-discovery). This covers both the explicit-binding and the "it just works" cases.

2. **Live tick refresh of event markers**
   - What we know: render() is called once; live updates use updateData(). renderEventLayer_ runs in render() but not in updateData().
   - What's unclear: Should new events from appendData appear immediately?
   - Recommendation: Store marker handles. In the live update path, optionally call renderEventLayer_ if ShowEventMarkers is true. Keep it lightweight with the 0-event early-out.

3. **Severity numeric mapping**
   - What we know: CONTEXT.md says "numeric, mapped to theme color via StatusOkColor/StatusWarnColor/StatusAlarmColor"
   - What's unclear: Exact numeric mapping (1/2/3? 0/1/2? continuous?)
   - Recommendation: Use 1=info/ok (green), 2=warning (yellow), 3=alarm (red). Default to 1. ISA-18.2 uses priority 1-4 but we keep it simple with 3 levels matching 3 theme colors.

## Project Constraints (from CLAUDE.md)

- Pure MATLAB, no external dependencies
- Octave 7+ compatibility required (no `dictionary`, no `enumeration`, no `arguments` blocks, no `events`/listeners blocks)
- Handle classes inherit from `handle`
- Error IDs: `ClassName:camelCaseProblem` pattern
- Properties: PascalCase for public, trailing underscore for private internals
- MISS_HIT style: 160 char line length, 4-space tabs
- Tests: Octave function-based `test_*.m` pattern with `add_*_path()` helper
- No new MEX kernels

## Sources

### Primary (HIGH confidence)
- `libs/EventDetection/Event.m` -- full source read; 6-arg constructor, SetAccess = private, no Id property
- `libs/EventDetection/EventStore.m` -- full source read; append/getEventsForTag/save API
- `libs/EventDetection/EventDetector.m` -- full source read; 2-arg Tag overload + legacy 6-arg
- `libs/SensorThreshold/MonitorTag.m` -- full source read; fireEventsOnRisingEdges_ + fireEventsInTail_ carrier pattern
- `libs/SensorThreshold/Tag.m` -- full source read; 8 properties, no EventStore
- `libs/FastSense/FastSense.m` -- render() method (lines 1016-1530); addTag (lines 943-985); no Tags_ tracking
- `libs/FastSense/FastSenseTheme.m` -- full source read; NO StatusOk/Warn/Alarm colors
- `libs/Dashboard/DashboardTheme.m` -- grep verified StatusOkColor/StatusWarnColor/StatusAlarmColor at lines 136-138
- `libs/Dashboard/EventTimelineWidget.m` -- full source read; uses getEventsForTag + carrier-based struct conversion

### Secondary (MEDIUM confidence)
- MATLAB `line()` marker syntax -- standard MATLAB API, extensively used in the codebase already

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - pure MATLAB, no new deps, patterns proven in codebase
- Architecture: HIGH - all source files read; critical findings verified from code
- Pitfalls: HIGH - identified from actual code structure, not speculation

**Research date:** 2026-04-17
**Valid until:** 2026-05-17 (stable codebase, no external dependencies)
