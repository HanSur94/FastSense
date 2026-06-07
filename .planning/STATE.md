---
gsd_state_version: 1.0
milestone: v5.0
milestone_name: milestone
status: executing
last_updated: "2026-06-07T19:38:37.543Z"
last_activity: 2026-06-03 -- Phase 1042 planning complete
progress:
  total_phases: 6
  completed_phases: 2
  total_plans: 8
  completed_plans: 8
  percent: 33
---

# State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-02)

**Core value:** A MATLAB engineer can ingest, browse, dashboard, and compare data across a growing fleet of near-identical machines from the FastSense Companion — including overlaying the same logical sensor across machines whose raw sensor keys differ — without leaving MATLAB and without external toolboxes.
**Current focus:** Phase 1041 — canonicalmapper

## Current Position

Phase: 1042
Plan: Not started
Milestone: v5.0 Multi-Machine Fleet — started 2026-06-02 (continues phase numbering from 1040). Prior: v4.0 Multi-User LAN Concurrency (shipped); v3.0 FastSense Companion (shipped 2026-04-30).
Status: Ready to execute
Last activity: 2026-06-03 -- Phase 1042 planning complete

### Note on parallel v4.0 work (main branch state)

While Phase 1028 was in flight on this branch, main shipped v4.0 Multi-User LAN Concurrency (phases 1029-1033) via PR #152. The two efforts touched some shared files (`LiveTagPipeline.m`, `build_mex.m`) — merged here on this commit with both feature sets preserved:

- Plan 02d in-memory prior-state cache + Plan 06 fs-stat coalescing live in the single-user code path of `LiveTagPipeline.processTag_`.
- v4.0 cluster-mode (TagWriteCoordinator + AtomicWriter) lives in the `if obj.IsClusterMode_` branch.
- `bench_tag_pipeline_1k` continues to drive the single-user path (no SharedRoot set).
- v4.0's STATE.md / ROADMAP.md entries (phases 1029-1033 Complete) preserved verbatim; phase 1028 Complete entry added alongside.

Three main PRs touched files v4.0 also modified — all auto/manually merged without functional conflict:

- PR #143 (260513-s0y) — Tile + Close all toolbar buttons. Tracking fixes (syncOpenedFigures_ Engines_ walk, public trackOpenedFigure hook, de-maximize + Units=pixels coercion) live alongside v4.0 cluster-mode wiring.
- PR #149 (260519-bs4) — Tag Status Table window. TagStatusTableWindow handle + Tags toolbar button live alongside v4.0 cluster-mode + pipeline-observer state.

Other main PRs (#138, #139, #141, #144, #145, #146) auto-merged without conflict during the earlier sync.

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
| 260508-huo | Fix CI — hoist companion test runners out of private/; guard headless web() in DashboardEngine; gate R2020b MEX-heavy tests | 2026-05-08 | 62b99ab | — | [260508-huo-fix-octave-tests-move-companion-runner-f](./quick/260508-huo-fix-octave-tests-move-companion-runner-f/) |
| 260508-mjp | Add tag-column search field to LiveLogPane mirroring events log | 2026-05-08 | 1c258fb | — | [260508-mjp-add-tag-column-search-field-to-livelogpa](./quick/260508-mjp-add-tag-column-search-field-to-livelogpa/) |
| 260508-n8h | Dashboard Info button opens modal in-app uifigure (uihtml) instead of system browser | 2026-05-08 | 8b525a8 | — | [260508-n8h-dashboard-info-button-opens-modal-render](./quick/260508-n8h-dashboard-info-button-opens-modal-render/) |
| 260511-ldu | PR #125 followup polish — extract bringFigureToFront_, tighten crosshair visibility, +2 tests, doc fixes | 2026-05-11 | 134a0d9 | — | [260511-ldu-pr-125-followup-polish-extract-bringfigu](./quick/260511-ldu-pr-125-followup-polish-extract-bringfigu/) |
| 260511-mjb | Fix 2 pre-existing TestFastSenseCompanion failures — findobj->findall for uifigure lookup; ObjectBeingDestroyed safety-net listener on DashboardEngine.hFigure (stops LiveTimer for delete(fig)/close all force paths) | 2026-05-11 | 8df1a67 | Verified | [260511-mjb-fix-2-pre-existing-testfastsensecompanio](./quick/260511-mjb-fix-2-pre-existing-testfastsensecompanion/) |
| 260511-n1r | Sever FigureDestroyedListener_ at top of DashboardEngine.delete() — fixes R2021b CI segfault in TestDashboardDirtyFlag | 2026-05-11 | e7026bb | Verified | [260511-n1r-fix-r2021b-segfault-delete-figuredestroy](./quick/260511-n1r-fix-r2021b-segfault-delete-figuredestroy/) |
| 260512-c5x | Fix tail-truncation artifact in FastSense MinMax downsampling | 2026-05-12 | c932acd | Verified | [260512-c5x-fix-tail-truncation-artifact-in-fastsens](./quick/260512-c5x-fix-tail-truncation-artifact-in-fastsens/) |
| 260512-cxc | Fix slider preview tail stuck at interior bucket midpoint (260512-c5x follow-up) | 2026-05-12 | f79642a | Verified | [260512-cxc-fix-slider-preview-tail-stuck-at-interio](./quick/260512-cxc-fix-slider-preview-tail-stuck-at-interio/) |
| 260512-egv | Fix slider drag broken after top-toolbar Reset | 2026-05-12 | 7ab7584 | Verified | [260512-egv-fix-slider-drag-broken-after-reset-due-t](./quick/260512-egv-fix-slider-drag-broken-after-reset-due-t/) |
| 260512-eu2 | Restore HoverCrosshair after Reset (260512-egv follow-up) | 2026-05-12 | dc84454 | Verified | [260512-eu2-restore-hovercrosshair-after-reset-by-mo](./quick/260512-eu2-restore-hovercrosshair-after-reset-by-mo/) |
| 260512-fd9 | Industrial plant demo opens with Live mode OFF by default | 2026-05-12 | ac0baaa | Verified | (inline) |
| 260512-hrn | Add Follow uitoggletool to FastSenseToolbar | 2026-05-12 | 596d399 | — | [260512-hrn-add-follow-toggle-button-to-fastsense-to](./quick/260512-hrn-add-follow-toggle-button-to-fastsense-to/) |
| 260513-ovt | Preserve widget X and Y views across Live ticks + Follow toggle reaches every page | 2026-05-13 | 498a5f3 | — | [260513-ovt-when-follow-button-is-pressed-y-axis-lim](./quick/260513-ovt-when-follow-button-is-pressed-y-axis-lim/) |
| 260513-q7w | Debounced post-resize refresh + ZOMBIE-PANEL fix | 2026-05-13 | 577bf95 | — | [260513-q7w-during-dashboard-figure-resize-fastsense](./quick/260513-q7w-during-dashboard-figure-resize-fastsense/) |
| 260513-sfp | Add auto-y-limit control buttons (V/A/L) to FastSenseWidget WidgetButtonBar | 2026-05-13 | 4db9138 | Verified | [260513-sfp-add-auto-y-limit-control-buttons-to-fast](./quick/260513-sfp-add-auto-y-limit-control-buttons-to-fast/) |
| 260513-s0y | Add Tile + Close all buttons to FastSenseCompanion top toolbar | 2026-05-14 | 182d6f1 | Shipped (PR #143) | [260513-s0y-add-tile-windows-and-close-all-windows-b](./quick/260513-s0y-add-tile-windows-and-close-all-windows-b/) |
| 260526-pw3 | Show all tag events in FastSense widgets across industrial plant demo | 2026-05-26 | c475d2a | — | [260526-pw3-in-the-industrial-plant-demo-ensure-all-](./quick/260526-pw3-in-the-industrial-plant-demo-ensure-all-/) |
| 260526-r9x | Add PerTag composer mode to FastSenseCompanion | 2026-05-26 | abdc80b | Verified | [260526-r9x-add-pertag-composer-mode-to-fastsensecom](./quick/260526-r9x-add-pertag-composer-mode-to-fastsensecom/) |
| 260519-bs4 | Add Tag Status Table window to FastSenseCompanion | 2026-05-19 | b2ed937 | Verified | [260519-bs4-implement-a-new-table-view-in-the-compan](./quick/260519-bs4-implement-a-new-table-view-in-the-compan/) |
| 260526-tcf | Fix two pre-existing column assertions in TestFastSenseCompanion.m | 2026-05-26 | e321ac7 | Ready for verification | [260526-tcf-fix-companion-toolbar-1x9-grid-test-cols](./quick/260526-tcf-fix-companion-toolbar-1x9-grid-test-cols/) |
| 260526-pqz | Raise per-signal slider-preview cap from 400 to 1000 buckets | 2026-05-26 | 834b43c | — | [260526-pqz-raise-preview-line-cap-per-signal-from-4](./quick/260526-pqz-raise-preview-line-cap-per-signal-from-4/) |
| 260529-rxf | Real per-event email alerts for background monitoring | 2026-05-29 | 203da7a | Verified | [260529-rxf-real-per-event-email-alerts-for-backgrou](./quick/260529-rxf-real-per-event-email-alerts-for-backgrou/) |
| 260529-fnt | Add FunctionTransport adapter | 2026-05-29 | 706e9d5 | Verified | (inline) |

## Progress Bar

```
v5.0 Multi-Machine Fleet
Phase 1041 [ ] 0% (0/? plans)
Phase 1042 [ ] 0% (0/? plans)
Phase 1043 [ ] 0% (0/? plans)
Phase 1044 [ ] 0% (0/? plans)
Phase 1045 [ ] 0% (0/? plans)
Phase 1046 [ ] 0% (0/? plans)
```

## Accumulated Context

### Roadmap Evolution

- 2026-04-29 — Milestone v3.0 FastSense Companion started (programmatic MATLAB uifigure companion app; design brainstormed prior; v2.1 Tag-API Tech Debt Cleanup carried forward in parallel)
- 2026-04-29 — v3.0 roadmap created: 5 phases (1018-1022) covering 28 REQ-IDs across COMPSHELL, CATALOG, BROWSER, INSPECT, ADHOC categories
- 2026-04-29 — v3.0 phase 1023 added (Industrial Plant Demo Integration): wraps `demo/industrial_plant/run_demo.m` in `FastSenseCompanion`; 4 new COMPDEMO REQ-IDs; total now 6 phases / 32 REQ-IDs
- 2026-05-13 — Milestone v4.0 Multi-User LAN Concurrency started; PROJECT.md updated, REQUIREMENTS.md created (14 P1 REQ-IDs across CONC/IDENT/EVTLOG/ACK/OPS categories; 6 P2 deferred to v4.1); research/ phase produced SUMMARY/STACK/FEATURES/ARCHITECTURE/PITFALLS markdown
- 2026-05-13 — v4.0 roadmap created: 5 phases (1029-1033) covering all 14 P1 REQ-IDs, full coverage no orphans; phase structure mirrors research-recommended build order (Foundation -> TagWriteCoordinator -> EventLog -> Single-Source Events -> Companion Integration); three PITFALLS corrections (OFD locks, mtime heartbeat, lock-serialised appends) baked into Phase 1029 success criteria
- 2026-06-02 — Phase 1040 added: Companion Notification Center (acknowledgeable in-app inbox pane in `FastSenseCompanion`; design brainstormed in-session and approved; EventStore-backed feed, dismiss = `acknowledgeEvent`, new collapsible right column + toolbar bell badge; `1040-CONTEXT.md` written)
- 2026-06-02 — Milestone v5.0 Multi-Machine Fleet started; REQUIREMENTS.md created (26 v1 REQ-IDs across FLEET/CANON/MACH/CMP/DASH categories); research SUMMARY.md completed with HIGH confidence
- 2026-06-02 — v5.0 roadmap created: 6 phases (1041-1046) covering all 26 v1 REQ-IDs, 100% coverage, no orphans; phase structure follows research dependency-ordered build sequence; critical pitfalls baked into phase success criteria

### Phase Numbering Note

v2.1 phases in the phases/ directory extend to 1017 (1012, 1013, 1014, 1017). v3.0 phases extended to 1023.1. Pending unscoped phases 1025-1028 are carry-forward from a backlog promotion (NOT v4.0). v4.0 phases start at 1029. v5.0 phases start at 1041.

### v5.0 Architecture Decisions Locked

- **Data model:** Approach 1 (Machine/Fleet layer). Each `Machine` owns its own `containers.Map` tag catalog. Global `TagRegistry` singleton left untouched (72 static call sites across 31 files).
- **Comparison UX:** Approach A locked — machine-first compare-builder dialog; opens its own overlay figure via `openAdHocPlot` Overlay path; no changes to the 3 Companion panes or `setProject`.
- **Machine selector placement:** Deferred to Phase 1044 UI planning — left-rail vs. top dropdown vs. tabs is a UI-phase decision; data model is placement-agnostic.
- **FleetDashboardCloner placement:** Deferred to Phase 1046 planning — behavior is specified; whether it lives in `libs/Fleet/`, as a static method on `DashboardSerializer`, or as a method on `Fleet` is unresolved.
- **openAdHocPlot per-series color injection:** Deferred to Phase 1045 planning — existing `plotOverlay_` uses MATLAB `ColorOrder` auto-assignment; explicit per-machine color injection form not pinned.

### Critical Invariants (must be verified at every phase gate)

1. `grep -rn "TagRegistry.register" libs/Fleet/` must return 0 (machine tags never enter global registry)
2. `grep -rn "uifigure\|uicontrol\|uitree\|uigridlayout\|uiprogressdlg" libs/Fleet/` must return 0 (no UI code in data model; Octave must run all Fleet data-model code)
3. `grep -rn "contains(" libs/Fleet/CanonicalMapper.m` must return 0 (Octave-safe string ops only)
4. LOW-confidence canonical matches are excluded from comparison unless explicitly confirmed by user
5. `CanonicalMapper.resolve` absent from steady-state tick profiler output (resolve-once-at-open pattern)

### Phase Dependencies Summary

```
1041 CanonicalMapper
  |
1042 Machine + Fleet + Pipeline DI (uses CanonicalMapper for resolveLogical)
  |
1043 DashboardSerializer Resolver Seam (depends on Machine resolver signature)
  |
1044 Companion Machine Dimension (consumes 1041 + 1042 + 1043)
  |
1045 Cross-Machine Comparison (depends on 1044 machine selector + 1042 Fleet.resolveLogical)
  |
1046 Clone/Remap (depends on 1041 + 1042 + 1043 + 1044)
```

### Research Flags for Planning

- **Phase 1044 planning:** Machine selector placement (left rail vs. top dropdown vs. tabs) was explicitly deferred in PROJECT.md; requires a focused UI decision before the phase plan is written; re-read SUMMARY.md Q5 + FEATURES.md Area 1 differentiators
- **Phase 1045 planning:** `openAdHocPlot` per-series color injection design is not pinned (`colors` arg vs. struct-array input); resolve before plan is locked; re-read SUMMARY.md Q5
- **Phase 1046 planning:** `FleetDashboardCloner` placement (standalone function vs. method on `Fleet` vs. `DashboardSerializer` static method) is unresolved; needs one design decision pass

### Brainstorm Outcomes (v3.0)

Design decisions locked during the v3.0 brainstorm conversation (2026-04-29):

- **Scope:** A + B + C combined — library browser + live monitoring + tag-first explorer. **Not** D (no in-app dashboard authoring/editing).
- **UI tech:** Programmatic `uifigure` (no App Designer, no `.mlapp`).
- **Connection contract:** Loose handoff via constructor: `FastSenseCompanion('Dashboards', {d1, d2}, 'Registry', TagRegistry)`. Tags pulled from `TagRegistry` singleton by default; pass `'Registry', reg` to override. Single project per app instance (no multi-project switcher).
- **Dashboard rendering:** Opening a dashboard pops it into its own MATLAB figure via existing `DashboardEngine.render()`. Companion is purely a control panel / navigator. Zero changes required to `DashboardEngine`.
- **Layout:** Three-pane window — left = searchable tag catalog with multi-select checkboxes and filter pills; middle = dashboard list; right = adaptive inspector.
- **Inspector states:** `welcome` (empty) / `tag` (single tag selected — metadata, thresholds, "used in" cross-references, "Plot this tag" -> `SensorDetailPlot`) / `multitag` (N>1 — plot composer with Linked grid / Overlay, time range All / Last 1h, Live Off/2s/5s) / `dashboard` (dashboard tile selected — summary + open + live toggle). Most-recent click wins (`LastInteraction = 'tags' | 'dashboard'`).
- **Public API:** `FastSenseCompanion(name-value)`, `setProject(dashboards, registry)`, `addDashboard(d)`, `removeDashboard(key)`, `selectTags(keys)`, `close()`. Private: pane handles. Not on surface: live-refresh control (delegates to `DashboardEngine`), dashboard creation/edit (out of scope).

### Cross-Cutting Engineering Constraints (locked in Phase 1018)

These apply to every phase and are reflected in phase success criteria rather than separate REQ-IDs:

- `Listeners_` cell array on every class that calls `addlistener`; `delete(obj.Listeners_)` in `CloseRequestFcn`
- `stop(t); delete(t);` always in that order for every timer (companion and ad-hoc)
- Companion is the only `uifigure`; all spawned figures are classical `figure` — never parent one inside the other
- `axes(uipanel)` not `uiaxes(uipanel)` for embedded plots (9x performance difference)
- Errors namespaced `FastSenseCompanion:*`; every callback wrapped in try/catch + non-blocking `uialert`
- Pure-logic helpers (`filterTags_`, `flattenWidgets_`) ship with unit tests
