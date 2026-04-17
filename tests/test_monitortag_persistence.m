function test_monitortag_persistence()
%TEST_MONITORTAG_PERSISTENCE Octave flat-style port of TestMonitorTagPersistence (Phase 1007-02).
%   Mirrors the 6 persistence scenarios for MonitorTag.Persist + DataStore
%   (MONITOR-09) plus grep gates + Pitfall 2 structural gate on
%   libs/SensorThreshold/MonitorTag.m and libs/FastSense/FastSenseDataStore.m.
%
%   Pitfall 2 opt-in gate: Persist=false is the default. A bound DataStore
%   with Persist=false must trigger ZERO SQLite writes. Every storeMonitor
%   call site in MonitorTag.m must sit inside an `if obj.Persist` guard
%   within 5 preceding lines.
%
%   See also test_monitortag, test_monitortag_events, test_monitortag_streaming,
%   TestMonitorTagPersistence.

    add_monitortag_persistence_path();
    TagRegistry.clear();

    % Scenarios 1-2 + grep gates + Pitfall 2 structural check run on every
    % backend (no SQLite writes are required to verify default-off behavior,
    % no-op on Persist=false, and the structural guards around storeMonitor).
    run_scenario_default_is_false_();
    run_scenario_persist_false_no_writes_();
    run_grep_gates_();
    run_pitfall_2_structural_();

    % Scenarios 3-6 exercise the actual SQLite monitors table round-trip.
    % They REQUIRE mksqlite — without it FastSenseDataStore falls back to
    % binary storage where storeMonitor/loadMonitor are intentional no-ops.
    % Skip cleanly on Octave-without-MEX so CI stays green; MATLAB (which
    % compiles mksqlite via install()) still exercises the full set.
    if exist('mksqlite', 'file') == 3
        run_scenario_persist_true_writes_();
        run_scenario_round_trip_();
        run_scenario_stale_after_mutation_();
        run_scenario_low_level_api_();
        fprintf('    All 6 persistence tests passed.\n');
    else
        fprintf('    SKIPPED scenarios 3-6: mksqlite MEX not available.\n');
        fprintf('    2 persistence tests + gates passed.\n');
    end
end

% --- Scenario 1: default Persist=false ---
function run_scenario_default_is_false_()
    TagRegistry.clear();
    parent = SensorTag('p', 'X', 1:10, 'Y', ones(1, 10));
    m = MonitorTag('m', parent, @(x, y) y > 5);
    assert(m.Persist == false, ...
        'Scenario 1: default Persist must be false (Pitfall 2)');
    assert(isempty(m.DataStore), ...
        'Scenario 1: default DataStore must be empty');
    TagRegistry.clear();
end

% --- Scenario 2: Persist=false + bound DataStore -> no writes ---
function run_scenario_persist_false_no_writes_()
    TagRegistry.clear();
    parent = SensorTag('p', 'X', 1:10, 'Y', ones(1, 10));
    ds = FastSenseDataStore(1:10, ones(1, 10));
    cleanup_obj = onCleanup(@() ds.cleanup()); %#ok<NASGU>

    m = MonitorTag('m', parent, @(x, y) y > 0.5, ...
        'DataStore', ds, 'Persist', false);
    [~, ~] = m.getXY();

    [X, ~, ~] = ds.loadMonitor('m');
    assert(isempty(X), ...
        'Scenario 2: Persist=false with DataStore bound must NOT write (Pitfall 2)');
    TagRegistry.clear();
end

% --- Scenario 3: Persist=true writes (X, Y) + staleness quad ---
function run_scenario_persist_true_writes_()
    TagRegistry.clear();
    parent = SensorTag('p', 'X', 1:10, 'Y', ones(1, 10));
    ds = FastSenseDataStore(1:10, ones(1, 10));
    cleanup_obj = onCleanup(@() ds.cleanup()); %#ok<NASGU>

    m = MonitorTag('m', parent, @(x, y) y > 0.5, ...
        'DataStore', ds, 'Persist', true);
    [~, ~] = m.getXY();

    [X, Y, meta] = ds.loadMonitor('m');
    assert(numel(X) == 10, 'Scenario 3: persisted X must have 10 points');
    assert(numel(Y) == 10, 'Scenario 3: persisted Y must have 10 points');
    assert(double(meta.num_points) == 10, ...
        'Scenario 3: quad num_points stamped at write');
    assert(meta.parent_xmin == 1, 'Scenario 3: quad parent_xmin stamped');
    assert(meta.parent_xmax == 10, 'Scenario 3: quad parent_xmax stamped');
    assert(strcmp(char(meta.parent_key), 'p'), ...
        'Scenario 3: quad parent_key stamped');
    TagRegistry.clear();
end

% --- Scenario 4: round-trip across in-process "sessions" ---
function run_scenario_round_trip_()
    TagRegistry.clear();
    parent = SensorTag('p', 'X', 1:10, 'Y', ones(1, 10) * 10);
    ds = FastSenseDataStore(1:10, ones(1, 10));
    cleanup_obj = onCleanup(@() ds.cleanup()); %#ok<NASGU>

    m1 = MonitorTag('m_rt', parent, @(x, y) y > 5, ...
        'DataStore', ds, 'Persist', true);
    [~, y1] = m1.getXY();

    TagRegistry.unregister(m1.Key);

    m2 = MonitorTag('m_rt', parent, @(x, y) y > 5, ...
        'DataStore', ds, 'Persist', true);
    [~, y2] = m2.getXY();

    assert(m2.recomputeCount_ == 0, ...
        'Scenario 4: m2 must skip recompute — loaded from disk');
    assert(isequal(y2, y1), ...
        'Scenario 4: m2 cached Y must equal m1 cached Y');
    TagRegistry.clear();
end

% --- Scenario 5: stale cache detection via quad mismatch ---
function run_scenario_stale_after_mutation_()
    TagRegistry.clear();
    parent1 = SensorTag('p', 'X', 1:10, 'Y', ones(1, 10) * 10);
    ds = FastSenseDataStore(1:10, ones(1, 10));
    cleanup_obj = onCleanup(@() ds.cleanup()); %#ok<NASGU>

    m1 = MonitorTag('m_stale', parent1, @(x, y) y > 5, ...
        'DataStore', ds, 'Persist', true);
    [~, ~] = m1.getXY();

    TagRegistry.unregister(m1.Key);
    TagRegistry.unregister(parent1.Key);
    parent2 = SensorTag('p', 'X', 1:15, 'Y', ones(1, 15) * 10);

    m2 = MonitorTag('m_stale', parent2, @(x, y) y > 5, ...
        'DataStore', ds, 'Persist', true);
    [~, y2] = m2.getXY();

    assert(m2.recomputeCount_ == 1, ...
        'Scenario 5: quad mismatch -> recompute must run');
    assert(numel(y2) == 15, ...
        'Scenario 5: recomputed Y must match new parent length (15)');
    TagRegistry.clear();
end

% --- Scenario 6: low-level FastSenseDataStore trio ---
function run_scenario_low_level_api_()
    ds = FastSenseDataStore(1:10, ones(1, 10));
    cleanup_obj = onCleanup(@() ds.cleanup()); %#ok<NASGU>

    ds.storeMonitor('key1', [1 2 3], [0 1 0], 'parentKey', 3, 1, 3);

    [X, Y, meta] = ds.loadMonitor('key1');
    assert(isequal(X, [1 2 3]), 'Scenario 6: X round-trip');
    assert(isequal(Y, [0 1 0]), 'Scenario 6: Y round-trip');
    assert(double(meta.num_points) == 3, ...
        'Scenario 6: num_points round-trip');
    assert(meta.parent_xmin == 1, 'Scenario 6: parent_xmin round-trip');
    assert(meta.parent_xmax == 3, 'Scenario 6: parent_xmax round-trip');

    ds.clearMonitor('key1');
    [X2, ~, ~] = ds.loadMonitor('key1');
    assert(isempty(X2), 'Scenario 6: clearMonitor must delete the row');
end

% --- Grep gates ---
function run_grep_gates_()
    mt_src = fileread(monitor_tag_path_());
    assert(~isempty(regexp(mt_src, 'Persist\s*=\s*false', 'once')), ...
        'Grep gate 1: MonitorTag.m must declare `Persist = false`');
    assert(~isempty(regexp(mt_src, 'DataStore\s*=\s*\[\]', 'once')), ...
        'Grep gate 2: MonitorTag.m must declare `DataStore = []`');

    ds_src = fileread(data_store_path_());
    assert(numel(regexp(ds_src, 'function\s+storeMonitor', 'match')) == 1, ...
        'Grep gate 3: FastSenseDataStore.m must have exactly 1 `function storeMonitor`');
    assert(numel(regexp(ds_src, 'function\s+\[.*\]\s*=\s*loadMonitor', 'match')) == 1, ...
        'Grep gate 4: FastSenseDataStore.m must have exactly 1 loadMonitor multi-output');
    assert(numel(regexp(ds_src, 'function\s+clearMonitor', 'match')) == 1, ...
        'Grep gate 5: FastSenseDataStore.m must have exactly 1 `function clearMonitor`');
    assert(numel(regexp(ds_src, 'CREATE TABLE monitors', 'match')) == 1, ...
        'Grep gate 6: FastSenseDataStore.m must CREATE the monitors table');
end

% --- Pitfall 2 structural gate ---
function run_pitfall_2_structural_()
    src = fileread(monitor_tag_path_());
    lines = strsplit(src, char(10));
    nStore = 0;
    nGuarded = 0;
    for i = 1:numel(lines)
        if ~isempty(regexp(lines{i}, 'storeMonitor\s*\(', 'once'))
            nStore = nStore + 1;
            lo = max(1, i - 5);
            window = strjoin(lines(lo:i-1), char(10));
            if ~isempty(regexp(window, 'if\s+.*obj\.Persist', 'once'))
                nGuarded = nGuarded + 1;
            end
        end
    end
    assert(nStore >= 1, ...
        'Pitfall 2: at least one storeMonitor call expected in MonitorTag.m');
    assert(nStore == nGuarded, ...
        sprintf('Pitfall 2 FAIL: %d storeMonitor calls, %d guarded by if obj.Persist', ...
        nStore, nGuarded));
end

function add_monitortag_persistence_path()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    addpath(fullfile(here, 'suite'));
    install();
end

function p = monitor_tag_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    p    = fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m');
end

function p = data_store_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    p    = fullfile(repo, 'libs', 'FastSense', 'FastSenseDataStore.m');
end
