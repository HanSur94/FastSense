<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a **render-once, re-downsample-on-zoom** architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re-downsamples only the visible range on every interaction. The library is organised into several layers:

- **Core plotting engine** (`FastSense`) – high-performance line rendering with dynamic downsampling and multi-resolution cache.
- **Dashboard system** (`DashboardEngine`, `DashboardWidget`) – widget‑based dashboards with live mode, edit mode, and JSON persistence.
- **Sensor / threshold domain model** (`Tag` hierarchy) – typed time‑series objects with listener‑driven reactivity.
- **Event detection pipeline** (`LiveEventPipeline`, `EventStore`) – real‑time violation monitoring and notification.
- **Utility layer** – progress bars, themes, toolbars, crosshair, navigator.

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
│   │   ├── SensorDetailPlot.m        # Sensor detail view with state bands
│   │   ├── NavigatorOverlay.m        # Minimap zoom navigator
│   │   ├── ConsoleProgressBar.m      # Progress indication
│   │   ├── binary_search.m           # Binary search utility
│   │   ├── build_mex.m               # MEX compilation script
│   │   └── private/                  # Internal algorithms + MEX sources
│   ├── SensorThreshold/              # Sensor and threshold system
│   │   ├── Sensor.m
│   │   ├── StateChannel.m
│   │   ├── ThresholdRule.m
│   │   ├── SensorRegistry.m
│   │   ├── ExternalSensorRegistry.m
│   │   └── private/                  # Resolution algorithms
│   ├── EventDetection/               # Event detection and viewer
│   │   ├── Event.m
│   │   ├── EventDetector.m
│   │   ├── EventViewer.m
│   │   ├── LiveEventPipeline.m
│   │   ├── NotificationService.m
│   │   ├── EventStore.m
│   │   ├── EventConfig.m
│   │   ├── IncrementalEventDetector.m
│   │   ├── DataSource.m              # Abstract data source
│   │   ├── MatFileDataSource.m       # File-based data source
│   │   ├── MockDataSource.m          # Test data generation
│   │   ├── NotificationRule.m        # Email notification rules
│   │   └── private/                  # Event grouping algorithms
│   ├── Dashboard/                    # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m
│   │   ├── DashboardBuilder.m
│   │   ├── DashboardLayout.m
│   │   ├── DashboardSerializer.m
│   │   ├── DashboardTheme.m
│   │   ├── DashboardToolbar.m
│   │   ├── DashboardWidget.m         # Abstract widget base
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
│   │   └── MarkdownRenderer.m        # HTML conversion for info panels
│   └── WebBridge/                    # TCP server for web visualization
│       ├── WebBridge.m
│       └── WebBridgeProtocol.m
├── examples/                         # 40+ runnable examples
└── tests/                            # 30+ test suites
```

## Render Pipeline

1. User calls `render()` (on [`FastSense`](API%20Reference:%20FastPlot) instance).
2. Creates figure and axes if `ParentAxes` is empty.
3. Validates data (monotonic X, matching dimensions).
4. If total data exceeds `MemoryLimit`, offloads to disk storage via `FastSenseDataStore` (see [Disk‑Backed Data Storage](#disk-backed-data-storage)).
5. Allocates downsampling buffers based on axes pixel width and `DownsampleFactor`.
6. For each line:
   - Initial downsample of the full X‑range using `MinMax` or `LTTB` algorithm.
   - Creates a graphics line handle (`hLine`).
7. Creates threshold, band, shading, and marker objects.
8. Installs an XLim `PostSet` listener on the axes to handle zoom/pan events.
9. Sets axis limits (auto‑scaled with 5% padding), disables automatic limit management.
10. Calls `drawnow` to display.

## Zoom / Pan Callback

When the user zooms or pans:

1. **XLim listener fires**.
2. New XLim is compared to the cached value; if unchanged, the callback returns immediately.
3. For each line:
   - **Binary search** (`binary_search`) locates the visible portion of the raw data – O(log N). If compiled, `binary_search_mex` is used (10–20× speedup).
   - A **pyramid level** with sufficient resolution is selected (see [Lazy Multi‑Resolution Pyramid](#lazy-multi-resolution-pyramid)).
   - If the level hasn’t been built yet, it is constructed **lazily**.
   - The visible range is downsampled to approximately `DownsampleFactor * pixelWidth` points (default target ~4000 points).
   - `hLine.XData` and `hLine.YData` are updated via dot‑notation (fast vectorised assignment).
4. Violation markers (if thresholds are present) are recomputed. A SIMD‑accelerated pass (`violation_cull_mex`) fuses detection with pixel culling.
5. If `LinkGroup` is active, the new XLim is propagated to all linked plots.
6. `drawnow limitrate` caps the display update rate at 20 FPS.

```
User zoom/pan
    → XLim listener
        → binary search visible range  (O(log n), optionally MEX)
        → select / lazily build pyramid level
        → downsample visible data (~4K pts)
        → update line handles
        → recompute violations
        → propagate to linked plots
        → drawnow limitrate
```

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket, the **minimum and maximum Y** values are retained. This preserves the signal envelope and extreme values. Complexity is O(N/bucket) per bucket. The MEX kernel `minmax_core_mex` achieves a 3–10× speedup over pure MATLAB.

### LTTB (Largest Triangle Three Buckets)
A visually optimal downsampling that preserves the overall signal shape. It selects point that maximises the triangle area between consecutive buckets. Slightly slower than MinMax but produces better visual fidelity. The MEX kernel `lttb_core_mex` yields a 10–50× speedup.

Both algorithms handle **NaN gaps** by segmenting contiguous non‑NaN regions and processing each segment independently.

## Lazy Multi‑Resolution Pyramid

**Problem:** At full zoom‑out with 50M+ points, scanning all data is O(N).

**Solution:** A pre‑computed MinMax pyramid with a configurable reduction factor (`PyramidReduction`, default 100).

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100× reduction   (   500,000 points)
Level 2: 100× reduction   (     5,000 points)
```

On zoom, the **coarsest level** with at least `(visiblePoints * DownsampleFactor)` data points is selected. At full zoom‑out, level 2 (5K points) is loaded and then downsampled to the target ~4K points in under 1 ms.

Levels are built **lazily** on first access. The first zoom‑out pays a one‑time build cost (~70 ms with MEX); subsequent queries are instantaneous.

## MEX Acceleration

Optional C MEX functions with SIMD intrinsics (AVX2 on x86‑64, NEON on ARM64). All share a common abstraction layer in `simd_utils.h`. If MEX is unavailable, pure‑MATLAB implementations are used with identical behaviour.

| Function                | Speedup   | Description                               |
|-------------------------|-----------|-------------------------------------------|
| `binary_search_mex`     | 10–20×    | O(log n) visible range lookup             |
| `minmax_core_mex`       | 3–10×     | Per‑pixel MinMax reduction                |
| `lttb_core_mex`         | 10–50×    | Triangle area computation for LTTB        |
| `violation_cull_mex`    | significant | Fused detection + pixel culling         |
| `compute_violations_mex`| significant | Batch violation detection for `resolve()` |
| `resolve_disk_mex`      | significant | SQLite disk‑based sensor resolution       |
| `build_store_mex`       | 2–3×      | Bulk SQLite writer for DataStore initialisation |
| `to_step_function_mex`  | significant | SIMD step‑function conversion for thresholds |

Compilation is handled by `build_mex.m`. It auto‑detects architecture and compiler, retries with SSE2 fallback if AVX2 fails, and copies shared MEX files into the `SensorThreshold/private` directory. A deterministic fingerprint (`mex_stamp`) prevents unnecessary recompilation during `install`.

## Data Flow Architecture

### Core Data Path
```
Raw Data (X, Y arrays)
    ↓
[FastSenseDataStore] (optional, for large datasets)
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
- **Memory mode**: X/Y arrays held in MATLAB workspace.
- **Disk mode**: Data chunked into an SQLite database via `FastSenseDataStore` (see [Disk‑Backed Data Storage](#disk-backed-data-storage)). Only chunks overlapping the visible range are loaded.
- **Auto mode**: Switches to disk when data exceeds `MemoryLimit` (default 500 MB).

## Sensor Threshold Resolution

Threshold resolution in the Tag‑based domain model uses a **segment‑based algorithm**:

1. Collect all state‑change timestamps from all `StateChannel` / `StateTag` objects.
2. For each segment between state changes:
   - Evaluate which `ThresholdRule` objects match the current state.
   - Group rules with identical conditions.
3. Assign threshold values per segment.
4. Detect violations using SIMD‑accelerated comparison.

Complexity is O(S × R) where S = number of state segments and R = number of rules, instead of O(N × R) per‑point evaluation.

## Disk‑Backed Data Storage

For datasets exceeding available memory (100M+ points), `FastSenseDataStore` provides SQLite‑backed chunked storage:

1. Data is split into chunks (~10K–500K points each, auto‑tuned).
2. Each chunk stored as a pair of typed BLOBs (X and Y) with indexed X‑range metadata.
3. On zoom/pan, only chunks overlapping the visible range are loaded and trimmed to the exact view window.
4. A pre‑computed L1 MinMax pyramid enables instant zoom‑out.

**Bulk write path** uses `build_store_mex`, a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing tens of thousands of `mksqlite` round‑trips.

Additional data columns (cell, char, logical, categorical) can be attached via `addColumn` / `getColumnRange`.

If `mksqlite` (the bundled SQLite3 MEX interface) is unavailable, a **binary file fallback** is used automatically.

## Theme Inheritance

```
Element overrides  ➜  Tile theme  ➜  Figure theme  ➜  'light' preset
```

Each level fills in only the fields it specifies; unspecified fields cascade from the next level. The cascade is implemented by `FastSenseTheme` and `DashboardTheme`, where a base preset is merged with a user‑supplied struct or name‑value pairs. Dashboard‑specific fields (widget background, toolbar colours, etc.) are appended on top of the common `FastSenseTheme` struct.

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[[Dashboard|FastSenseGrid]]**: Simple tiled grid of `FastSense` instances with synchronised live mode.
- **[[Dashboard Engine Guide|DashboardEngine]]**: Full widget‑based dashboard with gauges, numbers, status indicators, tables, timelines, and an interactive edit mode.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar      — Top toolbar (Live, Edit, Save, Export, Sync, Info)
├── DashboardLayout       — 24‑column responsive grid with scrollable canvas
├── DashboardTheme        — FastSenseTheme + dashboard‑specific fields
├── DashboardBuilder      — Edit mode overlay (drag/resize, palette, properties)
├── DashboardSerializer   — JSON save/load and .m script export
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (Sensor/DataStore/inline)
    ├── GaugeWidget            — Arc/donut/bar/thermometer gauge
    ├── NumberWidget            — Big number with trend arrow
    ├── StatusWidget           — Colored dot indicator
    ├── TextWidget             — Static label or header
    ├── TableWidget            — uitable display
    ├── RawAxesWidget          — User‑supplied plot function
    ├── EventTimelineWidget    — Colored event bars on timeline
    ├── GroupWidget            — Collapsible panels, tabbed containers
    ├── MultiStatusWidget      — Grid of sensor status dots
    ├── IconCardWidget         — Compact mushroom‑card display
    ├── SparklineCardWidget    — KPI card with mini sparkline
    ├── ChipBarWidget          — Horizontal row of status chips
    ├── DividerWidget          — Horizontal divider line
    ├── BarChartWidget         — Vertical/horizontal bar chart
    ├── ScatterWidget          — X‑Y scatter plot
    ├── HeatmapWidget          — 2D heatmap
    ├── HistogramWidget        — Histogram with optional normal fit
    └── ImageWidget            — Static image display
```

### Render Flow

1. `DashboardEngine.render()` creates the figure.
2. `DashboardTheme(preset)` generates the full theme struct.
3. `DashboardToolbar` creates the top toolbar panel (and optional page tabs in multi‑page mode).
4. Time control panel (`TimeRangeSelector`) is created at the bottom.
5. `DashboardLayout.createPanels()` computes grid positions, creates viewport/canvas/scrollbar, and allocates a `uipanel` for each widget.
6. Each widget’s `render(parentPanel)` is called to populate its panel.
7. `updateGlobalTimeRange()` scans widgets for data bounds and configures the time sliders.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:
1. `updateLiveTimeRange()` expands time bounds from new data without resetting the slider selection.
2. Each widget’s `refresh()` is called. Sensor‑bound widgets re‑read `Sensor.Y(end)` (or use the Tag‑based `updateData` path for incremental refresh).
3. The toolbar timestamp label is updated.
4. The slider ranges are repositioned to keep the view consistent.

### Edit Mode

Clicking “Edit” in the toolbar creates a `DashboardBuilder` instance:
1. A palette sidebar (left) shows widget type buttons.
2. A properties panel (right) shows the selected widget’s settings.
3. Drag/resize overlays are added on top of each widget panel.
4. Mouse callbacks handle repositioning and resizing with grid snap.
5. Editing operations are driven by the `DashboardLayout` for coordinate calculations.

### JSON Persistence

`DashboardSerializer` handles round‑trip serialisation:
- **Save:** each widget’s `toStruct()` produces a plain struct with `type`, `title`, `position`, and source information. Heterogeneous widget arrays are assembled manually into JSON (MATLAB’s `jsonencode` cannot handle cell arrays of mixed structs).
- **Load:** JSON is decoded, widget arrays are normalised to cell, and `configToWidgets()` dispatches to each widget class’s static `fromStruct()`. An optional `SensorResolver` function handle re‑binds `Sensor` objects by name. For `Tag`‑based widgets, a two‑phase deserialisation is used (`fromStruct` then `resolveRefs`) to resolve cross‑references.
- **Export script:** generates a `.m` file with `DashboardEngine` constructor calls and `addWidget` calls for each widget, including multi‑page support.

## Event Detection Architecture

The event detection system provides real‑time threshold violation monitoring with configurable notifications and data persistence.

### Core Components
```
LiveEventPipeline
├── DataSourceMap          — Maps sensor keys to data sources
├── IncrementalEventDetector — Tracks per‑sensor state and open events
├── EventStore            — Thread‑safe .mat file persistence
├── NotificationService   — Rule‑based email alerts
└── EventViewer          — Interactive Gantt chart + filterable table
```

### Data Sources
- **MatFileDataSource**: Polls .mat files for new data.
- **MockDataSource**: Generates realistic test signals with violations.
- **Custom sources**: Implement `DataSource.fetchNew()`.

### Event Detection Flow
1. `LiveEventPipeline.runCycle()` polls all data sources.
2. New data is passed to `IncrementalEventDetector.process()`.
3. Sensor state is evaluated via `Sensor.resolve()`.
4. Violations are grouped into events with debouncing (`MinDuration`).
5. Events are stored via `EventStore.append()` (atomic .mat writes).
6. `NotificationService` sends rule‑based email alerts with plot snapshots.
7. Active `EventViewer` instances auto‑refresh to show new events.

### Escalation Logic
When `EscalateSeverity` is enabled, events are promoted to the highest violated threshold:
- A violation starts at “Warning” level.
- If an “Alarm” threshold is also crossed, the event is escalated to “Alarm”.
- The event retains the highest severity level encountered.

## Progress Indication

`ConsoleProgressBar` provides hierarchical progress feedback in the command window:
- Single‑line ASCII/Unicode bars with backspace‑based updates.
- Indentation support for nested operations (e.g., dock → tabs → tiles).
- `freeze` / `finish` methods create permanent status lines.

`DashboardProgress` adapts progress reporting for dashboard render passes, showing per‑widget progress in interactive sessions.

## Interactive Features

### Toolbars and Navigation
- **[[API Reference: FastPlot|FastSenseToolbar]]**: Data cursor, crosshair, grid/legend toggles, autoscale, PNG/CSV export, live mode, metadata display.
- **DashboardToolbar**: Live toggle (with blue border), Follow (auto‑pan), Edit mode, Reset, Config, Image export, Info.
- **NavigatorOverlay**: Minimap with draggable zoom rectangle for `SensorDetailPlot`.

### Link Groups
Multiple `FastSense` instances can share synchronised zoom/pan via a common `LinkGroup` string. When one plot’s XLim changes, all plots in the same group update automatically.

### Hover Crosshair
`HoverCrosshair` provides a vertical cursor with multi‑line datatip showing interpolated Y values for every visible line. It chains with existing figure motion callbacks so it coexists with other interactive features.

---

This architecture forms the backbone of FastPlot, enabling ultra‑fast rendering of large time series while maintaining a rich set of interactive and analytical capabilities.
