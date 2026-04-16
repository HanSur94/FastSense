function test_monitortag_events()
%TEST_MONITORTAG_EVENTS Octave flat-style port of TestMonitorTagEvents (Phase 1006-02).
%   Mirrors the core assertions of tests/suite/TestMonitorTagEvents.m:
%     - Single rising edge -> 1 event with SensorName+ThresholdLabel carriers
%     - MinDuration filters short pulse (2-unit pulse at MinDuration=5)
%     - MinDuration keeps long pulse (6-unit-duration pulse at MinDuration=5)
%     - MinDuration = 0 preserves short pulse (default behavior)
%     - AlarmOffConditionFn hysteresis collapses sinusoid chatter to 1 edge
%     - Empty AlarmOffConditionFn preserves raw condition output
%     - Multiple rising edges -> multiple distinct events
%     - Second getXY cache hit does NOT re-emit events
%     - Event.StartTime / EndTime use native parent-X units
%     - Pitfall 5 grep gate: `.TagKeys` absent from MonitorTag.m
%     - Plan 01 regression grep gates still hold
%
%   See also test_monitortag, test_sensortag, TestMonitorTagEvents.

    add_monitortag_events_path();
    TagRegistry.clear();

    % --- Single rising edge fires event with carrier fields (MONITOR-05) ---
    parent = SensorTag('p', 'X', 1:10, 'Y', [0 0 0 0 10 10 10 0 0 0]);
    store  = EventStore('');
    m = MonitorTag('m', parent, @(xx, yy) yy > 5, 'EventStore', store);
    [~, ~] = m.getXY();
    events = store.getEvents();
    assert(numel(events) == 1, 'test_monitortag_events: expected exactly 1 event');
    assert(strcmp(events(1).SensorName, 'p'), ...
        'test_monitortag_events: SensorName carrier must equal parent.Key');
    assert(strcmp(events(1).ThresholdLabel, 'm'), ...
        'test_monitortag_events: ThresholdLabel carrier must equal monitor.Key');
    assert(strcmp(events(1).Direction, 'upper'), ...
        'test_monitortag_events: Direction must be upper');
    assert(events(1).StartTime == 5, 'test_monitortag_events: StartTime native units');
    assert(events(1).EndTime == 7,   'test_monitortag_events: EndTime native units');
    TagRegistry.clear();

    % --- MinDuration filters short pulse (MONITOR-06) ---
    x = 1:20; y = zeros(1, 20); y(10:11) = 10;
    parent = SensorTag('p2', 'X', x, 'Y', y);
    store  = EventStore('');
    m = MonitorTag('m2', parent, @(xx, yy) yy > 5, ...
                   'MinDuration', 5, 'EventStore', store);
    [~, bin] = m.getXY();
    assert(sum(bin) == 0, 'test_monitortag_events: MinDuration=5 must zero short pulse in cache');
    assert(numel(store.getEvents()) == 0, ...
        'test_monitortag_events: MinDuration=5 must filter short events');
    TagRegistry.clear();

    % --- MinDuration keeps long pulse ---
    x = 1:20; y = zeros(1, 20); y(8:14) = 10;
    parent = SensorTag('p3', 'X', x, 'Y', y);
    store  = EventStore('');
    m = MonitorTag('m3', parent, @(xx, yy) yy > 5, ...
                   'MinDuration', 5, 'EventStore', store);
    [~, bin] = m.getXY();
    assert(sum(bin) == 7, 'test_monitortag_events: Long pulse must survive debounce');
    events = store.getEvents();
    assert(numel(events) == 1, 'test_monitortag_events: Exactly 1 event for long pulse');
    assert(events(1).StartTime == 8,  'test_monitortag_events: StartTime 8');
    assert(events(1).EndTime   == 14, 'test_monitortag_events: EndTime 14');
    TagRegistry.clear();

    % --- MinDuration = 0 preserves short pulse ---
    x = 1:20; y = zeros(1, 20); y(10:11) = 10;
    parent = SensorTag('p4', 'X', x, 'Y', y);
    store  = EventStore('');
    m = MonitorTag('m4', parent, @(xx, yy) yy > 5, 'EventStore', store);
    [~, bin] = m.getXY();
    assert(sum(bin) == 2, 'test_monitortag_events: MinDuration=0 preserves short pulse');
    assert(numel(store.getEvents()) == 1, ...
        'test_monitortag_events: MinDuration=0 emits 1 event for short pulse');
    TagRegistry.clear();

    % --- Hysteresis suppresses chatter (MONITOR-07) ---
    x = linspace(0, 10, 1001);
    y = 10 + 0.5 * sin(2 * pi * x);

    parent_raw = SensorTag('p_raw', 'X', x, 'Y', y);
    m_raw = MonitorTag('m_raw', parent_raw, @(xx, yy) yy > 10);
    [~, bin_raw] = m_raw.getXY();
    edges_raw = sum(diff([0 bin_raw 0]) == 1);
    assert(edges_raw >= 5, ...
        'test_monitortag_events: Raw condition must chatter (expected >= 5 edges)');
    TagRegistry.clear();

    parent_hys = SensorTag('p_hys', 'X', x, 'Y', y);
    m_hys = MonitorTag('m_hys', parent_hys, @(xx, yy) yy > 10, ...
                       'AlarmOffConditionFn', @(xx, yy) yy < 9.5);
    [~, bin_hys] = m_hys.getXY();
    edges_hys = sum(diff([0 bin_hys 0]) == 1);
    assert(edges_hys == 1, ...
        'test_monitortag_events: Hysteresis must collapse chatter to exactly 1 edge');
    TagRegistry.clear();

    % --- Empty AlarmOffConditionFn preserves raw (Plan 01 behavior) ---
    x = 1:10; y = [0 0 10 10 0 0 10 10 0 0];
    parent = SensorTag('p5', 'X', x, 'Y', y);
    fn = @(xx, yy) yy > 5;
    m = MonitorTag('m5', parent, fn);
    [~, bin] = m.getXY();
    expected = double(logical(fn(x, y)));
    assert(isequal(bin, expected), ...
        'test_monitortag_events: Empty AlarmOffConditionFn must preserve raw output');
    TagRegistry.clear();

    % --- Multiple rising edges emit distinct events ---
    x = 1:15; y = zeros(1, 15); y(3:5) = 10; y(10:12) = 10;
    parent = SensorTag('p6', 'X', x, 'Y', y);
    store  = EventStore('');
    m = MonitorTag('m6', parent, @(xx, yy) yy > 5, 'EventStore', store);
    [~, ~] = m.getXY();
    events = store.getEvents();
    assert(numel(events) == 2, 'test_monitortag_events: 2 pulses -> 2 events');
    assert(events(1).StartTime == 3,  'test_monitortag_events: first pulse start');
    assert(events(1).EndTime   == 5,  'test_monitortag_events: first pulse end');
    assert(events(2).StartTime == 10, 'test_monitortag_events: second pulse start');
    assert(events(2).EndTime   == 12, 'test_monitortag_events: second pulse end');
    TagRegistry.clear();

    % --- No duplicate events on second getXY (cache hit) ---
    x = 1:10; y = [0 0 0 10 10 10 0 0 0 0];
    parent = SensorTag('p7', 'X', x, 'Y', y);
    store  = EventStore('');
    m = MonitorTag('m7', parent, @(xx, yy) yy > 5, 'EventStore', store);
    [~, ~] = m.getXY();
    n1 = numel(store.getEvents());
    [~, ~] = m.getXY();
    n2 = numel(store.getEvents());
    assert(n1 == 1, 'test_monitortag_events: first getXY emits 1 event');
    assert(n2 == n1, 'test_monitortag_events: cache hit must NOT re-emit events');
    TagRegistry.clear();

    % --- Native parent-X units for Event StartTime/EndTime ---
    x = [100 200 300 400 500];
    y = [0 0 10 10 0];
    parent = SensorTag('p8', 'X', x, 'Y', y);
    store  = EventStore('');
    m = MonitorTag('m8', parent, @(xx, yy) yy > 5, 'EventStore', store);
    [~, ~] = m.getXY();
    events = store.getEvents();
    assert(numel(events) == 1, 'test_monitortag_events: expected 1 event');
    assert(events(1).StartTime == 300, ...
        'test_monitortag_events: StartTime native units (not sample index)');
    assert(events(1).EndTime == 400, ...
        'test_monitortag_events: EndTime native units (not sample index)');
    TagRegistry.clear();

    % --- Grep gates on MonitorTag.m ---
    src = fileread(monitortag_events_source_path_());
    assert(isempty(regexp(src, '\.TagKeys', 'match')), ...
        'Pitfall 5: Event.TagKeys must not appear in MonitorTag.m pre-Phase-1010');
    assert(isempty(regexp(src, 'FastSenseDataStore|storeMonitor|storeResolved', 'match')), ...
        'Pitfall 2: MonitorTag.m must not reference persistence types');
    assert(~isempty(regexp(src, 'lazy-by-default, no persistence', 'once')), ...
        'Pitfall 2: header doc must be preserved');
    assert(isempty(regexp(src, 'PerSample|OnSample|onEachSample', 'match')), ...
        'MONITOR-10: MonitorTag.m must not expose per-sample callback keywords');
    assert(isempty(regexp(src, 'interp1.*''linear''', 'match')), ...
        'ALIGN-01: MonitorTag.m must not use interp1 linear');
    assert(isempty(regexp(src, 'methods \(Abstract\)', 'match')), ...
        'Octave safety: MonitorTag.m must not use methods (Abstract) block');

    fprintf('    All test_monitortag_events tests passed.\n');
end

function add_monitortag_events_path()
    %ADD_MONITORTAG_EVENTS_PATH Ensure repo + tests/suite on path.
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    addpath(fullfile(here, 'suite'));
    install();
end

function p = monitortag_events_source_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    p    = fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m');
end
