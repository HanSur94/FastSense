<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Event Detection Guide

The Event Detection system in FastSense provides threshold-based monitoring with live detection, notification services, visual event management, and advanced storage options. It bridges the [[Sensors]] library (MonitorTag thresholds) with real‑time event pipelines, persistent storage, and operator workflows.

## When to Use Event Detection

- **Live monitoring** – detect threshold violations as they occur in streaming data  
- **Historical batch analysis** – generate Event arrays from recorded sensor data using the offline detectors in [[Sensors]]  
- **Alert systems** – rule‑based email notifications with event snapshot generation  
- **Visual event review** – Gantt timelines, filterable tables, and click‑to‑plot context  
- **Data archival** – atomic file operations with backup rotation and optional cluster‑mode storage  
- **Operational context** – event acknowledgement, operator notes, and open‑event tracking  

## Core Workflow

1. **Configure sensors** – create MonitorTag objects with thresholds using [[Sensors]]  
2. **Provide data sources** – map sensor keys to `DataSource` instances (mock, file‑based, etc.)  
3. **Create a live pipeline** – instantiate `LiveEventPipeline` with monitors, data sources, and an `EventStore`  
4. **Start the pipeline** – periodic polling fetches new data, detects violations, emits `Event` objects  
5. **Acknowledge & annotate** – operators flag events as seen, add notes, and close open events  
6. **Visualise results** – open `EventViewer` on the stored event file for an interactive timeline  

For offline or one‑shot analysis you can directly use the `EventDetector` in the [[Sensors]] library and obtain an array of `Event` objects.

## Live Event Detection with LiveEventPipeline

### Monitors and Data Sources

Monitors are `MonitorTag` objects (see [[Sensors]]) that define the threshold rules. A `DataSourceMap` links each monitor key to a source of new data.

```matlab
% 1. Create MonitorTags with your sensor definitions (Sensors library)
% For this example we assume tempMon, pressMon are already configured.

% 2. Set up data sources
mockDS = MockDataSource('BaseValue', 100, 'NoiseStd', 2, ...
    'ViolationProbability', 0.001, 'ViolationAmplitude', 25);
fileDS = MatFileDataSource('sensors/pressure.mat', 'XVar', 'time', 'YVar', 'press');

dsMap = DataSourceMap();
dsMap.add('temp',   mockDS);
dsMap.add('press',  fileDS);

% 3. Create the pipeline
pipeline = LiveEventPipeline({tempMon, pressMon}, dsMap, ...
    'EventFile', 'live_events.mat', ...
    'Interval', 15, ...             % poll every 15 sec
    'MinDuration', 5, ...           % ignore violations shorter than 5 sec
    'EscalateSeverity', true);      % promote an event when peak exceeds a higher threshold

% 4. Attach an EventStore (optional, the pipeline handles saving)
es = EventStore('live_events.mat', 'MaxBackups', 3);
pipeline.EventStore = es;

% 5. Start live monitoring
pipeline.start();
```

The pipeline runs a timer. On each tick it fetches new data, passes it to each monitor via `MonitorTag.appendData()`, and forwards emitted `Event` objects to the `EventStore`. If a `NotificationService` is attached, matching rules fire on each new event.

### Controlling the Pipeline

```matlab
pipeline.stop();     % halt the timer
pipeline.runCycle(); % manually execute one poll (useful for testing)
```

### Callbacks on Event Start

You can attach a function handle to `OnEventStart` to log or react to new events. A simple logger is provided:

```matlab
pipeline.OnEventStart = eventLogger();   % prints one-line console messages
```

### Cluster Mode (Opt‑in)

For distributed, multi‑user environments, pass `'SharedRoot'` to the constructor. The pipeline acquires per‑monitor file locks, uses SQLite for event storage, and coordinates via `EventStore` cluster mode. Single‑user mode is the default and exercises zero concurrency code.

```matlab
pipeline = LiveEventPipeline(monitors, dsMap, ...
    'SharedRoot', '/mnt/shared/data');
```

## Event Objects and Lifecycle

Each detected violation becomes an `Event` instance (see [[Event Detection|API Reference: Event Detection]] for the full API). Key properties:

```matlab
event.StartTime         % datenum when violation started
event.EndTime           % datenum when it ended (NaN if still open)
event.Duration          % days
event.SensorName        % monitor key
event.ThresholdLabel    % threshold name
event.ThresholdValue    % threshold numeric value
event.Direction         % 'upper' or 'lower'

% Statistics (set by detector)
event.PeakValue
event.NumPoints
event.MinValue  / MaxValue  / MeanValue  / RmsValue  / StdValue

% Operational metadata (Phase 1012/1032)
event.IsOpen            % true while violation is ongoing (EndTime == NaN)
event.Id                % unique ID assigned by EventStore.append()
event.Identity          % struct with audit fields
event.AckedAt           % datenum when acknowledged ([] = unacked)
event.AckedBy           % struct {user, host, epoch, comment}
event.Notes             % free‑form operator annotation
```

### Closing an Open Event

When the violation clears, the detector calls `event.close(endTime, finalStats)`, which sets `EndTime`, `Duration`, `IsOpen=false`, and updates optional stats.

### Escalation

If a monitor has multiple thresholds (e.g., Warning and Alarm), the pipeline’s `EscalateSeverity=true` replaces the event’s `ThresholdLabel` when the peak exceeds a higher threshold. The same time span is reused with the new, more severe label. You can manually escalate via `event.escalateTo(newLabel, newValue)`.

### Visual Display State

`event.computeDisplayState()` returns one of four ISA‑18.2 states:  
- `'unacked-active'` – open, not acknowledged  
- `'acked-active'` – open but acknowledged (operator saw it, condition persists)  
- `'acked-cleared'` – closed and acknowledged (normal closure)  
- `'unacked-cleared'` – closed without ever being acknowledged  

## Event Storage with EventStore

`EventStore` provides atomic read/write of events to a `.mat` file (single‑user) or a cluster‑mode SQLite database.

### Single‑User MAT‑File Storage

```matlab
% Create store with automatic backup rotation
es = EventStore('events.mat', 'MaxBackups', 5);

% Append events (the pipeline does this automatically; you can also do it manually)
newEvents = [ev1, ev2];
es.append(newEvents);
es.save();   % atomic write: temp file + rename

% Load events from file
[events, metadata, changed] = EventStore.loadFile('events.mat');
```

Attach the store to your pipeline to enable automatic per‑cycle saving:

```matlab
pipeline.EventStore = es;
```

### Acknowledging Events

`EventStore.acknowledgeEvent()` records an acknowledgement and updates the event’s `AckedAt`, `AckedBy`, and `AckComment` fields. This supports operator workflows.

```matlab
ack = es.acknowledgeEvent('evt_001', ...
    'ByUser', 'jdoe', ...
    'ByHost', 'workstation1', ...
    'Comment', 'Acknowledged – investigating');
```

You can retrieve ack records for a specific event or all events.

### Cluster‑Mode (SQLite)

When `EventStore` is constructed with a `'SharedRoot'` argument, it creates a central SQLite database under `<SharedRoot>/events/store.sqlite`. The store uses journal‑mode DELETE and application‑level retry on database locks, making it safe for concurrent writers. The same `append`, `save`, and `acknowledgeEvent` interfaces work without changes in cluster mode.

## Visualising Events with EventViewer

The `EventViewer` provides an interactive Gantt timeline and filterable table. It can be opened directly from a stored file or updated programmatically.

```matlab
% Open from a saved .mat event store file
viewer = EventViewer.fromFile('live_events.mat');

% Or create with an event array and optional sensor data for context plots
viewer = EventViewer(events, sensorData, thresholdColors);
```

Features:  
- **Gantt timeline** – colored bars for each event, labelled by threshold  
- **Filterable table** – filter by sensor, threshold, date range; click a bar to highlight the row  
- **Auto‑refresh** – polls the source file at a given interval (useful for live dashboards)  
- **Export** – context menu for data export  

```matlab
viewer.startAutoRefresh(10);  % refresh every 10 seconds
viewer.stopAutoRefresh();
viewer.refreshFromFile();     % one‑off refresh
```

## Notification System

### NotificationRule

Each rule specifies matching criteria (sensor key, threshold label) and the email recipients. A rule with a higher match score takes precedence.

```matlab
% Default rule (catches all events)
defaultRule = NotificationRule('Recipients', {{'ops@company.com'}}, ...
    'Subject', 'Event: {sensor} - {threshold}', ...
    'IncludeSnapshot', false);

% Sensor‑specific rule (higher priority)
tempRule = NotificationRule('SensorKey', 'temperature', ...
    'Recipients', {{'thermal@company.com'}}, ...
    'Subject', 'Temperature Event: {threshold}', ...
    'IncludeSnapshot', true, ...
    'ContextHours', 2);

% Exact match (highest priority)
criticalRule = NotificationRule('SensorKey', 'temperature', ...
    'ThresholdLabel', 'critical', ...
    'Recipients', {{'safety@company.com', 'manager@company.com'}}, ...
    'Subject', 'CRITICAL: {sensor} {threshold}!');
```

Template variables available in subject and body:  
`{sensor}`, `{threshold}`, `{direction}`, `{startTime}`, `{endTime}`, `{duration}`, `{peak}`, `{mean}`, `{std}`, `{min}`, `{max}`, `{rms}`.

### NotificationService

```matlab
notif = NotificationService('DryRun', true, ...   % test mode – don't send
    'SnapshotDir', 'snapshots/', ...
    'SmtpServer', 'mail.company.com');

notif.setDefaultRule(defaultRule);
notif.addRule(tempRule);
notif.addRule(criticalRule);

% Attach to the pipeline
pipeline.NotificationService = notif;
```

When an event is emitted, the service finds the best matching rule, generates optional snapshots, substitutes template variables, and sends an email. Snapshot files are automatically cleaned after a configurable retention period.

### Standalone Snapshot Generation

The function `generateEventSnapshot` creates a detail plot and a context plot for a given event, useful for reports or manual emails.

```matlab
files = generateEventSnapshot(event, sensorData, ...
    'OutputDir', 'snapshots/', ...
    'SnapshotSize', [800, 400], ...
    'Padding', 0.1, ...          % extra time around the event for detail
    'ContextHours', 2);          % hours before the event for context
% files = {detailFile, contextFile}
```

## Utility Functions

### eventLogger

Simple console logger for live pipelines or offline detectors:

```matlab
pipeline.OnEventStart = eventLogger();
% prints: [EVENT] Temperature | temp high | UPPER | 123.45 -> 125.67 (dur=0.02) | peak=126.83
```

### printEventSummary

Prints a formatted summary table of an event array:

```matlab
printEventSummary(events);
```

### generateEventSnapshot

(Described above.)

## Severity Escalation

When a monitor has multiple thresholds (e.g., `'H Warning'` at 85 and `'HH Alarm'` at 95), an initial violation may be detected at the lower threshold. If `EscalateSeverity` is `true` (default in `LiveEventPipeline`), the system checks whether the peak value during the violation exceeds a higher threshold. If so, it escalates the event to the more severe label. This is done without altering the time span, giving a single event record with the appropriate severity.

You can also escalate an event manually with `event.escalateTo(newLabel, newThresholdValue)`.

## Performance Considerations

- **MinDuration** – Use a sensible minimum (seconds) to debounce noise and avoid event storms  
- **MaxCallsPerEvent** – Limit the number of times the `OnEventStart` callback is called for a single event (set in `LiveEventPipeline`)  
- **Backup rotation** – `MaxBackups` keeps disk usage bounded; old backups are automatically purged  
- **Incremental appends** – `MonitorTag.appendData()` processes only new data points, avoiding reprocessing the entire history  
- **Auto‑refresh intervals** – In `EventViewer`, choose a polling interval that balances responsiveness with CPU load  
- **Snapshot generation** – PNG export can be expensive; use sparingly or only for high‑severity events  

## Common Patterns

### Complete Live Monitoring Stack

```matlab
% 1. Build monitors and data sources
monitors = {tempMon, pressMon};
dsMap = DataSourceMap();
dsMap.add('temp', MockDataSource('Seed', 42));
dsMap.add('press', MatFileDataSource('data.mat'));

% 2. Create pipeline with storage and notifications
es = EventStore('live_events.mat', 'MaxBackups', 3);
notif = NotificationService('DryRun', true);
% ... add rules to notif ...

pipeline = LiveEventPipeline(monitors, dsMap, ...
    'EventFile', 'live_events.mat', ...
    'Interval', 30, ...
    'MinDuration', 10, ...
    'EscalateSeverity', true);
pipeline.EventStore = es;
pipeline.NotificationService = notif;

% 3. Start and open the viewer
pipeline.start();
viewer = EventViewer.fromFile('live_events.mat');
viewer.startAutoRefresh(30);
```

### Acknowledgment Workflow

```matlab
% Retrieve events needing attention (e.g., from EventStore.getEventsForTag('temp'))
% Then ack the critical one
ack = es.acknowledgeEvent('evt_001', 'ByUser', 'operator', ...
    'ByHost', 'console1', 'Comment', 'Checked – no action needed');
```

### Cluster Deployment

Add `'SharedRoot'` to the pipeline constructor (and to the `EventStore` if used independently) to enable file‑locked, multi‑writer event storage. The pipeline automatically uses cluster‑safe write coordination.

## See Also

- [[Sensors]] – Configure thresholds and MonitorTag objects  
- [[Event Detection|API Reference: Event Detection]] – Complete API listing for all Event Detection classes  
- [[Live Mode Guide]] – Real‑time data streaming patterns  
- [[Dashboard Engine Guide]] – Multi‑plot coordination and dashboards  
- [[Examples]] – Full working example scripts
