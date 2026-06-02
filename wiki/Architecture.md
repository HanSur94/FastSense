<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a render‑once, re‑downsample‑on‑zoom architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re‑downsamples only the visible range on every interaction. A dynamic downsampling engine, lazy multi‑resolution pyramid, and optional MEX acceleration ensure that datasets from a few hundred to over 100 million points remain responsive during pan and zoom.

The library is modular, with separate subsystems for plotting, dashboard layout, interactive tools, sensor threshold management, tag‑based data pipelines, event detection, and client‑side persistence, all cooperating through well‑defined interfaces.

## Project Structure

```
FastPlot/
├── install.m                        # Paths + MEX compilation
├── libs/
│   ├── FastSense/                    # Core plotting engine
│   │   ├── FastSense.m               # Main plotting class
│   │   ├── FastSenseGrid.m          # Tiled layout with link groups
│   │   ├── FastSenseDock.m          # Tabbed multi‑dashboard container
│   │   ├── FastSenseToolbar.m        # Interactive toolbar
│   │   ├── FastSenseTheme.m          # Theme system
│   │   ├── FastSenseDataStore.m      # SQLite‑backed chunked storage
│   │   ├── SensorDetailPlot.m        # Navigator + detail view
│   │   ├── NavigatorOverlay.m        # Minimap interactivity
│   │   ├── HoverCrosshair.m         # Hover‑driven cross‑hair
│   │   ├── ConsoleProgressBar.m      # Hierarchical progress
│   │   ├── binary_search.m           # O(log N) search
│   │   └── build_mex.m              # Compile MEX with SIMD
│   ├── SensorThreshold/              # Tag‑based domain model
│   │   ├── Tag.m                     # Abstract tag base
│   │   ├── SensorTag.m               # Raw sensor data tag
│   │   ├── StateTag.m               # Discrete state (e.g. machine modes)
│   │   ├── MonitorTag.m              # Threshold‑comparison binary tag
│   │   ├── CompositeTag.m            # Boolean/weight aggregation
│   │   ├── DerivedTag.m              # Compute‑derived time series
│   │   ├── TagRegistry.m             # Singleton catalogue
│   │   ├── BatchTagPipeline.m        # One‑shot raw→tag ingestion
│   │   ├── LiveTagPipeline.m          # Timer‑driven live ingestion
│   │   └── private/                  # Parsing, merges, MEX wrappers
│   ├── EventDetection/               # Event detection, notification
│   │   ├── Event.m
│   │   ├── EventStore.m
│   │   ├── EventBinding.m            # Event↔Tag many‑to‑many
│   │   ├── LiveEventPipeline.m
│   │   ├── NotificationService.m
│   │   └── ...
│   ├── Dashboard/                    # Dashboard engine
│   │   ├── DashboardEngine.m         # Orchestrator
│   │   ├── DashboardLayout.m        # 24‑column grid with scrolling
│   │   ├── DashboardTheme.m         # Theme + dashboard overrides
│   │   ├── DashboardBuilder.m       # Edit‑mode palette & drag‑resize
│   │   ├── DashboardSerializer.m    # JSON / .m script export
│   │   ├── DashboardToolbar.m       # Global tool buttons
│   │   ├── DashboardPage.m          # Multi‑page support
│   │   └── ... many widget classes ...
│   └── WebBridge/                   # TCP server for web clients
├── examples/                         # Runnable demos
└── tests/                            # Test suites
```

## Render Pipeline

Whenever `render()` is called (explicitly or internally via `renderAll()` on a grid), the following sequence executes:

1. **Figure/Axes Creation** – If no parent axes or parent figure specified, a new figure and axes are created.
2. **Data Validation** – X monotonicity, dimension match; storage mode (memory/disk) is resolved.
3. **Storage Switch** – For data exceeding `MemoryLimit`, the `FastSenseDataStore` moves data to disk.
4. **Theme Application** – Background, grid colour, font, line colour order are set.
5. **Downsampling Buffers** – Pixel width of axes determines target bucket count.
6. **Initial Downsample** – For each line: full data range downsampled via MinMax/LTTB to ~4000 points; graphics objects created.
7. **Annotations** – Bands, shaded regions, fills, markers, step‑function thresholds drawn.
8. **[API Reference: Sensors|Legacy] Threshold Rendering** – Optional violation markers placed at crossings.
9. **Listeners** – XLim PostSet listeners installed for zoom/pan; link groups connected.
10. **Async Refinement** – For large datasets (>50M points), a timer schedules a higher‑accuracy downsample once the initial render is on‑screen.
11. **`drawnow`** – Display final result.

## Zoom / Pan Callback

Whenever the user zooms or pans (XLim change):

1. **XLim Listener** fires; new XLim compared to cached value (skip unchanged).
2. For each line:
   - **Binary Search** (`binary_search_mex`) locates the data indices of the visible range in O(log N).
   - **Pyramid Level Selection** – The pyramid level with sufficient resolution but fewest points is chosen (lazy‑built if needed).
   - **Re‑downsample** – The visible segment is downsampled to ~4000 points (MinMax/LTTB) and line `XData`/`YData` updated (dot‑assignment for speed).
3. **Violation Markers** recomputed (SIMD‑accelerated culling).
4. **Propagation** – If `LinkGroup` active, XLim pushed to other plots in the same group.
5. **Display** – `drawnow limitrate` capped at 20 FPS.

## Downsampling Strategies

Two algorithms adapt data to pixel resolution:

* **MinMax** (default) – Per pixel bucket, preserves two points (min and max Y). Fast O(N/bucket), excellent for preserving extreme values.
* **LTTB** (Largest Triangle Three Buckets) – Visually optimal; preserves signal shape by maximising triangle area between consecutive buckets. Slightly more costly but better fidelity.

Both handle NaN gaps by segmenting contiguous non‑NaN regions.

### Multi‑Resolution Pyramid

Problem: full 50 M points at full zoom‑out would require scanning all data.

Solution: Pre‑computed MinMax pyramid with configurable reduction factor (default 100× per level):

```
Level 0: Raw data         (50 000 000 points)
Level 1: 100× reduction (   500 000 points)
Level 2: 100× reduction (     5 000 points)
```

At full zoom‑out, the coarsest level (e.g., level 2) is selected; it is downsampled once to ~4000 points in under 1 ms. Levels are built lazily on first access — only the visible range’s pyramid branches are computed.

## MEX Acceleration

Optional C MEX functions with platform‑adaptive SIMD (AVX2, SSE2, NEON) provide 10‑50× speed‑ups for core operations. If MEX is unavailable, pure‑MATLAB fallbacks are used with identical behaviour.

| Function | Typ. Speedup | Description |
|----------|--------------|-------------|
| `binary_search_mex` | 10‑20× | Index lookup in sorted array |
| `minmax_core_mex` | 3‑10× | Per‑pixel MinMax reduction |
| `lttb_core_mex` | 10‑50× | LTTB triangle computation |
| `violation_cull_mex` | ≥10× | Violation detection + culling |
| `build_store_mex` | 2‑3× | Bulk SQLite writer for `FastSenseDataStore` |
| `resolve_disk_mex` | ≥10× | Threshold resolution on disk |
| `to_step_function_mex` | ≥10× | Step‑function conversion |
| `delimited_parse_mex` | plan 1028 | Delimited file parsing (forthcoming) |

See [[MEX Acceleration]] for details on platform detection and fallback.

## Data Flow Architecture

### Core Data Path
```
Raw Data (X, Y arrays)
    ↓
FastSenseDataStore (optional, for disk storage)
    ↓
Pyramid Cache (lazy multi‑resolution MinMax)
    ↓
Downsampling Engine (MinMax / LTTB to pixel width)
    ↓
Graphics Objects (line handles, markers)
    ↓
Interactive Display (zoom, pan, link groups)
```

### Storage Modes

* **Memory mode**: X/Y held in MATLAB arrays.
* **Disk mode**: Data chunked into SQLite via `FastSenseDataStore` (typed BLOBs). Chunk metadata enables O(1) overlap searching. MEX‑accelerated bulk write avoids round‑trips.
* **Auto mode**: automatically switches to disk when memory estimate > `MemoryLimit` (default 500 MB).

## Sensor Threshold Resolution

### Legacy In‑Line Thresholds

The original `Sensor.resolve()` (see [[API Reference: Sensors|Sensors]]) operates on state segments: for each segment between state changes, evaluate which `ThresholdRules` apply, group by identical condition, assign threshold values, and detect violations.

Complexity: O(S×R) where S = state segments, R = rules. Pre‑computed `StateChannel` data accelerates this.

### Tag‑Based Monitoring (v2)

The new [[API Reference: Sensors#monitortag|MonitorTag]] approach is more modular:

* `MonitorTag` wraps a parent `SensorTag` (or composite) with a user‑supplied `ConditionFn` that returns true/false on the parent’s X/Y grid. Invalidation cascades automatically when the parent is updated (`DataChanged` listener).
* `CompositeTag` aggregates multiple `MonitorTag`/`CompositeTag` children via boolean operations (`and`, `or`, `majority`, `worst`, `count`, `severity`, `user_fn`). It performs a zero‑order‑hold merge avoiding set‑union and interpolation (the ALIGN contract).
* `DerivedTag` applies a user’s compute function to N parents, producing a continuous (X,Y) series, lazily laden and user‑invalidate.

Monitoring events (OnEventStart / OnEventEnd) are emitted for runs where conditions hold (≥MinDuration). `MonitorTag` uses a hysteresis state machine that continues across `appendData` calls, so no full recompute is needed for streaming.

## Tag Ingestion Pipelines

Two pipelines convert raw delimited files (CSV/TXT) to per‑tag `.mat` files, feeding the tag model.

### BatchTagPipeline
* One‑shot process: enumerates tag registry entries with `RawSource`, parses each referenced file once, slices the appropriate column, writes `<OutputDir>/<tagKey>.mat`.

### LiveTagPipeline
* Timer‑driven (default 15 s) – resembles `MatFileDataSource` polling but over raw text files.
* Only new rows appended since last tick are processed (file‑length based, deduplication per tick).
* Can run in cluster mode (`SharedRoot` option) with lock‑coordinated inter‑process safety.

Both pipelines share the same underlying reader (`readRawDelimited_`, `selectTimeAndValue_`, `writeTagMat_`).

## Event Detection Architecture

The event‑detection subsystem provides real‑time threshold‑violation monitoring with configurable notifications and data persistence.

### Core Components (v2 tag‑based)
- **Tag Domain**: `SensorTag`, `StateTag`, `MonitorTag` (binary), `CompositeTag` (aggregation), `DerivedTag` (computed).
- **MonitorTag**: wraps a parent tag and emits `Event` objects on rising/falling edges of its condition. Uses `appendData` for incremental streaming without recomputing the full series.
- **EventStore**: persists events to a `.mat` file (single‑user) or to SQLite in cluster mode.
- **EventBinding**: many‑to‑many registry linking events to tags, queried by `EventTimelineWidget` and the main dashboard.
- **LiveEventPipeline**: timer‑driven poll loop that fetches new data from `DataSourceMap`, updates parent tags, then feeds monitors via `appendData`.

### Notification
- **NotificationService** evaluates events against user‑configured `NotificationRule`s (with sensor‑key, threshold‑label matching, and recipient lists). Supports cooldown windows, dry‑run logging, and injectable transport (`EmailTransport`, `FunctionTransport`).
- **Snapshot** generators produce FastSense PNGs of the event neighbourhood for inclusion in emails.

### Escalation
When `EscalateSeverity` is enabled, an event triggered by a warning threshold can be promoted to alarm if a higher severity threshold is also crossed.

## Dashboard Architecture

The dashboard engine provides a rich widget‑based container for building industrial monitoring screens (see [[Dashboard Engine Guide]]).

### Components
```
DashboardEngine          Orchestrator, widget list, live timer, toolbar, theme.
  ├── DashboardToolbar    Global controls: live, follow, events, config, reset, export, info.
  ├── DashboardLayout     24‑column grid, scrollable canvas, widget pan/resize in edit mode.
  ├── DashboardTheme     Merges base theme with extra dashboard tokens (widget bg, gauge arc width, etc.).
  ├── DashboardBuilder   Edit‑mode palette (drag new widgets) + property inspector.
  ├── DashboardSerializer Round‑trip JSON / .m script export.
  └── Widgets           Subclasses of DashboardWidget:
      ├── FastSenseWidget     – FastSense instance (tag‑bound, inline data)
      ├── GaugeWidget        – arc, donut, bar, thermometer
      ├── NumberWidget       – big numeric display
      ├── StatusWidget      – coloured alarm dot / value
      ├── IconCardWidget    – mushroom‑style KPI card
      ├── ChipBarWidget    – row of labelled coloured circles
      ├── TableWidget      – uitable wrapper
      ├── EventTimelineWidget – Gantt‑style event timeline
      ├── GroupWidget       – collapsible panel / tabbed group
      ├── ... (TextWidget, ImageWidget, HeatmapWidget, etc.)
```

### Render Flow
1. `DashboardEngine.render()` creates the figure, applies theme, builds toolbar, time‑slider panel, and scrollable canvas.
2. `DashboardLayout.allocatePanels()` creates a `uipanel` per widget placeholder.
3. Widget `render(parentPanel)` is called on each widget, populating the panel.
4. `updateGlobalTimeRange()` scans widgets for data time bounds to set the global time slider.

### Live Mode
`startLive()` starts a timer; each tick calls `refresh()` on widgets and `updateLiveTimeRange()`. Listeners ensure real‑time updates without full re‑render.

### Edit Mode
Activated by the “Edit” toolbar button; a `DashboardBuilder` instance overlays drag/resize handles on every widget, provides a palette sidebar for adding new ones, and a property inspector for quick configuration.

### Serialisation
`DashboardSerializer` saves the full dashboard configuration (widget positions, properties, theme, live‑file references) as JSON or as a standalone `.m` script that reconstructs the dashboard at runtime.

## Theme Inheritance

Theming follows a cascading override model:

```
Per‑tile override  →  Figure‑level theme  →  Dashboard‑level theme  →  'light' preset (default)
```

Each level need only specify the fields it changes; unspecified fields fall through to the next level. `DashboardTheme()` is a unified constructor that merges these with needed dashboard‑specific fields (gauge colour, widget backgrounds, etc.).

## Interactive Features

### Toolbars
- **FastSenseToolbar** – for individual plots or grids: buttons for cursor modes, grid, legend, autoscale Y, export, live control.
- **DashboardToolbar** – for the dashboard: sync, live toggle, follow, events toggle, config, reset, export, info.

### Hover Crosshair
`HoverCrosshair` attaches to a FastSense instance and moves a vertical line + datatip as the mouse moves over the plot. Coexists with other cursor modes by chaining figure‑level callbacks.

### Navigator Overlay
`SensorDetailPlot` uses a dual‑panel layout with an overview (navigator) and a detailed view. The navigator has a draggable zoom rectangle and track‑pad like pan/zoom interactions.

### Link Groups
Multiple `FastSense` instances sharing the same `LinkGroup` string have their XLim synchronised: when one is panned, the others follow automatically.

### Follow Mode
In live mode, chart XLim can be set to `follow` – the time window slides to keep the newest data point visible.

## Progress Indication

`ConsoleProgressBar` provides single‑line self‑updating progress bars with optional indentation, used during hierarchical operations (e.g., rendering multiple tabs/dock tabs).

---

See also:
- [[Installation]] – for compiling MEX
- [[API Reference: FastPlot]] – for usage of FastSense
- [[Dashboard Engine Guide]] – for building widget dashboards
- [[Sensors|API Reference: Sensors]] – tag‑based monitoring
- [[Event Detection|API Reference: Event Detection]] – event pipeline details
- [[MEX Acceleration]] – performance internals
- [[Performance]] – tuning tips
