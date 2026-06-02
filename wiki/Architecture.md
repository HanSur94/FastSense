<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a **render-once, re-downsample-on-zoom** architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and **dynamically downsamples only the visible range** on every interaction. A modular downsampling engine, lazy multi‑resolution pyramid, and optional MEX acceleration ensure that datasets from a few hundred to over 100 million points remain responsive during pan and zoom.

The architecture is layered: the core **FastSense** rendering engine, a **Tag**‑based domain model for data abstraction, event detection and persistence, a dashboard widget system, and a set of utility pipelines for batch and live data ingestion. Each layer can be used independently or composed to build full‑featured monitoring dashboards.

## Project Structure (abridged)

```
FastPlot/
├── install.m
├── libs/
│   ├── FastSense/          # Core plotting engine
│   │   ├── FastSense.m
│   │   ├── FastSenseGrid.m
│   │   ├── FastSenseDock.m
│   │   ├── FastSenseToolbar.m
│   │   ├── FastSenseTheme.m
│   │   ├── FastSenseDataStore.m
│   │   ├── HoverCrosshair.m
│   │   ├── binary_search.m
│   │   ├── build_mex.m
│   │   └── private/        # Downsampling kernels, MEX source, etc.
│   ├── SensorThreshold/    # Tag‑based domain model + pipelines
│   │   ├── Tag.m           # Abstract base
│   │   ├── SensorTag.m     # Sensor data
│   │   ├── StateTag.m      # Discrete state
│   │   ├── MonitorTag.m    # 0/1 threshold monitor
│   │   ├── CompositeTag.m  # Aggregated 0/1 signal
│   │   ├── DerivedTag.m    # Continuous derived signal
│   │   ├── TagRegistry.m   # Singleton catalog
│   │   ├── BatchTagPipeline.m
│   │   ├── LiveTagPipeline.m
│   │   └── private/        # Parser helpers + MEX wrappers
│   ├── EventDetection/     # Event detection + notification
│   │   ├── Event.m
│   │   ├── EventStore.m
│   │   ├── EventBinding.m
│   │   ├── LiveEventPipeline.m
│   │   ├── NotificationService.m
│   │   └── ...
│   └── Dashboard/          # Dashboard engine + widgets
│       ├── DashboardEngine.m
│       ├── DashboardLayout.m
│       ├── DashboardBuilder.m
│       ├── DashboardSerializer.m
│       ├── DashboardTheme.m
│       └── Widgets/...     # 20+ widget types
└── examples/               # 40+ runnable examples
```

## Render Pipeline (FastSense)

1.  User calls `render()` on a [[FastPlot|API Reference: FastPlot]] instance.
2.  A figure/axes is created if not already parented.
3.  All data is validated: **X must be monotonically increasing**, and dimensions must match.
4.  If data exceeds `MemoryLimit` (default 500 MB), it is transferred to a disk‑backed store.
5.  Downsampling buffers are allocated based on the **pixel width of the axes**.
6.  For each line: an initial downsample of the full range is performed, and a graphics line object is created.
7.  Additional objects (thresholds, bands, shaded regions, markers) are rendered in front‑to‑back order.
8.  A `PostSet` listener is installed on the `XLim` property to handle zoom/pan.
9.  Axis limits are set and auto‑limits are disabled to prevent MATLAB from replacing the carefully chosen ranges.
10. A `drawnow` is issued to display the initial view.

## Zoom / Pan Callback

When the user zooms or pans:

1.  The `XLim` listener fires.
2.  The new `XLim` is compared to the cached value; if unchanged the callback is skipped.
3.  For each data line:
    - A **binary search** (`binary_search.m`) locates the visible X range in O(log N) time.
    - The appropriate **pyramid level** is selected that provides sufficient resolution.
    - If the level has not been computed yet, it is built **lazily**.
    - The visible range is downsampled to approximately **4,000 points** (configurable via `DownsampleFactor` and pixel width).
    - The line’s `XData` and `YData` are updated using **dot notation** for maximum speed.
4. Violation markers (for thresholds) are recomputed using SIMD‑accelerated pixel culling if MEX is available.
5. If a `LinkGroup` is active, the new XLim is propagated to all linked [[FastPlot|API Reference: FastPlot]] instances.
6. A `drawnow limitrate` call caps the refresh at **20 FPS** to avoid unnecessary GPU usage.

## Downsampling Algorithms

Two algorithms are provided; the choice is per‑line via the `DownsampleMethod` option.

### Min‑Max (default)
For each pixel‑width bucket, the minimum and maximum Y values are preserved. This strategy retains signal extremes and the overall envelope. Time complexity is O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)
A visually optimal algorithm that selects points to **maximise the triangle area** between consecutive buckets. It better preserves waveform shape at the cost of a slightly higher computational load. Both algorithms automatically handle **NaN gaps** by segmenting the signal into contiguous non‑NaN regions.

## Lazy Multi‑Resolution Pyramid

Full zoom‑out on a dataset of 50M+ points would require scanning all data even after downsampling. To avoid that, FastPlot maintains a **pre‑computed Min‑Max pyramid** with a configurable reduction factor (`PyramidReduction`, default 100× per level):

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100× reduction   (   500,000 points)
Level 2: 100× reduction   (     5,000 points)
…
```

On any zoom operation, the coarsest level that still provides at least one bucket per screen pixel is selected. Thus a full zoom‑out reads level 2 (5K points) and downsamples to ~4K in under 1 ms. Levels are built **lazily on first access** — the first zoom‑out pays a one‑time build cost (~70 ms with MEX), and subsequent queries are instant.

## MEX Acceleration

Optional C‑MEX functions compiled via `build_mex.m` provide order‑of‑magnitude speedups on both x86‑64 (AVX2/SSE2) and ARM64 (NEON) platforms. The MEX availability is checked once per session; **pure‑MATLAB fallbacks** are used when MEX is unavailable.

| MEX Function | Purpose | Speedup |
|--------------|---------|---------|
| `binary_search_mex` | O(log N) visible range lookup | 10‑20× |
| `minmax_core_mex` | Per‑pixel Min‑Max reduction | 3‑10× |
| `lttb_core_mex` | Triangle‑area computation for LTTB | 10‑50× |
| `violation_cull_mex` | Fused detection + pixel culling | significant |
| `compute_violations_mex` | Batch violation detection for `resolve()` | significant |
| `build_store_mex` | Bulk SQLite writer for DataStore init | 2‑3× |
| `to_step_function_mex` | SIMD step‑function conversion for thresholds | significant |
| `delimited_parse_mex` | SIMD delimited‑file parsing for tag pipeline | significant |

The compilation script selects the optimal SIMD instruction set (AVX2, SSE2, or NEON) based on the detected CPU architecture and falls back to SSE2 if AVX2 compilation fails.

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
- **Memory**: X/Y arrays held in MATLAB workspace.
- **Disk**: Data chunked into an SQLite database via [[FastSenseDataStore|#disk-backed-data-storage]].
- **Auto**: Automatically switches to disk when total data size exceeds `MemoryLimit` (default 500 MB).

## Disk‑Backed Data Storage

For datasets exceeding available memory (100M+ points), `FastSenseDataStore` provides **SQLite‑backed chunked storage**:

1. Data is split into chunks of ~100 K points each (auto‑tuned).
2. Each chunk is stored as a **typed BLOB** (X and Y) with an X‑range index for fast overlap queries.
3. On zoom/pan, only the chunks overlapping the visible range are loaded and trimmed to the exact window.
4. A pre‑computed **L1 Min‑Max pyramid** guarantees instant zoom‑out.

The bulk write path uses `build_store_mex` — a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, avoiding ~20 K mksqlite round‑trips.

## Tag‑Based Domain Model

The [[Sensors|API Reference: Sensors]] system has been unified under a **Tag hierarchy** (`Tag.m` abstract base). Concrete subclasses are:

- **`SensorTag`** – numeric time series (X, Y)
- **`StateTag`** – piecewise‑constant discrete states
- **`MonitorTag`** – derived 0/1 binary signal from a parent Tag, optionally with hysteresis, debouncing, and event emission
- **`CompositeTag`** – aggregation of multiple MonitorTag/CompositeTag children using AND/OR/MAJORITY/etc. modes
- **`DerivedTag`** – arbitrary continuous function of N parent Tags

All tags are registered in the singleton [[TagRegistry|API Reference: Sensors#tagregistry]]. The tag model enables **lazy, invalidate‑driven** recomputation: when a parent’s data changes, its `invalidate()` cascade automatically marks all dependent tags (MonitorTag, CompositeTag, DerivedTag) as dirty. On the next `getXY()` call the cache is recomputed, avoiding per‑frame overhead.

### MonitorTag Streaming (appendData)

`MonitorTag.appendData(newX, newY)` extends the derived binary signal **incrementally** without a full recompute. It preserves hysteresis finite‑state‑machine state and `MinDuration` debouncing across appends, making it suitable for real‑time streaming ingestion.

## Batch and Live Tag Pipeline

For datasets originating from raw delimited files, FastPlot includes **batch** and **live** pipelines:

```
BatchTagPipeline                  LiveTagPipeline
   raw/*.csv  →  <OutputDir>/<tag>.mat    raw/*.csv  →  <OutputDir>/<tag>.mat
   - one‑shot                              - timer‑driven polling (default 15 s)
   - MEX‑accelerated parsing               - incremental append
   - file‑cache dedup                      - per‑tag file‑cache dedup
```

Both pipelines share the same underlying parser and writer stack (`readRawDelimited_`, `selectTimeAndValue_`, `writeTagMat_`), ensuring byte‑identical output. `LiveTagPipeline` mimics the `MatFileDataSource`’s `modTime + lastIndex` pattern directly on raw text files, without requiring an intermediate `.mat` store.

## Event Detection Architecture

The event detection system provides **real‑time threshold violation monitoring** with persistence, notifications, and audit‑trail acknowledgements.

### Core Components
- **MonitorTag**: wraps a parent Tag and evaluates a `ConditionFn`. On rising/falling edges it can emit `Event` objects to an `EventStore`.
- **EventStore**: persistance handler, supporting both single‑user `.mat` storage and cluster‑mode (SQLite + NDJSON logs).
- **EventBinding**: many‑to‑many registry linking events to tags.
- **LiveEventPipeline**: timer‑driven orchestrator that polls data sources, updates parents, and runs `MonitorTag.appendData` on all monitored tags.

### Event Flow
1. `LiveEventPipeline` polls a `DataSourceMap` (e.g., `MatFileDataSource`) and fetches new data.
2. Parent tags are updated via `SensorTag.updateData`. This triggers an `invalidate` cascade to all registered MonitorTag listeners.
3. For each `MonitorTag`, `appendData(newX, newY)` evaluates the condition over the new data tail, **while preserving hysteresis and debouncing state**.
4. If a violation run completes (falling edge), an `Event` is emitted, appended to the `EventStore`, and bound to the tag via `EventBinding`.
5. Any configured `NotificationService` checks matching `NotificationRule`s and can send email alerts with optional FastSense screenshot attachments.

The pipeline respects an ordering invariant: **parent.updateData must be called before monitor.appendData** to avoid cache incoherence.

## Theme Inheritance

Themes cascade from a base preset (e.g., `'light'` or `'dark'`) through `FastSenseTheme`, with optional overrides at the figure, tile, and widget level. The merge order is:

```
Element override  >  Tile theme  >  Figure theme  >  Preset default
```

Dashboard‑specific fields (e.g., `WidgetBackground`, `StatusOkColor`) are merged into the same struct by `DashboardTheme.m`, allowing a single theme object to style both FastSense charts and dashboard widgets.

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[[Dashboard|FastSenseGrid]]**: lightweight tiled grid of FastSense charts.
- **[[Dashboard Engine Guide|DashboardEngine]]**: full‑widget dashboard with gauges, numbers, event timelines, and drag‑resize edit mode.

### Core Components (DashboardEngine)

```
DashboardEngine
├── DashboardToolbar     — top toolbar (Live, Edit, Save, Export, Info)
├── DashboardLayout      — 24‑column responsive grid
├── DashboardTheme       — merged FastSense + dashboard tokens
├── DashboardBuilder     — edit‑mode overlay (drag, palette, properties)
├── DashboardSerializer  — JSON save/load + .m script export
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget, GaugeWidget, NumberWidget,
    ├── StatusWidget, EventTimelineWidget, TextWidget,
    ├── TableWidget, RawAxesWidget, GroupWidget,
    ├── ImageWidget, HeatmapWidget, HistogramWidget,
    ├── BarChartWidget, ScatterWidget, SparklineCardWidget,
    ├── IconCardWidget, ChipBarWidget, MultiStatusWidget,
    └── DividerWidget
```

### Live Mode
A single timer fires at `LiveInterval`. On each tick, file‑based widgets reload data, `FastSenseWidget.refresh()` pushes data changes, and the global time range is extended. Widgets attached to a common time slider (the `TimeRangeSelector` at the bottom) are synchronised via `broadcastTimeRange`.

### Edit Mode
Clicking “Edit” activates `DashboardBuilder`:
- A palette sidebar lists available widget types.
- A properties panel shows settings for the selected widget.
- Widgets become draggable/resizable with grid‑snapping to the 24‑column layout.
- Full JSON persistence and a self‑contained `.m` script export are supported.

## Interactive Features

### Toolbars and Navigation
- **[[API Reference: FastPlot|FastSenseToolbar]]**: provides data cursor, crosshair, grid/legend toggle, autoscale, export, and live controls.
- **HoverCrosshair**: displays a vertical cross‑hair and multi‑line datatip while hovering over a FastSense plot. It chains onto the figure’s `WindowButtonMotionFcn` so it can coexist with other motion‑driven features.
- **NavigatorOverlay** (used by `SensorDetailPlot`): minimap with a draggable zoom rectangle.
- **Follow Mode**: in live dashboards, the X‑axis automatically scrolls to keep the latest data point visible.

### Link Groups
Multiple [[FastPlot|API Reference: FastPlot]] instances can share a **`LinkGroup`** string. When one plot’s XLim changes, all plots in the same group are updated automatically. This works across `FastSenseGrid` tiles and `FastSenseWidget` dashboards.

## Progress Indication

`ConsoleProgressBar` provides a single‑line, overwriting progress bar with hierarchical indentation. It is used throughout render pipelines (e.g., `FastSenseDock.renderAll`, `DashboardEngine.rend`) to give feedback during potentially long operations.

> **Note:** The full architecture includes additional subsystems such as `PlantLog` integration, concurrent cluster writes, and the `WebBridge` TCP server — these are covered in more focused documentation.

---

*See also:*
- [[MEX Acceleration]]
- [[Performance]]
- [[Live Mode Guide]]
- [[Dashboard Engine Guide]]
- [[API Reference: FastPlot|FastPlot]]
- [[API Reference: Dashboard|Dashboard]]
