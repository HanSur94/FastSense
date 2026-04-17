# Domain Pitfalls — v2.0 Tag-Based Domain Model

**Domain:** Unified Tag abstraction (Trendminer/PI AF flavor) bolted onto an existing tightly-coupled MATLAB sensor/threshold/event/widget codebase
**Researched:** 2026-04-16
**Confidence:** HIGH on codebase-internal pitfalls (direct read of `Threshold.m`, `CompositeThreshold.m`, `Event.m`, ROADMAP); MEDIUM on industrial-historian comparisons (Trendminer/PI AF docs corroborate cache-invalidation and template-regret patterns; Seeq lazy/persisted distinction inferred from formula-language docs, not explicitly stated)

---

## Summary

This rewrite is the highest-risk milestone the project has attempted. Twelve specific pitfalls are likely; six are critical, four are moderate, two are minor. The single biggest risk is **rewriting too much at once** — `Sensor`, `Threshold`, `StateChannel`, `EventDetection`, `FastSense.addSensor`, six dashboard widgets, and `SensorDetailPlot` all change shape under the Tag abstraction simultaneously. The codebase's lack of external users tempts a big-bang rewrite; this is the wrong instinct. Even with no users, every test file is an internal user. The strangler-fig sequencing must be enforced architecturally (introduce `Tag` as a *parallel* hierarchy first, then collapse `Sensor` into `SensorTag`), not just observed by discipline.

The second biggest risk is **conflating "Tag is one abstraction" with "Tag has one interface."** PI AF and Trendminer succeed because their tag interface is intentionally minimal (read a value, read metadata) — derived behavior lives in subtype-specific methods. A fat `Tag` base class that requires every subclass to implement `resolve(timeRange)`, `getValue(t)`, `computeStatus()`, `detectViolations()`, and `subscribe(callback)` will collapse under its own weight by Phase 3.

The third biggest risk is **MonitorTag derived-data persistence**. The temptation to "just store MonitorTag values to disk like a SensorTag" is the same trap Trendminer's own calculated-tag cache invalidation problem warns against (their docs explicitly note that calculated tags cache the interpolation type of underlying tags and require resaving when upstream changes — a workflow burden that surfaces precisely because persistence and derivation have been mixed).

All twelve pitfalls below are mapped to specific phases. Several should be revisited at every phase boundary as ongoing review checkpoints.

---

## Critical Pitfalls

### Pitfall 1: Over-Abstracted Tag Interface (the "fat base class" trap)

**What goes wrong:** The `Tag` abstract base class accumulates methods to satisfy each consumer: `FastSense` wants `getTimeSeries(range)`, `EventDetection` wants `detectViolations(rule)`, dashboard widgets want `currentValue()` and `currentStatus()`, `MonitorTag` wants `subscribe(upstream)`, `CompositeTag` wants `addChild()`, `StateTag` (which is categorical, not numeric) is forced to no-op or throw on numeric methods. By Phase 3 the base class has 15+ abstract methods, half of them stubbed `error('NotApplicable')` in subclasses.

**Why it happens:** "Everything is a Tag" gets read as "every Tag has the same shape." The codebase's existing `DashboardWidget` base class succeeded with a thin contract (`render`, `refresh`, `getType`, `toStruct`/`fromStruct`) — but it didn't have to satisfy four different consumer subsystems. `Tag` does, and the temptation is to expose every consumer's needs on the base.

**Warning signs (code review):**
- Any subclass implementing a method as `error('Tag:notApplicable', ...)` or returning empty defensively
- Base class growing past ~6 abstract methods
- Consumers (e.g., `FastSense.addTag`) doing `isa(t, 'SensorTag')` or `isa(t, 'CompositeTag')` switches to call subtype-specific methods — this is the symptom that the *interface* fragmented but the *base class* didn't
- A new `TagKind` enum property used to switch behavior inside generic code

**Prevention strategy:**
- **Define the Tag base class as the *intersection* of subtype capabilities, not the union.** Minimum viable contract: `Key`, `Name`, `Type` (read-only string), `toStruct`/`fromStruct`. That's it.
- Use **capability interfaces** (MATLAB has no real interfaces, simulate with abstract classes that subtypes mix in via inheritance or via duck-typed methods checked by `ismethod`):
  - `TimeSeriesTag` mixin → `getTimeSeries(rangeStart, rangeEnd)` — only `SensorTag` and `MonitorTag` implement
  - `StatusTag` mixin → `currentStatus()` — `MonitorTag`, `CompositeTag`, and `StateTag` implement
  - `Aggregating` mixin → `addChild`, `getChildren` — only `CompositeTag` implements
- Consumers test capability via `ismethod(t, 'getTimeSeries')`, NOT `isa(t, 'SensorTag')`. This is the same pattern PI AF uses with its Attribute Data References — different DRs (PI Point, Formula, Table Lookup) implement only what they support; the AF Attribute base contract is small.
- Code review rule: any new abstract method on `Tag` requires explicit justification that *all* current and planned subtypes implement it meaningfully (not as a no-op).

**Address in:** Phase 1 (foundation). This is a one-time architectural decision; getting it wrong here forces a re-rewrite at Phase 4 or 5.

---

### Pitfall 2: Premature MonitorTag Persistence (the "cache the derived" trap)

**What goes wrong:** MonitorTag (a derived 0/1/severity time series computed from a SensorTag + a Threshold) is treated as a first-class storable signal — its samples get written to disk via `FastSenseDataStore` "for performance." Then upstream sensor data is amended (late-arriving samples, replay, threshold reconfiguration, threshold value tweak from 80 to 75). The persisted MonitorTag is now stale. The system has no invalidation tracking, so dashboards display incorrect monitor states until someone manually rebuilds.

**Why it happens:**
1. SensorTag already persists to `FastSenseDataStore`; the symmetry "MonitorTag is also a time series, so it should also persist" feels natural.
2. Recomputing from upstream feels expensive when Threshold conditions are already evaluated by `compute_violations_mex`.
3. The existing `Sensor.resolve()` pattern eagerly computes violations alongside data — there's no pre-existing distinction between "raw" and "derived."

**Real-world precedent:** Trendminer's own documentation explicitly warns about this: calculated tags cache the interpolation type of underlying tags, and changing the upstream type requires resaving every calculated tag downstream and restarting the `tm-compute` service ([Trendminer Community: Tag does not load after changing interpolation type](https://community.trendminer.com/admin-corner-49/my-tag-does-not-load-anymore-after-changing-the-interpolation-type-in-the-data-source-173)). Their architecture treats calculated tags as a separate cache subsystem with explicit invalidation — and it's still painful enough to require service restarts.

**Prevention strategy:**
- **MonitorTag is lazy-by-default in v2.0.** When a consumer asks `monitorTag.getTimeSeries(t1, t2)`, it computes on-demand from upstream `SensorTag.getTimeSeries(t1, t2)` + the threshold rule. Use the existing MEX `compute_violations_mex` kernel — same hot path as today's `Sensor.resolve`.
- **Cache only within a single render/tick scope** (memoize on `(monitorKey, rangeStart, rangeEnd)` for the duration of one `onLiveTick`; clear on next tick). This captures the "render four widgets that all reference the same MonitorTag" performance win without persistence concerns.
- **No disk persistence for MonitorTag in v2.0.** Defer to v3.0 with explicit invalidation tracking (upstream version stamps, threshold version stamps, range-based dirty bits).
- If persistence is required for very long monitor histories, design it as a *separate optimisation feature*, not a default behavior, with explicit "rebuild" API and version stamps on the upstream SensorTag and Threshold.

**Warning signs:**
- Any code path that writes MonitorTag samples to `FastSenseDataStore`
- "Refresh monitor" button or toolbar action — that's a manual cache-invalidation, which means the abstraction leaked
- MonitorTag gaining a `LastComputedAt` or `Version` property
- Tests that mutate threshold values then read MonitorTag without explicit recompute — the test passes only because both happen in the same in-memory session

**Address in:** Phase 2 (MonitorTag implementation). Make laziness an explicit architectural decision documented in `MonitorTag.m` header. Add a code-review checkpoint for "any persistence of derived data."

---

### Pitfall 3: CompositeTag Time-Axis Memory Blowup

**What goes wrong:** A CompositeTag with N children, each on a different sensor with M samples, computes its aggregate time series by union-of-X timestamps, then forward-filling each child's value at every union timestamp. Memory: `O(N × |union(X_1, ..., X_N)|)`. For 8 children with 100k samples each at offset timestamps, the union can hit 800k timestamps, materialising an 8 × 800k = 6.4M-cell intermediate matrix per evaluation — for one composite. With nested composites, this multiplies recursively.

**Why it happens:** "Aggregate the children" reads as "align them on a common time axis first." The naive implementation creates a dense matrix; the optimised approach (merge-sort iterators, only emit timestamps where the *output* changes) requires algorithmic care that is easy to skip in v1.

**Why this matters in this codebase:** `CompositeThreshold.computeStatus()` today (read in `libs/SensorThreshold/CompositeThreshold.m` line 197-213) computes one scalar status — no time alignment needed. The Tag rewrite turns this into a *time series* computation (`CompositeTag` produces a derived signal, not just a current status), which is a fundamentally different problem. The naive port loses the cheapness.

**How industrial historians avoid it:** OPC HDA, PI AF analysis, and Trendminer compute composites event-driven — only at timestamps where any input changed. The output sample stream is `O(sum(|X_i|))` worst case, not `O(N × |union|)`. Trendminer Tag Builder formula tags are documented as event-driven calculations ([Trendminer Tag Builder: Custom calculations](https://userguide.trendminer.com/2025.R3.0/en/tag-builder--custom-calculations.html)), not interval-aligned.

**Prevention strategy:**
- **Implement CompositeTag aggregation as a merge-sort over child sample streams.** At each input event, look up the current value of *every other* child via binary search (the existing `binary_search_mex` MEX kernel does exactly this), emit one output sample if the aggregate changed.
- **Coalesce consecutive duplicate output samples** ("if the aggregate didn't change, don't emit") — this gives O(violation transitions) output, not O(input events).
- **For the "current status only" use case** (dashboard StatusWidget), keep a separate `currentStatus()` fast path that does NOT materialise the full series — looks up only the most recent value per child.
- **Cap recursion depth and emit a warning** if a CompositeTag tree goes deeper than 5 levels (matches `miss_hit.cfg` nesting limit philosophy). Deep composite trees are usually a modeling smell anyway.

**Warning signs:**
- `CompositeTag.getTimeSeries` allocates an N×M matrix
- Any `union(X_1, X_2, ..., X_N)` followed by `interp1` per child
- Memory spikes proportional to (numChildren × numSamples)
- Performance benchmarks not run on composites with >5 children and >100k samples per child

**Address in:** Phase 3 (CompositeTag implementation). Bench at end of phase with `CompositeTag` of 8 children × 100k samples; gate phase exit on memory < 50MB peak and < 200ms compute time.

---

### Pitfall 4: Event ↔ Tag Cycle Serialization Trap

**What goes wrong:** Events bind to Tags (an event "happened on tag X"). Tags want to know their attached events (for FastSense overlay rendering). The naive design: `Event` holds `TagRef` (or tag key), `Tag` holds `Events` cell. On serialization, each side serialises the other, producing infinite recursion or duplicate event records (Event serialised inline inside Tag, then Tag serialised inline inside Event, etc.). When deserialising, `Event.fromStruct` resolves `TagRef` from `TagRegistry.get(...)` — but the registry hasn't been populated yet because the Tag's `fromStruct` is what populates it, and *that* is calling `Event.fromStruct` first to rehydrate the events list.

**Why it happens:** The current `Event.m` (read at `libs/EventDetection/Event.m`) carries a `SensorName` *string* — a denormalised lookup key, not a handle. That works because Sensors aren't serialised inside Events. The Tag rewrite makes Tags first-class graph nodes that need to be navigable from both directions, and the temptation is to add bidirectional handle references.

**Real-world precedent:** This is the canonical pitfall of bidirectional ORM relations — Hibernate, EF Core, Doctrine all warn against it. `CompositeThreshold.fromStruct` in this codebase (read `libs/SensorThreshold/CompositeThreshold.m` line 276-334) already shows the correct pattern: it stores child *keys* in the struct, not child handles, and resolves via `ThresholdRegistry.get(key)` — but it requires children to be registered first, with a manual ordering rule documented in the class header (line 27-32).

**Prevention strategy — the canonical pattern:**
- **Store binding as a separate registry, not as bidirectional handles.** Introduce `EventBinding` (or extend `EventStore`) as the single source of truth: a relation `(eventId, tagKey)` table.
- **`Event` holds NO tag references.** It holds `eventId` and bookkeeping metadata only.
- **`Tag` holds NO event references.** Its `eventsAttached()` method queries `EventBinding.byTag(this.Key)`.
- **Serialization order:** Tags first (registered into `TagRegistry`), Events second (registered into `EventStore`), Bindings third. Each phase's `fromStruct` is independent — no cycles.
- **Single-write-side rule:** only `EventBinding.attach(event, tag)` mutates the relation. Both `Event.attachTo(tag)` and `Tag.attachEvent(event)` are forbidden as mutation APIs (they can exist as convenience wrappers that delegate to `EventBinding`).

**Warning signs:**
- Any `Event` property of type `Tag` or `cell of Tag`
- Any `Tag` property of type `Event` or `cell of Event`
- `Event.toStruct` recursing into tag.toStruct, or vice versa
- A "fix" attempt that serialises the binding twice, or breaks the cycle by silently dropping one direction
- Tests that work in-session but fail after `save → clear all → load`

**Address in:** Phase 4 (Events ↔ Tag binding). Integration test must include `save → clear classes → load → verify both directions queryable`.

---

### Pitfall 5: Big-Bang Rewrite Disguised as Phase Sequencing

**What goes wrong:** The rewrite's six phases (Tag base + retrofit, MonitorTag, CompositeTag, Events, render integration, cleanup) get scoped such that Phase 1's "retrofit Sensor as SensorTag" requires every consumer (FastSense, EventDetection, every dashboard widget, SensorDetailPlot, all 50+ tests) to update simultaneously. Phase 1 becomes a ~3000-line atomic commit. CI is red for the entire phase. Every defect found in Phase 2+ is half-blamed on "Phase 1 might have broken it."

**Why it happens:**
1. "No external users → backward compat is not a constraint" mistakenly reads as "no need for incremental migration."
2. The codebase's tight coupling makes incremental migration look infeasible: `Sensor` is referenced by ~7 production files and many tests; rewriting in place "must" be all-or-nothing.
3. Phases 1001-1003 (the Threshold first-class refactor) shipped as relatively atomic chunks, and they worked — that experience misleads here because the Threshold refactor was *additive* (new ThresholdRegistry alongside old ThresholdRules), whereas the Tag rewrite is *substitutive* (Sensor becomes SensorTag).

**Prevention strategy — strangler fig, even with no users:**
- **Phase 1: Add Tag as a parallel hierarchy. Do not touch Sensor.** `Tag`, `TagRegistry`, `SensorTag` (new wrapper around `Sensor` — or `SensorTag extends Sensor` — keeping `Sensor` unchanged). New `FastSense.addTag(t)` API alongside existing `addSensor(s)`. All existing tests continue to pass unmodified. Exit gate: green CI on full unmodified test suite + new Tag tests.
- **Phase 2: MonitorTag and CompositeTag built against the parallel Tag hierarchy.** Independent of legacy Sensor code. Exit gate: full Sensor tests still green.
- **Phase 3: Migrate one consumer at a time.** Pick `StatusWidget` first (smallest, recently refactored). Move its threshold-binding to take `MonitorTag` instead of `Threshold`. Run targeted tests. Then `GaugeWidget`. Then `MultiStatusWidget`. Each consumer migration is a separate commit with green CI. Use `isa(input, 'Tag')` branch to keep the old `Threshold` path alive during migration.
- **Phase 4: Migrate EventDetection.** It's the heaviest consumer; do it after the lighter widgets shake out the Tag API.
- **Phase 5: Collapse the parallel hierarchy.** Once everything consumes Tag, rename `Sensor` → archived, fold `SensorTag` to be self-sufficient. This is the *only* phase that should produce many-file deletions.
- **Phase 6: Cleanup, deprecation removal, doc rewrite.**

**Most common mistake:** Phase 1 conflating "introduce Tag" with "delete Sensor." These must be separate phases even when tempting to combine.

**Warning signs:**
- Phase 1 plan touches more than ~20 files
- Phase 1 PR description includes "all consumers updated to..."
- A phase has both new-code and dead-code-removal in scope
- Tests modified in the same commit as production code (rather than tests added first, code follows)
- The word "migrate" appears in Phase 1 plan; it should appear no earlier than Phase 3

**Address in:** Phase 0 / Roadmap creation (NOW, before Phase 1 plan-write). This is the meta-pitfall — getting the phase boundaries right is the prevention.

---

### Pitfall 6: Aggregate Mode Semantics Drift (binary → tri-state → numeric)

**What goes wrong:** The existing `CompositeThreshold` (read at `libs/SensorThreshold/CompositeThreshold.m` line 379-409) defines AND/OR/MAJORITY over a binary `{ok, alarm}` domain. CompositeTag in v2.0 must support tri-state `{ok, warn, alarm}` (because MonitorTag will support a `Severity` property per the milestone goals) and possibly a numeric severity scale. Designers extend AND/OR/MAJORITY without thinking through edge cases:

- "AND" of `{ok, warn, alarm}` → ? (Is it the *worst* status, i.e., max-severity? Or "all must be ok"?)
- "OR" of `{ok, warn}` → ? (Is one warn enough to demote? Or does ok dominate?)
- "MAJORITY" of `{ok, ok, warn, alarm}` → ? (Strict majority of "non-ok"? Of "alarm"? Of "any concerning"?)
- "MAJORITY" with even N and a tie → ? (Today's code treats `nOk > n/2` as ok — but with three states, what does "tie" even mean?)

Different designers in different phases interpret these differently; widgets read different statuses for the same composite over time as logic gets tweaked.

**Why it happens:** AND/OR/MAJORITY are well-defined in Boolean algebra and seem like obvious extensions to multi-valued logic. They aren't.

**Real-world precedent:** Industrial alarm systems (per ISA-18.2 and IEC 62682) typically use **severity max-rollup** semantics: a parent's status is `max(child_statuses)` over a strict severity ordering (`ok < warn < alarm < critical`). Grafana, CloudWatch, and most monitoring systems converged on this: any child at higher severity promotes the parent ([AWS CloudWatch Composite Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Create_Composite_Alarm.html), [Grafana severity issue #6553](https://github.com/grafana/grafana/issues/6553)). The "majority" mode is rarely used outside binary domains because its semantics with N-state values are genuinely ambiguous.

**Prevention strategy:**
- **Define a canonical Status type with strict ordering.** Adopt `Severity` enum: `OK < WARN < ALARM < CRITICAL` (4 levels max). Document it in a single header file (`Severity.m` or constant in `Tag.m`).
- **Default aggregation: severity max-rollup** ("worst child wins"). This is the unambiguous, industrial-standard semantic. Make it the default `AggregateMode = 'worst'`.
- **Restrict AND/OR/MAJORITY to binary contexts.** When a CompositeTag is created with `AggregateMode = 'majority'` and any child is multi-state, throw `CompositeTag:incompatibleAggregateMode` at `addChild` time, not at `computeStatus` time. (Fail fast at configuration, not at runtime.)
- **Provide explicit numeric aggregation modes for severity scales:** `'mean'`, `'max'`, `'min'`, `'count_ge_warn'`, `'count_ge_alarm'`. These have unambiguous numeric semantics.
- **Document the truth table** for each aggregate mode in the class header. Every mode × every state combination. If you can't write the truth table without ambiguity, the semantics aren't ready.

**Warning signs:**
- Aggregate mode logic with `if status == 'warn' && otherStatus == 'ok'` and similar pairwise comparisons
- Truth-table tests missing for combinations involving the middle severity level
- A "severity" property added to MonitorTag without updating all CompositeTag aggregate modes
- Two widgets displaying the same composite with different statuses (drift symptom)

**Address in:** Phase 3 (CompositeTag) — *before* writing the implementation. Design the Severity type and truth tables as the first artifact of the phase.

---

## Moderate Pitfalls

### Pitfall 7: TagRegistry Flat Namespace Collisions

**What goes wrong:** A SensorTag named `'pump_a_pressure'`, a MonitorTag named `'pump_a_pressure'` (the threshold-violation derivative of the same sensor), and a CompositeTag named `'pump_a_pressure'` (the rolled-up health) all coexist. The current `ThresholdRegistry` (and the planned `TagRegistry` collapsing both `SensorRegistry` + `ThresholdRegistry` per ROADMAP key decision) is a flat keyspace. The second `register('pump_a_pressure', ...)` either silently overwrites or throws — both are bad.

**Why it happens:** Convenient names collide naturally because related entities (a sensor and its threshold and its composite) inherit the same conceptual subject. The ROADMAP explicitly states "Single TagRegistry (replaces SensorRegistry + ThresholdRegistry) — One namespace, one search surface" — which is the right call but doubles the collision surface.

**Prevention strategy:**
- **Type-prefix convention enforced at register time.** Auto-prefix on registration: `sensor:pump_a_pressure`, `monitor:pump_a_pressure`, `composite:pump_a_pressure`. The user-facing API still accepts the unprefixed key and resolves by the type of the registered tag, but internally the registry stores prefixed keys to prevent collision.
- **Or: explicit collision check with helpful error.** `register(key, tag)` checks `containsKey` before insertion; if collision, error with `'TagRegistry:collision'`, message naming both tag types and keys.
- **Search API returns by type filter:** `TagRegistry.findByType('monitor')`, `TagRegistry.find('pump_a_pressure', 'monitor')`. Lookup-by-key-only (`get(key)`) requires a unique unprefixed key globally; throws on ambiguity.
- Pick *one* approach (prefix or collision-check) and document it; don't mix.

**Warning signs:**
- Tests that register two tags with the same key and assume both survive
- Code that does `TagRegistry.get(name)` without type discrimination
- A SensorTag and its MonitorTag derivative sharing exactly the same name in examples

**Address in:** Phase 1 (Tag root + TagRegistry). One-time API decision; lock it in early.

---

### Pitfall 8: Serialization Order Foot-Guns (composite-of-composite, lazy refs)

**What goes wrong:** `CompositeTag.fromStruct` resolves child keys via `TagRegistry.get(key)`. If a parent CompositeTag deserialises before its children are registered, the lookup fails — current `CompositeThreshold.fromStruct` (read at line 326-332) handles this with a `try/warning/skip`, which is silently lossy: the deserialised composite is missing children with no loud failure. With nested composites (composite-of-composite) and event bindings (Pitfall 4), the order requirements become subtle.

**Why it happens:** JSON serialization is order-sensitive but JSON itself doesn't encode dependencies. The `DashboardSerializer` save/load round-trip iterates widgets in declaration order, which is unrelated to tag dependency order.

**Prevention strategy — the canonical pattern is two-pass with placeholders OR lazy resolve on first use.** Two-pass is cleaner here:
- **Pass 1:** Iterate all serialised tags. For each, instantiate the empty Tag object and register in TagRegistry. For composites, do not yet resolve children.
- **Pass 2:** Iterate again. For each composite, resolve children from registry now that all are present.
- **Bonus pass 3 (events):** With all tags in registry, deserialise events and bindings.

This is exactly the pattern used by Hibernate session loading, Protobuf two-phase parsing, and most ORM cycle-resolvers.

- **Detect cycles explicitly.** A composite cycle (`A` includes `B`, `B` includes `A`) breaks the `computeStatus` traversal. Add cycle detection to `addChild`: walk the would-be subtree of the new child looking for `obj` itself, throw `CompositeTag:cycleDetected` if found.
- **Loud failure on missing references.** Replace silent `try/warning/skip` with hard error during deserialisation; add a `--strict` or `--lenient` mode if backward-tolerant loading is needed.

**Warning signs:**
- Serialization tests that pass when ordered correctly but fail when child order is shuffled
- Warnings logged on load that are easy to ignore (`'CompositeTag:loadChildFailed'`)
- Tests for composite-of-composite-of-composite (3 levels deep) missing
- No cycle-detection test in `CompositeTag` test suite

**Address in:** Phase 3 (CompositeTag) for two-pass loader; Phase 4 (Events) extends to three-pass.

---

### Pitfall 9: MEX Kernel Signature Drift / Per-Call Wrapping Cost

**What goes wrong:** Existing MEX kernels (`compute_violations_mex`, `lttb_core_mex`, `minmax_core_mex`, `binary_search_mex`, `to_step_function_mex`) take raw arrays — `(X, Y, threshold)` or similar. Wrapping them in a Tag-aware MATLAB layer that calls `tag.getTimeSeries()` → `[X, Y] = tag.getXY()` → `mex(X, Y, ...)` adds per-call overhead: argument unpacking, struct field reads, possibly `containers.Map` lookups inside the Tag's internal data resolver. For 60Hz live ticks rendering 12 widgets, this adds up.

**Why it happens:** The Tag abstraction wants encapsulation; the MEX layer wants raw arrays. The MATLAB wrapping layer between them is invisible until profiling.

**Prevention strategy:**
- **Preserve the raw-array MEX boundary.** MEX kernels never see Tag objects. The layer immediately above MEX accepts a Tag and extracts `(X, Y)` once, passes them in. No per-sample Tag method calls inside any hot path.
- **Cache `(X, Y)` pointers per render frame.** SensorTag's `getTimeSeries` should return references (handles to internally-cached arrays), not copies. MATLAB's COW semantics make this cheap *if* you don't mutate.
- **Bench every new wrapper.** For every Tag method that wraps a MEX call, run a benchmark before/after the wrapping introduction. Regression budget: ≤ 5% added overhead per MEX call site.
- **Profile the live tick after Phase 5.** Compare baseline (current `Sensor.resolve` → MEX) to new (`SensorTag.getTimeSeries` → MEX). Acceptable: ≤ 10% slower at 12-widget live tick.

**Warning signs:**
- Tag method calls inside MEX wrappers (per-sample or per-segment)
- `containers.Map` lookups on the hot path
- Adding `cellfun` or `arrayfun` over child tags inside a render loop
- The phrase "we'll optimise later" in any plan touching the render path

**Address in:** Phase 1 (when defining `SensorTag.getTimeSeries`) and revisited at Phase 5 (consumer migration). Bench at Phase 5 exit.

---

### Pitfall 10: FastSense Event-Overlay Polluting the Render Hot Path

**What goes wrong:** Adding "render attached events as overlay regions/markers" to FastSense lines is implemented as new branches inside the existing line-rendering loop in `FastSense.render()` and `FastSense.updateData()`. Every line render now checks "are there events on this tag?" → "fetch events" → "render shaded region per event." For lines with no attached events, the check is wasted; for lines with 1000 events, the loop dominates the render time.

**Why it happens:** Events live on Tags, and FastSense renders Tags, so colocating event rendering with line rendering "feels right." The existing FastSense code is a hot path that has been tuned over the v1.0 performance phase; adding conditional branches dilutes its tightness.

**Prevention strategy:**
- **Event overlay is a separate render layer.** Add `FastSense.renderEventLayer()` invoked *after* `renderLines()`. It iterates only tags with attached events, fetches events from the binding registry (Pitfall 4), and draws as `patch` (region) or `xline` (marker) objects on a separate axes child group.
- **Skip the event layer entirely if no events exist for any displayed tag.** Single early-out check at the top of `renderEventLayer`, not per-line.
- **Use existing `NavigatorOverlay` pattern as the model.** That overlay already lives separately from the line rendering and demonstrates the layer separation pattern in this codebase.
- **Cache event lookups per render frame.** Events for a given tag in a given time range shouldn't be re-fetched per frame; memoize on `(tagKey, rangeStart, rangeEnd)` for one render scope.
- **Live tick: only refresh the event layer if `EventStore` version changed.** Add a monotonic version counter to `EventStore`; FastSense compares against last-rendered version, skips event-layer refresh if unchanged.

**Warning signs:**
- New `if hasEvents(tag)` branches inside `FastSense.render` line loop
- Event-related code interleaved with line-rendering code
- Render benchmark regression after Phase 4 (events) merge
- Event rendering scaling with `numLines` instead of `numEventsAttached`

**Address in:** Phase 5 (FastSense overlay rendering). Bench before merge: render time with 12 lines, 0 events vs. 12 lines, 100 events per line. The 0-event path must not regress.

---

## Minor Pitfalls

### Pitfall 11: Test Rewrite Without a Stable Golden Integration Test

**What goes wrong:** Each phase rewrites the tests for the components it changes. By Phase 4, the test suite has been ~70% rewritten. A regression introduced in Phase 2 that *only* affects the legacy sensor path doesn't get caught because legacy-path tests were rewritten to the new path in Phase 1 and no longer exercise it. By Phase 5 cleanup, no one is sure whether a behavior change is a bug or an intended evolution.

**Why it happens:** Test rewrites happen alongside production rewrites; tests get treated as documentation for the new code, losing their regression-detection role for behavior.

**Prevention strategy:**
- **Designate one "golden" integration test that does not get rewritten across phases.** Pick (or construct) an end-to-end scenario: load a saved dashboard with sensors + thresholds + composites + events, render it, run a live tick, save it, reload, verify equivalence. This test asserts against *behavior outputs* (final widget statuses, rendered data point counts, event counts) — not internal API shapes.
- The golden test exercises the public API only. It changes only when the public API changes (e.g., `addSensor` → `addTag` rename). Internal refactors must not touch it.
- **Treat unexpected golden-test failures as block-the-merge.** If Phase 3 breaks the golden test, that's evidence the rewrite changed observable behavior — investigate before proceeding.
- Keep at least one **legacy-API smoke test** running until Phase 5. It deletes only when the legacy API itself is removed.

**Warning signs:**
- All tests in a touched file get rewritten in the same commit as the production change
- No single test file has been untouched across multiple phases
- "We don't have a test for this end-to-end scenario" said more than once during phase planning

**Address in:** Phase 0 (write the golden test against the *current* `Sensor`/`Threshold` API before Phase 1 starts). Phase 5 updates it for the public API rename only.

---

### Pitfall 12: Trendminer Feature Creep (D, F, G sneaking into v2.0)

**What goes wrong:** The Tag abstraction is in place by Phase 3. Suddenly "asset hierarchy is just a CompositeTag of CompositeTags, right? Let's add it." Or "calc tags are just a MonitorTag with a formula instead of a threshold; let's add a formula evaluator." Or "monitor templates are just a tag-creation factory; that's small." Each addition is individually small but the milestone slips from `A+B+C+E` to `A+B+C+D+E+F+G` and ships 4 months late.

**Why it happens:** Once you have a clean abstraction, every adjacent feature looks easy. PI AF and Trendminer accumulated their feature surface over 10+ years; trying to match it in one milestone is the trap.

**Real-world precedent:** PI AF best-practice docs explicitly warn about over-templating ("Once the build is started it often becomes clear that the complexities and differences of actual operational assets means that initial assumptions are misguided" — [Tycho Data on PI AF best practices](https://www.tychodata.com/blog/pi-asset-framework-best-practices), [ITI Group on building good asset hierarchies](https://www.itigroup.com/getting-started-with-pi-af-building-good-asset-hierarchies/)). The lesson: asset hierarchies are deceptively easy to *start* and very hard to evolve — defer them until the model has been stress-tested by real use.

**Prevention strategy:**
- **Hard-code the milestone scope into PROJECT.md and reference it in every phase plan.** "Ambitious tier (A + B + C + E only); D, F, G deferred." (Already done — line 51-62 of PROJECT.md. Maintain.)
- **Scope-creep checkpoint at each phase plan-write.** If a plan introduces a feature not on the A/B/C/E list, kick it to v3.0 backlog before writing the plan.
- **Keep a v3.0 backlog file open during v2.0.** When a tempting adjacent feature surfaces, write a one-paragraph backlog entry and move on. The temptation usually dissipates by the next phase.
- **No "while we're here" features.** A phase changes exactly what its goal says it changes.

**Warning signs:**
- Phrases in plans: "while we're at this," "this would be easy to add," "since we have Tag, we might as well..."
- Phase scope expanding by >20% during plan-write
- Backlog file empty (suggests features being silently scoped in instead of deferred)
- Tests added for D/F/G features

**Address in:** Ongoing — every phase plan-write should explicitly check against A/B/C/E scope.

---

## Cross-Cutting Concerns

### Octave compatibility

Every pitfall above must hold under Octave 7+ as well as MATLAB R2020b+ (per project constraints). Specific Octave gotchas:

- `containers.Map` behavior differs slightly between Octave and MATLAB; the existing `WidgetTypeMap_` pattern works but be careful with default-value retrieval. TagRegistry must be tested under Octave from Phase 1.
- `isequal` on handle classes differs (Octave compares contents, MATLAB compares identity by default). Pitfall 4's "EventBinding" registry uses keys (strings), not handle identity, sidestepping this.
- Property validation blocks (R2019b+ `arguments` blocks) are NOT supported in Octave. Stick with `varargin` parsing as the existing codebase does.

### MEX absence

MEX binaries may be absent (Octave on a fresh clone before `install()` runs). Tag's `getTimeSeries` and `CompositeTag` aggregation must work with pure-MATLAB fallbacks (slower but correct). Pitfall 9's "no Tag methods inside MEX wrappers" applies symmetrically to the .m fallback path.

### Test runner duality

The codebase has both function-style Octave tests (`tests/test_*.m`) and class-based suites (`tests/suite/Test*.m`). New Tag tests should follow whichever style the consumer being tested uses; the golden integration test (Pitfall 11) should ideally be runnable in both runners.

---

## Watch Closely During Rewrite

A short list of code-review reflexes to apply at every PR review during v2.0:

1. **"Does Tag have a new abstract method?"** → Pitfall 1. Justify it satisfies all subtypes meaningfully.
2. **"Does this PR persist derived data?"** → Pitfall 2. MonitorTag must stay lazy in v2.0.
3. **"Does this PR materialise a dense N×M matrix?"** → Pitfall 3. Use merge-sort streams.
4. **"Does this PR add a Tag handle to Event or vice versa?"** → Pitfall 4. Use EventBinding registry.
5. **"Does this PR delete legacy code in the same commit as new code?"** → Pitfall 5. Separate phases.
6. **"Does this PR add a new aggregate mode?"** → Pitfall 6. Truth table required.
7. **"Does this PR register a tag without type discrimination?"** → Pitfall 7. Use type-aware registry.
8. **"Does this PR's load order matter?"** → Pitfall 8. Two-pass loader.
9. **"Does this PR add MATLAB code on a MEX hot path?"** → Pitfall 9. Bench it.
10. **"Does this PR add conditionals to FastSense.render line loop?"** → Pitfall 10. Separate render layer.
11. **"Does this PR rewrite the golden integration test?"** → Pitfall 11. Don't.
12. **"Is this feature on the A/B/C/E scope list?"** → Pitfall 12. If no, defer.

---

## Pitfall-to-Phase Mapping

| Pitfall | Primary Phase | Verification |
|---------|---------------|--------------|
| 1. Over-abstracted Tag interface | Phase 1 (Tag base + retrofit) | Tag base class has ≤ 6 abstract methods; no `error('NotApplicable')` in any subclass |
| 2. MonitorTag premature persistence | Phase 2 (MonitorTag) | No `FastSenseDataStore` writes from MonitorTag; lazy compute documented in class header |
| 3. CompositeTag memory blowup | Phase 3 (CompositeTag) | Bench: 8 children × 100k samples, peak memory < 50MB, compute < 200ms |
| 4. Event ↔ Tag cycle | Phase 4 (Events) | `save → clear classes → load` round-trip test passes; no Tag handles inside Event, no Event handles inside Tag |
| 5. Big-bang sequencing | Phase 0 (roadmap) | Phase 1 plan touches ≤ 20 files; legacy `Sensor` API alive through Phase 4 |
| 6. Aggregate semantics drift | Phase 3 (CompositeTag) | Severity enum defined; truth tables documented in class header; `'majority'` rejects multi-state inputs at config time |
| 7. TagRegistry collisions | Phase 1 (TagRegistry) | Type-aware registry decision documented; collision test passes |
| 8. Serialization order | Phase 3 / Phase 4 | Two-pass loader implemented; cycle detection in `addChild`; 3-deep composite-of-composite test passes |
| 9. MEX wrapping cost | Phase 5 (consumer migration) | Live tick benchmark: ≤ 10% regression at 12-widget tick vs. baseline |
| 10. Render-path pollution | Phase 5 (FastSense overlay) | Render bench: 0-event path no regression; event layer scales with `numEventsAttached`, not `numLines` |
| 11. Test rewrite | Phase 0 → ongoing | Golden integration test exists from Phase 0; one untouched test file across all phases |
| 12. Feature creep | Ongoing | Each phase plan checked against A/B/C/E scope at plan-write |

---

## Sources

- [Trendminer Community: Tag does not load after changing interpolation type](https://community.trendminer.com/admin-corner-49/my-tag-does-not-load-anymore-after-changing-the-interpolation-type-in-the-data-source-173) — calculated tag cache invalidation pain
- [Trendminer Tag Builder: Custom Calculations](https://userguide.trendminer.com/2025.R3.0/en/tag-builder--custom-calculations.html) — formula tag architecture
- [Trendminer Community: Tags Indexing/Re-Indexing](https://community.trendminer.com/questions-answers-44/tags-indexing-re-indexing-or-update-414) — re-indexing burden
- [Tycho Data on PI AF Best Practices](https://www.tychodata.com/blog/pi-asset-framework-best-practices) — over-templating, regret-work warning
- [ITI Group: Building Good PI AF Asset Hierarchies](https://www.itigroup.com/getting-started-with-pi-af-building-good-asset-hierarchies/) — hierarchy structure mistakes
- [AVEVA PI AF Asset Hierarchies docs](https://docs.aveva.com/bundle/pi-server-l-af-pse/page/1021106.html) — official AF design guidance
- [AWS CloudWatch Composite Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Create_Composite_Alarm.html) — severity rollup canonical pattern
- [Grafana severity issue #6553](https://github.com/grafana/grafana/issues/6553) — multi-severity alert design discussion
- [Strangler Fig Pattern — Microsoft Azure](https://learn.microsoft.com/en-us/azure/architecture/patterns/strangler-fig) — incremental migration canonical reference
- [Shopify Engineering: Refactoring Legacy Code with Strangler Fig](https://shopify.engineering/refactoring-legacy-code-strangler-fig-pattern) — common mistakes in practice
- [Ghost in the Data: Refactoring Playbook (Mar 2026)](https://ghostinthedata.info/posts/2026/2026-03-28-your-data-model-isnt-broken-part-2/) — domain-model rewrite guidance
- Codebase: `libs/SensorThreshold/CompositeThreshold.m`, `libs/SensorThreshold/Threshold.m`, `libs/EventDetection/Event.m`, `.planning/PROJECT.md`, `.planning/ROADMAP.md` — direct read for current API shape and prior refactor decisions

---
*Pitfalls research for: v2.0 Tag-Based Domain Model — rewriting tightly-coupled sensor/threshold/event subsystem under unified Tag abstraction*
*Researched: 2026-04-16*
*Supersedes earlier v1.0 PITFALLS.md (which addressed dashboard-layout pitfalls, not relevant to v2.0 scope)*
