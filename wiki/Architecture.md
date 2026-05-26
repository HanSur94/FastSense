<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a render‑once, re‑downsample‑on‑zoom architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re‑downsamples only the visible range on every interaction. A dynamic downsampling engine, lazy multi‑resolution pyramid, and optional MEX acceleration ensure that datasets from a few hundred to over 100 million points remain responsive during pan and zoom.

## Project Structure

```
FastPlot/
├── install.m                        # Path install + MEX compilation
├── libs/
│   ├── FastSense/                    # Core plotting engine
│   │   ├── FastSense.m               # Main plotting class
│   │   ├── FastSenseGrid.m           # Tiled grid layout
│   │   ├── FastSenseDock.m           # Tabbed container
│   │   ├── FastSenseToolbar.m        # Interactive toolbar
│   │   ├── FastSenseTheme.m          # Theme system
│   │   ├── FastSenseDataStore.m      # SQLite‑backed chunked storage
│   │   ├── SensorDetailPlot.m        # Sensor detail view
│   │   ├── NavigatorOverlay.m        # Minimap zoom navigator
│   │   ├── ConsoleProgressBar.m      # Progress indication
│   │   ├── binary_search.m           # Binary search utility
│   │   ├── HoverCrosshair.m         # Hover cross‑hair
│   │   ├── build_mex.m              # MEX compilation script
│   │   └── private/                  # Internal algorithms + MEX sources
│   ├── SensorThreshold/              # Tag‑based monitoring + pipeline
│   │   ├── Tag.m                     # Abstract Tag base
│   │   ├── SensorTag.m              # Sensor data tag
│   │   ├── StateTag.m              # Discrete state tag
│   │   ├── MonitorTag.m             # 0/1 threshold monitor
│   │   ├── CompositeTag.m           # Composite aggregation
│   │   ├── DerivedTag.m             # Derived signal tag
│   │   ├── TagRegistry.m            # Singleton catalog
│   │   ├── BatchTagPipeline.m       # Batch raw‑data ingestion
│   │   ├── LiveTagPipeline.m        # Timer‑driven polling pipeline
│   │   └── private/                  # Parse/format + MEX wrappers
│   ├── EventDetection/               # Event detection and viewer
│   │   ├── Event.m                  # Event data object
│   │   ├── EventStore.m             # Persistence / cluster‑mode store
│   │   ├── EventBinding.m           # Event↔Tag many‑to‑many registry
│   │   ├── EventViewer.m            # Gantt viewer
│   │   ├── LiveEventPipeline.m      # Real‑time violation pipeline
│   │   ├── NotificationService.m     # Email alerts
│   │   ├── DataSource.m             # Abstract data source
│   │   ├── MatFileDataSource.m      # .mat file polling
│   │   ├── MockDataSource.m          # Test data generator
│   │   └── private/                  # Grouping algorithms
│   ├── Dashboard/                    # Dashboard engine
│   │   ├── DashboardEngine.m         # Orchestrator
│   │   ├── DashboardBuilder.m        # Edit‑mode drag‑resize
│   │   ├── DashboardLayout.m        # 24‑column responsive grid
│   │   ├── DashboardSerializer.m   # JSON / .m export
│   │   ├── DashboardTheme.m          # Theme for dashboard
│   │   ├── DashboardToolbar.m       # Top toolbar
│   │   ├── DashboardWidget.m        # Abstract widget base
│   │   ├── FastSenseWidget.m        # FastSense‑bound widget
│   │   ├── GaugeWidget.m            # Arc / donut / bar gauge
│   │   ├── NumberWidget.m           # Big number
│   │   ├── StatusWidget.m           # Colored dot indicator
│   │   ├── TextWidget.m             # Static label
│   │   ├── TableWidget.m            # uitable wrapper
│   │   ├── RawAxesWidget.m          # User‑supplied plot function
│   │   ├── EventTimelineWidget.m    # Event Gantt widget
│   │   ├── GroupWidget.m            # Collapsible / tabbed groups
│   │   ├── MultiStatusWidget.m      # Grid of status dots
│   │   ├── SparklineCardWidget.m    # KPI with mini sparkline
│   │   ├── ChipBarWidget.m        # Health chip row
│   │   ├── IconCardWidget.m        # Mushroom‑style card
│   │   ├── BarChartWidget.m         # Bar chart
│   │   ├── ScatterWidget.m          # Scatter plot
│   │   ├── HeatmapWidget.m          # heatmap
│   │   ├── HistogramWidget.m        # Histogram
│   │   ├── ImageWidget.m            # Image display
│   │   ├── DividerWidget.m         # Horizontal divider
│   │   ├── MarkdownRenderer.m      # Info panel HTML
│   │   └── TimeRangeSelector.m      # Slider with envelope preview
│   └── WebBridge/                    # TCP server for web visualization
│       ├── WebBridge.m
│       └── WebBridgeProtocol.m
├── examples/                         # 40+ runnable examples
└── tests/                            # 30+ test suites
```

## Render Pipeline

1. User calls `render()`.
2. Create figure/axes if not parented.
3. Validate all data (X monotonic, dimensions match).
4. Switch to disk storage mode if data exceeds `MemoryLimit`.
5. Allocate downsampling buffers based on axes pixel width.
6. For each line: initial downsample of full range, create graphics object.
7. Create threshold, band, shading, marker objects.
8. Install XLim PostSet listener for zoom/pan events.
9. Set axis limits, disable auto‑limits.
10. `drawnow` to display.

## Zoom/Pan Callback

When the user zooms or pans:

1. XLim listener fires.
2. Compare new XLim to cached value (skip if unchanged).
3. For each line:
   - Binary search visible X range — O(log N).
   - Select pyramid level with sufficient resolution.
   - Build pyramid level lazily if needed.
   - Downsample visible range to ~4,000 points.
   - Update `hLine.XData`/`YData` (dot notation for speed).
4. Recompute violation markers (fused SIMD with pixel culling).
5. If `LinkGroup` active: propagate XLim to linked plots.
6. `drawnow limitrate` (caps display at 20 FPS).

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket, keep the minimum and maximum Y values. Preserves signal envelope and extreme values. Fast O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)
Visually optimal downsampling that preserves signal shape by maximizing triangle area between consecutive buckets. Better visual fidelity but slightly slower.

Both algorithms handle NaN gaps by segmenting contiguous non‑NaN regions independently.

## Lazy Multi-Resolution Pyramid

Problem: At full zoom‑out with 50M+ points, scanning all data is O(N).

Solution: Pre‑computed MinMax pyramid with configurable reduction factor (default 100× per level):

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100× reduction   (   500,000 points)
Level 2: 100× reduction   (     5,000 points)
```

On zoom, the coarsest level with sufficient resolution is selected. Full zoom‑out reads level 2 (5K points) and downsamples to ~4K in under 1 ms.

Levels are built lazily on first access — the first zoom‑out pays a one‑time build cost (~70 ms with MEX), subsequent queries are instant.

## MEX Acceleration

Optional C MEX functions with SIMD intrinsics (AVX2 on x86_64, NEON on arm64). A shared `simd_utils.h` abstraction layer provides a single code base for all platforms. Detection of AVX2, fallback to SSE2, and arm64‑NEON is handled at `build_mex` time.

| Function | Speedup | Description |
|----------|---------|-------------|
| `binary_search_mex` | 10–20× | O(log N) visible range lookup |
| `minmax_core_mex` | 3–10× | Per‑pixel MinMax reduction |
| `lttb_core_mex` | 10–50× | Triangle area computation |
| `violation_cull_mex` | significant | Fused detection + pixel culling |
| `compute_violations_mex` | significant | Batch violation detection for `resolve()` |
| `resolve_disk_mex` | significant | SQLite disk‑based sensor resolution |
| `build_store_mex` | 2–3× | Bulk SQLite writer for DataStore init |
| `to_step_function_mex` | significant | SIMD step‑function conversion for thresholds |
| `delimited_parse_mex` | (plan 1028) | SIMD delimited file parsing for tag pipeline |

If MEX is unavailable, pure-MATLAB implementations are used with identical behavior.

## Data Flow Architecture

### Core Data Path
```
Raw Data (X, Y arrays)
    ↓
FastSenseDataStore (optional, for large datasets)
    ↓
Downsampling Engine (MinMax/LTTB)
    ↓
Pyramid Cache (lazy multi‑resolution)
    ↓
Graphics Objects (line handles)
    ↓
Interactive Display
```

### Storage Modes
- **Memory mode**: X/Y arrays held in MATLAB workspace.
- **Disk mode**: Data chunked into SQLite database via `FastSenseDataStore`.
- **Auto mode**: Switches to disk when data exceeds `MemoryLimit` (default 500 MB).

## Disk‑Backed Data Storage

For datasets exceeding available memory (100M+ points), `FastSenseDataStore` provides SQLite‑backed chunked storage:

1. Data is split into chunks (~10K‑500K points each, auto‑tuned).
2. Each chunk stored as a pair of typed BLOBs (X and Y) with X range metadata.
3. On zoom/pan, only chunks overlapping the visible range are loaded.
4. Pre‑computed L1 MinMax pyramid for instant zoom‑out.

The bulk write path uses `build_store_mex` — a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing ~20K mksqlite round‑trips.

## Sensor Threshold Resolution

### Legacy In‑Line Thresholds

The [[API Reference: Sensors|legacy]] `Sensor.resolve()` algorithm is segment‑based:

1. Collect all state‑change timestamps from all `StateChannels`.
2. For each segment between state changes:
   - Evaluate which `ThresholdRules` match the current state.
   - Group rules with identical conditions.
3. Assign threshold values per segment.
4. Detect violations using SIMD‑accelerated comparison.

Complexity: O(S × R) where S = state segments and R = rules, instead of O(N × R) per‑point evaluation.

### Tag‑Based Monitoring

The modern path uses the Tag domain model. A [[MonitorTag|API Reference: Sensors#monitortag]] wraps a parent `SensorTag` or `CompositeTag` and continuously evaluates a user‑provided `ConditionFn`:

```matlab
m = MonitorTag('temp_hi', tempSensor, @(x,y) y > 80, 'OnEventStart', eventLogger());
```

`MonitorTag` fires `OnEventStart` / `OnEventEnd` callbacks and can emit `Event` objects to an `EventStore`. The pipeline for detecting, persisting, and notifying these events is described in the [[Event Detection Architecture|#event-detection-architecture]].

## Batch and Live Tag Pipeline

For datasets that originate from raw delimited files, FastPlot includes a **batch** and **live** pipeline to convert raw CSV/txt to per‑tag `.mat` files.

```
BatchTagPipeline                       LiveTagPipeline
   raw/*.csv  →  <OutputDir>/<tag>.mat   raw/*.csv  →  <OutputDir>/<tag>.mat
   - one‑shot                                - polling timer (default 15 s)
   - MEX‑accelerated parsing                 - incremental append
                                             - per‑tag file‑cache dedup
```

Both pipelines use the same underlying `readRawDelimited_` + `selectTimeAndValue_` + `writeTagMat_` stack, ensuring byte‑identical output. The live variant mimics `MatFileDataSource`’s `modTime + lastIndex` pattern for raw delimited files without an intermediate `.mat` store.

## Event Detection Architecture

The event detection system provides real‑time threshold violation monitoring with configurable notifications and data persistence.

### Core Components (v2 – Tag‑based)
- **Tag Domain**: `SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `DerivedTag`
- **MonitorTag**: wraps a parent tag and emits events on rising/falling edges of its condition.
- **EventStore**: persistence handler for events (single‑user or cluster‑mode via SQLite).
- **EventBinding**: many‑to‑many mapping between events and tags.
- **LiveTagPipeline**: timer‑driven polling of raw files (matching `LiveEventPipeline` timing).
- **LiveEventPipeline** (legacy DataSource‑based): polls `DataSourceMap` and fires `IncrementalEventDetector`.

### Data Sources
- **MatFileDataSource**: Polls `.mat` files for new data.
- **MockDataSource**: Generates synthetic test signals with violations.

### Event Detection Flow (Monitor‑Tag Path)
1. `LiveTagPipeline` polls raw CSV/txt files and appends new samples to `SensorTag` / `StateTag` via `updateData`.
2. `updateData` cascades to registered `MonitorTag` listeners → `MonitorTag.appendData`.
3. `appendData` carries the hysteresis FSM and `MinDuration` debouncing forward, emitting `Event` handles for completed runs.
4. Events are persisted via `EventStore.append()`.

### Escalation Logic
When `EscalateSeverity` is enabled, events are promoted to the highest violated threshold:
- A violation starts at “Warning” level.
- If “Alarm” threshold is also crossed, the event is escalated to “Alarm”.
- The event retains the highest severity level encountered.

## Theme Inheritance

```
Element override  >  Tile theme  >  Figure theme  >  'default' preset
```

Each level fills in only the fields it specifies; unspecified fields cascade from the next level. The function `DashboardTheme(...)` merges FastSense theme fields with dashboard‑specific colours, fonts, etc.

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[[Dashboard|FastSenseGrid]]**: simple tiled grid of `FastSense` instances with optional live mode.
- **[[Dashboard Engine Guide|DashboardEngine]]**: full‑widget dashboard with gauges, numbers, status indicators, **multi‑page support**, edit mode, and serializable JSON configurations.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar      — Top toolbar (Live, Edit, Save, Export, Sync)
├── DashboardLayout       — 24‑column responsive grid with scrollable canvas
├── DashboardTheme        — FastSenseTheme + dashboard‑specific tokens
├── DashboardBuilder     — Edit‑mode overlay (drag/resize, palette, properties)
├── DashboardSerializer  — JSON save/load and .m script export
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
    ├── IconCardWidget        — Mushroom‑style KPI card
    ├── ChipBarWidget         — Row of health chips
    ├── SparklineCardWidget   — KPI number + mini sparkline
    ├── BarChartWidget        — Bar chart
    ├── ScatterWidget        — Scatter plot
    ├── HeatmapWidget        — Heatmap
    ├── HistogramWidget      — Histogram
    ├── DividerWidget        — Horizontal divider
    └── ImageWidget          — Image display
```

### Render Flow

1. `DashboardEngine.render()` creates the figure.
2. `DashboardTheme(preset)` generates the full theme struct.
3. `DashboardToolbar` creates the top toolbar panel.
4. Time control panel (dual sliders) is created at the bottom.
5. `DashboardLayout.createPanels()` computes grid positions, creates a scrollable canvas (if content exceeds viewport), and allocates a uipanel per widget.
6. Each widget’s `render(parentPanel)` is called to populate its panel.
7. `updateGlobalTimeRange()` scans widgets for data bounds and configures the time sliders.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:
1. **File‑watch**: For sensor‑bound widgets, checks `LiveFile` modification date.
2. Each widget’s `refresh()` is called.
3. `updateLiveTimeRange()` expands time bounds from new data.
4. All widgets bound to global time are updated via `broadcastTimeRange`.
5. A toolbar timestamp label is updated.

### Edit Mode

Clicking “Edit” in the toolbar creates a `DashboardBuilder` instance:
1. A palette sidebar (left) shows draggable widget cards.
2. A properties panel (right) shows selected widget settings.
3. Drag/resize overlays appear on each widget panel.
4. The content area narrows to accommodate sidebars.
5. Mouse up/down/motion handlers manage drag‑and‑drop placement.
6. Grid snap rounds positions to the nearest 24‑column grid cell.

### JSON Persistence

`DashboardSerializer` handles round‑trip serialization:
- **Save:** each widget’s `toStruct()` produces a plain struct; the whole dashboard config is written as JSON.
- **Load:** JSON is decoded, each widget struct dispatched to the correct `fromStruct()` static method.
- **Multi‑page support:** `DashboardPage` objects are serialized with their contained widgets.
- **Export script:** generates a portable `.m` script that reconstructs the dashboard using `DashboardEngine` constructor calls and `addWidget` statements.

## Progress Indication

`ConsoleProgressBar` provides hierarchical progress feedback:
- Single‑line ASCII/Unicode bars with backspace‑based updates.
- Indentation support for nested operations (e.g., dock → tabs → tiles).
- `freeze()` / `finish()` methods for permanent status lines.

## Interactive Features

### Toolbars and Navigation
- **[[API Reference: FastPlot|FastSenseToolbar]]**: Data cursor, crosshair, grid toggle, autoscale, export, live mode.
- **DashboardToolbar**: live toggle, edit mode, save/export, config, info.
- **NavigatorOverlay**: Minimap with draggable zoom rectangle for `SensorDetailPlot`.
- **HoverCrosshair**: shows vertical cross‑hair and multi‑line data‑tip while hovering.

### Link Groups
Multiple `FastSense` instances can share synchronized zoom/pan via `LinkGroup` strings. When one plot’s XLim changes, all plots in the same group update automatically. This works across `FastSenseGrid` tiles and FastSenseWidget dashboards.

### Follow Mode
In dashboard live mode, the “Follow” toggle attaches an XLim tail‑tracking behaviour: the time window slides to keep the latest data point visible, while preserving zoom width.
