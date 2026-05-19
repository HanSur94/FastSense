<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a render-once, re-downsample-on-zoom architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re-downsamples only the visible range on every interaction. The library is built around a [[FastPlot|FastSense]] core, widget‑based dashboards via [[Dashboard Engine Guide|DashboardEngine]], and a unified Tag‑domain model for sensors, thresholds, and derived signals.

## Project Structure

```
FastPlot/
├── install.m                        # Path install + MEX compilation
├── libs/
│   ├── FastSense/                    # Core plotting engine
│   │   ├── FastSense.m               # Main class
│   │   ├── FastSenseGrid.m           # Dashboard layout
│   │   ├── FastSenseDock.m           # Tabbed container
│   │   ├── FastSenseToolbar.m        # Interactive toolbar
│   │   ├── FastSenseTheme.m          # Theme system
│   │   ├── FastSenseDataStore.m      # SQLite-backed chunked storage
│   │   ├── HoverCrosshair.m          # Hover crosshair & datatip
│   │   ├── SensorDetailPlot.m        # Sensor detail view with state bands
│   │   ├── NavigatorOverlay.m        # Minimap zoom navigator
│   │   ├── ConsoleProgressBar.m      # Progress indication
│   │   ├── binary_search.m           # Binary search utility
│   │   ├── build_mex.m               # MEX compilation script
│   │   └── private/                  # Internal algorithms + MEX sources
│   ├── SensorThreshold/              # Tag‑domain model (sensors, states, monitors, composites)
│   │   ├── SensorTag.m
│   │   ├── StateTag.m
│   │   ├── MonitorTag.m
│   │   ├── CompositeTag.m
│   │   ├── DerivedTag.m
│   │   ├── Tag.m                     # Abstract base
│   │   ├── TagRegistry.m             # Singleton catalog
│   │   ├── BatchTagPipeline.m        # Bulk raw‑data → per‑tag .mat
│   │   ├── LiveTagPipeline.m         # Timer‑driven live raw‑data pipeline
│   │   └── private/                  # Parsers, SQLite helpers
│   ├── Dashboard/                    # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m
│   │   ├── DashboardBuilder.m
│   │   ├── DashboardLayout.m
│   │   ├── DashboardSerializer.m
│   │   ├── DashboardTheme.m
│   │   ├── DashboardToolbar.m
│   │   ├── DashboardWidget.m         # Abstract widget base
│   │   ├── DashboardPage.m           # Multi‑page container
│   │   ├── FastSenseWidget.m
│   │   ├── GaugeWidget.m
│   │   ├── NumberWidget.m
│   │   ├── StatusWidget.m
│   │   ├── TextWidget.m
│   │   ├── TableWidget.m
│   │   ├── RawAxesWidget.m
│   │   ├── EventTimelineWidget.m
│   │   ├── GroupWidget.m             # Collapsible/tabbed widget groups
│   │   ├── MultiStatusWidget.m       # Grid of status indicators
│   │   ├── BarChartWidget.m
│   │   ├── ScatterWidget.m
│   │   ├── HeatmapWidget.m
│   │   ├── HistogramWidget.m
│   │   ├── ImageWidget.m
│   │   ├── ChipBarWidget.m
│   │   ├── DividerWidget.m
│   │   ├── IconCardWidget.m
│   │   ├── SparklineCardWidget.m
│   │   ├── MarkdownRenderer.m
│   │   ├── DetachedMirror.m          # Standalone live‑mirror window
│   │   └── TimeRangeSelector.m       # Slider with envelope & event bands
│   ├── EventDetection/               # Event detection and viewer
│   │   ├── Event.m
│   │   ├── EventStore.m
│   │   ├── EventBinding.m            # Many‑to‑many Event↔Tag registry
│   │   ├── EventViewer.m
│   │   ├── LiveEventPipeline.m
│   │   ├── NotificationService.m
│   │   ├── DataSource.m              # Abstract data source
│   │   ├── MatFileDataSource.m
│   │   ├── MockDataSource.m
│   │   ├── NotificationRule.m
│   │   └── generateEventSnapshot.m
│   └── Concurrency/                  # Thread‑safe coordination (optional)
│       ├── EventLog.m
│       ├── TagWriteCoordinator.m
│       ├── AtomicWriter.m
│       ├── FileLock.m
│       └── build_concurrency_mex.m
├── examples/                         # 40+ runnable examples
└── tests/                            # 30+ test suites
```

## Render Pipeline

1. User calls `render()` on a [[FastPlot|FastSense]] instance or a container ([[Dashboard|FastSenseGrid]], [[Dashboard Engine Guide|DashboardEngine]]).  
2. If not already parented, a figure and axes are created. Theme is applied (background, grid, font).  
3. All added lines, thresholds, bands, shaded regions, markers, and fills are validated (X monotonic, dimensions match).  
4. Data exceeding `MemoryLimit` may be switched to disk‑backed storage via [[FastSenseDataStore]].  
5. Downsampling buffers are allocated based on the axes’ pixel width.  
6. For each line: an initial downsample of the full data range using the chosen method (MinMax or LTTB) is performed, and a graphics line object is created.  
7. Threshold lines, violation markers, bands, shaded areas, and markers are drawn in z‑order.  
8. An XLim `PostSet` listener is installed for zoom/pan events; a YLim listener detects manual Y‑axis zoom.  
9. Axis limits are set with padding; auto‑limits are disabled.  
10. `drawnow` is called to display the initial view.

## Zoom/Pan Callback

Whenever the user zooms or pans:

1. The XLim listener fires.  
2. The new XLim is compared to a cached value; if unchanged, no work is done.  
3. For each line:  
   - Binary search (`binary_search` or its MEX version) locates the visible portion of the raw X vector — O(log N).  
   - The appropriate pyramid level with sufficient resolution is selected (see Lazy Multi‑Resolution Pyramid).  
   - If the selected pyramid level hasn't been built yet, it is constructed lazily.  
   - The visible range is downsampled to about 4,000 points (configurable).  
   - The line’s `XData`/`YData` are updated in place (dot‑notation for speed).  
4. Violation markers are recomputed, using a fused SIMD pixel‑culling step if MEX is available.  
5. If a `LinkGroup` is active, the new XLim is propagated to all other plots in the same group.  
6. `drawnow limitrate` caps display updates at ~20 FPS.

## Downsampling Algorithms

### MinMax (default)

For each pixel bucket the minimum and maximum Y values are retained. This preserves the signal envelope and extreme values. Complexity O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)

Visually optimal downsampling that preserves the shape of the signal by maximising the triangle area between consecutive buckets. Slightly slower than MinMax but better visual fidelity.

Both algorithms respect NaN gaps by treating contiguous non‑NaN regions independently.

## Lazy Multi‑Resolution Pyramid

**Problem:** at full zoom‑out with 50 M+ points, scanning all raw data is O(N).  

**Solution:** a pre‑computed MinMax pyramid with a configurable reduction factor (default 100× per level):

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100× reduction   (   500,000 points)
Level 2: 100× reduction   (     5,000 points)
```

When the user zooms, the coarsest level that still offers sufficient resolution is used. A full zoom‑out reads level 2 (~5 K points) and downsamples to ~4 K in under 1 ms.  
Levels are built lazily on first access — the first zoom‑out incurs a one‑time build cost (~70 ms with MEX); subsequent queries are instant.

## MEX Acceleration

Optional C MEX functions with SIMD intrinsics (AVX2 on x86‑64, NEON on ARM64) accelerate the hot path:

| Function | Speedup | Description |
|----------|---------|-------------|
| `binary_search_mex` | 10–20× | O(log n) visible‑range lookup |
| `minmax_core_mex` | 3–10× | Per‑pixel MinMax reduction |
| `lttb_core_mex` | 10–50× | Triangle area computation |
| `violation_cull_mex` | significant | Fused detection + pixel culling |
| `compute_violations_mex` | significant | Batch violation detection for `Sensor.resolve()` |
| `resolve_disk_mex` | significant | SQLite‑backed sensor resolution |
| `build_store_mex` | 2–3× | Bulk SQLite writer for DataStore init |
| `to_step_function_mex` | significant | SIMD step‑function conversion for thresholds |

All share a common `simd_utils.h` abstraction layer. When MEX is unavailable, identical pure‑MATLAB fallbacks are used automatically.

## Data Flow Architecture

### Core Data Path

```
Raw Data (X, Y arrays)
    ↓
FastSenseDataStore (optional, for large datasets)
    ↓
Downsampling Engine (MinMax / LTTB)
    ↓
Pyramid Cache (lazy multi‑resolution)
    ↓
Graphics Objects (line handles)
    ↓
Interactive Display
```

### Storage Modes

- **Memory mode** – X/Y arrays held directly in the MATLAB workspace.  
- **Disk mode** – Data chunked into an SQLite database via `FastSenseDataStore`.  
- **Auto mode** – The library switches to disk mode when the data size exceeds `MemoryLimit` (default 500 MB per line).

## Sensor Threshold Resolution (Tag‑Based Model)

The library uses a unified Tag domain model instead of the older `Sensor`/`StateChannel`/`ThresholdRule` classes. The main tag types are:

- **SensorTag** – holds raw X/Y sensor data.  
- **StateTag** – discrete state signals (ZOH lookup).  
- **MonitorTag** – produces a binary 0/1 alarm signal by evaluating a condition on a parent tag’s data. Supports hysteresis, minimum duration, and event emission.  
- **CompositeTag** – aggregates multiple `MonitorTag` or other `CompositeTag` children using logical (AND/OR/WORST/COUNT/MAJORITY/SEVERITY) or user‑defined functions.  
- **DerivedTag** – produces a continuous (X,Y) signal from one or more parent tags via a user‑supplied compute function.

Resolution of violations is performed on‑demand by `MonitorTag.getXY()` (lazy‑memoized) or `appendData()` (streaming). The underlying algorithm walks the parent’s grid and evaluates the condition function. For large datasets, the `FastSenseDataStore` can be used for disk‑backed storage, and MEX‑accelerated functions handle the vectorised comparisons.

Complexity: O(N) per monitor (a single pass over the parent’s data), with lazy evaluation so no work is done until data is needed.

## Disk‑Backed Data Storage

For datasets exceeding available memory (100 M+ points), `FastSenseDataStore` provides SQLite‑backed chunked storage:

1. Data is split into chunks (10 K–500 K points each, auto‑tuned).  
2. Each chunk is stored as a pair of typed BLOBs (X and Y) with X‑range metadata.  
3. On zoom/pan, only the chunks overlapping the visible range are loaded.  
4. A pre‑computed L1 MinMax pyramid provides instant zoom‑out.

The bulk‑write path uses `build_store_mex` — a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, eliminating thousands of individual SQLite round‑trips. If SQLite is unavailable, a binary file fallback is used automatically.

## Theme Inheritance

Themes cascade through a hierarchy:

```
Widget‑level override  →  Tile theme  →  Figure theme  →  'default' preset
```

Each level fills only the fields it specifies; unspecified fields inherit from the next level. The `DashboardTheme` function extends the standard `FastSenseTheme` with dashboard‑specific colours (widget backgrounds, toolbar, status colours, etc.).

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[[Dashboard|FastSenseGrid]]**: a simple tiled grid of `FastSense` instances, with synchronised live mode.  
- **[[Dashboard Engine Guide|DashboardEngine]]**: a full widget‑based dashboard supporting gauges, numbers, status indicators, tables, timelines, collapsible groups, tabbed groups, and a visual edit mode.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar       — Top toolbar (Sync, Live, Config, Export, Info, …)
├── DashboardLayout        — 24‑col responsive grid with scrollable canvas
├── DashboardTheme         — FastSenseTheme + dashboard‑specific fields
├── DashboardBuilder       — Edit mode overlay (drag/resize, palette, properties)
├── DashboardSerializer    — JSON save/load and .m script export
├── DashboardPage          — Multi‑page support (named tabs)
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget        — Bind to SensorTag, DataStore, or inline data
    ├── GaugeWidget            — Arc / donut / bar / thermometer gauge
    ├── NumberWidget           — Big number with trend arrow
    ├── StatusWidget           — Coloured dot (tag, threshold, or legacy sensor)
    ├── TextWidget             — Static label or header
    ├── TableWidget            — uitable display (data or events)
    ├── RawAxesWidget          — User‑supplied plot function
    ├── EventTimelineWidget    — Coloured event bars on a timeline
    ├── GroupWidget            — Collapsible panels, tabbed containers
    ├── MultiStatusWidget      — Grid of sensor status dots
    ├── ChipBarWidget          — Compact row of health‑status chips
    ├── IconCardWidget         — Mushroom‑card style with coloured icon + value
    ├── SparklineCardWidget    — KPI card with sparkline and delta
    ├── DividerWidget          — Horizontal separator line
    ├── BarChartWidget         — Vertical / horizontal bar chart
    ├── ScatterWidget          — Scatter plot (optionally colour‑coded)
    ├── HeatmapWidget          — Heatmap with configurable colormap
    ├── HistogramWidget        — Histogram with optional normal fit
    ├── ImageWidget            — Display an image (file or function)
    └── DetachedMirror         — Pop‑out a widget into a standalone live‑synced window
```

### Render Flow

1. `DashboardEngine.render()` creates the figure.  
2. `DashboardTheme` generates the complete theme struct.  
3. The `DashboardToolbar` is created at the top, followed by the time‑slider panel at the bottom (if `ShowTimePanel` is true).  
4. `DashboardLayout` computes grid positions, creates viewport/canvas/scrollbar, and allocates a panel for each widget.  
5. Each widget’s `render(parentPanel)` is called to populate its content.  
6. `updateGlobalTimeRange()` scans all widgets for data bounds and configures the time sliders.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:
1. The global time range is extended if new data has arrived.  
2. Each widget’s `refresh()` is called (tag‑bound widgets re‑read their parent tag’s data; legacy widgets poll their callbacks).  
3. The toolbar timestamp is updated.  
4. The slider’s preview envelope and event markers are recomputed.  

### Edit Mode

Clicking “Edit” in the toolbar creates a `DashboardBuilder` instance:
1. A palette sidebar shows available widget types.  
2. A properties panel shows the settings of the selected widget.  
3. Drag/resize overlays are added on top of each widget panel.  
4. Mouse callbacks handle drag and resize, snapping positions to the nearest column/row.

### Multi‑Page Support

`DashboardEngine` can contain multiple `DashboardPage` objects. The toolbar shows page tabs, and widgets are added to the active page. Layout is managed separately for each page; only one page is visible at a time.

### JSON Persistence

`DashboardSerializer` converts dashboards to and from JSON or a `.m` script. Function handles cannot be serialised, so tag‑based widgets store key strings and the tag’s kind, allowing reconstruction via `TagRegistry`. The serialisation uses a two‑phase process — first instantiating all tags, then resolving cross‑references (e.g., `MonitorTag`’s parent, `CompositeTag`’s children).

## Event Detection Architecture

The event detection system monitors thresholds in real time, creates rich `Event` objects, and optionally sends notifications.

### Core Components

```
LiveEventPipeline
├── MonitorTargets          — Map of tagKey → MonitorTag
├── DataSourceMap           — Maps sensor keys to data sources
├── EventStore              — Thread‑safe event persistence
├── NotificationService     — Rule‑based email alerts
└── EventViewer             — Interactive Gantt chart + filterable table
```

### Detection Flow

1. `LiveEventPipeline.runCycle()` polls data sources (e.g., `MatFileDataSource`).  
2. New data is pushed to the parent `SensorTag` via `updateData()`.  
3. Each `MonitorTag.appendData()` is called, which evaluates the condition on the new tail points, respecting hysteresis and minimum duration.  
4. Events are persisted atomically via `EventStore`.  
5. `NotificationService` may trigger emails with PNG snapshots of the event.  
6. Active `EventViewer` instances auto‑refresh.

### Cluster Mode (Optional)

When a `SharedRoot` is provided, event stores and monitor writes use a centralised SQLite database and per‑tag NDJSON logs, coordinated by `TagWriteCoordinator` and `AtomicWriter` from the `Concurrency` library. Lock contention causes a monitor to be skipped for one tick, never blocking the pipeline.

## Progress Indication

`ConsoleProgressBar` provides a single‑line progress bar with backspace‑based updates, supporting indentation for nested operations (e.g., dock → tabs → tiles). The `DashboardProgress` helper is used by `DashboardEngine` to show a similar line while realising widgets.

## Interactive Features

### Toolbars and Navigation

- **[[API Reference: FastPlot|FastSenseToolbar]]**: data cursor, crosshair, grid/legend toggles, autoscale, export, live mode, follow, metadata, violation toggle.  
- **DashboardToolbar**: Sync‑All, Live toggle, Config dialog, Reset, Export Image, Export Script, Info panel.  
- **HoverCrosshair**: a vertical line and multi‑line datatip that follows the mouse, showing interpolated values from all visible lines.  
- **NavigatorOverlay**: a minimap with a draggable zoom rectangle, used in `SensorDetailPlot`.

### Link Groups

Multiple `FastSense` instances can share synchronised zoom/pan by setting the same `LinkGroup` string. When one plot’s XLim changes, all linked plots update automatically.

### Detached Mirrors

Any dashboard widget can be “detached” into a standalone figure. The mirror is a deep copy (via `toStruct`/`fromStruct` with reference restoration) and stays synchronised with the original widget’s data, updating on every live tick.
