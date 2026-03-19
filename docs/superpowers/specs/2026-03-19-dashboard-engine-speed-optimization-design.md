# Dashboard Engine Speed Optimization — Design Spec

**Date:** 2026-03-19
**Goal:** Optimize dashboard engine for two scenarios: live mode with 20-40 widgets at ~5s intervals, and initial dashboard load time. Maintain R2020b + Octave compatibility.

---

## 1. Dirty-Flag System

### Problem
`onLiveTick()` calls `refresh()` on every widget regardless of whether its data changed. With 30 widgets and only 5 sensors updating per tick, 25 widgets do unnecessary work.

### Design
- Add `Dirty` property (logical, default `true`) to `DashboardWidget` base class.
- Add `markDirty()` method that sets `Dirty = true`.
- `onLiveTick()` only calls `refresh()` on widgets where `Dirty == true`, then sets `Dirty = false`.

### Dirty triggers (set to `true`)
- Widget created or added to dashboard
- Sensor / DataStore fires data-changed callback
- Theme change or figure resize (bulk: mark all dirty via `DashboardEngine.markAllDirty()`)
- User edits widget properties in edit mode

**Note:** `setTimeRange()` does NOT mark dirty. Time range changes only require an `xlim()` update, which `setTimeRange()` already performs. The dirty flag is reserved for data changes that require a full refresh or `updateData()` call. This avoids the problem where `onTimeSlidersChanged()` at the end of `onLiveTick()` would re-dirty all widgets immediately after clearing.

### Dirty cleared
- After successful `refresh()` / `update()` in `onLiveTick()`, at the end of the tick (after `onTimeSlidersChanged()` completes)

### Resize / theme-change hooks
- Add `ResizeFcn` on `hFigure` → calls `DashboardEngine.markAllDirty()` then `realizeBatch()`
- Theme change method calls `markAllDirty()` after applying new colors

### Impact
Live tick drops from N_widgets refreshes to N_dirty updates. With 30 widgets and 5 active sensors: ~6x fewer refreshes per tick.

---

## 2. FastSenseWidget Incremental Update

### Problem
`FastSenseWidget.refresh()` deletes all axes children via `findobj()`, recreates axes, re-instantiates the FastSense object, and re-renders — the most expensive per-widget operation.

### Design
- Add `update()` method alongside existing `refresh()` that uses the existing `FastSenseObj.updateData()` API:
  ```matlab
  % In FastSenseWidget.update():
  if ~isempty(obj.FastSenseObj) && obj.FastSenseObj.IsRendered
      obj.FastSenseObj.updateData(1, obj.Sensor.X, obj.Sensor.Y);
  else
      obj.refresh();  % fall back to full rebuild
  end
  ```
- `FastSenseObj.updateData()` (FastSense.m lines 1527–1625) replaces the underlying data, rebuilds the pyramid cache, re-downsamples to the current view, and calls `drawnowLimitRate()`.
- No `hLines` property needed — `FastSenseObj` already owns the line handles and manages downsampling internally.
- `onLiveTick()` calls `update()` for dirty FastSenseWidgets instead of `refresh()` when possible.

### Fallback conditions (trigger full refresh)
- `FastSenseObj` is empty or `IsRendered == false`
- Axes handle invalid or deleted
- Theme changed since last render
- Widget panel resized
- First render after realization

### Impact
Data-only updates become O(N_viewport) re-downsampled updates instead of O(N_datapoints) full rebuilds. Significantly cheaper but not O(1) due to downsampling.

---

## 3. Viewport Culling

### Problem
All widgets are rendered on initial load and refreshed on every live tick, even when off-screen in the scrollable viewport.

### Design
- Add `Realized` property (logical, default `false`) to `DashboardWidget`.
- Add `VisibleRows` property to `DashboardLayout`: `[topRow, bottomRow]` derived from scroll position and viewport height.
- A widget is "in view" if its row range overlaps `[topRow - buffer, bottomRow + buffer]` where `buffer = 2` rows.

### Widget lifecycle
- **Not realized, off-screen:** Empty placeholder panel with title + "Loading..." text.
- **Scrolled into view:** Call `render()`, set `Realized = true`.
- **Realized, scrolled out of view:** Keep panel and handles alive, but skip `refresh()` in live mode. Accumulate dirty flag; refresh on scroll-back.

### Key decision: do NOT destroy off-screen widgets
Destroying and recreating is the exact problem being solved. Memory cost of keeping handles is negligible vs render cost.

### Scroll callback
The current `onScroll()` only repositions the canvas and has no reference to the engine or widget list. Add a callback hook:
```matlab
% In DashboardLayout:
properties (Access = public)
    OnScrollCallback = []   % function handle: @(topRow, bottomRow)
end

% In DashboardLayout.onScroll():
% ... existing canvas repositioning ...
if ~isempty(obj.OnScrollCallback)
    obj.OnScrollCallback(topRow, bottomRow);
end
```
`DashboardEngine` sets `obj.Layout.OnScrollCallback = @(r1,r2) obj.onScrollRealize(r1, r2)` after creating the layout.

### Visible row calculation
Derive `VisibleRows` from scroll position using existing layout math:
```matlab
canvasY = scrollVal * (1 - cr);          % canvas offset from viewport top
topOffset = -canvasY;
topRow = floor(topOffset / (RowHeight/cr + GapV/cr)) + 1;
bottomRow = topRow + floor(1 / (RowHeight/cr + GapV/cr));
```
Where `cr = canvasRatio()`, `RowHeight` and `GapV` are already stored on the layout.

### Impact
A 40-widget dashboard with 8 visible: initial render does ~12 widgets (8 + buffer) instead of 40. Live ticks skip 28+ off-screen widgets.

---

## 4. Staggered Initial Load

### Problem
Rendering all visible widgets synchronously blocks the figure for 2-5s on large dashboards.

### Design
Split `DashboardLayout.createPanels()` into two methods:
- **`allocatePanels()`** — creates all uipanels with background color + "Loading..." placeholder text. Stores `hPanel` on each widget but does NOT call `render()`. Requires `hPanel` on `DashboardWidget` to have `SetAccess = public` (currently `protected`).
- **`realizeWidget(i)`** — calls `widget.render(widget.hPanel)` for a single widget, sets `Realized = true`, removes placeholder text.

New method `DashboardEngine.realizeBatch(batchSize)` calls `realizeWidget()` in batches of 4-6 with `drawnow` between batches.

### Batch ordering
1. Visible widgets, sorted top-to-bottom, left-to-right
2. Buffer-zone widgets (1-2 rows above/below viewport)
3. Off-screen widgets skipped (viewport culling handles them on scroll)

### Implementation
- Use `drawnow`-in-loop approach (not timer-based) for R2020b + Octave compatibility.
- Each unrealized panel shows widget title + "Loading..." text (lightweight uicontrol), replaced by actual content when realized.

### Impact
User sees dashboard frame + first widgets within ~200ms. Perceived load time drops dramatically even if total render time is similar.

---

## 5. Replace JSON Serialization with Pure .m Export

### Problem
Two serialization paths exist (JSON + .m script export). JSON parsing has Octave quirks with `jsondecode`. Two code paths to maintain.

### Design
The `.m` script becomes the **only** persistence format. A saved dashboard is a valid MATLAB/Octave function that rebuilds the dashboard when executed.

### Export format
```matlab
function d = my_dashboard()
    d = DashboardEngine('My Dashboard');
    d.Theme = 'dark';
    d.LiveInterval = 5;

    w = d.addWidget('fastsense', 'Motor Temp', [1, 1, 12, 3]);
    w.Sensor = mySensorLookup('motor_temp');

    w = d.addWidget('number', 'RPM', [13, 1, 6, 1]);
    w.ValueFcn = @() getCurrentRPM();
    % ... etc
end
```

### Load path
Use `feval` on the function file (NOT `run()` — `run()` cannot call a function file or capture return values):
```matlab
% In DashboardSerializer.load():
[dir, funcname] = fileparts(filepath);
addpath(dir);
d = feval(funcname);
rmpath(dir);
```
The function calls `DashboardEngine` and `addWidget()` — the engine IS the deserializer. Both `addpath`/`rmpath` and `feval` work identically in MATLAB and Octave.

### API change: `addWidget()` must return widget handle
Current `addWidget()` signature: `function addWidget(obj, type, varargin)` — no output.
New signature: `function w = addWidget(obj, type, varargin)` — returns created widget.
This is backward-compatible: callers that ignore the return value are unaffected.

### Changes
- `DashboardSerializer.save()` writes `.m` function file (replaces `saveJSON()`)
- `DashboardSerializer.load()` uses `feval()` on the function, returns the engine
- Remove `saveJSON()`, `loadJSON()`, and all JSON parsing code
- Dashboard file extension changes from `.json` to `.m`
- `DashboardEngine.addWidget()` returns the widget handle
- Migration: existing JSON dashboards can be converted via `DashboardEngine.load('old.json').save('new.m')` using the existing `exportScript()` method before JSON code is removed

### Benefits
- Users can read, edit, version-control dashboards as plain MATLAB code
- No JSON parser dependency
- Dashboards are composable (logic, loops, conditionals)
- One fewer code path to maintain

---

## Implementation Order

Steps 1+2 are coupled (incremental update depends on dirty-flag gating). Steps 3+4 are coupled (staggered init depends on the allocatePanels/realizeWidget split from viewport culling). Step 5 is independent.

1. **Dirty-flag system** — biggest live-mode win, lowest risk
2. **FastSenseWidget incremental update** — biggest per-widget speedup, depends on step 1
3. **Viewport culling** — biggest initial-load win
4. **Staggered init** — polish on top of viewport culling
5. **.m serialization** — independent, can land in parallel with 1-4

## Files Modified

| File | Changes |
|------|---------|
| `DashboardWidget.m` | Add `Dirty`, `Realized` properties, `hPanel` (SetAccess public), `markDirty()` method |
| `DashboardEngine.m` | Gate `onLiveTick()` on dirty, add `realizeBatch()`, `markAllDirty()`, `onScrollRealize()`, `ResizeFcn` hook, `addWidget()` returns widget handle |
| `FastSenseWidget.m` | Add `update()` using `FastSenseObj.updateData()`, no `hLines` needed |
| `DashboardLayout.m` | Split `createPanels()` into `allocatePanels()`/`realizeWidget()`, add `VisibleRows`, `OnScrollCallback`, visible-row formula, staggered init loop |
| `DashboardSerializer.m` | Rewrite to .m-only save/load via `feval`, remove JSON code |
| Other widgets | Minor: call `markDirty()` in data-change callbacks (NOT in `setTimeRange()`) |

## Testing Strategy

- Unit test: dirty flag set/clear lifecycle
- Unit test: viewport visibility calculation
- Integration test: live tick only refreshes dirty widgets (mock timer)
- Integration test: scroll triggers realization of deferred widgets
- Smoke test: existing example dashboards load and render correctly
- Performance test: measure `onLiveTick` duration before/after with 30 widgets

## Backward Compatibility

- All new properties have safe defaults (`Dirty = true`, `Realized = false`)
- Existing dashboards work unchanged — first render marks everything realized
- JSON dashboards will need a one-time migration to `.m` format (provide migration script)
- No new MATLAB version requirements — R2020b + Octave compatible
