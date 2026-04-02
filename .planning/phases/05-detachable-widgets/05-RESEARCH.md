# Phase 5: Detachable Widgets - Research

**Researched:** 2026-04-01
**Domain:** MATLAB figure/uicontrol lifecycle, handle class patterns, timer-driven live sync
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Detach Button**
- Placed in widget header chrome (like info icon from Phase 3)
- Injected centrally via DashboardLayout.realizeWidget() — no per-widget changes
- Small button with detach/popout icon or text

**DetachedMirror Architecture**
- DetachedMirror is a separate handle class (NOT a DashboardWidget subclass)
- Registered in DashboardEngine.DetachedMirrors cell array
- Iterated separately in onLiveTick() — not part of widget grid layout
- Each DetachedMirror owns its own figure window and a cloned widget instance

**Widget Cloning**
- Clone via toStruct()/fromStruct() round-trip (same mechanism as serialization)
- FastSenseWidget override: rebind to same Sensor object, set UseGlobalTime = false
- Cloned widget rendered into DetachedMirror's figure panel

**Live Sync**
- DashboardEngine.onLiveTick() extended to iterate DetachedMirrors after active page widgets
- Each mirror calls widget.onLiveTick() on its cloned widget
- Stale handle cleanup: check ishandle(mirror.hFigure) before tick, remove if closed

**Lifecycle**
- Detached widgets are read-only mirrors (DETACH-07)
- Closing figure window triggers CloseRequestFcn → removes from registry
- Detached state is NOT persisted (SERIAL-04, Phase 6)

### Claude's Discretion
- DetachedMirror internal layout (figure title, panel arrangement)
- Button icon/text style
- Performance optimization for multiple simultaneous detached windows

### Deferred Ideas (OUT OF SCOPE)

None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DETACH-01 | Every widget shows a detach button in its header chrome | addDetachButton() in DashboardLayout.realizeWidget(), parallel to addInfoIcon() pattern from Phase 3 |
| DETACH-02 | Clicking detach opens the widget as a standalone figure window | detachWidget() on DashboardEngine creates a DetachedMirror, clones widget via toStruct/fromStruct, renders into new figure |
| DETACH-03 | Detached widget receives live data updates from DashboardEngine timer | onLiveTick() loops over DetachedMirrors after active-page widgets; calls cloned widget's refresh()/update() |
| DETACH-04 | Closing a detached figure window cleanly removes it from the mirror registry | CloseRequestFcn on DetachedMirror's figure calls removeDetached() on engine via injected callback |
| DETACH-05 | Detached FastSenseWidget gets independent time axis zoom/pan | Cloned FastSenseWidget has UseGlobalTime = false; XLim listener fires without global-time guard |
| DETACH-06 | Multiple widgets can be detached simultaneously without degrading refresh rate | No extra timers; single engine timer already covers all mirrors; stale handle check is O(n) cheap |
| DETACH-07 | Detached widgets are read-only live mirrors (no edits syncing back) | DetachedMirror holds cloned widget; no reference back to original widget object |
</phase_requirements>

---

## Summary

Phase 5 adds the ability for users to pop any dashboard widget into its own standalone MATLAB figure window while keeping it live-synced through the existing `DashboardEngine` timer. The implementation is a pure MATLAB handle-class extension — no new external dependencies or toolboxes required.

The core machinery is a new `DetachedMirror` handle class that owns a figure, a full-panel uipanel, and a cloned `DashboardWidget` instance. Cloning reuses the existing `toStruct()`/`fromStruct()` serialization round-trip, which is already battle-tested in Phase 1/serialization paths. The only widgets that need special handling after the round-trip are `FastSenseWidget` (must rebind live `Sensor` reference and force `UseGlobalTime = false`) and `RawAxesWidget` with a function-handle `PlotFcn` (function handles survive the clone without special treatment since no serialization to disk occurs).

Live sync is zero-cost in timer overhead — `DashboardEngine.onLiveTick()` already runs on a single timer; the plan simply extends the tail of that method to iterate `DetachedMirrors` after the active-page widget loop. Stale handle cleanup (closed windows) is an O(n) `ishandle()` check per tick — negligible even for dozens of detached windows.

**Primary recommendation:** Implement DetachedMirror as a standalone handle class; inject the detach button in `DashboardLayout.realizeWidget()` following the Phase 3 `addInfoIcon()` pattern exactly; extend `onLiveTick()` with a guarded mirror-tick loop.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MATLAB uicontrol | R2020b+ | Detach button in widget header | Already used for info icon; same parent (widget.hPanel) |
| MATLAB figure | R2020b+ | Standalone detached window | Native MATLAB; no toolbox required |
| MATLAB timer | R2020b+ | Already exists (LiveTimer) | No new timer; reuse engine timer |
| handle class | MATLAB OOP | DetachedMirror base | All Dashboard classes are handle; consistent |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| DashboardTheme | (in-repo) | Figure background/colors in mirror | Use `DashboardEngine.Theme` inherited by mirror |
| DashboardWidget.toStruct/fromStruct | (in-repo) | Widget cloning mechanism | Only path that works for all 20+ widget types without per-type switch |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| toStruct/fromStruct clone | Direct property copy | Would require per-type copy logic; toStruct/fromStruct already covers all types |
| Single engine timer coverage | Separate timer per mirror | Separate timers multiply timer overhead and risk drift; single timer is cleaner |
| CloseRequestFcn for cleanup | DeleteFcn on mirror object | CloseRequestFcn fires before deletion and is standard MATLAB close pattern |

**Installation:** No new packages — pure MATLAB, no dependencies.

---

## Architecture Patterns

### New File

```
libs/Dashboard/
├── DetachedMirror.m     # New handle class — one per detached window
├── DashboardEngine.m    # Extended: DetachedMirrors property, detachWidget(), removeDetached(), onLiveTick() extension
└── DashboardLayout.m    # Extended: addDetachButton() private helper, realizeWidget() calls it
```

### Pattern 1: DetachedMirror Class

**What:** A `handle` class (NOT a `DashboardWidget` subclass) that owns a MATLAB figure window, a full-figure uipanel, and a cloned `DashboardWidget`. Created on demand by `DashboardEngine.detachWidget()`.

**When to use:** Created exactly once per detach button click; destroyed when figure is closed.

**Key properties:**
```matlab
classdef DetachedMirror < handle
    properties (SetAccess = private)
        hFigure   = []   % standalone figure window
        hPanel    = []   % full-figure uipanel (fills figure)
        Widget    = []   % cloned DashboardWidget instance
    end
end
```

**Constructor pattern:**
```matlab
function obj = DetachedMirror(originalWidget, theme, removeCallback)
    % 1. Clone widget via toStruct/fromStruct
    s = originalWidget.toStruct();
    cloned = DashboardWidget.fromStructDispatch(s);  % or per-type dispatch

    % 2. For FastSenseWidget: rebind Sensor reference, force UseGlobalTime = false
    if isa(cloned, 'FastSenseWidget') && ~isempty(originalWidget.Sensor)
        cloned.Sensor = originalWidget.Sensor;
        cloned.UseGlobalTime = false;
    end

    % 3. Create figure
    obj.hFigure = figure('Name', originalWidget.Title, ...
        'NumberTitle', 'off', ...
        'Color', theme.DashboardBackground, ...
        'CloseRequestFcn', @(~,~) removeCallback());

    % 4. Full-figure panel
    obj.hPanel = uipanel('Parent', obj.hFigure, ...
        'Units', 'normalized', 'Position', [0 0 1 1], ...
        'BorderType', 'none', ...
        'BackgroundColor', theme.DashboardBackground);

    % 5. Render cloned widget into panel
    cloned.ParentTheme = theme;
    cloned.render(obj.hPanel);
    obj.Widget = cloned;
end
```

### Pattern 2: Detach Button Injection (Phase 3 parallel)

**What:** `DashboardLayout.realizeWidget()` already calls `addInfoIcon()` for widgets with a Description. Add a parallel call to a new private `addDetachButton(widget)` that always fires (every widget gets a detach button — DETACH-01).

**Where in realizeWidget():**
```matlab
function realizeWidget(obj, widget)
    if widget.Realized, return; end
    if isempty(widget.hPanel) || ~ishandle(widget.hPanel), return; end
    ph = findobj(widget.hPanel, 'Tag', 'placeholder');
    delete(ph);
    widget.render(widget.hPanel);
    widget.Realized = true;
    widget.Dirty = false;
    % Phase 3 injection — conditional
    if ~isempty(widget.Description)
        obj.addInfoIcon(widget);
    end
    % Phase 5 injection — unconditional (DETACH-01)
    if ~isempty(obj.DetachCallback)
        obj.addDetachButton(widget);
    end
end
```

**DashboardLayout gains a new public property:**
```matlab
DetachCallback = []   % @(widget) — set by DashboardEngine after render()
```

**Button placement:** `[0.82 0.90 0.08 0.08]` — left of info icon at `[0.90 0.90 0.08 0.08]`. If no info icon, can use `[0.90 0.90 0.08 0.08]` instead; simplest: always place at `[0.82 ...]` to avoid overlap.

**addDetachButton() private method:**
```matlab
function addDetachButton(obj, widget)
    theme = DashboardTheme('light');
    if ~isempty(widget.ParentTheme) && isstruct(widget.ParentTheme)
        theme = widget.ParentTheme;
    end
    uicontrol('Parent', widget.hPanel, ...
        'Style', 'pushbutton', ...
        'String', char(8599), ...   % unicode up-right arrow, or use '^' / 'pop'
        'Units', 'normalized', ...
        'Position', [0.82 0.90 0.08 0.08], ...
        'FontSize', 9, ...
        'ForegroundColor', theme.ToolbarFontColor, ...
        'BackgroundColor', theme.ToolbarBackground, ...
        'Tag', 'DetachButton', ...
        'TooltipString', 'Detach widget', ...
        'Callback', @(~,~) obj.DetachCallback(widget));
end
```

### Pattern 3: DashboardEngine Extensions

**New property:**
```matlab
DetachedMirrors = {}   % Cell array of DetachedMirror objects (SetAccess = private)
```

**detachWidget(widget) public method:**
```matlab
function detachWidget(obj, widget)
    themeStruct = DashboardTheme(obj.Theme);
    removeCallback = @() obj.removeDetached(widget);
    mirror = DetachedMirror(widget, themeStruct, removeCallback);
    obj.DetachedMirrors{end+1} = mirror;
end
```

**removeDetached(widget) public method** (called from CloseRequestFcn):
```matlab
function removeDetached(obj, widget)
    keep = true(1, numel(obj.DetachedMirrors));
    for i = 1:numel(obj.DetachedMirrors)
        m = obj.DetachedMirrors{i};
        if m.Widget == widget || ~ishandle(m.hFigure)
            keep(i) = false;
        end
    end
    obj.DetachedMirrors = obj.DetachedMirrors(keep);
    % Close figure if still open (handles case where removeDetached called programmatically)
    for i = 1:numel(obj.DetachedMirrors)
        % already filtered above
    end
end
```

**onLiveTick() extension** — append after the existing widget loop:
```matlab
% Tick detached mirrors; clean stale handles
staleIdx = [];
for i = 1:numel(obj.DetachedMirrors)
    m = obj.DetachedMirrors{i};
    if isempty(m.hFigure) || ~ishandle(m.hFigure)
        staleIdx(end+1) = i; %#ok<AGROW>
        continue;
    end
    try
        if isa(m.Widget, 'FastSenseWidget')
            m.Widget.update();
        else
            m.Widget.refresh();
        end
    catch ME
        warning('DashboardEngine:mirrorRefreshError', ...
            'DetachedMirror "%s" refresh failed: %s', m.Widget.Title, ME.message);
    end
end
if ~isempty(staleIdx)
    obj.DetachedMirrors(staleIdx) = [];
end
```

**Wire DetachCallback after layout is ready** — in `render()`, after `allocatePanels`:
```matlab
obj.Layout.DetachCallback = @(w) obj.detachWidget(w);
```

Also wire after `rerenderWidgets()` (page switch, reflow), since `realizeWidget()` is called fresh.

### Pattern 4: Widget Cloning for Non-Serializable Widgets

**toStruct/fromStruct round-trip** works for all types that have static `fromStruct()`. Verification:

| Widget type | toStruct/fromStruct | Live ref issue | Resolution |
|-------------|---------------------|---------------|------------|
| FastSenseWidget | YES — sensor by key | Sensor is a live object, fromStruct does `SensorRegistry.get(key)` which returns the same live Sensor | Also copy `obj.Sensor` directly after fromStruct to guarantee binding even if registry miss |
| RawAxesWidget | YES — PlotFcn stored as `func2str` | func2str loses closure state | PlotFcn closures survive in-memory clone; only disk serialization breaks them. For in-memory clone, copy PlotFcn directly from original |
| NumberWidget / StatusWidget / etc. | YES — no live refs | None | Standard |
| GroupWidget | YES — children serialized | Children have same issues as above | Handle recursively via fromStruct; same rules apply per child |

**Recommended clone dispatch** — `DetachedMirror` needs a way to call the right `fromStruct`. The existing `DashboardSerializer.configToWidgets()` has the dispatch table. Expose a static helper or replicate the small switch in `DetachedMirror`:

```matlab
% In DetachedMirror (private static helper)
function w = cloneWidget(original)
    s = original.toStruct();
    switch s.type
        case 'fastsense',    w = FastSenseWidget.fromStruct(s);
        case 'number',       w = NumberWidget.fromStruct(s);
        case 'status',       w = StatusWidget.fromStruct(s);
        case 'text',         w = TextWidget.fromStruct(s);
        case 'gauge',        w = GaugeWidget.fromStruct(s);
        case 'table',        w = TableWidget.fromStruct(s);
        case 'rawaxes',      w = RawAxesWidget.fromStruct(s);
        case 'timeline',     w = EventTimelineWidget.fromStruct(s);
        case 'group',        w = GroupWidget.fromStruct(s);
        case 'heatmap',      w = HeatmapWidget.fromStruct(s);
        case 'barchart',     w = BarChartWidget.fromStruct(s);
        case 'histogram',    w = HistogramWidget.fromStruct(s);
        case 'scatter',      w = ScatterWidget.fromStruct(s);
        case 'image',        w = ImageWidget.fromStruct(s);
        case 'multistatus',  w = MultiStatusWidget.fromStruct(s);
        otherwise
            error('DetachedMirror:unknownType', 'Unknown widget type: %s', s.type);
    end
    % Post-clone: restore live references lost by toStruct serialization
    if isa(w, 'FastSenseWidget') && ~isempty(original.Sensor)
        w.Sensor = original.Sensor;
    end
    if isa(w, 'RawAxesWidget') && ~isempty(original.PlotFcn)
        w.PlotFcn = original.PlotFcn;
        w.DataRangeFcn = original.DataRangeFcn;
    end
    % Force independent time axis for detached FastSenseWidget (DETACH-05)
    if isa(w, 'FastSenseWidget')
        w.UseGlobalTime = false;
    end
end
```

### Anti-Patterns to Avoid

- **Subclassing DashboardWidget for DetachedMirror:** The mirror is not a widget; it wraps one. Subclassing forces it into the grid layout system.
- **Creating a new timer per detached window:** Multiplies timer overhead and risks phase drift. Use the engine's single `LiveTimer`.
- **Calling `delete(figure)` inside CloseRequestFcn:** Use `delete(gcf)` or `closereq()` after cleanup, not before. Otherwise the figure handle disappears before `removeDetached()` can find it.
- **Storing the original widget index in DetachedMirror:** Widget indices change on page switch. Store the widget object handle instead, which is stable as long as the widget is alive.
- **Using drawnow inside the mirror tick loop:** The existing `onLiveTick()` does not call drawnow; the mirror loop should not either. MATLAB's event queue processes redraws automatically.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Widget cloning | Manual per-property copy | toStruct/fromStruct + live ref restore | Already covers all 20+ widget types; tested |
| Timer for mirrors | New `timer` per detached window | Existing `DashboardEngine.LiveTimer` | Timer proliferation causes overhead; single tick is sufficient |
| Figure title formatting | Custom string builder | `sprintf('%s — Live', widget.Title)` | Simple is correct |
| Stale handle detection | Try/catch on every method | `ishandle(mirror.hFigure)` check before tick | ishandle is the MATLAB idiom; cheap and reliable |
| Button positioning | Dynamic position calculator | Fixed normalized position in hPanel | Info icon already uses fixed position; same approach |

**Key insight:** The existing serialization infrastructure handles all widget types uniformly. The clone is just an in-memory serialize/deserialize with a live-reference restore step — no custom copy logic needed per widget.

---

## Common Pitfalls

### Pitfall 1: CloseRequestFcn Closure Capture

**What goes wrong:** If the `removeCallback` lambda captures `widget` by reference, and the original widget is deleted (e.g., page navigation), calling `removeDetached(widget)` may receive an invalid handle.

**Why it happens:** MATLAB closures capture variables at creation time; `widget` is a handle object, so the closure holds a reference.

**How to avoid:** In `removeDetached()`, guard with `isvalid(widget)` check before comparing. Also, clean up any mirror whose `hFigure` is no longer a valid handle — the stale-handle sweep in `onLiveTick()` handles this as a fallback.

**Warning signs:** `invalid object handle` errors in `removeDetached`.

### Pitfall 2: Double-Close on Figure Destruction

**What goes wrong:** `CloseRequestFcn` fires, calls `removeDetached()`, which tries to call `delete(hFigure)` — but MATLAB is already in the process of closing it, causing a double-delete error.

**Why it happens:** `CloseRequestFcn` fires before the figure is deleted. Calling `delete(hFigure)` inside the callback is the standard pattern — but only if you call it once.

**How to avoid:** `CloseRequestFcn` should call `obj.removeDetached()` first (which does bookkeeping), then `delete(obj.hFigure)`. Do NOT call `closereq()` or `delete(gcf)` additionally from `removeDetached`. Pattern:

```matlab
% CloseRequestFcn (registered in DetachedMirror constructor)
@(~,~) obj.onFigureClose()

function onFigureClose(obj)
    removeCallback();   % remove from engine registry
    delete(obj.hFigure);
end
```

**Warning signs:** `Error: Invalid figure handle` on close.

### Pitfall 3: DetachCallback Not Re-Wired After Reflow

**What goes wrong:** Page switch or group collapse triggers `rerenderWidgets()`, which calls `realizeWidget()` on all widgets. If `Layout.DetachCallback` is empty at that point, the new detach buttons never get wired.

**Why it happens:** `Layout.DetachCallback` is set once in `render()` but `rerenderWidgets()` recreates panels.

**How to avoid:** Set `Layout.DetachCallback` in `rerenderWidgets()` as well as `render()`. Since `DetachCallback` is a property of `DashboardLayout`, it persists across reflows — just verify it is set before `allocatePanels()` is called. Because `Layout` is not recreated between calls, the callback persists automatically. However, `reflow()` calls `createPanels()` → `allocatePanels()` which recreates the panels and calls `realizeWidget()` again, so the callback must still be present on `Layout` at that point.

**Warning signs:** Detach buttons appear only on initial render, disappear after page switch.

### Pitfall 4: GroupWidget Children Detach

**What goes wrong:** A `GroupWidget` (tabs/collapsible) contains child widgets. The detach button is added to the outer `GroupWidget.hPanel`. Clicking detach mirrors the `GroupWidget` itself, not an individual child.

**Why it happens:** `realizeWidget()` is called for every top-level widget. `GroupWidget` renders its own children internally; those children's panels are inside the group's panel, not the top-level canvas.

**How to avoid:** For MVP, accept that detaching a `GroupWidget` mirrors the entire group. This is the correct behavior per DETACH-01 ("every widget shows a detach button") — a GroupWidget is a widget. Document this in code comments. Individual child widget detach is a v2 feature.

**Warning signs:** None — this is expected behavior.

### Pitfall 5: RawAxesWidget with Function Handle Closures

**What goes wrong:** `RawAxesWidget.toStruct()` serializes `PlotFcn` as `func2str()`, losing closure state. `fromStruct()` uses `str2func()`, which only works for named functions, not anonymous lambdas.

**Why it happens:** `func2str(@(ax) plot(ax, x, y))` returns `@(ax) plot(ax, x, y)` which `str2func()` can parse, but without the captured variables `x` and `y`.

**How to avoid:** In `DetachedMirror.cloneWidget()`, after the `fromStruct()` call, explicitly copy `PlotFcn` and `DataRangeFcn` from the original object:

```matlab
if isa(w, 'RawAxesWidget') && ~isempty(original.PlotFcn)
    w.PlotFcn = original.PlotFcn;
    w.DataRangeFcn = original.DataRangeFcn;
end
```

This is safe because the detach happens in-memory (no disk round-trip).

**Warning signs:** Detached `RawAxesWidget` shows empty axes.

---

## Code Examples

### Info Icon Position Reference (Phase 3)

```matlab
% Source: libs/Dashboard/DashboardLayout.m addInfoIcon()
uicontrol('Parent', widget.hPanel, ...
    'Style', 'pushbutton', ...
    'String', 'i', ...
    'Units', 'normalized', ...
    'Position', [0.90 0.90 0.08 0.08], ...
    'FontSize', 9, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', iconFg, ...
    'BackgroundColor', iconBg, ...
    'Tag', 'InfoIconButton', ...
    'TooltipString', 'Widget info', ...
    'Callback', @(~,~) obj.openInfoPopup(widget, theme));
```

Position the detach button at `[0.82 0.90 0.08 0.08]` — immediately left of info icon.

### onLiveTick Pattern (Phase 1 established)

```matlab
% Source: libs/Dashboard/DashboardEngine.m onLiveTick()
for i = 1:numel(ws)
    w = ws{i};
    if w.Dirty && w.Realized && obj.Layout.isWidgetVisible(w.Position)
        try
            if isa(w, 'FastSenseWidget')
                w.update();
            else
                w.refresh();
            end
        catch ME
            warning('DashboardEngine:refreshError', ...
                'Widget "%s" refresh failed: %s', w.Title, ME.message);
        end
    end
end
```

Mirror tick loop follows this exact pattern (try/catch + warning; no drawnow; `ishandle` guard).

### ishandle Guard Pattern

```matlab
% Standard MATLAB stale-handle check (used throughout codebase)
if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
    return;
end
```

Use this before every access to `mirror.hFigure`.

### CloseRequestFcn Registration

```matlab
% Register in figure creation
obj.hFigure = figure('Name', title, ...
    'NumberTitle', 'off', ...
    'CloseRequestFcn', @(~,~) obj.onFigureClose());

% Handler
function onFigureClose(obj)
    if ~isempty(obj.RemoveCallback)
        obj.RemoveCallback();
    end
    if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
        delete(obj.hFigure);
    end
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-widget changes for new chrome | Central injection in realizeWidget() | Phase 3 | No per-widget changes needed for detach button |
| Global timer restart on error | ErrorFcn handler keeps timer alive | Phase 1 | Mirror tick errors are caught; timer survives |
| Flat Widgets list | Paged Widgets via ActivePage | Phase 4 | onLiveTick() must use activePageWidgets(); mirrors are separate from pages |

**Deprecated/outdated:**
- None relevant to this phase.

---

## Open Questions

1. **GroupWidget child detection for DetachCallback wiring**
   - What we know: `GroupWidget.render()` creates sub-panels internally; `realizeWidget()` is only called for the top-level GroupWidget.
   - What's unclear: Whether children inside a collapsed GroupWidget get a detach button (they won't, since `realizeWidget()` is not called on them).
   - Recommendation: Acceptable for v1; only top-level widgets get detach buttons. Document as known limitation.

2. **Button icon character compatibility**
   - What we know: The `char(8599)` unicode arrow may not render in all MATLAB/Octave versions.
   - What's unclear: Octave 7+ support for unicode in uicontrol strings.
   - Recommendation: Default to ASCII `'^'` or `'+'` with tooltip 'Detach'. Fall back gracefully.

3. **DetachedMirror during rerenderWidgets**
   - What we know: `rerenderWidgets()` deletes and recreates panels for active-page widgets. DetachedMirrors are independent figures — not touched.
   - What's unclear: Nothing — mirrors are independent. Confirmed safe.
   - Recommendation: No action needed.

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — pure MATLAB, no CLIs, services, or runtimes beyond what already runs the dashboard).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | matlab.unittest.TestCase (MATLAB) |
| Config file | tests/run_all_tests.m |
| Quick run command | `cd /path/to/FastPlot && matlab -batch "install; runtests('tests/suite/TestDashboardDetach')"` |
| Full suite command | `cd /path/to/FastPlot && matlab -batch "install; run_all_tests"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DETACH-01 | Every widget gets detach button after realizeWidget | unit | `runtests('tests/suite/TestDashboardDetach', 'Name', 'testDetachButtonInjected')` | Wave 0 |
| DETACH-02 | Clicking detach creates DetachedMirror with valid figure | unit | `runtests('tests/suite/TestDashboardDetach', 'Name', 'testDetachOpensWindow')` | Wave 0 |
| DETACH-03 | Mirror widget refresh called during onLiveTick | unit | `runtests('tests/suite/TestDashboardDetach', 'Name', 'testMirrorTickedOnLive')` | Wave 0 |
| DETACH-04 | Closing mirror figure removes from DetachedMirrors registry | unit | `runtests('tests/suite/TestDashboardDetach', 'Name', 'testCloseRemovesFromRegistry')` | Wave 0 |
| DETACH-05 | Cloned FastSenseWidget has UseGlobalTime = false | unit | `runtests('tests/suite/TestDashboardDetach', 'Name', 'testFastSenseIndependentZoom')` | Wave 0 |
| DETACH-06 | Multiple detaches don't create extra timers | unit | `runtests('tests/suite/TestDashboardDetach', 'Name', 'testNoExtraTimers')` | Wave 0 |
| DETACH-07 | Cloned widget has no back-reference to original | unit | `runtests('tests/suite/TestDashboardDetach', 'Name', 'testMirrorIsReadOnly')` | Wave 0 |

### Sampling Rate

- **Per task commit:** `runtests('tests/suite/TestDashboardDetach')`
- **Per wave merge:** `runtests({'tests/suite/TestDashboardDetach', 'tests/suite/TestDashboardEngine', 'tests/suite/TestDashboardLayout'})`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/suite/TestDashboardDetach.m` — covers all DETACH-01 through DETACH-07
- [ ] `libs/Dashboard/DetachedMirror.m` — new class file needed before tests can run

---

## Sources

### Primary (HIGH confidence)
- `libs/Dashboard/DashboardEngine.m` — onLiveTick, render, startLive, onClose, rerenderWidgets patterns read directly
- `libs/Dashboard/DashboardLayout.m` — realizeWidget, addInfoIcon, allocatePanels patterns read directly
- `libs/Dashboard/DashboardWidget.m` — toStruct, fromStruct, property list read directly
- `libs/Dashboard/FastSenseWidget.m` — UseGlobalTime, setTimeRange, onXLimChanged, toStruct/fromStruct read directly
- `libs/Dashboard/RawAxesWidget.m` — PlotFcn serialization issue confirmed in toStruct/fromStruct directly
- `.planning/phases/05-detachable-widgets/05-CONTEXT.md` — locked decisions

### Secondary (MEDIUM confidence)
- MATLAB documentation (training knowledge): `ishandle()`, `CloseRequestFcn`, `timer` behavior — consistent with what is observed in existing codebase Phase 1 code

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all code read from source; no external libraries
- Architecture: HIGH — patterns derived directly from Phase 3 (addInfoIcon) and Phase 1 (timer tick) code, both in-repo
- Pitfalls: HIGH — derived from reading actual toStruct/fromStruct implementations and CloseRequestFcn MATLAB idiom
- Clone dispatch: HIGH — confirmed all 15 widget types are present in DashboardEngine.addWidget() switch

**Research date:** 2026-04-01
**Valid until:** Stable — pure in-repo research, no external dependencies to drift
