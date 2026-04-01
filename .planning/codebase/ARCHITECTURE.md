# Architecture

**Analysis Date:** 2026-04-01

## Pattern Overview

**Overall:** Layered MATLAB library with MEX acceleration and an optional Python/Web bridge

**Key Characteristics:**
- Five independent libraries (`libs/`) each with a clear single responsibility
- Core rendering engine (`FastSense`) wraps MATLAB axes and drives all plotting via a render/update lifecycle
- Performance-critical code is implemented as compiled MEX C extensions with pure-MATLAB fallbacks
- Dashboard layer composes reusable `DashboardWidget` subclasses over the core rendering engine
- Browser-based visualization is bridged via TCP (MATLAB) → Python FastAPI server → WebSocket → browser

## Layers

**Core Rendering Engine:**
- Purpose: Ultra-fast time series plotting with dynamic downsampling
- Location: `libs/FastSense/`
- Contains: `FastSense.m` (main class), `FastSenseGrid.m`, `FastSenseDock.m`, `FastSenseToolbar.m`, `SensorDetailPlot.m`, `NavigatorOverlay.m`
- Depends on: `FastSenseDataStore` (disk backend), `FastSenseTheme` (styling), MEX kernels
- Used by: Dashboard widgets (`FastSenseWidget`), direct user scripts, `SensorDetailPlot`

**Disk-Backed Storage:**
- Purpose: SQLite-based chunked storage for datasets that exceed MATLAB memory
- Location: `libs/FastSense/FastSenseDataStore.m`
- Contains: Chunk-based read/write logic, WAL mode for live use, pyramid-level downsampling cache
- Depends on: `mksqlite` (bundled SQLite3 MEX), binary file fallback when mksqlite is absent
- Used by: `FastSense` when data is stored to disk, `WebBridge` WAL writes

**MEX Acceleration Layer:**
- Purpose: SIMD-optimized kernels for downsampling, violation detection, binary search, disk resolution
- Location: `libs/FastSense/private/mex_src/` (C sources), compiled to `*.mex`/`*.mexmaca64` binaries
- Contains: `lttb_core_mex.c`, `minmax_core_mex.c`, `compute_violations_mex.c`, `violation_cull_mex.c`, `binary_search_mex.c`, `build_store_mex.c`, `resolve_disk_mex.c`, `to_step_function_mex.c`, `simd_utils.h`, bundled SQLite3 (`sqlite3.c`/`sqlite3.h`)
- Depends on: Platform compiler; AVX2 (x86_64) or NEON (ARM64) with scalar fallback
- Used by: `FastSense`, `FastSenseDataStore`, `SensorThreshold` private helpers

**Sensor/Threshold Modeling:**
- Purpose: Domain model for sensors with state-dependent, condition-driven threshold rules
- Location: `libs/SensorThreshold/`
- Contains: `Sensor.m`, `SensorRegistry.m`, `ThresholdRule.m`, `StateChannel.m`, `loadModuleData.m`, `loadModuleMetadata.m`, `ExternalSensorRegistry.m`
- Depends on: MEX helpers (`to_step_function_mex`, `compute_violations_mex`, `resolve_disk_mex`, `violation_cull_mex`) via private helpers
- Used by: `FastSense.addSensor()`, `FastSenseWidget`, `SensorDetailPlot`, `EventDetection`, `DashboardEngine`

**Event Detection:**
- Purpose: Detect, persist, and stream threshold-violation events in batch and live modes
- Location: `libs/EventDetection/`
- Contains: `EventDetector.m`, `IncrementalEventDetector.m`, `LiveEventPipeline.m`, `EventStore.m`, `Event.m`, `EventConfig.m`, `EventViewer.m`, `NotificationRule.m`, `NotificationService.m`, `DataSource.m`, `DataSourceMap.m`, `MatFileDataSource.m`, `MockDataSource.m`, `detectEventsFromSensor.m`, `generateEventSnapshot.m`
- Depends on: `SensorThreshold` (`Sensor`, `ThresholdRule`), private helpers (`groupViolations.m`, `parseOpts.m`)
- Used by: Standalone scripts, `LiveEventPipeline` timer, `EventViewer`

**Dashboard Engine:**
- Purpose: Widget-based dashboard composition, layout, theming, serialization, and live refresh
- Location: `libs/Dashboard/`
- Contains: `DashboardEngine.m` (orchestrator), `DashboardWidget.m` (abstract base), `DashboardLayout.m` (24-column grid), `DashboardSerializer.m` (JSON/`.m` export), `DashboardTheme.m`, `DashboardToolbar.m`, `DashboardBuilder.m`, and concrete widgets (`FastSenseWidget.m`, `NumberWidget.m`, `StatusWidget.m`, `GaugeWidget.m`, `TextWidget.m`, `TableWidget.m`, `BarChartWidget.m`, `HeatmapWidget.m`, `HistogramWidget.m`, `ScatterWidget.m`, `ImageWidget.m`, `MultiStatusWidget.m`, `EventTimelineWidget.m`, `GroupWidget.m`, `RawAxesWidget.m`, `MarkdownRenderer.m`)
- Depends on: `FastSense` (via `FastSenseWidget`), `SensorThreshold` (via `Sensor` binding), `EventDetection` (via `EventTimelineWidget`)
- Used by: End-user dashboard scripts, `WebBridge`

**Web Bridge:**
- Purpose: Expose dashboard data and actions to a browser via TCP+Python HTTP server
- Location: `libs/WebBridge/` (MATLAB side), `bridge/python/` (server side), `bridge/web/` (browser client)
- Contains (MATLAB): `WebBridge.m`, `WebBridgeProtocol.m` (NDJSON message codec)
- Contains (Python): `server.py` (FastAPI + WebSocket), `tcp_client.py`, `sqlite_reader.py`, `blob_decoder.py`
- Contains (Web): `app.js`, `chart.js`, `dashboard.js`, `widgets.js`, `actions.js`, `style.css`
- Depends on: `FastSenseDataStore` (SQLite files), `DashboardEngine` (config), Python FastAPI/uvicorn
- Used by: Optional browser visualization workflow

## Data Flow

**Static Plot Workflow:**

1. User creates `FastSense()` or calls `FastSenseGrid`/`FastSenseDock`
2. User calls `addLine(x, y)`, `addThreshold()`, `addBand()`, etc.
3. User calls `render()`: downsample via MinMax/LTTB MEX, draw MATLAB graphics
4. Zoom/pan events trigger re-downsample (O(1) pyramid lookup) and re-render

**Sensor-Driven Workflow:**

1. Create `Sensor` with `X`, `Y`, `StateChannel`s, and `ThresholdRule`s
2. Call `sensor.resolve()`: MEX kernels compute threshold step functions and violation indices
3. Pass sensor to `FastSense.addSensor()` or bind to `FastSenseWidget`
4. `FastSense`/widget reads `ResolvedThresholds` and `ResolvedViolations` for rendering

**Live Event Detection Workflow:**

1. Build `DataSourceMap` of `DataSource` implementations (`MatFileDataSource`, custom)
2. Create `LiveEventPipeline(sensors, dataSourceMap)` with `Interval`
3. `pipeline.start()` starts a MATLAB timer; each tick calls `DataSource.fetchNew()`
4. `IncrementalEventDetector` processes new data, appends to `EventStore`
5. `NotificationService` fires callbacks/rules for new events

**WebBridge Workflow:**

1. `WebBridge(dashboard).serve()` starts TCP server and launches Python bridge subprocess
2. MATLAB sends NDJSON messages (`WebBridgeProtocol`) over TCP: `init`, `data_changed`, `config_changed`
3. Python `tcp_client.py` receives messages, updates `AppState`, broadcasts to WebSocket clients
4. Browser fetches data via REST (`/api/signals/{id}/data`) which reads SQLite via `SqliteReader`
5. Browser actions are sent via WebSocket, forwarded to MATLAB via TCP, and resolved as `action_result`

**State Management:**
- Each `FastSense` instance holds its own line/threshold/band state before and after render
- `DashboardEngine` owns `Widgets` list and drives refresh via a MATLAB timer
- `SensorRegistry` is a persistent singleton (`containers.Map` cached in static method)
- `FastSenseDataStore` manages SQLite connection lifecycle and pyramid cache

## Key Abstractions

**FastSense:**
- Purpose: Single-tile high-performance time series plot with downsampling
- Examples: `libs/FastSense/FastSense.m`
- Pattern: Handle class; pre-render configuration via `add*()` methods; post-render update via `updateData()`

**DashboardWidget (abstract):**
- Purpose: Uniform interface for all dashboard widgets (render, refresh, toStruct/fromStruct)
- Examples: `libs/Dashboard/DashboardWidget.m` (base), `libs/Dashboard/FastSenseWidget.m`, `libs/Dashboard/NumberWidget.m`
- Pattern: Abstract handle class; subclasses implement `render(parentPanel)`, `refresh()`, `getType()`

**DataSource (abstract):**
- Purpose: Pluggable interface for live data ingestion into the event pipeline
- Examples: `libs/EventDetection/DataSource.m` (interface), `libs/EventDetection/MatFileDataSource.m`, `libs/EventDetection/MockDataSource.m`
- Pattern: Abstract handle class; subclasses implement `fetchNew()` returning a standard struct

**FastSenseDataStore:**
- Purpose: Transparent disk backend so large datasets avoid loading into MATLAB RAM
- Examples: `libs/FastSense/FastSenseDataStore.m`
- Pattern: Handle class; chunk-indexed SQLite with range-query API; WAL mode for concurrent WebBridge reads

**SensorRegistry:**
- Purpose: Singleton catalog of named `Sensor` definitions
- Examples: `libs/SensorThreshold/SensorRegistry.m`
- Pattern: Static-method class using persistent variable; `get(key)` / `register(key, sensor)`

## Entry Points

**`install.m`:**
- Location: `install.m`
- Triggers: Run once after clone to add paths and compile MEX
- Responsibilities: `addpath` for all `libs/`, `examples/`, `benchmarks/`, `tests/`; MEX compilation

**`FastSense` constructor:**
- Location: `libs/FastSense/FastSense.m`
- Triggers: Direct user instantiation
- Responsibilities: Accept parent axes/LinkGroup/Theme/options, defer rendering to `render()`

**`DashboardEngine` constructor:**
- Location: `libs/Dashboard/DashboardEngine.m`
- Triggers: Direct user instantiation or `DashboardEngine.load(jsonPath)`
- Responsibilities: Create `DashboardLayout`, store widget list, accept name-value options

**`WebBridge.serve()`:**
- Location: `libs/WebBridge/WebBridge.m`
- Triggers: User calls `wb = WebBridge(dashboard); wb.serve()`
- Responsibilities: Enable WAL on data stores, start TCP server, launch Python subprocess, start config poll timer

**`LiveEventPipeline.start()`:**
- Location: `libs/EventDetection/LiveEventPipeline.m`
- Triggers: User calls `pipeline.start()`
- Responsibilities: Create MATLAB timer, run `IncrementalEventDetector` each tick, persist to `EventStore`, fire `NotificationService`

**`run_all_tests.m`:**
- Location: `tests/run_all_tests.m`
- Triggers: CI or developer runs tests
- Responsibilities: Discovers and runs all test files in `tests/`

## Error Handling

**Strategy:** Error IDs (`ClassName:reason`) on all `error()` calls; no global try/catch

**Patterns:**
- All `error()` calls use namespaced IDs (e.g., `'SensorRegistry:unknownKey'`, `'EventDetector:unknownOption'`)
- Constructor option validation: unknown keys throw immediately with helpful message listing valid options
- MEX fallback: if a `.mex` binary is absent the corresponding pure-MATLAB `.m` implementation is used transparently
- `EventStore.save()` uses atomic write (temp file rename) to prevent corrupt saves

## Cross-Cutting Concerns

**Logging:** `Verbose = true` on `FastSense` prints diagnostics; `ConsoleProgressBar.m` in `libs/FastSense/` for render progress
**Validation:** `parseOpts.m` (private helper used by `EventDetection` and others) provides defaults-based option parsing
**Authentication:** Not applicable — local MATLAB library with no auth layer

---

*Architecture analysis: 2026-04-01*
