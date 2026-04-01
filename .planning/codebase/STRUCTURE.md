# Codebase Structure

**Analysis Date:** 2026-04-01

## Directory Layout

```
FastPlot/
├── libs/                     # All MATLAB library code, one subdirectory per library
│   ├── FastSense/            # Core rendering engine + disk storage + MEX
│   │   └── private/          # Internal helpers and MEX C sources
│   │       └── mex_src/      # C source files for MEX kernels
│   ├── SensorThreshold/      # Sensor domain model, threshold rules, state channels
│   │   └── private/          # Internal resolve/batch helpers
│   ├── EventDetection/       # Event detection, live pipeline, notifications
│   │   └── private/          # groupViolations, parseOpts
│   ├── Dashboard/            # Widget-based dashboard engine
│   └── WebBridge/            # MATLAB-side TCP bridge
├── bridge/                   # Non-MATLAB bridge components
│   ├── python/               # FastAPI HTTP + WebSocket server
│   │   └── fastsense_bridge/ # Python package (server, tcp_client, sqlite_reader, blob_decoder)
│   └── web/                  # Browser client
│       ├── js/               # app.js, chart.js, dashboard.js, widgets.js, actions.js
│       ├── css/              # style.css
│       └── vendor/           # Third-party JS/CSS dependencies
├── tests/                    # All test files (flat + suite/ subfolder)
│   └── suite/                # Newer class-based (matlab.unittest) test classes
├── examples/                 # Runnable example scripts (one per feature area)
├── benchmarks/               # Performance benchmarks and profiling scripts
├── scripts/                  # Code generation utilities (Python)
├── docs/                     # Documentation, images, design plans
│   ├── images/
│   ├── plans/
│   └── superpowers/
├── private/                  # Root-level MEX binaries (shared fallback path)
├── wiki/                     # Generated wiki pages
├── install.m                 # One-time setup: addpath + MEX compile
├── miss_hit.cfg              # MISS_HIT static analysis configuration
├── README.md
└── CITATION.cff
```

## Directory Purposes

**`libs/FastSense/`:**
- Purpose: Core plotting engine; everything needed to render one time series tile
- Contains: `FastSense.m`, `FastSenseGrid.m`, `FastSenseDock.m`, `FastSenseToolbar.m`, `FastSenseTheme.m`, `FastSenseDataStore.m`, `FastSenseDefaults.m`, `SensorDetailPlot.m`, `NavigatorOverlay.m`, `ConsoleProgressBar.m`, compiled MEX binaries
- Key files: `FastSense.m`, `FastSenseDataStore.m`, `FastSenseTheme.m`

**`libs/FastSense/private/`:**
- Purpose: Internal MATLAB helpers not part of the public API
- Contains: `lttb_downsample.m`, `minmax_downsample.m`, `compute_violations.m`, `compute_violations_dynamic.m`, `downsample_violations.m`, `violation_cull.m`, `binary_search.m`, `getDefaults.m`, `clearDefaultsCache.m`, `loadMetaStruct.m`, `mergeTheme.m`, `resolveTheme.m`, `parseOpts.m`, `struct2nvpairs.m`
- Key files: `lttb_downsample.m`, `minmax_downsample.m`

**`libs/FastSense/private/mex_src/`:**
- Purpose: C source files for all MEX kernels
- Contains: `lttb_core_mex.c`, `minmax_core_mex.c`, `compute_violations_mex.c`, `violation_cull_mex.c`, `binary_search_mex.c`, `build_store_mex.c`, `resolve_disk_mex.c`, `to_step_function_mex.c`, `simd_utils.h`, `sqlite3.c`, `sqlite3.h`

**`libs/SensorThreshold/`:**
- Purpose: Domain model for sensors, state channels, and condition-driven thresholds
- Contains: `Sensor.m`, `SensorRegistry.m`, `ThresholdRule.m`, `StateChannel.m`, `loadModuleData.m`, `loadModuleMetadata.m`, `ExternalSensorRegistry.m`
- Key files: `Sensor.m`, `SensorRegistry.m`, `ThresholdRule.m`

**`libs/SensorThreshold/private/`:**
- Purpose: Internal computation helpers for threshold resolution
- Contains: `alignStateToTime.m`, `toStepFunction.m`, `compute_violations_batch.m`, `compute_violations_disk.m`, `buildThresholdEntry.m`, `mergeResolvedByLabel.m`, `conditionKey.m`, `appendResults.m`, `extractDatenumField.m`, plus MEX binaries

**`libs/EventDetection/`:**
- Purpose: Batch and live event detection from threshold violations
- Contains: `EventDetector.m`, `IncrementalEventDetector.m`, `LiveEventPipeline.m`, `EventStore.m`, `Event.m`, `EventConfig.m`, `EventViewer.m`, `NotificationRule.m`, `NotificationService.m`, `DataSource.m` (abstract), `DataSourceMap.m`, `MatFileDataSource.m`, `MockDataSource.m`, `detectEventsFromSensor.m`, `generateEventSnapshot.m`, `printEventSummary.m`, `eventLogger.m`
- Key files: `LiveEventPipeline.m`, `EventDetector.m`, `DataSource.m`

**`libs/Dashboard/`:**
- Purpose: Widget composition layer over `FastSense` for multi-widget dashboards
- Contains: `DashboardEngine.m`, `DashboardWidget.m` (abstract base), `DashboardLayout.m`, `DashboardSerializer.m`, `DashboardTheme.m`, `DashboardToolbar.m`, `DashboardBuilder.m`, all concrete widget classes
- Key files: `DashboardEngine.m`, `DashboardWidget.m`, `DashboardLayout.m`

**`libs/WebBridge/`:**
- Purpose: MATLAB-side TCP server and protocol codec for browser visualization
- Contains: `WebBridge.m`, `WebBridgeProtocol.m`
- Key files: `WebBridge.m`

**`bridge/python/fastsense_bridge/`:**
- Purpose: Python package that bridges MATLAB TCP messages to browser WebSocket/REST
- Contains: `server.py` (FastAPI), `tcp_client.py`, `sqlite_reader.py`, `blob_decoder.py`, `__main__.py`
- Key files: `server.py`, `tcp_client.py`

**`bridge/web/js/`:**
- Purpose: Browser-side JavaScript for dashboard rendering and WebSocket communication
- Contains: `app.js`, `chart.js`, `dashboard.js`, `widgets.js`, `actions.js`

**`tests/`:**
- Purpose: All test files; flat `.m` test scripts (legacy) and class-based suites
- Contains: `run_all_tests.m`, `add_fastsense_private_path.m`, 70+ `test_*.m` files
- Key files: `run_all_tests.m`

**`tests/suite/`:**
- Purpose: Newer `matlab.unittest.TestCase` class-based test classes
- Contains: 90+ `Test*.m` class files, `MockDashboardWidget.m`
- Key files: Mirrors all `test_*.m` files with class-based equivalents

**`examples/`:**
- Purpose: Runnable scripts demonstrating every feature; also used as acceptance tests
- Contains: 60+ `example_*.m` files, `demo_all.m`, `run_all_examples.m`

**`benchmarks/`:**
- Purpose: Performance measurement scripts
- Contains: `benchmark.m`, `benchmark_datastore.m`, `benchmark_features.m`, `benchmark_memory.m`, `benchmark_resolve.m`, `benchmark_resolve_stress.m`, `benchmark_zoom.m`, `profile_datastore.m`

**`scripts/`:**
- Purpose: Code generation and documentation utilities
- Contains: `generate_api_docs.py`, `generate_wiki.py`, `run_ci_benchmark.m`, `run_tests_with_coverage.m`

**`private/` (root):**
- Purpose: Root-level compiled MEX binaries accessible from the project root path
- Generated: Yes (compiled by `install.m` / `build_mex.m`)
- Committed: No (binaries excluded by `.gitignore`)

## Key File Locations

**Entry Points:**
- `install.m`: One-time setup — adds all paths, compiles MEX
- `libs/FastSense/FastSense.m`: Core plot object constructor
- `libs/Dashboard/DashboardEngine.m`: Dashboard orchestrator constructor
- `libs/WebBridge/WebBridge.m`: Web bridge entry point
- `libs/EventDetection/LiveEventPipeline.m`: Live event detection entry point
- `tests/run_all_tests.m`: Test runner

**Configuration:**
- `miss_hit.cfg`: MISS_HIT static analysis and style rules
- `install.m`: Defines which directories are on the MATLAB path

**Core Logic:**
- `libs/FastSense/FastSense.m`: Rendering, downsampling dispatch, zoom/pan, live mode
- `libs/FastSense/FastSenseDataStore.m`: SQLite chunked storage and pyramid cache
- `libs/FastSense/private/lttb_downsample.m`: LTTB algorithm (calls MEX)
- `libs/FastSense/private/minmax_downsample.m`: MinMax algorithm (calls MEX)
- `libs/SensorThreshold/Sensor.m`: Sensor resolve pipeline
- `libs/SensorThreshold/SensorRegistry.m`: Singleton sensor catalog
- `libs/EventDetection/EventDetector.m`: Batch threshold-violation grouping
- `libs/EventDetection/IncrementalEventDetector.m`: Stateful incremental detector for live mode
- `libs/Dashboard/DashboardWidget.m`: Abstract widget base class
- `libs/Dashboard/DashboardLayout.m`: 24-column grid layout engine
- `libs/WebBridge/WebBridgeProtocol.m`: NDJSON message codec

**Testing:**
- `tests/suite/`: Class-based `matlab.unittest.TestCase` tests (preferred for new tests)
- `tests/test_*.m`: Legacy function-based test scripts
- `tests/run_all_tests.m`: Runs all tests
- `scripts/run_tests_with_coverage.m`: Runs tests with coverage reporting

## Naming Conventions

**Files:**
- MATLAB classes: PascalCase matching the classdef name (e.g., `FastSense.m`, `DashboardEngine.m`)
- MATLAB functions: camelCase (e.g., `loadModuleData.m`, `parseOpts.m`, `groupViolations.m`)
- Test scripts (legacy): `test_snake_case.m` (e.g., `test_add_sensor.m`)
- Test classes (suite): `TestPascalCase.m` (e.g., `TestAddSensor.m`, `TestDashboardEngine.m`)
- Example scripts: `example_snake_case.m` (e.g., `example_basic.m`, `example_sensor_dashboard.m`)
- MEX sources: `snake_case_mex.c` (e.g., `lttb_core_mex.c`)
- MEX binaries: `snake_case_mex.mexmaca64` / `snake_case_mex.mex`

**Directories:**
- Libraries: PascalCase (e.g., `FastSense/`, `SensorThreshold/`, `Dashboard/`)
- Internal: `private/` subdirectory within each library for non-public code

## Where to Add New Code

**New Plotting Feature (e.g., new overlay type):**
- Primary code: `libs/FastSense/FastSense.m` (new `add*()` method)
- Internal helpers if complex: `libs/FastSense/private/`
- MEX kernel if performance-critical: `libs/FastSense/private/mex_src/` + register in `build_mex.m`
- Tests: `tests/suite/TestAddXxx.m` (class-based)
- Example: `examples/example_xxx.m`

**New Dashboard Widget:**
- Implementation: `libs/Dashboard/XxxWidget.m` extending `DashboardWidget`
- Register type: Add `case 'xxx'` to `DashboardEngine.addWidget()` in `libs/Dashboard/DashboardEngine.m`
- Serialization: Add `case 'xxx'` in `libs/Dashboard/DashboardSerializer.m`
- Tests: `tests/suite/TestXxxWidget.m`

**New Sensor Domain Concept:**
- Implementation: `libs/SensorThreshold/` (public class) or `libs/SensorThreshold/private/` (helper)
- Register in catalog: Edit `SensorRegistry.catalog()` in `libs/SensorThreshold/SensorRegistry.m`

**New Event Detection Feature:**
- Implementation: `libs/EventDetection/`
- Private helpers: `libs/EventDetection/private/`
- Tests: `tests/suite/TestXxx.m`

**Utilities / Shared Helpers:**
- Shared MATLAB helpers: `libs/FastSense/private/` (if FastSense-specific) or `libs/EventDetection/private/parseOpts.m` pattern
- Python utilities for bridge: `bridge/python/fastsense_bridge/`

## Special Directories

**`libs/FastSense/private/mex_src/`:**
- Purpose: C source files for compiled performance kernels; not on MATLAB path directly
- Generated: No (hand-written C)
- Committed: Yes

**`private/` (root) and `libs/FastSense/private/*.mex*`:**
- Purpose: Compiled MEX binary output
- Generated: Yes (by `install.m` calling `build_mex.m`)
- Committed: No (in `.gitignore`)

**`tests/suite/`:**
- Purpose: Class-based test suite (preferred over legacy `tests/test_*.m`)
- Generated: No
- Committed: Yes

**`wiki/`:**
- Purpose: Auto-generated wiki pages from source docstrings
- Generated: Yes (by `scripts/generate_wiki.py`)
- Committed: Yes (checked in for GitHub wiki rendering)

**`.planning/codebase/`:**
- Purpose: GSD codebase analysis documents for Claude planning commands
- Generated: Yes (by Claude `map-codebase` command)
- Committed: Optional

---

*Structure analysis: 2026-04-01*
