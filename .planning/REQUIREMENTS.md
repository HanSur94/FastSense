# Requirements: FastSense v5.0 Multi-Machine Fleet

**Defined:** 2026-06-02
**Core Value:** A MATLAB engineer can ingest, browse, dashboard, and compare data across a growing fleet of near-identical machines from the FastSense Companion — including overlaying the *same logical sensor* across machines whose raw sensor keys differ — without leaving MATLAB and without external toolboxes.

## v1 Requirements

Requirements for the v5.0 release. New category prefixes (FLEET/CANON/MACH/CMP/DASH) begin at 01. Phase numbering continues from v4.0 (last phase 1040), so v5.0 phases start at **1041**.

Design is locked to **Approach ①** (Machine/Fleet layer; global `TagRegistry` untouched). The canonical map is the gating dependency for comparison and clone/remap.

### Fleet & Machine Data Model (FLEET)

The additive `libs/Fleet/` layer: isolated per-machine tag catalogs, per-machine ingestion, and fleet config persistence. Foundation for everything else.

- [ ] **FLEET-01**: User can define a `Machine` (Id, Name, `DataRoot` folder, optional metadata) and add it to a `Fleet` via a script API (`Fleet.addMachine(...)`).
- [ ] **FLEET-02**: User can register two machines that share an identical local sensor key (e.g. both have `temperature`) with no duplicate-key error — each `Machine` owns an isolated tag catalog and machine tags never enter the global `TagRegistry` (verified: `grep "TagRegistry.register" libs/Fleet/` returns 0; `TagRegistry.list()` shows 0 machine tags after loading a 2-machine fleet).
- [ ] **FLEET-03**: A machine ingests its raw/live data into its own `DataRoot` via the existing `BatchTagPipeline`/`LiveTagPipeline`, scoped to that machine's tags (pipeline `tagSource_` DI seam). Existing single-machine pipeline usage (global registry) is byte-for-byte unchanged.
- [ ] **FLEET-04**: User can save a fleet configuration (machines, `DataRoot`s, metadata, canonical overrides) to a JSON file and reload it, round-tripping identically on both MATLAB R2020b+ and Octave 7+.
- [ ] **FLEET-05**: Opening a fleet of many machines loads tag *metadata* only — sample data for a machine loads lazily on first access (startup with a 5-machine test set stays under a documented memory/time budget).
- [ ] **FLEET-06**: User can assign a machine to a group and filter/browse the fleet by group, composable with free-text search (`Machine.Group` + `Fleet.filterByGroup`). *(differentiator)*

### Canonical Sensor Mapping (CANON)

The logical-sensor layer bridging differing per-machine keys. Must be reviewable so wrong comparisons can't happen silently.

- [x] **CANON-01**: For machines that name the same sensor differently, the mapper auto-suggests a logical-sensor mapping (`logicalId → {machineId → localKey}`) from name/unit similarity using only toolbox-free primitives (hand-rolled edit distance + normalization).
- [x] **CANON-02**: Every mapping entry carries a confidence level (HIGH/MEDIUM/LOW), and the mapper flags matches whose units are inconsistent.
- [x] **CANON-03**: User can manually override or correct a mapping (in the mapping review surface, or promoted from a per-machine choice in the comparison builder); the override persists in the fleet config and takes precedence over auto-suggestions.
- [x] **CANON-04**: User can query which of a machine's tags are unmapped or ambiguous (the tail needing attention) — `reviewPending()` / `unmapped(machineId)`.
- [x] **CANON-05**: User can review and edit the canonical map in the companion via a table (logical name / per-machine local key / status / confidence) and promote entries.

### Companion Machine Dimension (MACH)

Adds machine browsing/selection to the companion by reusing the existing `setProject` "active project" seam.

- [ ] **MACH-01**: User can browse and free-text-search the fleet's machines in the companion at fleet scale (20+, lazy-populated).
- [ ] **MACH-02**: Selecting a machine makes it the active context — the tag catalog and dashboard list show that machine's tags and dashboards (via `setProject(machine.Dashboards, machine)`; the four static `TagRegistry.find` call sites are re-pointed to the active machine).
- [ ] **MACH-03**: The companion always indicates which machine is the active context.
- [ ] **MACH-04**: Switching machines stops the previously-active dashboard's live timer before starting the new one — timer count is stable across repeated machine switches (no accumulation).
- [ ] **MACH-05**: Existing companion construction (`'Registry'`/`'Dashboards'` args, no `Fleet`) continues to work unchanged as a single implicit machine. *(backward compatibility)*

### Cross-Machine Comparison (CMP)

The headline capability. The flow is **machine-first** (Approach A — a modeless compare-builder dialog that opens its own overlay figure; reuses the `openAdHocPlot` Overlay path; no changes to the 3 panes or `setProject`): select machines, then choose each machine's data.

- [ ] **CMP-01**: User can build a comparison by (1) selecting machines, then (2) choosing the data for each — either a single "same sensor for all" quick-fill (auto-resolved per machine via the canonical map) or a tag chosen separately per machine — and overlay the result on one axes.
- [ ] **CMP-02**: Each machine's series gets a distinct color (stable **per machine**, not per selection order) and a machine-qualified legend label (`[machineName]: [localTag]`).
- [ ] **CMP-03**: A machine that lacks the chosen sensor shows `— none —` and is skipped gracefully with a surfaced warning by default — never a crash, never a silent wrong-data substitution; the user may explicitly substitute a different tag (see CMP-06).
- [ ] **CMP-04**: The builder refuses to auto-include LOW-confidence / unreviewed canonical matches (confidence gate) — they are surfaced and need an explicit per-machine confirm; a unit mismatch on a manual substitution is warned. Prevents silent wrong comparisons.
- [ ] **CMP-05**: A comparison resolves its tags once at open time (cached); live ticks call `updateData` only and do not degrade dashboard/companion refresh rate (`CanonicalMapper.resolve` absent from steady-state tick profile).
- [ ] **CMP-06**: In the builder, the user can set each machine's data independently — accept the auto-match, confirm a low-confidence match, pick a different local tag (separate data per machine), or skip the machine; a manual override can be promoted into the canonical map.

### Per-Machine Dashboards & Clone/Remap (DASH)

Hand-built independent per-machine dashboards, made maintainable by canonical-map-driven cloning.

- [ ] **DASH-01**: A machine's tag-bound dashboards serialize and reload correctly, resolving `(machineId, localKey)` via the Fleet→Machine resolver — including multi-page dashboards (closes the `FastSenseWidget.fromStruct:1516` + `DashboardEngine:4384` resolver gaps).
- [ ] **DASH-02**: Pre-v5.0 single-machine dashboards (JSON and `.m`) continue to load unchanged via the global registry (resolver defaults to `TagRegistry.get`). *(backward compatibility)*
- ~~**DASH-03**: User can clone a dashboard from one machine onto another; tag bindings are rebound to the target machine's tags via the canonical map.~~ **DROPPED 2026-06-17** (see note).
- ~~**DASH-04**: When a clone target lacks a sensor used by the source dashboard, the unresolved bindings are surfaced as a warnings list (not silent empty widgets).~~ **DROPPED 2026-06-17** (see note).

> **DASH-03/04 dropped from v5.0 (2026-06-17).** Clone/remap (Phase 1046) was discussed, planned, and gsd-plan-checker-VERIFIED, but cut before execution. Rationale: its only user-facing value this milestone would have been a *programmatic-only* API (the companion "Clone to machine" UI hook was already deferred), and the milestone's headline value — cross-machine comparison — already shipped in Phase 1045; no concrete dashboard-cloning workflow was in demand. The enabling resolver seam (Phase 1043 `DashboardEngine.load` `TagResolver`) stays in place, and the 1046 plans remain in git history, so clone/remap can be revived cheaply (~1 hr) if a real need appears.

## Future Requirements (deferred to v5.x)

Identified by research / scoping, deferred to keep v5.0 tight.

| Deferred | Reason |
|----------|--------|
| Regex batch mapping rules (naming-convention rules → O(rules)) | Valuable for systematic naming; defer until the base auto-suggest + override is proven |
| Clone dry-run preview (unresolvable bindings shown before clone) | Safety nicety on top of DASH-03/04; defer |
| Recent machines list | Minor navigation nicety |
| Machine health/status badge (green/amber/red) | Requires fleet-wide background monitoring (builds on v4.0 + Ph. 1039/1040); separate milestone |
| Batch clone (one source → N targets) | Add once single-clone is proven stable |
| Normalized-time (batch-aligned) comparison overlay | Requires batch-event infrastructure; wall-clock overlay is the v5.0 default |
| Statistical fleet envelope (min/max band across machines) | Requires a new aggregation compute layer |
| WebBridge parity for fleet features | Browser layer follows the MATLAB feature, as in prior milestones |

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| AF-style asset hierarchy tree | A flat searchable list + one `Group` field is sufficient for 20–50 machines; a full tree is over-engineering |
| Automatic machine discovery from the filesystem | Explicit `Fleet.addMachine(...)` in user scripts is the correct, predictable pattern |
| Refactoring `TagRegistry` to be instantiable (Approach ③) | 72 static call sites across 31 files; rejected for backward-compat risk |
| Namespaced compound keys in the global registry (Approach ②) | Key-sprawl + forced per-machine filtering everywhere; rejected |
| ML / semantic tag matching | Breaks the no-external-dependency constraint; edit-distance + overrides is sufficient |
| Forced dashboard templating across machines | User chose hand-built independent per-machine dashboards + clone/remap |
| Cross-machine MonitorTag/event rollups; fleet-wide background monitoring | Builds on v4.0 concurrency + Ph. 1039/1040 monitoring; out of this milestone |

## Traceability

Each requirement maps to exactly one phase. Confirmed by roadmapper 2026-06-02.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CANON-01 | Phase 1041 (CanonicalMapper) | Complete |
| CANON-02 | Phase 1041 (CanonicalMapper) | Complete |
| CANON-03 | Phase 1041 (CanonicalMapper) | Complete |
| CANON-04 | Phase 1041 (CanonicalMapper) | Complete |
| CANON-05 | Phase 1041 (CanonicalMapper) | Complete |
| FLEET-01 | Phase 1042 (Machine + Fleet + Pipeline DI Seam) | Pending |
| FLEET-02 | Phase 1042 (Machine + Fleet + Pipeline DI Seam) | Pending |
| FLEET-03 | Phase 1042 (Machine + Fleet + Pipeline DI Seam) | Pending |
| FLEET-04 | Phase 1042 (Machine + Fleet + Pipeline DI Seam) | Pending |
| FLEET-05 | Phase 1042 (Machine + Fleet + Pipeline DI Seam) | Pending |
| FLEET-06 | Phase 1042 (Machine + Fleet + Pipeline DI Seam) | Pending |
| DASH-01 | Phase 1043 (DashboardSerializer Resolver Seam + Backward Compat) | Pending |
| DASH-02 | Phase 1043 (DashboardSerializer Resolver Seam + Backward Compat) | Pending |
| MACH-01 | Phase 1044 (Companion Machine Dimension) | Pending |
| MACH-02 | Phase 1044 (Companion Machine Dimension) | Pending |
| MACH-03 | Phase 1044 (Companion Machine Dimension) | Pending |
| MACH-04 | Phase 1044 (Companion Machine Dimension) | Pending |
| MACH-05 | Phase 1044 (Companion Machine Dimension) | Pending |
| CMP-01 | Phase 1045 (Cross-Machine Comparison View) | Pending |
| CMP-02 | Phase 1045 (Cross-Machine Comparison View) | Pending |
| CMP-03 | Phase 1045 (Cross-Machine Comparison View) | Pending |
| CMP-04 | Phase 1045 (Cross-Machine Comparison View) | Pending |
| CMP-05 | Phase 1045 (Cross-Machine Comparison View) | Pending |
| CMP-06 | Phase 1045 (Cross-Machine Comparison View) | Pending |
| DASH-03 | Phase 1046 (Per-Machine Dashboard Clone/Remap) | **Dropped 2026-06-17** |
| DASH-04 | Phase 1046 (Per-Machine Dashboard Clone/Remap) | **Dropped 2026-06-17** |

**Coverage:**

- v1 requirements: 26 defined; **24 delivered, 2 dropped** (DASH-03/04 — Phase 1046 cut pre-execution 2026-06-17). FLEET 6, CANON 5, MACH 5, CMP 6, DASH 2/4.
- Mapped to phases: 24/24 in-scope (100%); Phase 1046 dropped.
- Unmapped: 0

---
*Requirements defined: 2026-06-02*
*Last updated: 2026-06-02 — Traceability confirmed by roadmapper; 26/26 requirements mapped to phases 1041-1046, 100% coverage.*
