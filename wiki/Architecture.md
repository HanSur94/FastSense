<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a **render‑once, re‑downsample‑on‑zoom** architecture.  
Rather than transferring millions of points to the GPU, it maintains a lightweight cache
and re‑downsamples only the visible range on every user interaction.

The library is split into several cooperating subsystems:

- **FastSense** – the high‑performance time‑series plot engine (pan/zoom, downsampling, threshold lines, live mode).
- **Tag Domain Model** – typed carriers for sensor data, states, monitors, and derived signals (supports *MonitorTag* condition evaluation and *EventStore* persistence).
- **Event Detection** – live polling, incremental event closure, notification rules, and interactive Gantt viewer.
- **Dashboard Engine** – widget‑based dashboards with gauges, numbers,
  tables, embedded FastSense plots, and edit‑mode builder.
- **WebBridge** – TCP‑server that serves dashboard data to web clients.

All components are designed to run identically on MATLAB and GNU Octave;
MEX acceleration is optional and automatically falls back to pure‑MATLAB code.

## Project Structure

The repository top‑level is `FastPlot/`.  
Below are the major library folders and their key classes:

**`libs/FastSense/`** – Core plotting engine  
`FastSense`, `FastSenseGrid`, `FastSenseDock`, `FastSenseToolbar`,  
`FastSenseTheme`, `FastSenseDataStore`, `NavigatorOverlay`, `SensorDetailPlot`,  
`HoverCrosshair`, `ConsoleProgressBar`, `binary_search`, `build_mex`, `mex_stamp`

**`libs/SensorThreshold/`** – Tag‑based domain model and batch/live pipelines  
`Tag`, `SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `DerivedTag`,  
`TagRegistry`, `BatchTagPipeline`, `LiveTagPipeline`

**`libs/EventDetection/`** – Event engine, persistence, viewer  
`Event`, `EventStore`, `LiveEventPipeline`, `EventViewer`,  
`MatFileDataSource`, `MockDataSource`, `NotificationService`, `NotificationRule`

**`libs/Dashboard/`** – Widget‑based dashboards (serialisable)  
`DashboardEngine`, `DashboardBuilder`, `DashboardLayout`, `DashboardWidget`,  
`DashboardTheme`, `DashboardToolbar`, `DashboardSerializer`, `DashboardPage`,  
`TimeRangeSelector`, widget subclasses (`FastSenseWidget`, `GaugeWidget`, …)
plus `GroupWidget`, `DetachedMirror`, `severityColor`

**`libs/WebBridge/`** – TCP server for live web visualisation  
`WebBridge`, `WebBridgeProtocol`

*Examples* and *tests* sit in `examples/` and `tests/` respectively.

## Render Pipeline (`FastSense.render`)

The main plot creation path:

1. Validate data (X monotonic, dimensions match).
2. Create figure/axes if no parent was provided.
3. Apply the chosen [[Themes|FastSenseTheme]] (background, grid, font).
4. Render back‑layer objects: bands, shaded regions.
5. Determine available pixel width; allocate downsampling buffers.
6. For each line:
   - Downsample the full X‑range to screen resolution (MinMax or LTTB).
   - Create the `hLine` graphics object.
7. Add threshold lines and violation markers.
8. Draw custom markers (foreground).
9. Install an XLim `PostSet` listener for dynamic re‑downsample on zoom/pan.
10. Install a resize listener to adapt downsampling to new pixel width.
11. Set axis limits with 5 % padding and disable auto‑limits.
12. `drawnow` to display.

If data exceeds the `MemoryLimit`, lines are automatically moved to a
disk‑backed store (`FastSenseDataStore`) in `auto` storage mode.

## Zoom / Pan Callback

When the user zooms or pans:

1. XLim listener fires.
2. New XLim is compared with cached value – skip processing if unchanged.
3. For each line:
   - Binary search (O log N) locates visible data indices.
   - A pyramid level with sufficient resolution is selected (built lazily).
   - Visible range is downsampled to ~4 000 points.
   - `hLine.XData` / `YData` are updated using dot‑notation for speed.
4. Violation markers are recomputed (fused SIMD with pixel culling).
5. If a `LinkGroup` is active, XLim is propagated to linked plots.
6. `drawnow limitrate` caps display updates at 20 FPS.

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket keep the minimum and maximum Y.  
Preserves the signal envelope and extreme spikes.  
Runs in O(N/bucket) per bucket.  Handles NaN gaps by processing each contiguous non‑NaN segment independently.

### LTTB (Largest Triangle Three Buckets)
Visually optimal downsampling that maximises triangle area between consecutive buckets to retain shape.  
Slightly slower than MinMax but better fidelity.  
Also respects NaN gaps.

## Lazy Multi‑Resolution Pyramid

To avoid scanning 50M+ points at full zoom‑out, a MinMax pyramid with a configurable reduction factor (default 100× per level) is maintained:

```
Level 0: raw data         (50 000 000 points)
Level 1: 100× reduction   (500 000 points)
Level 2: 100× reduction   (5 000 points)
```

On zoom, the coarsest level with enough resolution is selected.  
Full zoom‑out uses level 2 (5 K points) and downsamples it to ~4 K in < 1 ms.  
Each level is built lazily on first access; the first zoom‑out after data load incurs a one‑time build cost (~70 ms with MEX) – subsequent queries are instant.

## MEX Acceleration

The library ships C MEX files with SIMD intrinsics (AVX2 on x86_64, NEON on arm64).  
They are compiled by `build_mex()` during installation.  
A deterministic fingerprint (`mex_stamp`) ensures that re‑compilation is only triggered when sources change.

| Function                 | Speedup   | Purpose                                   |
|--------------------------|-----------|-------------------------------------------|
| `binary_search_mex`      | 10–20×    | O(log N) visible‑range look‑up            |
| `minmax_core_mex`        | 3–10×     | Per‑pixel MinMax reduction                |
| `lttb_core_mex`          | 10–50×    | LTTB triangle‑area computation            |
| `violation_cull_mex`     | signific. | Fused violation detection + pixel culling |
| `compute_violations_mex` | signific. | Batch violation detection for `resolve()` |
| `resolve_disk_mex`       | signific. | SQLite disk‑based sensor resolution       |
| `build_store_mex`        | 2–3×      | Bulk SQLite writer for `DataStore` init   |
| `to_step_function_mex`   | signific. | SIMD step‑function conversion for thresholds |

All functions share a common `simd_utils.h` abstraction.  
When MEX is unavailable, pure‑MATLAB implementations with identical behaviour are used automatically.

## Data Flow: FastSense Core

```
Raw Data (X,Y arrays)
    ↓
FastSenseDataStore (optional – large datasets)
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
- **Memory mode** – X/Y held in MATLAB workspace.
- **Disk mode** – data chunked into a SQLite database via `FastSenseDataStore`.
- **Auto mode** – automatically switches to disk when total data exceeds `MemoryLimit`.

The `FastSenseDataStore` uses typed BLOBs per chunk (X and Y) with X‑range metadata, enabling O(chunks) overlapping range queries.  
A pre‑computed L1 MinMax pyramid allows instant zoom‑out even from disk.

## Tag Domain Model and Event System

The traditional `Sensor` + `ThresholdRule` model has been replaced by a
**typed Tag hierarchy** that provides a unified, lazy‑evaluation framework
for raw data, state signals, and derived monitoring.

- **[[API Reference: Sensors|SensorTag]]** – holds raw (X, Y) data, can be in‑memory or disk‑backed.
- **StateTag** – piecewise‑constant discrete states (e.g., machine mode).
- **MonitorTag** – evaluates a condition function on a parent tag, producing a 0/1 alarm signal; supports hysteresis (`AlarmOffConditionFn`), debouncing (`MinDuration`), and optional persistence.
- **CompositeTag** – logical aggregation (AND / OR / MAJORITY …) of multiple child monitors.
- **DerivedTag** – arbitrary continuous (X, Y) derived from N parent tags via a `ComputeFn`.

All tags implement `getXY`, `valueAt`, `getTimeRange`, `getKind`, and `toStruct`/`fromStruct` for serialisation.  
Tag registries are managed by `TagRegistry` (singleton key‑value store with two‑phase deserialisation).

### Event Lifecycle

When a `MonitorTag` transitions from 0 to 1 (after debouncing), it produces `Event` objects.  
Events are:

- Opened with `IsOpen = true` and provisional `EndTime`.
- Accumulated by `LiveEventPipeline` and persisted to an `EventStore` (atomic `.mat` file).
- Closed when the monitor returns to 0, setting `EndTime` and final statistics.
- Decorated with severity (`Severity`) and category (`alarm`, `process_change`, …).
- Bound to tags via `EventBinding` (many‑to‑many).

An `EventViewer` renders events as a Gantt timeline with interactive filtering and auto‑refresh.  
[[Event Detection|Event Detection API]] provides full details.

## Dashboard Architecture

FastPlot offers two levels of dashboard composition:

- **[[Dashboard|FastSenseGrid]]** – a tiled grid of `FastSense` instances with synchronized live mode and minimal overhead.
- **[[Dashboard Engine Guide|DashboardEngine]]** – a widget‑based dashboard with gauges, numbers, status icons, tables, embedded FastSense plots, collapsible groups, and an interactive edit‑mode builder.

### DashboardEngine Composition

```
DashboardEngine
├── DashboardToolbar      — Live, Edit, Save, Export, Info
├── TimeRangeSelector     — dual‑slider with preview envelope
├── DashboardLayout       — 24‑column responsive grid (scrollable)
├── DashboardTheme        — inherits FastSenseTheme + dashboard fields
├── DashboardBuilder      — edit mode: palette, drag/resize, properties
├── DashboardSerializer   — JSON save/load and .m script export
└── Pages (DashboardPage)
    └── Widgets (DashboardWidget subclasses)
        ├── FastSenseWidget           — wraps a FastSense instance
        ├── GaugeWidget               — arc, donut, bar, thermometer
        ├── NumberWidget              — big number with trend arrow
        ├── StatusWidget              — coloured dot + label
        ├── TextWidget                — static header or label
        ├── TableWidget               — uitable bound to data or events
        ├── RawAxesWidget             — user‑supplied plot function
        ├── EventTimelineWidget       — event bars on timeline
        ├── MultiStatusWidget         — grid of sensor status indicators
        ├── BarChartWidget, ScatterWidget, HeatmapWidget, ImageWidget,
        │   HistogramWidget, SparklineCardWidget, IconCardWidget,
        │   ChipBarWidget, DividerWidget
        └── GroupWidget               — collapsible, tabbed, or panel groups
```

### Render Flow

1. `DashboardEngine.render()` creates the figure and applies the theme.
2. `DashboardToolbar` is placed at the top; time‑slider panel at the bottom.
3. `DashboardLayout.createPanels()` computes grid positions, creates a scrollable viewport/canvas, and pre‑allocates a `uipanel` per widget.
4. Each widget’s `render(parentPanel)` is called to populate its panel.
5. Global time range is computed by scanning all widgets.
6. The `TimeRangeSelector` draws a preview envelope and event markers.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:

1. All widgets are refreshed via `refresh()` (sensor‑bound widgets re‑read their tag’s Y data; other widgets update displays).
2. The global time range is expanded as new data arrives.
3. Slider positions are re‑applied; stale‑data warnings are shown if any widget’s time range did not advance.

### Edit Mode (DashboardBuilder)

Clicking “Edit” activates the builder overlay:

- A palette sidebar lists addable widget types.
- A properties panel shows the selected widget’s editable fields.
- Drag/resize overlays appear on each widget panel; grid snap rounds positions to columns/rows.
- Widgets can be added, deleted, or rearranged interactively.

### JSON Persistence

`DashboardSerializer` uses a collection of widget‑specific `toStruct()` methods and a static `fromStruct()` dispatcher.  
Multi‑page dashboards are stored with a `pages` array; `TagRegistry.loadFromStructs` provides a two‑pass deserialisation that resolves inter‑tag references.

## Theme Inheritance

Themes cascade in this order:

**Element override** → **Tile theme** → **Figure theme** → **`light`/`dark` preset**

Each level fills in only the fields it specifies; missing values are inherited from the next level down.  
`DashboardTheme` extends `FastSenseTheme` with dashboard‑specific colours (widget background, status colours, etc.).

## Event Detection Architecture (Live Pipeline)

The `LiveEventPipeline` combines the Tag monitor system with configurable data sources:

```
LiveEventPipeline
├── MonitorTargets          — containers.Map (key → MonitorTag)
├── DataSourceMap           — maps sensor keys to DataSource objects
├── EventStore               — atomic .mat file persistence
├── NotificationService      — rule‑based email with PNG snapshots
└── EventViewer               (optional auto‑refresh)
```

**Data Sources:**  
- `MatFileDataSource` – polls `.mat` files for new (X,Y) chunks.  
- `MockDataSource` – generates realistic test signals with configurable violations.  
Custom sources implement the `DataSource.fetchNew()` interface.

**Detection Flow:**  
1. `runCycle()` fetches new data from all sources.  
2. For each `MonitorTag`, the new (X,Y) tail is appended via `MonitorTag.appendData`.  
3. Open events are closed when the monitor returns to 0 (after debounce).  
4. New open events are created for rising edges.  
5. `NotificationService` sends rule‑matched emails, optionally attaching two PNG snapshots (detail + context).

**Escalation:**  
When `EscalateSeverity` is enabled, an event is promoted to the highest threshold crossed; it retains the worst severity ever encountered.

## Progress Indication

`ConsoleProgressBar` prints a single‑line, self‑overwriting bar with optional indentation.  
It is used during batch rendering (`renderAll`, `batchRealize`) and supports hierarchical nesting (e.g., dock → tab → tile).

## Interactive Features

- **[[API Reference: FastPlot|FastSenseToolbar]]** – data cursor, crosshair, grid/legend toggles, autoscale, export PNG/CSV, live mode controls.
- **DashboardToolbar** – live toggle, edit mode, config dialog, export.
- **NavigatorOverlay** – minimap with draggable rectangle for `SensorDetailPlot`.
- **Link Groups** – multiple `FastSense` instances can synchronise zoom/pan by sharing a `LinkGroup` string.
- **HoverCrosshair** – optional hover‑driven vertical line + multi‑line datatip.

## WebBridge

A lightweight TCP server (`WebBridge`) streams dashboard data (values, statuses, event lists) to web clients using a JSON protocol.  
It is designed for embedding FastPlot dashboards in browser‑based supervisors.
```
