<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Event Detection Guide

The Event Detection system provides threshold‑based monitoring, live detection pipelines, persistent storage, interactive visualisation, and notification services. It integrates with the [[Sensors]] library for threshold configuration and with the MonitorTag infrastructure for streaming, incremental alerting.

## When to Use Event Detection

- **Real‑time monitoring** – detect threshold violations in live data streams
- **Historical analysis** – review events from recorded sensor data with statistical summaries
- **Alerting** – configure rule‑based notifications with email and graphical snapshots
- **Visualisation** – view events in a Gantt timeline and filterable table
- **Data archival** – store events with automatic backup rotation and atomic file operations

## Core Workflow (Modern Approach)

1. **Create MonitorTag** objects with thresholds (see [[Sensors]] for threshold setup).
2. **Connect data sources** (`DataSource`) that supply new timestamps and values.
3. **Configure a pipeline** (`LiveEventPipeline`) that polls data, feeds `MonitorTag.appendData`, and detects events via `EventDetector`.
4. **Persist events** with `EventStore` (atomic saves, backups).
5. **Visualise and alert** with `EventViewer` and `NotificationService`.

For batch processing of already‑resolved `Sensor` data, the legacy `EventConfig` class can still be used by directly populating its `Sensors` property.

## Basic Event Detection (Batch with Sensors)

`EventConfig` runs detection across an array of `Sensor` objects that already hold data and thresholds.  The deprecated `addSensor` method is a no‑op; assign the `Sensors` property directly.

```matlab
% Create a sensor with data and a threshold
sensor = Sensor('temperature');
sensor.X = 1:100;
sensor.Y = 70 + 10*sin((1:100)/10) + randn(1,100);
sensor.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'temp high');

% Configure batch detection
cfg = EventConfig();
cfg.Sensors = {sensor};        % <-- direct assignment (do NOT use cfg.addSensor)
cfg.MinDuration = 2;           % ignore violations shorter than 2 seconds
cfg.EscalateSeverity = true;   % promote to higher thresholds if peak exceeds

events = cfg.runDetection();

% Quick summary
printEventSummary(events);
```

### EventConfig Properties

| Property | Purpose |
|----------|---------|
| `Sensors` | Cell array of `Sensor` objects (set directly). |
| `MinDuration` | Minimum event duration in seconds. |
| `MaxCallsPerEvent` | Limit callback invocations per event. |
| `OnEventStart` | Function handle called on each new event. |
| `ThresholdColors` | `containers.Map` from threshold label to RGB triple. |
| `AutoOpenViewer` | Open `EventViewer` automatically after detection. |
| `EscalateSeverity` | Escalate events to higher thresholds if peak exceeds (default `true`). |
| `EventFile` | Path for automatic event storage (empty = disabled). |
| `MaxBackups` | Number of backup files to keep (default 5). |

## Event Objects

Each detected event is represented by an `Event` object:

```matlab
e = Event(startTime, endTime, 'temperature', 'temp high', 85, 'upper');
e.setStats(peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal);
```

**Core properties** (set at construction, read‑only):

- `StartTime`, `EndTime`, `Duration` (days)
- `SensorName`, `ThresholdLabel`, `ThresholdValue`, `Direction` (`'upper'` or `'lower'`)

**Statistics** (populated by `setStats` or the detector):

- `PeakValue`, `NumPoints`, `MinValue`, `MaxValue`, `MeanValue`, `RmsValue`, `StdValue`

**Open/close lifecycle** (`IsOpen` flag, `close()` method):

```matlab
e.IsOpen = true;   % event still in progress
e.close(endTime, finalStats);   % finalises event (EndTime, Duration, stats)
```

**Severity escalation** (`escalateTo`):

```matlab
e.escalateTo('HH Alarm', 95)  % changes label & threshold value in place
```

**Tag‑binding** (`TagKeys`, `EventBinding`): events can be linked to any number of tags for advanced filtering.

## Live Event Detection

### Data Sources

Data sources implement the abstract `DataSource` interface; they return new data since the last call.

```matlab
% Test‑data generator
mockDS = MockDataSource('BaseValue', 100, 'NoiseStd', 2, ...
    'ViolationProbability', 0.001, 'ViolationAmplitude', 25);

% File‑based source for a continuously‑updated .mat file
fileDS = MatFileDataSource('sensors/temp.mat', ...
    'XVar', 'time', 'YVar', 'temp');
```

A `DataSourceMap` binds keys (sensor names) to data sources:

```matlab
dsMap = DataSourceMap();
dsMap.add('temperature', mockDS);
dsMap.add('pressure', fileDS);
```

### LiveEventPipeline

`LiveEventPipeline` orchestrates continuous monitoring. It expects a `containers.Map` of tag keys to `MonitorTag` objects and a `DataSourceMap`.

```matlab
% Suppose 'monitors' is a containers.Map with keys -> MonitorTag instances
pipeline = LiveEventPipeline(monitors, dsMap, ...
    'Interval', 15, ...              % poll every 15 seconds
    'MinDuration', 5, ...            % 5‑second minimum events
    'EscalateSeverity', true);

% Attach optional storage and notification
pipeline.EventStore = EventStore('live_events.mat', 'MaxBackups', 3);
pipeline.NotificationService = NotificationService('DryRun', true);

% Start / stop
pipeline.start();   % begins timer‑driven cycles
pipeline.stop();    % halts timer
```

During each `runCycle()`, the pipeline:

1. Fetches new data from every `DataSource`.
2. Calls `MonitorTag.Parent.updateData(newX, newY)` then `MonitorTag.appendData(newX, newY)` (order matters – see Pitfall Y in source comments).
3. Uses an internal `EventDetector` to find events from threshold crossings.
4. Appends new events to the `EventStore` and dispatches notifications.

> **Legacy Note:** `IncrementalEventDetector.process` is a stub. For incremental detection use `MonitorTag.appendData` via `LiveEventPipeline`.

## Event Storage and Persistence

### EventStore

`EventStore` provides atomic read/write of events to a shared `.mat` file with backup rotation.

```matlab
store = EventStore('events.mat', 'MaxBackups', 5);
store.append(newEvents);   % atomic file operation
store.save();              % or call explicitly

% Attach metadata for EventViewer
store.SensorData = cfg.SensorData;
store.ThresholdColors = cfg.ThresholdColors;

% Load events from file later
[events, meta, changed] = EventStore.loadFile('events.mat');
```

**Key methods:**

- `append(newEvents)` – appends events, auto‑assigns unique `Id`, updates timestamp.
- `getEvents()` – returns all events in memory.
- `closeEvent(eventId, endTime, finalStats)` – closes an open event (does **not** auto‑save).
- `save()` – writes to disk.
- `static loadFile(filePath)` – returns events, metadata, and a `changed` flag.

### Auto‑save in EventConfig

Set `EventFile` and `MaxBackups`; `runDetection()` will save automatically.

```matlab
cfg.EventFile = 'auto_events.mat';
cfg.MaxBackups = 5;
events = cfg.runDetection();   % events saved, backups rotated
```

## Event Visualization – EventViewer

`EventViewer` displays a Gantt timeline and a filterable table.

```matlab
% Create viewer with full context
viewer = EventViewer(events, sensorData, thresholdColors);

% Or open from a saved EventStore file
viewer = EventViewer.fromFile('events.mat');

% Auto‑refresh from the same file (e.g., every 10 seconds)
viewer.startAutoRefresh(10);
viewer.stopAutoRefresh();

% Update with new events programmatically
viewer.update(newEvents);
```

**Features:**

- **Gantt timeline** – coloured bars, one row per sensor, bar width = event duration.
- **Filterable table** – filter by sensor name, threshold label, date range.
- **Click‑to‑highlight** – clicking a bar highlights the corresponding table row.
- **Auto‑refresh** – polls the source file for changes.
- **Export** – context menu options for data export.

## Notification System

### Notification Rules

`NotificationRule` defines a matching condition, template, and delivery options.  Rules are scored: 3 = exact match (sensor + threshold), 2 = sensor match only, 1 = default.

```matlab
% Default rule (catches anything)
defaultRule = NotificationRule('Recipients', {{'ops@company.com'}}, ...
    'Subject', 'Event: {sensor} - {threshold}', ...
    'IncludeSnapshot', false);

% Sensor‑specific rule
tempRule = NotificationRule('SensorKey', 'temperature', ...
    'Recipients', {{'thermal@company.com'}}, ...
    'Subject', 'Temperature Event: {threshold}', ...
    'IncludeSnapshot', true, ...
    'ContextHours', 2);

% Exact match (sensor + threshold)
criticalRule = NotificationRule('SensorKey', 'temperature', ...
    'ThresholdLabel', 'critical', ...
    'Recipients', {{'safety@company.com','manager@company.com'}}, ...
    'Subject', 'CRITICAL: {sensor} {threshold}!');
```

### Template Variables

Use curly‑brace placeholders in `Subject` and `Message`:

- `{sensor}`, `{threshold}`, `{direction}`, `{peak}`
- `{startTime}`, `{endTime}`, `{duration}`
- `{mean}`, `{std}`, `{min}`, `{max}`, `{rms}`

### NotificationService

The `NotificationService` holds rules, handles snapshot generation, and sends emails.

```matlab
notif = NotificationService('DryRun', true, ...   % test mode
    'SnapshotDir', 'snapshots/', ...
    'SmtpServer', 'mail.company.com');

notif.setDefaultRule(defaultRule);
notif.addRule(tempRule);
notif.addRule(criticalRule);

% On each event (called by pipeline)
notif.notify(event, sensorData);
```

**Snapshots** are generated by `generateEventSnapshot` – two PNG files per event (detail and context).

## Severity Escalation

When a sensor has multiple thresholds (e.g., `'Warning'` at 85, `'Alarm'` at 95), enabling `EscalateSeverity` causes an event that starts at a lower threshold but peaks above a higher one to be escalated **in place**.  The original time span is kept, but label and value change to the higher threshold.

```matlab
det = EventDetector('EscalateSeverity', true);
% … event starts at 87 (Warning) but peak is 97 → escalated to Alarm
```

This behaviour can be controlled via `EventConfig.EscalateSeverity` or `EventDetector` constructor.

## Utility Functions

### `eventLogger()` – Console callback

Returns a function handle that prints a one‑line log:

```matlab
cfg.OnEventStart = eventLogger();
% Prints: [EVENT] Temperature | temp high | UPPER | 123.45 -> 125.67 (dur=0.02) | peak=126.83
```

### `printEventSummary(events)` – Tabular summary

```matlab
printEventSummary(events);
% Outputs a formatted table with Start, End, Duration, Sensor, Threshold, Dir, Peak, #Pts, Mean, Std
```

### `generateEventSnapshot(event, sensorData)` – Graphical snapshots

```matlab
files = generateEventSnapshot(event, sensorData, ...
    'OutputDir', 'snapshots/', ...
    'ContextHours', 2);
% Returns {detailFile, contextFile}
```

### Bridging with Sensors

If you have a `Sensor` with `ResolvedViolations` and `ResolvedThresholds`, the function `detectEventsFromSensor` (from the [[Sensors]] library) converts them directly to `Event` objects.

## Performance Considerations

- **MinDuration** – debounce noise with a reasonable minimum (seconds).
- **MaxCallsPerEvent** – limit callback overhead in high‑frequency streams.
- **MaxBackups** – control disk usage.
- **EventStore** – atomic writes, but only as often as needed; call `save()` sparingly.
- **Snapshot generation** – PNG creation is expensive; use only for high‑severity events or throttled intervals.
- **Live pipeline** – balance polling interval (`Interval`) against system load.

## Common Patterns

### Multi‑sensor batch analysis

```matlab
cfg = EventConfig();
cfg.Sensors = {tempSensor, pressSensor, vibSensor};
cfg.AutoOpenViewer = true;
events = cfg.runDetection();
```

### Live monitoring with persistence and alerts

```matlab
pipeline = LiveEventPipeline(monitors, dsMap, ...
    'Interval', 30, 'EventStore', store);
pipeline.NotificationService = notificationService;
pipeline.start();
```

### Retrospective analysis from saved store

```matlab
viewer = EventViewer.fromFile('historical_events.mat');
[events, meta] = EventStore.loadFile('historical_events.mat');
% programmatic filtering
criticals = events(strcmp({events.ThresholdLabel}, 'critical'));
```

## See Also

- [[Sensors]] – Configure thresholds and violations
- [[Live Mode Guide]] – Real‑time data streaming patterns
- [[Dashboard Engine Guide]] – Multi‑plot coordination
- [[Event Detection|API Reference: Event Detection]] – Detailed class and method documentation
- [[Examples]] – Complete working examples
