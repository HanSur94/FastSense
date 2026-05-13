<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot is a MATLAB/Octave library for interactive visualisation of very large time‑series datasets (millions to hundreds of millions of points). It follows a **render‑once, re‑downsample‑on‑zoom** paradigm: the library never pushes raw data to the GPU, but instead maintains a lightweight cache and re‑downsamples only the visible range on every user interaction. A multi‑resolution **pyramid** of pre‑computed MinMax summaries accelerates full‑zoom‑out views, and optional **MEX** routines with SIMD intrinsics further reduce latency.

Beyond raw plotting, FastPlot provides a **Tag‑based domain model** for sensors, states, monitors, and derived signals, plus a full **Dashboard engine** with widgets, live updating, and event detection.

---

## Project Structure

```
FastPlot/
├── install.m
├── libs/
│   ├── FastSense/                 # Core plotting engine and utilities
│   │   ├── FastSense.m            # Main class (render, addLine, thresholds, bands, markers)
│   │   ├── FastSenseGrid.m        # Tiled layout of FastSense instances
│   │   ├── FastSenseDock.m        # Tabbed container for grids
│   │   ├── FastSenseToolbar.m     # Interactive toolbar (cursor, crosshair, export, live)
│   │   ├── FastSenseTheme.m       # Theme presets and built‑in palettes
│   │   ├── FastSenseDataStore.m   # SQLite‑backed chunked storage for large datasets
│   │   ├── SensorDetailPlot.m     # Two‑panel overview+detail with navigator
│   │   ├── NavigatorOverlay.m     # Minimap zoom rectangle
│   │   ├── ConsoleProgressBar.m   # Hierarchical console progress
│   │   ├── binary_search.m        # Compiled or pure‑MATLAB binary search
│   │   ├── build_mex.m            # MEX compilation script
│   │   └── private/               # MEX sources, simd_utils.h, SQLite3 amalgamation
│   ├── SensorThreshold/           # Tag‑based domain model & pipeline
│   │   ├── Tag.m, SensorTag.m, StateTag.m, MonitorTag.m,
│   │   │   CompositeTag.m, DerivedTag.m
│   │   ├── TagRegistry.m          # Singleton catalog of Tags
│   │   ├── BatchTagPipeline.m     # One‑shot raw‑file → per‑tag .mat
│   │   ├── LiveTagPipeline.m      # Timer‑driven continuous pipeline
│   │   └── private/               # Parser, writer, MEX copies
│   ├── EventDetection/            # Event detection & notification
│   │   ├── Event.m, EventStore.m, EventBinding.m, EventViewer.m
│   │   ├── LiveEventPipeline.m, IncrementalEventDetector.m
│   │   ├── DataSource.m, MatFileDataSource.m, MockDataSource.m
│   │   ├── NotificationService.m, NotificationRule.m
│   │   └── …
│   ├── Dashboard/                 # Dashboard engine & widgets
│   │   ├── DashboardEngine.m, DashboardLayout.m, DashboardToolbar.m,
│   │   │   DashboardTheme.m, DashboardBuilder.m, DashboardSerializer.m
│   │   ├── Widgets/
│   │   │   ├── FastSenseWidget.m, GaugeWidget.m, NumberWidget.m,
│   │   │   │   StatusWidget.m, TextWidget.m, TableWidget.m, …
│   │   │   ├── GroupWidget.m, MultiStatusWidget.m, DividerWidget.m,
│   │   │   │   SparklineCardWidget.m, ChipBarWidget.m, IconCardWidget.m
│   │   │   └── EventTimelineWidget.m
│   │   └── Page/                  # Multi‑page support
│   └── WebBridge/                 # TCP server for web visualisation
└── examples/ & tests/
```

---

## Core Rendering Architecture (`FastSense`)

The central `FastSense` class manages one or more data lines, optional thresholds, bands, and marker overlays within a single MATLAB axes. Its lifecycle:

1. **Configuration**  
   User calls `addLine`, `addThreshold`, `addBand`, `addShaded`, `addMarker` to describe the plot.  
   Property settings (Theme, LinkGroup, LiveViewMode, etc.) control appearance and behaviour.

2. **Render**  
   `render()` creates the figure/axes if not already provided, applies the theme, validates data (monotonic X, matching dimensions), optionally switches large datasets to disk storage, allocates downsampling buffers, performs an initial downsample of the full range, creates graphics objects for lines, thresholds, bands, and markers, and installs an **XLim PostSet listener** to intercept zoom and pan events.

3. **Zoom / Pan Callback**  
   - XLim listener fires on every user pan/zoom.  
   - New XLim is compared to cached value (skip if unchanged).  
   - For each line:  
     a. **Binary search** (O(log N)) locates the visible X range.  
     b. **Pyramid level** with sufficient resolution is selected (built lazily if needed).  
     c. Visible points are **downsampled** to ~4000 points using MinMax or LTTB.  
     d. `hLine.XData`/`YData` are updated via dot‑notation (fast).  
   - Violation markers are recomputed (fused SIMD with pixel culling when MEX is available).  
   - If a `LinkGroup` is active, the new XLim is propagated to all linked plots.  
   - `drawnow limitrate` caps the display at approximately 20 FPS.

### Data Update Paths

- **`addLine`** – must be called **before** `render()`.  
- **`updateData(lineIdx, newX, newY)`** replaces the underlying raw data for a line after rendering and triggers a re‑downsample **without** recreating graphics objects.  
- **Live mode** – a timer polls a `.mat` file or a data source; on change, `updateData` is called automatically.

---

## Downsampling Algorithms

### MinMax (default)

For each pixel bucket, the minimum and maximum Y values are retained.  
This preserves the signal envelope and extreme values, ensuring that spikes are never lost.  
Time complexity: O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)

Visually optimal algorithm that preserves the overall shape of the signal by maximising the triangle area between consecutive buckets.  
Better visual fidelity, especially for slowly varying signals, but computationally more expensive than MinMax.

Both algorithms handle **NaN gaps** by segmenting contiguous non‑NaN regions independently.

---

## Lazy Multi‑Resolution Pyramid

**Problem:** a full‑zoom‑out with 50 M+ points would scan the entire dataset (O(N)).  
**Solution:** a pre‑computed MinMax pyramid with a configurable reduction factor (default 100× per level):

```
Level 0: Raw data          (50 000 000 points)
Level 1: 100× reduction    (   500 000 points)
Level 2: 100× reduction    (     5 000 points)
```

On zoom, the coarsest level that still provides at least one sample per pixel is chosen. Full‑zoom‑out reads only level 2 (~5 k points) and downsamples to ~4 k in under 1 ms.  
Levels are built **lazily** on first access – the initial zoom‑out pays a one‑time build cost (~70 ms with MEX); subsequent queries are instant.

---

## MEX Acceleration

Optional C MEX functions leverage SIMD intrinsics (AVX2 on x86_64, NEON on arm64). Every accelerated function has a pure‑MATLAB fallback with identical behaviour.

| Function | Speedup | Description |
|----------|---------|-------------|
| `binary_search_mex` | 10–20× | O(log N) visible‑range lookup |
| `minmax_core_mex` | 3–10× | Per‑pixel MinMax reduction |
| `lttb_core_mex` | 10–50× | Triangle area computation |
| `violation_cull_mex` | significant | Fused detection + pixel culling |
| `compute_violations_mex` | significant | Batch violation detection |
| `build_store_mex` | 2–3× | Bulk SQLite writer (DataStore init) |
| `to_step_function_mex` | significant | SIMD step‑function conversion |

A shared `simd_utils.h` abstraction layer keeps platform‑specific code manageable.  
If MEX compilation fails or is not available, the library automatically falls back to the equivalent MATLAB implementations.

For details see [[MEX Acceleration]].

---

## Data Storage & Sources

### In‑Memory / Inline Data

The simplest usage: pass raw `x` and `y` arrays directly to `addLine`.  
Data is held in MATLAB’s workspace and subject to normal memory limits.

### `FastSenseDataStore` (Disk‑Backed)

For datasets exceeding available memory (100 M+ points), the `FastSenseDataStore` provides SQLite‑backed chunked storage:

- Data is split into chunks (10 k–500 k points, auto‑tuned).  
- Each chunk stored as a pair of typed BLOBs (X and Y) with X‑range metadata.  
- On zoom/pan, only chunks overlapping the visible range are loaded.  
- A pre‑computed **L1 MinMax pyramid** enables instant zoom‑out.

`FastSense` can automatically switch to disk mode when total data exceeds the `MemoryLimit` (default 500 MB).

### Tag‑Based Sensors (`SensorTag`)

In the v2.0 domain model, a `SensorTag` holds data in memory (`X`, `Y`) or can be switched to disk via `toDisk()`.  
It can also be populated from a **raw data file** (CSV/txt) using a pipeline (see below).  
A `SensorTag` is the recommended way to bind a data source to dashboards and monitor chains.

---

## Tag‑Based Domain Model (v2.0)

FastPlot introduces a unified Tag hierarchy that replaces the legacy `Sensor`/`ThresholdRule` classes. All tags are managed by `TagRegistry`.

```
Tag (abstract)
├── SensorTag      — in-memory/disk numeric (X,Y) sensor data
├── StateTag       — piecewise-constant state values (numeric or cellstr)
├── MonitorTag     — binary 0/1 alarm derived from a parent’s (X,Y)
├── CompositeTag   — aggregate N children into a 0/1 (AND/OR/MAJORITY/…)
└── DerivedTag     — continuous (X,Y) computed from N parent Tags
```

- `MonitorTag` continuously evaluates a condition (with optional hysteresis and MinDuration debouncing). It emits events via `EventStore` and can call user‑defined `OnEventStart`/`OnEventEnd` handlers.  
- `CompositeTag` allows logic operations (AND, OR, WORST, COUNT, MAJORITY, SEVERITY) across multiple binary streams.  
- `DerivedTag` applies an arbitrary compute function (or object) to its parents, producing a new time series.

All tags support `getXY`, `valueAt(t)`, `getTimeRange`, serialisation, and a two‑phase deserialisation (`fromStruct` + `resolveRefs`) that handles circular references safely.

### Pipelines

- **BatchTagPipeline** – one‑off batch processing: reads raw CSV/txt files, parses them, and writes a `.mat` file per tag.  
- **LiveTagPipeline** – timer‑driven incremental pipeline that monitors file modification times and appends new rows.

These are the preferred ingestion paths for streaming file‑based data.

---

## Dashboard Architecture

FastPlot provides two dashboard solutions:

### `FastSenseGrid` – Tiled Quick View

A lightweight grid of synchronised `FastSense` tiles.  
Ideal for rapid prototyping or when only time‑series charts are needed.  
Tiles can be a mix of `FastSense` and raw MATLAB axes.  
Supports tile spanning and per‑tile theme overrides.  
See [[Dashboard Engine Guide]] for the richer widget‑based alternative.

### `DashboardEngine` – Full Widget Dashboard

`DashboardEngine` manages a widget‑based layout with a 24‑column responsive grid, toolbars, serialisation, and edit mode.

```
DashboardEngine
├── DashboardToolbar        — Sync, Live, Config, Export, Image, Info, Reset
├── DashboardLayout         — Grid positioning, scrollable canvas, viewport
├── DashboardTheme          — Dashboard‑specific colours, fonts, status colours
├── DashboardBuilder        — Edit‑mode overlay (drag/resize, palette, properties)
├── DashboardSerializer     — JSON save/load and .m script export
├── TimeRangeSelector       — Dual‑slider time control with event envelope
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget     — Embeds a FastSense instance bound to a Tag
    ├── Render‑only widgets — GaugeWidget, NumberWidget, StatusWidget,
    │                         TextWidget, TableWidget, BarChartWidget, …
    ├── Composite widgets   — GroupWidget (collapsible/tabbed), MultiStatusWidget
    └── Event widgets       — EventTimelineWidget (Gantt bars)
```

- **Multi‑page support**: `DashboardPage` containers allow tabs within the same figure.  
- **Live mode**: a timer calls `refresh()` on every widget; `FastSenseWidget` uses incremental `updateData()` to avoid full re‑renders.  
- **Event overlays**: The time‑range slider can display per‑widget event markers and a combined preview envelope.

Widgets can be detached into standalone figures via `detachWidget` (cloned mirror with live data).

---

## Event Detection & Notification

The event detection system provides real‑time threshold violation monitoring.

```
LiveEventPipeline (or LiveTagPipeline)
├── MonitorTargets         — containers.Map of MonitorTag instances
├── DataSourceMap          — maps sensor keys to DataSource objects
├── EventStore             — atomic .mat file persistence
├── NotificationService    — rule‑based email alerts with plot snapshots
└── EventViewer            — interactive Gantt chart + filterable table
```

- **Data Sources**:  
  - `MatFileDataSource` – polls a MATLAB .mat file.  
  - `MockDataSource` – generates realistic test signals.  
  - Custom sources implement `DataSource.fetchNew()`.  

- **Detection Flow** (when using `LiveEventPipeline`):  
  1. `runCycle()` fetches new data from all sources.  
  2. Each `MonitorTag`’s parent `SensorTag` is updated, then `MonitorTag.appendData()` evaluates the condition.  
  3. New events (with debouncing) are persisted via `EventStore`.  
  4. `NotificationService` sends rule‑based email alerts with context snapshots.  
  5. Active `EventViewer` windows auto‑refresh.

- **EventBinding** – a singleton tracks many‑to‑many relationships between `Event` IDs and `Tag` keys, enabling efficient reverse lookups.

For more on event configuration see [[API Reference: Event Detection]].

---

## Theme Inheritance

```
Element overrides  >  Tile theme  >  Figure theme  >  'default' preset
```

Each level supplies only the fields it specifies; missing fields cascade from the next level in the chain.  
`FastSenseTheme` returns a complete struct with all visual attributes.  
`DashboardTheme` extends it with dashboard‑specific colours (widget backgrounds, toolbar colours, status colours, etc.).

---

## Interactive Features

### Toolbars
- **`FastSenseToolbar`** – data cursor, crosshair, grid/legend toggles, autoscale, export, live toggle, follow mode.  
- **`DashboardToolbar`** – live on/off, follow, event markers, config, export image, info, reset.  

### Link Groups
Multiple `FastSense` instances sharing the same `LinkGroup` string automatically synchronise their X‑axis on zoom/pan.

### Hover Crosshair & Data Cursor
`HoverCrosshair` provides a mouse‑following vertical line with multi‑line datatip, while `FastSenseToolbar` can also enable a snap‑to‑data cursor (built‑in `datacursormode` with enhanced tooltips).

### Navigator Overlay
`SensorDetailPlot` uses a minimap with a draggable zoom rectangle to quickly navigate large time ranges.

### Event Pick Mode
On a `FastSenseWidget`, the “+” button enters a two‑click pick mode on the chart axes to create a manual annotation event directly.

---

## Progress Indication

- **`ConsoleProgressBar`** – single‑line console bar with indentation, suitable for hierarchical processes (dock → tabs → tiles).  
- **`DashboardProgress`** – user‑friendly progress line emitted during dashboard render passes.

---

## Cross‑References

- [[Home]] – Getting started and installation.  
- [[MEX Acceleration]] – Detailed description of compiled acceleration.  
- [[Performance]] – Tuning parameters and benchmarks.  
- [[Dashboard Engine Guide]] – Building and configuring dashboards.  
- [[API Reference: FastPlot]] – Full API for `FastSense`.  
- [[API Reference: Dashboard]] – Widget API and serialisation.  
- [[API Reference: Event Detection]] – Event system configuration.
