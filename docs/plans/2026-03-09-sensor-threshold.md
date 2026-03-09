# Sensor/Threshold System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a SensorThreshold library with Sensor, StateChannel, ThresholdRule, and SensorRegistry classes, integrate with FastPlot via `addSensor()`, and restructure the repo into a monorepo with `libs/`.

**Architecture:** Compute-first, plot-second. Sensors own their data, state channels, and threshold rules. `resolve()` precomputes all threshold time series and violations. `addSensor()` on FastPlot just wires precomputed arrays into existing `addLine`/`addBand` methods. Two independently optimizable pipelines.

**Tech Stack:** MATLAB classdef (handle classes), `containers.Map`, binary search for time alignment, zero-order hold for state interpolation.

---

### Task 1: Restructure Repo into Monorepo

**Files:**
- Create: `libs/FastPlot/` (move all FastPlot files here)
- Create: `libs/SensorThreshold/` (empty dir for now)
- Create: `libs/SensorThreshold/private/` (empty dir for now)
- Create: `setup.m` (path setup script)
- Modify: `tests/run_all_tests.m` (update paths)

**Step 1: Create `libs/` directory structure**

```bash
mkdir -p libs/FastPlot libs/SensorThreshold/private
```

**Step 2: Move all FastPlot files into `libs/FastPlot/`**

Move these files:
- `FastPlot.m` → `libs/FastPlot/FastPlot.m`
- `FastPlotFigure.m` → `libs/FastPlot/FastPlotFigure.m`
- `FastPlotDock.m` → `libs/FastPlot/FastPlotDock.m`
- `FastPlotToolbar.m` → `libs/FastPlot/FastPlotToolbar.m`
- `FastPlotTheme.m` → `libs/FastPlot/FastPlotTheme.m`
- `FastPlotDefaults.m` → `libs/FastPlot/FastPlotDefaults.m`
- `ConsoleProgressBar.m` → `libs/FastPlot/ConsoleProgressBar.m`
- `build_mex.m` → `libs/FastPlot/build_mex.m`
- `private/` → `libs/FastPlot/private/` (entire directory)
- `vendor/` → `libs/FastPlot/vendor/` (entire directory)

```bash
git mv FastPlot.m libs/FastPlot/
git mv FastPlotFigure.m libs/FastPlot/
git mv FastPlotDock.m libs/FastPlot/
git mv FastPlotToolbar.m libs/FastPlot/
git mv FastPlotTheme.m libs/FastPlot/
git mv FastPlotDefaults.m libs/FastPlot/
git mv ConsoleProgressBar.m libs/FastPlot/
git mv build_mex.m libs/FastPlot/
git mv private libs/FastPlot/
git mv vendor libs/FastPlot/
```

**Step 3: Create `setup.m`**

```matlab
function setup()
%SETUP Add FastPlot and SensorThreshold libraries to the MATLAB path.
%   Run this once per session to make all library classes available.

    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'libs', 'FastPlot'));
    addpath(fullfile(root, 'libs', 'SensorThreshold'));
    fprintf('FastPlot + SensorThreshold libraries added to path.\n');
end
```

**Step 4: Update `tests/run_all_tests.m`**

Add a call to the repo-root `setup.m` at the top of `run_all_tests` so tests can find the moved classes. Add this after line 4:

```matlab
    % Ensure libs are on path
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
```

**Step 5: Update all example files**

Every example that calls `addpath` pointing to the repo root needs updating. Search for `addpath` in `examples/*.m` and replace with a call to `setup.m` or update the path to `libs/FastPlot`.

**Step 6: Verify nothing is broken**

```bash
cd /Users/hannessuhr/FastPlot && matlab -batch "setup; run_all_tests"
```

Expected: All existing tests pass.

**Step 7: Commit**

```bash
git add -A
git commit -m "refactor: restructure repo into monorepo with libs/ directory"
```

---

### Task 2: ThresholdRule Class

**Files:**
- Create: `libs/SensorThreshold/ThresholdRule.m`
- Create: `tests/test_threshold_rule.m`

**Step 1: Write the failing test**

Create `tests/test_threshold_rule.m`:

```matlab
function test_threshold_rule()
%TEST_THRESHOLD_RULE Tests for ThresholdRule class.

    add_sensor_path();

    % testConstructorDefaults
    rule = ThresholdRule(@(st) st.x == 1, 50);
    assert(rule.Value == 50, 'testConstructorDefaults: Value');
    assert(strcmp(rule.Direction, 'upper'), 'testConstructorDefaults: Direction default');
    assert(isempty(rule.Label), 'testConstructorDefaults: Label default');
    assert(isempty(rule.Color), 'testConstructorDefaults: Color default');
    assert(strcmp(rule.LineStyle, '--'), 'testConstructorDefaults: LineStyle default');

    % testConstructorWithOptions
    rule = ThresholdRule(@(st) st.x > 2, 100, ...
        'Direction', 'lower', 'Label', 'Low Alarm', ...
        'Color', [1 0 0], 'LineStyle', ':');
    assert(rule.Value == 100, 'testConstructorWithOptions: Value');
    assert(strcmp(rule.Direction, 'lower'), 'testConstructorWithOptions: Direction');
    assert(strcmp(rule.Label, 'Low Alarm'), 'testConstructorWithOptions: Label');
    assert(isequal(rule.Color, [1 0 0]), 'testConstructorWithOptions: Color');
    assert(strcmp(rule.LineStyle, ':'), 'testConstructorWithOptions: LineStyle');

    % testConditionEvaluation
    rule = ThresholdRule(@(st) st.machine == 1 && st.zone == 0, 50);
    st.machine = 1; st.zone = 0;
    assert(rule.ConditionFn(st) == true, 'testConditionEval: true case');
    st.machine = 2; st.zone = 0;
    assert(rule.ConditionFn(st) == false, 'testConditionEval: false case');

    % testInvalidDirection
    threw = false;
    try
        ThresholdRule(@(st) true, 50, 'Direction', 'sideways');
    catch
        threw = true;
    end
    assert(threw, 'testInvalidDirection: should throw');

    fprintf('    All 4 threshold_rule tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end
```

**Step 2: Run test to verify it fails**

```bash
matlab -batch "cd tests; test_threshold_rule"
```

Expected: FAIL — `ThresholdRule` class not found.

**Step 3: Implement ThresholdRule**

Create `libs/SensorThreshold/ThresholdRule.m`:

```matlab
classdef ThresholdRule
    %THRESHOLDRULE Defines a condition-value pair for dynamic thresholds.
    %   rule = ThresholdRule(@(st) st.machine == 1, 50)
    %   rule = ThresholdRule(@(st) st.machine == 1, 50, 'Direction', 'upper')
    %
    %   The condition function receives a struct with state channel values
    %   and returns true/false. When true, the threshold Value applies.

    properties
        ConditionFn   % function_handle: @(st) logical expression
        Value         % numeric: threshold value when condition is true
        Direction     % char: 'upper' or 'lower'
        Label         % char: display label
        Color         % 1x3 double: RGB color (empty = use theme default)
        LineStyle     % char: line style
    end

    methods
        function obj = ThresholdRule(conditionFn, value, varargin)
            obj.ConditionFn = conditionFn;
            obj.Value = value;

            % Defaults
            obj.Direction = 'upper';
            obj.Label = '';
            obj.Color = [];
            obj.LineStyle = '--';

            % Parse name-value pairs
            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Direction'
                        d = varargin{i+1};
                        if ~ismember(d, {'upper', 'lower'})
                            error('ThresholdRule:invalidDirection', ...
                                'Direction must be ''upper'' or ''lower'', got ''%s''.', d);
                        end
                        obj.Direction = d;
                    case 'Label'
                        obj.Label = varargin{i+1};
                    case 'Color'
                        obj.Color = varargin{i+1};
                    case 'LineStyle'
                        obj.LineStyle = varargin{i+1};
                    otherwise
                        error('ThresholdRule:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end
    end
end
```

**Step 4: Run test to verify it passes**

```bash
matlab -batch "cd tests; test_threshold_rule"
```

Expected: All 4 tests pass.

**Step 5: Commit**

```bash
git add libs/SensorThreshold/ThresholdRule.m tests/test_threshold_rule.m
git commit -m "feat: add ThresholdRule class for dynamic threshold conditions"
```

---

### Task 3: StateChannel Class

**Files:**
- Create: `libs/SensorThreshold/StateChannel.m`
- Create: `tests/test_state_channel.m`

**Step 1: Write the failing test**

Create `tests/test_state_channel.m`:

```matlab
function test_state_channel()
%TEST_STATE_CHANNEL Tests for StateChannel class.

    add_sensor_path();

    % testConstructorDefaults
    sc = StateChannel('machine_state', 'MatFile', 'data/states.mat');
    assert(strcmp(sc.Key, 'machine_state'), 'testConstructor: Key');
    assert(strcmp(sc.MatFile, 'data/states.mat'), 'testConstructor: MatFile');
    assert(strcmp(sc.KeyName, 'machine_state'), 'testConstructor: KeyName defaults to Key');

    % testConstructorCustomKeyName
    sc = StateChannel('ms', 'MatFile', 'data/states.mat', 'KeyName', 'machine_state');
    assert(strcmp(sc.Key, 'ms'), 'testCustomKeyName: Key');
    assert(strcmp(sc.KeyName, 'machine_state'), 'testCustomKeyName: KeyName');

    % testValueAtNumeric — zero-order hold with numeric states
    sc = StateChannel('state');
    sc.X = [1 5 10 20];
    sc.Y = [0 1 2 3];
    assert(sc.valueAt(0) == 0, 'testValueAt: before first -> first value');
    assert(sc.valueAt(1) == 0, 'testValueAt: at first timestamp');
    assert(sc.valueAt(3) == 0, 'testValueAt: between 1 and 5');
    assert(sc.valueAt(5) == 1, 'testValueAt: at second timestamp');
    assert(sc.valueAt(7) == 1, 'testValueAt: between 5 and 10');
    assert(sc.valueAt(15) == 2, 'testValueAt: between 10 and 20');
    assert(sc.valueAt(100) == 3, 'testValueAt: after last');

    % testValueAtString — zero-order hold with cell string states
    sc = StateChannel('mode');
    sc.X = [1 5 10];
    sc.Y = {'off', 'running', 'evacuated'};
    assert(strcmp(sc.valueAt(3), 'off'), 'testValueAtString: before change');
    assert(strcmp(sc.valueAt(7), 'running'), 'testValueAtString: after change');
    assert(strcmp(sc.valueAt(15), 'evacuated'), 'testValueAtString: last');

    % testValueAtBulk — vectorized lookup
    sc = StateChannel('state');
    sc.X = [1 5 10];
    sc.Y = [0 1 2];
    vals = sc.valueAt([0 3 5 7 15]);
    assert(isequal(vals, [0 0 1 1 2]), 'testValueAtBulk');

    fprintf('    All 5 state_channel tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end
```

**Step 2: Run test to verify it fails**

```bash
matlab -batch "cd tests; test_state_channel"
```

Expected: FAIL — `StateChannel` class not found.

**Step 3: Implement StateChannel**

Create `libs/SensorThreshold/StateChannel.m`:

```matlab
classdef StateChannel < handle
    %STATECHANNEL Discrete state signal with zero-order hold lookup.
    %   sc = StateChannel('machine_state', 'MatFile', 'data/states.mat')
    %   sc.load();
    %   val = sc.valueAt(datenum_time);

    properties
        Key       % char: unique identifier
        MatFile   % char: path to .mat file
        KeyName   % char: field name in .mat (defaults to Key)
        X         % 1xN datenum timestamps
        Y         % 1xN numeric, or 1xN cell of char/string
    end

    methods
        function obj = StateChannel(key, varargin)
            obj.Key = key;
            obj.KeyName = key;
            obj.MatFile = '';
            obj.X = [];
            obj.Y = [];

            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'MatFile'
                        obj.MatFile = varargin{i+1};
                    case 'KeyName'
                        obj.KeyName = varargin{i+1};
                    otherwise
                        error('StateChannel:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end

        function load(obj)
            %LOAD Thin wrapper — delegates to external loading library.
            %   Override or extend this method to use your data loading system.
            error('StateChannel:notImplemented', ...
                'load() is a wrapper for an external loading library. Set X and Y directly or implement your loader.');
        end

        function val = valueAt(obj, t)
            %VALUEAT Return state value at time t using zero-order hold.
            %   val = sc.valueAt(5.0)       — single scalar query
            %   vals = sc.valueAt([1 2 3])  — vectorized bulk query
            %
            %   Returns the last known value at or before time t.
            %   If t is before the first timestamp, returns the first value.

            if isscalar(t)
                % Single lookup — binary search
                idx = obj.bsearchRight(t);
                if iscell(obj.Y)
                    val = obj.Y{idx};
                else
                    val = obj.Y(idx);
                end
            else
                % Bulk lookup — vectorized
                n = numel(t);
                if iscell(obj.Y)
                    val = cell(1, n);
                    for k = 1:n
                        idx = obj.bsearchRight(t(k));
                        val{k} = obj.Y{idx};
                    end
                else
                    val = zeros(1, n);
                    for k = 1:n
                        idx = obj.bsearchRight(t(k));
                        val(k) = obj.Y(idx);
                    end
                end
            end
        end
    end

    methods (Access = private)
        function idx = bsearchRight(obj, val)
            %BSEARCHRIGHT Last index where X(idx) <= val, clamped to [1, N].
            x = obj.X;
            n = numel(x);
            if val < x(1)
                idx = 1;
                return;
            end
            lo = 1; hi = n; idx = 1;
            while lo <= hi
                mid = floor((lo + hi) / 2);
                if x(mid) <= val
                    idx = mid;
                    lo = mid + 1;
                else
                    hi = mid - 1;
                end
            end
        end
    end
end
```

**Step 4: Run test to verify it passes**

```bash
matlab -batch "cd tests; test_state_channel"
```

Expected: All 5 tests pass.

**Step 5: Commit**

```bash
git add libs/SensorThreshold/StateChannel.m tests/test_state_channel.m
git commit -m "feat: add StateChannel class with zero-order hold lookup"
```

---

### Task 4: `alignStateToTime` Private Helper

**Files:**
- Create: `libs/SensorThreshold/private/alignStateToTime.m`
- Create: `tests/test_align_state.m`

**Step 1: Write the failing test**

Create `tests/test_align_state.m`:

```matlab
function test_align_state()
%TEST_ALIGN_STATE Tests for alignStateToTime helper.

    add_sensor_path();
    add_private_path();

    % testNumericAlignment
    stateX = [1 5 10 20];
    stateY = [0 1 2 3];
    sensorX = [0 2 5 7 10 15 25];
    result = alignStateToTime(stateX, stateY, sensorX);
    assert(isequal(result, [0 0 1 1 2 2 3]), 'testNumericAlignment');

    % testCellStringAlignment
    stateX = [1 5 10];
    stateY = {'off', 'running', 'idle'};
    sensorX = [0 3 5 8 12];
    result = alignStateToTime(stateX, stateY, sensorX);
    assert(isequal(result, {'off', 'off', 'running', 'running', 'idle'}), 'testCellStringAlignment');

    % testSingleStateValue
    stateX = [5];
    stateY = [1];
    sensorX = [1 3 5 7 9];
    result = alignStateToTime(stateX, stateY, sensorX);
    assert(isequal(result, [1 1 1 1 1]), 'testSingleStateValue');

    % testExactTimestampMatch
    stateX = [1 2 3];
    stateY = [10 20 30];
    sensorX = [1 2 3];
    result = alignStateToTime(stateX, stateY, sensorX);
    assert(isequal(result, [10 20 30]), 'testExactTimestampMatch');

    fprintf('    All 4 align_state tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end

function add_private_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(fullfile(repo_root, 'libs', 'SensorThreshold', 'private'));
end
```

**Step 2: Run test to verify it fails**

```bash
matlab -batch "cd tests; test_align_state"
```

Expected: FAIL — `alignStateToTime` not found.

**Step 3: Implement `alignStateToTime`**

Create `libs/SensorThreshold/private/alignStateToTime.m`:

```matlab
function aligned = alignStateToTime(stateX, stateY, sensorX)
%ALIGNSTATETOTIME Align state values to sensor timestamps via zero-order hold.
%   aligned = alignStateToTime(stateX, stateY, sensorX)
%
%   For each timestamp in sensorX, returns the last known state value
%   from stateY (zero-order hold / nearest-previous). If sensorX timestamp
%   is before the first stateX, returns the first state value.
%
%   Inputs:
%     stateX  — 1xM sorted timestamps of state changes
%     stateY  — 1xM state values (numeric array or cell array of char/string)
%     sensorX — 1xN sorted sensor timestamps to align to
%
%   Output:
%     aligned — 1xN aligned state values (same type as stateY)

    n = numel(sensorX);
    isCellY = iscell(stateY);

    if isCellY
        aligned = cell(1, n);
    else
        aligned = zeros(1, n);
    end

    % Vectorized: use histc/discretize-style binning for bulk alignment
    % For each sensorX value, find the last stateX <= sensorX
    % This is equivalent to a right binary search for each element
    m = numel(stateX);

    % Use interp1 with 'previous' for numeric, manual for cell
    if ~isCellY && m > 1
        % Fast vectorized path for numeric states
        % interp1 'previous' does exactly zero-order hold
        aligned = interp1(stateX, stateY, sensorX, 'previous', 'extrap');
        % interp1 extrap with 'previous' returns NaN for values before first
        % Fix: set those to the first state value
        beforeFirst = sensorX < stateX(1);
        aligned(beforeFirst) = stateY(1);
    elseif ~isCellY && m == 1
        aligned(:) = stateY(1);
    else
        % Cell path — loop with binary search
        for k = 1:n
            t = sensorX(k);
            if t < stateX(1)
                idx = 1;
            else
                lo = 1; hi = m; idx = 1;
                while lo <= hi
                    mid = floor((lo + hi) / 2);
                    if stateX(mid) <= t
                        idx = mid;
                        lo = mid + 1;
                    else
                        hi = mid - 1;
                    end
                end
            end
            aligned{k} = stateY{idx};
        end
    end
end
```

**Step 4: Run test to verify it passes**

```bash
matlab -batch "cd tests; test_align_state"
```

Expected: All 4 tests pass.

**Step 5: Commit**

```bash
git add libs/SensorThreshold/private/alignStateToTime.m tests/test_align_state.m
git commit -m "feat: add alignStateToTime helper for zero-order hold alignment"
```

---

### Task 5: Sensor Class (Core)

**Files:**
- Create: `libs/SensorThreshold/Sensor.m`
- Create: `tests/test_sensor.m`

**Step 1: Write the failing test**

Create `tests/test_sensor.m`:

```matlab
function test_sensor()
%TEST_SENSOR Tests for Sensor class.

    add_sensor_path();

    % testConstructorDefaults
    s = Sensor('pressure');
    assert(strcmp(s.Key, 'pressure'), 'testConstructor: Key');
    assert(strcmp(s.KeyName, 'pressure'), 'testConstructor: KeyName defaults to Key');
    assert(isempty(s.Name), 'testConstructor: Name default');
    assert(isempty(s.ID), 'testConstructor: ID default');
    assert(isempty(s.X), 'testConstructor: X default');
    assert(isempty(s.Y), 'testConstructor: Y default');

    % testConstructorWithOptions
    s = Sensor('pressure', 'Name', 'Chamber Pressure', 'ID', 101, ...
        'MatFile', 'data.mat', 'KeyName', 'press_ch1', ...
        'Source', 'raw/pressure.dta');
    assert(strcmp(s.Name, 'Chamber Pressure'), 'testOptions: Name');
    assert(s.ID == 101, 'testOptions: ID');
    assert(strcmp(s.MatFile, 'data.mat'), 'testOptions: MatFile');
    assert(strcmp(s.KeyName, 'press_ch1'), 'testOptions: KeyName');
    assert(strcmp(s.Source, 'raw/pressure.dta'), 'testOptions: Source');

    % testAddStateChannel
    s = Sensor('pressure');
    sc = StateChannel('machine_state');
    sc.X = [1 5 10]; sc.Y = [0 1 2];
    s.addStateChannel(sc);
    assert(numel(s.StateChannels) == 1, 'testAddStateChannel: count');
    assert(strcmp(s.StateChannels{1}.Key, 'machine_state'), 'testAddStateChannel: key');

    % testAddThresholdRule
    s = Sensor('pressure');
    s.addThresholdRule(@(st) st.machine == 1, 50, 'Direction', 'upper', 'Label', 'HH');
    assert(numel(s.ThresholdRules) == 1, 'testAddThresholdRule: count');
    assert(s.ThresholdRules{1}.Value == 50, 'testAddThresholdRule: value');
    assert(strcmp(s.ThresholdRules{1}.Label, 'HH'), 'testAddThresholdRule: label');

    % testAddMultipleRules
    s = Sensor('pressure');
    s.addThresholdRule(@(st) st.m == 1, 50, 'Direction', 'upper');
    s.addThresholdRule(@(st) st.m == 2, 80, 'Direction', 'upper');
    s.addThresholdRule(@(st) st.m == 1, 10, 'Direction', 'lower');
    assert(numel(s.ThresholdRules) == 3, 'testMultipleRules: count');

    fprintf('    All 5 sensor tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end
```

**Step 2: Run test to verify it fails**

```bash
matlab -batch "cd tests; test_sensor"
```

Expected: FAIL — `Sensor` class not found.

**Step 3: Implement Sensor (without `resolve()` yet)**

Create `libs/SensorThreshold/Sensor.m`:

```matlab
classdef Sensor < handle
    %SENSOR Represents a sensor with data, state channels, and threshold rules.
    %   s = Sensor('pressure', 'Name', 'Chamber Pressure', 'MatFile', 'data.mat')
    %   s.addStateChannel(stateChannel);
    %   s.addThresholdRule(@(st) st.machine == 1, 50, 'Direction', 'upper');
    %   s.load();
    %   s.resolve();

    properties
        Key           % char: unique identifier
        Name          % char: human-readable display name
        ID            % numeric: sensor ID
        Source        % char: path to original data file
        MatFile       % char: path to .mat file with transformed data
        KeyName       % char: field name in .mat file (defaults to Key)
        X             % array: time data (datenum)
        Y             % array: sensor values (1xN or MxN)
        StateChannels % cell array of StateChannel objects
        ThresholdRules % cell array of ThresholdRule objects
        ResolvedThresholds  % struct: precomputed threshold time series
        ResolvedViolations  % struct: precomputed violation points
        ResolvedStateBands  % struct: precomputed state region bands
    end

    methods
        function obj = Sensor(key, varargin)
            obj.Key = key;
            obj.KeyName = key;
            obj.Name = '';
            obj.ID = [];
            obj.Source = '';
            obj.MatFile = '';
            obj.X = [];
            obj.Y = [];
            obj.StateChannels = {};
            obj.ThresholdRules = {};
            obj.ResolvedThresholds = struct();
            obj.ResolvedViolations = struct();
            obj.ResolvedStateBands = struct();

            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Name',     obj.Name = varargin{i+1};
                    case 'ID',       obj.ID = varargin{i+1};
                    case 'Source',   obj.Source = varargin{i+1};
                    case 'MatFile',  obj.MatFile = varargin{i+1};
                    case 'KeyName',  obj.KeyName = varargin{i+1};
                    otherwise
                        error('Sensor:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end

        function load(obj)
            %LOAD Thin wrapper — delegates to external loading library.
            error('Sensor:notImplemented', ...
                'load() is a wrapper for an external loading library. Set X and Y directly or implement your loader.');
        end

        function addStateChannel(obj, sc)
            %ADDSTATECHANNEL Attach a StateChannel to this sensor.
            obj.StateChannels{end+1} = sc;
        end

        function addThresholdRule(obj, conditionFn, value, varargin)
            %ADDTHRESHOLDRULE Add a dynamic threshold rule.
            %   s.addThresholdRule(@(st) st.machine == 1, 50, 'Direction', 'upper')
            rule = ThresholdRule(conditionFn, value, varargin{:});
            obj.ThresholdRules{end+1} = rule;
        end
    end
end
```

**Step 4: Run test to verify it passes**

```bash
matlab -batch "cd tests; test_sensor"
```

Expected: All 5 tests pass.

**Step 5: Commit**

```bash
git add libs/SensorThreshold/Sensor.m tests/test_sensor.m
git commit -m "feat: add Sensor class with state channels and threshold rules"
```

---

### Task 6: Sensor `resolve()` Method

**Files:**
- Modify: `libs/SensorThreshold/Sensor.m` (add `resolve()` and `getThresholdsAt()`)
- Create: `tests/test_sensor_resolve.m`

**Step 1: Write the failing test**

Create `tests/test_sensor_resolve.m`:

```matlab
function test_sensor_resolve()
%TEST_SENSOR_RESOLVE Tests for Sensor.resolve() precomputation.

    add_sensor_path();

    % testResolveSingleRule — one state channel, one threshold rule
    s = Sensor('pressure');
    s.X = 1:20;
    s.Y = [5 5 5 5 15 15 15 15 5 5 5 5 15 15 15 15 5 5 5 5];

    sc = StateChannel('machine');
    sc.X = [1 10];
    sc.Y = [0 1];
    s.addStateChannel(sc);

    % Threshold of 10 only applies when machine == 1 (timestamps 10-20)
    s.addThresholdRule(@(st) st.machine == 1, 10, 'Direction', 'upper', 'Label', 'HH');

    s.resolve();

    % Should have one resolved threshold
    assert(numel(s.ResolvedThresholds) == 1, 'testSingleRule: count');
    th = s.ResolvedThresholds(1);
    assert(strcmp(th.Label, 'HH'), 'testSingleRule: label');
    assert(strcmp(th.Direction, 'upper'), 'testSingleRule: direction');
    % Threshold line should have steps: NaN for t<10, 10 for t>=10
    % Violations should only be at t=13,14,15,16 (where y=15 > 10 AND machine==1)
    viol = s.ResolvedViolations(1);
    assert(all(viol.X >= 10), 'testSingleRule: violations only in active region');
    assert(all(viol.Y > 10), 'testSingleRule: violation values exceed threshold');

    % testResolveMultipleRules — two states, two thresholds
    s = Sensor('temp');
    s.X = 1:20;
    s.Y = [30 30 30 30 60 60 60 60 30 30 30 30 60 60 60 60 30 30 30 30];

    sc = StateChannel('mode');
    sc.X = [1 11];
    sc.Y = [0 1];
    s.addStateChannel(sc);

    s.addThresholdRule(@(st) st.mode == 0, 50, 'Direction', 'upper', 'Label', 'Normal HH');
    s.addThresholdRule(@(st) st.mode == 1, 40, 'Direction', 'upper', 'Label', 'Strict HH');

    s.resolve();

    assert(numel(s.ResolvedThresholds) == 2, 'testMultipleRules: threshold count');

    % testResolveMultipleStateChannels
    s = Sensor('pressure');
    s.X = 1:20;
    s.Y = ones(1, 20) * 50;

    sc1 = StateChannel('machine');
    sc1.X = [1 10]; sc1.Y = [0 1];
    sc2 = StateChannel('zone');
    sc2.X = [1 5 15]; sc2.Y = [0 1 2];
    s.addStateChannel(sc1);
    s.addStateChannel(sc2);

    s.addThresholdRule(@(st) st.machine == 1 && st.zone == 1, 40, ...
        'Direction', 'upper', 'Label', 'Combo alarm');

    s.resolve();
    assert(numel(s.ResolvedThresholds) == 1, 'testMultiState: threshold count');

    % testResolveNoRules — should not error
    s = Sensor('pressure');
    s.X = 1:10;
    s.Y = ones(1, 10);
    s.resolve();
    assert(isempty(s.ResolvedThresholds), 'testNoRules: empty thresholds');
    assert(isempty(s.ResolvedViolations), 'testNoRules: empty violations');

    % testResolveNoStateChannels — rules with no state dependency
    s = Sensor('pressure');
    s.X = 1:10;
    s.Y = [1 2 3 4 5 6 7 8 9 10];
    s.addThresholdRule(@(st) true, 5, 'Direction', 'upper', 'Label', 'Static');
    s.resolve();
    assert(numel(s.ResolvedThresholds) == 1, 'testNoState: threshold count');
    viol = s.ResolvedViolations(1);
    assert(isequal(viol.X, [6 7 8 9 10]), 'testNoState: violation X');

    % testGetThresholdsAt
    s = Sensor('pressure');
    s.X = 1:20;
    s.Y = ones(1, 20);
    sc = StateChannel('machine');
    sc.X = [1 10]; sc.Y = [0 1];
    s.addStateChannel(sc);
    s.addThresholdRule(@(st) st.machine == 0, 50, 'Direction', 'upper');
    s.addThresholdRule(@(st) st.machine == 1, 80, 'Direction', 'upper');
    active = s.getThresholdsAt(5);
    assert(numel(active) == 1 && active(1).Value == 50, 'testGetThresholdsAt: state 0');
    active = s.getThresholdsAt(15);
    assert(numel(active) == 1 && active(1).Value == 80, 'testGetThresholdsAt: state 1');

    fprintf('    All 6 sensor_resolve tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end
```

**Step 2: Run test to verify it fails**

```bash
matlab -batch "cd tests; test_sensor_resolve"
```

Expected: FAIL — `resolve` method not found on Sensor.

**Step 3: Add `resolve()` and `getThresholdsAt()` to Sensor.m**

Add these methods to the `methods` block of `libs/SensorThreshold/Sensor.m`:

```matlab
        function resolve(obj)
            %RESOLVE Precompute threshold time series, violations, and state bands.
            %   Must be called after X, Y, and all StateChannels are loaded.

            nRules = numel(obj.ThresholdRules);

            if nRules == 0
                obj.ResolvedThresholds = [];
                obj.ResolvedViolations = [];
                obj.ResolvedStateBands = [];
                return;
            end

            sensorX = obj.X;
            sensorY = obj.Y;
            n = numel(sensorX);

            % Collect all state-change timestamps into a merged time grid
            allTimes = sensorX(:)';
            for i = 1:numel(obj.StateChannels)
                allTimes = [allTimes, obj.StateChannels{i}.X(:)'];
            end
            timeGrid = unique(allTimes);
            timeGrid = sort(timeGrid);

            % Align all state channels to the time grid
            stateValues = struct();
            for i = 1:numel(obj.StateChannels)
                sc = obj.StateChannels{i};
                stateValues.(sc.Key) = alignStateToTime(sc.X, sc.Y, timeGrid);
            end

            % Also align states to sensor timestamps for violation detection
            sensorStates = struct();
            for i = 1:numel(obj.StateChannels)
                sc = obj.StateChannels{i};
                sensorStates.(sc.Key) = alignStateToTime(sc.X, sc.Y, sensorX);
            end

            % Evaluate each rule across time grid → build stepped threshold line
            resolvedTh = [];
            resolvedViol = [];
            for r = 1:nRules
                rule = obj.ThresholdRules{r};

                % Build threshold time series on the merged time grid
                thY = NaN(1, numel(timeGrid));
                for k = 1:numel(timeGrid)
                    st = obj.buildStateStruct(stateValues, k);
                    if rule.ConditionFn(st)
                        thY(k) = rule.Value;
                    end
                end

                % Store resolved threshold
                th.X = timeGrid;
                th.Y = thY;
                th.Direction = rule.Direction;
                th.Label = rule.Label;
                th.Color = rule.Color;
                th.LineStyle = rule.LineStyle;
                th.Value = rule.Value;

                % Compute violations on sensor data
                % For each sensor point, check if the rule is active and violated
                vX = [];
                vY = [];
                for k = 1:n
                    st = obj.buildStateStruct(sensorStates, k);
                    if rule.ConditionFn(st)
                        if strcmp(rule.Direction, 'upper') && sensorY(k) > rule.Value
                            vX(end+1) = sensorX(k);
                            vY(end+1) = sensorY(k);
                        elseif strcmp(rule.Direction, 'lower') && sensorY(k) < rule.Value
                            vX(end+1) = sensorX(k);
                            vY(end+1) = sensorY(k);
                        end
                    end
                end

                viol.X = vX;
                viol.Y = vY;
                viol.Direction = rule.Direction;
                viol.Label = rule.Label;

                if isempty(resolvedTh)
                    resolvedTh = th;
                    resolvedViol = viol;
                else
                    resolvedTh(end+1) = th;
                    resolvedViol(end+1) = viol;
                end
            end

            obj.ResolvedThresholds = resolvedTh;
            obj.ResolvedViolations = resolvedViol;
            obj.ResolvedStateBands = struct(); % placeholder for state shading
        end

        function active = getThresholdsAt(obj, t)
            %GETTHRESHOLDSAT Evaluate all rules at a single time point.
            %   Returns struct array of active thresholds at time t.

            active = [];
            st = struct();
            for i = 1:numel(obj.StateChannels)
                sc = obj.StateChannels{i};
                st.(sc.Key) = sc.valueAt(t);
            end

            for r = 1:numel(obj.ThresholdRules)
                rule = obj.ThresholdRules{r};
                if rule.ConditionFn(st)
                    entry.Value = rule.Value;
                    entry.Direction = rule.Direction;
                    entry.Label = rule.Label;
                    if isempty(active)
                        active = entry;
                    else
                        active(end+1) = entry;
                    end
                end
            end
        end
```

Also add a private helper method:

```matlab
    methods (Access = private)
        function st = buildStateStruct(obj, alignedStates, idx)
            %BUILDSTATESTRUCT Build state struct for a single time index.
            st = struct();
            fields = fieldnames(alignedStates);
            for f = 1:numel(fields)
                vals = alignedStates.(fields{f});
                if iscell(vals)
                    st.(fields{f}) = vals{idx};
                else
                    st.(fields{f}) = vals(idx);
                end
            end
        end
    end
```

**Step 4: Run test to verify it passes**

```bash
matlab -batch "cd tests; test_sensor_resolve"
```

Expected: All 6 tests pass.

**Step 5: Commit**

```bash
git add libs/SensorThreshold/Sensor.m tests/test_sensor_resolve.m
git commit -m "feat: add Sensor.resolve() for precomputing thresholds and violations"
```

---

### Task 7: SensorRegistry Class

**Files:**
- Create: `libs/SensorThreshold/SensorRegistry.m`
- Create: `tests/test_sensor_registry.m`

**Step 1: Write the failing test**

Create `tests/test_sensor_registry.m`:

```matlab
function test_sensor_registry()
%TEST_SENSOR_REGISTRY Tests for SensorRegistry class.

    add_sensor_path();

    % testGetReturnsASensor
    s = SensorRegistry.get('pressure');
    assert(isa(s, 'Sensor'), 'testGet: returns Sensor');
    assert(strcmp(s.Key, 'pressure'), 'testGet: correct key');

    % testGetUnknownKeyThrows
    threw = false;
    try
        SensorRegistry.get('nonexistent_sensor_xyz');
    catch
        threw = true;
    end
    assert(threw, 'testGetUnknown: should throw');

    % testGetMultiple
    sensors = SensorRegistry.getMultiple({'pressure', 'temperature'});
    assert(numel(sensors) == 2, 'testGetMultiple: count');
    assert(isa(sensors{1}, 'Sensor'), 'testGetMultiple: type 1');
    assert(isa(sensors{2}, 'Sensor'), 'testGetMultiple: type 2');

    % testList — should not error
    SensorRegistry.list();

    fprintf('    All 4 sensor_registry tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end
```

**Step 2: Run test to verify it fails**

```bash
matlab -batch "cd tests; test_sensor_registry"
```

Expected: FAIL — `SensorRegistry` class not found.

**Step 3: Implement SensorRegistry**

Create `libs/SensorThreshold/SensorRegistry.m`:

```matlab
classdef SensorRegistry
    %SENSORREGISTRY Catalog of predefined sensor definitions.
    %   s = SensorRegistry.get('pressure')
    %   sensors = SensorRegistry.getMultiple({'pressure', 'temperature'})
    %   SensorRegistry.list()
    %
    %   All sensors are defined in the catalog() method below. Edit that
    %   method to add, remove, or modify sensor definitions. Definitions
    %   are cached in a persistent variable for fast repeated lookups.

    methods (Static)
        function s = get(key)
            %GET Retrieve a predefined sensor by key.
            map = SensorRegistry.catalog();
            if ~map.isKey(key)
                error('SensorRegistry:unknownKey', ...
                    'No sensor defined with key ''%s''. Use SensorRegistry.list() to see available sensors.', key);
            end
            s = map(key);
        end

        function sensors = getMultiple(keys)
            %GETMULTIPLE Retrieve multiple sensors by key.
            sensors = cell(1, numel(keys));
            for i = 1:numel(keys)
                sensors{i} = SensorRegistry.get(keys{i});
            end
        end

        function list()
            %LIST Print all available sensor keys and names.
            map = SensorRegistry.catalog();
            keys = sort(map.keys());
            fprintf('\n  Available sensors:\n');
            for i = 1:numel(keys)
                s = map(keys{i});
                name = s.Name;
                if isempty(name); name = '(no name)'; end
                fprintf('    %-25s  %s\n', keys{i}, name);
            end
            fprintf('\n');
        end
    end

    methods (Static, Access = private)
        function map = catalog()
            %CATALOG Define all sensors here. Cached via persistent variable.
            persistent cache;
            if isempty(cache)
                cache = containers.Map();

                % === Example sensor definitions ===
                % Edit this section to define your sensors.

                s = Sensor('pressure', 'Name', 'Chamber Pressure', 'ID', 101);
                cache('pressure') = s;

                s = Sensor('temperature', 'Name', 'Chamber Temperature', 'ID', 102);
                cache('temperature') = s;

                % Add more sensors below:
                % s = Sensor('flow', 'Name', 'Gas Flow Rate', 'ID', 103, ...
                %     'MatFile', 'data/flow.mat');
                % s.addThresholdRule(@(st) st.machine == 1, 100, ...
                %     'Direction', 'upper', 'Label', 'Flow HH');
                % cache('flow') = s;
            end
            map = cache;
        end
    end
end
```

**Step 4: Run test to verify it passes**

```bash
matlab -batch "cd tests; test_sensor_registry"
```

Expected: All 4 tests pass.

**Step 5: Commit**

```bash
git add libs/SensorThreshold/SensorRegistry.m tests/test_sensor_registry.m
git commit -m "feat: add SensorRegistry catalog for predefined sensor definitions"
```

---

### Task 8: FastPlot `addSensor()` Integration

**Files:**
- Modify: `libs/FastPlot/FastPlot.m` (add `addSensor()` method)
- Create: `tests/test_add_sensor.m`

**Step 1: Write the failing test**

Create `tests/test_add_sensor.m`:

```matlab
function test_add_sensor()
%TEST_ADD_SENSOR Tests for FastPlot.addSensor() integration.

    add_sensor_path();

    % testAddSensorBasic — adds a line from sensor data
    s = Sensor('pressure', 'Name', 'Chamber Pressure');
    s.X = 1:100;
    s.Y = rand(1, 100) * 10;
    s.resolve();

    fp = FastPlot();
    fp.addSensor(s);
    assert(numel(fp.Lines) == 1, 'testBasic: one line added');
    assert(strcmp(fp.Lines(1).DisplayName, 'Chamber Pressure'), 'testBasic: display name');

    % testAddSensorWithThresholds
    s = Sensor('pressure', 'Name', 'Pressure');
    s.X = 1:100;
    s.Y = [ones(1,50)*5, ones(1,50)*15];

    sc = StateChannel('machine');
    sc.X = [1 50]; sc.Y = [0 1];
    s.addStateChannel(sc);
    s.addThresholdRule(@(st) st.machine == 1, 10, 'Direction', 'upper', 'Label', 'HH');
    s.resolve();

    fp = FastPlot();
    fp.addSensor(s, 'ShowThresholds', true);
    assert(numel(fp.Lines) >= 2, 'testWithThresholds: line + threshold line(s)');

    % testAddSensorNoThresholds — ShowThresholds false
    s = Sensor('temp', 'Name', 'Temperature');
    s.X = 1:50;
    s.Y = rand(1, 50);
    s.addThresholdRule(@(st) true, 5, 'Direction', 'upper');
    s.resolve();

    fp = FastPlot();
    fp.addSensor(s, 'ShowThresholds', false);
    assert(numel(fp.Lines) == 1, 'testNoThresholds: only data line');

    % testAddSensorUsesKeyAsFallbackName
    s = Sensor('flow_rate');
    s.X = 1:10;
    s.Y = rand(1, 10);
    s.resolve();

    fp = FastPlot();
    fp.addSensor(s);
    assert(strcmp(fp.Lines(1).DisplayName, 'flow_rate'), 'testFallbackName: uses Key');

    fprintf('    All 4 add_sensor tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end
```

**Step 2: Run test to verify it fails**

```bash
matlab -batch "cd tests; test_add_sensor"
```

Expected: FAIL — `addSensor` method not found on FastPlot.

**Step 3: Add `addSensor()` to FastPlot.m**

Add this method to the public methods section of `libs/FastPlot/FastPlot.m`, after the existing `addThreshold` method:

```matlab
        function addSensor(obj, sensor, varargin)
            %ADDSENSOR Add a resolved Sensor's data and thresholds to the plot.
            %   fp.addSensor(s)
            %   fp.addSensor(s, 'ShowThresholds', true, 'ShowStateShading', true)
            %
            %   The sensor must have X and Y populated (via load() or direct
            %   assignment) and resolve() must have been called if thresholds
            %   are used.

            if obj.IsRendered
                error('FastPlot:alreadyRendered', ...
                    'Cannot add sensors after render() has been called.');
            end

            defaults.ShowThresholds = true;
            defaults.ShowStateShading = false;
            [parsed, ~] = parseOpts(defaults, varargin, obj.Verbose);

            % Determine display name: prefer Name, fall back to Key
            displayName = sensor.Name;
            if isempty(displayName)
                displayName = sensor.Key;
            end

            % Add sensor data as a line
            obj.addLine(sensor.X, sensor.Y, 'DisplayName', displayName);

            % Add resolved thresholds as stepped lines + violation markers
            if parsed.ShowThresholds && ~isempty(sensor.ResolvedThresholds)
                for i = 1:numel(sensor.ResolvedThresholds)
                    th = sensor.ResolvedThresholds(i);

                    % Add stepped threshold line (only where condition is active)
                    thLabel = th.Label;
                    if isempty(thLabel)
                        thLabel = sprintf('Threshold %d', i);
                    end

                    thColor = th.Color;
                    if isempty(thColor)
                        thColor = obj.Theme.ThresholdColor;
                    end

                    thStyle = th.LineStyle;
                    if isempty(thStyle)
                        thStyle = obj.Theme.ThresholdStyle;
                    end

                    % Add threshold as a line (NaN gaps where inactive)
                    obj.addLine(th.X, th.Y, ...
                        'DisplayName', thLabel, ...
                        'Color', thColor, ...
                        'LineStyle', thStyle, ...
                        'LineWidth', 1.5);

                    % Add violation markers if any
                    viol = sensor.ResolvedViolations(i);
                    if ~isempty(viol.X)
                        obj.addLine(viol.X, viol.Y, ...
                            'DisplayName', '', ...
                            'Color', thColor, ...
                            'LineStyle', 'none', ...
                            'Marker', 'o', ...
                            'MarkerSize', 4);
                    end
                end
            end

            % Add state shading bands
            if parsed.ShowStateShading && ~isempty(fieldnames(sensor.ResolvedStateBands))
                % Future: add bands via obj.addBand() for each state region
            end
        end
```

Note: The exact method signature of `addLine` may need adjustment based on what FastPlot.addLine actually accepts. Check `FastPlot.m` for the `addLine` method signature — it uses name-value pairs like `'DisplayName'`, `'Color'`, `'LineStyle'`, etc. The threshold line is added as a regular line with NaN gaps where the rule is inactive — NaN values create visual breaks in the line, showing the stepped threshold only where active.

**Step 4: Run test to verify it passes**

```bash
matlab -batch "cd tests; test_add_sensor"
```

Expected: All 4 tests pass.

**Step 5: Commit**

```bash
git add libs/FastPlot/FastPlot.m tests/test_add_sensor.m
git commit -m "feat: add FastPlot.addSensor() for Sensor integration"
```

---

### Task 9: End-to-End Example

**Files:**
- Create: `examples/example_sensor_threshold.m`

**Step 1: Create example script**

Create `examples/example_sensor_threshold.m`:

```matlab
%EXAMPLE_SENSOR_THRESHOLD Demonstrates the Sensor/Threshold system with FastPlot.
%   Shows dynamic thresholds that change based on machine state.

% Setup paths
setup;

% --- Create sensor with synthetic data ---
s = Sensor('pressure', 'Name', 'Chamber Pressure', 'ID', 101);
t = linspace(0, 100, 10000);
s.X = t;
s.Y = 40 + 20*sin(2*pi*t/30) + 5*randn(1, numel(t));

% --- Create state channel (machine state changes over time) ---
sc = StateChannel('machine_state');
sc.X = [0 25 50 75];
sc.Y = [0 1 2 1];  % 0=idle, 1=running, 2=evacuated
s.addStateChannel(sc);

% --- Define dynamic thresholds per state ---
% Idle: threshold at 70
s.addThresholdRule(@(st) st.machine_state == 0, 70, ...
    'Direction', 'upper', 'Label', 'HH (idle)', ...
    'Color', [0.8 0 0], 'LineStyle', '--');

% Running: stricter threshold at 55
s.addThresholdRule(@(st) st.machine_state == 1, 55, ...
    'Direction', 'upper', 'Label', 'HH (running)', ...
    'Color', [1 0.3 0], 'LineStyle', '--');

% Evacuated: very strict threshold at 45
s.addThresholdRule(@(st) st.machine_state == 2, 45, ...
    'Direction', 'upper', 'Label', 'HH (evacuated)', ...
    'Color', [1 0 0], 'LineStyle', '-');

% --- Precompute everything ---
s.resolve();

% --- Plot with FastPlot ---
fp = FastPlot();
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title('Chamber Pressure with Dynamic Thresholds');
xlabel('Time');
ylabel('Pressure [mbar]');
```

**Step 2: Run example to verify it works visually**

```bash
matlab -batch "cd examples; example_sensor_threshold"
```

Expected: A FastPlot figure showing the pressure signal with three different threshold lines that appear/disappear based on machine state, with violation markers where pressure exceeds the active threshold.

**Step 3: Commit**

```bash
git add examples/example_sensor_threshold.m
git commit -m "feat: add sensor threshold example with dynamic state-based thresholds"
```

---

### Task 10: Run Full Test Suite

**Step 1: Run all tests**

```bash
matlab -batch "setup; cd tests; run_all_tests"
```

Expected: All tests pass (old FastPlot tests + new Sensor/Threshold tests).

**Step 2: Fix any failures**

If any test fails, fix the issue and re-run.

**Step 3: Final commit if fixes needed**

```bash
git add -A
git commit -m "fix: resolve test failures after monorepo restructure"
```
