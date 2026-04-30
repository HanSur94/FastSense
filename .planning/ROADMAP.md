# Roadmap: FastSense Advanced Dashboard

## Milestones

- ✅ **v1.0 FastSense Advanced Dashboard** — Phases 1-9 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Engine Code Review Fixes** — Phase 1 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Performance Optimization** — Phase 1 (shipped 2026-04-04)
- ✅ **v1.0 First-Class Thresholds & Composites** — Phases 1000-1003 (shipped 2026-04-15)
- ✅ **v2.0 Tag-Based Domain Model** — Phases 1004-1011 (shipped 2026-04-17)
- 📋 **v2.1 Tag-API Tech Debt Cleanup** — Phases 1012-1017 (carry-forward, parallel — not active)
- 🚧 **v3.0 FastSense Companion** — Phases 1018-1022 (active milestone, started 2026-04-29)

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
<summary>✅ v2.0 Tag-Based Domain Model (Phases 1004-1011) — SHIPPED 2026-04-17</summary>

- [x] Phase 1004: Tag Foundation + Golden Test
- [x] Phase 1005: SensorTag + StateTag (data carriers)
- [x] Phase 1006: MonitorTag (lazy, in-memory)
- [x] Phase 1007: MonitorTag streaming + persistence
- [x] Phase 1008: CompositeTag
- [x] Phase 1009: Consumer migration (one widget at a time)
- [x] Phase 1010: Event ↔ Tag binding + FastSense overlay
- [x] Phase 1011: Cleanup — collapse parallel hierarchy + delete legacy

Full details: [milestones/v2.0-ROADMAP.md](milestones/v2.0-ROADMAP.md)

</details>

<details>
<summary>🚧 v2.1 Tag-API Tech Debt Cleanup (Phases 1012-1017) — in flight</summary>

- [x] Phase 1012: Migrate examples to Tag API
- [x] Phase 1013: Dead code deletion — EventDetector, IncrementalEventDetector, EventConfig
- [x] Phase 1014: DashboardSerializer .m export for Tag-bound widgets
- 🚧 Phase 1017: Tag system event auto-wiring — registry default EventStore, dual-key emission

</details>

### v3.0 FastSense Companion — Phases 1018-1022 (active)

- [x] **Phase 1018: Companion Shell + Project Handoff** — `uifigure` skeleton, `CompanionTheme`, constructor API, Octave guard, `close()` lifecycle, `setProject()`, figure/uifigure boundary discipline (completed 2026-04-29)
- [x] **Phase 1019: Tag Catalog** — `TagCatalogPane` with debounced search, filter pills, label grouping, multi-select with persistence, count badge, `refreshCatalog()` (completed 2026-04-29)
- [x] **Phase 1020: Dashboard Browser** — `DashboardListPane` with name search, Open button, `addDashboard`/`removeDashboard`, dashboard inspector routing (completed 2026-04-29)
- [x] **Phase 1021: Inspector** — `InspectorPane` with four states (welcome / single-tag / dashboard / multi-tag composer routing), sparkline preview, `SensorDetailPlot` integration, per-dashboard play/pause (completed 2026-04-30)
- [x] **Phase 1022: Ad-Hoc Plot Composer** — `FastSense` overlay and `FastSenseGrid` linked grid spawning from selected tags, independent figure lifecycle, figure-close cleanup (completed 2026-04-30)
- [x] **Phase 1023: Industrial Plant Demo Integration** — extend `demo/industrial_plant/run_demo.m` to launch a `FastSenseCompanion` over the demo's populated `TagRegistry` + the 6-page `DashboardEngine`; demo doubles as the milestone canary (completed 2026-04-30)

## Phase Details

### Phase 1018: Companion Shell + Project Handoff
**Goal**: Engineers can construct a fully-themed, properly-closed companion window that accepts dashboards and a tag registry, guards against Octave, and cleans up all resources on close — with no UI features yet but all structural constraints locked in.
**Depends on**: Nothing (new library `libs/FastSenseCompanion/`)
**Requirements**: COMPSHELL-01, COMPSHELL-02, COMPSHELL-03, COMPSHELL-04, COMPSHELL-05, COMPSHELL-06
**Success Criteria** (what must be TRUE):
  1. User calls `FastSenseCompanion('Dashboards', {d1, d2}, 'Registry', reg, 'Name', 'Demo', 'Theme', 'dark')` and a single themed `uifigure` with a three-column `uigridlayout` opens immediately — no separate `render()` call required
  2. Passing an unknown name-value key or a non-`DashboardEngine` entry throws the correct namespaced error (`FastSenseCompanion:unknownOption` or `FastSenseCompanion:invalidDashboard`) with the offending index in the message
  3. User calls `app.close()` (or clicks the window X) and `timerfindall` shows no companion-owned timers remain; no dashboard or ad-hoc figure is closed as a side effect
  4. User runs the constructor under Octave and receives `FastSenseCompanion:notSupported` before any `uifigure` is created; companion tests are in the Octave skip list
  5. User calls `app.setProject(newDashboards, newReg)` and the three pane panels visibly reset to blank/welcome state without recreating the `uifigure`
  6. `grep -n 'gcf\|gca' libs/FastSenseCompanion/` returns zero hits — companion never calls `gcf`/`gca`; all spawned dashboard/ad-hoc figures are classical `figure` windows
**Plans**: 3 plans
Plans:
- [x] 1018-01-PLAN.md — Library scaffolding: CompanionTheme, three pane stubs, install.m path entry
- [x] 1018-02-PLAN.md — FastSenseCompanion orchestrator: constructor, close/delete, setProject, Octave guard
- [x] 1018-03-PLAN.md — Tests: function-based smoke (test_companion_shell.m) + class-based suite (TestFastSenseCompanion.m)
**UI hint**: yes

### Phase 1019: Tag Catalog
**Goal**: Engineers can browse, search, filter, and multi-select tags from the registry in the left pane, with their selection surviving filter changes and the catalog refreshable on demand.
**Depends on**: Phase 1018 (companion shell with left-pane panel)
**Requirements**: CATALOG-01, CATALOG-02, CATALOG-03, CATALOG-04, CATALOG-05, CATALOG-06
**Success Criteria** (what must be TRUE):
  1. User types a substring in the search field and the visible tag list narrows within ~150 ms (debounced), matching `Key`, `Name`, and `Description` case-insensitively; clearing the field restores the full list via the keyboard-reachable clear button
  2. User clicks one or more filter pills (by tag kind or criticality) and the list narrows; multiple pills compose AND across categories and OR within a category; the count badge ("12 of 256 visible") updates on every filter change
  3. User checks three tags, types a search that hides two of them, then clears the search — the same three tags remain checked (selection set is separate from `uilistbox.Value`)
  4. Tags are grouped by their first `Tag.Labels` entry; tags with no labels appear under an "Ungrouped" header
  5. User calls `app.refreshCatalog()` after adding tags to the registry externally, and the catalog reflects the new tags; prior to that call the catalog shows the snapshot taken at construction (no listener-leak risk)
**Plans**: 3 plans
Plans:
- [x] 1019-01-PLAN.md — Pure-logic helpers (filterTags, groupByLabel) + Octave-compatible unit tests
- [x] 1019-02-PLAN.md — TagCatalogPane full implementation + FastSenseCompanion attach/refreshCatalog updates
- [x] 1019-03-PLAN.md — Class-based test suite TestTagCatalogPane (CATALOG-01..06 coverage)
**UI hint**: yes

### Phase 1020: Dashboard Browser
**Goal**: Engineers can see all dashboards passed to the companion, open any one in its own figure window, search by name, and add or remove dashboards dynamically — without breaking inspector state for unaffected dashboards.
**Depends on**: Phase 1018 (companion shell with middle-pane panel)
**Requirements**: BROWSER-01, BROWSER-02, BROWSER-03, BROWSER-04, BROWSER-05
**Success Criteria** (what must be TRUE):
  1. Middle pane lists every `DashboardEngine` with its `Title`, widget count, and an `IsLive` status dot; clicking a row (not the Open button) routes the inspector to the dashboard inspector state
  2. User clicks "Open" on a dashboard row and the dashboard renders in its own classical `figure` window via `DashboardEngine.render()`; if `render()` throws, a non-blocking `uialert` surfaces the error and the companion stays alive
  3. User types in the name search field and the dashboard list narrows by case-insensitive substring on `Title`; clearing the field restores the full list
  4. User calls `app.addDashboard(d)` and the new dashboard appears in the list immediately; `app.removeDashboard(key)` removes it and returns the inspector to welcome state if that dashboard was being inspected
**Plans**: 3 plans
Plans:
- [x] 1020-01-PLAN.md — Pure helper filterDashboards + DashboardEventData payload class + unit tests
- [x] 1020-02-PLAN.md — DashboardListPane full implementation + FastSenseCompanion addDashboard/removeDashboard + listener wiring
- [x] 1020-03-PLAN.md — Class-based test suite TestDashboardListPane (BROWSER-01..05) + TestFastSenseCompanion augmentation
**UI hint**: yes

### Phase 1021: Inspector
**Goal**: Engineers get an adaptive right-pane inspector that shows a contextual view for whatever they last selected — welcome state by default, single-tag detail with sparkline and Open Detail button, dashboard summary with play/pause, or a routing handoff to the plot composer when multiple tags are selected.
**Depends on**: Phase 1019 (tag selection events), Phase 1020 (dashboard selection events)
**Requirements**: INSPECT-01, INSPECT-02, INSPECT-03, INSPECT-04, INSPECT-05, INSPECT-06
**Success Criteria** (what must be TRUE):
  1. With nothing selected, inspector shows welcome state: project name, tag/dashboard counts, and a hint describing the three panes
  2. User selects exactly one tag and inspector shows single-tag detail: `Key`, `Name`, `Units`, `Description`, `Criticality`, threshold rules (if applicable), a sparkline rendered via `axes(uipanel)` (not `uiaxes`), and an "Open Detail" button that opens `SensorDetailPlot` in its own classical figure
  3. User selects exactly one dashboard (by clicking its row, not Open) and inspector shows dashboard summary: `Title`, widget count, referenced tags, `LiveInterval`, and `Play`/`Pause` buttons that call `d.startLive()`/`d.stopLive()` on the engine
  4. User selects 2+ tags and inspector routes to the plot composer state (ADHOC-01 rendering — tag chip list, mode toggle, Plot button); the state tracks the selection so adding or removing a checked tag updates the chip list in place
  5. Selecting tags after clicking a dashboard row moves inspector back to tag-detail state; `LastInteraction` is the routing rule and flips correctly in both directions
  6. An exception thrown inside any inspector callback (sparkline render, dashboard accessor, etc.) is caught, surfaced via non-blocking `uialert`, and does not crash the companion or any open figure
**Plans**: 4 plans
Plans:
- [x] 1021-01-PLAN.md — Pure helper inspectorResolveState + InspectorStateEventData + AdHocPlotEventData payload classes + unit tests
- [x] 1021-02-PLAN.md — TagCatalogPane public-API additions (getSelectedKeys, deselectKey) + FastSenseCompanion events/cache/resolveInspectorState_ + listener wiring + extended InspectorPane.attach signature
- [x] 1021-03-PLAN.md — Full InspectorPane implementation: 4-state machine (welcome/tag/dashboard/multitag), sparkline via axes(uipanel), threshold list, referenced-tags walker, Play/Pause, chip list, mode toggle, Plot CTA
- [x] 1021-04-PLAN.md — Class-based test suites: TestInspectorPane (INSPECT-01..06) + augment TestFastSenseCompanion (event firing tests) + augment TestTagCatalogPane (getSelectedKeys/deselectKey)
**UI hint**: yes

### Phase 1022: Ad-Hoc Plot Composer
**Goal**: Engineers can spawn independent multi-tag plots from the inspector's composer state — either as a single overlay `FastSense` figure or a `FastSenseGrid` tiled figure — and those figures have clean independent lifecycles: closing a plot does not affect the companion, and closing the companion does not auto-close open plots.
**Depends on**: Phase 1021 (composer state wired into inspector; multi-tag selection routing established)
**Requirements**: ADHOC-01, ADHOC-02, ADHOC-03, ADHOC-04, ADHOC-05
**Success Criteria** (what must be TRUE):
  1. With 2+ tags selected, composer shows tag chip list, Overlay/Linked-grid mode toggle, and a "Plot" CTA button
  2. User picks Overlay + Plot and a classical `figure` opens with a single `FastSense` instance containing one `addLine` per selected tag with theme-consistent colors; the companion remains open and interactive
  3. User picks Linked grid + Plot and a classical `figure` opens with a `FastSenseGrid` containing one tile per selected tag; tiles render with independent x-axes (LinkGroup wiring deferred to v3.x per ADHOC-08)
  4. After spawning plots, user closes one plot figure — the companion is unaffected and the remaining plots stay open; after closing the companion, previously-spawned plot figures remain open and fully functional
  5. Ad-hoc plots render the full available range of each tag; user can zoom/pan in the figure for sub-range exploration; `timerfindall` after closing all spawned figures shows no orphan companion-owned timers
**Plans**: 3 plans
Plans:
- [x] 1022-01-PLAN.md — openAdHocPlot private helper: Overlay + LinkedGrid figure factory with per-tag failure tolerance
- [x] 1022-02-PLAN.md — FastSenseCompanion orchestrator: onOpenAdHocPlotRequested_ listener + addlistener wiring in constructor + setProject
- [x] 1022-03-PLAN.md — Tests: helper unit suite (runOpenAdHocPlotTests) + MockPlottableTag fixture + TestFastSenseCompanion ADHOC end-to-end (lifecycle + orphan-timer)
**UI hint**: yes

### Phase 1023: Industrial Plant Demo Integration
**Goal**: The existing `demo/industrial_plant/` runnable demo gains an opt-in `FastSenseCompanion` window that wraps its already-populated `TagRegistry` and `DashboardEngine`, so a single `run_demo()` invocation gives engineers the dashboard window + the companion side-by-side as a milestone canary.
**Depends on**: Phases 1018–1022 (full companion functional). No new tag/dashboard authoring needed — the demo is already on the Tag-API.
**Requirements**: COMPDEMO-01, COMPDEMO-02, COMPDEMO-03, COMPDEMO-04
**Success Criteria** (what must be TRUE):
  1. User runs `install(); ctx = run_demo();` and the existing 6-page dashboard opens as today; the returned `ctx` now also carries a `companion` field — a live `FastSenseCompanion` handle whose tag catalog reflects the demo's `TagRegistry` (every `SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag` registered by `registerPlantTags`) and whose dashboard list contains the demo's single `DashboardEngine`
  2. Companion window opens by default but can be suppressed with `run_demo('Companion', false)`; closing the dashboard via its `CloseRequestFcn` also closes the companion (and vice versa is OK — closing the companion does NOT close the dashboard, matching ADHOC-04 lifecycle rules)
  3. Companion's tag catalog visibly groups the plant's tags by their `Tag.Labels` categories (`area:reactor`, `area:feed_line`, `area:cooling`, etc. — whatever `registerPlantTags` actually sets); the user can multi-select tags from across areas and ad-hoc plot them in a fresh figure that lives independently of dashboard + companion
  4. `teardownDemo(ctx)` is updated to also call `ctx.companion.close()` if the companion handle is still valid; running the demo + closing both windows leaves zero orphan timers in `timerfindall` (verifiable by an integration test or a documented manual smoke step)
**Plans**: 2 plans
Plans:
- [x] 1023-01-PLAN.md — Wire-in: buildCompanion private helper + run_demo Companion name-value option + teardownDemo close cascade + buildDashboard demoClose_ cascade
- [x] 1023-02-PLAN.md — TestIndustrialPlantDemoCompanion class-based suite covering COMPDEMO-01..04 against real demo
**UI hint**: yes — demo is a runtime UI smoke test of the whole companion against real plant tags + a real dashboard

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-9 | v1.0 Advanced Dashboard | 24/24 | Complete | 2026-04-03 |
| 01. Code Review Fixes | v1.0 Code Review | 4/4 | Complete | 2026-04-03 |
| 01. Performance Optimization | v1.0 Performance | 3/3 | Complete | 2026-04-04 |
| 1000-1003 | v1.0 First-Class Thresholds | 14/14 | Complete | 2026-04-15 |
| 1004. Tag Foundation + Golden Test | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1005. SensorTag + StateTag | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1006. MonitorTag (lazy, in-memory) | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1007. MonitorTag streaming + persistence | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1008. CompositeTag | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1009. Consumer migration | v2.0 | 4/4 | Complete | 2026-04-17 |
| 1010. Event ↔ Tag binding + overlay | v2.0 | 3/3 | Complete | 2026-04-17 |
| 1011. Cleanup + delete legacy | v2.0 | 5/5 | Complete | 2026-04-17 |
| 1012. Migrate examples to Tag API | v2.1 | 10/10 | Complete | — |
| 1013. Dead code deletion | v2.1 | — | Complete | — |
| 1014. DashboardSerializer .m export | v2.1 | 1/1 | Complete | — |
| 1017. Tag system event auto-wiring | v2.1 | 0/? | In progress | — |
| 1018. Companion Shell + Project Handoff | v3.0 | 3/3 | Complete    | 2026-04-29 |
| 1019. Tag Catalog | v3.0 | 3/3 | Complete    | 2026-04-29 |
| 1020. Dashboard Browser | v3.0 | 3/3 | Complete   | 2026-04-29 |
| 1021. Inspector | v3.0 | 4/4 | Complete   | 2026-04-30 |
| 1022. Ad-Hoc Plot Composer | v3.0 | 3/3 | Complete   | 2026-04-30 |
