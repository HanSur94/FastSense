<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a **render‑once, re‑downsample‑on‑zoom** pipeline. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re‑samples only the visible range on every interaction. A dynamic downsampling engine, lazy multi‑resolution pyramid, and optional MEX acceleration ensure that datasets from a few hundred to over 100 million points remain responsive during pan and zoom.

## Render Pipeline

1. User calls `render()` on a [[FastPlot|API Reference: FastPlot]] instance.
2. If no parent axes exists, a new figure and axes are created.
3. All data (X, Y pairs) are validated: X must be strictly monotonic, dimensions must match.
4. If total data exceeds the `MemoryLimit`, the storage mode switches to disk.
5. Downsampling buffers are allocated based on pixel width of the axes (`DownsampleFactor` points per pixel).
6. For each line, an initial downsample of the full X‑range populates the graphics object.
7. Threshold lines, bands, shaded regions, and markers are drawn.
8. An `XLim` PostSet listener is installed on the axes for zoom/pan events.
9. Axis limits are set, auto‑limits are disabled.
10. `drawnow` forces the first frame.

## Zoom/Pan Callback

When the user zooms or pans:

1. The `XLim` listener fires.
2. New `XLim` is compared to a cached value; unchanged ranges are skipped.
3. For each line:
   - **Binary search** locates the visible X‑range in O(log N).
   - The coarsest **pyramid level** with sufficient resolution is selected.
   - If that level has not yet been built, it is **lazily constructed**.
   - The visible data slice is downsampled to ~4 000 points.
   - `hLine.XData` / `YData` are updated using dot notation for speed.
4. Violation markers are recomputed (fused SIMD with pixel culling when MEX is available).
5. If a `LinkGroup` is active, the new XLim is propagated to all linked plots.
6. `drawnow limitrate` caps the refresh rate at ~20 FPS.

## Data Flow

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

- **Memory mode**: Data stays in MATLAB workspace arrays.
- **Disk mode**: Data is chunked into a SQLite database via [[FastSenseDataStore|API Reference: Utilities#fastsensestoredata]].
- **Auto mode**: Automatically switches to disk when total byte size exceeds `MemoryLimit`.

## Downsampling Algorithms

### MinMax (default)

For each pixel bucket, the minimum and maximum Y values are kept. This preserves the signal envelope and all extreme values. Complexity: O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)

Visually optimal downsampling that preserves signal shape by maximising triangle area between successive buckets. Better visual fidelity, slightly slower than MinMax. Both algorithms handle NaN gaps by segmenting contiguous non‑NaN regions independently.

## Lazy Multi‑Resolution Pyramid

A multi‑level pyramid avoids scanning the entire raw dataset on full zoom‑out.

```
Level 0: Raw data         (50 000 000 points)
Level 1: 100× reduction   (   500 000 points)
Level 2: 100× reduction   (     5 000 points)
```

The pyramid is built **on demand**: the first zoom‑out triggers a one‑time build (~70 ms with MEX), after which subsequent queries are instantaneous. Each level is pre‑computed with MinMax to guarantee that envelope extremes are never lost.

## MEX Acceleration

Optional C MEX functions with platform‑specific SIMD (AVX2 on x86_64, NEON on arm64) are provided. A shared `simd_utils.h` abstraction layer yields a single code base. Detection of AVX2, fallback to SSE2, and NEON is handled at `build_mex` time.

| Function                  | Speedup   | Description                                  |
|---------------------------|-----------|----------------------------------------------|
| `binary_search_mex`      | 10–20×    | O(log N) visible range lookup                |
| `minmax_core_mex`        | 3–10×     | Per‑pixel MinMax reduction                   |
| `lttb_core_mex`          | 10–50×    | Triangle area computation for LTTB           |
| `violation_cull_mex`     | signif.   | Fused detection + pixel culling              |
| `compute_violations_mex` | signif.   | Batch violation detection for `resolve()`    |
| `resolve_disk_mex`       | signif.   | SQLite disk‑based sensor resolution          |
| `build_store_mex`        | 2–3×      | Bulk SQLite writer for DataStore init        |
| `to_step_function_mex`   | signif.   | SIMD step‑function conversion for thresholds |
| `delimited_parse_mex`    | (plan)    | SIMD delimited file parsing for tag pipeline |

If MEX is unavailable, pure‑MATLAB implementations are used with identical behaviour.

## Disk‑Backed Data Storage

For datasets exceeding memory (100M+ points), [[FastSenseDataStore|API Reference: Utilities#fastsensestoredata]] provides SQLite‑backed chunked storage:

1. Data is split into chunks (~10K‑500K points each, auto‑tuned).
2. Each chunk is stored as a pair of typed BLOBs (X and Y) with X‑range metadata.
3. On zoom/pan, **only chunks overlapping the visible range** are loaded.
4. A pre‑computed L1 MinMax pyramid enables instant zoom‑out.

The bulk write path uses `build_store_mex` to insert all chunks in a single C call, avoiding thousands of `mksqlite` round‑trips.

## Sensor Threshold Resolution

### Legacy In‑Line Thresholds

The legacy `Sensor.resolve()` algorithm is segment‑based:

1. Collect state‑change timestamps from all `StateChannels`.
2. For each segment, evaluate which `ThresholdRules` match the current state.
3. Group rules with identical conditions.
4. Assign threshold values per segment.
5. Detect violations using SIMD‑accelerated comparison.

Complexity: O(S × R) where S = state segments and R = rules, instead of O(N × R) per‑point evaluation.

### Tag‑Based Monitoring

The modern path uses the Tag domain model ([[API Reference: Sensors]]). A [[MonitorTag|API Reference: Sensors#monitortag]] wraps a parent `SensorTag` or `CompositeTag` and continuously evaluates a `ConditionFn`:

```matlab
m = MonitorTag('temp_hi', tempSensor, @(x,y) y > 80, 'OnEventStart', eventLogger);
```

`MonitorTag` fires callbacks and emits `Event` objects to an `EventStore`. The full event detection pipeline is described under [[Event Detection Architecture]].

## Event Detection Architecture

The event detection system provides real‑time threshold violation monitoring with configurable notifications and persistence.

### Core Components (Tag‑based v2)

- **Tag Domain**: `SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `DerivedTag`
- **MonitorTag**: wraps a parent tag and emits events on rising/falling edges of its condition.
- **EventStore**: persistence handler (single‑user or cluster‑mode via SQLite).
- **EventBinding**: many‑to‑many mapping between events and tags.
- **LiveEventPipeline**: timer‑driven polling of `DataSourceMap` for new data.
- **NotificationService**: rule‑based email alerts with event snapshots.

### Data Sources

- **MatFileDataSource**: Polls `.mat` files for new data.
- **MockDataSource**: Generates synthetic test signals with violations.

### Event Detection Flow (Monitor‑Tag Path)

1. `LiveTagPipeline` (or `LiveEventPipeline`) polls raw files and appends new samples to parent `SensorTag` / `StateTag` via `updateData`.
2. `updateData` cascades to registered `MonitorTag` listeners → `MonitorTag.appendData`.
3. `appendData` carries forward hysteresis and `MinDuration` debouncing, emitting `Event` handles for completed runs.
4. Events are persisted via `EventStore.append()`.

### Escalation Logic

When `EscalateSeverity` is enabled, events are promoted to the highest violated threshold: a violation starts at “Warning” and is escalated to “Alarm” if a higher threshold is also crossed.

## Batch and Live Tag Pipeline

For datasets originating from raw delimited files, FastPlot includes both a **batch** and a **live** pipeline to convert raw CSV/txt to per‑tag `.mat` files.

```
BatchTagPipeline                       LiveTagPipeline
   raw/*.csv  →  <OutputDir>/<tag>.mat   raw/*.csv  →  <OutputDir>/<tag>.mat
   - one‑shot                                - polling timer (default 15 s)
   - MEX‑accelerated parsing                 - incremental append
                                             - per‑tag file‑cache dedup
```

Both pipelines share the same underlying `readRawDelimited_` + `selectTimeAndValue_` + `writeTagMat_` stack, ensuring byte‑identical output.

## Class Hierarchy

FastPlot is built from several cooperating classes:

- **FastSense** – core time‑series plot (downsampling, pyramid, zoom/pan listeners).
- **FastSenseGrid** – tiled dashboard manager (lay out multiple `FastSense` tiles in one figure).
- **FastSenseDock** – tabbed container for multiple `FastSenseGrid` dashboards.
- **FastSenseToolbar** – interactive toolbar (data cursor, crosshair, export, live mode).
- **FastSenseTheme** – theme system (light/dark presets, per‑tile overrides).
- **FastSenseDataStore** – SQLite‑backed chunked storage for datasets larger than RAM.
- **DashboardEngine** – widget‑based dashboard with gauges, status indicators, edit mode, and JSON serialization.
- **DashboardWidget** (abstract) – base class for dashboard widgets: `FastSenseWidget`, `GaugeWidget`, `NumberWidget`, `StatusWidget`, `EventTimelineWidget`, `GroupWidget`, etc.

See [[Dashboard Engine Guide]] for the full widget ecosystem.

## Theme Inheritance

```
Element override  >  Tile theme  >  Figure theme  >  'default' preset
```

Each level fills in only the fields it specifies; unspecified fields cascade from the next level. `DashboardTheme()` merges FastSense theme fields with dashboard‑specific colours, fonts, etc.

## Link Groups and Follow Mode

Multiple `FastSense` instances can be assigned the same `LinkGroup` string. When the XLim of one changes, all plots in the group update automatically. This works across tiles and dashboard widgets.

In live mode, the “Follow” toggle causes the X‑axis to slide so that the latest data point remains visible, preserving the current zoom width.

## Interactive Features

- **FastSenseToolbar**: Provides data cursor, crosshair, grid/legend toggles, autoscale, PNG/data export, live toggle, and Follow button.
- **HoverCrosshair**: Shows a vertical line and multi‑line data‑tip while hovering.
- **NavigatorOverlay**: Minimap with draggable zoom rectangle for `SensorDetailPlot`.
- **ConsoleProgressBar**: Hierarchical ASCII progress bars for dashboard rendering.

## Dashboard Architecture

The dashboard engine (`DashboardEngine`) manages a 24‑column responsive grid. Widgets are rendered in panels, and the layout supports multi‑page configurations, edit mode (drag/resize), and JSON serialization. For details, see [[Dashboard Engine Guide]].

## Progress Indication

`ConsoleProgressBar` provides single‑line, overwriting progress feedback with optional indentation for nested operations (e.g., dock → tabs → tiles). `DashboardProgress` provides a similar feature during dashboard rendering.

---

*This page documents the architecture as of the latest source. Detailed API references are linked throughout.*
