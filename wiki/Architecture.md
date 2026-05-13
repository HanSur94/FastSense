<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a **render-once, re-downsample-on-zoom** architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re-downsamples only the visible range on every interaction. This enables fluid zooming and panning over datasets with 100M+ points on modest hardware.

The library is written in MATLAB, with optional C MEX acceleration for performance‑critical kernels. A pure‑MATLAB fallback path is always available.

## Project Structure

```
FastPlot/
├── install.m                        # Path install + MEX compilation
├── libs/
│   ├── FastSense/                    # Core plotting engine
│   │   ├── FastSense.m               # Main class
│   │   ├── FastSenseGrid.m           # Tiled layout
│   │   ├── FastSenseDock.m           # Tabbed container
│   │   ├── FastSenseToolbar.m        # Interactive toolbar
│   │   ├── FastSenseTheme.m          # Theme system
│   │   ├── FastSenseDataStore.m      # SQLite‑backed chunked storage
│   │   ├── SensorDetailPlot.m        # Detail view with minimap
│   │   ├── NavigatorOverlay.m        # Minimap zoom navigator
│   │   ├── ConsoleProgressBar.m      # Progress indication
│   │   ├── binary_search.m           # Binary search (MATLAB & MEX)
│   │   ├── build_mex.m               # MEX compilation script
│   │   └── private/                  # Internal algorithms + MEX sources
│   ├── SensorThreshold/              # Sensor and threshold system
│   │   ├── SensorTag.m, StateTag.m, MonitorTag.m, CompositeTag.m
│   │   ├── TagRegistry.m             # Singleton tag catalog
│   │   └── private/                  # Resolution algorithms
│   ├── EventDetection/               # Event detection and viewer
│   │   ├── Event.m, EventStore.m, EventViewer.m
│   │   ├── LiveEventPipeline.m
│   │   ├── NotificationService.m
│   │   ├── DataSource.m, MatFileDataSource.m, MockDataSource.m
│   │   └── … 
│   ├── Dashboard/                    # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m
│   │   ├── DashboardLayout.m, DashboardBuilder.m, DashboardSerializer.m
│   │   ├── DashboardTheme.m
│   │   └── Widgets: FastSenseWidget, GaugeWidget, … (20+ widget types)
│   └── WebBridge/                    # TCP server for web visualization
├── examples/                         # 40+ runnable examples
└── tests/                            # 30+ test suites
```

## Render Pipeline

The render pipeline is triggered by `FastSense.render()` and follows these steps:

1. **Create figure/axes** – if no `ParentAxes` is supplied, a new figure is created.
2. **Validate data** – all X vectors are checked for monotonicity and Y dimensions are validated.
3. **Disk storage handoff** – for datasets exceeding `MemoryLimit` (default 500 MB), line data is transparently moved to a [[FastSenseDataStore|SQLite‑backed store]].
4. **Allocate downsampling buffers** – based on the pixel width of the target axes.
5. **Initial downsample** – each line’s full range is downsampled to ~4000 points.
6. **Graphics creation** – line, threshold, band, shading, and marker objects are created with the downsampled data.
7. **Install callbacks** – an `XLim PostSet` listener is attached for zoom/pan handling.
8. **Finalize** – axis limits are set (auto‑limits disabled) and the figure is drawn.

## Zoom/Pan Callback

Every zoom or pan interaction:

1. **XLim listener fires** → compare new XLim to cached value; skip if unchanged.
2. **Binary search** (`binary_search` or `binary_search_mex`) locates the visible X range in O(log N).
3. **Pyramid level selection** – the coarsest pyramid level with sufficient resolution for the current view is selected.
4. **Lazy build** – if the required pyramid level has not yet been computed, it is built on the fly and cached.
5. **Re‑downsample** – the visible portion is reduced to ~4000 points.
6. **Update graphics** – `hLine.XData/YData` are overwritten using dot‑notation assignment (fast).
7. **Violation markers** – recomputed using a fused SIMD + pixel‑cull kernel.
8. **Linked plots** – if the `LinkGroup` property is set, `XLim` is propagated to all linked [[API Reference: FastPlot|FastSense]] instances.
9. **Frame cap** – `drawnow limitrate` caps the update at ~20 FPS.

## Downsampling Algorithms

### MinMax (default)

For each pixel bucket, the minimum and maximum Y values are retained. This preserves the signal envelope and extreme values. Time complexity is O(N/bucket) per bucket.

### LTTB (Largest‑Triangle‑Three‑Buckets)

A visually optimal downsampler that maximizes triangle area between consecutive buckets, producing a shape that closely matches the original line. It is slightly slower but offers higher visual fidelity.

Both algorithms handle NaN gaps by segmenting contiguous non‑NaN regions independently.

## Lazy Multi‑Resolution Pyramid

Scanning the entire raw data at full zoom‑out (50M+ points) would be O(N). To avoid this, FastPlot builds a **pre‑computed MinMax pyramid** with a configurable reduction factor (default 100× per level):

| Level | Size example (50 M points)  |
|-------|-----------------------------|
| 0 (raw) | 50,000,000 points         |
| 1       | 500,000 points (100× reduction) |
| 2       | 5,000 points              |

When zooming out, the coarsest level with enough points for the pixel width is selected. Full zoom‑out reads only level 2 (5 K points) and downsamples to ~4 K in under 1 ms. 

Levels are built **lazily** on first access. The first wide zoom-incur a one‑time build cost (≈70 ms with MEX); subsequent queries are instant.

## MEX Acceleration

Optional C MEX functions using SIMD intrinsics (AVX2 on x86_64, NEON on ARM64) accelerate critical paths. All share a common `simd_utils.h` abstraction layer. If MEX files are not available, pure‑MATLAB implementations provide identical behaviour.

| MEX function              | Speedup   | Description                                 |
|---------------------------|-----------|---------------------------------------------|
| `binary_search_mex`       | 10–20×    | O(log n) visible‑range lookup               |
| `minmax_core_mex`         | 3–10×     | Per‑pixel MinMax reduction                  |
| `lttb_core_mex`           | 10–50×    | LTTB triangle‑area computation             |
| `violation_cull_mex`      | significant | Fused detection + pixel culling          |
| `compute_violations_mex`  | significant | Batch violation detection for `resolve()` |
| `resolve_disk_mex`        | significant | SQLite‑based sensor resolution            |
| `build_store_mex`         | 2–3×      | Bulk SQLite writer for DataStore init       |
| `to_step_function_mex`    | significant | SIMD step‑function conversion for thresholds |

Compilation is handled by `build_mex.m`, which auto‑detects the CPU architecture and fallback compiler. The MEX accordinary are bundled with the SQLite3 amalgamation, so no system SQLite installation is required.

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

- **Memory mode** – X/Y arrays held directly in MATLAB.
- **Disk mode** – data chunked into a SQLite database via [[FastSenseDataStore]].
- **Auto mode** – switches to disk when total line data exceeds `MemoryLimit` (default 500 MB).

## Sensor Threshold Resolution

The `Sensor.resolve()` algorithm is **segment‑based**:

1. Collect all state‑change timestamps from `StateChannel`s.
2. For each segment between state changes:
   - Determine which `ThresholdRules` are active.
   - Group rules with identical conditions.
3. Assign threshold values per segment.
4. Detect violations using SIMD‑accelerated comparison.

Complexity is O(S × R) where S = state segments and R = rules, rather than the impractical O(N × R) per‑point evaluation.

## Disk‑Backed Data Storage

For datasets exceeding available memory, `FastSenseDataStore` provides SQLite‑backed chunked storage:

- Data is split into chunks (~10 K – 500 K points each, auto‑tuned).
- Each chunk is stored as a pair of typed BLOBs (X and Y) with X‑range metadata.
- On zoom/pan, only chunks overlapping the visible range are loaded.
- A **pre‑computed L1 MinMax pyramid** allows instant full‑zoom‑out.

Bulk writes use `build_store_mex`, a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing thousands of SQL round‑trips.

If SQLite (via `mksqlite`) is unavailable, a binary‑file fallback is used automatically.

## Theme Inheritance

```
Element override  →  Tile theme  →  Figure theme  →  'light' preset
```

Each level fills only the fields it specifies; unspecified fields cascade from the next broader level.

## Dashboard Architecture

FastPlot offers two levels of dashboard:

- **[[API Reference: FastPlot|FastSenseGrid]]** – Simple tiled grid of FastSense instances with synchronised live mode.
- **[[Dashboard Engine Guide|DashboardEngine]]** – Full widget‑based dashboard with gauges, numbers, status indicators, tables, timelines, and an edit mode.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar      — Top toolbar (Live, Edit, Save, Export, Sync)
├── DashboardLayout       — 24‑column responsive grid with scrollable canvas
├── DashboardTheme        — FastSenseTheme + dashboard‑specific fields
├── DashboardBuilder      — Edit mode overlay (drag/resize, palette, properties)
├── DashboardSerializer   — JSON save/load and .m script export
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (Sensor/DataStore/inline)
    ├── GaugeWidget            — Arc/donut/bar/thermometer gauge
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
3. `DashboardToolbar` creates the top toolbar.
4. A time‑control panel (dual sliders) is created at the bottom.
5. `DashboardLayout.createPanels()` computes grid positions, creates a viewport/canvas/scrollbar, and a uipanel per widget.
6. Each widget’s `render(parentPanel)` is called to populate its panel.
7. `updateGlobalTimeRange()` scans all widgets for data bounds and configures the time sliders.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:

1. `updateLiveTimeRange()` expands the time bounds as new data arrives.
2. Each widget’s `refresh()` is called.
3. The toolbar timestamp is updated.
4. Current slider positions are re‑applied to the updated time range.

### Edit Mode

Clicking “Edit” in the toolbar creates a `DashboardBuilder` instance:

1. A palette sidebar (left) with draggable widget type icons.
2. A properties panel (right) showing settings for the selected widget.
3. Drag/resize overlays appear on each widget panel.
4. The content area narrows to accommodate the sidebars.
5. Mouse callbacks handle drag and resize; grid snap rounds to the nearest column/row.

### JSON Persistence

`DashboardSerializer` handles round‑trip serialisation:

- **Save**: each widget’s `toStruct()` produces a plain struct; the struct is encoded to JSON with manual array assembly (MATLAB’s `jsonencode` cannot handle heterogeneous cell arrays).
- **Load**: JSON is decoded, widgets are rebuilt via each class’s `fromStruct()` static method. An optional `SensorResolver` function handle re‑binds `Sensor` objects by name.
- **Export script**: generates a `.m` file with `DashboardEngine` constructor and `addWidget` calls.

## Event Detection Architecture

The event detection system provides real‑time threshold violation monitoring with configurable notifications and data persistence.

### Core Components

```
LiveEventPipeline
├── MonitorTargets         — containers.Map of MonitorTag instances
├── DataSourceMap          — Maps sensor keys to DataSource objects
├── EventStore             — Thread‑safe .mat file persistence
├── NotificationService    — Rule‑based email alerts
└── EventViewer            — Interactive Gantt chart + filterable table
```

### Data Sources

- **MatFileDataSource** – Polls `.mat` files for new data.
- **MockDataSource** – Generates realistic test signals with violations.
- **Custom sources** – Implement the `DataSource.fetchNew()` interface.

### Event Detection Flow

1. `LiveEventPipeline.runCycle()` polls all data sources.
2. New data is passed to each `MonitorTag` via `appendData()`.
3. The monitor’s `ConditionFn` evaluates the updated parent data.
4. Violations are grouped into events, respecting `MinDuration` (debouncing).
5. Events are stored via `EventStore.append()` (atomic `.mat` writes).
6. `NotificationService` sends rule‑based email alerts with plot snapshots.
7. Active `EventViewer` instances auto‑refresh to show new events.

### Escalation Logic

When `EscalateSeverity` is enabled, events are promoted to the highest violated threshold:

- A violation starts at “Warning” level.
- If an “Alarm” threshold is also crossed, the event is escalated to “Alarm”.
- The event retains the highest severity encountered.

## Progress Indication

`ConsoleProgressBar` provides hierarchical progress feedback:

- Single‑line ASCII/Unicode bars with backspace‑based updates.
- Indentation support for nested operations (e.g., dock → tabs → tiles).
- `freeze()` and `finish()` modes for permanent status lines.

## Interactive Features

### Toolbars and Navigation

- **[[API Reference: FastPlot|FastSenseToolbar]]** – Data cursor, crosshair, grid toggle, autoscale, export, live mode.
- **DashboardToolbar** – Live toggle, edit mode, save/export, name editing.
- **NavigatorOverlay** – Minimap with draggable zoom rectangle for `SensorDetailPlot`.

### Link Groups

Multiple [[API Reference: FastPlot|FastSense]] instances can share synchronised zoom/pan via a `LinkGroup` string. When one plot’s XLim changes, all plots in the same group update automatically.
