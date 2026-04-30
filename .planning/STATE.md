---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: FastSense Companion
status: executing
last_updated: "2026-04-30T08:23:44.289Z"
last_activity: 2026-04-30
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 16
  completed_plans: 15
---

# State

## Current Position

Phase: 1022 (Ad-Hoc Plot Composer) — EXECUTING
Plan: 3 of 3
Status: Ready to execute
Last activity: 2026-04-30
Last session: 2026-04-30T08:23:44.282Z

## Progress Bar

```
v3.0 FastSense Companion
Phase 1018 [██████████] 100% (3/3 plans complete in Phase 1018; 1/6 phases complete overall)
Phase 1019 [██████████] 100% (3/3 plans complete in Phase 1019; 6/6 plans complete overall)
```

## Accumulated Context

### Roadmap Evolution

- 2026-04-29 — Milestone v3.0 FastSense Companion started (programmatic MATLAB uifigure companion app; design brainstormed prior; v2.1 Tag-API Tech Debt Cleanup carried forward in parallel)
- 2026-04-29 — v3.0 roadmap created: 5 phases (1018-1022) covering 28 REQ-IDs across COMPSHELL, CATALOG, BROWSER, INSPECT, ADHOC categories
- 2026-04-29 — v3.0 phase 1023 added (Industrial Plant Demo Integration): wraps `demo/industrial_plant/run_demo.m` in `FastSenseCompanion`; 4 new COMPDEMO REQ-IDs; total now 6 phases / 32 REQ-IDs

### Phase Numbering Note

v2.1 phases in the phases/ directory extend to 1017 (1012, 1013, 1014, 1017). v3.0 phases start at 1018 to avoid collision.

### Brainstorm Outcomes (v3.0)

Design decisions locked during the v3.0 brainstorm conversation (2026-04-29):

- **Scope:** A + B + C combined — library browser + live monitoring + tag-first explorer. **Not** D (no in-app dashboard authoring/editing).
- **UI tech:** Programmatic `uifigure` (no App Designer, no `.mlapp`).
- **Connection contract:** Loose handoff via constructor: `FastSenseCompanion('Dashboards', {d1, d2}, 'Registry', TagRegistry)`. Tags pulled from `TagRegistry` singleton by default; pass `'Registry', reg` to override. Single project per app instance (no multi-project switcher).
- **Dashboard rendering:** Opening a dashboard pops it into its own MATLAB figure via existing `DashboardEngine.render()`. Companion is purely a control panel / navigator. Zero changes required to `DashboardEngine`.
- **Layout:** Three-pane window — left = searchable tag catalog with multi-select checkboxes and filter pills; middle = dashboard list; right = adaptive inspector.
- **Inspector states:** `welcome` (empty) / `tag` (single tag selected — metadata, thresholds, "used in" cross-references, "Plot this tag" → `SensorDetailPlot`) / `multitag` (N>1 — plot composer with Linked grid / Overlay, time range All / Last 1h, Live Off/2s/5s) / `dashboard` (dashboard tile selected — summary + open + live toggle). Most-recent click wins (`LastInteraction = 'tags' | 'dashboard'`).
- **Tag grouping:** Derived from `Tag.Labels` (existing property; no new model field). Filter pills also reflect `Tag.Criticality`.
- **Ad-hoc plotting modes:** Linked grid (`FastSenseGrid` with shared `LinkGroup`) and Overlay (single `FastSense` instance with multiple lines). Dropped "Separate figures" as YAGNI.
- **Live refresh:** Companion does **not** own a refresh timer for dashboards — uses each `DashboardEngine`'s own `LiveInterval` and start/stop. For ad-hoc plots, companion runs a `timer` that calls `tag.getXY()` and `updateData()` on the open figure; timer stored on figure `UserData`, stops on figure close.
- **File structure:**
  - `libs/FastSenseCompanion/FastSenseCompanion.m` (orchestrator, public API)
  - `libs/FastSenseCompanion/TagCatalogPane.m` (left pane)
  - `libs/FastSenseCompanion/DashboardListPane.m` (middle pane)
  - `libs/FastSenseCompanion/InspectorPane.m` (right pane)
  - `libs/FastSenseCompanion/CompanionTheme.m` (static color/font helper, mirrors `DashboardTheme`)
  - `libs/FastSenseCompanion/private/companionUsageIndex.m` (tag → dashboards map)
  - `libs/FastSenseCompanion/private/filterTags.m` (search + filter pure logic)
  - `libs/FastSenseCompanion/private/openAdHocPlot.m` (figure factory)
- **Event wiring:** MATLAB `events`/`notify`. Pane events: `TagSelectionChanged`, `DashboardSelected`, `OpenSensorDetail`, `OpenAdHocPlot`, `OpenDashboard`. Orchestrator owns selection state (`SelectedTagKeys`, `SelectedDashboardIdx`, `LastInteraction`).
- **Public API:** `FastSenseCompanion(name-value)`, `setProject(dashboards, registry)`, `addDashboard(d)`, `removeDashboard(key)`, `selectTags(keys)`, `close()`. Private: pane handles. Not on surface: live-refresh control (delegates to `DashboardEngine`), dashboard creation/edit (out of scope).
- **Errors:** All namespaced `FastSenseCompanion:*`. Constructor / `setProject` validate eagerly. Every event callback wrapped in try/catch → `uialert(fig, ...)`. Downstream throws (e.g., `DashboardEngine.render`) never crash the companion.
- **Testing:** Pure-logic unit tests (`tests/test_companion_filter_tags.m`, `tests/test_companion_usage_index.m`). Class-based integration suite (`tests/suite/TestFastSenseCompanion.m`) — hidden `uifigure('Visible','off')`, drives state via `selectTags`, mocks `openAdHocPlot` via DI seam (constructor accepts a callable, defaults to real helper). No pixel-perfect UI tests.
- **Out of scope (v1 of Companion):** dashboard authoring; multi-project; cross-session persistence; status strip with global KPIs; custom time-range picker; detachable panes; WebBridge integration.

### Cross-Cutting Engineering Constraints (locked in Phase 1018)

These apply to every phase and are reflected in phase success criteria rather than separate REQ-IDs:

- `Listeners_` cell array on every class that calls `addlistener`; `delete(obj.Listeners_)` in `CloseRequestFcn`
- `stop(t); delete(t);` always in that order for every timer (companion and ad-hoc)
- Companion is the only `uifigure`; all spawned figures are classical `figure` — never parent one inside the other
- `axes(uipanel)` not `uiaxes(uipanel)` for embedded plots (9x performance difference)
- Errors namespaced `FastSenseCompanion:*`; every callback wrapped in try/catch + non-blocking `uialert`
- Pure-logic helpers (`filterTags_`, `flattenWidgets_`) ship with unit tests

### Research Flags for Planning

- **Phase 1020 planning:** Read `libs/Dashboard/DashboardPage.m` and `libs/Dashboard/GroupWidget.m` to confirm `Widgets` and `Children` GetAccess. Determines whether `DashboardEngine.getWidgets()` wrapper is required or if `d.Widgets`/`d.Pages{i}.Widgets` suffices.
- **Phase 1021 planning:** Run 20-line scratch test of `SensorDetailPlot(tag, 'Parent', uipanelHandle)` to verify resize behavior under embedded panel parenting.
- **Phase 1022 planning:** Write standalone 50-line `FastSenseGrid` + `timer` + `CloseRequestFcn` prototype before full implementation; verify zero orphan timers in `timerfindall` after close.

### Decisions (Phase 1020)

- **1020-02:** applyFilter_() is the single rebuild path for DashboardListPane row list; onRowClicked_ sets SelectedIdx_ then calls applyFilter_() for highlight rather than painting individual buttons
- **1020-02:** addDashboard uses handle identity (==) for duplicate detection; removeDashboard uses Name (case-sensitive strcmp) for lookup per CONTEXT.md
- **1020-02:** Listeners re-wired in setProject after detach clears them; SelectedDashboardIdx_ clamped to 0 in refresh() when engine list shrinks

### Carry-Forward

- **v2.1 Tag-API Tech Debt Cleanup** — in flight, parallel to v3.0. Phases 1012-1017. Does not block v3.0 work.
