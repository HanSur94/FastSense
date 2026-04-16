---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Tag-Based Domain Model
status: executing
stopped_at: "Completed 1005-02-PLAN.md — StateTag (219 SLOC) with ZOH valueAt byte-for-byte matching StateChannel + StateTag:emptyState hygiene guard; TestStateTag (17 methods) + test_statetag (29 asserts) GREEN; legacy StateChannel/Sensor byte-for-byte unchanged (Pitfall 5 PASS); Plan 1005-03 (FastSense.addTag dispatcher) unblocked"
last_updated: "2026-04-16T14:24:06.955Z"
last_activity: 2026-04-16
progress:
  total_phases: 15
  completed_phases: 7
  total_plans: 26
  completed_plans: 25
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-16)

**Core value:** Users can organize complex dashboards into navigable sections and pop out any widget for detailed analysis without losing the dashboard context.
**Current focus:** Phase 1005 — SensorTag + StateTag (data carriers)

## Current Position

Phase: 1005 (SensorTag + StateTag (data carriers)) — EXECUTING
Plan: 3 of 3
Status: Ready to execute
Last activity: 2026-04-16

Progress: [░░░░░░░░░░] 0% (0/8 v2.0 phases complete)

## Performance Metrics

**Velocity:**

- Total plans completed: 0 (v2.0)
- Average duration: —
- Total execution time: 0 hours (v2.0)

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
| Phase 999.3 P01 | 3min | 2 tasks | 2 files |
| Phase 999.3-graph-data-export-mat-csv P02 | 2min | 2 tasks | 2 files |
| Phase 1000 P01 | 4min | 2 tasks | 2 files |
| Phase 1000 P02 | 2 | 2 tasks | 2 files |
| Phase 1000 P03 | 5min | 2 tasks | 2 files |
| Phase 1002 P02 | 25 | 2 tasks | 6 files |
| Phase 1003 P01 | 3min | 1 tasks | 3 files |
| Phase 1003 P03 | 10min | 1 tasks | 3 files |
| Phase 1004-tag-foundation-golden-test P01 | 4min | 2 tasks | 4 files |
| Phase 1004-tag-foundation-golden-test P02 | 6min | 2 tasks | 4 files |
| Phase 1004-tag-foundation-golden-test P03 | 3min | 2 tasks | 3 files |
| Phase 1005-sensortag-statetag-data-carriers P01 | 4min | 2 tasks | 3 files |
| Phase 1005 P02 | 8min | 2 tasks | 3 files |

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
- [Phase 999.3]: No render() required before exportData() — buildExportStruct_ accesses raw Lines/Thresholds directly
- [Phase 999.3]: testExportCSVDatetime guarded with ~exist('OCTAVE_VERSION') since datetime is MATLAB-only
- [Phase 999.3]: exportData dual-API mirrors exportPNG: no-arg opens dialog, with-arg saves directly (extension determines format)
- [Phase 999.3]: Used regexp for Octave-safe extension guard in onExportData instead of endsWith()
- [Phase 1000-02]: Debounce timer uses ExecutionMode singleShot with 0.1s StartDelay — each slider event cancels/replaces previous timer
- [Phase 1000-02]: repositionPanels no longer calls markDirty — position change alone does not require data refresh
- [Phase 1000]: Sensor identity comparison uses MATLAB handle == operator; on sensor swap LastSensorRef mismatch triggers full teardown
- [Phase 1000]: CachedXMax always set to x(n) on each tick; CachedXMin only initialised once when inf to avoid overwriting on incremental append
- [Phase 1000-03]: allocatePanels for non-active pages so Realized stays false at startup; realizeBatch(5) in switchPage reuses batch infrastructure
- [Phase 1002]: IconCardWidget Threshold resolver in own varargin constructor; mutual exclusivity post-loop
- [Phase 1002]: MultiStatusWidget toStruct emits s.items typed array for mixed Sensor/threshold entries
- [Phase 1002]: ChipBarWidget threshold block before statusFcn in resolveChipColor so threshold takes priority
- [Phase 1003]: CompositeThreshold extends Threshold directly so isa check works; AND/OR/MAJORITY via AggregateMode property; toStruct children as cell of structs with key+optional value; fromStruct resolves via ThresholdRegistry with warn-and-skip for missing keys; isequal() for Octave-safe handle identity
- [Phase 1004]: Tag base uses throw-from-base (error 'Tag:notImplemented') rather than methods (Abstract); exactly 6 stubs enforced by runtime grep test; test abstract stubs by instantiating Tag('k') directly (portable MATLAB+Octave); Criticality setter validates ischar before strcmp; Name defaults to Key in constructor; MockTag.toStruct wraps Labels to survive struct() cellstr collapse
- [Phase 1004-tag-foundation-golden-test]: TagRegistry hard-errors on duplicate key (Pitfall 7) — departure from ThresholdRegistry's silent-overwrite
- [Phase 1004-tag-foundation-golden-test]: Two-phase loadFromStructs (Pass 1 instantiate+register, Pass 2 resolveRefs in try/catch) is the canonical Tag-family serialization pattern; wraps any resolveRefs failure as TagRegistry:unresolvedRef (Pitfall 8)
- [Phase 1004-tag-foundation-golden-test]: instantiateByKind dispatch table lives on TagRegistry (not Tag base) so Phase 1005+ extends kinds by adding switch cases rather than touching the abstract base class
- [Phase 1004-tag-foundation-golden-test]: Golden integration test dual-style (TestGoldenIntegration.m + test_golden_integration.m) exercises full legacy Sensor+StateChannel+Threshold+CompositeThreshold+EventDetector+FastSense path with DO NOT REWRITE grep-enforced header; fixture mirrors test_event_integration.m Y pattern so assertion values (events at t=4 peak 16 and t=13 peak 22) are known-good
- [Phase 1004-tag-foundation-golden-test]: Phase-wide budget verification committed as 1004-BUDGET-VERIFICATION.md with 16 PASS verdicts across 6 gates (Pitfalls 1/5/7/8/11 + Success Criterion 4); 10/20 files touched (50% margin); zero edits across 15-file forbidden-path grep
- [Phase 1005-sensortag-statetag-data-carriers]: SensorTag is classdef < Tag composing a private Sensor_ delegate (HAS-A, not IS-A); getXY/getTimeRange/valueAt implemented directly, load/toDisk/toMemory/isOnDisk forward to inner Sensor; toStruct omits X/Y by design (runtime data); fromStruct uses compact fieldOr_ helper
- [Phase 1005-02]: StateTag.valueAt byte-for-byte copy of StateChannel.valueAt (scalar+vector × numeric+cellstr); only addition is StateTag:emptyState guard at top
- [Phase 1005-02]: splitArgs_ uses while-loop with hasX/hasY flags (not ~isempty) so explicit 'X',[] construction is distinguishable from the defaulted path and dangling-key errors are hygienic
- [Phase 1005-02]: toStruct double-wraps cellstr Y via {obj.Y} (same defense as Labels) to survive MATLAB struct() cellstr-collapse; fromStruct unwraps symmetrically; X/Y inlined because state channels are small by nature

### Roadmap Evolution

- Phase 8 added: Widget improvements — DividerWidget, CollapsibleWidget, Y-axis limits
- Phase 1 added: Dashboard Performance Optimization — faster creation, instantiation, and interactivity
- Phase 1000 added: Dashboard Engine Performance Optimization Phase 2 — 6 bottlenecks: incremental FastSenseWidget refresh, debounced slider broadcast, lazy page realization, cached time ranges, batched page switch, debounced resize
- Milestone v2.0 added: Tag-Based Domain Model (Ambitious tier — A+B+C+E) — full SensorThreshold reboot under unified `Tag` root + MonitorTag time-series + CompositeTag aggregation + events attached to tags
- Phases 1004-1011 mapped (2026-04-16): 8-phase strangler-fig decomposition — Tag introduced as parallel hierarchy in Phase 1004; legacy classes deleted only in Phase 1011. 45/45 v2.0 REQs mapped (TAG, MONITOR, COMPOSITE, META, EVENT, ALIGN, MIGRATE). Phase 1009 owns no exclusive REQ-IDs (structural consumer-migration phase).

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 1004: ≤20-file budget for the parallel-hierarchy introduction is the falsifiable gate per Pitfall 5 — if Phase 1004 plan exceeds this, the strangler-fig sequencing is broken and the plan must be re-scoped before execution
- Phase 1006: MonitorTag live-tick performance unverified — bench at phase exit (≤10% regression vs. legacy `Sensor.resolve` at 12-widget tick)
- Phase 1008: CompositeTag merge-sort streaming aggregation must avoid N×M union materialization — 8 children × 100k samples bench gates phase exit (<50MB peak, <200ms compute)
- Phase 1009: Per-widget consumer migration is many small commits, not one big PR — each commit must keep `tests/run_all_tests.m` AND the golden integration test green

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260403-nvv | Add example_dashboard_advanced.m showcasing all phase 01-08 features | 2026-04-03 | 45e456f | [260403-nvv-add-or-edit-example-script-showcasing-al](./quick/260403-nvv-add-or-edit-example-script-showcasing-al/) |
| 260404-gaj | CI MEX build matrix: macOS ARM64, Windows 10+11, Linux Ubuntu | 2026-04-04 | pending | [260404-gaj-implement-github-actions-ci-workflow-tha](./quick/260404-gaj-implement-github-actions-ci-workflow-tha/) |
| 260405-l0t | Add example_mushroom_cards.m showcasing IconCardWidget, ChipBarWidget, SparklineCardWidget | 2026-04-05 | c32b2aa | [260405-l0t-add-example-script-showcasing-mushroom-c](./quick/260405-l0t-add-example-script-showcasing-mushroom-c/) |
| 260405-oqu | Create 4 dedicated widget example scripts (iconcard, chipbar, sparkline, divider) | 2026-04-05 | 1f53bca | [260405-oqu-create-5-dedicated-widget-example-script](./quick/260405-oqu-create-5-dedicated-widget-example-script/) |
| 260405-ovf | Update README based on research of 12 highly-starred open-source projects | 2026-04-05 | 144fbb2 | [260405-ovf-update-project-readme-based-on-research-](./quick/260405-ovf-update-project-readme-based-on-research-/) |
| 260405-plc | Change DashboardToolbar Edit button to open source file in MATLAB editor | 2026-04-05 | 5188b04 | [260405-plc-change-the-edit-button-of-dashboardengin](./quick/260405-plc-change-the-edit-button-of-dashboardengin/) |

## Session Continuity

Last session: 2026-04-16T14:24:06.951Z
Stopped at: Completed 1005-02-PLAN.md — StateTag (219 SLOC) with ZOH valueAt byte-for-byte matching StateChannel + StateTag:emptyState hygiene guard; TestStateTag (17 methods) + test_statetag (29 asserts) GREEN; legacy StateChannel/Sensor byte-for-byte unchanged (Pitfall 5 PASS); Plan 1005-03 (FastSense.addTag dispatcher) unblocked
Resume file: None
