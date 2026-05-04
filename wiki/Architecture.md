<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot employs a **render‑once, re‑downsample‑on‑zoom** architecture. Instead of pushing millions of data points to the GPU, it maintains a lightweight multi‑resolution cache and re‑downsamples only the visible time range during every interaction. A MEX‑accelerated core, lazy pyramid construction and pixel‑accurate MinMax/LTTB algorithms make panning and zooming fluid even with 100M+ points.

## Project Structure

```
FastPlot/
├── install.m                         # Path setup + MEX compilation
├── libs/
│   ├── FastSense/                     # Core plotting engine
│   │   ├── FastSense.m                # Main class
│   │   ├── FastSenseGrid.m            # Tiled grid of FastSense instances
│   │   ├── FastSenseDock.m            # Tabbed container
│   │   ├── FastSenseToolbar.m         # Interactive toolbar
│   │   ├── FastSenseTheme.m           #4 presets: 'light', 'dark'
│   │   ├── FastSenseDataStore.m       # SQLite‑backed chunked storage
│   │   ├── SensorDetailPlot.m         # Two‑panel navigator
│   │   ├── NavigatorOverlay.m         # Zoom rectangle for detail view
│   │   ├── ConsoleProgressBar.m       # Hierarchical progress output
│   │   ├── binary_search.m            #acci binary search (MEX fallback)
│   │   ├── build_mex.m                # MEX compilation script
│   │   └── private/                   # Internal algorithms + MEX source
│   ├── SensorThreshold/               # Tag system (v2.0)
│   │   ├── Tag.m                      # Abstract base
│   │   ├── SensorTag.m               #acci numeric time series
│   │   ├── StateTag.m                # Discrete state with ZOH lookup
│   │   ├── MonitorTag.m              #aci threshold monitor (0/1 signal)
│   │   ├── CompositeTag.m            # Multi‑child logical aggregator
│   │   ├── DerivedTag.m              # Continuous derived (X,Y) from parents
│   │   ├── TagRegistry.m             # Singleton catalog + two‑phase loader
│   │   ├── BatchTagPipeline.m        # Raw‑file → per‑tag .mat offline
│   │   ├── LiveTagPipeline.m         # Timer‑driven raw‑file monitoring
│   │   └── private/                  # Parser + resolution helpers
│   ├── EventDetection/               # Event detection and viewer
│   │   ├── Event.m                   # Single event with escalation
│   │   ├── EventBinding.m            # Many‑to‑many event‑tag registry
│   │   ├── EventStore.m              # Thread‑safe .mat persistence
│   │   ├── EventViewer.m             # Gantt timeline + filterable table
│   │   ├── LiveEventPipeline.m       # Real‑time MonitorTag processing
│   │   ├── DataSource.m              # Abstract fetchNew() interface
│   │   ├── DataSourceMap.m           # Key → DataSource registry
│   │   ├── MatFileDataSource.m       # .mat‑based incremental reader
│   │   ├── MockDataSource.m          # Test data generator
│   │   ├── NotificationRule.m        # Email notification configuration
│   │   ├── NotificationService.m     # Rule‑based email dispatcher
│   │   ├── EventConfig.m             #ista Defaults for detection
│   │   └── private/                  # Snapshot generation helpers
│   ├── Dashboard/                     # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m         # Top‑level orchestrator
│   │   ├── DashboardBuilder.m        # Edit mode with drag/resize
│   │   ├── DashboardLayout.m         # 24‑column responsive canvas
│   │   ├── DashboardSerializer.m     # JSON + .m export/import
│   │   ├── DashboardTheme.m          # FastSenseTheme + dashboard fields
│   │   ├── DashboardToolbar.m        #tern Global controls
│   │   ├── DashboardWidget.m         # Abstract base for widgets
│   │   ├── FastSenseWidget.m         # FastSense‑based time series
│   │   ├── RawAxesWidget.m           # User‑supplied plot function
│   │   ├── GroupWidget.m             # Collapsible/tabbed containers
│   │   ├── EventTimelineWidget.m     # Colored event bars
│   │   ├── GaugeWidget.m, NumberWidget.m, StatusWidget.m, …
│   │   └── … (additional widgets)
│   └── WebBridge/                    # TCP server for web visualization
├── examples/                         # 40+ runnable scripts
└── tests/                            # 30+ test suites
```

## Render Pipeline

When `fp.render()` is invoked:

1.  Create a figure and axes (or attach to `ParentAxes`).
2.  Apply the [[API Reference: Themes|Theme]] – background, font, grid, colours.
3.  Validate all line data (X must be monotonic; Y must match length).
4.  If a `SensorTag` binding is06 present,16 resolve its data (in‑memory or from a `FastSenseDataStore`).
5.  Determine screen pixel width of the axes and allocate downsampling buffers accordingly.
6. awn For every line: perform an initial full‑range downsample, create the graphics line object using `plot` or `area`.
7.  Draw threshold lines, violation markers (if enabled), horizontal bands, shaded regions and custom markers.
8.  Install an `XLim` PostSet listener on the axes for dynamic zoom/pan handling.
9. awn Set axis limits, disable auto‑limit expansion, and force manual Y‑limiting.
10. `drawnow` to show the finished plot. If `DeferDraw` is true, postpone the final draw.

## Zoom/Pan Callback

User interactions (mouse zoom, pan, pan tool, or linked group) trigger:

1.  The `XLim` listener fires.
2. awn Compare new limits to a cached value – skip if unchanged.
3.  For each displayed line:
      - Use `binary_search` (O(log N)) to find the index range that falls inside the new X-limits.
      - Choose the coarsest pyramid level whose resolution satisfies the number of visible pixels.
      - If that level is not yet built, construct it lazily.
      - Downsample the700 visible segment to approximately 4 000 points (1‑2 points per screen pixel).
      - Update the line’s `XData` and `YData` directly (dot‑notation assignment for speed).
4.  Recompute violation markers for threshold lines; this uses fused SIMD‑accelerated detection with pixel culling (`violation_cull_mex`) when available.
5.  If a `LinkGroup` string is set, propagate the new X‑limits to all other `FastSense` instances sharing the same group.
6.  Call `drawnow limitrate` to cap the display update at ~20 fps.

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket, the algorithm retains the minimum and maximum Y‑values. This preserves the signal envelope and any extreme peaks. Complexity is O(N/bucket) per bucket.

### LTTB (Largest‑Triangle‑Three‑Buckets)
Visually optimal downsampling that keeps the signal shape by maximizing triangle area between consecutive buckets. Better fidelity, but slightly more computation time.

Both algorithms handle NaN gaps by segmenting contiguous non‑NaN regions and processing them independently.

## Lazy Multi‑Resolution Pyramid

Problem: a full scan of 50M+ points at zoom‑out would be O(N).

Solution: a pre‑computed MinMax pyramid with configurable reduction factor (default 100× per level):

```
Level 0: raw data   (50,000,000 points)
Level 1: 100×       (   500,000 points)
Level 2: 100×       (     5,000 points)
```

On zoom‑out, only the coarsest level that provides sufficient resolution is32 consulted. Full‑zoom‑out reads only 5 000 points and downsamples to ~4 000 in under 1 ms.

Pyramid levels are built lazily on first access – the very first zoom‑out pays a one‑time build cost (~70 ms with MEX), but all subsequent queries are instantaneous.

## MEX Acceleration

Optional C MEX functions with SIMD intrinsics (AVX2 on x86_64, NEON on arm64) accelerate the hot paths:

| Function | Typical speedup | Description |
|----------|-----------------|-------------|
| `binary_search_mex` | 10–20× | O(log n) visible range lookup |
| `minmax_core_mex` | 3–10× | Per‑pixel MinMax reduction |
| `lttb_core_mex` | 10–50× | Triangle area computation for LTTB |
| `violation_cull_mex` | significant | Fused violation detection + pixel culling |
| `compute_violations_mex` | significant | Batch violation detection for MonitorTag |
| `resolve_disk_mex` | significant | Disk‑based resolution for10 thresholds |
| `build_store_mex` | 2–3× | Bulk SQLite writer for DataStore initialisation |
| `to_step_function_mex` | significant | SIMD step‑function conversion for thresholds |

All MEX files share a common `simd_utils.h` layer. If MEX is unavailable, pure‑MATLAB fallbacks are used automatically – behaviour is identical.

## Data Flow Architecture

### Core Data Path

```
Raw data (X, Y arrays from SensorTag or files)
          ↓
FastSenseDataStore (optional, for large datasets)
          ↓
Downsampling engine (MinMax / LTTB)
          ↓
Pyramid cache (lazy multi‑resolution)
          ↓
Graphics objects (line handles)
          ↓
Interactive display
```

### Storage Modes

- **Memory mode**: X/Y arrays are held directly in the MATLAB workspace.
- **Disk mode**: Data is chunked into a SQLite database via `FastSenseDataStore`.awn Only the chunks overlapping the visible range are loaded from disk.
- **Auto mode** (default): `FastSense` switches to disk storage when the16 total16 data for one line exceeds the configurable `MemoryLimit` (default 500 MB).

## Threshold Monitoring

The v2.0 Tag‑based model replaces the legacy `Sensor.resolve()` approach. A `MonitorTag` is bound to a parent `Tag` (typically a06 `SensorTag`) and a user‑supplied `ConditionFn` that returns a logical per sample. The monitor produces a binary 0/1 time‑series that indicates when the parent crosses a threshold.

- **ConditionFn**: `@(x, y) → logical` – evaluated on the parent’s native grid (no interpolation). If `AlarmOffConditionFn` is provided, it implements hysteresis (only triggers when the `ConditionFn` becomes true *and* `AlarmOffConditionFn` was true previously).
- **MinDuration**: minimum violation duration in native parent‑X units. Short spikes are ignored.
- **Event emission**:when a violation becomes active, `MonitorTag` fires an `OnEventStart` callback; when it ends, `OnEventEnd` fires. The events are08 automatically stored via a bound `EventStore` and registered in `EventBinding` for later inspection.

The21 `LiveEventPipeline` connects a `DataSourceMap` to06 a set of `MonitorTag` targets. On each tick, it06 fetches new data, updates the parents, calls `monitor.appendData()`, and hands any completed events to the `NotificationService`.

## Disk‑Backed Data Storage

For datasets exceeding system memory (100M+ points), `FastSenseDataStore` provides SQLite‑backed chunked storage:

- Data is split into chunks (10 000 to 500 000 points each, auto‑tuned).
- Each chunk is stored as typed BLOBs (X and Y) together with its X‑range metadata.
- On zoom/pan, only the chunks overlapping the current view are loaded and trimmed to the exact window.
- A pre‑computed level‑1 MinMax pyramid is stored alongside, allowing instant full‑zoom rendering.

The bulk write path uses `build_store_mex` – a single C call writes all chunks with SIMD‑accelerated Y min/max computation, replacing ~20 000 mksqlite round‑trips. If SQLite is unavailable, a binary‑file fallback is used automatically.

## Theme Inheritance

```
Element override  →  Tile theme  →  Figure theme  →  'light' preset
```

`FastSenseTheme` returns a struct with14 fields for axes, text, grid, lines, etc. The theme propagates through `FastSense` → `FastSenseGrid` → `FastSenseDock` → `DashboardEngine`. Each level can provide a partial override; missing fields cascade from the next outer level.

Widget‑based dashboards augment the theme with additional fields (widget background, border, toolbar colours, status colours, etc.) via `DashboardTheme`.

## Dashboard Architecture

### [[Dashboard|FastSenseGrid]] vs [[Dashboard Engine Guide|DashboardEngine]]

- **FastSenseGrid**: a simple tiled grid of `FastSense` instances with synchronised live mode.
- **DashboardEngine**: a full widget‑based06 dashboard with gauges, numbers, status indicators, event timelines, and an interactive edit mode.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar        — Live, Edit, Save, Export, Config, Info
├── DashboardLayout         — 24‑column canvas with scrollable viewport
├── DashboardTheme          —1 FastSenseTheme + dashboard‑specific fields
├── DashboardBuilder        — Edit mode overlay (palette, properties, drag/resize)
├── DashboardSerializer     — JSON + .m export/import
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (SensorTag / DataStore)
    ├── GaugeWidget            — Arc, donut, bar, thermometer
    ├── NumberWidget            — Big KPI with trend arrow
    ├── StatusWidget           — Colured dot indicator with threshold
    ├── TextWidget              — Static label or header
    ├── TableWidget             — uitable data display
    ├── RawAxesWidget           — User‑supplied plot function on raw axes
    ├── EventTimelineWidget    — Colured event bars on a timeline
    ├── GroupWidget             — Collapsible panels, tabbed groups
    ├── MultiStatusWidget       — Grid of status dots
    ├── SparklineCardWidget     — KPI + sparkline + delta
    ├── IconCardWidget          — Icon‑based KPI card
    ├── ChipBarWidget           — Horizontal status chips
    └── ... (BarChart, Scatter, Heatmap, Histogram, Image, Divider)
```

### Render Flow

1.  `DashboardEngine.render()` create the figure.
2.  `DashboardTheme(preset)` generates the full theme struct.
3.  `DashboardToolbar` creates the top control bar.
4.  A time‑range selector (dual sliders + preview envelope) is placed at the bottom (can be hidden).
5.  `DashboardLayout.createPanels()` computes grid positions, creates a viewport with a scrollable canvas, and allocates a `uipanel` for each widget.
6.  Each widget’s `render(parentPanel)` is10 called; theacci engine may render in batches for perceived responsiveness.
7.  `updateGlobalTimeRange()` scans all widgets to determine the data time span and configures the time sliders.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:
1.  `updateLiveTimeRange()` expands the time bounds from new data.
2.  Each widget’s `refresh()` is called – `FastSenseWidget` re‑reads the bound `SensorTag` and updates the16 chart incrementally using `updateData()`.
3.  The toolbar timestamp label is updated.
4.  The time‑slider selection is preserved, and a stale‑data warning appears if any widget’s latest timestamp stops advancing.

### Edit Mode

Clicking “Edit” in the toolbar creates a `DashboardBuilder` instance:
- A palette sidebar shows widget type buttons (can be dragged onto the canvas).
- A properties panel shows settings for the selected widget.
- Drag/resize overlays with grid snapping are added on top of each widget panel.
-cil The content area narrows to accommodate the sidebars.
- The builder’s `findNextSlot()` automatically places new widgets without overlap.

### JSON Persistence

`DashboardSerializer` handles round‑trip:
- **Save**: each widget’s `toStruct()` returns a plain struct with `type, title, position, source` etc. The struct list is encoded to JSON (heterogeneous08 arrays assembled manually to avoid MATLAB JSON limitations).
- **Load**: JSON→structs, dispatched to each widget class’s `fromStruct()` static method, then `resolveRefs()` wires `SensorTag`/`EventStore`/`Threshold` handles via `TagRegistry`.
- **Export script**: generates a `.m` file that reconstructs the entire dashboard using the public API.

## Event Detection Architecture

Real‑time threshold monitoring is done by `MonitorTag` and the `LiveEventPipeline`.

### Core Components

```
LiveEventPipeline
├── MonitorTargets         — containers.Map: key → MonitorTag
├── DataSourceMap          — key → DataSource (e.g., MatFileDataSource)
├── EventStore             — atomic .mat persistence
├── NotificationService    — rule‑based email alerts
└── (optional) EventViewer — Gantt chart that auto‑refreshes
```

### Event Detection Flow

1.  `LiveEventPipeline.runCycle()` iterates over `MonitorTargets`.
2.  For each key:
      - The `DataSource` returns new `X,Y` data via `fetchNew()`.
      - The16 parent `SensorTag` is updated with `parent.updateData()`.
      - The monitor’s `appendData(newX, newY)` is called – this extends its cached 0/1 series, respects hysteresis and `MinDuration`, and fires `OnEventStart` / `OnEventEnd` for completed violations.
3.  Every16 new event is stored in the `EventStore` (atomic .mat write) and registered in `EventBinding` for the monitor’s tag key.
4.  `NotificationService` evaluates its rules and may send email alerts with PNG snapshots.
5.  Any open `EventViewer` instances automatically reload from the16 file to display the latest events.

### Escalation Logic

When `EscalateSeverity` is enabled, events are promoted to the highest violated threshold:
- A violation starts at “Warning” level.
- If a higher‑severity monitor also fires for the same time window, the event is escalated to “Alarm”.
- The event retains the highest severity encountered.

## Progress Indication

`ConsoleProgressBar` provides hierarchical progress output:
- Single‑line ASCII/Unicode bar that overwrites itself using backspace characters.
- Indentation support for nested operations (dock → tabs → tiles).
- `freeze()` and `finish()` modes for permanent status lines.
- Used by `DashboardEngine` (via `DashboardProgress`) for multi‑page rendering.

## Interactive Features

### Toolbars and Navigation

- **[[API Reference: FastPlot|FastSenseToolbar]]**: data cursor, crosshair, grid/legend toggles, Y‑autoscale, PNG export, live mode buttons, metadata display.
- **DashboardToolbar**: live toggle with blue indicator, config dialog, export, info panel, event‑marker visibility toggle.
- **NavigatorOverlay**: a mini‑map with draggable zoom rectangle inside `SensorDetailPlot` – supports rapid navigation over16 entire datasets.

### Link Groups

Multiple `FastSense` instances can be synchronised by setting the same `LinkGroup` string. When one plot’s X‑limits change, all members of the group update immediately with no visible lag.

---

*See [[MEX Acceleration]] and [[Performance]] for deeper dives into internals.*
