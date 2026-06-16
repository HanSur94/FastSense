---
milestone: v5.0
milestone_name: Multi-Machine Fleet
phases_total: 5
phases_complete: 5
phases_dropped: 1
last_updated: "2026-06-17"
---

# Roadmap: v5.0 Multi-Machine Fleet

## Overview

Six dependency-ordered phases were planned to build the fleet layer from the inside out. CanonicalMapper ships first because the confidence schema must be correct before any mapping is persisted. Machine and Fleet follow with the pipeline DI seam, establishing the core invariant that machine tags never touch the global TagRegistry. The DashboardSerializer resolver seam is fixed in isolation with a backward-compat regression test before any fleet dashboard is serialized. Companion machine-dimension wiring then repoints the four static TagRegistry.find call sites and adds machine selection via setProject. Cross-machine comparison (machine-first compare-builder dialog, Approach A locked) builds on the machine selector and Fleet.resolveLogical.

> **Milestone delivered at 5 phases (2026-06-17).** Phase 1046 (Clone/Remap, DASH-03/04) was planned + checker-verified but **dropped before execution** — a programmatic-only clone API with no concrete demand, while the milestone's headline value (cross-machine comparison) already shipped in Phase 1045. The 1043 resolver seam that would enable it remains in place; the 1046 plans live in git history if revived.

## Phases

- [x] **Phase 1041: CanonicalMapper** - Logical-sensor mapping foundation with confidence levels, auto-suggest, manual overrides, and unmapped-tail surfacing (completed 2026-06-03)
- [x] **Phase 1042: Machine + Fleet + Pipeline DI Seam** - Isolated per-machine tag catalogs, fleet config persistence, lazy load, and pipeline tagSource_ DI (completed 2026-06-07)
- [x] **Phase 1043: DashboardSerializer Resolver Seam + Backward Compat** - Fix fromStruct:1516 and multi-page resolver drop; backward-compat regression test (completed 2026-06-07)
- [x] **Phase 1044: Companion Machine Dimension** - Machine selector, setProject wiring, active-machine indicator, timer lifecycle on machine switch (completed 2026-06-10)
- [x] **Phase 1045: Cross-Machine Comparison View** - Machine-first compare-builder dialog (Approach A); resolve-once caching; confidence gate; auto-color per machine (completed 2026-06-17)
- ~~**Phase 1046: Per-Machine Dashboard Clone/Remap**~~ — **DROPPED 2026-06-17** (planned + checker-verified, cut before execution; DASH-03/04 dropped — see Overview note)

## Phase Details

### Phase 1041: CanonicalMapper

**Goal**: The canonical sensor mapping layer exists and is correct — every mapping entry carries a confidence level and unit-consistency is checked, so no wrong comparison can happen silently
**Depends on**: Nothing (zero external dependencies; no existing code modified)
**Requirements**: CANON-01, CANON-02, CANON-03, CANON-04, CANON-05
**Success Criteria** (what must be TRUE):

  1. User can call `mapper.suggest(machines)` and receive a `logicalId -> {machineId -> localKey}` map built from toolbox-free edit-distance similarity; every entry has a confidence level (HIGH/MEDIUM/LOW)
  2. Every mapping entry with inconsistent sensor units is flagged; a LOW-confidence entry is surfaced in `mapper.reviewPending()` and excluded from comparison until confirmed
  3. User can call `mapper.override(logicalId, machineId, localKey)` and the override persists with precedence over auto-suggestions; `mapper.unmapped(machineId)` returns the tail of unresolved tags
  4. User can view and edit the canonical map in the Companion via a table (logical name / per-machine local key / status / confidence) and promote entries
  5. `grep -rn "contains(" libs/Fleet/CanonicalMapper.m` returns 0 (Octave-safe); no Statistics Toolbox `editDistance` call present

**Plans**: 4 plans
Plans:

- [x] 1041-01-test-scaffold-bootstrap-PLAN.md — Wave 0: TestCanonicalMapper.m (30 RED tests) + install.m Fleet path + libs/Fleet/ bootstrap
- [x] 1041-02-mapper-core-suggest-PLAN.md — Wave 1: CanonicalMapper core — normalize + edit-distance + suggest + confidence + unit-mismatch (CANON-01, CANON-02)
- [x] 1041-03-override-persist-query-PLAN.md — Wave 2: override/confirm precedence + JSON round-trip + reviewPending/unmapped/isResolvable (CANON-03, CANON-04)
- [x] 1041-04-canonical-map-editor-PLAN.md — Wave 3: standalone CanonicalMapEditor uifigure + human-verify checkpoint (CANON-05)

### Phase 1042: Machine + Fleet + Pipeline DI Seam

**Goal**: Each Machine owns an isolated tag catalog and a DataRoot; a Fleet holds searchable machines; pipelines can be scoped to a machine; machine tags never enter the global TagRegistry
**Depends on**: Phase 1041 (Fleet.resolveLogical calls CanonicalMapper)
**Requirements**: FLEET-01, FLEET-02, FLEET-03, FLEET-04, FLEET-05, FLEET-06
**Success Criteria** (what must be TRUE):

  1. User can define machines, add them to a Fleet, and load/save the fleet config (machines, DataRoots, metadata, canonical overrides) round-trip identically on MATLAB R2020b+ and Octave 7+
  2. Two machines that share an identical local sensor key (e.g. both have `temperature`) coexist without error; `grep -rn "TagRegistry.register" libs/Fleet/` returns 0; `TagRegistry.list()` shows 0 machine tags after loading a 2-machine fleet
  3. A machine ingests its data via BatchTagPipeline/LiveTagPipeline scoped to its own DataRoot (tagSource_ DI seam); existing single-machine pipeline usage is byte-for-byte unchanged
  4. Fleet startup with a 5-machine test set stays under the documented memory/time budget (< 2 s, < 50 MB) because tag metadata loads lazily and sample data loads only on first access
  5. User can filter/browse the fleet by group and free-text search composably (`Machine.Group` + `Fleet.filterByGroup`); `grep -rn "uifigure\|uicontrol\|uitree\|uigridlayout" libs/Fleet/` returns 0 (no UI code in data model)

**Plans**: 4 plansPlans:
**Wave 1**

- [x] 1042-01-test-scaffold-normalize-helper-PLAN.md — Wave 1: RED TestMachine/TestFleet suites + Octave flat tests + Fleet-private normalizeToCell_ helper
- [x] 1042-02-pipeline-tagsource-di-seam-PLAN.md — Wave 1: tagSource_ DI seam in BatchTagPipeline + LiveTagPipeline (FLEET-03; single-machine byte-for-byte unchanged)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 1042-03-machine-catalog-class-PLAN.md — Wave 2: Machine class — isolated catalog, duck-type read API, ingest wrappers, EventStore, lazy load, timer-safe delete (FLEET-01/02/03/05)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 1042-04-fleet-persistence-search-PLAN.md — Wave 3: Fleet class — addMachine, composable filters, JSON round-trip with embedded canonical map + fleetConfigVersion (FLEET-01/04/06)

### Phase 1043: DashboardSerializer Resolver Seam + Backward Compat

**Goal**: Machine-scoped tag resolution is threaded correctly through the full Dashboard load path — including the fromStruct and multi-page gaps — and pre-v5.0 dashboards continue to load unchanged
**Depends on**: Phase 1042 (machine resolver signature `@(localKey) machine.get(localKey)` depends on Machine API)
**Requirements**: DASH-01, DASH-02
**Success Criteria** (what must be TRUE):

  1. A fleet dashboard with tags on page 2 loads correctly: widgets on all pages resolve their tags via the injected machine resolver, not TagRegistry.get
  2. Pre-v5.0 single-machine JSON and `.m` dashboards load unchanged with no fleet objects present; the resolver defaults to TagRegistry.get when no resolver is supplied (backward-compat regression test passes)
  3. Loading a fleet dashboard with no resolver injected emits a warning (not silent empty tags and not a crash)
  4. The `.m` export path (`linesForWidget`) does not emit bare `TagRegistry.get(...)` for fleet widgets — it emits the machine-scoped form

**Plans**: 3 plans
Plans:
**Wave 0**

- [x] 1043-01-test-scaffold-resolver-seam-PLAN.md — Wave 0: RED TestFleetDashboardResolver class suite (SC1-SC4) + Octave flat test_dashboard_resolver (DASH-01/02)

**Wave 1** *(blocked on Wave 0 completion)*

- [x] 1043-02-resolver-threading-load-path-PLAN.md — Wave 1: fromStruct tagResolver arg + createWidgetFromStruct/configToWidgets threading + DashboardEngine.load multi-page resolver + TagResolver/SensorResolver NV + tagResolverMissing warning (DASH-01/02)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 1043-03-m-export-machine-scoping-PLAN.md — Wave 2: linesForWidget 'tag' case + machineVar via exportScript/exportScriptPages + save() inline 'tag' case (DASH-01)

### Phase 1044: Companion Machine Dimension

**Goal**: The Companion shows a machine selector; selecting a machine makes it the active context for tag catalog and dashboard list; legacy single-machine construction continues to work; machine switches are clean (no timer accumulation)
**Depends on**: Phase 1041, Phase 1042, Phase 1043
**Requirements**: MACH-01, MACH-02, MACH-03, MACH-04, MACH-05
**Success Criteria** (what must be TRUE):

  1. User can browse and free-text search the fleet's machines in the Companion at fleet scale (20+ machines, lazy-populated list)
  2. Selecting a machine makes it the active context — the tag catalog and dashboard list show that machine's tags and dashboards (the four static TagRegistry.find call sites at TagCatalogPane.m:60,205 and FastSenseCompanion.m:1616,1618 are re-pointed to the active machine object); the Companion always shows which machine is currently active
  3. Switching machines stops the previously-active dashboard's live timer before starting the new one; `timerfindall` count is stable across repeated machine switches (no accumulation)
  4. Legacy `'Registry'`/`'Dashboards'` constructor args (no Fleet) continue to work unchanged as a single implicit machine

**Plans**: 5 plans
**UI hint**: yes
Plans:
**Wave 1**

- [x] 1044-01-PLAN.md — Wave 1: Fleet.machineIds() public accessor + insertion-order Octave-flat test (MACH-01)
- [x] 1044-02-PLAN.md — Wave 1: MachineSelectorPane (TagCatalogPane copy) + filterMachines helper + flat filter tests (MACH-01)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 1044-03-PLAN.md — Wave 2: 'Fleet' NV pair + conditional [3 3]/[3 4] grid + [1 10]/[1 11] toolbar + active-machine label slot + close() detach (MACH-01/03/05)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 1044-04-PLAN.md — Wave 3: four-call-site redirect + onMachineSelected_ switch + updateActiveMachineIndicator_ + auto-select first (MACH-02/03/04)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 1044-05-PLAN.md — Wave 4: class-suite tests — ActiveContext/ActiveMachineLabel/TimerStable/LegacyUnchanged (MACH-02/03/04/05)

### Phase 1045: Cross-Machine Comparison View

**Goal**: User can build a machine-first comparison (select machines, set each machine's data, open overlay figure) with confidence-gated auto-resolution; resolved tags are cached at open time so live ticks do not degrade refresh rate
**Depends on**: Phase 1041, Phase 1042, Phase 1044
**Requirements**: CMP-01, CMP-02, CMP-03, CMP-04, CMP-05, CMP-06
**Success Criteria** (what must be TRUE):

  1. User can open a machine-first compare-builder dialog (Approach A — modeless, opens its own overlay figure via openAdHocPlot Overlay path; no changes to the 3 Companion panes or setProject), select machines, and set each machine's data either via shared-sensor quick-fill (canonical map) or a per-machine tag
  2. Each machine's series gets a distinct color stable per machine (not per selection order) and a legend label in the form `[machineName]: [sensorDisplayName]`
  3. A machine that lacks the chosen sensor shows `-- none --` and is skipped gracefully with a surfaced warning; the comparison opens with the remaining machines — no crash, no silent wrong-data substitution
  4. The builder refuses to auto-include LOW-confidence / unreviewed canonical matches — they are surfaced and require explicit per-machine confirmation; a unit mismatch on a manual substitution triggers a warning; `CanonicalMapper.resolve` is absent from the steady-state tick profile (tags resolved once at open time, cached)
  5. In the builder, user can accept auto-match, confirm a low-confidence match, pick a different local tag per machine, or skip a machine; a manual override can be promoted into the canonical map

**Plans**: 5 plans
**UI hint**: yes
Plans:
**Wave 1**

- [x] 1045-01-PLAN.md — Wave 1: CanonicalMapper.resolve + buildCompareResolution_/compareSeriesColor_ pure helpers + flat test (CMP-02/03/04/05 seam)
- [x] 1045-02-PLAN.md — Wave 1: openAdHocPlot SeriesColors/SeriesLabels NV args + legacy byte-compat + NV-arg tests (CMP-02)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 1045-03-PLAN.md — Wave 2: CompareBuilderDialog — modeless dialog shell + four-state row grid + resolve-once-at-open Open path (CMP-01/03/04/05/06)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 1045-04-PLAN.md — Wave 3: per-row Confirm + Promote (uiconfirm async, in-memory override) + theme refresh (CMP-06)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 1045-05-PLAN.md — Wave 4: fleet-mode Compare toolbar button + CompareBuilderDlg_ singleton + close() teardown + CMP class-suite tests + human-verify checkpoint (CMP-01/02/05/06)

### Phase 1046: Per-Machine Dashboard Clone/Remap — DROPPED (2026-06-17)

> **Dropped before execution.** Discussed, planned (2 plans, 2 waves), and gsd-plan-checker-VERIFIED, then cut: a programmatic-only clone API with no concrete demand; the milestone's headline value (cross-machine comparison) shipped in Phase 1045. The 1043 resolver seam remains; the 1046 CONTEXT + plans live in git history (commits `7e0477fc`, `e0803185`) if revived. The original specification is retained below for the record.

**Goal**: User can clone a dashboard from one machine onto another with tag bindings rebound via the canonical map; failed remaps are surfaced as a warnings list, never silent empty widgets
**Depends on**: Phase 1041, Phase 1042, Phase 1043, Phase 1044
**Requirements**: DASH-03, DASH-04
**Success Criteria** (what must be TRUE):

  1. User can clone a dashboard from a source machine onto a target machine; all tag bindings that resolve via the canonical map are rebound correctly to the target machine's local tags
  2. When a clone target lacks a sensor used by the source dashboard, the unresolved bindings appear in a returned warnings list (not silent empty widgets, not a crash); the cloned dashboard opens with the remaining widgets bound correctly
  3. An end-to-end round-trip passes: serialize a machine's dashboard, load it on a different machine (with machine-scoped resolver), all tags bound to the target machine's catalog

**Plans**: 2 plans (checker-VERIFIED 2026-06-17)
Plans:
**Wave 1**

- [ ] 1046-01-PLAN.md — Wave 1: CanonicalMapper.logicalIdFor reverse lookup + flat Octave-safe test (DASH-03 seam)

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 1046-02-PLAN.md — Wave 2: DashboardSerializer.cloneForMachine (target resolver + warnings + temp-json load) + TestFleetDashboardClone class-suite (DASH-03/04, A→B round-trip)

## Progress

**Execution Order:** 1041 → 1042 → 1043 → 1044 → 1045 → 1046

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1041. CanonicalMapper | 4/4 | Complete    | 2026-06-03 |
| 1042. Machine + Fleet + Pipeline DI Seam | 4/4 | Complete   | 2026-06-07 |
| 1043. DashboardSerializer Resolver Seam + Backward Compat | 3/3 | Complete   | 2026-06-07 |
| 1044. Companion Machine Dimension | 0/5 | Not started | - |
| 1045. Cross-Machine Comparison View | 0/5 | Not started | - |
| 1046. Per-Machine Dashboard Clone/Remap | 0/? | Not started | - |
