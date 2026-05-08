<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a **render-once, re-downsample‑on‑zoom** architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight multi‑resolution pyramid cache and re‑downsamples only the visible range on every interaction. This approach keeps zoom/pan fluid even for datasets with 100M+ samples.

The core rendering engine is **FastSense**, which provides high‑performance time‑series plots. Higher‑level components include **FastSenseGrid** (tiled dashboards), **DashboardEngine** (widget‑based dashboards with gauges, numbers, event timelines), and the **Event Detection** pipeline. A unified **Tag** domain model (v2.0) replaces legacy Sensor/Threshold classes, offering a consistent abstraction for raw sensors, discrete states, monitors, composites, and derived signals.

## Project Structure

```
FastPlot/
├── install.m                        # Path setup + MEX compilation
├── libs/
│   ├── FastSense/                   # Core plotting engine
│   │   ├── FastSense.m              # Main class
│   │   ├── FastSenseGrid.m          # Tiled dashboard layout
│   │   ├── FastSenseDock.m          # Tabbed container
│   │   ├── FastSenseToolbar.m       # Interactive toolbar
│   │   ├── FastSenseTheme.m         # Theme system
│   │   ├── FastSenseDataStore.m     # SQLite-backed chunked storage
│   │   ├── SensorDetailPlot.m       # Sensor detail view with navigator
│   │   ├── NavigatorOverlay.m       # Minimap zoom rectangle
│   │   ├── ConsoleProgressBar.m     # Hierarchical progress bars
│   │   ├── HoverCrosshair.m         # Hover-driven crosshair + datatip
│   │   ├── binary_search.m          # Binary search utility (MEX‑accelerated)
│   │   ├── build_mex.m              # MEX compilation script
│   │   ├── mex_stamp.m              # Fingerprint for MEX cache validation
│   │   └── private/                 # Internal algorithms + MEX sources
│   ├── SensorThreshold/             # Tag domain model + registry
│   │   ├── Tag.m                    # Abstract base
│   │   ├── SensorTag.m              # Raw sensor data
│   │   ├── StateTag.m               # Discrete state signals (ZOH)
│   │   ├── MonitorTag.m             # Binary 0/1 monitor (lazy)
│   │   ├── CompositeTag.m           # Multi‑child aggregator
│   │   ├── DerivedTag.m             # Continuous derived signal
│   │   ├── TagRegistry.m            # Singleton catalog
│   │   ├── BatchTagPipeline.m       # Bulk raw‑data → per‑tag .mat
│   │   ├── LiveTagPipeline.m        # Timer‑driven raw‑data → .mat
│   │   └── private/                 # Resolution / parse helpers
│   ├── EventDetection/              # Event detection and viewer
│   │   ├── EventStore.m             # Thread‑safe .mat persistence
│   │   ├── Event.m                  # Event handle
│   │   ├── EventBinding.m           # Many‑to‑many Event↔Tag registry
│   │   ├── LiveEventPipeline.m      # Monitor‑based live detection
│   │   ├── EventViewer.m            # Gantt + table GUI
│   │   ├── NotificationService.m    # Email alerts with snapshots
│   │   ├── DataSource.m             # Abstract data source
│   │   ├── MatFileDataSource.m      # File‑based polling
│   │   ├── MockDataSource.m         # Test data generator
│   │   ├── NotificationRule.m       # Per‑sensor/threshold notification rules
│   │   └── private/                 # Internal utilities
│   ├── Dashboard/                   # Widget‑based dashboard engine
│   │   ├── DashboardEngine.m        # Top‑level orchestrator
│   │   ├── DashboardLayout.m        # 24‑column responsive grid + scrolling
│   │   ├── DashboardTheme.m         # Dashboard‑specific theme fields
│   │   ├── DashboardToolbar.m       # Toolbar with Live, Export, Config
│   │   ├── DashboardBuilder.m       # Edit‑mode drag/resize + palette
│   │   ├── DashboardSerializer.m    # JSON save/load + .m script export
│   │   ├── DashboardPage.m          # Multi‑page container
│   │   ├── DashboardProgress.m      # Render progress feedback
│   │   ├── DashboardWidget.m        # Abstract widget base
│   │   ├── FastSenseWidget.m        # FastSense chart wrapper
│   │   ├── GaugeWidget.m            # Arc/donut/bar/thermometer gauge
│   │   ├── NumberWidget.m           # Big number + trend arrow
│   │   ├── StatusWidget.m           # Colored dot indicator
│   │   ├── TextWidget.m             # Static label / header
│   │   ├── TableWidget.m            # uitable display
│   │   ├── RawAxesWidget.m          # User‑supplied plot function
│   │   ├── EventTimelineWidget.m    # Colored event bars on timeline
│   │   ├── GroupWidget.m            # Collapsible panels / tabs
│   │   ├── MultiStatusWidget.m      # Grid of sensor status dots
│   │   ├── IconCardWidget.m         # Mushroom‑style icon + value + label
│   │   ├── ChipBarWidget.m          # Compact row of status chips
│   │   ├── SparklineCardWidget.m    # Big number + sparkline + delta
│   │   ├── DividerWidget.m          # Horizontal separator
│   │   ├── BarChartWidget.m         # Bar chart via raw axes
│   │   ├── ScatterWidget.m          # Scatter plot
│   │   ├── HeatmapWidget.m          # 2‑D color grid
│   │   ├── HistogramWidget.m        # Histogram
│   │   ├── ImageWidget.m            # Embedded image
│   │   ├── MarkdownRenderer.m       # Markdown‑to‑HTML converter
│   │   ├── TimeRangeSelector.m      # Dual‑slider time scrubber
│   │   └── DetachedMirror.m         # Live mirror in standalone figure
│   └── WebBridge/                   # TCP server for web visualization
│       ├── WebBridge.m
│       └── WebBridgeProtocol.m
├── examples/                        # 40+ runnable examples
└── tests/                           # 30+ test suites
```

## Render Pipeline

The core render sequence in **FastSense** (and [FastSenseWidget]()) follows these steps:

1. User calls `render()` (or `renderAll()` for grids).
2. Create figure and axes if no parent is provided.
3. Validate all input: X monotonic, dimensions match.
4. If total data size exceeds `MemoryLimit`, switch to disk-based storage (`FastSenseDataStore`).
5. Compute the number of visible pixels and allocate downsampling buffers accordingly.
6. **Initial downsample** of the full X-range for each line, using MinMax or LTTB, yielding ~4 000 points.
7. Create graphics objects (lines, bands, shadings, threshold lines, markers).
8. Install a `XLim` `PostSet` listener to catch zoom/pan events.
9. Set initial axis limits (5% padding), disable auto‑limits.
10. Execute `drawnow` to display.

For **DashboardEngine**, the render flow is:

1. `DashboardEngine.render()` creates the figure.
2. `DashboardTheme(preset)` generates the full theme struct.
3. `DashboardToolbar` and (optionally) a multi‑page tab bar and time slider panel are created.
4. `DashboardLayout.allocatePanels()` computes grid positions, creates viewport/canvas/scrollbar, and pre‑allocates a `uipanel` for each widget.
5. Each widget’s `render(parentPanel)` populates its panel (e.g., `FastSenseWidget` creates a `FastSense` inside it).
6. `updateGlobalTimeRange()` scans widgets for data bounds and configures the dual time sliders.

## Zoom/Pan Callback

Whenever the user zooms or pans:

1. The `XLim` listener fires.
2. Compare new limits to cached values; skip if unchanged.
3. For each line:
   - Perform a binary search (O(log N)) to find the visible X indices.
   - Select the coarsest pyramid level that still provides sufficient resolution.
   - If the level does not exist, build it lazily.
   - Downsample the visible range to ≈4 000 screen points.
   - Update the line’s `XData`/`YData` using dot‑notation (fast assignment).
4. Recompute threshold violation markers and event‑layer markers (if enabled).
5. If `LinkGroup` is active, propagate the new `XLim` to all linked plots.
6. Call `drawnow limitrate` to cap the update rate at ~20 FPS.

Downsampling and pyramid‑level selection keep the per‑frame cost essentially independent of the total dataset size.

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket, keep the minimum **and** maximum Y values. This preserves the signal envelope and extreme spikes. Complexity is O(N / bucket_width) per bucket.

### LTTB (Largest Triangle Three Buckets)
A visually optimal technique that selects one representative point per bucket by maximizing the triangle area formed with the previous and next bucket’s chosen point. Provides better visual fidelity for smooth curves, but slower than MinMax.

Both algorithms handle NaN gaps by processing contiguous non‑NaN segments independently.

> **MEX acceleration** boosts MinMax by 3‑10× and LTTB by 10‑50× – see [MEX Acceleration]().

## Lazy Multi-Resolution Pyramid

Problem: at full zoom‑out, scanning 50M+ points is O(N) and unacceptable.

Solution: a pre‑computed MinMax pyramid with a configurable reduction factor (default **100× per level**):

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100× reduction   (   500,000 points)
Level 2: 100× reduction   (     5,000 points)
```

When the user zooms out, the coarsest level with enough resolution is selected. A full zoom‑out reads level 2 (5 K points) and downsamples to ~4 K in under **1 ms**.

Each level is **built lazily** on first access. The initial build cost (≈70 ms with MEX) is paid once; subsequent queries are instant.

The pyramid is maintained in memory for active lines and, for disk‑backed data (`FastSenseDataStore`), a pre‑computed L1 MinMax pyramid is stored alongside chunks to accelerate zoom‑out without touching raw data.

## MEX Acceleration

Optional C MEX functions with SIMD intrinsics (AVX2 on x86‑64, NEON on ARM64) accelerate the most performance‑critical paths:

| Function | Speedup | Description |
|----------|---------|-------------|
| `binary_search_mex` | 10‑20× | O(log n) visible range lookup |
| `minmax_core_mex` | 3‑10× | Per‑pixel MinMax reduction |
| `lttb_core_mex` | 10‑50× | Triangle area computation |
| `violation_cull_mex` | significant | Fused detection + pixel culling |
| `compute_violations_mex` | significant | Batch violation detection for `resolve()` (legacy) |
| `resolve_disk_mex` | significant | SQLite disk‑based resolution |
| `build_store_mex` | 2‑3× | Bulk SQLite writer for `DataStore` init |
| `to_step_function_mex` | significant | SIMD step‑function conversion for thresholds |

Plus the `mksqlite` interface (compiled with a bundled SQLite3 amalgamation) for high‑speed database access.

All functions share a common `simd_utils.h` abstraction layer. When MEX is unavailable or compilation fails (e.g., AVX2 failure retries with SSE2), a pure‑MATLAB fallback is used with identical behaviour. The install process determines whether to recompile via a **MEX stamp** (`mex_stamp.m`) that fingerprints all source files.

See [[MEX Acceleration]] for more details.

## Data Flow Architecture

### Core Data Path (FastSense)

```
Raw Data (X, Y arrays)  →  FastSenseDataStore (optional, large data)
                            ↓
                    Downsampling Engine (MinMax / LTTB)
                            ↓
                    Pyramid Cache (lazy multi‑resolution)
                            ↓
                    Graphics Objects (line handles)
                            ↓
                    Interactive Display (zooms trigger re‑downsample)
```

### Tag‑to‑Widget Data Path (DashboardEngine)

```
SensorTag / MonitorTag / DerivedTag …
    ↓  (via getXY())
FastSenseWidget.update() or FastSense.updateData()
    ↓
FastSense internal pipeline (downsample → pyramid → plot)
```

MonitorTags and DerivedTags are **lazy** – their output is cached and recomputed only when a parent fires an `invalidate()` notification. This observer pattern flows through the entire derivation graph.

### Storage Modes

- **Memory mode**: X/Y arrays held directly in MATLAB workspace.
- **Disk mode**: Data stored as chunked BLOBs in a SQLite database via `FastSenseDataStore`.
- **Auto mode**: Automatically switches to disk when total data size exceeds `MemoryLimit` (default 500 MB).

## Sensor Threshold Resolution (v2.0)

The legacy `Sensor.resolve()` has been superseded by the **Tag** domain model. Instead of evaluating definitions per segment, threshold violations are generated by **MonitorTag** objects:

1. A `MonitorTag` wraps a parent `Tag` (e.g., `SensorTag` or `StateTag`) and a `ConditionFn` (e.g., `@(x,y) y > 50`).
2. `getXY()` returns a 0/1 time series aligned to the parent’s native grid (lazy‑evaluated).
3. **Hysteresis** is supported via an optional `AlarmOffConditionFn`.
4. **Debouncing** with `MinDuration` ensures that transient violations shorter than a minimum time are not reported.
5. **CompositeTag** aggregates multiple `MonitorTag`/`CompositeTag` children using boolean operators (AND, OR, MAJORITY, COUNT, WORST, SEVERITY) or a custom function.
6. **DerivedTag** produces continuous (X,Y) signals computed from N parent Tags.

Live detection uses `LiveEventPipeline`, which polls `DataSource` objects, pushes new data into parent Tags, and then calls `appendData` on `MonitorTag` objects. Events are emitted, stored via `EventStore`, and may trigger `NotificationService` for email alerts. `EventTimelineWidget` and `FastSense` (via `EventStore.Events`) display detected events.

## Disk-Backed Data Storage

`FastSenseDataStore` provides SQLite‑backed chunked storage for datasets exceeding available memory:

1. Data is split into chunks (~10 K‑500 K points each, auto‑tuned).
2. Each chunk is stored as a pair of typed BLOBs (`X` and `Y`) with the chunk’s X‑range indexed for fast overlap queries.
3. On zoom/pan, only chunks intersecting the visible range are loaded.
4. A pre‑computed L1 MinMax pyramid (stored alongside chunks) enables instant zoom‑out without touching raw data.
5. Monitoring tags can persist their derived (X,Y) using `storeMonitor` / `loadMonitor`, validated via a quad‑signature for cache freshness.

The bulk write path uses `build_store_mex`, a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing thousands of individual SQLite round‑trips.

When SQLite is unavailable, a binary‑file fallback is used automatically.

## Theme Inheritance

Themes cascade with a clear hierarchy:

```
Element override  →  Tile theme  →  Figure theme  →  'default' preset
```

`FastSenseTheme` defines standard plot properties (colors, fonts, line styles). `DashboardTheme` extends these with dashboard‑specific fields (widget backgrounds, header colors, gauge colours). Any property not explicitly set at a given level inherits from the next broader level.

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[[FastPlot|FastSenseGrid]]**: A simple tiled grid of `FastSense` instances with synchronized live mode – ideal for quick, multi‑panel time‑series dashboards.
- **[[Dashboard Engine Guide|DashboardEngine]]**: A full widget‑based system supporting gauges, numbers, status indicators, tables, event timelines, and an interactive edit mode.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar       — Top toolbar (Live, Export, Image, Config, Events)
├── DashboardLayout        — 24‑column responsive grid with scrollable canvas
├── DashboardTheme         — FastSenseTheme + dashboard‑specific fields
├── DashboardBuilder       — Edit mode overlay (drag/resize, palette, properties)
├── DashboardSerializer    — JSON save/load and .m script export
├── TimeRangeSelector      — Dual‑slider time scrubber with preview envelope
├── DashboardPage          — Named page container for multi‑page dashboards
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget          — FastSense instance (Tag / DataStore / inline)
    ├── GaugeWidget             — Arc/donut/bar/thermometer gauge
    ├── NumberWidget             — Big number with trend arrow
    ├── StatusWidget             — Colored dot indicator
    ├── TextWidget               — Static label or header
    ├── TableWidget              — uitable display
    ├── RawAxesWidget           — User‑supplied plot function
    ├── EventTimelineWidget     — Colored event bars on timeline
    ├── GroupWidget             — Collapsible panels, tabbed containers
    ├── MultiStatusWidget       — Grid of sensor status dots
    ├── IconCardWidget          — Compact card with icon, value, label
    ├── ChipBarWidget           — Horizontal row of mini status chips
    ├── SparklineCardWidget     — KPI card with sparkline + delta
    ├── DividerWidget           — Horizontal separator
    ├── BarChartWidget          — Bar chart
    ├── ScatterWidget           — Scatter plot
    ├── HeatmapWidget           — 2‑D colour map
    ├── HistogramWidget         — Histogram
    │── ImageWidget             — Embedded image
    └── DetachedMirror          — Live clone in standalone figure
```

### Render and Live Mode

- **Render flow**: Figure creation → theme application → toolbar/time‑slider → `allocatePanels` (lazy widget rendering) → `updateGlobalTimeRange()`.
- **Live mode**: A single timer calls `updateLiveTimeRange()` and then `refresh()` on every widget. Widgets that support incremental updates (like `FastSenseWidget`) use `updateData()` to avoid full rebuilds. A stale‑data banner appears when no new data is detected.
- **Edit mode**: Clicking the Edit button activates `DashboardBuilder`, which overlays drag/resize rectangles, a widget palette sidebar, and a properties panel.
- **Export**: `DashboardSerializer` can export the layout to JSON or a standalone `.m` script.

## Event Detection Architecture

The event system uses the **MonitorTag** pipeline instead of legacy `Sensor.resolve()`. Core components:

```
LiveEventPipeline
├── DataSourceMap          — Maps sensor keys to data sources
├── MonitorTargets         — containers.Map of key → MonitorTag
├── EventStore             — Atomic .mat file persistence
├── NotificationService    — Rule‑based email alerts with snapshots
└── EventViewer           — Gantt chart + filterable table
```

### Detection Flow

1. `LiveEventPipeline.runCycle()` polls all data sources.
2. New data is split per sensor and fed into the corresponding `MonitorTarget` via `appendData()`.
3. Inside `MonitorTag`, the hysteresis FSM and `MinDuration` debouncing produce binary alarm states.
4. Events are grouped, assigned an `Id`, and stored via `EventStore.append()`.
5. `EventBinding` links events to tag keys for many‑to‑many queries.
6. `NotificationService` evaluates rules and sends email alerts (optionally with plot snapshots).
7. Active `EventViewer` instances auto‑refresh to display new events.

Severity escalation (`Severity` field) and manual annotations are supported via `Event` handles and the `EventDetails` popup.

## Progress Indication

`ConsoleProgressBar` provides hierarchical, non‑blocking progress output to the command window:

- Single‑line updates with backspace‑based overwriting.
- Indentation support for nested operations (e.g., dock → tabs → tiles).
- `freeze()` / `finish()` transition a bar to a permanent line, allowing the next bar to start below.

`DashboardProgress` wraps this for the dashboard render pass, showing per‑widget progress while respecting the configured `ProgressMode` (auto/on/off).

## Interactive Features

### Toolbars and Navigation
- **[[API Reference: FastPlot|FastSenseToolbar]]**: Data cursor, crosshair, grid/legend toggles, autoscale, export, live toggle.
- **DashboardToolbar**: Live, Export Image, Config, Events toggle, Info modal.
- **NavigatorOverlay**: Minimap with draggable zoom rectangle (used in `SensorDetailPlot`).
- **HoverCrosshair**: A vertical crosshair + multi‑line datatip that follows the mouse cursor. Coexists with the toolbar’s crosshair mode without conflict.

### Link Groups
Multiple `FastSense` instances can share synchronized zoom/pan via a `LinkGroup` string. When one plot’s `XLim` changes, the new limits are broadcast to all members of the same group.

### Detached Mirrors
Any [`DashboardWidget`]() can be popped out into a standalone figure window using `DashboardEngine.detachWidget()`. The detached mirror is a lightweight clone that stays live via the main dashboard’s timer, refreshing its content without maintaining a full duplicate pipeline.

### Info Panel
DashboardEngine supports a linked Markdown file (`InfoFile`). It is rendered to HTML (`MarkdownRenderer`) and displayed either in‑app (modal `uifigure` with `uihtml`) or in a system browser, providing contextual documentation for the dashboard.
