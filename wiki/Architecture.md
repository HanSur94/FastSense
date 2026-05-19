<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a **render-once, re-downsample-on-zoom** architecture. Rather than pushing millions of points to the GPU, it maintains a lightweight multi‑resolution pyramid cache and only downsamples the visible time range on every interaction. A lazy‑loaded C MEX layer accelerates the hot path, with pure‑MATLAB fallbacks ensuring full portability. The domain model is built around a **Tag‑based data graph** (MonitorTag, SensorTag, StateTag, etc.) that cleanly separates data acquisition, threshold logic, and event emission from the rendering pipeline.

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
│   ├── SensorThreshold/              # Tag‑based sensor & threshold system
│   │   ├── Tag.m                     # Abstract base class
│   │   ├── SensorTag.m               # Raw sensor time series
│   │   ├── StateTag.m                # Discrete state signals (ZOH)
│   │   ├── MonitorTag.m              # Derived 0/1 binary alarm signal
│   │   ├── CompositeTag.m            # Aggregated MonitorTags (AND/OR/…)
│   │   ├── DerivedTag.m              # Continuous computed signal
│   │   ├── TagRegistry.m             # Singleton tag catalog
│   │   ├── LiveTagPipeline.m         # Timer‑driven raw‑file → per‑tag .mat
│   │   ├── BatchTagPipeline.m        # One‑shot batch raw‑file ingestion
│   │   └── private/                  # Parsers & write helpers
│   ├── EventDetection/               # Event detection and viewer
│   │   ├── Event.m
│   │   ├── EventStore.m
│   │   ├── EventViewer.m
│   │   ├── LiveEventPipeline.m
│   │   └── …
│   ├── Dashboard/                    # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m
│   │   ├── DashboardBuilder.m
│   │   ├── DashboardLayout.m
│   │   └── widgets/…
│   └── WebBridge/                    # TCP server for web visualization
├── examples/                         # 40+ runnable examples
└── tests/                            # 30+ test suites
```

## Render Pipeline

1. User calls `render()` on a [[API Reference: FastPlot|FastSense]] instance.
2. A figure and axes are created (or `ParentAxes` is used).
3. All data is validated: X must be monotonic; dimensions must match.
4. If total data size exceeds `MemoryLimit` (default 500 MB), lines are transparently moved to `FastSenseDataStore` (SQLite‑backed disk storage).
5. Downsampling buffers are pre‑allocated based on the axes’ pixel width.
6. For each line:
   - An initial full‑range downsample is computed.
   - A graphics line object is created with `hLine.XData` / `hLine.YData` set.
7. Threshold lines, band fills, shaded regions, and custom markers are rendered in back‑to‑front order.
8. An `XLim` `PostSet` listener is installed on the axes to capture zoom/pan.
9. Axis limits are set, auto‑limits disabled, and `drawnow` triggers the initial display.

## Zoom/Pan Callback

When the user zooms or pans:

1. The `XLim` listener compares the new limits against a cached value and **skips** if unchanged.
2. For each line:
   - The visible X range is located with an **O(log N) binary search** (`binary_search` / `binary_search_mex`).
   - The **coarsest pyramid level** that still provides at least `~4000` points for the visible window is selected.
   - If the level has not been built yet, it is **lazily computed** (one‑time cost per level).
   - Visible range is downsampled to `~4000` points using the configured algorithm (MinMax or LTTB).
   - `hLine.XData` / `hLine.YData` are updated via dot‑notation assignment for speed.
3. Violation markers (threshold crossings) are recomputed with a **fused SIMD + pixel‑culling** pass (`violation_cull_mex`).
4. If a `LinkGroup` is active, `XLim` is propagated to all plots in the same group.
5. `drawnow limitrate` caps display updates at ~20 fps.

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket the minimum and maximum Y values are retained. This preserves the signal envelope and extreme values, making it ideal for industrial threshold monitoring. Complexity: O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)
A visually optimal algorithm that selects points to maximise the triangle area between consecutive buckets, producing a line that faithfully represents the overall shape. Slightly slower than MinMax, but better for exploratory data analysis. Complexity: O(N/bucket) per bucket with a linear scan.

Both algorithms handle **NaN gaps** by segmenting contiguous non‑NaN regions independently.

## Lazy Multi‑Resolution Pyramid

A pre‑computed MinMax pyramid avoids scanning raw data on every zoom‑out. With a configurable reduction factor (default 100× per level):

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100× reduction   (   500,000 points)
Level 2: 100× reduction   (     5,000 points)
```

When zoomed out, the coarsest level with sufficient resolution is selected. Full zoom‑out reads level 2 (5,000 points) and downsamples it to ~4,000 points in **<1 ms**. Levels are built on first access (one‑time cost of ~70 ms with MEX); subsequent queries are instant.

## MEX Acceleration

Optional C MEX functions with SIMD intrinsics (AVX2 on x86‑64, NEON on ARM64) dramatically accelerate the most expensive operations. If a MEX binary is not available, pure‑MATLAB implementations are used transparently.

| Function | Speedup | Description |
|----------|---------|-------------|
| [`binary_search_mex`](private/mex_src/binary_search_mex.c) | 10–20× | O(log n) visible range lookup |
| [`minmax_core_mex`](private/mex_src/minmax_core_mex.c) | 3–10× | Per‑pixel MinMax reduction |
| [`lttb_core_mex`](private/mex_src/lttb_core_mex.c) | 10–50× | Triangle area computation (LTTB) |
| [`violation_cull_mex`](private/mex_src/violation_cull_mex.c) | significant | Fused detection + pixel culling |
| [`compute_violations_mex`](private/mex_src/compute_violations_mex.c) | significant | Batch violation detection for `Sensor.resolve()` |
| [`to_step_function_mex`](private/mex_src/to_step_function_mex.c) | significant | SIMD step‑function conversion for thresholds |
| [`build_store_mex`](private/mex_src/build_store_mex.c) | 2–3× | Bulk SQLite writer for `FastSenseDataStore` initialisation |
| `resolve_disk_mex` | significant | SQLite disk‑based sensor resolution |

All MEX functions share a common `simd_utils.h` abstraction layer. Compilation is handled by `build_mex.m` and automatically detects the architecture.

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
- **Memory mode**: X/Y arrays held in MATLAB workspace.
- **Disk mode**: Data chunked into an SQLite database via [[API Reference: FastPlot|FastSenseDataStore]].
- **Auto mode**: Switches automatically when data exceeds `MemoryLimit` (default 500 MB).

## Tag‑Based Domain Model

Since the v2.0 rewrite, all data acquisition and threshold logic is expressed through a **Tag** hierarchy. Tags provide a uniform interface (`getXY`, `valueAt`, `getTimeRange`) that decouples the rendering engine from data source specifics.

- **`SensorTag`** — raw time‑series data, optionally backed by disk (`FastSenseDataStore`) or .mat files.
- **`StateTag`** — discrete state signals with zero‑order‑hold lookup (replaces legacy `StateChannel`).
- **`MonitorTag`** — binary 0/1 alarm signal derived from a parent Tag via a user‑supplied condition function. Supports hysteresis (`AlarmOffConditionFn`), minimum duration debouncing, and automatic event emission.
- **`CompositeTag`** — aggregates multiple `MonitorTag` children with AND/OR/MAJORITY/COUNT/WORST/SEVERITY logic.
- **`DerivedTag`** — produces a continuous (X,Y) signal from N parent Tags using a user‑supplied compute function.

All Tags are registered in the singleton `TagRegistry`, enabling dynamic wiring, two‑phase JSON serialisation, and live pipelines (`LiveTagPipeline`, `BatchTagPipeline`) that watch raw files and update the tag graph automatically.

## Sensor Threshold Resolution

**Legacy path**: `Sensor.resolve()` evaluates all `ThresholdRule` objects over every state segment; complexity O(S × R) instead of O(N × R).

**Tag‑based path**: Thresholds are expressed as `MonitorTag` instances. When new data arrives on a parent `SensorTag`, the `MonitorTag` re‑evaluates only the portion of the signal that changed (`appendData` stream) and maintains a binary alarm series. Violation overlaps are detected in `FastSense` via `violation_cull_mex` directly on the downsampled (`getXY`) data, without expensive per‑point resolution.

## Disk‑Backed Data Storage

For datasets exceeding available memory (100M+ points), `FastSenseDataStore` provides SQLite‑backed chunked storage:

1. Data is split into chunks (~10K–500K points each, auto‑tuned).
2. Each chunk is stored as a pair of typed BLOBs (X and Y) with the chunk’s X‑range in a metadata column.
3. On zoom/pan, only chunks overlapping the visible range are loaded; the exact sub‑range is trimmed in memory.
4. A pre‑computed L1 MinMax pyramid allows instant zoom‑out.
5. The bulk write path uses `build_store_mex` — a single C call that writes all chunks with SIMD‑accelerated Y‑min/max computation, replacing ~20K `mksqlite` round‑trips.

If SQLite (`mksqlite`) is unavailable, a binary‑file fallback is used automatically.

## Theme Inheritance

```
Widget/Tile override  →  Dashboard theme  →  Figure theme  →  'light' preset
```

Each level specifies only the fields it wants to change; unspecified entries cascade from the next level.

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[[Dashboard|FastSenseGrid]]** — simple tiled grid of FastSense instances with synchronised live mode.
- **[[Dashboard Engine Guide|DashboardEngine]]** — full widget‑based dashboard with gauges, numbers, status indicators, tables, timelines, and edit mode.

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
    ├── StatusWidget           — Colored dot indicator
    ├── TextWidget             — Static label or header
    └── … (18 widgets total)
```

### Render Flow

1. `DashboardEngine.render()` creates the figure.
2. `DashboardTheme(preset)` generates the full theme struct.
3. `DashboardToolbar` creates the top toolbar panel.
4. A time control panel (dual sliders) is created at the bottom.
5. `DashboardLayout.createPanels()` allocates uipanels for each widget based on grid positions.
6. Each widget’s `render(parentPanel)` is called to populate its panel.
7. `updateGlobalTimeRange()` scans widgets for data bounds and configures the time sliders.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:
1. `updateLiveTimeRange()` expands time bounds from new data.
2. Each widget’s `refresh()` is called (rewriting data without axes teardown).
3. The toolbar’s timestamp label is updated; current slider positions are re‑applied.

### Edit Mode

Clicking “Edit” creates a `DashboardBuilder` instance:
1. A palette sidebar shows widget type buttons.
2. A properties panel shows selected widget settings.
3. Drag/resize overlays are added on top of each widget panel.
4. Mouse interactions are captured to reposition and resize widgets.

### JSON Persistence

`DashboardSerializer` handles round‑trip serialisation in a two‑pass manner (first construct Tag stubs, then `resolveRefs`) to handle cross‑references.

## Event Detection Architecture

The event detection system uses **MonitorTag** for streaming threshold violation monitoring.

### Core Components

```
LiveEventPipeline
├── MonitorTargets        — containers.Map of key → MonitorTag
├── DataSourceMap         — Maps sensor keys to data sources
├── EventStore            — Thread‑safe .mat file (or SQLite cluster) persistence
├── NotificationService   — Rule‑based email alerts
└── EventViewer          — Interactive Gantt chart + filterable table
```

### Event Detection Flow

1. `LiveEventPipeline.runCycle()` polls all configured data sources.
2. For each `MonitorTag`, the parent’s `updateData()` is called first, then `monitor.appendData(newX, newY)` extends the binary alarm series incrementally.
3. `MonitorTag` internally tracks hysteresis, minimum duration, and open events; closed events are emitted to the optional `EventStore`.
4. `NotificationService` sends rule‑based email alerts with plot snapshots.
5. Active `EventViewer` instances refresh to show new events.

## Progress Indication

`ConsoleProgressBar` provides a self‑overwriting single‑line progress bar with optional hierarchical indentation. It supports `freeze()` to make a bar permanent and `update()` to smoothly advance.

## Interactive Features

### Toolbars and Navigation
- **[[API Reference: FastPlot|FastSenseToolbar]]** — data cursor, crosshair, grid toggle, autoscale, export, live mode.
- **`DashboardToolbar`** — live toggle, edit mode, save/export, dashboard name editing.
- **`NavigatorOverlay`** — minimap with draggable zoom rectangle for `SensorDetailPlot`.

### Link Groups
Multiple `FastSense` instances can share synchronised zoom/pan by setting the same `LinkGroup` string. When one plot’s `XLim` changes, all plots in that group update automatically.

### Hover Crosshair
`HoverCrosshair` shows a vertical line tracking the cursor and a multi‑line datatip (one row per visible line) without interfering with existing `WindowButtonMotionFcn` handlers.

---
