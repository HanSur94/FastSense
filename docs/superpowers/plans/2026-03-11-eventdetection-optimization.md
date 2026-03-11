# EventDetection Optimization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optimize the EventDetection library: incremental-only detection, cached bar positions, and unified backup logic.

**Architecture:** Three independent changes — (1) IncrementalEventDetector detects over a data slice instead of full history, (2) EventViewer caches bar positions in a matrix for O(1) hit-testing, (3) EventConfig delegates backup/save to EventStore.

**Tech Stack:** MATLAB

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `libs/EventDetection/IncrementalEventDetector.m` | Modify | Slice-based detection in `process()` |
| `libs/EventDetection/EventViewer.m` | Modify | Add `BarPositions` matrix, update `drawTimeline` and `findBarUnderCursor` |
| `libs/EventDetection/EventStore.m` | Modify | Add `ThresholdColors` and `Timestamp` properties, save them in `save()` |
| `libs/EventDetection/EventConfig.m` | Modify | Delete `saveEvents`/`pruneBackups`, delegate to `EventStore` |
| `tests/test_incremental_detector.m` | Modify | Add test for slice-based detection efficiency |
| `tests/test_event_viewer.m` | Modify | Add test for cached bar positions |
| `tests/test_event_config.m` | Modify | Add test for EventConfig saving via EventStore |

---

## Task 1: Slice-based detection in IncrementalEventDetector

**Files:**
- Modify: `tests/test_incremental_detector.m`
- Modify: `libs/EventDetection/IncrementalEventDetector.m:31-80`

- [ ] **Step 1: Write failing test — slice detection produces same results**

Add this test to `tests/test_incremental_detector.m` — verifies that multi-batch detection with long history still finds events correctly (regression test for the slice change):

```matlab
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
```

- [ ] **Step 2: Register the test in the runner**

Add `test_slice_detection_consistency();` to the function list at the top of `test_incremental_detector.m` (after line 9, before `fprintf`).

- [ ] **Step 3: Run test to verify it passes with current code (baseline)**

Run in MATLAB:
```
cd('/Users/hannessuhr/FastPlot'); setup(); cd('tests'); test_incremental_detector
```
Expected: ALL PASSED (this test should pass with current code too — it's a regression test)

- [ ] **Step 4: Implement slice-based detection**

In `libs/EventDetection/IncrementalEventDetector.m`, replace the `process()` method body (lines 31-153). The key change is lines 47-80 — instead of building tmpSensor with full `st.fullX`/`st.fullY`, use a slice:

```matlab
function newEvents = process(obj, sensorKey, sensor, newX, newY, newStateX, newStateY)
    newEvents = Event.empty();
    if isempty(newX); return; end

    st = obj.getState(sensorKey);

    % Append new data (kept for EventViewer click-to-plot)
    st.fullX = [st.fullX, newX];
    st.fullY = [st.fullY, newY];

    % Update state channels if new state data
    if ~isempty(newStateX)
        st.stateX = [st.stateX, newStateX];
        st.stateY = [st.stateY, newStateY];
    end

    % Determine slice start: open event start or new data start
    if ~isempty(st.openEvent)
        sliceStart = st.openEvent.StartTime;
    else
        sliceStart = newX(1);
    end

    % Find slice index in accumulated data
    sliceIdx = binary_search(st.fullX, sliceStart, 'left');
    sliceX = st.fullX(sliceIdx:end);
    sliceY = st.fullY(sliceIdx:end);

    % Build a temporary sensor for detection on the slice
    tmpSensor = Sensor(sensorKey);
    tmpSensor.X = sliceX;
    tmpSensor.Y = sliceY;

    % Copy threshold rules from the source sensor
    for i = 1:numel(sensor.ThresholdRules)
        rule = sensor.ThresholdRules{i};
        tmpSensor.addThresholdRule(rule.Condition, rule.Value, ...
            'Direction', rule.Direction, 'Label', rule.Label, ...
            'Color', rule.Color, 'LineStyle', rule.LineStyle);
    end

    % Copy state channels — use accumulated state data (sliced)
    for i = 1:numel(sensor.StateChannels)
        origSC = sensor.StateChannels{i};
        if ~isempty(st.stateX)
            sc = StateChannel(origSC.Key);
            % Slice state data to match time window
            stSliceIdx = binary_search(st.stateX, sliceStart, 'left');
            sc.X = st.stateX(stSliceIdx:end);
            sc.Y = st.stateY(stSliceIdx:end);
        else
            sc = origSC;
        end
        tmpSensor.addStateChannel(sc);
    end

    tmpSensor.resolve();

    % Build detector
    det = EventDetector('MinDuration', obj.MinDuration, ...
        'MaxCallsPerEvent', obj.MaxCallsPerEvent);

    % Detect on slice using existing infrastructure
    allEvents = detectEventsFromSensor(tmpSensor, det);

    % Filter to only events that touch the new data window
    sliceStartTime = newX(1);
    relevantEvents = Event.empty();
    if ~isempty(allEvents)
        for i = 1:numel(allEvents)
            ev = allEvents(i);
            if ev.EndTime >= sliceStartTime
                relevantEvents(end+1) = ev;
            end
        end
    end

    % Handle open events
    completedEvents = Event.empty();
    newOpenEvent = [];

    for i = 1:numel(relevantEvents)
        ev = relevantEvents(i);
        if ev.EndTime >= newX(end) && ...
           obj.isViolationAtEnd(st.fullY, ev)
            % Event is still ongoing at end of this batch
            newOpenEvent = ev;
        else
            % Check if this merges with previous open event
            if ~isempty(st.openEvent) && ...
               strcmp(ev.ThresholdLabel, st.openEvent.ThresholdLabel) && ...
               ev.StartTime <= st.openEvent.EndTime + 1/86400
                % Merge: use earlier start, recompute stats
                merged = Event(st.openEvent.StartTime, ev.EndTime, ...
                    ev.SensorName, ev.ThresholdLabel, ev.ThresholdValue, ev.Direction);
                idx1 = find(st.fullX >= st.openEvent.StartTime, 1);
                idx2 = find(st.fullX <= ev.EndTime, 1, 'last');
                window = st.fullY(idx1:idx2);
                merged = obj.computeAndSetStats(merged, window, ev.Direction);
                completedEvents(end+1) = merged;
            elseif ~obj.isOldEvent(ev, st.lastProcessedTime)
                completedEvents(end+1) = ev;
            end
        end
    end

    % Finalize previous open event if it didn't merge
    if ~isempty(st.openEvent) && isempty(completedEvents)
        if ~isempty(newOpenEvent) && ...
           strcmp(newOpenEvent.ThresholdLabel, st.openEvent.ThresholdLabel)
            % Still open, carry forward
        else
            % Open event ended
            completedEvents(end+1) = st.openEvent;
        end
    end

    % Escalate severity
    if obj.EscalateSeverity && ~isempty(completedEvents)
        completedEvents = obj.escalate(completedEvents, sensor);
    end

    % Update state
    st.openEvent = newOpenEvent;
    st.lastProcessedTime = newX(end);
    obj.sensorState_(sensorKey) = st;

    % Fire callbacks
    for i = 1:numel(completedEvents)
        if ~isempty(obj.OnEventStart)
            obj.OnEventStart(completedEvents(i));
        end
    end

    newEvents = completedEvents;
end
```

- [ ] **Step 5: Run all incremental detector tests**

Run in MATLAB:
```
cd('/Users/hannessuhr/FastPlot'); setup(); cd('tests'); test_incremental_detector
```
Expected: ALL PASSED (8 tests including the new one)

- [ ] **Step 6: Run full test suite**

Run in MATLAB:
```
cd('/Users/hannessuhr/FastPlot'); setup(); cd('tests'); run_all_tests
```
Expected: 52/52 passed, 0 failed

- [ ] **Step 7: Commit**

```bash
git add tests/test_incremental_detector.m libs/EventDetection/IncrementalEventDetector.m
git commit -m "feat: slice-based detection in IncrementalEventDetector

Detect over a data slice (from open event start or new data start)
instead of full accumulated history. Reduces per-cycle CPU from O(N)
to O(slice) where N grows over months of runtime."
```

---

## Task 2: Cache bar positions in EventViewer

**Files:**
- Modify: `tests/test_event_viewer.m`
- Modify: `libs/EventDetection/EventViewer.m`

- [ ] **Step 1: Write failing test — BarPositions matrix populated**

Add this test to `tests/test_event_viewer.m`:

```matlab
function test_bar_positions_cached()
    events = makeEvents();
    viewer = EventViewer(events);
    % BarPositions should be an Nx4 matrix matching BarRects count
    assert(~isempty(viewer.BarPositions), 'bar_positions_not_empty');
    assert(size(viewer.BarPositions, 1) == numel(viewer.BarRects), 'bar_positions_count');
    assert(size(viewer.BarPositions, 2) == 4, 'bar_positions_cols');
    % Each row should have positive width and height
    assert(all(viewer.BarPositions(:,3) > 0), 'bar_widths_positive');
    assert(all(viewer.BarPositions(:,4) > 0), 'bar_heights_positive');
    close(viewer.hFigure);
    fprintf('  PASS: test_bar_positions_cached\n');
end
```

Note: `BarPositions` needs to be accessible from tests. Since it's currently going to be a private property, either make it public or add a getter. For testability, add it as a read-only public property.

- [ ] **Step 2: Register the test in the runner**

Add `test_bar_positions_cached();` to the test function list in `test_event_viewer.m`.

- [ ] **Step 3: Run test to verify it fails**

Run in MATLAB:
```
cd('/Users/hannessuhr/FastPlot'); setup(); cd('tests'); test_event_viewer
```
Expected: FAIL — `BarPositions` property does not exist

- [ ] **Step 4: Add BarPositions property to EventViewer**

In `libs/EventDetection/EventViewer.m`, add to the properties block (after `BarEvents`, around line 23):

```matlab
BarPositions    % Nx4 matrix: [x, y, w, h] cached from drawTimeline
```

- [ ] **Step 5: Populate BarPositions in drawTimeline**

In `drawTimeline()`, after the line `obj.BarRects = hRects;` (around line 290), add:

```matlab
obj.BarRects = hRects;
obj.BarEvents = events;

% Cache bar positions in a plain matrix for fast hit-testing
obj.BarPositions = zeros(nEvents, 4);
for i = 1:nEvents
    obj.BarPositions(i, :) = get(hRects(i), 'Position');
end
```

Also initialize `BarPositions` to empty in the `cla` block at the top of `drawTimeline`:

```matlab
obj.BarRects = [];
obj.BarEvents = [];
obj.BarPositions = [];
```

- [ ] **Step 6: Update findBarUnderCursor to use cached matrix**

Replace the `findBarUnderCursor` method body. Instead of calling `get(obj.BarRects(i), 'Position')` in the loop, read from `obj.BarPositions`:

```matlab
function idx = findBarUnderCursor(obj)
    %FINDBARUNDERCURSOR Find the closest bar to the current mouse position.
    idx = 0;
    if isempty(obj.BarPositions); return; end

    cp = get(obj.hTimelineAxes, 'CurrentPoint');
    mx = cp(1,1);
    my = cp(1,2);

    xl = get(obj.hTimelineAxes, 'XLim');
    yl = get(obj.hTimelineAxes, 'YLim');
    if mx < xl(1) || mx > xl(2) || my < yl(1) || my > yl(2)
        return;
    end

    % Minimum hit width: 5 pixels in data coords
    axPos = get(obj.hTimelineAxes, 'Position');
    figPos = get(obj.hFigure, 'Position');
    axWidthPx = axPos(3) * figPos(3);
    xRange = xl(2) - xl(1);
    minHitW = xRange * 5 / max(axWidthPx, 1);

    bestDist = inf;
    for i = 1:size(obj.BarPositions, 1)
        rx = obj.BarPositions(i,1);
        ry = obj.BarPositions(i,2);
        rw = obj.BarPositions(i,3);
        rh = obj.BarPositions(i,4);
        if my < ry || my > ry + rh; continue; end
        hitW = max(rw, minHitW);
        cx = rx + rw / 2;
        if mx >= cx - hitW/2 && mx <= cx + hitW/2
            dist = abs(mx - cx);
            if dist < bestDist
                bestDist = dist;
                idx = i;
            end
        end
    end
end
```

- [ ] **Step 7: Run all event viewer tests**

Run in MATLAB:
```
cd('/Users/hannessuhr/FastPlot'); setup(); cd('tests'); test_event_viewer
```
Expected: ALL PASSED (7 tests including the new one)

- [ ] **Step 8: Run full test suite**

Run in MATLAB:
```
cd('/Users/hannessuhr/FastPlot'); setup(); cd('tests'); run_all_tests
```
Expected: All passed, 0 failed

- [ ] **Step 9: Commit**

```bash
git add tests/test_event_viewer.m libs/EventDetection/EventViewer.m
git commit -m "perf: cache bar positions in EventViewer for O(1) hit-testing

Store bar rectangle positions in an Nx4 matrix during drawTimeline.
findBarUnderCursor reads from the matrix instead of calling get()
on each graphics handle, eliminating N graphics queries per mouse-move."
```

---

## Task 3: Unify backup logic — EventConfig delegates to EventStore

**Files:**
- Modify: `libs/EventDetection/EventStore.m:4-9,38-58`
- Modify: `libs/EventDetection/EventConfig.m:107-153`
- Modify: `tests/test_event_config.m`

- [ ] **Step 1: Write failing test — EventConfig saves via EventStore format**

Add this test to `tests/test_event_config.m` (before the final `fprintf`):

```matlab
% testSaveViaEventStore
tmpFile = fullfile(tempdir, 'test_cfg_store_save.mat');
if exist(tmpFile, 'file'); delete(tmpFile); end
cfg = EventConfig();
cfg.EventFile = tmpFile;
cfg.MaxBackups = 0;
s = Sensor('temp', 'Name', 'Temperature');
s.X = 1:10;
s.Y = [5 5 12 14 11 13 5 5 5 5];
s.addThresholdRule(struct(), 10, 'Direction', 'upper', 'Label', 'warn');
cfg.setColor('warn', [1 0 0]);
cfg.addSensor(s);
events = cfg.runDetection();
% File should exist and contain events, sensorData, thresholdColors, timestamp
assert(exist(tmpFile, 'file') == 2, 'save: file exists');
data = load(tmpFile);
assert(isfield(data, 'events'), 'save: has events');
assert(isfield(data, 'sensorData'), 'save: has sensorData');
assert(isfield(data, 'thresholdColors'), 'save: has thresholdColors');
assert(isfield(data, 'timestamp'), 'save: has timestamp');
assert(numel(data.events) == numel(events), 'save: event count matches');
delete(tmpFile);
```

- [ ] **Step 2: Run test to verify it passes with current code (baseline)**

Run in MATLAB:
```
cd('/Users/hannessuhr/FastPlot'); setup(); cd('tests'); test_event_config
```
Expected: ALL PASSED (this should pass with the current EventConfig.saveEvents too — it's a regression test)

- [ ] **Step 3: Add ThresholdColors and Timestamp properties to EventStore**

In `libs/EventDetection/EventStore.m`, add two new properties (after `SensorData`, around line 8):

```matlab
properties
    FilePath        = ''
    MaxBackups      = 5
    PipelineConfig  = struct()
    SensorData      = []   % struct array: name, t, y (for EventViewer click-to-plot)
    ThresholdColors = struct()  % serialized threshold colors struct
    Timestamp       = []        % datetime: when events were saved
end
```

- [ ] **Step 4: Update EventStore.save() to include new fields**

In `libs/EventDetection/EventStore.m`, replace the `save()` method (lines 38-58):

```matlab
function save(obj)
    if isempty(obj.FilePath); return; end

    % Backup existing file
    if isfile(obj.FilePath) && obj.MaxBackups > 0
        obj.createBackup();
    end

    % Atomic write: save to temp, then rename
    tmpFile = [obj.FilePath '.tmp'];
    events = obj.events_; %#ok<PROPLC>
    lastUpdated = now; %#ok<NASGU>
    pipelineConfig = obj.PipelineConfig; %#ok<PROPLC,NASGU>
    sensorData = obj.SensorData; %#ok<PROPLC,NASGU>
    thresholdColors = obj.ThresholdColors; %#ok<PROPLC,NASGU>
    timestamp = obj.Timestamp; %#ok<PROPLC,NASGU>

    varList = {'events', 'lastUpdated', 'pipelineConfig'};
    if ~isempty(sensorData)
        varList{end+1} = 'sensorData';
    end
    if ~isempty(fieldnames(thresholdColors)) || ~isstruct(thresholdColors)
        varList{end+1} = 'thresholdColors';
    end
    if ~isempty(timestamp)
        varList{end+1} = 'timestamp';
    end
    builtin('save', tmpFile, varList{:}, '-v7.3');
    movefile(tmpFile, obj.FilePath);
end
```

- [ ] **Step 5: Replace EventConfig.saveEvents with EventStore delegation**

In `libs/EventDetection/EventConfig.m`, replace the `saveEvents` method (lines 107-138):

```matlab
function saveEvents(obj, events)
    %SAVEEVENTS Save events, sensor data, and colors to .mat file via EventStore.
    store = EventStore(obj.EventFile, 'MaxBackups', obj.MaxBackups);
    store.append(events);
    store.SensorData = obj.SensorData;
    store.Timestamp = datetime('now');

    % Convert containers.Map to struct for serialization
    if obj.ThresholdColors.Count > 0
        keys = obj.ThresholdColors.keys();
        vals = obj.ThresholdColors.values();
        colorStruct = struct();
        for i = 1:numel(keys)
            safeKey = matlab.lang.makeValidName(keys{i});
            colorStruct.(safeKey) = struct('label', keys{i}, 'rgb', vals{i});
        end
        store.ThresholdColors = colorStruct;
    end

    store.save();
end
```

- [ ] **Step 6: Delete EventConfig.pruneBackups method**

Remove the `pruneBackups` method (lines 140-153) from `EventConfig.m`. EventStore's `createBackup`/`pruneBackups` now handles this.

- [ ] **Step 7: Run all event config tests**

Run in MATLAB:
```
cd('/Users/hannessuhr/FastPlot'); setup(); cd('tests'); test_event_config
```
Expected: ALL PASSED (9 tests including the new one)

- [ ] **Step 8: Run full test suite**

Run in MATLAB:
```
cd('/Users/hannessuhr/FastPlot'); setup(); cd('tests'); run_all_tests
```
Expected: All passed, 0 failed

- [ ] **Step 9: Commit**

```bash
git add libs/EventDetection/EventStore.m libs/EventDetection/EventConfig.m tests/test_event_config.m
git commit -m "refactor: EventConfig delegates backup/save to EventStore

Remove duplicate createBackup/pruneBackups from EventConfig.
EventStore gains ThresholdColors and Timestamp properties.
Single backup implementation to maintain."
```

---

## Task 4: Final verification and push

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

Run in MATLAB:
```
cd('/Users/hannessuhr/FastPlot'); setup(); cd('tests'); run_all_tests
```
Expected: All passed, 0 failed

- [ ] **Step 2: Push**

```bash
git push
```
