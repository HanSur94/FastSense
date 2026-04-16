---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Completed 1006-04-PLAN.md (exportgraphics headless image export fix)
last_updated: "2026-04-16T13:50:40.400Z"
last_activity: 2026-04-16
progress:
  total_phases: 9
  completed_phases: 7
  total_plans: 27
  completed_plans: 26
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-01)

**Core value:** Users can organize complex dashboards into navigable sections and pop out any widget for detailed analysis without losing the dashboard context.
**Current focus:** Phase 1006 — fix-137-matlab-test-failures

## Current Position

Phase: 1006 (fix-137-matlab-test-failures) — EXECUTING
Plan: 4 of 4
Status: Ready to execute
Last activity: 2026-04-16

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01-infrastructure-hardening P01-01 | 148 | 1 tasks | 2 files |
| Phase 01-infrastructure-hardening P02 | 900 | 2 tasks | 3 files |
| Phase 01-infrastructure-hardening P01-03 | 15min | 3 tasks | 3 files |
| Phase 01-infrastructure-hardening P01-04 | 1min | 1 tasks | 1 files |
| Phase 02-collapsible-sections P02-02 | 5 | 2 tasks | 1 files |
| Phase 02-collapsible-sections P02-01 | 11min | 2 tasks | 4 files |
| Phase 03-widget-info-tooltips P01 | 6min | 2 tasks | 2 files |
| Phase 03-widget-info-tooltips P02 | 15min | 2 tasks | 2 files |
| Phase 03-widget-info-tooltips P03-03 | 1min | 1 tasks | 2 files |
| Phase 04-multi-page-navigation P04-01 | 15min | 2 tasks | 4 files |
| Phase 04 P02 | 20min | 2 tasks | 1 files |
| Phase 04-multi-page-navigation P04-03 | 6min | 2 tasks | 2 files |
| Phase 04-multi-page-navigation P04-04 | 2 | 1 tasks | 1 files |
| Phase 05-detachable-widgets P05-01 | 8min | 2 tasks | 2 files |
| Phase 05-detachable-widgets P05-02 | 2min | 2 tasks | 2 files |
| Phase 05-detachable-widgets P05-03 | 25min | 2 tasks | 1 files |
| Phase 06-serialization-persistence P06-02 | 25 | 2 tasks | 2 files |
| Phase 06-serialization-persistence P01 | 11min | 2 tasks | 2 files |
| Phase 07-tech-debt-cleanup P07-01 | 1min | 2 tasks | 2 files |
| Phase 08 P03 | 2min | 1 tasks | 2 files |
| Phase 08-widget-improvements-dividerwidget-collapsiblewidget-y-axis-limits P08-01 | 5 | 2 tasks | 6 files |
| Phase 08-widget-improvements-dividerwidget-collapsiblewidget-y-axis-limits P08-02 | 4min | 1 tasks | 2 files |
| Phase 09-threshold-mini-labels-in-fastsense-plots P01 | 2min | 2 tasks | 1 files |
| Phase 09-threshold-mini-labels-in-fastsense-plots P02 | 2min | 2 tasks | 2 files |
| Phase 01-dashboard-engine-code-review-fixes P01-01 | 2 | 2 tasks | 2 files |
| Phase 01-dashboard-engine-code-review-fixes P03 | 4min | 2 tasks | 2 files |
| Phase 01-dashboard-engine-code-review-fixes P04 | 2min | 2 tasks | 7 files |
| Phase 01-dashboard-performance-optimization P01 | 3 | 2 tasks | 2 files |
| Phase 01-dashboard-performance-optimization P03 | 10min | 2 tasks | 1 files |
| Phase 999.1-mushroom-cards-for-dashboard-engine P04 | 5min | 2 tasks | 8 files |
<<<<<<< HEAD
| Phase 999.3 P01 | 3min | 2 tasks | 2 files |
| Phase 999.3-graph-data-export-mat-csv P02 | 2min | 2 tasks | 2 files |
| Phase 1000 P01 | 4min | 2 tasks | 2 files |
| Phase 1000 P02 | 2 | 2 tasks | 2 files |
=======
| Phase 1000 P03 | 5min | 2 tasks | 2 files |
>>>>>>> worktree-agent-a9506b74
| Phase 1002 P02 | 25 | 2 tasks | 6 files |
| Phase 1003 P01 | 3min | 1 tasks | 3 files |
| Phase 1003 P03 | 10min | 1 tasks | 3 files |
| Phase 1004 P01 | 5min | 2 tasks | 2 files |
| Phase 1004 P02 | 8min | 2 tasks | 1 files |
| Phase 1004 P03 | 2min | 2 tasks | 2 files |
| Phase 1006 P01 | 5 | 3 tasks | 2 files |
| Phase 1006 P02 | 10min | 2 tasks | 4 files |
| Phase 1006 P04 | 8 | 2 tasks | 1 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- — see PROJECT.md Key Decisions for pending architectural choices (EngineRef pattern, info tooltip click mechanism, DetachedMirror timer strategy)
- [Phase 01-infrastructure-hardening]: ErrorFcn added to DashboardEngine.LiveTimer using onLiveTimerError; timer restart guarded by IsLive flag
- [Phase 01-infrastructure-hardening]: normalizeToCell placed in libs/Dashboard/private/ per INFRA-03; test uses indirect verification via DashboardSerializer.loadJSON due to MATLAB private/ path restrictions
- [Phase 01-infrastructure-hardening]: GroupWidget children emitted via constructors not d.addWidget() to avoid adding them as top-level widgets; groupCount threaded through emitChildWidget to prevent variable name collisions
- [Phase 01-infrastructure-hardening]: Test triggers ErrorFcn indirectly via a throwing TimerFcn rather than calling private onLiveTimerError directly
- [Phase 02-collapsible-sections]: All 6 DashboardTheme presets pass tab contrast checks (delta >= 0.05); no DashboardTheme.m changes needed for LAYOUT-08
- [Phase 02-collapsible-sections]: Used EngineRef callback pattern (lambda injection) for ReflowCallback, consistent with Phase 1 LiveTimer ErrorFcn pattern
- [Phase 02-collapsible-sections]: reflowAfterCollapse() guards on hFigure validity to avoid errors when no figure is rendered
- [Phase 03-widget-info-tooltips]: openInfoPopup/closeInfoPopup made public for testability; hFigure/hInfoPopup as public properties for test injection and state verification
- [Phase 03-widget-info-tooltips]: closeInfoPopup guards callback restore with wasOpen flag to prevent overwriting prior figure callbacks during guard call at start of openInfoPopup
- [Phase 03-widget-info-tooltips]: hFigure already stored in allocatePanels() by 03-01 — no DashboardEngine wiring needed; reflow() guard added via closeInfoPopup() before createPanels()
- [Phase 03-widget-info-tooltips]: Strip HTML tags after MarkdownRenderer.render() to produce plain text for uicontrol edit control; static private stripHtmlTags helper added to DashboardLayout
- [Phase 04-multi-page-navigation]: DashboardPage is a standalone file (not nested struct) for clean module separation; addWidget() accepts DashboardWidget objects via isa() guard; active page defaults to last-added Pages entry
- [Phase 04]: ActivePage stays at 1 after multiple addPage() calls — only switchPage() changes it; matches testSwitchPage expectations
- [Phase 04]: Hidden PageBar placeholder created for single-page so hPageBar is always valid after render(); testPageBarHiddenSinglePage passes
- [Phase 04-multi-page-navigation]: save() uses file extension (.json vs .m) to route to saveJSON() or DashboardSerializer.save(); multi-page uses exportScriptPages() for .m
- [Phase 04-multi-page-navigation]: widgetsPagesToConfig() is a parallel path to widgetsToConfig() — not calling widgetsToConfig internally for clean separation
- [Phase 04-multi-page-navigation]: Added switchPage(2) before save() in testSaveLoadRoundTrip to establish non-default active page before asserting loaded.ActivePage == 2
- [Phase 05-detachable-widgets]: DetachedMirror is NOT a DashboardWidget subclass - wraps one to avoid grid layout entanglement
- [Phase 05-detachable-widgets]: cloneWidget() uses explicit 15-type dispatch switch in DetachedMirror for self-containment
- [Phase 05-detachable-widgets]: DashboardEngine.render() sets Layout.DetachCallback = @(w) obj.detachWidget(w) as forward reference; plan 03 implements detachWidget() method
- [Phase 05-detachable-widgets]: Detach button String='^' (ASCII caret) per RESEARCH.md open question 2 — safe cross-platform fallback
- [Phase 05-detachable-widgets]: containers.Map used as handle-class indirect reference for removeCallback forward-reference pattern in detachWidget()
- [Phase 05-detachable-widgets]: removeDetachedByRef() (private, identity-based) separates close-triggered removal from stale-scan cleanup in onLiveTick()
- [Phase 06-serialization-persistence]: exportScriptPages fixed to emit function wrapper + two-pass addPage/switchPage so feval and widget routing work correctly for multi-page .m files
- [Phase 06-serialization-persistence]: Pre-existing TestDashboardSerializerRoundTrip/testRoundTripPreservesWidgetSpecificProperties failure confirmed out-of-scope for plan-02
- [Phase 06-serialization-persistence]: Single non-default named page must serialize with widgetsPagesToConfig (pages field) not widgetsToConfig (widgets field)
- [Phase 06-serialization-persistence]: switchPage() required before addWidget() to route widget to non-first page in multi-page mode
- [Phase 07-tech-debt-cleanup]: Time panel methods delegate to activePageWidgets() for multi-page scoping; single-page backward compatibility preserved via fallback in activePageWidgets()
- [Phase 08]: YLimits omitted from toStruct when empty to preserve backward-compatible JSON
- [Phase 08]: ylim() applied after fp.render() in both render() and refresh() — both paths must apply limits after axis rebuild
- [Phase 08-widget-improvements]: DividerWidget uses uipanel with BackgroundColor for the divider line; save()/exportScript() emit without Title since divider widgets are purely decorative
- [Phase 08-widget-improvements-dividerwidget-collapsiblewidget-y-axis-limits]: addCollapsible delegates to addWidget('group') so multi-page routing is automatic; varargin forwarding allows Collapsed, Position, and other GroupWidget properties
- [Phase 09-threshold-mini-labels-in-fastsense-plots]: ShowThresholdLabels=false default makes label feature zero-cost and fully backward compatible; Octave fallback via try/catch for BackgroundColor/Margin/EdgeColor
- [Phase 09-threshold-mini-labels-in-fastsense-plots]: ShowThresholdLabels wired before render() call in both render() and refresh(); showThresholdLabels omitted from JSON when false for backward compat
- [Phase 01-dashboard-engine-code-review-fixes]: removeWidget branches on ~isempty(obj.Pages) to operate on Pages{ActivePage}.Widgets in multi-page mode
- [Phase 01-dashboard-engine-code-review-fixes]: wireListeners() extracted as private method; called in both addWidget paths for sensor PostSet listener parity
- [Phase 01-dashboard-engine-code-review-fixes]: onResize delegates entirely to rerenderWidgets(); markAllDirty+realizeBatch was insufficient for panel repositioning
- [Phase 01-dashboard-engine-code-review-fixes]: linesForWidget uses indent parameter so exportScript (no indent) and exportScriptPages (4-space indent) share one widget dispatch implementation
- [Phase 01-dashboard-engine-code-review-fixes]: save() and emitChildWidget() left unchanged — constructor-style generation serves different purpose than d.addWidget() script generation
- [Phase 01-dashboard-engine-code-review-fixes]: markRealized/markUnrealized accessor methods enforce Realized SetAccess=private encapsulation in DashboardWidget
- [Phase 01-dashboard-engine-code-review-fixes]: BarChartWidget YData in-place update uses try-catch for Octave bar object property access compatibility
- [Phase 01-dashboard-performance-optimization]: bench_dashboard.m uses rows 1-8 layout with 6 fastsense, 4 number, 4 status, 3 group, 2 text, 1 barchart for representative 20-widget benchmark
- [Phase 01-dashboard-performance-optimization]: testLiveTickUnder50ms uses 200ms generous CI ceiling (target 50ms post-optimization) to avoid flakiness before Plan 02-03 implement speedup
- [Phase 01-dashboard-performance-optimization]: updateLiveTimeRangeFrom(ws) added alongside updateLiveTimeRange() so onLiveTick can pass pre-fetched widget list
- [Phase 01-dashboard-performance-optimization]: repositionPanels() falls back to rerenderWidgets() if any panel handle is missing — safe degradation at first render
- [Phase 01-dashboard-performance-optimization]: render() pre-allocates all page panels at startup with non-active pages hidden so switchPage is pure visibility toggle
- [Phase 999.1-mushroom-cards-for-dashboard-engine]: Wave 1 widget files copied from main repo to worktree for plan 04; DetachedMirror restoreLiveRefs handles ValueFcn generically via isprop so no per-type clone code needed beyond fromStruct dispatch

<<<<<<< HEAD

- [Phase 999.3]: No render() required before exportData() — buildExportStruct_ accesses raw Lines/Thresholds directly
- [Phase 999.3]: testExportCSVDatetime guarded with ~exist('OCTAVE_VERSION') since datetime is MATLAB-only
- [Phase 999.3]: exportData dual-API mirrors exportPNG: no-arg opens dialog, with-arg saves directly (extension determines format)
- [Phase 999.3]: Used regexp for Octave-safe extension guard in onExportData instead of endsWith()
- [Phase 1000-02]: Debounce timer uses ExecutionMode singleShot with 0.1s StartDelay — each slider event cancels/replaces previous timer
- [Phase 1000-02]: repositionPanels no longer calls markDirty — position change alone does not require data refresh
- [Phase 1000]: Sensor identity comparison uses MATLAB handle == operator; on sensor swap LastSensorRef mismatch triggers full teardown
- [Phase 1000]: CachedXMax always set to x(n) on each tick; CachedXMin only initialised once when inf to avoid overwriting on incremental append

=======

- [Phase 1000-03]: allocatePanels for non-active pages so Realized stays false at startup; realizeBatch(5) in switchPage reuses batch infrastructure

>>>>>>> worktree-agent-a9506b74

- [Phase 1002]: IconCardWidget Threshold resolver in own varargin constructor; mutual exclusivity post-loop
- [Phase 1002]: MultiStatusWidget toStruct emits s.items typed array for mixed Sensor/threshold entries
- [Phase 1002]: ChipBarWidget threshold block before statusFcn in resolveChipColor so threshold takes priority
- [Phase 1003]: CompositeThreshold extends Threshold directly so isa check works; AND/OR/MAJORITY via AggregateMode property; evaluateLeaf_ uses IsUpper; addChild uses warning not error for unknown key
- [Phase 1003]: toStruct children as cell of structs with key+optional value; fromStruct resolves via ThresholdRegistry with warn-and-skip for missing keys; isequal() for Octave-safe handle identity
- [Phase 1004]: exportImage uses datestr 'yyyymmdd_HHMMSS' not ISO 'yyyyMMdd_HHmmss'; format inferred from extension if omitted; notRendered check uses isempty + ishandle guard
- [Phase 1004]: Image button inserted between Export and Save in right-to-left DashboardToolbar layout; dispatchImageExport extracted for testable cancel no-op; datestr format 'yyyymmdd_HHMMSS' confirmed over ISO notation
- [Phase 1004]: testCancelNoOp uses dispatchImageExport(0,'',1) directly to bypass uiputfile without mocking
- [Phase 1004]: Octave suite skips IMG-01 (button verification): Octave print() excludes uicontrols by default per RISK-1
- [Phase 1006]: D-01 implemented: pinned all setup-matlab@v3 call-sites to release: R2020b in tests.yml (x2) and examples.yml (x1)
- [Phase 1006]: MEX cache key scoped to r2020b (mex-matlab-linux-r2020b-) to prevent ABI-stale binary reuse on future pin bumps
- [Phase 1006-02]: Branch C selected for mksqlite fix: assumeTrue(exist('mksqlite','file')==3) guard in TestMethodSetup; tests filter rather than fail when mksqlite absent
- [Phase 1006-02]: build_mex:mksqliteCompileFailed warning ID added to silent catch so compile failures surface in CI step summaries
- [Phase 1006]: exportImage uses three-branch dispatch: exportapp (R2024a+), exportgraphics (R2020a-R2023b headless-safe), print+stub-axes (Octave unchanged)

### Roadmap Evolution

- Phase 8 added: Widget improvements — DividerWidget, CollapsibleWidget, Y-axis limits
- Phase 1 added: Dashboard Performance Optimization — faster creation, instantiation, and interactivity
- Phase 1000 added: Dashboard Engine Performance Optimization Phase 2 — 6 bottlenecks: incremental FastSenseWidget refresh, debounced slider broadcast, lazy page realization, cached time ranges, batched page switch, debounced resize
- Phase 1005 added: Expand CI coverage — MATLAB + Octave tests on macOS and Windows, MATLAB benchmark (COV-01 through COV-06). Builds on quick tasks 260416-j6e/jfo/jnp/k23.
- Phase 1006 added: Fix 137 MATLAB test failures surfaced by CI improvements (7 categories from R2025b drift). Scope driven by debug investigation at `.planning/debug/matlab-tests-failures-investigation.md`. MATLABFIX-G (version pinning) should be discussed before planning A-F because G1 (pin R2020b) eliminates ~71 tests worth of work.

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 3 (Multi-Page): DashboardEngine render guard interaction with panel-visibility-based page switching needs architecture review before implementation starts
- Phase 5 (Detachable): `cloneForDetach()` for FastSenseWidget and RawAxesWidget involves non-serializable live references — enumerate affected widget types at phase start

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260403-nvv | Add example_dashboard_advanced.m showcasing all phase 01-08 features | 2026-04-03 | 45e456f | [260403-nvv-add-or-edit-example-script-showcasing-al](./quick/260403-nvv-add-or-edit-example-script-showcasing-al/) |
| 260404-gaj | CI MEX build matrix: macOS ARM64, Windows 10+11, Linux Ubuntu | 2026-04-04 | pending | [260404-gaj-implement-github-actions-ci-workflow-tha](./quick/260404-gaj-implement-github-actions-ci-workflow-tha/) |
| 260405-l0t | Add example_mushroom_cards.m showcasing IconCardWidget, ChipBarWidget, SparklineCardWidget | 2026-04-05 | c32b2aa | [260405-l0t-add-example-script-showcasing-mushroom-c](./quick/260405-l0t-add-example-script-showcasing-mushroom-c/) |
| 260405-oqu | Create 4 dedicated widget example scripts (iconcard, chipbar, sparkline, divider) | 2026-04-05 | 1f53bca | [260405-oqu-create-5-dedicated-widget-example-script](./quick/260405-oqu-create-5-dedicated-widget-example-script/) |
| 260405-ovf | Update README based on research of 12 highly-starred open-source projects | 2026-04-05 | 144fbb2 | [260405-ovf-update-project-readme-based-on-research-](./quick/260405-ovf-update-project-readme-based-on-research-/) |
| 260405-plc | Change DashboardToolbar Edit button to open source file in MATLAB editor | 2026-04-05 | 5188b04 | [260405-plc-change-the-edit-button-of-dashboardengin](./quick/260405-plc-change-the-edit-button-of-dashboardengin/) |
| 260416-hau | Fix Octave 11 abstract methods incompat in DashboardWidget.m (+ 2 related Octave gaps) | 2026-04-16 | dbd109e | [260416-hau-fix-octave-11-abstract-methods-incompat-](./quick/260416-hau-fix-octave-11-abstract-methods-incompat-/) |
| 260416-j6e | Enable MATLAB CI on every push/PR: upgrade setup-matlab v2->v3 with cache, add build-mex-matlab job, remove schedule gate, keep Octave | 2026-04-16 | 97c1576 | [260416-j6e-enable-matlab-ci-on-every-push-pr-upgrad](./quick/260416-j6e-enable-matlab-ci-on-every-push-pr-upgrad/) |
| 260416-jfo | CI quick wins bundle: concurrency groups + per-job timeouts, MATLAB examples on push, step summaries, Dependabot (Octave Codecov deferred) | 2026-04-16 | 5e0efea | [260416-jfo-ci-quick-wins-bundle-concurrency-groups-](./quick/260416-jfo-ci-quick-wins-bundle-concurrency-groups-/) |
| 260416-jnp | DRY refactor: extract duplicated Octave build-mex job into reusable workflow (_build-mex-octave.yml) with artifact-name input | 2026-04-16 | 5ab68e0 | [260416-jnp-dry-refactor-extract-duplicated-octave-b](./quick/260416-jnp-dry-refactor-extract-duplicated-octave-b/) |
| 260416-k23 | Upgrade Octave CI containers 8.4.0 → 11.1.0 and drop break_closure_cycles workaround (upstream bug #67749 fixed in 11.1.0) | 2026-04-16 | c371b6f | [260416-k23-upgrade-octave-ci-containers-8-4-0-to-11](./quick/260416-k23-upgrade-octave-ci-containers-8-4-0-to-11/) |

## Session Continuity

Last session: 2026-04-16T13:50:40.394Z
Stopped at: Completed 1006-04-PLAN.md (exportgraphics headless image export fix)
Resume file: None
