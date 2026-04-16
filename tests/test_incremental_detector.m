function test_incremental_detector()
    add_event_path();
    test_first_batch_detects_events();
    test_incremental_new_events_only();
    test_open_event_carries_over();
    test_open_event_finalizes();
    test_no_data_no_events();
    test_severity_escalation();
    test_multiple_sensors();
    test_slice_detection_consistency();
    fprintf('test_incremental_detector: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    install();
end

function test_first_batch_detects_events()
    det = IncrementalEventDetector('MinDuration', 0);
    sensor = makeSensor('temp', 100, 'upper');
    t = linspace(now-1, now, 100);
    y = 80 * ones(1,100); y(40:60) = 120;  % violation from 40 to 60
    newEvents = det.process('temp', sensor, t, y, [], {});
    assert(numel(newEvents) >= 1, 'detected_event');
    assert(strcmp(newEvents(1).SensorName, 'temp'), 'sensor_name');
    fprintf('  PASS: test_first_batch_detects_events\n');
end

function test_incremental_new_events_only()
    det = IncrementalEventDetector('MinDuration', 0);
    sensor = makeSensor('temp', 100, 'upper');
    t1 = linspace(now-1, now-0.5, 50);
    y1 = 80 * ones(1,50); y1(20:30) = 120;
    ev1 = det.process('temp', sensor, t1, y1, [], {});
    n1 = numel(ev1);
    % Second batch — no violations
    t2 = linspace(now-0.5, now, 50);
    y2 = 80 * ones(1,50);
    ev2 = det.process('temp', sensor, t2, y2, [], {});
    assert(numel(ev2) == 0, 'no_new_events');
    fprintf('  PASS: test_incremental_new_events_only\n');
end

function test_open_event_carries_over()
    det = IncrementalEventDetector('MinDuration', 0);
    sensor = makeSensor('temp', 100, 'upper');
    % Batch 1: violation starts but doesn't end
    t1 = linspace(now-1, now-0.5, 50);
    y1 = 80 * ones(1,50); y1(40:50) = 120;  % violation continues at end
    ev1 = det.process('temp', sensor, t1, y1, [], {});
    % Open event should exist but not be emitted yet
    assert(numel(ev1) == 0, 'no_finalized_yet');
    assert(det.hasOpenEvent('temp'), 'has_open_event');
    fprintf('  PASS: test_open_event_carries_over\n');
end

function test_open_event_finalizes()
    det = IncrementalEventDetector('MinDuration', 0);
    sensor = makeSensor('temp', 100, 'upper');
    % Batch 1: violation at end
    t1 = linspace(now-1, now-0.5, 50);
    y1 = 80*ones(1,50); y1(40:50) = 120;
    det.process('temp', sensor, t1, y1, [], {});
    % Batch 2: violation ends
    t2 = linspace(now-0.5, now, 50);
    y2 = 80*ones(1,50); y2(1:5) = 120;  % violation continues briefly then stops
    ev2 = det.process('temp', sensor, t2, y2, [], {});
    assert(numel(ev2) == 1, 'finalized_event');
    % Event should span from batch 1 to batch 2
    assert(ev2(1).StartTime < now - 0.4, 'start_in_batch1');
    assert(ev2(1).EndTime > now - 0.5, 'end_in_batch2');
    fprintf('  PASS: test_open_event_finalizes\n');
end

function test_no_data_no_events()
    det = IncrementalEventDetector('MinDuration', 0);
    sensor = makeSensor('temp', 100, 'upper');
    ev = det.process('temp', sensor, [], [], [], {});
    assert(isempty(ev), 'no_events_empty_data');
    fprintf('  PASS: test_no_data_no_events\n');
end

function test_severity_escalation()
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (Octave classdef limitation)\n');
        return;
    end
    det = IncrementalEventDetector('MinDuration', 0, 'EscalateSeverity', true);
    sensor = Sensor('temp');
    tH = Threshold('h', 'Name', 'H', 'Direction', 'upper');
    tH.addCondition(struct(), 100);
    sensor.addThreshold(tH);
    tHH = Threshold('hh', 'Name', 'HH', 'Direction', 'upper');
    tHH.addCondition(struct(), 150);
    sensor.addThreshold(tHH);
    t = linspace(now-1, now, 100);
    y = 80*ones(1,100); y(40:60) = 160;  % exceeds HH
    ev = det.process('temp', sensor, t, y, [], {});
    % Event should be escalated to HH
    hhEvents = ev(strcmp({ev.ThresholdLabel}, 'HH'));
    assert(~isempty(hhEvents), 'escalated_to_HH');
    fprintf('  PASS: test_severity_escalation\n');
end

function test_multiple_sensors()
    det = IncrementalEventDetector('MinDuration', 0);
    s1 = makeSensor('temp', 100, 'upper');
    s2 = makeSensor('pres', 50, 'upper');
    t = linspace(now-1, now, 100);
    y1 = 80*ones(1,100); y1(30:40) = 120;
    y2 = 30*ones(1,100); y2(60:70) = 60;
    ev1 = det.process('temp', s1, t, y1, [], {});
    ev2 = det.process('pres', s2, t, y2, [], {});
    assert(~isempty(ev1) && strcmp(ev1(1).SensorName, 'temp'), 'sensor1');
    assert(~isempty(ev2) && strcmp(ev2(1).SensorName, 'pres'), 'sensor2');
    fprintf('  PASS: test_multiple_sensors\n');
end

function test_slice_detection_consistency()
    det = IncrementalEventDetector('MinDuration', 0);
    sensor = makeSensor('temp', 100, 'upper');
    % Batch 1: large history with one event
    t1 = linspace(now-10, now-5, 500);
    y1 = 80*ones(1,500); y1(100:150) = 120;
    ev1 = det.process('temp', sensor, t1, y1, [], {});
    n1 = numel(ev1);
    % Batch 2: another event in new data
    t2 = linspace(now-5, now, 500);
    y2 = 80*ones(1,500); y2(200:250) = 120;
    ev2 = det.process('temp', sensor, t2, y2, [], {});
    % Should detect exactly the new event, not re-emit old one
    assert(n1 >= 1, 'batch1_event');
    assert(numel(ev2) >= 1, 'batch2_event');
    assert(ev2(1).StartTime > now - 5.1, 'new_event_in_batch2');
    fprintf('  PASS: test_slice_detection_consistency\n');
end

function sensor = makeSensor(key, threshVal, dir)
    sensor = Sensor(key);
    t = Threshold('h', 'Name', 'H', 'Direction', dir);
    t.addCondition(struct(), threshVal);
    sensor.addThreshold(t);
end
