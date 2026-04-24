# Phase 1012: Live event markers and click-to-details on FastSense and FastSenseWidget — Research

**Researched:** 2026-04-24
**Domain:** MATLAB event-overlay rendering, live-tick marker diffing, floating details panel (MATLAB+Octave GUI), open-event schema migration on a `.mat`-backed `EventStore`
**Confidence:** HIGH (all findings grounded in source files on disk)

## Summary

Phase 1012 is a **pure extension** of Phase 1010's `renderEventLayer_` overlay: it adds three orthogonal capabilities — open-event visibility, marker click-to-details, and widget-level (`FastSenseWidget`) wiring — without rewriting a single line of Phase 1010 code. Every extension point is already present in the code base as of Phase 1011 cleanup:

- `EventStore` is a `.mat`-backed handle class (NOT SQLite — common misconception). Schema migration is a **struct-field** concern, not a DDL concern. The migration strategy is *default-on-read*: an old `.mat` file with no `IsOpen` field simply reads `false`.
- `MonitorTag.fireEventsInTail_` (`libs/SensorThreshold/MonitorTag.m:580-628`) already has the exact hook for open-event emission — a branch currently `continue`s on runs open at tail end. That `continue` becomes "emit with `IsOpen=true` and cache the event Id".
- `FastSense.renderEventLayer_` (`libs/FastSense/FastSense.m:2193-2247`) already batches markers per severity and already computes `Y = tag.valueAt(ev.StartTime)`. The Phase 1012 changes are additive: open-vs-closed marker styling, per-marker `ButtonDownFcn`, and a single `uistack(...,'top')` at the end.
- `DashboardLayout.openInfoPopup/closeInfoPopup` (`libs/Dashboard/DashboardLayout.m:405-518`) is a **near-exact template** for the click-details surface — ESC + click-outside + X-button dismiss are all already solved in that file. One caveat: DashboardLayout's popup uses a standalone **`figure`** (not a `uipanel` in the same figure). CONTEXT.md locks the decision as `uipanel` inside the same figure, so the template must be *adapted* (swap `figure(...)` for `uipanel(...)` + a synthetic close button) — not blindly copied.
- `FastSenseWidget.ShowThresholdLabels` (`libs/Dashboard/FastSenseWidget.m:21,72,255,327,417`) is the direct precedent for `ShowEventMarkers` — 5 touch-points, one property, one forwarding statement each in `render()` and `rebuildForTag_()`, one line each in `toStruct`/`fromStruct`.

**Primary recommendation:** Ship this phase as **3 plans** following the Phase 1010 structure:
1. **Plan 01 — Schema + live emission**: `Event.IsOpen`, `EventStore.closeEvent`, running-stats accumulation in `MonitorTag`, backward-compatible `.mat` deserialization.
2. **Plan 02 — Render + click surface**: extend `FastSense.renderEventLayer_` for open/closed styling + per-marker `ButtonDownFcn`; ship `FastSense.openEventDetails_`/`closeEventDetails_` modeled on `DashboardLayout.openInfoPopup/closeInfoPopup`.
3. **Plan 03 — Widget wiring + live diff**: `FastSenseWidget.ShowEventMarkers` + `EventStore` + `LastEventIds_` diff in `refresh()`; serialization round-trip; Pitfall 10 0-event bench.

## Project Constraints (from CLAUDE.md)

These directives constrain every plan in this phase and override any research recommendation that conflicts:

- **Pure MATLAB + Octave 7+ only** — no external toolboxes, no npm, no pip. All new code MUST compile/run on both runtimes. Tests MUST ship in both styles (suite `Test*.m` + flat `test_*.m`).
- **Backward compatibility** — existing dashboard scripts and serialized dashboards must continue to work. `ShowEventMarkers` default `false`, `EventStore` default `[]`, `IsOpen` default `false`, `toStruct` omits properties when at default.
- **Widget contract** — new features work through the existing `DashboardWidget` base class interface; no new abstract methods.
- **Performance** — detached live-mirrored widgets must not degrade dashboard refresh rate. Applied to this phase: a 12-line FastSense with **zero** events must show no measurable regression vs. Phase 1010 baseline (Pitfall 10 continuation).
- **Handle-class conventions** — `classdef < handle`; public user-facing props; `SetAccess=private` for internal; trailing-underscore private cache fields (`cache_`, `Tags_`, `EventMarkerHandles_`).
- **Error ID namespacing** — `ClassName:camelCaseProblem` (e.g., `EventStore:unknownEventId`, `FastSense:invalidEventId`, `Event:closedOpenEvent`).
- **Octave compat gotchas** — bare `catch` (never `catch e`), no `arguments` blocks, `containers.Map('KeyType','char','ValueType','any')` for maps, `exist('OCTAVE_VERSION','builtin')` for runtime branch, MATLAB `struct()` collapses cellstr scalars so `{obj.Labels}` double-wrap is the accepted defense.
- **GSD workflow enforcement** — all code edits go through GSD plan-phase; this RESEARCH.md is the planner input.
- **Test layout** — `tests/suite/Test*.m` (MATLAB xUnit-style) + `tests/test_*.m` (Octave flat-style function-based). Both styles MUST be shipped for the core behaviors (schema, rendering, widget wiring).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Phase boundary (domain):**
- Extend Phase-1010 overlay with three orthogonal capabilities; EventStore is SSOT (D1 — locked during brainstorm).
- Do NOT redo `Event.TagKeys` / `EventBinding` / `EventStore.eventsForTag` / `FastSense.renderEventLayer_` / Severity→Color mapping — all shipped in Phase 1010.

**Open-event schema:**
- `Event` gains new `IsOpen` logical property (default `false`) — backward-compatible scalar flag.
- Close is signaled by `EventStore.closeEvent(eventId, endTime, finalStats)` — in-place update; keeps `Event.Id` stable; satisfies D1 SSOT.
- `EndTime` on an open event is `NaN` — Octave-safe, consumers guard via `isnan()`.
- Peak/Min/Max/Mean/RMS/Std are **running/partial** values updated on each live-tick append.

**Marker rendering:**
- Y-position: `Y = signal value at StartTime`, computed via `interp1(x, y, startT, 'nearest', 'extrap')` — anchors marker to signal line. (Note: current Phase 1010 code uses `tag.valueAt(ev.StartTime)` which is ZOH. Plan-phase should lock which applies — see Q5 below.)
- Open = hollow circle (`MarkerFaceColor='none'`, `MarkerEdgeColor=severityColor`); closed = filled.
- Z-order: marker layer is `uistack(...,'top')` after `renderLines()`.
- Marker size: fixed `8 pt` (new theme constant `EventMarkerSize`).

**Click-to-details surface:**
- Surface type: floating `uipanel` inside same figure, anchored near clicked marker; ESC + click-outside + X dismiss.
- Fields shown (full dump, single vertical block): `StartTime`, `EndTime` (or `"Open"` when `IsOpen==true`), duration (or `"Open"`), `PeakValue`, `Min`, `Max`, `Mean`, `RMS`, `Std`, `Severity`, `Category`, `TagKeys`, `ThresholdLabel`, `Notes`.
- Three redundant dismiss paths: `ESC` + click-outside + `X` button.
- Click detection: per-marker `ButtonDownFcn` with `UserData.eventId`.

**FastSenseWidget wiring + live refresh:**
- `FastSenseWidget` gains `ShowEventMarkers` (default `false`) and `EventStore` (default `[]`) — forwarded to inner `FastSense` during `render()`; mirrors Phase-9 `ShowThresholdLabels`.
- Toggle exposure: programmatic / serializer only (no toolbar button, no context menu).
- Live refresh: piggybacks `DashboardEngine.onLiveTick` → widget `refresh()` calls `EventStore.eventsForTag(tagKey)` and diffs against last-rendered marker set.
- Filtering: on/off only.

### Claude's Discretion
- Exact `uipanel` pixel layout (font sizes, padding) — follow existing `DashboardLayout` info-tooltip styling.
- Running-stats computation details on pipeline side (how MonitorTag accumulates `PeakValue` etc. without re-scanning history each tick) — performance-tuned during plan/execute.
- Whether `closeEvent` is a method on `EventStore` or an update pathway inside the Event handle — plan-phase decides after re-reading current `EventStore` code.

### Deferred Ideas (OUT OF SCOPE)
- Severity/Category filter chips on the toggle.
- Toolbar button and/or right-click context menu for the `ShowEventMarkers` toggle.
- Pulsating/animated open-event markers.
- Hit-test via axes-level `ButtonDownFcn` + `pdist2` (only needed if N >> 100).
- Automatic `EventStore` discovery from a widget's bound Tag parent.
</user_constraints>

## Phase Requirements

None. CONTEXT.md explicitly states no REQ-IDs are mapped to this phase. It is a refinement of Phase 1010's shipped `EVENT-01..EVENT-07` set. Plans will **not** carry a `requirements:` frontmatter, and `/gsd:verify-work` will not check REQ coverage. The success criteria for each plan come directly from the CONTEXT.md decision list above.

## Standard Stack

This phase is built entirely on the existing in-project stack — no new libraries.

### Core (reused)

| Component | Source File | Purpose | Why Reused |
|-----------|-------------|---------|------------|
| `Event` handle class | `libs/EventDetection/Event.m` | Event record; already holds `TagKeys`, `Severity`, `Category`, `Id` | Phase 1010 added all event-level fields; add `IsOpen` only. |
| `EventStore` handle class | `libs/EventDetection/EventStore.m` | `.mat`-file-backed event repository | SSOT per D1. Extend with `closeEvent`; no file-format change required (struct fields). |
| `EventBinding` | `libs/EventDetection/EventBinding.m` | `(eventId, tagKey)` many-to-many registry | Unchanged — open events already get Ids via `EventStore.append`. |
| `MonitorTag` | `libs/SensorThreshold/MonitorTag.m` | Rising/falling edge detection; running event emission | Already has `fireEventsInTail_`, `fireEventsOnRisingEdges_`, `appendData` — the exact hooks we extend. |
| `FastSense.renderEventLayer_` | `libs/FastSense/FastSense.m:2193` | Severity-batched round-marker overlay | Already walks `Tags_`, reads `eventsForTag`, severity-buckets. |
| `DashboardLayout.openInfoPopup` | `libs/Dashboard/DashboardLayout.m:405` | ESC + click-outside + X-button dismiss pattern | Direct template for the click-details surface, with one adaptation (figure → uipanel). |
| `FastSenseWidget.ShowThresholdLabels` | `libs/Dashboard/FastSenseWidget.m:21,72,255,327,417` | Boolean feature gate + forward to inner FastSense + JSON round-trip | Direct template for `ShowEventMarkers`. |

### Supporting (existing conventions)

| Utility | Source | Use Case |
|---------|--------|----------|
| `binary_search` (bundled MEX + `.m` fallback) | `libs/FastSense/private/` | `SensorTag.valueAt` uses it — so `tag.valueAt(ev.StartTime)` is already fast. |
| `containers.Map('KeyType','char','ValueType','any')` | MATLAB/Octave core | Not used in this phase (no Ids→handles mapping needed on client side), but same pattern underpins EventBinding we depend on. |
| `parseOpts` | `libs/EventDetection/private/parseOpts.m` | Existing NV-pair helper used by `EventStore` constructor; reusable for `closeEvent` NV-pair finalStats form (optional). |

### Alternatives Considered (and rejected in CONTEXT.md)

| Instead of | Could Use | Why Rejected |
|------------|-----------|--------------|
| `IsOpen` logical + `NaN` EndTime | State enum `'open'`/`'closed'` | Rejected (see CONTEXT): boolean is grep-friendly, no enum proliferation, backward-compat scalar. |
| `EventStore.closeEvent` in-place update | Append a "closed" Event shadowing the "open" one | Rejected: violates D1 SSOT; `Event.Id` stability requirement; makes `EventBinding` reverse lookup messy. |
| `uipanel` inside same figure | Standalone popup `figure` (DashboardLayout style) | CONTEXT locks `uipanel` — anchored near clicked marker is the UX goal. Standalone figure loses spatial context. |
| Per-marker `ButtonDownFcn` | Axes-level `ButtonDownFcn` + `pdist2` hit-test | CONTEXT explicitly defers the hit-test approach until N >> 100 markers; per-marker is simple and fast at typical N < 100. |

**Installation:** No `npm install` — pure MATLAB. Existing `install.m` compiles MEX; nothing new compiles this phase.

## Architecture Patterns

### Recommended Task / Plan Structure

```
Plan 01 — Schema + live emission            (Event.m, EventStore.m, MonitorTag.m)
├── Event.IsOpen property (public, default false)
├── EventStore.closeEvent(id, endTime, finalStats)
├── EventStore.mat backward-compat deserialization (field-defaulting)
├── MonitorTag rising-edge path emits open event + caches id
├── MonitorTag falling-edge path calls closeEvent with finalStats
├── Running-stats accumulator (cache_.openStats_ struct) extended on appendData
└── Tests: TestEventOpenClose.m + test_event_open_close.m (dual style)

Plan 02 — Render + click surface            (FastSense.m, DashboardTheme.m)
├── DashboardTheme.EventMarkerSize = 8 (new constant)
├── FastSense.renderEventLayer_ extended:
│   ├── Open events: hollow circle (MarkerFaceColor='none')
│   ├── Closed events: filled (existing)
│   ├── Per-marker ButtonDownFcn with UserData.eventId (individual line() per event, NOT batched per severity — see Pattern 2 below)
│   └── uistack(handles, 'top') once at end
├── FastSense.openEventDetails_(evId) / closeEventDetails_()
│   ├── Modeled on DashboardLayout.openInfoPopup/closeInfoPopup
│   ├── Uipanel (not figure) anchored near click point
│   ├── ESC + WindowButtonDownFcn (click-outside) + X-button dismiss
│   └── Full-field dump per CONTEXT field list
└── Tests: TestFastSenseEventClick.m (MATLAB+JVM) + test_fastsense_event_click.m (Octave only when display is real)

Plan 03 — Widget wiring + live diff         (FastSenseWidget.m, DashboardSerializer.m)
├── FastSenseWidget.ShowEventMarkers property (default false)
├── FastSenseWidget.EventStore property (default [])
├── render() forwards both to inner FastSenseObj
├── rebuildForTag_() forwards both
├── refresh() marker-diff: LastEventIds_ cell, diff open→closed transitions, full redraw trigger
├── toStruct omits when defaults (ShowEventMarkers=false or EventStore=[])
├── fromStruct re-hydrates ShowEventMarkers; EventStore NOT round-tripped (handle, not serializable)
├── Pitfall 10 gate: bench_fastsense_zero_events.m — no regression vs. Phase 1010 baseline
└── Tests: TestFastSenseWidgetEventMarkers.m + test_fastsense_widget_event_markers.m
```

### Pattern 1: Backward-compatible `.mat` schema migration

The project's precedent for optional struct fields is **field-default-on-read** — no versioning, no migration scripts. Specifically for `Event`:

```matlab
% From Event.m (Phase 1010) — public writable, default = [] or '':
properties
    TagKeys   = {}   % cell of char (EVENT-01)
    Severity  = 1    % numeric (EVENT-04)
    Category  = ''   % char (EVENT-05)
    Id        = ''   % char (EVENT-02)
end
```

A legacy `.mat` file saved before Phase 1010 is loaded, MATLAB materializes the missing fields with their class-definition defaults. Phase 1010 added four fields this way with zero migration code. Phase 1012 adds `IsOpen = false` the same way:

```matlab
% Event.m addition (Phase 1012):
properties
    IsOpen = false   % logical: true when StartTime is set but EndTime is NaN
end
```

**Verification source:** `EventStore.loadFile` (`libs/EventDetection/EventStore.m:148-191`) uses `builtin('load', filePath)` which materializes an array of Event handles. MATLAB's handle-class loader fills missing properties with declared defaults. Octave behaves identically for `-mat7` format with `builtin('save'/'load')`.

**`EventStore.save()` details (lines 107-140):** uses `-v7.3` in MATLAB, default format in Octave (`exist('OCTAVE_VERSION', 'builtin')` branch at line 134). This is a **single-file `.mat`**, not SQLite — the CONTEXT wording "on-disk schema: nullable end_time, new is_open column" is inaccurate; there is no column. It's a struct field on a handle array.

### Pattern 2: Per-marker line() handles vs. severity-batched line()

Current `renderEventLayer_` (`FastSense.m:2236-2246`) draws **one `line()` per severity level** with a concatenated `[x, y]` array:

```matlab
% Current (Phase 1010) — batched by severity:
for s = 1:3
    if ~isempty(xBySev{s})
        c = obj.severityToColor_(s);
        h = line(xBySev{s}, yBySev{s}, ...
            'Parent', obj.hAxes, ...
            'Marker', 'o', 'MarkerSize', 8, ...
            'MarkerFaceColor', c, 'MarkerEdgeColor', c, ...
            'LineStyle', 'none', 'HandleVisibility', 'off');
        obj.EventMarkerHandles_{end+1} = h;
    end
end
```

**Problem for Phase 1012:** one `line` handle holds N markers; a single `ButtonDownFcn` on the line fires but cannot know *which* marker was clicked without a hit-test. CONTEXT rejects that hit-test approach (Pitfall 12 / deferred).

**Solution:** switch to **one `line()` per event** (still cheap at N < 100) so each handle carries its own `UserData.eventId` and `ButtonDownFcn`:

```matlab
% Phase 1012 — one line per event:
for i = 1:numel(obj.Tags_)
    tag = obj.Tags_{i};
    events = es.getEventsForTag(char(tag.Key));
    for j = 1:numel(events)
        ev = events(j);
        sev = max(1, min(3, ev.Severity));
        yVal = tag.valueAt(ev.StartTime);
        if isnan(yVal), continue; end
        c = obj.severityToColor_(sev);
        if ev.IsOpen
            faceColor = 'none';  % hollow
        else
            faceColor = c;        % filled
        end
        sz = obj.themeField_('EventMarkerSize', 8);
        h = line(ev.StartTime, yVal, ...
            'Parent', obj.hAxes, ...
            'Marker', 'o', 'MarkerSize', sz, ...
            'MarkerFaceColor', faceColor, 'MarkerEdgeColor', c, ...
            'LineStyle', 'none', ...
            'HandleVisibility', 'off', ...
            'HitTest', 'on', ...
            'PickableParts', 'visible', ...
            'ButtonDownFcn', @(src, evt) obj.onEventMarkerClick_(src, evt), ...
            'UserData', struct('eventId', ev.Id, 'tagKey', char(tag.Key)));
        obj.EventMarkerHandles_{end+1} = h;
    end
end
uistack([obj.EventMarkerHandles_{:}], 'top');  % single uistack call at end
```

**Performance:** at CONTEXT's "typical N < 100" events, `N` separate `line` primitives are still O(N) draw calls — but MATLAB/Octave handle that volume trivially. A separate `bench_fastsense_event_markers.m` at 100 / 500 / 1000 events under the Pitfall 10 gate de-risks this.

### Pattern 3: `uipanel`-in-figure click-details surface (adapted from DashboardLayout)

CONTEXT locks `uipanel` inside the same FastSense figure. The DashboardLayout template uses a standalone `figure`, so we adapt:

```matlab
% New private method on FastSense — sketch only; plan-phase locks exact layout:
function openEventDetails_(obj, ev, anchorX, anchorY)
    obj.closeEventDetails_();  % idempotent guard
    fig = obj.hFigure;
    if isempty(fig) || ~ishandle(fig), return; end
    % Save prior callbacks (DashboardLayout pattern — lines 416-418)
    obj.PrevWBDFcn_ = get(fig, 'WindowButtonDownFcn');
    obj.PrevKPFcn_  = get(fig, 'KeyPressFcn');
    % Convert data coords to normalized figure coords for anchor
    panelPos = obj.dataToFigureNormalized_(anchorX, anchorY);  % [x y w h]
    pnl = uipanel('Parent', fig, ...
        'Units', 'normalized', 'Position', panelPos, ...
        'BackgroundColor', [0.15 0.15 0.18], ...
        'ForegroundColor', [0.92 0.92 0.94], ...
        'BorderType', 'line');
    % Title row with X button
    uicontrol('Parent', pnl, 'Style', 'text', ...
        'String', sprintf('Event %s', ev.Id), ...
        'Units', 'normalized', 'Position', [0.05 0.88 0.70 0.10], ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'left', ...
        'BackgroundColor', [0.15 0.15 0.18], 'ForegroundColor', [0.92 0.92 0.94]);
    uicontrol('Parent', pnl, 'Style', 'pushbutton', ...
        'String', 'X', ...
        'Units', 'normalized', 'Position', [0.88 0.88 0.10 0.10], ...
        'Callback', @(~,~) obj.closeEventDetails_());
    % Field dump (single vertical block)
    txt = obj.formatEventFields_(ev);   % produces multi-line char
    uicontrol('Parent', pnl, 'Style', 'edit', ...
        'Max', 100, 'Min', 0, ...         % multi-line read-only
        'Enable', 'inactive', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', 'Position', [0.05 0.05 0.90 0.80], ...
        'String', txt, ...
        'FontName', 'Courier', 'FontSize', 10, ...
        'BackgroundColor', [0.15 0.15 0.18], 'ForegroundColor', [0.92 0.92 0.94]);
    obj.hEventDetails_ = pnl;
    % Install figure-level dismiss handlers (DashboardLayout pattern)
    set(fig, 'WindowButtonDownFcn', @(~,~) obj.onFigureClickForEventDetails_());
    set(fig, 'KeyPressFcn',         @(~,evt) obj.onKeyPressForEventDetails_(evt));
end
```

**Key divergences from DashboardLayout:**
1. `uipanel` not `figure`; no `CloseRequestFcn` (panels don't have one — the X button supplies the explicit close path).
2. Anchor position is computed from marker data coordinates — a helper `dataToFigureNormalized_` converts via `get(hAxes, 'Position')` and axes x/y limits. This is the only genuinely new helper; existing code has no precedent.
3. Click-outside dismiss uses the same parent-walk trick (DashboardLayout `onFigureClickForDismiss`, lines 488-511) but with `obj.hEventDetails_` as the sentinel.

### Pattern 4: Live-tick marker diff in `FastSenseWidget.refresh()`

`DashboardEngine.onLiveTick` (lines 926-995) already calls `w.update()` for `FastSenseWidget` (line 948-949). `update()` (line 143-162) calls `FastSenseObj.updateData(1, x, y)` — the lines are updated in place without axes rebuild. Event markers need the same treatment:

```matlab
% FastSenseWidget addition — private:
properties (Access = private)
    LastEventIds_   = {}   % cell of char — event Ids rendered at last refresh
    LastEventOpen_  = []   % logical array parallel to LastEventIds_
end

function refreshEventMarkers_(obj)
    if ~obj.ShowEventMarkers || isempty(obj.EventStore) || isempty(obj.Tag)
        return;
    end
    events = obj.EventStore.getEventsForTag(char(obj.Tag.Key));
    nE = numel(events);
    ids = cell(1, nE);
    openFlags = false(1, nE);
    for k = 1:nE
        ids{k} = events(k).Id;
        openFlags(k) = logical(events(k).IsOpen);
    end
    % Diff: added ids, removed ids, changed-open-to-closed
    added     = ~ismember(ids, obj.LastEventIds_);
    closedNow = false(1, nE);
    for k = 1:nE
        idx = find(strcmp(ids{k}, obj.LastEventIds_), 1);
        if ~isempty(idx) && obj.LastEventOpen_(idx) && ~openFlags(k)
            closedNow(k) = true;  % open->closed: redraw from hollow to filled
        end
    end
    if any(added) || any(closedNow) || ...
            numel(ids) ~= numel(obj.LastEventIds_)
        % Something changed — trigger full renderEventLayer_ rebuild.
        % (Cheap: the inner FastSense delete-and-redraw pattern already exists.)
        obj.FastSenseObj.renderEventLayer();  % make private method callable, or use a public thin wrapper
    end
    obj.LastEventIds_  = ids;
    obj.LastEventOpen_ = openFlags;
end
```

**Open question (plan-phase):** `renderEventLayer_` is currently `Access = private` on `FastSense.m:2192`. The widget needs a public trigger — either promote to `Access = public` or add a thin public wrapper. The latter is more conservative (explicit public API).

### Anti-Patterns to Avoid

- **Adding `NaN` checks in the line-rendering loop for event markers** — violates Pitfall 10 (render-path pollution). Event markers MUST stay in a separate method called *after* line rendering with a single early-out at the top.
- **Mutating `Event.EndTime` from outside `EventStore.closeEvent`** — violates D1 SSOT. Only `closeEvent` mutates open events; `Event.setStats` etc. get a sibling path `Event.updateRunningStats`. (See running-stats discussion under Q2 below.)
- **Storing `Event` handles on `Tag`** — Pitfall 4 from Phase 1010. `Tag.eventsAttached()` is a QUERY (lines 167-176 of `Tag.m`), not a stored property. Open events are queried live from `EventStore.getEventsForTag`.
- **Writing `.mat` files during live tick** — Pitfall 2 (persistence discipline). `MonitorTag.persistIfEnabled_` is gated on `obj.Persist`; `EventStore.save()` is NEVER called by the live path (line 107-140 comment: "consumers choose when to persist"). `closeEvent` must NOT call `save()`.
- **Using `isa(ev, 'Event')` to branch** — pre-Phase-1011 we mixed `Event` handles and structs; as of the Phase-1011 cleanup that distinction is gone in new code. Still, `EventStore.getEventsForTag` (lines 83-91) branches on `isa(ev, 'Event') || isstruct(ev)` for robust cached-load paths. DO NOT add new isa branches in Phase-1012 emission code — emit `Event` handles only.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ESC + click-outside + X dismiss pattern | Custom figure callback chain | Copy-and-adapt `DashboardLayout.openInfoPopup` structure (lines 405-518) | Already handles save/restore of prior figure callbacks, the outer-click parent-walk, and ESC key matching with Octave-compatible callbacks. |
| Open-event timing (rising edge detection) | New edge-detector | `MonitorTag.fireEventsInTail_` (`MonitorTag.m:580`) already emits on rising edges; we just add open-event emission in the branch that currently skips tail-open runs (line 602-604). | Rising-edge detection is correct and Octave-ported. |
| Event-Tag lookup by key | New index | `EventStore.getEventsForTag(tagKey)` + `EventBinding.getEventsForTag` | Single source of truth; Phase 1010 shipped. |
| Severity → color | New theme struct | `FastSense.severityToColor_` (`FastSense.m:2249-2272`) reads `DashboardTheme.StatusOkColor/WarnColor/AlarmColor` with hardcoded fallbacks | Phase 1010 nailed this; reuse. |
| Backward-compat struct field migration | Version number + `switch` loader | `properties { IsOpen = false }` default-on-read | Project precedent (Phase 1010 added 4 fields this way). |
| Live-tick incremental refresh | New timer | `DashboardEngine.onLiveTick` (`DashboardEngine.m:926-995`) already iterates active-page widgets and calls `w.update()` / `w.refresh()` | Plug into the `FastSenseWidget.update()` path via a new `refreshEventMarkers_` called from `update()`. |
| NV-pair parsing | New parser | `libs/EventDetection/private/parseOpts.m` | Already used by `EventStore` ctor; reusable for `closeEvent` if we accept `finalStats` as NV pairs instead of a struct. |

**Key insight:** Phase 1012 is ≥ 80% plumbing — the hardest part (dismiss pattern, rising-edge detection, severity coloring, schema migration) is already solved elsewhere in the codebase. Wrong instinct: "we need a new class." Right instinct: "which existing method gets one extra branch?"

## Runtime State Inventory

> N/A — Phase 1012 is purely additive. No rename/refactor/migration. Skipping this section.

## Common Pitfalls

### Pitfall A: `.mat` backward-compatibility drift

**What goes wrong:** A pre-Phase-1012 `.mat` file containing `Event` handles loads without `IsOpen`. If consumer code reads `ev.IsOpen` before the class-definition default kicks in (e.g., during `save→clear classes→load` mid-session), the field is absent.

**Why it happens:** MATLAB materializes missing properties from the `classdef` defaults on load — but only when the class definition is on path. In Octave 7/8 with classdef + handle, the same holds. The risk window is if someone runs `clear classes` between sessions *and* reloads the `.mat` into a still-old-code session.

**How to avoid:**
1. Keep `IsOpen = false` default in the class definition (not in the constructor).
2. Test: `save(tmp, 'events')` with old code; reload with new code; assert every event has `IsOpen=false`. Ship as `TestEventBackwardCompat.m` + `test_event_backward_compat.m`.
3. Use `isfield()` guard ONLY in the cached-struct-load branch of `EventStore.getEventsForTag` (line 88-90); no guard needed on fresh handles.

**Warning signs:** `struct has no field IsOpen` error at load time → class definition not on path (install.m regression), not a data corruption.

### Pitfall B: `ButtonDownFcn` blocked by axes zoom/pan

**What goes wrong:** If a FastSense figure is in "zoom in" mode (toolbar button active, `zoom on`), `ButtonDownFcn` on line objects is **intercepted** by the zoom-tool and never fires. Same for pan.

**Why it happens:** MATLAB's interactive-tool framework captures clicks at the figure level and prevents propagation to individual object callbacks.

**How to avoid:**
1. When opening the details panel, optionally call `zoom(obj.hFigure, 'off'); pan(obj.hFigure, 'off');` — but this mutates user state. Plan-phase decides.
2. **Preferred:** accept that clicks work only when no toolbar tool is active. Document this. Add a "tip: click event markers with no tool active" to `FastSense` doc header.
3. Test in both modes — ship `TestFastSenseEventClickZoomGuard.m` that activates zoom, clicks marker, asserts no panel appears (and no error either).

**Warning signs:** clicks silently do nothing while zoom tool is engaged; looks like a broken callback wiring.

### Pitfall C: Running-stats accuracy vs. performance

**What goes wrong:** Naïve running stats re-scan the full cache on every `appendData` tick. For a 10-second-window live dashboard, this turns the live tick into O(N×T) where N = open-event run length and T = tick count.

**Why it happens:** MATLAB vectorization feels "free" but every `max(y(startIdx:endIdx))` during `fireEventsInTail_` walks the whole run.

**How to avoid:**
1. Extend `cache_` (the MonitorTag private struct at `MonitorTag.m:114`) with an `openStats_` field:
   ```matlab
   openStats_ = struct( ...
       'eventId',    '', ...
       'nPoints',    0, ...
       'sumY',       0, ...
       'sumYSq',     0, ...
       'maxY',       -Inf, ...
       'minY',        Inf, ...
       'peakAbs',    0);
   ```
2. On each `appendData` call while a run is open, update these in O(chunk-size) only — not O(run-length).
3. On falling edge, derive `PeakValue = max(|maxY|, |minY|)` (for direction-aware peak), `MeanValue = sumY/nPoints`, `StdValue = sqrt(sumYSq/n - (sumY/n)^2)`, `RmsValue = sqrt(sumYSq/n)`. Pass as the `finalStats` struct to `EventStore.closeEvent`.

**Warning signs:** live-tick timing grows with event age — i.e., tick at t=0 is 5ms, tick at t=60s on the same run is 50ms.

### Pitfall D: uipanel position outside axes bounds

**What goes wrong:** the details panel anchored near a marker at the right edge of the plot renders offscreen.

**Why it happens:** naïve "anchor = (marker x+20px, marker y-10px)" without clamping.

**How to avoid:** after computing the anchor, clamp the panel's bottom-left and top-right to `[0 0 1 1]` in figure-normalized units. If the clamp would flip the panel (right edge > 1.0), mirror its x offset to the left side of the marker.

**Warning signs:** half-visible panels cut by figure edge.

### Pitfall E: Widget serialization leaks `EventStore` handle

**What goes wrong:** `FastSenseWidget.toStruct` recursively serializes `obj.EventStore`, which is a handle with nested state (file path, backups, events). Either saves a broken struct or fails.

**How to avoid:** do **NOT** round-trip `EventStore` through JSON. `ShowEventMarkers` is user configuration (persistable); `EventStore` is a runtime binding (re-established by the app on load). Precedent: `FastSenseWidget.DataStoreObj` is also not round-tripped directly (see `toStruct` lines 250-266; no `s.DataStoreObj = ...`).

**Warning signs:** serialized JSON contains `FilePath`, `events_`, or `MaxBackups` under a widget.

### Pitfall F: Octave `uistack` on empty handle array

**What goes wrong:** `uistack([], 'top')` errors in some Octave versions if called with an empty cell.

**How to avoid:**
```matlab
if ~isempty(obj.EventMarkerHandles_)
    try
        uistack([obj.EventMarkerHandles_{:}], 'top');
    catch
        % Octave fallback — reparent-in-order
    end
end
```
Project precedent: `FastSenseWidget.refresh` and `BarChartWidget` YData in-place update both use `try-catch` for Octave compat (STATE.md entry for `Phase 01-dashboard-engine-code-review-fixes`).

**Warning signs:** test fails only on Octave CI, passes on MATLAB CI.

### Pitfall G: Pitfall 10 regression — open-event visibility adds a per-event `line()` call

**What goes wrong:** moving from severity-batched `line()` (3 calls total) to per-event `line()` (N calls) increases the 0-event render budget only if we accidentally enter the per-event loop when there are no events. But the existing single early-out (`if ~obj.ShowEventMarkers || isempty(obj.Tags_), return; end`) already protects this path.

**How to avoid:** the 0-event path is `ShowEventMarkers=true` with `EventStore` attached but empty. Add a second early-out: `if isempty(es.getEventsForTag(char(tag.Key)))` skip to next tag. Already implicit in the existing loop (`if isempty(events), continue; end`, line 2225). Ship the Pitfall 10 bench anyway:

```matlab
% bench_fastsense_zero_events.m
% 12 lines, no EventStore attached — baseline
% 12 lines, empty EventStore attached — Phase 1012 early-out path
% 12 lines, EventStore with 0 events for these tags — fallback path
% Assert: all three within 5% of each other AND within 5% of Phase 1010 baseline
```

**Warning signs:** bench regression on the "empty EventStore" configuration.

## Code Examples

Verified patterns grounded in current source files.

### Event schema extension

```matlab
% libs/EventDetection/Event.m — add IsOpen in the public props block (after line 28):
properties
    TagKeys   = {}   % Phase 1010
    Severity  = 1
    Category  = ''
    Id        = ''
    IsOpen    = false  % Phase 1012 — true while event is still open (EndTime = NaN)
end
```

### EventStore.closeEvent (new method)

```matlab
% libs/EventDetection/EventStore.m — add after existing append() (~line 38):
function closeEvent(obj, eventId, endTime, finalStats)
    %CLOSEEVENT Close an open event in-place; update running stats with final values.
    %   es.closeEvent(eventId, endTime, finalStats) where finalStats is a
    %   struct with fields PeakValue, MinValue, MaxValue, MeanValue, RmsValue,
    %   StdValue, NumPoints. Mutates the event record; does NOT call save().
    %
    %   Errors:
    %     EventStore:unknownEventId — eventId not in store
    %     EventStore:alreadyClosed  — event found but IsOpen already false
    if isempty(obj.events_)
        error('EventStore:unknownEventId', 'No events; id ''%s'' not found.', eventId);
    end
    for i = 1:numel(obj.events_)
        ev = obj.events_(i);
        if isa(ev, 'Event') && strcmp(ev.Id, eventId)
            if ~ev.IsOpen
                error('EventStore:alreadyClosed', ...
                    'Event ''%s'' is not open.', eventId);
            end
            % In-place mutation on handle class — no copy.
            ev.EndTime  = endTime;
            ev.Duration = endTime - ev.StartTime;
            ev.IsOpen   = false;
            if nargin >= 4 && ~isempty(finalStats)
                ev.setStats( ...
                    finalStats.PeakValue, finalStats.NumPoints, ...
                    finalStats.MinValue,  finalStats.MaxValue, ...
                    finalStats.MeanValue, finalStats.RmsValue, ...
                    finalStats.StdValue);
            end
            return;
        end
    end
    error('EventStore:unknownEventId', 'Event id ''%s'' not found.', eventId);
end
```

Note: `Event.EndTime`, `Event.Duration`, and the setStats-targets (`PeakValue` etc.) are currently `SetAccess = private` (`Event.m:6-21`). Plan 01 MUST relax `EndTime` and `Duration` to `SetAccess = public` (or add a dedicated `close()` method on `Event` that `closeEvent` calls). The latter is cleaner; the former matches Phase 1010's pattern for `TagKeys` etc. Decision deferred to plan-phase.

### MonitorTag — open-event emission hook

```matlab
% libs/SensorThreshold/MonitorTag.m fireEventsInTail_ (line 580-628) — replace
% the `continue` at line 602-604 with open-event emission + id caching:
for k = 1:numel(sI)
    if eI(k) == numel(bin_new)
        % Run still open at tail end — Phase 1012: emit open event.
        if k == 1 && priorLastFlag == 1 && sI(k) == 1 && ~isnan(priorOngoingStart)
            startT = priorOngoingStart;
        else
            startT = newX(sI(k));
        end
        % Skip if we already emitted this open run (carried-id is stored in cache_.openEventId_).
        if ~isempty(obj.cache_.openEventId_), continue; end
        ev = Event(startT, NaN, char(obj.Parent.Key), char(obj.Key), NaN, 'upper');
        ev.IsOpen = true;
        if ~isempty(obj.EventStore)
            obj.EventStore.append(ev);
            ev.TagKeys = {char(obj.Key), char(obj.Parent.Key)};
            EventBinding.attach(ev.Id, char(obj.Key));
            EventBinding.attach(ev.Id, char(obj.Parent.Key));
            obj.cache_.openEventId_ = ev.Id;  % cache for closeEvent on falling edge
        end
        if ~isempty(obj.OnEventStart), obj.OnEventStart(ev); end
        continue;
    end
    % ... existing closed-run emission path ...
end
```

The CONTEXT decision "Peak/Min/Max/Mean/RMS/Std are running/partial values" means that on each `appendData` tick during an open run, we update the open event's stats in-place via a helper (e.g., `ev.updateRunningStats(newX, newY)` — small new method on `Event`). Alternatively, `cache_.openStats_` accumulates and is flushed on falling edge via `closeEvent(finalStats)`. CONTEXT defers the exact implementation to plan-phase; the accumulator approach is strictly more performant (no handle mutation per tick).

### FastSense — per-marker ButtonDownFcn

See Pattern 2 above — one `line()` per event with `UserData = struct('eventId', ..., 'tagKey', ...)`.

### FastSenseWidget — ShowEventMarkers property wiring

```matlab
% libs/Dashboard/FastSenseWidget.m — add to public props block (after line 21):
ShowEventMarkers = false   % Phase 1012; mirrors ShowThresholdLabels
EventStore       = []      % Phase 1012; forwarded to inner FastSense

% In render() around line 72 — add two forwarding lines:
fp.ShowEventMarkers = obj.ShowEventMarkers;
fp.EventStore       = obj.EventStore;

% In rebuildForTag_() around line 327 — same two lines.

% In toStruct() around line 255 — omit-when-default:
if obj.ShowEventMarkers, s.showEventMarkers = true; end
% NOTE: do NOT write s.eventStore — it's a runtime handle.

% In fromStruct() around line 417 — add:
if isfield(s, 'showEventMarkers')
    obj.ShowEventMarkers = s.showEventMarkers;
end
```

## State of the Art

| Phase 1010 approach | Phase 1012 refinement | Trigger | Impact |
|---------------------|------------------------|---------|--------|
| Severity-batched `line()` (3 handles total) | Per-event `line()` (N handles) | Per-marker `ButtonDownFcn` needs distinct handles | Bench check required (Pitfall G). |
| Events emitted only on falling edge | Events emitted on rising edge too (with `IsOpen=true`) | Live visibility requirement | In-place close via `closeEvent`. |
| Event stats finalized once (per `setStats` call in closing emission) | Running stats accumulated per `appendData` tick | "User sees peak climb during open event" | Minor perf cost per tick; bounded. |
| `Event.EndTime` always set at construction | `Event.EndTime = NaN` when `IsOpen=true` | Schema convention | Consumers guard with `isnan()`. |
| Widget-layer toggle absent — FastSense-only | `FastSenseWidget.ShowEventMarkers` + `EventStore` | CONTEXT decision — dashboard users shouldn't drop to bare `FastSense` | One new property each. |

**Deprecated/outdated:** nothing deprecated this phase. Phase 1011 already deleted the 8 legacy classes.

## Open Questions

1. **`Event.EndTime` mutability — public setter or `Event.close(endTime)` method?**
   - What we know: Phase 1010 relaxed `SetAccess` on `TagKeys`/`Severity`/`Category`/`Id` (public props block, line 24-28 of `Event.m`). The original 14 props remain `SetAccess = private` (line 6-21).
   - What's unclear: minimum-viable API. Either (a) add `EndTime` + `Duration` to the public block, OR (b) add `Event.close(endTime, finalStats)` method that mutates private fields internally.
   - Recommendation: (b) is more encapsulated — `EventStore.closeEvent` calls `ev.close(endTime, finalStats)`. Single write side preserved. Plan 01 locks.

2. **Running-stats accumulator: on `Event` or on `MonitorTag.cache_`?**
   - What we know: `MonitorTag.cache_` already has `lastStateFlag_`, `lastHystState_`, `ongoingRunStart_` boundary-state fields. Adding an `openStats_` sub-struct there fits the existing pattern.
   - What's unclear: whether the live dashboard wants to show the running stats in real time (before close). The CONTEXT field list includes `PeakValue`, `Min`, `Max`, `Mean`, `RMS`, `Std` — but silently implies these reflect the latest state at click time.
   - Recommendation: accumulator lives in `MonitorTag.cache_.openStats_` for O(1) updates; on each `appendData` tick, write a **snapshot** into `ev.PeakValue`/etc. via `ev.updateRunningStats(...)` so that a click during the open run sees live values. Cost: O(1) per tick. Plan 01 locks.

3. **`renderEventLayer_` access — promote to public or add thin wrapper?**
   - What we know: currently `methods (Access = private)` at `FastSense.m:2192`. Plan 03 (widget-level marker diff) needs to trigger a marker-layer rebuild from outside `FastSense`.
   - What's unclear: whether `FastSenseWidget` should call `fp.refreshEventLayer()` (new public method) or tuck the diff inside the widget and call a public `fp.renderEventLayer()` (renamed).
   - Recommendation: add a public thin wrapper `FastSense.refreshEventLayer()` that calls the private method. Keeps the existing private implementation intact; zero ripple to tests that mock/stub the private. Plan 02 locks.

4. **`uipanel` anchor — data coords → figure normalized coords helper.**
   - What we know: no precedent in the codebase for this conversion. `DashboardLayout.openInfoPopup` uses a standalone `figure` positioned with `movegui(fig, 'center')` (line 431); no anchor-to-data logic exists.
   - What's unclear: correct handling of log scale axes, datetime X, and zoomed-in state.
   - Recommendation: `FastSense.dataToFigureNormalized_(x, y)` helper — uses `get(hAxes, 'Position')`, `get(hAxes, 'XLim')`, `get(hAxes, 'YLim')`, and respects `XScale`/`YScale`. Datetime is already converted to datenum on ingest (`XType`, `IsDatetime` at lines 119-120), so internally X is always numeric. Ship with unit test exercising linear + log + after-zoom cases. Plan 02 scopes.

5. **`interp1` vs. `valueAt` for marker Y.**
   - CONTEXT locks `interp1(x, y, startT, 'nearest', 'extrap')`.
   - Current code uses `tag.valueAt(ev.StartTime)` which is ZOH (binary_search-based, `SensorTag.m:112-121`).
   - These agree on ZOH (step-function) signals; they disagree on sparse sensor data where 'nearest' picks the closer neighbor.
   - Recommendation: stick with `tag.valueAt` — it's already tested and Octave-safe. If plan-phase wants strict CONTEXT literal compliance, add an `'InterpMethod', 'nearest'` name-value on `FastSense` defaulting to the current behavior. Flag this for plan-phase lock.

6. **`interp1 + 'extrap'` Octave gotcha.**
   - `interp1(x, y, t, 'nearest', 'extrap')` is supported on Octave 7+ for most cases but warns on repeated x values. `tag.valueAt` uses `binary_search` which is MEX-accelerated and has no such warning. If plan-phase keeps CONTEXT literal, wrap with `try` + fall back to `valueAt`.

## Environment Availability

> N/A — Phase 1012 has no external dependencies. It touches only existing in-project files and reuses bundled MATLAB/Octave + MEX (`binary_search_mex`). `mksqlite` is irrelevant here (no disk backend). Skipping full audit.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | MATLAB xUnit suite (`matlab.unittest.TestRunner`) + custom flat Octave runner |
| Config file | `tests/run_all_tests.m` (auto-discovery; no config file) |
| Quick run command | `matlab -batch "addpath(genpath(pwd)); install(); run_all_tests('tests/test_event_open_close.m')"` (Octave: swap `matlab -batch` for `octave --eval`) |
| Full suite command | `matlab -batch "addpath(genpath(pwd)); install(); run_all_tests()"` |

### Phase Requirements → Test Map

Phase 1012 has no REQ-IDs. CONTEXT.md lists **behavioral acceptance criteria** instead; map those:

| CONTEXT decision | Behavior | Test type | Automated command | File exists? |
|------------------|----------|-----------|-------------------|-------------|
| `Event.IsOpen` default false; missing field defaults on load | Schema migration | unit (suite + flat) | `test_event_open_close` | ❌ Wave 0 — new |
| `EventStore.closeEvent(id, endTime, finalStats)` in-place update | Store mutation | unit | `test_event_store.m` extension | ✅ extend existing |
| MonitorTag emits open event on rising edge; closes on falling edge | Pipeline integration | unit + integration | `test_monitortag_open_events` | ❌ Wave 0 — new |
| Running stats accumulate during open run | Live accuracy | unit | `test_monitortag_running_stats` | ❌ Wave 0 — new |
| Open marker hollow; closed marker filled | Render visual | unit (handle property probe) | `test_fastsense_event_overlay` extension | ✅ extend existing |
| Per-marker `ButtonDownFcn` wires `UserData.eventId` | Click wiring | unit (handle property probe) | `test_fastsense_event_click_wiring` | ❌ Wave 0 — new |
| Click opens uipanel with event fields; ESC/outside/X dismisses | GUI integration | **manual-only on headless CI**; automated on MATLAB-with-JVM | `test_fastsense_event_details_panel` (JVM-gated) | ❌ Wave 0 — new |
| `FastSenseWidget.ShowEventMarkers` default false, forwards to inner `FastSense` | Widget wiring | unit | `test_fastsense_widget_event_markers` | ❌ Wave 0 — new |
| Widget `refresh()` marker diff open→closed triggers re-render | Live refresh | unit (mock `EventStore`) | `test_fastsense_widget_event_diff` | ❌ Wave 0 — new |
| `toStruct/fromStruct` round-trip `ShowEventMarkers` (omit when false) | Serialization | unit | `test_fastsense_widget_serialization` extension | ✅ extend existing |
| Pitfall 10 zero-events: no regression vs. Phase 1010 baseline | Render perf | benchmark | `bench_fastsense_zero_events.m` | ❌ Wave 0 — new (bench script) |

### Sampling Rate

- **Per task commit:** `tests/run_all_tests.m` with filter = changed files' tests only.
- **Per wave merge:** full `tests/run_all_tests.m`.
- **Phase gate:** full suite green on MATLAB R2020b + Octave 7 (macOS ARM64 dev; Linux Ubuntu in CI) + `bench_fastsense_zero_events.m` shows no regression on macOS ARM64 dev machine.

### Wave 0 Gaps

- [ ] `tests/suite/TestEventOpenClose.m` + `tests/test_event_open_close.m` — Event.IsOpen default + round-trip.
- [ ] `tests/suite/TestMonitorTagOpenEvents.m` + `tests/test_monitortag_open_events.m` — rising-edge emit IsOpen=true; falling-edge calls closeEvent; both paths covered in `fireEventsInTail_` and `fireEventsOnRisingEdges_`.
- [ ] `tests/suite/TestMonitorTagRunningStats.m` + `tests/test_monitortag_running_stats.m` — per-tick accumulator correctness.
- [ ] `tests/suite/TestFastSenseEventClickWiring.m` + `tests/test_fastsense_event_click_wiring.m` — marker has `ButtonDownFcn` and `UserData.eventId`; does NOT actually trigger callback (headless-safe).
- [ ] `tests/suite/TestFastSenseEventDetailsPanel.m` — JVM-gated GUI test; creates a figure, programmatically fires `ButtonDownFcn`, asserts panel visible, simulates ESC, asserts panel gone. Skip on `~usejava('jvm')`.
- [ ] `tests/suite/TestFastSenseWidgetEventMarkers.m` + `tests/test_fastsense_widget_event_markers.m` — property defaults, forwarding, toStruct/fromStruct omit-when-default.
- [ ] `tests/suite/TestFastSenseWidgetEventDiff.m` + `tests/test_fastsense_widget_event_diff.m` — mock `EventStore`, fire refresh, assert `LastEventIds_` updates.
- [ ] `benchmarks/bench_fastsense_zero_events.m` — new benchmark; 12-line plot; no events, empty store, missing store; assert per-configuration stability ≤ 5%.

*(If no gaps: not applicable — this phase has substantial Wave 0 scaffolding.)*

## Sources

### Primary (HIGH confidence — all first-party source files)

- `libs/EventDetection/Event.m` (78 lines) — schema shape, constructor, setStats method.
- `libs/EventDetection/EventStore.m` (216 lines) — `.mat`-file backend (NOT SQLite), atomic save, cached loadFile, getEventsForTag primary + fallback paths.
- `libs/EventDetection/EventBinding.m` (128 lines) — many-to-many index; unchanged by this phase.
- `libs/SensorThreshold/MonitorTag.m` (826 lines) — rising-edge and tail-stream event emission; `cache_` struct precedent.
- `libs/SensorThreshold/Tag.m:140-176` — `addManualEvent`, `eventsAttached`, `EventStore` base-class property (shipped Phase 1010).
- `libs/SensorThreshold/SensorTag.m:100-130` — `getXY`, `valueAt` (ZOH via `binary_search`).
- `libs/FastSense/FastSense.m:89-143, 2193-2272` — `ShowEventMarkers`, `EventStore`, `Tags_`, `EventMarkerHandles_`, `renderEventLayer_`, `severityToColor_`.
- `libs/Dashboard/FastSenseWidget.m` (422 lines) — render/rebuildForTag_/refresh/update/toStruct/fromStruct; `ShowThresholdLabels` precedent.
- `libs/Dashboard/DashboardEngine.m:926-995` — `onLiveTick` hot path; widget refresh dispatch.
- `libs/Dashboard/DashboardLayout.m:405-518` — `openInfoPopup`/`closeInfoPopup`/`onFigureClickForDismiss`/`onKeyPressForDismiss` — click-details template.
- `libs/Dashboard/DashboardTheme.m:136-138` — `StatusOkColor`/`StatusWarnColor`/`StatusAlarmColor` (existing); new constant `EventMarkerSize = 8` goes here.
- `tests/test_fastsense_event_overlay.m` — Phase 1010 acceptance test; extend for Phase 1012.
- `.planning/STATE.md` — decisions 1010/1011 referenced inline in this doc.
- `.planning/ROADMAP.md` — Phase 1010/1011 success criteria and pitfall gates.
- `.planning/milestones/v2.0-phases/1010-event-tag-binding-fastsense-overlay/1010-RESEARCH.md` — Phase 1010 research that set up the overlay we extend.
- `CLAUDE.md` — project instructions; MATLAB conventions.
- `.planning/config.json` — `workflow.nyquist_validation: true` → Validation Architecture section included above.

### Secondary (MEDIUM confidence)

- `.planning/phases/1012-.../1012-CONTEXT.md` — user-authored decisions; read as locked.

### Tertiary (LOW confidence)

- None. All claims grounded in on-disk source or STATE/ROADMAP entries.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every file referenced was read line-by-line at listed line numbers.
- Architecture patterns: HIGH — patterns are distilled from existing shipped code (Phase 1010 + Phase 9 + Phase 3); no novel architecture this phase.
- Pitfalls: MEDIUM-HIGH — Pitfalls A/B/C/D/E/F/G derived from code analysis + Phase 1010 precedent; real-world Octave version skew on uistack (Pitfall F) is anecdotal from STATE.md `Phase 01-dashboard-engine-code-review-fixes` entry about `BarChartWidget` try/catch.
- Open questions: flagged 6; all are plan-phase locks, not research gaps.

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 (30 days — stable in-project extension; no external library dependency)
