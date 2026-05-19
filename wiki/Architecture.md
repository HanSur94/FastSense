<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview
FastPlot uses a **render‑once, re‑downsample‑on‑zoom** architecture.  
Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re‑downsamples only the visible range on every interaction.  
This keeps memory low, interaction fluid, and enables handling of >100 M data points.

## Project Structure

```text
FastPlot/
├── install.m                        # Path setup + MEX compilation
├── libs/
│   ├── FastSense/                    # Core plotting engine
│   │   ├── FastSense.m               # Main class
│   │   ├── FastSenseGrid.m           # Tiled dashboard layout
│   │   ├── FastSenseDock.m           # Tabbed container
│   │   ├── FastSenseToolbar.m        # Interactive toolbar
│   │   ├── FastSenseTheme.m          # Theme system
│   │   ├── FastSenseDataStore.m      # SQLite‑backed chunked storage
│   │   ├── SensorDetailPlot.m        # Sensor detail view with state bands
│   │   ├── NavigatorOverlay.m        # Minimap zoom navigator
│   │   ├── ConsoleProgressBar.m      # Progress indication
│   │   ├── binary_search.m           # Binary search utility
│   │   ├── build_mex.m               # MEX compilation script
│   │   └── private/                  # Internal algorithms + MEX sources
│   ├── SensorThreshold/              # Sensor and threshold system
│   │   ├── Tag.m                     # Abstract base for unified data model
│   │   ├── SensorTag.m, StateTag.m, MonitorTag.m, CompositeTag.m, DerivedTag.m
│   │   ├── TagRegistry.m             # Central catalog of Tags
│   │   ├── BatchTagPipeline.m, LiveTagPipeline.m
│   │   └── private/                  # Resolution algorithms
│   ├── EventDetection/               # Event detection and viewer
│   │   ├── Event.m, EventStore.m, EventViewer.m
│   │   ├── LiveEventPipeline.m, IncrementalEventDetector.m
│   │   ├── NotificationService.m
│   │   └── DataSource.m, MatFileDataSource.m, MockDataSource.m
│   ├── Dashboard/                    # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m, DashboardBuilder.m
│   │   ├── DashboardLayout.m, DashboardSerializer.m, DashboardTheme.m, DashboardToolbar.m
│   │   ├── DashboardWidget.m         # Abstract widget base
│   │   ├── FastSenseWidget.m, GaugeWidget.m, NumberWidget.m, ...
│   │   └── GroupWidget.m, ChipBarWidget.m, IconCardWidget.m, SparklineCardWidget.m, ...
│   └── Concurrency/                  # Cluster‑mode helpers (Phase 1032)
└── examples/                         # 40+ runnable examples
└── tests/                            # 30+ test suites
```

## Render Pipeline

1. User calls `fp.render()`.
2. Create figure / axes if not parented.
3. Validate all data (X monotonic, dimensions match).
4. Switch to disk storage mode if data exceeds `MemoryLimit`.
5. Allocate downsampling buffers based on axes pixel width.
6. For each line: initial downsample of full range, create graphics object.
7. Create threshold, band, shading, marker objects.
8. Install `XLim` PostSet listener for zoom/pan events.
9. Set axis limits, disable auto‑limits.
10. `drawnow` to display.

## Zoom/Pan Callback

When the user zooms or pans:

1. `XLim` listener fires.
2. Compare new `XLim` to cached value (skip if unchanged).
3. For each line:
   - Binary search visible X range – O(log N).
   - Select pyramid level with sufficient resolution.
   - Build pyramid level lazily if needed.
   - Downsample visible range to ~4 000 points.
   - Update `hLine.XData` / `YData` using dot notation for speed.
4. Recompute violation markers (fused SIMD with pixel culling when MEX available).
5. If `LinkGroup` active: propagate `XLim` to linked plots.
6. `drawnow limitrate` – caps display at ~20 FPS.

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket, keep the minimum and maximum Y values. Preserves signal envelope and extreme values. Complexity O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)
Visually optimal downsampling that preserves signal shape by maximizing triangle area between consecutive buckets. Better visual fidelity but slightly slower.

Both algorithms handle NaN gaps by segmenting contiguous non‑NaN regions independently.

## Lazy Multi‑Resolution Pyramid

**Problem:** At full zoom‑out with >50 M points, scanning all data is O(N).

**Solution:** Pre‑computed MinMax pyramid with configurable reduction factor (default 100× per level):

```
Level 0: Raw data         (50 000 000 points)
Level 1: 100× reduction   (   500 000 points)
Level 2: 100× reduction   (     5 000 points)
```

On zoom, the coarsest level with sufficient resolution is selected. Full zoom‑out reads level 2 (5 K points) and downsamples to ~4 K in under 1 ms.  
Levels are built lazily on first access — the first zoom‑out pays a one‑time build cost (~70 ms with MEX), subsequent queries are instant.

## MEX Acceleration

Optional C MEX functions with SIMD intrinsics (AVX2 on x86‑64, NEON on ARM64) provide substantial speedups. If MEX is unavailable, pure‑MATLAB implementations are used with identical behaviour.

| Function | Typical Speedup | Description |
|----------|----------------|-------------|
| `binary_search_mex` | 10–20× | O(log N) visible range lookup |
| `minmax_core_mex` | 3–10× | Per‑pixel MinMax reduction |
| `lttb_core_mex` | 10–50× | Triangle area computation for LTTB |
| `violation_cull_mex` | significant | Fused violation detection + pixel culling |
| `compute_violations_mex` | significant | Batch violation detection for `resolve()` |
| `resolve_disk_mex` | significant | SQLite disk‑based sensor resolution |
| `build_store_mex` | 2–3× | Bulk SQLite writer for `DataStore` initialisation |
| `to_step_function_mex` | significant | SIMD step‑function conversion for thresholds |

All share a common `simd_utils.h` abstraction layer.

## Data Flow Architecture

### Core Data Path

```text
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
- **Auto mode**: Switches to disk when data exceeds `MemoryLimit` (default 500 MB).

## Sensor Threshold Resolution

The `Sensor.resolve()` algorithm is segment‑based (used by the legacy `Sensor` class; in the v2.0 Tag model, `MonitorTag` replaces this with direct condition evaluation):

1. Collect all state‑change timestamps from all `StateChannel` / `StateTag` objects.
2. For each segment between state changes:
   - Evaluate which `ThresholdRule` / condition matches the current state.
   - Group rules with identical conditions.
3. Assign threshold values per segment.
4. Detect violations using SIMD‑accelerated comparison when MEX is available.

Complexity: O(S × R) where S = state segments and R = rules, instead of per‑point O(N × R).

## Disk‑Backed Data Storage

For datasets exceeding available memory (>100 M points), `FastSenseDataStore` provides SQLite‑backed chunked storage:

1. Data is split into chunks (~10 K – 500 K points each, auto‑tuned).
2. Each chunk stored as typed BLOBs (X and Y) with X‑range metadata.
3. On zoom/pan, only chunks overlapping the visible range are loaded.
4. Pre‑computed L1 MinMax pyramid for instant zoom‑out.

The bulk write path uses `build_store_mex` — a single C call that writes all chunks with SIMD‑accelerated Y min/max computation.  
If SQLite is unavailable, a binary file fallback is used automatically.

## Theme Inheritance

```
Element override  >  Tile theme  >  Figure theme  >  'default' preset
```

Each level fills in only the fields it specifies; unspecified fields cascade from the next level.

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **`FastSenseGrid`**: Simple tiled grid of FastSense instances with synchronised live mode.
- **`DashboardEngine`**: Full widget‑based dashboard with gauges, numbers, status indicators, tables, timelines, and interactive edit mode (see [[Dashboard Engine Guide]]).

### DashboardEngine Components

```text
DashboardEngine
├── DashboardToolbar      — Top toolbar (Live, Edit, Save, Export, Sync)
├── DashboardLayout       — 24‑column responsive grid with scrollable canvas
├── DashboardTheme        — FastSenseTheme + dashboard‑specific fields
├── DashboardBuilder      — Edit mode overlay (drag/resize, palette, properties)
├── DashboardSerializer   — JSON save/load and .m script export
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (Sensor / DataStore / inline)
    ├── GaugeWidget            — Arc / donut / bar / thermometer gauge
    ├── NumberWidget            — Big number with trend arrow
    ├── StatusWidget           — Coloured dot indicator
    ├── TextWidget             — Static label or header
    ├── TableWidget            — uitable display
    ├── RawAxesWidget          — User‑supplied plot function
    ├── EventTimelineWidget    — Coloured event bars on timeline
    ├── GroupWidget            — Collapsible panels, tabbed containers
    ├── ChipBarWidget          — Horizontal row of status chips
    ├── IconCardWidget         — Mushroom‑style icon + value card
    ├── SparklineCardWidget    — Big number + sparkline + delta indicator
    └── MultiStatusWidget      — Grid of sensor status dots
```

### Render Flow

1. `DashboardEngine.render()` creates the figure.
2. `DashboardTheme(preset)` generates the full theme struct.
3. `DashboardToolbar` creates the top toolbar panel.
4. Time control panel (dual sliders) is created at the bottom.
5. `DashboardLayout.createPanels()` computes grid positions, creates viewport/canvas/scrollbar, and creates a uipanel per widget.
6. Each widget’s `render(parentPanel)` populates its panel.
7. `updateGlobalTimeRange()` scans widgets for data bounds and configures the time sliders.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:
1. `updateLiveTimeRange()` expands time bounds from new data.
2. Each widget’s `refresh()` is called.
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
- **Save:** each widget’s `toStruct()` produces a plain struct; JSON is assembled manually because MATLAB’s `jsonencode` cannot handle heterogeneous cell arrays.
- **Load:** JSON is decoded, widgets normalised to cell, and `configToWidgets()` dispatches to each widget class’s `fromStruct()` static method. An optional `SensorResolver` function handle re‑binds Tag objects by key.
- **Export script:** generates a `.m` file with `DashboardEngine` constructor calls and `addWidget` calls.

## Event Detection Architecture

The event detection system provides real‑time threshold violation monitoring with configurable notifications and data persistence.

### Core Components

```text
LiveEventPipeline
├── DataSourceMap          — Maps sensor keys to data sources
├── IncrementalEventDetector — Tracks per‑sensor state and open events
├── EventStore            — Thread‑safe .mat file persistence (single‑user) or SQLite (cluster mode)
├── NotificationService   — Rule‑based email alerts
└── EventViewer          — Interactive Gantt chart + filterable table
```

### Data Sources

- **`MatFileDataSource`**: Polls .mat files for new data.
- **`MockDataSource`**: Generates realistic test signals with violations.
- Custom sources implement the `DataSource.fetchNew()` interface.

### Event Detection Flow (single‑user)

1. `LiveEventPipeline.runCycle()` polls all data sources.
2. New data is passed to `IncrementalEventDetector.process()`.
3. Sensor state is evaluated.
4. Violations are grouped into events with debouncing (`MinDuration`).
5. Events are stored via `EventStore.append()` (atomic temp‑and‑rename writes).
6. `NotificationService` sends rule‑based email alerts with plot snapshots.
7. Active `EventViewer` instances auto‑refresh to show new events.

### Escalation Logic

When `EscalateSeverity` is enabled, events are promoted to the highest violated threshold:
- A violation starts at “Warning” level.
- If “Alarm” threshold is also crossed, the event is escalated to “Alarm”.
- The event retains the highest severity level encountered.

## Progress Indication

`ConsoleProgressBar` provides hierarchical progress feedback:
- Single‑line ASCII/Unicode bars with backspace‑based updates.
- Indentation support for nested operations (e.g., dock → tabs → tiles).
- `freeze()` / `finish()` modes for permanent status lines.

## Interactive Features

### Toolbars and Navigation
- **`FastSenseToolbar`**: Data cursor, crosshair, grid toggle, autoscale, export, live mode (see [[API Reference: FastPlot|FastSenseToolbar]]).
- **`DashboardToolbar`**: Live toggle, edit mode, save/export, name editing.
- **`NavigatorOverlay`**: Minimap with draggable zoom rectangle for `SensorDetailPlot`.

### Link Groups
Multiple `FastSense` instances can share synchronised zoom/pan via `LinkGroup` strings. When one plot’s `XLim` changes, all plots in the same group update automatically.

## Cross‑References

- For a complete API reference, see [[API Reference: FastPlot]] and [[API Reference: Dashboard]].
- Learn about the unified Tag data model in [[API Reference: Sensors]].
- Details on MEX acceleration and performance: [[MEX Acceleration]], [[Performance]].
- See complete examples in [[Examples]].
