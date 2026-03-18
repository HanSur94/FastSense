function test_event_integration()
%TEST_EVENT_INTEGRATION End-to-end integration test for EventDetection library.

    add_event_path();

    % Full pipeline: Sensor -> resolve -> detectEventsFromSensor
    s = Sensor('vibration', 'Name', 'Motor Vibration');
    s.X = 1:20;
    s.Y = [5 5 5 12 14 16 14 5 5 5 5 5 18 20 22 5 5 5 5 5];

    sc = StateChannel('machine');
    sc.X = [1 11]; sc.Y = [1 1];
    s.addStateChannel(sc);

    s.addThresholdRule(struct('machine', 1), 10, ...
        'Direction', 'upper', 'Label', 'vibration warning');
    s.resolve();

    % Detect with default detector
    events = detectEventsFromSensor(s);
    assert(numel(events) == 2, 'integration: 2 events detected');
    assert(events(1).StartTime == 4, 'integration: e1 start');
    assert(events(1).EndTime == 7, 'integration: e1 end');
    assert(events(2).StartTime == 13, 'integration: e2 start');
    assert(events(2).EndTime == 15, 'integration: e2 end');

    % Verify stats
    assert(events(1).NumPoints == 4, 'integration: e1 numpoints');
    assert(events(1).PeakValue == 16, 'integration: e1 peak');
    assert(events(2).PeakValue == 22, 'integration: e2 peak');

    % Detect with debounce — only keep events >= 3 duration
    det = EventDetector('MinDuration', 3);
    events = detectEventsFromSensor(s, det);
    assert(numel(events) == 1, 'integration debounce: 1 event');
    assert(events(1).StartTime == 4, 'integration debounce: kept longer event');

    % Callback integration
    callCount = 0;
    function onEvent(ev)
        callCount = callCount + 1;
    end
    det = EventDetector('OnEventStart', @onEvent);
    detectEventsFromSensor(s, det);
    assert(callCount == 2, 'integration callback: 2 calls');

    fprintf('    All 4 event_integration tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); setup();
end
