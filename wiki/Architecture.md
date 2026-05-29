<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a **render‑once, re‑downsample‑on‑zoom** architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re‑downsamples only the visible range on every interaction. A dynamic downsampling engine, lazy multi‑resolution pyramid, and optional MEX acceleration ensure that datasets from a few hundred to over 100 million points remain responsive during pan and zoom.

## High‑Level Design

The library is organised into several loosely coupled subsystems:

```
User Interaction (zoom/pan)
    │
    ▼
Callback layer (Xlim listener, toolbar)
    │
    ▼
FastSense render engine ──► DataStore (disk / memory)
    │
    ▼
Downsampling (MinMax / LTTB) ──► Pyramid cache
    │
    ▼
Graphics objects (line, patch, scatter)
```

Every zoom or pan triggers a re‑downsample of the visible data, never the full dataset. An optional per‑signal data pyramid stores pre‑computed MinMax levels so that the full zoom‑out only reads a few thousand points.

## Render Pipeline

When `fp.render()` is called (see [[API Reference: FastPlot]]) the following steps occur:

1.  **Figure & axes** – Create a new figure/axes unless `ParentAxes` is supplied.
2.  **Validate data** – Ensure X is monotonic and dimensions match. NaN gaps in Y are handled by segmenting.
3.  **Storage mode** – If data exceeds `MemoryLimit` (default 500 MB) and `StorageMode` is `'auto'`, the trace is moved to a [[FastSenseDataStore]] SQLite database.
4.  **Allocate downsampling buffers** – based on the axes pixel width × `DownsampleFactor`.
5.  **Initial downsample** – For each line, compute a pixel‑resolution view of the full X range.
6.  **Create graphics** – Line, threshold, band, shaded, and marker objects are drawn in layers.
7.  **Install listeners** – A `PostSet` listener on the XLim property triggers the zoom/pan callback.
8.  **Finalise** – Axis limits are set, auto‑limits disabled, and `drawnow` displays the result.

## Zoom / Pan Callback

When the user zooms or pans the chart:

1.  The XLim listener fires.
2.  If the new XLim equals the cached value, the callback exits immediately.
3.  **Binary search** – for each signal, the visible X range is located in O(log N) using `binary_search` / `binary_search_mex`.
4.  **Pyramid selection** – the coarsest pyramid level with sufficient screen resolution is chosen; if that level hasn’t been built yet it is created lazily.
5.  **Downsample** – the visible segment is downsampled to approximately 4 000 points (pixel width × `DownsampleFactor`).
6.  **Update graphics** – line `XData` / `YData` are replaced via dot‑notation assignment.
7.  **Violation markers** – recomputed with SIMD‑accelerated pixel culling.
8.  **Link groups** – if a [[API Reference: FastPlot#linkgroup|LinkGroup]] is configured, the XLim is propagated to all plots in the same group.
9.  **Rate‑limit display** – `drawnow limitrate` caps the refresh at ~20 FPS.

## Downsampling Algorithms

FastPlot offers two core downsamplers, selectable per‑line via the `'DownsampleMethod'` option.

### MinMax (default)
For each pixel bucket, the minimum and maximum Y values are retained. This preserves the signal envelope and extreme values, and is fast: O(N / bucket) per bucket. It is ideal for threshold monitoring and outlier detection.

### LTTB (Largest Triangle Three Buckets)
A visually optimal algorithm that maximises the triangle area between consecutive buckets, preserving the perceptual shape of the signal. LTTB gives better visual fidelity at the cost of a modest speed penalty.

Both algorithms handle NaN gaps by segmenting contiguous non‑NaN regions and downsampling each independently.

## Lazy Multi‑Resolution Pyramid

Scanning 50 M+ points at full zoom‑out would be O(N). To avoid this, FastPlot builds a pre‑computed MinMax pyramid with a configurable reduction factor (default 100× per level):

```
Level 0: Raw data         (50 000 000 points)
Level 1: 100× reduction   (      500 000 points)
Level 2: 100× reduction   (        5 000 points)
```

On zoom, the coarsest level that provides at least one point per pixel is selected. Full zoom‑out reads level 2 (~5 K points) and downsamples to the final display resolution in under 1 ms.

Levels are built lazily on first access; the one‑time build cost is paid only once per zoom level.

## MEX Acceleration

Optional C MEX functions (with SIMD intrinsics: AVX2 on x86_64, NEON on arm64) accelerate the most performance‑critical paths. A shared `simd_utils.h` abstraction layer provides a single code base for all platforms.

| Function | Speedup | Description |
|----------|---------|-------------|
| `binary_search_mex` | 10–20× | O(log N) visible range lookup |
| `minmax_core_mex` | 3–10× | Per‑pixel MinMax reduction |
| `lttb_core_mex` | 10–50× | Triangle area computation |
| `violation_cull_mex` | significant | Fused violation detection + pixel culling |
| `compute_violations_mex` | significant | Batch violation detection for `resolve()` |
| `resolve_disk_mex` | significant | SQLite disk‑based sensor resolution |
| `build_store_mex` | 2–3× | Bulk SQLite write for DataStore init |
| `to_step_function_mex` | significant | SIMD step‑function conversion for thresholds |

If a MEX binary is not available (e.g., not compiled or architecture mismatch), the library transparently falls back to pure‑MATLAB implementations with identical behaviour. For example, `binary_search.m` contains both a MEX dispatch and an iterative MATLAB fallback.

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
- **Disk mode**: Data chunked into an SQLite database via `FastSenseDataStore`.
- **Auto mode**: Switches to disk when the total in‑memory footprint exceeds `MemoryLimit` (default 500 MB).

## Disk‑Backed Data Storage

For datasets exceeding available memory (100 M+ points), `FastSenseDataStore` provides an SQLite‑backed chunked storage:

1.  Data split into chunks (10 K‑500 K points each, auto‑tuned per trace).
2.  Each chunk stored as a pair of typed BLOBs (X and Y) with X‑range metadata.
3.  On zoom/pan, only chunks overlapping the visible range are loaded.
4.  A pre‑computed L1 MinMax pyramid enables instant full‑zoom‑out.

The bulk write path uses `build_store_mex` – a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing thousands of individual mksqlite round‑trips.

## Sensor Threshold Resolution

### Legacy In‑Line Thresholds
The pre‑v2.0 `Sensor.resolve()` algorithm is segment‑based:

1.  Collect state‑change timestamps from all `StateChannels`.
2.  For each segment between state changes, evaluate which `ThresholdRules` apply.
3.  Assign thresholds per segment and detect violations using SIMD‑accelerated comparison.

Complexity: O(S × R), where S = state segments and R = rules, rather than O(N × R) per‑point evaluation.

### Tag‑Based Monitoring (v2.0)
The modern path uses the Tag domain model. A [[MonitorTag|API Reference: Sensors#monitortag]] wraps a parent `SensorTag` or `CompositeTag` and continuously evaluates a user‑supplied `ConditionFn`:

```matlab
m = MonitorTag('temp_hi', tempSensor, @(x,y) y > 80, 'OnEventStart', eventLogger());
```

`MonitorTag` fires `OnEventStart`/`OnEventEnd` callbacks and can emit `Event` objects to an `EventStore`. The full monitoring pipeline is described in the [[Event Detection Architecture|#event-detection-architecture]].

## Batch and Live Tag Pipeline

Both pipelines convert raw delimited files (CSV, TXT) into per‑tag `.mat` files consumed by `SensorTag.load`.

```
BatchTagPipeline                       LiveTagPipeline
   raw/*.csv  →  <OutputDir>/<tag>.mat   raw/*.csv  →  <OutputDir>/<tag>.mat
   - one‑shot                                - polling timer (default 15 s)
   - MEX‑accelerated parsing                 - incremental append
                                             - per‑tag file‑cache dedup
```

They share the same underlying private helpers (`readRawDelimited_`, `selectTimeAndValue_`, `writeTagMat_`), guaranteeing byte‑identical output. The live variant mimics `MatFileDataSource`’s `modTime + lastIndex` state machine for raw text files.

## Event Detection Architecture

The event system provides real‑time threshold violation monitoring with configurable notifications and data persistence.

### Core Components
- **Tag Domain**: `SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `DerivedTag`.
- **MonitorTag**: emits events on rising/falling edges of its condition.
- **EventStore**: persistence handler for events (single‑user or cluster‑mode via SQLite).
- **EventBinding**: many‑to‑many registry linking events and tags.
- **LiveEventPipeline**: timer‑driven loop that feeds new data into tags and processes monitors.

### Event Detection Flow (Monitor‑Tag Path)
1. `LiveTagPipeline` polls raw files and appends samples to `SensorTag`/`StateTag` via `updateData`.
2. `updateData` cascades to registered `MonitorTag` listeners → `MonitorTag.appendData`.
3. `appendData` carries the hysteresis FSM and `MinDuration` debouncing forward, emitting `Event` handles for completed runs.
4. Events are persisted via `EventStore.append()`.

### Escalation Logic
When `EscalateSeverity` is enabled, events are promoted to the highest violated threshold: a “Warning” can become an “Alarm” if a higher threshold is also crossed. The event retains the peak severity level.

## Theme Inheritance

FastPlot’s theme system merges layers of styles:

```
Widget override  >  Tile theme  >  Figure theme  >  'light' / 'dark' preset
```

Each level fills in only the fields it specifies; unspecified fields cascade from the next level. `DashboardTheme(...)` extends `FastSenseTheme` with dashboard‑specific tokens (widget backgrounds, status colours, etc.).

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine
- **[[Dashboard|FastSenseGrid]]**: simple tiled grid of `FastSense` instances with optional live mode.
- **[[Dashboard Engine Guide|DashboardEngine]]**: full‑widget dashboard with gauges, numbers, status indicators, multi‑page support, edit mode, and serializable JSON configurations.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar       — Top toolbar (Live, Edit, Save, Export, Sync)
├── DashboardLayout        — 24‑column responsive grid with scrollable canvas
├── DashboardTheme         — FastSenseTheme + dashboard‑specific tokens
├── DashboardBuilder       — Edit‑mode overlay (drag/resize, palette, properties)
├── DashboardSerializer    — JSON save/load and .m script export
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance bound to a Tag
    ├── GaugeWidget             — Arc/donut/bar/thermometer gauge
    ├── NumberWidget            — Big number with trend arrow
    ├── StatusWidget            — Colored dot indicator
    ├── TextWidget              — Static label or header
    ├── TableWidget             — uitable display
    ├── RawAxesWidget           — User‑supplied plot function
    ├── EventTimelineWidget     — Colored event bars on timeline
    ├── GroupWidget             — Collapsible panels, tabbed containers
    ├── MultiStatusWidget       — Grid of sensor status dots
    ├── IconCardWidget          — Mushroom‑style KPI card
    ├── ChipBarWidget           — Row of health chips
    ├── SparklineCardWidget     — KPI number + mini sparkline
    ├── BarChartWidget          — Bar chart
    ├── ScatterWidget           — Scatter plot
    ├── HeatmapWidget           — Heatmap
    ├── HistogramWidget         — Histogram
    ├── ImageWidget             — Image display
    └── DividerWidget           — Horizontal divider
```

### Render Flow

1. `DashboardEngine.render()` creates the figure and applies the theme.
2. `DashboardToolbar` is placed at the top.
3. A time‑range slider panel (`TimeRangeSelector`) is created at the bottom.
4. `DashboardLayout.allocatePanels()` computes grid positions and creates a scrollable canvas if content exceeds the viewport.
5. Each widget’s `render(parentPanel)` is called.
6. `updateGlobalTimeRange()` scans widgets for data bounds and configures the time sliders.

### Live Mode

A timer fires at `LiveInterval` seconds; on each tick all widgets are refreshed and the global time range is expanded if new data arrived. When “Follow” mode is on, the time window slides to keep the latest data point visible.

### JSON Persistence

`DashboardSerializer` handles round‑trip serialization:
- **Save:** each widget’s `toStruct()` produces a plain struct; the config is written as JSON.
- **Load:** widgets are reconstructed via their `fromStruct()` static methods. Multi‑page dashboards are fully supported.
- **Export script:** generates a portable `.m` script that rebuilds the dashboard.

## Interactive Features

- **[[API Reference: FastPlot#toolbar|FastSenseToolbar]]**: data cursor, crosshair, grid/legend toggle, autoscale, export, live mode.
- **NavigatorOverlay**: minimap with draggable zoom rectangle for `SensorDetailPlot`.
- **HoverCrosshair**: vertical cross‑hair and multi‑line data‑tip on hover.
- **Link Groups**: multiple `FastSense` instances share synchronized zoom/pan via a string group ID.
- **Follow Mode**: in live mode, the viewport slides to keep the tail of the data visible while preserving zoom width.

For further performance details, see [[Performance]] and [[MEX Acceleration]].
