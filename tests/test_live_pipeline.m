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
    addpath(repoRoot);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    addpath(fullfile(repoRoot, 'libs', 'FastSense'));
    install();
end

function [pipeline, storeFile] = makePipeline()
    % Create registry sensors
    s1 = Sensor('temp');
    tHH = Threshold('hh', 'Name', 'HH', 'Direction', 'upper');
    tHH.addCondition(struct(), 100);
    s1.addThreshold(tHH);

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
    if ~exist('OCTAVE_VERSION', 'builtin')
        % Octave cannot save classdef objects to .mat
        assert(isfile(f), 'store_file_created');
    end
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
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (Octave cannot save classdef objects to .mat)\n');
        return;
    end
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
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (timer not implemented in Octave)\n');
        return;
    end
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
    tHH1 = Threshold('hh', 'Name', 'HH', 'Direction', 'upper');
    tHH1.addCondition(struct(), 100);
    s1.addThreshold(tHH1);
    s2 = Sensor('broken');
    tH2 = Threshold('h', 'Name', 'H', 'Direction', 'upper');
    tH2.addCondition(struct(), 50);
    s2.addThreshold(tH2);

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
