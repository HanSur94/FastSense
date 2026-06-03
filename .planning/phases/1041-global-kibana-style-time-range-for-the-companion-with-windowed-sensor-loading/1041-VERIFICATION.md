---
phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
verified: 2026-06-02T17:00:00Z
status: human_needed
score: 10/10 automated must-haves verified; 1 deferred visual checklist (9 items)
human_verification:
  - test: "Step 1 — Default range button label and color"
    expected: "Toolbar button reads 'Last 7 days' with WidgetBorderColor background (no Accent)"
    why_human: "uifigure rendering not headlessly assertable"
  - test: "Step 2 — Picker opens with 3 tabs and Quick tab active"
    expected: "400x280 popup, Quick/Relative/Absolute tabs, 6 preset buttons, highlighted 'Last 7 days', Cancel visible, no Apply"
    why_human: "uifigure visual rendering + pixel geometry not headlessly assertable"
  - test: "Step 3 — One-click quick preset applies and closes popup"
    expected: "Clicking 'Last 30 days' closes popup immediately, updates label, turns Accent, re-queries open views"
    why_human: "Popup close interaction and button color change require live session"
  - test: "Step 4 — Relative builder tab: live preview + Apply"
    expected: "N spinner + unit dropdown present; changing values updates preview label live; Apply closes and updates"
    why_human: "uispinner/uidropdown interaction and live preview update not headlessly assertable"
  - test: "Step 5A — Absolute tab: start > end validation"
    expected: "Apply disabled and red 'Invalid: start must be before end' text shown"
    why_human: "uidatepicker interaction and validation state color not headlessly assertable"
  - test: "Step 5B — Absolute tab: valid range applies"
    expected: "Apply enables, preview shows days span, clicking Apply closes popup and shows date-string label"
    why_human: "uidatepicker interaction not headlessly assertable"
  - test: "Step 6 — Empty-state widget for out-of-window sensor"
    expected: "Ad-hoc plot for a 2020 tag under 'Last 30 days' range shows centered 'No data in selected range', no crash"
    why_human: "Visual rendering of the empty-state label in a spawned figure requires live session"
  - test: "Step 7 — Relative window slides on live tick"
    expected: "With 'Last 7 days' active and live mode on, new tail samples appear each tick; absolute window stays fixed"
    why_human: "Timing behavior across multiple live ticks requires a live session with a tail-producing sensor"
  - test: "Step 8 — Theme restyle of range button"
    expected: "Switching theme in Settings dialog restyles range button FontColor + BackgroundColor to new theme"
    why_human: "Theme switch visual comparison requires live session"
  - test: "Step 9 — Persistence across companion reopen"
    expected: "After setting 'Last 30 days', closing and reopening the companion, button reads 'Last 30 days' (Accent)"
    why_human: "prefs round-trip behavior observable only in live MATLAB session"
---

# Phase 1041: Global Kibana-style Time Range Verification Report

**Phase Goal:** Give companion users a global Kibana-style time-range picker (relative/absolute + quick presets, default Last 7 days) so opening any sensor/plot loads only that window instead of the full up-to-10-year history. Disk-backed sensors read only overlapping chunks via `DataStore.getRange`; in-RAM sensors slice in place. Implemented via an additive `getXYRange(t0,t1)` Tag method (existing `getXY()` untouched), a `CompanionTimeRange` source-of-truth + toolbar `CompanionTimeBar`, with open views re-queried on range change.

**Verified:** 2026-06-02T17:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `getXYRange(t0,t1)` exists on Tag base with concrete default (binary-search slice of getXY()); getXY() untouched | VERIFIED | `Tag.m:125-158` — concrete default; `Tag.m:120-123` — getXY() still raises `Tag:notImplemented` |
| 2 | `SensorTag.getXYRange` overrides with disk path (`DataStore_.getRange`) and RAM path (binary-search slice) | VERIFIED | `SensorTag.m:123-162` — disk branch at :133, RAM branch at :152 |
| 3 | `SensorTag.getTimeRange` fixed for disk-backed sensors (returns non-NaN `[XMin, XMax]` via DataStore) | VERIFIED | `SensorTag.m:175-189` — `isOnDisk()` branch calls `DataStore_.getTimeExtent()` at :180 |
| 4 | `FastSenseDataStore.getTimeExtent()` O(1) accessor exists; `XMin`/`XMax` captured at construction | VERIFIED | `FastSenseDataStore.m:42-43` (XMin/XMax properties), `:75-76` (set at ctor), `:112-116` (getTimeExtent method) |
| 5 | `CompanionTimeRange` handle class: relative/absolute/all spec, resolve to datenum, label(), isDefault(), toStruct/fromStruct, RangeChanged event | VERIFIED | `CompanionTimeRange.m:31-33` (events block), `:46` (resolve), `:69/87/104` (setters), `:46-67` (label/isDefault/toStruct/fromStruct) |
| 6 | `CompanionTimeBar` toolbar button (`Tag='CompanionTimeRangeBtn'`) in col-9 flex slot + singleton 400x280 popup with Quick/Relative/Absolute panels | VERIFIED | `CompanionTimeBar.m:39-40` (hBtn_/hPopup_ properties), `:84` (Tag set), `:317/369/430` (buildQuickPanel_/buildRelativePanel_/buildAbsolutePanel_), `:234/242` (Quick + Relative tabs) |
| 7 | `DashboardEngine.setTimeWindow(t0,t1)` fans window to all widgets via `allPageWidgets()` + `ismethod` guard + try/catch; skips rerender when unrendered | VERIFIED | `DashboardEngine.m:1808-1842` — fans to all widgets at :1820-1834, `ishandle(hFigure)` guard at :1841 |
| 8 | `FastSenseWidget` pulls windowed data via `pullData_()` at all 3 sites; `renderEmptyState_()` shows "No data in selected range"; `ShowingEmptyState_` flag guards refresh/update | VERIFIED | `FastSenseWidget.m:83-84` (properties), `:655-663` (setTimeWindow), `:1326-1334` (pullData_), `:1336-1361` (renderEmptyState_) |
| 9 | `SensorDetailPlot` accepts `'TimeWindow'` NV-option and loads windowed data via `getXYRange`; `openAdHocPlot` overlay `PlotFcn` upgraded to `@(ax,tRange)` | VERIFIED | `SensorDetailPlot.m:91` (conDefaults.TimeWindow), `:133-134` (getXYRange branch); `openAdHocPlot.m:100` (`@(ax,tRange)` signature), `:148/153-160` (plotOverlay_ with tRange) |
| 10 | `FastSenseCompanion.onRangeChanged_` pushes resolved `[t0,t1]` to all `Engines_` + ad-hoc `OpenedFigures_` (via appdata stash); open-site wiring (dashboard + ad-hoc + Inspector "Plot") starts windowed; prefs persistence | VERIFIED | `FastSenseCompanion.m:1856-1908` (onRangeChanged_), `:1875` (Engines_ setTimeWindow), `:1888` (OpenedFigures_ via getappdata), `:1932-1934` / `:2311-2312` / `:2363-2364` (open-site wiring), `:1864-1868` (prefs save), `:174-178` (prefs load at ctor); `InspectorPane.m:868-873` (currentTimeWindow at open-detail) |

**Score:** 10/10 automated truths verified

---

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `libs/SensorThreshold/Tag.m` — `getXYRange` concrete default | VERIFIED | Lines 125-158; extent-guard at :142-148; one-point padding at :151-152 |
| `libs/SensorThreshold/SensorTag.m` — `getXYRange` override + `getTimeRange` disk-fix | VERIFIED | Lines 123-189; disk branch at :133, RAM branch at :152, getTimeRange disk at :179-181 |
| `libs/FastSense/FastSenseDataStore.m` — `getTimeExtent()` accessor | VERIFIED | Lines 112-116; XMin/XMax set at construction lines 75-76 |
| `libs/FastSenseCompanion/CompanionTimeRange.m` | VERIFIED | New file; events block :31; resolve/setRelative/setAbsolute/setAll/label/isDefault/toStruct/fromStruct all present |
| `libs/FastSenseCompanion/CompanionTimeBar.m` | VERIFIED | New file; button Tag 'CompanionTimeRangeBtn' :84; popup buildQuickPanel_/buildRelativePanel_/buildAbsolutePanel_ :317/:369/:430; 6 presets :330-335 including 'All data'; uidatepicker :455/:469; uispinner :402 |
| `libs/Dashboard/FastSenseWidget.m` — `TimeWindow_`, `setTimeWindow`, `pullData_`, `renderEmptyState_`, `isShowingEmptyState` | VERIFIED | Lines 83-84 (properties), 655-663 (setTimeWindow), 1326-1334 (pullData_), 1336+ (renderEmptyState_) |
| `libs/Dashboard/DashboardEngine.m` — `TimeWindow_`, `setTimeWindow`, `getTimeWindow` | VERIFIED | Lines 71 (property), 1808-1842 (setTimeWindow), 1846 (getTimeWindow) |
| `libs/FastSense/SensorDetailPlot.m` — `'TimeWindow'` NV-option | VERIFIED | Lines 45 (TimeWindow_ property), 91 (conDefaults.TimeWindow), 113 (opts.TimeWindow assign), 133-134 (getXYRange branch) |
| `libs/FastSenseCompanion/private/openAdHocPlot.m` — `@(ax,tRange)` PlotFcn, `plotOverlay_` uses `getXYRange` | VERIFIED | Line 100 (`@(ax,tRange)` closure), 148 (plotOverlay_ signature), 153-160 (tRange routing) |
| `libs/FastSenseCompanion/FastSenseCompanion.m` — `TimeRange_`, `TimeBar_`, `onRangeChanged_`, `currentTimeWindow`, prefs round-trip, open-site wiring | VERIFIED | Lines 128-129 (properties), 174-178 (prefs load), 451 (TimeBar_ construction in col 9), 562-563 (RangeChanged listener), 1227-1232 (currentTimeWindow), 1856-1908 (onRangeChanged_) |
| `libs/FastSenseCompanion/InspectorPane.m` — `onOpenDetail_` applies window via `currentTimeWindow()` | VERIFIED | Lines 868-873 |
| `libs/FastSenseCompanion/companionPrefs.m` — `timeRange` field documented | VERIFIED | Line 22 (header comment documents field) |
| `tests/test_sensor_tag_range.m` | VERIFIED | File exists; 7 sub-tests; executed 7/7 green per orchestrator |
| `tests/test_companion_time_range.m` | VERIFIED | File exists; 10 sub-tests; executed 10/10 green per orchestrator |
| `tests/test_dashboard_time_window.m` | VERIFIED | File exists; 8 sub-tests; executed 8/8 green per orchestrator |
| `tests/suite/TestCompanionTimeBar.m` | VERIFIED | File exists; 8 sub-tests; executed 8/8 green per orchestrator |
| `tests/SpyTimeWindowEngine.m` | VERIFIED | File exists; subclasses DashboardEngine for isa() gate compliance |
| `.planning/phases/.../1041-MANUAL-VERIFY.md` | VERIFIED | File exists; 9-step visual checklist authored |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `CompanionTimeBar` (Quick preset click) | `CompanionTimeRange.setRelative` / `setAll` | `buildQuickPanel_` preset button callbacks | WIRED | `CompanionTimeBar.m:330-335` preset table, button callbacks call setRelative/setAll |
| `CompanionTimeRange.RangeChanged` | `FastSenseCompanion.onRangeChanged_` | `addlistener` | WIRED | `FastSenseCompanion.m:562-563` |
| `onRangeChanged_` | `DashboardEngine.setTimeWindow` on Engines_ | `for i = 1:numel(obj.Engines_)` | WIRED | `FastSenseCompanion.m:1871-1878` |
| `onRangeChanged_` | `DashboardEngine.setTimeWindow` on OpenedFigures_ | `getappdata(hFig,'DashboardEngine')` | WIRED | `FastSenseCompanion.m:1880-1892` |
| `openAdHocPlot` | appdata stash on figure | `setappdata(hFig,'DashboardEngine',engine)` | WIRED | `openAdHocPlot.m:142` |
| `DashboardEngine.setTimeWindow` | `FastSenseWidget.setTimeWindow` | `allPageWidgets()` + `ismethod` guard | WIRED | `DashboardEngine.m:1820-1834` |
| `FastSenseWidget.refresh/update` | `Tag.getXYRange` | `pullData_()` | WIRED | `FastSenseWidget.m:1329-1330` (getXYRange when TimeWindow_ non-empty) |
| `SensorTag.getXYRange` (disk) | `FastSenseDataStore.getRange` | `DataStore_.getRange(tStart, tEnd)` | WIRED | `SensorTag.m:133-135` |
| `SensorTag.getTimeRange` (disk) | `FastSenseDataStore.getTimeExtent` | `DataStore_.getTimeExtent()` | WIRED | `SensorTag.m:180` |
| Companion ctor | `companionPrefs('load')` → `CompanionTimeRange.fromStruct` | prefs.timeRange field | WIRED | `FastSenseCompanion.m:175-178` |
| `onRangeChanged_` | `companionPrefs('save', p)` | `p.timeRange = obj.TimeRange_.toStruct()` | WIRED | `FastSenseCompanion.m:1864-1868` |
| Open-site: `onOpenDashboardRequested_` | `ed.Engine.setTimeWindow(t0,t1)` | `currentTimeWindow()` resolve | WIRED | `FastSenseCompanion.m:1932-1934` |
| Open-site: `onOpenAdHocPlotRequested_` | `eng.setTimeWindow` | `currentTimeWindow()` resolve | WIRED | `FastSenseCompanion.m:2311-2312`, `:2363-2364` |
| Open-site: `InspectorPane.onOpenDetail_` | `eng.setTimeWindow` via `Orchestrator_.currentTimeWindow()` | `getappdata(hFig,'DashboardEngine')` | WIRED | `InspectorPane.m:868-873` |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `FastSenseWidget.pullData_()` | `[x, y]` | `Tag.getXYRange(TimeWindow_(1), TimeWindow_(2))` | Yes — routes to DataStore.getRange (disk) or binary-search slice (RAM) | FLOWING |
| `CompanionTimeRange.resolve()` | `[t0, t1]` | Spec-type dispatch: `now()` for relative, stored absolute dates for absolute, `[]/[]` for all | Yes — resolve is pure computation against live `now()` | FLOWING |
| `DashboardEngine.setTimeWindow` | `TimeWindow_` | Pushed by `FastSenseCompanion.onRangeChanged_` resolving `CompanionTimeRange` | Yes — wired chain from UI → CompanionTimeRange → DashboardEngine → FastSenseWidget | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Check | Result | Status |
|----------|-------|--------|--------|
| `Tag.getXYRange` with out-of-extent window returns empty | Code inspection: `Tag.m:142-148` — `tEnd < X(1) \|\| tStart > X(end)` guard returns `X=[];Y=[]` | Guard present and correct | PASS |
| `SensorTag.getXYRange` disk branch calls `DataStore_.getRange` | Code inspection: `SensorTag.m:133-135` | Single-line delegation present | PASS |
| `DashboardEngine.setTimeWindow` guards rerender on unrendered engine | Code inspection: `DashboardEngine.m:1841` — `ishandle(obj.hFigure)` guard | Guard present (bug fix `2a3480b9` applied) | PASS |
| `onRangeChanged_` iterates both Engines_ and OpenedFigures_ | Code inspection: `FastSenseCompanion.m:1871-1892` | Both loops present with try/catch wrappers | PASS |
| Test suites green (orchestrator-run) | Per 1041-05-SUMMARY: `test_sensor_tag_range` 7/7, `test_companion_time_range` 10/10, `test_dashboard_time_window` 8/8, `TestCompanionTimeBar` 8/8, `TestFastSenseCompanion` 83/85 (2 non-1041 pre-existing) | All 1041-specific tests green | PASS |
| MISS_HIT style/lint clean | Per Plan 01-05 summaries: clean on all touched files | All plans report clean | PASS |

Behavioral spot-checks: SKIPPED for live server/figure tests (requires interactive MATLAB session — correctly routed to 1041-MANUAL-VERIFY.md)

---

### Requirements Coverage

No formal REQ-IDs mapped to this phase (ad-hoc phase). All must-haves derived from GOAL + 1041-CONTEXT.md acceptance defaults. All 10 derived truths verified above.

---

### Anti-Patterns Found

| File | Pattern | Severity | Assessment |
|------|---------|----------|------------|
| `FastSenseWidget.m:1341-1342` | Fallback `theme` struct with hardcoded colors `[0.15 0.15 0.17]` / `[0.5 0.5 0.55]` in `renderEmptyState_()` | Info | Intentional defensive fallback when no DashboardTheme configured; `getTheme()` is called first and overwrites if available. Not a stub. |
| `companionPrefs.m:22` | `timeRange` field documented only in comment, not in allow-list logic | Info | `companionPrefs` uses struct pass-through (no allow-list filter per codebase pattern). The `fromStruct` tolerant deserialization handles missing fields. Non-blocking. |

No blockers found. The "No data in selected range" empty-state renders a real label (not placeholder text). All data paths are wired with real implementations.

---

### Known Non-Blocking Items (Per Test Evidence Brief)

- **`testPerTagModeSpawnsNFigures`** — PRE-EXISTING PerTag lifecycle test that leaks 2 FastSense deferred timers. The correct new empty-state behavior (PerTag fixture tags use integer X = 1:3, so the default datenum window is out-of-extent) shifted render timing and exposed this pre-existing leak. Routed to a separate `/gsd:debug` task. Not a 1041 regression.
- **`testOpenWikiOpensWikiBrowser`** — Pre-existing headless assumption-filter incomplete; unrelated to Phase 1041.

---

### Human Verification Required

The 9-step visual checklist in `1041-MANUAL-VERIFY.md` covers behaviors that are not headlessly assertable. This was explicitly deferred by user decision.

#### 1. Default range button label and color (Step 1)

**Test:** Open the companion in MATLAB, inspect the toolbar immediately after open.
**Expected:** Range button reads "Last 7 days" with WidgetBorderColor background (not Accent).
**Why human:** uifigure button rendering and color inspection not headlessly assertable.

#### 2. Picker opens with 3 tabs, Quick active (Step 2)

**Test:** Click the "Last 7 days" button.
**Expected:** 400x280 popup titled "Time Range", 3 tabs (Quick/Relative/Absolute), Quick tab Accent-highlighted, 6 presets listed, "Last 7 days" preset highlighted, Cancel visible (no Apply in Quick mode).
**Why human:** uifigure popup geometry and tab rendering require live session.

#### 3. One-click preset applies and re-queries (Step 3)

**Test:** With picker open, click "Last 30 days".
**Expected:** Popup closes immediately, toolbar label updates to "Last 30 days", button turns Accent, open views re-query.
**Why human:** Popup-close interaction and Accent-color state change require live session.

#### 4. Relative tab: live preview + Apply (Step 4)

**Test:** Reopen picker, switch to Relative tab, change N=14 and unit=weeks.
**Expected:** Preview label updates live to the new date span. Click Apply — popup closes, label reads "Last 14 weeks".
**Why human:** uispinner/uidropdown interaction and live preview update require live session.

#### 5. Absolute tab: validation + Apply (Step 5)

**Test:** Switch to Absolute tab. Set start=today, end=yesterday → Apply disabled, red error text. Fix end to tomorrow → Apply enabled. Click Apply.
**Expected:** See MANUAL-VERIFY.md Steps 5A and 5B.
**Why human:** uidatepicker date-selection interaction and color-coded validation text require live session.

#### 6. Empty-state for out-of-window sensor (Step 6)

**Test:** With "Last 30 days" active, open an ad-hoc plot for a tag whose data is entirely in 2020.
**Expected:** Plot window shows centered bold "No data in selected range" label; no crash, no blank axes.
**Why human:** Visual rendering of the empty-state label in a spawned figure requires live session.

#### 7. Relative window slides on live tick (Step 7)

**Test:** Set range to "Last 7 days", open a live-to-today sensor, click Live, let 3+ ticks elapse.
**Expected:** Right edge of data window slides forward with wall-clock now; "Last 7 days" label stays constant. Absolute range regression: window stays fixed.
**Why human:** Timing behavior across multiple live ticks with a tail-producing sensor requires live session.

#### 8. Theme restyle of range button (Step 8)

**Test:** Open Settings dialog, switch theme (dark ↔ light), close Settings.
**Expected:** Range button FontColor and BackgroundColor restyle to the new theme.
**Why human:** Theme visual comparison requires live session.

#### 9. Persistence across companion reopen (Step 9)

**Test:** Set "Last 30 days", call `c.close()`, reopen with `c2 = FastSenseCompanion('Registry', TagRegistry)`.
**Expected:** New companion shows "Last 30 days" (Accent), `c2.currentTimeWindow()` returns ~30-day span.
**Why human:** Observable only in a live MATLAB session where prefs file survives across object destruction.

---

### Gaps Summary

No gaps blocking goal achievement. All 10 automated must-haves are verified in the codebase. The only outstanding items are the 9 visual/interactive behaviors in `1041-MANUAL-VERIFY.md`, which were explicitly deferred by user decision and correctly categorized as human-only (uifigure rendering, live tick timing, prefs persistence across sessions).

---

_Verified: 2026-06-02T17:00:00Z_
_Verifier: Claude (gsd-verifier)_
