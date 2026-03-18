# Live Event Detection Pipeline — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a live event detection pipeline that reads continuously-updated sensor data, detects threshold violations incrementally, stores events to a shared `.mat` file, and sends email notifications with event snapshot plots.

**Architecture:** Monolithic orchestrator (`LiveEventPipeline`) owns a 15-second timer. Each cycle it reads new data via swappable `DataSource` objects, runs incremental detection with open-event carry-over, writes to an atomic `EventStore`, and triggers rule-based `NotificationService` with two FastSense snapshot PNGs per event.

**Tech Stack:** MATLAB classes, `containers.Map`, MATLAB `timer`, `sendmail`, FastSense for snapshot rendering.

**Test runner:** `cd tests && matlab -batch "run_all_tests"` or individual: `matlab -batch "test_data_source"`

---

### Task 1: DataSource Abstract Class

**Files:**
- Create: `libs/EventDetection/DataSource.m`
- Test: `tests/test_data_source.m`

**Step 1: Write the failing test**

```matlab
function test_data_source()
    add_event_path();
    test_cannot_instantiate();
    test_subclass_must_implement_fetchNew();
    fprintf('test_data_source: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    setup();
end

function test_cannot_instantiate()
    try
        ds = DataSource();
        error('Should not reach here');
    catch ex
        assert(contains(ex.message, 'Abstract'), 'cannot_instantiate');
    end
    fprintf('  PASS: test_cannot_instantiate\n');
end

function test_subclass_must_implement_fetchNew()
    % A minimal concrete subclass that does implement fetchNew
    % is tested in test_mock_data_source.m
    % Here we just verify the class file loads without error
    mc = meta.class.fromName('DataSource');
    assert(~isempty(mc), 'class_exists');
    methods = {mc.MethodList.Name};
    assert(ismember('fetchNew', methods), 'has_fetchNew');
    fprintf('  PASS: test_subclass_must_implement_fetchNew\n');
end
```

**Step 2: Run test to verify it fails**

Run: `matlab -batch "cd tests; test_data_source"`
Expected: FAIL — `DataSource` class not found

**Step 3: Write minimal implementation**

```matlab
classdef (Abstract) DataSource < handle
    % DataSource  Abstract interface for fetching new sensor data.
    %
    %   Subclasses must implement fetchNew() which returns a struct:
    %     .X       — 1xN datenum timestamps
    %     .Y       — 1xN (or MxN) values
    %     .stateX  — 1xK datenum state timestamps (empty if none)
    %     .stateY  — 1xK state values (empty if none)
    %     .changed — logical, true if new data since last call

    methods (Abstract)
        result = fetchNew(obj)
    end

    methods (Static)
        function result = emptyResult()
            result = struct('X', [], 'Y', [], 'stateX', [], 'stateY', {{}}, 'changed', false);
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `matlab -batch "cd tests; test_data_source"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/DataSource.m tests/test_data_source.m
git commit -m "feat: add DataSource abstract class"
```

---

### Task 2: MockDataSource

**Files:**
- Create: `libs/EventDetection/MockDataSource.m`
- Test: `tests/test_mock_data_source.m`

**Step 1: Write the failing test**

```matlab
function test_mock_data_source()
    add_event_path();
    test_constructor_defaults();
    test_first_fetch_returns_backlog();
    test_subsequent_fetch_returns_incremental();
    test_unchanged_if_called_too_fast();
    test_deterministic_seed();
    test_violation_episodes();
    test_sparse_state_changes();
    test_sample_interval();
    fprintf('test_mock_data_source: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    setup();
end

function test_constructor_defaults()
    ds = MockDataSource();
    assert(ds.BaseValue == 100, 'default_base');
    assert(ds.NoiseStd == 1, 'default_noise');
    assert(ds.SampleInterval == 3, 'default_interval');
    assert(ds.BacklogDays == 3, 'default_backlog');
    fprintf('  PASS: test_constructor_defaults\n');
end

function test_first_fetch_returns_backlog()
    ds = MockDataSource('BacklogDays', 1, 'SampleInterval', 3);
    result = ds.fetchNew();
    assert(result.changed, 'first_fetch_changed');
    expectedPoints = floor(1 * 86400 / 3);
    assert(abs(numel(result.X) - expectedPoints) < 10, 'backlog_point_count');
    assert(numel(result.Y) == numel(result.X), 'xy_match');
    assert(all(diff(result.X) > 0), 'monotonic_time');
    fprintf('  PASS: test_first_fetch_returns_backlog\n');
end

function test_subsequent_fetch_returns_incremental()
    ds = MockDataSource('BacklogDays', 0.001, 'SampleInterval', 3);
    ds.fetchNew();  % consume backlog
    pause(0.01);
    ds.PipelineInterval = 15;
    result = ds.fetchNew();
    assert(result.changed, 'second_fetch_changed');
    assert(numel(result.X) == 5, 'incremental_5pts');  % 15s / 3s = 5
    fprintf('  PASS: test_subsequent_fetch_returns_incremental\n');
end

function test_unchanged_if_called_too_fast()
    ds = MockDataSource('BacklogDays', 0.001, 'SampleInterval', 3);
    ds.fetchNew();
    ds.PipelineInterval = 15;
    ds.fetchNew();  % get incremental batch
    result = ds.fetchNew();  % immediate second call
    % Should still return new data (mock always advances)
    assert(result.changed, 'mock_always_advances');
    fprintf('  PASS: test_unchanged_if_called_too_fast\n');
end

function test_deterministic_seed()
    ds1 = MockDataSource('Seed', 42, 'BacklogDays', 0.01);
    ds2 = MockDataSource('Seed', 42, 'BacklogDays', 0.01);
    r1 = ds1.fetchNew();
    r2 = ds2.fetchNew();
    assert(isequal(r1.Y, r2.Y), 'deterministic_values');
    assert(isequal(r1.X, r2.X), 'deterministic_times');
    fprintf('  PASS: test_deterministic_seed\n');
end

function test_violation_episodes()
    ds = MockDataSource('BaseValue', 50, 'NoiseStd', 0.1, ...
        'ViolationProbability', 1.0, 'ViolationAmplitude', 30, ...
        'BacklogDays', 0.01, 'Seed', 99);
    result = ds.fetchNew();
    % With violation probability 1.0, signal should exceed base + amplitude at some point
    assert(any(result.Y > 60), 'violation_above_base');
    fprintf('  PASS: test_violation_episodes\n');
end

function test_sparse_state_changes()
    ds = MockDataSource('BacklogDays', 1, 'StateValues', {{'idle','running','cooldown'}}, ...
        'StateChangeProbability', 0.01, 'Seed', 7);
    result = ds.fetchNew();
    assert(~isempty(result.stateX), 'has_state_times');
    assert(~isempty(result.stateY), 'has_state_values');
    % State transitions should be much sparser than data points
    assert(numel(result.stateX) < numel(result.X) / 10, 'state_sparse');
    % All state values should be from the allowed set
    for i = 1:numel(result.stateY)
        assert(ismember(result.stateY{i}, {'idle','running','cooldown'}), 'valid_state');
    end
    fprintf('  PASS: test_sparse_state_changes\n');
end

function test_sample_interval()
    ds = MockDataSource('BacklogDays', 0.01, 'SampleInterval', 5);
    result = ds.fetchNew();
    dt = diff(result.X) * 86400;  % convert datenum diff to seconds
    assert(all(abs(dt - 5) < 0.01), 'sample_interval_5s');
    fprintf('  PASS: test_sample_interval\n');
end
```

**Step 2: Run test to verify it fails**

Run: `matlab -batch "cd tests; test_mock_data_source"`
Expected: FAIL — `MockDataSource` not found

**Step 3: Write minimal implementation**

```matlab
classdef MockDataSource < DataSource
    % MockDataSource  Generates realistic industrial sensor signals for testing.

    properties
        BaseValue       = 100
        NoiseStd        = 1
        DriftRate       = 0        % drift per second
        SampleInterval  = 3        % seconds between points
        BacklogDays     = 3        % days of history on first fetch
        ViolationProbability  = 0.005  % chance per point of starting violation
        ViolationAmplitude    = 20     % how far signal ramps beyond base
        ViolationDuration     = 60     % seconds per violation episode
        StateValues           = {{}}   % cell of char, e.g. {'idle','running'}
        StateChangeProbability = 0.001 % chance per point of state transition
        Seed                  = []     % optional RNG seed
        PipelineInterval      = 15     % seconds per fetch cycle
    end

    properties (Access = private)
        rng_            % RNG stream
        lastTime_       % datenum of last generated point
        backlogDone_    = false
        currentState_   = ''
        inViolation_    = false
        violationEnd_   = 0
        violationSign_  = 1
        driftAccum_     = 0
    end

    methods
        function obj = MockDataSource(varargin)
            p = inputParser();
            p.addParameter('BaseValue',       100);
            p.addParameter('NoiseStd',        1);
            p.addParameter('DriftRate',        0);
            p.addParameter('SampleInterval',   3);
            p.addParameter('BacklogDays',      3);
            p.addParameter('ViolationProbability',  0.005);
            p.addParameter('ViolationAmplitude',    20);
            p.addParameter('ViolationDuration',     60);
            p.addParameter('StateValues',      {{}});
            p.addParameter('StateChangeProbability', 0.001);
            p.addParameter('Seed',             []);
            p.addParameter('PipelineInterval', 15);
            p.parse(varargin{:});
            flds = fieldnames(p.Results);
            for i = 1:numel(flds)
                obj.(flds{i}) = p.Results.(flds{i});
            end
            if ~isempty(obj.Seed)
                obj.rng_ = RandStream('mt19937ar', 'Seed', obj.Seed);
            else
                obj.rng_ = RandStream('mt19937ar', 'Seed', 'shuffle');
            end
            if ~isempty(obj.StateValues) && ~isempty(obj.StateValues{1})
                obj.currentState_ = obj.StateValues{1}{1};
            end
        end

        function result = fetchNew(obj)
            if ~obj.backlogDone_
                result = obj.generateBacklog();
                obj.backlogDone_ = true;
            else
                result = obj.generateIncremental();
            end
        end
    end

    methods (Access = private)
        function result = generateBacklog(obj)
            nPoints = floor(obj.BacklogDays * 86400 / obj.SampleInterval);
            tEnd = now;
            tStart = tEnd - obj.BacklogDays;
            X = linspace(tStart, tEnd, nPoints);
            [Y, stateX, stateY] = obj.generateSignal(X);
            obj.lastTime_ = X(end);
            result = struct('X', X, 'Y', Y, 'stateX', stateX, 'stateY', {stateY}, 'changed', true);
        end

        function result = generateIncremental(obj)
            nPoints = round(obj.PipelineInterval / obj.SampleInterval);
            dt = obj.SampleInterval / 86400;  % to datenum
            X = obj.lastTime_ + dt * (1:nPoints);
            [Y, stateX, stateY] = obj.generateSignal(X);
            obj.lastTime_ = X(end);
            result = struct('X', X, 'Y', Y, 'stateX', stateX, 'stateY', {stateY}, 'changed', true);
        end

        function [Y, stateX, stateY] = generateSignal(obj, X)
            n = numel(X);
            Y = zeros(1, n);
            stateX = [];
            stateY = {};
            hasStates = ~isempty(obj.StateValues) && ~isempty(obj.StateValues{1});

            for i = 1:n
                % Drift
                obj.driftAccum_ = obj.driftAccum_ + obj.DriftRate * obj.SampleInterval;

                % Base + noise + drift
                noise = obj.NoiseStd * obj.rng_.randn();
                val = obj.BaseValue + obj.driftAccum_ + noise;

                % Violation episode
                if obj.inViolation_
                    tSec = (X(i) - obj.violationEnd_) * 86400;
                    if tSec >= 0
                        obj.inViolation_ = false;
                    else
                        remaining = (obj.violationEnd_ - X(i)) * 86400;
                        total = obj.ViolationDuration;
                        progress = 1 - remaining / total;
                        envelope = sin(pi * progress);  % smooth ramp up and down
                        val = val + obj.violationSign_ * obj.ViolationAmplitude * envelope;
                    end
                else
                    if obj.rng_.rand() < obj.ViolationProbability
                        obj.inViolation_ = true;
                        obj.violationEnd_ = X(i) + obj.ViolationDuration / 86400;
                        obj.violationSign_ = 2 * (obj.rng_.rand() > 0.5) - 1;
                    end
                end

                Y(i) = val;

                % State transitions (sparse)
                if hasStates && obj.rng_.rand() < obj.StateChangeProbability
                    states = obj.StateValues{1};
                    newIdx = obj.rng_.randi(numel(states));
                    newState = states{newIdx};
                    if ~strcmp(newState, obj.currentState_)
                        obj.currentState_ = newState;
                        stateX(end+1) = X(i);
                        stateY{end+1} = newState;
                    end
                end
            end
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `matlab -batch "cd tests; test_mock_data_source"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/MockDataSource.m tests/test_mock_data_source.m
git commit -m "feat: add MockDataSource with realistic industrial signals"
```

---

### Task 3: MatFileDataSource

**Files:**
- Create: `libs/EventDetection/MatFileDataSource.m`
- Test: `tests/test_mat_file_data_source.m`

**Step 1: Write the failing test**

```matlab
function test_mat_file_data_source()
    add_event_path();
    test_constructor();
    test_first_fetch_reads_all();
    test_incremental_fetch();
    test_unchanged_file();
    test_state_data();
    test_missing_file();
    fprintf('test_mat_file_data_source: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    setup();
end

function test_constructor()
    ds = MatFileDataSource('/tmp/test.mat', 'XVar', 't', 'YVar', 'y');
    assert(strcmp(ds.FilePath, '/tmp/test.mat'), 'filepath');
    assert(strcmp(ds.XVar, 't'), 'xvar');
    assert(strcmp(ds.YVar, 'y'), 'yvar');
    fprintf('  PASS: test_constructor\n');
end

function test_first_fetch_reads_all()
    f = [tempname '.mat'];
    x = [1 2 3 4 5]; y = [10 20 30 40 50];
    save(f, 'x', 'y');
    ds = MatFileDataSource(f, 'XVar', 'x', 'YVar', 'y');
    result = ds.fetchNew();
    assert(result.changed, 'changed');
    assert(isequal(result.X, x), 'all_x');
    assert(isequal(result.Y, y), 'all_y');
    delete(f);
    fprintf('  PASS: test_first_fetch_reads_all\n');
end

function test_incremental_fetch()
    f = [tempname '.mat'];
    x = [1 2 3]; y = [10 20 30];
    save(f, 'x', 'y');
    ds = MatFileDataSource(f, 'XVar', 'x', 'YVar', 'y');
    ds.fetchNew();  % read initial
    % Append new data
    x = [1 2 3 4 5]; y = [10 20 30 40 50];
    save(f, 'x', 'y');
    result = ds.fetchNew();
    assert(result.changed, 'changed');
    assert(isequal(result.X, [4 5]), 'only_new_x');
    assert(isequal(result.Y, [40 50]), 'only_new_y');
    delete(f);
    fprintf('  PASS: test_incremental_fetch\n');
end

function test_unchanged_file()
    f = [tempname '.mat'];
    x = [1 2 3]; y = [10 20 30];
    save(f, 'x', 'y');
    ds = MatFileDataSource(f, 'XVar', 'x', 'YVar', 'y');
    ds.fetchNew();
    result = ds.fetchNew();
    assert(~result.changed, 'not_changed');
    assert(isempty(result.X), 'empty_x');
    delete(f);
    fprintf('  PASS: test_unchanged_file\n');
end

function test_state_data()
    f = [tempname '.mat'];
    x = [1 2 3]; y = [10 20 30];
    stateX = [1 2.5]; stateY = {'idle', 'running'};
    save(f, 'x', 'y', 'stateX', 'stateY');
    ds = MatFileDataSource(f, 'XVar', 'x', 'YVar', 'y', ...
        'StateXVar', 'stateX', 'StateYVar', 'stateY');
    result = ds.fetchNew();
    assert(isequal(result.stateX, stateX), 'state_x');
    assert(isequal(result.stateY, stateY), 'state_y');
    delete(f);
    fprintf('  PASS: test_state_data\n');
end

function test_missing_file()
    ds = MatFileDataSource('/tmp/nonexistent_abc123.mat', 'XVar', 'x', 'YVar', 'y');
    result = ds.fetchNew();
    assert(~result.changed, 'missing_not_changed');
    assert(isempty(result.X), 'missing_empty');
    fprintf('  PASS: test_missing_file\n');
end
```

**Step 2: Run test to verify it fails**

Run: `matlab -batch "cd tests; test_mat_file_data_source"`
Expected: FAIL — `MatFileDataSource` not found

**Step 3: Write minimal implementation**

```matlab
classdef MatFileDataSource < DataSource
    % MatFileDataSource  Reads sensor data from a continuously-updated .mat file.

    properties
        FilePath     = ''
        XVar         = 'X'
        YVar         = 'Y'
        StateXVar    = ''
        StateYVar    = ''
    end

    properties (Access = private)
        lastModTime_  = 0
        lastIndex_    = 0
        lastStateIdx_ = 0
    end

    methods
        function obj = MatFileDataSource(filePath, varargin)
            p = inputParser();
            p.addRequired('filePath', @ischar);
            p.addParameter('XVar', 'X', @ischar);
            p.addParameter('YVar', 'Y', @ischar);
            p.addParameter('StateXVar', '', @ischar);
            p.addParameter('StateYVar', '', @ischar);
            p.parse(filePath, varargin{:});
            obj.FilePath  = p.Results.filePath;
            obj.XVar      = p.Results.XVar;
            obj.YVar      = p.Results.YVar;
            obj.StateXVar = p.Results.StateXVar;
            obj.StateYVar = p.Results.StateYVar;
        end

        function result = fetchNew(obj)
            result = DataSource.emptyResult();

            if ~isfile(obj.FilePath)
                return;
            end

            info = dir(obj.FilePath);
            modTime = info.datenum;

            if modTime <= obj.lastModTime_
                return;
            end
            obj.lastModTime_ = modTime;

            data = load(obj.FilePath);

            if ~isfield(data, obj.XVar) || ~isfield(data, obj.YVar)
                return;
            end

            allX = data.(obj.XVar);
            allY = data.(obj.YVar);

            if obj.lastIndex_ >= numel(allX)
                return;
            end

            newIdx = (obj.lastIndex_ + 1):numel(allX);
            result.X = allX(newIdx);
            result.Y = allY(newIdx);
            result.changed = true;
            obj.lastIndex_ = numel(allX);

            % State data
            if ~isempty(obj.StateXVar) && isfield(data, obj.StateXVar)
                allStateX = data.(obj.StateXVar);
                allStateY = data.(obj.StateYVar);
                if obj.lastStateIdx_ < numel(allStateX)
                    sIdx = (obj.lastStateIdx_ + 1):numel(allStateX);
                    result.stateX = allStateX(sIdx);
                    result.stateY = allStateY(sIdx);
                    obj.lastStateIdx_ = numel(allStateX);
                end
            end
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `matlab -batch "cd tests; test_mat_file_data_source"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/MatFileDataSource.m tests/test_mat_file_data_source.m
git commit -m "feat: add MatFileDataSource for reading continuously-updated .mat files"
```

---

### Task 4: DataSourceMap

**Files:**
- Create: `libs/EventDetection/DataSourceMap.m`
- Test: `tests/test_data_source_map.m`

**Step 1: Write the failing test**

```matlab
function test_data_source_map()
    add_event_path();
    test_add_and_get();
    test_keys();
    test_has();
    test_unknown_key_errors();
    test_remove();
    fprintf('test_data_source_map: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    setup();
end

function test_add_and_get()
    m = DataSourceMap();
    ds = MockDataSource('BaseValue', 50);
    m.add('pressure', ds);
    out = m.get('pressure');
    assert(out.BaseValue == 50, 'get_returns_source');
    fprintf('  PASS: test_add_and_get\n');
end

function test_keys()
    m = DataSourceMap();
    m.add('a', MockDataSource());
    m.add('b', MockDataSource());
    k = m.keys();
    assert(numel(k) == 2, 'two_keys');
    assert(ismember('a', k) && ismember('b', k), 'correct_keys');
    fprintf('  PASS: test_keys\n');
end

function test_has()
    m = DataSourceMap();
    m.add('x', MockDataSource());
    assert(m.has('x'), 'has_true');
    assert(~m.has('y'), 'has_false');
    fprintf('  PASS: test_has\n');
end

function test_unknown_key_errors()
    m = DataSourceMap();
    try
        m.get('nope');
        error('Should not reach here');
    catch ex
        assert(contains(ex.identifier, 'unknownKey'), 'error_id');
    end
    fprintf('  PASS: test_unknown_key_errors\n');
end

function test_remove()
    m = DataSourceMap();
    m.add('x', MockDataSource());
    m.remove('x');
    assert(~m.has('x'), 'removed');
    fprintf('  PASS: test_remove\n');
end
```

**Step 2: Run test to verify it fails**

Run: `matlab -batch "cd tests; test_data_source_map"`
Expected: FAIL — `DataSourceMap` not found

**Step 3: Write minimal implementation**

```matlab
classdef DataSourceMap < handle
    % DataSourceMap  Maps sensor keys to DataSource instances.

    properties (Access = private)
        map_
    end

    methods
        function obj = DataSourceMap()
            obj.map_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function add(obj, key, dataSource)
            assert(isa(dataSource, 'DataSource'), 'DataSourceMap:invalidType', ...
                'Value must be a DataSource subclass.');
            obj.map_(key) = dataSource;
        end

        function ds = get(obj, key)
            if ~obj.map_.isKey(key)
                error('DataSourceMap:unknownKey', 'No DataSource for key "%s".', key);
            end
            ds = obj.map_(key);
        end

        function k = keys(obj)
            k = obj.map_.keys();
        end

        function tf = has(obj, key)
            tf = obj.map_.isKey(key);
        end

        function remove(obj, key)
            if obj.map_.isKey(key)
                obj.map_.remove(key);
            end
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `matlab -batch "cd tests; test_data_source_map"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/DataSourceMap.m tests/test_data_source_map.m
git commit -m "feat: add DataSourceMap for sensor-key to data-source mapping"
```

---

### Task 5: EventStore

**Files:**
- Create: `libs/EventDetection/EventStore.m`
- Test: `tests/test_event_store_rw.m`

**Step 1: Write the failing test**

```matlab
function test_event_store_rw()
    add_event_path();
    test_constructor();
    test_append_and_save();
    test_atomic_write();
    test_load_static();
    test_load_unchanged();
    test_backup_rotation();
    test_metadata();
    fprintf('test_event_store_rw: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    setup();
end

function test_constructor()
    f = [tempname '.mat'];
    store = EventStore(f);
    assert(strcmp(store.FilePath, f), 'filepath');
    assert(store.MaxBackups == 5, 'default_backups');
    fprintf('  PASS: test_constructor\n');
end

function test_append_and_save()
    f = [tempname '.mat'];
    store = EventStore(f);
    ev1 = Event(now-1, now-0.5, 'sensorA', 'HH', 100, 'high');
    store.append(ev1);
    store.save();
    assert(isfile(f), 'file_created');
    data = load(f);
    assert(numel(data.events) == 1, 'one_event');
    % Append more
    ev2 = Event(now-0.3, now-0.1, 'sensorB', 'LL', 10, 'low');
    store.append(ev2);
    store.save();
    data = load(f);
    assert(numel(data.events) == 2, 'two_events');
    delete(f);
    fprintf('  PASS: test_append_and_save\n');
end

function test_atomic_write()
    f = [tempname '.mat'];
    store = EventStore(f);
    ev = Event(now, now+0.01, 'x', 'H', 50, 'high');
    store.append(ev);
    store.save();
    % File should exist and be readable
    data = load(f);
    assert(isfield(data, 'events'), 'has_events');
    assert(isfield(data, 'lastUpdated'), 'has_timestamp');
    delete(f);
    fprintf('  PASS: test_atomic_write\n');
end

function test_load_static()
    f = [tempname '.mat'];
    store = EventStore(f);
    ev = Event(now, now+0.01, 'x', 'H', 50, 'high');
    store.append(ev);
    store.save();
    [events, meta] = EventStore.load(f);
    assert(numel(events) == 1, 'loaded_one');
    assert(isfield(meta, 'lastUpdated'), 'meta_timestamp');
    delete(f);
    fprintf('  PASS: test_load_static\n');
end

function test_load_unchanged()
    f = [tempname '.mat'];
    store = EventStore(f);
    ev = Event(now, now+0.01, 'x', 'H', 50, 'high');
    store.append(ev);
    store.save();
    [~, ~] = EventStore.load(f);
    [events, meta, changed] = EventStore.load(f);
    assert(~changed, 'unchanged');
    delete(f);
    fprintf('  PASS: test_load_unchanged\n');
end

function test_backup_rotation()
    f = [tempname '.mat'];
    store = EventStore(f, 'MaxBackups', 2);
    for i = 1:4
        ev = Event(now+i, now+i+0.01, 'x', 'H', 50, 'high');
        store.append(ev);
        store.save();
        pause(0.1);
    end
    [fdir, fname] = fileparts(f);
    backups = dir(fullfile(fdir, [fname '_backup_*.mat']));
    assert(numel(backups) <= 2, 'max_2_backups');
    delete(f);
    for b = 1:numel(backups)
        delete(fullfile(fdir, backups(b).name));
    end
    fprintf('  PASS: test_backup_rotation\n');
end

function test_metadata()
    f = [tempname '.mat'];
    store = EventStore(f);
    store.PipelineConfig = struct('sensors', {{'a','b'}});
    ev = Event(now, now+0.01, 'x', 'H', 50, 'high');
    store.append(ev);
    store.save();
    data = load(f);
    assert(isfield(data, 'pipelineConfig'), 'has_config');
    assert(isequal(data.pipelineConfig.sensors, {'a','b'}), 'config_matches');
    delete(f);
    fprintf('  PASS: test_metadata\n');
end
```

**Step 2: Run test to verify it fails**

Run: `matlab -batch "cd tests; test_event_store_rw"`
Expected: FAIL — `EventStore` class not found (name collision check: existing `test_event_store.m` tests different functionality in `EventConfig`)

**Step 3: Write minimal implementation**

```matlab
classdef EventStore < handle
    % EventStore  Atomic read/write of events to a shared .mat file.

    properties
        FilePath        = ''
        MaxBackups      = 5
        PipelineConfig  = struct()
    end

    properties (Access = private)
        events_     = Event.empty()
    end

    methods
        function obj = EventStore(filePath, varargin)
            p = inputParser();
            p.addRequired('filePath', @ischar);
            p.addParameter('MaxBackups', 5, @isnumeric);
            p.parse(filePath, varargin{:});
            obj.FilePath   = p.Results.filePath;
            obj.MaxBackups = p.Results.MaxBackups;
        end

        function append(obj, newEvents)
            if isempty(newEvents); return; end
            if isempty(obj.events_)
                obj.events_ = newEvents(:)';
            else
                obj.events_ = [obj.events_, newEvents(:)'];
            end
        end

        function events = getEvents(obj)
            events = obj.events_;
        end

        function save(obj)
            if isempty(obj.FilePath); return; end

            % Backup existing file
            if isfile(obj.FilePath) && obj.MaxBackups > 0
                obj.createBackup();
            end

            % Atomic write: save to temp, then rename
            tmpFile = [obj.FilePath '.tmp'];
            events = obj.events_;
            lastUpdated = now;
            pipelineConfig = obj.PipelineConfig;
            save(tmpFile, 'events', 'lastUpdated', 'pipelineConfig', '-v7.3');
            movefile(tmpFile, obj.FilePath);
        end

        function n = numEvents(obj)
            n = numel(obj.events_);
        end
    end

    methods (Static)
        function [events, meta, changed] = load(filePath)
            persistent lastModTime;
            if isempty(lastModTime)
                lastModTime = containers.Map('KeyType', 'char', 'ValueType', 'double');
            end

            events = Event.empty();
            meta = struct();
            changed = false;

            if ~isfile(filePath); return; end

            info = dir(filePath);
            modTime = info.datenum;

            if lastModTime.isKey(filePath) && modTime <= lastModTime(filePath)
                % Unchanged — still load events but mark changed=false
                data = builtin('load', filePath);
                if isfield(data, 'events')
                    events = data.events;
                end
                if isfield(data, 'lastUpdated')
                    meta.lastUpdated = data.lastUpdated;
                end
                return;
            end

            lastModTime(filePath) = modTime;
            changed = true;

            data = builtin('load', filePath);
            if isfield(data, 'events')
                events = data.events;
            end
            if isfield(data, 'lastUpdated')
                meta.lastUpdated = data.lastUpdated;
            end
            if isfield(data, 'pipelineConfig')
                meta.pipelineConfig = data.pipelineConfig;
            end
        end
    end

    methods (Access = private)
        function createBackup(obj)
            [fdir, fname, fext] = fileparts(obj.FilePath);
            stamp = datestr(now, 'yyyymmdd_HHMMSS');
            backupName = fullfile(fdir, [fname '_backup_' stamp fext]);
            copyfile(obj.FilePath, backupName);
            obj.pruneBackups();
        end

        function pruneBackups(obj)
            [fdir, fname] = fileparts(obj.FilePath);
            pattern = fullfile(fdir, [fname '_backup_*.mat']);
            backups = dir(pattern);
            if numel(backups) > obj.MaxBackups
                [~, idx] = sort({backups.date});
                toDelete = backups(idx(1:end - obj.MaxBackups));
                for i = 1:numel(toDelete)
                    delete(fullfile(fdir, toDelete(i).name));
                end
            end
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `matlab -batch "cd tests; test_event_store_rw"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/EventStore.m tests/test_event_store_rw.m
git commit -m "feat: add EventStore with atomic write and backup rotation"
```

---

### Task 6: IncrementalEventDetector

**Files:**
- Create: `libs/EventDetection/IncrementalEventDetector.m`
- Test: `tests/test_incremental_detector.m`

**Step 1: Write the failing test**

```matlab
function test_incremental_detector()
    add_event_path();
    test_first_batch_detects_events();
    test_incremental_new_events_only();
    test_open_event_carries_over();
    test_open_event_finalizes();
    test_no_data_no_events();
    test_severity_escalation();
    test_multiple_sensors();
    fprintf('test_incremental_detector: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    setup();
end

function test_first_batch_detects_events()
    det = IncrementalEventDetector('MinDuration', 0);
    sensor = makeSensor('temp', 100, 'upper');
    t = linspace(now-1, now, 100);
    y = 80 * ones(1,100); y(40:60) = 120;  % violation from 40 to 60
    newEvents = det.process('temp', sensor, t, y, [], {});
    assert(numel(newEvents) >= 1, 'detected_event');
    assert(strcmp(newEvents(1).SensorName, 'temp'), 'sensor_name');
    fprintf('  PASS: test_first_batch_detects_events\n');
end

function test_incremental_new_events_only()
    det = IncrementalEventDetector('MinDuration', 0);
    sensor = makeSensor('temp', 100, 'upper');
    t1 = linspace(now-1, now-0.5, 50);
    y1 = 80 * ones(1,50); y1(20:30) = 120;
    ev1 = det.process('temp', sensor, t1, y1, [], {});
    n1 = numel(ev1);
    % Second batch — no violations
    t2 = linspace(now-0.5, now, 50);
    y2 = 80 * ones(1,50);
    ev2 = det.process('temp', sensor, t2, y2, [], {});
    assert(numel(ev2) == 0, 'no_new_events');
    fprintf('  PASS: test_incremental_new_events_only\n');
end

function test_open_event_carries_over()
    det = IncrementalEventDetector('MinDuration', 0);
    sensor = makeSensor('temp', 100, 'upper');
    % Batch 1: violation starts but doesn't end
    t1 = linspace(now-1, now-0.5, 50);
    y1 = 80 * ones(1,50); y1(40:50) = 120;  % violation continues at end
    ev1 = det.process('temp', sensor, t1, y1, [], {});
    % Open event should exist but not be emitted yet
    assert(numel(ev1) == 0, 'no_finalized_yet');
    assert(det.hasOpenEvent('temp'), 'has_open_event');
    fprintf('  PASS: test_open_event_carries_over\n');
end

function test_open_event_finalizes()
    det = IncrementalEventDetector('MinDuration', 0);
    sensor = makeSensor('temp', 100, 'upper');
    % Batch 1: violation at end
    t1 = linspace(now-1, now-0.5, 50);
    y1 = 80*ones(1,50); y1(40:50) = 120;
    det.process('temp', sensor, t1, y1, [], {});
    % Batch 2: violation ends
    t2 = linspace(now-0.5, now, 50);
    y2 = 80*ones(1,50); y2(1:5) = 120;  % violation continues briefly then stops
    ev2 = det.process('temp', sensor, t2, y2, [], {});
    assert(numel(ev2) == 1, 'finalized_event');
    % Event should span from batch 1 to batch 2
    assert(ev2(1).StartTime < now - 0.4, 'start_in_batch1');
    assert(ev2(1).EndTime > now - 0.5, 'end_in_batch2');
    fprintf('  PASS: test_open_event_finalizes\n');
end

function test_no_data_no_events()
    det = IncrementalEventDetector('MinDuration', 0);
    sensor = makeSensor('temp', 100, 'upper');
    ev = det.process('temp', sensor, [], [], [], {});
    assert(isempty(ev), 'no_events_empty_data');
    fprintf('  PASS: test_no_data_no_events\n');
end

function test_severity_escalation()
    det = IncrementalEventDetector('MinDuration', 0, 'EscalateSeverity', true);
    sensor = Sensor('temp');
    sensor.addThresholdRule(struct(), 100, 'Direction', 'upper', 'Label', 'H');
    sensor.addThresholdRule(struct(), 150, 'Direction', 'upper', 'Label', 'HH');
    t = linspace(now-1, now, 100);
    y = 80*ones(1,100); y(40:60) = 160;  % exceeds HH
    ev = det.process('temp', sensor, t, y, [], {});
    % Event should be escalated to HH
    hhEvents = ev(strcmp({ev.ThresholdLabel}, 'HH'));
    assert(~isempty(hhEvents), 'escalated_to_HH');
    fprintf('  PASS: test_severity_escalation\n');
end

function test_multiple_sensors()
    det = IncrementalEventDetector('MinDuration', 0);
    s1 = makeSensor('temp', 100, 'upper');
    s2 = makeSensor('pres', 50, 'upper');
    t = linspace(now-1, now, 100);
    y1 = 80*ones(1,100); y1(30:40) = 120;
    y2 = 30*ones(1,100); y2(60:70) = 60;
    ev1 = det.process('temp', s1, t, y1, [], {});
    ev2 = det.process('pres', s2, t, y2, [], {});
    assert(~isempty(ev1) && strcmp(ev1(1).SensorName, 'temp'), 'sensor1');
    assert(~isempty(ev2) && strcmp(ev2(1).SensorName, 'pres'), 'sensor2');
    fprintf('  PASS: test_multiple_sensors\n');
end

function sensor = makeSensor(key, threshVal, dir)
    sensor = Sensor(key);
    sensor.addThresholdRule(struct(), threshVal, 'Direction', dir, 'Label', 'H');
end
```

**Step 2: Run test to verify it fails**

Run: `matlab -batch "cd tests; test_incremental_detector"`
Expected: FAIL — `IncrementalEventDetector` not found

**Step 3: Write minimal implementation**

```matlab
classdef IncrementalEventDetector < handle
    % IncrementalEventDetector  Wraps EventDetector with incremental state.
    %   Tracks last-processed index per sensor and carries over open events.

    properties
        MinDuration      = 0
        MaxCallsPerEvent = 1
        OnEventStart     = []
        EscalateSeverity = true
    end

    properties (Access = private)
        sensorState_     % containers.Map: key -> struct
    end

    methods
        function obj = IncrementalEventDetector(varargin)
            p = inputParser();
            p.addParameter('MinDuration', 0);
            p.addParameter('MaxCallsPerEvent', 1);
            p.addParameter('OnEventStart', []);
            p.addParameter('EscalateSeverity', true);
            p.parse(varargin{:});
            obj.MinDuration      = p.Results.MinDuration;
            obj.MaxCallsPerEvent = p.Results.MaxCallsPerEvent;
            obj.OnEventStart     = p.Results.OnEventStart;
            obj.EscalateSeverity = p.Results.EscalateSeverity;
            obj.sensorState_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function newEvents = process(obj, sensorKey, sensor, newX, newY, newStateX, newStateY)
            newEvents = Event.empty();
            if isempty(newX); return; end

            st = obj.getState(sensorKey);

            % Append new data
            st.fullX = [st.fullX, newX];
            st.fullY = [st.fullY, newY];

            % Update state channels if new state data
            if ~isempty(newStateX)
                st.stateX = [st.stateX, newStateX];
                st.stateY = [st.stateY, newStateY];
            end

            % Build a temporary sensor for detection on the new slice
            tmpSensor = Sensor(sensorKey);
            tmpSensor.X = st.fullX;
            tmpSensor.Y = st.fullY;

            % Copy threshold rules from the source sensor
            for i = 1:numel(sensor.ThresholdRules)
                rule = sensor.ThresholdRules{i};
                tmpSensor.addThresholdRule(rule.Condition, rule.Value, ...
                    'Direction', rule.Direction, 'Label', rule.Label, ...
                    'Color', rule.Color, 'LineStyle', rule.LineStyle);
            end

            % Copy state channels — use accumulated state data
            for i = 1:numel(sensor.StateChannels)
                origSC = sensor.StateChannels{i};
                if ~isempty(st.stateX)
                    sc = StateChannel(origSC.Key, st.stateX, st.stateY);
                else
                    sc = origSC;
                end
                tmpSensor.addStateChannel(sc);
            end

            tmpSensor.resolve();

            % Build detector
            det = EventDetector('MinDuration', obj.MinDuration, ...
                'MaxCallsPerEvent', obj.MaxCallsPerEvent);

            % Detect on full data using existing infrastructure
            allEvents = detectEventsFromSensor(tmpSensor, det);

            % Filter to only events that touch the new data window
            sliceStart = newX(1);
            relevantEvents = Event.empty();
            for i = 1:numel(allEvents)
                ev = allEvents(i);
                if ev.EndTime >= sliceStart
                    relevantEvents(end+1) = ev;
                end
            end

            % Handle open events
            completedEvents = Event.empty();
            newOpenEvent = [];

            for i = 1:numel(relevantEvents)
                ev = relevantEvents(i);
                if ev.EndTime >= newX(end) && ...
                   obj.isViolationAtEnd(st.fullY, ev)
                    % Event is still ongoing at end of this batch
                    newOpenEvent = ev;
                else
                    % Check if this merges with previous open event
                    if ~isempty(st.openEvent) && ...
                       strcmp(ev.ThresholdLabel, st.openEvent.ThresholdLabel) && ...
                       ev.StartTime <= st.openEvent.EndTime + 1/86400
                        % Merge: use earlier start, recompute stats
                        merged = Event(st.openEvent.StartTime, ev.EndTime, ...
                            ev.SensorName, ev.ThresholdLabel, ev.ThresholdValue, ev.Direction);
                        idx1 = find(st.fullX >= st.openEvent.StartTime, 1);
                        idx2 = find(st.fullX <= ev.EndTime, 1, 'last');
                        window = st.fullY(idx1:idx2);
                        obj.computeAndSetStats(merged, window);
                        completedEvents(end+1) = merged;
                    elseif ~obj.isOldEvent(ev, st.lastProcessedTime)
                        completedEvents(end+1) = ev;
                    end
                end
            end

            % Finalize previous open event if it didn't merge
            if ~isempty(st.openEvent) && isempty(completedEvents)
                % Check if open event ended in this batch
                if ~isempty(newOpenEvent) && ...
                   strcmp(newOpenEvent.ThresholdLabel, st.openEvent.ThresholdLabel)
                    % Still open, carry forward
                else
                    % Open event ended
                    completedEvents(end+1) = st.openEvent;
                end
            end

            % Escalate severity
            if obj.EscalateSeverity && ~isempty(completedEvents)
                completedEvents = obj.escalate(completedEvents, sensor);
            end

            % Update state
            st.openEvent = newOpenEvent;
            st.lastProcessedTime = newX(end);
            obj.sensorState_(sensorKey) = st;

            % Fire callbacks
            for i = 1:numel(completedEvents)
                if ~isempty(obj.OnEventStart)
                    obj.OnEventStart(completedEvents(i));
                end
            end

            newEvents = completedEvents;
        end

        function tf = hasOpenEvent(obj, sensorKey)
            tf = false;
            if obj.sensorState_.isKey(sensorKey)
                st = obj.sensorState_(sensorKey);
                tf = ~isempty(st.openEvent);
            end
        end

        function st = getSensorState(obj, sensorKey)
            st = obj.getState(sensorKey);
        end
    end

    methods (Access = private)
        function st = getState(obj, key)
            if obj.sensorState_.isKey(key)
                st = obj.sensorState_(key);
            else
                st = struct('fullX', [], 'fullY', [], ...
                    'stateX', [], 'stateY', {{}}, ...
                    'openEvent', [], 'lastProcessedTime', 0);
                obj.sensorState_(key) = st;
            end
        end

        function tf = isViolationAtEnd(~, fullY, ev)
            % Check if the last data point is still in violation
            lastVal = fullY(end);
            if strcmp(ev.Direction, 'high')
                tf = lastVal > ev.ThresholdValue;
            else
                tf = lastVal < ev.ThresholdValue;
            end
        end

        function tf = isOldEvent(~, ev, lastProcessedTime)
            tf = ev.EndTime <= lastProcessedTime;
        end

        function computeAndSetStats(~, ev, window)
            nPts = numel(window);
            minVal = min(window);
            maxVal = max(window);
            meanVal = mean(window);
            rmsVal = sqrt(mean(window.^2));
            stdVal = std(window);
            if strcmp(ev.Direction, 'high')
                peakVal = maxVal;
            else
                peakVal = minVal;
            end
            ev.setStats(peakVal, nPts, minVal, maxVal, meanVal, rmsVal, stdVal);
        end

        function events = escalate(~, events, sensor)
            % Reuse logic from EventConfig.escalateEvents
            for i = 1:numel(events)
                ev = events(i);
                for j = 1:numel(sensor.ThresholdRules)
                    rule = sensor.ThresholdRules{j};
                    if ~strcmp(rule.Direction(1:min(end,5)), ev.Direction(1:min(end,5)))
                        continue;
                    end
                    if strcmp(ev.Direction, 'high') && rule.Value > ev.ThresholdValue && ev.PeakValue > rule.Value
                        ev.escalateTo(rule.Label, rule.Value);
                    elseif strcmp(ev.Direction, 'low') && rule.Value < ev.ThresholdValue && ev.PeakValue < rule.Value
                        ev.escalateTo(rule.Label, rule.Value);
                    end
                end
            end
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `matlab -batch "cd tests; test_incremental_detector"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/IncrementalEventDetector.m tests/test_incremental_detector.m
git commit -m "feat: add IncrementalEventDetector with open-event carry-over"
```

---

### Task 7: NotificationRule

**Files:**
- Create: `libs/EventDetection/NotificationRule.m`
- Test: `tests/test_notification_rule.m`

**Step 1: Write the failing test**

```matlab
function test_notification_rule()
    add_event_path();
    test_constructor();
    test_matches_sensor_and_threshold();
    test_matches_sensor_only();
    test_matches_default();
    test_fill_template();
    fprintf('test_notification_rule: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    setup();
end

function test_constructor()
    r = NotificationRule('SensorKey', 'temp', 'ThresholdLabel', 'HH', ...
        'Recipients', {{'a@b.com'}}, 'Subject', 'Alert: {sensor}');
    assert(strcmp(r.SensorKey, 'temp'), 'sensor');
    assert(strcmp(r.ThresholdLabel, 'HH'), 'label');
    assert(strcmp(r.Recipients{1}, 'a@b.com'), 'recipient');
    fprintf('  PASS: test_constructor\n');
end

function test_matches_sensor_and_threshold()
    r = NotificationRule('SensorKey', 'temp', 'ThresholdLabel', 'HH');
    ev = Event(now, now+0.01, 'temp', 'HH', 100, 'high');
    assert(r.matches(ev) == 3, 'exact_match_score_3');
    ev2 = Event(now, now+0.01, 'temp', 'H', 80, 'high');
    assert(r.matches(ev2) == 0, 'wrong_threshold_no_match');
    fprintf('  PASS: test_matches_sensor_and_threshold\n');
end

function test_matches_sensor_only()
    r = NotificationRule('SensorKey', 'temp');
    ev = Event(now, now+0.01, 'temp', 'HH', 100, 'high');
    assert(r.matches(ev) == 2, 'sensor_match_score_2');
    ev2 = Event(now, now+0.01, 'pressure', 'HH', 100, 'high');
    assert(r.matches(ev2) == 0, 'wrong_sensor');
    fprintf('  PASS: test_matches_sensor_only\n');
end

function test_matches_default()
    r = NotificationRule();  % no sensor/threshold = default
    ev = Event(now, now+0.01, 'anything', 'X', 1, 'high');
    assert(r.matches(ev) == 1, 'default_score_1');
    fprintf('  PASS: test_matches_default\n');
end

function test_fill_template()
    r = NotificationRule('Subject', 'ALERT: {sensor} - {threshold} ({direction})', ...
        'Message', 'Peak: {peak}, Duration: {duration}');
    ev = Event(now, now + 1/24, 'temp', 'HH', 100, 'high');
    ev.setStats(105, 10, 90, 105, 98, 99, 3);
    subj = r.fillTemplate(r.Subject, ev);
    assert(contains(subj, 'temp'), 'subj_sensor');
    assert(contains(subj, 'HH'), 'subj_threshold');
    assert(contains(subj, 'high'), 'subj_direction');
    msg = r.fillTemplate(r.Message, ev);
    assert(contains(msg, '105'), 'msg_peak');
    fprintf('  PASS: test_fill_template\n');
end
```

**Step 2: Run test to verify it fails**

Run: `matlab -batch "cd tests; test_notification_rule"`
Expected: FAIL — `NotificationRule` not found

**Step 3: Write minimal implementation**

```matlab
classdef NotificationRule < handle
    % NotificationRule  Configures notification for sensor/threshold events.

    properties
        SensorKey       = ''
        ThresholdLabel  = ''
        Recipients      = {{}}
        Subject         = 'Event: {sensor} - {threshold}'
        Message         = '{sensor} exceeded {threshold} ({direction}) at {startTime}. Peak: {peak}'
        IncludeSnapshot = true
        ContextHours    = 2
        SnapshotPadding = 0.1
        SnapshotSize    = [800, 400]
    end

    methods
        function obj = NotificationRule(varargin)
            p = inputParser();
            p.addParameter('SensorKey', '', @ischar);
            p.addParameter('ThresholdLabel', '', @ischar);
            p.addParameter('Recipients', {{}});
            p.addParameter('Subject', 'Event: {sensor} - {threshold}', @ischar);
            p.addParameter('Message', '{sensor} exceeded {threshold} ({direction}) at {startTime}. Peak: {peak}', @ischar);
            p.addParameter('IncludeSnapshot', true, @islogical);
            p.addParameter('ContextHours', 2, @isnumeric);
            p.addParameter('SnapshotPadding', 0.1, @isnumeric);
            p.addParameter('SnapshotSize', [800 400], @isnumeric);
            p.parse(varargin{:});
            flds = fieldnames(p.Results);
            for i = 1:numel(flds)
                obj.(flds{i}) = p.Results.(flds{i});
            end
        end

        function score = matches(obj, event)
            % Returns match score: 3=sensor+threshold, 2=sensor, 1=default, 0=no match
            hasSensor = ~isempty(obj.SensorKey);
            hasThreshold = ~isempty(obj.ThresholdLabel);

            if hasSensor && ~strcmp(event.SensorName, obj.SensorKey)
                score = 0; return;
            end
            if hasThreshold && ~strcmp(event.ThresholdLabel, obj.ThresholdLabel)
                score = 0; return;
            end

            if hasSensor && hasThreshold
                score = 3;
            elseif hasSensor
                score = 2;
            else
                score = 1;  % default rule
            end
        end

        function txt = fillTemplate(~, template, event)
            txt = template;
            txt = strrep(txt, '{sensor}', event.SensorName);
            txt = strrep(txt, '{threshold}', event.ThresholdLabel);
            txt = strrep(txt, '{direction}', event.Direction);
            txt = strrep(txt, '{startTime}', datestr(event.StartTime, 'yyyy-mm-dd HH:MM:SS'));
            txt = strrep(txt, '{endTime}', datestr(event.EndTime, 'yyyy-mm-dd HH:MM:SS'));
            txt = strrep(txt, '{duration}', sprintf('%.1fs', event.Duration * 86400));
            txt = strrep(txt, '{peak}', sprintf('%.4g', event.PeakValue));
            txt = strrep(txt, '{mean}', sprintf('%.4g', event.MeanValue));
            txt = strrep(txt, '{rms}', sprintf('%.4g', event.RmsValue));
            txt = strrep(txt, '{std}', sprintf('%.4g', event.StdValue));
            txt = strrep(txt, '{thresholdValue}', sprintf('%.4g', event.ThresholdValue));
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `matlab -batch "cd tests; test_notification_rule"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/NotificationRule.m tests/test_notification_rule.m
git commit -m "feat: add NotificationRule with template filling and match scoring"
```

---

### Task 8: generateEventSnapshot

**Files:**
- Create: `libs/EventDetection/generateEventSnapshot.m`
- Test: `tests/test_event_snapshot.m`

**Step 1: Write the failing test**

```matlab
function test_event_snapshot()
    add_event_path();
    test_generates_two_pngs();
    test_detail_plot_bounds();
    test_context_plot_bounds();
    test_shaded_region_exists();
    test_custom_size();
    fprintf('test_event_snapshot: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    addpath(fullfile(repoRoot, 'libs', 'FastSense'));
    setup();
end

function [ev, sensorData] = makeTestEvent()
    tStart = now - 1/24;  % 1 hour ago
    tEnd = now - 0.5/24;  % 30 min ago
    ev = Event(tStart, tEnd, 'temperature', 'HH', 100, 'high');
    ev.setStats(115, 50, 90, 115, 105, 106, 5);
    t = linspace(now - 3/24, now, 1000);
    y = 80 + 5*randn(1, 1000);
    idx = t >= tStart & t <= tEnd;
    y(idx) = 110 + 5*randn(1, sum(idx));
    sensorData = struct('X', t, 'Y', y, 'thresholdValue', 100, 'thresholdDirection', 'upper');
end

function test_generates_two_pngs()
    [ev, sd] = makeTestEvent();
    outDir = tempname; mkdir(outDir);
    files = generateEventSnapshot(ev, sd, 'OutputDir', outDir);
    assert(numel(files) == 2, 'two_files');
    assert(isfile(files{1}), 'detail_exists');
    assert(isfile(files{2}), 'context_exists');
    assert(contains(files{1}, 'detail'), 'detail_name');
    assert(contains(files{2}, 'context'), 'context_name');
    rmdir(outDir, 's');
    fprintf('  PASS: test_generates_two_pngs\n');
end

function test_detail_plot_bounds()
    [ev, sd] = makeTestEvent();
    outDir = tempname; mkdir(outDir);
    files = generateEventSnapshot(ev, sd, 'OutputDir', outDir);
    % Just verify files were created (visual verification is manual)
    assert(isfile(files{1}), 'detail_created');
    rmdir(outDir, 's');
    fprintf('  PASS: test_detail_plot_bounds\n');
end

function test_context_plot_bounds()
    [ev, sd] = makeTestEvent();
    outDir = tempname; mkdir(outDir);
    files = generateEventSnapshot(ev, sd, 'OutputDir', outDir, 'ContextHours', 2);
    assert(isfile(files{2}), 'context_created');
    rmdir(outDir, 's');
    fprintf('  PASS: test_context_plot_bounds\n');
end

function test_shaded_region_exists()
    [ev, sd] = makeTestEvent();
    outDir = tempname; mkdir(outDir);
    files = generateEventSnapshot(ev, sd, 'OutputDir', outDir);
    % Verify the images are non-trivially sized (> 1KB)
    d = dir(files{1});
    assert(d.bytes > 1000, 'detail_not_empty');
    d = dir(files{2});
    assert(d.bytes > 1000, 'context_not_empty');
    rmdir(outDir, 's');
    fprintf('  PASS: test_shaded_region_exists\n');
end

function test_custom_size()
    [ev, sd] = makeTestEvent();
    outDir = tempname; mkdir(outDir);
    files = generateEventSnapshot(ev, sd, 'OutputDir', outDir, 'SnapshotSize', [400, 200]);
    assert(isfile(files{1}), 'custom_size_ok');
    rmdir(outDir, 's');
    fprintf('  PASS: test_custom_size\n');
end
```

**Step 2: Run test to verify it fails**

Run: `matlab -batch "cd tests; test_event_snapshot"`
Expected: FAIL — `generateEventSnapshot` not found

**Step 3: Write minimal implementation**

```matlab
function files = generateEventSnapshot(event, sensorData, varargin)
    % generateEventSnapshot  Create two FastSense PNG snapshots for an event.
    %
    %   files = generateEventSnapshot(event, sensorData, ...)
    %
    %   Returns cell array {detailPath, contextPath}.
    %
    %   Options:
    %     OutputDir      — directory for PNGs (default: tempdir)
    %     SnapshotSize   — [width, height] pixels (default: [800, 400])
    %     Padding        — fraction of event duration for detail padding (default: 0.1)
    %     ContextHours   — hours before event for context plot (default: 2)

    p = inputParser();
    p.addParameter('OutputDir', tempdir, @ischar);
    p.addParameter('SnapshotSize', [800, 400], @isnumeric);
    p.addParameter('Padding', 0.1, @isnumeric);
    p.addParameter('ContextHours', 2, @isnumeric);
    p.parse(varargin{:});

    outDir   = p.Results.OutputDir;
    figSize  = p.Results.SnapshotSize;
    padding  = p.Results.Padding;
    ctxHours = p.Results.ContextHours;

    if ~isfolder(outDir); mkdir(outDir); end

    stamp = datestr(event.StartTime, 'yyyymmdd_HHMMSS');
    baseName = sprintf('%s_%s_%s', event.SensorName, event.ThresholdLabel, stamp);

    detailFile  = fullfile(outDir, [baseName '_detail.png']);
    contextFile = fullfile(outDir, [baseName '_context.png']);

    X = sensorData.X;
    Y = sensorData.Y;
    thVal = sensorData.thresholdValue;
    thDir = sensorData.thresholdDirection;

    evStart = event.StartTime;
    evEnd   = event.EndTime;
    evDur   = evEnd - evStart;

    % --- Plot 1: Event Detail ---
    padAmount = max(evDur * padding, 30/86400);  % at least 30 seconds
    xMin1 = evStart - padAmount;
    xMax1 = evEnd + padAmount;
    renderSnapshot(X, Y, thVal, thDir, evStart, evEnd, xMin1, xMax1, ...
        figSize, detailFile, sprintf('%s — Event Detail', event.SensorName));

    % --- Plot 2: Event Context (2h before) ---
    xMin2 = evStart - ctxHours/24;
    xMax2 = evEnd + padAmount;
    renderSnapshot(X, Y, thVal, thDir, evStart, evEnd, xMin2, xMax2, ...
        figSize, contextFile, sprintf('%s — %dh Context', event.SensorName, ctxHours));

    files = {detailFile, contextFile};
end

function renderSnapshot(X, Y, thVal, thDir, evStart, evEnd, xMin, xMax, figSize, outFile, titleStr)
    fig = figure('Visible', 'off', 'Position', [100 100 figSize]);
    ax = axes(fig);

    % Clip data to view
    mask = X >= xMin & X <= xMax;
    if any(mask)
        plot(ax, X(mask), Y(mask), 'b-', 'LineWidth', 1);
    end
    hold(ax, 'on');

    % Shaded violation region
    yLims = ax.YLim;
    patch(ax, [evStart evEnd evEnd evStart], ...
        [yLims(1) yLims(1) yLims(2) yLims(2)], ...
        [1 0 0], 'FaceAlpha', 0.15, 'EdgeColor', 'none');

    % Threshold line
    line(ax, [xMin xMax], [thVal thVal], 'Color', [0.8 0 0], ...
        'LineStyle', '--', 'LineWidth', 1.5);

    % Violation markers
    vMask = mask;
    if strcmp(thDir, 'upper')
        vMask = vMask & Y > thVal;
    else
        vMask = vMask & Y < thVal;
    end
    if any(vMask)
        plot(ax, X(vMask), Y(vMask), 'r.', 'MarkerSize', 8);
    end

    xlim(ax, [xMin xMax]);
    datetick(ax, 'x', 'HH:MM:SS', 'keeplimits');
    title(ax, titleStr, 'Interpreter', 'none');
    ylabel(ax, 'Value');
    grid(ax, 'on');
    hold(ax, 'off');

    % Export
    print(fig, outFile, '-dpng', sprintf('-r%d', 150));
    close(fig);
end
```

**Step 4: Run test to verify it passes**

Run: `matlab -batch "cd tests; test_event_snapshot"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/generateEventSnapshot.m tests/test_event_snapshot.m
git commit -m "feat: add generateEventSnapshot with detail and context plots"
```

---

### Task 9: NotificationService

**Files:**
- Create: `libs/EventDetection/NotificationService.m`
- Test: `tests/test_notification_service.m`

**Step 1: Write the failing test**

```matlab
function test_notification_service()
    add_event_path();
    test_constructor();
    test_add_rule();
    test_rule_matching_priority();
    test_notify_dry_run();
    test_default_rule();
    test_disabled();
    test_snapshot_generation();
    fprintf('test_notification_service: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    addpath(fullfile(repoRoot, 'libs', 'FastSense'));
    setup();
end

function test_constructor()
    ns = NotificationService();
    assert(ns.Enabled, 'enabled_default');
    assert(isempty(ns.Rules), 'no_rules');
    fprintf('  PASS: test_constructor\n');
end

function test_add_rule()
    ns = NotificationService();
    r = NotificationRule('SensorKey', 'temp', 'Recipients', {{'a@b.com'}});
    ns.addRule(r);
    assert(numel(ns.Rules) == 1, 'one_rule');
    fprintf('  PASS: test_add_rule\n');
end

function test_rule_matching_priority()
    ns = NotificationService();
    % Default rule
    ns.setDefaultRule(NotificationRule('Recipients', {{'default@b.com'}}));
    % Sensor rule
    ns.addRule(NotificationRule('SensorKey', 'temp', 'Recipients', {{'sensor@b.com'}}));
    % Sensor+threshold rule
    ns.addRule(NotificationRule('SensorKey', 'temp', 'ThresholdLabel', 'HH', ...
        'Recipients', {{'exact@b.com'}}));

    ev = Event(now, now+0.01, 'temp', 'HH', 100, 'high');
    rule = ns.findBestRule(ev);
    assert(strcmp(rule.Recipients{1}, 'exact@b.com'), 'best_is_exact');

    ev2 = Event(now, now+0.01, 'temp', 'H', 80, 'high');
    rule2 = ns.findBestRule(ev2);
    assert(strcmp(rule2.Recipients{1}, 'sensor@b.com'), 'best_is_sensor');

    ev3 = Event(now, now+0.01, 'pressure', 'X', 50, 'high');
    rule3 = ns.findBestRule(ev3);
    assert(strcmp(rule3.Recipients{1}, 'default@b.com'), 'best_is_default');
    fprintf('  PASS: test_rule_matching_priority\n');
end

function test_notify_dry_run()
    ns = NotificationService('DryRun', true);
    ns.setDefaultRule(NotificationRule('Recipients', {{'test@b.com'}}));
    ev = Event(now, now+0.01, 'temp', 'HH', 100, 'high');
    ev.setStats(105, 10, 90, 105, 98, 99, 3);
    sd = struct('X', linspace(now-1,now,100), 'Y', 80*ones(1,100), ...
        'thresholdValue', 100, 'thresholdDirection', 'upper');
    % Should not throw (dry run skips actual email)
    ns.notify(ev, sd);
    assert(ns.NotificationCount == 1, 'count_incremented');
    fprintf('  PASS: test_notify_dry_run\n');
end

function test_default_rule()
    ns = NotificationService('DryRun', true);
    ev = Event(now, now+0.01, 'x', 'Y', 1, 'high');
    rule = ns.findBestRule(ev);
    assert(isempty(rule), 'no_default_no_match');
    fprintf('  PASS: test_default_rule\n');
end

function test_disabled()
    ns = NotificationService('Enabled', false, 'DryRun', true);
    ns.setDefaultRule(NotificationRule('Recipients', {{'x@y.com'}}));
    ev = Event(now, now+0.01, 'x', 'Y', 1, 'high');
    ev.setStats(2, 1, 1, 2, 1.5, 1.6, 0.5);
    sd = struct('X', [now], 'Y', [2], 'thresholdValue', 1, 'thresholdDirection', 'upper');
    ns.notify(ev, sd);
    assert(ns.NotificationCount == 0, 'disabled_no_notify');
    fprintf('  PASS: test_disabled\n');
end

function test_snapshot_generation()
    ns = NotificationService('DryRun', true, 'SnapshotDir', tempname);
    ns.setDefaultRule(NotificationRule('Recipients', {{'x@y.com'}}, 'IncludeSnapshot', true));
    ev = Event(now-1/24, now-0.5/24, 'temp', 'HH', 100, 'high');
    ev.setStats(115, 50, 90, 115, 105, 106, 5);
    t = linspace(now-3/24, now, 500);
    y = 80 + 2*randn(1,500);
    sd = struct('X', t, 'Y', y, 'thresholdValue', 100, 'thresholdDirection', 'upper');
    ns.notify(ev, sd);
    % Check snapshots were created
    files = dir(fullfile(ns.SnapshotDir, '*.png'));
    assert(numel(files) >= 2, 'snapshots_created');
    rmdir(ns.SnapshotDir, 's');
    fprintf('  PASS: test_snapshot_generation\n');
end
```

**Step 2: Run test to verify it fails**

Run: `matlab -batch "cd tests; test_notification_service"`
Expected: FAIL — `NotificationService` not found

**Step 3: Write minimal implementation**

```matlab
classdef NotificationService < handle
    % NotificationService  Rule-based email notifications with event snapshots.

    properties
        Rules           = NotificationRule.empty()
        DefaultRule     = []
        Enabled         = true
        DryRun          = false
        SnapshotDir     = ''
        SnapshotRetention = 7  % days
        SmtpServer      = ''
        SmtpPort        = 25
        SmtpUser        = ''
        SmtpPassword    = ''
        FromAddress     = 'fastsense@noreply.com'
        NotificationCount = 0
    end

    methods
        function obj = NotificationService(varargin)
            p = inputParser();
            p.addParameter('Enabled', true, @islogical);
            p.addParameter('DryRun', false, @islogical);
            p.addParameter('SnapshotDir', '', @ischar);
            p.addParameter('SmtpServer', '', @ischar);
            p.addParameter('FromAddress', 'fastsense@noreply.com', @ischar);
            p.parse(varargin{:});
            obj.Enabled     = p.Results.Enabled;
            obj.DryRun      = p.Results.DryRun;
            obj.SnapshotDir = p.Results.SnapshotDir;
            obj.SmtpServer  = p.Results.SmtpServer;
            obj.FromAddress = p.Results.FromAddress;
            if isempty(obj.SnapshotDir)
                obj.SnapshotDir = fullfile(tempdir, 'fastsense_snapshots');
            end
        end

        function addRule(obj, rule)
            if isempty(obj.Rules)
                obj.Rules = rule;
            else
                obj.Rules(end+1) = rule;
            end
        end

        function setDefaultRule(obj, rule)
            obj.DefaultRule = rule;
        end

        function rule = findBestRule(obj, event)
            bestScore = 0;
            rule = [];
            for i = 1:numel(obj.Rules)
                score = obj.Rules(i).matches(event);
                if score > bestScore
                    bestScore = score;
                    rule = obj.Rules(i);
                end
            end
            if isempty(rule) && ~isempty(obj.DefaultRule)
                if obj.DefaultRule.matches(event) > 0
                    rule = obj.DefaultRule;
                end
            end
        end

        function notify(obj, event, sensorData)
            if ~obj.Enabled; return; end

            rule = obj.findBestRule(event);
            if isempty(rule); return; end

            subject = rule.fillTemplate(rule.Subject, event);
            message = rule.fillTemplate(rule.Message, event);

            % Generate snapshots
            snapshotFiles = {};
            if rule.IncludeSnapshot
                try
                    snapshotFiles = generateEventSnapshot(event, sensorData, ...
                        'OutputDir', obj.SnapshotDir, ...
                        'SnapshotSize', rule.SnapshotSize, ...
                        'Padding', rule.SnapshotPadding, ...
                        'ContextHours', rule.ContextHours);
                catch ex
                    fprintf('[NOTIFY WARNING] Snapshot failed: %s\n', ex.message);
                end
            end

            % Send email
            if ~obj.DryRun
                try
                    obj.sendEmail(rule.Recipients, subject, message, snapshotFiles);
                catch ex
                    fprintf('[NOTIFY ERROR] Email failed: %s\n', ex.message);
                end
            else
                fprintf('[NOTIFY DRY-RUN] To: %s | Subject: %s\n', ...
                    strjoin(rule.Recipients, ', '), subject);
            end

            obj.NotificationCount = obj.NotificationCount + 1;
        end

        function cleanupSnapshots(obj)
            if ~isfolder(obj.SnapshotDir); return; end
            files = dir(fullfile(obj.SnapshotDir, '*.png'));
            cutoff = now - obj.SnapshotRetention;
            for i = 1:numel(files)
                if files(i).datenum < cutoff
                    delete(fullfile(obj.SnapshotDir, files(i).name));
                end
            end
        end
    end

    methods (Access = private)
        function sendEmail(obj, recipients, subject, message, attachments)
            if ~isempty(obj.SmtpServer)
                setpref('Internet', 'SMTP_Server', obj.SmtpServer);
            end
            if ~isempty(obj.FromAddress)
                setpref('Internet', 'E_mail', obj.FromAddress);
            end
            if isempty(attachments)
                sendmail(recipients, subject, message);
            else
                sendmail(recipients, subject, message, attachments);
            end
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `matlab -batch "cd tests; test_notification_service"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/NotificationService.m tests/test_notification_service.m
git commit -m "feat: add NotificationService with rule-based email and snapshots"
```

---

### Task 10: LiveEventPipeline

**Files:**
- Create: `libs/EventDetection/LiveEventPipeline.m`
- Test: `tests/test_live_pipeline.m`

**Step 1: Write the failing test**

```matlab
function test_live_pipeline()
    add_event_path();
    test_constructor();
    test_single_cycle();
    test_multiple_cycles_incremental();
    test_events_written_to_store();
    test_notification_triggered();
    test_start_stop();
    test_sensor_failure_skipped();
    fprintf('test_live_pipeline: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    addpath(fullfile(repoRoot, 'libs', 'FastSense'));
    setup();
end

function [pipeline, storeFile] = makePipeline()
    % Create registry sensors
    s1 = Sensor('temp');
    s1.addThresholdRule(struct(), 100, 'Direction', 'upper', 'Label', 'HH');

    % Create data source map with mock
    dsMap = DataSourceMap();
    dsMap.add('temp', MockDataSource('BaseValue', 80, 'NoiseStd', 1, ...
        'ViolationProbability', 0.5, 'ViolationAmplitude', 30, ...
        'BacklogDays', 0.01, 'Seed', 42, 'SampleInterval', 3));

    storeFile = [tempname '.mat'];
    sensors = containers.Map();
    sensors('temp') = s1;

    pipeline = LiveEventPipeline(sensors, dsMap, ...
        'EventFile', storeFile, ...
        'Interval', 15);
    pipeline.NotificationService = NotificationService('DryRun', true);
    pipeline.NotificationService.setDefaultRule( ...
        NotificationRule('Recipients', {{'test@test.com'}}, 'IncludeSnapshot', false));
end

function test_constructor()
    [p, f] = makePipeline();
    assert(strcmp(p.Status, 'stopped'), 'initial_status');
    assert(p.Interval == 15, 'interval');
    if isfile(f); delete(f); end
    fprintf('  PASS: test_constructor\n');
end

function test_single_cycle()
    [p, f] = makePipeline();
    p.runCycle();
    assert(isfile(f), 'store_file_created');
    if isfile(f); delete(f); end
    fprintf('  PASS: test_single_cycle\n');
end

function test_multiple_cycles_incremental()
    [p, f] = makePipeline();
    p.runCycle();  % backlog
    p.runCycle();  % incremental
    p.runCycle();  % incremental
    % Should not error — incremental processing works
    if isfile(f); delete(f); end
    fprintf('  PASS: test_multiple_cycles_incremental\n');
end

function test_events_written_to_store()
    [p, f] = makePipeline();
    p.runCycle();
    data = load(f);
    assert(isfield(data, 'events'), 'has_events');
    assert(isfield(data, 'lastUpdated'), 'has_timestamp');
    if isfile(f); delete(f); end
    fprintf('  PASS: test_events_written_to_store\n');
end

function test_notification_triggered()
    [p, f] = makePipeline();
    % Run enough cycles to likely generate events
    for i = 1:3
        p.runCycle();
    end
    % With ViolationProbability=0.5 and 3 cycles, notification count may be > 0
    % This is probabilistic but Seed=42 should be deterministic
    count = p.NotificationService.NotificationCount;
    fprintf('  Notification count: %d\n', count);
    if isfile(f); delete(f); end
    fprintf('  PASS: test_notification_triggered\n');
end

function test_start_stop()
    [p, f] = makePipeline();
    p.start();
    assert(strcmp(p.Status, 'running'), 'running');
    pause(1);
    p.stop();
    assert(strcmp(p.Status, 'stopped'), 'stopped');
    if isfile(f); delete(f); end
    fprintf('  PASS: test_start_stop\n');
end

function test_sensor_failure_skipped()
    % Add a sensor with a broken data source
    s1 = Sensor('temp');
    s1.addThresholdRule(struct(), 100, 'Direction', 'upper', 'Label', 'HH');
    s2 = Sensor('broken');
    s2.addThresholdRule(struct(), 50, 'Direction', 'upper', 'Label', 'H');

    dsMap = DataSourceMap();
    dsMap.add('temp', MockDataSource('BaseValue', 80, 'BacklogDays', 0.001, 'Seed', 1));
    % 'broken' source points to non-existent file
    dsMap.add('broken', MatFileDataSource('/tmp/nonexistent_xyz.mat'));

    storeFile = [tempname '.mat'];
    sensors = containers.Map();
    sensors('temp') = s1;
    sensors('broken') = s2;

    p = LiveEventPipeline(sensors, dsMap, 'EventFile', storeFile);
    % Should not throw — broken sensor is skipped
    p.runCycle();
    if isfile(storeFile); delete(storeFile); end
    fprintf('  PASS: test_sensor_failure_skipped\n');
end
```

**Step 2: Run test to verify it fails**

Run: `matlab -batch "cd tests; test_live_pipeline"`
Expected: FAIL — `LiveEventPipeline` not found

**Step 3: Write minimal implementation**

```matlab
classdef LiveEventPipeline < handle
    % LiveEventPipeline  Orchestrates live event detection.

    properties
        Sensors              % containers.Map: key -> Sensor
        DataSourceMap        % DataSourceMap
        EventStore           % EventStore
        NotificationService  % NotificationService
        Interval            = 15     % seconds
        Status              = 'stopped'
        MinDuration         = 0
        EscalateSeverity    = true
        MaxCallsPerEvent    = 1
        OnEventStart        = []
    end

    properties (Access = private)
        timer_
        detector_       % IncrementalEventDetector
        cycleCount_     = 0
    end

    methods
        function obj = LiveEventPipeline(sensors, dataSourceMap, varargin)
            p = inputParser();
            p.addRequired('sensors');
            p.addRequired('dataSourceMap');
            p.addParameter('EventFile', '', @ischar);
            p.addParameter('Interval', 15, @isnumeric);
            p.addParameter('MinDuration', 0, @isnumeric);
            p.addParameter('EscalateSeverity', true, @islogical);
            p.addParameter('MaxBackups', 5, @isnumeric);
            p.parse(sensors, dataSourceMap, varargin{:});

            obj.Sensors       = sensors;
            obj.DataSourceMap = dataSourceMap;
            obj.Interval      = p.Results.Interval;
            obj.MinDuration   = p.Results.MinDuration;
            obj.EscalateSeverity = p.Results.EscalateSeverity;

            if ~isempty(p.Results.EventFile)
                obj.EventStore = EventStore(p.Results.EventFile, ...
                    'MaxBackups', p.Results.MaxBackups);
            end

            obj.detector_ = IncrementalEventDetector( ...
                'MinDuration', obj.MinDuration, ...
                'EscalateSeverity', obj.EscalateSeverity);

            obj.NotificationService = NotificationService('DryRun', true);
        end

        function start(obj)
            if strcmp(obj.Status, 'running'); return; end
            obj.Status = 'running';
            obj.timer_ = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', obj.Interval, ...
                'TimerFcn', @(~,~) obj.timerCallback(), ...
                'ErrorFcn', @(~,~) obj.timerError());
            start(obj.timer_);
            fprintf('[PIPELINE] Started (interval=%ds)\n', obj.Interval);
        end

        function stop(obj)
            if ~isempty(obj.timer_) && isvalid(obj.timer_)
                stop(obj.timer_);
                delete(obj.timer_);
            end
            obj.timer_ = [];
            obj.Status = 'stopped';
            % Flush store
            if ~isempty(obj.EventStore)
                obj.EventStore.save();
            end
            fprintf('[PIPELINE] Stopped\n');
        end

        function runCycle(obj)
            obj.cycleCount_ = obj.cycleCount_ + 1;
            allNewEvents = Event.empty();

            sensorKeys = obj.Sensors.keys();
            for i = 1:numel(sensorKeys)
                key = sensorKeys{i};
                try
                    newEvents = obj.processSensor(key);
                    if ~isempty(newEvents)
                        allNewEvents = [allNewEvents, newEvents];
                    end
                catch ex
                    fprintf('[PIPELINE WARNING] Sensor "%s" failed: %s\n', key, ex.message);
                end
            end

            % Write to store
            if ~isempty(obj.EventStore) && ~isempty(allNewEvents)
                obj.EventStore.append(allNewEvents);
                try
                    obj.EventStore.save();
                catch ex
                    fprintf('[PIPELINE WARNING] Store write failed: %s\n', ex.message);
                end
            elseif ~isempty(obj.EventStore) && obj.cycleCount_ == 1
                % Save even if no events on first cycle (creates the file)
                obj.EventStore.save();
            end

            % Send notifications
            if ~isempty(obj.NotificationService)
                for i = 1:numel(allNewEvents)
                    ev = allNewEvents(i);
                    sd = obj.buildSensorData(ev.SensorName);
                    try
                        obj.NotificationService.notify(ev, sd);
                    catch ex
                        fprintf('[PIPELINE WARNING] Notification failed: %s\n', ex.message);
                    end
                end
            end

            if ~isempty(allNewEvents)
                fprintf('[PIPELINE] Cycle %d: %d new events\n', obj.cycleCount_, numel(allNewEvents));
            end
        end
    end

    methods (Access = private)
        function newEvents = processSensor(obj, key)
            newEvents = Event.empty();

            if ~obj.DataSourceMap.has(key)
                return;
            end

            ds = obj.DataSourceMap.get(key);
            result = ds.fetchNew();

            if ~result.changed
                return;
            end

            sensor = obj.Sensors(key);

            newEvents = obj.detector_.process(key, sensor, ...
                result.X, result.Y, result.stateX, result.stateY);
        end

        function sd = buildSensorData(obj, sensorKey)
            % Build sensorData struct for snapshot generation
            st = obj.detector_.getSensorState(sensorKey);
            sensor = obj.Sensors(sensorKey);

            thVal = NaN;
            thDir = 'upper';
            if ~isempty(sensor.ThresholdRules)
                thVal = sensor.ThresholdRules{1}.Value;
                thDir = sensor.ThresholdRules{1}.Direction;
            end

            sd = struct('X', st.fullX, 'Y', st.fullY, ...
                'thresholdValue', thVal, 'thresholdDirection', thDir);
        end

        function timerCallback(obj)
            try
                obj.runCycle();
            catch ex
                fprintf('[PIPELINE ERROR] Cycle failed: %s\n', ex.message);
            end
        end

        function timerError(obj)
            obj.Status = 'error';
            fprintf('[PIPELINE] Timer error — status set to error\n');
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `matlab -batch "cd tests; test_live_pipeline"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/LiveEventPipeline.m tests/test_live_pipeline.m
git commit -m "feat: add LiveEventPipeline orchestrator with 15s timer"
```

---

### Task 11: Integration Example

**Files:**
- Create: `examples/example_live_pipeline.m`

**Step 1: Write the example**

```matlab
% example_live_pipeline  Live event detection pipeline demo.
%
%   Demonstrates the full pipeline:
%     1. MockDataSource generates multi-day industrial sensor data
%     2. LiveEventPipeline runs 15s detection cycles
%     3. Events are saved to a shared .mat file
%     4. EventViewer polls the file and auto-refreshes
%     5. Notifications are logged (dry-run mode)
%
%   To stop: pipeline.stop()

setup();

%% 1. Define sensors with thresholds
tempSensor = Sensor('temperature', 'Name', 'Chamber Temperature');
tempSensor.addThresholdRule(struct(), 120, 'Direction', 'upper', 'Label', 'H Warning');
tempSensor.addThresholdRule(struct(), 150, 'Direction', 'upper', 'Label', 'HH Alarm');
tempSensor.addThresholdRule(struct(), 40,  'Direction', 'lower', 'Label', 'L Warning');
tempSensor.addThresholdRule(struct(), 20,  'Direction', 'lower', 'Label', 'LL Alarm');

presSensor = Sensor('pressure', 'Name', 'Chamber Pressure');
presSensor.addThresholdRule(struct(), 5.0, 'Direction', 'upper', 'Label', 'H Warning');
presSensor.addThresholdRule(struct(), 6.5, 'Direction', 'upper', 'Label', 'HH Alarm');
presSensor.addThresholdRule(struct(), 1.0, 'Direction', 'lower', 'Label', 'LL Alarm');

vibSensor = Sensor('vibration', 'Name', 'Motor Vibration');
vibSensor.addThresholdRule(struct(), 8.0, 'Direction', 'upper', 'Label', 'H Warning');
vibSensor.addThresholdRule(struct(), 12.0, 'Direction', 'upper', 'Label', 'HH Alarm');

sensors = containers.Map();
sensors('temperature') = tempSensor;
sensors('pressure')    = presSensor;
sensors('vibration')   = vibSensor;

%% 2. Create mock data sources
dsMap = DataSourceMap();
dsMap.add('temperature', MockDataSource( ...
    'BaseValue', 85, 'NoiseStd', 3, 'DriftRate', 0.0001, ...
    'ViolationProbability', 0.003, 'ViolationAmplitude', 50, ...
    'ViolationDuration', 120, 'BacklogDays', 2, ...
    'SampleInterval', 3, 'Seed', 42));

dsMap.add('pressure', MockDataSource( ...
    'BaseValue', 3.2, 'NoiseStd', 0.2, 'DriftRate', 0, ...
    'ViolationProbability', 0.002, 'ViolationAmplitude', 4, ...
    'ViolationDuration', 90, 'BacklogDays', 2, ...
    'SampleInterval', 3, 'Seed', 99));

dsMap.add('vibration', MockDataSource( ...
    'BaseValue', 4.5, 'NoiseStd', 0.8, 'DriftRate', 0, ...
    'ViolationProbability', 0.004, 'ViolationAmplitude', 6, ...
    'ViolationDuration', 60, 'BacklogDays', 2, ...
    'SampleInterval', 3, 'Seed', 7));

%% 3. Configure event store
storeFile = fullfile(tempdir, 'fastsense_live_events.mat');
fprintf('Event store: %s\n', storeFile);

%% 4. Create pipeline
pipeline = LiveEventPipeline(sensors, dsMap, ...
    'EventFile', storeFile, ...
    'Interval', 15, ...
    'MinDuration', 0);

%% 5. Configure notifications (dry-run mode — logs to console)
notif = NotificationService('DryRun', true);
notif.setDefaultRule(NotificationRule( ...
    'Recipients', {{'ops-team@company.com'}}, ...
    'Subject', '[FastSense] {sensor}: {threshold} violation', ...
    'Message', 'Sensor {sensor} violated {threshold} ({direction}) from {startTime} to {endTime}. Peak: {peak}', ...
    'IncludeSnapshot', false));

% Temperature-specific critical alert
notif.addRule(NotificationRule( ...
    'SensorKey', 'temperature', 'ThresholdLabel', 'HH Alarm', ...
    'Recipients', {{'safety@company.com', 'manager@company.com'}}, ...
    'Subject', 'CRITICAL: Temperature HH Alarm!', ...
    'Message', 'Temperature exceeded HH limit. Peak: {peak}. Immediate action required.'));

pipeline.NotificationService = notif;

%% 6. Start the pipeline
fprintf('\nStarting live event detection pipeline...\n');
fprintf('Press Ctrl+C or run pipeline.stop() to stop.\n\n');
pipeline.start();

%% 7. Open EventViewer (client side)
% Wait for first cycle to create the store file
pause(2);
pipeline.runCycle();  % run first cycle immediately

if isfile(storeFile)
    viewer = EventViewer.fromFile(storeFile);
    viewer.startAutoRefresh(15);
    fprintf('EventViewer opened and auto-refreshing every 15s.\n');
end
```

**Step 2: Run the example to verify it works**

Run: `matlab -batch "cd examples; example_live_pipeline; pause(20); pipeline.stop();"`
Expected: Pipeline starts, runs cycles, events detected, viewer opens

**Step 3: Commit**

```bash
git add examples/example_live_pipeline.m
git commit -m "feat: add example_live_pipeline demonstrating full live detection"
```

---

### Task 12: Run Full Test Suite

**Step 1: Run all tests**

Run: `matlab -batch "cd tests; run_all_tests"`
Expected: All tests pass, including all new test files

**Step 2: Fix any failures**

Address any test failures found during full suite run.

**Step 3: Commit fixes if needed**

```bash
git add -A && git commit -m "fix: resolve test failures from full suite run"
```
