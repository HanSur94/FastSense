function test_live_event_pipeline_tag()
%TEST_LIVE_EVENT_PIPELINE_TAG Octave flat tests for LiveEventPipeline MonitorTag wire-up.
%   Phase 1009 Plan 03 — mirrors TestLiveEventPipelineTag; provides Octave
%   coverage of the Phase 1007 SC#4 realization (appendData wire-up) and
%   the Pitfall Y parent-before-child ordering gate.
%
%   See also TestLiveEventPipelineTag, LiveEventPipeline, MonitorTag.

    add_live_event_pipeline_tag_path();

    TagRegistry.clear();
    cleanup_on_exit_ = onCleanup(@() TagRegistry.clear());

    test_pitfall1_no_subclass_isa_in_lep();
    test_monitor_tag_path_emits_events_on_append_data();
    test_append_data_order_with_parent();
    test_legacy_sensor_path_unchanged();
    test_monitors_nv_pair_optional();
    test_mixed_sensors_and_monitors();

    fprintf('    All 6 live_event_pipeline_tag tests passed.\n');
end

function add_live_event_pipeline_tag_path()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    install();
    addpath(fullfile(repo, 'tests', 'suite'));
end

function test_pitfall1_no_subclass_isa_in_lep()
    % LiveEventPipeline.m must NOT contain any isa(.., 'SensorTag'|
    % 'MonitorTag'|'StateTag'|'CompositeTag') switches — dispatch is
    % via the MonitorTargets map only.
    here = fileparts(mfilename('fullpath'));
    lepFile = fullfile(here, '..', 'libs', 'EventDetection', 'LiveEventPipeline.m');
    src = fileread(lepFile);
    badKinds = {'SensorTag', 'MonitorTag', 'StateTag', 'CompositeTag'};
    for i = 1:numel(badKinds)
        pat = ['isa\([^,]+,\s*''', badKinds{i}, ''''];
        m   = regexp(src, pat, 'once');
        assert(isempty(m), ...
            sprintf('Pitfall 1 violation: isa(..,''%s'') in LiveEventPipeline.m', ...
                badKinds{i}));
    end
end

function test_monitor_tag_path_emits_events_on_append_data()
    [pipeline, store, ~, ~, ds] = make_live_tag_fixture();
    ds.setNextResult(struct('changed', true, ...
        'X', 6:10, 'Y', [1 1 20 20 1], ...
        'stateX', [], 'stateY', {{}}));

    pipeline.runCycle();

    evts = store.getEvents();
    assert(numel(evts) >= 1, ...
        sprintf('MonitorTag path must emit >= 1 event, got %d', numel(evts)));
    assert(strcmp(evts(1).SensorName, 's1'), ...
        'carrier: SensorName must be parent.Key');
    assert(strcmp(evts(1).ThresholdLabel, 'm1'), ...
        'carrier: ThresholdLabel must be monitor.Key');
end

function test_append_data_order_with_parent()
    % Pitfall Y proof: parent.updateData MUST be called BEFORE
    % monitor.appendData.  If ordering is wrong, recomputeCount_ spikes.
    [pipeline, ~, monitor, parent, ds] = make_live_tag_fixture();

    % Prime the monitor cache (fast-path ready).
    parent.updateData(1:5, [1 1 1 1 1]);
    [~, ~] = monitor.getXY();
    preRecompute = monitor.recomputeCount_;

    ds.setNextResult(struct('changed', true, ...
        'X', 6:10, 'Y', [20 20 20 20 20], ...
        'stateX', [], 'stateY', {{}}));
    pipeline.runCycle();

    postRecompute = monitor.recomputeCount_;
    delta = postRecompute - preRecompute;
    assert(delta <= 1, ...
        sprintf(['Pitfall Y violation: appendData hit cold recompute path ' ...
                 '(delta=%d). parent.updateData must be called BEFORE ' ...
                 'monitor.appendData.'], delta));

    % Verify the cache actually extended — only possible if appendData
    % ran after parent absorbed the new data.
    [cx, ~] = monitor.getXY();
    assert(numel(cx) >= 10, sprintf('monitor cache length >= 10, got %d', numel(cx)));
    assert(cx(end) == 10, sprintf('monitor cache end must be 10, got %g', cx(end)));
end

function test_legacy_sensor_path_unchanged()
    s = Sensor('s1');
    thr = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
    thr.addCondition(struct(), 10);
    s.addThreshold(thr);

    sensors = containers.Map('KeyType', 'char', 'ValueType', 'any');
    sensors('s1') = s;
    dsMap = DataSourceMap();
    ds = StubDataSource();
    dsMap.add('s1', ds);

    p = LiveEventPipeline(sensors, dsMap, 'Interval', 60, 'MinDuration', 0);
    p.runCycle();  % must not error
    assert(strcmp(p.Status, 'stopped'), 'legacy: Status unchanged');
end

function test_monitors_nv_pair_optional()
    s = Sensor('s1');
    thr = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
    thr.addCondition(struct(), 10);
    s.addThreshold(thr);
    sensors = containers.Map('KeyType', 'char', 'ValueType', 'any');
    sensors('s1') = s;
    dsMap = DataSourceMap();
    dsMap.add('s1', StubDataSource());

    p = LiveEventPipeline(sensors, dsMap, 'Interval', 60);
    assert(~isempty(p.MonitorTargets), ...
        'MonitorTargets must be initialized');
    assert(isa(p.MonitorTargets, 'containers.Map'), ...
        'MonitorTargets must be containers.Map');
    assert(p.MonitorTargets.Count == 0, ...
        'MonitorTargets defaults to empty');
end

function test_mixed_sensors_and_monitors()
    TagRegistry.clear();

    parent = SensorTag('s1', 'X', 1:5, 'Y', [1 1 1 1 1]);
    TagRegistry.register('s1', parent);
    monitor = MonitorTag('m1', parent, @(x, y) y > 15);
    TagRegistry.register('m1', monitor);
    store = EventStore(makePhase1009Fixtures.makeEventStoreTmp());
    monitor.EventStore = store;

    s2 = Sensor('s2');
    thr = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
    thr.addCondition(struct(), 10);
    s2.addThreshold(thr);

    sensors = containers.Map('KeyType', 'char', 'ValueType', 'any');
    sensors('s2') = s2;

    ds1 = StubDataSource();
    ds1.setNextResult(struct('changed', true, ...
        'X', 6:10, 'Y', [20 20 20 20 20], ...
        'stateX', [], 'stateY', {{}}));
    ds2 = StubDataSource();
    dsMap = DataSourceMap();
    dsMap.add('s1', ds1);
    dsMap.add('s2', ds2);

    monitorsMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    monitorsMap('s1') = monitor;

    p = LiveEventPipeline(sensors, dsMap, ...
        'Monitors', monitorsMap, ...
        'Interval', 60, 'MinDuration', 0);

    p.runCycle();
    assert(store.numEvents() >= 1, ...
        sprintf('mixed: expected >= 1 event on monitor side, got %d', ...
            store.numEvents()));
end

function [pipeline, store, monitor, parent, ds] = make_live_tag_fixture()
    TagRegistry.clear();

    parent  = SensorTag('s1', 'X', 1:5, 'Y', [1 1 1 1 1]);
    TagRegistry.register('s1', parent);

    monitor = MonitorTag('m1', parent, @(x, y) y > 15);
    TagRegistry.register('m1', monitor);

    store = EventStore(makePhase1009Fixtures.makeEventStoreTmp());
    monitor.EventStore = store;

    ds    = StubDataSource();
    dsMap = DataSourceMap();
    dsMap.add('s1', ds);

    monitorsMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    monitorsMap('s1') = monitor;

    sensors = containers.Map('KeyType', 'char', 'ValueType', 'any');

    pipeline = LiveEventPipeline(sensors, dsMap, ...
        'Monitors', monitorsMap, ...
        'Interval', 60, 'MinDuration', 0);
end
