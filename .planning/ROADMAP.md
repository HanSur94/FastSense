# Roadmap: FastSense Advanced Dashboard

## Overview

This milestone extends the existing FastSense dashboard engine with three major capabilities: nested layout organization (collapsible sections and multi-page navigation), per-widget info tooltips, and detachable live-mirrored widgets. Infrastructure hardening runs first to fix known timer and serializer bugs that would otherwise destabilize later phases. The work then proceeds through self-contained feature deliveries before a final serialization and compatibility verification pass.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Infrastructure Hardening** - Fix timer safety, GroupWidget .m export bug, jsondecode normalization, and validate backward compatibility (completed 2026-04-01)
- [x] **Phase 2: Collapsible Sections** - Wire grid reflow into GroupWidget collapse/expand so collapsing reclaims screen space (completed 2026-04-01)
- [x] **Phase 3: Widget Info Tooltips** - Add info icon and click-driven description popup to all widget header chrome (completed 2026-04-01)
- [x] **Phase 4: Multi-Page Navigation** - Add DashboardPage container, PageBar UI, and page-switching with active-page persistence (completed 2026-04-01)
- [x] **Phase 5: Detachable Widgets** - Detach button on every widget; DetachedMirror class; live sync via shared timer (completed 2026-04-02)
- [x] **Phase 6: Serialization & Persistence** - Verify and harden round-trip correctness for all new structures across JSON and .m formats (completed 2026-04-02)
- [x] **Phase 7: Tech Debt Cleanup** - Fix multi-page time panel scoping and test comment mislabeling (completed 2026-04-03)
- [x] **Phase 8: Widget Improvements** - DividerWidget, addCollapsible API, Y-axis limits on FastSenseWidget (completed 2026-04-03)
- [x] **Phase 9: Threshold Mini-Labels in FastSense Plots** - Optional inline labels within plot axes showing threshold names (completed 2026-04-03)

## Phase Details

### Phase 1: Infrastructure Hardening
**Goal**: The dashboard engine is safe to extend — timer errors cannot silently kill refresh, GroupWidget children survive .m export, and jsondecode normalization is applied wherever nested arrays are decoded
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-01, INFRA-02, INFRA-03, COMPAT-01, COMPAT-02, COMPAT-03, COMPAT-04
**Success Criteria** (what must be TRUE):
  1. When an error occurs inside the live timer tick, the timer continues running and the error is logged (does not silently stop)
  2. A GroupWidget with children exported to .m and re-imported loads all children correctly
  3. All existing dashboard scripts run without modification after infrastructure changes
  4. Previously saved JSON and .m dashboards load without errors or data loss
**Plans**: 3 plans
Plans:
- [x] 01-01-PLAN.md — Add ErrorFcn to DashboardEngine.LiveTimer (INFRA-01)
- [x] 01-02-PLAN.md — Extract normalizeToCell shared helper and refactor call sites (INFRA-03)
- [x] 01-03-PLAN.md — Fix GroupWidget .m export children + full suite backward compatibility gate (INFRA-02, COMPAT-01..04)

### Phase 2: Collapsible Sections
**Goal**: Users can collapse GroupWidget sections to reclaim screen space, with the grid reflowing immediately and the expanded/collapsed state surviving save/load
**Depends on**: Phase 1
**Requirements**: LAYOUT-01, LAYOUT-02, LAYOUT-07, LAYOUT-08
**Success Criteria** (what must be TRUE):
  1. Collapsing a GroupWidget causes widgets below it to shift upward, filling the reclaimed space
  2. Expanding a collapsed GroupWidget pushes widgets below it downward to make room
  3. A tabbed GroupWidget's active tab is preserved after a JSON save/load round-trip
  4. Tab labels are legible in both light and dark themes without visual ambiguity
**Plans**: 2 plans
Plans:
- [x] 02-01-PLAN.md — Wire ReflowCallback into GroupWidget collapse/expand and inject via DashboardEngine (LAYOUT-01, LAYOUT-02)
- [x] 02-02-PLAN.md — Test ActiveTab JSON round-trip and verify/fix tab contrast in all themes (LAYOUT-07, LAYOUT-08)

### Phase 3: Widget Info Tooltips
**Goal**: Users can view a widget's written description without leaving the dashboard, via an info icon in the widget header that opens a Markdown-rendered popup
**Depends on**: Phase 2
**Requirements**: INFO-01, INFO-02, INFO-03, INFO-04, INFO-05
**Success Criteria** (what must be TRUE):
  1. Any widget with a non-empty Description shows an info icon in its header; widgets without a Description do not
  2. Clicking the info icon opens a popup displaying the description text rendered as Markdown
  3. The popup can be dismissed by clicking outside it or pressing Escape
  4. All 20+ existing widget types show the info icon and popup without any per-widget code changes
**Plans**: 2 plans
Plans:
- [x] 03-01-PLAN.md — Test scaffold (TestInfoTooltip) + DashboardLayout info icon injection and popup methods (INFO-01, INFO-02, INFO-03, INFO-04, INFO-05)
- [x] 03-02-PLAN.md — Wire hFigure into DashboardLayout from DashboardEngine, add reflow popup guard, integration tests (INFO-01, INFO-02, INFO-03, INFO-04, INFO-05)

### Phase 4: Multi-Page Navigation
**Goal**: Users can organize a dashboard into multiple named pages, navigate between them via a page bar, and have the active page survive a save/load cycle
**Depends on**: Phase 1
**Requirements**: LAYOUT-03, LAYOUT-04, LAYOUT-05, LAYOUT-06
**Success Criteria** (what must be TRUE):
  1. A dashboard defined with multiple pages shows a navigation bar (toolbar buttons or tab strip) that switches the visible page
  2. Only the active page's widgets are rendered; widgets on other pages are hidden and do not consume render time
  3. After saving and reloading a multi-page dashboard, the same page is active as when it was saved
  4. Existing single-page dashboards open without a visible page bar and behave identically to before
**Plans**: 3 plans
Plans:
- [x] 04-01-PLAN.md — DashboardPage class + TestDashboardMultiPage scaffold (LAYOUT-03, LAYOUT-04, LAYOUT-05, LAYOUT-06)
- [x] 04-02-PLAN.md — DashboardEngine: Pages model, PageBar UI, switchPage, scoped onLiveTick (LAYOUT-03, LAYOUT-04, LAYOUT-06)
- [x] 04-03-PLAN.md — DashboardSerializer: multi-page JSON save/load + backward compat (LAYOUT-05, LAYOUT-03)

### Phase 5: Detachable Widgets
**Goal**: Users can pop any widget out as a standalone figure window that stays live-synced with the dashboard's data updates, without degrading dashboard refresh rate
**Depends on**: Phase 1, Phase 4
**Requirements**: DETACH-01, DETACH-02, DETACH-03, DETACH-04, DETACH-05, DETACH-06, DETACH-07
**Success Criteria** (what must be TRUE):
  1. Every widget shows a detach button in its header; clicking it opens the widget in a new MATLAB figure window
  2. The detached figure continues to update with new data on each dashboard timer tick
  3. Closing a detached figure window removes it from the engine's mirror registry; subsequent timer ticks produce no errors
  4. A detached FastSenseWidget has independent time axis zoom/pan (UseGlobalTime = false) without affecting the in-dashboard copy
  5. Detaching multiple widgets simultaneously does not measurably increase per-tick execution time in the dashboard
**Plans**: 3 plans
Plans:
- [x] 05-01-PLAN.md — DetachedMirror class + TestDashboardDetach test scaffold (DETACH-01..07)
- [x] 05-02-PLAN.md — DashboardLayout: DetachCallback property + addDetachButton() injection (DETACH-01)
- [x] 05-03-PLAN.md — DashboardEngine: DetachedMirrors registry, detachWidget(), removeDetached(), onLiveTick() mirror tail (DETACH-02..07)

### Phase 6: Serialization & Persistence
**Goal**: All new structures (multi-page layouts, collapsed state) survive both JSON and .m save/load round-trips, and detached widget state is correctly excluded from persistence
**Depends on**: Phase 4, Phase 5
**Requirements**: SERIAL-01, SERIAL-02, SERIAL-03, SERIAL-04, SERIAL-05
**Success Criteria** (what must be TRUE):
  1. A multi-page dashboard saved as JSON and reloaded has the same pages, widgets, and active page as before saving
  2. A multi-page dashboard exported to .m and re-imported reconstructs all pages and widgets identically
  3. The collapsed/expanded state of every section is preserved after a save/load round-trip
  4. Saving and reloading a dashboard does not include detached window state (windows do not auto-reopen on load)
  5. A dashboard JSON created before this milestone loads without errors on the updated engine
**Plans**: 2 plans
Plans:
- [x] 06-01-PLAN.md — Multi-page JSON round-trip + detached exclusion + legacy backward compat tests (SERIAL-01, SERIAL-04, SERIAL-05)
- [x] 06-02-PLAN.md — Multi-page .m export/import round-trip + collapsed state persistence tests (SERIAL-02, SERIAL-03)

### Phase 7: Tech Debt Cleanup
**Goal**: Fix multi-page time panel methods to scope to active page widgets, and correct test comment mislabeling from Phase 4
**Depends on**: Phase 4
**Requirements**: (none — tech debt closure, no new requirements)
**Gap Closure:** Closes tech debt from v1.0 milestone audit
**Success Criteria** (what must be TRUE):
  1. updateGlobalTimeRange(), updateLiveTimeRange(), broadcastTimeRange(), resetGlobalTime() iterate activePageWidgets() instead of obj.Widgets
  2. Time panel functions correctly in multi-page dashboards
  3. testSwitchPage comment references LAYOUT-06, testSaveLoadRoundTrip references LAYOUT-05
**Plans**: 1 plan
Plans:
- [x] 07-01-PLAN.md — Fix 4 time panel methods + correct test comment labels

### Phase 8: Widget improvements: DividerWidget, CollapsibleWidget, Y-axis limits
**Goal**: Add DividerWidget for visual section separation, addCollapsible convenience API on DashboardEngine, and configurable Y-axis limits on FastSenseWidget
**Depends on:** Phase 7
**Requirements**: DIVIDER-01, DIVIDER-02, DIVIDER-03, COLLAPSIBLE-01, YLIMITS-01, YLIMITS-02, YLIMITS-03
**Success Criteria** (what must be TRUE):
  1. DividerWidget renders a horizontal line with theme-colored appearance and is fully integrated into all type-dispatch switches
  2. d.addCollapsible('label', {children}) creates a collapsible GroupWidget with children attached
  3. FastSenseWidget with YLimits=[min max] clamps Y-axis range that persists across refresh cycles and save/load round-trips
  4. All existing tests continue to pass
**Plans**: 3 plans
Plans:
- [x] 08-01-PLAN.md — DividerWidget class + all 6 type-dispatch switch integrations (DIVIDER-01, DIVIDER-02, DIVIDER-03)
- [x] 08-02-PLAN.md — addCollapsible convenience method on DashboardEngine (COLLAPSIBLE-01)
- [x] 08-03-PLAN.md — YLimits property on FastSenseWidget with render/refresh/serialization (YLIMITS-01, YLIMITS-02, YLIMITS-03)

### Phase 9: Threshold Mini-Labels in FastSense Plots
**Goal:** Add optional small inline labels within FastSense plot axes that display the name of each threshold line, so users can identify thresholds at a glance without relying on legends or tooltips
**Depends on:** Phase 8
**Requirements:** LABEL-01, LABEL-02, LABEL-03, LABEL-04, LABEL-05, LABEL-06
**Success Criteria** (what must be TRUE):
  1. FastSense with ShowThresholdLabels=false (default) creates no text labels on threshold lines
  2. FastSense with ShowThresholdLabels=true creates 8pt right-aligned labels on each threshold line
  3. Labels reposition to the current right edge of visible axes on zoom, pan, and live data update
  4. FastSenseWidget.ShowThresholdLabels propagates to the underlying FastSense instance
  5. ShowThresholdLabels survives toStruct/fromStruct JSON round-trip (omitted when false)
  6. All existing tests continue to pass
**Plans:** 2/2 plans complete

Plans:
- [x] 09-01-PLAN.md — ShowThresholdLabels property + hText struct field + label creation in render() + updateThresholdLabels() method + call sites (LABEL-01, LABEL-02, LABEL-03)
- [x] 09-02-PLAN.md — FastSenseWidget ShowThresholdLabels wiring + toStruct/fromStruct + TestThresholdLabels test suite (LABEL-04, LABEL-05, LABEL-06)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Infrastructure Hardening | 4/4 | Complete   | 2026-04-01 |
| 2. Collapsible Sections | 2/2 | Complete   | 2026-04-01 |
| 3. Widget Info Tooltips | 3/3 | Complete   | 2026-04-01 |
| 4. Multi-Page Navigation | 3/3 | Complete   | 2026-04-01 |
| 5. Detachable Widgets | 3/3 | Complete   | 2026-04-02 |
| 6. Serialization & Persistence | 2/2 | Complete   | 2026-04-02 |
| 7. Tech Debt Cleanup | 1/1 | Complete   | 2026-04-03 |
| 8. Widget Improvements | 3/3 | Complete   | 2026-04-03 |
| 9. Threshold Mini-Labels | 2/2 | Complete   | 2026-04-03 |
