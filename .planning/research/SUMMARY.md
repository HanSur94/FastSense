# Project Research Summary

**Project:** FastSense Advanced Dashboard — v5.0 Multi-Machine Fleet
**Domain:** Multi-asset fleet monitoring, canonical sensor mapping, and cross-machine comparison — pure MATLAB sensor dashboard
**Researched:** 2026-06-02
**Confidence:** HIGH

---

## Executive Summary

v5.0 adds a fleet layer — `Machine`, `Fleet`, and `CanonicalMapper` in a new `libs/Fleet/` library — on top of a production-grade MATLAB dashboard engine that has zero external dependencies and must remain backward-compatible with 72 static `TagRegistry` call sites across 31 files. The core architectural decision is already locked: each `Machine` owns an isolated `containers.Map` tag catalog and never touches the global `TagRegistry` singleton. The fleet layer is purely additive: no existing single-machine code path changes except five precisely-identified call sites in `TagCatalogPane`, `FastSenseCompanion`, `FastSenseWidget.fromStruct`, and the multi-page load path in `DashboardEngine`.

The recommended approach follows a strict build order: `CanonicalMapper` first (no dependencies, validates the mapping logic in isolation), then `Machine` + pipeline DI seam, then `Fleet` + config persistence, then the `DashboardSerializer` resolver seam (independently testable), and finally the Companion machine-dimension wiring. Every phase is independently deployable and has a concrete exit gate. The single biggest implementation risk is the resolver seam: the existing `DashboardSerializer.configToWidgets` resolver hook covers only the legacy `source.type='sensor'` path; the `source.type='tag'` path in `FastSenseWidget.fromStruct:1516` bypasses it entirely, and the multi-page load path at `DashboardEngine.m:4384` drops the resolver silently. This must be fixed in isolation (Phase 4) with a backward-compat regression test before any fleet dashboard is serialized.

The second highest risk is canonical mapping correctness: fuzzy matching that silently maps physically-different sensors produces wrong comparisons with no error signal. The mitigation is mandatory `confidence` levels (HIGH/MEDIUM/LOW) baked into the mapper schema from day one, a comparison-view gate that refuses to overlay LOW/unreviewed mappings, and a unit-consistency check. All string operations must use `lower`/`regexprep`/`strsplit`/`strfind` (never `contains` or toolbox functions) to maintain Octave parity in the data model. The companion UI is MATLAB-only and guarded by an existing Octave check — no new Octave guard needed there.

---

## Key Findings

### Recommended Stack

All functionality is covered by built-in MATLAB/Octave primitives already used in this codebase. No new dependencies. The "DO NOT ADD" list is firm: no Statistics Toolbox `editDistance`, no Text Analytics Toolbox, no `contains()` in Octave-targeted data-model code, no `jsonencode` called directly on cell-array-of-heterogeneous-structs, and no `dir('**/*.ext')` recursive glob in Octave-targeted code.

**Core technologies:**

- `lower` / `regexprep` / `strsplit` / `strtrim` / `strfind` — key normalization pipeline for `CanonicalMapper`; all present identically on R2020b+ and Octave 7+; already used in `filterTags.m` and `filterDashboards.m`
- Hand-rolled Wagner-Fischer edit distance (`editDistance_` private helper, ~20 LOC) — approximate token matching for auto-rule scoring; call count is at most `n_keys x n_canonical_ids` at config-load time (200 x 50 = 10,000 pairs, < 1 ms); no toolbox required
- `jsonencode` / `jsondecode` + `strjoin(parts, ',')` for heterogeneous arrays — fleet config persistence (machine list, DataRoot, canonical overrides); already used throughout codebase for project artifacts (`DashboardSerializer.saveJSON/loadJSON`, `ndjsonEncode/Decode`); fleet config is a project artifact (human-readable, VCS-committable) so `.mat` is wrong here
- `uilistbox` + `uieditfield` with 150 ms debounce timer — machine selector in Companion; exact pattern already live in `TagCatalogPane` (uilistbox with `Multiselect='on'`, `Items`/`ItemsData`) and `DashboardListPane`; copy verbatim
- `dir(fullfile(root, '*.ext'))` with an explicit recursive helper (not `**` glob) — per-machine `DataRoot` file discovery; `**` is unsupported in Octave 7; iterative `dir` + `isdir` loop is already the codebase pattern
- `containers.Map('KeyType','char','ValueType','any')` — per-machine tag catalog in `Machine.Tags_`; mirrors `TagRegistry` internal structure; same form required for Octave
- `movefile(tmp, dest, 'f')` atomic-write pattern — safe fleet config save; already in `companionPrefs.m` and `EventStore.save()`

### Expected Features

All prior-art tools (AVEVA PI Vision, Seeq, Grafana, TrendMiner) converge on the same feature set for fleet comparison. The canonical map is the gating dependency for Areas 2 and 4; nothing in comparison or clone/remap is usable without it.

**Must have (table stakes):**

- Free-text search across machine names/IDs — every fleet tool requires this; `Fleet` must support `filterByName(pattern)` returning a machine subset
- Active-machine indicator in Companion — users need to know which machine context is current; "which machine am I looking at?" confusion is the documented pain point across all industrial tools
- `Machine.getTag(localKey)` per-machine tag catalog isolation — the core invariant; machine tags never enter the global `TagRegistry`
- Canonical map: `logicalId -> {machineId -> localKey}` — foundational for all comparison and clone/remap; auto-suggest from key similarity + manual override; unmapped/ambiguous-tail surfacing
- Mandatory confidence levels (HIGH/MEDIUM/LOW) on every mapping entry — silent wrong comparisons are the most dangerous failure mode
- Cross-machine comparison overlay: pick logical sensor -> one FastSense axes, one series per machine, auto-colored, machine-labeled legend (format: `[machineName]: [sensorDisplayName]`), wall-clock alignment (default), missing-sensor graceful skip with warning
- Machine-scoped `DashboardSerializer` resolver — correctness requirement for fleet dashboard round-trips
- Clone a dashboard onto another machine with tag bindings rebound via canonical map; failed remaps surfaced as a warnings list, not silent empty widgets

**Should have (differentiators):**

- Machine list grouped by user-defined category/group — `Machine.Group` field + `Fleet.filterByGroup(group)` composable with text search
- Recent machines list — reduces navigation friction for analysts rotating between 3-5 machines
- Clone dry-run preview — shows unresolvable bindings before clone completes; depends on canonical map being confirmed
- Regex batch mapping rules for naming conventions — reduces setup from O(N x M) to O(rules)
- Interactive mapping review pane in companion — full canonical map table (logical name / per-machine local key / status / confidence) with edit capability

**Defer to v5.x:**

- Machine health/status badge (green/amber/red) — requires fleet-wide background monitoring milestone; do NOT block machine selector on this
- Batch clone (one source -> N targets) — add once single-clone is proven stable
- Normalized-time (batch-aligned) comparison overlay — requires batch event infrastructure
- Statistical fleet envelope (min/max band) — requires new aggregation compute layer
- "Out of sync" dashboard staleness indicator — high complexity; not v5.0

**Anti-features (explicitly out of scope):**

- Full AF-style asset hierarchy tree — flat searchable list + one `Group` field is sufficient for 20-50 machines
- Automatic machine discovery from filesystem — explicit `Fleet.addMachine(...)` in user scripts is the correct pattern
- `TagRegistry` refactored to be instantiable — 72 static call sites across 31 files; rejected
- Namespaced compound keys in global registry — key-sprawl and forced per-machine filtering everywhere; rejected
- ML-based semantic tag matching — breaks no-external-dependency constraint; edit distance + regex is sufficient

### Architecture Approach

The v5.0 architecture is a pure addition layer: `libs/Fleet/` (`Machine`, `Fleet`, `CanonicalMapper`) sits above the existing `SensorThreshold` / `Dashboard` / `FastSenseCompanion` stack and communicates downward through five concrete seams identified by code audit at commit HEAD. All other existing code paths are unchanged. The key structural decision is that `Machine` owns its own `containers.Map` and exposes the same read API as `TagRegistry` (`get`, `find`, `findByKind`, `findByLabel`, `keys`), so existing panes can be retargeted to a machine by changing four static `TagRegistry.find` call sites to call the `Registry_` object reference already stored in each pane.

**Major components:**

1. `libs/Fleet/CanonicalMapper.m` (NEW) — normalization pipeline, hand-rolled Wagner-Fischer edit distance, confidence-level tagging, manual override `containers.Map`, unit-consistency check, `reviewPending()` / `unmapped(machineId)` query API
2. `libs/Fleet/Machine.m` (NEW) — `containers.Map`-backed tag catalog; duck-type methods `get(key)`, `find(predFn)`, `findByKind`, `findByLabel`, `keys`; `DataRoot`, `Dashboards`, `EventStore`; `ingestBatch()` / `startLive()` wrappers using `tagSource_` DI; lazy metadata vs. data loading; NEVER calls `TagRegistry.register`
3. `libs/Fleet/Fleet.m` (NEW) — searchable machine list; `filterByName`/`filterByGroup` composable query API; `resolveLogical(logicalId)` -> CanonicalMapper -> `{machine, Tag}` pairs; `save(path)` / `load(path)` with `fleetConfigVersion`; owns `CanonicalMapper`
4. `libs/Dashboard/{FastSenseWidget, DashboardSerializer, DashboardEngine}.m` (MODIFIED) — optional `tagResolver` function handle threaded from `DashboardEngine.load()` -> `DashboardSerializer.configToWidgets()` -> `DashboardSerializer.createWidgetFromStruct()` -> `FastSenseWidget.fromStruct()`; resolver signature `@(localKey) machine.get(localKey)`; fallback to `TagRegistry.get` when resolver absent (backward compat)
5. `libs/FastSenseCompanion/{FastSenseCompanion, TagCatalogPane}.m` + `private/openAdHocPlot.m` (MODIFIED) — four static `TagRegistry.find` call sites redirected to `obj.Registry_.find(...)`; machine selector UI; `setProject(machine.Dashboards, machine)` wired to `Machine` handle; machine-switch stops old DashboardEngine timer before starting new one
6. `libs/SensorThreshold/{BatchTagPipeline, LiveTagPipeline}.m` (MODIFIED) — `tagSource_` private property defaulting to `@TagRegistry.find`; new `'TagSource'` NV constructor pair; `eligibleTags_` calls `obj.tagSource_` instead of static `TagRegistry.find`

**Exact seams with file:line:**

| Seam | File:Line | Change |
|------|-----------|--------|
| Widget tag resolution in fromStruct | `FastSenseWidget.m:1516` | Add optional `tagResolver` arg; default falls back to `TagRegistry.get` |
| Resolver dropped on multi-page load | `DashboardEngine.m:4384` | Propagate resolver into every `createWidgetFromStruct` call |
| CatalogPane tag enumeration (x2) | `TagCatalogPane.m:60,205` | `TagRegistry.find(...)` -> `obj.Registry_.find(...)` |
| Live-scan enumeration (x2) | `FastSenseCompanion.m:1616,1618` | `TagRegistry.find(...)` -> `obj.Registry_.find(...)` |
| Pipeline tag source | `BatchTagPipeline.m:256` / `LiveTagPipeline.m:801` | `tagSource_` DI seam; default unchanged |
| openAdHocPlot monitor lookup | `openAdHocPlot.m:165` | Accept no-result gracefully (comparison overlays work without auto-wired EventStore) |

### Critical Pitfalls

1. **Machine tags accidentally entering the global TagRegistry** — `TagRegistry:duplicateKey` is a hard unrecoverable error; 20 machines with identical key `'temperature'` crashes on machine 2. Gate: `grep -rn "TagRegistry.register" libs/Fleet/` must return 0. Must be enforced in Phase 1 — retrofitting later requires touching every fleet ingestion call site.

2. **Resolver propagation gap in `fromStruct` + multi-page load** — `FastSenseWidget.fromStruct:1516` calls `TagRegistry.get` directly bypassing any injected resolver; `DashboardEngine.m:4384` drops the resolver silently on the multi-page path. Fleet dashboards load with `Tag = []` or bind to the wrong machine's tag. Fix both gaps together in Phase 3; phase exit gate includes a backward-compat regression test.

3. **Canonical mapping false matches — silent wrong comparisons** — over-eager fuzzy matching maps physically-different sensors; code works, chart renders, data is wrong. This is the most dangerous failure mode. Confidence field (HIGH/MEDIUM/LOW) must be in the mapper schema from day one; comparison view gates on confidence and refuses LOW/unreviewed entries; unit-consistency check rejects matches where sensor units differ.

4. **`localKey` vs `logicalId` vs `registry Key` namespace confusion** — three distinct `char` namespaces that look identical; conflating them produces wrong-tag bindings that are hard to diagnose. Enforce naming discipline in API signatures; assertion in `Machine.getTag(localKey)` errors if key contains `/` (canonical namespace separator never appears in machine-local keys).

5. **Lazy-load discipline absent at 20+ machines** — `machine.loadAllTags()` at Fleet startup = ~640 MB before first UI frame on a 20-machine fleet. `Machine` uses metadata-only load at startup; `X`/`Y` arrays on first `getTag` call only. Phase exit gate: Fleet startup with 5-machine test dataset < 2 s, < 50 MB.

---

## Implications for Roadmap

Based on the dependency analysis in ARCHITECTURE.md and the phase-to-pitfall mapping in PITFALLS.md, six phases are suggested. The ordering is dependency-driven.

### Phase 1: CanonicalMapper

**Rationale:** Zero external dependencies; validates the core logical-sensor mapping logic before any wiring; foundational for every subsequent feature that touches comparison or clone/remap. Confidence-level schema must be correct from the start — retrofitting after mappings are persisted requires re-evaluating every entry.

**Delivers:** `libs/Fleet/CanonicalMapper.m` with normalization pipeline (`lower`/`regexprep`/`strsplit`), hand-rolled Wagner-Fischer edit distance, confidence levels (HIGH/MEDIUM/LOW), manual override `containers.Map`, unit-consistency check, `reviewPending()` / `unmapped(machineId)` query API; `tests/suite/TestCanonicalMapper.m`.

**Addresses:** Area 3 table stakes (canonical map structure, auto-suggest, manual override, unmapped-tail surfacing).

**Avoids:** Pitfalls 3 (false matches), 4 (false misses), 5 (namespace confusion).

**Exit gates:** Confidence field present on every entry; LOW-confidence comparison gate test passes; unit-consistency test passes; `grep -rn "contains(" libs/Fleet/CanonicalMapper.m` returns 0.

### Phase 2: Machine + Fleet Data Model + Pipeline DI Seam

**Rationale:** Depends on CanonicalMapper for `Fleet.resolveLogical`; pipeline DI seam changes are additive (default unchanged) and lowest-risk; `Machine` must be stable before companion wiring.

**Delivers:** `libs/Fleet/Machine.m` (isolated tag catalog, duck-type API, lazy metadata/data loading, `ingestBatch`/`startLive` wrappers, `DataRoot`, `EventStore`); `libs/Fleet/Fleet.m` (searchable machines, `filterByName`/`filterByGroup`, `resolveLogical`, `save`/`load` with `fleetConfigVersion`); `BatchTagPipeline.m` + `LiveTagPipeline.m` `tagSource_` DI seam; `tests/suite/TestMachine.m`; `tests/suite/TestFleet.m`.

**Addresses:** Area 1 (machine browsing data model), Area 3 (canonical map integration).

**Avoids:** Pitfalls 1 (TagRegistry containment gate), 5 (namespace discipline), 6 (lazy-load in Machine design), 9 (per-machine DataRoot isolation), 12 (fleet config schema versioning), 13 (no `ui*` in `libs/Fleet/`), 14 (Octave parity).

**Exit gates:** `grep -rn "TagRegistry.register" libs/Fleet/` returns 0; `grep -rn "uifigure\|uicontrol\|uitree\|uigridlayout\|uiprogressdlg" libs/Fleet/` returns 0; Fleet startup < 2 s / < 50 MB; `Fleet.save`/`Fleet.load` round-trip passes on both MATLAB and Octave.

### Phase 3: DashboardSerializer Resolver Seam + Backward-Compat Tests

**Rationale:** Independent of Fleet/Machine; Dashboard code has its own test suite; isolating it proves backward compat before companion wiring starts. Must be complete before any fleet dashboard is serialized.

**Delivers:** `FastSenseWidget.fromStruct` optional `tagResolver` arg (default: `TagRegistry.get`, backward compat preserved); `DashboardSerializer.configToWidgets` + `createWidgetFromStruct` threading `tagResolver`; `DashboardEngine.load()` optional resolver arg propagated into multi-page path at line 4384; backward-compat regression test loading pre-v5.0 single-machine JSON with no fleet objects present.

**Addresses:** Area 4 (machine-scoped dashboard round-trip correctness).

**Avoids:** Pitfall 2 (resolver propagation gap — central correctness requirement), Pitfall 10 (backward-compat break on load).

**Exit gates:** Pre-v5.0 `examples/` JSON files load without change; multi-page fleet JSON load: Tags resolved on page 2 widgets; no-resolver load of fleet dashboard emits warning (not silent empty tags); `linesForWidget` `.m` export does not emit bare `TagRegistry.get(...)` for fleet widgets.

### Phase 4: Companion Machine Dimension + Machine Selector UI

**Rationale:** Depends on Phases 1-3; highest integration surface; most expensive to debug. Machine selector ships without health badge (deferred to monitoring milestone — do not block on it).

**Delivers:** `FastSenseCompanion.setProject(machine.Dashboards, machine)` accepting a `Machine` handle; four static `TagRegistry.find` call sites redirected to `obj.Registry_.find(...)` (TagCatalogPane.m:60,205; FastSenseCompanion.m:1616,1618); machine selector pane (uilistbox + debounce); active-machine indicator; machine-switch timer lifecycle (`oldEngine.stop()` before `newEngine.start()`); `openAdHocPlot.m:165` graceful no-result; `tests/suite/TestFleetIntegration.m`.

**Addresses:** Area 1 (machine browsing + active context).

**Avoids:** Pitfall 7 (inactive-machine timer refresh — timer lifecycle is machine-selection-driven).

**Exit gates:** Legacy `Registry`/`Dashboards` constructor args still work; `timerfindall` count stable across machine switches; `TagRegistry.list()` shows 0 machine tags after loading a 2-machine fleet.

### Phase 5: Cross-Machine Comparison View

**Rationale:** Depends on Phase 4 (machine selector must exist to pick machines) and Phase 2 (Fleet.resolveLogical and CanonicalMapper confidence gate).

**Delivers:** Companion comparison flow — pick logical sensor -> `Fleet.resolveLogical(logicalId)` called once at open time -> Tag handles cached in local cell array -> `openAdHocPlot(tags, 'Overlay', theme, 'DisplayNames', machineQualifiedNames)` with machine-labeled legend (`[machineName]: [sensorDisplayName]`); missing-sensor graceful skip with warning; wall-clock overlay as default; Tags resolved once at comparison-open, `fp.updateData()` per tick only.

**Addresses:** Area 2 table stakes (overlay N machines, auto-color, machine-labeled legend, wall-clock alignment, missing-sensor graceful skip, multi-select from fleet).

**Avoids:** Pitfall 8 (comparison view re-resolving on every tick — cache-at-open); Pitfall 3 (LOW-confidence mapping gate in comparison view).

**Exit gates:** `CanonicalMapper.resolve` absent from steady-state tick profiler output; LOW-confidence mapping excluded from comparison with warning; missing sensor on one machine skips gracefully without crash.

### Phase 6: Per-Machine Dashboard Clone/Remap

**Rationale:** Depends on Phases 2-4; canonical map must be confirmed for target machines; DashboardSerializer resolver seam (Phase 3) must be in place.

**Delivers:** `FleetDashboardCloner` (or method on `Fleet`) implementing clone of source dashboard onto target machine via canonical map; failed-remap collection and warning surfacing (not silent empty widgets); `RebindPending` flag on widgets with unresolved bindings; per-machine dashboard save/load round-trip via scoped resolver.

**Addresses:** Area 4 table stakes (clone/remap deployment workflow, machine-scoped resolver round-trip).

**Avoids:** Pitfall 11 (clone/remap silent failure — failed remaps collected and surfaced as non-empty warnings list).

**Exit gates:** Clone a 5-widget dashboard where target machine lacks one sensor: warnings list has 1 entry, 4 widgets rebound correctly; end-to-end round-trip: serialize machine dashboard -> load on different machine -> all tags bound correctly.

### Phase Ordering Rationale

- CanonicalMapper first because confidence-level schema must be correct before any mapping is persisted; retrofitting later requires re-evaluating every stored entry.
- Machine/Fleet second because pipelines and companion depend on it; DI seam to pipelines is the lowest-risk existing-code modification (additive, default unchanged).
- Serializer seam third because it touches a high-value existing module independently; its backward-compat regression test is a risk gate for everything that follows; isolating it prevents Dashboard regressions from mixing into companion integration work.
- Companion fourth because it consumes all three prior phases and has the highest integration surface.
- Comparison view fifth because it requires both the machine selector (Phase 4) and Fleet.resolveLogical (Phase 2) to be stable.
- Clone/remap last because it requires the canonical map to be confirmed for target machines and is the highest-complexity serialization workflow.

### Research Flags

Phases with well-documented patterns (no additional research phase needed):
- **Phase 1 (CanonicalMapper):** all primitives confirmed in codebase; Wagner-Fischer is textbook algorithm; no ambiguity
- **Phase 2 (Machine/Fleet data model):** `containers.Map` and JSON serialization patterns confirmed in 5+ existing files; lazy-load architecture is straightforward
- **Phase 3 (Serializer seam):** exact file:line seams identified by code audit; change is mechanical; backward-compat test pattern established

Phases where a targeted pre-phase review is advisable (re-read relevant ARCHITECTURE.md sections before planning):
- **Phase 4 (Companion machine dimension):** machine selector placement (left rail vs. top dropdown vs. tabs) was explicitly deferred in PROJECT.md; requires a focused UI decision before the phase plan is written; re-read ARCHITECTURE.md Q5 + FEATURES.md Area 1 differentiators
- **Phase 5 (Comparison view):** `openAdHocPlot` per-series color injection design is not pinned (`colors` arg vs. struct-array input); resolve before plan is locked; re-read ARCHITECTURE.md Q5
- **Phase 6 (Clone/remap):** `FleetDashboardCloner` placement (standalone function vs. method on `Fleet` vs. `DashboardSerializer` static method) is unresolved; needs one design decision pass

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Every primitive confirmed with file:line codebase evidence; no new dependencies; all MATLAB/Octave divergences identified with workarounds already present in this codebase |
| Features | HIGH | Prior art verified from PI Vision, Seeq, Grafana, TrendMiner; feature categories agree across all four tools; dependency graph grounded in codebase architecture |
| Architecture | HIGH | All findings from direct code audit at commit HEAD on branch `claude/friendly-leakey-0bc166`; exact file:line seams identified for every integration point; anti-patterns grounded in rejected design approaches from PROJECT.md |
| Pitfalls | HIGH | All 14 pitfalls traced to concrete files; recovery strategies and phase-to-pitfall mapping provided; prior v4.0 pitfall research consulted for concurrency patterns |

**Overall confidence:** HIGH

### Gaps to Address

- **Machine selector UI placement** — PROJECT.md explicitly deferred left-rail vs. top-dropdown vs. tabs; must be resolved before Phase 4 planning; data model is placement-agnostic
- **`openAdHocPlot` per-series color injection** — existing `plotOverlay_` uses MATLAB `ColorOrder` auto-assignment; explicit per-machine color injection requires either a `colors` arg or struct-array input; form not pinned; resolve at Phase 5 planning
- **`FleetDashboardCloner` placement** — behavior is specified; whether it lives in `libs/Fleet/`, as a static method on `DashboardSerializer`, or as a method on `Fleet` is unresolved; resolve at Phase 6 planning
- **Octave CI fleet test coverage** — `TestMachine.m` and `TestCanonicalMapper.m` must be explicitly added to the Octave CI job in the Phase 2 plan (not automatic)

---

## Sources

### Primary (HIGH confidence — direct code audit at commit HEAD)

- `libs/FastSenseCompanion/TagCatalogPane.m` — confirmed uilistbox + debounce pattern; static `TagRegistry.find` at lines 60, 205
- `libs/FastSenseCompanion/FastSenseCompanion.m` — static `TagRegistry.find` at lines 1616, 1618; `obj.Registry_.get` object call at line 2182; `setProject` seam; Octave guard at lines 136-139
- `libs/FastSenseCompanion/DashboardListPane.m` — per-row grid + scrollable panel pattern
- `libs/FastSenseCompanion/private/filterTags.m` — `strfind(lower(...))` Octave-portable search (not `contains`)
- `libs/FastSenseCompanion/private/filterDashboards.m` — `strfind` not `contains` convention
- `libs/Dashboard/FastSenseWidget.m` — `TagRegistry.get(s.source.key)` at line 1516 (resolver seam); `TagRegistry.getEventStore()` at lines 178, 1440; `toStruct` at line 1211
- `libs/Dashboard/DashboardSerializer.m` — resolver hook at lines 388-411 covering only `source.type='sensor'`; `linesForWidget` `TagRegistry.get(...)` emission at lines 44, 47, 793, 796
- `libs/Dashboard/DashboardEngine.m` — multi-page path at line 4384 drops resolver; `load()` resolver arg threading gap
- `libs/SensorThreshold/TagRegistry.m` — hard-error on duplicate key (line 90); persistent catalog (lines 417-420); `getEventStore` persistent slot (lines 423-431)
- `libs/SensorThreshold/BatchTagPipeline.m` — `eligibleTags_` static call at line 256
- `libs/SensorThreshold/LiveTagPipeline.m` — `eligibleTags_` static call at line 801; SharedRoot/cluster mode (lines 161, 225-241)
- `libs/Concurrency/ndjsonDecode.m` line 29 — "Both MATLAB R2016b+ and Octave 5+ ship jsondecode"
- `libs/FastSenseCompanion/companionPrefs.m` — `.mat` pattern for user prefs; `movefile` atomic-write
- `libs/EventDetection/EventStore.m` lines 108, 636 — `dir(fullfile(dir, '*.ext'))` pattern
- `libs/Dashboard/private/normalizeToCell.m` — post-`jsondecode` cell normalization helper
- `.planning/PROJECT.md` — locked v5.0 scope, out-of-scope decisions, Approach 1 architecture choice

### Secondary (MEDIUM confidence — industry prior art)

- AVEVA PI Vision documentation — element templates + substitution parameters; "Switch Asset" panel; context-switching UX
- Seeq `spy.swap` documentation — exact-name matching as canonical map; per-asset failure report; asset swap rebinding
- Grafana variables documentation — multi-value variable pattern; per-series auto-color pain point; dashboard repeat panels
- TrendMiner layer comparison user guide — normalized-time overlay is specialized mode, not default
- USPTO patent US10460240 — tag normalization and similarity scoring patterns for industrial machines

---
*Research completed: 2026-06-02*
*Ready for roadmap: yes*
