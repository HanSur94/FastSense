# Phase 1042: Machine + Fleet + Pipeline DI Seam - Context

**Gathered:** 2026-06-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Data-model phase. Delivers `libs/Fleet/Machine.m` + `libs/Fleet/Fleet.m` + the pipeline `tagSource_` DI seam.

Each `Machine` owns an isolated `containers.Map` tag catalog + a `DataRoot` + its own `EventStore` + a `Dashboards` cell. A `Fleet` holds searchable machines and persists the fleet config (machines, DataRoots, metadata, embedded canonical map) to a JSON file that round-trips identically on MATLAB R2020b+ and Octave 7+. `BatchTagPipeline`/`LiveTagPipeline` gain a `tagSource_` DI seam so a machine ingests into its own `DataRoot` without touching the global registry. **Machine tags NEVER enter the global `TagRegistry`.** No UI code in `libs/Fleet/` (Octave runs all of it).

Covers **FLEET-01..06**.

Out of this phase: companion machine-dimension wiring (1044), DashboardSerializer resolver seam (1043), cross-machine comparison (1045), clone/remap (1046), and `CanonicalMapper` itself (1041 — already shipped).
</domain>

<decisions>
## Implementation Decisions

User chose "nothing" to discuss and approved locking the four open gray areas at Claude's discretion (D-01..D-11). D-12..D-14 restate locked research findings for the planner's convenience.

### Catalog Population & Lazy Load (FLEET-01, FLEET-05)
- **D-01:** Tags are populated **programmatically** — the user constructs `Tag` objects (`SensorTag`, …) and calls `machine.addTag(t)`. Mirrors today's `TagRegistry.register`/`addTag` mental model and the Machine duck-type read API. **No new manifest/catalog file format.**
- **D-02:** "Metadata-only at startup" means the `Tag` object carries its metadata eagerly (Key / Name / Labels / Units / `RawSource` pointer) while X/Y sample arrays are NOT materialized until first `getXY()`/value access. **Reuse the existing `SensorTag.RawSource` deferred-read path** (the same `RawSource.file` the pipelines' `eligibleTags_` already filter on) — do not invent a new lazy mechanism.
- **D-03:** The fleet config persists machine **definitions** (Id / Name / DataRoot / Group / Metadata) + the embedded canonical map. It does **not** serialize the tag catalog — tags are rebuilt by the user's script (`machine.addTag`) or rehydrated from `DataRoot` `.mat` files written by `ingestBatch`. Keeps config small; consistent with `TagRegistry` not persisting tags today.
- **D-04:** Filesystem auto-discovery of tags from a `DataRoot` is **out** (already an excluded anti-feature). Population is explicit.

### Canonical Map Storage (FLEET-04)
- **D-05:** The canonical map is **embedded inside the single fleet JSON** under a `canonicalMap` key. `Fleet.save` inlines `CanonicalMapper.toStruct()`; `Fleet.load` rehydrates via `CanonicalMapper.fromStruct()`. One self-contained, VCS-committable artifact (no sibling-file coupling, no second relative-path to manage).
- **D-06:** `CanonicalMapper`'s standalone `save`/`load` JSON (`CanonicalMapper.m:351/413`) is unchanged and stays for the `CanonicalMapEditor`'s direct use; Fleet just reuses the already-existing `toStruct`/`fromStruct` (`CanonicalMapper.m:337/387`).

### DataRoot Path Persistence (FLEET-04)
- **D-07:** Paths are stored **as-given**. On load, **relative** DataRoot paths resolve against the loaded config file's directory (portable when config + data ship/commit together); **absolute** paths are used verbatim; a leading `~` is expanded. Least-surprise, standard config behavior.
- **D-08:** Auto-relativizing an absolute DataRoot on save is **deferred** (a nicety, not needed for round-trip).

### Machine API & Identity (FLEET-01, FLEET-06)
- **D-09:** `Fleet.addMachine` primary ergonomic form is a name-value factory: `Fleet.addMachine('Id',id,'Name',name,'DataRoot',root,'Group',grp,'Metadata',s)` — constructs the Machine, adds it, returns the handle. **Also** accept a pre-built handle: `Fleet.addMachine(machineObj)`. `Machine` has a public NV constructor `Machine('Id',…,'Name',…,'DataRoot',…)`.
- **D-10:** `Id` is **user-supplied and required**; unique within a Fleet (error `Fleet:duplicateMachineId` on collision, mirroring `TagRegistry`'s hard duplicate-key error). It is the stable identity used as the `CanonicalMapper` `machineId` and the comparison legend key — **never derived from Name** (names change/collide). `Name` defaults to `Id` when omitted.
- **D-11:** `Group` is a **single freeform char** field (default `''` = ungrouped). `Fleet.filterByGroup(g)` and `Fleet.filterByName(pattern)` each return a Machine subset and are **composable by chaining** (AND). Free-text search uses `strfind(lower(...))` (Octave-safe), never `contains`.

### Pipeline DI Seam (FLEET-03) — locked by research, restated for the planner
- **D-12:** Add a private `tagSource_ = @TagRegistry.find` to **both** `BatchTagPipeline` and `LiveTagPipeline`; `eligibleTags_` calls `obj.tagSource_(pred)` instead of the static `TagRegistry.find`. Expose via a `'TagSource'` constructor NV pair (match the existing `setWriteFnForTesting_` DI idiom). Default unchanged → single-machine usage is byte-for-byte identical.
- **D-13:** `Machine.ingestBatch()` / `Machine.startLive(interval)` wrap the pipelines with `OutputDir = machine.DataRoot` and `TagSource = @(pred) machine.find(pred)`. Forward `'SharedRoot'` optionally so a clustered machine keeps v4.0 cluster mode; omitting it runs zero cluster-path code.

### Machine-owned services
- **D-14:** Each `Machine` owns its own `EventStore = EventStore(machine.DataRoot)` (per-machine isolation, Phase 1039 cluster-safe pattern). The global `TagRegistry.setEventStore` slot is NOT touched. `Machine` also holds `Dashboards` (cell) for later phases.

### Claude's Discretion
The planner may refine mechanics (exact property names, error-id spelling, private-helper decomposition, `fleetConfigVersion` value) as long as the ROADMAP success criteria and the milestone critical invariants hold. D-01..D-11 were Claude-decided per user approval; D-12..D-14 restate locked research, not fresh choices.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v5.0 milestone specs (scope authority)
- `.planning/REQUIREMENTS.md` §"Fleet & Machine Data Model (FLEET)" — FLEET-01..06 verbatim requirements
- `.planning/ROADMAP.md` §"Phase 1042" — goal + 5 success criteria + dependency on 1041
- `.planning/PROJECT.md` §"Current Milestone: v5.0" + §"Key decisions carried in" — Approach ① lock, TagRegistry-untouched, JSON-not-`.mat`
- `.planning/STATE.md` §"v5.0 Architecture Decisions Locked" + §"Critical Invariants" — the 5 invariants verified at every phase gate

### v5.0 research (HIGH confidence — read before planning)
- `.planning/research/SUMMARY.md` §"Phase 2: Machine + Fleet Data Model + Pipeline DI Seam" — deliverables, exit gates, pitfalls-avoided for THIS phase
- `.planning/research/ARCHITECTURE.md` lines 51-110 (Q1) — Machine duck-type read API (`get`/`find`/`findByKind`/`findByLabel`/`keys`) Machine must expose
- `.planning/research/ARCHITECTURE.md` lines 203-278 (Q3) — pipeline `tagSource_` DI seam + `Machine.ingestBatch`/`startLive` wrappers + v4.0 SharedRoot interaction (exact code)
- `.planning/research/ARCHITECTURE.md` lines 281-303 (Q4) — per-machine EventStore; global slot untouched
- `.planning/research/PITFALLS.md` — pitfalls 1 (TagRegistry containment), 5 (localKey/logicalId/registryKey namespace), 6 (lazy-load), 9 (DataRoot isolation), 12 (fleet config schema versioning), 13 (no `ui*` in `libs/Fleet/`), 14 (Octave parity)

### Dependency artifacts (Phase 1041, complete)
- `libs/Fleet/CanonicalMapper.m` — the `resolveLogical` dependency; `toStruct`/`fromStruct` (337/387) + `save`/`load` (351/413) reused by Fleet config; entry-struct fields (`machineId localKey localName localUnits similarity confidence status unitMismatch`)
- `.planning/phases/1041-canonicalmapper/1041-04-SUMMARY.md` — final CanonicalMapper API state as shipped

### Existing-code seams to read
- `libs/SensorThreshold/BatchTagPipeline.m:251-256` — `eligibleTags_` + the `TagRegistry.find` call to replace with `tagSource_`
- `libs/SensorThreshold/LiveTagPipeline.m:786-801` — identical `eligibleTags_` seam; SharedRoot/cluster at `161`, `225-241`
- `libs/SensorThreshold/TagRegistry.m` — read API to mirror; the duplicate-key hard-error pattern to emulate for duplicate machine Id
- `libs/EventDetection/EventStore.m` — `Machine.EventStore = EventStore(DataRoot)`; `movefile` atomic-write pattern (also `libs/FastSenseCompanion/companionPrefs.m`) for `Fleet.save`
- `libs/Dashboard/private/normalizeToCell.m` — post-`jsondecode` cell normalization for Octave-safe round-trip

### Project conventions
- `CLAUDE.md` — naming (PascalCase classes, camelCase methods, trailing-underscore privates), error-id convention `ClassName:camelCaseProblem`, Octave parity, install.m path wiring
- `.planning/codebase/CONVENTIONS.md` — repo-wide conventions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CanonicalMapper.toStruct`/`fromStruct` (`libs/Fleet/CanonicalMapper.m:337,387`) — embed/rehydrate the canonical map inside fleet JSON for free.
- `TagRegistry` read API (`get`/`find`/`findByKind`/`findByLabel`/`keys`) — Machine duck-types this so existing panes (1044) can consume a Machine as `registry` unchanged.
- `SensorTag.RawSource` deferred-read — already the lazy-load mechanism; reuse for FLEET-05 (no new code).
- `BatchTagPipeline`/`LiveTagPipeline` `eligibleTags_` — one-line change to `obj.tagSource_(pred)`; the existing `setWriteFnForTesting_` shows the DI-seam idiom.
- `EventStore(dataRoot)` + `movefile` atomic-write (`EventStore.save` / `companionPrefs.m`) — per-machine EventStore + safe `Fleet.save`.
- `jsonencode`/`jsondecode` + `normalizeToCell` (`libs/Dashboard/private/normalizeToCell.m`) — heterogeneous-array JSON round-trip + post-decode normalization for Octave parity.
- Octave-safe string ops `strfind(lower(...))` / `regexprep` / `strsplit` (`filterTags.m`, `filterDashboards.m`) — for `filterByName`/`filterByGroup`; never `contains()`.

### Established Patterns
- `containers.Map('KeyType','char','ValueType','any')` — `Machine.Tags_` catalog; mirrors `TagRegistry` internals.
- `TagRegistry` = static class + persistent map; `Machine` is the INSTANCE counterpart (handle class owning its own Map) — the essence of Approach ①.
- DI seam = private fn-handle property defaulting to the global function, overridable via NV pair (`setWriteFnForTesting_`, write-fn seam) — apply identically to `tagSource_`.
- Config = human-readable JSON project artifact (`DashboardSerializer.saveJSON`/`loadJSON`); atomic `movefile(tmp,dest,'f')` on save.
- `fleetConfigVersion` field stored in saved config for forward schema evolution (PITFALLS #12).

### Integration Points
- `Fleet.resolveLogical(logicalId)` → `CanonicalMapper` (1041) → per-machine `machine.get(localKey)` → `{machine, Tag}` pairs (consumed by 1045).
- Machine read API → consumed by Companion panes in 1044 (the four static `find` sites are repointed there, NOT here).
- `tagSource_` default `@TagRegistry.find` → preserves every existing single-machine pipeline caller.
- `Machine.DataRoot` → pipeline `OutputDir` + EventStore root (the isolation boundary).

</code_context>

<specifics>
## Specific Ideas

- Machine `Id` is the canonical `machineId` and the comparison legend key (`[machineName]: [sensorDisplayName]` in 1045) — hence Id required + stable, Name display-only.
- One-file fleet config the user can commit + hand-edit; relative DataRoots so a teammate who clones the repo gets working paths.

</specifics>

<deferred>
## Deferred Ideas

- Auto-relativize an absolute DataRoot on save (D-08) — nicety; not needed for round-trip.
- Per-machine catalog manifest written to `DataRoot` for cross-session catalog rehydration without re-running the user script — possible future convenience; current model rebuilds via script / `ingestBatch`.
- Filesystem auto-discovery of machines/tags — explicitly out-of-scope (REQUIREMENTS §Out of Scope).
- `fleetConfigVersion` migration logic beyond a stored version field — add when a v2 schema actually exists.

None of these are scope creep; no out-of-domain ideas were raised since the user chose not to discuss.

</deferred>

---

*Phase: 1042-machine-fleet-pipeline-di-seam*
*Context gathered: 2026-06-03*
