# Research Summary — v2.0 Tag-Based Domain Model

**Synthesized:** 2026-04-16
**Sources:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md, PROJECT.md
**Overall confidence:** HIGH on stack/features/architecture; MEDIUM on the rewrite-strategy resolution (see §3).

---

## 1. Executive Summary

- **No new dependencies, no new MEX kernels, no new toolboxes.** Every primitive v2.0 needs already exists in the codebase: `methods (Abstract)` (proven on Octave via `DashboardWidget`), `containers.Map` (proven via `SensorRegistry`/`ThresholdRegistry`), `FastSenseDataStore` (proven via `Sensor.toDisk()`), and the eight existing MEX kernels (`compute_violations_batch`, `binary_search_mex`, `to_step_function_mex`, etc.) cover every MonitorTag/CompositeTag computation. (STACK §"Summary", §"Integration Points")
- **Tag is a refactor + composition layer, not a new system.** `MonitorTag` is essentially `Sensor.resolve()`'s violation pipeline lifted into a first-class Tag; `CompositeTag` is `CompositeThreshold` over time-series instead of point-in-time; `TagRegistry` collapses the two existing registries. The render core, MEX layer, `FastSenseDataStore`, `DashboardEngine`, layout/theme/serializer, and entire WebBridge stack do **not** change. (ARCH §"Summary", §"Integration Points")
- **The single biggest meta-risk is a big-bang rewrite disguised as phase sequencing.** Even with no external users, every test file is an internal user; the project has ~7 production files plus 50+ tests touching `Sensor`. Strangler-fig sequencing must be enforced architecturally (Tag introduced as a *parallel* hierarchy first), not merely observed by discipline. (PITFALLS §5)
- **MonitorTag must be lazy-by-default with no disk persistence in v2.0.** Trendminer's own docs warn that derived-tag persistence + cache invalidation is a workflow nightmare requiring service restarts. Memoize per-render-tick; defer disk persistence to v3.0. (PITFALLS §2)
- **Industrial-historian semantics are convergent and well-documented.** PI AF, Trendminer, Seeq, and Cognite all converge on the same data model (Tag + Type discriminator, derived signals, ZOH alignment, many-to-many event/tag binding, severity max-rollup aggregation). v2.0's design choices are validated against four reference implementations. (FEATURES §"Competitor Feature Matrix")

---

## 2. Locked Decisions (from PROJECT.md + research consensus)

These are **not open** at roadmap-planning time.

| Decision | Source | Notes |
|----------|--------|-------|
| Scope = Ambitious tier: A (Tag root + retrofit) + B (MonitorTag) + C (CompositeTag) + E (Events on tags) | PROJECT.md L51-62 | D (Asset hierarchy), F (Custom event GUI), G (Calc tags) explicitly deferred |
| Single `TagRegistry` replaces `SensorRegistry` + `ThresholdRegistry` | PROJECT.md Key Decisions; ARCH §"TagRegistry"; STACK §"containers.Map" | Flat keyspace with `findByKind()` discrimination |
| MonitorTag is a full time-series signal (not current-state only) | PROJECT.md Key Decisions | Plottable, event-detectable, recursively composable |
| Vocabulary: `Tag` suffix on all primitives; `addTag()` API | PROJECT.md Key Decisions | Trendminer-faithful naming |
| No new dependencies; pure-MATLAB invariant preserved | STACK §"ADDED" (none); PROJECT.md Constraints | Octave 7+/MATLAB R2020b+ floor maintained |
| ZOH (zero-order-hold) is the only legal alignment for CompositeTag aggregation | FEATURES §6; ARCH §"CompositeTag Alignment" | Linear interpolation explicitly forbidden |
| MonitorTag is downstream-only (no back-write into source SensorTag) | FEATURES §2 anti-features | The whole point of v2.0 is to remove the `Sensor.resolve()` entanglement |
| Render core, MEX layer, FastSenseDataStore, WebBridge stack untouched | ARCH §"Render layer untouched" | Only consumers of the old domain types change |

---

## 3. Recommended Approach — Resolving the Rewrite-Strategy Tension

### The disagreement

- **Architecture (HIGH confidence)** recommends *in-place rewrite*: 7 phases, tests rewritten with each phase, old classes deleted in Phase 7. Reasoning: PROJECT.md says no users → no backward compat constraint → adapter layer is wasted work.
- **Pitfalls (HIGH confidence)** recommends *strangler-fig*: Tag introduced as a parallel hierarchy in Phase 1 (Sensor untouched), consumers migrated one-by-one in Phase 3, legacy classes collapsed in Phase 5. Reasoning: even with no external users, the test suite is an internal user, and `Sensor` has ~7 production consumers + 50+ test files. Big-bang sequencing leaves CI red for an entire phase and makes Phase 2+ defects half-blamed on Phase 1.

### Recommendation: **Adopt the strangler-fig approach (Pitfalls' recommendation), with Architecture's phase deliverables.**

**Why strangler-fig wins:**
1. The "no users" framing is misleading. Architecture admits that **Phase 4 (MonitorTag) and Phase 5 (EventDetection migration) are the largest single phases**, each touching the violation-detection core that ~10 widgets and `EventDetector`/`IncrementalEventDetector`/`detectEventsFromSensor` consume. Architecture's "rewrite tests with each phase" plan implicitly bets that all of those rewrites land cleanly in one phase boundary; if any one regresses, the whole phase is red.
2. **The 1001-1003 ThresholdRegistry refactor (the codebase's only relevant precedent) shipped *additively*** — new ThresholdRegistry alongside old ThresholdRules — *not* substitutively. Pitfalls correctly identifies that this lulls the team into thinking "atomic phase rewrites work here," but the v2.0 rewrite is fundamentally substitutive. (PITFALLS §5)
3. The **Phase 1 file-touch budget of ≤20 files** (Pitfalls §5) is a concrete, falsifiable gate. Architecture's Phase 1 plan touches `Tag.m`, `TagRegistry.m`, and `DashboardSerializer.m` — well under 20. But Architecture's Phase 3 (consumer migration) touches `FastSense.m`, `SensorDetailPlot.m`, `FastSenseWidget.m`, `DashboardWidget.m`, `MultiStatusWidget.m`, `IconCardWidget.m`, `EventTimelineWidget.m` simultaneously — exactly the big-bang anti-pattern.
4. Strangler-fig **costs almost nothing extra**: the "parallel hierarchy" is one `SensorTag extends handle` class that wraps or composes a `Sensor` until Phase 5/6 collapses them. No long-lived adapter API needs to be designed; the adapter is private code that gets deleted within the milestone.

### Canonical Phase Decomposition

The recommended decomposition merges Architecture's deliverables (7 phases) with Pitfalls' sequencing discipline (no production deletions until late) and Features' dependency order (A → B → C → D → E from FEATURES §"Phase Ordering Implications"). **One canonical structure for the roadmapper to consume:**

| Phase | Deliverable | Files Touched | Exit Gate |
|-------|-------------|---------------|-----------|
| **0 — Pre-roadmap** | Golden integration test against current `Sensor`/`Threshold` API; v3.0 backlog file | 1 new test file | Golden test green on current code |
| **1 — Tag foundation (parallel hierarchy)** | `Tag` abstract base, `TagRegistry` (with two-phase loader), throw-from-base contract, ≤6 abstract methods (Pitfall 1 budget) | ≤5 new files; **Sensor untouched** | All existing tests still green; new Tag CRUD tests green; Tag base has ≤6 abstract methods |
| **2 — SensorTag + StateTag (data carriers)** | `SensorTag` (wraps/extends `Sensor`), `StateTag` (port of `StateChannel`); both registered in TagRegistry; `FastSense.addTag()` added alongside `addSensor()` | 2 new files + `FastSense.m` additive method | All existing tests green; new Tag-based smoke test green; `addSensor()` still works |
| **3 — MonitorTag (lazy, in-memory only)** | `MonitorTag` ports `compute_violations_batch` + `buildThresholdEntry` + `mergeResolvedByLabel` into `recompute_`; lazy-by-default; per-render-tick memoization; **no disk persistence** | New `MonitorTag.m`; private helpers re-homed | Lazy compute documented in class header; no `FastSenseDataStore` writes; benchmark vs. `Sensor.resolve` shows ≤10% regression |
| **4 — CompositeTag** | `CompositeTag` aggregation via merge-sort streams (NOT N×M union materialization); cycle detection on `addChild`; severity max-rollup as default; truth tables in class header | New `CompositeTag.m` | Bench: 8 children × 100k samples, peak <50MB, compute <200ms; cycle test passes; AND/OR/MAJORITY rejected for multi-state at config time |
| **5 — Consumer migration (one widget at a time)** | Migrate `MultiStatusWidget` → `IconCardWidget` → `FastSenseWidget` → `EventTimelineWidget` → `SensorDetailPlot` → `DashboardWidget` base. Each is a **separate commit with green CI**. Use `isa(input, 'Tag')` branch to keep the legacy path alive. | ~7 widget files (sequentially, not atomically) | After each commit: full test suite green; golden test green |
| **6 — EventDetection migration + Event ↔ Tag binding** | `EventBinding` registry (NOT bidirectional handles per Pitfall 4); `Event.TagKeys` cell; `EventStore.eventsForTag(key)`; rewrite `IncrementalEventDetector`, `detectEventsFromSensor`, `EventViewer`, `MockDataSource`, `MatFileDataSource`; `FastSense.addEventBand`/`addEventOverlay` as **separate render layer** (Pitfall 10) | ~7 EventDetection files + `FastSense.m` | `save → clear classes → load` round-trip test passes; render bench: 0-event path no regression; live tick ≤10% regression |
| **7 — Collapse parallel hierarchy + delete legacy** | Fold `SensorTag` to be self-sufficient; **delete** `Sensor.m`, `Threshold.m`, `ThresholdRule.m`, `CompositeThreshold.m`, `StateChannel.m`, `SensorRegistry.m`, `ThresholdRegistry.m`, `ExternalSensorRegistry.m`; rewrite tests for deleted classes; update golden test for public API rename (`addSensor` → `addTag`) | ~8 file deletions; test cleanup | Full test suite green; no consumer references legacy types; golden test green on new API |

**Phase count: 7 implementation phases + Phase 0 prep.** This matches Architecture's 7-phase deliverable scope while honoring Pitfalls' sequencing discipline.

**Critical constraint:** Phases 1-4 add new code without removing any. **No production deletions before Phase 7.** Phase 5 is the only phase with parallel old/new code paths simultaneously live in production.

---

## 4. Stack Additions / Removals

**Net new dependencies: zero.** (STACK §"ADDED")

**Net new MEX kernels: zero.** (STACK §"MEX kernel reuse")

**Net new MATLAB classes:** ~7 in `libs/SensorThreshold/` (`Tag`, `TagRegistry`, `SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `EventBinding`); ~8 deleted in Phase 7 (`Sensor`, `Threshold`, `ThresholdRule`, `CompositeThreshold`, `StateChannel`, `SensorRegistry`, `ThresholdRegistry`, `ExternalSensorRegistry`). Net file count change: roughly neutral.

**Banned features (anti-dependencies — rationale matters; see STACK §"NOT ADDED"):**
- `dictionary` (R2022b+; not on Octave 11)
- `matlab.mixin.Heterogeneous` / `matlab.mixin.Copyable` / `matlab.mixin.SetGet` (Octave incomplete)
- `enumeration` blocks (parsed-no-op on Octave)
- `events` / listeners (parsed-no-op on Octave)
- `arguments` blocks (patchy on Octave)
- New MEX kernel for tag aggregation (`all`/`any`/`sum` is sub-millisecond at typical N)

---

## 5. Feature Table-Stakes by Phase

Drawn from FEATURES §1-§6 and aligned to the canonical phase decomposition:

| Phase | Table-stakes (must ship) | Differentiators (consider) |
|-------|--------------------------|----------------------------|
| 1-2 | `Tag.Key`/`Name`/`Type`/`Units`/`Description`/`Labels`; `getXY()`/`valueAt(t)`/`getTimeRange()`; `TagRegistry.get/register/find/findByKind`; `toStruct`/`fromStruct` | `Tag.Criticality` enum; `Tag.Metadata` open struct; `findByLabel(label)` |
| 3 | MonitorTag = (sourceTag, condition) → time series; binary 0/1 output; lazy windowed evaluation; auto-emit Events | Tri-state `{ok,warn,alarm}`; severity 0..1; debounce/MinDuration; hysteresis (deadband) |
| 4 | AggregateMode: AND, OR, MAJORITY, COUNT, MAX/WORST_CASE; children by handle or key; self-reference + cycle detection; ZOH time alignment | SEVERITY weighted aggregation; USER_FN escape hatch; per-child weight |
| 5 | (no new tag features — pure consumer migration) | — |
| 6 | `Event.TagKeys` cell (many-to-many); `EventStore.eventsForTag`; FastSense overlay rendering as **separate layer**; severity → color via theme; `EventTimelineWidget.FilterTags` | Auto-emit from MonitorTag; render mode {regions, markers, swim-lanes}; manual event creation API |
| 7 | (no new features — cleanup only) | — |

**Anti-features explicitly banned from v2.0** (consolidated in §9 below).

---

## 6. Architecture Decisions

### 6.1 Tag interface contract — THIN base class
- `Tag < handle` with **≤6 abstract methods** (Pitfall 1 budget): `getXY()`, `valueAt(t)`, `getTimeRange()`, `getKind()`, `toStruct()`, `fromStruct(s)` (static).
- Per-subtype capabilities exposed via **subtype-specific methods**, not base-class abstracts. Consumers test capability via `ismethod(t, 'getTimeSeries')`, **not** `isa(t, 'SensorTag')` switches. (PITFALLS §1)
- Octave-safety pattern: pair `methods (Abstract)` block with throw-from-base stubs (proven via `DataSource.fetchNew`). (STACK §"Abstract-class contract"; ARCH §"Abstract methods convention")
- **Hierarchy is FLAT**, not layered: `Tag` → `{SensorTag, StateTag, MonitorTag, CompositeTag}`. No `DataTag`/`DerivedTag` intermediate layer (YAGNI; matches `DashboardWidget` precedent). (ARCH §"Subclass Hierarchy")

### 6.2 MonitorTag computation — LAZY + memoized + parent-driven invalidation
- **No disk persistence in v2.0.** Memoize on `(monitorKey, rangeStart, rangeEnd)` per render tick; clear on next tick. (PITFALLS §2)
- `recompute_()` ports `Sensor.resolve()`'s violation pipeline — same MEX kernels (`compute_violations_batch`), same private helpers (`buildThresholdEntry`, `mergeResolvedByLabel`). No semantic changes.
- Invalidation: parent `SensorTag.updateData()` → `monitor.invalidate()`; condition add/remove → `dirty_ = true`. Live tick uses full recompute on invalidation in v2.0; incremental append deferred. (ARCH §"Cache + invalidation mechanics")
- **Defer per-MonitorTag SQLite chunks to v3.0.** Existing `FastSenseDataStore.storeResolved`/`loadResolved` pattern (per-SensorTag) is sufficient for typical MonitorTag sizes (tens to hundreds of segments).

### 6.3 CompositeTag alignment — merge-sort streams, NOT dense union materialization
- **Naive `union(X_i)` followed by `interp1` per child is forbidden** (Pitfall 3 — would hit O(N × |union|) memory blowup for nested composites).
- Implement aggregation as merge-sort over child sample streams: at each input event, look up current value of every other child via `binary_search_mex`, emit one output sample if aggregate changed. Coalesce consecutive duplicates. Output complexity: O(transitions), not O(input events).
- Keep separate `currentStatus()` fast path for "current instant only" widget queries (no full-series materialization).
- **Default AggregateMode = `'worst'` (severity max-rollup).** AND/OR/MAJORITY only legal for binary-domain children (validated at `addChild`, not `computeStatus`). Truth tables documented in class header. (PITFALLS §6)

### 6.4 TagRegistry — flat keyspace, type discrimination on register
- One `containers.Map` (replaces `SensorRegistry` + `ThresholdRegistry`).
- **Pick ONE collision strategy and document it** (PITFALLS §7): either (a) auto-prefix on register (`'sensor:pump'`, `'monitor:pump'`) or (b) hard error on duplicate key. Recommend (b) for simplicity; matches existing `ThresholdRegistry` behavior.
- **Two-phase deserialization** fixes the documented `CompositeThreshold.fromStruct` ordering trap: Pass 1 instantiate all tags with empty children; Pass 2 resolve cross-references. Loud error on missing references (no silent `try/warning/skip`). (ARCH §"Two-phase deserialization"; PITFALLS §8)

### 6.5 Event ↔ Tag binding — separate `EventBinding` registry, NOT bidirectional handles
- **Critical: Event holds NO tag handles. Tag holds NO event handles.** All bindings live in a separate `EventBinding` registry as `(eventId, tagKey)` rows. (PITFALLS §4 — this is the canonical pitfall of bidirectional ORM relations)
- `Event.TagKeys` is a cell of *strings* (keys), not handles. Survives serialization, no cycles.
- `Tag.eventsAttached()` is a query on `EventBinding.byTag(this.Key)`, not a stored property.
- Single-write-side rule: only `EventBinding.attach(eventId, tagKey)` mutates; convenience wrappers on Event/Tag delegate.
- FastSense overlay rendering is a **separate render layer** (`renderEventLayer()` after `renderLines()`, with single early-out if no events) — Pitfall 10. Models on existing `NavigatorOverlay` separation.

---

## 7. Top Pitfalls and Where They Land in the Roadmap

Full pitfall-to-phase mapping in PITFALLS.md. Highest-stakes for the roadmapper:

| Pitfall | Land in Phase | Verification gate |
|---------|---------------|-------------------|
| **5. Big-bang rewrite disguised as phase sequencing** | Phase 0 (roadmap) | Phase 1 plan touches ≤20 files; legacy `Sensor` API alive through Phase 6 |
| **1. Over-abstracted Tag interface** | Phase 1 | Tag base ≤6 abstract methods; no `error('NotApplicable')` in any subclass |
| **2. MonitorTag premature persistence** | Phase 3 | No `FastSenseDataStore` writes from MonitorTag; "lazy-by-default" documented in class header |
| **3. CompositeTag memory blowup** | Phase 4 | Bench: 8 children × 100k samples → <50MB peak, <200ms compute |
| **6. Aggregate semantics drift** | Phase 4 (BEFORE implementation) | Severity enum + truth tables documented as Phase 4's first artifact |
| **4. Event ↔ Tag cycle** | Phase 6 | `save → clear classes → load` round-trip test; no Tag handles in Event, no Event handles in Tag |
| **10. Render-path pollution** | Phase 6 | 0-event render path no regression; event layer scales with `numEventsAttached`, not `numLines` |
| **9. MEX wrapping cost** | Phase 5 (revisit at Phase 6 exit) | Live tick benchmark ≤10% regression at 12-widget tick |
| **11. Test rewrite without golden** | Phase 0 (build it now) | One untouched golden integration test across all phases |
| **12. Trendminer feature creep (D/F/G)** | Ongoing | Each phase plan checked against A+B+C+E scope at plan-write time |
| **7. TagRegistry collisions** | Phase 1 | Collision strategy documented; collision test passes |
| **8. Serialization order** | Phase 4 / Phase 6 | Two-pass loader; cycle detection; 3-deep composite-of-composite test |

**Code-review reflexes** (PITFALLS §"Watch Closely During Rewrite") should be embedded in every phase plan template.

---

## 8. Open Decisions for Roadmap Planning

These need user input before Phase 1 plan-write:

1. **MonitorTag severity encoding.** Y as binary `0/1`, integer severity `{0,1,2}`, or float severity `[0,1]`? **Recommended:** integer severity (ARCH OQ-1, FEATURES §2). Locking this affects MonitorTag's `OutputMode` enum and CompositeTag aggregator semantics.
2. **TagRegistry collision strategy.** Auto-prefix vs. hard error on duplicate. **Recommended:** hard error (matches existing `ThresholdRegistry`). PITFALLS §7.
3. **StateTag plottable in FastSense?** Currently StateChannel is a condition input only. **Recommended:** allow, render as bands by default (kind='state' branch in `addTag`). ARCH OQ-2.
4. **CompositeTag mixed-kind children.** Can a CompositeTag have a SensorTag child? **Recommended:** error at `addChild` — children must be MonitorTag or CompositeTag. ARCH OQ-3, FEATURES §3 anti-features.
5. **Live append optimization for MonitorTag.** Phase 3 ships full-recompute on invalidation. Should Phase 5/6 add `MonitorTag.appendData(newX, newY)` for incremental tail computation, or defer to v3.0? **Recommended:** defer; full recompute is sufficient at typical sizes. ARCH OQ-4.
6. **Strangler-fig adoption.** This synthesis recommends strangler-fig over in-place rewrite (§3). User confirmation needed before Phase 1 plan-write commits to either path.

---

## 9. Anti-Features / Out of Scope (consolidated)

Carry these into PROJECT.md "Out of Scope" before Phase 1 starts. Each appears in at least two source files.

**Domain features explicitly deferred:**
- Asset hierarchy (milestone D) — even though every research source mentions it; PROJECT.md L62 confirms
- Formula DSL / calc tags (milestone G) — use MATLAB function handles for MonitorTag conditions
- Custom event GUI (milestone F) — manual event API exists in code, no GUI
- Alarm acknowledgement workflow (ISA-18.2 lifecycle) — separate product
- Event mutation / editing — events are immutable; "edit" = "supersede with new event"
- Tag versioning / definition history — out of scope
- Per-sample quality codes — NaN remains the missing-value convention
- Multiple time bases per Tag — one time base; display formatting only
- Hierarchical label paths (`'plant/unit-A/pump-3'`) — flat labels only
- Full-text search across descriptions — function-handle predicates suffice
- Synced external metadata source — users build their own loader

**Implementation patterns explicitly forbidden:**
- Linear interpolation in CompositeTag aggregation (ZOH only)
- Eager full-history MonitorTag computation (lazy-windowed only)
- String-based condition DSL on MonitorTag (function handles only)
- Multiple value semantics on one MonitorTag (binary AND severity AND categorical) — pick one
- Per-sample side-effect callbacks on MonitorTag (event-level only)
- MonitorTag back-write into source SensorTag (downstream-only)
- Materialized CompositeTag aggregation cache (lazy only)
- Per-event drawing customization (theme-driven coloring only)
- Recursive events that emit events (events are leaves; only signals recurse)
- Embedding Events inside Tag (`Tag.Events = [...]`) — many-to-many via `EventBinding`
- Bidirectional Tag↔Event handles — Pitfall 4
- Disk persistence of MonitorTag derived series in v2.0 — Pitfall 2
- N×M dense matrix materialization in CompositeTag aggregation — Pitfall 3
- New abstract methods on Tag base without justification across all subtypes — Pitfall 1
- Tag method calls inside MEX wrappers — Pitfall 9
- Conditional branches in `FastSense.render` line loop for events — Pitfall 10

**Stack additions explicitly banned** (see §4): `dictionary`, `matlab.mixin.Heterogeneous`, `matlab.mixin.Copyable`, `matlab.mixin.SetGet`, `enumeration` blocks, `events`/listeners, `arguments` blocks, new MEX kernels.

---

## 10. Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All decisions verified against existing codebase patterns; Octave compatibility verified against authoritative wiki (STACK §"Sources") |
| Features | HIGH | Convergent across 4 reference historians (PI AF, Trendminer, Seeq, Cognite); Trendminer-specific severity encoding marked MEDIUM in FEATURES |
| Architecture | HIGH on integration points (direct source grep); MEDIUM on MonitorTag perf under live load (needs Phase 3 benchmarking) | ARCH §"Confidence Assessment" |
| Pitfalls | HIGH on codebase-internal pitfalls (direct source read); MEDIUM on industrial-historian comparisons | PITFALLS §header |
| Rewrite strategy (§3) | MEDIUM | Synthesizer's recommendation; user confirmation needed (Open Decision 6) |

**Gaps to flag during planning:**
- **MonitorTag live-tick performance unverified.** ARCH §"Confidence" notes lazy+cache pattern is standard but FastSense pan/zoom interaction is unverified. Needs benchmarking at Phase 3 exit.
- **Octave abstract-class semantics partial.** Throw-from-base pattern is HIGH confidence; pure `Abstract` attribute is MEDIUM. Mitigation already specified (pair both).
- **Strangler-fig vs. in-place rewrite decision** is the single most-important open decision (Open Decision 6).

---

## 11. References

All citations link back to the source research files; this summary deliberately avoids restating verbatim.

- **Stack details:** [STACK.md](./STACK.md) — see §"Recommended Stack" (table), §"NOT ADDED" (anti-deps with rationale), §"Octave Compatibility Risks", §"Integration Points"
- **Feature table-stakes & anti-features:** [FEATURES.md](./FEATURES.md) — see §1-§6 (per-section tables), §"Anti-Features Summary", §"Competitor Feature Matrix", §"Phase Ordering Implications"
- **Architecture & build order:** [ARCHITECTURE.md](./ARCHITECTURE.md) — see §"Tag Interface Contract", §"MonitorTag Computation Strategy", §"CompositeTag Alignment Strategy", §"TagRegistry Organization", §"Event ↔ Tag Binding", §"Suggested Build Order", §"Integration Points" (file-by-file change table)
- **Pitfalls & verification gates:** [PITFALLS.md](./PITFALLS.md) — see §"Critical Pitfalls" 1-6, §"Moderate Pitfalls" 7-10, §"Watch Closely During Rewrite" (PR review reflexes), §"Pitfall-to-Phase Mapping"
- **Locked scope:** [PROJECT.md](../PROJECT.md) — see §"Current Milestone" (Ambitious tier A+B+C+E), §"Key Decisions" (v2.0 entries)

---

*Synthesis for: v2.0 Tag-Based Domain Model — pure-MATLAB unified Tag abstraction over existing FastSense codebase*
*Synthesized: 2026-04-16*
