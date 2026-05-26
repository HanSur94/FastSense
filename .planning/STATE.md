---
gsd_state_version: 1.0
milestone: v4.0
milestone_name: Multi-User LAN Concurrency
status: shipping
stopped_at: PR #152 ready for merge (v4.0); PR #114 (Phase 1028 perf) shipped 2026-05-19 on parallel branch.
last_updated: "2026-05-19T10:00:00Z"
last_activity: 2026-05-19 -- Phase 1028 (Tag update perf — MEX + SIMD) COMPLETE on parallel branch claude/adoring-ishizaka-edc93c; v4.0 milestone separately shipping via PR #152.
progress:
  total_phases: 12
  completed_phases: 6
  total_plans: 26
  completed_plans: 30
---

# State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-13)

**Core value:** A MATLAB engineer can ingest a million-sample sensor stream, monitor thresholds, build sub-second-responsive dashboards, and navigate it all from a single Companion app — without leaving MATLAB and without external toolboxes.
**Current focus:** Phase 1029 — Concurrency Foundation

## Current Position

Phase: 1028 (tag-update-perf-mex-simd) — COMPLETE 2026-05-19 (this branch)
Plan: 6 of 6 executed (with 03/04 deferred per Plan 02d data). Shipped plans: 01, 02, 02b, 02d, 05, 06.
Milestone: v3.0 FastSense Companion — SHIPPED 2026-04-30; v4.0 Multi-User LAN Concurrency — shipping via PR #152 (parallel branch); v1.0 perf line tracks phase 1028 — now COMPLETE via PR #114.
Status: Phase 1028 closed. WithIO `tickMin` reduced 4497 ms → 3603 ms (−19.9%) on Octave Linux x86_64 CI run 26089658442, almost entirely from Plan 02d's in-memory prior-state cache. Plan 06 ships per-tick fs-stat coalescing reducing 1600 → 1 syscalls/tick (−99.94% mechanism-level; wall-time +3.2% within variance on tmpfs CI). PR #114 carries the phase. Follow-up candidates for a future perf phase: in-memory propagation refactor; `containers.Map` → struct-array refactor; `.mat` save-side optimization. K2/K3/K4 deferred per data (target regions bucket as 0 ms post-cache).
Last activity: 2026-05-19 — Completed phase 1028: Tag update perf — MEX + SIMD. Plan 06 shipped per-tick fs-stat coalescing seam (1600 → 1 syscall/tick = −99.94% reduction; wall-time within variance), phase wrap docs (VERIFICATION.md Final Result, ROADMAP.md, STATE.md, 1028-06-SUMMARY.md). Cumulative phase win: WithIO −19.9% from Plan 02d's read-side cache. K2/K3/K4 deferred per data; in-memory propagation + Map refactor remain as candidates for a follow-up perf phase.

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
| 260511-mjb | Fix 2 pre-existing TestFastSenseCompanion failures — findobj→findall for uifigure lookup; ObjectBeingDestroyed safety-net listener on DashboardEngine.hFigure (stops LiveTimer for delete(fig)/close all force paths) | 2026-05-11 | 8df1a67 | Verified | [260511-mjb-fix-2-pre-existing-testfastsensecompanio](./quick/260511-mjb-fix-2-pre-existing-testfastsensecompanio/) |
| 260511-n1r | Sever FigureDestroyedListener_ at top of DashboardEngine.delete() — fixes R2021b CI segfault in TestDashboardDirtyFlag (listener captured engine handle; on R2021b GC could destroy engine before its hFigure, then listener fired on deleted handle inside MATLAB's C++ dispatch layer) | 2026-05-11 | e7026bb | Verified | [260511-n1r-fix-r2021b-segfault-delete-figuredestroy](./quick/260511-n1r-fix-r2021b-segfault-delete-figuredestroy/) |
| 260512-c5x | Fix tail-truncation artifact in FastSense MinMax downsampling — append (segX(end), segY(end)) anchor in all four cores (MEX/pure-MATLAB/log-X/slider-preview) when bucket's min/max miss segX(end). Industrial plant demo reactor.pressure tail delta 10580s→0.97s; n=2*nb+1 when anchor needed | 2026-05-12 | c932acd | Verified | [260512-c5x-fix-tail-truncation-artifact-in-fastsens](./quick/260512-c5x-fix-tail-truncation-artifact-in-fastsens/) |
| 260512-cxc | Fix slider preview tail stuck at interior bucket midpoint (260512-c5x follow-up) — in getPreviewSeries capture anchorX before dropping the trailing point, then override xCenters(end):=anchorX so the slider tail tracks live data growth. Industrial plant demo slider-tail delta 414s→0.00s; tracks tick-for-tick after Reset | 2026-05-12 | f79642a | Verified | [260512-cxc-fix-slider-preview-tail-stuck-at-interio](./quick/260512-cxc-fix-slider-preview-tail-stuck-at-interio/) |
| 260512-egv | Fix slider drag broken after top-toolbar Reset — add TimeRangeSelector.reinstallCallbacks + call at end of DashboardEngine.rerenderWidgets. Root cause: HoverCrosshair's chained WBM pattern unwinds in install order (not LIFO) when rerenderWidgets deletes widget panels 1..N, leaving a dangling-handle closure on the figure WBM that swallows motion events before they reach trs.onButtonMotion_. Re-installing TRS callbacks at the outermost layer restores drag. Acknowledged trade-off: per-widget HoverCrosshair goes inert until next instantiation (out-of-scope refactor) | 2026-05-12 | 7ab7584 | Verified | [260512-egv-fix-slider-drag-broken-after-reset-due-t](./quick/260512-egv-fix-slider-drag-broken-after-reset-due-t/) |
| 260512-eu2 | Restore HoverCrosshair after Reset (260512-egv follow-up) — move TRS.reinstallCallbacks from end of rerenderWidgets to BETWEEN the delete-old-panels loop and the allocate-new-panels block. New chain post-rerender: newHcN→...→newHc1→trs.onButtonMotion_. Both slider drag AND per-widget HoverCrosshair work after Reset. Verified on live demo: POST-RESET WBM = HC's onFigureMove_, synth drag moves Selection by ~1.74 days, 2 live HoverCrosshair instances alive on active page | 2026-05-12 | dc84454 | Verified | [260512-eu2-restore-hovercrosshair-after-reset-by-mo](./quick/260512-eu2-restore-hovercrosshair-after-reset-by-mo/) |
| 260512-fd9 | Industrial plant demo opens with Live mode OFF by default — removed `engine.startLive()` from buildDashboard.m. Both dashboard and companion now start idle (engine.IsLive=0, companion.IsLive=0); user opts in via the top-toolbar "Live" button. Aligns the two windows on the same default; data writer + LiveTagPipeline keep running independently in the background | 2026-05-12 | ac0baaa | Verified | (inline) |
| 260512-hrn | Add Follow uitoggletool to FastSenseToolbar — between Live and Metadata — with setFollow(), syncFollowState(), IsPropagating-aware auto-disengage in FastSense.onXLimChanged, AppData stash at 4 attacher sites, and 9 function-style tests (test_fastsense_follow_toggle.m) | 2026-05-12 | 596d399, 0a4a516 | — | [260512-hrn-add-follow-toggle-button-to-fastsense-to](./quick/260512-hrn-add-follow-toggle-button-to-fastsense-to/) |
| 260513-ovt | Preserve widget X and Y views across Live ticks + Follow toggle reaches every page — (1) added LiveViewMode='follow' guard inside FastSenseWidget.autoScaleY_, (2) removed `autoScaleY_(y)` from FastSenseWidget.refresh/update, (3) removed `broadcastTimeRange(tStart, tEnd)` from DashboardEngine.onLiveTick, (4) flipped FastSenseWidget.LiveViewMode default 'reset'→'preserve', (5) made FastSenseToolbar.syncFollowState public so FastSense.onXLimChanged's auto-disengage hook actually syncs the Follow button, (6) made DashboardEngine.{allPageWidgets,activePageWidgets} public + onFollowToggle uses allPageWidgets() so Follow actually flips every FastSenseWidget across all pages on multi-page dashboards (was silently no-op via swallowed MethodRestricted). Live mode is now strictly "append data only"; Follow does width-preserving slide with 2% right-edge gap. test_fastsense_follow_toggle 10/10, test_dashboard_time_sync_all_pages 5/5, test_dashboard_range_selector_integration 2/2; verified end-to-end on industrial plant demo (Follow ON: XLim+0.140d toward tail, width preserved exactly, 2/2 widgets switched; OFF: 2/2 reverted) | 2026-05-13 | 498a5f3, ca5be95, 8d41c48, 63cdff4 | — | [260513-ovt-when-follow-button-is-pressed-y-axis-lim](./quick/260513-ovt-when-follow-button-is-pressed-y-axis-lim/) |
| 260513-q7w | Debounced post-resize refresh + ZOMBIE-PANEL fix that stops widgets going white during drag-resize and tab switching — TWO parallel timers on every figure resize event (300 ms cheap two-pass refresh + 1.2 s unconditional rerenderWidgets backstop). switchPage cancels both timers AND waits up to 3 s for in-flight rerenderWidgets to complete before mutating state. `IsRerendering_` flag prevents rerender-cascade scheduling. Re-entrancy guard aborts instead of self-rescheduling. **Root-cause fix**: rerenderWidgets now deletes the OUTER cell panel (via hCellPanel, falling back to hPanel for pre-realization widgets) — previous code deleted only `hPanel` which after realization points to the INNER content panel, leaving the outer cell + its WidgetButtonBar chrome alive on the canvas as "zombies" that stacked up over multiple rerenders and painted over freshly switched-to pages. test_dashboard_range_selector_integration 2/2, test_dashboard_time_sync_all_pages 5/5; canvas-children-count canary verifies zero zombie accumulation across 4 rerenders + resize + tab switch (constant 29) | 2026-05-13 | 577bf95, 99c8808, 4eda604, bc305dc, 54d5aa0, 20bcd4c | — | [260513-q7w-during-dashboard-figure-resize-fastsense](./quick/260513-q7w-during-dashboard-figure-resize-fastsense/) |
| 260513-sfp | Add auto-y-limit control buttons (V/A/L) to FastSenseWidget WidgetButtonBar — new YLimitMode property (auto-visible / auto-all / locked, default 'auto-visible' reproduces pre-260513-sfp behaviour), setYLimitMode public method (clears UserZoomedY on explicit click so click re-engages autoscale), autoScaleY_ refactored to dispatch on mode AFTER existing precedence guards (YLimits pin / UserZoomedY / FastSense.LiveViewMode=='follow') so 260513-ovt Follow semantics are preserved. DashboardLayout duck-types widget chrome via ismethod(widget,'setYLimitMode'), so future widgets that expose Y-rescale modes opt in without touching DashboardLayout. ASCII glyphs (V/A/L) match existing Info/Detach. reflowChrome_ re-anchors on resize. toStruct omits the default so legacy dashboards stay diff-invisible. test_fastsense_widget_ylimit_modes 11/11, test_fastsense_widget_tag 7/7, test_fastsense_follow_toggle 10/10, test_dashboard_time_sync_all_pages 5/5. Verified on live industrial-plant demo, all 8 scenarios approved. Known caveat: V/A/L cluster butts against Info button (0-px gap) — inherited from pre-existing addInfoIcon 28-px-typo, explicitly out-of-scope per plan; logged in deferred-items.md | 2026-05-13 | 4db9138, cc18c7f, a9cc181 | Verified | [260513-sfp-add-auto-y-limit-control-buttons-to-fast](./quick/260513-sfp-add-auto-y-limit-control-buttons-to-fast/) |
| 260513-s0y | Add Tile + Close all buttons to FastSenseCompanion top toolbar — private OpenedFigures_ tracking + syncOpenedFigures_ (walks Engines_ before tile/close-all) + public trackOpenedFigure hook (InspectorPane.onOpenDetail_ and CompanionEventViewer.openEventDashboard_ forward their figure handles). tileOpenedWindows: ceil(sqrt(N))×ceil(N/cols) grid on monitor containing the companion, 24px margin, 8px gutter, row-major top-down. Before set(Position), coerces each figure to WindowState='normal' + Units='pixels' — root cause of initial "Tile does nothing" report was DashboardEngine.render defaulting to Units='normalized' (pixel rects got treated as screen fractions, pushing figures off-canvas). closeAllOpenedWindows: snapshot + close(h) per handle (honors each figure's CloseRequestFcn). Inner toolbar grid 1×4→1×6 (Events / Live / Tile / Close all / spacer / gear; gear Layout.Column 4→6). 9 sub-tests in test_companion_tile_close_buttons.m PASS; TestFastSenseCompanion regression 64/64 PASS. Verified on live industrial-plant demo. Shipped as PR #143. | 2026-05-14 | 182d6f1, 2867caa, 1be2cc8, e58bc35, c47c0c1, db9ef88 | Shipped (PR #143) | [260513-s0y-add-tile-windows-and-close-all-windows-b](./quick/260513-s0y-add-tile-windows-and-close-all-windows-b/) |
| 260519-bs4 | Add Tag Status Table window to FastSenseCompanion — new `TagStatusTableWindow.m` (classical figure, not uifigure, per CONTEXT.md), opened via new **Tags ↗** button on companion top toolbar (col 3 in the post-merge 1×7 grid: Events / Live / Tags / Tile / Close all / spacer / gear). Detached-only window with 12-column `uitable`: Key, Name, Type, Criticality, Units, Latest, Status (smart per-type — Monitor→OK/ALARM, State→state label, others→—), Last updated (X(end) timestamp), Activity (Live/Inactive at 5-min threshold), Events (count from EventStore), Samples, Labels. All 18 demo tags listed (snapshot from `TagRegistry.find(@(t)true)`). Two parallel refresh paths: (a) push-on-write via existing `FastSenseCompanion.scanLiveTagUpdates_` → `markStatusTableDirty_(keys)` when companion is in Live mode, (b) window-owned `RefreshTimer_` (1s fixedSpacing, unique UUID name, BusyMode='drop', self-stop after 2 consecutive tick errors) so the table refreshes regardless of companion's IsLive — addresses user feedback that Activity/Last updated must stay correct when companion is idle. Pause/Resume polling toggle freezes both paths (markTagsDirty becomes a no-op while paused; header shows "Last refreshed: HH:MM:SS (paused)"). "Last refreshed" heartbeat label updates every tick. Filter chips mirror TagCatalogPane pattern: Type (Sensor/Monitor/Composite/State/Derived), Criticality (Low/Medium/High/Safety), Activity (Live/Inactive) — multi-toggle, AND-across-groups / OR-within-group; broadened free-text search across Key+Name+Units+Labels. Push-on-write hook in companion stays — both mechanisms run in parallel. Six atomic commits + 1 merge: 01 base class + 11 pure-logic tests; 02 companion wiring + 7 lifecycle tests; 03 Activity column + own timer (+5 logic + 2 lifecycle tests, deviation from "push-on-write only" CONTEXT decision per user); 04 last-refreshed header + chip filters + broader search (+4 logic + 2 lifecycle tests); 05 Pause/Resume polling toggle (+4 lifecycle tests); 06 Events count column (+4 logic + 1 lifecycle test); 07 merge with main (PR #143 toolbar grid conflict). Final test counts post-merge: `test_companion_tag_status_table` 24/24 (pure-logic), `TestTagStatusTableWindow` 16/16 (UI lifecycle), `test_companion_tile_close_buttons` 9/9 (main's new test still PASS), `TestFastSenseCompanion` 64/64 (no regression) = 113/113 total. Verified end-to-end on live industrial-plant demo: 4 MonitorTags showed real event counts (29/32/33/35), 14 others showed 0; Activity flipped Live→Inactive at exactly 5-min boundary via static buildRow_ proof; companion IsLive=0 throughout (window polled itself). Deferred / out-of-scope: (1) polling-scope clarification dismissed by user (heartbeat-only vs. passive-observation vs. only-update-changed-cells — left as-is, table updates all cells every tick); (2) Info button + markdown help — scoped up to a milestone-sized "unified in-app help/wiki" effort, parked as backlog 999.1. | 2026-05-19 | b2ed937, e8a1be5, 43d2d3b, 2a24965, 50d464c, 10df740, 73a3bf1 | Verified | [260519-bs4-implement-a-new-table-view-in-the-compan](./quick/260519-bs4-implement-a-new-table-view-in-the-compan/) |

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
- 2026-05-13 — Milestone v4.0 Multi-User LAN Concurrency started; PROJECT.md updated, REQUIREMENTS.md created (14 P1 REQ-IDs across CONC/IDENT/EVTLOG/ACK/OPS categories; 6 P2 deferred to v4.1); research/ phase produced SUMMARY/STACK/FEATURES/ARCHITECTURE/PITFALLS markdown
- 2026-05-13 — v4.0 roadmap created: 5 phases (1029-1033) covering all 14 P1 REQ-IDs, full coverage no orphans; phase structure mirrors research-recommended build order (Foundation → TagWriteCoordinator → EventLog → Single-Source Events → Companion Integration); three PITFALLS corrections (OFD locks, mtime heartbeat, lock-serialised appends) baked into Phase 1029 success criteria

### Phase Numbering Note

v2.1 phases in the phases/ directory extend to 1017 (1012, 1013, 1014, 1017). v3.0 phases extended to 1023.1. Pending unscoped phases 1025-1028 are carry-forward from a backlog promotion (NOT v4.0). v4.0 phases start at **1029** to leave room for the pending carry-forward and avoid collision.

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
- **Phase 1029 planning (v4.0):** `lockfile_mex.c` OFD-vs-`F_SETLK` branching; Win32 `LockFileEx` flag combinations; `F_OFD_SETLK` re-acquire behaviour from same process (LOW confidence per SUMMARY.md); empirical `staleTimeout` calibration on target office LAN; mksqlite `extended_result_codes` pass-through probe (feeds Phase 1032's retry wrapper).
- **Phase 1031 planning (v4.0):** SMB atomicity stress test on the target file server (Pitfalls 4 + 5 + 12); phase budget includes contingency to re-architect to per-writer-file + merge if SMB atomicity fails.
- **Phase 1032 planning (v4.0):** SQLite `BUSY_SNAPSHOT` retry semantics under 50-writer contention; retry-loop tuning needs 20-process write-contention test.

### Decisions (Phase 1020)

- **1020-02:** applyFilter_() is the single rebuild path for DashboardListPane row list; onRowClicked_ sets SelectedIdx_ then calls applyFilter_() for highlight rather than painting individual buttons
- **1020-02:** addDashboard uses handle identity (==) for duplicate detection; removeDashboard uses Name (case-sensitive strcmp) for lookup per CONTEXT.md
- **1020-02:** Listeners re-wired in setProject after detach clears them; SelectedDashboardIdx_ clamped to 0 in refresh() when engine list shrinks

### Decisions (Phase 1028)

- **1028-02b/02d/05/06 DI-seam pattern:** All four mid-phase architectural levers share a single shape — `Access = private` flag (production default true) + `Hidden setFooForTesting_(tf)` setter that validates `logical scalar`. This preserves D-10 (no public API), gives the harness a single flip-point per lever, and makes the test surface uniform. Future phases that add a switchable behaviour to a Tag-pipeline class should follow this pattern.
- **1028-02d in-memory cache mechanism:** The big win in the phase was a read-side cache, not a write-side coalesce. The original Plan 02d framing ("coalesce within-tick semantics") was wrong — `processTag_` already calls `writeFn_` exactly once per tag per tick. The actual mechanism is a `containers.Map` of `tag.Key -> struct('X', priorX, 'Y', priorY)` populated lazily and refreshed after every write, skipping the per-tick `load()` inside `writeTagMat_('append',...)`. Crash-recovery semantics preserved because `save()` cadence is unchanged.
- **1028-03/04 deferral was data-driven, not a scope cut:** K2/K3/K4 kernel target regions bucket as 0 ms in the post-cache `tBreakdown` profile. Plans 03/04 PLAN.md files exist on disk and are valid pickup points if a future profile pass with direct `tic/toc` probes finds those regions to be non-trivial. The deferral is documented in VERIFICATION.md and the 1028-06-SUMMARY.md retrospective.
- **1028-05 null-result ship-the-seam pattern:** When a planned architectural lever's expected mechanism doesn't materialise empirically, ship the lever as an internal seam and surface the null result in VERIFICATION.md. Avoid the false dichotomy of "meets ship-criterion → ship" vs "doesn't → revert"; the third option is "ships as forward-compat, doesn't move today's number". Establishes a precedent for honest measurement reporting.
- **1028-06 fs-stat coalesce mechanism:** One `dir(parentDir)` per unique parent directory per tick, keyed map populated lazily on first lookup, frozen for the rest of that tick. Octave-safe (no MATLAB-specific syntax). Trade-off: a file appearing mid-tick is NOT visible in that tick. Acceptable because the per-tag mtime check vs `lastModTime` already serialises ingestion at tick boundaries.

### Carry-Forward

- **v2.1 Tag-API Tech Debt Cleanup** — in flight, parallel to v3.0/v4.0. Phases 1012-1017. Does not block v4.0 work.
- **Pending unscoped phases 1025-1028** — promoted from backlog 2026-05-08; NOT v4.0 scope. 1025 + 1026 largely addressed via quick tasks 260508-d8y / 260508-das. 1027/1027.1 complete. 1028 (Tag update perf — MEX + SIMD) remains on the books, may be re-scoped later.
