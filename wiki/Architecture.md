<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a render-once, re-downsample-on-zoom architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re-downsamples only the visible range on every interaction.

## Project Structure

```
FastPlot/
├── setup.m                        # Path setup + MEX compilation
├── libs/
│   ├── FastSense/                 # Core plotting engine
│   │   ├── FastSense.m            # Main class
│   │   ├── FastSenseGrid.m        # Dashboard layout
│   │   ├── FastSenseDock.m        # Tabbed container
│   │   ├── FastSenseToolbar.m     # Interactive toolbar
│   │   ├── FastSenseTheme.m       # Theme system
│   │   ├── FastSenseDataStore.m   # SQLite-backed chunked storage
│   │   ├── SensorDetailPlot.m     # Sensor detail view with state bands
│   │   ├── NavigatorOverlay.m     # Minimap zoom navigator
│   │   ├── ConsoleProgressBar.m   # Progress indication
│   │   ├── binary_search.m        # Binary search utility
│   │   ├── build_mex.m            # MEX compilation script
│   │   └── private/               # Internal algorithms + MEX sources
│   ├── SensorThreshold/           # Sensor and threshold system
│   │   ├── Sensor.m
│   │   ├── StateChannel.m
│   │   ├── ThresholdRule.m
│   │   ├── SensorRegistry.m
│   │   └── private/               # Resolution algorithms
│   ├── EventDetection/            # Event detection and viewer
│   │   ├── Event.m
│   │   ├── EventDetector.m
│   │   ├── EventViewer.m
│   │   ├── LiveEventPipeline.m
│   │   ├── NotificationService.m
│   │   ├── EventStore.m
│   │   ├── EventConfig.m
│   │   ├── IncrementalEventDetector.m
│   │   ├── DataSource.m           # Abstract data source
│   │   ├── MatFileDataSource.m    # File-based data source
│   │   ├── MockDataSource.m       # Test data generation
│   │   ├── NotificationRule.m     # Email notification rules
│   │   └── private/               # Event grouping algorithms
│   ├── Dashboard/                 # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m
│   │   ├── DashboardLayout.m
│   │   ├── DashboardSerializer.m
│   │   ├── DashboardTheme.m
│   │   ├── DashboardToolbar.m
│   │   ├── DashboardWidget.m
│   │   ├── FastSenseWidget.m
│   │   ├── GaugeWidget.m
│   │   ├── NumberWidget.m
│   │   ├── StatusWidget.m
│   │   ├── TextWidget.m
│   │   ├── TableWidget.m
│   │   ├── RawAxesWidget.m
│   │   └── EventTimelineWidget.m
│   └── WebBridge/                 # TCP server for web visualization
└── examples/                      # 40+ runnable examples
```

## Render Pipeline

1. User calls `render()`
2. Create figure/axes if not parented
3. Validate all data (X monotonic, dimensions match)
4. Allocate downsampling buffers based on axes pixel width
5. For each line: initial downsample of full range, create graphics object
6. Create threshold, band, shading, marker objects
7. Install XLim PostSet listener for zoom/pan events
8. Set axis limits, disable auto-limits
9. `drawnow` to display

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

## Sensor Threshold Resolution

The `Sensor.resolve()` algorithm is segment-based:

1. Collect all state-change timestamps from all StateChannels
2. For each segment between state changes:
   - Evaluate which ThresholdRules match the current state
   - Group rules with identical conditions
3. Assign threshold values per segment
4. Detect violations using SIMD-accelerated comparison

Complexity: O(S × R) where S = state segments and R = rules, instead of O(N × R) per-point evaluation.

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

## Dashboard Engine Architecture

The `DashboardEngine` provides a serializable, widget-based dashboard system separate from `FastSenseGrid`. While `FastSenseGrid` is a tiled grid of FastSense instances, `DashboardEngine` uses a 24-column responsive grid with heterogeneous widget types (plots, gauges, numbers, status indicators, tables, timelines, and raw axes).

### Key Components

```
DashboardEngine
├── DashboardToolbar      — Top toolbar (Live, Edit, Save, Export, Info)
├── DashboardLayout       — 24-column grid with scrollable canvas
├── DashboardTheme        — FastSenseTheme + dashboard-specific fields
├── DashboardSerializer   — JSON save/load and .m script export
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (Sensor/DataStore/inline)
    ├── GaugeWidget            — Arc/donut/bar/thermometer gauge
    ├── NumberWidget            — Big number with trend arrow
    ├── StatusWidget            — Colored dot indicator
    ├── TextWidget             — Static label or header
    ├── TableWidget            — uitable display
    ├── RawAxesWidget          — User-supplied plot function
    └── EventTimelineWidget    — Colored event bars on timeline
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
2. Each widget's `refresh()` is called (sensor-bound widgets re-read `Sensor.Y(end)`)
3. The toolbar timestamp label is updated
4. Current slider positions are re-applied to the updated time range

## Event Detection Architecture

The event detection system provides real-time threshold violation monitoring with configurable notifications and data persistence.

### Core Components

```
LiveEventPipeline
├── DataSourceMap          — Maps sensor keys to data sources
├── IncrementalEventDetector — Tracks per-sensor state and open events
├── EventStore            — Thread-safe .mat file persistence
├── NotificationService   — Rule-based email alerts
└── EventViewer          — Interactive Gantt chart + filterable table
```

### Data Sources

- **MatFileDataSource**: Polls .mat files for new data
- **MockDataSource**: Generates realistic test signals with violations
- **Custom sources**: Implement `DataSource.fetchNew()` interface

### Event Detection Flow

1. `LiveEventPipeline.runCycle()` polls all data sources
2. New data is passed to `IncrementalEventDetector.process()`
3. Sensor state is evaluated via `Sensor.resolve()`
4. Violations are grouped into events with debouncing (`MinDuration`)
5. Events are stored via `EventStore.append()` (atomic .mat writes)
6. `NotificationService` sends rule-based email alerts with plot snapshots
7. Active `EventViewer` instances auto-refresh to show new events

### Escalation Logic

When `EscalateSeverity` is enabled, events are promoted to the highest violated threshold:
- A violation starts at "Warning" level
- If "Alarm" threshold is also crossed, the event is escalated to "Alarm"
- The event retains the highest severity level encountered

## Interactive Features

### Progress Indication
`ConsoleProgressBar` provides hierarchical progress feedback:
- Single-line ASCII/Unicode bars with backspace-based updates
- Indentation support for nested operations (e.g., dock → tabs → tiles)
- Freeze/finish modes for permanent status lines

### Toolbars and Navigation
- **FastSenseToolbar**: Data cursor, crosshair, grid toggle, autoscale, export, live mode
- **DashboardToolbar**: Live toggle, edit mode, save/export, name editing
- **NavigatorOverlay**: Minimap with draggable zoom rectangle for `SensorDetailPlot`

### Link Groups
Multiple FastSense instances can share synchronized zoom/pan via `LinkGroup` strings. When one plot's XLim changes, all plots in the same group update automatically.
