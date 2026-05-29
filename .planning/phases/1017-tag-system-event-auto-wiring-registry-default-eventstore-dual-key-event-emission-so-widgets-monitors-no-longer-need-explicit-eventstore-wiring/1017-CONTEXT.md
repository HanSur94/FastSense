# Phase 1017: Tag system event auto-wiring - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Make `EventStore` wiring an opt-in for advanced cases instead of a per-instance requirement. After this phase, the canonical pattern is:

```matlab
store = EventStore(eventFile);
TagRegistry.setEventStore(store);
% ...register sensors, monitors, composites — no 'EventStore' NV-pairs anywhere
% Dashboard authors call addWidget('fastsense', 'Tag', sensorTag) and events
% emitted by any MonitorTag whose Parent == sensorTag automatically render.
% EventTimelineWidget and TableWidget(events) discover the same default.
```

Closes a hidden bug where events were filed under a MonitorTag's own key (e.g.
`reactor.pressure.critical`) but FastSense queried using the bound SensorTag's
key (`reactor.pressure`), so markers never appeared on the parent's plot even
when the EventStore was correctly wired everywhere.

Out of scope: any change to how events are persisted, how MonitorTags evaluate
conditions, or how dashboards lay out event markers visually.

</domain>

<decisions>
## Implementation Decisions

### API Design

- **Dual-key event emission.** `MonitorTag.fireEvent` (and the alarm-off path)
  set `ev.TagKeys = {monitor.Key, parent.Key}` so events are self-describing
  and `EventStore.getEventsForTag(parentKey)` finds them without needing the
  store to walk the registry. Chosen over the registry-walk alternative
  because it keeps `EventStore` decoupled from `TagRegistry` on the read
  path and makes serialized events stand alone.
- **Registry-default EventStore lives on `TagRegistry`.** Mirrors the existing
  `catalog()` persistent-cache pattern: add static methods
  `TagRegistry.setEventStore(store)` and `TagRegistry.getEventStore()` backed
  by a persistent variable. Rejected creating a separate `EventStoreRegistry`
  class — the registry is already the singleton root for tag-scoped
  cross-cutting concerns.

### Backward Compatibility

- **Explicit per-instance store wins, silently.** When a MonitorTag,
  FastSenseWidget, EventTimelineWidget, or TableWidget(events) is constructed
  with an explicit `EventStore` / `EventStoreObj`, that store is used as
  before; the registry default is only consulted when the explicit slot is
  empty. No deprecation warning, no log line — preserves the absolute
  silence of existing scripts and tests.
- **No new error IDs.** The registry-default lookup must be safe to call
  before any store has been registered (returns `[]` → consumers fall back
  to their pre-1017 behavior).

### Scope

- **Demo migration is in scope.** `demo/industrial_plant/private/registerPlantTags.m`
  drops the per-MonitorTag `'EventStore', store` pairs and adds a single
  `TagRegistry.setEventStore(store)` near the top. The `build*Page.m` helpers
  drop any explicit `'EventStore'` NV-pair on FastSenseWidget /
  EventTimelineWidget / TableWidget calls. Migrating them in this phase
  proves the API is actually ergonomic in practice.
- **example_event_markers.m migration is in scope** as a second canonical
  example, since it's the existing reference for "events on plots".

### Test Strategy

- **Extend, don't rewrite.** Augment `tests/suite/TestDashboardEventsToggle.m`
  and `tests/test_dashboard_events_toggle.m` (both branches of the existing
  events-toggle pair) with cases that:
  1. Verify registry-default fallback resolves on each consumer
     (FastSense, FastSenseWidget, EventTimelineWidget, TableWidget(events)).
  2. Verify explicit per-instance store overrides registry default.
  3. Verify `MonitorTag` emitted events are returned by
     `EventStore.getEventsForTag(parent.Key)` (the dual-key fix).
  4. Verify `example_event_markers.m` still runs without errors after
     the demo migration.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- **TagRegistry.catalog() persistent-cache pattern**
  ([libs/SensorThreshold/TagRegistry.m:374](libs/SensorThreshold/TagRegistry.m:374))
  — same shape works for the new `eventStoreRef()` private helper.
- **Tag.EventStore property** ([libs/SensorThreshold/Tag.m:60](libs/SensorThreshold/Tag.m:60))
  — already a per-tag override slot; the new fallback only kicks in when
  this is empty.
- **MonitorTag fireEvent** ([libs/SensorThreshold/MonitorTag.m:874](libs/SensorThreshold/MonitorTag.m:874))
  — single edit site for stamping `ev.TagKeys = {obj.Key, obj.Parent.Key}`.
- **FastSense.renderEventLayer_ auto-discovery loop**
  ([libs/FastSense/FastSense.m:2304-2313](libs/FastSense/FastSense.m:2304))
  — extend the existing `if isempty(es)` fallback chain with one more clause.
- **Existing global-toggle plumbing** (PR #80, b33d2de) — `DashboardEngine.EventMarkersVisible`
  already fans out to every widget; nothing in this phase touches that path.

### Established Patterns

- **Persistent singleton via static method + private function** — used by
  `TagRegistry.catalog()` and matched by the new `eventStoreRef()`.
- **`isempty` fallback chains** — the `FastSense.renderEventLayer_` auto-
  discovery loop is the canonical place to add the registry tail.
- **NV-pair backward compat** — `MonitorTag` constructor already silently
  accepts or omits `'EventStore'`; the registry fallback adds zero new
  surface area.

### Integration Points

- **Six edit sites:**
  1. `libs/SensorThreshold/TagRegistry.m` — add `setEventStore` / `getEventStore`.
  2. `libs/SensorThreshold/MonitorTag.m` — dual-key on event emission +
     constructor fallback to `TagRegistry.getEventStore()`.
  3. `libs/FastSense/FastSense.m` — registry fallback in
     `renderEventLayer_` after the bound-tag-EventStore lookup fails.
  4. `libs/Dashboard/FastSenseWidget.m` — same registry fallback before
     forwarding to inner FastSense.
  5. `libs/Dashboard/EventTimelineWidget.m` — registry fallback in the
     `EventStoreObj`-empty branch of `getEvents_()`.
  6. `libs/Dashboard/TableWidget.m` — registry fallback in the
     `Mode='events'` branch.
- **Two demo edit sites:**
  - `demo/industrial_plant/private/registerPlantTags.m` — add
    `TagRegistry.setEventStore(store)` once, drop four
    `'EventStore', store` MonitorTag NV-pairs.
  - `demo/industrial_plant/private/buildOverviewPage.m` /
    `buildFeedLinePage.m` / `buildReactorPage.m` / `buildCoolingPage.m` /
    `buildEventsPage.m` / `buildDiagnosticsPage.m` — drop any leftover
    explicit `'EventStore'` NV-pairs (the comments referencing
    "ShowEventMarkers" can also be tightened).
- **One example edit site:**
  - `examples/example_event_markers.m` — switch to the registry-default
    pattern as the new canonical recipe.

</code_context>

<specifics>
## Specific Ideas

- The hidden bug to fix while we're here: `MonitorTag.fireEvent` writes
  `ev.TagKeys = {monitor.Key}` today (or doesn't set it; need to verify which
  during planning). The dual-key change must include both `monitor.Key` and
  `parent.Key` in TagKeys so `getEventsForTag(parentKey)` works.
- Demo's misleading comment: `demo/industrial_plant/private/buildEventsPage.m`
  claims FastSense "auto-discovers EventStore from any bound MonitorTag" —
  it doesn't (it checks the bound tag, not its monitor children). Fix the
  comment as part of the demo migration.

</specifics>

<deferred>
## Deferred Ideas

- A separate `EventStoreRegistry` per kind (per-tag-class scoping) — premature
  abstraction; registry-wide singleton is sufficient.
- Deprecation warning on explicit duplicate wiring — would break "absolute
  silence for existing scripts" rule. Can revisit in a future cleanup phase.
- Walk-the-registry approach in `EventStore.getEventsForTag` — rejected for
  this phase (couples EventStore to TagRegistry on the hot read path); the
  dual-key approach delivers the same outcome with fewer entanglements.

</deferred>
