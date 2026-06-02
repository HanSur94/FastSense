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

### Active

- ✓ Dashboard performance optimization: theme caching, O(1) widget dispatch, single-pass live tick, in-place resize, visibility page switch — v1.0 Performance
- ✓ Tag-based domain model: unified `Tag` foundation, `TagRegistry`, `MonitorTag` derived time-series, `CompositeTag` aggregation — v2.0
- ✓ Events attached to tags with FastSense overlay rendering — v2.0

## Current State

**Shipped:** v2.0 Tag-Based Domain Model (2026-04-17); v3.0 FastSense Companion (2026-04-30); v4.0 Multi-User LAN Concurrency (verifying, 2026-06-02)

The SensorThreshold subsystem has been fully rebooted on a unified `Tag` foundation. Legacy `Sensor`/`Threshold`/`StateChannel`/`CompositeThreshold` classes are deleted. All consumers (FastSenseWidget, dashboard widgets, EventDetection, LiveEventPipeline) operate through the Tag API (`addTag`, `getXY`, `valueAt`). Events bind to tags via `EventBinding` registry and render as toggleable round markers in FastSense. All `examples/` scripts have been migrated to the Tag API and a dedicated 5-script showcase lives under `examples/02-sensors/tags/`.

**Vocabulary:** `SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `TagRegistry`, `EventBinding`. FastSense API: `addTag(t)`.

**Companion (Phase 1040, 2026-06-02):** the FastSenseCompanion **Event Viewer** now hosts an acknowledgeable notification inbox (`NotificationCenterPane`) as a horizontally-resizable right panel (draggable divider); a toolbar **bell** shows the unacked count + highest-severity color and opens the viewer. Dismiss == shared, audited `EventStore.acknowledgeEvent`.

## Current Milestone: v5.0 Multi-Machine Fleet

**Goal:** Ingest, browse, dashboard, and compare data across a growing fleet of near-identical machines from the FastSense Companion — including overlaying the same logical sensor across machines whose sensor keys differ.

**Target features:**
- Fleet/Machine data model — new `libs/Fleet/`: `Machine` (own isolated tag catalog + `DataRoot` + dashboards + ingestion, mirrors `TagRegistry` read API) and `Fleet` (searchable machines + config persistence). Global `TagRegistry` singleton left untouched.
- Per-machine ingestion — existing `BatchTagPipeline`/`LiveTagPipeline` scoped per machine (own `DataRoot`); default global-registry path unchanged (backward compatible).
- Canonical/logical-sensor mapping — automated rules + overrides + unmapped/ambiguous-tail surfacing; bridges differing keys across machines and scales to 20+/growing fleets.
- Companion machine dimension — searchable machine selector; selecting a machine reuses the existing `setProject(machine.Dashboards, machine)`; legacy `Registry`/`Dashboards` constructor args still work (single implicit machine).
- Per-machine dashboards + clone/remap — hand-built, independent per machine; clone a dashboard onto another machine with tag bindings rebound via the canonical map; `DashboardSerializer` gains a machine-scoped resolver.
- Cross-machine comparison view — pick a logical sensor → overlay its series across selected machines (reuses `openAdHocPlot` Overlay mode, pulling Tag objects from each machine's catalog).

**Key decisions carried in (from in-session brainstorm):**
- Data model = Approach ① (Machine/Fleet layer). `TagRegistry` is static-only (a `persistent` map, 72 static call sites across 31 files) so it cannot be instanced — each `Machine` owns its own `containers.Map` instead, leaving the global registry and all existing single-machine usage untouched.
- The one existing-code seam: `DashboardSerializer` must resolve `(machineId, localKey)` via Fleet→Machine instead of the global `TagRegistry.get` when (de)serializing a machine's tag-bound dashboards. Runtime widget resolution is unaffected (widgets hold Tag objects).

**Deferred:**
- Exact machine-selector placement (left rail vs top dropdown vs tabs) and comparison-view layout — resolved in a dedicated UI phase.
- WebBridge parity for fleet features.
- Cross-machine MonitorTag/event rollups and fleet-wide background monitoring (builds on v4.0 concurrency + Phase 1039/1040 monitoring; not in this milestone).

### Out of Scope

- Forced dashboard templating across machines — user chose hand-built, independent per-machine dashboards (clone/remap tooling instead).
- Refactoring `TagRegistry` to be instantiable (Approach ③) — rejected for backward-compat risk to 72 call sites.
- Namespaced compound keys in the global registry (Approach ②) — rejected for key-sprawl and forced per-machine filtering everywhere.
- Drag-and-drop visual rearrangement, cross-widget filtering, interactive controls — unchanged from prior milestones (DashboardEngine is visualization, not control panel).

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
| v2.0 reboot under unified `Tag` root (Option 2) | No-users codebase; preserves design wins from 1001-1003 as concepts; cleanest end state vs. interface-shim approach (Option 3) | Pending v2.0 |
| Vocabulary: `Tag` suffix on all primitives (`SensorTag`, `MonitorTag`, ...) | Trendminer-faithful; uniform mental model; `addTag()` API replaces `addSensor()` | Pending v2.0 |
| Single `TagRegistry` (replaces `SensorRegistry` + `ThresholdRegistry`) | One namespace, one search surface; fewer parallel singletons | Pending v2.0 |
| MonitorTag as full time-series signal (not current-state only) | Plottable, persistable, event-detectable; reuses existing infrastructure | Pending v2.0 |
| Defer asset hierarchy (D), custom event GUI (F), calc tags (G) to later milestones | Ambitious tier (A+B+C+E) is shippable on its own; D/F/G are independent additions | Pending v2.0 |

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
*Last updated: 2026-06-02 — Milestone v5.0 Multi-Machine Fleet started*
