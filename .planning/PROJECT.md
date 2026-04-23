# FastSense Advanced Dashboard

## What This Is

A MATLAB sensor data dashboard engine with nested layout organization (tabs, collapsible groups, multi-page navigation), per-widget info tooltips with Markdown rendering, and detachable live-mirrored widgets that pop out as independent figure windows. Built for MATLAB engineers analyzing sensor data with threshold-based monitoring.

## Core Value

Users can organize complex dashboards into navigable sections and pop out any widget for detailed analysis without losing the dashboard context.

## Requirements

### Validated

- ✓ Widget-based dashboard composition with 20+ widget types — existing
- ✓ 24-column grid layout system — existing
- ✓ Dashboard serialization (JSON/.m export) — existing
- ✓ Theming (light/dark, custom colors) — existing
- ✓ Live data refresh via DashboardEngine timer — existing
- ✓ GroupWidget for basic widget grouping — existing
- ✓ DashboardToolbar with global controls — existing
- ✓ WebBridge for browser-based visualization — existing
- ✓ Timer error recovery (ErrorFcn + auto-restart) — v1.0
- ✓ GroupWidget .m export preserves children — v1.0
- ✓ Shared normalizeToCell helper for jsondecode normalization — v1.0
- ✓ Collapsible sections with grid reflow — v1.0
- ✓ Tab persistence through save/load — v1.0
- ✓ Widget info tooltips with Markdown rendering — v1.0
- ✓ Multi-page dashboards with PageBar navigation — v1.0
- ✓ Active page persistence through save/load — v1.0
- ✓ Detachable live-mirrored widgets — v1.0
- ✓ Independent time axis zoom on detached FastSenseWidget — v1.0
- ✓ Multi-page JSON and .m round-trip serialization — v1.0
- ✓ Collapsed state persistence — v1.0
- ✓ Legacy JSON backward compatibility — v1.0
- ✓ DividerWidget for visual dashboard section separation — v1.0 Phase 8
- ✓ addCollapsible convenience method on DashboardEngine — v1.0 Phase 8
- ✓ Configurable Y-axis limits (YLimits) on FastSenseWidget — v1.0 Phase 8
- ✓ Threshold mini-labels (ShowThresholdLabels) on FastSense and FastSenseWidget — v1.0 Phase 9
- ✓ Dashboard performance Phase 2: incremental FastSenseWidget refresh, O(1) cached time ranges, debounced slider broadcast, lazy page realization, batched switchPage, debounced resize — v2.0 Phase 1000
- ✓ First-class Threshold entities: `Threshold` handle class, `ThresholdRegistry`, preserved as concepts under v2.0 Tag model — v2.0 Phase 1001
- ✓ Direct widget-threshold binding: StatusWidget, GaugeWidget, IconCardWidget, MultiStatusWidget, ChipBarWidget bind thresholds without requiring Sensor — v2.0 Phase 1002
- ✓ Composite Thresholds: hierarchical AND/OR/MAJORITY aggregation of child thresholds — v2.0 Phase 1003
- ✓ Tag-based domain model: unified `Tag` foundation, `TagRegistry` two-phase loader, `SensorTag`/`StateTag`/`MonitorTag` (lazy + streaming + persistence)/`CompositeTag` (AND/OR/MAJORITY/COUNT/WORST/SEVERITY/USER_FN) — v2.0 Phases 1004–1011
- ✓ Event ↔ Tag binding with many-to-many `EventBinding` registry + FastSense round-marker overlay (theme-colored by severity) — v2.0 Phase 1010
- ✓ Tag ingestion pipeline: raw `.csv`/`.txt`/`.dat` → per-tag `.mat` via `BatchTagPipeline` (sync) + `LiveTagPipeline` (timer, modTime+lastIndex incremental); `SensorTag`/`StateTag` gain `RawSource` NV-pair — v2.0 Phase 1012
- ✓ Mushroom card widgets (IconCardWidget, ChipBarWidget, SparklineCardWidget) + DashboardTheme InfoColor — v2.0 Phase 999.1
- ✓ Graph data export (`.mat` / `.csv`) with NaN-filled union, ISO 8601 + datenum columns — v2.0 Phase 999.3
- ✓ Dashboard image export button (PNG/JPEG, multi-page active-page capture, live-mode no-pause) — v2.0 Phase 1004 Image Export
- ✓ MATLAB-on-every-push CI with R2020b pinning; 137 test failures from R2025b drift fixed across 6 root-cause categories — v2.0 Phase 1006
- ✓ Prebuilt MEX binaries for macOS ARM64 shipped (27 files tracked); `.mex-version` source-hash stamp gates rebuild; `refresh-mex-binaries.yml` 7-platform matrix workflow with auto-PR; 5 existing CI workflows reuse committed binaries; release tarball ships MEX — v2.0 Phase 1013 *(MATLAB-side + Windows/Linux end-user verification deferred to HUMAN-UAT)*

### Active

*(none — v2.0 shipped; next milestone to be defined via /gsd:new-milestone)*

## Current State

**Shipped:** v2.0 Tag-Based Domain Model (2026-04-23) — full milestone including Tag rewrite (Phases 1004–1011), Dashboard Performance Phase 2 (Phase 1000), First-Class Thresholds + Composites (Phases 1001–1003), Mushroom Cards + Image/Data Export (Phases 999.1, 999.3, 1004 Image), MATLAB CI fixes (Phase 1006), Tag Pipeline (Phase 1012), and Prebuilt MEX Binaries (Phase 1013).

The SensorThreshold subsystem has been fully rebooted on a unified `Tag` foundation. Legacy `Sensor`/`Threshold`/`StateChannel`/`CompositeThreshold`/`ThresholdRule`/`SensorRegistry`/`ThresholdRegistry`/`ExternalSensorRegistry` classes are deleted. All consumers (FastSenseWidget, dashboard widgets, EventDetection, LiveEventPipeline) operate through the Tag API (`addTag`, `getXY`, `valueAt`). Events bind to tags via `EventBinding` registry (many-to-many) and render as toggleable round markers in FastSense theme-colored by severity. Raw data files are ingested to per-tag `.mat` via `BatchTagPipeline` (synchronous) or `LiveTagPipeline` (timer-driven, modTime+lastIndex incremental), driven off each tag's `RawSource` struct.

Install experience: macOS ARM64 end users skip MEX compilation on fresh clone via shipped binaries gated by `.mex-version` source-hash stamp. Windows/Linux binaries land automatically via `refresh-mex-binaries.yml` auto-PR workflow.

**Vocabulary:** `Tag`, `SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `TagRegistry`, `EventBinding`, `BatchTagPipeline`, `LiveTagPipeline`, `RawSource`. FastSense API: `addTag(t)`, `ShowEventMarkers`.

**Tech debt carried into next milestone:**
- `EventDetector.detect(tag, threshold)` references deleted Threshold API — dead code
- `DashboardSerializer` `.m` export silently omits Tag-bound widgets (JSON path works)
- 93 `Threshold(` constructor refs in 42 MATLAB-only suite test files
- Phase 1013 HUMAN-UAT: MATLAB fresh-clone + Windows/Linux install verification pending
- Phase 1005 (CI coverage expansion — MATLAB+Octave full test suites on macOS/Windows) never planned
- 4 unresolved debug sessions (CI / test investigations)

**Next milestone candidates:**
- Asset hierarchy (Asset tree, templates, tag-to-asset binding, browse rollups)
- Custom event GUI (click-drag region selection in FastSense → label dialog)
- Calc tags / formula evaluator for arbitrary derived tags
- Tri-state / continuous severity MonitorTag output
- WebBridge parity for Tag API features
- v2.0 tech debt cleanup
- Full CI coverage (macOS/Windows test suites, MATLAB benchmark)

### Out of Scope

- Drag-and-drop visual rearrangement — complexity vs. value for MATLAB-script-driven workflows
- Cross-filtering between widgets — would require a data binding framework
- Interactive controls (dropdowns, sliders) — DashboardEngine is visualization, not control panel
- Browser/WebBridge parity for new features — future milestone
- GroupWidget children individual detach buttons — v1 limitation, top-level only
- Time panel in multi-page mode — works on active page only (known limitation)

## Context

- FastSense is a MATLAB library for high-performance time series visualization with sensor/threshold modeling
- Dashboard engine (`libs/Dashboard/`) has DashboardEngine, DashboardWidget (20+ types), DashboardLayout (24-col grid), DashboardSerializer, DashboardTheme, DashboardBuilder, DashboardPage, DetachedMirror, MarkdownRenderer
- v1.0 shipped: 9 phases, 24 plans, 44 requirements, 2948 lines added across 24 files
- v1.0 code review shipped: 1 phase, 4 plans, 14 bug fixes across DashboardEngine, GroupWidget, DashboardSerializer, DashboardLayout, DashboardWidget, DashboardTheme, HeatmapWidget, BarChartWidget, HistogramWidget
- v1.0 performance shipped: 1 phase, 3 plans — theme caching (getCachedTheme), containers.Map dispatch, single-pass onLiveTick, repositionPanels for resize, visibility toggle for page switch
- New classes added: DashboardPage.m, DetachedMirror.m, DividerWidget.m
- Key patterns established: central injection via realizeWidget(), ReflowCallback for layout updates, DetachCallback for widget pop-out, normalizeToCell for jsondecode safety, markRealized/markUnrealized for lifecycle encapsulation, linesForWidget for shared serialization dispatch, getCachedTheme for theme struct caching, WidgetTypeMap_ for O(1) widget dispatch
- 24,473 LOC MATLAB across libs/ (as of v1.0 completion)
- Known tech debt: 5 items (INFO-03 Markdown downgrade, missing serialization tests, single-page save edge case) — code review tech debt resolved

## Constraints

- **Tech stack**: Pure MATLAB (no external dependencies) — consistent with existing codebase
- **Backward compatibility**: Existing dashboard scripts and serialized dashboards continue to work
- **Widget contract**: Features work through the existing DashboardWidget base class interface
- **Performance**: Detached live-mirrored widgets share the engine timer, no extra timers

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Extend GroupWidget for tabs/collapsible | GroupWidget already handles widget containment | ✓ Good |
| Info tooltip via widget header icon | Minimal UI footprint, consistent placement | ✓ Good |
| Live mirror via DashboardEngine timer | Reuse existing refresh infrastructure | ✓ Good |
| Central injection via realizeWidget() | Single choke-point for all 20+ widget types | ✓ Good |
| DetachedMirror as separate class (not DashboardWidget) | Avoids grid layout interference | ✓ Good |
| Clone via toStruct/fromStruct round-trip | Works for all widget types without per-type dispatch | ✓ Good |
| containers.Map for CloseRequestFcn reference | Solves closure-over-cell-array mutation limitation | ✓ Good |
| Plain text popup (HTML stripped) over javacomponent | Cross-platform safe (Octave compatible) | ✓ Good |
| DividerWidget via uipanel not axes | Simpler, no zoom/pan interaction, cheaper render | ✓ Good |
| addCollapsible on DashboardEngine (not DashboardBuilder) | DashboardEngine owns programmatic API | ✓ Good |
| YLimits=[] for auto, [min max] for fixed | Consistent with MATLAB ylim() convention | ✓ Good |
| ShowThresholdLabels opt-in (default false) | Backward compatible; labels only when explicitly requested | ✓ Good |
| Threshold label at right edge, repositions on zoom/pan | Always visible in view, doesn't move with data | ✓ Good |
| Realized property SetAccess=private with markRealized/markUnrealized | Enforces lifecycle contract, prevents external bypass | ✓ Good |
| linesForWidget shared static helper in DashboardSerializer | Eliminates exportScript/exportScriptPages drift | ✓ Good |
| wireListeners private helper in DashboardEngine | Single listener-wiring call for both page-routed and single-page paths | ✓ Good |
| getCachedTheme with preset invalidation | Eliminates 4 redundant DashboardTheme() calls per render/switch/tick | ✓ Good |
| containers.Map widget dispatch (WidgetTypeMap_) | O(1) type lookup replacing 17-case switch; kpi alias preserved | ✓ Good |
| repositionPanels for onResize | In-place panel repositioning vs destroy+recreate; fallback to rerenderWidgets on missing handles | ✓ Good |
| switchPage visibility toggle | Hide/show panels instead of full rerender; pre-allocate all page panels at render() | ✓ Good |
| Single-pass onLiveTick with updateLiveTimeRangeFrom | One activePageWidgets() call, merged mark-dirty+refresh loop | ✓ Good |
| v2.0 reboot under unified `Tag` root (Option 2) | No-users codebase; preserves design wins from 1001-1003 as concepts; cleanest end state vs. interface-shim approach (Option 3) | ✓ Good |
| Vocabulary: `Tag` suffix on all primitives (`SensorTag`, `MonitorTag`, ...) | Trendminer-faithful; uniform mental model; `addTag()` API replaces `addSensor()` | ✓ Good |
| Single `TagRegistry` (replaces `SensorRegistry` + `ThresholdRegistry`) | One namespace, one search surface; fewer parallel singletons | ✓ Good |
| MonitorTag as full time-series signal (not current-state only) | Plottable, persistable, event-detectable; reuses existing infrastructure | ✓ Good |
| Defer asset hierarchy (D), custom event GUI (F), calc tags (G) to later milestones | Ambitious tier (A+B+C+E) is shippable on its own; D/F/G are independent additions | ✓ Good |
| MonitorTag lazy-by-default with opt-in `Persist` + `appendData` streaming | Avoids premature persistence (Pitfall 2); >5x speedup vs. full recompute for 100k-sample tails | ✓ Good |
| Zero Event ↔ Tag handle cycles; `EventBinding` is the only write side | `save → clear classes → load` round-trip works; Events decouple from Tags | ✓ Good |
| Separate `renderEventLayer_` in FastSense (not conditionals in line-render loop) | 0-event render benchmark shows no regression vs. pre-Phase-1010 baseline | ✓ Good |
| `.mex-version` source-hash stamp gates rebuild; `build_mex.m` mtime check as backstop | End users skip compilation on fresh clone when stamp matches; fallback catches stale binaries | ✓ Good |
| `.gitignore` negation allow-list for tracked MEX at designated paths only | MATLAB flat under `private/`, Octave under `octave-<platform>/` subdirs; stray `.mex*` anywhere else stays ignored | ✓ Good |
| Pin MATLAB CI to R2020b (MATLABFIX-G) | Stabilizes 137 R2025b-drift failures; reshapes A/E/F scope; predictable CI baseline | ✓ Good |
| `BatchTagPipeline` + `LiveTagPipeline` as TWO classes (not one with modes) | Clean sync vs. timer-driven separation; each with its own lifecycle and observability (`LastFileParseCount`) | ✓ Good |
| Per-tag try/catch isolation + end-of-run `TagPipeline:ingestFailed` aggregation | One bad file doesn't kill entire ingest; caller gets clear final error with all failures | ✓ Good |
| `mex_stamp.m` in public scope (`libs/FastSense/`, not `private/`) | install.m at repo root can call it directly via existing addpath chain; avoids `addpath('private')` rejection on R2025b+ | ✓ Good |
| 12 explicit Pitfall gates per v2.0 phase (PITFALLS.md) | Falsifiable file-touch budgets, semantics drift checks, render-path purity gates, golden-test sanctity — kept rewrite honest | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-23 after v2.0 Tag-Based Domain Model milestone*
