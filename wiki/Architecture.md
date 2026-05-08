<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot is built on a **render-once, re-downsample-on-zoom** architecture. Rather than pushing millions of data points to the GPU on every interaction, the library maintains lightweight downsampling caches and recomputes only the visible range at screen resolution. A multi‑level pyramid cache eliminates the need to scan raw data during zoom/pan, while optional MEX acceleration with SIMD intrinsics makes the C‑backed code paths competitive with native toolkits.

The core plotting engine (`FastSense`) is wrapped by higher‑level layouts (`FastSenseGrid`, `DashboardEngine`) and integrates with a Tag‑based domain model for sensors, thresholds, and derived signals.

---

## Project Structure

```
FastPlot/
├── install.m                        # Path install + MEX compilation
├── libs/
│   ├── FastSense/                    # Core plotting engine
│   │   ├── FastSense.m               # Main class
│   │   ├── FastSenseGrid.m           # Dashboard layout
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
│   ├── SensorThreshold/              # Tag‑based domain model
│   │   ├── Tag.m                     # Abstract base class
│   │   ├── SensorTag.m               # Sensor time‑series data
│   │   ├── StateTag.m                # Discrete state signals
│   │   ├── MonitorTag.m              # Binary monitor (threshold)
│   │   ├── CompositeTag.m            # Aggregate monitor
│   │   ├── DerivedTag.m              # Continuous derived signal
│   │   ├── TagRegistry.m             # Singleton catalog
│   │   ├── BatchTagPipeline.m        # Raw‑data → per‑tag .mat pipeline
│   │   ├── LiveTagPipeline.m         # Timer‑driven raw‑data pipeline
│   │   └── private/                  # File parsing and writing utilities
│   ├── EventDetection/               # Event detection and viewer
│   │   ├── Event.m
│   │   ├── EventStore.m
│   │   ├── EventViewer.m
│   │   ├── LiveEventPipeline.m
│   │   ├── NotificationService.m
│   │   ├── NotificationRule.m
│   │   ├── DataSource.m              # Abstract data source
│   │   ├── MatFileDataSource.m       # File‑based data source
│   │   ├── MockDataSource.m          # Test data generation
│   │   └── private/
│   ├── Dashboard/                    # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m
│   │   ├── DashboardBuilder.m
│   │   ├── DashboardLayout.m
│   │   ├── DashboardSerializer.m
│   │   ├── DashboardTheme.m
│   │   ├── DashboardToolbar.m
│   │   ├── DashboardWidget.m         # Abstract widget base
│   │   ├── FastSenseWidget.m
│   │   ├── GaugeWidget.m
│   │   ├── NumberWidget.m
│   │   ├── StatusWidget.m
│   │   ├── TextWidget.m
│   │   ├── TableWidget.m
│   │   ├── RawAxesWidget.m
│   │   ├── EventTimelineWidget.m
│   │   ├── GroupWidget.m             # Collapsible/tabbed widget groups
│   │   ├── MultiStatusWidget.m       # Grid of status indicators
│   │   ├── BarChartWidget.m
│   │   ├── ScatterWidget.m
│   │   ├── HeatmapWidget.m
│   │   ├── HistogramWidget.m
│   │   ├── ImageWidget.m
│   │   ├── IconCardWidget.m          # Compact icon + value card
│   │   ├── SparklineCardWidget.m     # KPI card with sparkline
│   │   ├── ChipBarWidget.m           # Horizontal status chip bar
│   │   ├── DividerWidget.m           # Horizontal divider line
│   │   ├── DashboardPage.m           # Multi‑page container
│   │   ├── DashboardConfigDialog.m   # Config editor
│   │   ├── TimeRangeSelector.m       # Time‑range scrubber
│   │   ├── DashboardProgress.m       # Progress helper
│   │   └── MarkdownRenderer.m        # Markdown→HTML for info panels
│   └── WebBridge/                    # TCP server for web visualization
│       ├── WebBridge.m
│       └── WebBridgeProtocol.m
├── examples/                         # 40+ runnable examples
└── tests/                            # 30+ test suites
```

---

## Render Pipeline

1. User calls `render()` on a `FastSense` instance.
2. If no parent axes have been supplied, a new figure and axes are created.
3. All line data are validated: X must be monotonic and the same length as Y.
4. When total data volume exceeds `MemoryLimit` (default 500 MB) and `StorageMode` is `'auto'`, the line is transparently moved to a disk‑backed `FastSenseDataStore`.
5. Downsampling buffers are allocated based on the current axes pixel width.
6. For each line an initial downsample of the full X‑range is computed and a graphics `line` object is created.
7. Band, shaded region, threshold, violation marker, and custom marker objects are created (the order ensures correct Z‑stacking).
8. A `PostSet` listener on `XLim` is installed — this drives all zoom/pan re‑downsampling.
9. Axis limits are set with 5 % padding and auto‑limits are disabled (the plot then manages its own range).
10. A deferred refinement pass is scheduled for large datasets to fill in missing pyramid levels.
11. `drawnow` makes the plot visible.

---

## Zoom / Pan Callback

Every interactive change to the X‑axis fires the same callback chain:

1. **XLim listener fires** — the new limits are compared to a cached value; identical limits are skipped.
2. **Binary search** locates the first and last visible point indices in O(log N) using `binary_search` (or `binary_search_mex` if MEX is available).
3. **Pyramid level selection** — the coarsest pre‑computed level that still has more samples than the target pixel count is chosen. If the required level does not yet exist, it is built lazily (see [Lazy Multi‑Resolution Pyramid](#lazy-multi-resolution-pyramid)).
4. **Downsample visible range** — about 2–4 points per pixel (configurable via `DownsampleFactor`) are extracted from the selected pyramid level using MinMax or LTTB.
5. **Update graphics** — the `XData` and `YData` of the line handle are replaced using dot‑notation for speed (avoiding `set` overhead).
6. **Violation markers** are recomputed for the visible range with SIMD‑accelerated culling when MEX is present.
7. **LinkGroup** — if the plot belongs to a `LinkGroup`, the new XLim is propagated to all other plots in the same group.
8. **drawnow limitrate** caps the frame rate at approximately 20 FPS.

---

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket the minimum and maximum Y values are kept. This preserves the signal envelope and guarantees that extreme values are never missed. The algorithm runs in O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)
Visually optimised downsampling that maximises triangle area between consecutive buckets, preserving the perceived shape of the signal. Slightly slower than MinMax but yields better visual fidelity for smooth curves.

Both algorithms handle NaN gaps by splitting into contiguous non‑NaN segments and processing each independently.

---

## Lazy Multi‑Resolution Pyramid

The challenge: when fully zoomed out with 50 M+ points, scanning all raw data to subsample to screen pixels is O(N) and too slow for interactive use.

**Solution:** a pre‑computed MinMax pyramid with a configurable reduction factor (default 100× per level):

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100× reduction   (   500,000 points)
Level 2: 100× reduction   (     5,000 points)
```

On zoom, the coarsest level with sufficient resolution is selected. At full zoom‑out the renderer reads level 2 (5 K points) and downsamples to ~4 K in under 1 ms.

Levels are built lazily on first access — the first zoom‑out pays a one‑time build cost (~70 ms with MEX), subsequent queries are instant.

---

## MEX Acceleration

Optional C MEX functions with SIMD intrinsics (AVX2 on x86_64, NEON on arm64) accelerate the most compute‑intensive operations. Every MEX function has an identical pure‑MATLAB fallback that is used automatically when compilation is unavailable.

| Function | Speedup | Description |
|---|---|---|
| `binary_search_mex` | 10–20× | O(log N) visible‑range lookup |
| `minmax_core_mex` | 3–10× | Per‑pixel MinMax reduction |
| `lttb_core_mex` | 10–50× | Triangle‑area computation for LTTB |
| `violation_cull_mex` | significant | Fused detection + pixel culling for violation markers |
| `compute_violations_mex` | significant | Batch violation detection for threshold resolution |
| `resolve_disk_mex` | significant | SQLite‑disk‑based sensor resolution |
| `build_store_mex` | 2–3× | Bulk SQLite writer for DataStore initialisation |
| `to_step_function_mex` | significant | SIMD step‑function conversion for thresholds |

All MEX sources share a common `simd_utils.h` abstraction layer and the bundled SQLite3 amalgamation. The build system (`build_mex.m`) detects the platform and selects appropriate compiler flags; if AVX2 fails, it automatically retries with SSE2.

The availability check is cached per session:
```matlab
persistent useMex;
if isempty(useMex)
    useMex = (exist('binary_search_mex', 'file') == 3);
end
```

For full details, see [[MEX Acceleration]].

---

## Data Flow Architecture

### Core Data Path

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
- **Memory mode** — X/Y arrays held in MATLAB workspace.
- **Disk mode** — data chunked into a SQLite database via `FastSenseDataStore`.
- **Auto mode** — switches to disk when total data exceeds `MemoryLimit` (default 500 MB).

---

## Tag‑Based Domain Model

FastPlot v2.0 replaces the previous `Sensor`/`StateChannel`/`ThresholdRule` model with a unified **Tag** hierarchy ([API Reference: Sensors](API-Reference-Sensors)). Every signal is a `Tag`, providing a consistent interface (`getXY`, `valueAt`, `getTimeRange`, `toStruct`).

```
Tag (abstract)
├── SensorTag        — raw sensor time series (X, Y)
├── StateTag         — discrete state signals (ZOH lookup)
├── MonitorTag       — binary monitor: applies ConditionFn to parent → 0/1 output
├── CompositeTag     — aggregate multiple Monitor/Composite children with logical modes
└── DerivedTag       — continuous derived signal from N parents via a compute function
```

**Threshold / event detection** is now a first‑class citizen of this model:

1. A `MonitorTag` is created with a parent `SensorTag` (or `StateTag`, `DerivedTag`) and a condition function.
2. Calling `monitor.getXY()` lazily evaluates the condition on the parent’s grid, returning a binary series (with optional hysteresis and debounce via `MinDuration`).
3. The `EventStore` and `LiveEventPipeline` consume `MonitorTag` objects directly — the pipeline polls data sources, pushes new data to `MonitorTag.appendData`, and emits `Event` objects with correct `TagKeys`.

### Event Detection Flow

```
[Data Sources] → LiveEventPipeline.runCycle()
    ├─ fetch new data from DataSourceMap
    ├─ append to parent Tag (e.g., SensorTag.updateData)
    ├─ append to MonitorTag via monitor.appendData (streaming tail extension)
    ├─ events created/closed via EventStore
    └─ NotificationService sends alerts (with plot snapshots)
```

The pipeline can escalate event severity when multiple thresholds are crossed and supports configurable callbacks.

---

## Disk‑Backed Data Storage

For datasets that exceed available memory, `FastSenseDataStore` provides SQLite‑backed chunked storage:

1. Data is split into chunks (~10 K–500 K points each, auto‑tuned).
2. Each chunk is stored as a pair of typed BLOBs (X and Y) together with X‑range metadata.
3. On zoom/pan only chunks overlapping the visible range are loaded.
4. A pre‑computed L1 MinMax pyramid (level 1) is built at storage time for instant zoom‑out.

Bulk insert uses `build_store_mex` — a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing tens of thousands of individual `mksqlite` round‑trips.

If SQLite is unavailable (e.g., MEX compilation failure), a binary‑file fallback is used automatically.

---

## Theme Inheritance

```
Element override  →  Tile theme  →  Figure theme  →  Preset ('light' or 'dark')
```

Each level fills in only the fields it specifies; unspecified fields cascade from the next level. The `FastSenseTheme` and `DashboardTheme` functions return complete structs by merging preset defaults with user overrides. The palette of line colours (8×3 matrix) is resolved at theme load time.

---

## Dashboard Architecture

FastPlot provides two levels of dashboard composition:

- **`FastSenseGrid`** — lightweight tiled grid of FastSense instances with synchronised live mode.
- **`DashboardEngine`** — full widget‑based dashboard with gauges, numbers, status indicators, tables, timelines, and an edit mode. Layout is managed on a 24‑column responsive grid.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar      — Top toolbar (Live, Edit, Save, Export, Info)
├── DashboardLayout       — 24‑column responsive grid with scrollable canvas
├── DashboardTheme        — FastSenseTheme + dashboard‑specific fields
├── DashboardBuilder      — Edit mode overlay (drag/resize, palette, properties)
├── DashboardSerializer   — JSON save/load and .m script export
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (Tag / DataStore / inline)
    ├── GaugeWidget            — Arc/donut/bar/thermometer gauge
    ├── NumberWidget            — Big number with trend arrow
    ├── StatusWidget           — Colored dot indicator
    ├── TextWidget             — Static label or header
    ├── TableWidget            — uitable display
    ├── RawAxesWidget          — User‑supplied plot function
    ├── EventTimelineWidget    — Colored event bars on timeline
    ├── GroupWidget            — Collapsible panels, tabbed containers
    ├── MultiStatusWidget      — Grid of sensor status dots
    ├── IconCardWidget         — Compact card with icon, value, label
    ├── SparklineCardWidget    — KPI card with sparkline chart
    ├── ChipBarWidget          — Horizontal row of status chips
    └── DividerWidget          — Visual section separator
```

### Dashboard Pages
The engine supports **multi‑page dashboards** via `DashboardPage` objects. Each page holds its own set of widgets, and navigation is handled by a tab bar. This keeps the user interface dense yet organised.

For detailed usage, see [[Dashboard Engine Guide]].

---

## Progress Indication

`ConsoleProgressBar` renders a single‑line progress bar in the MATLAB console, supporting indentation for nested operations (e.g., dock → tabs → tiles). The bar uses Unicode block characters on MATLAB and ASCII on Octave. The lifecycle is:

```
pb = ConsoleProgressBar(indent);
pb.start();
pb.update(current, total, label);   % loop
pb.freeze();   % make permanent, or
pb.finish();   % 100% + freeze
```

`DashboardProgress` is a higher‑level wrapper that logs per‑widget realisation progress during `DashboardEngine.render()` while respecting the `ProgressMode` setting.

---

## Interactive Features

- **Toolbars** – `FastSenseToolbar` provides data cursor, crosshair, grid/legend toggles, autoscale, export, and live controls. `DashboardToolbar` adds live toggle, edit mode, save/export, and name editing.
- **NavigatorOverlay** – minimap with draggable zoom rectangle for `SensorDetailPlot`.
- **Link Groups** – multiple `FastSense` instances can synchronise zoom/pan via a shared `LinkGroup` string.
- **Live Mode** – polls a `.mat` file (or raw text file via pipelines) at a configurable interval and auto‑refreshes the plot; `LiveViewMode` controls whether the X‑axis follows the data or stays fixed.
- **Event Markers** – event overlays (round markers) can be toggled on any `FastSense` plot; clicking a marker opens a floating details window with editable notes.

---

## Cross‑References

- [[Home]] | [[Installation]] | [[Getting Started]]
- [[API Reference: FastPlot]] | [[API Reference: Dashboard]] | [[API Reference: Themes]] | [[API Reference: Sensors]] | [[API Reference: Event Detection]] | [[API Reference: Utilities]]
- [[Live Mode Guide]] | [[Datetime Guide]] | [[Dashboard Engine Guide]]
- [[MEX Acceleration]] | [[Performance]]
- [[Examples]]
