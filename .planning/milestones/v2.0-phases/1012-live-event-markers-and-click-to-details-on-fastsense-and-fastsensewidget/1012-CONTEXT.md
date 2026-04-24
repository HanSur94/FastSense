# Phase 1012: Live event markers and click-to-details on FastSense and FastSenseWidget — Context

**Gathered:** 2026-04-24
**Status:** Ready for planning
**Mode:** Smart discuss (4 areas, 16 questions, all recommendations accepted)

<domain>
## Phase Boundary

Extend the Phase-1010 Event-↔-Tag overlay with three orthogonal capabilities, without touching Phase 1010's already-shipped deliverables:

1. **Open-event visibility** — events become visible as markers the moment they are detected, not only once closed.
2. **Click-to-details** — a marker click opens a floating panel showing every field of the clicked event.
3. **Dashboard-widget-level wiring** — `FastSenseWidget` exposes `ShowEventMarkers` + `EventStore` so dashboard users get the overlay without dropping to the bare `FastSense` core class.

Single source of truth is `EventStore` (D1 — locked during brainstorm). Open events are persisted on rising edge and updated in-place on close; the widget only ever reads from `EventStore`.

**Explicitly out of scope** (Pitfall 5 / Pitfall 12):
- Redoing `Event.TagKeys` / `EventBinding` / `EventStore.eventsForTag` / `FastSense.renderEventLayer_` / Severity→Color theme mapping — all shipped in Phase 1010.
- Severity/Category marker filtering (deferred — see deferred-items.md).
- A toolbar button or right-click menu for the toggle (deferred — API-only for now, mirrors the Phase-9 `ShowThresholdLabels` delivery shape).

</domain>

<decisions>
## Implementation Decisions

### Open-event schema
- `Event` gains a new `IsOpen` logical property (default `false`) — backward-compatible scalar flag, grep-friendly, no enum proliferation.
- Close is signaled by `EventStore.closeEvent(eventId, endTime, finalStats)` which updates the same Event record in-place — keeps `Event.Id` stable, satisfies D1 SSOT.
- `EndTime` on an open event is `NaN` — Octave-safe, consumers guard via `isnan()`.
- Peak/Min/Max/Mean/RMS/Std are **running/partial** values updated on each live-tick append — users see the peak climb during an open event.

### Marker rendering
- Y-position: `Y = signal value at StartTime`, computed via **`tag.valueAt(startT)`** — this is the method already used by Phase 1010's `renderEventLayer_` (ZOH via `binary_search`); keep consistent to avoid behavioral drift between open and closed markers.
- Open = hollow circle (`MarkerFaceColor='none'`, `MarkerEdgeColor=severityColor`); closed = filled — universally-read open/closed visual grammar, no extra color needed.
- Z-order: marker layer is `uistack(...,'top')` after `renderLines()` — markers always visible, zero impact on the line-rendering hot path (Pitfall 10).
- Marker size: fixed `8 pt` (new theme constant `EventMarkerSize`), not axes-relative — stable across zoom/resize.

### Click-to-details surface
- Surface type: floating `uipanel` inside the same figure, anchored near the clicked marker; closes on outside-click, ESC, or X-button. **Implementation note (after research):** Phase 3's `openInfoPopup` uses a separate `figure`, not a `uipanel` — so the close mechanics cannot be lifted verbatim. Plan-phase will build a new `uipanel`-based popup that mimics the Phase-3 UX: ESC via parent-figure `WindowKeyPressFcn`, click-outside via parent `WindowButtonDownFcn` with hit-test against the panel's Position, X-button via a top-right `uicontrol` with a `Callback` that deletes the panel handle.
- Fields shown (full dump, single vertical block): `StartTime`, `EndTime` (or `"Open"` when `IsOpen==true`), duration (or `"Open"`), `PeakValue`, `Min`, `Max`, `Mean`, `RMS`, `Std`, `Severity`, `Category`, `TagKeys`, `ThresholdLabel`, `Notes`.
- Three redundant dismiss paths: `ESC` key + click-outside + `X` button.
- Click detection: per-marker `ButtonDownFcn` with `UserData.eventId` — simple & fast for typical `N < 100` events; no hit-test indirection. **Implementation note (after research):** Phase 1010's `renderEventLayer_` currently batches markers by severity (3 `line()` calls). For per-marker click callbacks, plan-phase must switch to one `line()` per event. Pitfall-10 regression guard: zero-event bench of a 12-line FastSense plot must show no measurable regression.

### FastSenseWidget wiring + live refresh
- `FastSenseWidget` gains `ShowEventMarkers` (logical, default `false` for back-compat) and `EventStore` (handle, default empty) — forwarded to the inner `FastSense` during `render()`; mirrors the Phase-9 `ShowThresholdLabels` pattern.
- Toggle exposure: **programmatic / serializer only** in this phase — no toolbar button, no context menu (deferred).
- Live refresh: piggybacks on `DashboardEngine.onLiveTick` → widget's `refresh()` calls `EventStore.eventsForTag(tagKey)` and diffs the result against the last-rendered marker set, redrawing only added/removed/closed markers.
- Filtering: on/off only in this phase; severity/category filters deferred to a future phase.

### Claude's Discretion
- Exact `uipanel` pixel layout (font sizes, padding) — follow existing `DashboardLayout` info-tooltip styling.
- Running-stats computation details on the pipeline side (how `MonitorTag` accumulates `PeakValue` etc. without re-scanning history each tick) — performance-tuned during plan/execute.
- Whether `closeEvent` is a method on `EventStore` or an update pathway inside the Event handle — plan-phase decides after re-reading current `EventStore` code.

</decisions>

<code_context>
## Existing Code Insights

### Reusable assets
- `FastSense.renderEventLayer_` (from Phase 1010) — already walks `EventStore.eventsForTag(tagKey)` and creates round markers colored by `Event.Severity` via `DashboardTheme`. Extend rather than replace. Current call happens after `renderLines()`; single early-out if no events (Pitfall 10 guard).
- `DashboardLayout` info-tooltip mechanism (from Phase 3) — floating `uipanel`, ESC + click-outside + X-button close, `hFigure` tracked on `DashboardEngine`. Model the click-details surface on this.
- `FastSenseWidget.ShowThresholdLabels` (from Phase 9) — handle-class property, default `false`, forwarded to inner `FastSense` at `render()` and `refresh()` — direct template for `ShowEventMarkers`.
- `DashboardEngine.onLiveTick` (from Phase 1 and Phase 1000) — batch widget refresh with cached time ranges. Event-marker diff logic plugs in here.
- `EventStore.eventsForTag(key)` (from Phase 1010) — read path already exists.
- `MonitorTag.appendData` (from Phase 1007) — incremental live pipeline already in place. Rising-edge detection and running-stats accumulation hook here.

### Established patterns
- Handle classes inherit from `handle`; properties declared `public` for user-facing, `SetAccess=private` for internal.
- Error IDs: `ClassName:camelCaseProblem` — e.g., `Event:invalidStatus`, `EventStore:unknownEventId`.
- Tests: MATLAB suite `tests/suite/Test*.m` + Octave-style `tests/test_*.m` function-based parallel.
- Backward-compatibility discipline: new properties default to values that reproduce pre-phase behavior (Phase 8/9 precedent with `YLimits=[]`, `ShowThresholdLabels=false`).
- Render bench gate (Pitfall 10 precedent from Phase 1010): 12-line FastSense plot with zero attached events must show no measurable regression vs. pre-phase baseline.
- JSON serialization: omit properties from `toStruct` when empty/default to keep files clean and backward-compatible.

### Integration points
- `libs/EventDetection/Event.m` — new `IsOpen` property + backward-compatible `fromStruct` (missing `IsOpen` → default `false`).
- `libs/EventDetection/EventStore.m` — new `closeEvent(id, endTime, finalStats)` method. **Storage is a `.mat`-file-backed handle array of `Event` objects, NOT SQLite** (clarification after research). `IsOpen` is added to `Event` as a default-`false` property; MATLAB/Octave materialize missing fields on `.mat` load via the class definition, so no migration script is required (precedent: Phase 1010 added 4 fields the same way).
- `libs/SensorThreshold/MonitorTag.m` (Phase 1006/1007) — rising-edge `appendData` path emits an open Event and caches its Id; falling-edge calls `closeEvent`; running-stats fields accumulate per tick.
- `libs/FastSense/FastSense.m::renderEventLayer_` — extend with open-event styling (hollow vs filled) + per-marker `ButtonDownFcn` wiring + click-details panel; add `EventMarkerSize` theme lookup.
- `libs/Dashboard/FastSenseWidget.m` — new `ShowEventMarkers` + `EventStore` properties; `render()` and `refresh()` forward them; `refresh()` performs marker diff against a cached `LastEventIds_` set.
- `libs/Dashboard/DashboardTheme.m` — new `EventMarkerSize = 8` constant.
- `libs/Dashboard/DashboardLayout.m` — floating panel helpers may be reusable; confirm during plan-phase.
- `libs/Dashboard/DashboardSerializer.m` — `FastSenseWidget` `toStruct/fromStruct` must round-trip `ShowEventMarkers` (omit when `false`).

</code_context>

<specifics>
## Specific Ideas

- The brainstorm explicitly rejected push-callback and "widget merges EventStore + MonitorTag" architectures; EventStore stays the single source of truth (D1).
- User-facing wording in the details panel: use "Open" as both the `EndTime` and `Duration` label when `IsOpen==true`.
- Marker click must not trigger axes `zoom`/`pan` interactions (a live FastSense plot may have toolbar zoom active); guard by setting `HitTest='on'` on markers and stopping propagation, or by temporarily suspending pan/zoom while the details panel is open — confirm during plan-phase.

</specifics>

<deferred>
## Deferred Ideas

- **Severity/Category filter chips on the toggle** — keep the toggle boolean for now; add a filter UI once user demand is observed.
- **Toolbar button and/or right-click context menu** for the `ShowEventMarkers` toggle — API-only delivery in this phase, UI surfaces later.
- **Pulsating/animated open-event markers** — considered under Area 2 Q2 but rejected for perf + distraction.
- **Hit-test via axes-level `ButtonDownFcn` + `pdist2`** — only needed if `N >> 100` markers; revisit if users report perf issues.
- **Automatic `EventStore` discovery** from a widget's bound Tag parent — considered under Area 4 Q1 but rejected to keep the wiring explicit and discoverable.

</deferred>
