# Requirements — Milestone v2.0 Tag-Based Domain Model

**Milestone:** v2.0 — Tag-Based Domain Model
**Defined:** 2026-04-16
**Source:** PROJECT.md (Ambitious tier scope), research/SUMMARY.md, user scoping decisions
**Strategy:** Strangler-fig sequencing (Tag introduced as parallel hierarchy in Phase 1; legacy classes deleted only in Phase 7)

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

- [ ] **TAG-01**: Define `Tag` abstract base class (`< handle`) with throw-from-base contract for `getXY()`, `valueAt(t)`, `getTimeRange()`, `getKind()`, `toStruct()`, and static `fromStruct(s)` — proven Octave-safe pattern from `DashboardWidget`/`DataSource`. Maximum 6 abstract methods (Pitfall 1 budget).
- [ ] **TAG-02**: Tag root exposes universal properties: `Key` (unique string), `Name` (display), `Units`, `Description`, `Labels` (cell of strings), `Metadata` (open struct), `Criticality` (`low|medium|high|safety` enum), `SourceRef` (optional provenance string).
- [ ] **TAG-03**: `TagRegistry` singleton with `register(key, tag)`, `get(key)`, `unregister(key)`, `clear()`. Throws `TagRegistry:duplicateKey` on collision (hard error, matches existing ThresholdRegistry behavior).
- [ ] **TAG-04**: `TagRegistry` query API: `find(predicate)`, `findByLabel(label)`, `findByKind(kind)` — enables label-driven dashboards and tag-discovery widgets.
- [ ] **TAG-05**: `TagRegistry` introspection: `list()`, `printTable()`, `viewer()` (Octave-safe uitable). Carry-forward from existing `SensorRegistry`/`ThresholdRegistry`.
- [ ] **TAG-06**: `TagRegistry.loadFromStructs(structs)` performs **two-phase deserialization** — Pass 1 instantiates all tags with empty children; Pass 2 resolves cross-references. Eliminates the documented `CompositeThreshold.fromStruct` ordering trap.
- [ ] **TAG-07**: Every Tag subclass implements `toStruct()` and static `fromStruct(s)` for JSON round-trip. `TagRegistry.loadFromStructs` round-trip works for any composition depth (composite of composites).
- [ ] **TAG-08**: `SensorTag` subclass — raw `(X, Y)` data, `load(matFile)`, `toDisk(store)/toMemory()/isOnDisk()`, DataStore property. Feature-equivalent to existing `Sensor` class for raw signal handling.
- [ ] **TAG-09**: `StateTag` subclass — zero-order-hold `valueAt(t)` lookup over discrete state transitions; X (timestamps) + Y (numeric or cell-array states). Feature-equivalent to existing `StateChannel` class.
- [ ] **TAG-10**: User can call `FastSense.addTag(tag)` polymorphically. Internal dispatch routes by `tag.getKind()` to existing line-rendering (sensor/monitor) or band-rendering (state) code paths.

### MONITOR — MonitorTag

- [ ] **MONITOR-01**: `MonitorTag` constructed as `MonitorTag(key, parentTag, conditionFn)` produces a binary 0/1 time series via `getXY()`. Output represents condition activation over time (0=inactive/ok, 1=active/violation).
- [ ] **MONITOR-02**: `MonitorTag` IS a `Tag` (`isa(m, 'Tag')` returns true). Plottable via `FastSense.addTag(m)`. Registerable in `TagRegistry`. Can be the parent of another MonitorTag (recursive monitoring) or a child of a CompositeTag.
- [ ] **MONITOR-03**: MonitorTag uses **lazy evaluation with memoization** — `getXY()` computes derived series on first read, caches result, returns cache on subsequent reads until `invalidate()` clears the cache. Per Pitfalls §2: lazy-by-default; eager full-history computation explicitly forbidden.
- [ ] **MONITOR-04**: Parent-driven invalidation — when parent SensorTag's `updateData()` runs OR a referenced StateTag's `updateData()` runs, all dependent MonitorTags receive `invalidate()`. Condition add/remove on MonitorTag also marks `dirty_ = true`.
- [ ] **MONITOR-05**: MonitorTag emits Events via integrated `EventDetector` — when the binary signal transitions 0→1, a new Event is created and pushed to the bound `EventStore` with `TagKeys = {monitor.Key, monitor.Parent.Key}`.
- [ ] **MONITOR-06**: MonitorTag `MinDuration` / debounce — events fire only when violation persists at least `MinDuration` seconds (suppresses sub-threshold-duration chatter). ISA-18.2 alarm-suppression standard.
- [ ] **MONITOR-07**: MonitorTag hysteresis / deadband — `MonitorTag` accepts separate alarm-on threshold (or condition) and alarm-off threshold; prevents chattering at boundary. ISA-18.2 standard practice; most simple historians lack this.
- [ ] **MONITOR-08**: MonitorTag streaming — `appendData(newX, newY)` extends the cached output incrementally without full recompute. Wraps existing `IncrementalEventDetector` pattern. Used by `LiveEventPipeline` live-tick path.
- [ ] **MONITOR-09**: MonitorTag opt-in disk persistence — when `MonitorTag.Persist = true`, derived `(X, Y)` is cached to `FastSenseDataStore` via new `storeMonitor(key, X, Y)`/`loadMonitor(key)` API. Default off; Pitfalls §2 cache-invalidation pain limited to opt-in users.
- [ ] **MONITOR-10**: MonitorTag rejects per-sample side-effect callbacks. Only event-level callbacks (`OnEventStart`/`OnEventEnd`) supported. Prevents PI-AF-style unpredictable-side-effects pitfall.

### COMPOSITE — CompositeTag

- [ ] **COMPOSITE-01**: `CompositeTag` extends `Tag`. Aggregates one or more child Tags via configurable `AggregateMode`. Itself a Tag — recursively composable (CompositeTag of CompositeTags).
- [ ] **COMPOSITE-02**: Built-in aggregation modes: `'and'`, `'or'`, `'majority'`, `'count'`, `'worst'` (max), `'severity'` (weighted average), `'user_fn'` (function handle escape hatch).
- [ ] **COMPOSITE-03**: Children added via `addChild(tagOrKey, opts)` accepting either a Tag handle or a string key (resolved via TagRegistry). Optional `'Weight'` per-child for SEVERITY mode.
- [ ] **COMPOSITE-04**: Cycle detection on `addChild` — rejects self-reference (existing `CompositeThreshold` behavior) AND deeper cycles via DFS (A → B → A) with `CompositeTag:cycleDetected` error.
- [ ] **COMPOSITE-05**: `CompositeTag.getXY()` produces aggregated time series via union-of-timestamps grid + `valueAt` per child per grid point. **Implementation: merge-sort over child sample streams** — NOT N×M dense `union(X_i)` materialization (Pitfalls §3 memory-blowup avoidance).
- [ ] **COMPOSITE-06**: `CompositeTag.valueAt(t)` returns aggregated value at a single instant via `valueAt(t)` on each child + apply aggregator. Fast path for current-state widgets (StatusWidget, GaugeWidget) without full-series materialization.
- [ ] **COMPOSITE-07**: CompositeTag children must be `MonitorTag` or `CompositeTag` (rejected at `addChild` if `SensorTag` or `StateTag` — those have no inherent ok/alarm semantics).

### META — Tag Metadata + Search

- [ ] **META-01**: `Tag.Labels` (cell of strings) — flat cross-cutting classification (`{'pressure', 'pump-3', 'critical'}`). Renamed from existing `Threshold.Tags` to avoid name collision with the Tag class itself.
- [ ] **META-02**: `TagRegistry.findByLabel(label)` returns all tags carrying the given label. Direct port of existing `ThresholdRegistry.findByTag` pattern.
- [ ] **META-03**: `Tag.Metadata` (struct) — open key-value bag for asset id, source file, vendor, etc. Future-proofs for the deferred Asset hierarchy milestone (D); usable today via stringly-typed `Metadata.asset = 'pump-3'`.
- [ ] **META-04**: `Tag.Criticality` enum (`'low'|'medium'|'high'|'safety'`) drives default colors in StatusWidget/IconCardWidget/MultiStatusWidget and event-marker color in FastSense (severity → theme color).

### EVENT — Events on Tag

- [ ] **EVENT-01**: `Event.TagKeys` (cell of strings) replaces the current `SensorName`/`ThresholdLabel` denormalized strings. Supports many-to-many Event ↔ Tag binding (one event can reference multiple tags; one tag can have many events).
- [ ] **EVENT-02**: Separate `EventBinding` registry stores `(eventId, tagKey)` rows. **Critical: Event holds NO Tag handles; Tag holds NO Event handles.** Prevents serialization cycles and matches PI AF event-frame ↔ element binding pattern.
- [ ] **EVENT-03**: `EventStore.eventsForTag(key)` query returns all events bound to the given tag (filters via EventBinding). `Tag.eventsAttached()` is a query, not a stored property.
- [ ] **EVENT-04**: `Event.Severity` field (numeric, mapped to theme color via `StatusOkColor`/`StatusWarnColor`/`StatusAlarmColor`). ISA-18.2 priority levels.
- [ ] **EVENT-05**: `Event.Category` field (`'alarm'|'maintenance'|'process_change'|'manual_annotation'`). Drives default render style in FastSense overlay; drives filter in EventTimelineWidget.
- [ ] **EVENT-06**: Manual event creation API — `tag.addManualEvent(tStart, tEnd, label, message)` writes a new Event to the bound EventStore with `TagKeys = {tag.Key}` and `Category = 'manual_annotation'`. Foundation for the deferred custom-event-GUI milestone (F).
- [ ] **EVENT-07**: FastSense renders events bound to a plotted Tag as **round marker symbols** at event timestamps (Trendminer-style). Theme-driven color from `Event.Severity`. **Toggleable** via `FastSense.ShowEventMarkers` property (default true). Implemented as a **separate render layer** (Pitfalls §10) — `renderEventLayer()` after `renderLines()`, single early-out if no events.

### ALIGN — Time Alignment

- [ ] **ALIGN-01**: Zero-order-hold (LOCF / step) is the only legal alignment in CompositeTag aggregation. Linear interpolation between samples is explicitly **forbidden** (wrong semantics for state signals; out-of-scope for sensor signals).
- [ ] **ALIGN-02**: Union-of-timestamps grid for CompositeTag aggregation — evaluate at every unique timestamp from any child, not on a fixed regular grid. Preserves event-edges; no sampling artifacts.
- [ ] **ALIGN-03**: Aggregation drops grid points before `max(child.X(1))` — no false alarms from "child not yet started" condition. Standard industrial pattern.
- [ ] **ALIGN-04**: NaN handling in aggregation — `AND` with NaN → NaN; `OR` with NaN → other operand; `MAX/WORST` with NaN → ignore; `COUNT` ignores NaN. IEEE 754 conventions; documented in CompositeTag class header.

### MIGRATE — Migration & Cleanup

- [ ] **MIGRATE-01**: Phase 0 deliverable — write a **golden integration test** against the current `Sensor`/`Threshold` API that exercises a representative dashboard (sensor + threshold + composite + event detection). This test stays green through every v2.0 phase as a regression guard. Migrated to new API in Phase 7 only.
- [ ] **MIGRATE-02**: **Strangler-fig sequencing** enforced — `Tag` introduced as a parallel hierarchy in Phase 1 (≤20-file budget). `Sensor`, `Threshold`, `StateChannel`, `CompositeThreshold` untouched through Phase 6. Legacy classes deleted ONLY in Phase 7 cleanup.
- [ ] **MIGRATE-03**: Phase 7 deletes legacy classes: `Sensor.m`, `Threshold.m`, `ThresholdRule.m`, `CompositeThreshold.m`, `StateChannel.m`, `SensorRegistry.m`, `ThresholdRegistry.m`, `ExternalSensorRegistry.m`. Test suite migrated phase-by-phase; full `tests/run_all_tests.m` green at every phase boundary; new tests for Tag/MonitorTag/CompositeTag/Event-Tag-binding added per phase.

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
| (filled by gsd-roadmapper) | | |

---

*Defined for: v2.0 Tag-Based Domain Model — pure-MATLAB unified Tag abstraction over existing FastSense codebase*
*Defined: 2026-04-16*
