# Requirements: FastSense Advanced Dashboard — v3.0 FastSense Companion

**Defined:** 2026-04-29
**Core Value:** Users can organize complex dashboards into navigable sections and pop out any widget for detailed analysis without losing the dashboard context.

**Milestone goal:** Ship a programmatic MATLAB `uifigure`-based companion app that gives engineers a unified gateway to the dashboards and tags they've built with the FastSense library — searchable tag catalog, dashboard navigator, and ad-hoc multi-tag plotting in one window.

## Milestone v3.0 Requirements

Categories derived from the four research dimensions (Stack / Features / Architecture / Pitfalls). Engineering-practice items (listener retention, timer cleanup, error namespacing, unit-tested helpers) are baked into how every phase is built — they are referenced in phase success criteria, not tracked as separate REQ-IDs.

### Companion Shell + Project Handoff

- [x] **COMPSHELL-01**: User constructs a companion via `FastSenseCompanion('Dashboards', {d1, d2}, 'Registry', TagRegistry, 'Name', 'Line 4 Demo', 'Theme', 'dark')`; passing unknown name-value keys throws `FastSenseCompanion:unknownOption`; passing a non-`DashboardEngine` in `Dashboards` throws `FastSenseCompanion:invalidDashboard` with the offending index
- [x] **COMPSHELL-02**: Constructor opens a single `uifigure` window with a three-column `uigridlayout` (catalog left, dashboards middle, inspector right) and the chosen theme applied via `CompanionTheme`; no separate `render()` step is required
- [x] **COMPSHELL-03**: User invokes `app.close()` (or clicks the window's X) and the companion deletes its retained listeners, stops + deletes any owned timers, and closes the `uifigure` — without affecting any dashboard or ad-hoc plot figures the user opened
- [x] **COMPSHELL-04**: User invokes the constructor on Octave (`exist('OCTAVE_VERSION', 'builtin') ~= 0`) and immediately receives `FastSenseCompanion:notSupported` with a message naming the minimum MATLAB release; no `uifigure` is created; companion examples and tests are added to the Octave skip list
- [x] **COMPSHELL-05**: User calls `app.setProject(dashboards, registry)` after construction and the catalog and dashboard list rebuild against the new project; the inspector returns to welcome state; previously opened dashboard / ad-hoc figures are not affected
- [x] **COMPSHELL-06**: Companion is the only `uifigure` in the session; opened dashboards and ad-hoc plots remain classical `figure` windows (no `uifigure`/`figure` parent-mixing); companion code never references `gcf`/`gca`

### Tag Catalog

- [x] **CATALOG-01**: User types in the catalog's search field and the visible tag list updates within ~150 ms after typing stops, matching `Key`, `Name`, and `Description` (case-insensitive substring); empty search shows the full catalog
- [x] **CATALOG-02**: User clicks a filter pill (sensor / state / monitor / composite / criticality bucket) and the visible tag list narrows to tags matching the pill; multiple pills compose with logical AND across categories and OR within a category
- [x] **CATALOG-03**: User multi-selects tags via checkboxes / Ctrl+click and the selection set survives subsequent search-filter / pill changes — checking a tag, typing into the search bar, and clearing the search returns the same checked state
- [x] **CATALOG-04**: Catalog renders tags grouped by `Tag.Labels` (first label = group header); tags with empty `Labels` appear under an "Ungrouped" header
- [x] **CATALOG-05**: Catalog displays a count badge ("12 of 256 visible") and a clear-search button next to the search field; the clear button restores the full list and is keyboard-reachable
- [x] **CATALOG-06**: When `TagRegistry` is mutated externally after construction, the catalog reflects the change only after `app.refreshCatalog()` is called (snapshot-on-construct semantics; explicit refresh is the contract — no listener leak risk on a static-method registry)

### Dashboard Browser

- [x] **BROWSER-01**: Middle pane lists every `DashboardEngine` instance passed in `'Dashboards'`, showing the dashboard's `Title`, widget count, and a status dot reflecting `IsLive`
- [x] **BROWSER-02**: User clicks a dashboard row's "Open" button and the dashboard opens in its own classical figure via existing `DashboardEngine.render()`; if `render()` throws, the companion catches the error, surfaces a non-blocking `uialert`, and stays alive
- [x] **BROWSER-03**: User clicks a dashboard row (without clicking Open) and the inspector switches to the dashboard inspector state for that dashboard; `LastInteraction` flips to `'dashboard'`
- [x] **BROWSER-04**: Dashboard browser supports a single-line name search field that narrows the visible dashboard list by case-insensitive substring on `Title`
- [x] **BROWSER-05**: User invokes `app.addDashboard(d)` or `app.removeDashboard(key)` and the dashboard list updates immediately without rebuilding the entire window; dropped dashboards no longer appear in the inspector if the inspector was on that dashboard

### Inspector

- [x] **INSPECT-01**: With nothing selected the inspector shows the welcome state (project name, tag/dashboard counts, a hint explaining the affordances of the three panes)
- [x] **INSPECT-02**: User selects exactly one tag in the catalog and the inspector switches to single-tag detail showing `Key`, `Name`, `Units`, `Description`, `Criticality`, threshold rules (if `SensorTag` / `MonitorTag`), a sparkline preview rendered via `axes(uipanel)` (NOT `uiaxes(uipanel)`), and an "Open Detail" button that opens a `SensorDetailPlot` in its own figure
- [x] **INSPECT-03**: User selects exactly one dashboard in the browser (without clicking Open) and the inspector switches to dashboard inspector showing `Title`, widget count, referenced tags, current `LiveInterval`, and per-dashboard `▶ Play` / `⏸ Pause` buttons that call `d.startLive()` / `d.stopLive()`
- [x] **INSPECT-04**: User selects ≥2 tags in the catalog and the inspector switches to the plot composer state (specified under ADHOC); checking/unchecking tags updates the composer's tag list in place
- [x] **INSPECT-05**: Inspector mode flips by most-recent click — selecting tags after a dashboard click moves the inspector back to tag detail; `LastInteraction` is the routing rule
- [x] **INSPECT-06**: An exception thrown inside any inspector callback (sparkline render error, dashboard accessor failure, etc.) is caught, surfaced via non-blocking `uialert(obj.hFig_, ...)`, and does not crash the companion or any open figure

### Ad-Hoc Plot Composer

- [x] **ADHOC-01**: With ≥2 tags selected, the composer shows a tag chip list, an "Overlay / Linked grid" mode toggle, and a "Plot" CTA button
- [x] **ADHOC-02**: User picks "Overlay" + Plot → companion opens a classical figure containing a single `FastSense` instance with one `addLine` per selected tag; line colors come from `CompanionTheme`
- [x] **ADHOC-03**: User picks "Linked grid" + Plot → companion opens a classical figure containing a `FastSenseGrid` with one tile per selected tag; tiles share the figure but `LinkGroup` wiring is deferred to a future milestone (tiles render with independent x-axes for v3.0)
- [x] **ADHOC-04**: Spawned ad-hoc plot figures are independent of the companion — closing a plot figure does not affect the companion or other plots; closing the companion does not auto-close ad-hoc plots already open
- [x] **ADHOC-05**: Ad-hoc plots render the full available range of each tag (no time-range presets in v3.0); user can zoom/pan in the figure for sub-range exploration

### Industrial Plant Demo Integration

- [x] **COMPDEMO-01**: User runs `install(); ctx = run_demo();` from a clean MATLAB session and the returned `ctx` includes a `companion` field — a live `FastSenseCompanion` handle wrapping the demo's `TagRegistry` (populated by `registerPlantTags`) and the demo's `DashboardEngine` (built by `buildDashboard`); the companion window opens alongside the existing 6-page dashboard
- [x] **COMPDEMO-02**: User invokes `run_demo('Companion', false)` and the demo runs as before with no companion window; this preserves backward-compatibility for callers / tests that only need the dashboard
- [ ] **COMPDEMO-03**: Companion's tag catalog visibly groups plant tags by their `Tag.Labels` (e.g., `area:reactor`, `area:feed_line`, `area:cooling`); user can multi-select across areas and spawn an ad-hoc plot figure that lives independently of dashboard + companion
- [x] **COMPDEMO-04**: `teardownDemo(ctx)` closes the companion if its handle is still valid; running the demo and then closing both dashboard + companion leaves zero orphan companion-owned timers in `timerfindall` (verifiable via integration test or a documented manual smoke step)

## Future Requirements

### v3.x candidates (deferred from v3.0 scoping)

- **CATALOG-07** (deferred): "Used in dashboards" cross-reference — selecting a tag highlights the dashboards in the middle pane that reference it; cached as a `containers.Map(tagKey -> dashboardIndices)` rebuilt on `setProject` / `addDashboard` / `removeDashboard`
- **ADHOC-06** (deferred): Time-range presets (All / Last 1h) on the plot composer — preset buttons feed start/end into the spawned plot
- **ADHOC-07** (deferred): Live tick toggle (Off / 2 s / 5 s) on the plot composer — companion-owned `timer` per ad-hoc figure that calls `tag.getXY()` and updates the open plot; timer stop+delete on figure close; `AdHocTimers_` map on the orchestrator with prune pass
- **ADHOC-08** (deferred): `LinkGroup` wiring on spawned `FastSenseGrid` — fresh `LinkGroup` per spawned grid so x-axis pan/zoom is synced across tiles
- **BROWSER-06** (deferred): Live indicator dot per dashboard row reflecting `IsLive` in real time
- **BROWSER-07** (deferred): Global "Pause All" toolbar toggle that calls `stopLive()` on every dashboard and stops every ad-hoc live timer

### v3.x candidates (not yet scheduled)

- **CATALOG-08** (deferred): Recently-selected ring buffer (session-scoped, last 5 tags) accessible via a "Recent" pill
- **INSPECT-07** (deferred): Inline embedded `SensorDetailPlot` inside the inspector pane (rather than opening it in its own figure) — gated on the empirical resize test flagged in research
- **COMPSHELL-07** (deferred): Octave fallback path (`uipanel` + `SizeChangedFcn` + `uicontrol`) so Octave engineers get a degraded but functional companion window

## Out of Scope

The following are explicitly excluded from v3.0 *and* from any post-v3.0 milestone unless reopened:

- **Dashboard authoring or editing inside the companion** — the companion is a viewer/launcher; users author dashboards via FastSense library scripts and `DashboardEngine.addWidget` calls. Reason: avoids duplicating `DashboardBuilder` UX in a second surface; keeps the companion focused on navigation
- **Custom time-range picker for ad-hoc plots** — only presets (when ADHOC-06 ships) and figure-level zoom are supported. Reason: presets cover ≥90% of cases; custom picker is a separate feature surface that adds complexity disproportionate to its value
- **Persisting companion state across MATLAB sessions** — selection, search, and pane state are session-scoped; closing the window discards them. Reason: state is fast to recreate from the project script; persistence introduces save-format compatibility burden
- **Multi-project switcher** — one project per companion window. Reason: users wanting two projects open in parallel can construct two `FastSenseCompanion` instances; switcher would re-implement window management for marginal value
- **Detachable companion panes** — the three panes are fixed. Reason: deviates from the "single control panel" mental model; opening dashboards/ad-hoc plots in separate figures already gives users multi-window flexibility
- **Status strip with global live KPIs** — no top-of-window strip showing system-wide violation count, live tick, last refresh time. Reason: dashboards each carry their own live state; a global strip implies global aggregation that the companion does not own
- **WebBridge integration** — companion is pure MATLAB; the existing WebBridge surface is independent. Reason: companion explicitly chose a MATLAB-native UI; bridging to the web surface is a different milestone
- **Modifying existing libraries** beyond a single optional 3-line additive `DashboardEngine.getWidgets()` accessor — no behavioral changes to `DashboardEngine`, `Tag`, `TagRegistry`, `FastSense`, `FastSenseGrid`, or `SensorDetailPlot`. Reason: backward compatibility is a project-level constraint

## Traceability

| REQ-ID | Phase | Plan |
|--------|-------|------|
| COMPSHELL-01 | Phase 1018 | _TBD_ |
| COMPSHELL-02 | Phase 1018 | _TBD_ |
| COMPSHELL-03 | Phase 1018 | _TBD_ |
| COMPSHELL-04 | Phase 1018 | _TBD_ |
| COMPSHELL-05 | Phase 1018 | _TBD_ |
| COMPSHELL-06 | Phase 1018 | _TBD_ |
| CATALOG-01 | Phase 1019 | _TBD_ |
| CATALOG-02 | Phase 1019 | _TBD_ |
| CATALOG-03 | Phase 1019 | _TBD_ |
| CATALOG-04 | Phase 1019 | _TBD_ |
| CATALOG-05 | Phase 1019 | _TBD_ |
| CATALOG-06 | Phase 1019 | _TBD_ |
| BROWSER-01 | Phase 1020 | _TBD_ |
| BROWSER-02 | Phase 1020 | _TBD_ |
| BROWSER-03 | Phase 1020 | _TBD_ |
| BROWSER-04 | Phase 1020 | _TBD_ |
| BROWSER-05 | Phase 1020 | _TBD_ |
| INSPECT-01 | Phase 1021 | _TBD_ |
| INSPECT-02 | Phase 1021 | _TBD_ |
| INSPECT-03 | Phase 1021 | _TBD_ |
| INSPECT-04 | Phase 1021 | _TBD_ |
| INSPECT-05 | Phase 1021 | _TBD_ |
| INSPECT-06 | Phase 1021 | _TBD_ |
| ADHOC-01 | Phase 1022 | _TBD_ |
| ADHOC-02 | Phase 1022 | _TBD_ |
| ADHOC-03 | Phase 1022 | _TBD_ |
| ADHOC-04 | Phase 1022 | _TBD_ |
| ADHOC-05 | Phase 1022 | _TBD_ |

---
*v3.0 requirements defined: 2026-04-29*
*Predecessor: REQUIREMENTS-v2.1.md (in-flight tech-debt cleanup, parallel)*
