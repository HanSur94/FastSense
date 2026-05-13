<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Event Detection Guide

The Event Detection system provides threshold‑based monitoring, persisted event storage, and interactive visualisation. It builds on the [[Sensors]] library for real‑time violation detection and adds stateful pipeline management, notifications, and file‑backed event archives. Use this system when you need to capture, store, and react to threshold crossings from live data streams or recorded sessions.

**What’s covered here**
* Creating, storing, and visualising `Event` objects.
* Running a live detection pipeline with `LiveEventPipeline`.
* Connecting to data sources (`DataSource`, `MockDataSource`, `MatFileDataSource`).
* Sending notifications with `NotificationRule` and `NotificationService`.
* Utility logging, snapshots, and summary generation.

**Key classes used in this guide**

| Class / Function | Purpose |
|------------------|---------|
| `Event`          | Represents a single threshold violation |
| `EventStore`     | Atomic file‑based storage of events |
| `EventViewer`    | Interactive Gantt chart and filterable table |
| `LiveEventPipeline` | Orchestrates live detection, storage, and notifications |
| `DataSourceMap`  | Associates sensor keys with data feed objects |
| `DataSource` (abstract) | Interface for fetching fresh sensor data |
| `MockDataSource` | Simulates industrial‑sensor signals |
| `MatFileDataSource` | Reads data from a `.mat` file that is continuously updated |
| `NotificationRule` & `NotificationService` | Rule‑based email alerts with optional snapshot attachments |
| `eventLogger` | Simple console logging callback |
| `printEventSummary` | Tabular console summary of events |
| `generateEventSnapshot` | Creates PNG images showing the event in context |

## Core workflow

1. **Create `MonitorTag` objects** (part of [[Sensors]]) with threshold rules.
2. **Choose a data source** (`MockDataSource`, `MatFileDataSource`, or a custom `DataSource`).
3. **Map sensors to data sources** using `DataSourceMap`.
4. **Create a `LiveEventPipeline`** that connects monitors, data sources, storage, and notifications.
5. **Start the pipeline** – it will periodically fetch data, detect violations, and record events.

Afterwards, events can be stored in an `EventStore`, viewed with `EventViewer`, and optionally trigger email notifications.

## Events

An `Event` object records the start, end, sensor, threshold, and statistics of a violation:

```matlab
% Create an event (manual construction – usually handled by the pipeline)
ev = Event(datenum('2025-01-15 10:00:00'), ...
           datenum('2025-01-15 10:02:30'), ...
           'Temperature', 'High Alarm', 85, 'upper');
ev.setStats(peakValue=91.2, numPoints=30, minVal=80.1, maxVal=91.2, ...
            meanVal=84.5, rmsVal=85.1, stdVal=1.87);
```

Key properties:
* `StartTime`, `EndTime` – datenum boundaries.
* `SensorName`, `ThresholdLabel`, `ThresholdValue`, `Direction` – identify the trigger.
* `PeakValue`, `NumPoints`, `MinValue`, `MaxValue`, `MeanValue`, `RmsValue`, `StdValue` – statistics populated by the detector.
* `IsOpen` – `true` while a violation is still ongoing (EndTime = NaN).
* `Severity`, `Category`, `TagKeys`, `Notes` – used for event management and manual annotations.

## EventStore — persistent file storage

`EventStore` provides atomic read/write to a `.mat` file with automatic backup rotation.

```matlab
store = EventStore('events.mat', 'MaxBackups', 3);

% Append new events (idempotent, assigns unique Ids to Events)
store.append(newEvents);

% Save to disk (also writes PipelineConfig, SensorData, ThresholdColors)
store.save();

% Retrieve events
allEvents = store.getEvents();

% Static method to load from disk without constructing an object
[events, meta, changed] = EventStore.loadFile('events.mat');
```

During live monitoring, the pipeline automatically calls `store.append` and `store.save` after each cycle. The stored file is self‑contained and can be opened directly by `EventViewer.fromFile`.

### Closing open events

An event with `IsOpen == true` can be closed in place:

```matlab
store.closeEvent('evt-001', endTime, struct('PeakValue', 92.3, 'NumPoints', 45));
% does NOT save automatically – the caller must call save() afterwards
```

## Live detection with LiveEventPipeline

`LiveEventPipeline` ties together monitors, a data source map, and an event store. It runs a polling cycle at a fixed interval.

### Step 1 – define monitors

(Assumes `MonitorTag` objects are already created – see [[Sensors]].)

```matlab
% Example: two MonitorTags
monitors = containers.Map();
monitors('temp') = tempMonitor;
monitors('press') = pressMonitor;
```

### Step 2 – set up data sources

Use one of the provided data sources or inherit from `DataSource`.

```matlab
% For testing: MockDataSource with random violations
mockSrc = MockDataSource('BaseValue', 100, 'NoiseStd', 1.5, ...
    'ViolationProbability', 0.005, 'ViolationAmplitude', 20);

% For live file monitoring
fileSrc = MatFileDataSource('sensor_data.mat', ...
    'XVar', 'timestamps', 'YVar', 'temperature');

% Map sensor keys to data sources
dsMap = DataSourceMap();
dsMap.add('temp', mockSrc);
dsMap.add('press', fileSrc);
```

**`MockDataSource` parameters** (all optional):
* `BaseValue`, `NoiseStd`, `DriftRate` – signal characteristics.
* `SampleInterval` – seconds between synthetic points.
* `BacklogDays` – initial history in days.
* `ViolationProbability` – probability of starting a violation each step.
* `ViolationAmplitude`, `ViolationDuration` – how far above base value and how long.
* `StateValues`, `StateChangeProbability` – optional discrete state channel.

**`MatFileDataSource` parameters**:
* `XVar`, `YVar` – variable names in the `.mat` file.
* `StateXVar`, `StateYVar` – optional state variables.

### Step 3 – create and start the pipeline

```matlab
pipeline = LiveEventPipeline(monitors, dsMap, ...
    'EventFile', 'live_events.mat', ...     % enable auto-save
    'Interval', 10, ...                     % poll every 10 seconds
    'MinDuration', 3, ...                   % seconds of sustained violation
    'EscalateSeverity', true, ...
    'MaxCallsPerEvent', 1, ...
    'OnEventStart', eventLogger());        % console logging callback

% Optionally attach notification service
notif = NotificationService('DryRun', true, ...
    'SnapshotDir', 'snapshots/');
pipeline.NotificationService = notif;

% Launch the timer-driven cycle
pipeline.start();
```

The pipeline’s main loop:
1. Fetches new data from each `DataSource`.
2. Calls `MonitorTag.appendData` (cold path recomputes violations).
3. Detects new events (based on `MinDuration` etc.).
4. Appends them to the `EventStore` and saves.
5. Invokes the notification service if configured.

Stop the pipeline with `pipeline.stop()`.

## EventViewer — interactive Gantt and table

Open the viewer with existing events:

```matlab
viewer = EventViewer(events);                 % just events
viewer = EventViewer(events, sensorData);     % enable click-to‑plot
viewer = EventViewer(events, sensorData, thresholdColors); % custom colours
```

Or load directly from a saved event store file:

```matlab
viewer = EventViewer.fromFile('live_events.mat');
```

**Features**:
* **Gantt timeline** – each event rendered as a coloured bar with label.
* **Filterable table** – by sensor, threshold, date range.
* **Click interaction** – clicking a bar highlights the row.
* **Auto‑refresh** – polls the source file periodically.

```matlab
viewer.startAutoRefresh(10);   % refresh every 10 seconds
viewer.stopAutoRefresh();
viewer.refreshFromFile();      % manual refresh
```

To update the viewer with new events in‑memory:

```matlab
viewer.update(newlyDetectedEvents);
```

## Data sources

All data sources must inherit from the abstract class `DataSource`. They must implement `fetchNew()`, which returns a struct with fields:
* `X` – vector of datenum timestamps of new data.
* `Y` – matching value(s).
* `stateX`, `stateY` – optional discrete state.
* `changed` – logical, true if new data was available.

A static helper `DataSource.emptyResult()` returns a correctly‑structured empty result.

## Notification system

### NotificationRule

Each rule defines a recipient list and optional filtering by sensor name or threshold label. The `matches(event)` method returns a score:
* 3 – exact match on sensor *and* threshold label.
* 2 – match on sensor only.
* 1 – default rule (no sensor/ threshold restriction).
* 0 – no match.

```matlab
% Generic catch‑all
default = NotificationRule('Recipients', {{'alerts@company.com'}}, ...
    'Subject', 'Alert: {sensor}', ...
    'IncludeSnapshot', false);

% Sensor‑specific rule
tempRule = NotificationRule('SensorKey', 'Temperature', ...
    'Recipients', {{'thermal@company.com'}}, ...
    'Subject', 'Temperature event: {threshold}', ...
    'IncludeSnapshot', true, ...
    'ContextHours', 1);

% Highest priority: exact match on sensor and threshold
criticalRule = NotificationRule('SensorKey', 'Pressure', ...
    'ThresholdLabel', 'Critical', ...
    'Recipients', {{'safety@company.com', 'manager@company.com'}}, ...
    'Subject', 'CRITICAL: {sensor} {threshold}!');
```

Message bodies and subjects support template variables:
`{sensor}`, `{threshold}`, `{direction}`, `{peak}`, `{startTime}`, `{endTime}`, `{duration}`, `{mean}`, `{std}`, `{min}`, `{max}`, `{rms}`.

### NotificationService

Configure the service and attach rules:

```matlab
notif = NotificationService('DryRun', false, ...
    'SnapshotDir', 'snapshots/');

notif.setDefaultRule(default);
notif.addRule(tempRule);
notif.addRule(criticalRule);

% During pipeline operation, call notify for each event
notif.notify(event, sensorData);
```

Keys options:
* `DryRun` – if true, only logs but does not send.
* `SnapshotDir`, `SnapshotRetention` – where snapshot PNGs are saved and how long they stay.
* SMTP settings – `SmtpServer`, `SmtpPort`, `SmtpUser`, `SmtpPassword`, `FromAddress`.

When `IncludeSnapshot` is true, a PNG file is generated (see `generateEventSnapshot`) and attached. The service also cleans up old snapshots automatically.

## Utility functions

### eventLogger

A simple function handle that prints a one‑line log when an event starts.

```matlab
logger = eventLogger();   % returns @logEvent
% Usage in LiveEventPipeline: 'OnEventStart', eventLogger()
% Output example:
% [EVENT] Temperature | High Alarm | UPPER | 739123.45 -> 739123.47 (dur=0.02) | peak=126.83
```

### printEventSummary

Prints a formatted table of events to the console:

```matlab
printEventSummary(events);
% No events detected.   (if empty)
%
% Start        End          Duration   Sensor           Threshold           Dir    Peak     #Pts  Mean      Std
% ...
% N event(s) total.
```

### generateEventSnapshot

Creates two PNG figures: a detailed close‑up and a wider context view.

```matlab
files = generateEventSnapshot(event, sensorData, ...
    'OutputDir', 'snapshots/', ...
    'SnapshotSize', [800, 400], ...
    'Padding', 0.1, ...
    'ContextHours', 2);
% files = {'..._detail.png', '..._context.png'}
```

The sensor data struct must have fields `X`, `Y`, `thresholdValue`, `thresholdDirection`.

## Event Binding (EventBinding singleton)

Events can be linked to tags via the `EventBinding` registry. This is used internally by `EventStore` and the `Tag` system but can be used manually:

```matlab
EventBinding.attach(eventId, 'sensor_A');
tagKeys = EventBinding.getTagKeysForEvent(eventId);
events  = EventBinding.getEventsForTag('sensor_A', eventStore);
```

## Common Patterns

### Basic live monitoring pipeline

```matlab
% Assume monitors and data sources ready
pipeline = LiveEventPipeline(monitors, dsMap, ...
    'EventFile', 'example.mat', 'Interval', 15);
pipeline.start();
```

### Testing with mock data

Using `MockDataSource` with all defaults:

```matlab
mock = MockDataSource();
dsMap = DataSourceMap();
dsMap.add('sensor1', mock);
pipeline = LiveEventPipeline(monitors, dsMap, ...
    'EventFile', 'mock_test.mat', 'Interval', 5);
pipeline.start();
```

### Attaching notifications to a running pipeline

```matlab
notif = NotificationService('DryRun', true, 'SnapshotDir', 'test_snaps');
notif.setDefaultRule(NotificationRule('Recipients', {{'test@localhost'}}));
pipeline.NotificationService = notif;
```

### Post‑hoc analysis

```matlab
[events, meta] = EventStore.loadFile('live_events.mat');
printEventSummary(events(contains({events.SensorName}, 'Temp')));
viewer = EventViewer.fromFile('live_events.mat');
```

## Performance considerations

* `MinDuration` – filter brief noise spikes; set this to a few seconds for most signals.
* `MaxCallsPerEvent` – limits callback overhead when many events fire rapidly.
* **Backup files** – `EventStore` keeps up to `MaxBackups` rotated copies; adjust to balance disk usage.
* **Incremental detection** – `LiveEventPipeline` uses `MonitorTag.appendData` which is efficient for streaming data; it does not reprocess entire history.
* **Snapshot generation** – PNG creation is expensive; enable only for critical events and consider reducing image size.

## See Also

- [[Sensors]] – Creating thresholds and monitors
- [[Live Mode Guide]] – Real‑time data streaming patterns
- [[Dashboard Engine Guide]] – Multi‑plot coordination
- [[Examples]] – Complete working examples
