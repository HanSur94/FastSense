<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a render-once, re-downsample-on-zoom architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re-downsamples only the visible range on every interaction.

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
│   │   ├── Tag.m                     # Abstract base for unified domain model
│   │   ├── SensorTag.m               # Time-series data carriers
│   │   ├── StateTag.m                # Discrete state signals with ZOH lookup
│   │   ├── MonitorTag.m              # Derived 0/1 binary threshold monitors
│   │   ├── CompositeTag.m            # Aggregate monitors via AND/OR/majority
│   │   ├── TagRegistry.m             # Singleton catalog of named Tag entities
│   │   ├── BatchTagPipeline.m        # Synchronous raw-data to per-tag .mat
│   │   ├── LiveTagPipeline.m         # Timer-driven raw-data pipeline
│   │   └── private/                  # Resolution algorithms
│   ├── EventDetection/               # Event detection and viewer
│   │   ├── Event.m                   # Single threshold violation events
│   │   ├── EventDetector.m           # Detects events from violations
│   │   ├── EventViewer.m             # Gantt chart + filterable table
│   │   ├── LiveEventPipeline.m       # Orchestrates live event detection
│   │   ├── EventStore.m              # Atomic read/write to .mat files
│   │   ├── EventConfig.m             # Detection system configuration
│   │   ├── EventBinding.m            # Many-to-many Event-Tag registry
│   │   ├── IncrementalEventDetector.m # Incremental state wrapper
│   │   ├── DataSource.m              # Abstract data fetching interface
│   │   ├── MatFileDataSource.m       # Polls .mat files for changes
│   │   ├── MockDataSource.m          # Realistic test signal generation
│   │   ├── NotificationService.m     # Rule-based email alerts
│   │   ├── NotificationRule.m        # Email notification configuration
│   │   └── private/                  # Event grouping algorithms
│   ├── Dashboard/                    # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m         # Top-level dashboard orchestrator
│   │   ├── DashboardBuilder.m        # Edit mode overlay for GUI
│   │   ├── DashboardLayout.m         # 24-column responsive grid
│   │   ├── DashboardSerializer.m     # JSON load/save and .m export
│   │   ├── DashboardTheme.m          # FastSenseTheme + dashboard fields
│   │   ├── DashboardToolbar.m        # Global toolbar controls
│   │   ├── DashboardWidget.m         # Abstract widget base
│   │   ├── DashboardPage.m           # Named page container for multi-page
│   │   ├── DashboardProgress.m       # Progress bar for render passes
│   │   ├── DashboardConfigDialog.m   # Config editor figure
│   │   ├── DetachedMirror.m          # Standalone live-mirrored windows
│   │   ├── TimeRangeSelector.m       # Dual-slider time range control
│   │   ├── FastSenseWidget.m         # FastSense instance wrapper
│   │   ├── GaugeWidget.m             # Arc/donut/bar/thermometer gauges
│   │   ├── NumberWidget.m            # Big number with trend arrow
│   │   ├── StatusWidget.m            # Colored dot indicators
│   │   ├── TextWidget.m              # Static labels/headers
│   │   ├── TableWidget.m             # uitable display
│   │   ├── RawAxesWidget.m           # User-supplied plot functions
│   │   ├── EventTimelineWidget.m     # Colored event bars on timeline
│   │   ├── GroupWidget.m             # Collapsible/tabbed containers
│   │   ├── MultiStatusWidget.m       # Grid of status indicators
│   │   ├── IconCardWidget.m          # Compact card with icon and value
│   │   ├── SparklineCardWidget.m     # KPI card with mini chart
│   │   ├── ChipBarWidget.m           # Horizontal row of status chips
│   │   ├── DividerWidget.m           # Visual section separators
│   │   ├── BarChartWidget.m          # Vertical/horizontal bar charts
│   │   ├── ScatterWidget.m           # X/Y scatter plots
│   │   ├── HeatmapWidget.m           # 2D color-mapped data
│   │   ├── HistogramWidget.m         # Distribution plots
│   │   ├── ImageWidget.m             # PNG/JPEG display
│   │   └── MarkdownRenderer.m        # Lightweight Markdown to HTML
│   └── WebBridge/                    # TCP server for web visualization
│       ├── WebBridge.m
│       └── WebBridgeProtocol.m
├── examples/                         # 40+ runnable examples
└── tests/                            # 30+ test suites
```

## Render Pipeline

1. User calls `render()`
2. Create figure/axes if not parented
3. Validate all data (X monotonic, dimensions match)
4. Switch to disk storage mode if data exceeds `MemoryLimit`
5. Allocate downsampling buffers based on axes pixel width
6. For each line: initial downsample of full range, create graphics object
7. Create threshold, band, shading, marker objects
8. Install XLim PostSet listener for zoom/pan events
9. Set axis limits, disable auto-limits
10. `drawnow` to display

## Zoom/Pan Callback

When the user zooms or pans:

1. XLim listener fires
2. Compare new XLim to cached value (skip if unchanged)
3. For each line:
   - Binary search visible X range — O(log N)
   - Select pyramid level with sufficient resolution
   - Build pyramid level lazily if needed
   - Downsample visible range to ~4,000 points
   - Update hLine.XData/YData (dot notation for speed)
4. Recompute violation markers (fused SIMD with pixel culling)
5. If LinkGroup active: propagate XLim to linked plots
6. `drawnow limitrate` (caps display at 20 FPS)

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket, keep the minimum and maximum Y values. Preserves signal envelope and extreme values. Fast O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)
Visually optimal downsampling that preserves signal shape by maximizing triangle area between consecutive buckets. Better visual fidelity but slightly slower.

Both algorithms handle NaN gaps by segmenting contiguous non-NaN regions independently.

## Lazy Multi-Resolution Pyramid

Problem: At full zoom-out with 50M+ points, scanning all data is O(N).

Solution: Pre-computed MinMax pyramid with configurable reduction factor (default 100x per level):

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100x reduction   (   500,000 points)
Level 2: 100x reduction   (     5,000 points)
```

On zoom, the coarsest level with sufficient resolution is selected. Full zoom-out reads level 2 (5K points) and downsamples to ~4K in under 1ms.

Levels are built lazily on first access — the first zoom-out pays a one-time build cost (~70ms with MEX), subsequent queries are instant.

## MEX Acceleration

Optional C MEX functions with SIMD intrinsics (AVX2 on x86_64, NEON on arm64):

| Function | Speedup | Description |
|----------|---------|-------------|
| binary_search_mex | 10-20x | O(log n) visible range lookup |
| minmax_core_mex | 3-10x | Per-pixel MinMax reduction |
| lttb_core_mex | 10-50x | Triangle area computation |
| violation_cull_mex | significant | Fused detection + pixel culling |
| compute_violations_mex | significant | Batch violation detection for resolve() |
| resolve_disk_mex | significant | SQLite disk-based sensor resolution |
| build_store_mex | 2-3x | Bulk SQLite writer for DataStore init |
| to_step_function_mex | significant | SIMD step-function conversion for thresholds |

All share a common `simd_utils.h` abstraction layer. If MEX is unavailable, pure-MATLAB implementations are used with identical behavior.

## Data Flow Architecture

### Core Data Path
```
Raw Data (X, Y arrays)
    ↓
FastSenseDataStore (optional, for large datasets)
    ↓
Downsampling Engine (MinMax/LTTB)
    ↓
Pyramid Cache (lazy multi-resolution)
    ↓
Graphics Objects (line handles)
    ↓
Interactive Display
```

### Storage Modes
- **Memory mode**: X/Y arrays held in MATLAB workspace
- **Disk mode**: Data chunked into SQLite database via `FastSenseDataStore`
- **Auto mode**: Switches to disk when data exceeds `MemoryLimit` (default 500MB)

## Tag-Based Domain Model

FastPlot v2.0 introduces a unified Tag hierarchy for sensor data and derived signals:

```
Tag (abstract base)
├── SensorTag      — time-series data carriers with disk/memory modes
├── StateTag       — discrete state signals with zero-order hold lookup
├── MonitorTag     — derived 0/1 binary threshold monitors
└── CompositeTag   — aggregate multiple monitors via AND/OR/majority
```

### TagRegistry
Singleton catalog providing centralized CRUD operations:
- **Hard-error on duplicate keys** (unlike ThresholdRegistry's silent overwrite)
- **Two-phase deserialization** for circular references
- **Order-insensitive loading** from JSON configurations

### Tag Pipeline Architecture
Raw text files → per-tag .mat files via configurable pipelines:

```
BatchTagPipeline    — synchronous processing for initial data loads
LiveTagPipeline     — timer-driven incremental updates for live data
```

Both share common parsing/selection/writing logic with file-level deduplication.

## Event Detection Architecture

The event detection system provides real-time threshold violation monitoring:

### Core Components

```
LiveEventPipeline
├── MonitorTargets        — containers.Map of key → MonitorTag
├── DataSourceMap         — Maps sensor keys to data sources  
├── EventStore           — Thread-safe .mat file persistence
├── NotificationService  — Rule-based email alerts
└── EventViewer         — Interactive Gantt chart + filterable table
```

### Data Sources

- **MatFileDataSource**: Polls .mat files for new data
- **MockDataSource**: Generates realistic test signals with violations
- **Custom sources**: Implement `DataSource.fetchNew()` interface

### Event Detection Flow

1. `LiveEventPipeline.runCycle()` polls all data sources
2. New data is passed to parent tags via `updateData()`
3. MonitorTag instances receive `appendData()` for streaming tail extension
4. Threshold conditions are evaluated incrementally with hysteresis support
5. Events are grouped with debouncing (`MinDuration`) and escalation logic
6. Events are stored via `EventStore.append()` (atomic .mat writes)
7. `NotificationService` sends rule-based email alerts with plot snapshots
8. Active `EventViewer` instances auto-refresh to show new events

### MonitorTag Streaming Architecture

MonitorTag supports incremental processing via `appendData()`:
- Preserves hysteresis FSM state across append boundaries
- Maintains MinDuration bookkeeping for debouncing
- Falls back to full recompute when cache is cold
- Optional persistence via FastSenseDataStore with staleness detection

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[[Dashboard|FastSenseGrid]]**: Simple tiled grid of FastSense instances with synchronized live mode
- **[[Dashboard Engine Guide|DashboardEngine]]**: Full widget-based dashboard with gauges, numbers, status indicators, tables, timelines, and edit mode

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar      — Top toolbar (Live, Config, Export, Info)
├── DashboardLayout       — 24-column responsive grid with scrollable canvas
├── DashboardTheme        — FastSenseTheme + dashboard-specific fields
├── DashboardBuilder      — Edit mode overlay (drag/resize, palette, properties)
├── DashboardSerializer   — JSON save/load and .m script export
├── TimeRangeSelector     — Dual-slider time control with data preview
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (Tag/DataStore/inline)
    ├── GaugeWidget            — Arc/donut/bar/thermometer gauge
    ├── NumberWidget           — Big number with trend arrow
    ├── StatusWidget           — Colored dot indicator
    ├── TextWidget             — Static label or header
    ├── TableWidget            — uitable display
    ├── RawAxesWidget          — User-supplied plot function
    ├── EventTimelineWidget    — Colored event bars on timeline
    ├── GroupWidget            — Collapsible panels, tabbed containers
    ├── MultiStatusWidget      — Grid of sensor status dots
    ├── IconCardWidget         — Compact card with colored icon and value
    ├── SparklineCardWidget    — KPI card with mini sparkline chart
    ├── ChipBarWidget          — Horizontal row of status chips
    └── DividerWidget          — Visual section separators
```

### Render Flow

1. `DashboardEngine.render()` creates the figure
2. `DashboardTheme(preset)` generates the full theme struct
3. `DashboardToolbar` creates the top toolbar panel
4. Time control panel (dual sliders) is created at the bottom
5. `DashboardLayout.createPanels()` computes grid positions, creates viewport/canvas/scrollbar, and creates a uipanel per widget
6. Each widget's `render(parentPanel)` is called to populate its panel
7. `updateGlobalTimeRange()` scans widgets for data bounds and configures the time sliders

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:
1. `updateLiveTimeRange()` expands time bounds from new data
2. Each widget's `refresh()` is called (tag-bound widgets re-read current values)
3. The toolbar timestamp label is updated
4. Current slider positions are re-applied to the updated time range
5. Stale widget detection warns when data stops updating

### Edit Mode

Clicking "Edit" in the toolbar creates a `DashboardBuilder` instance:
1. A palette sidebar (left) shows widget type buttons
2. A properties panel (right) shows selected widget settings
3. Drag/resize overlays are added on top of each widget panel
4. The content area narrows to accommodate sidebars
5. Mouse move/up callbacks handle drag and resize interactions
6. Grid snap rounds positions to the nearest column/row

### JSON Persistence

`DashboardSerializer` handles round-trip serialization:
- **Save:** each widget's `toStruct()` produces a plain struct with type, title, position, and source. The struct is encoded to JSON with heterogeneous widget arrays assembled manually.
- **Load:** JSON is decoded, widgets array is normalized to cell, and `configToWidgets()` dispatches to each widget class's `fromStruct()` static method.
- **Export script:** generates a `.m` file with `DashboardEngine` constructor calls and `addWidget` calls for each widget.

### Multi-Page Support

DashboardEngine supports named pages via `DashboardPage` containers:
- Pages are stored in a `Pages` cell array with an `ActivePage` index
- `addWidget()` routes to the active page when pages exist
- Page switching uses panel visibility toggling for performance
- Each page maintains its own widget list and layout state

## Disk-Backed Data Storage

For datasets exceeding available memory (100M+ points), `FastSenseDataStore` provides SQLite-backed chunked storage:

1. Data is split into chunks (~10K-500K points each, auto-tuned)
2. Each chunk stored as a pair of typed BLOBs (X and Y) with X range metadata
3. On zoom/pan, only chunks overlapping the visible range are loaded
4. Pre-computed L1 MinMax pyramid for instant zoom-out

The bulk write path uses `build_store_mex` — a single C call that writes all chunks with SIMD-accelerated Y min/max computation, replacing ~20K mksqlite round-trips.

If SQLite is unavailable, a binary file fallback is used automatically.

## Theme Inheritance

```
Element override  >  Tile theme  >  Figure theme  >  'default' preset
```

Each level fills in only the fields it specifies; unspecified fields cascade from the next level.

## Progress Indication

`ConsoleProgressBar` provides hierarchical progress feedback:
- Single-line ASCII/Unicode bars with backspace-based updates
- Indentation support for nested operations (e.g., dock → tabs → tiles)
- Freeze/finish modes for permanent status lines

## Interactive Features

### Toolbars and Navigation
- **[[API Reference: FastPlot|FastSenseToolbar]]**: Data cursor, crosshair, grid toggle, autoscale, export, live mode
- **DashboardToolbar**: Live toggle, config editor, save/export, info display
- **NavigatorOverlay**: Minimap with draggable zoom rectangle for `SensorDetailPlot`

### Link Groups
Multiple FastSense instances can share synchronized zoom/pan via `LinkGroup` strings. When one plot's XLim changes, all plots in the same group update automatically.

## Octave Compatibility

FastPlot maintains full compatibility with GNU Octave 7+:
- MEX files use platform-tagged subdirectories (`octave-<platform>/`)
- Timer-based features fall back to blocking poll loops
- Theme systems avoid MATLAB-specific graphics properties
- All widgets use core uicontrol/uipanel primitives
