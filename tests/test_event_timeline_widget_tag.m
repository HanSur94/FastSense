function test_event_timeline_widget_tag()
%TEST_EVENT_TIMELINE_WIDGET_TAG Octave flat tests for EventTimelineWidget Tag migration.
%   Phase 1009 Plan 02 — verifies EventStore.getEventsForTag directly
%   (Octave-compatible) and enforces the Pitfall 1 grep gate on
%   EventTimelineWidget.m.  Classdef-dependent widget-construction tests
%   are MATLAB-only (DashboardWidget:Abstract blocks Octave parse).
%
%   See also TestEventTimelineWidgetTag, EventStore, makePhase1009Fixtures.

    add_event_timeline_widget_tag_path();

    test_pitfall1_no_isa_in_widget();
    test_get_events_for_tag_on_store();

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    All Octave-runnable event_timeline_widget_tag tests passed (2). Widget-construction tests SKIPPED on Octave.\n');
        return;
    end

    test_filter_tag_key_matches_sensor_name();
    test_filter_tag_key_matches_threshold_label();
    test_empty_filter_tag_key_is_all_events();
    test_legacy_filter_sensors();
    test_filter_tag_key_round_trip();

    fprintf('    All 7 event_timeline_widget_tag tests passed.\n');
end

function test_pitfall1_no_isa_in_widget()
    here = fileparts(mfilename('fullpath'));
    widgetFile = fullfile(here, '..', 'libs', 'Dashboard', 'EventTimelineWidget.m');
    src = fileread(widgetFile);
    badKinds = {'SensorTag', 'MonitorTag', 'StateTag', 'CompositeTag'};
    for i = 1:numel(badKinds)
        pattern = ['isa\([^,]+,\s*''', badKinds{i}, ''''];
        matches = regexp(src, pattern, 'once');
        assert(isempty(matches), ...
            sprintf('test_event_timeline_widget_tag: Pitfall 1 violation — isa(.., ''%s'') in EventTimelineWidget.m', ...
                    badKinds{i}));
    end
end

function test_get_events_for_tag_on_store()
    store = build_store();
    got = store.getEventsForTag('press_a');
    assert(numel(got) == 3, ...
        sprintf('getEventsForTag(''press_a'') should yield 3 events, got %d', numel(got)));

    got2 = store.getEventsForTag('temp_b');
    assert(numel(got2) == 2);

    gotMiss = store.getEventsForTag('nonexistent');
    assert(isempty(gotMiss));

    % Match by ThresholdLabel (MONITOR-05 carrier): an event whose
    % ThresholdLabel == tagKey must be returned even if SensorName differs.
    store2 = EventStore(makePhase1009Fixtures.makeEventStoreTmp());
    ev = Event(100, 150, 'parent_x', 'mon_alarm', 5, 'upper');
    store2.append(ev);
    got3 = store2.getEventsForTag('mon_alarm');
    assert(numel(got3) == 1, 'ThresholdLabel carrier match must work');
end

function test_filter_tag_key_matches_sensor_name()
    store = build_store();
    w = EventTimelineWidget('Title', 'T', 'EventStoreObj', store, ...
        'FilterTagKey', 'press_a');
    [tMin, tMax] = w.getTimeRange();
    assert(tMin == 10, sprintf('FilterTagKey=press_a tMin should be 10 (got %g)', tMin));
    assert(tMax == 35);
end

function test_filter_tag_key_matches_threshold_label()
    store = EventStore(makePhase1009Fixtures.makeEventStoreTmp());
    ev = Event(100, 150, 'parent_x', 'mon_alarm', 5, 'upper');
    store.append(ev);
    w = EventTimelineWidget('Title', 'T', 'EventStoreObj', store, ...
        'FilterTagKey', 'mon_alarm');
    [tMin, tMax] = w.getTimeRange();
    assert(tMin == 100);
    assert(tMax == 150);
end

function test_empty_filter_tag_key_is_all_events()
    store = build_store();
    w = EventTimelineWidget('Title', 'T', 'EventStoreObj', store);
    [tMin, tMax] = w.getTimeRange();
    assert(tMin == 10);
    assert(tMax == 85);
end

function test_legacy_filter_sensors()
    evts = struct('startTime', {10, 20, 30}, ...
                  'endTime',   {15, 25, 35}, ...
                  'label',     {'Pump-101', 'Valve-202', 'Pump-101'}, ...
                  'color',     {[1 0 0], [0 1 0], [0 0 1]});
    w = EventTimelineWidget('Title', 'F', ...
        'Events', evts, 'FilterSensors', {{'Pump-101'}});
    [tMin, ~] = w.getTimeRange();
    assert(tMin == 10);
end

function test_filter_tag_key_round_trip()
    w = EventTimelineWidget('Title', 'RT');
    w.FilterTagKey = 'alpha';
    s = w.toStruct();
    assert(isfield(s, 'filterTagKey'));
    assert(strcmp(s.filterTagKey, 'alpha'));

    w2 = EventTimelineWidget.fromStruct(s);
    assert(strcmp(w2.FilterTagKey, 'alpha'));
end

function store = build_store()
    store = EventStore(makePhase1009Fixtures.makeEventStoreTmp());
    store.append(Event(10, 15, 'press_a', 'hi',  50, 'upper'));
    store.append(Event(20, 25, 'press_a', 'hi',  50, 'upper'));
    store.append(Event(30, 35, 'press_a', 'alm', 80, 'upper'));
    store.append(Event(60, 70, 'temp_b', 'hi',  100, 'upper'));
    store.append(Event(75, 85, 'temp_b', 'alm', 120, 'upper'));
end

function add_event_timeline_widget_tag_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    install();
    addpath(fullfile(repo_root, 'tests', 'suite'));
end
