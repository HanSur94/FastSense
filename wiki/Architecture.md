<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a render-once, re-downsample-on-zoom architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re-downsamples only the visible range on every interaction. A unified Tag domain model provides a clean interface for sensors, states, monitors, and derived signals, while the dashboard engine composes these into interactive visualisations.

## Project Structure

```text
FastPlot/
├── install.m                          
├── libs/
│   ├── FastSense/                     — core plotting engine
│   │   ├── FastSense.m                — main class
│   │   ├── FastSenseGrid.m            — tiled grid
│   │   ├── FastSenseDock.m            — tabbed container
│   │   ├── FastSenseToolbar.m         — interactive toolbar
│   │   ├── FastSenseTheme.m           — theme system
│   │   ├── FastSenseDataStore.m       — SQLite-backed chunked storage
│   │   ├── SensorDetailPlot.m         — sensor detail view
│   │   ├── NavigatorOverlay.m         — minimap zoom navigator
│   │   ├── ConsoleProgressBar.m       — progress indication
│   │   ├── binary_search.m            — binary search utility
│   │   ├── build_mex.m                — MEX compilation
│   │   └── private/                   — internal algorithms + MEX source
│   ├── SensorThreshold/               — Tag-based sensor & threshold system
│   │   ├── Tag.m                       — abstract base for all tags
│   │   ├── SensorTag.m                — numerical sensor data
│   │   ├── StateTag.m                 — discrete state (ZOH)
│   │   ├── MonitorTag.m               — binary threshold monitor
│   │   ├── CompositeTag.m             — N‑child logical aggregate
│   │   ├── DerivedTag.m               — continuous derived signal
│   │   ├── TagRegistry.m              — singleton catalog
│   │   ├── LiveTagPipeline.m          — live raw‑data ingestion
│   │   ├── BatchTagPipeline.m         — batch raw‑data ingestion
│   │   └── readRawDelimitedForTest_.m — test shim for parser
│   ├── EventDetection/                — event detection & viewer
│   │   ├── Event.m
│   │   ├── EventStore.m
│   │   ├── EventViewer.m
│   │   ├── LiveEventPipeline.m
│   │   ├── NotificationService.m
│   │   ├── EventBinding.m             — many-to-many Tag↔Event registry
│   │   └── ... (DataSource, MatFileDataSource, etc.)
│   ├── Dashboard/                     — widget‑based dashboard engine
│   │   ├── DashboardEngine.m
│   │   ├── DashboardLayout.m          — 24‑column responsive grid
│   │   ├── DashboardBuilder.m         — edit mode overlay
│   │   ├── DashboardSerializer.m      — JSON/.m export/import
│   │   ├── DashboardTheme.m           — theme (extends FastSenseTheme)
│   │   ├── DashboardToolbar.m
│   │   ├── DashboardWidget.m          — abstract widget base
│   │   ├── FastSenseWidget.m          — FastSense‑backed chart widget
│   │   ├── GaugeWidget.m
│   │   ├── NumberWidget.m
│   │   ├── StatusWidget.m
│   │   ├── TextWidget.m
│   │   ├── TableWidget.m
│   │   ├── EventTimelineWidget.m
│   │   ├── GroupWidget.m              — collapsible/tabbed groups
│   │   ├── ChipBarWidget.m
│   │   ├── IconCardWidget.m
│   │   ├── SparklineCardWidget.m
│   │   └── ... (other widgets)
│   └── WebBridge/                     — TCP server for web visualisation
├── examples/                          
└── tests/                             
```

## Class Hierarchy and Interactions

```text
Tag (abstract)
 ├── SensorTag    — numeric time series
 ├── StateTag     — discrete state (piecewise constant)
 ├── MonitorTag   — binary output from condition on parent Tag
 ├── CompositeTag — logical aggregate of child Tags (AND, OR, …)
 └── DerivedTag   — continuous output from compute function on parent Tags

TagRegistry (singleton) — stores all named Tags

FastSense (interactive chart)
 ├── FastSenseGrid   — tiled layout of FastSense instances
 ├── FastSenseDock   — tabbed container for multiple grids
 └── FastSenseToolbar— toolbar attached to a FastSense or grid

DashboardEngine
 ├── DashboardLayout — 24‑column grid positioning
 ├── DashboardToolbar
 ├── DashboardBuilder — drag/resize edit mode
 └── DashboardWidget (abstract)
      ├── FastSenseWidget     (wraps FastSense + Tag binding)
      ├── GaugeWidget
      ├── StatusWidget
      ├── EventTimelineWidget (binds to EventStore)
      └── ... (other widgets)

EventDetection
 ├── LiveEventPipeline (orchestrates MonitorTags + data sources)
 ├── EventStore         (atomic .mat persistence)
 ├── EventViewer        (Gantt + table UI)
 └── EventBinding       (many‑to‑many Tag–Event registry)
```

## Render Pipeline

1. User calls `render()` (or `renderAll()` on a grid).
2. Create figure/axes if not parented.
3. Validate all data (X monotonic, dimensions match).
4. Switch to disk storage mode if data exceeds `MemoryLimit`.
5. Allocate downsampling buffers based on axes pixel width.
6. For each line: initial downsample of full range, create graphics object.
7. Create threshold, band, shading, marker objects.
8. Install XLim PostSet listener for zoom/pan events.
9. Set axis limits, disable auto-limits.
10. `drawnow` to display.

## Zoom/Pan Callback

When the user zooms or pans:

1. XLim listener fires.
2. Compare new XLim to cached value (skip if unchanged).
3. For each line:
   - Binary search visible X range — O(log N).
   - Select pyramid level with sufficient resolution.
   - Build pyramid level lazily if needed.
   - Downsample visible range to ~4,000 points.
   - Update `hLine.XData`/`YData` (dot notation for speed).
4. Recompute violation markers (fused SIMD with pixel culling).
5. If `LinkGroup` active: propagate XLim to linked plots.
6. `drawnow limitrate` (caps display at 20 FPS).

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket, keep the minimum and maximum Y values. Preserves signal envelope and extreme values. Fast O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)
Visually optimal downsampling that preserves signal shape by maximising triangle area between consecutive buckets. Better visual fidelity but slightly slower.

Both algorithms handle NaN gaps by segmenting contiguous non-NaN regions independently.

## Lazy Multi-Resolution Pyramid

Problem: At full zoom-out with 50M+ points, scanning all data is O(N).

Solution: Pre-computed MinMax pyramid with configurable reduction factor (default 100× per level):

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100× reduction   (   500,000 points)
Level 2: 100× reduction   (     5,000 points)
```

On zoom, the coarsest level with sufficient resolution is selected. Full zoom-out reads level 2 (5K points) and downsamples to ~4K in under 1 ms.

Levels are built lazily on first access — the first zoom-out pays a one-time build cost (~70 ms with MEX), subsequent queries are instant.

## MEX Acceleration

Optional C MEX functions with SIMD intrinsics (AVX2 on x86_64, NEON on arm64):

| Function | Speedup | Description |
|----------|---------|-------------|
| binary_search_mex | 10–20× | O(log n) visible range lookup |
| minmax_core_mex | 3–10× | Per-pixel MinMax reduction |
| lttb_core_mex | 10–50× | Triangle area computation |
| violation_cull_mex | significant | Fused detection + pixel culling |
| compute_violations_mex | significant | Batch violation detection for resolve() |
| resolve_disk_mex | significant | SQLite disk-based sensor resolution |
| build_store_mex | 2–3× | Bulk SQLite writer for DataStore init |
| to_step_function_mex | significant | SIMD step-function conversion for thresholds |

All share a common `simd_utils.h` abstraction layer. If MEX is unavailable, pure-MATLAB implementations are used with identical behaviour.

## Data Flow Architecture

### Core Data Path

```text
Raw Data (X, Y arrays)
    ↓
FastSenseDataStore (optional, for large datasets)
    ↓
Downsampling Engine (MinMax/LTTB)
    ↓
Pyramid Cache (lazy multi-resolution)
    ↓
Graphics Objects (line handles)
    ↓
Interactive Display
```

### Storage Modes
- **Memory mode**: X/Y arrays held in MATLAB workspace.
- **Disk mode**: Data chunked into SQLite database via `FastSenseDataStore`.
- **Auto mode**: Switches to disk when data exceeds `MemoryLimit` (default 500 MB).

## Tag Domain Model

FastPlot v2.0 uses a unified **Tag** hierarchy to represent all time‑series data (sensors, states, derived alarms). Every Tag has a unique `Key`, common metadata (`Name`, `Units`, `Labels`, …), and implements the contracts:

- `getXY()` → `[X, Y]`
- `valueAt(t)` → scalar at time `t` (ZOH)
- `getTimeRange()` → `[tMin, tMax]`
- `toStruct()` / static `fromStruct(s)` for serialisation.

Concrete subclasses:

| Class | Purpose |
|-------|---------|
| `SensorTag` | Numerical sensor data (in‑memory or disk‑backed) |
| `StateTag` | Discrete state transitions (piecewise constant, numeric or cellstr) |
| `MonitorTag` | Binary 0/1 output computed from a parent Tag via a condition function; supports hysteresis, min duration, event emission |
| `CompositeTag` | Aggregates 1..N child Tags with logical operators (AND, OR, majority, count, …) to produce a single 0/1 series |
| `DerivedTag` | Continuous signal derived from multiple parent Tags via a user‑supplied compute function |

`TagRegistry` acts as the singleton catalog, supporting CRUD, label‑based queries, and a **two‑phase deserialisation** (`loadFromStructs`) that avoids dependency order issues.

This model replaces the older `Sensor`/`StateChannel`/`ThresholdRule` classes and connects directly to `DashboardWidget` and `LiveEventPipeline`.

## Sensor Threshold Resolution

(Historical note: the `Sensor.resolve()` algorithm below describes the legacy approach; in the new Tag model thresholds are expressed as `MonitorTag` instances.)

1. Collect all state‑change timestamps from all StateChannels.
2. For each segment between state changes:
   - Evaluate which `ThresholdRules` match the current state.
   - Group rules with identical conditions.
3. Assign threshold values per segment.
4. Detect violations using SIMD‑accelerated comparison.

Complexity: O(S × R) where S = state segments and R = rules, instead of O(N × R) per‑point evaluation.

## Disk-Backed Data Storage

For datasets exceeding available memory (100M+ points), `FastSenseDataStore` provides SQLite‑backed chunked storage:

1. Data is split into chunks (~10K–500K points each, auto‑tuned).
2. Each chunk is stored as a pair of typed BLOBs (X and Y) with X range metadata.
3. On zoom/pan, only chunks overlapping the visible range are loaded.
4. Pre‑computed L1 MinMax pyramid for instant zoom‑out.

The bulk write path uses `build_store_mex` — a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing ~20K mksqlite round‑trips.

If SQLite is unavailable, a binary file fallback is used automatically.

## Theme Inheritance

```text
Element override  →  Tile theme  →  Figure theme  →  'default' preset
```

Each level fills in only the fields it specifies; unspecified fields cascade from the next level.

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[[API Reference: FastPlot|FastSenseGrid]]**: Simple tiled grid of FastSense instances with synchronised live mode.
- **[[Dashboard Engine Guide|DashboardEngine]]**: Full widget‑based dashboard with gauges, numbers, status indicators, tables, timelines, and edit mode.

### DashboardEngine Components

```text
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
    ├── StatusWidget           — Coloured dot indicator
    ├── TextWidget             — Static label or header
    ├── TableWidget            — uitable display
    ├── EventTimelineWidget    — Coloured event bars on timeline
    ├── GroupWidget            — Collapsible panels, tabbed containers
    └── MultiStatusWidget      — Grid of sensor status dots
```

### Render Flow

1. `DashboardEngine.render()` creates the figure.
2. `DashboardTheme(preset)` generates the full theme struct.
3. `DashboardToolbar` creates the top toolbar panel.
4. Time control panel (dual sliders) is created at the bottom.
5. `DashboardLayout.createPanels()` computes grid positions, creates viewport/canvas/scrollbar, and allocates a uipanel per widget.
6. Each widget’s `render(parentPanel)` is called to populate its panel.
7. `updateGlobalTimeRange()` scans widgets for data bounds and configures the time sliders.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:
1. `updateLiveTimeRange()` expands time bounds from new data.
2. Each widget’s `refresh()` is called (sensor‑bound widgets re‑read data).
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

`DashboardSerializer` handles round‑trip serialisation:
- **Save:** each widget’s `toStruct()` produces a plain struct; the struct is encoded to JSON with heterogeneous widget arrays assembled manually.
- **Load:** JSON is decoded, widgets array is normalised to cell, `configToWidgets()` dispatches to each widget class’s static `fromStruct()` method.
- **Export script:** generates a `.m` file with `DashboardEngine` constructor calls and `addWidget` calls for each widget.

## Event Detection Architecture

The event detection system provides real‑time threshold violation monitoring with configurable notifications and data persistence.

### Core Components

```text
LiveEventPipeline
├── DataSourceMap          — Maps sensor keys to data sources
├── MonitorTargets         — containers.Map of MonitorTag instances
├── EventStore             — Thread‑safe .mat file persistence
├── NotificationService    — Rule‑based email alerts
└── EventViewer            — Interactive Gantt chart + filterable table
```

### Event Detection Flow

1. `LiveEventPipeline.runCycle()` polls all data sources.
2. New data is pushed to parent Tags, then to `MonitorTag.appendData()`.
3. `MonitorTag` evaluates its condition, applies hysteresis and min duration, and emits events into the bound `EventStore`.
4. `EventStore.append()` performs atomic .mat writes.
5. `NotificationService` sends rule‑based email alerts with plot snapshots.
6. Active `EventViewer` instances auto‑refresh to show new events.

### Escalation Logic

If `EscalateSeverity` is enabled, an event is promoted to the highest violated threshold level (e.g., from Warning to Alarm). The event retains the highest severity encountered.

## Progress Indication

`ConsoleProgressBar` provides hierarchical progress feedback:
- Single‑line ASCII/Unicode bars with backspace‑based updates.
- Indentation support for nested operations (dock → tabs → tiles).
- Freeze/finish modes for permanent status lines.

## Interactive Features

### Toolbars and Navigation
- **[[API Reference: FastPlot|FastSenseToolbar]]**: Data cursor, crosshair, grid toggle, autoscale, export, live mode.
- **DashboardToolbar**: Live toggle, edit mode, save/export, name editing.
- **NavigatorOverlay**: Minimap with draggable zoom rectangle for `SensorDetailPlot`.

### Link Groups
Multiple FastSense instances can share synchronised zoom/pan via `LinkGroup` strings. When one plot’s XLim changes, all plots in the same group update automatically.
