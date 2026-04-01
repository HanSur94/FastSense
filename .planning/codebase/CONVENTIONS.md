# Coding Conventions

**Analysis Date:** 2026-04-01

## Naming Patterns

**Files:**
- Classes: PascalCase matching the class name exactly — `FastSense.m`, `DashboardBuilder.m`, `EventDetector.m`
- Functions: camelCase or lowercase — `parseOpts.m`, `compute_violations.m`, `groupViolations.m`
- Test files (suite): `Test` prefix + PascalCase — `TestSensor.m`, `TestEventDetector.m`
- Test files (Octave function-based): `test_` prefix + snake_case — `test_sensor.m`, `test_add_sensor.m`
- Private helpers: placed in `private/` subdirectory of owning library

**Classes:**
- PascalCase with regex `[A-Z][a-zA-Z0-9]+` (enforced by MISS_HIT)
- Handle classes inherit from `handle`: `classdef FastSense < handle`
- Abstract base classes used for interfaces: `DataSource` (abstract), subclassed by `MockDataSource`, `MatFileDataSource`

**Methods:**
- Public API: camelCase — `addSensor()`, `addThreshold()`, `addLine()`, `render()`
- Private helpers: camelCase — `rngRand()`, `rngRandn()`, `generateBacklog()`
- Lifecycle: `TestClassSetup` method always named `addPaths`
- Test methods: camelCase starting with verb — `testConstructorDefaults`, `testAddSensorBasic`

**Properties:**
- Public properties: PascalCase — `Key`, `Name`, `Lines`, `Thresholds`, `IsRendered`
- Private implementation properties: trailing underscore sometimes used for internal state — `rng_`, `lastTime_`, `backlogDone_`
- Inline default values on property declaration — `Verbose = false`, `LiveInterval = 2.0`

**Error Identifiers:**
- Pattern: `ClassName:camelCaseProblem` — e.g., `FastSense:alreadyRendered`, `Sensor:unknownOption`, `EventDetector:unknownOption`

**Variables:**
- Local variables: camelCase — `nPts`, `startTime`, `endTime`, `thresholdLabel`
- Loop indices: single letters `i`, `j`, `k`
- Count variables: `n` prefix — `nPts`, `nPassed`, `nFailed`
- Boolean flags: `Is` prefix for properties — `IsRendered`, `IsActive`, `IsServing`

## Code Style

**Formatting:**
- Tool: MISS_HIT (`mh_style`, `mh_lint`, `mh_metric`)
- Config: `miss_hit.cfg` at repo root
- Line length: 160 characters maximum
- Tab width: 4 spaces
- Many style rules currently suppressed to accommodate existing code (see `suppress_rule` entries in `miss_hit.cfg`)

**Linting:**
- Tool: MISS_HIT `mh_lint` and `mh_metric --ci`
- Cyclomatic complexity limit: 80 (aspirational target: 20)
- Max function length: 520 lines (aspirational target: 200)
- Max nesting depth: 5
- Max parameters: 12 (aspirational target: 8)

## Import Organization

**Path Setup:**
- Tests call `install()` to add all library paths
- Each test file includes a local `add_sensor_path()` or similar helper function
- Suite tests use `TestClassSetup` with `addPaths` to call `addpath` + `install()`

**Module Loading:**
- No import statements for MATLAB code (functions are on path)
- Python bridge uses standard module imports with explicit relative imports within the package

## Error Handling

**MATLAB Pattern — structured error IDs:**
```matlab
error('ClassName:problemName', 'Human-readable message: %s', detail);
% Example:
error('Sensor:unknownOption', 'Unknown option ''%s''.', varargin{i});
error('FastSense:alreadyRendered', 'Cannot add lines after render().');
error('FastSense:sizeMismatch', 'X and Y must have the same length.');
```

**Defensive validation at method entry:**
```matlab
% Validate before operation
if obj.IsRendered
    error('FastSense:alreadyRendered', ...
        'Cannot add lines after render().');
end
if numel(x) ~= numel(y)
    error('FastSense:sizeMismatch', 'X and Y must have the same length.');
end
```

**Unknown option pattern:**
```matlab
otherwise
    error('ClassName:unknownOption', 'Unknown option ''%s''.', varargin{i});
```

**Verbose/diagnostic logging (not errors):**
```matlab
if obj.Verbose
    fprintf('[FastSense] addLine: %d pts -> pre-built DataStore\n', nPts);
end
```

**Python bridge — standard HTTP error pattern:**
```python
raise HTTPException(status_code=404, detail="Signal not found")
```

## Logging

**Framework:** `fprintf` to stdout (no external logging library)

**Patterns:**
- Verbose diagnostics guarded by `obj.Verbose` flag (default `false`)
- Prefix format: `[ClassName]` — e.g., `[FastSense] render: line 1: 1000 pts -> 200 displayed`
- Test progress: `fprintf('    All N tests passed.\n')` in Octave-style function tests
- Suite progress: printed automatically by `TestRunner.withTextOutput`

## Comments

**When to Comment:**
- All public classes: comprehensive header comment with description, usage examples, property list, method list, and See also
- All public methods: `%METHODNAME Description.` header followed by input/output documentation
- Private helpers: brief `%FUNCTIONNAME Purpose.` header
- Inline logic: short comments explaining non-obvious decisions (especially NaN handling, IEEE 754 guarantees, performance choices)

**MATLAB docstring format:**
```matlab
function result = myFunction(x, y, opts)
%MYFUNCTION Short description.
%   result = MYFUNCTION(x, y) longer description.
%
%   Inputs:
%     x    — description
%     y    — description
%
%   Outputs:
%     result — description
%
%   See also OtherClass, helperFunction.
```

## Function Design

**Size:** MISS_HIT enforces max 520 lines per function (aspirational 200). `FastSense.m` itself is 3297 lines split across many methods.

**Parameters:** Max 12 enforced; prefer name-value pairs for optional arguments.

**Name-value option parsing:** Two patterns in use:
1. `switch/case` loop over `varargin` (used in `Sensor`, `EventDetector`, simple constructors):
```matlab
for i = 1:2:numel(varargin)
    switch varargin{i}
        case 'Name',  obj.Name = varargin{i+1};
        otherwise
            error('ClassName:unknownOption', 'Unknown option ''%s''.', varargin{i});
    end
end
```
2. `inputParser` (used in `MockDataSource`, `NotificationService`, `IncrementalEventDetector`):
```matlab
p = inputParser();
p.addParameter('BaseValue', 100);
p.parse(varargin{:});
```
3. `parseOpts` (private helper used internally by `FastSense`):
```matlab
[opts, unmatched] = parseOpts(defaults, args);
```

**Return Values:** MATLAB multi-output convention: `[out1, out2] = func(...)`. Empty returns use `[]` or `{}`.

## Module Design

**Exports:** All public `.m` files in `libs/<LibName>/` are directly on path after `install()`. No explicit export list.

**Private helpers:** Placed in `libs/<LibName>/private/` — only accessible to code in the parent directory. Examples: `compute_violations.m`, `parseOpts.m`, `groupViolations.m`, `mergeTheme.m`.

**Barrel Files:** None. Path management handled entirely by `install.m`.

**Access control on class members:**
- `properties (Access = public)` — user-configurable settings
- `properties (SetAccess = private)` — internal data readable but not writable externally
- `properties (Access = private)` — fully internal state
- `methods (Access = public)` — public API
- `methods (Access = private)` — internal helpers

---

*Convention analysis: 2026-04-01*
