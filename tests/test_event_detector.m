function test_event_detector()
%TEST_EVENT_DETECTOR Tests for EventDetector class via MonitorTag + EventStore.
%   Rewritten in Phase 1011 from 6-arg detect to Tag-based detection.
%   Event stats (PeakValue, NumPoints, etc.) verified via raw data lookup
%   since MonitorTag events do not carry stats.

    add_event_path();
    TagRegistry.clear();
    EventBinding.clear();

    % testDetectSingleEvent -- via MonitorTag
    st = SensorTag('temp_single', 'X', [1 2 3 4 5 6 7 8 9 10], ...
        'Y', [5 5 12 14 11 13 5 5 5 5]);
    es = EventStore('');
    mon = MonitorTag('warn_single', st, @(x, y) y > 10, 'EventStore', es);
    [~, my] = mon.getXY();
    events = es.getEvents();
    assert(numel(events) == 1, 'singleEvent: count');
    assert(events(1).StartTime == 3, 'singleEvent: StartTime');
    assert(events(1).EndTime == 6, 'singleEvent: EndTime');
    assert(events(1).Duration == 3, 'singleEvent: Duration');
    % Verify peak from raw data
    [sx, sy] = st.getXY();
    mask = sx >= 3 & sx <= 6;
    assert(max(sy(mask)) == 14, 'singleEvent: peak from data');

    % testMultipleEvents
    TagRegistry.clear(); EventBinding.clear();
    st2 = SensorTag('temp_multi', 'X', [1 2 3 4 5 6 7 8 9 10], ...
        'Y', [12 13 5 5 5 14 15 5 5 5]);
    es2 = EventStore('');
    mon2 = MonitorTag('warn_multi', st2, @(x, y) y > 10, 'EventStore', es2);
    mon2.getXY();
    events2 = es2.getEvents();
    assert(numel(events2) == 2, 'multipleEvents: count');
    assert(events2(1).StartTime == 1, 'multipleEvents: e1 start');
    assert(events2(2).StartTime == 6, 'multipleEvents: e2 start');

    % testDebounceFilter
    TagRegistry.clear(); EventBinding.clear();
    st3 = SensorTag('temp_debounce', 'X', [1 2 3 4 5 6 7 8 9 10], ...
        'Y', [12 5 5 14 15 16 17 5 5 5]);
    es3 = EventStore('');
    mon3 = MonitorTag('warn_debounce', st3, @(x, y) y > 10, ...
        'MinDuration', 2, 'EventStore', es3);
    mon3.getXY();
    events3 = es3.getEvents();
    assert(numel(events3) == 1, 'debounce: count');
    assert(events3(1).StartTime == 4, 'debounce: kept event');

    % testNoViolations
    TagRegistry.clear(); EventBinding.clear();
    st4 = SensorTag('temp_noviol', 'X', [1 2 3 4 5], 'Y', [5 6 7 8 9]);
    es4 = EventStore('');
    mon4 = MonitorTag('warn_noviol', st4, @(x, y) y > 10, 'EventStore', es4);
    mon4.getXY();
    assert(isempty(es4.getEvents()), 'noViolations: empty');

    TagRegistry.clear(); EventBinding.clear();
    fprintf('    All 4 event_detector tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
