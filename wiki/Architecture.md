<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a render-once, re-downsample-on-zoom architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re-downsamples only the visible range on every interaction. All data is managed through a unified **Tag** domain model (v2.0) that provides lazy evaluation, invalidation cascades, and native integration with the downsampling pipeline.

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
│   │   ├── FastSenseDefaults.m       # Global defaults
│   │   ├── HoverCrosshair.m          # Hover-tracking crosshair
│   │   ├── NavigatorOverlay.m        # Minimap zoom navigator
│   │   ├── ConsoleProgressBar.m      # Progress indication
│   │   ├── binary_search.m           # Binary search utility
│   │   ├── build_mex.m               # MEX compilation script
│   │   ├── mex_stamp.m               # Fingerprint for build freshness
│   │   └── private/                  # Internal algorithms + MEX sources
│   ├── SensorThreshold/              # Tag-based domain model (v2.0)
│   │   ├── Tag.m                     # Abstract base
│   │   ├── SensorTag.m              # Raw time-series data
│   │   ├── StateTag.m               # Discrete states (ZOH)
│   │   ├── MonitorTag.m             # Binary derived from condition
│   │   ├── CompositeTag.m           # Aggregate multiple monitors
│   │   ├── DerivedTag.m             # Arbitrary computed series
│   │   ├── TagRegistry.m            # Singleton catalog
│   │   └── private/                  # Pipeline helpers (parser, writer)
│   ├── EventDetection/               # Event detection and viewer
│   │   ├── Event.m
│   │   ├── EventStore.m
│   │   ├── EventViewer.m
│   │   ├── LiveEventPipeline.m
│   │   ├── NotificationService.m
│   │   ├── NotificationRule.m
│   │   ├── EventBinding.m            # Event↔Tag many-to-many
│   │   ├── EventConfig.m
│   │   ├── DataSource.m              # Abstract data source
│   │   ├── DataSourceMap.m
│   │   ├── MatFileDataSource.m
│   │   ├── MockDataSource.m
│   │   └── private/
│   ├── Dashboard/                    # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m
│   │   ├── DashboardBuilder.m
│   │   ├── DashboardLayout.m
│   │   ├── DashboardSerializer.m
│   │   ├── DashboardTheme.m
│   │   ├── DashboardToolbar.m
│   │   ├── DashboardWidget.m         # Abstract base
│   │   ├── FastSenseWidget.m
│   │   ├── GaugeWidget.m
│   │   ├── NumberWidget.m
│   │   ├── StatusWidget.m
│   │   ├── TextWidget.m
│   │   ├── TableWidget.m
│   │   ├── RawAxesWidget.m
│   │   ├── EventTimelineWidget.m
│   │   ├── GroupWidget.m
│   │   ├── MultiStatusWidget.m
│   │   ├── BarChartWidget.m
│   │   ├── ScatterWidget.m
│   │   ├── HeatmapWidget.m
│   │   ├── HistogramWidget.m
│   │   ├── ImageWidget.m
│   │   ├── IconCardWidget.m
│   │   ├── ChipBarWidget.m
│   │   ├── SparklineCardWidget.m
│   │   ├── DividerWidget.m
│   │   ├── MarkdownRenderer.m
│   │   ├── TimeRangeSelector.m
│   │   └── severityColor.m
│   └── WebBridge/                    # TCP server for web visualization
│       ├── WebBridge.m
│       └── WebBridgeProtocol.m
├── examples/                         # 40+ runnable examples
└── tests/                            # 30+ test suites
```

## Render Pipeline

1.  User calls `render()`.
2.  Create figure/axes if not parented.
3.  Validate all data (X monotonic, dimensions match).
4.  Switch to disk storage mode if data exceeds `MemoryLimit` (auto mode).
5.  Allocate downsampling buffers based on axes pixel width.
6.  For each line: initial downsample of full range, create graphics object.
7.  Create threshold, band, shading, marker objects.
8.  Install XLim PostSet listener for zoom/pan events.
9.  Set axis limits, disable auto-limits.
10. `drawnow` to display.

## Zoom/Pan Callback

When the user zooms or pans:

1.  XLim listener fires.
2.  Compare new XLim to cached value (skip if unchanged).
3.  For each line:
    *   Binary search visible X range — O(log N).
    *   Select pyramid level with sufficient resolution.
    *   Build pyramid level lazily if needed.
    *   Downsample visible range to ~4,000 points.
    *   Update `hLine.XData`/`YData` (dot notation for speed).
4.  Recompute violation markers (fused SIMD with pixel culling).
5.  If LinkGroup active: propagate XLim to linked plots.
6.  `drawnow limitrate` (caps display at 20 FPS).

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket, keep the minimum and maximum Y values. Preserves signal envelope and extreme values. Fast O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)
Visually optimal downsampling that preserves signal shape by maximizing triangle area between consecutive buckets. Better visual fidelity but slightly slower.

Both algorithms handle NaN gaps by segmenting contiguous non-NaN regions independently.

## Lazy Multi-Resolution Pyramid

Problem: At full zoom-out with 50M+ points, scanning all data is O(N).

Solution: Pre-computed MinMax pyramid with configurable reduction factor (default 100× per level):

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100× reduction   (   500,000 points)
Level 2: 100× reduction   (     5,000 points)
```

On zoom, the coarsest level with sufficient resolution is selected. Full zoom-out reads level 2 (5K points) and downsamples to ~4K in under 1 ms.

Levels are built lazily on first access — the first zoom-out pays a one-time build cost (~70 ms with MEX), subsequent queries are instant.

## MEX Acceleration

Optional C MEX functions with SIMD intrinsics (AVX2 on x86_64, NEON on arm64). The list below reflects the actual sources compiled by `build_mex()`:

| Function | Speedup | Description |
|----------|---------|-------------|
| `binary_search_mex` | 10–20× | O(log n) visible range lookup |
| `minmax_core_mex` | 3–10× | Per-pixel MinMax reduction |
| `lttb_core_mex` | 10–50× | Triangle area computation |
| `violation_cull_mex` | significant | Fused detection + pixel culling |
| `compute_violations_mex` | significant | Batch violation detection for `resolve()` |
| `resolve_disk_mex` | significant | SQLite disk‑based sensor resolution |
| `build_store_mex` | 2–3× | Bulk SQLite writer for DataStore init |
| `to_step_function_mex` | significant | SIMD step‑function conversion for thresholds |
| `mksqlite` | – | SQLite3 MEX interface (bundled `sqlite3.c`) |

All share a common `simd_utils.h` abstraction layer. If MEX is unavailable, pure‑MATLAB implementations are used with identical behavior.

## Data Flow Architecture

### Core Data Path

```
Tag.getXY()  (lazy, memoized)
    ↓
Downsampling Engine (MinMax/LTTB)
    ↓
Pyramid Cache (lazy multi‑resolution)
    ↓
Graphics Objects (line handles)
    ↓
Interactive Display
```

### Domain Model (v2.0 Tags)

The core data is represented by a **Tag** hierarchy — abstract base with subclasses:

| Subclass | Data produced | Typical use |
|----------|--------------|-------------|
| `SensorTag` | Raw (X, Y) from measurement | Primary sensor readings |
| `StateTag` | Discrete states via ZOH | Machine modes, recipes |
| `MonitorTag` | 0/1 binary series from condition | Thresholds, alarms |
| `CompositeTag` | 0/1 from child aggregation (AND, OR, …) | Multi‑condition alarms |
| `DerivedTag` | Arbitrary computed (X, Y) | Processed metrics |

All Tags implement `getXY()`, `valueAt(t)`, `getTimeRange()`, `getKind()`, `toStruct()`, and a static `fromStruct()`. **Listener chains** automatically invalidate downstream monitors when a parent’s data changes (`updateData` → `invalidate` cascade). This replaces the older `Sensor.resolve()` approach with a fully lazy, composable data flow.

### Storage Modes

- **Memory mode**: X/Y arrays held in MATLAB workspace.
- **Disk mode**: Data chunked into SQLite database via `FastSenseDataStore`.
- **Auto mode**: Switches to disk when data exceeds `MemoryLimit` (default 500 MB).

`FastSenseDataStore` also provides **MonitorTag persistence** — when `Persist = true` and a `DataStore` is attached, the computed 0/1 signal is cached on disk with a quad‑signature staleness check (`parent_key`, `num_points`, `parent_xmin`, `parent_xmax`).

## Sensor Threshold Resolution (Lazy Evaluation)

Threshold violation detection is now embodied in **`MonitorTag`** and its aggregation cousins (`CompositeTag`, `DerivedTag`). The classic “threshold line” in FastSense plots a stored threshold value directly, while the underlying logic that produces event‑ready binary signals follows these steps:

1.  A **`MonitorTag`** is created with a `Parent` (typically a `SensorTag`) and a `ConditionFn` (e.g., `@(x,y) y > threshold`).
2.  When `getXY()` is called, the tag lazily evaluates the condition on the parent’s native grid → produces a 0/1 vector.
3.  If a `MinDuration` is set, runs shorter than that value are filtered out (debouncing).
4.  Optional `AlarmOffConditionFn` provides hysteresis.
5.  The `EventStore` and `OnEventStart`/`OnEventEnd` callbacks emit events when the binary signal changes state.
6.  **Invalidation** is automatic: calling `parent.updateData()` or `parent.appendData()` fires a listener cascade that marks the `MonitorTag` dirty; the next `getXY()` recomputes only the affected portion.

**Complexity**: O(N) for the first evaluation, where N = length of parent’s data. Incremental appends (`appendData`) avoid full recomputation, preserving the FSM state across the boundary. `CompositeTag` and `DerivedTag` provide higher‑order compositions without materialising intermediate full grids if not needed.

## Disk-Backed Data Storage

For datasets exceeding available memory (100M+ points), `FastSenseDataStore` provides SQLite‑backed chunked storage:

1.  Data is split into chunks (~10K–500K points each, auto‑tuned).
2.  Each chunk stored as a pair of typed BLOBs (X and Y) with X‑range metadata.
3.  On zoom/pan, only chunks overlapping the visible range are loaded.
4.  Pre‑computed L1 MinMax pyramid for instant zoom‑out.

The bulk write path uses `build_store_mex` — a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing ~20K mksqlite round‑trips.

If SQLite is unavailable, a binary file fallback is used automatically.

## Theme Inheritance

```
Element override  >  Tile theme  >  Figure theme  >  'default' preset
```

Each level fills in only the fields it specifies; unspecified fields cascade from the next level.

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[FastSenseGrid]**: Simple tiled grid of FastSense instances with synchronised live mode.
- **[DashboardEngine]**: Full widget‑based dashboard with gauges, numbers, status indicators, tables, timelines, and edit mode.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar      — Top toolbar (Live, Edit, Save, Export, Sync)
├── DashboardLayout       — 24‑column responsive grid with scrollable canvas
├── DashboardTheme        — FastSenseTheme + dashboard‑specific fields
├── DashboardBuilder      — Edit mode overlay (drag/resize, palette, properties)
├── DashboardSerializer   — JSON save/load and .m script export
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (Tag/DataStore/inline)
    ├── GaugeWidget            — Arc/donut/bar/thermometer gauge
    ├── NumberWidget            — Big number with trend arrow
    ├── StatusWidget           — Coloured dot indicator
    ├── TextWidget             — Static label or header
    ├── TableWidget            — uitable display
    ├── RawAxesWidget          — User‑supplied plot function
    ├── EventTimelineWidget    — Coloured event bars on timeline
    ├── GroupWidget            — Collapsible panels, tabbed containers
    ├── MultiStatusWidget      — Grid of sensor status dots
    ├── ChipBarWidget          — Horizontal strip of mini status chips
    ├── IconCardWidget         — Compact icon + value card
    ├── SparklineCardWidget    — KPI card with inline sparkline
    ├── DividerWidget          — Horizontal section divider
    └── HeatmapWidget, HistogramWidget, ImageWidget, ScatterWidget,
        BarChartWidget, MarkdownRenderer
```

### Render Flow

1.  `DashboardEngine.render()` creates the figure.
2.  `DashboardTheme(preset)` generates the full theme struct.
3.  `DashboardToolbar` creates the top toolbar panel.
4.  Time control panel (dual sliders) is created at the bottom (hidden if `ShowTimePanel = false`).
5.  `DashboardLayout.createPanels()` computes grid positions, creates viewport/canvas/scrollbar, and creates a uipanel per widget.
6.  Each widget’s `render(parentPanel)` is called to populate its panel.
7.  `updateGlobalTimeRange()` scans widgets for data bounds and configures the time sliders.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:
1.  `updateLiveTimeRange()` expands time bounds from new data.
2.  Each widget’s `refresh()` is called (sensor‑bound widgets re‑read `Tag.getXY()`).
3.  The toolbar timestamp label is updated.
4.  Current slider positions are re‑applied to the updated time range.

### Edit Mode

Clicking “Edit” in the toolbar creates a `DashboardBuilder` instance:
1.  A palette sidebar (left) shows widget type buttons.
2.  A properties panel (right) shows selected widget settings.
3.  Drag/resize overlays are added on top of each widget panel.
4.  The content area narrows to accommodate sidebars.
5.  Mouse move/up callbacks handle drag and resize interactions.
6.  Grid snap rounds positions to the nearest column/row.

### JSON Persistence

`DashboardSerializer` handles round‑trip serialisation:
- **Save:** each widget’s `toStruct()` produces a plain struct with type, title, position, and source. The struct is encoded to JSON with heterogeneous widget arrays assembled manually (MATLAB’s `jsonencode` cannot handle cell arrays of mixed structs).
- **Load:** JSON is decoded, widgets array is normalised to cell, and `configToWidgets()` dispatches to each widget class’s `fromStruct()` static method. An optional `SensorResolver` function handle re‑binds Tag objects by key (via `TagRegistry`).
- **Export script:** generates a `.m` file with `DashboardEngine` constructor calls and `addWidget` calls for each widget.

## Event Detection Architecture

The event detection system provides real‑time threshold violation monitoring (now underpinned by `MonitorTag` evaluation) with configurable notifications and data persistence.

### Core Components

```
LiveEventPipeline
├── MonitorTargets        — containers.Map of key → MonitorTag
├── DataSourceMap         — Maps sensor keys to data sources
├── EventStore            — Thread‑safe .mat file persistence
├── NotificationService   — Rule‑based email alerts
└── EventViewer          — Interactive Gantt chart + filterable table
```

### Data Sources

- **MatFileDataSource**: Polls .mat files for new data.
- **MockDataSource**: Generates realistic test signals with violations.
- **Custom sources**: Implement `DataSource.fetchNew()` interface.

### Event Detection Flow (Tag‑based)

1.  `LiveEventPipeline.runCycle()` polls all data sources.
2.  New data is pushed to the corresponding `SensorTag::updateData()`.
3.  Each `MonitorTag` registered in `MonitorTargets` is then updated via `appendData()` — this triggers the lazy recomputation logic, maintaining the FSM state and emitting events.
4.  Events are stored via `EventStore.append()` (atomic .mat writes).
5.  `NotificationService` sends rule‑based email alerts with plot snapshots.
6.  Active `EventViewer` instances auto‑refresh to show new events.

### Escalation Logic

When `EscalateSeverity` is enabled, events are promoted to the highest violated threshold: a violation starting at “Warning” level may escalate to “Alarm” if a stricter threshold is also crossed. The event retains the highest severity level encountered.

### Event–Tag Binding

`EventBinding` provides a singleton many‑to‑many registry between event IDs and tag keys. Events can be queried by tag (forward and reverse indexes) for use in charts and timeline overlays.

## Progress Indication

`ConsoleProgressBar` provides hierarchical progress feedback:
- Single‑line ASCII/Unicode bars with backspace‑based updates.
- Indentation support for nested operations (e.g., dock → tabs → tiles).
- Freeze/finish modes for permanent status lines.

`DashboardProgress` wraps this for dashboard render passes, emitting a self‑updating line as widgets are realised.

## Interactive Features

### Toolbars and Navigation
- **[FastSenseToolbar]**: Data cursor, crosshair, grid toggle, autoscale, export, live mode.
- **DashboardToolbar**: Live toggle, edit mode, save/export, name editing.
- **NavigatorOverlay**: Minimap with draggable zoom rectangle for `SensorDetailPlot`.

### Link Groups
Multiple FastSense instances can share synchronised zoom/pan via `LinkGroup` strings. When one plot’s XLim changes, all plots in the same group update automatically.

### Hover Crosshair
The `HoverCrosshair` class attaches a vertical tracking line and multi‑line datatip to a rendered FastSense plot. It chains with existing figure callbacks, coexisting with toolbar crosshair and navigator drag.
