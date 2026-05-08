---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: FastSense Companion
status: shipped
last_updated: "2026-05-08T23:30:00.000Z"
last_activity: 2026-05-08 -- Quick fix 260508-od4: roll back ny6 switchPage refresh sweep (didn't fix stuck-widget symptom, added per-tab cost) + guard HoverCrosshair.onFigureMove_ against invalid-object errors after panel teardown (OD4-01/02)
progress:
  total_phases: 6
  completed_phases: 6
  total_plans: 18
  completed_plans: 18
shipped_at: 2026-04-30
---

# State

## Current Position

Milestone: v3.0 FastSense Companion — SHIPPED 2026-04-30
Status: Awaiting next milestone (run `/gsd:new-milestone` to scope v3.x or v4.0)
Last activity: 2026-05-08 -- Quick fix 260508-ny6 (31a7b94): switchPage now marks active-page widgets dirty + refreshes them (incl. nested GroupWidget children), so HistogramWidget/HeatmapWidget/BarChartWidget/ScatterWidget no longer render empty after tab switch (NY6-01/02/03)

### Quick Tasks Completed

| # | Description | Date | Commit | Status | Directory |
|---|-------------|------|--------|--------|-----------|
| 260504-rcw | Fix isempty(containers.Map) guard in FastSenseCompanion.scanLiveTagUpdates_ | 2026-05-04 | cb83b51 | — | [260504-rcw-fix-isempty-containers-map-guard-in-fast](./quick/260504-rcw-fix-isempty-containers-map-guard-in-fast/) |
| 260504-sgt | Implement Companion Settings Dialog (Theme + Live period) | 2026-05-04 | c522988 | Verified | [260504-sgt-implement-companion-settings-dialog-them](./quick/260504-sgt-implement-companion-settings-dialog-them/) |
| 260504-sfp | Unify single-tag Open Detail through openAdHocPlot + right-click event-marker context menu | 2026-05-04 | 1d0ccd3 | — | [260504-sfp-fastsensecompanion-route-single-tag-open](./quick/260504-sfp-fastsensecompanion-route-single-tag-open/) |
| 260508-b8m | Refresh CLAUDE.md for Tag-based API and add Running MATLAB code section | 2026-05-08 | 90d9c03 | — | [260508-b8m-refresh-claude-md-for-tag-based-api-and-](./quick/260508-b8m-refresh-claude-md-for-tag-based-api-and-/) |
| 260508-bju | Lock down WebBridge CORS to localhost with env-var override | 2026-05-08 | 518b778 | Verified | [260508-bju-lock-down-webbridge-cors-to-localhost-on](./quick/260508-bju-lock-down-webbridge-cors-to-localhost-on/) |
| 260508-bxh | Gate WebSocket /ws endpoint with same origin policy as HTTP CORS | 2026-05-08 | e1aeebc | — | [260508-bxh-gate-websocket-ws-endpoint-with-same-ori](./quick/260508-bxh-gate-websocket-ws-endpoint-with-same-ori/) |
| 260508-d7k | Fix companion app dark mode — add uilistbox + 7 widget classes to theme walker | 2026-05-08 | 4472cc2 | Verified | [260508-d7k-fix-companion-app-dark-mode-switching-th](./quick/260508-d7k-fix-companion-app-dark-mode-switching-th/) |
| 260508-d8y | FastSense hover crosshair + datatip | 2026-05-08 | 0221795 | — | [260508-d8y-fastsense-hover-crosshair-datatip](./quick/260508-d8y-fastsense-hover-crosshair-datatip/) |
| 260508-das | Restore dashboard time-slider preview lines + event markers (backlog 999.3) | 2026-05-08 | 4110024 | Verified | [260508-das-implement-backlog-999-3-dashboard-time-s](./quick/260508-das-implement-backlog-999-3-dashboard-time-s/) |
| 260508-edd | Color dashboard slider preview event markers per-severity (sev1/2/3 -> green/orange/red) | 2026-05-08 | 9c1ef82 | Verified | [260508-edd-color-slider-preview-event-markers-per-e](./quick/260508-edd-color-slider-preview-event-markers-per-e/) |
| 260508-eu2 | Restore EventStore on detached FastSenseWidget so event markers stay visible after detach | 2026-05-08 | 952ad90 | Verified | [260508-eu2-restore-eventstore-on-detached-fastsense](./quick/260508-eu2-restore-eventstore-on-detached-fastsense/) |
| 260508-f7p | Reset button on time panel now restyles on dashboard theme switch | 2026-05-08 | 0e9c6f7 | Verified | (inline) |
| 260508-jf1 | Fix orange stale-data banner overlapping multi-page tab strip in DashboardEngine | 2026-05-08 | 66fbfbc | — | [260508-jf1-fix-orange-no-data-banner-overlapping-da](./quick/260508-jf1-fix-orange-no-data-banner-overlapping-da/) |
| 260508-jyh | Reserve permanent top strip for stale-data banner (banner no longer overlays toolbar / tabs / widgets) | 2026-05-08 | bdf1dc5 | Verified | [260508-jyh-stale-banner-reserved-strip-atop-dashboa](./quick/260508-jyh-stale-banner-reserved-strip-atop-dashboa/) |
| 260508-kau | Slider preview aggregates lines + event markers across ALL pages (KAU-01) | 2026-05-08 | 70c3c4c | — | [260508-kau-slider-preview-aggregates-all-pages-widg](./quick/260508-kau-slider-preview-aggregates-all-pages-widg/) |
| 260508-kov | Revert slider preview/markers to active-page-only iteration (supersedes kau via forward-fix; KOV-01) | 2026-05-08 | ac5d4df | — | [260508-kov-revert-slider-preview-to-active-page-onl](./quick/260508-kov-revert-slider-preview-to-active-page-onl/) |
| 260508-l2k | Slider preview + event-marker iteration recurses into GroupWidget children, scoped to active page (L2K-01) | 2026-05-08 | 5cd3e27 | — | [260508-l2k-preview-iteration-recurses-into-groupwid](./quick/260508-l2k-preview-iteration-recurses-into-groupwid/) |
| 260508-llw | Broadcast time range across ALL pages (broadcastTimeRange + resetGlobalTime) and re-broadcast on tab-switch so realized widgets inherit synced range (LLW-01/02/03) | 2026-05-08 | ed66ec5 | Verified | [260508-llw-broadcast-time-range-across-all-pages-wi](./quick/260508-llw-broadcast-time-range-across-all-pages-wi/) |
| 260508-m52 | Shrink WidgetButtonBar from full-width to 64px right-anchored strip so widget titles below it become visible (M52-01/02) | 2026-05-08 | 1410524 | Superseded by mhv | [260508-m52-shrink-widget-button-bar-to-right-anchor](./quick/260508-m52-shrink-widget-button-bar-to-right-anchor/) |
| 260508-mhv | Restore full-width WidgetButtonBar; render widget content into WidgetContentPanel sub-panel below the bar so titles/axes never truncate (MHV-01/02) | 2026-05-08 | 6860bad | Verified | [260508-mhv-full-width-widget-bar-with-content-panel](./quick/260508-mhv-full-width-widget-bar-with-content-panel/) |
| 260508-n3u | FastSenseWidget.getPreviewSeries skips downsampling for sensors with <=100 samples (raw fidelity below threshold, downsample above) (N3U-01) | 2026-05-08 | 4a260ef | — | [260508-n3u-preview-skips-downsampling-under-100-sam](./quick/260508-n3u-preview-skips-downsampling-under-100-sam/) |
| 260508-ng1 | Add Reset button to DashboardToolbar that triggers DashboardEngine.rerenderWidgets() | 2026-05-08 | fb80f4b | Verified | [260508-ng1-add-reset-button-to-dashboard-toolbar](./quick/260508-ng1-add-reset-button-to-dashboard-toolbar/) |
| 260508-ny6 | switchPage marks active-page widgets dirty + refreshes them, incl. nested GroupWidget children; isolates per-widget refresh failures (NY6-01/02/03) | 2026-05-08 | 31a7b94 | Superseded by od4 | [260508-ny6-tab-switch-marks-active-page-widgets-dir](./quick/260508-ny6-tab-switch-marks-active-page-widgets-dir/) |
| 260508-od4 | Roll back ny6 (switchPage markDirty+refresh sweep didn't fix stuck-widget symptom and added per-tab cost) + fix HoverCrosshair.onFigureMove_ invalid-object guard (OD4-01/02) | 2026-05-08 | 6ef1a86, 936feac | — | [260508-od4-rollback-ny6-sweep-and-fix-hovercrosshai](./quick/260508-od4-rollback-ny6-sweep-and-fix-hovercrosshai/) |

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
