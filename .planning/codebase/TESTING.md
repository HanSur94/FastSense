# Testing Patterns

**Analysis Date:** 2026-04-01

## Test Framework

**Runner (MATLAB):**
- `matlab.unittest` — class-based test suite in `tests/suite/`
- Config: `scripts/run_tests_with_coverage.m` (coverage), `tests/run_all_tests.m` (basic)

**Runner (Octave):**
- Function-based tests in `tests/test_*.m`
- Each test runs in an isolated subprocess to survive Octave 8.x `break_closure_cycles` crash
- Subprocess isolation implemented in `tests/run_all_tests.m` via `run_octave_tests()`

**Python bridge:**
- `pytest>=7.0` with `pytest-asyncio>=0.21`
- FastAPI `TestClient` (from `httpx`) for REST endpoint testing
- Config: `[tool.pytest.ini_options]` in `bridge/python/pyproject.toml` with `asyncio_mode = "auto"`

**Assertion Library (MATLAB):**
- `testCase.verifyEqual(actual, expected, 'message')`
- `testCase.verifyTrue(condition, 'message')`
- `testCase.verifyFalse(condition, 'message')`
- `testCase.verifyEmpty(value, 'message')`
- `testCase.verifyNotEmpty(value, 'message')`
- `testCase.verifyGreaterThan(a, b, 'message')`
- `testCase.verifyLessThan(a, b, 'message')`
- `testCase.verifyError(@() expr, 'ErrorID:subid')`
- `testCase.verifyWarning(@() expr, 'WarningID:subid')`
- `testCase.verifyWarningFree(@() expr, 'message')`

**Assertion Library (Python):**
- Native `assert` statements
- `numpy.testing.assert_array_equal` for numeric array comparisons

**Run Commands:**
```bash
# MATLAB — all tests
matlab -batch "cd tests; run_all_tests()"

# MATLAB — tests with coverage (outputs coverage.xml for Codecov)
matlab -batch "addpath('scripts'); run_tests_with_coverage()"

# Octave — all tests (subprocess isolation)
cd tests && octave --eval "run_all_tests()"

# Python bridge
cd bridge/python && pytest

# CI — lint + metric check
mh_style libs/ tests/ examples/
mh_lint libs/ tests/ examples/
mh_metric --ci libs/ tests/ examples/
```

## Test File Organization

**Location:**
- MATLAB suite (class-based): `tests/suite/Test*.m` — primary test location
- MATLAB Octave compat (function-based): `tests/test_*.m` — parallel to suite
- Python: `bridge/python/tests/test_*.py`

**Naming:**
- Suite class files: `Test` + PascalCase subject — `TestSensor.m`, `TestEventDetector.m`, `TestDashboardBuilder.m`
- Octave function files: `test_` + snake_case subject — `test_sensor.m`, `test_event_detector.m`
- Python files: `test_` + snake_case — `test_server.py`, `test_blob_decoder.py`

**Structure:**
```
tests/
├── run_all_tests.m          # Entry point: runs MATLAB suite or Octave tests
├── add_fastsense_private_path.m  # Helper to add private/ dirs to path
├── test_*.m                 # Octave-compatible function-based tests
└── suite/
    └── Test*.m              # matlab.unittest class-based tests (primary)

bridge/python/tests/
├── __init__.py
├── test_server.py           # FastAPI endpoint tests
├── test_blob_decoder.py     # Unit tests for BLOB decoder
├── test_tcp_client.py       # TCP client tests
└── test_sqlite_reader.py    # SQLite reader tests
```

## Test Structure

**Suite Organization (MATLAB — primary pattern):**
```matlab
classdef TestSensor < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            % optionally: add_fastsense_private_path();
        end
    end

    methods (Test)
        function testConstructorDefaults(testCase)
            s = Sensor('pressure');
            testCase.verifyEqual(s.Key, 'pressure', 'testConstructor: Key');
            testCase.verifyEmpty(s.Name, 'testConstructor: Name default');
        end

        function testSomethingWithFigure(testCase)
            d = DashboardEngine('Test');
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));
            % ... assertions
        end
    end

    methods (Static, Access = private)
        function deleteIfExists(path)
            if exist(path, 'file'); delete(path); end
        end
    end
end
```

**Octave Function-Based Pattern:**
```matlab
function test_sensor()
%TEST_SENSOR Tests for Sensor class.
    add_sensor_path();

    % testConstructorDefaults
    s = Sensor('pressure');
    assert(strcmp(s.Key, 'pressure'), 'testConstructor: Key');
    assert(isempty(s.Name), 'testConstructor: Name default');

    fprintf('    All 5 sensor tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
```

**Patterns:**
- Every suite test class has a `TestClassSetup` method `addPaths` that calls `install()`
- Figure-creating tests: always call `set(d.hFigure, 'Visible', 'off')` and register `testCase.addTeardown(@() close(d.hFigure))`
- Temporary file tests: register `testCase.addTeardown(@() TestClass.deleteIfExists(tmpFile))`
- Assertion messages use format `'testName: property'` for clear failure identification

## Mocking

**Framework:** MATLAB — manual mock classes (no external mock library)

**Patterns:**
```matlab
% MockDataSource — realistic industrial sensor signal generator for testing
src = MockDataSource('BaseValue', 100, 'NoiseStd', 1, 'Seed', 42);
result = src.fetchNew();

% MockDashboardWidget — test double for DashboardWidget
w = MockDashboardWidget();

% DashboardBuilder mock point injection — property on production class
builder.MockCurrentPoint = [x y];  % overrides figure CurrentPoint
```

**Python mock pattern:**
```python
from unittest.mock import AsyncMock, MagicMock

state.tcp_client = MagicMock()
state.tcp_client.send_action = AsyncMock()
# Verify:
app_state.tcp_client.send_action.assert_called_once()
```

**What to Mock:**
- External data sources: use `MockDataSource` instead of real `.mat` files or live data
- Figure/UI interactions: use `MockCurrentPoint` property to simulate mouse events
- TCP client in Python bridge tests: `MagicMock()` with `AsyncMock` for async methods

**What NOT to Mock:**
- Core computation functions (violations, downsampling) — test with real numeric data
- Class constructors and property access — use real objects

## Fixtures and Factories

**Test Data (MATLAB):**
```matlab
% Inline sensor with known data
s = Sensor('pressure', 'Name', 'Chamber Pressure');
s.X = 1:100;
s.Y = rand(1, 100) * 10;
s.resolve();

% State channel setup
sc = StateChannel('machine');
sc.X = [1 50]; sc.Y = [0 1];
s.addStateChannel(sc);
s.addThresholdRule(struct('machine', 1), 10, 'Direction', 'upper', 'Label', 'HH');

% Temporary file with cleanup
tmpFile = fullfile(tempdir, 'test_event_store.mat');
testCase.addTeardown(@() TestEventStore.deleteIfExists(tmpFile));
```

**Test Data (Python — pytest fixtures):**
```python
@pytest.fixture
def sample_db(tmp_path: Path) -> Path:
    """Create a minimal .fpdb with one chunk, thresholds, and violations."""
    db_path = tmp_path / "test.fpdb"
    conn = sqlite3.connect(str(db_path))
    # ... build schema and insert rows ...
    conn.commit()
    conn.close()
    return db_path

@pytest.fixture
def app_state(sample_db: Path) -> AppState:
    """Create an AppState with one signal and a mocked TCP client."""
    state = AppState()
    state.signals = [{"id": "s1", "dbPath": str(sample_db), "title": "Temperature"}]
    state.tcp_client = MagicMock()
    state.tcp_client.send_action = AsyncMock()
    return state

@pytest.fixture
def client(app_state: AppState) -> TestClient:
    app = create_app(app_state)
    return TestClient(app)
```

**Location:**
- MATLAB: inline in test methods (no shared fixture files)
- Python: `@pytest.fixture` functions at module scope in `bridge/python/tests/`

## Coverage

**Requirements:** No enforced minimum percentage.

**View Coverage:**
```bash
# MATLAB — generates coverage.xml (Cobertura format) uploaded to Codecov
matlab -batch "addpath('scripts'); run_tests_with_coverage()"

# CI uploads to Codecov with flag 'matlab' (only on schedule or workflow_dispatch)
```

**Coverage scope:** All `.m` files in `libs/FastSense/`, `libs/SensorThreshold/`, `libs/EventDetection/`, `libs/Dashboard/`, `libs/WebBridge/` (not `private/` subdirectories).

## Test Types

**Unit Tests:**
- Scope: individual class methods and private functions
- Examples: `TestSensor.m`, `TestEventDetector.m`, `TestComputeViolations.m`, `TestBinarySearch.m`
- Pattern: construct object, call method, verify returned values/state

**Integration Tests:**
- Scope: multi-class workflows (e.g., `Sensor` + `FastSense` + `addSensor`)
- Examples: `TestAddSensor.m`, `TestEventIntegration.m`, `TestEventStoreRw.m`
- Pattern: build full object graph, run workflow, verify end-to-end state

**UI/Render Tests:**
- Scope: figure creation, widget rendering, dashboard layout
- Examples: `TestDashboardBuilder.m`, `TestDashboardEngine.m`, `TestSensorDetailPlot.m`, `TestGaugeWidget.m`
- Pattern: render with `Visible=off`, add teardown to close, verify handle validity

**MEX/Parity Tests:**
- Scope: verify MEX and MATLAB implementations produce identical results
- Examples: `TestMexParity.m`, `TestViolationsMexParity.m`, `TestMexEdgeCases.m`
- Pattern: `testCase.assumeTrue(exist('binary_search_mex', 'file') == 3, 'MEX not compiled')` guards; skip gracefully if MEX absent

**E2E Tests:**
- `TestWebBridgeE2E.m` — starts real TCP server, connects client, validates message protocol
- `bridge/python/tests/test_server.py` — FastAPI `TestClient` hitting all REST endpoints

## Common Patterns

**Async Testing (Python):**
```python
# asyncio_mode = "auto" in pyproject.toml, so async tests work natively
async def test_something(client: TestClient) -> None:
    resp = client.get("/api/signals")
    assert resp.status_code == 200
```

**Error Testing (MATLAB):**
```matlab
% Verify a specific error ID is raised
testCase.verifyError(@() sdp.render(), 'SensorDetailPlot:alreadyRendered');
testCase.verifyError(@() fig.tilePanel(1), 'FastSenseGrid:tileConflict');

% Verify no warning
testCase.verifyWarningFree(@() w.render(hp), 'render should not warn');

% Verify a specific warning
testCase.verifyWarning(@() d.showInfo(), 'FastSense:someWarning');
```

**Conditional skip for MEX-dependent tests:**
```matlab
testCase.assumeTrue(exist('binary_search_mex', 'file') == 3, 'MEX not compiled');
% Test is skipped (marked Incomplete) if MEX absent — does not fail CI
```

**Numeric tolerance for floating-point assertions:**
```matlab
testCase.verifyLessThan(abs(events(1).MeanValue - 12.5), 1e-10, 'stats: MeanValue');
expected_rms = sqrt(mean([12 14 11 13].^2));
testCase.verifyLessThan(abs(events(1).RmsValue - expected_rms), 1e-10, 'stats: RmsValue');
```

**Python array assertion:**
```python
np.testing.assert_array_equal(result, expected_values)
```

---

*Testing analysis: 2026-04-01*
