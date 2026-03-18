function test_event_detector()
%TEST_EVENT_DETECTOR Tests for EventDetector class.

    add_event_path();

    % testDetectSingleEvent
    det = EventDetector();
    t      = [1 2 3 4 5 6 7 8 9 10];
    values = [5 5 12 14 11 13 5 5 5 5];
    events = det.detect(t, values, 10, 'upper', 'warn', 'temp');
    assert(numel(events) == 1, 'singleEvent: count');
    assert(events(1).StartTime == 3, 'singleEvent: StartTime');
    assert(events(1).EndTime == 6, 'singleEvent: EndTime');
    assert(events(1).Duration == 3, 'singleEvent: Duration');
    assert(strcmp(events(1).SensorName, 'temp'), 'singleEvent: SensorName');
    assert(strcmp(events(1).ThresholdLabel, 'warn'), 'singleEvent: ThresholdLabel');
    assert(events(1).ThresholdValue == 10, 'singleEvent: ThresholdValue');
    assert(strcmp(events(1).Direction, 'upper'), 'singleEvent: Direction');

    % testStats — computed over ALL points in event window
    % Event window is indices 3-6: values [12 14 11 13], t [3 4 5 6]
    assert(events(1).PeakValue == 14, 'stats: PeakValue');
    assert(events(1).NumPoints == 4, 'stats: NumPoints');
    assert(events(1).MinValue == 11, 'stats: MinValue');
    assert(events(1).MaxValue == 14, 'stats: MaxValue');
    assert(abs(events(1).MeanValue - 12.5) < 1e-10, 'stats: MeanValue');
    expected_rms = sqrt(mean([12 14 11 13].^2));
    assert(abs(events(1).RmsValue - expected_rms) < 1e-10, 'stats: RmsValue');
    expected_std = std([12 14 11 13]);
    assert(abs(events(1).StdValue - expected_std) < 1e-10, 'stats: StdValue');

    % testPeakValueLow — for low direction, PeakValue is MinValue
    det = EventDetector();
    t      = [1 2 3 4 5];
    values = [50 3 2 4 50];
    events = det.detect(t, values, 10, 'lower', 'alarm', 'pressure');
    assert(events(1).PeakValue == 2, 'peakLow: PeakValue is min');

    % testMultipleEvents
    det = EventDetector();
    t      = [1 2 3 4 5 6 7 8 9 10];
    values = [12 13 5 5 5 14 15 5 5 5];
    events = det.detect(t, values, 10, 'upper', 'warn', 'temp');
    assert(numel(events) == 2, 'multipleEvents: count');
    assert(events(1).StartTime == 1, 'multipleEvents: e1 start');
    assert(events(2).StartTime == 6, 'multipleEvents: e2 start');

    % testDebounceFilter
    det = EventDetector('MinDuration', 2);
    t      = [1 2 3 4 5 6 7 8 9 10];
    values = [12 5 5 14 15 16 17 5 5 5];
    events = det.detect(t, values, 10, 'upper', 'warn', 'temp');
    % First event: t=1 to t=1, duration=0 -> filtered
    % Second event: t=4 to t=7, duration=3 -> kept
    assert(numel(events) == 1, 'debounce: count');
    assert(events(1).StartTime == 4, 'debounce: kept event');

    % testNoViolations
    det = EventDetector();
    t      = [1 2 3 4 5];
    values = [5 6 7 8 9];
    events = det.detect(t, values, 10, 'upper', 'warn', 'temp');
    assert(isempty(events), 'noViolations: empty');

    % testCallback
    callCount = 0;
    lastEvent = [];
    function onEvent(ev)
        callCount = callCount + 1;
        lastEvent = ev;
    end
    det = EventDetector('OnEventStart', @onEvent);
    t      = [1 2 3 4 5 6 7 8 9 10];
    values = [12 13 5 5 5 14 15 5 5 5];
    det.detect(t, values, 10, 'upper', 'warn', 'temp');
    assert(callCount == 2, 'callback: called twice');
    assert(lastEvent.StartTime == 6, 'callback: last event');

    % testMaxCallsPerEvent
    callCount = 0;
    det = EventDetector('OnEventStart', @onEvent, 'MaxCallsPerEvent', 1);
    t      = [1 2 3 4 5];
    values = [12 13 14 15 16];
    det.detect(t, values, 10, 'upper', 'warn', 'temp');
    assert(callCount == 1, 'maxCalls: only called once for one event');

    fprintf('    All 7 event_detector tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
