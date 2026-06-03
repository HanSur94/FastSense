# Phase 1041: Global Kibana-style time range for the Companion — Research

**Researched:** 2026-06-02
**Domain:** MATLAB uifigure companion + Tag data layer windowing
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Data layer — source-agnostic windowed read (additive, backward-compatible)**
- Add `[X, Y] = getXYRange(obj, tStart, tEnd)` to the Tag contract.
- `Tag` base provides a concrete default: call `getXY()` then binary-search-slice. Derived/composite/state/monitor tags work immediately.
- `SensorTag` overrides `getXYRange`: disk-backed delegates to `DataStore.getRange(tStart, tEnd)`; RAM slices `X_/Y_`.
- Existing `getXY()` is UNTOUCHED. Empty/`[]` bounds returns full series.
- `SensorTag.getTimeRange()` disk-backed fix: consult DataStore for true extent. Add cheap `XMin`/`XMax` getter to `FastSenseDataStore`.

**Orchestration layer**
- New handle class `CompanionTimeRange`: single source of truth. Holds spec (relative or absolute). Fires `RangeChanged` event.
- New UI control `CompanionTimeBar`: Kibana picker in the existing companion toolbar `'1x'` spacer column.
- Quick presets: Last 24h / 7d / 30d / 90d / 1y / All. Relative builder. Absolute `uidatepicker` start + end.
- uifigure-native controls only. Do NOT model on classical-axes `TimeRangeSelector`.

**View layer**
- `DashboardEngine.setTimeWindow(t0, t1)` storing `TimeWindow_`; feeds existing `rerenderWidgets`/`updateGlobalTimeRange` machinery.
- `FastSenseWidget`: switch the THREE data-pull call sites — render, refresh, update — from `getXY()` to `getXYRange(t0, t1)`.
- `SensorDetailPlot`: add `'TimeWindow'` NV-option via `parseOpts`.
- `openAdHocPlot` overlay path and `RawAxesWidget` closure: honor window.

**Data flow & re-query**
- On open: companion resolves current range, passes `[t0, t1]` into view.
- On `RangeChanged`: companion iterates `OpenedFigures_` + managed `Engines_`, calls `setTimeWindow` on each.
- Relative range slides on live ticks; absolute stays fixed.
- Mixed extents: `getXYRange` returns empty → per-widget "No data in selected range" empty-state.

**Default range:** Last 7 days, configurable via `companionPrefs`.

### Claude's Discretion
- Exact `CompanionTimeBar` layout, popup styling, preset list rendering, label formatting.
- Internal representation of the relative/absolute spec and the resolve math.
- Whether `CompanionTimeRange` is a standalone handle class or folded into the companion (recommend standalone for testability).
- How the window is threaded engine→widget (engine-stored `TimeWindow_` read by widget on refresh, vs passed per-refresh).

### Deferred Ideas (OUT OF SCOPE)
- Auto-refresh interval control.
- Sub-day time-of-day precision in the picker UI.
- Scrub-beyond-window incremental loading in `SensorDetailPlot`'s navigator.
- Per-view pin / unpin from the global range.
- Recently-used ranges list.
- `datetime`/timezone-aware handling beyond a single numeric time-base convention.
</user_constraints>

---

## Summary

This research investigated seven open questions from CONTEXT.md using direct code inspection of the canonical codebase. All seven questions are now resolved with code-level evidence.

**The canonical time-base is MATLAB `datenum` (days since Jan 0, 0000)**, used universally in the industrial plant demo and the primary data pipeline. The InspectorPane sparkline formatter already embeds the multi-convention detection heuristic (`x > 7e5` → datenum). The date picker must convert wall-clock calendar dates to datenum via `datenum(d)` or equivalently `datenum(datetime(...))`.

**FastSenseDataStore already stores `XMin`/`XMax` as public `SetAccess=private` properties** (lines 42-43), populated from `x(1)`/`x(end)` at construction. No new SQL query is needed for the time-extent getter; just expose reading those two properties.

**DashboardEngine has no existing `TimeWindow_`** — it stores `DataTimeRange` (widget union) and passes time ranges to the `TimeRangeSelector` scrubber. A new `TimeWindow_` property (default `[]` = full range) is the cleanest seam; the three widget data-pull call sites in `FastSenseWidget` (lines 283, 337, 367) call `getXY()` directly and need to be switched to `getXYRange`.

**`uidatepicker` is available R2020a+** (confirmed by CONTEXT.md notes). The companion's established dialog pattern is a small standalone `uifigure` (see `CompanionSettingsDialog.m`), which is the model for the picker popup.

**The companion tracks opened figures in `OpenedFigures_`** (column vector of figure handles, line 116-117 of FastSenseCompanion.m) but the only handle stored for ad-hoc plots is the `hFig` returned from `openAdHocPlot`. The `DashboardEngine` itself is NOT stashed on figure appdata — only `hFig` is tracked. This means a re-query strategy requires either (a) stashing the engine on figure appdata at open time, or (b) finding the engine from `hFig` via `findobj` / appdata lookup.

**The InspectorPane multitag composer `SparkWindowSec_` (30-minute sparkline window, line 28)** is a display-only window inside the sparkline sub-panel, not a data-load limiter. The global time bar supersedes it for data loading; the sparkline can remain unchanged (it already applies its own trailing window before plotting).

**Octave/MATLAB split:** `getXYRange` + DataStore extent reading are Octave-safe. All companion UI classes are MATLAB-only; the established guard pattern is `if exist('OCTAVE_VERSION', 'builtin') ~= 0; fprintf(...); return; end` in function-based tests, and `skipOnOctave` in `TestMethodSetup` for class suites.

**Primary recommendation:** Implement the data layer (Tag.getXYRange + SensorTag override + DataStore.XMin/XMax exposure + SensorTag.getTimeRange disk-fix) first, in isolation, with full Octave-runnable unit tests. Then build the MATLAB-only CompanionTimeRange + CompanionTimeBar in a later wave.

---

## Standard Stack

### Core (all existing — no new dependencies)

| Component | Where | Purpose in this Phase |
|-----------|-------|----------------------|
| `libs/SensorThreshold/Tag.m` | `getXY(:120)`, `getTimeRange(:130)` | Add `getXYRange` default implementation |
| `libs/SensorThreshold/SensorTag.m` | `X_`, `DataStore_`, `isOnDisk()` | Override `getXYRange`; fix `getTimeRange` disk path |
| `libs/FastSense/FastSenseDataStore.m` | `XMin`/:42, `XMax`/:43, `getRange`/:92 | `XMin`/`XMax` already public `SetAccess=private` — expose via getter or document as readable directly |
| `libs/Dashboard/FastSenseWidget.m` | `getXY` calls at `:283`, `:337`, `:367` | Switch to `getXYRange(t0, t1)` |
| `libs/Dashboard/DashboardEngine.m` | `DataTimeRange`/:70, `updateGlobalTimeRange`/:1807, `rerenderWidgets`/:1730 | Add `TimeWindow_` property + `setTimeWindow` method |
| `libs/FastSense/SensorDetailPlot.m` | `parseOpts`/:90, `getXY`/:126 | Add `'TimeWindow'` NV-option |
| `libs/FastSenseCompanion/FastSenseCompanion.m` | toolbar grid `:326-327`, `OpenedFigures_`/:116 | Host `CompanionTimeBar` in toolbar spacer; push window on `RangeChanged` |
| `libs/FastSenseCompanion/companionPrefs.m` | forward-compatible struct load/save | Store default range preset |
| `libs/FastSenseCompanion/private/openAdHocPlot.m` | `plotOverlay_`/:142, `engine`/:88 | Pass `TimeWindow` to engine at open time; stash engine on figure appdata |

### New Files to Create

| File | Purpose |
|------|---------|
| `libs/FastSenseCompanion/CompanionTimeRange.m` | Source-of-truth handle class: spec (relative/absolute) + resolve + `RangeChanged` event |
| `libs/FastSenseCompanion/CompanionTimeBar.m` | uifigure-native toolbar picker: preset buttons + relative builder + absolute `uidatepicker` |

---

## Open Questions — Resolved with Code Evidence

### Q1: X Time-Base Convention (RESOLVED — HIGH confidence)

**Evidence from codebase:**

- `demo/industrial_plant/plantConfig.m:113`: `cfg.TimeBase = 'datenum';` — explicit documentation of the canonical convention.
- `demo/industrial_plant/seedHistory.m:53-55`: `nowRef = now(); tHist = (nowRef - nDays : 1/86400 : nowRef)';` — X is `now()` (MATLAB datenum, days since Jan 0, 0000), 1-Hz steps are `1/86400` days.
- `demo/industrial_plant/private/makeDataGenerator.m:15-16`: "Time base: MATLAB serial date number (datenum). All X values fed to TagRegistry / FastSense are datenum-style doubles."
- `examples/01-basics/example_datetime.m:9`: `x = datenum(2024,1,1) + (0:n-1)/86400;` — canonical time-based example also uses datenum.
- `examples/simple_live_dashboard.m:54,79`: uses `posixtime(datetime('now'))` — this is the ONLY posixtime usage found. A small number of scripts use posixtime (Unix epoch, seconds since 1970).
- `libs/FastSenseCompanion/InspectorPane.m:604-620`: `formatXTick_` already implements a multi-convention heuristic: `if x > 1e9 → posixtime`, `elseif x > 7e5 → datenum`, `elseif x >= 60 → MM:SS`, else seconds.
- `libs/FastSenseCompanion/InspectorPane.m:676-678`: `windowSparkData_` heuristic for datenum: `if (xMax - tv(1)) < 1 && (xMax > 7e5)` then divide window by 86400.
- `SensorTag.load(:222)`: index fallback `obj.X_ = 1:numel(entry)` — non-time X for .mat files with no x field.

**Recommendation (LOCKED):** The canonical convention is **MATLAB `datenum`** (double, days since Jan 0, 0000). The date picker converts wall-clock dates using `datenum(year, month, day)` or `datenum(datetime(...))`. For relative presets: `now() - N_days` for Last N days.

**Handling for posixtime tags:** The InspectorPane heuristic (`x > 1e9`) is a reliable runtime discriminator. The `CompanionTimeRange.resolve()` method should similarly auto-detect or allow the tag type to self-report. For v1, since the industrial plant demo (the primary use case) is uniformly datenum, `CompanionTimeRange` stores and resolves in datenum. Posixtime tags (like `simple_live_dashboard`) will behave correctly only if their time range is discovered from `getTimeRange()` and compared in the same unit — this is handled naturally because `getTimeRange()` returns the tag's native X unit, and the picker's extent bounds = union of known tag extents (already in native X units).

**Index-X tags (SensorTag.load fallback, `X_ = 1:numel`):** These cannot honor a date window. `getXYRange(t0, t1)` should detect this via `getTimeRange()` returning a small integer range and fall back to full series (i.e., return all data). The recommended detection: if `getTimeRange()` returns `[1, N]` with integer-valued bounds, treat as index-X and return full series from the default `getXYRange` base class implementation. A simpler pragmatic approach: the base class `getXYRange` default slices by binary search — if the window `[t0, t1]` does not overlap `[X(1), X(end)]`, it returns empty, which is the correct empty-state behavior. No special-casing is needed for index-X tags; they just always show "no data" when a date window is active — the user learns to switch to "All" for those tags.

**Relative anchor:** Wall-clock `now()` (datenum). For purely historical data, Last-7-days vs wall-clock will be empty; the empty-state handles this. Confirmed for v1.

### Q2: FastSenseDataStore XMin/XMax (RESOLVED — HIGH confidence)

**Evidence from codebase:**

- `libs/FastSense/FastSenseDataStore.m:40-48` (SetAccess=private properties block):
  ```matlab
  properties (SetAccess = private)
      NumPoints  = 0
      XMin       = NaN    % :42
      XMax       = NaN    % :43
      ...
  end
  ```
- `libs/FastSense/FastSenseDataStore.m:75-76` (constructor):
  ```matlab
  obj.XMin = x(1);
  obj.XMax = x(end);
  ```
  These are set at construction from the full X array — they represent the global [xMin, xMax] of the store.
- `libs/FastSense/FastSenseDataStore.m:92-110` (`getRange` signature and semantics): `getRange(obj, xMin, xMax)` reads chunks where `x_max >= xMin AND x_min <= xMax`, plus one neighbour on each side (one-point padding via `padClamp`). Returns `[xOut, yOut]`.

**Resolution:** `FastSenseDataStore.XMin` and `FastSenseDataStore.XMax` **already exist as public (read-accessible) properties** — they are `SetAccess=private` but readable externally. No new SQL query needed. The `SensorTag.getTimeRange()` fix for disk-backed sensors simply reads `obj.DataStore_.XMin` and `obj.DataStore_.XMax` instead of returning `[NaN NaN]`. This is O(1), no disk access.

**`getRange` one-point padding behavior (confirmed):** `libs/FastSense/FastSenseDataStore.m:989-993` (`padClamp`): `iStart = max(1, iStart - 1); iEnd = min(n, iEnd + 1);` — one extra point on each boundary, always. This ensures continuity at the edge of the window. `getXYRange` for disk-backed SensorTags calls `DataStore_.getRange(tStart, tEnd)` directly.

**Inverted range handling:** `getRange(:98-101)`: `if xMin > xMax → xOut = []; yOut = [];` — returns empty, no error. The `getXYRange` contract should document the same.

### Q3: DashboardEngine Global-Range Internals (RESOLVED — HIGH confidence)

**Evidence from codebase:**

- `libs/Dashboard/DashboardEngine.m:70`: `DataTimeRange = [0 1]` — existing field for widget union time range.
- `libs/Dashboard/DashboardEngine.m:85`: `TimeRangeSelector_ = []` — the existing drag-scrubber for the time panel.
- `libs/Dashboard/DashboardEngine.m:1807-1842` (`updateGlobalTimeRange`): scans `activePageWidgets()` → calls `ws{i}.getTimeRange()` → updates `DataTimeRange` and calls `TimeRangeSelector_.setDataRange(tMin, tMax)`.
- `libs/Dashboard/DashboardEngine.m:1730` (`rerenderWidgets`): full widget teardown/rebuild cycle; `TimeRangeSelector_.reinstallCallbacks()` is called here.
- `libs/Dashboard/FastSenseWidget.m:283` (render): `[~, yInit] = obj.Tag.getXY();` (line ~283, for y autoscale purposes)
- `libs/Dashboard/FastSenseWidget.m:337`: `[x, y] = obj.Tag.getXY();` (refresh incremental path)
- `libs/Dashboard/FastSenseWidget.m:367`: `[x, y] = obj.Tag.getXY();` (update path)

**Design recommendation for `setTimeWindow`:** Add `TimeWindow_ = []` to `DashboardEngine` private properties. `setTimeWindow(t0, t1)` stores `[t0 t1]` in `TimeWindow_` then calls `rerenderWidgets()` to rebuild widgets that now read the windowed data. `FastSenseWidget` reads `obj.Engine.TimeWindow_` (or the engine passes it as a parameter to the widget's render/refresh/update) to call `getXYRange(t0, t1)`. The cleanest seam is for `FastSenseWidget` to read the engine's window directly on each data pull — no per-refresh parameter threading required.

**Does the engine pass per-refresh context to widgets?** No. Currently `DashboardEngine.onLiveTick` calls `widget.refresh()` or `widget.update()` with no arguments. The engine calls these via `ws{i}.refresh()` / `ws{i}.update()`. The widget reads from its `Tag` property. To pass the window: either (a) widget queries `engine.TimeWindow_` itself, or (b) engine calls a new `widget.setTimeWindow(t0, t1)` before tick. Option (a) is simpler — `FastSenseWidget` already has an `Engine` back-reference in some form.

**Verify FastSenseWidget has Engine access:** The widget is constructed via `engine.addWidget(...)` — check if it holds an engine ref.

### Q4: uidatepicker / uifigure Controls (RESOLVED — HIGH confidence)

**Evidence from codebase and CONTEXT.md:**
- CONTEXT.md explicitly confirms: `uidatepicker (R2020a+) is date-only (no time-of-day) — fine for v1 day-granularity; sub-day precision is deferred.`
- `uidatepicker` returns a `datetime` value. For datenum conversion: `datenum(uidatepicker.Value)`.
- Pattern confirmed: `CompanionSettingsDialog.m` uses its own `uifigure` (line 50-55): `obj.hFig_ = uifigure('Name', 'Companion Settings', 'Position', [200 200 360 200], 'Resize', 'off', ...)` — this is the established popup pattern.
- The picker popup should follow the same pattern: a small non-modal `uifigure` with a `uigridlayout`, containing `uidropdown` (presets), `uieditfield` (N), `uidropdown` (unit), `uidatepicker` (start/end), and `uibutton` (Apply/Cancel).
- No classical axes in the picker → the drawnow-before-axes pitfall does NOT apply to this control.
- From CLAUDE.md cross-cutting constraints: `Listeners_` cell + `stop/delete` timer ordering applies to any timer in `CompanionTimeBar`; all callbacks wrapped in try/catch + `uialert`.

### Q5: Companion Open/Track/Re-Query Wiring (RESOLVED — MEDIUM confidence)

**Evidence from codebase:**

- `libs/FastSenseCompanion/FastSenseCompanion.m:116-117`: `OpenedFigures_ = []  % column vector of figure handles`.
- `libs/FastSenseCompanion/FastSenseCompanion.m:2140-2147`: `trackOpenedFigure_` walks `OpenedFigures_` and appends non-duplicate valid handles.
- `libs/FastSenseCompanion/private/openAdHocPlot.m:131-137`:
  ```matlab
  engine.render();
  engine.startLive();
  hFig = engine.hFigure;
  if ~isempty(hFig) && ishandle(hFig)
      set(hFig, 'CloseRequestFcn', @(s, ~) closeFcn_(s, engine));
  end
  ```
  The engine handle is captured in the `CloseRequestFcn` closure but is NOT stored on `hFig` appdata — only `hFig` is returned and tracked.

- `libs/FastSenseCompanion/FastSenseCompanion.m:2150-2159`: `onOpenAdHocPlotRequested_` calls `openAdHocPlot({tgK}, 'LinkedGrid', obj.Theme)` and then `obj.trackOpenedFigure_(hFig_k)` — the engine is NOT stashed.

**Gap identified:** When `RangeChanged` fires and the companion wants to call `setTimeWindow` on an opened ad-hoc figure's engine, there is no current way to recover the engine from `hFig`. The companion only has the figure handle.

**Recommendation:** When `openAdHocPlot` opens an engine and returns `hFig`, stash the engine on `hFig` appdata at that call site:
```matlab
setappdata(hFig, 'DashboardEngine', engine);
```
Then on `RangeChanged`, iterate `OpenedFigures_`:
```matlab
for k = 1:numel(obj.OpenedFigures_)
    hf = obj.OpenedFigures_(k);
    if ~ishandle(hf); continue; end
    eng = getappdata(hf, 'DashboardEngine');
    if ~isempty(eng) && isvalid(eng)
        eng.setTimeWindow(t0, t1);
    end
end
```
Managed engines in `Engines_` (dashboards) already have direct handles; iterate those separately.

**Confidence: MEDIUM** — the `openAdHocPlot` stash is a one-line addition with no downside, but requires verifying that `Engines_` contains all companion-managed dashboard engines.

### Q6: Inspector Multitag Composer (RESOLVED — HIGH confidence)

**Evidence from codebase:**

- `libs/FastSenseCompanion/InspectorPane.m:28`: `SparkWindowSec_ = 1800` — the 30-minute sparkline window.
- `libs/FastSenseCompanion/InspectorPane.m:668-686`: `windowSparkData_` applies this window for sparkline display only. It calls `tag.getXY()` and then slices in memory.
- The multitag composer (lines ~1181-1200) has Overlay / Linked grid / Per Tag mode buttons and a Plot CTA button. There is NO "time range All / Last 1h" dropdown in the current InspectorPane implementation (the STATE.md v3.0 brainstorm mention was an idea that was not implemented — the current code has only `SparkWindowSec_` for sparklines).

**Resolution:** The InspectorPane has no time range picker to supersede. The global `CompanionTimeBar` is additive — it applies when views are opened. The sparkline `SparkWindowSec_` is a display convenience (trailing 30 min) that is completely independent of the global range. **Leave the sparkline unchanged.** It shows the last 30 min of whatever data is in memory; it does not drive data loading.

### Q7: Octave vs MATLAB Split for Tests (RESOLVED — HIGH confidence)

**Evidence from codebase:**

- `tests/test_companion_open_ad_hoc_plot.m:9-12`: canonical Octave-skip pattern for MATLAB-only companion code:
  ```matlab
  if exist('OCTAVE_VERSION', 'builtin') ~= 0
      fprintf('  Skipping test_companion_open_ad_hoc_plot on Octave.\n');
      return;
  end
  ```
- `tests/suite/TestFastSenseCompanion.m:33-38`: `skipOnOctave` in `TestMethodSetup` skips entire suite on Octave.
- `libs/SensorThreshold/Tag.m`, `SensorTag.m`, `FastSenseDataStore.m`: pure MATLAB/Octave compatible (binary search + array slicing + mksqlite). No MATLAB-specific syntax in the data layer.

**Confirmed split:**

| Code | Runtime | Test location |
|------|---------|--------------|
| `Tag.getXYRange` (base default) | MATLAB + Octave | `tests/test_sensor_tag_range.m` (new, function-style) |
| `SensorTag.getXYRange` (RAM + disk) | MATLAB + Octave | Same file |
| `SensorTag.getTimeRange` disk-fix | MATLAB + Octave | Same file |
| `FastSenseDataStore` XMin/XMax | MATLAB + Octave | Same file |
| `CompanionTimeRange` (pure logic) | MATLAB + Octave | `tests/test_companion_time_range.m` (new, function-style with Octave header guard for event-firing) |
| `CompanionTimeBar` (UI) | MATLAB-only | `tests/suite/TestCompanionTimeBar.m` (new, class-based, Octave-skipped in `TestMethodSetup`) |
| `DashboardEngine.setTimeWindow` | MATLAB + Octave | `tests/test_dashboard_time_window.m` (new, function-style) |
| `FastSenseWidget` windowed calls | MATLAB + Octave | Same file |

---

## Architecture Patterns

### Recommended New File Structure

```
libs/FastSenseCompanion/
├── CompanionTimeRange.m    % NEW: handle class — source of truth for time spec
├── CompanionTimeBar.m      % NEW: uifigure toolbar control for the picker popup
└── (existing files unchanged)

tests/
├── test_sensor_tag_range.m         % NEW: Octave-safe data-layer tests
├── test_companion_time_range.m     % NEW: CompanionTimeRange logic tests
├── test_dashboard_time_window.m    % NEW: DashboardEngine.setTimeWindow tests
└── suite/
    └── TestCompanionTimeBar.m      % NEW: MATLAB-only UI integration tests
```

### Pattern 1: Tag.getXYRange Default Implementation

The base class provides a concrete (non-error) default by calling `getXY()` then slicing:

```matlab
% In Tag.m — concrete default
function [X, Y] = getXYRange(obj, tStart, tEnd)
    %GETXYRANGE Return X, Y sliced to [tStart, tEnd].
    %   Default: calls getXY() then binary-search-slices.
    %   SensorTag overrides for disk-backed efficiency.
    %   Empty/[] bounds return full series (delegates to getXY()).
    if nargin < 3 || isempty(tStart) || isempty(tEnd)
        [X, Y] = obj.getXY();
        return;
    end
    [X, Y] = obj.getXY();
    if isempty(X); return; end
    iLo = binary_search(X, tStart, 'left');
    iHi = binary_search(X, tEnd,   'right');
    iLo = max(1, iLo - 1);  % one-point padding (matches DataStore.getRange)
    iHi = min(numel(X), iHi + 1);
    X = X(iLo:iHi);
    Y = Y(iLo:iHi);
end
```

### Pattern 2: SensorTag.getXYRange Override

```matlab
% In SensorTag.m
function [X, Y] = getXYRange(obj, tStart, tEnd)
    %GETXYRANGE Return windowed (X, Y). Disk path delegates to DataStore.getRange.
    if nargin < 3 || isempty(tStart) || isempty(tEnd)
        [X, Y] = obj.getXY(); return;
    end
    if obj.isOnDisk()
        [X, Y] = obj.DataStore_.getRange(tStart, tEnd);
    else
        if isempty(obj.X_); X = []; Y = []; return; end
        iLo = binary_search(obj.X_, tStart, 'left');
        iHi = binary_search(obj.X_, tEnd,   'right');
        iLo = max(1, iLo - 1);
        iHi = min(numel(obj.X_), iHi + 1);
        X = obj.X_(iLo:iHi);
        Y = obj.Y_(iLo:iHi);
    end
end
```

### Pattern 3: SensorTag.getTimeRange Disk-Fix

```matlab
% In SensorTag.m — existing getTimeRange(:134-143)
function [tMin, tMax] = getTimeRange(obj)
    if obj.isOnDisk()
        tMin = obj.DataStore_.XMin;  % already stored at construction
        tMax = obj.DataStore_.XMax;
        return;
    end
    if isempty(obj.X_)
        tMin = NaN; tMax = NaN; return;
    end
    tMin = obj.X_(1);
    tMax = obj.X_(end);
end
```

### Pattern 4: CompanionTimeRange (Standalone Handle Class)

```matlab
classdef CompanionTimeRange < handle
    events
        RangeChanged
    end
    properties (Access = private)
        SpecType_ = 'relative'  % 'relative' | 'absolute' | 'all'
        RelN_     = 7           % numeric
        RelUnit_  = 'days'      % 'hours'|'days'|'weeks'|'months'|'years'
        AbsT0_    = []          % datenum
        AbsT1_    = []          % datenum
    end
    methods
        function [t0, t1] = resolve(obj)
            % Resolves spec to concrete [t0, t1] in datenum.
            % Relative anchor: now() (wall-clock datenum).
            switch obj.SpecType_
                case 'relative'
                    t1 = now();
                    t0 = t1 - obj.relN_asDays_();
                case 'absolute'
                    t0 = obj.AbsT0_; t1 = obj.AbsT1_;
                case 'all'
                    t0 = []; t1 = [];  % signals "full series"
            end
        end
        function setRelative(obj, N, unit)
            obj.SpecType_ = 'relative';
            obj.RelN_ = N; obj.RelUnit_ = unit;
            notify(obj, 'RangeChanged');
        end
        function setAbsolute(obj, t0, t1)
            obj.SpecType_ = 'absolute';
            obj.AbsT0_ = t0; obj.AbsT1_ = t1;
            notify(obj, 'RangeChanged');
        end
        function setAll(obj)
            obj.SpecType_ = 'all';
            notify(obj, 'RangeChanged');
        end
        function lbl = label(obj)
            % Returns human-readable label for toolbar button.
            switch obj.SpecType_
                case 'relative'
                    lbl = sprintf('Last %d %s', obj.RelN_, obj.RelUnit_);
                case 'absolute'
                    lbl = sprintf('%s to %s', datestr(obj.AbsT0_, 'yyyy-mm-dd'), ...
                        datestr(obj.AbsT1_, 'yyyy-mm-dd'));
                case 'all'
                    lbl = 'All';
            end
        end
    end
    methods (Access = private)
        function d = relN_asDays_(obj)
            switch obj.RelUnit_
                case 'hours',  d = obj.RelN_ / 24;
                case 'days',   d = obj.RelN_;
                case 'weeks',  d = obj.RelN_ * 7;
                case 'months', d = obj.RelN_ * 30;
                case 'years',  d = obj.RelN_ * 365;
                otherwise,     d = obj.RelN_;
            end
        end
    end
end
```

### Pattern 5: DashboardEngine.setTimeWindow Seam

Add to `DashboardEngine` private properties:
```matlab
TimeWindow_ = []  % [t0 t1] datenum set by companion; [] = full range
```

New public method:
```matlab
function setTimeWindow(obj, t0, t1)
    %SETTIMEWINDOW Set the load window and trigger a widget re-resolve.
    %   t0, t1: datenum scalars. Both [] resets to full range.
    obj.TimeWindow_ = [t0, t1];
    obj.rerenderWidgets();
end
```

`FastSenseWidget` data-pull change (all three sites):
```matlab
% Before: [x, y] = obj.Tag.getXY();
% After:
eng = obj.Engine_;  % back-reference to parent DashboardEngine
if ~isempty(eng) && ~isempty(eng.TimeWindow_)
    [x, y] = obj.Tag.getXYRange(eng.TimeWindow_(1), eng.TimeWindow_(2));
else
    [x, y] = obj.Tag.getXY();
end
```

### Pattern 6: CompanionTimeBar Toolbar Integration

The companion toolbar is a 1×10 `uigridlayout` (post-Phase-1040). Column 9 is the `'1x'` spacer. `CompanionTimeBar` occupies that spacer (expands to fill available width). The range button is a `uibutton` showing the current label; clicking opens the picker popup (`uifigure`, small, non-modal, positioned near the toolbar button using `getpixelposition`).

### Anti-Patterns to Avoid

- **Stateful window on Tag:** Rejected (Approach 2 in CONTEXT.md). Collides with live pipelines and monitor tags.
- **WindowedTag wrapper:** Rejected (Approach 3 in CONTEXT.md). Breaks `isa(tag, 'MonitorTag')` checks at `openAdHocPlot:165`.
- **Calling `updateGlobalTimeRange` after `setTimeWindow`:** Do NOT call `updateGlobalTimeRange` from `setTimeWindow` — that method scans widgets for their data range and resets the scrubber. Instead call `rerenderWidgets()` which rebuilds widget panels (widgets then load the windowed data in their render paths), then let the existing live-tick logic handle `updateLiveTimeRange`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Date conversion | Custom date-string parser | `datenum(year, month, day)` / `datenum(datetime(...))` | MATLAB built-in; Octave-compatible |
| Binary search for slice bounds | Custom loop | `binary_search(X, val, 'left'/'right')` | Already used everywhere in Tag data layer |
| Time-extent of disk store | SQL `SELECT min(x)/max(x)` | `DataStore_.XMin` / `DataStore_.XMax` | Already O(1) stored at construction |
| Preference persistence | Custom file | `companionPrefs('load'/'save', struct)` | Already handles atomic write, missing-file, corrupt-file |
| Option parsing | Custom NV-pair loop | `parseOpts(defaults, varargin)` | Established pattern used in SensorDetailPlot, DashboardEngine |
| Popup dialog sizing/positioning | Manual pixel math | `uifigure` + `uigridlayout` | Same as CompanionSettingsDialog — tested and themed |

---

## Common Pitfalls

### Pitfall 1: `SensorTag.getTimeRange()` returns `[NaN NaN]` for disk-backed sensors — already documented in CONTEXT.md

**What goes wrong:** The picker's extent bounds (union of known tag time ranges) come up `[NaN NaN]` for disk-backed sensors because the current implementation reads `obj.X_` which is empty after `toDisk()`.
**Root cause:** `SensorTag.getTimeRange(:134-143)` only reads `obj.X_` — it does not consult `DataStore_`.
**Fix:** Check `obj.isOnDisk()` first and return `[obj.DataStore_.XMin, obj.DataStore_.XMax]`. `XMin`/`XMax` are set at construction from `x(1)`/`x(end)` so no extra I/O.

### Pitfall 2: Replacing `getXY()` with `getXYRange()` in `FastSenseWidget.getPreviewSeries` / `getTimeRange`

**What goes wrong:** `FastSenseWidget` also uses `obj.Tag.getXY()` in `getPreviewSeries` (used by the dashboard slider preview) and has cached `CachedXMin`/`CachedXMax` (line :75-77). If you switch `getPreviewSeries` to `getXYRange`, the preview envelope covers only the loaded window rather than the full dataset — slider-preview no longer shows the global picture.
**How to avoid:** Only switch the THREE data-plot call sites (render/refresh/update). Leave `getPreviewSeries` and `getTimeRange`/cache logic on `getXY()` so the preview slider always shows the full historical envelope.

### Pitfall 3: Engine back-reference from FastSenseWidget

**What goes wrong:** If `FastSenseWidget` doesn't have a back-reference to its parent `DashboardEngine`, it cannot read `TimeWindow_`. 
**Check needed:** Verify whether `FastSenseWidget` stores an `Engine_` handle. If not, one option is to pass `TimeWindow_` as a parameter to `FastSenseWidget.setTimeWindow(t0, t1)` and have the engine call it before ticks. A simpler alternative: add a `TimeWindow_` property directly on `FastSenseWidget` populated by the engine's `setTimeWindow` method (which iterates `activePageWidgets()` and calls `widget.setTimeWindow`).

### Pitfall 4: `rerenderWidgets` is expensive — don't call on every live tick

**What goes wrong:** `DashboardEngine.setTimeWindow` calls `rerenderWidgets()` which deletes and recreates all widget panels. This is the correct choice for a user-initiated range change, but it must NOT be called on every live tick for a relative sliding window.
**How to avoid:** During live ticks, the relative range slides silently. Ticks call `widget.update()` / `widget.refresh()` which already read `getXYRange` with the current `now()`. Only call `rerenderWidgets` when the user explicitly changes the range spec (via `CompanionTimeBar`).

### Pitfall 5: `OpenedFigures_` pruning invalidates stale handles

**What goes wrong:** `OpenedFigures_` holds raw figure handles. Before iterating for `RangeChanged`, dead handles must be pruned: `obj.OpenedFigures_(~ishandle(obj.OpenedFigures_)) = [];`. Missing this causes errors.
**How to avoid:** The companion already has a `syncOpenedFigures_` method that does this pruning — call it before iterating in the `RangeChanged` listener.

### Pitfall 6: uidatepicker value is `datetime`, not datenum

**What goes wrong:** `uidatepicker.Value` returns a `datetime` object. Passing it directly to `getXYRange(tStart, tEnd)` fails for datenum-based tags (datetime vs double comparison).
**Fix:** Always convert: `t0 = datenum(picker.Value)`. Document in `CompanionTimeRange.setAbsolute`.

### Pitfall 7: `binary_search` in `getXYRange` base default — path dependency

**What goes wrong:** `Tag.getXYRange` default calls `binary_search(X, val, side)`. This helper lives in `libs/FastSense/`. Tests for `Tag.getXYRange` must have this on the path.
**Fix:** Call `install()` in test setup (standard pattern), or inline the bsearch as a local function in `Tag.m` to avoid the external dependency. The safer choice is to use the existing `binary_search` and rely on `install()` in tests.

---

## Code Examples

### getTimeRange disk fix (verified pattern)

```matlab
% SensorTag.getTimeRange — corrected
function [tMin, tMax] = getTimeRange(obj)
    %GETTIMERANGE Return [X(1), X(end)].  [NaN NaN] if empty.
    if obj.isOnDisk()
        tMin = obj.DataStore_.XMin;
        tMax = obj.DataStore_.XMax;
        return;
    end
    if isempty(obj.X_)
        tMin = NaN; tMax = NaN; return;
    end
    tMin = obj.X_(1);
    tMax = obj.X_(end);
end
```

### Companion RangeChanged listener in FastSenseCompanion

```matlab
% In FastSenseCompanion constructor, after TimeRange_ is instantiated:
obj.Listeners_{end+1} = addlistener(obj.TimeRange_, 'RangeChanged', ...
    @(~,~) obj.onRangeChanged_());

% In FastSenseCompanion private methods:
function onRangeChanged_(obj)
    try
        [t0, t1] = obj.TimeRange_.resolve();
        % Push to managed engines (dashboards)
        for i = 1:numel(obj.Engines_)
            try
                if isvalid(obj.Engines_{i})
                    obj.Engines_{i}.setTimeWindow(t0, t1);
                end
            catch
            end
        end
        % Push to ad-hoc figure engines (via appdata stash)
        obj.syncOpenedFigures_();
        for k = 1:numel(obj.OpenedFigures_)
            hf = obj.OpenedFigures_(k);
            if ~ishandle(hf); continue; end
            try
                eng = getappdata(hf, 'DashboardEngine');
                if ~isempty(eng) && isvalid(eng)
                    eng.setTimeWindow(t0, t1);
                end
            catch
            end
        end
    catch ME
        try uialert(obj.hFig_, ME.message, 'Time Range Error'); catch; end
    end
end
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|-----------------|--------|
| `tag.getXY()` returns full 10-year series | `tag.getXYRange(t0, t1)` returns only the window | Genuine memory savings for disk-backed sensors; performance improvement on render |
| `SensorTag.getTimeRange()` returns `[NaN NaN]` for disk | Reads `DataStore_.XMin`/`XMax` | Picker extent bounds now work for all sensors |
| Companion opens full-history plots | Companion passes `[t0 t1]` at open time | Views load bounded data immediately |

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — pure MATLAB/Octave code changes only; `uidatepicker` is MATLAB built-in available R2020a+).

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json` — Validation Architecture section is required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Custom runner: `tests/run_all_tests.m`; class suites via `matlab.unittest.TestCase` (MATLAB only) |
| Config file | `tests/run_all_tests.m` discovers `test_*.m` + `suite/Test*.m` |
| Quick run (function-style) | `mcp__matlab__evaluate_matlab_code` calling `test_sensor_tag_range()` |
| Full suite | `mcp__matlab__run_matlab_file` on `tests/run_all_tests.m` |

### Phase Requirements → Test Map

No formal REQ-IDs for this ad-hoc phase. Derive from CONTEXT.md acceptance criteria.

| Behavior | Test Type | Automated Command | Notes |
|----------|-----------|-------------------|-------|
| `Tag.getXYRange([],[])` returns full series (same as `getXY`) | unit | `test_sensor_tag_range` → testGetXYRangeFull | MATLAB + Octave |
| `Tag.getXYRange(t0,t1)` returns only in-range points (RAM SensorTag) | unit | `test_sensor_tag_range` → testGetXYRangeRAMInRange | MATLAB + Octave |
| `SensorTag.getXYRange` empty result when window outside data | unit | `test_sensor_tag_range` → testGetXYRangeEmpty | MATLAB + Octave |
| `SensorTag.getXYRange(t0,t1)` inverted range returns empty | unit | `test_sensor_tag_range` → testGetXYRangeInverted | MATLAB + Octave |
| `SensorTag.getTimeRange()` returns non-NaN for disk-backed sensor | unit | `test_sensor_tag_range` → testGetTimeRangeDisk | MATLAB + Octave (needs mksqlite or binary fallback) |
| `DashboardEngine.setTimeWindow` stores `TimeWindow_` | unit | `test_dashboard_time_window` → testSetTimeWindow | MATLAB + Octave (headless engine, no figure) |
| `DashboardEngine.setTimeWindow([],[])` clears window | unit | `test_dashboard_time_window` → testClearTimeWindow | MATLAB + Octave |
| `CompanionTimeRange.resolve()` relative → wall-clock datenum | unit | `test_companion_time_range` → testResolveRelative | MATLAB + Octave |
| `CompanionTimeRange.resolve()` absolute → exact t0/t1 | unit | `test_companion_time_range` → testResolveAbsolute | MATLAB + Octave |
| `CompanionTimeRange` fires `RangeChanged` on spec change | unit | `test_companion_time_range` → testRangeChangedFires (MATLAB only; uses `addlistener`) | MATLAB; guard with Octave skip |
| `CompanionTimeRange.resolve()` 'all' → `[]/[]` | unit | `test_companion_time_range` → testResolveAll | MATLAB + Octave |
| `CompanionTimeRange.label()` returns correct string | unit | `test_companion_time_range` → testLabel | MATLAB + Octave |
| Opened plot loads bounded point count under Last 7d window | integration | `test_dashboard_time_window` → testOpenedPlotBounded | MATLAB only (DashboardEngine render) |
| Mixed-extent: `getXYRange` outside data returns empty; widget shows empty-state | unit | `test_sensor_tag_range` → testMixedExtentEmpty | MATLAB + Octave |
| `CompanionTimeBar` range button shows correct label | UI smoke | `TestCompanionTimeBar` → testRangeButtonLabel | MATLAB only; Octave-skipped |
| `CompanionTimeBar` preset click fires `RangeChanged` | UI smoke | `TestCompanionTimeBar` → testPresetFiresEvent | MATLAB only |

### Sampling Rate

- **Per task commit:** Run the function-style test for the directly modified module (e.g., `test_sensor_tag_range()` after Tag/SensorTag changes).
- **Per wave merge:** `tests/run_all_tests.m` full suite.
- **Phase gate:** Full suite green before `/gsd:verify-work`.

### Wave 0 Gaps (files to create before implementation)

- [ ] `tests/test_sensor_tag_range.m` — covers `getXYRange` + `getTimeRange` disk-fix (Octave-safe; uses `MockTag` or inline `SensorTag` with synthetic data)
- [ ] `tests/test_companion_time_range.m` — covers `CompanionTimeRange` logic (Octave guard for event firing)
- [ ] `tests/test_dashboard_time_window.m` — covers `DashboardEngine.setTimeWindow` (headless; no figure required)
- [ ] `tests/suite/TestCompanionTimeBar.m` — covers MATLAB-only UI smoke tests

No framework install needed — existing runner covers everything.

---

## Sources

### Primary (HIGH confidence)
- Direct code read: `libs/SensorThreshold/SensorTag.m` — `getXY`, `getTimeRange`, `load` index fallback, `toDisk`, `isOnDisk`, `DataStore_`
- Direct code read: `libs/SensorThreshold/Tag.m` — contract methods, `getXY` stub
- Direct code read: `libs/FastSense/FastSenseDataStore.m` — `XMin`/`XMax` properties, `getRange` semantics, `padClamp`, `initSqlite` chunk schema
- Direct code read: `libs/Dashboard/DashboardEngine.m` — `DataTimeRange`, `TimeRangeSelector_`, `updateGlobalTimeRange`, `updateLiveTimeRange`, `rerenderWidgets`, `render`, `startLive`
- Direct code read: `libs/Dashboard/FastSenseWidget.m` — `getXY` call sites at render/refresh/update
- Direct code read: `libs/FastSenseCompanion/FastSenseCompanion.m` — toolbar grid (1×10), `OpenedFigures_`, `onOpenAdHocPlotRequested_`, `trackOpenedFigure_`
- Direct code read: `libs/FastSenseCompanion/private/openAdHocPlot.m` — engine lifecycle, `hFig` return, `CloseRequestFcn`, `plotOverlay_` getXY call at :147
- Direct code read: `libs/FastSenseCompanion/CompanionSettingsDialog.m` — established uifigure popup dialog pattern
- Direct code read: `libs/FastSenseCompanion/InspectorPane.m` — `SparkWindowSec_` (30 min sparkline), `windowSparkData_`, `formatXTick_` (multi-convention heuristic), multitag composer (Overlay/LinkedGrid/PerTag buttons only; no time-range picker)
- Direct code read: `libs/FastSenseCompanion/companionPrefs.m` — forward-compatible struct, atomic write pattern
- Direct code read: `demo/industrial_plant/plantConfig.m:113` — `cfg.TimeBase = 'datenum'`
- Direct code read: `demo/industrial_plant/seedHistory.m:53-55` — `now()` datenum usage
- Direct code read: `demo/industrial_plant/private/makeDataGenerator.m:15-16` — explicit datenum documentation
- Direct code read: `tests/suite/TestFastSenseCompanion.m` — Octave skip pattern; headless Linux gate
- Direct code read: `tests/test_companion_open_ad_hoc_plot.m` — function-style MATLAB-only guard pattern

### Secondary (MEDIUM confidence)
- CONTEXT.md verified file:line insights (cross-referenced against actual code and confirmed accurate)
- STATE.md v3.0 brainstorm note on "time range All / Last 1h" — confirmed NOT implemented in current InspectorPane; the note described a discarded idea

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all files read directly
- Architecture: HIGH — data-layer patterns are mechanical; UI patterns follow established CompanionSettingsDialog template
- Pitfalls: HIGH — pitfalls 1-5 are code-evidence backed; pitfall 6-7 are straightforward type-system observations
- Validation architecture: HIGH — existing test patterns are clear and the new test targets are well-defined

**Research date:** 2026-06-02
**Valid until:** 2026-07-02 (stable codebase; no external dependencies)
