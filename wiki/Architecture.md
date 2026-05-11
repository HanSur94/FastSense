<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a render-once, re-downsample-on-zoom architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight multi-resolution cache and re-downsamples only the visible range on every interaction. This yields fluid zoom/pan for datasets of 1 K to 100 M+ points, with optional MEX acceleration for critical paths. The library is structured into modular packages—plotting engine, sensor/threshold system, event detection, dashboard, and web bridge—each with a clear public API and internal private algorithms.

## Project Structure

```
FastPlot/
├── install.m                        # Path install + MEX compilation
├── libs/
│   ├── FastSense/                    # Core plotting engine
│   │   ├── FastSense.m               # Main class
│   │   ├── FastSenseGrid.m           # Tiled dashboard layout
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
│   │   ├── Tag.m                     # Abstract base for unified Tag model
│   │   ├── SensorTag.m               # Sensor time‑series
│   │   ├── StateTag.m                # Discrete state
│   │   ├── MonitorTag.m              # Derived 0/1 binary monitor
│   │   ├── CompositeTag.m            # Multi‑child logic combiner
│   │   ├── TagRegistry.m             # Singleton catalog
│   │   └── private/                  # Resolution algorithms
│   ├── EventDetection/               # Event detection and viewer
│   │   ├── Event.m
│   │   ├── EventStore.m
│   │   ├── LiveEventPipeline.m
│   │   └── …
│   ├── Dashboard/                    # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m
│   │   ├── DashboardLayout.m
│   │   ├── DashboardTheme.m
│   │   ├── DashboardWidget.m         # Abstract widget base
│   │   └── … (many widget classes)
│   └── WebBridge/                    # TCP server for web visualization
│       ├── WebBridge.m
│       └── WebBridgeProtocol.m
├── examples/                         # 40+ runnable examples
└── tests/                            # 30+ test suites
```

## Render Pipeline

1. User calls `render()` on a [[API Reference: FastPlot|FastSense]] instance (or through a grid/dashboard).
2. Create figure/axes if not parented.
3. Validate all data — X monotonic, dimensions match, etc.
4. Switch to disk storage mode if cumulative data size exceeds `MemoryLimit`.
5. Allocate downsampling buffers sized to the axes pixel width.
6. For each line:
   - Initial downsample of the full data range to screen resolution using MinMax or LTTB.
   - Create a `line()` graphics object (or `patch` for fills).
7. Create threshold, band, shading, and marker objects.
8. Install a `PostSet` listener on the axes `XLim` property to trigger re‑downsample on zoom/pan.
9. Set axis limits (with 5 % padding) and disable auto‑limits.
10. `drawnow` to display. If `DeferDraw` is true, the final `drawnow` is skipped (for batch rendering).

## Zoom/Pan Callback

When the user zooms or pans:

1. `XLim` listener fires.
2. Compare new XLim to cached value — if unchanged, bail out.
3. For each line:
   - Binary search the visible X range — O(log N), accelerated by MEX when available.
   - Select the coarsest data pyramid level that still provides >= one raw point per pixel.
   - Build that pyramid level lazily if it hasn’t been computed yet.
   - Downsample the visible portion to approximately `(axes width × DownsampleFactor)` points (default ~4 000).
   - Update `hLine.XData` and `hLine.YData` directly (dot notation for speed, avoids `set()` overhead).
4. Recompute violation markers (threshold crossings) — fused SIMD pipeline with pixel‑space culling.
5. If `LinkGroup` is active: propagate the new `XLim` to all other [[API Reference: FastPlot|FastSense]] instances in the same group.
6. `drawnow limitrate` — caps display updates at ~20 FPS to avoid over‑rendering during fast drags.

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket, the algorithm stores the minimum and maximum Y value. This preserves the signal envelope and extreme values, making it safe for threshold violation detection. Complexity is O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)
Visually optimal downsampling that preserves the overall signal shape by maximising the triangle area between consecutive buckets. Suitable for presentation‑quality plots, but slightly slower than MinMax.

Both algorithms automatically segment contiguous non‑NaN regions — gaps are rendered correctly without interpolation.

## Lazy Multi‑Resolution Pyramid

**Problem:** At full zoom‑out with 50 M+ points, scanning all data is O(N) — far too slow for interactive use.

**Solution:** A pre‑computed MinMax pyramid with a configurable reduction factor (default 100× per level):

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100× reduction   (   500,000 points)
Level 2: 100× reduction   (     5,000 points)
```

On zoom, the system picks the coarsest level that still has at least one point per pixel. At full zoom‑out, level 2 (5 K points) is read in <1 ms (even in pure MATLAB) and then downsampled to the final display resolution (~4 K points). Levels are built lazily on first access — the very first zoom‑out pays a one‑time build cost (~70 ms with MEX), after which subsequent requests are instant.

## MEX Acceleration

Optional C MEX functions use SIMD intrinsics — AVX2 on x86_64, NEON on arm64 — to accelerate the hot paths. A shared `simd_utils.h` abstraction layer provides portability. When MEX binaries are unavailable, pure‑MATLAB implementations run with identical behaviour (automatically detected via `exist()`).

| MEX Function | Speedup | Description |
|--------------|---------|-------------|
| `binary_search_mex` | 10–20× | O(log n) visible‑range lookup |
| `minmax_core_mex` | 3–10× | Per‑pixel MinMax reduction |
| `lttb_core_mex` | 10–50× | Triangle area computation for LTTB |
| `violation_cull_mex` | significant | Fused threshold detection + pixel culling |
| `compute_violations_mex` | significant | Batch violation detection for `Sensor.resolve()` |
| `resolve_disk_mex` | significant | SQLite disk‑based sensor resolution |
| `build_store_mex` | 2–3× | Bulk SQLite writer for `FastSenseDataStore` init |
| `to_step_function_mex` | significant | SIMD step‑function conversion for thresholds |

The `mksqlite` MEX (bundled SQLite3 amalgamation) handles database I/O; if it cannot be compiled, a binary‑file fallback is used automatically.

For details on compilation and performance see [[MEX Acceleration]] and [[Performance]].

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

- **Memory mode:** X/Y arrays held directly in MATLAB workspace — fastest, but limited by available RAM.
- **Disk mode:** Data chunked into a temporary SQLite database via `FastSenseDataStore`. Only chunks intersecting the visible X‑range are loaded. The bulk write path uses `build_store_mex` to write all chunks in a single call, replacing thousands of round‑trips.
- **Auto mode:** FastSense automatically switches to disk storage when the combined size of all lines exceeds the `MemoryLimit` property (default 500 MB). This transparent hand‑off prevents out‑of‑memory errors on memory‑constrained systems.

When SQLite is unavailable, the system falls back to binary file storage (extra columns still require mksqlite).

## Sensor Threshold Resolution

The threshold resolution algorithm (`Sensor.resolve()`) is segment‑based rather than point‑by‑point:

1. Collect all state‑change timestamps from all associated `StateChannels` (now `StateTag` objects).
2. For each segment between state changes:
   - Evaluate which `ThresholdRules` match the current state.
   - Group rules with identical conditions to avoid redundant computation.
3. Assign threshold values per segment.
4. Detect violations using SIMD‑accelerated comparison (`compute_violations_mex`).

Complexity is O(S × R) where S is the number of state segments and R is the number of rules — far cheaper than O(N × R) per‑point evaluation.

## Disk‑Backed Data Storage

For datasets exceeding available memory (100 M+ points), `FastSenseDataStore` provides chunked SQLite storage:

1. Data is split into chunks (10 K–500 K points each, auto‑tuned).
2. Each chunk stored as typed BLOBs (X and Y) with X‑range metadata for fast overlap queries.
3. On zoom/pan, only chunks overlapping the visible range are loaded and trimmed to the exact view window.
4. A pre‑computed L1 MinMax pyramid enables instant zoom‑out, even in disk mode.

Extra data columns (cell, char, categorical, logical, …) can be attached via `addColumn` / `getColumnRange`.

## Theme Inheritance

Themes cascade from the most specific to the least specific:

```
Element override  →  Tile theme  →  Figure theme  →  'light'/'dark' preset
```

Each level fills in only the fields it specifies; missing fields cascade to the next level. This allows fine‑grained per‑widget styling while preserving a consistent global look.

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[[Dashboard|FastSenseGrid]]**: Simple tiled grid of [[API Reference: FastPlot|FastSense]] instances with optional live mode synchronisation. The `axes()` method also allows mixing in raw MATLAB axes for bar charts, scatter plots, etc.
- **[[Dashboard Engine Guide|DashboardEngine]]**: Full widget‑based dashboard with gauges, big numbers, status indicators, tables, timelines, event overlays, and a drag‑and‑drop edit mode. Layouts are serialisable to JSON and exportable as standalone `.m` scripts.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar      — Top toolbar (Live, Sync, Config, Image, Export, Info)
├── DashboardLayout       — 24‑column responsive grid with scrollable canvas
├── DashboardTheme        — extends FastSenseTheme with widget‑specific colours
├── DashboardBuilder      — Edit mode overlay (drag/resize, palette, properties)
├── DashboardSerializer   — JSON save/load and .m script export
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (Tag/DataStore/inline)
    ├── GaugeWidget            — Arc/donut/bar/thermometer
    ├── NumberWidget            — Big number with trend arrow
    ├── StatusWidget            — Coloured dot indicator
    ├── TextWidget/DividerWidget — Labels and separators
    ├── TableWidget            — uitable display
    ├── RawAxesWidget          — User‑supplied plot function
    ├── EventTimelineWidget    — Coloured event bars on timeline
    ├── GroupWidget            — Collapsible panels, tab containers
    ├── MultiStatusWidget      — Grid of sensor status dots
    ├── IconCardWidget         — State‑coloured icon + value
    ├── SparklineCardWidget    — KPI with mini sparkline
    ├── ChipBarWidget          — Horizontal row of status chips
    ├── BarChartWidget         — Bar chart via sensor/DataFcn
    ├── ScatterWidget          — X‑Y scatter
    ├── HeatmapWidget          — Heatmap from matrix
    ├── HistogramWidget        — Histogram from data
    └── ImageWidget            — Display PNG/JPG
```

Time synchronisation is handled by a **TimeRangeSelector** at the bottom of the dashboard; all widgets that opt into global time (`UseGlobalTime=true`) follow the slider position. The selector also renders an aggregate data envelope preview and per‑widget downsampled line traces.

For deeper discussion see [[Dashboard Engine Guide]].

## Event Detection Architecture

The event detection system provides real‑time threshold violation monitoring with configurable notifications and data persistence.

### Core Components

```
LiveEventPipeline
├── DataSourceMap          — Maps sensor keys to data sources
├── IncrementalEventDetector — Tracks per‑sensor state and open events
├── EventStore            — Thread‑safe .mat file persistence + atomic writes
├── NotificationService   — Rule‑based email alerts with plot snapshots
└── EventViewer          — Interactive Gantt chart + filterable table
```

### Event Detection Flow

1. `LiveEventPipeline.runCycle()` polls all data sources.
2. New data is passed to `IncrementalEventDetector.process()`, which uses the registered `MonitorTag` instances to produce binary alarm/OK series.
3. Violations are grouped into events with configurable debouncing (`MinDuration`).
4. Events are persisted via `EventStore.append()` (atomic `.mat` writes).
5. `NotificationService` sends rule‑based email alerts, optionally attaching FastSense‑generated PNG snapshots.
6. Any active `EventViewer` instances auto‑refresh.

The pipeline is timer‑driven; the `Interval` property controls the polling rate. A `DataSourceMap` allows different sensors to come from different file sources or mock generators.

## Progress Indication

`ConsoleProgressBar` provides hierarchical progress feedback for long‑running renders:

- Single‑line ASCII/Unicode bar with backspace‑based updates.
- Indentation support for nested operations (e.g., dock → tabs → tiles).
- `freeze()` / `finish()` for permanent status lines after an operation completes.

## Interactive Features

### Toolbars and Navigation

- **[[API Reference: FastPlot|FastSenseToolbar]]**: Data cursor, crosshair, grid/legend toggle, Y‑autoscale, PNG/CSV export, live mode, and metadata toggling.
- **DashboardToolbar**: Live toggle, sync, config dialog, image export, native script export, and info panel.
- **NavigatorOverlay**: Minimap with a draggable zoom rectangle, used by `SensorDetailPlot`.

### Link Groups

Multiple [[API Reference: FastPlot|FastSense]] instances can share synchronised zoom/pan by assigning the same `LinkGroup` string. When one plot’s XLim changes, all others in the group update automatically — no manual callback wiring required.
