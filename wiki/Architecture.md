<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->
# Architecture

## Overview

FastPlot uses a **render-once, re-downsample-on-zoom** architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re-downsamples only the visible range on every interaction. This keeps RAM usage low and enables fluid navigation with datasets up to 100 M points (and beyond, via disk-backed storage).

The library is organised into several cooperating subsystems:

| Subsystem              | Responsibility |
|------------------------|----------------|
| **FastSense**          | Core time‑series plot with dynamic downsampling |
| **Dashboard**          | Layout engine, widgets, serialisable dashboards |
| **SensorThreshold**    | Unified Tag domain model for sensors, states, and derived monitors |
| **EventDetection**     | Real‑time threshold violation detection, alerting, and event viewer |
| **WebBridge**          | TCP server for web‑based visualisation |

The following sections describe each part in detail.

---

## Project Structure

```
FastPlot/
├── install.m                       # Path install + MEX compilation
├── libs/
│   ├── FastSense/                   # Core plotting engine
│   │   ├── FastSense.m              # Main class
│   │   ├── FastSenseGrid.m          # Tiled dashboard layout
│   │   ├── FastSenseDock.m          # Tabbed container
│   │   ├── FastSenseToolbar.m       # Interactive toolbar
│   │   ├── FastSenseTheme.m         # Theme system
│   │   ├── FastSenseDataStore.m     # SQLite‑backed chunked storage
│   │   ├── SensorDetailPlot.m       # Sensor overview+detail with navigator
│   │   ├── NavigatorOverlay.m       # Minimap zoom navigator
│   │   ├── ConsoleProgressBar.m     # Hierarchical progress indicator
│   │   ├── binary_search.m          # Binary search utility (MEX‑accelerated)
│   │   ├── build_mex.m              # MEX compilation script
│   │   └── private/                 # Internal algorithms + MEX sources
│   ├── SensorThreshold/             # Sensor, state, and derived Tags
│   │   ├── Tag.m                    # Abstract base class
│   │   ├── SensorTag.m              # Raw time‑series data
│   │   ├── StateTag.m               # Discrete state ZOH signal
│   │   ├── MonitorTag.m             # Binary alarm monitor
│   │   ├── CompositeTag.m           # N‑child aggregation (AND/OR/…)
│   │   ├── DerivedTag.m             # Continuous derived signal
│   │   ├── TagRegistry.m            # Singleton registry
│   │   ├── BatchTagPipeline.m       # Offline raw‑file → .mat pipeline
│   │   ├── LiveTagPipeline.m        # Timer‑driven streaming pipeline
│   │   └── private/                 # Resolution algorithms + MEX sources
│   ├── EventDetection/             # Event detection and viewer
│   │   ├── Event.m                  # Single event (open/closed)
│   │   ├── EventStore.m             # Atomic .mat persistence
│   │   ├── EventBinding.m           # Many‑to‑many Event↔Tag registry
│   │   ├── LiveEventPipeline.m      # Real‑time detection orchestrator
│   │   ├── IncrementalEventDetector.m
│   │   ├── NotificationService.m    # Rule‑based email alerts
│   │   ├── EventViewer.m            # Gantt chart + filterable table
│   │   ├── DataSource.m             # Abstract data source
│   │   ├── MatFileDataSource.m      # .mat file polling
│   │   ├── MockDataSource.m         # Test signal generator
│   │   └── private/                 # Event grouping algorithms
│   ├── Dashboard/                   # Dashboard engine (serialisable)
│   │   ├── DashboardEngine.m        # Top‑level orchestrator
│   │   ├── DashboardLayout.m        # 24‑column responsive grid
│   │   ├── DashboardTheme.m         # Theme + dashboard‑specific fields
│   │   ├── DashboardToolbar.m       # Toolbar (Live, Edit, Config, Export)
│   │   ├── DashboardBuilder.m       # Edit mode: drag/resize, palette
│   │   ├── DashboardSerializer.m    # JSON save/load + .m script export
│   │   ├── DashboardWidget.m        # Abstract widget base
│   │   ├── FastSenseWidget.m        # FastSense tile (Tag/DataStore/Inline)
│   │   ├── GaugeWidget.m           # Arc/donut/bar/thermometer
│   │   ├── NumberWidget.m           # Big number + trend
│   │   ├── StatusWidget.m           # Coloured dot indicator
│   │   ├── TextWidget.m             # Static label or heading
│   │   ├── TableWidget.m            # uitable
│   │   ├── RawAxesWidget.m          # User‑supplied plot function
│   │   ├── EventTimelineWidget.m    # Coloured event bars
│   │   ├── GroupWidget.m            # Collapsible panels, tabbed containers
│   │   ├── MultiStatusWidget.m      # Grid of sensor status dots
│   │   ├── IconCardWidget.m         # Compact card with coloured icon
│   │   ├── SparklineCardWidget.m    # KPI card with sparkline
│   │   ├── ChipBarWidget.m          # Horizontal row of mini status chips
│   │   ├── DividerWidget.m          # Visual section separator
│   │   ├── HeatmapWidget.m
│   │   ├── HistogramWidget.m
│   │   ├── ImageWidget.m
│   │   ├── MarkdownRenderer.m       # Markdown → HTML for info panels
│   │   ├── TimeRangeSelector.m      # Interactive time‑range scrubber
│   │   ├── SeverityColor.m          # Event severity ↔ colour mapping
│   │   └── DetachedMirror.m         # Live‑mirrored pop‑out window
│   └── WebBridge/                   # TCP server for web visualisation
├── examples/                        # 40+ runnable examples
└── tests/                           # 30+ test suites
```

---

## Core Rendering Pipeline (FastSense)

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

### Zoom/Pan Callback

When the user zooms or pans:

1. XLim listener fires
2. Compare new XLim to cached value (skip if unchanged)
3. For each line:
   - Binary search visible X range — **O(log N)**
   - Select pyramid level with sufficient resolution
   - Build pyramid level lazily if needed
   - Downsample visible range to ~4,000 points
   - Update `hLine.XData`/`hLine.YData` (dot notation for speed)
4. Recompute violation markers (fused SIMD with pixel culling)
5. If `LinkGroup` active: propagate XLim to linked plots
6. `drawnow limitrate` (caps display at 20 FPS)

---

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket, keep the minimum and maximum Y values. Preserves signal envelope and extreme values. Fast **O(N/bucket)** per bucket.

### LTTB (Largest Triangle Three Buckets)
Visually optimal downsampling that preserves signal shape by maximising triangle area between consecutive buckets. Better fidelity but slightly slower.

Both algorithms handle NaN gaps by segmenting contiguous non‑NaN regions independently.

---

## Lazy Multi‑Resolution Pyramid

**Problem:** At full zoom‑out with 50M+ points, scanning all data is O(N).

**Solution:** Pre‑computed MinMax pyramid with configurable reduction factor (default 100× per level):

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100× reduction   (   500,000 points)
Level 2: 100× reduction   (     5,000 points)
```

On zoom, the coarsest level with sufficient resolution is selected. Full zoom‑out reads level 2 (5K points) and downsamples to ~4K in **under 1 ms**.

Levels are built lazily on first access — the first zoom‑out pays a one‑time build cost (~70 ms with MEX); subsequent queries are instant.

---

## MEX Acceleration

Optional C MEX functions with SIMD intrinsics (AVX2 on x86_64, NEON on arm64). If MEX is unavailable, pure‑MATLAB fallbacks are used with identical behaviour.

| Function | Speedup | Description |
|----------|---------|-------------|
| `binary_search_mex` | 10–20× | O(log n) visible range lookup |
| `minmax_core_mex` | 3–10× | Per‑pixel MinMax reduction |
| `lttb_core_mex` | 10–50× | Triangle area computation |
| `violation_cull_mex` | significant | Fused detection + pixel culling |
| `compute_violations_mex` | significant | Batch violation detection for `Sensor.resolve()` |
| `resolve_disk_mex` | significant | SQLite disk‑based sensor resolution |
| `build_store_mex` | 2–3× | Bulk SQLite writer for `DataStore` init |
| `to_step_function_mex` | significant | SIMD step‑function conversion for thresholds |

All share a common `simd_utils.h` abstraction layer. See [[MEX Acceleration]] for compilation details and platform‑specific flags.

---

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
- **Disk mode**: Data chunked into an SQLite database via `FastSenseDataStore`.
- **Auto mode**: Switches to disk when data exceeds `MemoryLimit` (default 500 MB).

---

## Sensor Threshold Resolution

The `Sensor.resolve()` algorithm is **segment‑based**:

1. Collect all state‑change timestamps from all `StateChannels` (or `StateTags` in v2.0).
2. For each segment between state changes:
   - Evaluate which `ThresholdRules` match the current state.
   - Group rules with identical conditions.
3. Assign threshold values per segment.
4. Detect violations using SIMD‑accelerated comparison.

**Complexity:** O(S × R) where S = state segments and R = rules — instead of O(N × R) per‑point evaluation.

---

## Disk‑Backed Data Storage

For datasets exceeding available memory (100M+ points), `FastSenseDataStore` provides SQLite‑backed chunked storage:

1. Data is split into chunks (~10K‑500K points each, auto‑tuned).
2. Each chunk stored as a pair of typed BLOBs (X and Y) with X‑range metadata.
3. On zoom/pan, only chunks overlapping the visible range are loaded.
4. Pre‑computed L1 MinMax pyramid allows **instant zoom‑out**.

The bulk write path uses `build_store_mex` — a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing thousands of SQL round‑trips. If SQLite is unavailable, a binary file fallback is used automatically.

---

## Theme Inheritance

```
Element override  >  Tile theme  >  Figure theme  >  'light'/'dark' preset
```

Each level fills in only the fields it specifies; unspecified fields cascade from the next level.

The theme system is detailed in [[Themes]].

---

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[[Dashboard|FastSenseGrid]]**: Simple tiled grid of `FastSense` instances with synchronised live mode.
- **[[Dashboard Engine Guide|DashboardEngine]]**: Full widget‑based dashboard with gauges, numbers, status indicators, tables, timelines, and **edit mode**.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar      — Top toolbar (Live, Edit, Follow, Config, Export)
├── DashboardLayout       — 24‑column responsive grid with scrollable canvas
├── DashboardTheme        — FastSenseTheme + dashboard‑specific fields
├── DashboardBuilder      — Edit mode overlay (drag/resize, palette, properties)
├── DashboardSerializer   — JSON save/load and .m script export
├── TimeRangeSelector     — Dual‑slider time scrubber with preview envelope
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (Tag/DataStore/inline)
    ├── GaugeWidget            — Arc/donut/bar/thermometer
    ├── NumberWidget            — Big number with trend arrow
    ├── StatusWidget           — Coloured dot indicator
    ├── TextWidget             — Static label or header
    ├── TableWidget            — uitable display
    ├── RawAxesWidget          — User‑supplied plot function
    ├── EventTimelineWidget    — Coloured event bars on timeline
    ├── GroupWidget            — Collapsible panels, tabbed containers
    └── MultiStatusWidget      — Grid of sensor status dots
```

### Render Flow

1. `DashboardEngine.render()` creates the figure.
2. `DashboardTheme(preset)` generates the full theme struct.
3. `DashboardToolbar` creates the top toolbar panel.
4. `TimeRangeSelector` creates the bottom time‑slider panel.
5. `DashboardLayout.createPanels()` computes grid positions, creates viewport/canvas/scrollbar, and creates a `uipanel` per widget.
6. Each widget’s `render(parentPanel)` is called to populate its panel.
7. `updateGlobalTimeRange()` scans widgets for data bounds and configures the time sliders.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:
1. `updateLiveTimeRange()` expands time bounds from new data.
2. Each widget’s `refresh()` is called (sensor‑bound widgets re‑read `Sensor.Y(end)`).
3. The toolbar timestamp label is updated.
4. Current slider positions are re‑applied to the updated time range.

### Edit Mode

Clicking “Edit” in the toolbar creates a `DashboardBuilder`:
1. A palette sidebar (left) shows widget type buttons.
2. A properties panel (right) shows selected widget settings.
3. Drag/resize overlays are added on top of each widget panel.
4. The content area narrows to accommodate sidebars.
5. Mouse move/up callbacks handle drag and resize interactions.
6. Grid snap rounds positions to the nearest column/row.

### JSON Persistence

`DashboardSerializer` handles round‑trip serialisation:
- **Save:** Each widget’s `toStruct()` produces a plain struct. Heterogeneous widget arrays are assembled manually (MATLAB’s `jsonencode` cannot handle cell arrays of mixed structs).
- **Load:** JSON is decoded, widgets array is normalised to cell, and `configToWidgets()` dispatches to each widget class’s static `fromStruct()`. An optional `SensorResolver` function handle re‑binds Sensor objects by name.
- **Export script:** Generates a `.m` file with `DashboardEngine` constructor calls and `addWidget` calls for each widget.

---

## Tag System (SensorThreshold Library)

In v2.0, the domain model is built around the **Tag** hierarchy, replacing the older Sensor/Threshold classes. See [[Sensors]] for usage examples.

| Class | Role |
|-------|------|
| **SensorTag** | Raw time‑series data (X, Y) |
| **StateTag** | Discrete states with ZOH lookup |
| **MonitorTag** | Binary alarm monitor derived from a parent Tag |
| **CompositeTag** | Aggregate of N children (AND/OR/majority…) |
| **DerivedTag** | Continuous signal computed from N parents |

All Tags are registered in `TagRegistry`, a singleton registry. They can be serialised via two‑phase `loadFromStructs` (Pass 1: create; Pass 2: resolve references) to avoid order dependence.

**Pipelines** (`BatchTagPipeline`, `LiveTagPipeline`) map raw `.csv`/`.txt` files to per‑tag `.mat` outputs, supporting offline and streaming processing.

---

## Event Detection Architecture

The event detection system provides real‑time threshold violation monitoring with configurable notifications and data persistence.

### Core Components

```
LiveEventPipeline
├── DataSourceMap          — Maps sensor keys to data sources
├── IncrementalEventDetector — Tracks per‑sensor state and open events
├── EventStore             — Thread‑safe .mat file persistence
├── NotificationService    — Rule‑based email alerts
└── EventViewer           — Interactive Gantt chart + filterable table
```

### Data Sources

- **MatFileDataSource**: Polls .mat files for new data.
- **MockDataSource**: Generates realistic test signals with violations.
- **Custom sources**: Implement the `DataSource.fetchNew()` interface.

### Event Detection Flow

1. `LiveEventPipeline.runCycle()` polls all data sources.
2. New data is passed to `IncrementalEventDetector.process()`.
3. Sensor state is evaluated via `Sensor.resolve()` (or via `MonitorTag.appendData` in v2.0).
4. Violations are grouped into events with debouncing (`MinDuration`).
5. Events are stored via `EventStore.append()` (atomic .mat writes).
6. `NotificationService` sends rule‑based email alerts with plot snapshots.
7. Active `EventViewer` instances auto‑refresh to show new events.

### Escalation Logic

When `EscalateSeverity` is enabled, events are promoted to the highest violated threshold:
- A violation starts at “Warning” level.
- If “Alarm” threshold is also crossed, the event is escalated to “Alarm”.
- The event retains the highest severity level encountered.

Events are bound to Tags via `EventBinding`, a singleton many‑to‑many registry providing O(1) lookup in both directions.

---

## Progress Indication

`ConsoleProgressBar` provides hierarchical progress feedback:
- Single‑line ASCII/Unicode bars with backspace‑based updates.
- Indentation support for nested operations (e.g., dock → tabs → tiles).
- Freeze/finish modes for permanent status lines.

---

## Interactive Features

### Toolbars and Navigation
- **[[API Reference: FastPlot|FastSenseToolbar]]**: Data cursor, crosshair, grid toggle, autoscale, export, live mode.
- **DashboardToolbar**: Live toggle, edit mode, save/export, name editing, config dialog.
- **NavigatorOverlay**: Minimap with draggable zoom rectangle for `SensorDetailPlot`.
- **HoverCrosshair**: Vertical tracking line + multi‑line datatip (attached automatically to `FastSense`).

### Link Groups
Multiple `FastSense` instances can share synchronised zoom/pan via `LinkGroup` strings. When one plot’s XLim changes, all plots in the same group update automatically.
