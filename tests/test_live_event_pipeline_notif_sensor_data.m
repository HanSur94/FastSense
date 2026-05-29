function test_live_event_pipeline_notif_sensor_data()
%TEST_LIVE_EVENT_PIPELINE_NOTIF_SENSOR_DATA Lock down Plan 01's runCycle sensorData fix.
%   Proves that LiveEventPipeline.runCycle passes populated sensorData
%   (with non-empty .X and .Y) to NotificationService.notify, NOT struct().
%
%   See also CaptureNotificationService, LiveEventPipeline.
%   Phase 1039 Plan 04.

    add_test_path_();
    TagRegistry.clear();
    EventBinding.clear();
    cleaner = onCleanup(@() cleanup_()); %#ok<NASGU>

    test_notify_receives_populated_sensor_data();
    test_notify_sensor_data_has_threshold_fields();

    fprintf('    All 2 live_event_pipeline_notif_sensor_data tests passed.\n');
end

function add_test_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    install();
    addpath(fullfile(repo, 'tests'));
    addpath(fullfile(repo, 'tests', 'suite'));
end

function cleanup_()
    TagRegistry.clear();
    EventBinding.clear();
end

function test_notify_receives_populated_sensor_data()
    [pipeline, cap, ds, ~] = make_fixture_();

    % Tail samples include values above the monitor's threshold (y > 15) so
    % at least one event is emitted on this tick.
    ds.setNextResult(struct('changed', true, ...
        'X', 6:10, 'Y', [1 1 20 20 1], ...
        'stateX', [], 'stateY', {{}}));

    pipeline.runCycle();

    assert(~isempty(cap.LastEvent), ...
        'notify must have been called at least once (no event captured)');
    sd = cap.LastSensorData();
    assert(isstruct(sd), 'sensorData must be a struct, got %s', class(sd));
    assert(isfield(sd, 'X') && isfield(sd, 'Y'), ...
        'sensorData must have fields .X and .Y');
    assert(~isempty(sd.X), 'sensorData.X must be non-empty (Plan 01 D-02 bug fix)');
    assert(~isempty(sd.Y), 'sensorData.Y must be non-empty (Plan 01 D-02 bug fix)');
    assert(numel(sd.X) == numel(sd.Y), ...
        'sensorData.X and .Y must have the same length (X=%d, Y=%d)', ...
        numel(sd.X), numel(sd.Y));
    fprintf('  PASS: test_notify_receives_populated_sensor_data\n');
end

function test_notify_sensor_data_has_threshold_fields()
    [pipeline, cap, ds, ~] = make_fixture_();

    ds.setNextResult(struct('changed', true, ...
        'X', 6:10, 'Y', [1 1 20 20 1], ...
        'stateX', [], 'stateY', {{}}));
    pipeline.runCycle();

    sd = cap.LastSensorData();
    assert(isfield(sd, 'thresholdValue'), ...
        'sensorData must carry .thresholdValue (generateEventSnapshot contract)');
    assert(isfield(sd, 'thresholdDirection'), ...
        'sensorData must carry .thresholdDirection (generateEventSnapshot contract)');
    assert(ischar(sd.thresholdDirection) || (isstring(sd.thresholdDirection) && isscalar(sd.thresholdDirection)), ...
        'sensorData.thresholdDirection must be char/string; got %s', class(sd.thresholdDirection));
    fprintf('  PASS: test_notify_sensor_data_has_threshold_fields\n');
end

function [pipeline, cap, ds, monitor] = make_fixture_()
    TagRegistry.clear();
    EventBinding.clear();

    parent  = SensorTag('s1', 'X', 1:5, 'Y', [1 1 1 1 1]);
    TagRegistry.register('s1', parent);

    monitor = MonitorTag('m1', parent, @(x, y) y > 15);
    TagRegistry.register('m1', monitor);

    % Bind an in-memory EventStore so MonitorTag emits + LiveEventPipeline can harvest.
    % Reuse the existing fixture helper (tests/suite/MakePhase1009Fixtures.m:71) for the
    % EventStore temp path -- keeps test fixtures consistent across the suite and avoids
    % rolling a local tempname helper.
    storeFile = MakePhase1009Fixtures.makeEventStoreTmp();
    store = EventStore(storeFile);
    monitor.EventStore = store;

    ds    = StubDataSource();
    dsMap = DataSourceMap();
    dsMap.add('s1', ds);

    monitorsMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    monitorsMap('s1') = monitor;

    % CaptureNotificationService -- must have at least one rule that matches,
    % otherwise super.notify would early-return. CaptureNotificationService
    % overrides notify completely (no rule check), but we still set a rule
    % to mirror real-world usage so this fixture catches a future refactor
    % that re-introduces the rule check before sensorData resolution.
    cap = CaptureNotificationService('DryRun', true);
    cap.setDefaultRule(NotificationRule( ...
        'Recipients',      {{'test@example.com'}}, ...
        'IncludeSnapshot', false));

    % Plan 01 NV-pair (the API surface this plan locks down):
    pipeline = LiveEventPipeline(monitorsMap, dsMap, ...
        'Interval',            60, ...
        'MinDuration',         0, ...
        'NotificationService', cap);
end
