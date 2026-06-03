---
phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
plan: "04"
subsystem: companion
tags: [matlab, companion, time-range, uifigure, picker, datenum, prefs, open-sites]

# Dependency graph
requires:
  - phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
    provides: CompanionTimeRange RangeChanged/resolve/setRelative/setAbsolute/setAll/label (Plan 02)
  - phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
    provides: DashboardEngine.setTimeWindow fan-out + FastSenseWidget windowed pull (Plan 03)
provides:
  - CompanionTimeBar handle class: themed toolbar button (Tag 'CompanionTimeRangeBtn') + 400x280 singleton picker popup
  - Picker: Quick presets (6 one-click), Relative (uispinner + uidropdown + live preview), Absolute (uidatepicker + validation + preview)
  - FastSenseCompanion.onRangeChanged_: pushes [t0,t1] to all Engines_ + OpenedFigures_ (via appdata stash)
  - FastSenseCompanion.currentTimeWindow(): public helper for open-site callers
  - openAdHocPlot engine stash: setappdata(hFig,'DashboardEngine',engine) after render
  - companionPrefs timeRange field: persists CompanionTimeRange spec across sessions
  - Open-site wiring: onOpenDashboardRequested_, onOpenAdHocPlotRequested_, InspectorPane.onOpenDetail_ all start windowed
affects:
  - 1041-05: integration/UI test suite validates CompanionTimeBar + end-to-end window propagation

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Singleton popup pattern: isvalid(hPopup_) guard; figure(hPopup_) to bring to front (mirrors CompanionSettingsDialog)"
    - "appdata stash for engine recovery: setappdata(hFig,'DashboardEngine',engine) in openAdHocPlot; getappdata in RangeChanged loop"
    - "Open-site window application: after every companion-initiated open, recover engine via appdata + setTimeWindow(t0,t1)"
    - "Pref round-trip: prefs.timeRange = TimeRange_.toStruct(); fromStruct on load"

key-files:
  created:
    - libs/FastSenseCompanion/CompanionTimeBar.m
  modified:
    - libs/FastSenseCompanion/FastSenseCompanion.m
    - libs/FastSenseCompanion/private/openAdHocPlot.m
    - libs/FastSenseCompanion/companionPrefs.m
    - libs/FastSenseCompanion/InspectorPane.m

key-decisions:
  - "currentTimeWindow() placed as public method so InspectorPane.onOpenDetail_ can call it without coupling to TimeRange_ directly"
  - "onRangeChanged_ calls syncOpenedFigures_() before iterating OpenedFigures_ to prune dead handles and pull in Engines_ figures; managed dashboard may be set twice (Engines_ + OpenedFigures_) -- idempotent, harmless for v1"
  - "TimeBar_ teardown runs AFTER Listeners_ teardown in close() so the RangeChanged listener (already deleted) cannot fire during the bar's own delete()"
  - "Toolbar ColumnWidth unchanged: col 9 stays '1x'; CompanionTimeBar fills the flex slot without ColumnWidth edit"
  - "InspectorPane open-site: uses getappdata(hFig,'DashboardEngine') + Orchestrator_.currentTimeWindow() -- no direct TimeRange_ coupling to InspectorPane"

patterns-established:
  - "Pattern: ad-hoc engine recovered via appdata stash (not via toolbar state) -- works regardless of PerTag/Overlay/LinkedGrid mode"
  - "Pattern: every open site applies window post-open via try/catch guard so window application never blocks figure creation"

requirements-completed: []

# Metrics
duration: 8min
completed: 2026-06-02
---

# Phase 1041 Plan 04: CompanionTimeBar + Companion Time-Range Wiring Summary

**Three-mode toolbar picker (Quick/Relative/Absolute) wired into FastSenseCompanion: range button shows current range, picker commits to CompanionTimeRange, RangeChanged pushes resolved window to all managed and ad-hoc engines, and every newly opened view starts windowed**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-02T16:37:59Z
- **Completed:** 2026-06-02T16:46:06Z
- **Tasks:** 4 (Task 1a + 1b + Task 2 + Task 3)
- **Files modified:** 5 (1 new + 4 modified)

## Accomplishments

- `CompanionTimeBar` creates the `'CompanionTimeRangeBtn'` toolbar button in col 9, and a singleton 400x280 uifigure popup with three modes: Quick presets (6 one-click), Relative builder (uispinner + uidropdown + live preview), Absolute (uidatepicker + validation + preview). MISS_HIT clean.
- `FastSenseCompanion` instantiates `CompanionTimeRange` from prefs (or default Last 7 days), creates `CompanionTimeBar`, wires `RangeChanged` listener, adds `onRangeChanged_` that pushes `setTimeWindow(t0,t1)` to `Engines_` and `OpenedFigures_` (via `getappdata(hFig,'DashboardEngine')` stash), exposes `currentTimeWindow()` public helper.
- `openAdHocPlot` now stashes the engine on the figure via `setappdata(hFig,'DashboardEngine',engine)` so `onRangeChanged_` can re-query it.
- Open-site wiring: `onOpenDashboardRequested_`, `onOpenAdHocPlotRequested_` (PerTag + regular), and `InspectorPane.onOpenDetail_` all apply the current window to the freshly opened engine.
- `companionPrefs` header documents the `timeRange` field (struct round-trips without allow-list change); written by `onRangeChanged_`, read at ctor.

## Task Commits

Each task was committed atomically:

1. **Task 1a: CompanionTimeBar range button + popup skeleton + Quick presets** - `af975bac` (feat)
2. **Task 1b: CompanionTimeBar Relative + Absolute panels + Apply/Cancel** - `2b423b6c` (feat)
3. **Task 2: openAdHocPlot stash + companionPrefs timeRange** - `67459620` (feat)
4. **Task 3: FastSenseCompanion integration** - `8d6f4342` (feat)

## Files Created/Modified

- `libs/FastSenseCompanion/CompanionTimeBar.m` — New handle class: toolbar range button + singleton 3-mode picker popup
- `libs/FastSenseCompanion/FastSenseCompanion.m` — TimeRange_/TimeBar_ properties; ctor prefs load; bar instantiation; RangeChanged listener; onRangeChanged_; currentTimeWindow; open-site wiring; theme switch; cleanup
- `libs/FastSenseCompanion/private/openAdHocPlot.m` — Engine stash via setappdata after render
- `libs/FastSenseCompanion/companionPrefs.m` — Header comment documents timeRange field
- `libs/FastSenseCompanion/InspectorPane.m` — onOpenDetail_ applies window via currentTimeWindow()

## Decisions Made

- `currentTimeWindow()` is public so InspectorPane can call it without coupling to `TimeRange_` directly.
- `onRangeChanged_` calls `syncOpenedFigures_()` before iterating `OpenedFigures_` — managed dashboard figures appear in both `Engines_` and `OpenedFigures_`; `setTimeWindow` is idempotent so double-calling is harmless.
- `TimeBar_` teardown runs after `Listeners_` teardown so the RangeChanged listener cannot fire during bar cleanup.
- Toolbar `ColumnWidth` `{110, 110, 110, 130, 70, 90, 70, 70, '1x', 36}` unchanged — `CompanionTimeBar` fills the col-9 flex slot without modifying the width array.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## MATLAB/Octave Test Execution — DEFERRED

MATLAB test execution cannot be run from this environment (no MCP tools available). The implementation must be smoke-checked and the Plan 05 test suite run in the live MATLAB session.

### Deferred test commands

Run in MATLAB Command Window (or via `mcp__matlab__evaluate_matlab_code`):

```matlab
% Ensure paths are set:
install();

% Regression: CompanionTimeRange unchanged — confirm still green
test_companion_time_range()
% Expected: "All 10 test_companion_time_range tests passed."

% Regression: ad-hoc plot test -- stash is additive, should still pass
test_companion_open_ad_hoc_plot()
% Expected: test passes (stash does not break existing behavior)

% Regression: full dashboard time-window tests
test_dashboard_time_window()
% Expected: "All 8 test_dashboard_time_window tests passed."

% Smoke check -- companion constructs, range button label reads "Last 7 days":
% (requires running MATLAB desktop session)
% install();
% r = TagRegistry;
% c = FastSenseCompanion('Registry', r, 'Visible', 'off');
% btn = findobj(c.hFig_, 'Tag', 'CompanionTimeRangeBtn');
% disp(btn.Text)   % Expected: 'Last 7 days'
% c.close();
```

For the full Plan 05 test suite (covers TestCompanionTimeBar + companion integration assertions):
```matlab
run_all_tests()  % look for TestCompanionTimeBar and TestFastSenseCompanion in output
```

### Visual verification (deferred to live session)

1. Open the companion: `c = FastSenseCompanion('Registry', TagRegistry);`
2. Toolbar shows "Last 7 days" button in the col-9 flex slot.
3. Click the button — picker popup opens at 400x280, Quick tab active, "Last 7 days" preset highlighted.
4. Click "Last 30 days" — popup closes, button label updates to "Last 30 days", button turns Accent color.
5. Reopen picker, switch to Relative tab — spinner shows 7, dropdown shows "days", preview shows date range.
6. Change spinner to 14, dropdown to "weeks" — preview updates live. Click Apply — popup closes, button shows "Last 14 weeks".
7. Switch to Absolute tab — two date pickers shown. Set start=today, end=yesterday — Apply is disabled, "Invalid: start must be before end" in red. Fix end to tomorrow — Apply enabled, preview shows "1 days". Click Apply.
8. Open an ad-hoc plot from the Inspector while a non-default range is set — plot should start within the selected window.

## Known Stubs

None — all paths wired. The Quick preset buttons commit and close. The Relative and Absolute panels are fully populated (no TODO markers remain).

## Next Phase Readiness

- `CompanionTimeBar` public contract is complete and ready for Plan 05 `TestCompanionTimeBar` assertions.
- All four companion integration points (managed dashboards, ad-hoc plots, PerTag plots, sensor detail) apply the window at open time and re-apply on `RangeChanged`.
- Default Last 7 days persists across sessions via `companionPrefs`.
- Plan 05 test suite + manual checklist is the remaining step to validate the complete feature end-to-end.

## Self-Check

Files created/modified exist:

```
[ -f "libs/FastSenseCompanion/CompanionTimeBar.m" ] → FOUND
[ -f "libs/FastSenseCompanion/FastSenseCompanion.m" ] → FOUND (modified)
[ -f "libs/FastSenseCompanion/private/openAdHocPlot.m" ] → FOUND (modified)
[ -f "libs/FastSenseCompanion/companionPrefs.m" ] → FOUND (modified)
[ -f "libs/FastSenseCompanion/InspectorPane.m" ] → FOUND (modified)
```

Commits exist:

```
git log --oneline | grep 1041-04 → 4 commits found (af975bac, 2b423b6c, 67459620, 8d6f4342)
```

## Self-Check: PASSED

---

*Phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading*
*Completed: 2026-06-02*
