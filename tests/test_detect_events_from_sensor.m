function test_detect_events_from_sensor()
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (known Octave classdef limitation)\n');
        return;
    end
%TEST_DETECT_EVENTS_FROM_SENSOR Tests for Sensor convenience wrapper.

    add_event_path();

    % --- Setup: sensor with resolved violations ---
    s = Sensor('temp', 'Name', 'Temperature');
    s.X = [1 2 3 4 5 6 7 8 9 10];
    s.Y = [5 5 12 14 11 13 5 5 5 5];

    % Add a threshold (no state channels = always active)
    tw = Threshold('warn_high', 'Name', 'warn high', 'Direction', 'upper');
    tw.addCondition(struct(), 10);
    s.addThreshold(tw);
    s.resolve();

    % testDefaultDetector
    events = detectEventsFromSensor(s);
    assert(numel(events) >= 1, 'default: at least one event');
    assert(strcmp(events(1).SensorName, 'Temperature'), 'default: SensorName from sensor.Name');
    assert(strcmp(events(1).ThresholdLabel, 'warn high'), 'default: ThresholdLabel');
    assert(strcmp(events(1).Direction, 'upper'), 'default: Direction');

    % testCustomDetector
    det = EventDetector('MinDuration', 5);
    events = detectEventsFromSensor(s, det);
    % Event duration is 3 (t=3 to t=6), so debounce should filter it
    assert(isempty(events), 'customDetector: debounced');

    % testMultipleThresholds — each threshold produces independent events
    s2 = Sensor('temp', 'Name', 'Temperature');
    s2.X = [1 2 3 4 5 6 7 8 9 10];
    s2.Y = [5 5 12 14 11 13 5 5 5 5];
    tw2 = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
    tw2.addCondition(struct(), 10);
    s2.addThreshold(tw2);
    tc2 = Threshold('critical', 'Name', 'critical', 'Direction', 'upper');
    tc2.addCondition(struct(), 13);
    s2.addThreshold(tc2);
    s2.resolve();

    events = detectEventsFromSensor(s2);
    % warn: indices 3-6 (values 12,14,11,13 > 10)
    % critical: index 4 (value 14 > 13) and index 6 (value 13 == 13, NOT > 13)
    % So we expect at least 2 events (1 warn + 1 critical)
    labels = arrayfun(@(e) e.ThresholdLabel, events, 'UniformOutput', false);
    assert(any(strcmp(labels, 'warn')), 'multiThresh: has warn');
    assert(any(strcmp(labels, 'critical')), 'multiThresh: has critical');

    fprintf('    All 3 detect_events_from_sensor tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
