# Sensor/Threshold System — Design Document

## Overview

A new SensorThreshold library alongside FastPlot for defining sensors, state channels, and dynamic thresholds. Sensors precompute all threshold and violation data before plotting. FastPlot receives only pre-shaped arrays.

## Architecture: Compute First, Plot Second

```
define → load (external lib) → resolve (precompute) → plot (just wiring)
```

Two independent optimization paths:
- **Sensor pipeline** (`load` → `resolve`): vectorized ops, binary search alignment, bulk threshold evaluation, memory preallocation
- **Plot pipeline** (`addSensor` → `render`): existing FastPlot downsampling, pyramid cache, SIMD acceleration

`resolve()` once → plot N times across different tiles/figures without recomputation.

## Monorepo Structure

```
FastPlot/                          (repo root)
├── libs/
│   ├── FastPlot/                  (all current FastPlot files move here)
│   │   ├── FastPlot.m
│   │   ├── FastPlotFigure.m
│   │   ├── FastPlotDock.m
│   │   ├── FastPlotToolbar.m
│   │   ├── FastPlotTheme.m
│   │   ├── FastPlotDefaults.m
│   │   ├── ConsoleProgressBar.m
│   │   ├── private/
│   │   ├── vendor/
│   │   └── build_mex.m
│   └── SensorThreshold/           (new library)
│       ├── Sensor.m
│       ├── StateChannel.m
│       ├── ThresholdRule.m
│       ├── SensorRegistry.m
│       └── private/
│           └── alignStateToTime.m
├── setup.m                        (adds both libs to path)
├── tests/
├── examples/
├── docs/
└── README.md
```

`setup.m` adds both `libs/FastPlot` and `libs/SensorThreshold` to the MATLAB path.

## Classes

### Sensor

Primary object. Owns data, thresholds, and state channels.

```matlab
s = Sensor('pressure', ...
    'Name',       'Chamber Pressure', ...
    'ID',         101, ...
    'Source',      'raw_data/pressure_log.dta', ...
    'MatFile',    'data/pressure.mat', ...
    'KeyName',    'pressure_ch1');
```

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `Key` | char | Unique identifier (constructor arg 1) |
| `Name` | char | Human-readable display name |
| `ID` | numeric | Numeric sensor ID |
| `Source` | char | Path to original data file (.dta, .txt, etc.) |
| `MatFile` | char | Path to .mat file with transformed data |
| `KeyName` | char | Field name in the .mat file (defaults to `Key`) |
| `X` | array | Time data (datenum), loaded from .mat |
| `Y` | array | Sensor values (1xN or MxN) |
| `StateChannels` | StateChannel[] | Attached state channels |
| `ThresholdRules` | ThresholdRule[] | Dynamic threshold definitions |
| `ResolvedThresholds` | struct | Cached precomputed threshold time series |
| `ResolvedViolations` | struct | Cached precomputed violation points |
| `ResolvedStateBands` | struct | Cached precomputed state region bands |

**Methods:**

- `load()` — thin wrapper for external loading library. Does not implement loading logic itself.
- `addStateChannel(stateChannel)` — attach a StateChannel object
- `addThresholdRule(conditionFn, value, ...)` — add a dynamic threshold rule
- `resolve()` — precomputes everything:
  1. Aligns all state channels to sensor time axis (binary search, bulk vectorized)
  2. Builds stepped threshold time series for each rule
  3. Computes all violations against time-varying thresholds
  4. Caches results in `ResolvedThresholds`, `ResolvedViolations`, `ResolvedStateBands`
- `getThresholdsAt(t)` — evaluate rules at a single time point (for interactive use)

### StateChannel

Represents a discrete state signal from a separate .mat file.

```matlab
sc = StateChannel('machine_state', ...
    'MatFile', 'data/states.mat', ...
    'KeyName', 'machine_state');
sc.load();
```

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `Key` | char | Unique identifier |
| `MatFile` | char | Path to .mat file |
| `KeyName` | char | Field name in .mat (defaults to `Key`) |
| `X` | array | Timestamps (datenum) |
| `Y` | array/cell | State values (numeric, char, string, or cell array) |

**Methods:**

- `load()` — thin wrapper for external loading library
- `valueAt(t)` — returns state value at time t via zero-order hold (binary search, O(log n))

### ThresholdRule

Defines a condition-value pair for dynamic thresholds.

```matlab
rule = ThresholdRule(@(st) st.machine_state == 1 && st.temp_zone == 0, ...
    50, 'Direction', 'upper', 'Label', 'HH Alarm (evacuated+cold)');
```

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `ConditionFn` | function_handle | `@(st) ...` — st is a struct with current state values |
| `Value` | numeric | Threshold value when condition is true |
| `Direction` | char | `'upper'` or `'lower'` |
| `Label` | char | Display label |
| `Color` | array | RGB color (optional, defaults from theme) |
| `LineStyle` | char | Line style (optional) |

Conditions are full MATLAB expressions. The struct `st` contains fields named after each attached StateChannel's Key, with the current value at that time point.

### SensorRegistry

Single .m file catalog of predefined sensors. Persistent cache for fast repeated lookups.

```matlab
s = SensorRegistry.get('pressure');
sensors = SensorRegistry.getMultiple({'pressure', 'temperature'});
SensorRegistry.list();  % prints available sensors
```

**Implementation:**

```matlab
classdef SensorRegistry
    methods (Static)
        function s = get(key)
            all = SensorRegistry.catalog();
            s = all(key);
        end

        function sensors = getMultiple(keys)
            sensors = cellfun(@SensorRegistry.get, keys, 'Uni', false);
        end

        function list()
            all = SensorRegistry.catalog();
            keys = all.keys();
            for i = 1:numel(keys)
                s = all(keys{i});
                fprintf('  %-20s  %s\n', keys{i}, s.Name);
            end
        end
    end

    methods (Static, Access = private)
        function map = catalog()
            persistent cache;
            if isempty(cache)
                cache = containers.Map();

                s = Sensor('pressure', 'Name', 'Chamber Pressure', ...
                    'ID', 101, 'MatFile', 'data/pressure.mat');
                s.addThresholdRule(@(st) st.machine_state == 1, 50, ...
                    'Direction', 'upper', 'Label', 'HH Alarm');
                cache('pressure') = s;

                % ... more sensor definitions ...
            end
            map = cache;
        end
    end
end
```

## Time Alignment

### alignStateToTime.m (private helper)

Aligns state channel values to sensor timestamps using zero-order hold (last known value).

- Uses binary search for O(log n) per query, or vectorized bulk alignment
- Can reuse FastPlot's existing `binary_search` implementation
- State values can be numeric, char, string, or cell — alignment handles all types

### Threshold Resolution in resolve()

1. Collect all state-change timestamps from all state channels
2. Merge with sensor timestamps into sorted unique time grid
3. At each time point, build state struct with all current state values
4. Evaluate each ThresholdRule.ConditionFn(st) — first matching rule wins (priority order)
5. Output: stepped [tX, tY] arrays per threshold direction
6. Cache the result — invalidate only if state data changes

### Violation Detection

For time-varying thresholds, split sensor data at threshold step boundaries, run violation detection per segment, concatenate results. Leverages existing `compute_violations.m` logic.

## FastPlot Integration

### addSensor() method

New public method on FastPlot (~50-80 lines). Purely wires precomputed data:

```matlab
fp = FastPlot();
s = SensorRegistry.get('pressure');
s.load();
s.resolve();

fp.addSensor(s, 'ShowThresholds', true, 'ShowStateShading', true);
fp.render();
```

**addSensor() internally:**
1. `addLine(s.X, s.Y, 'DisplayName', s.Name)` — sensor data line
2. If `ShowThresholds`: adds precomputed stepped threshold lines + violation markers
3. If `ShowStateShading`: adds precomputed state bands via `addBand()`

### FastPlotFigure / FastPlotDock

No changes needed. They work with FastPlot tiles:

```matlab
fig = FastPlotFigure([2, 1]);
fig.tile(1).addSensor(SensorRegistry.get('pressure'));
fig.tile(2).addSensor(SensorRegistry.get('temperature'));
fig.renderAll();
```

### Visualization

- **Stepped threshold lines**: threshold value changes over time as states change (staircase line)
- **State shading**: optional background bands showing active state regions
- **Violation markers**: points where sensor data exceeds the time-varying threshold

## Performance Constraints

- **Sensor loading must be very fast** — `load()` is a thin wrapper, actual loading delegated to optimized external library
- **`resolve()` is the compute bottleneck** — must be vectorized, use binary search for alignment, preallocate memory, cache results
- **`addSensor()` does zero computation** — just passes precomputed arrays to FastPlot
- **Separate optimization paths**: sensor pipeline and plot pipeline are independently profilable and optimizable
- **`resolve()` once, plot many**: precomputed data reusable across multiple plots/tiles/figures
