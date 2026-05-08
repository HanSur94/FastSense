<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->
# Architecture

## Overview
FastPlot uses a render‑once, re‑downsample‑on‑zoom architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight pyramid cache and re‑downsamples only the visible range on every interaction.

## Project Structure
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
│   │   ├── SensorDetailPlot.m
│   │   ├── NavigatorOverlay.m
│   │   ├── ConsoleProgressBar.m
│   │   ├── binary_search.m
│   │   ├── build_mex.m
│   │   ├── mex_stamp.m
│   │   └── private/        # Downsampling engines + MEX sources
│   ├── SensorThreshold/    # Sensor and threshold management
│   │   ├── SensorTag.m
│   │   ├── StateTag.m
│   │   ├── MonitorTag.m
│   │   ├── CompositeTag.m
│   │   ├── DerivedTag.m
│   │   ├── TagRegistry.m
│   │   └── ...
│   ├── EventDetection/     # Event detection and viewer
│   │   ├── Event.m
│   │   ├── EventStore.m
│   │   ├── EventViewer.m
│   │   ├── LiveEventPipeline.m
│   │   ├── NotificationService.m
│   │   └── ...
│   ├── Dashboard/          # Widget-based dashboard engine
│   │   ├── DashboardEngine.m
│   │   ├── DashboardLayout.m
│   │   ├── DashboardBuilder.m
│   │   ├── DashboardSerializer.m
│   │   ├── DashboardTheme.m
│   │   ├── DashboardToolbar.m
│   │   ├── FastSenseWidget.m
│   │   ├── GaugeWidget.m
│   │   ├── StatusWidget.m
│   │   ├── ... (many widgets)
│   │   └── GroupWidget.m
│   └── WebBridge/          # TCP server for web visualization
│       ├── WebBridge.m
│       └── WebBridgeProtocol.m
├── examples/
└── tests/
```

## Render Pipeline
1. User calls `render()` (or `renderAll()` for grids/dashboards).
2. Create figure/axes if not parented.
3. Validate all data (X monotonic, dimensions match).
4. Optionally switch to disk storage mode if data exceeds `MemoryLimit`.
5. Allocate downsampling buffers sized to axes pixel width.
6. For each line: initial downsample of full range → create graphics object.
7. Create threshold, band, shading, marker objects.
8. Install `XLim` PostSet listener for zoom/pan events.
9. Set axis limits, disable auto-limits.
10. `drawnow` to display; for large datasets, async refinement may be scheduled.

## Zoom/Pan Callback
When the user zooms or pans:
1. `XLim` listener fires.
2. Compare new XLim to cached value (skip if unchanged).
3. For each line:
   - Binary search visible X range — O(log N) using `binary_search`. A MEX‑accelerated path (`binary_search_mex`) provides 10–20× speedup.
   - Select the pyramid level with sufficient resolution (see [[#Lazy-Multi-Resolution-Pyramid]]).
   - Build pyramid level lazily if needed.
   - Downsample visible range to ~`DownsampleFactor × axes width` points.
   - Update `hLine.XData/YData` via dot notation for speed.
4. Recompute violation markers (fused SIMD with pixel culling if MEX available).
5. If `LinkGroup` active: propagate XLim to linked plots (see [[API Reference: FastPlot]]).
6. `drawnow limitrate` (caps display at 20 FPS).

## Downsampling Algorithms
### MinMax (default)
For each pixel bucket, keeps the minimum and maximum Y values. Preserves signal envelope and extremes. O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)
Visually optimal downsampling that preserves signal shape by maximizing triangle area between consecutive buckets. Better visual fidelity but higher compute cost.

Both algorithms handle NaN gaps by segmenting contiguous non‑NaN regions independently.

### Lazy Multi‑Resolution Pyramid
Problem: At full zoom‑out with 50M+ points, scanning all data is O(N).

Solution: Pre‑computed MinMax pyramid with configurable reduction factor `PyramidReduction` (default 100× per level):

```
Level 0: Raw data         (50,000,000 pts)
Level 1: 100× reduction   (   500,000 pts)
Level 2: 100× reduction   (     5,000 pts)
```

On zoom, the coarsest level with sufficient resolution is selected. Full zoom‑out reads level 2 (5K pts) and downsamples to ~4K in under 1 ms.

Levels are built lazily on first access — the first zoom‑out pays a one‑time build cost (~70 ms with MEX). Subsequent queries are instant.

## MEX Acceleration
Optional C MEX functions with SIMD intrinsics (AVX2 on x86_64, NEON on arm64) provide significant speedups:

| MEX Function              | Speedup   | Description                                |
|---------------------------|-----------|--------------------------------------------|
| `binary_search_mex`       | 10–20×    | O(log n) visible range lookup              |
| `minmax_core_mex`         | 3–10×     | Per‑pixel MinMax reduction                 |
| `lttb_core_mex`           | 10–50×    | Triangle area computation                  |
| `violation_cull_mex`      | significant | Fused detection + pixel culling          |
| `compute_violations_mex`  | significant | Batch violation detection for resolve()  |
| `resolve_disk_mex`        | significant | SQLite disk‑based sensor resolution      |
| `build_store_mex`         | 2–3×      | Bulk SQLite writer for DataStore init     |
| `to_step_function_mex`    | significant | SIMD step‑function conversion for thresholds |

All share a common `simd_utils.h` abstraction layer. If MEX is unavailable, pure‑MATLAB implementations are used with identical behavior. See [[MEX Acceleration]] for compilation details.

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
- **Memory mode**: X/Y arrays held in MATLAB workspace.
- **Disk mode**: Data chunked into SQLite database via `FastSenseDataStore`.
- **Auto mode**: Switches to disk when data exceeds `MemoryLimit` (default 500 MB).

## Sensor Threshold Resolution
The SensorThreshold library uses a segment‑based algorithm for resolving threshold violations. For each sensor:

1. Collect all state‑change timestamps from all `StateChannel`s.
2. For each segment between state changes:
   - Evaluate which `ThresholdRule`s match the current state.
   - Group rules with identical conditions.
3. Assign threshold values per segment.
4. Detect violations using SIMD‑accelerated comparison (MEX).

Complexity is O(S × R) where S = state segments and R = rules, instead of O(N × R) per‑point evaluation.

## Disk‑Backed Data Storage
For datasets exceeding available memory (100M+ points), `FastSenseDataStore` provides SQLite‑backed chunked storage:

1. Data split into chunks (~10K–500K points each, auto‑tuned).
2. Each chunk stored as typed BLOBs (X and Y) with X range metadata.
3. On zoom/pan, only chunks overlapping the visible range are loaded.
4. Pre‑computed L1 MinMax pyramid for instant zoom‑out.

The bulk write path uses `build_store_mex` — a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing ~20K `mksqlite` round‑trips.

If SQLite is unavailable, a binary file fallback is used automatically.

## Theme Inheritance
Themes cascade in this order:
```
Element override  >  Tile theme  >  Figure theme  >  'default' preset
```
Each level fills in only the fields it specifies; unspecified fields cascade from the next level. See [[API Reference: Themes]].

## Dashboard Architecture
The library provides two dashboard approaches:

- **`FastSenseGrid`**: Simple tiled grid of [[API Reference: FastPlot|FastSense]] instances with synchronized live mode. See [[API Reference: Dashboard]] for basic usage.

- **`DashboardEngine`**: Full widget‑based dashboard with gauges, numbers, status indicators, tables, timelines, and edit mode. Supports multi‑page layouts and JSON serialization. See [[Dashboard Engine Guide]] for a detailed walkthrough.

### DashboardEngine Components
```
DashboardEngine
├── DashboardToolbar      — Top toolbar (Live, Edit, Save, Export, Sync)
├── DashboardLayout       — 24‑column responsive grid with scrollable canvas
├── DashboardTheme        — FastSenseTheme + dashboard‑specific fields
├── DashboardBuilder      — Edit mode overlay (drag/resize, palette, properties)
├── DashboardSerializer   — JSON save/load and .m script export
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (Sensor/DataStore/inline)
    ├── GaugeWidget            — Arc/donut/bar/thermometer gauge
    ├── NumberWidget            — Big number with trend arrow
    ├── StatusWidget           — Colored dot indicator
    ├── TextWidget             — Static label or header
    ├── TableWidget            — uitable display
    ├── RawAxesWidget          — User‑supplied plot function
    ├── EventTimelineWidget    — Colored event bars on timeline
    ├── GroupWidget            — Collapsible panels, tabbed containers
    └── MultiStatusWidget      — Grid of sensor status dots
```

### Render Flow
1. `DashboardEngine.render()` creates the figure.
2. `DashboardTheme(preset)` generates the full theme struct.
3. `DashboardToolbar` creates the top toolbar panel.
4. Time control panel (dual sliders) is created at the bottom.
5. `DashboardLayout.createPanels()` computes grid positions, creates viewport/canvas/scrollbar, and creates a uipanel per widget.
6. Each widget's `render(parentPanel)` is called to populate its panel.
7. `updateGlobalTimeRange()` scans widgets for data bounds and configures the time sliders.

### Live Mode
When `startLive()` is called, a timer fires at `LiveInterval` seconds:
1. `updateLiveTimeRange()` expands time bounds from new data.
2. Each widget's `refresh()` is called.
3. The toolbar timestamp label is updated.
4. Current slider positions are re‑applied to the updated time range.

### Edit Mode
Clicking “Edit” in the toolbar creates a `DashboardBuilder` instance:
1. A palette sidebar (left) shows widget type buttons.
2. A properties panel (right) shows selected widget settings.
3. Drag/resize overlays are added on top of each widget panel.
4. The content area narrows to accommodate sidebars.
5. Mouse move/up callbacks handle drag and resize interactions.
6. Grid snap rounds positions to the nearest column/row.

### JSON Persistence
`DashboardSerializer` handles round‑trip serialization:
- **Save:** each widget’s `toStruct()` produces a plain struct. The struct is encoded to JSON with heterogeneous widget arrays assembled manually (MATLAB’s `jsonencode` cannot handle cell arrays of mixed structs).
- **Load:** JSON is decoded, widgets array is normalized to cell, and `configToWidgets()` dispatches to each widget class’s `fromStruct()` static method. An optional `SensorResolver` function handle re‑binds Sensor objects by name.
- **Export script:** generates a `.m` file with `DashboardEngine` constructor calls and `addWidget` calls for each widget.

## Event Detection Architecture
The event detection system provides real‑time threshold violation monitoring with configurable notifications and data persistence.

### Core Components
```
LiveEventPipeline
├── MonitorTargets        — containers.Map of key → MonitorTag
├── DataSourceMap         — Maps sensor keys to data sources
├── EventStore            — Thread‑safe .mat file persistence
├── NotificationService   — Rule‑based email alerts
└── EventViewer          — Interactive Gantt chart + filterable table
```

### Event Detection Flow
1. `LiveEventPipeline.runCycle()` polls all data sources.
2. New data is fed to `MonitorTag.appendData()`.
3. `MonitorTag.ConditionFn` evaluates violations.
4. Violations are grouped into events with debouncing (`MinDuration`).
5. Events are stored via `EventStore.append()` (atomic .mat writes).
6. `NotificationService` sends rule‑based email alerts with plot snapshots.
7. Active `EventViewer` instances auto‑refresh to show new events.

### Escalation Logic
When `EscalateSeverity` is enabled, events are promoted to the highest violated threshold:
- A violation starts at “Warning” level.
- If “Alarm” threshold is also crossed, the event is escalated to “Alarm”.
- The event retains the highest severity level encountered.

See [[API Reference: Event Detection]] for further details.

## Progress Indication
`ConsoleProgressBar` provides hierarchical progress feedback:
- Single‑line ASCII/Unicode bars with backspace‑based updates.
- Indentation support for nested operations (e.g., dock → tabs → tiles).
- Freeze/finish modes for permanent status lines.

## Interactive Features
### Toolbars and Navigation
- **[[API Reference: FastPlot|FastSenseToolbar]]**: Data cursor, crosshair, grid/legend toggle, autoscale, export, live mode.
- **DashboardToolbar**: Live toggle, edit mode, save/export, name editing.
- **NavigatorOverlay**: Minimap with draggable zoom rectangle for `SensorDetailPlot`.

### Link Groups
Multiple FastSense instances can share synchronized zoom/pan via `LinkGroup` strings. When one plot’s XLim changes, all plots in the same group update automatically.

### Hover Crosshair
Enabled by default (`FastSense.HoverCrosshair = true`), it creates a vertical crosshair tracking the cursor and shows interpolated values for all visible lines. See [[API Reference: FastPlot]].
