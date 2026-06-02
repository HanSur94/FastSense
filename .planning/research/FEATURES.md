# Feature Research — v5.0 Multi-Machine Fleet

**Domain:** Multi-asset / fleet monitoring and comparison — MATLAB-based sensor-data dashboard for engineering analysis across a growing fleet of near-identical machines.
**Researched:** 2026-06-02
**Confidence:** HIGH (prior art verified from AVEVA PI Vision, Seeq, Grafana, TrendMiner; codebase context HIGH from PROJECT.md)

---

## Scope Statement

This document covers the FEATURE EXPECTATIONS (behaviors users will look for) across the four v5.0 areas: machine browsing, cross-asset comparison, canonical/logical sensor mapping, and per-asset dashboards. Implementation details are out of scope here — those are resolved in roadmap phases. Every finding is categorized as TABLE STAKES (missing = product feels incomplete), DIFFERENTIATOR (valued but not assumed), or ANTI-FEATURE (explicitly out of scope, with rationale).

**Architecture locked-in decisions that bound feature scope (from PROJECT.md):**
- Machine layer is `Machine` + `Fleet` in `libs/Fleet/`; global `TagRegistry` untouched (backward compat)
- Per-machine dashboards are hand-built and independent (no forced templates); clone/remap is the deployment mechanism
- Comparison view reuses `openAdHocPlot` Overlay mode pulling Tag objects from each machine's catalog
- `DashboardSerializer` gains machine-scoped resolver for `(machineId, localKey)` lookups
- Visualization-only; no control panel, no drag-and-drop, no interactive actuation

---

## Area 1 — Machine/Asset Browsing & Selection at Scale

### Table Stakes

| Feature | Why Expected | Complexity | Dependency Notes |
|---------|--------------|------------|-----------------|
| Free-text search across machine names/IDs | Every fleet tool (PI Vision Switch Asset, Seeq asset tree, Grafana variable dropdown) provides instant search filtering; users with 20+ machines can't scroll a flat list. Wildcard/substring matching is the minimum expectation. | LOW | Requires `Fleet` holding a list of `Machine` objects with searchable metadata (name, id, group). |
| Select one machine as the "active machine" in Companion | The companion's existing three-pane layout (tag catalog / dashboard list / inspector) already scopes to a single machine at a time. Users expect a clear indicator of which machine is currently active — PI Vision calls this "asset context"; Seeq calls it the "selected asset." | LOW | `FastSenseCompanion.setProject(machine.Dashboards, machine)` is the existing seam. |
| Visual indicator of active machine | All industrial tools (PI Vision context bar, Seeq workbench header, Grafana top-of-dashboard variable row) prominently show what asset is currently being viewed. Absence causes "which machine am I looking at?" confusion. | LOW | Companion UI update only; no new data model. |
| Machine list grouped by a user-defined category/group | PI Vision groups by AF element level; Grafana uses chained variables; Seeq uses asset tree folders. Engineers with multi-site fleets naturally group by line, cell, or site. Even a flat list with a category label is sufficient for 20–50 machines. | MEDIUM | `Machine` must carry a `Group` field; `Fleet` must support group-filtered queries. |
| Loading a machine's dashboards and tag catalog on selection | Seeq and PI Vision both load the context-relevant signals and dashboards when an asset is selected. The companion already does this via `setProject`; the expectation is that it works for any machine in the fleet, not just a hardcoded set. | LOW | Core of the `Machine` model; existing `setProject` seam accommodates this. |

### Differentiators

| Feature | Value Proposition | Complexity | Dependency Notes |
|---------|-------------------|------------|-----------------|
| "Recent machines" list (last N selected) | Reduces navigation friction for analysts who rotate between 3–5 machines routinely. Present in file-manager conventions everywhere; not always present in industrial tools at this granularity. | LOW | Small persistence layer (prefs or companion state); no data model change. |
| Machine health/status badge in the list | Showing a green/amber/red indicator next to each machine in the selector (derived from active MonitorTag violations) helps triage which machine to investigate next. Not just browsing — it surfaces urgency. | HIGH | Requires cross-machine event rollup per machine, which touches the `Fleet` model and per-machine `EventStore` reads. Depends on fleet-wide background monitoring (deferred to later milestone per PROJECT.md). Flag: do NOT block machine selector on this. |
| Filter by group + search simultaneously | Combining text search with group filter (e.g., "Line A" + "pump") is more useful than either alone for 50+ machine fleets. Grafana supports chained variables for exactly this. | LOW-MEDIUM | `Fleet` query API needs `filterByGroup(group)` + `filterByName(pattern)` composable. |
| Pin/star specific machines | Users frequently return to the same 3–5 machines; starring them surfaces them at the top of the selector. Common in developer tools, less common in industrial historians but immediately intuitive. | LOW | UI preference only; no data-model change. |

### Anti-Features

| Feature | Why Avoid | Alternative |
|----------|-----------|-------------|
| Full asset hierarchy tree (multi-level AF-style tree with expand/collapse nodes) | PI AF trees are powerful but require dedicated tree-browsing UI, AF server integration, and significant complexity for 20-50 flat-fleet use cases. The FastSense Companion is a MATLAB uifigure — a proper tree widget (uitree) exists but adds drag-and-drop + expand/collapse complexity that is out of scope. The fleet is near-identical and flat, not a deep hierarchy. | Flat searchable list with a single group/category field. This scales to hundreds of machines and is idiomatic for engineering scripts. |
| Automatic machine discovery from filesystem | Scanning a data root directory to auto-register new machines couples Fleet to a specific folder convention; breaks for remote paths, mapped drives, and non-standard layouts. PI Vision/Seeq both require explicit asset registration. | Explicit `Fleet.addMachine(...)` call in user setup scripts; machine list is user-managed. |
| Live telemetry "is machine online" presence indicator | Requires a ping/health check mechanism to each machine's DataRoot, creating timing and network assumptions that don't fit a pure MATLAB file-based model. Out of scope per PROJECT.md (WebBridge parity deferred). | Stale/fresh data timestamp on last ingestion run (LOW complexity) is a deferred differentiator, not a live ping. |
| Drag-and-drop machine reordering | DashboardEngine is visualization, not a control panel. User ordering is controlled by script/config, not drag-and-drop. | Named groups + alphabetic sort within group. |

---

## Area 2 — Cross-Asset Comparison of the Same Measurement

### Table Stakes

| Feature | Why Expected | Complexity | Dependency Notes |
|---------|--------------|------------|-----------------|
| Overlay N machines' same logical sensor on one FastSense axes | This is the core comparison value. PI Vision overlay trend, Seeq Compare View, Grafana multi-value variable panels, TrendMiner layer comparison — all converge on this primitive. Expected behavior: pick a logical sensor name → one FastSense axes with one series per machine, auto-colored, legendized. | MEDIUM | Requires canonical map to resolve logical name → per-machine Tag key. Depends on Area 3 mapping layer. |
| Per-machine color assignment (distinct, auto-assigned) | Every tool assigns a distinct color per asset when overlaying. Users expect to distinguish "Machine 01 (blue)" from "Machine 03 (orange)" in the legend. Grafana's lack of consistent color auto-assignment across panels is a documented pain point — FastSense should solve this explicitly. | LOW | `openAdHocPlot` Overlay mode already color-cycles; need to propagate machine label into legend. |
| Legend showing machine name or ID (not just sensor key) | When 5 machines' temperature series are overlaid, the legend must say "M01 / M03 / M07" not "temperature_channel_1 / temperature_channel_1 / temperature_channel_1." All industrial tools do this. | LOW | Legend label = `[machineName]: [sensorDisplayName]` concatenation in the addTag/addLine call. |
| Same-time (wall-clock) overlay as the primary alignment | Absolute timestamp alignment is the default in all time-series tools and expected for: "what happened to all machines on Tuesday at 14:00?" Seeq Compare View uses normalized time — but that is a specialized mode, not the default. PI Vision overlay trend uses wall-clock by default. | LOW | This is already how `openAdHocPlot` Overlay mode works; no change needed. |
| Handle "sensor missing on some machines" gracefully | Not all machines in a fleet have identical sensor coverage. Seeq's `spy.swap` documents this explicitly: if `Area F does not include a Temperature signal, spy.swap() reports failure for that asset.` PI Vision's element-relative displays similarly silently omit missing attributes. Users expect: machines with the sensor show up; machines without it are skipped (with a warning, not a crash). | LOW-MEDIUM | Comparison view must iterate machine.getTag(localKey) with try/catch or a `hasTag(key)` guard; skip + warn for missing. |
| Select machines for comparison (multi-select from the fleet) | The companion must let the user pick which subset of machines to include in a comparison, not force "all machines." Grafana multi-value variable, PI Vision Switch Asset list, Seeq workbench signal selection all require explicit multi-select. | MEDIUM | UI component in comparison initiation flow; `Fleet.getMachines(subset)` query needed. |

### Differentiators

| Feature | Value Proposition | Complexity | Dependency Notes |
|---------|-------------------|------------|-----------------|
| Normalized-time (batch-start-aligned) overlay | Seeq Compare View's primary mode is time-normalized relative to capsule/batch start, enabling "how does each machine's temperature curve evolve through its cycle?" This is powerful for batch processes but requires a batch/event anchor. FastSense already has event markers — a batch-start event could be the alignment anchor. | HIGH | Requires: (a) a per-machine batch-start event concept, (b) re-indexing time arrays relative to that anchor. Defer unless batch processes are confirmed in target user workflow. |
| Show per-machine min/max envelope band on overlay | When comparing 10+ machines, individual traces become cluttered. Showing a min/max band + median trace is a fleet-scale pattern (industrial IoT research papers, GE Proficy fleet analytics). More informative than 10 overlapping lines. | HIGH | Requires statistical aggregation across Tag arrays; significant new computation not in existing FastSense primitives. Defer to v5.x. |
| Comparison initiated from a context menu on a logical sensor | Instead of a separate "compare" mode, right-clicking (or a button action) on a logical sensor in the tag catalog opens the comparison view pre-populated with that sensor. Intuitive UX flow consistent with how FastSenseCompanion already opens ad-hoc plots from tag selection. | LOW | Wiring change only in companion event handling; the comparison view logic is independent. |
| Save a comparison configuration (N machines + logical sensor) as a named preset | Analysts often run the same comparison repeatedly. Allowing them to save `{logicalSensor, machineSubset}` as a named preset reduces repetition. | MEDIUM | Small serialization; no new data model complexity. |

### Anti-Features

| Feature | Why Avoid | Alternative |
|----------|-----------|-------------|
| Cross-machine MonitorTag/event rollup in the comparison view | Rolling up violations across N machines in real-time requires cross-machine event queries and fleet-wide monitoring infrastructure, which PROJECT.md explicitly defers to after v5.0. | Per-machine event overlays in individual machine dashboards remain independent. Cross-machine rollup is a future milestone. |
| Interactive cross-widget filtering (click one machine in comparison → filter other panels) | FastSense Companion is visualization-only; cross-widget filtering requires a coordination bus and event propagation across DashboardEngine instances. Explicitly out of scope per PROJECT.md. | Use comparison view as a standalone overlay window; users manually open per-machine dashboards for drill-down. |
| Animated "race" timeline where machines' series step forward in sync | Purely visual novelty; creates playback/timer infrastructure that conflicts with the static-analysis-first design. | Side-by-side overlay with synchronized x-axis zoom is sufficient for analytical comparison. |
| Statistical aggregation (mean/std/percentile across fleet) as a widget type | Compelling for fleet health monitoring but requires a new compute layer above individual Tag reads. Scope creep for v5.0. | Single-machine NumberWidget/GaugeWidget per machine in per-machine dashboards. Fleet aggregation is a future differentiator. |

---

## Area 3 — Canonical/Logical Sensor Mapping & Asset Templates

### Table Stakes

| Feature | Why Expected | Complexity | Dependency Notes |
|---------|--------------|------------|-----------------|
| A canonical map: `logical_name → {machine_id → local_key}` | Every fleet tool that enables cross-asset comparison requires this layer. PI AF element templates use substitution parameters (e.g., `%..\Element%.%Attribute%.PV`). Seeq `spy.swap` requires identically-named signals — or a manual swap group mapping. This is the foundational data structure for all comparison features. | MEDIUM | The `Machine` model must expose `getTag(localKey)` and the canonical map must live in `Fleet` (or a new `CanonicalMap` class). |
| Auto-suggest canonical mappings from key similarity across machines | PI AF uses naming conventions + substitution patterns. Tag mapping patents (US10460240) describe normalizing tag descriptions and computing similarity scores. For near-identical machines, most sensors share a common stem; auto-suggest surfaces likely matches (e.g., `temp_ch1` on M01 ↔ `temp_sensor_1` on M02) for user confirmation. Without this, users must manually map 50+ sensors per machine. | MEDIUM | Requires string similarity heuristic (edit distance or regex-based stem extraction); no ML needed; pure MATLAB. |
| Manual override for any mapping | Auto-suggest will be wrong for edge cases. PI AF allows per-element attribute override of the template default. Seeq `spy.swap` requires explicit swap group specification when auto-match fails. Manual override is TABLE STAKES — the analyst must always have final say. | LOW | A `CanonicalMap.setOverride(logicalName, machineId, localKey)` API; persisted in `Fleet` config. |
| Surface unmapped / ambiguous-tail sensors | After auto-mapping, some sensors will remain unmapped (absent on some machines) or ambiguous (two candidate local keys match the same logical name). This "unmapped tail" must be visible to the user — not silently discarded. PI Vision's element-relative displays show empty/broken attribute cells for missing tags. Seeq's asset tree shows signal gaps. | LOW-MEDIUM | A `CanonicalMap.getUnmapped(machineId)` and `getAmbiguous(logicalName)` query API; surfaced in a companion view. |
| Persist the canonical map across sessions | The map is built once (with user confirmation/overrides) and reused. PI AF templates persist to the AF server. Seeq asset groups persist to workbench. In FastSense's file-based model, the canonical map must serialize to JSON/mat alongside `Fleet` config. | LOW | `Fleet.save(path)` / `Fleet.load(path)` already planned; canonical map is a sub-struct of fleet config. |

### Differentiators

| Feature | Value Proposition | Complexity | Dependency Notes |
|---------|-------------------|------------|-----------------|
| Interactive mapping review UI in companion | A pane (or modal) that shows the full canonical map — logical name, per-machine local key, status (auto-matched / manual override / unmapped) — so analysts can review and edit. TrendMiner allows duplicating searches and remapping variables. PI Vision's Configure Context Switching panel is a lightweight precedent. | MEDIUM | New companion pane or dialog; reads/writes `CanonicalMap`; relies on `Fleet` and per-machine tag catalogs. |
| Regex-based batch rule for naming conventions | For machines that follow a convention like `M{id}_temp_*`, a single rule `M*_temp_(\w+) → temperature_\1` maps all temperature sensors in one line. PI AF substitution parameters do this implicitly via `%Element%` tokens. Reduces setup time from O(N * M) to O(rules). | MEDIUM | Rule engine in `CanonicalMap` with pattern-match + capture-group substitution; pure MATLAB string ops. |
| Re-run auto-suggest incrementally as new machines are added | When a new machine is added to the fleet, the canonical map should automatically propose mappings for it without invalidating existing confirmed mappings. This is the "growing fleet" use case in PROJECT.md. | LOW-MEDIUM | `CanonicalMap.addMachine(machine)` triggers partial re-suggest limited to the new machine's unmapped keys. |
| Export canonical map as a MATLAB script | Consistent with DashboardSerializer's `.m` export philosophy — the canonical map can be exported as a script so engineers can version-control and review it as code. | LOW | Template: `map.setOverride('temperature', 'M01', 'temp_ch1'); ...` — mechanically generated. |

### Anti-Features

| Feature | Why Avoid | Alternative |
|----------|-----------|-------------|
| Forced identical tag keys across machines (global namespace namespace shim) | PROJECT.md explicitly rejected Approach ② (namespaced compound keys in the global registry) for key-sprawl and forced per-machine filtering at every call site (72 static call sites). | Per-machine isolated `containers.Map` + canonical map bridge. |
| ML-based semantic tag matching (embedding similarity, LLM tag description matching) | Adds Python/external-service dependency; breaks the "pure MATLAB, no external dependencies" constraint. Overkill for near-identical machines with predictable naming conventions. | String similarity (edit distance, common-stem extraction) is sufficient and stays within MATLAB. |
| Automatic application of canonical map without user review | Auto-suggest is valuable; auto-applying without surfacing conflicts would silently produce wrong comparisons. Seeq requires user confirmation for asset swaps; PI AF requires template instantiation. | Show suggestions + require accept/override before a mapping is active in comparisons. |
| Per-logical-sensor unit normalization/conversion | Unit conversion (psi ↔ bar, °C ↔ °F) across machines is a data transformation concern outside the visualization scope. FastSense renders what Tags provide; normalizing units is the pipeline responsibility. | Document as user responsibility in setup scripts; flag as a pitfall in PITFALLS.md. |

---

## Area 4 — Per-Asset Dashboards (Independent + Clone/Remap)

### Table Stakes

| Feature | Why Expected | Complexity | Dependency Notes |
|---------|--------------|------------|-----------------|
| Each machine holds its own independent set of dashboards | PROJECT.md locked this decision: hand-built, independent per-machine dashboards. This is the validated engineering-team pattern: each machine may have different sensors warranting a custom layout. Forcing templates breaks this. The expectation from engineers who build their own dashboards is that they have full autonomy over layout, widget types, and sensor bindings per machine. | LOW | `Machine.Dashboards` is a `{DashboardEngine}` cell array; already in the v5.0 spec. |
| Clone a dashboard onto another machine with tag bindings rebound | Adobe Commerce, Datadog, and Seeq all describe cloning dashboards with remapped data bindings as a standard workflow: "clone to get the same layout, then fix the data sources." For near-identical machines, this is the deployment pattern: build once on M01, clone to M02–M20 with bindings rebound via the canonical map. | MEDIUM | `DashboardSerializer.toStruct(engine)` + `DashboardSerializer.fromStruct(s, machine)` where `fromStruct` resolves tag keys via `fleet.resolve(machineId, localKey)` instead of `TagRegistry.get(key)`. Already identified in PROJECT.md as the one existing seam. |
| Machine-scoped tag resolution in DashboardSerializer | When saving/loading a machine's dashboard, widget tag bindings must resolve to that machine's local tag keys — not the global TagRegistry. Without this, deserializing a machine's dashboard on a different machine would silently bind to wrong (or non-existent) tags. This is the core correctness requirement for fleet deployment. | MEDIUM | `DashboardSerializer` gains a machine-scoped resolver path as identified in PROJECT.md Key Decisions. |
| Per-machine dashboard save/load round-trip | DashboardSerializer already supports JSON and `.m` export. Machine-scoped dashboards must round-trip correctly — loaded from disk, bindings resolve to the correct machine's tags, and serialization re-emits the correct machine-qualified key. | LOW-MEDIUM | Extension of existing serialization; the scoped resolver is the new piece. Existing `toStruct/fromStruct` infrastructure is the foundation. |

### Differentiators

| Feature | Value Proposition | Complexity | Dependency Notes |
|---------|-------------------|------------|-----------------|
| Preview of unresolvable tag bindings before clone completes | When cloning M01's dashboard onto M03, some of M01's tag keys may not map to M03 via the canonical map. Seeq's spy.swap reports this in a `Result` column. A clone UX that shows "3 bindings cannot be resolved — here are the gaps" before writing the clone gives analysts an actionable checklist rather than a broken dashboard. | MEDIUM | Requires a dry-run mode in `DashboardSerializer.fromStruct` that returns a resolution report without materializing the engine. |
| Batch clone: apply one source dashboard to all (or selected) machines | For a fleet of 20+ machines, cloning one at a time is tedious. A `Fleet.cloneDashboard(sourceEngine, sourceMachine, targetMachines)` function that runs the clone/remap loop is a significant time-saver. | MEDIUM | Wraps the single-machine clone operation in a loop; depends on canonical map being confirmed for all target machines. |
| Export a machine's dashboard suite as a standalone `.m` script | Consistent with existing DashboardSerializer `.m` export; allows version-controlling per-machine dashboards in a Git repo and re-running them from scratch on any machine in the fleet. | LOW | Extension of existing `exportScript` path with machine-scoped resolver; follows the established DashboardSerializer pattern from v2.1. |
| Show which dashboards are "out of sync" with the canonical template | If M01's dashboard was updated (new widget added) but M03–M20's clones were not updated, showing a stale/fresh indicator per machine-dashboard lets analysts prioritize re-cloning. Analogous to how AF template updates propagate to element instances in PI Vision. | HIGH | Requires comparing dashboard struct checksums across machines, plus a definition of what "template version" means for an independent-dashboard model. Likely too complex for v5.0. Defer. |

### Anti-Features (Consistent With "Independent Dashboard" Decision)

| Feature | Why Avoid | Alternative |
|----------|-----------|-------------|
| Forced template propagation (edit one template → auto-updates all machines) | PROJECT.md explicitly out-of-scoped this: user chose hand-built independent dashboards. PI AF template propagation ("update template → immediately reflects in all instances") only works when all instances are structural copies of the same template. FastSense machines can have legitimately different widgets. | Clone/remap on demand; no auto-propagation. Users control when to re-clone. |
| Lock machine dashboards to prevent independent customization | Locking defeats the purpose of hand-built per-machine dashboards. Engineers need to add machine-specific widgets (a sensor that only exists on M07, for example). | All dashboards remain independently editable; no locking mechanism. |
| Cross-machine widget linking (clicking a widget on M01's dashboard highlights M03's) | This is cross-widget filtering, explicitly out of scope per PROJECT.md for all milestones. Adds coordination bus complexity. | Open comparison view for side-by-side; each machine's dashboard remains independent. |
| Automatic dashboard generation from canonical map (no hand-building) | If the canonical map defines all logical sensors, one could auto-generate a generic dashboard from it. But auto-generated dashboards lose the domain-specific layout choices (which sensors go on which page, thresholds, color choices) that make per-machine dashboards valuable. | Hand-build or clone/customize; auto-generation is a future low-priority differentiator, not a v5.0 goal. |

---

## Feature Dependencies

```
[Canonical Map — Area 3]
    └──required by──> [Cross-asset comparison — Area 2]
                          └──required by──> [Comparison view overlay with logical sensor name]
    └──required by──> [Clone/remap dashboard — Area 4]
                          └──required by──> [Machine-scoped DashboardSerializer resolver]

[Machine/Fleet data model]
    └──required by──> [All 4 areas]
    └──enables──> [Machine selector in companion — Area 1]
    └──enables──> [Per-machine tag catalog — Area 2 & 3]
    └──enables──> [Per-machine dashboards — Area 4]

[Area 1 — Machine selector]
    └──prerequisite for──> [Area 2 comparison view] (must select machines before comparing)
    └──prerequisite for──> [Area 4 per-machine dashboard browsing]

[Area 3 — Canonical map (auto-suggest)]
    └──enhances──> [Area 3 — Manual override] (override fills gaps auto-suggest misses)
    └──enhances──> [Area 4 — Clone/remap preview] (dry-run uses same resolution logic)

[Machine health badge — Area 1 differentiator]
    └──depends on──> [Fleet-wide background monitoring — DEFERRED to future milestone]
    !!DO NOT BLOCK machine selector on this!!
```

### Dependency Notes

- **Canonical map is the foundational dependency.** Areas 2 and 4 both require it. The canonical map must be built (even partially) before comparison or clone/remap is usable.
- **Machine/Fleet model must precede everything.** All four areas build on `Machine` + `Fleet` being instantiable with per-machine tag catalogs.
- **Area 1 is the entry point.** Users must be able to browse and select a machine before they can do anything with it. Machine selector is Phase 1 material.
- **Area 3 auto-suggest can be iterative.** Users can start with manual mapping for a small subset; auto-suggest makes it scale to 20+ machines.
- **Health badges in Area 1 are explicitly deferred** pending fleet-wide background monitoring (a later milestone). Do not let this block the machine selector shipping.
- **Clone/remap dry-run preview (Area 4 differentiator) depends on the canonical map being confirmed** — it is a post-map feature, not a Phase 1 requirement.

---

## MVP Definition (v5.0)

### Launch With (Core Fleet Support)

- [x] Machine/Fleet data model (`Machine` + `Fleet` in `libs/Fleet/`) — all other features depend on this
- [x] Machine selector in companion: searchable flat list, one-machine-at-a-time active context — users cannot do anything without this
- [x] `Machine.getTag(localKey)` catalog — per-machine tag isolation, backward-compatible with global registry
- [x] Canonical map data structure + manual override API — foundational for comparison and clone/remap
- [x] Auto-suggest canonical mappings from key similarity — required to make the canonical map tractable for 20+ machines
- [x] Unmapped/ambiguous-tail surfacing — without this, silent gaps create wrong comparisons
- [x] Cross-machine comparison view: pick logical sensor → overlay N machines, auto-color + machine-labeled legend, skip missing gracefully
- [x] Machine-scoped DashboardSerializer resolver — required for clone/remap correctness
- [x] Clone a dashboard onto another machine with canonical-map rebinding — the primary fleet deployment workflow

### Add After Validation (v5.x)

- [ ] Recent machines list — quality-of-life; add once basic browsing is proven
- [ ] Group + text filter combination — add when fleet size grows beyond ~30 machines in practice
- [ ] Batch clone (one source → N targets) — add once single-clone is proven stable
- [ ] Clone dry-run preview (unresolvable bindings report) — add once clone is used enough to expose edge cases
- [ ] Pin/star machines — add once usage patterns emerge
- [ ] Regex batch-rule for canonical mapping — add once manual+auto workflow is understood by users
- [ ] Export canonical map as `.m` script — low-risk addition whenever serialization is reviewed

### Future Consideration (v5.x or later)

- [ ] Normalized-time (batch-aligned) comparison overlay — requires batch event infrastructure
- [ ] Machine health badge in selector — requires fleet-wide monitoring milestone
- [ ] Interactive mapping review pane — complex UI; useful but not blocking
- [ ] Statistical fleet envelope (min/max band) in comparison — requires new aggregation compute layer
- [ ] "Out of sync" dashboard staleness indicator — high complexity; deferred

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Machine/Fleet data model | HIGH | MEDIUM | P1 |
| Machine selector (search + active context) | HIGH | LOW | P1 |
| Canonical map (manual + auto-suggest) | HIGH | MEDIUM | P1 |
| Cross-machine comparison overlay | HIGH | MEDIUM | P1 |
| Clone/remap dashboard | HIGH | MEDIUM | P1 |
| Machine-scoped DashboardSerializer | HIGH | LOW-MEDIUM | P1 |
| Unmapped/ambiguous tail surfacing | HIGH | LOW | P1 |
| Recent machines / pin | MEDIUM | LOW | P2 |
| Group + text filter combo | MEDIUM | LOW | P2 |
| Batch clone | MEDIUM | LOW-MEDIUM | P2 |
| Clone dry-run preview | MEDIUM | MEDIUM | P2 |
| Regex batch mapping rules | MEDIUM | MEDIUM | P2 |
| Normalized-time comparison | LOW-MEDIUM | HIGH | P3 |
| Fleet health badge | MEDIUM | HIGH | P3 |
| Statistical envelope overlay | MEDIUM | HIGH | P3 |

---

## Prior Art Summary

| Tool | Key Lessons for v5.0 |
|------|----------------------|
| **AVEVA PI Vision + PI AF** | Element templates + substitution parameters = canonical map model. "Switch Asset" panel = machine selector with wildcard search and hierarchy filter. Context switching = single-dropdown replaces entire display. Override per-element attribute = manual mapping override. At 50,000+ assets: flat list + search scales better than tree browsing for fast context switching. |
| **Seeq Asset Groups + spy.swap** | Exact-name matching is the simplest canonical map; auto-suggest fills the gap when names differ. Missing signal → per-asset failure report (not silent skip, not crash). Asset swap = rebinding an analysis from one asset to another using matching signal names. |
| **Seeq Compare View** | Normalized-time overlay is powerful for batch processes but is a specialized mode, not the default. Default = wall-clock overlay. |
| **Grafana template variables** | Multi-value variable = select N machines → N series on one panel. Auto-color across series is a known pain point (inconsistent unless manually pinned). Dashboard repeat panels = per-machine panel rows. Variable chaining = group + machine two-level filter. |
| **TrendMiner layer comparison** | Statistical comparison (KS test, Pearson correlation, relative difference) is a differentiator for batch engineers; not table stakes for general sensor monitoring. |
| **GE Proficy Knowledge Center** | Fleet-level asset-centric views for plant-of-plants rollups = future milestone (not v5.0). |

---

## Sources

- [AVEVA PI Vision Documentation — PI AF Blog](https://www.aveva.com/en/perspectives/blog/easy-as-pi-asset-framework/)
- [PI Vision Architecture](https://docs.aveva.com/bundle/pi-vision/page/1009400.html)
- [PI Vision Switch Asset community thread — PI Square](https://pisquare.osisoft.com/s/question/0D51I00004UHnHzSAL/asset-context-switching-in-pi-vision-2017r2)
- [PI Vision Swap Related Assets — YouTube tutorial reference](https://www.youtube.com/watch?v=SIxUbTPZWtU)
- [Seeq Compare View documentation — R65](https://support.seeq.com/kb/R65/cloud/compare-view)
- [Seeq spy.swap documentation — Python module user guide](https://python-docs.seeq.com/user_guide/spy.swap.html)
- [Seeq Asset Groups — knowledge base](https://support.seeq.com/kb/R58/cloud/asset-groups)
- [Grafana variables — dynamic dashboards blog 2024](https://grafana.com/blog/2024/10/30/grafana-variables-what-they-are-and-how-they-create-dynamic-dashboards/)
- [Grafana Node / Fleet Overview dashboard](https://grafana.com/grafana/dashboards/22269-node-fleet-overview/)
- [Grafana repeat panels tutorial](https://grafana.com/blog/2020/06/09/learn-grafana-how-to-automatically-repeat-rows-and-panels-in-dynamic-dashboards/)
- [TrendMiner layer comparison — User Guide 2025.R1](https://userguide.trendminer.com/2025.R1.0/en/layer-comparison.html)
- [PI AF tag naming patterns — PISharp](https://www.pisharp.com/article/202/building-flexible-pi-af-templates-with-variable-tagname-patterns) (returned 403; content reconstructed from search summaries)
- [AVEVA PI Vision 2024 Release Notes](https://docs.aveva.com/bundle/pi-vision/page/1254880.html)
- [Tag Mapping for Industrial Machines — USPTO patent US10460240](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10460240)

---

*Feature research for: Multi-asset fleet monitoring + comparison — MATLAB sensor data dashboard*
*Researched: 2026-06-02*
