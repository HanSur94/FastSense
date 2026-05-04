<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Event Detection Guide

The Event Detection system in FastSense provides storage, visualization, and notification services for threshold violations detected by the [[Sensors]] library. It orchestrates live detection pipelines, manages atomic event persistence, and offers interactive Gantt‑style viewing. Use it when you need to track, review, and alert on sensor threshold breaches in real time or after the fact.

## When to Use Event Detection

- **Real‑time monitoring** – detect and store events as they occur in streaming data.
- **Historical analysis** – load saved events for offline review and statistical summaries.
- **Alert systems** – send rule‑based email notifications with PNG snapshots.
- **Event visualization** – explore events on a Gantt timeline with filterable tables.
- **Data archival** – persist events with automatic backup rotation and atomic writes.

## Core Workflow

The typical workflow spans the [[Sensors]] library and the EventDetection classes:

1. **Create sensors** with threshold rules (see [[Sensors]]).
2. **Wrap sensors in `MonitorTag` objects** – these carry the detection logic.
3. **Configure data sources** using `MockDataSource` or `MatFileDataSource`.
4. **Assemble the `LiveEventPipeline`** – it polls data sources, runs detection, appends events to an `EventStore`, and triggers notifications.
5. **Start the pipeline** – events are automatically stored and, optionally, opened in the `EventViewer`.
6. **Review events** with `EventViewer`, `printEventSummary`, or `generateEventSnapshot`.

## Event Objects

Each detected violation becomes an [[Event Detection|Event]] object. Events are created by the pipeline’s internal detection (via `MonitorTag`), but you can also instantiate them manually for testing.

```matlab
% Manual creation
ev = Event(datenum(2025,1,10,12,0,0), ...
           datenum(2025,1,10,12,5,0), ...
           'Temperature', 'High Warning', 85, 'upper');

% Statistical enrichment (normally done by the detector)
ev.setStats(peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal);

% Close an open event (useful for live monitoring)
ev.close(endTime, finalStats);

% Escalate the event to a higher threshold label
ev.escalateTo('HH Alarm', 95);
```

Key properties (all read‑only after creation unless noted):

- `StartTime`, `EndTime` – datenum timestamps.
- `Duration` – difference in days (set automatically on creation or closing).
- `SensorName`, `ThresholdLabel`, `ThresholdValue`, `Direction`.
- `PeakValue`, `NumPoints`, `MinValue`, `MaxValue`, `MeanValue`, `RmsValue`, `StdValue` – set via `setStats`.
- `Id` – unique identifier assigned by `EventStore.append`.
- `IsOpen` – true while the event is ongoing; toggled by `close`.
- `Severity`, `Category`, `Notes`, `TagKeys` – metadata fields for tagging and annotation (see [[Event Detection|EventBinding]]).

## Event Storage with `EventStore`

The [[Event Detection|EventStore]] class handles persistence with atomic file operations and automatic backup rotation.

```matlab
% Create an event store backed by a .mat file
store = EventStore('events.mat', 'MaxBackups', 5);

% Append new events (does not immediately write to disk)
store.append(newEvents);

% Optionally embed sensor data for later visualization
store.SensorData = mySensorData;           % struct array
store.ThresholdColors = myColorMap;        % containers.Map

% Save to disk atomically
store.save();

% Load events and metadata
[events, meta, changed] = EventStore.loadFile('events.mat');
```

`EventStore` also supports closing open events:

```matlab
store.closeEvent(eventId, endTime, finalStats);
% Remember to call store.save() afterwards
```

## Live Event Detection Pipeline

The [[Event Detection|LiveEventPipeline]] provides turn‑key continuous monitoring. It periodically fetches new data from `DataSource` objects, feeds it into `MonitorTag` instances for detection, stores resulting events in an `EventStore`, and invokes a `NotificationService`.

### Setting Up Data Sources

Data sources are subclasses of the abstract `DataSource`. Two concrete implementations are provided:

```matlab
% Mock data source for testing – injects synthetic violations
mockDS = MockDataSource('BaseValue', 100, ...
    'NoiseStd', 1, ...
    'ViolationProbability', 0.005, ...
    'ViolationAmplitude', 25);

% File‑based data source for live files
fileDS = MatFileDataSource('sensor_data.mat', ...
    'XVar', 'timestamp', 'YVar', 'value');
```

### Mapping Sources to Monitors

A `DataSourceMap` associates sensor keys with data sources:

```matlab
dsMap = DataSourceMap();
dsMap.add('temp_01', mockDS);
dsMap.add('press_01', fileDS);
```

### Creating Monitor Tags

`MonitorTag` objects (from the [[Sensors]] library) perform threshold detection. Build one for each monitored sensor:

```matlab
% Assuming 'sensor' is a Sensor object with thresholds defined
monitorTemp = MonitorTag('temp_01', tempSensor, '>', 85, ...
    'Label', 'High Temp');
monitorPress = MonitorTag('press_01', pressSensor, '<', 50, ...
    'Label', 'Low Pressure');
```

Collect them in a `containers.Map`:

```matlab
targets = containers.Map();
targets('temp_01') = monitorTemp;
targets('press_01') = monitorPress;
```

### Assembling and Running the Pipeline

Combine everything into a `LiveEventPipeline`:

```matlab
pipeline = LiveEventPipeline(targets, dsMap, ...
    'EventStore', store, ...                 % EventStore object (optional)
    'Interval', 15, ...                      % seconds between cycles
    'MinDuration', 5/86400, ...              % minimum event duration in days
    'EscalateSeverity', true, ...            % enable H→HH escalation
    'OnEventStart', eventLogger());          % optional callback

% Configure notifications (see below)
pipeline.NotificationService = notifService;

% Start and stop monitoring
pipeline.start();   % begins timer‑driven polling
pipeline.stop();    % halts the timer
```

The pipeline automatically appends events to its `EventStore` (if provided) and calls the notification service on each event. It respects `MinDuration` to filter transient violations.

## Notification System

### Notification Rules

[[Event Detection|NotificationRule]] objects specify who gets notified and what the email contains. Rules support priority matching: exact sensor+threshold match > sensor‑only match > default rule.

```matlab
% Default rule – catches every event
defaultRule = NotificationRule('Recipients', {{'ops@company.com'}}, ...
    'Subject', 'Event: {sensor} - {threshold}', ...
    'IncludeSnapshot', false);

% Sensor‑specific rule
tempRule = NotificationRule('SensorKey', 'temp_01', ...
    'Recipients', {{'thermal@company.com'}}, ...
    'Subject', 'Temperature Event: {threshold}', ...
    'IncludeSnapshot', true, ...
    'ContextHours', 2);

% Exact match rule (highest priority)
critRule = NotificationRule('SensorKey', 'temp_01', ...
    'ThresholdLabel', 'Critical', ...
    'Recipients', {{'safety@company.com', 'manager@company.com'}}, ...
    'Subject', 'CRITICAL: {sensor} {threshold}!');
```

Template variables available: `{sensor}`, `{threshold}`, `{direction}`, `{startTime}`, `{endTime}`, `{duration}`, `{peak}`, `{mean}`, `{std}`, `{min}`, `{max}`, `{rms}`.

### Notification Service

The [[Event Detection|NotificationService]] manages rule matching and email dispatch:

```matlab
notif = NotificationService('DryRun', true, ...   % test mode – no emails sent
    'SmtpServer', 'mail.company.com', ...
    'SnapshotDir', 'snapshots/');

notif.setDefaultRule(defaultRule);
notif.addRule(tempRule);
notif.addRule(critRule);
```

A pipeline call to `notif.notify(event, sensorData)` triggers snapshot generation (if the best rule requests it) and sends the email. Snapshots older than `SnapshotRetention` days are automatically cleaned up.

## Event Visualization with `EventViewer`

[[Event Detection|EventViewer]] displays events on an interactive Gantt chart alongside a filterable table.

```matlab
% Open viewer directly from a saved .mat file
viewer = EventViewer.fromFile('events.mat');

% Or construct with events, sensor data, and threshold colors
viewer = EventViewer(events, sensorData, thresholdColors);

% Update viewer with new events
viewer.update(newEvents);
```

Key viewer features:

- Click on a Gantt bar to highlight the corresponding table row.
- Filter by sensor, threshold, or date range using the table controls.
- **Auto‑refresh** – set an interval to reload from the source file:
  ```matlab
  viewer.startAutoRefresh(10);   % refresh every 10 seconds
  viewer.stopAutoRefresh();
  ```
- **Multi‑sensor context** – clicking a bar can plot the underlying sensor data if `SensorData` was provided.

## Utility Functions

### `eventLogger`

A simple callback factory that prints a one‑line log when an event occurs.

```matlab
cfg.OnEventStart = eventLogger();   % or set on pipeline
% Prints: [EVENT] Temperature | High Temp | UPPER | 739123.45 -> 739123.47 (dur=0.0014) | peak=126.83
```

### `printEventSummary`

Format a summary table of events to the console.

```matlab
printEventSummary(events);
% Columns: Start, End, Duration, Sensor, Threshold, Dir, Peak, #Pts, Mean, Std
```

### `generateEventSnapshot`

Create two PNG snapshots for an event: a detail plot and a wider context plot.

```matlab
files = generateEventSnapshot(event, sensorData, ...
    'OutputDir', 'snapshots/', ...
    'SnapshotSize', [800, 400], ...
    'Padding', 0.1, ...          % 10% margin around the event
    'ContextHours', 2);          % hours before event start
% Returns {'detail.png', 'context.png'}
```

## Event‑Tag Binding (`EventBinding`)

[[Event Detection|EventBinding]] is a static registry that links `Event` objects to `Tag` objects (from the broader FastSense system). It enables many‑to‑many relationships for taxonomy and filtering. You rarely call it directly; instead, use convenience methods on `Event` or `EventStore`.

```matlab
% Attach a tag to an event
EventBinding.attach(event.Id, 'FleetA');

% Query events for a tag
taggedEvents = EventBinding.getEventsForTag('FleetA', eventStore);
```

## Performance Considerations

- **Polling interval**: Set the pipeline’s `Interval` to a value that balances responsiveness and load.
- **Minimum duration**: Use `MinDuration` (in days) to ignore short‑lived spikes.
- **Snapshot generation**: PNG creation can be expensive; restrict snapshots to high‑priority rules only.
- **File backups**: Adjust `MaxBackups` in `EventStore` to manage disk usage.
- **Incremental data**: `MatFileDataSource` reads only new points since the last fetch, making it efficient for large files.

## Common Patterns

### Multi‑Sensor Live Pipeline with Notifications

```matlab
% 1. Create sensors and monitor tags
tempMon = MonitorTag('temp', tempSensor, '>', 90, 'Label', 'Overheat');
pressMon = MonitorTag('press', pressSensor, '<', 10, 'Label', 'Vacuum Loss');
targets = containers.Map({'temp','press'}, {tempMon, pressMon});

% 2. Data source mapping
dsMap = DataSourceMap();
dsMap.add('temp', MatFileDataSource('temp_data.mat'));
dsMap.add('press', MatFileDataSource('press_data.mat'));

% 3. Notification rules
notif = NotificationService('DryRun', false, 'SmtpServer', 'smtp.local');
notif.addRule(NotificationRule('SensorKey', 'temp', ...
    'Recipients', {{'alerts@company.com'}}, 'Subject', 'Overheat detected'));

% 4. Pipeline
pipeline = LiveEventPipeline(targets, dsMap, ...
    'EventStore', EventStore('monitoring.mat'), ...
    'NotificationService', notif, ...
    'OnEventStart', eventLogger());

pipeline.start();
```

### Event Analysis from Saved Data

```matlab
% Load stored events
viewer = EventViewer.fromFile('historical_events.mat');

% Programmatic access
[events, meta] = EventStore.loadFile('historical_events.mat');
highTempEvents = events(strcmp({events.SensorName}, 'Temperature') & ...
                        strcmp({events.ThresholdLabel}, 'High'));
printEventSummary(highTempEvents);
```

## See Also

- [[Sensors]] – Configure thresholds and MonitorTag objects.
- [[Live Mode Guide]] – Real‑time data streaming patterns.
- [[Dashboard Engine Guide]] – Multi‑plot coordination.
- [[Examples]] – Complete working examples.
