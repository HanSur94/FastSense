# Event Detection Library Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a third library (`libs/EventDetection/`) that groups threshold violations into events with statistics, debounce filtering, configurable callbacks, console output, a figure-based event viewer UI, and a live demo example.

**Architecture:** `EventDetector` class with configurable debounce and callback. `Event` value class holds metadata and stats. Private `groupViolations` helper does the core clustering. `EventConfig` manages system-wide configuration. `EventViewer` provides a Gantt timeline + filterable table UI with click-to-plot. Console functions for formatted summary and live logging. Convenience function `detectEventsFromSensor` bridges to the SensorThreshold library.

**Tech Stack:** MATLAB/Octave, no toolbox dependencies, assert-based unit tests.

**Design doc:** `docs/plans/2026-03-09-event-detection-design.md`

---

### Task 1: Event value class

**Files:**
- Create: `libs/EventDetection/Event.m`
- Test: `tests/test_event.m`

**Step 1: Write the failing test**

Create `tests/test_event.m`:

```matlab
function test_event()
%TEST_EVENT Tests for Event value class.

    add_event_path();

    % testConstructor
    e = Event(10, 20, 'temp', 'warning high', 80, 'high');
    assert(e.StartTime == 10, 'constructor: StartTime');
    assert(e.EndTime == 20, 'constructor: EndTime');
    assert(e.Duration == 10, 'constructor: Duration');
    assert(strcmp(e.SensorName, 'temp'), 'constructor: SensorName');
    assert(strcmp(e.ThresholdLabel, 'warning high'), 'constructor: ThresholdLabel');
    assert(e.ThresholdValue == 80, 'constructor: ThresholdValue');
    assert(strcmp(e.Direction, 'high'), 'constructor: Direction');

    % testStats
    e = Event(1, 5, 'temp', 'warn', 80, 'high');
    e = e.setStats(100, 3, 70, 90, 82, 83, 5);
    assert(e.PeakValue == 100, 'stats: PeakValue');
    assert(e.NumPoints == 3, 'stats: NumPoints');
    assert(e.MinValue == 70, 'stats: MinValue');
    assert(e.MaxValue == 90, 'stats: MaxValue');
    assert(abs(e.MeanValue - 82) < 1e-10, 'stats: MeanValue');
    assert(abs(e.RmsValue - 83) < 1e-10, 'stats: RmsValue');
    assert(abs(e.StdValue - 5) < 1e-10, 'stats: StdValue');

    % testInvalidDirection
    threw = false;
    try
        Event(1, 5, 'temp', 'warn', 80, 'sideways');
    catch
        threw = true;
    end
    assert(threw, 'invalidDirection: should throw');

    % testEndBeforeStart
    threw = false;
    try
        Event(10, 5, 'temp', 'warn', 80, 'high');
    catch
        threw = true;
    end
    assert(threw, 'endBeforeStart: should throw');

    fprintf('    All 4 event tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);setup();
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_event"`
Expected: FAIL — `Event` class not found.

**Step 3: Write minimal implementation**

Create `libs/EventDetection/Event.m`:

```matlab
classdef Event
    %EVENT Represents a single detected threshold violation event.
    %   e = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)
    %   e = e.setStats(peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal)

    properties (SetAccess = private)
        StartTime       % numeric: first violation timestamp
        EndTime         % numeric: last violation timestamp
        Duration        % numeric: EndTime - StartTime
        SensorName      % char: sensor/channel name
        ThresholdLabel  % char: threshold label
        ThresholdValue  % numeric: threshold value that was violated
        Direction       % char: 'high' or 'low'
        PeakValue       % numeric: worst violation value
        NumPoints       % numeric: number of data points in event window
        MinValue        % numeric: minimum signal value during event
        MaxValue        % numeric: maximum signal value during event
        MeanValue       % numeric: mean signal value during event
        RmsValue        % numeric: root mean square of signal during event
        StdValue        % numeric: standard deviation of signal during event
    end

    properties (Constant)
        DIRECTIONS = {'high', 'low'}
    end

    methods
        function obj = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)
            if ~ismember(direction, Event.DIRECTIONS)
                error('Event:invalidDirection', ...
                    'Direction must be ''high'' or ''low'', got ''%s''.', direction);
            end
            if endTime < startTime
                error('Event:invalidTimeRange', ...
                    'EndTime (%g) must be >= StartTime (%g).', endTime, startTime);
            end
            obj.StartTime = startTime;
            obj.EndTime = endTime;
            obj.Duration = endTime - startTime;
            obj.SensorName = sensorName;
            obj.ThresholdLabel = thresholdLabel;
            obj.ThresholdValue = thresholdValue;
            obj.Direction = direction;
            obj.PeakValue = [];
            obj.NumPoints = 0;
            obj.MinValue = [];
            obj.MaxValue = [];
            obj.MeanValue = [];
            obj.RmsValue = [];
            obj.StdValue = [];
        end

        function obj = setStats(obj, peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal)
            %SETSTATS Set event statistics.
            obj.PeakValue = peakValue;
            obj.NumPoints = numPoints;
            obj.MinValue = minVal;
            obj.MaxValue = maxVal;
            obj.MeanValue = meanVal;
            obj.RmsValue = rmsVal;
            obj.StdValue = stdVal;
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_event"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/Event.m tests/test_event.m
git commit -m "feat: add Event value class with metadata and stats"
```

---

### Task 2: groupViolations private helper

**Files:**
- Create: `libs/EventDetection/private/groupViolations.m`
- Test: `tests/test_group_violations.m`

**Step 1: Write the failing test**

Create `tests/test_group_violations.m`:

```matlab
function test_group_violations()
%TEST_GROUP_VIOLATIONS Tests for groupViolations private helper.

    add_event_path();
    add_event_private_path();

    % testSingleGroup — continuous violation
    t      = [1 2 3 4 5 6 7 8 9 10];
    values = [5 5 12 14 11 13 5 5 5 5];
    groups = groupViolations(t, values, 10, 'high');
    assert(numel(groups) == 1, 'singleGroup: count');
    assert(groups(1).startIdx == 3, 'singleGroup: startIdx');
    assert(groups(1).endIdx == 6, 'singleGroup: endIdx');

    % testTwoGroups — gap splits into two events
    t      = [1 2 3 4 5 6 7 8 9 10];
    values = [12 13 5 5 5 14 15 5 5 5];
    groups = groupViolations(t, values, 10, 'high');
    assert(numel(groups) == 2, 'twoGroups: count');
    assert(groups(1).startIdx == 1, 'twoGroups: g1 start');
    assert(groups(1).endIdx == 2, 'twoGroups: g1 end');
    assert(groups(2).startIdx == 6, 'twoGroups: g2 start');
    assert(groups(2).endIdx == 7, 'twoGroups: g2 end');

    % testLowDirection
    t      = [1 2 3 4 5];
    values = [50 3 2 4 50];
    groups = groupViolations(t, values, 10, 'low');
    assert(numel(groups) == 1, 'lowDir: count');
    assert(groups(1).startIdx == 2, 'lowDir: start');
    assert(groups(1).endIdx == 4, 'lowDir: end');

    % testNoViolations
    t      = [1 2 3 4 5];
    values = [5 6 7 8 9];
    groups = groupViolations(t, values, 10, 'high');
    assert(isempty(groups), 'noViolations: empty');

    % testAllViolations
    t      = [1 2 3];
    values = [20 30 40];
    groups = groupViolations(t, values, 10, 'high');
    assert(numel(groups) == 1, 'allViolations: count');
    assert(groups(1).startIdx == 1, 'allViolations: start');
    assert(groups(1).endIdx == 3, 'allViolations: end');

    fprintf('    All 5 group_violations tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);setup();
end

function add_event_private_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(fullfile(repo_root, 'libs', 'EventDetection', 'private'));
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_group_violations"`
Expected: FAIL — `groupViolations` not found.

**Step 3: Write minimal implementation**

Create `libs/EventDetection/private/groupViolations.m`:

```matlab
function groups = groupViolations(t, values, thresholdValue, direction)
%GROUPVIOLATIONS Cluster consecutive threshold violations into groups.
%   groups = groupViolations(t, values, thresholdValue, direction)
%
%   Returns struct array with fields: startIdx, endIdx.
%   Empty if no violations found.

    if strcmp(direction, 'high')
        violating = values > thresholdValue;
    else
        violating = values < thresholdValue;
    end

    groups = [];

    if ~any(violating)
        return;
    end

    % Find transitions: 0→1 = start, 1→0 = end
    d = diff([0, violating, 0]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;

    nGroups = numel(starts);
    groups = struct('startIdx', cell(1, nGroups), 'endIdx', cell(1, nGroups));
    for i = 1:nGroups
        groups(i).startIdx = starts(i);
        groups(i).endIdx   = ends(i);
    end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_group_violations"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/private/groupViolations.m tests/test_group_violations.m
git commit -m "feat: add groupViolations private helper for clustering violations"
```

---

### Task 3: EventDetector class

**Files:**
- Create: `libs/EventDetection/EventDetector.m`
- Test: `tests/test_event_detector.m`

**Step 1: Write the failing test**

Create `tests/test_event_detector.m`:

```matlab
function test_event_detector()
%TEST_EVENT_DETECTOR Tests for EventDetector class.

    add_event_path();

    % testDetectSingleEvent
    det = EventDetector();
    t      = [1 2 3 4 5 6 7 8 9 10];
    values = [5 5 12 14 11 13 5 5 5 5];
    events = det.detect(t, values, 10, 'high', 'warn', 'temp');
    assert(numel(events) == 1, 'singleEvent: count');
    assert(events(1).StartTime == 3, 'singleEvent: StartTime');
    assert(events(1).EndTime == 6, 'singleEvent: EndTime');
    assert(events(1).Duration == 3, 'singleEvent: Duration');
    assert(strcmp(events(1).SensorName, 'temp'), 'singleEvent: SensorName');
    assert(strcmp(events(1).ThresholdLabel, 'warn'), 'singleEvent: ThresholdLabel');
    assert(events(1).ThresholdValue == 10, 'singleEvent: ThresholdValue');
    assert(strcmp(events(1).Direction, 'high'), 'singleEvent: Direction');

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
    events = det.detect(t, values, 10, 'low', 'alarm', 'pressure');
    assert(events(1).PeakValue == 2, 'peakLow: PeakValue is min');

    % testMultipleEvents
    det = EventDetector();
    t      = [1 2 3 4 5 6 7 8 9 10];
    values = [12 13 5 5 5 14 15 5 5 5];
    events = det.detect(t, values, 10, 'high', 'warn', 'temp');
    assert(numel(events) == 2, 'multipleEvents: count');
    assert(events(1).StartTime == 1, 'multipleEvents: e1 start');
    assert(events(2).StartTime == 6, 'multipleEvents: e2 start');

    % testDebounceFilter
    det = EventDetector('MinDuration', 2);
    t      = [1 2 3 4 5 6 7 8 9 10];
    values = [12 5 5 14 15 16 17 5 5 5];
    events = det.detect(t, values, 10, 'high', 'warn', 'temp');
    % First event: t=1 to t=1, duration=0 -> filtered
    % Second event: t=4 to t=7, duration=3 -> kept
    assert(numel(events) == 1, 'debounce: count');
    assert(events(1).StartTime == 4, 'debounce: kept event');

    % testNoViolations
    det = EventDetector();
    t      = [1 2 3 4 5];
    values = [5 6 7 8 9];
    events = det.detect(t, values, 10, 'high', 'warn', 'temp');
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
    det.detect(t, values, 10, 'high', 'warn', 'temp');
    assert(callCount == 2, 'callback: called twice');
    assert(lastEvent.StartTime == 6, 'callback: last event');

    % testMaxCallsPerEvent
    callCount = 0;
    det = EventDetector('OnEventStart', @onEvent, 'MaxCallsPerEvent', 1);
    t      = [1 2 3 4 5];
    values = [12 13 14 15 16];
    det.detect(t, values, 10, 'high', 'warn', 'temp');
    assert(callCount == 1, 'maxCalls: only called once for one event');

    fprintf('    All 7 event_detector tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);setup();
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_event_detector"`
Expected: FAIL — `EventDetector` class not found.

**Step 3: Write minimal implementation**

Create `libs/EventDetection/EventDetector.m`:

```matlab
classdef EventDetector < handle
    %EVENTDETECTOR Detects events from threshold violations.
    %   det = EventDetector()
    %   det = EventDetector('MinDuration', 2, 'OnEventStart', @myCallback)
    %   events = det.detect(t, values, thresholdValue, direction, thresholdLabel, sensorName)

    properties
        MinDuration      % numeric: minimum event duration (default 0)
        OnEventStart     % function handle: callback f(event) on new event
        MaxCallsPerEvent % numeric: max callback invocations per event (default 1)
    end

    methods
        function obj = EventDetector(varargin)
            obj.MinDuration = 0;
            obj.OnEventStart = [];
            obj.MaxCallsPerEvent = 1;

            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'MinDuration',      obj.MinDuration = varargin{i+1};
                    case 'OnEventStart',     obj.OnEventStart = varargin{i+1};
                    case 'MaxCallsPerEvent', obj.MaxCallsPerEvent = varargin{i+1};
                    otherwise
                        error('EventDetector:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end

        function events = detect(obj, t, values, thresholdValue, direction, thresholdLabel, sensorName)
            %DETECT Find events from threshold violations.
            %   events = det.detect(t, values, thresholdValue, direction, thresholdLabel, sensorName)
            %   Returns Event array.

            groups = groupViolations(t, values, thresholdValue, direction);
            events = [];

            if isempty(groups)
                return;
            end

            callCount = 0;

            for i = 1:numel(groups)
                si = groups(i).startIdx;
                ei = groups(i).endIdx;

                startTime = t(si);
                endTime   = t(ei);
                duration  = endTime - startTime;

                % Debounce filter
                if duration < obj.MinDuration
                    continue;
                end

                ev = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction);

                % Compute stats over all points in event window
                windowValues = values(si:ei);
                nPts    = numel(windowValues);
                minVal  = min(windowValues);
                maxVal  = max(windowValues);
                meanVal = mean(windowValues);
                rmsVal  = sqrt(mean(windowValues.^2));
                stdVal  = std(windowValues);

                if strcmp(direction, 'high')
                    peakVal = maxVal;
                else
                    peakVal = minVal;
                end

                ev = ev.setStats(peakVal, nPts, minVal, maxVal, meanVal, rmsVal, stdVal);

                if isempty(events)
                    events = ev;
                else
                    events(end+1) = ev;
                end

                % Callback
                if ~isempty(obj.OnEventStart) && callCount < obj.MaxCallsPerEvent
                    obj.OnEventStart(ev);
                    callCount = callCount + 1;
                end
            end
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_event_detector"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/EventDetector.m tests/test_event_detector.m
git commit -m "feat: add EventDetector class with debounce and callbacks"
```

---

### Task 4: detectEventsFromSensor convenience function

**Files:**
- Create: `libs/EventDetection/detectEventsFromSensor.m`
- Test: `tests/test_detect_events_from_sensor.m`

**Step 1: Write the failing test**

Create `tests/test_detect_events_from_sensor.m`:

```matlab
function test_detect_events_from_sensor()
%TEST_DETECT_EVENTS_FROM_SENSOR Tests for Sensor convenience wrapper.

    add_event_path();

    % --- Setup: sensor with resolved violations ---
    s = Sensor('temp', 'Name', 'Temperature');
    s.X = [1 2 3 4 5 6 7 8 9 10];
    s.Y = [5 5 12 14 11 13 5 5 5 5];

    % Add a threshold rule (no state channels = always active)
    s.addThresholdRule(struct(), 10, 'Direction', 'upper', 'Label', 'warn high');
    s.resolve();

    % testDefaultDetector
    events = detectEventsFromSensor(s);
    assert(numel(events) >= 1, 'default: at least one event');
    assert(strcmp(events(1).SensorName, 'Temperature'), 'default: SensorName from sensor.Name');
    assert(strcmp(events(1).ThresholdLabel, 'warn high'), 'default: ThresholdLabel');
    assert(strcmp(events(1).Direction, 'high'), 'default: Direction');

    % testCustomDetector
    det = EventDetector('MinDuration', 5);
    events = detectEventsFromSensor(s, det);
    % Event duration is 3 (t=3 to t=6), so debounce should filter it
    assert(isempty(events), 'customDetector: debounced');

    % testMultipleThresholds — each threshold produces independent events
    s2 = Sensor('temp', 'Name', 'Temperature');
    s2.X = [1 2 3 4 5 6 7 8 9 10];
    s2.Y = [5 5 12 14 11 13 5 5 5 5];
    s2.addThresholdRule(struct(), 10, 'Direction', 'upper', 'Label', 'warn');
    s2.addThresholdRule(struct(), 13, 'Direction', 'upper', 'Label', 'critical');
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
    addpath(repo_root);setup();
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_detect_events_from_sensor"`
Expected: FAIL — `detectEventsFromSensor` not found.

**Step 3: Write minimal implementation**

Create `libs/EventDetection/detectEventsFromSensor.m`:

```matlab
function events = detectEventsFromSensor(sensor, detector)
%DETECTEVENTSFROMSENSOR Detect events from a Sensor object's resolved violations.
%   events = detectEventsFromSensor(sensor)
%   events = detectEventsFromSensor(sensor, detector)
%
%   Bridges the SensorThreshold and EventDetection libraries.
%   Uses sensor.ResolvedViolations and sensor.ResolvedThresholds to
%   detect events for each threshold independently.

    if nargin < 2
        detector = EventDetector();
    end

    % Use sensor Name if available, otherwise Key
    if ~isempty(sensor.Name)
        sensorName = sensor.Name;
    else
        sensorName = sensor.Key;
    end

    events = [];
    resolved = sensor.ResolvedViolations;

    if isempty(resolved)
        return;
    end

    for i = 1:numel(resolved)
        viol = resolved(i);
        vX = viol.X;
        vY = viol.Y;

        if isempty(vX)
            continue;
        end

        % Map SensorThreshold direction to EventDetection direction
        if strcmp(viol.Direction, 'upper')
            direction = 'high';
        else
            direction = 'low';
        end

        label = viol.Label;

        % Get threshold value from ResolvedThresholds
        thresholdValue = NaN;
        if ~isempty(sensor.ResolvedThresholds)
            for j = 1:numel(sensor.ResolvedThresholds)
                th = sensor.ResolvedThresholds(j);
                if strcmp(th.Label, label) && strcmp(th.Direction, viol.Direction)
                    % Use the non-NaN threshold value
                    validY = th.Y(~isnan(th.Y));
                    if ~isempty(validY)
                        thresholdValue = validY(1);
                    end
                    break;
                end
            end
        end

        % Detect events from violation points
        % Since these are already violation points, we create events by
        % grouping consecutive violation timestamps
        newEvents = detector.detect(sensor.X, sensor.Y, thresholdValue, direction, label, sensorName);

        if isempty(events)
            events = newEvents;
        elseif ~isempty(newEvents)
            events = [events, newEvents];
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_detect_events_from_sensor"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/detectEventsFromSensor.m tests/test_detect_events_from_sensor.m
git commit -m "feat: add detectEventsFromSensor convenience wrapper"
```

---

### Task 5: Update setup.m and integration test

**Files:**
- Modify: `setup.m`
- Test: `tests/test_event_integration.m`

**Step 1: Write the failing integration test**

Create `tests/test_event_integration.m`:

```matlab
function test_event_integration()
%TEST_EVENT_INTEGRATION End-to-end integration test for EventDetection library.

    add_event_path();

    % Full pipeline: Sensor → resolve → detectEventsFromSensor
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
    addpath(repo_root);setup();
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_event_integration"`
Expected: Fails if setup.m hasn't been updated yet (EventDetection not on path).

**Step 3: Update setup.m**

In `setup.m`, add the EventDetection library path:

```matlab
function setup()
%SETUP Add FastSense, SensorThreshold, and EventDetection libraries to the MATLAB path.
%   Run this once per session to make all library classes available.

    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'libs', 'FastSense'));
    addpath(fullfile(root, 'libs', 'SensorThreshold'));
    addpath(fullfile(root, 'libs', 'EventDetection'));
    fprintf('FastSense + SensorThreshold + EventDetection libraries added to path.\n');
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_event_integration"`
Expected: PASS

**Step 5: Run full test suite**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); run_all_tests"`
Expected: All tests pass, including the 4 new test files.

**Step 6: Commit**

```bash
git add setup.m tests/test_event_integration.m
git commit -m "feat: wire EventDetection into setup.m, add integration test"
```

---

### Task 6: Console output — printEventSummary and eventLogger

**Files:**
- Create: `libs/EventDetection/printEventSummary.m`
- Create: `libs/EventDetection/eventLogger.m`
- Test: `tests/test_event_console.m`

**Step 1: Write the failing test**

Create `tests/test_event_console.m`:

```matlab
function test_event_console()
%TEST_EVENT_CONSOLE Tests for console output functions.

    add_event_path();

    % --- Setup events ---
    e1 = Event(10, 25, 'Temperature', 'warning high', 80, 'high');
    e1 = e1.setStats(95.2, 150, 72, 95.2, 87.3, 88.1, 4.21);
    e2 = Event(50, 55, 'Pressure', 'low alarm', 5, 'low');
    e2 = e2.setStats(2.1, 50, 2.1, 6.8, 4.5, 4.7, 1.2);
    events = [e1, e2];

    % testPrintEventSummary — should not error, should produce output
    out = evalc('printEventSummary(events)');
    assert(~isempty(out), 'printSummary: produces output');
    assert(contains(out, 'Temperature'), 'printSummary: contains sensor name');
    assert(contains(out, 'warning high'), 'printSummary: contains threshold label');
    assert(contains(out, 'Pressure'), 'printSummary: contains second sensor');

    % testPrintEventSummaryEmpty — should not error
    out = evalc('printEventSummary([])');
    assert(contains(out, 'No events'), 'printSummaryEmpty: no events message');

    % testEventLogger — returns function handle
    logger = eventLogger();
    assert(isa(logger, 'function_handle'), 'eventLogger: returns function handle');

    % testEventLoggerOutput — prints one-line log
    out = evalc('logger(e1)');
    assert(~isempty(out), 'eventLoggerOutput: produces output');
    assert(contains(out, 'EVENT'), 'eventLoggerOutput: contains EVENT tag');
    assert(contains(out, 'Temperature'), 'eventLoggerOutput: contains sensor name');
    assert(contains(out, 'warning high'), 'eventLoggerOutput: contains label');

    fprintf('    All 4 event_console tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);setup();
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_event_console"`
Expected: FAIL — `printEventSummary` not found.

**Step 3: Write printEventSummary implementation**

Create `libs/EventDetection/printEventSummary.m`:

```matlab
function printEventSummary(events)
%PRINTEVENTSUMMARY Print a formatted table of events to the console.
%   printEventSummary(events)

    if isempty(events)
        fprintf('No events detected.\n');
        return;
    end

    % Header
    fprintf('\n');
    fprintf('%-12s %-12s %-10s %-16s %-18s %-6s %10s %6s %10s %10s\n', ...
        'Start', 'End', 'Duration', 'Sensor', 'Threshold', 'Dir', ...
        'Peak', '#Pts', 'Mean', 'Std');
    fprintf('%s\n', repmat('-', 1, 120));

    % Rows
    for i = 1:numel(events)
        e = events(i);
        fprintf('%-12.2f %-12.2f %-10.2f %-16s %-18s %-6s %10.2f %6d %10.2f %10.2f\n', ...
            e.StartTime, e.EndTime, e.Duration, ...
            truncStr(e.SensorName, 16), truncStr(e.ThresholdLabel, 18), ...
            e.Direction, e.PeakValue, e.NumPoints, e.MeanValue, e.StdValue);
    end
    fprintf('\n%d event(s) total.\n\n', numel(events));
end

function s = truncStr(s, maxLen)
    if numel(s) > maxLen
        s = [s(1:maxLen-2), '..'];
    end
end
```

**Step 4: Write eventLogger implementation**

Create `libs/EventDetection/eventLogger.m`:

```matlab
function fn = eventLogger()
%EVENTLOGGER Factory that returns a function handle for live event logging.
%   logger = eventLogger()
%   det = EventDetector('OnEventStart', eventLogger());
%
%   Each call to the returned function prints a one-line log message.

    fn = @logEvent;
end

function logEvent(ev)
    fprintf('[EVENT] %s | %s | %s | %.2f -> %.2f (dur=%.2f) | peak=%.2f\n', ...
        ev.SensorName, ev.ThresholdLabel, upper(ev.Direction), ...
        ev.StartTime, ev.EndTime, ev.Duration, ev.PeakValue);
end
```

**Step 5: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_event_console"`
Expected: PASS

**Step 6: Commit**

```bash
git add libs/EventDetection/printEventSummary.m libs/EventDetection/eventLogger.m tests/test_event_console.m
git commit -m "feat: add printEventSummary and eventLogger console output"
```

---

### Task 7: EventConfig class

**Files:**
- Create: `libs/EventDetection/EventConfig.m`
- Test: `tests/test_event_config.m`

**Step 1: Write the failing test**

Create `tests/test_event_config.m`:

```matlab
function test_event_config()
%TEST_EVENT_CONFIG Tests for EventConfig configuration class.

    add_event_path();

    % testConstructorDefaults
    cfg = EventConfig();
    assert(isempty(cfg.Sensors), 'defaults: Sensors empty');
    assert(isempty(cfg.SensorData), 'defaults: SensorData empty');
    assert(cfg.MinDuration == 0, 'defaults: MinDuration');
    assert(cfg.MaxCallsPerEvent == 1, 'defaults: MaxCallsPerEvent');
    assert(isempty(cfg.OnEventStart), 'defaults: OnEventStart');
    assert(cfg.AutoOpenViewer == false, 'defaults: AutoOpenViewer');

    % testAddSensor
    cfg = EventConfig();
    s = Sensor('temp', 'Name', 'Temperature');
    s.X = 1:10;
    s.Y = [5 5 12 14 11 13 5 5 5 5];
    s.addThresholdRule(struct(), 10, 'Direction', 'upper', 'Label', 'warn');
    cfg.addSensor(s);
    assert(numel(cfg.Sensors) == 1, 'addSensor: count');
    assert(numel(cfg.SensorData) == 1, 'addSensor: data count');
    assert(strcmp(cfg.SensorData(1).name, 'Temperature'), 'addSensor: data name');
    assert(isequal(cfg.SensorData(1).t, s.X), 'addSensor: data t');
    assert(isequal(cfg.SensorData(1).y, s.Y), 'addSensor: data y');

    % testSetColor
    cfg = EventConfig();
    cfg.setColor('warn', [1 0 0]);
    assert(isequal(cfg.ThresholdColors('warn'), [1 0 0]), 'setColor: stored');

    % testBuildDetector
    cfg = EventConfig();
    cfg.MinDuration = 5;
    cfg.MaxCallsPerEvent = 3;
    cfg.OnEventStart = @(e) disp(e);
    det = cfg.buildDetector();
    assert(isa(det, 'EventDetector'), 'buildDetector: class');
    assert(det.MinDuration == 5, 'buildDetector: MinDuration');
    assert(det.MaxCallsPerEvent == 3, 'buildDetector: MaxCallsPerEvent');
    assert(~isempty(det.OnEventStart), 'buildDetector: OnEventStart');

    % testRunDetection
    cfg = EventConfig();
    s = Sensor('temp', 'Name', 'Temperature');
    s.X = 1:10;
    s.Y = [5 5 12 14 11 13 5 5 5 5];
    s.addThresholdRule(struct(), 10, 'Direction', 'upper', 'Label', 'warn');
    cfg.addSensor(s);
    events = cfg.runDetection();
    assert(numel(events) >= 1, 'runDetection: found events');
    assert(strcmp(events(1).SensorName, 'Temperature'), 'runDetection: sensor name');

    fprintf('    All 5 event_config tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);setup();
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_event_config"`
Expected: FAIL — `EventConfig` class not found.

**Step 3: Write minimal implementation**

Create `libs/EventDetection/EventConfig.m`:

```matlab
classdef EventConfig < handle
    %EVENTCONFIG Configuration for the event detection system.
    %   cfg = EventConfig()
    %   cfg.MinDuration = 2;
    %   cfg.addSensor(sensor);
    %   events = cfg.runDetection();

    properties
        Sensors           % cell array of Sensor objects
        SensorData        % struct array: name, t, y (for viewer click-to-plot)
        MinDuration       % numeric: debounce (default 0)
        MaxCallsPerEvent  % numeric: callback limit (default 1)
        OnEventStart      % function handle: callback
        ThresholdColors   % containers.Map: label → [R G B]
        AutoOpenViewer    % logical: auto-open EventViewer after detection
    end

    methods
        function obj = EventConfig()
            obj.Sensors = {};
            obj.SensorData = [];
            obj.MinDuration = 0;
            obj.MaxCallsPerEvent = 1;
            obj.OnEventStart = [];
            obj.ThresholdColors = containers.Map();
            obj.AutoOpenViewer = false;
        end

        function addSensor(obj, sensor)
            %ADDSENSOR Register a sensor with its data.
            sensor.resolve();
            obj.Sensors{end+1} = sensor;

            % Store data for viewer
            if ~isempty(sensor.Name)
                name = sensor.Name;
            else
                name = sensor.Key;
            end
            entry.name = name;
            entry.t = sensor.X;
            entry.y = sensor.Y;

            if isempty(obj.SensorData)
                obj.SensorData = entry;
            else
                obj.SensorData(end+1) = entry;
            end
        end

        function setColor(obj, label, rgb)
            %SETCOLOR Set color for a threshold label.
            obj.ThresholdColors(label) = rgb;
        end

        function det = buildDetector(obj)
            %BUILDDETECTOR Create a configured EventDetector.
            args = {'MinDuration', obj.MinDuration, ...
                    'MaxCallsPerEvent', obj.MaxCallsPerEvent};
            if ~isempty(obj.OnEventStart)
                args = [args, {'OnEventStart', obj.OnEventStart}];
            end
            det = EventDetector(args{:});
        end

        function events = runDetection(obj)
            %RUNDETECTION Detect events across all configured sensors.
            det = obj.buildDetector();
            events = [];

            for i = 1:numel(obj.Sensors)
                newEvents = detectEventsFromSensor(obj.Sensors{i}, det);
                if isempty(events)
                    events = newEvents;
                elseif ~isempty(newEvents)
                    events = [events, newEvents];
                end
            end

            if obj.AutoOpenViewer && ~isempty(events)
                if isempty(obj.ThresholdColors) || obj.ThresholdColors.Count == 0
                    EventViewer(events, obj.SensorData);
                else
                    EventViewer(events, obj.SensorData, obj.ThresholdColors);
                end
            end
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_event_config"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/EventConfig.m tests/test_event_config.m
git commit -m "feat: add EventConfig configuration class"
```

---

### Task 8: EventViewer figure UI

**Files:**
- Create: `libs/EventDetection/EventViewer.m`
- Test: `tests/test_event_viewer.m`

**Step 1: Write the failing test**

Create `tests/test_event_viewer.m`:

```matlab
function test_event_viewer()
%TEST_EVENT_VIEWER Tests for EventViewer figure UI.
%   Note: these tests run headless — they verify object creation and
%   data wiring, not visual rendering.

    add_event_path();

    % --- Setup events ---
    e1 = Event(10, 25, 'Temperature', 'warning high', 80, 'high');
    e1 = e1.setStats(95.2, 150, 72, 95.2, 87.3, 88.1, 4.21);
    e2 = Event(50, 55, 'Pressure', 'low alarm', 5, 'low');
    e2 = e2.setStats(2.1, 50, 2.1, 6.8, 4.5, 4.7, 1.2);
    e3 = Event(30, 40, 'Temperature', 'critical high', 100, 'high');
    e3 = e3.setStats(110, 80, 95, 110, 103, 104, 3.5);
    events = [e1, e2, e3];

    sensorData(1).name = 'Temperature';
    sensorData(1).t = 1:100;
    sensorData(1).y = 50 + 30*sin((1:100)/10);
    sensorData(2).name = 'Pressure';
    sensorData(2).t = 1:100;
    sensorData(2).y = 10 + 5*sin((1:100)/8);

    colors = containers.Map();
    colors('warning high') = [1 0.8 0];
    colors('critical high') = [1 0 0];
    colors('low alarm') = [0 0.5 1];

    % testConstructorEventsOnly
    viewer = EventViewer(events);
    assert(~isempty(viewer.hFigure), 'eventsOnly: figure created');
    assert(ishandle(viewer.hFigure), 'eventsOnly: valid handle');
    close(viewer.hFigure);

    % testConstructorWithSensorData
    viewer = EventViewer(events, sensorData);
    assert(~isempty(viewer.SensorData), 'withData: SensorData stored');
    close(viewer.hFigure);

    % testConstructorWithColors
    viewer = EventViewer(events, sensorData, colors);
    assert(~isempty(viewer.ThresholdColors), 'withColors: colors stored');
    close(viewer.hFigure);

    % testUpdate — should not error
    viewer = EventViewer(events, sensorData);
    e4 = Event(70, 75, 'Temperature', 'warning high', 80, 'high');
    e4 = e4.setStats(88, 50, 78, 88, 83, 84, 2.1);
    viewer.update([events, e4]);
    close(viewer.hFigure);

    % testFilterSensors — getSensorNames returns unique sensor names
    viewer = EventViewer(events);
    names = viewer.getSensorNames();
    assert(numel(names) == 2, 'filterSensors: 2 unique sensors');
    assert(any(strcmp(names, 'Temperature')), 'filterSensors: has Temperature');
    assert(any(strcmp(names, 'Pressure')), 'filterSensors: has Pressure');
    close(viewer.hFigure);

    % testFilterLabels — getThresholdLabels returns unique labels
    viewer = EventViewer(events);
    labels = viewer.getThresholdLabels();
    assert(numel(labels) == 3, 'filterLabels: 3 unique labels');
    close(viewer.hFigure);

    fprintf('    All 6 event_viewer tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);setup();
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_event_viewer"`
Expected: FAIL — `EventViewer` class not found.

**Step 3: Write implementation**

Create `libs/EventDetection/EventViewer.m`:

```matlab
classdef EventViewer < handle
    %EVENTVIEWER Figure-based event viewer with Gantt timeline and filterable table.
    %   viewer = EventViewer(events)
    %   viewer = EventViewer(events, sensorData)
    %   viewer = EventViewer(events, sensorData, thresholdColors)
    %   viewer.update(newEvents)

    properties
        Events          % Event array
        SensorData      % struct array: name, t, y (for click-to-plot)
        ThresholdColors % containers.Map: label → [R G B]
        hFigure         % figure handle
    end

    properties (Access = private)
        hTimelineAxes   % axes for Gantt chart
        hTable          % uitable handle
        hSensorFilter   % popup menu for sensor filter
        hLabelFilter    % popup menu for label filter
        FilteredEvents  % currently displayed events after filtering
    end

    methods
        function obj = EventViewer(events, sensorData, thresholdColors)
            obj.Events = events;
            obj.FilteredEvents = events;

            if nargin >= 2
                obj.SensorData = sensorData;
            else
                obj.SensorData = [];
            end

            if nargin >= 3
                obj.ThresholdColors = thresholdColors;
            else
                obj.ThresholdColors = containers.Map();
            end

            obj.buildFigure();
        end

        function update(obj, events)
            %UPDATE Refresh the viewer with new events.
            obj.Events = events;
            obj.applyFilters();
        end

        function names = getSensorNames(obj)
            %GETSENSORNAMES Get unique sensor names from events.
            names = unique(arrayfun(@(e) e.SensorName, obj.Events, 'UniformOutput', false));
        end

        function labels = getThresholdLabels(obj)
            %GETTHRESHOLDLABELS Get unique threshold labels from events.
            labels = unique(arrayfun(@(e) e.ThresholdLabel, obj.Events, 'UniformOutput', false));
        end
    end

    methods (Access = private)
        function buildFigure(obj)
            obj.hFigure = figure('Name', 'Event Viewer', ...
                'NumberTitle', 'off', ...
                'Position', [100 100 1200 700], ...
                'Color', [0.15 0.15 0.18]);

            % --- Top panel: Gantt timeline ---
            obj.hTimelineAxes = axes('Parent', obj.hFigure, ...
                'Position', [0.05 0.55 0.9 0.40], ...
                'Color', [0.2 0.2 0.23], ...
                'XColor', [0.8 0.8 0.8], ...
                'YColor', [0.8 0.8 0.8]);
            title(obj.hTimelineAxes, 'Event Timeline', 'Color', [0.9 0.9 0.9]);
            hold(obj.hTimelineAxes, 'on');

            % --- Filter dropdowns ---
            uicontrol('Parent', obj.hFigure, 'Style', 'text', ...
                'String', 'Sensor:', ...
                'Units', 'normalized', 'Position', [0.05 0.48 0.05 0.03], ...
                'BackgroundColor', [0.15 0.15 0.18], 'ForegroundColor', [0.8 0.8 0.8]);

            sensorNames = [{'All'}, obj.getSensorNames()];
            obj.hSensorFilter = uicontrol('Parent', obj.hFigure, 'Style', 'popupmenu', ...
                'String', sensorNames, ...
                'Units', 'normalized', 'Position', [0.10 0.48 0.15 0.03], ...
                'Callback', @(~,~) obj.applyFilters());

            uicontrol('Parent', obj.hFigure, 'Style', 'text', ...
                'String', 'Threshold:', ...
                'Units', 'normalized', 'Position', [0.28 0.48 0.07 0.03], ...
                'BackgroundColor', [0.15 0.15 0.18], 'ForegroundColor', [0.8 0.8 0.8]);

            threshLabels = [{'All'}, obj.getThresholdLabels()];
            obj.hLabelFilter = uicontrol('Parent', obj.hFigure, 'Style', 'popupmenu', ...
                'String', threshLabels, ...
                'Units', 'normalized', 'Position', [0.35 0.48 0.15 0.03], ...
                'Callback', @(~,~) obj.applyFilters());

            % --- Bottom panel: event table ---
            columnNames = {'Start', 'End', 'Duration', 'Sensor', 'Threshold', ...
                'Dir', 'Peak', '#Pts', 'Min', 'Max', 'Mean', 'RMS', 'Std'};
            obj.hTable = uitable('Parent', obj.hFigure, ...
                'Units', 'normalized', 'Position', [0.05 0.03 0.9 0.42], ...
                'ColumnName', columnNames, ...
                'ColumnWidth', {70 70 65 120 130 45 70 50 70 70 70 70 70}, ...
                'CellSelectionCallback', @(src, evt) obj.onRowClick(src, evt));

            obj.drawTimeline();
            obj.populateTable();
        end

        function drawTimeline(obj)
            cla(obj.hTimelineAxes);
            events = obj.FilteredEvents;

            if isempty(events)
                return;
            end

            sensorNames = obj.getSensorNames();
            nSensors = numel(sensorNames);

            % Default colors
            defaultColors = [0.2 0.6 1; 1 0.4 0.2; 0.2 0.8 0.4; ...
                             1 0.8 0; 0.6 0.3 0.8; 0 0.8 0.8];

            for i = 1:numel(events)
                ev = events(i);
                sIdx = find(strcmp(sensorNames, ev.SensorName));
                yPos = nSensors - sIdx + 1;

                % Get color
                if obj.ThresholdColors.isKey(ev.ThresholdLabel)
                    c = obj.ThresholdColors(ev.ThresholdLabel);
                else
                    c = defaultColors(mod(sIdx-1, size(defaultColors,1)) + 1, :);
                end

                barH = 0.6;
                duration = max(ev.Duration, 0.5); % min width for visibility
                rectangle(obj.hTimelineAxes, ...
                    'Position', [ev.StartTime, yPos - barH/2, duration, barH], ...
                    'FaceColor', c, 'EdgeColor', c * 0.7, ...
                    'LineWidth', 1, 'Curvature', [0.1 0.1]);
            end

            set(obj.hTimelineAxes, 'YTick', 1:nSensors, ...
                'YTickLabel', flip(sensorNames), ...
                'YLim', [0.3, nSensors + 0.7]);
            xlabel(obj.hTimelineAxes, 'Time', 'Color', [0.8 0.8 0.8]);
        end

        function populateTable(obj)
            events = obj.FilteredEvents;

            if isempty(events)
                set(obj.hTable, 'Data', {});
                return;
            end

            nEvents = numel(events);
            data = cell(nEvents, 13);
            for i = 1:nEvents
                ev = events(i);
                data{i,1}  = ev.StartTime;
                data{i,2}  = ev.EndTime;
                data{i,3}  = ev.Duration;
                data{i,4}  = ev.SensorName;
                data{i,5}  = ev.ThresholdLabel;
                data{i,6}  = ev.Direction;
                data{i,7}  = ev.PeakValue;
                data{i,8}  = ev.NumPoints;
                data{i,9}  = ev.MinValue;
                data{i,10} = ev.MaxValue;
                data{i,11} = ev.MeanValue;
                data{i,12} = ev.RmsValue;
                data{i,13} = ev.StdValue;
            end
            set(obj.hTable, 'Data', data);
        end

        function applyFilters(obj)
            events = obj.Events;

            if isempty(events)
                obj.FilteredEvents = [];
                obj.drawTimeline();
                obj.populateTable();
                return;
            end

            % Sensor filter
            sensorIdx = get(obj.hSensorFilter, 'Value');
            sensorNames = get(obj.hSensorFilter, 'String');
            if sensorIdx > 1
                selectedSensor = sensorNames{sensorIdx};
                mask = arrayfun(@(e) strcmp(e.SensorName, selectedSensor), events);
                events = events(mask);
            end

            % Label filter
            labelIdx = get(obj.hLabelFilter, 'Value');
            labelNames = get(obj.hLabelFilter, 'String');
            if labelIdx > 1
                selectedLabel = labelNames{labelIdx};
                mask = arrayfun(@(e) strcmp(e.ThresholdLabel, selectedLabel), events);
                events = events(mask);
            end

            obj.FilteredEvents = events;
            obj.drawTimeline();
            obj.populateTable();
        end

        function onRowClick(obj, ~, evt)
            if isempty(evt.Indices)
                return;
            end
            row = evt.Indices(1);
            ev = obj.FilteredEvents(row);

            % Find matching sensor data
            if isempty(obj.SensorData)
                return;
            end

            sIdx = [];
            for i = 1:numel(obj.SensorData)
                if strcmp(obj.SensorData(i).name, ev.SensorName)
                    sIdx = i;
                    break;
                end
            end

            if isempty(sIdx)
                return;
            end

            sd = obj.SensorData(sIdx);

            % Open FastSense for this sensor, zoomed to event
            fp = FastSense();
            fp.addLine(sd.t, sd.y, 'Label', sd.name);

            % Add threshold line
            fp.addThreshold(ev.ThresholdValue, ...
                'Label', ev.ThresholdLabel, ...
                'Direction', ev.Direction);

            % Zoom to event with 20% padding
            margin = ev.Duration * 0.2;
            if margin == 0
                margin = 5;
            end
            fp.XLim = [ev.StartTime - margin, ev.EndTime + margin];
            fp.render();
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); test_event_viewer"`
Expected: PASS

**Step 5: Commit**

```bash
git add libs/EventDetection/EventViewer.m tests/test_event_viewer.m
git commit -m "feat: add EventViewer with Gantt timeline, table, and click-to-plot"
```

---

### Task 9: Live demo example script

**Files:**
- Create: `examples/example_event_detection_live.m`

**Step 1: Write the example**

Create `examples/example_event_detection_live.m`:

```matlab
function example_event_detection_live()
%EXAMPLE_EVENT_DETECTION_LIVE Live event detection demo with industrial sensors.
%   Demonstrates the EventDetection library with 3 mock industrial sensors,
%   threshold-based event detection, console logging, EventViewer UI,
%   and a MATLAB timer for live data updates.
%
%   Run:  example_event_detection_live()
%   Stop: example_event_detection_live('stop')

    setup();

    persistent liveTimer liveViewer liveCfg liveN;

    % --- Handle stop command ---
    if nargin == 0
        % Start mode — fall through
    else
        error('Use the returned stop function to stop live mode.');
    end

    fprintf('\n=== Event Detection Live Demo ===\n\n');

    % --- 1. Create mock sensor data ---
    N = 500;  % initial data points
    dt = 0.1; % sample interval (seconds)
    t = (0:N-1) * dt;

    % Temperature: baseline 70°C, with ramps and spikes
    temp = 70 + 5*sin(t/5) + 2*randn(1, N);
    % Inject a ramp violation at t=20-30
    rampIdx = t >= 20 & t <= 30;
    temp(rampIdx) = temp(rampIdx) + linspace(0, 25, sum(rampIdx));
    % Inject a spike at t=40
    spikeIdx = t >= 40 & t <= 42;
    temp(spikeIdx) = temp(spikeIdx) + 30;

    % Pressure: baseline 6 bar, with dips
    pressure = 6 + 0.5*sin(t/3) + 0.3*randn(1, N);
    % Inject a low-pressure event at t=15-18
    lowIdx = t >= 15 & t <= 18;
    pressure(lowIdx) = pressure(lowIdx) - 4;

    % Vibration: baseline 2 mm/s, with oscillation bursts
    vibration = 2 + 0.3*randn(1, N);
    % Inject oscillation burst at t=35-45
    burstIdx = t >= 35 & t <= 45;
    vibration(burstIdx) = vibration(burstIdx) + 4 * abs(sin((t(burstIdx)-35)*3));

    % --- 2. Create Sensor objects ---
    sTemp = Sensor('temperature', 'Name', 'Temperature');
    sTemp.X = t; sTemp.Y = temp;
    sTemp.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'temp warning');
    sTemp.addThresholdRule(struct(), 95, 'Direction', 'upper', 'Label', 'temp critical');

    sPres = Sensor('pressure', 'Name', 'Pressure');
    sPres.X = t; sPres.Y = pressure;
    sPres.addThresholdRule(struct(), 4, 'Direction', 'lower', 'Label', 'pressure low');

    sVib = Sensor('vibration', 'Name', 'Vibration');
    sVib.X = t; sVib.Y = vibration;
    sVib.addThresholdRule(struct(), 5, 'Direction', 'upper', 'Label', 'vibration high');

    % --- 3. Configure event detection ---
    cfg = EventConfig();
    cfg.MinDuration = 0.5;
    cfg.OnEventStart = eventLogger();
    cfg.MaxCallsPerEvent = 2;

    cfg.addSensor(sTemp);
    cfg.addSensor(sPres);
    cfg.addSensor(sVib);

    cfg.setColor('temp warning',  [1.0 0.8 0.0]);
    cfg.setColor('temp critical', [1.0 0.2 0.0]);
    cfg.setColor('pressure low',  [0.2 0.5 1.0]);
    cfg.setColor('vibration high',[0.8 0.3 0.8]);

    % --- 4. Initial detection ---
    fprintf('--- Initial Detection ---\n');
    events = cfg.runDetection();

    fprintf('\n--- Event Summary ---\n');
    printEventSummary(events);

    % --- 5. Open EventViewer ---
    liveViewer = EventViewer(events, cfg.SensorData, cfg.ThresholdColors);
    liveCfg = cfg;
    liveN = N;

    % --- 6. Start live timer ---
    fprintf('Starting live mode (new data every 2 seconds)...\n');
    fprintf('Close the Event Viewer figure to stop.\n\n');

    liveTimer = timer('ExecutionMode', 'fixedRate', ...
        'Period', 2.0, ...
        'TimerFcn', @(~,~) liveUpdate());

    % Stop when figure is closed
    set(liveViewer.hFigure, 'DeleteFcn', @(~,~) stopLive());

    start(liveTimer);

    function liveUpdate()
        try
            % Append 50 new data points
            nNew = 50;
            liveN = liveN + nNew;
            tNew = ((liveN - nNew):(liveN - 1)) * dt;

            % Generate new data with occasional violations
            newTemp = 70 + 5*sin(tNew/5) + 2*randn(1, nNew);
            newPres = 6 + 0.5*sin(tNew/3) + 0.3*randn(1, nNew);
            newVib  = 2 + 0.3*randn(1, nNew);

            % Random chance of violations
            if rand() < 0.3
                vi = randi(nNew);
                span = min(vi+10, nNew);
                newTemp(vi:span) = newTemp(vi:span) + 20;
            end
            if rand() < 0.2
                vi = randi(nNew);
                span = min(vi+8, nNew);
                newPres(vi:span) = newPres(vi:span) - 4;
            end

            % Update sensors
            for i = 1:numel(liveCfg.Sensors)
                s = liveCfg.Sensors{i};
                switch s.Key
                    case 'temperature'
                        s.X = [s.X, tNew]; s.Y = [s.Y, newTemp];
                    case 'pressure'
                        s.X = [s.X, tNew]; s.Y = [s.Y, newPres];
                    case 'vibration'
                        s.X = [s.X, tNew]; s.Y = [s.Y, newVib];
                end
                liveCfg.SensorData(i).t = s.X;
                liveCfg.SensorData(i).y = s.Y;
            end

            % Re-detect
            fprintf('--- Live Update (t=%.1f) ---\n', tNew(end));
            events = liveCfg.runDetection();

            % Update viewer
            if isvalid(liveViewer) && ishandle(liveViewer.hFigure)
                liveViewer.update(events);
            end
        catch err
            fprintf('Live update error: %s\n', err.message);
        end
    end

    function stopLive()
        if ~isempty(liveTimer) && isvalid(liveTimer)
            stop(liveTimer);
            delete(liveTimer);
            fprintf('\nLive mode stopped.\n');
        end
    end
end
```

**Step 2: Verify example runs**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('examples'); example_event_detection_live"`
Expected: Console output shows initial detection + live logging. EventViewer figure opens with Gantt timeline and table. Timer appends data every 2 seconds.

**Step 3: Commit**

```bash
git add examples/example_event_detection_live.m
git commit -m "feat: add live event detection demo with industrial mock data"
```

---

### Task 10: Full test suite run and final commit

**Step 1: Run full test suite**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); run_all_tests"`
Expected: All tests pass, including the 6 new test files:
- `test_event.m`
- `test_group_violations.m`
- `test_event_detector.m`
- `test_detect_events_from_sensor.m`
- `test_event_console.m`
- `test_event_config.m`
- `test_event_viewer.m`
- `test_event_integration.m`

**Step 2: Verify no regressions**

All existing 33 tests should still pass unchanged.
