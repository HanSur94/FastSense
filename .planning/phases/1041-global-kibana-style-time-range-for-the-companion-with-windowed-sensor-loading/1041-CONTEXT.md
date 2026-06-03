# Phase 1041: Global Kibana-style time range for the Companion with windowed sensor loading - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Mode:** Brainstormed in-session (interactive design dialogue; approved by user)

<domain>
## Phase Boundary

Add a **global, Kibana-style time-range picker** to `FastSenseCompanion` so that opening
any sensor/plot from the companion loads **only the chosen time window** instead of the
full (up to 10-year) history. The motivating problem: a sensor whose data is 10 years old
and reaches to today should not pull all of it into a plot — the user picks a window
(default **Last 7 days**) and only that slice is read.

The win is real only because the window is pushed down to where the data physically lives:
- **Disk-backed sensors** (`FastSenseDataStore`, the "huge data" path) read only the
  overlapping SQLite chunks via `getRange` — genuine load savings on the 10-year case.
- **In-RAM `.mat` sensors** (the "small data" path) slice the already-loaded arrays —
  nothing to save, but identical behavior so the feature is source-agnostic.

**Orchestration approach (chosen): Approach 1 — window-as-parameter.** The window flows as
a parameter into views; the domain model (`Tag`) stays stateless. Rejected: Approach 2
(stateful window on the Tag — collides with live pipelines / monitors / derived parents)
and Approach 3 (`WindowedTag` wrapper — must impersonate every Tag subclass and breaks
`isa(tag,'MonitorTag')` checks).

**In scope (v1):** global picker (relative + absolute + quick presets), source-agnostic
windowed read, disk-backed `getTimeRange` fix, applying the window to companion-opened
ad-hoc plots + single-sensor detail views + companion-opened dashboards, re-query of open
views on range change, relative-window sliding on live ticks.

**Out of this phase:** see Deferred.
</domain>

<decisions>
## Implementation Decisions

### Data layer — source-agnostic windowed read (additive, backward-compatible)
- Add `[X, Y] = getXYRange(obj, tStart, tEnd)` to the **Tag contract**.
- `Tag` base class provides a **concrete default**: call the existing `getXY()` then
  binary-search-slice to `[tStart, tEnd]`. This makes derived/composite/state/monitor tags
  work immediately with zero per-subclass effort.
- `SensorTag` **overrides** `getXYRange`: if disk-backed (`isOnDisk()`), delegate to
  `DataStore.getRange(tStart, tEnd)`; if in-RAM, binary-search-slice `X_/Y_`.
- The existing `getXY()` (no-arg) is **UNTOUCHED** → existing scripts and serialized
  dashboards keep working. A windowed call with empty/`[]` bounds returns the full series
  (delegates to `getXY()`).
- **Disk-backed `getTimeRange()` fix:** `SensorTag.getTimeRange()` today returns `[NaN NaN]`
  for disk-backed sensors because it only reads `X_`. The picker needs the true extent, so
  it must consult the DataStore. Add a cheap `XMin`/`XMax` getter to `FastSenseDataStore`
  (first-chunk min / last-chunk max — chunk X-range metadata already exists).

### Orchestration layer — companion owns one global range
- New handle class **`CompanionTimeRange`**: the single source of truth. Holds the range as
  a **spec** — either `relative {N, unit}` (e.g. Last 7 days → now) or `absolute {t0, t1}` —
  and **resolves** to a concrete `[tStart, tEnd]` at query time (relative resolves against
  "now"). Fires a `RangeChanged` event when edited.
- New UI control **`CompanionTimeBar`**: the Kibana picker, hosted in the **existing
  companion toolbar** (the `'1x'` spacer column in `hToolbarGrid`). A range button shows the
  current range label ("Last 7 days"); clicking opens a popup with three modes:
  - **Quick presets:** Last 24h / 7d / 30d / 90d / 1y / All.
  - **Relative builder:** Last [N] [days/weeks/months/years] → now.
  - **Absolute:** `uidatepicker` start + end.
- uifigure-native controls only (`uidropdown`, `uidatepicker`, `uieditfield`, `uibutton`) —
  consistent with the companion being uifigure-based (MATLAB-only) already. Do NOT model it
  on the classical-axes `TimeRangeSelector` (that is a drag-scrubber on classical axes).

### View layer — small, localized changes
- `DashboardEngine.setTimeWindow(t0, t1)` storing a `TimeWindow_`; on set, re-resolve via the
  **existing** `rerenderWidgets` / `updateGlobalTimeRange` machinery (engine already manages a
  global time range for its scrubber — we feed a window *in*). `TimeWindow_` defaults to empty
  (= full range) so non-companion engine use is unaffected.
- `FastSenseWidget`: switch the **three** data-pull call sites — `render` (~:283),
  `refresh` (~:337), `update` (~:367) — from `getXY()` to `getXYRange(t0, t1)` using the
  engine's current window.
- `SensorDetailPlot`: add a `'TimeWindow'` NV-option (parsed via `parseOpts`); main axes loads
  windowed data via `getXYRange`.
- `openAdHocPlot` overlay path (`plotOverlay_`, ~:147) and `RawAxesWidget` closure: read the
  window so overlaid lines honor it too.

### Data flow & re-query
- **On open** (Inspector "Plot" / "Open Detail", Event-Viewer table double-click, and
  dashboards opened from the companion list): companion resolves the current range → passes
  `[t0, t1]` in → the view loads only that slice.
- **On `RangeChanged`:** companion iterates tracked `OpenedFigures_` (+ managed `Engines_`)
  → `setTimeWindow` on each → re-resolve. Widening a disk-backed window re-queries `getRange`
  (loads more only on demand).
- **Live tick:** a **relative** range slides as "now" advances (tail data streams in — dovetails
  with the `LiveViewMode='preserve'` already set on companion ad-hoc plots); an **absolute**
  range stays fixed.
- **Mixed extents:** a global range need not intersect every tag (e.g. a 2018 `.mat` sensor
  under a Last-7-days window). `getXYRange` returns empty → the widget shows a
  "no data in selected range" empty-state. The picker's scrub/extent bounds are the **union**
  of known tag extents.

### Default range
- **Last 7 days**, configurable via `companionPrefs`.

### Claude's Discretion
- Exact `CompanionTimeBar` layout, popup styling, preset list rendering, label formatting.
- Internal representation of the relative/absolute spec and the resolve math.
- Whether `CompanionTimeRange` is a standalone handle class or folded into the companion
  (recommend standalone for testability).
- How the window is threaded engine→widget (engine-stored `TimeWindow_` read by widget on
  refresh, vs passed per-refresh) — pick the cleaner seam.

### OPEN — confirm during planning
- **X time-base convention.** The date picker assumes `X` is a real timestamp. Confirm the
  unit (datenum days vs posix seconds vs `datetime`) used by the disk-backed live sensors and
  map wall-clock dates → `X` accordingly. Tags with **non-time X** (e.g. `SensorTag.load`'s
  `1:numel` index fallback) cannot honor a date window — decide fallback (ignore window / load
  full / treat as empty). Recommendation: define one numeric convention; index-X tags fall back
  to full series.
- **Relative anchor = wall-clock "now" vs latest-available-sample.** Kibana uses wall-clock now
  (matches the live-to-today primary case). For purely historical data, "Last 7 days" vs
  wall-clock is empty (handled by the empty-state). Confirm; recommend wall-clock now for v1.
- **Managed-dashboard interaction.** Companion-opened dashboards may already have their own
  `TimeRangeSelector` scrubber. Safe default: the global window sets the **load** window; the
  dashboard's scrubber operates within it. Confirm whether v1 re-queries managed dashboards
  live on `RangeChanged` or only sets their initial window.
- **Inspector multitag composer** already exposes a primitive "time range All / Last 1h" choice
  (see STATE.md v3.0 brainstorm note). Decide whether the global bar supersedes or feeds it.
</decisions>

<code_context>
## Existing Code Insights (verified in-session)

### Reusable / target assets
- `libs/SensorThreshold/Tag.m` — abstract base; `getXY(obj)` (:120) and `getTimeRange(obj)`
  (:130) are the contract methods. New `getXYRange` default lands here.
- `libs/SensorThreshold/SensorTag.m` — `getXY()` returns `X_/Y_` (:115); `getTimeRange()`
  returns `[NaN NaN]` when `X_` empty (:134, the disk-backed gap); disk path
  `toDisk()/toMemory()/isOnDisk()/DataStore_` (:226–248); `load()` index fallback
  `X_ = 1:numel(entry)` (:222, the non-time-X case).
- `libs/FastSense/FastSenseDataStore.m` — `getRange(xMin, xMax)` chunked range read with
  one-point padding (:92); `readSlice`, `findIndex`, `NumPoints`, chunk X-range metadata
  (basis for the new `XMin/XMax` getter); WAL for live use.
- `libs/Dashboard/FastSenseWidget.m` — pulls data via `obj.Tag.getXY()` at render (:283),
  refresh (:337), update (:367); already caches `CachedXMin/CachedXMax` (:75–77) for O(1)
  `getTimeRange`.
- `libs/Dashboard/DashboardEngine.m` — `updateGlobalTimeRange` (:1807), `updateLiveTimeRange`
  (:1844), `rerenderWidgets` (:1730), `render` (:449), `startLive` (:565), `LiveInterval` (:25);
  existing `TimeRangeSelector` integration to extend, not duplicate.
- `libs/FastSense/SensorDetailPlot.m` — ctor `(tag, varargin)` via `parseOpts` (:90); calls
  `tag.getXY()` for validation + render; `setZoomRange/getZoomRange`; NavigatorOverlay.
- `libs/FastSenseCompanion/private/openAdHocPlot.m` — `plotOverlay_` calls `tags{k}.getXY()`
  (:147); `findEventStoreFor_` uses `isa(tt,'MonitorTag')` (:165, the check Approach 3 would
  break); LinkedGrid builds one `FastSenseWidget` per tag.
- `libs/FastSenseCompanion/FastSenseCompanion.m` — toolbar `hToolbarGrid` with a `'1x'` spacer
  at col 9 / gear at col 10 (:327); root `uigridlayout [3 3]`, ColumnWidth `{220,'1x',360}`,
  RowHeight `{32,'1x',360}` (:301–303); `OpenedFigures_` tracked opened-figure handles
  (:115–117); managed `Engines_`; `LiveTimer_`/`onLiveTick_`/`LivePeriod_`;
  `onOpenAdHocPlotRequested_` (:2150), `onOpenDashboardRequested_`.
- `libs/FastSenseCompanion/companionPrefs.m` — where the default-range pref lives.
- `libs/Dashboard/TimeRangeSelector.m` — a classical-axes drag-scrubber with
  `OnRangeChanged`/`setDataRange`/`setSelection`/`setEnvelope`; **reference for semantics only**,
  not the picker UI (the new bar is uifigure-native).

### Established patterns to follow
- Companion event-driven panes: fire an event (`RangeChanged`) on the orchestrator; listeners
  re-query. Mirror `OpenAdHocPlotRequested` / `DetachRequested` wiring.
- Every companion callback wrapped try/catch → non-blocking `uialert` (never crash the window).
- `parseOpts` NV-option pattern for new view options (`'TimeWindow'`).
- Tag-API uses `isa(x,'Tag')` (abstract base), never `isa` on a concrete subclass name where a
  base will do (Pitfall 1).

### Integration points
- `Tag.getXYRange` (base default) + `SensorTag.getXYRange` override + `SensorTag.getTimeRange`
  disk-fix + `FastSenseDataStore.XMin/XMax`.
- `DashboardEngine.setTimeWindow` ←→ existing rerender/global-range machinery.
- `FastSenseCompanion`: instantiate `CompanionTimeRange` + `CompanionTimeBar` in the toolbar;
  on `RangeChanged` push window to `OpenedFigures_` + `Engines_`; pass window at every open site.

### Environment / compatibility notes
- `getXYRange` and `getTimeRange` are pure MATLAB (binary-search + slice / DataStore) → work in
  **Octave too** (data-layer tests should run in both runtimes).
- The companion UI (`CompanionTimeBar`) is **MATLAB-only** (uifigure) — consistent with existing
  companion tests being env-skipped in headless Octave CI (see "known env test failures" pattern).
- `uidatepicker` (R2020a+) is date-only (no time-of-day) — fine for v1 day-granularity;
  sub-day precision is deferred.
- uifigure pitfall: `drawnow` before constructing any classical axes inside a uifigure — not
  expected here since the bar uses uifigure controls, but relevant if any preview axes is added.
</code_context>

<specifics>
## Specific Ideas (approved UX defaults)

- Default range **Last 7 days** (relative), configurable via `companionPrefs`.
- Quick presets: **Last 24h / 7d / 30d / 90d / 1y / All**.
- Relative builder reads "Last [N] [days/weeks/months/years]" → now (the from-date→now model
  the user picked).
- Absolute mode uses `uidatepicker` for start and end.
- The toolbar button always shows the **current range label** (e.g. "Last 7 days" / an absolute
  "2024-01-01 → 2024-03-01").
- Relative ranges **slide** on live ticks; absolute ranges are **fixed**.
- Mixed-extent / no-intersection → per-widget **"No data in selected range"** empty-state.
- Picker extent/scrub bounds = **union of known tag time ranges**.
</specifics>

<deferred>
## Deferred Ideas (out of scope for v1 — YAGNI)

- **Auto-refresh interval control** (Kibana "Refresh every"). The companion already has a Live
  toggle; a separate refresh-rate control is a follow-up.
- **Sub-day time-of-day precision** in the picker UI (`uidatepicker` is date-only). Day
  granularity for v1.
- **Scrub-beyond-window incremental loading** in `SensorDetailPlot`'s navigator (panning past
  the loaded window triggering a fresh `getRange`). v1 loads the window; navigator spans it.
- **Per-view pin / unpin** from the global range (a view opting out of the companion range).
- **Recently-used ranges** list.
- **`datetime`/timezone-aware** handling beyond a single numeric time-base convention.
</deferred>
