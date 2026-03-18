# ExternalSensorRegistry Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an `ExternalSensorRegistry` class that lets users explicitly define sensors and wire them to external .mat file data sources, without modifying any existing FastPlot code.

**Architecture:** Single new class `ExternalSensorRegistry` in `libs/SensorThreshold/`. It holds a `containers.Map` of Sensor objects and an internal `DataSourceMap`. Sensors are registered explicitly; data wiring is a separate step via `wireMatFile` and `wireStateChannel`. The resulting `DataSourceMap` plugs directly into the existing `LiveEventPipeline`.

**Tech Stack:** MATLAB, matlab.unittest framework

**Spec:** `docs/superpowers/specs/2026-03-18-external-sensor-registry-design.md`

---

## Chunk 1: Core Registry

### Task 1: Test — Constructor and Name property

**Files:**
- Create: `tests/suite/TestExternalSensorRegistry.m`

- [ ] **Step 1: Write the failing test**

```matlab
classdef TestExternalSensorRegistry < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstructor(testCase)
            reg = ExternalSensorRegistry('TestLab');
            testCase.verifyEqual(reg.Name, 'TestLab', 'name_set');
        end

        function testEmptyOnCreation(testCase)
            reg = ExternalSensorRegistry('TestLab');
            testCase.verifyEqual(reg.count(), 0, 'empty_count');
            testCase.verifyTrue(isempty(reg.keys()), 'empty_keys');
        end
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `matlab -batch "install(); results = runtests('tests/suite/TestExternalSensorRegistry'); disp(results)"`
Expected: FAIL — `ExternalSensorRegistry` class not found

- [ ] **Step 3: Write minimal implementation — constructor, Name, count, keys**

Create `libs/SensorThreshold/ExternalSensorRegistry.m`:

```matlab
classdef ExternalSensorRegistry < handle
    %EXTERNALSENSORREGISTRY Non-singleton sensor registry for external data.
    %   ExternalSensorRegistry holds explicitly registered Sensor objects
    %   and wires them to .mat file data sources for use with
    %   LiveEventPipeline.
    %
    %   Unlike SensorRegistry (singleton with hardcoded catalog), this
    %   class supports multiple instances and is populated via register().
    %
    %   See also SensorRegistry, Sensor, DataSourceMap.

    properties
        Name  % char: human-readable label for this registry
    end

    properties (Access = private)
        catalog_  % containers.Map (char -> Sensor)
        dsMap_    % DataSourceMap
    end

    methods
        function obj = ExternalSensorRegistry(name)
            %EXTERNALSENSORREGISTRY Construct a named registry.
            %   reg = ExternalSensorRegistry('MyLab')
            obj.Name = name;
            obj.catalog_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.dsMap_ = DataSourceMap();
        end

        function n = count(obj)
            %COUNT Number of registered sensors.
            n = double(obj.catalog_.Count);
        end

        function k = keys(obj)
            %KEYS Return all registered sensor keys.
            k = obj.catalog_.keys();
        end
    end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `matlab -batch "install(); results = runtests('tests/suite/TestExternalSensorRegistry'); disp(results)"`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add tests/suite/TestExternalSensorRegistry.m libs/SensorThreshold/ExternalSensorRegistry.m
git commit -m "feat: add ExternalSensorRegistry constructor with count/keys"
```

---

### Task 2: Test and implement — register, get, unregister

**Files:**
- Modify: `tests/suite/TestExternalSensorRegistry.m`
- Modify: `libs/SensorThreshold/ExternalSensorRegistry.m`

- [ ] **Step 1: Add failing tests**

Add to the `methods (Test)` block in `TestExternalSensorRegistry.m`:

```matlab
function testRegisterAndGet(testCase)
    reg = ExternalSensorRegistry('TestLab');
    s = Sensor('temp', 'Name', 'Temperature');
    reg.register('temp', s);
    out = reg.get('temp');
    testCase.verifyEqual(out.Key, 'temp', 'get_key');
    testCase.verifyEqual(out.Name, 'Temperature', 'get_name');
    testCase.verifyEqual(reg.count(), 1, 'count_after_register');
end

function testGetUnknownKeyThrows(testCase)
    reg = ExternalSensorRegistry('TestLab');
    threw = false;
    try
        reg.get('nonexistent');
    catch
        threw = true;
    end
    testCase.verifyTrue(threw, 'should_throw');
end

function testUnregister(testCase)
    reg = ExternalSensorRegistry('TestLab');
    reg.register('temp', Sensor('temp'));
    reg.unregister('temp');
    testCase.verifyEqual(reg.count(), 0, 'empty_after_unregister');
end

function testGetMultiple(testCase)
    reg = ExternalSensorRegistry('TestLab');
    reg.register('a', Sensor('a'));
    reg.register('b', Sensor('b'));
    out = reg.getMultiple({'a', 'b'});
    testCase.verifyEqual(numel(out), 2, 'getMultiple_count');
    testCase.verifyEqual(out{1}.Key, 'a', 'getMultiple_key1');
    testCase.verifyEqual(out{2}.Key, 'b', 'getMultiple_key2');
end

function testGetAll(testCase)
    reg = ExternalSensorRegistry('TestLab');
    reg.register('a', Sensor('a'));
    reg.register('b', Sensor('b'));
    m = reg.getAll();
    testCase.verifyTrue(isa(m, 'containers.Map'), 'getAll_type');
    testCase.verifyEqual(m.Count, uint64(2), 'getAll_count');
end

function testGetAllReturnsCopy(testCase)
    reg = ExternalSensorRegistry('TestLab');
    reg.register('a', Sensor('a'));
    m = reg.getAll();
    m('injected') = Sensor('injected');
    % Original registry should be unaffected
    testCase.verifyEqual(reg.count(), 1, 'copy_not_mutated');
end

function testRegisterNonSensorThrows(testCase)
    reg = ExternalSensorRegistry('TestLab');
    threw = false;
    try
        reg.register('bad', struct('Key', 'bad'));
    catch
        threw = true;
    end
    testCase.verifyTrue(threw, 'should_throw_non_sensor');
end

function testUnregisterNonexistentNoError(testCase)
    reg = ExternalSensorRegistry('TestLab');
    reg.unregister('nonexistent');  % should not error
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `matlab -batch "install(); results = runtests('tests/suite/TestExternalSensorRegistry'); disp(results)"`
Expected: FAIL — `register`, `get`, etc. not defined

- [ ] **Step 3: Implement register, get, unregister, getMultiple, getAll**

Add to the `methods` block of `ExternalSensorRegistry.m`:

```matlab
function register(obj, key, sensor)
    %REGISTER Add a Sensor to the catalog.
    %   reg.register('key', sensorObj)
    assert(isa(sensor, 'Sensor'), ...
        'ExternalSensorRegistry:invalidType', ...
        'Value must be a Sensor object.');
    obj.catalog_(key) = sensor;
end

function unregister(obj, key)
    %UNREGISTER Remove a Sensor from the catalog.
    if obj.catalog_.isKey(key)
        obj.catalog_.remove(key);
    end
end

function s = get(obj, key)
    %GET Retrieve a sensor by key.
    if ~obj.catalog_.isKey(key)
        error('ExternalSensorRegistry:unknownKey', ...
            'No sensor with key ''%s'' in registry ''%s''.', key, obj.Name);
    end
    s = obj.catalog_(key);
end

function sensors = getMultiple(obj, keys)
    %GETMULTIPLE Retrieve multiple sensors by key.
    sensors = cell(1, numel(keys));
    for i = 1:numel(keys)
        sensors{i} = obj.get(keys{i});
    end
end

function m = getAll(obj)
    %GETALL Return a copy of the catalog as a containers.Map.
    m = containers.Map(obj.catalog_.keys(), obj.catalog_.values());
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `matlab -batch "install(); results = runtests('tests/suite/TestExternalSensorRegistry'); disp(results)"`
Expected: PASS (10 tests)

- [ ] **Step 5: Commit**

```bash
git add tests/suite/TestExternalSensorRegistry.m libs/SensorThreshold/ExternalSensorRegistry.m
git commit -m "feat: add register/get/unregister/getMultiple/getAll to ExternalSensorRegistry"
```

---

### Task 3: Test and implement — list and printTable

**Files:**
- Modify: `tests/suite/TestExternalSensorRegistry.m`
- Modify: `libs/SensorThreshold/ExternalSensorRegistry.m`

- [ ] **Step 1: Add failing tests**

Add to `methods (Test)`:

```matlab
function testListNoError(testCase)
    reg = ExternalSensorRegistry('TestLab');
    reg.register('temp', Sensor('temp', 'Name', 'Temperature'));
    reg.list();  % should not error
end

function testListEmpty(testCase)
    reg = ExternalSensorRegistry('TestLab');
    reg.list();  % should not error on empty registry
end

function testPrintTableNoError(testCase)
    reg = ExternalSensorRegistry('TestLab');
    reg.register('temp', Sensor('temp', 'Name', 'Temperature', 'ID', 1));
    reg.printTable();  % should not error
end

function testPrintTableEmpty(testCase)
    reg = ExternalSensorRegistry('TestLab');
    reg.printTable();  % should not error on empty registry
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `matlab -batch "install(); results = runtests('tests/suite/TestExternalSensorRegistry'); disp(results)"`
Expected: FAIL — `list` and `printTable` not defined

- [ ] **Step 3: Implement list and printTable**

Add to the `methods` block of `ExternalSensorRegistry.m`. Follow the same pattern as `SensorRegistry.list()` and `SensorRegistry.printTable()` (see `libs/SensorThreshold/SensorRegistry.m:78-156`), but operate on `obj.catalog_` instead of the static `catalog()`:

```matlab
function list(obj)
    %LIST Print all registered sensor keys and names.
    ks = sort(obj.catalog_.keys());
    fprintf('\n  [%s] Available sensors:\n', obj.Name);
    for i = 1:numel(ks)
        s = obj.catalog_(ks{i});
        name = s.Name;
        if isempty(name); name = '(no name)'; end
        fprintf('    %-25s  %s\n', ks{i}, name);
    end
    fprintf('\n');
end

function printTable(obj)
    %PRINTTABLE Print a detailed table of all registered sensors.
    ks = sort(obj.catalog_.keys());
    nSensors = numel(ks);
    if nSensors == 0
        fprintf('No sensors registered in ''%s''.\n', obj.Name);
        return;
    end
    fprintf('\n  [%s]\n', obj.Name);
    fprintf('  %-20s %-25s %6s  %-20s %-20s %7s %6s %8s\n', ...
        'Key', 'Name', 'ID', 'Source', 'MatFile', '#States', '#Rules', '#Points');
    fprintf('  %s\n', repmat('-', 1, 118));
    for i = 1:nSensors
        s = obj.catalog_(ks{i});
        name = s.Name; if isempty(name); name = ''; end
        idStr = ''; if ~isempty(s.ID); idStr = num2str(s.ID); end
        nStates = numel(s.StateChannels);
        nRules  = numel(s.ThresholdRules);
        nPts    = numel(s.X);
        fprintf('  %-20s %-25s %6s  %-20s %-20s %7d %6d %8d\n', ...
            ExternalSensorRegistry.truncStr(ks{i}, 20), ...
            ExternalSensorRegistry.truncStr(name, 25), ...
            idStr, ...
            ExternalSensorRegistry.truncStr(s.Source, 20), ...
            ExternalSensorRegistry.truncStr(s.MatFile, 20), ...
            nStates, nRules, nPts);
    end
    fprintf('\n  %d sensor(s) total.\n\n', nSensors);
end
```

Also add a private static helper (add a new `methods (Static, Access = private)` block):

```matlab
methods (Static, Access = private)
    function s = truncStr(s, maxLen)
        if isempty(s); s = ''; end
        if numel(s) > maxLen
            s = [s(1:maxLen-2), '..'];
        end
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `matlab -batch "install(); results = runtests('tests/suite/TestExternalSensorRegistry'); disp(results)"`
Expected: PASS (14 tests)

- [ ] **Step 5: Commit**

```bash
git add tests/suite/TestExternalSensorRegistry.m libs/SensorThreshold/ExternalSensorRegistry.m
git commit -m "feat: add list/printTable to ExternalSensorRegistry"
```

---

## Chunk 2: Data Wiring

### Task 4: Test and implement — wireMatFile

**Files:**
- Modify: `tests/suite/TestExternalSensorRegistry.m`
- Modify: `libs/SensorThreshold/ExternalSensorRegistry.m`

- [ ] **Step 1: Create a test .mat fixture**

Add a `TestMethodSetup` block that creates a temporary .mat file:

```matlab
properties
    TempDir
end

methods (TestMethodSetup)
    function createTempDir(testCase)
        testCase.TempDir = tempname();
        mkdir(testCase.TempDir);
        testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
    end
end
```

- [ ] **Step 2: Add failing tests for wireMatFile**

Add to `methods (Test)`:

```matlab
function testWireMatFile(testCase)
    % Create a .mat file with two signals
    time = [1 2 3 4 5];
    temp_bearing = [20 21 22 23 24];
    press_oil = [5 5.1 5.2 5.3 5.4];
    matPath = fullfile(testCase.TempDir, 'data.mat');
    save(matPath, 'time', 'temp_bearing', 'press_oil');

    reg = ExternalSensorRegistry('TestLab');
    reg.register('bearing_temp', Sensor('bearing_temp'));
    reg.register('oil_pressure', Sensor('oil_pressure'));

    reg.wireMatFile(matPath, {
        'bearing_temp',  'XVar', 'time', 'YVar', 'temp_bearing';
        'oil_pressure',  'XVar', 'time', 'YVar', 'press_oil';
    });

    % Verify Sensor properties were set
    s1 = reg.get('bearing_temp');
    testCase.verifyEqual(s1.MatFile, matPath, 'matfile_set');

    % Verify DataSourceMap was populated
    dsMap = reg.getDataSourceMap();
    testCase.verifyTrue(dsMap.has('bearing_temp'), 'ds_bearing');
    testCase.verifyTrue(dsMap.has('oil_pressure'), 'ds_oil');
end

function testWireMatFileUnknownKeyThrows(testCase)
    matPath = fullfile(testCase.TempDir, 'empty.mat');
    x = 1; save(matPath, 'x');

    reg = ExternalSensorRegistry('TestLab');
    threw = false;
    try
        reg.wireMatFile(matPath, {'nonexistent', 'XVar', 'x', 'YVar', 'x'});
    catch
        threw = true;
    end
    testCase.verifyTrue(threw, 'should_throw_unknown_key');
end

function testWireMatFileDuplicateWarns(testCase)
    time = [1 2 3]; val = [10 20 30];
    matPath = fullfile(testCase.TempDir, 'data.mat');
    save(matPath, 'time', 'val');

    reg = ExternalSensorRegistry('TestLab');
    reg.register('s1', Sensor('s1'));
    reg.wireMatFile(matPath, {'s1', 'XVar', 'time', 'YVar', 'val'});

    % Wire again — should warn but not error
    reg.wireMatFile(matPath, {'s1', 'XVar', 'time', 'YVar', 'val'});

    % Should still work
    dsMap = reg.getDataSourceMap();
    testCase.verifyTrue(dsMap.has('s1'), 'still_wired');
end

function testGetDataSourceMap(testCase)
    reg = ExternalSensorRegistry('TestLab');
    dsMap = reg.getDataSourceMap();
    testCase.verifyTrue(isa(dsMap, 'DataSourceMap'), 'returns_dsmap');
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `matlab -batch "install(); results = runtests('tests/suite/TestExternalSensorRegistry'); disp(results)"`
Expected: FAIL — `wireMatFile` and `getDataSourceMap` not defined

- [ ] **Step 4: Implement wireMatFile and getDataSourceMap**

Add to the `methods` block of `ExternalSensorRegistry.m`:

```matlab
function wireMatFile(obj, matFilePath, mappings)
    %WIREMATFILE Wire .mat file fields to registered sensor keys.
    %   reg.wireMatFile('data.mat', {
    %       'sensorKey', 'XVar', 'time', 'YVar', 'value';
    %   })
    %
    %   Each row of mappings: {sensorKey, 'XVar', xField, 'YVar', yField}
    for i = 1:size(mappings, 1)
        key = mappings{i, 1};
        if ~obj.catalog_.isKey(key)
            error('ExternalSensorRegistry:unknownKey', ...
                'Cannot wire ''%s'': not registered in ''%s''.', key, obj.Name);
        end

        % Parse name-value pairs from remaining columns
        nvPairs = mappings(i, 2:end);
        p = inputParser();
        p.addParameter('XVar', 'X', @ischar);
        p.addParameter('YVar', 'Y', @ischar);
        p.parse(nvPairs{:});

        % Set Sensor properties
        s = obj.catalog_(key);
        s.MatFile = matFilePath;
        s.KeyName = p.Results.YVar;

        % Create MatFileDataSource
        ds = MatFileDataSource(matFilePath, ...
            'XVar', p.Results.XVar, 'YVar', p.Results.YVar);

        % Warn on overwrite
        if obj.dsMap_.has(key)
            warning('ExternalSensorRegistry:overwrite', ...
                'Overwriting data source for ''%s'' in ''%s''.', key, obj.Name);
        end
        obj.dsMap_.add(key, ds);
    end
end

function dsMap = getDataSourceMap(obj)
    %GETDATASOURCEMAP Return the DataSourceMap for pipeline use.
    dsMap = obj.dsMap_;
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `matlab -batch "install(); results = runtests('tests/suite/TestExternalSensorRegistry'); disp(results)"`
Expected: PASS (18 tests)

- [ ] **Step 6: Commit**

```bash
git add tests/suite/TestExternalSensorRegistry.m libs/SensorThreshold/ExternalSensorRegistry.m
git commit -m "feat: add wireMatFile and getDataSourceMap to ExternalSensorRegistry"
```

---

### Task 5: Test and implement — wireStateChannel

**Files:**
- Modify: `tests/suite/TestExternalSensorRegistry.m`
- Modify: `libs/SensorThreshold/ExternalSensorRegistry.m`

- [ ] **Step 1: Add failing tests for wireStateChannel**

Add to `methods (Test)`:

```matlab
function testWireStateChannelSameFile(testCase)
    % State data in same file as sensor data
    time = [1 2 3 4 5];
    val = [10 20 30 40 50];
    state_time = [1 3];
    state_val = {{'idle', 'running'}};
    matPath = fullfile(testCase.TempDir, 'combined.mat');
    save(matPath, 'time', 'val', 'state_time', 'state_val');

    reg = ExternalSensorRegistry('TestLab');
    reg.register('s1', Sensor('s1'));
    reg.wireMatFile(matPath, {'s1', 'XVar', 'time', 'YVar', 'val'});
    reg.wireStateChannel('s1', 'machine_state', matPath, ...
        'XVar', 'state_time', 'YVar', 'state_val');

    s = reg.get('s1');
    testCase.verifyEqual(numel(s.StateChannels), 1, 'one_state_channel');
    testCase.verifyEqual(s.StateChannels{1}.Key, 'machine_state', 'sc_key');

    % For same-file case, DataSource should have StateXVar/StateYVar set
    ds = reg.getDataSourceMap().get('s1');
    testCase.verifyEqual(ds.StateXVar, 'state_time', 'ds_stateXVar');
    testCase.verifyEqual(ds.StateYVar, 'state_val', 'ds_stateYVar');
end

function testWireStateChannelDifferentFile(testCase)
    % Sensor data in one file, state data in another
    time = [1 2 3 4 5]; val = [10 20 30 40 50];
    sensorPath = fullfile(testCase.TempDir, 'sensor.mat');
    save(sensorPath, 'time', 'val');

    state_time = [1 3]; state_val = {{'idle', 'running'}};
    statePath = fullfile(testCase.TempDir, 'states.mat');
    save(statePath, 'state_time', 'state_val');

    reg = ExternalSensorRegistry('TestLab');
    reg.register('s1', Sensor('s1'));
    reg.wireMatFile(sensorPath, {'s1', 'XVar', 'time', 'YVar', 'val'});
    reg.wireStateChannel('s1', 'machine_state', statePath, ...
        'XVar', 'state_time', 'YVar', 'state_val');

    s = reg.get('s1');
    testCase.verifyEqual(numel(s.StateChannels), 1, 'one_state_channel');
    sc = s.StateChannels{1};
    testCase.verifyEqual(sc.MatFile, statePath, 'sc_matfile');
    testCase.verifyEqual(sc.KeyName, 'state_val', 'sc_keyname');

    % DataSource should NOT have StateXVar set (different file)
    ds = reg.getDataSourceMap().get('s1');
    testCase.verifyEqual(ds.StateXVar, '', 'ds_no_stateXVar');
end

function testWireStateChannelUnknownSensorThrows(testCase)
    reg = ExternalSensorRegistry('TestLab');
    threw = false;
    try
        reg.wireStateChannel('nonexistent', 'state', 'file.mat', ...
            'XVar', 'x', 'YVar', 'y');
    catch
        threw = true;
    end
    testCase.verifyTrue(threw, 'should_throw');
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `matlab -batch "install(); results = runtests('tests/suite/TestExternalSensorRegistry'); disp(results)"`
Expected: FAIL — `wireStateChannel` not defined

- [ ] **Step 3: Implement wireStateChannel**

Add to the `methods` block of `ExternalSensorRegistry.m`:

```matlab
function wireStateChannel(obj, sensorKey, stateKey, matFilePath, varargin)
    %WIRESTATECHANNEL Wire state channel data to a registered sensor.
    %   reg.wireStateChannel('sensorKey', 'stateKey', 'states.mat', ...
    %       'XVar', 'state_time', 'YVar', 'state_val')
    if ~obj.catalog_.isKey(sensorKey)
        error('ExternalSensorRegistry:unknownKey', ...
            'Cannot wire state to ''%s'': not registered in ''%s''.', ...
            sensorKey, obj.Name);
    end

    p = inputParser();
    p.addParameter('XVar', 'X', @ischar);
    p.addParameter('YVar', 'Y', @ischar);
    p.parse(varargin{:});

    % Create StateChannel
    % Note: For different-file state channels, the caller must populate
    % sc.X and sc.Y manually (or via MatFileDataSource with state vars),
    % because StateChannel.load() is not yet implemented.
    sc = StateChannel(stateKey, 'MatFile', matFilePath, ...
        'KeyName', p.Results.YVar);

    % Attach to sensor
    s = obj.catalog_(sensorKey);
    s.addStateChannel(sc);

    % If same file as sensor data, update existing DataSource
    if obj.dsMap_.has(sensorKey)
        ds = obj.dsMap_.get(sensorKey);
        if strcmp(ds.FilePath, matFilePath)
            ds.StateXVar = p.Results.XVar;
            ds.StateYVar = p.Results.YVar;
        end
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `matlab -batch "install(); results = runtests('tests/suite/TestExternalSensorRegistry'); disp(results)"`
Expected: PASS (21 tests — wireStateChannel)

- [ ] **Step 5: Commit**

```bash
git add tests/suite/TestExternalSensorRegistry.m libs/SensorThreshold/ExternalSensorRegistry.m
git commit -m "feat: add wireStateChannel to ExternalSensorRegistry"
```

---

## Chunk 3: Viewer and Integration

### Task 6: Test and implement — viewer

**Files:**
- Modify: `tests/suite/TestExternalSensorRegistry.m`
- Modify: `libs/SensorThreshold/ExternalSensorRegistry.m`

- [ ] **Step 1: Add failing test**

Add to `methods (Test)`:

```matlab
function testViewer(testCase)
    reg = ExternalSensorRegistry('TestLab');
    reg.register('temp', Sensor('temp', 'Name', 'Temperature', 'ID', 1));
    hFig = reg.viewer();
    testCase.addTeardown(@close, hFig);
    testCase.verifyTrue(ishandle(hFig), 'returns_figure');
end

function testViewerEmpty(testCase)
    reg = ExternalSensorRegistry('TestLab');
    hFig = reg.viewer();
    testCase.addTeardown(@close, hFig);
    testCase.verifyTrue(ishandle(hFig), 'handles_empty');
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `matlab -batch "install(); results = runtests('tests/suite/TestExternalSensorRegistry'); disp(results)"`
Expected: FAIL — `viewer` not defined

- [ ] **Step 3: Implement viewer**

Add to the `methods` block of `ExternalSensorRegistry.m`. Follow the same pattern as `SensorRegistry.viewer()` (see `libs/SensorThreshold/SensorRegistry.m:158-216`), but operate on `obj.catalog_` and include `obj.Name` in the figure title:

```matlab
function hFig = viewer(obj)
    %VIEWER Open a GUI figure showing all registered sensors.
    ks = sort(obj.catalog_.keys());
    nSensors = numel(ks);

    colNames = {'Key', 'Name', 'ID', 'Source', 'MatFile', '#States', '#Rules', '#Points'};
    data = cell(nSensors, numel(colNames));
    for i = 1:nSensors
        s = obj.catalog_(ks{i});
        data{i,1} = ks{i};
        data{i,2} = s.Name;
        if isempty(s.ID); data{i,3} = ''; else; data{i,3} = s.ID; end
        data{i,4} = s.Source;
        data{i,5} = s.MatFile;
        data{i,6} = numel(s.StateChannels);
        data{i,7} = numel(s.ThresholdRules);
        data{i,8} = numel(s.X);
    end

    hFig = figure('Name', sprintf('%s — Sensor Registry', obj.Name), ...
        'NumberTitle', 'off', ...
        'Position', [200 200 900 400], ...
        'Color', [0.15 0.15 0.18], ...
        'MenuBar', 'none', 'ToolBar', 'none');

    uicontrol('Parent', hFig, 'Style', 'text', ...
        'String', sprintf('%s  (%d sensors)', obj.Name, nSensors), ...
        'Units', 'normalized', 'Position', [0.02 0.92 0.96 0.06], ...
        'BackgroundColor', [0.15 0.15 0.18], ...
        'ForegroundColor', [0.9 0.9 0.9], ...
        'FontSize', 14, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');

    colWidths = {140, 180, 50, 140, 140, 55, 50, 60};
    uitable('Parent', hFig, ...
        'Data', data, 'ColumnName', colNames, ...
        'ColumnWidth', colWidths, ...
        'Units', 'normalized', 'Position', [0.02 0.02 0.96 0.88], ...
        'RowName', [], ...
        'BackgroundColor', [0.22 0.22 0.25; 0.18 0.18 0.21], ...
        'ForegroundColor', [0.9 0.9 0.9], 'FontSize', 11);
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `matlab -batch "install(); results = runtests('tests/suite/TestExternalSensorRegistry'); disp(results)"`
Expected: PASS (23 tests)

- [ ] **Step 5: Commit**

```bash
git add tests/suite/TestExternalSensorRegistry.m libs/SensorThreshold/ExternalSensorRegistry.m
git commit -m "feat: add viewer to ExternalSensorRegistry"
```

---

### Task 7: Integration test — LiveEventPipeline round-trip

**Files:**
- Modify: `tests/suite/TestExternalSensorRegistry.m`

- [ ] **Step 1: Add integration test**

This test verifies that `ExternalSensorRegistry` produces outputs compatible with `LiveEventPipeline`:

```matlab
function testLivePipelineCompatibility(testCase)
    % Create .mat file with sensor data
    time = linspace(now - 1, now, 100);
    temp = randn(1, 100) * 5 + 50;
    matPath = fullfile(testCase.TempDir, 'live.mat');
    save(matPath, 'time', 'temp');

    % Build registry
    reg = ExternalSensorRegistry('IntegrationTest');
    s = Sensor('temp', 'Name', 'Temperature', 'Units', 'degC');
    s.addThresholdRule(struct(), 60, 'Direction', 'upper', 'Label', 'Warning');
    reg.register('temp', s);
    reg.wireMatFile(matPath, {'temp', 'XVar', 'time', 'YVar', 'temp'});

    % Verify outputs are the right types for LiveEventPipeline
    dsMap = reg.getDataSourceMap();
    sensors = reg.getAll();

    testCase.verifyTrue(isa(dsMap, 'DataSourceMap'), 'dsMap_type');
    testCase.verifyTrue(isa(sensors, 'containers.Map'), 'sensors_type');

    % Verify DataSource can fetch data
    ds = dsMap.get('temp');
    result = ds.fetchNew();
    testCase.verifyTrue(result.changed, 'fetched_data');
    testCase.verifyEqual(numel(result.X), 100, 'all_points');
end
```

- [ ] **Step 2: Run test to verify it passes**

Run: `matlab -batch "install(); results = runtests('tests/suite/TestExternalSensorRegistry'); disp(results)"`
Expected: PASS (24 tests)

- [ ] **Step 3: Commit**

```bash
git add tests/suite/TestExternalSensorRegistry.m
git commit -m "test: add LiveEventPipeline compatibility integration test"
```
