function test_live_event_pipeline_tag()
%TEST_LIVE_EVENT_PIPELINE_TAG Octave flat tests for LiveEventPipeline MonitorTag wire-up.
%   Rewritten in Phase 1011 to use the MonitorTargets-first constructor.
%   Legacy Sensor-based tests removed (Sensor pipeline deleted in Plan 03).
%
%   See also TestLiveEventPipelineTag, LiveEventPipeline, MonitorTag.

    add_live_event_pipeline_tag_path();

    TagRegistry.clear();
    EventBinding.clear();
    cleanup_on_exit_ = onCleanup(@() cleanup_registries()); %#ok<NASGU>

    test_pitfall1_no_subclass_isa_in_lep();
    test_monitor_tag_path_emits_events_on_append_data();
    test_append_data_order_with_parent();

    fprintf('    All 3 live_event_pipeline_tag tests passed.\n');
end

function add_live_event_pipeline_tag_path()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    install();
    addpath(fullfile(repo, 'tests', 'suite'));
end

function cleanup_registries()
    TagRegistry.clear();
    EventBinding.clear();
end

function test_pitfall1_no_subclass_isa_in_lep()
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

    [cx, ~] = monitor.getXY();
    assert(numel(cx) >= 10, sprintf('monitor cache length >= 10, got %d', numel(cx)));
    assert(cx(end) == 10, sprintf('monitor cache end must be 10, got %g', cx(end)));
end

function [pipeline, store, monitor, parent, ds] = make_live_tag_fixture()
    TagRegistry.clear();
    EventBinding.clear();

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

    pipeline = LiveEventPipeline(monitorsMap, dsMap, ...
        'Interval', 60, 'MinDuration', 0);
end
