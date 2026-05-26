function test_plant_log_integration_smoke()
%TEST_PLANT_LOG_INTEGRATION_SMOKE End-to-end smoke for Phase 1029.
%   Verifies that install() alone places libs/PlantLog/ on the path, and
%   exercises a full attach → addEntries → query → dedup → clear → re-add
%   cycle in a single function. Does NOT manually addpath libs/PlantLog/ —
%   that is precisely what install.m is supposed to do.

    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);   % so install() itself is callable
    install();

    % --- Path verification ---
    wStore = which('PlantLogStore');
    wEntry = which('PlantLogEntry');
    assert(~isempty(wStore), 'smoke: PlantLogStore on path after install()');
    assert(~isempty(strfind(wStore, 'PlantLog')), 'smoke: PlantLogStore path under libs/PlantLog'); %#ok<STREMP>
    assert(~isempty(wEntry), 'smoke: PlantLogEntry on path after install()');
    assert(~isempty(strfind(wEntry, 'PlantLog')), 'smoke: PlantLogEntry path under libs/PlantLog'); %#ok<STREMP>

    % --- End-to-end lifecycle ---
    s = PlantLogStore('synthetic.csv');
    assert(s.getCount() == 0, 'smoke: empty store at start');

    % Mixed-batch add: class array + struct array
    es(1) = PlantLogEntry('Timestamp', 100, 'Message', 'pump on',  'Metadata', struct('Machine', 'M1'));
    es(2) = PlantLogEntry('Timestamp', 200, 'Message', 'pump off', 'Metadata', struct('Machine', 'M1'));
    ss(1) = struct('Timestamp', 150, 'Message', 'temp warn',  'Metadata', struct('Machine', 'M2'), 'SourceFile', 'synthetic.csv', 'Id', '', 'RowHash', '');
    ss(2) = struct('Timestamp', 250, 'Message', 'cooler on',  'Metadata', struct('Machine', 'M2'), 'SourceFile', 'synthetic.csv', 'Id', '', 'RowHash', '');
    s.addEntries(es);
    s.addEntries(ss);
    assert(s.getCount() == 4, 'smoke: 4 entries after mixed add');

    % Sort invariant
    all_entries = s.getEntries();
    ts = [all_entries.Timestamp];
    assert(issorted(ts), 'smoke: entries sorted ascending by Timestamp');
    assert(isequal(ts, [100 150 200 250]), 'smoke: correct sort order');

    % Range query
    mid = s.getEntriesInRange(150, 225);
    assert(numel(mid) == 2, 'smoke: range [150,225] has 2 entries');
    midTs = [mid.Timestamp];
    assert(isequal(midTs, [150 200]), 'smoke: range entries are correct');

    % Dedup on re-add
    s.addEntries(es);
    s.addEntries(ss);
    assert(s.getCount() == 4, 'smoke: dedup holds across mixed re-add');

    % Static hash
    h = PlantLogStore.computeEntryHash('pump on', struct('Machine', 'M1'));
    assert(numel(h) == 16, 'smoke: static hash length 16');
    assert(~isempty(regexp(h, '^[0-9a-f]{16}$', 'once')), 'smoke: static hash is lowercase hex');

    % Clear + reset
    s.clear();
    assert(s.getCount() == 0, 'smoke: clear empties store');
    s.addEntries(PlantLogEntry('Timestamp', 1, 'Message', 'first-after-clear', 'Metadata', struct()));
    assert(strcmp(s.getEntries().Id, 'plog_1'), 'smoke: id counter reset after clear');

    % Independence from EventStore (integration-level)
    es_store = EventStore(tempname);
    s.clear();
    for k = 1:5
        s.addEntries(PlantLogEntry('Timestamp', k, 'Message', sprintf('plant-%d', k), 'Metadata', struct('K', k)));
    end
    evs = es_store.getEvents();
    assert(isempty(evs), 'smoke: EventStore untouched by PlantLogStore ops');
    assert(s.getCount() == 5, 'smoke: PlantLogStore populated independently of EventStore');

    fprintf('    All 9 plant_log_integration_smoke assertions passed.\n');
end
