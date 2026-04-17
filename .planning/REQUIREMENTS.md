# Requirements — Milestone v2.0 Tag-Based Domain Model

**Milestone:** v2.0 — Tag-Based Domain Model
**Defined:** 2026-04-16
**Source:** PROJECT.md (Ambitious tier scope), research/SUMMARY.md, user scoping decisions
**Strategy:** Strangler-fig sequencing (Tag introduced as parallel hierarchy in Phase 1004; legacy classes deleted only in Phase 1011)

## Scope Summary

**In scope (45 requirements across 7 categories):**
- TAG (10): Tag root abstraction + TagRegistry + SensorTag/StateTag retrofit + FastSense.addTag dispatch
- MONITOR (10): MonitorTag derived time-series with debounce, hysteresis, streaming, opt-in disk persistence
- COMPOSITE (7): CompositeTag aggregation (AND/OR/MAJORITY/COUNT/MAX/SEVERITY/USER_FN) with cycle detection
- META (4): Labels, metadata, criticality, search
- EVENT (7): Event ↔ Tag binding via separate EventBinding registry; FastSense round-marker overlay (toggleable)
- ALIGN (4): Zero-order-hold alignment, union-grid evaluation, NaN handling
- MIGRATE (3): Strangler-fig discipline, golden integration test, legacy-class deletion at end

**MonitorTag value semantics:** Binary 0/1 only (tri-state and continuous severity explicitly deferred).

**Event rendering:** Round markers at event timestamps in FastSense, theme-colored by severity, toggleable on/off via FastSense property.

---

## v2.0 Requirements

### TAG — Tag Foundation

- [x] **TAG-01**: Define `Tag` abstract base class (`< handle`) with throw-from-base contract for `getXY()`, `valueAt(t)`, `getTimeRange()`, `getKind()`, `toStruct()`, and static `fromStruct(s)` — proven Octave-safe pattern from `DashboardWidget`/`DataSource`. Maximum 6 abstract methods (Pitfall 1 budget).
- [x] **TAG-02**: Tag root exposes universal properties: `Key` (unique string), `Name` (display), `Units`, `Description`, `Labels` (cell of strings), `Metadata` (open struct), `Criticality` (`low|medium|high|safety` enum), `SourceRef` (optional provenance string).
- [x] **TAG-03**: `TagRegistry` singleton with `register(key, tag)`, `get(key)`, `unregister(key)`, `clear()`. Throws `TagRegistry:duplicateKey` on collision (hard error, matches existing ThresholdRegistry behavior).
- [x] **TAG-04**: `TagRegistry` query API: `find(predicate)`, `findByLabel(label)`, `findByKind(kind)` — enables label-driven dashboards and tag-discovery widgets.
- [x] **TAG-05**: `TagRegistry` introspection: `list()`, `printTable()`, `viewer()` (Octave-safe uitable). Carry-forward from existing `SensorRegistry`/`ThresholdRegistry`.
- [x] **TAG-06**: `TagRegistry.loadFromStructs(structs)` performs **two-phase deserialization** — Pass 1 instantiates all tags with empty children; Pass 2 resolves cross-references. Eliminates the documented `CompositeThreshold.fromStruct` ordering trap.
- [x] **TAG-07**: Every Tag subclass implements `toStruct()` and static `fromStruct(s)` for JSON round-trip. `TagRegistry.loadFromStructs` round-trip works for any composition depth (composite of composites).
- [x] **TAG-08**: `SensorTag` subclass — raw `(X, Y)` data, `load(matFile)`, `toDisk(store)/toMemory()/isOnDisk()`, DataStore property. Feature-equivalent to existing `Sensor` class for raw signal handling.
- [x] **TAG-09**: `StateTag` subclass — zero-order-hold `valueAt(t)` lookup over discrete state transitions; X (timestamps) + Y (numeric or cell-array states). Feature-equivalent to existing `StateChannel` class.
- [x] **TAG-10**: User can call `FastSense.addTag(tag)` polymorphically. Internal dispatch routes by `tag.getKind()` to existing line-rendering (sensor/monitor) or band-rendering (state) code paths.

### MONITOR — MonitorTag

- [x] **MONITOR-01**: `MonitorTag` constructed as `MonitorTag(key, parentTag, conditionFn)` produces a binary 0/1 time series via `getXY()`. Output represents condition activation over time (0=inactive/ok, 1=active/violation).
- [x] **MONITOR-02**: `MonitorTag` IS a `Tag` (`isa(m, 'Tag')` returns true). Plottable via `FastSense.addTag(m)`. Registerable in `TagRegistry`. Can be the parent of another MonitorTag (recursive monitoring) or a child of a CompositeTag.
- [x] **MONITOR-03**: MonitorTag uses **lazy evaluation with memoization** — `getXY()` computes derived series on first read, caches result, returns cache on subsequent reads until `invalidate()` clears the cache. Per Pitfalls §2: lazy-by-default; eager full-history computation explicitly forbidden.
- [x] **MONITOR-04**: Parent-driven invalidation — when parent SensorTag's `updateData()` runs OR a referenced StateTag's `updateData()` runs, all dependent MonitorTags receive `invalidate()`. Condition add/remove on MonitorTag also marks `dirty_ = true`.
- [x] **MONITOR-05**: MonitorTag emits Events via integrated `EventDetector` — when the binary signal transitions 0→1, a new Event is created and pushed to the bound `EventStore` with `TagKeys = {monitor.Key, monitor.Parent.Key}`.
- [x] **MONITOR-06**: MonitorTag `MinDuration` / debounce — events fire only when violation persists at least `MinDuration` seconds (suppresses sub-threshold-duration chatter). ISA-18.2 alarm-suppression standard.
- [x] **MONITOR-07**: MonitorTag hysteresis / deadband — `MonitorTag` accepts separate alarm-on threshold (or condition) and alarm-off threshold; prevents chattering at boundary. ISA-18.2 standard practice; most simple historians lack this.
- [x] **MONITOR-08**: MonitorTag streaming — `appendData(newX, newY)` extends the cached output incrementally without full recompute. Wraps existing `IncrementalEventDetector` pattern. Used by `LiveEventPipeline` live-tick path.
- [x] **MONITOR-09**: MonitorTag opt-in disk persistence — when `MonitorTag.Persist = true`, derived `(X, Y)` is cached to `FastSenseDataStore` via new `storeMonitor(key, X, Y)`/`loadMonitor(key)` API. Default off; Pitfalls §2 cache-invalidation pain limited to opt-in users.
- [x] **MONITOR-10**: MonitorTag rejects per-sample side-effect callbacks. Only event-level callbacks (`OnEventStart`/`OnEventEnd`) supported. Prevents PI-AF-style unpredictable-side-effects pitfall.

### COMPOSITE — CompositeTag

- [x] **COMPOSITE-01**: `CompositeTag` extends `Tag`. Aggregates one or more child Tags via configurable `AggregateMode`. Itself a Tag — recursively composable (CompositeTag of CompositeTags).
- [x] **COMPOSITE-02**: Built-in aggregation modes: `'and'`, `'or'`, `'majority'`, `'count'`, `'worst'` (max), `'severity'` (weighted average), `'user_fn'` (function handle escape hatch).
- [x] **COMPOSITE-03**: Children added via `addChild(tagOrKey, opts)` accepting either a Tag handle or a string key (resolved via TagRegistry). Optional `'Weight'` per-child for SEVERITY mode.
- [x] **COMPOSITE-04**: Cycle detection on `addChild` — rejects self-reference (existing `CompositeThreshold` behavior) AND deeper cycles via DFS (A → B → A) with `CompositeTag:cycleDetected` error.
- [x] **COMPOSITE-05**: `CompositeTag.getXY()` produces aggregated time series via union-of-timestamps grid + `valueAt` per child per grid point. **Implementation: merge-sort over child sample streams** — NOT N×M dense `union(X_i)` materialization (Pitfalls §3 memory-blowup avoidance).
- [x] **COMPOSITE-06**: `CompositeTag.valueAt(t)` returns aggregated value at a single instant via `valueAt(t)` on each child + apply aggregator. Fast path for current-state widgets (StatusWidget, GaugeWidget) without full-series materialization.
- [x] **COMPOSITE-07**: CompositeTag children must be `MonitorTag` or `CompositeTag` (rejected at `addChild` if `SensorTag` or `StateTag` — those have no inherent ok/alarm semantics).

### META — Tag Metadata + Search

- [x] **META-01**: `Tag.Labels` (cell of strings) — flat cross-cutting classification (`{'pressure', 'pump-3', 'critical'}`). Renamed from existing `Threshold.Tags` to avoid name collision with the Tag class itself.
- [x] **META-02**: `TagRegistry.findByLabel(label)` returns all tags carrying the given label. Direct port of existing `ThresholdRegistry.findByTag` pattern.
- [x] **META-03**: `Tag.Metadata` (struct) — open key-value bag for asset id, source file, vendor, etc. Future-proofs for the deferred Asset hierarchy milestone (D); usable today via stringly-typed `Metadata.asset = 'pump-3'`.
- [x] **META-04**: `Tag.Criticality` enum (`'low'|'medium'|'high'|'safety'`) drives default colors in StatusWidget/IconCardWidget/MultiStatusWidget and event-marker color in FastSense (severity → theme color).

### EVENT — Events on Tag

- [x] **EVENT-01**: `Event.TagKeys` (cell of strings) replaces the current `SensorName`/`ThresholdLabel` denormalized strings. Supports many-to-many Event ↔ Tag binding (one event can reference multiple tags; one tag can have many events).
- [x] **EVENT-02**: Separate `EventBinding` registry stores `(eventId, tagKey)` rows. **Critical: Event holds NO Tag handles; Tag holds NO Event handles.** Prevents serialization cycles and matches PI AF event-frame ↔ element binding pattern.
- [x] **EVENT-03**: `EventStore.eventsForTag(key)` query returns all events bound to the given tag (filters via EventBinding). `Tag.eventsAttached()` is a query, not a stored property.
- [x] **EVENT-04**: `Event.Severity` field (numeric, mapped to theme color via `StatusOkColor`/`StatusWarnColor`/`StatusAlarmColor`). ISA-18.2 priority levels.
- [x] **EVENT-05**: `Event.Category` field (`'alarm'|'maintenance'|'process_change'|'manual_annotation'`). Drives default render style in FastSense overlay; drives filter in EventTimelineWidget.
- [x] **EVENT-06**: Manual event creation API — `tag.addManualEvent(tStart, tEnd, label, message)` writes a new Event to the bound EventStore with `TagKeys = {tag.Key}` and `Category = 'manual_annotation'`. Foundation for the deferred custom-event-GUI milestone (F).
- [x] **EVENT-07**: FastSense renders events bound to a plotted Tag as **round marker symbols** at event timestamps (Trendminer-style). Theme-driven color from `Event.Severity`. **Toggleable** via `FastSense.ShowEventMarkers` property (default true). Implemented as a **separate render layer** (Pitfalls §10) — `renderEventLayer()` after `renderLines()`, single early-out if no events.

### ALIGN — Time Alignment

- [x] **ALIGN-01**: Zero-order-hold (LOCF / step) is the only legal alignment in CompositeTag aggregation. Linear interpolation between samples is explicitly **forbidden** (wrong semantics for state signals; out-of-scope for sensor signals).
- [x] **ALIGN-02**: Union-of-timestamps grid for CompositeTag aggregation — evaluate at every unique timestamp from any child, not on a fixed regular grid. Preserves event-edges; no sampling artifacts.
- [x] **ALIGN-03**: Aggregation drops grid points before `max(child.X(1))` — no false alarms from "child not yet started" condition. Standard industrial pattern.
- [x] **ALIGN-04**: NaN handling in aggregation — `AND` with NaN → NaN; `OR` with NaN → other operand; `MAX/WORST` with NaN → ignore; `COUNT` ignores NaN. IEEE 754 conventions; documented in CompositeTag class header.

### MIGRATE — Migration & Cleanup

- [x] **MIGRATE-01**: Phase 0 deliverable — write a **golden integration test** against the current `Sensor`/`Threshold` API that exercises a representative dashboard (sensor + threshold + composite + event detection). This test stays green through every v2.0 phase as a regression guard. Migrated to new API in Phase 7 only.
- [x] **MIGRATE-02**: **Strangler-fig sequencing** enforced — `Tag` introduced as a parallel hierarchy in Phase 1 (≤20-file budget). `Sensor`, `Threshold`, `StateChannel`, `CompositeThreshold` untouched through Phase 6. Legacy classes deleted ONLY in Phase 7 cleanup.
- [x] **MIGRATE-03**: Phase 7 deletes legacy classes: `Sensor.m`, `Threshold.m`, `ThresholdRule.m`, `CompositeThreshold.m`, `StateChannel.m`, `SensorRegistry.m`, `ThresholdRegistry.m`, `ExternalSensorRegistry.m`. Test suite migrated phase-by-phase; full `tests/run_all_tests.m` green at every phase boundary; new tests for Tag/MonitorTag/CompositeTag/Event-Tag-binding added per phase.

---

## Future Requirements (deferred — captured for visibility, not scoped to v2.0)

These were considered and intentionally deferred to later milestones:

- **Asset hierarchy** (Milestone D) — `Asset` tree, asset templates ("Pump" type), tag-to-asset binding, browse rollups by equipment. Every research source mentions it; explicitly deferred per PROJECT.md.
- **Custom event GUI** (Milestone F) — click-and-drag region selection in FastSense → label dialog. EVENT-06 ships the code path foundation.
- **Calc tags / formula DSL** (Milestone G) — string-based formula evaluator (`"a + b > 5"`). Function-handle conditions in MONITOR-01 cover the immediate need.
- **Tri-state MonitorTag output** (`{ok, warn, alarm}`) — user scoped MonitorTag to binary 0/1 only for v2.0. Defer to a v2.x milestone if real usage demands it.
- **Continuous severity MonitorTag output** (`0..1` float) — same reasoning as tri-state; user picked binary only.
- **Per-child threshold override on CompositeTag** — children can have per-child thresholds that override their default. User said no preference; defer to keep CompositeTag scope tight.
- **MonitorTag streaming auto-derived from parent live tick** — current MONITOR-08 ships explicit `appendData()`. Auto-discovery via parent listeners deferred.
- **Hierarchical label paths** (`'plant/unit-A/pump-3'`) — flat labels only in v2.0. Real hierarchy belongs in Asset milestone.
- **Auto-derived labels from Type/Units** (e.g. SensorTag with `Units='bar'` → auto-label `'pressure'`) — future polish.
- **Label-driven dashboard widgets** (`addAllByLabel('critical')`) — convenience method on DashboardBuilder. Future polish.
- **Regular-grid resample mode** for CompositeTag — union-grid is sufficient for v2.0; resample is a downstream-FFT concern.
- **Alignment caching** keyed on `(children, window)` — premature optimization; profile first.

---

## Out of Scope (explicit exclusions with reasoning)

These will NOT be implemented in v2.0 OR deferred milestones:

- **Tag versioning / definition history** — massive complexity (PI AF charges money for it); no FastSense user demand. NaN-as-missing convention sufficient.
- **Quality codes per sample** (PI AF `AFValueStatus`) — doubles storage footprint, complicates every consumer; NaN remains the missing-value convention.
- **Multiple time bases per Tag** (e.g. UTC + local) — time-zone hell; every existing FastSense MEX kernel assumes one numeric time vector.
- **Event mutation / editing** — events are immutable; "edit" = "supersede with new event". Audit-trail hell otherwise.
- **Event acknowledgement workflow** (full ISA-18.2 alarm lifecycle) — separate product. Needs user identity, persistence beyond EventStore, UI flows.
- **Recursive events that emit events** — events are leaves; only signals recurse.
- **Embedded Tag.Events property** — many-to-many requires the EventBinding registry; embedding violates the model.
- **Bidirectional Tag↔Event handles** — Pitfalls §4. Forces serialization cycles; orphan-cleanup bugs.
- **Per-event drawing customization** (per-event color/line-width/hatch) — theme-driven coloring instead; consistency wins.
- **Materialized aggregation cache for CompositeTag** — lazy + downsampling sufficient; cache invalidation harder than recompute.
- **Per-sample side-effect callbacks on MonitorTag** — only event-level callbacks supported.
- **MonitorTag back-write into source SensorTag** — the entire reason for v2.0 is to break this entanglement.
- **N×M dense matrix materialization in CompositeTag** — Pitfalls §3 memory-blowup risk; merge-sort streaming required.
- **String-based condition DSL on MonitorTag** — function handles only; DSL deferred to calc-tags milestone (G).
- **Multi-output-mode MonitorTag** (one tag carrying binary AND severity AND categorical) — pick ONE output mode per MonitorTag; v2.0 picks binary.
- **Linear interpolation in CompositeTag aggregation** — ZOH only; ALIGN-01.
- **Eager full-history MonitorTag computation** — lazy-windowed only; MONITOR-03.
- **Padding short-history children with zeros at start of CompositeTag time range** — ALIGN-03 drops pre-history grid points; padding-with-zero looks like "ok" and falsely raises COUNT/MAJORITY results.
- **Time-zone-aware alignment** — display formatting only; one time base.

### Stack additions explicitly forbidden

- `dictionary` (R2022b+; not in Octave 11)
- `matlab.mixin.Heterogeneous` / `matlab.mixin.Copyable` / `matlab.mixin.SetGet` (Octave incomplete)
- `enumeration` blocks (parsed-no-op on Octave)
- `events` / listeners (parsed-no-op on Octave)
- `arguments` blocks (patchy on Octave)
- New MEX kernels for tag aggregation (`all`/`any`/`sum` is sub-millisecond at typical N)
- Tag-graph database (Neo4j, etc.) — would smash "no external deps" invariant
- JSON-schema validators — `toStruct`/`fromStruct` + `isfield` checks sufficient
- New persistence backend (Parquet/HDF5) — `FastSenseDataStore` already does this for the same data shape

---

## Traceability

| REQ-ID | Phase | Notes |
|--------|-------|-------|
| TAG-01 | 1004 | Tag abstract base — ≤6 abstract methods budget (Pitfall 1) |
| TAG-02 | 1004 | Universal Tag root properties (Key, Name, Units, Description, Labels, Metadata, Criticality, SourceRef) |
| TAG-03 | 1004 | TagRegistry singleton CRUD with hard-error duplicate-key (Pitfall 7) |
| TAG-04 | 1004 | TagRegistry query API (find, findByLabel, findByKind) |
| TAG-05 | 1004 | TagRegistry introspection (list, printTable, viewer) |
| TAG-06 | 1004 | Two-phase loadFromStructs deserializer (Pitfall 8) |
| TAG-07 | 1004 | toStruct/fromStruct round-trip for any composition depth |
| TAG-08 | 1005 | SensorTag — port of Sensor raw-data role |
| TAG-09 | 1005 | StateTag — port of StateChannel ZOH lookup |
| TAG-10 | 1005 | FastSense.addTag polymorphic dispatch by getKind() |
| MONITOR-01 | 1006 | MonitorTag(key, parent, conditionFn) → binary 0/1 series |
| MONITOR-02 | 1006 | MonitorTag IS-A Tag; recursively composable |
| MONITOR-03 | 1006 | Lazy memoized recompute; eager forbidden (Pitfall 2) |
| MONITOR-04 | 1006 | Parent-driven invalidation (parent.updateData → monitor.invalidate) |
| MONITOR-05 | 1006 | Event auto-emit on 0→1 transitions; consumer wiring fully realized in 1009 |
| MONITOR-06 | 1006 | MinDuration debounce — ISA-18.2 alarm suppression |
| MONITOR-07 | 1006 | Hysteresis / deadband — separate alarm-on/alarm-off thresholds |
| MONITOR-08 | 1007 | appendData incremental tail computation for live tick |
| MONITOR-09 | 1007 | Opt-in Persist=true via FastSenseDataStore.storeMonitor/loadMonitor |
| MONITOR-10 | 1006 | No per-sample side-effect callbacks; event-level only |
| COMPOSITE-01 | 1008 | CompositeTag extends Tag; recursively composable |
| COMPOSITE-02 | 1008 | AND/OR/MAJORITY/COUNT/WORST/SEVERITY/USER_FN aggregation modes |
| COMPOSITE-03 | 1008 | addChild accepts handle or key; optional Weight for SEVERITY |
| COMPOSITE-04 | 1008 | Cycle detection on addChild via DFS (Pitfall 8) |
| COMPOSITE-05 | 1008 | Merge-sort streaming aggregation; no N×M materialization (Pitfall 3) |
| COMPOSITE-06 | 1008 | valueAt(t) fast path for current-state widgets |
| COMPOSITE-07 | 1008 | Children must be MonitorTag or CompositeTag (no SensorTag/StateTag) |
| META-01 | 1004 | Tag.Labels (cell of strings) on Tag root |
| META-02 | 1004 | TagRegistry.findByLabel — port of ThresholdRegistry.findByTag |
| META-03 | 1004 | Tag.Metadata open struct on Tag root |
| META-04 | 1004 | Tag.Criticality enum drives default widget colors |
| EVENT-01 | 1010 | Event.TagKeys cell replaces SensorName/ThresholdLabel |
| EVENT-02 | 1010 | Separate EventBinding registry; no bidirectional handles (Pitfall 4) |
| EVENT-03 | 1010 | EventStore.eventsForTag(key) query |
| EVENT-04 | 1010 | Event.Severity → theme color (StatusOk/Warn/Alarm) |
| EVENT-05 | 1010 | Event.Category drives FastSense overlay style + EventTimelineWidget filter |
| EVENT-06 | 1010 | tag.addManualEvent — manual annotation API (foundation for milestone F) |
| EVENT-07 | 1010 | FastSense round-marker overlay; toggleable; separate render layer (Pitfall 10) |
| ALIGN-01 | 1006 | ZOH-only alignment in MonitorTag (interpolation forbidden) |
| ALIGN-02 | 1006 | Union-of-timestamps grid (CompositeTag inherits in 1008) |
| ALIGN-03 | 1006 | Drop grid points before max(child.X(1)) — no false pre-history alarms |
| ALIGN-04 | 1006 | NaN handling in aggregation per IEEE 754 conventions |
| MIGRATE-01 | 1004 | Phase-0 golden integration test — written this phase, untouched until 1011 |
| MIGRATE-02 | 1004 | Strangler-fig sequencing enforced — ≤20-file budget for 1004 (Pitfall 5) |
| MIGRATE-03 | 1011 | Delete 8 legacy classes; rewrite golden test for new API |

**Coverage:** 45/45 v2.0 requirements mapped to exactly one phase. Phase 1009 (consumer migration) is a structural integration phase that owns no exclusive REQ-IDs — it wires existing Tag/MONITOR/COMPOSITE REQs into existing widget consumers without introducing new requirements.

**Phase distribution:**
- Phase 1004: 13 REQs (TAG-01..07, META-01..04, MIGRATE-01, MIGRATE-02)
- Phase 1005: 3 REQs (TAG-08, TAG-09, TAG-10)
- Phase 1006: 12 REQs (MONITOR-01..07, MONITOR-10, ALIGN-01..04)
- Phase 1007: 2 REQs (MONITOR-08, MONITOR-09)
- Phase 1008: 7 REQs (COMPOSITE-01..07)
- Phase 1009: 0 REQs (structural consumer migration; MONITOR-05 auto-emit fully realized end-to-end here)
- Phase 1010: 7 REQs (EVENT-01..07)
- Phase 1011: 1 REQ (MIGRATE-03)

---

*Defined for: v2.0 Tag-Based Domain Model — pure-MATLAB unified Tag abstraction over existing FastSense codebase*
*Defined: 2026-04-16*
*Traceability filled: 2026-04-16 by gsd-roadmapper (Phases 1004-1011 mapped, 45/45 coverage)*
