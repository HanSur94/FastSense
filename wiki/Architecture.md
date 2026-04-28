<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a **render‑once, re‑downsample‑on‑zoom** architecture. Instead of pushing millions of points to the GPU, it maintains lightweight caches and re‑downsamples only the visible range on every interaction. This provides fluid pan/zoom performance for datasets from 1K to 100M+ points.

The library is organised into several interconnected subsystems:

- **Core plotting engine** (`FastSense`, `FastSenseGrid`, `FastSenseDock`) – time‑series rendering with dynamic downsampling, linked zoom, theme support, and live polling.
- **Dashboard framework** (`DashboardEngine`, `DashboardWidget` hierarchy) – full‑widget dashboards with gauges, numbers, status indicators, tables, timelines, and an edit mode.
- **Tag‑based data domain** (`SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `TagRegistry`) – a unified data model for raw sensors, derived signals, and event generation.
- **Event detection** (`LiveEventPipeline`, `EventDetector`, `EventStore`, `EventViewer`) – threshold‑based real‑time violation monitoring with persistence and notifications.
- **MEX acceleration** – optional C compilations with SIMD intrinsics for the hottest loops; pure‑MATLAB fallbacks are always available.

## Class Hierarchy (Core Plotting)

```
FastSense          – single time‑series plot
FastSenseGrid      – tiled grid of FastSense instances (or raw axes)
FastSenseDock      – tabbed container for multiple FastSenseGrid dashboards
FastSenseToolbar   – interactive toolbar (cursors, crosshair, export, live)
FastSenseTheme     – theme struct builder (light/dark presets)
FastSenseDataStore – SQLite‑backed chunked storage for large datasets
```

`FastSense` is the primary unit of rendering. `FastSenseGrid` manages a grid of such plots; `FastSenseDock` wraps multiple grids as tabs. Each can be themed independently and supports linked zoom/pan via `LinkGroup` strings.

## Render Pipeline

When `fp.render()` is called (source: `FastSense.render` docstring):

1. Create a figure and axes (or use `ParentAxes`).
2. Apply the current `Theme` (background, grid, fonts, colours).
3. Render bands, shaded regions, and area fills (back layer).
4. Render area‑fills from lines to a baseline.
5. For each line: downsample the full data range to screen pixel resolution using the configured algorithm (MinMax or LTTB) and create the graphics object.
6. Draw threshold lines, violation markers, and threshold labels.
7. Draw custom event markers (front layer).
8. Set axis limits with 5% padding, disable auto‑limits.
9. Install XLim and resize listeners for dynamic re‑downsample on zoom/pan.
10. Schedule async refinement for very large datasets (optional background pyramid build).
11. Register in any active `LinkGroup` for synchronised zoom.
12. Call `drawnow` to display.

All calls to `addLine`, `addThreshold`, `addBand`, `addShaded`, etc. must be made **before** `render()`. After rendering, only `updateData()` can replace an existing line’s data without destroying graphics objects.

## Zoom/Pan Callback

FastSense relies on an XLim listener (not continuous redraw). When the user zooms or pans:

- A PostSet listener on the axes’ `XLim` property fires.
- For each line, the visible X range is located with a binary search (**O(log n)**) via `binary_search`.
- The coarsest pre‑built pyramid level that provides sufficient resolution is selected.
- Visible data is downsampled to roughly `DownsampleFactor × pixel width` points (typically ~4,000).
- Graphics object properties (`XData`, `YData`) are updated directly using MATLAB dot notation for speed.
- Violation markers are recomputed (optionally fused with pixel culling).
- If a `LinkGroup` is active, the new XLim is propagated to all linked plots.
- `drawnow limitrate` caps the display rate at ~20 FPS.

This approach keeps the UI responsive, even with hundreds of millions of points.

## Downsampling Algorithms

FastSense supports two algorithms, selectable per‑line or globally via `DefaultDownsampleMethod`.

### MinMax (default)
For each pixel bucket, the minimum and maximum Y values are retained. This preserves the signal envelope and extreme values. Complexity is **O(N / bucket)**.

### LTTB (Largest‑Triangle‑Three‑Buckets)
Visually optimal downsampling that preserves signal shape by maximising triangle area between consecutive buckets. Better visual fidelity at a slightly higher computational cost.

Both algorithms handle NaN gaps by segmenting contiguous non‑NaN regions independently.

## Lazy Multi‑Resolution Pyramid

A multi‑level **MinMax pyramid** is constructed lazily to accelerate zoom:

```
Level 0 → Raw data              (e.g. 50,000,000 points)
Level 1 → 100× reduction        (      500,000 points)
Level 2 → 100× reduction        (        5,000 points)
```

The reduction factor is controlled by the `PyramidReduction` property (default 100). When a zoom level changes, the coarsest level that still provides enough pixel buckets is used for re‑downsampling. Full zoom‑out reads only level 2 (5K points) and downsamples that to the target resolution in under 1 ms.

Levels are built on first access. The one‑time build cost (if done with MEX) is ~70 ms for 50 M points; subsequent zooms are instant.

## MEX Acceleration

Performance‑critical routines can be compiled to C with SIMD intrinsics (AVX2 on x86_64, NEON on ARM64). `build_mex` handles compilation of all MEX sources.

The following MEX functions exist (each with a pure‑MATLAB fallback):

- `binary_search_mex` – visible range lookup (O(log n))
- `minmax_core_mex` – per‑pixel MinMax reduction
- `lttb_core_mex` – triangle area computation for LTTB
- `violation_cull_mex` – fused threshold violation detection + pixel culling
- `compute_violations_mex` – batch violation detection for legacy `resolve()`
- `resolve_disk_mex` – SQLite‑backed sensor resolution
- `build_store_mex` – bulk SQLite writer for `FastSenseDataStore` initialisation
- `to_step_function_mex` – SIMD step‑function conversion for time‑varying thresholds

Availability is checked once per session (`exist(…, 'file')`). If a MEX file is not found, the identical algorithm runs in pure MATLAB. This ensures the library works out‑of‑the‑box without a compiler, but reaps speed gains when MEX is available.

## Data Flow Architecture

### Core Data Path
```
Raw Data (X, Y arrays, Tag objects)
    ↓
FastSenseDataStore (optional, for large datasets)
    ↓
Downsampling Engine (MinMax / LTTB) + Pyramid Cache
    ↓
Graphics Objects (line handles)
    ↓
Interactive Display
```

### Storage Modes
`FastSense` can operate in three modes, controlled by the `StorageMode` property:

- **Memory mode** (`'memory'`) – X/Y arrays stay in the MATLAB workspace.
- **Disk mode** (`'disk'`) – data is chunked into an SQLite database via `FastSenseDataStore`. Only chunks overlapping the visible range are loaded on zoom/pan. Suitable for 100 M+ points.
- **Auto mode** (`'auto'`) – switches to disk mode when the total byte size of all lines exceeds `MemoryLimit` (default 500 MB).

When using disk mode, a pre‑computed L1 MinMax pyramid is stored for instant zoom‑out, and bulk writes are accelerated by `build_store_mex`.

## Tag‑Based Data Domain

The `Tag` hierarchy replaces the legacy `Sensor`/`StateChannel` paradigm:

```
Tag (abstract base)
├── SensorTag          – raw sensor time series (X, Y)
├── StateTag           – discrete state transitions (X, Y numeric or cellstr)
├── MonitorTag         – derived 0/1 binary alarm signal from a condition
└── CompositeTag       – aggregation of multiple MonitorTags (AND, OR, worst‑case, etc.)
```

All tags are registered in `TagRegistry`, a global singleton. `FastSense.addTag()` accepts any `Tag` subclass; for `SensorTag` and `MonitorTag` it creates a standard line plot, for `StateTag` a stepped line.

### Derived Signals and Event Detection (New Pipeline)

**MonitorTag** is the core of derived alarm signals:
- It watches its `Parent` tag (any `Tag` with `getXY()`).
- Evaluates a user‑supplied `ConditionFn` on the parent’s data to produce a 0/1 time series.
- Supports hysteresis (`AlarmOffConditionFn`), minimum duration debouncing (`MinDuration`), and opt‑in persistence to `FastSenseDataStore`.
- Streaming updates are handled by `appendData()`, which extends the cached result incrementally and emits events only when a violation run closes.

**LiveEventPipeline** orchestrates real‑time event detection:
- It holds a `DataSourceMap` that maps sensor keys to `DataSource` instances (e.g. `MatFileDataSource`).
- Each tick polls the sources, updates parent sensor data, then calls `MonitorTag.appendData()`.
- New events are stored atomically in an `EventStore` (persistent `.mat` file).
- `NotificationService` can fire email alerts with embedded plot snapshots.

**EventBinding** maintains a many‑to‑many mapping between events (by `Id`) and tag `Key`s, enabling O(1) query “all events for a given tag”.

## Legacy Sensor Threshold Resolution

*(The legacy system based on `Sensor`, `StateChannel`, and `ThresholdRule` is being superseded by the Tag model. Existing code using `Sensor.resolve()` still works but new projects should adopt `MonitorTag` + `EventStore`.)*

In the older approach, a `Sensor`’s `resolve()` algorithm used a segment‑based state evaluation:
- Collect all state‑change timestamps from attached `StateChannel`s.
- For each segment, determine which `ThresholdRule`s match the current state and group rules with identical conditions.
- Assign threshold values per segment.
- Detect violations using SIMD‑accelerated comparison (if MEX available).

This gave **O(S × R)** complexity where S = number of state segments and R = number of rules, instead of evaluating every point individually.

## Disk‑Backed Data Storage (`FastSenseDataStore`)

`FastSenseDataStore` provides SQLite‑based storage for datasets that exceed available RAM:

1. Data is split into chunks (~100K points each, auto‑tuned).
2. Each chunk is stored as two typed BLOBs (X and Y) with indexed X range metadata.
3. On zoom/pan, only chunks overlapping the visible range are loaded, then trimmed to the exact view window.
4. A pre‑computed L1 MinMax pyramid is stored for instant zoom‑out.
5. Extra data columns (cell, string, categorical, logical, etc.) can be added and retrieved by X‑range.

The bulk write path (`build_store_mex`) performs a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing thousands of individual SQLite round‑trips.

If the MEX SQLite interface (`mksqlite`) is not available, a pure binary file fallback is used automatically.

## Theme Inheritance

Theming follows a stacking rule:

```
Element override  →  Tile theme  →  Figure theme  →  'default' preset
```

Each level specifies only the fields it needs; missing fields cascade from the next level. `FastSenseTheme` and `DashboardTheme` provide presets (`'light'` and `'dark'`) that can be partially overridden.

## Dashboard Architecture

`DashboardEngine` is the top‑level orchestrator for widget‑based dashboards. It manages:

- A grid layout (`DashboardLayout` – 24 columns, responsive, scrollable).
- A theme (`DashboardTheme`, extending `FastSenseTheme` with dashboard‑specific colours and font sizes).
- A toolbar (`DashboardToolbar`) with live toggle, edit mode, export, config, and info buttons.
- A time‑range selector (`TimeRangeSelector`) with an aggregate data envelope and event‑marker overlay.
- Optional multi‑page support (`DashboardPage`).

Widgets (`DashboardWidget` subclasses) include:

| Widget | Purpose |
|--------|---------|
| `FastSenseWidget` | a `FastSense` instance bound to a `Tag` or data source |
| `GaugeWidget` | arc, donut, bar, or thermometer gauge |
| `NumberWidget` | big number with trend arrow |
| `StatusWidget` | colored dot indicator |
| `TextWidget` | static label or section header |
| `TableWidget` | `uitable` display |
| `RawAxesWidget` | user‑supplied plot function on raw axes |
| `EventTimelineWidget` | colored event bars on a timeline |
| `GroupWidget` | collapsible panels or tabbed containers |
| `MultiStatusWidget` | grid of sensor status dots |
| `SparklineCardWidget` | KPI card with a mini sparkline |
| `IconCardWidget` | compact icon + value + label |
| `ChipBarWidget` | horizontal row of status chips |
| `HeatmapWidget`, `BarChartWidget`, … | additional chart types |

### Render Flow (Dashboard)

1. `DashboardEngine.render()` creates the figure.
2. A theme struct is built (cached until `Theme` changes).
3. `DashboardToolbar` is created at the top; time‑control panel at the bottom.
4. `DashboardLayout.createPanels()` computes grid positions, creates viewport/canvas/scrollbar, and allocates a `uipanel` per widget.
5. Each widget’s `render(parentPanel)` is called.
6. Global time range is computed from all widget data bounds and configured on the time sliders.
7. If a `LiveInterval` is set, a timer is started for live updates.

Live mode uses a timer that polls data sources, calls `refresh()` on each widget, and updates the global time range selector.

Edit mode (`DashboardBuilder`) adds drag/resize overlays, a widget palette sidebar, and a properties panel, allowing interactive layout without coding.

## Event Detection Architecture

The new event detection pipeline revolves around `MonitorTag` and `EventStore`:

```
LiveEventPipeline
├── DataSourceMap          – maps sensor keys to data sources
├── MonitorTargets          – containers.Map of key → MonitorTag
├── EventStore               – atomic .mat file persistence
├── NotificationService      – rule‑based email alerts
└── EventViewer              – interactive Gantt chart + filterable table
```

**Flow:**
1. `LiveEventPipeline.runCycle()` polls all data sources.
2. New data is pushed to the parent sensor tags.
3. For each monitor, `MonitorTag.appendData(newX, newY)` extends the cached 0/1 signal and emits closed violation events into the `EventStore`.
4. `EventStore.save()` atomically writes all events to disk.
5. `NotificationService` sends email alerts (optional snapshots) using configurable rules.
6. Active `EventViewer` instances auto‑refresh to show new events.

Events are now identified by a unique `Id` and can carry multiple `TagKeys` (via `EventBinding`), enabling cross‑sensor event queries.

## Interactive Features

### Toolbars and Navigation
- **FastSenseToolbar**: Data cursor (snaps to nearest point), crosshair, grid/legend toggle, Y autoscale, PNG/data export, refresh, live mode, metadata display, violation visibility.
- **DashboardToolbar**: Live toggle, events toggle, edit mode, save/export, config dialog, info panel.
- **NavigatorOverlay**: Minimap with draggable zoom rectangle, used by `SensorDetailPlot`.

### Link Groups
Multiple `FastSense` instances (even across different grids or docks) can share synchronised zoom/pan by assigning the same `LinkGroup` string. When one plot’s XLim changes, all others in the group update automatically.

## Progress Indication

`ConsoleProgressBar` provides a single‑line progress bar with indentation support. It is used hierarchically – for example, a dock’s `renderAll()` prints a header for each tab, then nested per‑tile progress bars. Bars can be frozen permanently to stack multiple stages.

## See Also

- [[MEX Acceleration]] – detailed MEX performance and compilation
- [[Performance]] – tuning tips and benchmarks
- [[API Reference: FastPlot]] – comprehensive API for `FastSense`
- [[Dashboard Engine Guide]] – building dashboards programmatically
- [[Live Mode Guide]] – live data polling patterns
