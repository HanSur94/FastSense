# Phase 1017: Tag System Event Auto-Wiring — Research

**Researched:** 2026-04-28
**Domain:** MATLAB — TagRegistry singleton, MonitorTag event emission, FastSense/Dashboard EventStore wiring
**Confidence:** HIGH (all findings verified against source code; no external dependencies)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Dual-key event emission.** `MonitorTag.fireEvent` (and the alarm-off path) set `ev.TagKeys = {monitor.Key, parent.Key}` so events are self-describing and `EventStore.getEventsForTag(parentKey)` finds them without needing the store to walk the registry. Chosen over the registry-walk alternative because it keeps `EventStore` decoupled from `TagRegistry` on the read path and makes serialized events stand alone.
- **Registry-default EventStore lives on `TagRegistry`.** Mirrors the existing `catalog()` persistent-cache pattern: add static methods `TagRegistry.setEventStore(store)` and `TagRegistry.getEventStore()` backed by a persistent variable. Rejected creating a separate `EventStoreRegistry` class — the registry is already the singleton root for tag-scoped cross-cutting concerns.
- **Explicit per-instance store wins, silently.** When a MonitorTag, FastSenseWidget, EventTimelineWidget, or TableWidget(events) is constructed with an explicit `EventStore` / `EventStoreObj`, that store is used as before; the registry default is only consulted when the explicit slot is empty. No deprecation warning, no log line — preserves the absolute silence of existing scripts and tests.
- **No new error IDs.** The registry-default lookup must be safe to call before any store has been registered (returns `[]` — consumers fall back to their pre-1017 behavior).
- **Demo migration is in scope.** `demo/industrial_plant/private/registerPlantTags.m` drops the per-MonitorTag `'EventStore', store` pairs and adds a single `TagRegistry.setEventStore(store)` near the top. The `build*Page.m` helpers drop any explicit `'EventStore'` NV-pair on FastSenseWidget / EventTimelineWidget / TableWidget calls. Migrating them in this phase proves the API is actually ergonomic in practice.
- **example_event_markers.m migration is in scope** as a second canonical example, since it is the existing reference for "events on plots".

### Claude's Discretion

None explicitly listed.

### Deferred Ideas (OUT OF SCOPE)

- A separate `EventStoreRegistry` per kind (per-tag-class scoping) — premature abstraction; registry-wide singleton is sufficient.
- Deprecation warning on explicit duplicate wiring — would break "absolute silence for existing scripts" rule. Can revisit in a future cleanup phase.
- Walk-the-registry approach in `EventStore.getEventsForTag` — rejected for this phase (couples EventStore to TagRegistry on the hot read path); the dual-key approach delivers the same outcome with fewer entanglements.

</user_constraints>

---

## Summary

Phase 1017 makes EventStore wiring opt-in by placing a registry-wide default on `TagRegistry` and fixing a hidden key-mismatch bug in `MonitorTag` event emission. The work is a precise six-file edit with one consistent pattern applied at each site: check explicit slot first, fall back to `TagRegistry.getEventStore()` when empty.

The hidden bug is already partially fixed: both `fireEventsOnRisingEdges_` (line 877) and `appendData` (lines 738, 763) already stamp `ev.TagKeys = {char(obj.Key), char(obj.Parent.Key)}` and call `EventBinding.attach` for both keys — but only when `obj.EventStore` is non-empty. The dual-key stamp path is therefore gated on EventStore being present. After Phase 1017, MonitorTag's constructor will fall back to `TagRegistry.getEventStore()`, so the stamp path fires even when no per-instance EventStore was supplied. No new stamp logic is needed in `fireEventsOnRisingEdges_` or `appendData` — just the constructor fallback.

The early-return guard at `fireEventsOnRisingEdges_:862` (`if isempty(obj.EventStore) && isempty(obj.OnEventStart) && isempty(obj.OnEventEnd)`) means events are silently suppressed when no store and no callbacks are wired. The fix must land in the constructor so `obj.EventStore` is populated before first use.

**Primary recommendation:** Add `TagRegistry.setEventStore` / `getEventStore` backed by a private `eventStoreRef_()` persistent-cache helper, wire the constructor fallback into MonitorTag (single line), then add a registry-fallback tail to each consumer's existing `isempty(es)` chain.

---

## Standard Stack

No external packages. All changes are pure MATLAB classdef edits.

| File | Role | Verified location |
|------|------|-------------------|
| `libs/SensorThreshold/TagRegistry.m` | Add `setEventStore` / `getEventStore` static methods + private `eventStoreRef_()` helper | Line 374 (after existing `catalog()` helper) |
| `libs/SensorThreshold/MonitorTag.m` | Add constructor fallback to `TagRegistry.getEventStore()` when `'EventStore'` NV not provided | Lines 169-183 (NV-pair switch block); sentinel after the loop |
| `libs/FastSense/FastSense.m` | Add `TagRegistry.getEventStore()` tail to `renderEventLayer_` fallback chain | Lines 2304-2314 (existing loop) |
| `libs/Dashboard/FastSenseWidget.m` | Add registry fallback before forwarding to inner `FastSense` | Lines 101-104 (existing guard block) |
| `libs/Dashboard/EventTimelineWidget.m` | Add registry fallback in `resolveEvents()` before returning `evts = []` | Lines 266-273 (existing `isempty(obj.EventStoreObj)` check) |
| `libs/Dashboard/TableWidget.m` | Add registry fallback in events branch | Line 86 (existing `~isempty(obj.EventStoreObj)` guard) |

---

## Architecture Patterns

### Pattern 1: `eventStoreRef_()` private persistent-cache helper on TagRegistry

Mirrors the existing `catalog()` helper exactly. Stores an `EventStore` handle (or `[]`) in a `persistent` variable. `setEventStore` writes to it; `getEventStore` reads from it. `clear()` must also reset this persistent.

```matlab
% Source: TagRegistry.m lines 374-386 (catalog() — the model to copy)
methods (Static, Access = private)
    function ref = eventStoreRef_()
        %EVENTSTOREREF_ Persistent slot for the registry-default EventStore.
        %   Initialized to [] on first call; set via TagRegistry.setEventStore.
        %   Tests call TagRegistry.clear() which also resets this slot.
        persistent store;
        if isempty(store)
            store = {[]};  % cell wrapper so isempty(store) distinguishes
        end                % "not yet initialized" from "initialized to []"
        ref = store;
    end
end
```

**Cell-wrapper note:** A bare `persistent store; if isempty(store), store = []; end` cannot distinguish "never initialized" from "initialized to []". Use a 1-element cell `{[]}` as the container so the persistent variable itself is never empty after initialization, but `store{1}` can be `[]`. `getEventStore` returns `store{1}`; `setEventStore(s)` sets `store{1} = s`.

**`clear()` extension:** The existing `clear()` (lines 109-116) iterates `map.keys()` and removes each. Add `ref = TagRegistry.eventStoreRef_(); ref{1} = [];` at the end so test isolation resets the store too. Since `ref` is a handle-like cell returned by value from the persistent, mutation via `ref{1} = []` does NOT propagate back to the persistent. Instead use a two-persistent approach or a containers.Map wrapper — see Pitfall 1 below.

### Pattern 2: Consumer registry-fallback chain (three-line tail)

Applied identically at FastSense, FastSenseWidget, EventTimelineWidget, and TableWidget. Each already has an `if isempty(es)` or `if isempty(obj.EventStoreObj)` guard. Append one clause before the final `return`:

```matlab
% After existing tag-EventStore loop in FastSense.renderEventLayer_ (line 2314)
if isempty(es)
    es = TagRegistry.getEventStore();
end
if isempty(es), return; end
```

### Pattern 3: MonitorTag constructor fallback

The NV-pair switch already handles `'EventStore'` at line 169. After the `for` loop (line 183), add a fallback for the case where no explicit store was provided:

```matlab
% After the for i = 1:2:numel(monArgs) loop
if isempty(obj.EventStore)
    obj.EventStore = TagRegistry.getEventStore();
end
```

This single addition makes the existing dual-key stamp paths in `fireEventsOnRisingEdges_` and `appendData` fire automatically, because those paths are already gated on `~isempty(obj.EventStore)`.

### Recommended Project Structure (no change)

```
libs/SensorThreshold/
    TagRegistry.m        ← add setEventStore / getEventStore / eventStoreRef_()
    MonitorTag.m         ← add constructor fallback (3 lines)
libs/FastSense/
    FastSense.m          ← extend renderEventLayer_ fallback chain (3 lines)
libs/Dashboard/
    FastSenseWidget.m    ← extend render() guard block (3 lines)
    EventTimelineWidget.m ← extend resolveEvents() (3 lines)
    TableWidget.m        ← extend refresh() events branch (3 lines)
demo/industrial_plant/private/
    registerPlantTags.m  ← add setEventStore call; drop 4 'EventStore' NV-pairs
    buildEventsPage.m    ← drop 'EventStoreObj', ctx.store (already using registry default)
tests/suite/
    TestDashboardEventsToggle.m ← add 4 new test methods
tests/
    test_dashboard_events_toggle.m ← add 4 new test blocks
```

### Anti-Patterns to Avoid

- **Mutating a persistent cell via returned copy:** Returning `ref = store` from `eventStoreRef_()` and then doing `ref{1} = x` outside does NOT update the persistent. Must mutate inside the function or use a containers.Map (handle-class) so mutations propagate.
- **Stamping TagKeys outside the `~isempty(obj.EventStore)` guard:** The dual-key stamp and `EventBinding.attach` calls in `fireEventsOnRisingEdges_` (line 874-879) and `appendData` (lines 738-741, 762-765) are already gated on `~isempty(obj.EventStore)`. Do NOT move the stamp outside that guard — EventBinding.attach requires a valid eventId (assigned by EventStore.append), so it must always run after append.
- **Applying registry fallback in FastSenseWidget.refresh() instead of render():** The `fp.EventStore` forwarding at line 103 happens once at render time. `refresh()` does not re-forward the store. The fallback belongs in the `render()` guard block so the inner FastSense gets the store before its first `renderEventLayer_` call.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Event-to-tag lookup | Custom tagKey scan in EventStore.getEventsForTag | EventBinding reverse index (already exists, O(1)) | EventBinding already handles both paths: EventBinding-based lookup + carrier-field fallback |
| Persistent singleton | New class or module-level global | `persistent` variable inside a static `Access=private` method | Established pattern in TagRegistry.catalog() and EventBinding.bindings_() |
| Cell-persistent mutation | Returning cell ref and mutating externally | Use containers.Map (handle class) as the persistent, so mutation propagates | Maps are handles — assignment to `map('key') = val` mutates in place through any reference |

---

## Verified Current State of Each Edit Site

### 1. TagRegistry.m — no `setEventStore`/`getEventStore` yet

Lines 365-387 contain `methods (Static, Access = private)` with only `truncStr` and `catalog()`. There is no `eventStoreRef_` helper and no public `setEventStore`/`getEventStore`. The `clear()` method (lines 109-116) touches only the catalog map.

**Required:** Add two public static methods and one private helper. Extend `clear()` to reset the store slot.

### 2. MonitorTag.m — `'EventStore'` NV handled, no registry fallback yet

Lines 163-183: NV-pair `for` loop handles `'EventStore'` at line 169-170 (`obj.EventStore = monArgs{i+1}`). After the loop (line 183), there is no fallback. The early-return in `fireEventsOnRisingEdges_` (line 862) gates all event emission on `~isempty(obj.EventStore)`.

**Dual-key stamp status (VERIFIED):** Both `fireEventsOnRisingEdges_` (lines 877-879) and `appendData` (lines 738-741, 762-765) already stamp `ev.TagKeys = {char(obj.Key), char(obj.Parent.Key)}` and call `EventBinding.attach` for both keys — gated on `~isempty(obj.EventStore)`. The stamp code is correct; only the constructor fallback is missing.

**Required:** 3 lines after the NV loop (lines 183-185 insert point):
```matlab
if isempty(obj.EventStore)
    obj.EventStore = TagRegistry.getEventStore();
end
```

### 3. FastSense.m — auto-discovery loop ends at line 2314, no registry tail

Lines 2304-2313: The existing loop iterates `obj.Tags_` and checks `isprop(t, 'EventStore') && ~isempty(t.EventStore)`. If nothing found, `es` remains `[]` and line 2314 is `if isempty(es), return; end`.

**Required:** Replace the `if isempty(es), return; end` with:
```matlab
if isempty(es)
    es = TagRegistry.getEventStore();
end
if isempty(es), return; end
```

### 4. FastSenseWidget.m — EventStore forwarding at lines 101-104, no registry fallback

Lines 101-104:
```matlab
if obj.ShowEventMarkers || ~isempty(obj.EventStore)
    fp.ShowEventMarkers = obj.ShowEventMarkers;
    fp.EventStore       = obj.EventStore;
end
```
When `obj.EventStore` is empty and `obj.ShowEventMarkers` is false, nothing is forwarded to the inner FastSense. FastSense will then run its own auto-discovery (which now includes the registry tail from edit site 3).

**Decision:** The cleanest approach is to resolve the registry default at the widget level too, so `fp.EventStore` is populated even when neither `obj.EventStore` nor `obj.ShowEventMarkers` was set:
```matlab
esForward = obj.EventStore;
if isempty(esForward)
    esForward = TagRegistry.getEventStore();
end
if obj.ShowEventMarkers || ~isempty(esForward)
    fp.ShowEventMarkers = obj.ShowEventMarkers;
    fp.EventStore       = esForward;
end
```
This ensures the inner FastSense gets the registry-default store so its `renderEventLayer_` can fire.

### 5. EventTimelineWidget.m — `resolveEvents()` at lines 266-284

Lines 266-273: `if ~isempty(obj.EventStoreObj)` — when empty, falls through to `EventFcn` or `Events` static array. No registry lookup.

**Required:** After `elseif ~isempty(obj.Events)` block (line 283 closes), before the function ends, add:
```matlab
% Registry-default fallback (Phase 1017)
if isempty(evts)
    defaultStore = TagRegistry.getEventStore();
    if ~isempty(defaultStore)
        if ~isempty(obj.FilterTagKey)
            raw  = defaultStore.getEventsForTag(obj.FilterTagKey);
            evts = obj.eventObjectsToStructs(raw);
        else
            obj.EventStoreObj = defaultStore;
            evts = obj.eventStoreToStructs();
            obj.EventStoreObj = [];
        end
    end
end
```
Alternatively, simpler: populate `obj.EventStoreObj` from the registry at the top of `resolveEvents()` only for the duration of this call (local variable approach avoids side effects on `obj`).

**Simpler pattern (preferred):**
```matlab
function evts = resolveEvents(obj)
    evts = [];
    esObj = obj.EventStoreObj;
    if isempty(esObj)
        esObj = TagRegistry.getEventStore();  % Phase 1017 registry fallback
    end
    if ~isempty(esObj)
        if ~isempty(obj.FilterTagKey)
            raw  = esObj.getEventsForTag(obj.FilterTagKey);
            evts = obj.eventObjectsToStructs(raw);
        else
            % temporarily bind so eventStoreToStructs() can access it
            obj.EventStoreObj = esObj;
            evts = obj.eventStoreToStructs();
            obj.EventStoreObj = [];
        end
    elseif ...
```
This requires `eventStoreToStructs` to use `obj.EventStoreObj` (it already does, line 304). The temporary assignment approach works but is somewhat fragile. A cleaner alternative is passing `esObj` as an argument into `eventStoreToStructs_` — but that requires refactoring a private method. Given the existing pattern, the local variable approach using `esObj` throughout `resolveEvents` (not temporarily mutating `obj`) is cleanest: re-read `getEvents()` directly from `esObj`.

### 6. TableWidget.m — events branch at line 86

Line 86: `elseif strcmp(obj.Mode, 'events') && ~isempty(obj.EventStoreObj)`. When `obj.EventStoreObj` is empty, the events branch is skipped.

**Required:**
```matlab
esObj = obj.EventStoreObj;
if isempty(esObj)
    esObj = TagRegistry.getEventStore();  % Phase 1017 registry fallback
end
% ... then replace obj.EventStoreObj with esObj in the branch condition and body
```

### 7. registerPlantTags.m — 4 explicit `'EventStore', store` NV-pairs to remove

Lines 107, 117, 127, 135 pass `'EventStore', store` to each MonitorTag constructor. After Phase 1017, replace with a single `TagRegistry.setEventStore(store)` call after line 53 (`store = EventStore(eventFile);`).

The function signature `[store, plantHealthKey] = registerPlantTags(rawDir)` returns the store — callers (`run_demo.m` etc.) use it for explicit dashboard wiring today. After Phase 1017, those explicit wirings in `buildEventsPage.m` can be dropped too, but the return value can be preserved for callers that still want the handle for persistence/save operations.

### 8. buildEventsPage.m — `'EventStoreObj', ctx.store` at line 57

This is the only explicit `EventStoreObj` NV-pair in any build page. After Phase 1017, drop it. The `EventTimelineWidget` will discover the registry default. The `FilterTagKey` NV-pair stays (it controls filtering, not the store source).

### 9. example_event_markers.m — explicit `'EventStore', es` on two `addWidget` calls

Lines 45, 48 pass `'EventStore', es` to the `'fastsense'` widget type. After Phase 1017, replace with a single `TagRegistry.setEventStore(es)` call before `d.addWidget(...)`. Drop the per-widget `'EventStore', es` NV-pairs. Also drop `'ShowEventMarkers', true` since the registry-default store is now present — though keeping `ShowEventMarkers=true` is valid (it is the `FastSenseWidget` show flag, not the discovery mechanism).

---

## EventStore.getEventsForTag — How It Actually Works (Critical)

This was a key verification target. The implementation (lines 76-138 of `EventStore.m`) uses a **two-path approach**:

1. **Primary path:** `EventBinding.getEventsForTag(tagKey, obj)` — O(1) reverse-index lookup. Returns events whose Id appears in the EventBinding reverse index for `tagKey`.
2. **Fallback path:** carrier-field matching — iterates `obj.events_` and checks `strcmp(ev.SensorName, tagKey) || strcmp(ev.ThresholdLabel, tagKey)` for events NOT already found by EventBinding.

**Key finding:** `EventBinding.getEventsForTag` uses the reverse index built by `EventBinding.attach(eventId, tagKey)`. MonitorTag already calls `EventBinding.attach(ev.Id, char(obj.Key))` AND `EventBinding.attach(ev.Id, char(obj.Parent.Key))` for each event (lines 878-879, 740-741, 764-765). So `getEventsForTag(parentKey)` **already returns monitor events** — provided EventBinding.attach was called. EventBinding.attach is gated on `~isempty(obj.EventStore)` (the same guard). Therefore:

- When `obj.EventStore` is wired at construction: dual-key binding happens, `getEventsForTag(parentKey)` works.
- When `obj.EventStore` is empty at construction: events are suppressed entirely, no binding, `getEventsForTag(parentKey)` returns nothing.

The fix is purely in the constructor fallback — no changes needed to EventBinding, EventStore, or the stamp code.

---

## Common Pitfalls

### Pitfall 1: Persistent cell mutation does not propagate through returned copy

**What goes wrong:** `eventStoreRef_()` returns `ref = store` (a copy of the persistent cell). Outside code does `ref{1} = es`. The persistent is not updated.

**Why it happens:** MATLAB cells are value types. The persistent `store` is copied on assignment.

**How to avoid:** Use a `containers.Map` as the persistent (handle class — mutations via any reference propagate). Or keep mutation inside the private function:
```matlab
% Inside TagRegistry — correct pattern
function setEventStore(store)
    ref = TagRegistry.eventStoreRef_();
    ref('store') = store;  % containers.Map mutation propagates
end
function store = getEventStore()
    ref = TagRegistry.eventStoreRef_();
    if ref.isKey('store')
        store = ref('store');
    else
        store = [];
    end
end
methods (Static, Access = private)
    function m = eventStoreRef_()
        persistent mapRef;
        if isempty(mapRef)
            mapRef = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end
        m = mapRef;
    end
end
```
Alternatively, use a two-persistent approach where `setEventStore` calls the private function with an argument that triggers a write path — more complex. The `containers.Map` handle approach is the established pattern already used by `EventBinding.bindings_()` and `EventBinding.reverseIndex_()`.

**clear() extension:** `ref = TagRegistry.eventStoreRef_(); if ref.isKey('store'), ref.remove('store'); end` — safe because Map mutations propagate.

### Pitfall 2: FastSenseWidget registry fallback fires on every render, not once

**What goes wrong:** If `TagRegistry.setEventStore()` is called after a widget has already been rendered (e.g., mid-session), the widget's inner FastSense still has `fp.EventStore = []` from the render-time forwarding, so events won't appear until the widget is re-rendered.

**Why it happens:** `fp.EventStore` is set once in `render()`. `refresh()` does not re-forward it.

**How to avoid:** This is acceptable for the Phase 1017 scope (the canonical usage pattern is set-store-before-render). Document as a known limitation. The inner FastSense's `renderEventLayer_` also gets the registry fallback (edit site 3), so it will pick up the store on every render call even if `fp.EventStore` was not forwarded — as long as `TagRegistry.getEventStore()` is non-empty at render time.

### Pitfall 3: MonitorTag.fromStruct does not restore EventStore — this is correct

`MonitorTag.fromStruct()` (line 907 onwards) explicitly documents: `ConditionFn / AlarmOffConditionFn / EventStore / callbacks are NOT restored — consumers must re-bind these after load.` After Phase 1017, the constructor-time fallback to `TagRegistry.getEventStore()` fills this gap automatically for deserialized MonitorTags as long as the registry default is set before `loadFromStructs`.

**Warning sign:** Tests that round-trip MonitorTag via fromStruct and expect events without an explicit re-bind — verify they set `TagRegistry.setEventStore()` before the round-trip.

### Pitfall 4: `fireEventsOnRisingEdges_` early-return guard catches the no-callbacks case

Line 862: `if isempty(obj.EventStore) && isempty(obj.OnEventStart) && isempty(obj.OnEventEnd)`. If a MonitorTag is constructed with `OnEventStart` or `OnEventEnd` but no `EventStore`, the early return is skipped — but then `ev.TagKeys` is stamped only inside the `if ~isempty(obj.EventStore)` block (line 874). Events emitted via callbacks only have no TagKeys stamp and no EventBinding entry. This is pre-existing behavior. Phase 1017 does not need to fix it (callback-only MonitorTags don't have a store to look up by).

### Pitfall 5: `TagRegistry.clear()` must reset both the catalog and the store slot

Tests call `TagRegistry.clear()` for isolation. If the store slot is not reset, stale store handles persist across tests causing false positives. The existing `clear()` only wipes the catalog map.

**Fix:** After the map-clear loop in `clear()`, add:
```matlab
ref = TagRegistry.eventStoreRef_();
if ref.isKey('store')
    ref.remove('store');
end
```

### Pitfall 6: EventTimelineWidget temporarily mutating obj.EventStoreObj creates re-entrancy risk

If `resolveEvents()` is called re-entrantly (e.g., from a timer tick while a previous tick is still running), temporarily setting `obj.EventStoreObj = esObj` then `obj.EventStoreObj = []` could leave the property in an inconsistent state. Use a local variable approach instead:

```matlab
function evts = resolveEvents(obj)
    esObj = obj.EventStoreObj;
    if isempty(esObj)
        esObj = TagRegistry.getEventStore();
    end
    if ~isempty(esObj)
        % use esObj directly, not obj.EventStoreObj
    end
```
Refactor `eventStoreToStructs()` to accept an optional `esObj` argument, or inline the conversion. Do NOT temporarily assign to `obj.EventStoreObj`.

---

## Code Examples

### TagRegistry.setEventStore / getEventStore (Verified pattern)

```matlab
% Source: mirrors TagRegistry.catalog() at line 374 and EventBinding.bindings_() at line 109
methods (Static)
    function setEventStore(store)
        %SETEVENTSTORE Register the default EventStore for the registry.
        %   TagRegistry.setEventStore(store) sets the global default used by
        %   consumers (FastSense, FastSenseWidget, EventTimelineWidget,
        %   TableWidget) when no per-instance EventStore is configured.
        %   Pass [] to clear the default.
        ref = TagRegistry.eventStoreRef_();
        ref('store') = store;
    end

    function store = getEventStore()
        %GETEVENTSTORE Return the registry-default EventStore, or [] if unset.
        %   Safe to call before any store has been registered.
        ref = TagRegistry.eventStoreRef_();
        if ref.isKey('store')
            store = ref('store');
        else
            store = [];
        end
    end
end

methods (Static, Access = private)
    function m = eventStoreRef_()
        %EVENTSTOREREF_ Persistent containers.Map for the registry EventStore.
        %   Handle-class Map so mutations propagate through the returned ref.
        persistent mapRef;
        if isempty(mapRef)
            mapRef = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end
        m = mapRef;
    end
end
```

### FastSense.renderEventLayer_ registry tail (Verified pattern)

```matlab
% Source: FastSense.m lines 2304-2314 (existing loop) — extend as follows
es = obj.EventStore;
if isempty(es)
    for i = 1:numel(obj.Tags_)
        if isprop(obj.Tags_{i}, 'EventStore') && ~isempty(obj.Tags_{i}.EventStore)
            es = obj.Tags_{i}.EventStore;
            break;
        end
    end
end
% Phase 1017: registry-default fallback (tail of existing chain)
if isempty(es)
    es = TagRegistry.getEventStore();
end
if isempty(es), return; end
```

### FastSenseWidget render() extended guard (Verified pattern)

```matlab
% Source: FastSenseWidget.m lines 101-104 — extended
esForward = obj.EventStore;
if isempty(esForward)
    esForward = TagRegistry.getEventStore();  % Phase 1017
end
if obj.ShowEventMarkers || ~isempty(esForward)
    fp.ShowEventMarkers = obj.ShowEventMarkers;
    fp.EventStore       = esForward;
end
```

### MonitorTag constructor fallback (Verified insert point)

```matlab
% Source: MonitorTag.m — insert after the NV-pair for-loop (line 183)
% Phase 1017: if no explicit EventStore was provided, fall back to registry default.
if isempty(obj.EventStore)
    obj.EventStore = TagRegistry.getEventStore();
end
```

### TagRegistry.clear() extension (Verified insert point)

```matlab
% Source: TagRegistry.m lines 109-116 — add after the map-clear loop
% Phase 1017: also reset the registry-default EventStore slot.
ref = TagRegistry.eventStoreRef_();
if ref.isKey('store')
    ref.remove('store');
end
```

### registerPlantTags.m migration (before / after)

**Before (current):**
```matlab
store = EventStore(eventFile);
% ... then each MonitorTag:
mFeedlinePressureHigh = MonitorTag(mDefs(1).Key, ..., 'EventStore', store, ...);
mReactorPressureCritical = MonitorTag(mDefs(2).Key, ..., 'EventStore', store, ...);
mReactorTemperatureHigh = MonitorTag(mDefs(3).Key, ..., 'EventStore', store, ...);
mCoolingFlowLow = MonitorTag(mDefs(4).Key, ..., 'EventStore', store, ...);
```

**After (Phase 1017):**
```matlab
store = EventStore(eventFile);
TagRegistry.setEventStore(store);  % single registry-default wiring
% ... then each MonitorTag (no 'EventStore' NV-pair):
mFeedlinePressureHigh = MonitorTag(mDefs(1).Key, ..., ...);
mReactorPressureCritical = MonitorTag(mDefs(2).Key, ..., ...);
mReactorTemperatureHigh = MonitorTag(mDefs(3).Key, ..., ...);
mCoolingFlowLow = MonitorTag(mDefs(4).Key, ..., ...);
```

---

## State of the Art

| Old Approach | Current Approach After Phase 1017 | Impact |
|--------------|-----------------------------------|--------|
| `MonitorTag(..., 'EventStore', store)` per monitor | `TagRegistry.setEventStore(store)` once at setup | 4 NV-pairs → 1 call in demo; N NV-pairs → 1 call in any user script |
| `FastSenseWidget(..., 'EventStore', es)` per widget | Widget auto-discovers via registry | Dashboard authors write zero EventStore wiring on widgets |
| Events filed under `monitor.key` only | Events filed under both `{monitor.key, parent.key}` | `getEventsForTag(sensorTag.Key)` now finds monitor events |
| EventTimelineWidget requires explicit EventStoreObj | Discovers registry default | Zero per-widget wiring for basic usage |
| TableWidget(Mode='events') requires explicit EventStoreObj | Discovers registry default | Same |

---

## Open Questions

1. **EventTimelineWidget.eventStoreToStructs() private method signature**
   - What we know: it accesses `obj.EventStoreObj` directly (line 304: `raw = obj.EventStoreObj.getEvents()`).
   - What's unclear: whether it is cleanest to (a) refactor it to accept an optional esArg, or (b) inline the `getEvents()` call in `resolveEvents()` using `esObj` directly.
   - Recommendation: inline the equivalent 10-line conversion in `resolveEvents()` using `esObj.getEvents()` rather than temporarily mutating `obj.EventStoreObj`. This avoids any re-entrancy risk and keeps the private helper unchanged.

2. **buildEventsPage.m misleading comment (line 35-38)**
   - What we know: the comment says "FastSense auto-discovers EventStore from any bound MonitorTag" — this is inaccurate; FastSense checks the bound SensorTag's own EventStore property, not its monitor children.
   - What's unclear: whether to fix the comment as part of Phase 1017 or treat it as incidental cleanup.
   - Recommendation: fix the comment as part of the demo migration since CONTEXT.md explicitly calls this out.

3. **`example_event_markers.m` tag registration**
   - What we know: the example creates `SensorTag('pump_a_pressure')` and `SensorTag('motor_b_temperature')` but does NOT call `TagRegistry.register()`. So `TagRegistry.getEventStore()` will be set but the tags themselves won't be in the registry.
   - What's unclear: whether the migration should also add `TagRegistry.register()` calls for the tags.
   - Recommendation: yes, add `TagRegistry.clear(); TagRegistry.register(...)` calls for both sensor tags at the top of the example, matching the canonical pattern from DEMO-05.

---

## Environment Availability

Step 2.6: SKIPPED — this phase involves pure MATLAB classdef edits with no external tool, service, or CLI dependencies.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | MATLAB `matlab.unittest.TestCase` (suite) + Octave function-based (flat) |
| Config file | `tests/run_all_tests.m` (auto-discovery) |
| Quick run command | `cd /path/to/repo && octave --no-gui --eval "run_all_tests"` |
| Full suite command | Same (tests/run_all_tests.m runs both suite and flat tests) |

### Phase Requirements — Test Map

| Behavior | Test Type | File | Method / Block | Automated Command |
|----------|-----------|------|----------------|-------------------|
| Registry-default store resolves on FastSense (no per-instance store) | unit | `TestDashboardEventsToggle.m` | `testRegistryDefaultFastSense` | See below |
| Registry-default store resolves on FastSenseWidget | unit | `TestDashboardEventsToggle.m` | `testRegistryDefaultFastSenseWidget` | See below |
| Registry-default store resolves on EventTimelineWidget | unit | `TestDashboardEventsToggle.m` | `testRegistryDefaultEventTimeline` | See below |
| Registry-default store resolves on TableWidget(events) | unit | `TestDashboardEventsToggle.m` | `testRegistryDefaultTableWidget` | See below |
| Explicit per-instance store overrides registry default | unit | `TestDashboardEventsToggle.m` | `testExplicitStoreWinsOverRegistry` | See below |
| MonitorTag events returned by getEventsForTag(parentKey) | unit | `TestDashboardEventsToggle.m` | `testDualKeyEmission` | See below |
| Octave parity for all above | unit | `test_dashboard_events_toggle.m` | test blocks 9-14 | See below |
| Existing tests continue green (no regression) | regression | All existing tests | — | Full suite |

**Quick run for just these tests:**
```bash
# MATLAB
matlab -nodesktop -r "addpath(pwd); install(); run(matlab.unittest.TestSuite.fromFile('tests/suite/TestDashboardEventsToggle.m')); exit"

# Octave
octave --no-gui --eval "addpath(pwd); install(); test_dashboard_events_toggle(); exit"
```

### Wave 0 Gaps (new test methods to add)

The existing `TestDashboardEventsToggle.m` has 5 test methods (testEngineDefaultTrue, testEngineFlagFlip, testToolbarButtonExists, testIndicatorBorderSwap, testFastSenseToggleClearsAndRepopulates, testFastSenseWidgetPreRenderNoOp, testEventTimelineWidgetIsExempt, testFanoutUpdatesToolbarIndicator).

**New methods required (extend, don't rewrite per CONTEXT.md):**

- [ ] `testRegistryDefaultFastSense` — set `TagRegistry.setEventStore(es)`, create FastSense with a SensorTag (no explicit es on fp), render, verify markers appear
- [ ] `testRegistryDefaultFastSenseWidget` — same via FastSenseWidget with `ShowEventMarkers=true`
- [ ] `testRegistryDefaultEventTimeline` — set registry default, create EventTimelineWidget with no `EventStoreObj`, refresh, verify events returned
- [ ] `testRegistryDefaultTableWidget` — set registry default, create TableWidget with `Mode='events'` and no `EventStoreObj`, refresh, verify rows populated
- [ ] `testExplicitStoreWinsOverRegistry` — set registry store A, construct FastSenseWidget with explicit store B, verify fp.EventStore == B (not A)
- [ ] `testDualKeyEmission` — create SensorTag + MonitorTag (no explicit EventStore; registry default set), call `mon.getXY()`, verify `es.getEventsForTag(sensorTag.Key)` returns non-empty

All 6 methods also need flat Octave equivalents in `test_dashboard_events_toggle.m` (test blocks 9-14).

**Each test method must call `TagRegistry.clear(); EventBinding.clear();` in setup** to prevent cross-test contamination from the new persistent store slot.

---

## Sources

### Primary (HIGH confidence — verified against source code)

- `libs/SensorThreshold/TagRegistry.m` lines 109-116, 365-387 — `clear()` and `catalog()` patterns
- `libs/SensorThreshold/MonitorTag.m` lines 162-198, 844-903 — NV-pair loop, `fireEventsOnRisingEdges_`
- `libs/FastSense/FastSense.m` lines 2293-2314 — `renderEventLayer_` auto-discovery loop
- `libs/Dashboard/FastSenseWidget.m` lines 1-104 — `EventStore` property, render() guard block
- `libs/Dashboard/EventTimelineWidget.m` lines 14-19, 258-298 — `EventStoreObj`, `resolveEvents()`
- `libs/Dashboard/TableWidget.m` lines 14-17, 80-107 — `EventStoreObj`, events branch
- `libs/EventDetection/EventStore.m` lines 76-138 — `getEventsForTag()` dual-path implementation
- `libs/EventDetection/EventBinding.m` lines 1-130 — reverse index, `attach()`, `getEventsForTag()`
- `libs/SensorThreshold/Tag.m` lines 55-180 — `EventStore` property, `addManualEvent()`
- `demo/industrial_plant/private/registerPlantTags.m` lines 102-136 — 4 explicit `'EventStore'` NV-pairs
- `demo/industrial_plant/private/buildEventsPage.m` lines 55-62 — explicit `'EventStoreObj'`
- `examples/example_event_markers.m` lines 34, 39, 45, 48 — per-MonitorTag and per-widget explicit wiring
- `tests/suite/TestDashboardEventsToggle.m` — existing 8 test methods to extend
- `tests/test_dashboard_events_toggle.m` — existing Octave flat tests to extend

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure in-codebase; no external libraries
- Architecture: HIGH — exact line numbers verified; patterns match existing code
- Pitfalls: HIGH — each pitfall derived from reading actual MATLAB persistent/handle semantics present in the codebase
- Test gaps: HIGH — verified by reading both test files completely

**Research date:** 2026-04-28
**Valid until:** Stable until source files change — 90 days
