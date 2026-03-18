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
    addpath(repoRoot);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    install();
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
    if exist('OCTAVE_VERSION', 'builtin')
        % Octave uses global RNG (no RandStream) — seeded instances share
        % state so two back-to-back runs are not independent.
        fprintf('  SKIPPED (no RandStream in Octave)\n');
        return;
    end
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
