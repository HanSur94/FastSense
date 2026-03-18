<!-- AUTO-GENERATED from source code by scripts/generate_api_docs.py — do not edit manually -->

# API Reference: Event Detection

## `EventDetector` --- Detects events from threshold violations.

> Inherits from: `handle`

det = EventDetector()
  det = EventDetector('MinDuration', 2, 'OnEventStart', @myCallback)
  events = det.detect(t, values, thresholdValue, direction, thresholdLabel, sensorName)

### Constructor

```matlab
obj = EventDetector(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| MinDuration |  | numeric: minimum event duration (default 0) |
| OnEventStart |  | function handle: callback f(event) on new event |
| MaxCallsPerEvent |  | numeric: max callback invocations per event (default 1) |

### Methods

#### `events = detect(obj, t, values, thresholdValue, direction, thresholdLabel, sensorName)`

DETECT Find events from threshold violations.
  events = det.detect(t, values, thresholdValue, direction, thresholdLabel, sensorName)
  Returns Event array.

---

## `IncrementalEventDetector` --- Wraps EventDetector with incremental state.

> Inherits from: `handle`

Tracks last-processed index per sensor and carries over open events.

### Constructor

```matlab
obj = IncrementalEventDetector(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| MinDuration | `0` |  |
| MaxCallsPerEvent | `1` |  |
| OnEventStart | `[]` |  |
| EscalateSeverity | `true` |  |

### Methods

#### `newEvents = process(obj, sensorKey, sensor, newX, newY, newStateX, newStateY)`

#### `tf = hasOpenEvent(obj, sensorKey)`

#### `st = getSensorState(obj, sensorKey)`

---

## `Event` --- Represents a single detected threshold violation event.

> Inherits from: `handle`

e = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)
  e.setStats(peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal)

### Constructor

```matlab
obj = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| DIRECTIONS | `{'upper', 'lower'}` |  |

### Methods

#### `obj = setStats(obj, peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal)`

SETSTATS Set event statistics.

#### `obj = escalateTo(obj, newLabel, newThresholdValue)`

ESCALATETOP Escalate event to a higher severity threshold.

---

## `EventConfig` --- Configuration for the event detection system.

> Inherits from: `handle`

cfg = EventConfig()
  cfg.MinDuration = 2;
  cfg.addSensor(sensor);
  events = cfg.runDetection();

### Constructor

```matlab
obj = EventConfig()
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Sensors |  | cell array of Sensor objects |
| SensorData |  | struct array: name, t, y (for viewer click-to-plot) |
| MinDuration |  | numeric: debounce (default 0) |
| MaxCallsPerEvent |  | numeric: callback limit (default 1) |
| OnEventStart |  | function handle: callback |
| ThresholdColors |  | containers.Map: label -> [R G B] |
| AutoOpenViewer |  | logical: auto-open EventViewer after detection |
| EscalateSeverity |  | logical: escalate events to higher thresholds (default true) |
| EventFile |  | char: path to .mat file for auto-saving events (empty = disabled) |
| MaxBackups |  | numeric: number of backup files to keep (default 5, 0 = no backups) |

### Methods

#### `addSensor(obj, sensor)`

ADDSENSOR Register a sensor with its data.

#### `setColor(obj, label, rgb)`

SETCOLOR Set color for a threshold label.

#### `det = buildDetector(obj)`

BUILDDETECTOR Create a configured EventDetector.

#### `events = runDetection(obj)`

RUNDETECTION Detect events across all configured sensors.

---

## `EventStore` --- Atomic read/write of events to a shared .mat file.

> Inherits from: `handle`

### Constructor

```matlab
obj = EventStore(filePath, varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| FilePath | `''` |  |
| MaxBackups | `5` |  |
| PipelineConfig | `struct()` |  |
| SensorData | `[]` | struct array: name, t, y (for EventViewer click-to-plot) |
| ThresholdColors | `struct()` | serialized threshold colors struct |
| Timestamp | `[]` | datetime: when events were saved |

### Methods

#### `append(obj, newEvents)`

#### `events = getEvents(obj)`

#### `save(obj)`

#### `n = numEvents(obj)`

### Static Methods

#### `EventStore.[events, meta, changed] = loadFile(filePath)`

---

## `EventViewer` --- Figure-based event viewer with Gantt timeline and filterable table.

> Inherits from: `handle`

viewer = EventViewer(events)
  viewer = EventViewer(events, sensorData)
  viewer = EventViewer(events, sensorData, thresholdColors)
  viewer.update(newEvents)

### Constructor

```matlab
obj = EventViewer(events, sensorData, thresholdColors)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Events |  | Event array |
| SensorData |  | struct array: name, t, y (for click-to-plot) |
| ThresholdColors |  | containers.Map: label -> [R G B] |
| hFigure |  | figure handle |
| BarPositions |  | Nx4 matrix: [x, y, w, h] cached from drawTimeline |
| BarRects |  | rectangle handles for hover detection |
| BarEvents |  | Event objects corresponding to BarRects |

### Methods

#### `update(obj, events)`

UPDATE Refresh the viewer with new events.

#### `names = getSensorNames(obj)`

GETSENSORNAMES Get unique sensor names from events.

#### `labels = getThresholdLabels(obj)`

GETTHRESHOLDLABELS Get unique threshold labels from events.

#### `refreshFromFile(obj)`

REFRESHFROMFILE Reload events from the source .mat file.

#### `startAutoRefresh(obj, interval)`

STARTAUTOREFRESH Start polling the source file at given interval.
  obj.startAutoRefresh(5)  % refresh every 5 seconds

#### `stopAutoRefresh(obj)`

STOPAUTOREFRESH Stop the auto-refresh timer.

### Static Methods

#### `EventViewer.viewer = fromFile(filepath)`

FROMFILE Open EventViewer from a saved .mat event store file.
  viewer = EventViewer.fromFile('events.mat')

---

## `LiveEventPipeline` --- Orchestrates live event detection.

> Inherits from: `handle`

### Constructor

```matlab
obj = LiveEventPipeline(sensors, dataSourceMap, varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Sensors |  | containers.Map: key -> Sensor |
| DataSourceMap |  | DataSourceMap |
| EventStore |  | EventStore |
| NotificationService |  | NotificationService |
| Interval | `15` | seconds |
| Status | `'stopped'` |  |
| MinDuration | `0` |  |
| EscalateSeverity | `true` |  |
| MaxCallsPerEvent | `1` |  |
| OnEventStart | `[]` |  |

### Methods

#### `start(obj)`

#### `stop(obj)`

#### `runCycle(obj)`

---

## `NotificationService` --- Rule-based email notifications with event snapshots.

> Inherits from: `handle`

### Constructor

```matlab
obj = NotificationService(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Rules | `NotificationRule.empty()` |  |
| DefaultRule | `[]` |  |
| Enabled | `true` |  |
| DryRun | `false` |  |
| SnapshotDir | `''` |  |
| SnapshotRetention | `7` | days |
| SmtpServer | `''` |  |
| SmtpPort | `25` |  |
| SmtpUser | `''` |  |
| SmtpPassword | `''` |  |
| FromAddress | `'fastsense@noreply.com'` |  |
| NotificationCount | `0` |  |

### Methods

#### `addRule(obj, rule)`

#### `setDefaultRule(obj, rule)`

#### `rule = findBestRule(obj, event)`

#### `notify(obj, event, sensorData)`

#### `cleanupSnapshots(obj)`

---

## `NotificationRule` --- Configures notification for sensor/threshold events.

> Inherits from: `handle`

### Constructor

```matlab
obj = NotificationRule(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| SensorKey | `''` |  |
| ThresholdLabel | `''` |  |
| Recipients | `{{}}` |  |
| Subject | `'Event: {sensor} - {threshold}'` |  |
| Message | `'{sensor} exceeded {threshold} ({direction}) at {startTime}. Peak: {peak}'` |  |
| IncludeSnapshot | `true` |  |
| ContextHours | `2` |  |
| SnapshotPadding | `0.1` |  |
| SnapshotSize | `[800, 400]` |  |

### Methods

#### `score = matches(obj, event)`

Returns match score: 3=sensor+threshold, 2=sensor, 1=default, 0=no match

#### `txt = fillTemplate(~, template, event)`

---

## `DataSource` --- Abstract interface for fetching new sensor data.

> Inherits from: `handle`

Subclasses must implement fetchNew() which returns a struct:
    .X       — 1xN datenum timestamps
    .Y       — 1xN (or MxN) values
    .stateX  — 1xK datenum state timestamps (empty if none)
    .stateY  — 1xK state values (empty if none)
    .changed — logical, true if new data since last call

### Methods

#### `result = fetchNew(obj)`

### Static Methods

#### `DataSource.result = emptyResult()`

---

## `MatFileDataSource` --- Reads sensor data from a continuously-updated .mat file.

> Inherits from: `DataSource`

### Constructor

```matlab
obj = MatFileDataSource(filePath, varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| FilePath | `''` |  |
| XVar | `'X'` |  |
| YVar | `'Y'` |  |
| StateXVar | `''` |  |
| StateYVar | `''` |  |

### Methods

#### `result = fetchNew(obj)`

---

## `DataSourceMap` --- Maps sensor keys to DataSource instances.

> Inherits from: `handle`

### Constructor

```matlab
obj = DataSourceMap()
```

### Methods

#### `add(obj, key, dataSource)`

#### `ds = get(obj, key)`

#### `k = keys(obj)`

#### `tf = has(obj, key)`

#### `remove(obj, key)`

---

## `MockDataSource` --- Generates realistic industrial sensor signals for testing.

> Inherits from: `DataSource`

### Constructor

```matlab
obj = MockDataSource(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| BaseValue | `100` |  |
| NoiseStd | `1` |  |
| DriftRate | `0` | drift per second |
| SampleInterval | `3` | seconds between points |
| BacklogDays | `3` | days of history on first fetch |
| ViolationProbability | `0.005` | chance per point of starting violation |
| ViolationAmplitude | `20` | how far signal ramps beyond base |
| ViolationDuration | `60` | seconds per violation episode |
| StateValues | `{{}}` | cell of char, e.g. {'idle','running'} |
| StateChangeProbability | `0.001` | chance per point of state transition |
| Seed | `[]` | optional RNG seed |
| PipelineInterval | `15` | seconds per fetch cycle |

### Methods

#### `result = fetchNew(obj)`

