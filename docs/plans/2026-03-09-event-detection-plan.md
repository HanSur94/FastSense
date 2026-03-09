# Event Detection Library Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a third library (`libs/EventDetection/`) that groups threshold violations into events with statistics, debounce filtering, and configurable callbacks.

**Architecture:** Standalone `EventDetector` class with configurable debounce and callback. `Event` value class holds metadata and stats. Private `groupViolations` helper does the core clustering. Convenience function `detectEventsFromSensor` bridges to the SensorThreshold library.

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

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_event"`
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

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_event"`
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

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_group_violations"`
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

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_group_violations"`
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

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_event_detector"`
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

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_event_detector"`
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

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_detect_events_from_sensor"`
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

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_detect_events_from_sensor"`
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

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_event_integration"`
Expected: Fails if setup.m hasn't been updated yet (EventDetection not on path).

**Step 3: Update setup.m**

In `setup.m`, add the EventDetection library path:

```matlab
function setup()
%SETUP Add FastPlot, SensorThreshold, and EventDetection libraries to the MATLAB path.
%   Run this once per session to make all library classes available.

    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'libs', 'FastPlot'));
    addpath(fullfile(root, 'libs', 'SensorThreshold'));
    addpath(fullfile(root, 'libs', 'EventDetection'));
    fprintf('FastPlot + SensorThreshold + EventDetection libraries added to path.\n');
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_event_integration"`
Expected: PASS

**Step 5: Run full test suite**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); run_all_tests"`
Expected: All tests pass, including the 4 new test files.

**Step 6: Commit**

```bash
git add setup.m tests/test_event_integration.m
git commit -m "feat: wire EventDetection into setup.m, add integration test"
```
