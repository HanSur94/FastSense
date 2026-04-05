# Code Reviewer Memory — FastPlot Project (being renamed to FastSense)

## Project: FastPlot (MATLAB) — rename to FastSense in progress (2026-03-16)
A high-performance MATLAB plotting library with dynamic downsampling, pyramid caching, and theme support.

## Rename: FastPlot → FastSense (key facts for reviewers)
- `libs/FastPlot/` → `libs/FastSense/`; all `FastPlot*.m` → `FastSense*.m`
- `FastPlotWidget.m` lives at `libs/Dashboard/FastPlotWidget.m` (NO `widgets/` subdirectory — spec table has wrong path)
- `FastPlotFigure` is a STALE/historical name for `FastPlotGrid`; it exists only in wiki and worktrees, NOT in current .m files
- Widget type string `'fastplot'` (lowercase) is the dispatch key in DashboardEngine/Builder/Serializer
- Python package `bridge/python/fastplot_bridge/` → `fastsense_bridge/`; includes `tcp_client.py` and `blob_decoder.py`
- `test_tcp_client.py` has a `from fastplot_bridge...` import that must be updated

## Key Classes and Their APIs

### FastPlot
- `addLine(x, y, ...)` — core line-add method (must be called BEFORE render())
- `addSensor(sensor, 'ShowThresholds', true/false)` — adds sensor data + resolved thresholds
- `addThreshold(value, ...)` or `addThreshold(thX, thY, ...)` — scalar or time-varying
- `render()` — creates figure/axes, draws everything, installs XLim listeners
- XLim listener installed via `addlistener(hAxes, 'XLim', 'PostSet', ...)` in render()
- Guard flag: `IsPropagating` prevents re-entrant XLim callbacks
- `LinkGroup` property enables synchronized zoom across instances via a persistent static registry
- `propagateXLim(newXLim)` — syncs XLim to all LinkGroup members
- Properties exposed: `hAxes`, `IsRendered`, `CachedXLim`, `FullXLim`, `IsPropagating`

### FastPlotFigure
- `tile(n)` → FastPlot for tile n (creates on first call)
- `axes(n)` → raw MATLAB axes for tile n
- `setTileSpan(n, [rowSpan colSpan])` — tile spanning
- `renderAll()` — renders all tiles, shows figure
- **NO `tilePanel()` method exists** — spec references it incorrectly

### Event (EventDetection)
- Direction field is `'high'` or `'low'` (NOT 'H', 'HH', 'L', 'LL', 'upper', 'lower')
- Has: `StartTime`, `EndTime`, `SensorName`, `ThresholdLabel`, `Direction`, `PeakValue`
- Does NOT have: `Key`, `Severity`, or a severity enum

### EventStore
- Constructor: `EventStore(filePath)` — takes a file path, NOT 'events.mat' directly loads events
- `getEvents()` — returns stored events
- `append(events)`, `save()`, `numEvents()`
- `EventStore.loadFile(filePath)` — static method for file-based loading
- NO `query('SensorKey', ...)` method exists

### Sensor (SensorThreshold)
- `Key`, `Name`, `X`, `Y`
- `ResolvedThresholds` — struct array with fields: `X`, `Y`, `Direction`, `Label`, `Color`, `LineStyle`
- `ThresholdRule.Direction` is `'upper'` or `'lower'`
- No `.Key` on resolved thresholds

## Dashboard Architecture (Task 5 — Deferred Rendering, e080bf2)
- `allocatePanels()` creates panels with placeholder uicontrols (Tag='placeholder'), no render call.
- `realizeWidget()` guards on `Realized` and valid `hPanel`, removes placeholder, calls render, sets `Realized=true`, `Dirty=false`.
- `realizeBatch(N)` prioritizes visible widgets, calls `drawnow` between batches.
- `onScrollRealize()` realizes newly-visible unrealized widgets on scroll.
- `onLiveTick` is gated on `w.Dirty && w.Realized && isWidgetVisible`.
- BUG (MAJOR): `rerenderWidgets()` does not reset `Realized=false` before calling `createPanels`. Since `realizeWidget` returns early if `Realized=true`, a rerender after `removeWidget` will silently skip any previously-realized widget.
- BUG (MINOR): `realizeWidget` sets `Dirty=false` unconditionally; widgets realized off-screen during initial batch enter live mode with `Dirty=false`, so the first tick skips them.
- ORDERING (MINOR): `OnScrollCallback` wired AFTER `realizeBatch` in `render()`. Safe in practice but semantically fragile.
- COSMETIC: `onScrollRealize(topRow, bottomRow)` args are unused; `isWidgetVisible` reads `Layout.VisibleRows` internally.
- TEST NAME: `testAllocatePanelsDoesNotCallRender` is misleading; it actually verifies post-`render()` realized state, not that `allocatePanels` skips rendering.

## Common Issues Found in Specs
1. Spec referenced non-existent `FastPlotFigure.tilePanel()` — actual method is `tile(n)` or `axes(n)`
2. Spec referenced non-existent `EventStore.query('SensorKey', ...)` — no such method
3. Event severity labels in spec ('H', 'HH', 'L', 'LL') don't match actual Event.Direction ('high'/'low')
4. Spec conflated `ThresholdRule.Direction` ('upper'/'lower') with event severity naming
5. XLim sync between panels: can reuse `IsPropagating` guard pattern from LinkGroup
