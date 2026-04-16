# Roadmap: FastSense Advanced Dashboard

## Milestones

- ✅ **v1.0 FastSense Advanced Dashboard** — Phases 1-9 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Engine Code Review Fixes** — Phase 1 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Performance Optimization** — Phase 1 (shipped 2026-04-04)
- ✅ **v1.0 First-Class Thresholds & Composites** — Phases 1000-1003 (shipped 2026-04-15)
- 🚧 **v2.0 Tag-Based Domain Model** — Phases 1004-1011 (in progress, started 2026-04-16)

## Phases

<details>
<summary>✅ v1.0 FastSense Advanced Dashboard (Phases 1-9) — SHIPPED 2026-04-03</summary>

- [x] Phase 1: Infrastructure Hardening (4/4 plans) — completed 2026-04-01
- [x] Phase 2: Collapsible Sections (2/2 plans) — completed 2026-04-01
- [x] Phase 3: Widget Info Tooltips (3/3 plans) — completed 2026-04-01
- [x] Phase 4: Multi-Page Navigation (3/3 plans) — completed 2026-04-01
- [x] Phase 5: Detachable Widgets (3/3 plans) — completed 2026-04-02
- [x] Phase 6: Serialization & Persistence (2/2 plans) — completed 2026-04-02
- [x] Phase 7: Tech Debt Cleanup (1/1 plan) — completed 2026-04-03
- [x] Phase 8: Widget Improvements (3/3 plans) — completed 2026-04-03
- [x] Phase 9: Threshold Mini-Labels (2/2 plans) — completed 2026-04-03

Full details: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.0 Dashboard Engine Code Review Fixes (Phase 1) — SHIPPED 2026-04-03</summary>

- [x] Phase 1: Dashboard Engine Code Review Fixes (4/4 plans) — completed 2026-04-03

</details>

<details>
<summary>✅ v1.0 Dashboard Performance Optimization (Phase 1) — SHIPPED 2026-04-04</summary>

- [x] Phase 1: Dashboard Performance Optimization (3/3 plans) — completed 2026-04-04

Full details: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.0 First-Class Thresholds & Composites (Phases 1000-1003) — SHIPPED 2026-04-15</summary>

- [x] Phase 1000: Dashboard Engine Performance Optimization Phase 2 (3/3 plans)
- [x] Phase 1001: First-Class Threshold Entities (6/6 plans)
- [x] Phase 1002: Direct Widget-Threshold Binding (2/2 plans)
- [x] Phase 1003: Composite Thresholds (3/3 plans)

</details>

### v2.0 Tag-Based Domain Model — Phases 1004-1011 (active)

- [x] **Phase 1004: Tag Foundation + Golden Test** — abstract `Tag` base, `TagRegistry` (two-phase loader), META properties, plus untouchable golden integration test guarding the rewrite (completed 2026-04-16)
- [ ] **Phase 1005: SensorTag + StateTag (data carriers)** — port `Sensor`/`StateChannel` to Tag subclasses; add `FastSense.addTag()` alongside legacy `addSensor()`
- [ ] **Phase 1006: MonitorTag (lazy, in-memory)** — derived 0/1 time series with debounce, hysteresis, parent-driven invalidation, ZOH alignment; no disk persistence
- [ ] **Phase 1007: MonitorTag streaming + persistence** — `appendData` incremental tail computation and opt-in `FastSenseDataStore` storeMonitor/loadMonitor
- [ ] **Phase 1008: CompositeTag** — AND/OR/MAJORITY/COUNT/WORST/SEVERITY/USER_FN aggregation with cycle detection and merge-sort streaming
- [ ] **Phase 1009: Consumer migration (one widget at a time)** — migrate FastSenseWidget, MultiStatusWidget, IconCardWidget, EventTimelineWidget, SensorDetailPlot, DashboardWidget base, EventDetection consumers; each in a separate green-CI commit
- [ ] **Phase 1010: Event ↔ Tag binding + FastSense overlay** — `Event.TagKeys`, `EventBinding` registry, `EventStore.eventsForTag`, FastSense round-marker overlay (toggleable)
- [ ] **Phase 1011: Cleanup — collapse parallel hierarchy + delete legacy** — delete 8 legacy classes, rewrite golden test for new API, full suite green

## Phase Details

### Phase 1004: Tag Foundation + Golden Test
**Goal**: Establish a parallel Tag hierarchy and an untouchable end-to-end regression guard so the rewrite has a stable safety net before any consumer touches Tag code.
**Depends on**: Nothing (parallel hierarchy — legacy `Sensor`/`Threshold` untouched)
**Requirements**: TAG-01, TAG-02, TAG-03, TAG-04, TAG-05, TAG-06, TAG-07, META-01, META-02, META-03, META-04, MIGRATE-01, MIGRATE-02
**Success Criteria** (what must be TRUE):
  1. User can call `TagRegistry.register(key, tag)` / `get(key)` / `findByLabel('critical')` / `findByKind('sensor')` and observe correct results in a fresh session
  2. User can save a heterogeneous tag set to JSON and round-trip it back in any order (composite of composites included) via `TagRegistry.loadFromStructs` two-phase loader
  3. The Phase-0 golden integration test (current `Sensor` + `Threshold` + `CompositeThreshold` + `EventDetector` end-to-end) passes against the un-modified legacy code with the new Tag base in the path
  4. Every existing test in `tests/run_all_tests.m` still passes — Sensor/Threshold/StateChannel are byte-for-byte unchanged
  5. `Tag` base class exposes ≤6 abstract-by-convention methods (verified by counting `error('Tag:notImplemented', ...)` stubs)
**Verification gates** (from PITFALLS.md):
  - **Pitfall 1 (over-abstracted Tag):** Tag base class has ≤6 abstract methods; no `error('NotApplicable')` stub appears in any subclass written this phase
  - **Pitfall 5 (big-bang sequencing):** Phase touches ≤20 files (falsifiable file-touch budget); no edits to `Sensor.m`, `Threshold.m`, `StateChannel.m`, `CompositeThreshold.m`, `SensorRegistry.m`, `ThresholdRegistry.m`
  - **Pitfall 7 (TagRegistry collisions):** Collision strategy locked (hard error matching `ThresholdRegistry`); collision test green
  - **Pitfall 8 (serialization order):** Two-pass `loadFromStructs` shipped; loud error on missing references (no silent try/warning/skip); 3-deep composite-of-composite round-trip test green
  - **Pitfall 11 (test rewrite without golden):** Golden integration test exists and is checked in; documented as "do not rewrite without architectural review"
**Plans**: 3 plans

Plans:
- [x] 1004-01-PLAN.md — Tag abstract base class + MockTag helper + tests (TAG-01, TAG-02, META-01, META-03, META-04)
- [x] 1004-02-PLAN.md — TagRegistry singleton + two-phase loader + tests (TAG-03, TAG-04, TAG-05, TAG-06, TAG-07, META-02)
- [x] 1004-03-PLAN.md — Golden integration test + file-touch budget verification (MIGRATE-01, MIGRATE-02)

### Phase 1005: SensorTag + StateTag (data carriers)
**Goal**: Port the raw-data half of the domain (`Sensor`'s data role and `StateChannel`'s ZOH lookup) into Tag subclasses so users can plot sensor and state data via the new `addTag()` API while every existing path keeps working.
**Depends on**: Phase 1004 (Tag base + TagRegistry)
**Requirements**: TAG-08, TAG-09, TAG-10
**Success Criteria** (what must be TRUE):
  1. User can construct a `SensorTag('press_a')`, call `load(matFile)` and `toDisk(store)` and observe behavior feature-equivalent to the legacy `Sensor` raw-data API
  2. User can construct a `StateTag` with `(timestamps, states)` and `valueAt(t)` returns the correct ZOH lookup matching legacy `StateChannel` behavior
  3. User can call `FastSense.addTag(tag)` polymorphically — a SensorTag renders as a line, a StateTag renders as bands — without changing the underlying render code path
  4. Both `addSensor()` (legacy) and `addTag()` (new) work in the same FastSense instance — strangler-fig discipline preserved
  5. All existing tests still green; new `TestSensorTag` + `TestStateTag` + `TestFastSenseAddTag` smoke tests green
**Verification gates** (from PITFALLS.md):
  - **Pitfall 1:** No `isa(t, 'SensorTag')` switches inside `FastSense.addTag` — dispatch by `tag.getKind()` only
  - **Pitfall 5:** Phase touches ≤15 files; legacy `Sensor.m`/`StateChannel.m` not edited
  - **Pitfall 9 (MEX wrapping cost):** `SensorTag.getXY()` returns references not copies; benchmark vs. legacy `Sensor.getXY` ≤5% regression
**Plans**: 3 plans

Plans:
- [x] 1005-01-PLAN.md — SensorTag composition wrapper + tests (TAG-08)
- [ ] 1005-02-PLAN.md — StateTag with ZOH valueAt + tests (TAG-09)
- [ ] 1005-03-PLAN.md — FastSense.addTag dispatcher + TagRegistry sensor/state kinds + Pitfall 9 benchmark (TAG-10)

### Phase 1006: MonitorTag (lazy, in-memory)
**Goal**: Replace the side-effect violation pipeline buried inside `Sensor.resolve()` with a first-class `MonitorTag` derived signal that is lazy by default, parent-driven invalidated, and supports debounce + hysteresis — without any disk persistence.
**Depends on**: Phase 1005 (SensorTag + StateTag for parent references)
**Requirements**: MONITOR-01, MONITOR-02, MONITOR-03, MONITOR-04, MONITOR-05, MONITOR-06, MONITOR-07, MONITOR-10, ALIGN-01, ALIGN-02, ALIGN-03, ALIGN-04
**Success Criteria** (what must be TRUE):
  1. User can construct `MonitorTag(key, parentSensorTag, conditionFn)` and `getXY()` returns a binary 0/1 time series produced via lazy memoized recompute
  2. When the parent SensorTag's `updateData()` is called, the dependent MonitorTag's cache is observably invalidated (next `getXY` recomputes)
  3. User can configure `MinDuration = 5` and observe that violations shorter than 5 seconds do not produce events (debounce works)
  4. User can configure separate alarm-on / alarm-off thresholds and observe no chatter at the boundary (hysteresis works)
  5. MonitorTag fires Events on 0→1 transitions with `TagKeys = {monitor.Key, parent.Key}` and the Event lands in the bound EventStore
  6. Aggregation against a child StateTag uses zero-order-hold only; pre-history grid points are dropped (no false "ok" padding)
**Verification gates** (from PITFALLS.md):
  - **Pitfall 2 (premature persistence):** Zero `FastSenseDataStore.storeMonitor` / `storeResolved` calls anywhere in MonitorTag code; "lazy-by-default, no persistence" documented in `MonitorTag.m` class header
  - **Pitfall 5:** Phase touches ≤12 files; legacy `Sensor.resolve()` still works untouched
  - **Pitfall 9:** Live-tick benchmark with one MonitorTag observed against legacy `Sensor.resolve` baseline → ≤10% regression at 12-widget tick
  - **MONITOR-10 explicit:** No per-sample callback APIs exposed (only `OnEventStart` / `OnEventEnd`)
  - **ALIGN-01 explicit:** No call to `interp1` with `'linear'` anywhere in `MonitorTag` aggregation code
**Plans**: TBD
**UI hint**: yes

### Phase 1007: MonitorTag streaming + persistence
**Goal**: Add the two opt-in performance/persistence levers MonitorTag needs for live pipelines and very-long-history monitors — without compromising the lazy-by-default contract from Phase 1006.
**Depends on**: Phase 1006 (MonitorTag base behavior)
**Requirements**: MONITOR-08, MONITOR-09
**Success Criteria** (what must be TRUE):
  1. User can call `monitor.appendData(newX, newY)` and the cached output extends incrementally without full recompute (verified by timing vs. full-recompute baseline)
  2. User can set `MonitorTag.Persist = true`, plot the monitor, restart MATLAB, reload the dashboard, and observe the previously-computed `(X, Y)` returns from disk via `FastSenseDataStore.loadMonitor` without recomputation
  3. With `Persist = false` (default), no SQLite writes occur — opt-in discipline holds
  4. `LiveEventPipeline` live-tick path uses `appendData` and produces correct events at >= the legacy throughput
**Verification gates** (from PITFALLS.md):
  - **Pitfall 2:** `Persist = false` is the documented default; `storeMonitor` only invoked when `Persist == true`
  - **Pitfall 5:** Phase touches ≤8 files (mostly `MonitorTag.m`, `FastSenseDataStore.m`, plus tests)
  - **Pitfall 9:** `appendData` benchmark vs. full recompute shows >5x speedup for 100k-sample tail append
**Plans**: TBD

### Phase 1008: CompositeTag
**Goal**: Aggregate one or more MonitorTags / CompositeTags into a single derived signal via merge-sort streaming, supporting AND / OR / MAJORITY / COUNT / WORST / SEVERITY / USER_FN — replacing the legacy `CompositeThreshold` for time-series aggregation.
**Depends on**: Phase 1006 (MonitorTag exists as a child type), Phase 1007 (streaming primitive available for live aggregation)
**Requirements**: COMPOSITE-01, COMPOSITE-02, COMPOSITE-03, COMPOSITE-04, COMPOSITE-05, COMPOSITE-06, COMPOSITE-07
**Success Criteria** (what must be TRUE):
  1. User can construct a `CompositeTag` with `'and' | 'or' | 'majority' | 'count' | 'worst' | 'severity' | 'user_fn'` and observe correct aggregated output for a documented truth table
  2. User can call `addChild(monitorTagOrKey, 'Weight', 0.7)` accepting either a Tag handle or a string key resolved via TagRegistry
  3. Self-reference and deeper cycles (A → B → A) are rejected at `addChild` time with `CompositeTag:cycleDetected`
  4. `addChild(sensorTag)` is rejected — only MonitorTag and CompositeTag are valid children (no inherent ok/alarm semantics for raw signals or states)
  5. `valueAt(t)` returns the aggregated current value without materializing the full series (fast path for StatusWidget/GaugeWidget)
**Verification gates** (from PITFALLS.md):
  - **Pitfall 3 (memory blowup):** Bench with 8 children × 100k samples → peak RAM <50MB AND compute <200ms; no `union(X_1, ..., X_N)` followed by `interp1` per child anywhere in the implementation
  - **Pitfall 6 (semantics drift):** Truth tables for every `AggregateMode × {0, 1, NaN}` combination documented in the class header; `'majority'` rejects multi-state inputs at `addChild` time, not at `getXY` time
  - **Pitfall 8:** 3-deep composite-of-composite-of-composite round-trip test green
  - **ALIGN-04 explicit:** Test verifies AND-with-NaN → NaN, OR-with-NaN → other operand, MAX/WORST-with-NaN → ignore, COUNT ignores NaN
**Plans**: TBD

### Phase 1009: Consumer migration (one widget at a time)
**Goal**: Migrate every existing consumer of `Sensor` / `Threshold` / `StateChannel` / `CompositeThreshold` to the new Tag API — one widget per commit, each with green CI — so the legacy hierarchy can be deleted in Phase 1011 with zero references remaining.
**Depends on**: Phase 1008 (full Tag API surface available — Sensor/State/Monitor/Composite all working)
**Requirements**: (no exclusively-owned REQ-IDs — this is a structural integration phase that wires existing Tag REQs into existing consumers; MONITOR-05 auto-emit from Phase 1006 fully realized end-to-end here)
**Success Criteria** (what must be TRUE):
  1. After each per-widget commit, `tests/run_all_tests.m` is green AND the Phase-0 golden integration test is green
  2. `FastSenseWidget` accepts a `Tag` (any kind) via a `Tag` property; legacy `Sensor` property still works through an `isa(input, 'Tag')` branch
  3. `MultiStatusWidget`, `IconCardWidget`, `EventTimelineWidget`, `SensorDetailPlot`, `DashboardWidget` base, `EventDetection` consumers all read MonitorTag outputs (auto-emit, status, severity) through the Tag API
  4. No new REQ-IDs are introduced — this phase is pure plumbing migration
  5. Every commit in this phase is independently revertable without breaking CI
**Verification gates** (from PITFALLS.md):
  - **Pitfall 5:** No legacy class is deleted in this phase; legacy `addSensor` / `addThreshold` paths remain alive in production
  - **Pitfall 9:** Live-tick benchmark with 12 migrated widgets ≤10% regression vs. baseline
  - **Pitfall 11:** Golden integration test untouched throughout this phase
**Plans**: TBD
**UI hint**: yes

### Phase 1010: Event ↔ Tag binding + FastSense overlay
**Goal**: Replace the denormalized `SensorName`/`ThresholdLabel` strings on `Event` with a many-to-many binding via a separate `EventBinding` registry, and render bound events as toggleable round markers on FastSense plots — without polluting the existing line-rendering hot path.
**Depends on**: Phase 1009 (consumers fully on Tag API; EventDetection consumers ready to consume new Event shape)
**Requirements**: EVENT-01, EVENT-02, EVENT-03, EVENT-04, EVENT-05, EVENT-06, EVENT-07
**Success Criteria** (what must be TRUE):
  1. User can query `EventStore.eventsForTag('pump_a_pressure_high')` and receive every event whose `TagKeys` cell contains that key (many-to-many works)
  2. `Event` carries no Tag handles and `Tag` carries no Event handles — verified by `save → clear classes → load` round-trip test
  3. User can call `tag.addManualEvent(t1, t2, 'spike', 'manual annotation')` and observe a new Event in the bound EventStore with `Category = 'manual_annotation'`
  4. User can plot a Tag in FastSense and observe round markers at every bound event timestamp, theme-colored by `Event.Severity`; setting `FastSense.ShowEventMarkers = false` removes them
  5. Render bench: a 12-line FastSense plot with zero attached events shows no measurable regression vs. pre-Phase-1010 baseline (separate render layer ships)
**Verification gates** (from PITFALLS.md):
  - **Pitfall 4 (Event ↔ Tag cycle):** Grep confirms zero `Event` properties of type `Tag`/`cell of Tag` and zero `Tag` properties of type `Event`/`cell of Event`; `save → clear classes → load` test green
  - **Pitfall 10 (render-path pollution):** New `renderEventLayer()` is a separate method called after `renderLines()`; single early-out at top if no events; no new conditionals in the line-rendering loop; 0-event render benchmark no regression
  - **Pitfall 5:** Phase touches ≤12 files (Event.m, EventBinding.m new, EventStore.m, EventViewer.m, FastSense.m, plus tests)
  - **EVENT-02 explicit:** Single-write-side rule — only `EventBinding.attach` mutates the relation; convenience wrappers on Event/Tag delegate
**Plans**: TBD
**UI hint**: yes

### Phase 1011: Cleanup — collapse parallel hierarchy + delete legacy
**Goal**: Delete the eight legacy classes, fold any remaining adapter shims, rewrite the golden integration test for the new public API (`addSensor` → `addTag`), and ship a unified Tag-only domain model with a green test suite.
**Depends on**: Phase 1010 (every consumer fully on Tag API; no production reference to legacy classes remains)
**Requirements**: MIGRATE-03
**Success Criteria** (what must be TRUE):
  1. The eight legacy classes are deleted from `libs/SensorThreshold/`: `Sensor.m`, `Threshold.m`, `ThresholdRule.m`, `CompositeThreshold.m`, `StateChannel.m`, `SensorRegistry.m`, `ThresholdRegistry.m`, `ExternalSensorRegistry.m`
  2. `grep -rE 'Sensor\(|Threshold\(|CompositeThreshold\(|StateChannel\(|SensorRegistry\.|ThresholdRegistry\.|ExternalSensorRegistry\.' libs/ tests/ examples/ benchmarks/` returns zero hits in production code (test fixtures explicitly migrated)
  3. The golden integration test is rewritten to call `FastSense.addTag` (not `addSensor`) and passes — proving end-to-end behavior preserved across the rewrite
  4. `tests/run_all_tests.m` is fully green; new tests for Tag/MonitorTag/CompositeTag/Event-Tag-binding all green
  5. `libs/SensorThreshold/` library file count is roughly neutral vs. milestone start (≈8 deleted, ≈7 added: Tag, TagRegistry, SensorTag, StateTag, MonitorTag, CompositeTag, EventBinding)
**Verification gates** (from PITFALLS.md):
  - **Pitfall 5:** This is the ONE phase in v2.0 where production deletions are allowed; no new feature code in this phase
  - **Pitfall 11:** Golden integration test rewrite is the ONLY allowed touch — must preserve assertion semantics; if behavior changed, that's a bug to investigate, not a test to update
  - **Pitfall 12 (feature creep):** Plan-write checked against A+B+C+E scope — no D/F/G features introduced under guise of cleanup
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-9 | v1.0 Advanced Dashboard | 24/24 | Complete | 2026-04-03 |
| 01. Code Review Fixes | v1.0 Code Review | 4/4 | Complete | 2026-04-03 |
| 01. Performance Optimization | v1.0 Performance | 3/3 | Complete | 2026-04-04 |
| 1000-1003 | v1.0 First-Class Thresholds | 14/14 | Complete | 2026-04-15 |
| 1004. Tag Foundation + Golden Test | v2.0 | 3/3 | Complete    | 2026-04-16 |
| 1005. SensorTag + StateTag | v2.0 | 1/3 | In Progress|  |
| 1006. MonitorTag (lazy, in-memory) | v2.0 | 0/? | Not started | — |
| 1007. MonitorTag streaming + persistence | v2.0 | 0/? | Not started | — |
| 1008. CompositeTag | v2.0 | 0/? | Not started | — |
| 1009. Consumer migration | v2.0 | 0/? | Not started | — |
| 1010. Event ↔ Tag binding + overlay | v2.0 | 0/? | Not started | — |
| 1011. Cleanup + delete legacy | v2.0 | 0/? | Not started | — |

## Backlog

### Phase 999.1: Mushroom Cards for Dashboard Engine (BACKLOG)

**Goal:** Add Home Assistant-style Mushroom Card widgets to the dashboard engine — minimal, icon-driven cards with clean visual design for sensor status, controls, and quick glance data. Three new widget classes: IconCardWidget, ChipBarWidget, SparklineCardWidget, plus theme additions and full serializer/builder/detach integration.
**Requirements:** [MUSH-01: DashboardTheme InfoColor, MUSH-02: IconCardWidget, MUSH-03: ChipBarWidget, MUSH-04: SparklineCardWidget, MUSH-05: DashboardEngine type registration, MUSH-06: DashboardSerializer integration, MUSH-07: DetachedMirror + DashboardBuilder integration]
**Plans:** 1/3 plans executed

Plans:
- [ ] 999.1-01-PLAN.md — DashboardTheme InfoColor + IconCardWidget implementation
- [ ] 999.1-02-PLAN.md — ChipBarWidget implementation
- [ ] 999.1-03-PLAN.md — SparklineCardWidget implementation
- [x] 999.1-04-PLAN.md — Infrastructure wiring (Engine, Serializer, DetachedMirror, Builder)

### Phase 999.2: Dashboard Image Export Button (BACKLOG)

**Goal:** Add an image export button to the dashboard toolbar that captures the entire dashboard layout as a single image (PNG/JPEG), enabling users to share or document their dashboard state with one click.
**Requirements:** TBD
**Plans:** 0 plans

Plans:
- [ ] TBD (promote with /gsd:review-backlog when ready)

### Phase 999.3: Graph Data Export (.mat / .csv) (BACKLOG)

**Goal:** Enable exporting any graph's underlying data as .mat or .csv files, so users can easily extract plotted data for further analysis in MATLAB or external tools.
**Requirements:** [EXPORT-01: CSV export with time + Y columns, EXPORT-02: MAT export with lines + thresholds structs, EXPORT-03: NaN-filled union for mismatched X arrays, EXPORT-04: Datetime ISO 8601 + datenum columns, EXPORT-05: Toolbar Export Data button, EXPORT-06: Empty plot error guard]
**Plans:** 2/2 plans complete

Plans:
- [x] 999.3-01-PLAN.md — Core exportData method + private helpers + tests
- [x] 999.3-02-PLAN.md — Toolbar button, icon, callbacks + test updates

### Phase 1000: Dashboard Engine Performance Optimization Phase 2

**Goal:** Fix 6 identified performance bottlenecks in DashboardEngine: (1) FastSenseWidget.refresh() full teardown → incremental update reusing axes/FastSense, (2) broadcastTimeRange synchronous slider → debounced/coalesced updates, (3) All-page panel creation at startup → lazy page realization on first switchPage(), (4) getTimeRange full-array scan per widget per tick → cached min/max with incremental update, (5) switchPage synchronous realize → batched with drawnow, (6) Resize marks all dirty → debounced resize without dirty marking. Goal: 10-50x faster live ticks, 2-5x faster startup, smooth slider interactivity.
**Requirements**: [PERF2-01: Incremental FastSenseWidget refresh, PERF2-02: Debounced time slider broadcast, PERF2-03: Lazy page panel realization, PERF2-04: Cached widget time ranges, PERF2-05: Batched switchPage realize, PERF2-06: Debounced resize without dirty]
**Depends on:** None
**Plans:** 3/3 plans complete

Plans:
- [x] 1000-01-PLAN.md — Incremental FastSenseWidget refresh + cached time ranges
- [x] 1000-02-PLAN.md — Debounced slider broadcast + resize without dirty marking
- [ ] 1000-03-PLAN.md — Lazy page panel realization + batched switchPage realize

### Phase 1001: First-Class Threshold Entities

**Goal:** Make thresholds independent, reusable entities with ThresholdRegistry and shared-reference semantics (TrendMiner-style). Breaking change: replace ThresholdRules/addThresholdRule with Threshold handle class + addThreshold across all libraries.
**Requirements**: [THR-01: Threshold handle class, THR-02: ThresholdRegistry singleton, THR-03: Sensor integration (addThreshold/removeThreshold), THR-04: Resolve adaptation, THR-05: Downstream consumer migration, THR-06: Test migration]
**Depends on:** Phase 1000
**Plans:** 6/6 plans complete

Plans:
- [x] 1001-01-PLAN.md — Threshold handle class + ThresholdRegistry singleton + tests
- [x] 1001-02-PLAN.md — Sensor.m refactor (Thresholds property, addThreshold, resolve adaptation) + sensor test migration
- [x] 1001-03-PLAN.md — Dashboard widgets, SensorRegistry display, loadModuleMetadata migration + widget tests
- [x] 1001-04-PLAN.md — EventDetection migration (IncrementalEventDetector, LiveEventPipeline, EventViewer) + EventDetection tests
- [x] 1001-05-PLAN.md — Gap closure: migrate 10 core sensor + consumer widget test files from addThresholdRule
- [x] 1001-06-PLAN.md — Gap closure: migrate 5 EventDetection test files from addThresholdRule

### Phase 1002: Direct Widget-Threshold Binding — StatusWidget, GaugeWidget, and other widgets can reference Threshold objects directly without requiring a Sensor. Enables standalone threshold-driven status indicators.

**Goal:** Add Threshold + Value/ValueFcn properties to StatusWidget, GaugeWidget, IconCardWidget, MultiStatusWidget, and ChipBarWidget so they can display threshold-driven status without requiring a Sensor object. Purely additive — existing Sensor-bound behavior unchanged.
**Requirements**: [THRBIND-01: StatusWidget + GaugeWidget threshold binding, THRBIND-02: IconCardWidget + MultiStatusWidget + ChipBarWidget threshold binding, THRBIND-03: Serialization round-trip for threshold-bound widgets, THRBIND-04: Backward compatibility, THRBIND-05: ValueFcn live tick support]
**Depends on:** Phase 1001
**Plans:** 2/2 plans complete

Plans:
- [x] 1002-01-PLAN.md — StatusWidget + GaugeWidget threshold binding + serialization + tests
- [ ] 1002-02-PLAN.md — IconCardWidget + MultiStatusWidget + ChipBarWidget threshold binding + serialization + tests

### Phase 1003: Composite Thresholds — CompositeThreshold class that aggregates child Threshold objects for hierarchical status. Component A is green only if children A.A and A.B are both green. Enables system health trees and nested status monitoring.

**Goal:** Create CompositeThreshold class that aggregates child Threshold objects with AND/OR/MAJORITY logic for hierarchical system health monitoring. Wire into all dashboard widgets (StatusWidget, GaugeWidget, IconCardWidget, MultiStatusWidget) with isa-guards and auto-expansion. Add serialization for save/load persistence.
**Requirements**: [COMP-01: CompositeThreshold inherits Threshold, COMP-02: AND/OR/MAJORITY aggregation, COMP-03: Nested composites, COMP-04: computeStatus method, COMP-05: addChild dual-input, COMP-06: Per-child ValueFcn/Value, COMP-07: Shared handle references, COMP-08: MultiStatusWidget expansion, COMP-09: ThresholdRegistry + serialization]
**Depends on:** Phase 1002
**Plans:** 3/3 plans complete

Plans:
- [x] 1003-01-PLAN.md — CompositeThreshold class + TDD test suite (AND/OR/MAJORITY, addChild, computeStatus, nesting)
- [x] 1003-02-PLAN.md — Widget isa-guards (StatusWidget, GaugeWidget, IconCardWidget) + MultiStatusWidget composite expansion
- [x] 1003-03-PLAN.md — CompositeThreshold toStruct/fromStruct serialization + round-trip tests
