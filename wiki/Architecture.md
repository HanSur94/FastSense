<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a **render‑once, re‑downsample‑on‑zoom** architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re‑downsamples only the visible range on every interaction. The library is organised into several independent but cooperating modules:

- **FastSense** – core high‑performance time‑series rendering engine
- **Dashboard** – widget‑based dashboard builder with editable layouts
- **SensorThreshold** – Tag‑based domain model for sensors, states, thresholds, and derived signals (v2.0)
- **EventDetection** – live threshold violation detection, event storage, and notification
- **WebBridge** – TCP server for streaming dashboards to a browser

## Project Structure

```
FastPlot/
├── install.m                        # Path install + MEX compilation
├── libs/
│   ├── FastSense/                    # Core plotting engine
│   │   ├── FastSense.m               # Main class
│   │   ├── FastSenseGrid.m           # Tiled layout manager
│   │   ├── FastSenseDock.m           # Tabbed container
│   │   ├── FastSenseToolbar.m        # Interactive toolbar
│   │   ├── FastSenseTheme.m          # Theme system
│   │   ├── FastSenseDataStore.m      # SQLite‑backed chunked storage
│   │   ├── SensorDetailPlot.m        # Sensor detail view with navigator
│   │   ├── NavigatorOverlay.m        # Minimap zoom rectangle
│   │   ├── ConsoleProgressBar.m      # Console progress indication
│   │   ├── binary_search.m           # Binary search (MEX or pure MATLAB)
│   │   ├── build_mex.m               # MEX compilation script
│   │   └── private/                  # Internal algorithms + MEX sources
│   ├── SensorThreshold/              # Sensor, state, threshold, and Tag system
│   │   ├── Tag.m                     # Abstract base for Tag domain model
│   │   ├── SensorTag.m               # Concrete sensor data tag
│   │   ├── StateTag.m                # Discrete state signals (ZOH lookup)
│   │   ├── MonitorTag.m              # Binary alarm derived from one parent
│   │   ├── CompositeTag.m            # Aggregation of multiple MonitorTags
│   │   ├── DerivedTag.m              # Continuous derived signal from N parents
│   │   ├── TagRegistry.m             # Singleton catalog of Tag objects
│   │   ├── BatchTagPipeline.m        # One‑shot ingestion of raw files → .mat
│   │   └── LiveTagPipeline.m         # Timer‑driven live ingestion
│   ├── EventDetection/               # Event detection and viewer
│   │   ├── Event.m                   # Single violation event
│   │   ├── EventStore.m              # Atomic .mat‑file persistence
│   │   ├── EventViewer.m             # Gantt timeline + filterable table
│   │   ├── LiveEventPipeline.m       # Real‑time MonitorTag‑based detection
│   │   ├── NotificationService.m     # Email alerts with snapshots
│   │   ├── MatFileDataSource.m       # File‑based data source
│   │   ├── MockDataSource.m          # Test signal generator
│   │   └── EventBinding.m            # Many‑to‑many Event–Tag index
│   ├── Dashboard/                    # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m         # Top‑level orchestrator
│   │   ├── DashboardLayout.m         # 24‑column responsive grid
│   │   ├── DashboardBuilder.m        # Edit‑mode overlay
│   │   ├── DashboardSerializer.m     # JSON save/load + .m export
│   │   ├── DashboardTheme.m          # Extended theme with dashboard fields
│   │   ├── DashboardToolbar.m        # Global toolbar
│   │   └── Widgets (DashboardWidget subclasses)
│   │       ├── FastSenseWidget.m, GaugeWidget.m, NumberWidget.m,
│   │       ├── StatusWidget.m, TextWidget.m, TableWidget.m,
│   │       ├── RawAxesWidget.m, EventTimelineWidget.m, GroupWidget.m,
│   │       ├── MultiStatusWidget.m, BarChartWidget.m, ScatterWidget.m,
│   │       ├── HeatmapWidget.m, HistogramWidget.m, ImageWidget.m,
│   │       ├── ChipBarWidget.m, IconCardWidget.m, SparklineCardWidget.m,
│   │       ├── DividerWidget.m,
│   │       └── MarkdownRenderer.m
│   └── WebBridge/                    # TCP server for web visualisation
│       ├── WebBridge.m
│       └── WebBridgeProtocol.m
├── examples/                         # 40+ runnable examples
└── tests/                            # 30+ test suites
```

## Render Pipeline

When `render()` is called on a `FastSense` instance:

1. Create figure/axes if no `ParentAxes` is supplied
2. Validate all data — X must be monotonic, dimensions must match
3. Optionally switch to disk‑backed storage (`FastSenseDataStore`) if total data exceeds `MemoryLimit`
4. Allocate downsampling buffers based on axes pixel width (`DownsampleFactor` points per pixel)
5. For each line: compute an initial downsample of the full X range, create a line graphics object
6. Create threshold lines, violation markers, horizontal bands, shaded regions, custom markers
7. Install an `XLim` `PostSet` listener on the axes to react to zoom/pan events
8. Set initial axis limits with 5% padding, disable autoscaling
9. Call `drawnow` to display the completed plot
10. Register the instance in its `LinkGroup` for synchronised zoom/pan across plots

## Zoom / Pan Callback

When the user zooms or pans:

1. The `XLim` listener fires.
2. New limits are compared to the cached value; if unchanged, no action is taken.
3. For each line:
   - Binary search on X to find the visible index range – O(log N)
   - Select the coarsest pyramid level with sufficient resolution for the current view
   - Build that pyramid level lazily if it doesn’t exist yet
   - Downsample the visible range to ~4000 points (accommodating typical screen width)
   - Update the graphics handle’s `XData` and `YData` via dot‑notation assignment for speed
4. Recompute threshold violation markers (fused SIMD with pixel culling when MEX is available)
5. If the plot belongs to a `LinkGroup`, propagate the new XLim to all other plots in the group
6. Issue `drawnow limitrate` to cap the refresh rate at ~20 FPS

## Downsampling Algorithms

Two algorithms are available for reducing millions of points to a few thousand:

### MinMax
For each pixel bucket, remember the **minimum and maximum** Y value found among the points in that bucket. This preserves the signal envelope and ensures extreme values are never hidden. Complexity per bucket is O(N/bucket), where N is the number of visible raw points.

### LTTB (Largest Triangle Three Buckets)
Visually optimal downsampling that maximises triangle area between consecutive buckets, producing a shape‑preserving line trace. It yields better visual fidelity for slowly changing signals but is slightly more computationally expensive than MinMax.

Both algorithms handle NaN gaps by treating contiguous non‑NaN regions independently.

## Lazy Multi‑Resolution Pyramid

A full scan of all data at every zoom level would be O(N). Instead, FastPlot builds a **lazy MinMax pyramid** with a configurable reduction factor (default 100× per level):

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100× reduction   (   500,000 points)
Level 2: 100× reduction   (     5,000 points)
```

When the user zooms, the coarsest level that still provides at least 1 point per pixel column is selected. For a fully zoomed‑out view, the system reads level 2 (5K points) and downsamples to ~4K points in under 1 ms. Levels are built **lazily** on first access; the initial zoom‑out pays a one‑time build cost (~70 ms with MEX), after which all queries are instantaneous.

## MEX Acceleration

Optional C MEX functions, compiled from source in `libs/FastSense/private/mex_src/`, accelerate the most performance‑critical paths with platform‑appropriate SIMD instructions (AVX2 on x86‑64, NEON on arm64). If a MEX binary is not available for a particular function, a pure‑MATLAB fallback is used automatically, preserving identical behaviour.

| Function | Speedup | Description |
|----------|---------|-------------|
| `binary_search_mex` | 10–20× | O(log N) visible range lookup |
| `minmax_core_mex` | 3–10× | Per‑pixel MinMax reduction kernel |
| `lttb_core_mex` | 10–50× | Triangle area computation for LTTB |
| `violation_cull_mex` | significant | Fused violation detection + pixel culling |
| `compute_violations_mex` | significant | Batch violation detection for `Sensor.resolve()` (disk mode) |
| `resolve_disk_mex` | significant | Disk‑based sensor threshold resolution |
| `build_store_mex` | 2–3× | Bulk SQLite writer for `FastSenseDataStore` initialisation |
| `to_step_function_mex` | significant | SIMD step‑function conversion for thresholds |

All MEX sources share a common `simd_utils.h` header. The compilation script (`build_mex.m`) automatically detects the CPU architecture and selects the best compiler (GCC for Octave, platform default for MATLAB).

## Data Flow Architecture

### Core Data Path

```
Raw Data (X, Y arrays)
    ↓
FastSenseDataStore (optional, for large datasets exceeding memory)
    ↓
Downsampling Engine (MinMax / LTTB)
    ↓
Pyramid Cache (lazy multi‑resolution)
    ↓
Graphics Objects (line handles)
    ↓
Interactive Display
```

The core engine can operate in two modes:

- **Memory mode** – X/Y arrays held directly in the MATLAB workspace.
- **Disk mode** – Data is chunked and stored in a SQLite database via `FastSenseDataStore`. Only chunks overlapping the visible X range are loaded on each zoom/pan event.

When the `StorageMode` is `'auto'`, the system automatically switches to disk mode if the total memory footprint exceeds the `MemoryLimit` property (default 500 MB).

## Disk‑Backed Data Storage (`FastSenseDataStore`)

For datasets exceeding available memory (100M+ points), `FastSenseDataStore` provides SQLite‑backed chunked storage:

1. Data is split into chunks (~10K – 500K points each, auto‑tuned).
2. Each chunk is stored as a pair of typed BLOBs (X and Y) with the chunk’s X range indexed in the database.
3. During zoom/pan, only chunks overlapping the visible range are loaded, trimmed, and concatenated.
4. A pre‑computed MinMax pyramid (level 1) is stored alongside, enabling instant full‑range overview.

The bulk‑write path uses `build_store_mex`, a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing tens of thousands of individual SQLite round‑trips. If the `mksqlite` MEX interface is unavailable, a binary‑file fallback is used transparently.

## Theme Inheritance

The FastPlot theme system (`FastSenseTheme`, `DashboardTheme`) uses a cascade:

```
Element‑specific override → Tile theme → Figure theme → Preset ('light' or 'dark')
```

Each level fills in only the fields it specifies; missing fields inherit from the next level. This design allows sweeping style changes via a single preset while still permitting fine‑grained per‑widget overrides.

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[[Dashboard|FastSenseGrid]]** – Simple tiled grid of `FastSense` instances, ideal for lightweight, synchronised live‑mode dashboards.
- **[[Dashboard Engine Guide|DashboardEngine]]** – Full widget‑based dashboard with gauges, numbers, status indicators, tables, timelines, edit mode, and JSON save/load.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar      — Live, Edit, Export, Sync, Info buttons
├── DashboardLayout       — 24‑column responsive grid with scrollable canvas
├── DashboardTheme        — FastSenseTheme extended with dashboard‑specific colours
├── DashboardBuilder      — Edit‑mode overlay (drag/resize, palette, properties)
├── DashboardSerializer   — JSON save/load and .m script export
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (Sensor/Tag/DataStore/inline data)
    ├── GaugeWidget            — Arc, donut, bar, thermometer styles
    ├── NumberWidget            — Big number with trend arrow
    ├── StatusWidget           — Coloured dot indicator (sensor‑first or threshold‑based)
    ├── TextWidget             — Static label or section header
    ├── TableWidget            — uitable display (sensor data or events)
    ├── RawAxesWidget          — User‑supplied plot function on raw axes
    ├── EventTimelineWidget    — Coloured event bars on a timeline
    ├── GroupWidget            — Collapsible panels, tabbed containers
    ├── MultiStatusWidget      — Grid of sensor status dots
    ├── SparklineCardWidget    — KPI card with sparkline and delta
    ├── IconCardWidget         — Mushroom‑style card with state‑coloured icon
    ├── ChipBarWidget          — Compact horizontal row of status chips
    ├── DividerWidget          — Decorative divider line
    └── MarkdownRenderer.m     — Converts subset of Markdown to HTML
```

### Live Mode

When live mode is started (either at the `FastSense`, `FastSenseGrid`, or `DashboardEngine` level), a repeating timer:
1. Polls the configured data file (or `DataSource` / pipeline) for new data.
2. Updates the global time range if it expands.
3. Calls `refresh()` on every widget — sensor‑bound widgets re‑read the latest sample(s).
4. For `FastSenseWidget`, the refresh uses an incremental `updateData()` call to preserve zoom state.
5. The toolbar timestamp is updated and the time sliders are re‑applied.

### Edit Mode

Clicking “Edit” in the dashboard toolbar activates `DashboardBuilder`:

1. A palette sidebar (left) lists available widget types.
2. A properties panel (right) shows settings of the selected widget.
3. Drag/resize overlays appear on top of each widget panel.
4. Grid snapping rounds positions to the nearest column/row.
5. On exit, the layout is persisted via `DashboardSerializer`.

### JSON Persistence

- **Save** – each widget’s `toStruct()` returns a plain struct. The heterogeneous arrays are manually assembled into a JSON string.
- **Load** – the JSON is parsed, and each widget struct is dispatched to the appropriate `fromStruct()` static method. An optional `SensorResolver` function handle rebinds Sensor objects by name.

## MEX Fallback Mechanism

Every performance‑critical operation first checks for the presence of a compiled MEX file:

```matlab
persistent useMex;
if isempty(useMex)
    useMex = (exist('binary_search_mex', 'file') == 3);
end
if useMex
    idx = binary_search_mex(x, val, direction);
    return;
end
% --- Pure-MATLAB iterative binary search ---
...
```

If the MEX file is not on the path (e.g., because compilation failed or the system does not have a compiler), the pure‑MATLAB implementation is used automatically. The behaviour is identical — the MEX functions are drop‑in replacements.

## Link Groups

Multiple `FastSense` instances can share a synchronised zoom/pan range by assigning them the same `LinkGroup` string. When one plot’s XLim changes, all other plots in the same group are updated automatically. This mechanism works across different figures and even tabs within a `FastSenseDock`.

## Event Detection Architecture

The event system is built on the Tag domain model (v2.0). Key components:

```
LiveEventPipeline
├── MonitorTargets     — containers.Map of MonitorTag(s) to evaluate
├── DataSourceMap      — maps tag keys to DataSource instances
├── EventStore         — thread‑safe .mat persistence
├── NotificationService— rule‑based email alerts with plot snapshots
└── EventViewer        — interactive Gantt chart + filterable table
```

### Detection Flow

1. `LiveEventPipeline.runCycle()` polls all data sources for new data.
2. New data is applied to the parent tag (`updateData`), then pushed through each `MonitorTag`’s `appendData` method (streaming extension of the binary alarm series).
3. Complete open‑then‑close events are extracted from the monitor’s output, debounced by `MinDuration`.
4. Events are appended to the `EventStore` and optionally forwarded to `NotificationService`.
5. Active `EventViewer` instances auto‑refresh to show new events.

### Hierarchical Resolution

Complex threshold logic is expressed through the `MonitorTag` hierarchy: a `MonitorTag` can observe another `MonitorTag` , allowing logical combinations (AND/OR/MAJORITY/COUNT etc.) via `CompositeTag`, and continuous arithmetic derivation via `DerivedTag`. This replaces the older fixed `Sensor.resolve()` algorithm with a composable, lazy‑by‑default pipeline.

## Progress Indication

`ConsoleProgressBar` renders a single‑line, overwriting progress bar in the MATLAB console. It supports:

- Indentation for hierarchical operations (e.g., dock → tab → tile).
- `freeze()` to permanently commit a completed bar to the console, allowing a new bar to appear on the next line.
- `finish()` as a shortcut to 100% completion.

Template for progress output is used throughout the library (`FastSenseGrid`, `DashboardEngine`, `FastSenseDock`).

## Interactive Features

### Toolbars and Navigation
- **[[API Reference: FastPlot|FastSenseToolbar]]** – Data cursor, crosshair, grid/legend toggles, autoscale, PNG/data export, live mode.
- **DashboardToolbar** – Live toggle, edit mode, config dialog, image export, info panel.
- **NavigatorOverlay** – Minimap with draggable zoom rectangle for `SensorDetailPlot`.

### Link Groups
See the dedicated section above.
