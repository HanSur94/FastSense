<!-- GSD:project-start source:PROJECT.md -->
## Project

**FastSense Advanced Dashboard**

An upgrade to FastSense's existing dashboard engine adding nested layout organization (tabs, collapsible groups, multi-page navigation), per-widget info tooltips for contextual documentation, and detachable live-mirrored widgets that pop out as independent figure windows. Built for MATLAB engineers who use dashboards for sensor data analysis.

**Core Value:** Users can organize complex dashboards into navigable sections and pop out any widget for detailed analysis without losing the dashboard context.

### Constraints

- **Tech stack**: Pure MATLAB (no external dependencies) — consistent with existing codebase
- **Backward compatibility**: Existing dashboard scripts and serialized dashboards must continue to work
- **Widget contract**: New features must work through the existing DashboardWidget base class interface
- **Performance**: Detached live-mirrored widgets must not degrade dashboard refresh rate
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- MATLAB - Core plotting engine, sensor modeling, dashboard, event detection, WebBridge server side
- C - MEX acceleration kernels (SIMD-optimized); SQLite3 bundled amalgamation
- Python 3.11+ - Web bridge server (`bridge/python/`)
- JavaScript (ES modules) - Browser dashboard frontend (`bridge/web/js/`)
- HTML/CSS - Browser dashboard UI (`bridge/web/`)
## Runtime
- MATLAB R2020b+ (primary target)
- GNU Octave 7+ (fully supported alternative)
- Linux (x86_64, CI primary)
- macOS (ARM64 / Apple Silicon primary dev machine)
- Windows (x86_64, tested in CI via Chocolatey Octave 9.2.0)
- Python 3.11+ (bridge server only)
- pip / pyproject.toml
- Lockfile: not present (no uv.lock or requirements.txt)
## Frameworks
- No external MATLAB toolboxes required — all functionality is toolbox-free
- MEX C extensions compiled via `build_mex()` / `install()` at first run
- FastAPI >= 0.104 - REST API + WebSocket + static file serving
- Uvicorn >= 0.24 - ASGI server (standard extras for websockets)
- uPlot (vendored) - High-performance time series charting library (`bridge/web/vendor/uPlot.min.js`, `bridge/web/vendor/uPlot.min.css`)
- Vanilla JS (no build step, no npm)
- pytest >= 7.0
- pytest-asyncio >= 0.21 (asyncio_mode = auto)
- httpx >= 0.25 (async HTTP test client)
- Custom test runner (`tests/run_all_tests.m`)
- Both flat script tests (`tests/test_*.m`) and class-based suites (`tests/suite/Test*.m`)
- MISS_HIT (Python pip install) - MATLAB style checker, linter, and complexity metrics
## Key Dependencies
- SQLite3 amalgamation (bundled at `libs/FastSense/private/mex_src/sqlite3.c` + `sqlite3.h`) - disk-backed DataStore; no system install required
- mksqlite (bundled C source at `libs/FastSense/mksqlite.c`) - MATLAB MEX interface to SQLite3
- `binary_search_mex.c` - binary search on sorted time arrays
- `minmax_core_mex.c` - MinMax downsampling kernel (AVX2/NEON)
- `lttb_core_mex.c` - Largest-Triangle-Three-Buckets downsampling kernel
- `violation_cull_mex.c` - threshold violation culling
- `compute_violations_mex.c` - batch violation detection
- `to_step_function_mex.c` - SIMD step-function conversion
- `build_store_mex.c` - bulk SQLite writer for DataStore init
- `resolve_disk_mex.c` - disk-based resolve with SQLite
- `fastapi >= 0.104`
- `uvicorn[standard] >= 0.24`
- `websockets >= 12.0`
- `numpy >= 1.24`
- `anthropic` (dev/scripts dependency, NOT in main dependencies — used only by `scripts/generate_wiki.py`)
- GitHub Actions - CI/CD (tests, MEX build, benchmarks, wiki generation, release)
- Codecov - test coverage reporting (MATLAB runs only; token via secret)
## Configuration
- `FASTSENSE_SKIP_BUILD=1` - skip MEX compilation in CI when MEX binaries are cached
- `FASTSENSE_RESULTS_FILE` - path for Octave test result output in CI
- `ANTHROPIC_API_KEY` - required only for `scripts/generate_wiki.py` (wiki auto-generation)
- `miss_hit.cfg` - MISS_HIT linter/style/metric configuration (project root)
- `bridge/python/pyproject.toml` - Python bridge package config
- ARM64: `-O3 -ffast-math` (Clang/MATLAB) or `-O3 -mcpu=apple-m3 -ftree-vectorize -ffast-math` (GCC/Octave)
- x86_64: `-O3 -mavx2 -mfma -ftree-vectorize -ffast-math` (with SSE2 fallback)
- Windows MSVC: `/O2 /arch:AVX2 /fp:fast`
## Platform Requirements
- MATLAB R2020b+ or GNU Octave 7+
- C compiler accessible to `mex` or `mkoctfile` (Xcode CLT on macOS, GCC on Linux, MSVC on Windows)
- Optional: GCC via Homebrew (`/opt/homebrew/bin/gcc-{10..15}`) for Octave AVX2 builds
- Python 3.11+ (only if using the WebBridge feature)
- Self-contained MATLAB/Octave environment
- No internet access required; no toolbox licenses required
- MEX binaries must be compiled once per platform on install
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Classes: PascalCase matching the class name exactly — `FastSense.m`, `DashboardBuilder.m`, `EventDetector.m`
- Functions: camelCase or lowercase — `parseOpts.m`, `compute_violations.m`, `groupViolations.m`
- Test files (suite): `Test` prefix + PascalCase — `TestSensor.m`, `TestEventDetector.m`
- Test files (Octave function-based): `test_` prefix + snake_case — `test_sensor.m`, `test_add_sensor.m`
- Private helpers: placed in `private/` subdirectory of owning library
- PascalCase with regex `[A-Z][a-zA-Z0-9]+` (enforced by MISS_HIT)
- Handle classes inherit from `handle`: `classdef FastSense < handle`
- Abstract base classes used for interfaces: `DataSource` (abstract), subclassed by `MockDataSource`, `MatFileDataSource`
- Public API: camelCase — `addSensor()`, `addThreshold()`, `addLine()`, `render()`
- Private helpers: camelCase — `rngRand()`, `rngRandn()`, `generateBacklog()`
- Lifecycle: `TestClassSetup` method always named `addPaths`
- Test methods: camelCase starting with verb — `testConstructorDefaults`, `testAddSensorBasic`
- Public properties: PascalCase — `Key`, `Name`, `Lines`, `Thresholds`, `IsRendered`
- Private implementation properties: trailing underscore sometimes used for internal state — `rng_`, `lastTime_`, `backlogDone_`
- Inline default values on property declaration — `Verbose = false`, `LiveInterval = 2.0`
- Pattern: `ClassName:camelCaseProblem` — e.g., `FastSense:alreadyRendered`, `Sensor:unknownOption`, `EventDetector:unknownOption`
- Local variables: camelCase — `nPts`, `startTime`, `endTime`, `thresholdLabel`
- Loop indices: single letters `i`, `j`, `k`
- Count variables: `n` prefix — `nPts`, `nPassed`, `nFailed`
- Boolean flags: `Is` prefix for properties — `IsRendered`, `IsActive`, `IsServing`
## Code Style
- Tool: MISS_HIT (`mh_style`, `mh_lint`, `mh_metric`)
- Config: `miss_hit.cfg` at repo root
- Line length: 160 characters maximum
- Tab width: 4 spaces
- Many style rules currently suppressed to accommodate existing code (see `suppress_rule` entries in `miss_hit.cfg`)
- Tool: MISS_HIT `mh_lint` and `mh_metric --ci`
- Cyclomatic complexity limit: 80 (aspirational target: 20)
- Max function length: 520 lines (aspirational target: 200)
- Max nesting depth: 5
- Max parameters: 12 (aspirational target: 8)
## Import Organization
- Tests call `install()` to add all library paths
- Each test file includes a local `add_sensor_path()` or similar helper function
- Suite tests use `TestClassSetup` with `addPaths` to call `addpath` + `install()`
- No import statements for MATLAB code (functions are on path)
- Python bridge uses standard module imports with explicit relative imports within the package
## Error Handling
## Logging
- Verbose diagnostics guarded by `obj.Verbose` flag (default `false`)
- Prefix format: `[ClassName]` — e.g., `[FastSense] render: line 1: 1000 pts -> 200 displayed`
- Test progress: `fprintf('    All N tests passed.\n')` in Octave-style function tests
- Suite progress: printed automatically by `TestRunner.withTextOutput`
## Comments
- All public classes: comprehensive header comment with description, usage examples, property list, method list, and See also
- All public methods: `%METHODNAME Description.` header followed by input/output documentation
- Private helpers: brief `%FUNCTIONNAME Purpose.` header
- Inline logic: short comments explaining non-obvious decisions (especially NaN handling, IEEE 754 guarantees, performance choices)
## Function Design
## Module Design
- `properties (Access = public)` — user-configurable settings
- `properties (SetAccess = private)` — internal data readable but not writable externally
- `properties (Access = private)` — fully internal state
- `methods (Access = public)` — public API
- `methods (Access = private)` — internal helpers
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Five independent libraries (`libs/`) each with a clear single responsibility
- Core rendering engine (`FastSense`) wraps MATLAB axes and drives all plotting via a render/update lifecycle
- Performance-critical code is implemented as compiled MEX C extensions with pure-MATLAB fallbacks
- Dashboard layer composes reusable `DashboardWidget` subclasses over the core rendering engine
- Browser-based visualization is bridged via TCP (MATLAB) → Python FastAPI server → WebSocket → browser
## Layers
- Purpose: Ultra-fast time series plotting with dynamic downsampling
- Location: `libs/FastSense/`
- Contains: `FastSense.m` (main class), `FastSenseGrid.m`, `FastSenseDock.m`, `FastSenseToolbar.m`, `SensorDetailPlot.m`, `NavigatorOverlay.m`
- Depends on: `FastSenseDataStore` (disk backend), `FastSenseTheme` (styling), MEX kernels
- Used by: Dashboard widgets (`FastSenseWidget`), direct user scripts, `SensorDetailPlot`
- Purpose: SQLite-based chunked storage for datasets that exceed MATLAB memory
- Location: `libs/FastSense/FastSenseDataStore.m`
- Contains: Chunk-based read/write logic, WAL mode for live use, pyramid-level downsampling cache
- Depends on: `mksqlite` (bundled SQLite3 MEX), binary file fallback when mksqlite is absent
- Used by: `FastSense` when data is stored to disk, `WebBridge` WAL writes
- Purpose: SIMD-optimized kernels for downsampling, violation detection, binary search, disk resolution
- Location: `libs/FastSense/private/mex_src/` (C sources), compiled to `*.mex`/`*.mexmaca64` binaries
- Contains: `lttb_core_mex.c`, `minmax_core_mex.c`, `compute_violations_mex.c`, `violation_cull_mex.c`, `binary_search_mex.c`, `build_store_mex.c`, `resolve_disk_mex.c`, `to_step_function_mex.c`, `simd_utils.h`, bundled SQLite3 (`sqlite3.c`/`sqlite3.h`)
- Depends on: Platform compiler; AVX2 (x86_64) or NEON (ARM64) with scalar fallback
- Used by: `FastSense`, `FastSenseDataStore`, `SensorThreshold` private helpers
- Purpose: Domain model for sensors with state-dependent, condition-driven threshold rules
- Location: `libs/SensorThreshold/`
- Contains: `Sensor.m`, `SensorRegistry.m`, `ThresholdRule.m`, `StateChannel.m`, `loadModuleData.m`, `loadModuleMetadata.m`, `ExternalSensorRegistry.m`
- Depends on: MEX helpers (`to_step_function_mex`, `compute_violations_mex`, `resolve_disk_mex`, `violation_cull_mex`) via private helpers
- Used by: `FastSense.addSensor()`, `FastSenseWidget`, `SensorDetailPlot`, `EventDetection`, `DashboardEngine`
- Purpose: Detect, persist, and stream threshold-violation events in batch and live modes
- Location: `libs/EventDetection/`
- Contains: `EventDetector.m`, `IncrementalEventDetector.m`, `LiveEventPipeline.m`, `EventStore.m`, `Event.m`, `EventConfig.m`, `EventViewer.m`, `NotificationRule.m`, `NotificationService.m`, `DataSource.m`, `DataSourceMap.m`, `MatFileDataSource.m`, `MockDataSource.m`, `detectEventsFromSensor.m`, `generateEventSnapshot.m`
- Depends on: `SensorThreshold` (`Sensor`, `ThresholdRule`), private helpers (`groupViolations.m`, `parseOpts.m`)
- Used by: Standalone scripts, `LiveEventPipeline` timer, `EventViewer`
- Purpose: Widget-based dashboard composition, layout, theming, serialization, and live refresh
- Location: `libs/Dashboard/`
- Contains: `DashboardEngine.m` (orchestrator), `DashboardWidget.m` (abstract base), `DashboardLayout.m` (24-column grid), `DashboardSerializer.m` (JSON/`.m` export), `DashboardTheme.m`, `DashboardToolbar.m`, `DashboardBuilder.m`, and concrete widgets (`FastSenseWidget.m`, `NumberWidget.m`, `StatusWidget.m`, `GaugeWidget.m`, `TextWidget.m`, `TableWidget.m`, `BarChartWidget.m`, `HeatmapWidget.m`, `HistogramWidget.m`, `ScatterWidget.m`, `ImageWidget.m`, `MultiStatusWidget.m`, `EventTimelineWidget.m`, `GroupWidget.m`, `RawAxesWidget.m`, `MarkdownRenderer.m`)
- Depends on: `FastSense` (via `FastSenseWidget`), `SensorThreshold` (via `Sensor` binding), `EventDetection` (via `EventTimelineWidget`)
- Used by: End-user dashboard scripts, `WebBridge`
- Purpose: Expose dashboard data and actions to a browser via TCP+Python HTTP server
- Location: `libs/WebBridge/` (MATLAB side), `bridge/python/` (server side), `bridge/web/` (browser client)
- Contains (MATLAB): `WebBridge.m`, `WebBridgeProtocol.m` (NDJSON message codec)
- Contains (Python): `server.py` (FastAPI + WebSocket), `tcp_client.py`, `sqlite_reader.py`, `blob_decoder.py`
- Contains (Web): `app.js`, `chart.js`, `dashboard.js`, `widgets.js`, `actions.js`, `style.css`
- Depends on: `FastSenseDataStore` (SQLite files), `DashboardEngine` (config), Python FastAPI/uvicorn
- Used by: Optional browser visualization workflow
## Data Flow
- Each `FastSense` instance holds its own line/threshold/band state before and after render
- `DashboardEngine` owns `Widgets` list and drives refresh via a MATLAB timer
- `SensorRegistry` is a persistent singleton (`containers.Map` cached in static method)
- `FastSenseDataStore` manages SQLite connection lifecycle and pyramid cache
## Key Abstractions
- Purpose: Single-tile high-performance time series plot with downsampling
- Examples: `libs/FastSense/FastSense.m`
- Pattern: Handle class; pre-render configuration via `add*()` methods; post-render update via `updateData()`
- Purpose: Uniform interface for all dashboard widgets (render, refresh, toStruct/fromStruct)
- Examples: `libs/Dashboard/DashboardWidget.m` (base), `libs/Dashboard/FastSenseWidget.m`, `libs/Dashboard/NumberWidget.m`
- Pattern: Abstract handle class; subclasses implement `render(parentPanel)`, `refresh()`, `getType()`
- Purpose: Pluggable interface for live data ingestion into the event pipeline
- Examples: `libs/EventDetection/DataSource.m` (interface), `libs/EventDetection/MatFileDataSource.m`, `libs/EventDetection/MockDataSource.m`
- Pattern: Abstract handle class; subclasses implement `fetchNew()` returning a standard struct
- Purpose: Transparent disk backend so large datasets avoid loading into MATLAB RAM
- Examples: `libs/FastSense/FastSenseDataStore.m`
- Pattern: Handle class; chunk-indexed SQLite with range-query API; WAL mode for concurrent WebBridge reads
- Purpose: Singleton catalog of named `Sensor` definitions
- Examples: `libs/SensorThreshold/SensorRegistry.m`
- Pattern: Static-method class using persistent variable; `get(key)` / `register(key, sensor)`
## Entry Points
- Location: `install.m`
- Triggers: Run once after clone to add paths and compile MEX
- Responsibilities: `addpath` for all `libs/`, `examples/`, `benchmarks/`, `tests/`; MEX compilation
- Location: `libs/FastSense/FastSense.m`
- Triggers: Direct user instantiation
- Responsibilities: Accept parent axes/LinkGroup/Theme/options, defer rendering to `render()`
- Location: `libs/Dashboard/DashboardEngine.m`
- Triggers: Direct user instantiation or `DashboardEngine.load(jsonPath)`
- Responsibilities: Create `DashboardLayout`, store widget list, accept name-value options
- Location: `libs/WebBridge/WebBridge.m`
- Triggers: User calls `wb = WebBridge(dashboard); wb.serve()`
- Responsibilities: Enable WAL on data stores, start TCP server, launch Python subprocess, start config poll timer
- Location: `libs/EventDetection/LiveEventPipeline.m`
- Triggers: User calls `pipeline.start()`
- Responsibilities: Create MATLAB timer, run `IncrementalEventDetector` each tick, persist to `EventStore`, fire `NotificationService`
- Location: `tests/run_all_tests.m`
- Triggers: CI or developer runs tests
- Responsibilities: Discovers and runs all test files in `tests/`
## Error Handling
- All `error()` calls use namespaced IDs (e.g., `'SensorRegistry:unknownKey'`, `'EventDetector:unknownOption'`)
- Constructor option validation: unknown keys throw immediately with helpful message listing valid options
- MEX fallback: if a `.mex` binary is absent the corresponding pure-MATLAB `.m` implementation is used transparently
- `EventStore.save()` uses atomic write (temp file rename) to prevent corrupt saves
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
