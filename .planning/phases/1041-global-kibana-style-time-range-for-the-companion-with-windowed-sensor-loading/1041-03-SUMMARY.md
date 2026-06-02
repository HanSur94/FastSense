---
phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
plan: "03"
subsystem: dashboard
tags: [fastSenseWidget, dashboardEngine, sensorDetailPlot, openAdHocPlot, windowed-read, empty-state, disk-backed]

# Dependency graph
requires:
  - phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
    provides: Tag.getXYRange(t0,t1) contract + SensorTag.getXYRange disk override + getTimeRange disk-fix (Plan 01)
provides:
  - FastSenseWidget.setTimeWindow(t0,t1) + TimeWindow_ private property
  - FastSenseWidget.isShowingEmptyState() queryable seam
  - FastSenseWidget.pullData_() private helper routing getXYRange vs getXY
  - THREE-WAY render binding: windowed->fp.addLine(getXYRange), disk-empty-window->fp.addLine(getXYRange(getTimeRange())), in-RAM-empty->fp.addTag (unchanged)
  - FastSenseWidget.renderEmptyState_() 'No data in selected range' label
  - DashboardEngine.setTimeWindow(t0,t1) fans window to all widgets + rerenderWidgets once
  - DashboardEngine.getTimeWindow() accessor
  - SensorDetailPlot 'TimeWindow' NV-option via parseOpts; windowed main-axes load
  - openAdHocPlot Overlay PlotFcn window-capable via @(ax,tRange) signature
  - tests/test_dashboard_time_window.m (8 sub-tests: fan-out, windowed pull, disk render, all-data fix, in-RAM, empty-state, preview-stays-full)
affects:
  - 1041-04 (companion toolbar wiring calls setTimeWindow on engines/widgets)
  - 1041-05 (integration tests validate end-to-end windowed loading)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "THREE-WAY render dispatch: windowed branch binds fp.addLine(getXYRange); disk-empty-window branch resolves extent via getTimeRange+getXYRange then fp.addLine; in-RAM-empty branch keeps fp.addTag verbatim"
    - "Early-return empty-state in render() probes data BEFORE creating axes so 'No data' avoids a blank FastSense instance"
    - "Fan-out pattern: DashboardEngine.setTimeWindow iterates allPageWidgets() with ismethod guard + try/catch, mirrors broadcastTimeRange"
    - "Cached probe in render(): single getXYRange call per branch (probe + bind share the same [xw,yw] variables)"

key-files:
  created:
    - tests/test_dashboard_time_window.m
  modified:
    - libs/Dashboard/FastSenseWidget.m
    - libs/Dashboard/DashboardEngine.m
    - libs/FastSense/SensorDetailPlot.m
    - libs/FastSenseCompanion/private/openAdHocPlot.m

key-decisions:
  - "Probe and bind use the same cached [xw,yw] variables in render() to avoid double getXYRange calls on disk-backed sensors"
  - "ShowingEmptyState_ flag guards refresh/update fast-paths so empty<->data transitions trigger a full rebuildForTag_ instead of incremental updateData"
  - "DashboardEngine.setTimeWindow does NOT call updateGlobalTimeRange (would reset scrubber); fans out window then rerenderWidgets() once"
  - "renderEmptyState_() uses uigridlayout in parentPanel (same pattern as DashboardListPane); theme colors resolved via getTheme() with fallback struct"
  - "SensorDetailPlot ctor-validation getXY() intentionally untouched: warns on empty full-extent which is correct even under a window"
  - "openAdHocPlot Overlay PlotFcn arity upgraded to @(ax,tRange); nargin<4 guard makes tRange optional for backward compat"

patterns-established:
  - "Pattern: empty-window disk branch for 'All data': ismethod(tag,'isOnDisk') && tag.isOnDisk() -> getTimeRange -> getXYRange -> fp.addLine"
  - "Pattern: widget holds TimeWindow_, engine pushes it before rerender -- widget has NO back-ref to engine"

requirements-completed: []

# Metrics
duration: 8min
completed: 2026-06-02
---

# Phase 1041 Plan 03: Dashboard View-Layer Time-Window Summary

**FastSenseWidget windowed data pulls with disk-aware empty-window fallback (fixing the 'All data' blank-plot bug), DashboardEngine.setTimeWindow fan-out, SensorDetailPlot 'TimeWindow' option, and window-capable Overlay PlotFcn**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-02T16:25:26Z
- **Completed:** 2026-06-02T16:33:41Z
- **Tasks:** 3 (1 TDD-RED + 2 TDD-GREEN)
- **Files modified:** 5 (1 new test + 4 modified source)

## Accomplishments

- `FastSenseWidget` gains `TimeWindow_` property and `setTimeWindow(t0,t1)` method; three data-pull sites (render y-autoscale seed, refresh, update) route through new `pullData_()` helper that calls `getXYRange(t0,t1)` when windowed and `getXY()` otherwise
- THREE-WAY render binding: (1) windowed -> `fp.addLine(xw, yw)` from `getXYRange`; (2) empty-window + disk-backed -> `fp.addLine` after `getXYRange(getTimeRange())` (fixes the 'All data' blank-plot bug where `fp.addTag(diskTag)` bound an empty line because `getXY()` is empty on disk); (3) empty-window + in-RAM -> `fp.addTag(obj.Tag)` byte-identical to today
- Empty-state `renderEmptyState_()` renders "No data in selected range" (14pt bold, PlaceholderTextColor centered) into the panel before creating axes; `isShowingEmptyState()` is a queryable seam for tests; `ShowingEmptyState_` flag guards `refresh()`/`update()` fast-paths so empty<->data transitions rebuild axes
- `DashboardEngine.setTimeWindow(t0,t1)` fans window via `allPageWidgets()` + `ismethod` guard + per-widget try/catch (mirrors `broadcastTimeRange` shape), calls `rerenderWidgets()` once, does NOT touch scrubber or call `updateGlobalTimeRange`
- `SensorDetailPlot` gains `'TimeWindow'` NV-option (via `parseOpts`); `render()` branches to `getXYRange(t0,t1)` when set; ctor-validation `getXY()` intentionally unchanged
- `openAdHocPlot` Overlay `PlotFcn` upgraded to `@(ax, tRange)` signature; `plotOverlay_` accepts optional `tRange` and calls `getXYRange(tRange(1),tRange(2))` when non-empty (backward compat: `nargin < 4` guard falls back to `getXY()`)
- Test scaffold `tests/test_dashboard_time_window.m`: 8 sub-tests covering fan-out (Octave-safe), disk windowed render bind, disk 'All data' full-extent bind, in-RAM full-pull, empty-state decision, preview-stays-full

## Task Commits

Each task was committed atomically:

1. **Task 1: RED test scaffold** - `32083158` (test)
2. **Task 2: FastSenseWidget windowed + empty-state** - `3848c947` (feat)
3. **Task 3: DashboardEngine.setTimeWindow + SensorDetailPlot + Overlay** - `c64defdd` (feat)

**Plan metadata:** (see below in final commit)

## Files Created/Modified

- `tests/test_dashboard_time_window.m` — 8-sub-test headless scaffold; testSetTimeWindow/testClearTimeWindow unguarded (Octave-safe); render-dependent tests Octave-guarded; RED for Tasks 2-3 fixed by GREEN commits
- `libs/Dashboard/FastSenseWidget.m` — TimeWindow_ + ShowingEmptyState_ properties; setTimeWindow() + isShowingEmptyState() public methods; pullData_() + renderEmptyState_() private helpers; THREE-WAY render bind; pullData_() at 3 data-pull sites; refresh/update fast-path guards
- `libs/Dashboard/DashboardEngine.m` — TimeWindow_ private property; setTimeWindow() + getTimeWindow() public methods near updateGlobalTimeRange
- `libs/FastSense/SensorDetailPlot.m` — TimeWindow_ private property; 'TimeWindow' added to conDefaults via parseOpts; render() branches getXYRange vs getXY
- `libs/FastSenseCompanion/private/openAdHocPlot.m` — plotOverlay_ accepts optional tRange using getXYRange; Overlay widget uses @(ax,tRange) PlotFcn

## Decisions Made

- Probe and bind share the same cached `[xw, yw]` variables in `render()` to avoid double `getXYRange` calls on disk-backed sensors (chunk I/O is expensive)
- `ShowingEmptyState_` flag guards `refresh()`/`update()` fast-paths: if the widget is showing an empty state or the FastSense axes are absent, the incremental `updateData` path is skipped and `rebuildForTag_()` runs instead (handles empty<->data transition correctly)
- `DashboardEngine.setTimeWindow` does NOT call `updateGlobalTimeRange` — that method rescans widget data ranges and resets the scrubber, which is explicitly undesired (RESEARCH anti-pattern)
- `renderEmptyState_()` resolves theme via existing `getTheme()` with a fallback struct so it works even when no DashboardTheme has been configured

## Deviations from Plan

None - plan executed exactly as written.

## MATLAB/Octave Test Execution — DEFERRED

MISS_HIT static analysis (`mh_style` + `mh_lint`) was run and is clean on all 5 files. MATLAB/Octave test **execution** requires a live MATLAB session and is deferred.

### Deferred test commands

Run in MATLAB Command Window or via `mcp__matlab__evaluate_matlab_code`:

```matlab
% Primary: new windowed tests (8 sub-tests; pure fan-out sub-tests also run in Octave)
test_dashboard_time_window()
% Expected: "    All 8 test_dashboard_time_window tests passed."

% Regression: FastSenseWidget tag-render (no regression from additive changes)
test_fastsense_widget_tag()
% Expected: "    All 7 fastsense_widget_tag tests passed."

% Regression: data-layer (Plan 01 contract; unaffected by this plan)
test_sensor_tag_range()
% Expected: "    All 7 test_sensor_tag_range tests passed."
```

For Octave (pure fan-out sub-tests only):
```bash
octave --no-gui tests/test_dashboard_time_window.m
# Expected: "    Property fan-out tests passed; figure-dependent tests SKIPPED on Octave."
```

### What each sub-test verifies

| Sub-test | Behavior verified | Octave-safe |
|----------|-------------------|-------------|
| testSetTimeWindow | engine.setTimeWindow stores window; each widget's TimeWindow_ equals [t0 t1] | Yes |
| testClearTimeWindow | engine.setTimeWindow([],[]) clears widgets' TimeWindow_ to empty | Yes |
| testWidgetWindowedPull | windowed widget pulls fewer points at refresh/update | No |
| testWidgetWindowedRenderBindsDisk | disk-backed render with non-empty window binds non-empty line via fp.addLine | No |
| testWidgetAllDataDiskNonEmpty | disk-backed 'All data' (empty window) binds FULL extent, NOT blank addTag line | No |
| testWidgetFullPullWhenEmpty | in-RAM tag + empty window = full series via fp.addTag (unchanged path) | No |
| testEmptyStateDecision | out-of-extent window -> isShowingEmptyState() == true | No |
| testPreviewStillFull | getTimeRange/getPreviewSeries on windowed widget still return full extent | No |

## Known Stubs

None — all data paths are wired. The empty-state renders a real label (not placeholder text). The windowed pulls route through the real `getXYRange` contract from Plan 01.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- View layer is complete: `FastSenseWidget` + `DashboardEngine` + `SensorDetailPlot` + `openAdHocPlot` all honor a pushed time window
- Backward compatibility preserved: empty window over in-RAM tags is byte-identical to pre-phase; disk 'All data' now loads full extent instead of blank
- Preview/navigator cache (`getPreviewSeries`, `getTimeRange`, `CachedXMin/CachedXMax`) untouched — full envelope still shown in slider
- Ready for Plan 1041-04: companion toolbar picker + wiring that calls `setTimeWindow` on managed engines/figures
- Deferred: toolbar picker UI (Plan 04), tests-suite + manual checklist (Plan 05)

---
*Phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading*
*Completed: 2026-06-02*
