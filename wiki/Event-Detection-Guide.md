<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Event Detection Guide

The Event Detection system provides real‑time threshold‑violation monitoring, persistent event storage, interactive visualisation, and rule‑based notifications, all built around the **MonitorTag** architecture from the [[Sensors]] library. It bridges low‑level signal monitoring with high‑level operational awareness: event logging, acknowledgement tracking, tag‑based grouping, email alerts, and snapshot generation.

## When to Use Event Detection

* **Live process monitoring** – detect excursions from normal operating bands seconds after they occur
* **Alarm management** – track open/closed/acknowledged state per ISA‑18.2
* **Multi‑user cluster** – run detection on a central server and share events across workstations via SQLite / NDJSON
* **Custom notification pipelines** – route alarms through an existing corporate mailer or webhook without touching SMTP config
* **Event review** – browse filtered Gantt timelines, zoom to sensor data, and export summaries

## Core Workflow

1. **Create MonitorTag objects** (see [[Sensors]] guide) – each carries a sensor, threshold rules, and incremental detection logic.
2. **Supply data sources** – live files, mock generators, or any class that implements `fetchNew()`.
3. **Launch a `LiveEventPipeline`** – connects monitors to data sources, runs repeated detection cycles, picks up new events, and fires callbacks.
4. **Store events** – the pipeline pushes events into an `EventStore`; you can save to a `.mat` file (single‑user) or to a shared SQLite + NDJSON folder (cluster).
5. **Visualise & act** – open an `EventViewer` for a Gantt timeline or a filterable table; set up `NotificationService` for email alerts with optional PNG snapshots.

## Quick Start with a Mock Data Source

```matlab
% 1. Create data sources
mockDS = MockDataSource('BaseValue', 100, 'NoiseStd', 2, ...
    'ViolationProbability', 0.01, 'ViolationAmplitude', 25, ...
    'SampleInterval', 3, 'BacklogDays', 3, 'PipelineInterval', 15);
dsMap = DataSourceMap();
dsMap.add('temperature', mockDS);

% 2. Assume we have a MonitorTag for temperature already built
%    (constructed via the Sensors library – see [[Sensors]])
% monitors = containers.Map;
% monitors('temperature') = tempMonitor;

% 3. Create the pipeline
pipeline = LiveEventPipeline(monitors, dsMap, ...
    'EventFile', 'events.mat', ...
    'Interval', 15, ...
    'MinDuration', 2, ...
    'EscalateSeverity', true, ...
    'MaxCallsPerEvent', 2);

% 4. Start monitoring
pipeline.start();
pause(60);               % let it run for 1 minute
pipeline.stop();

% 5. View stored events
viewer = EventViewer.fromFile('events.mat');
```

## Live Event Pipeline

`LiveEventPipeline` is the central orchestrator. It holds a `containers.Map` of **MonitorTargets** (each a `MonitorTag` from the Sensors library) and a `DataSourceMap`. Every `Interval` seconds, `runCycle()` fetches new data from each source, feeds it to the corresponding `MonitorTag`, and automatically appends any newly detected events to the attached `EventStore`.

### Constructor Options

```matlab
pipeline = LiveEventPipeline(monitors, dataSourceMap, ...
    'EventFile',       'shared.mat', ... % auto‑create EventStore
    'Interval',        15, ...
    'MinDuration',     0, ...            % forwarded to MonitorTag
    'EscalateSeverity', true, ...
    'MaxCallsPerEvent', 1, ...
    'OnEventStart',    eventLogger());   % simple console log per event
```

### Cluster Mode (Multi‑User)

Pass a `'SharedRoot'` to enable cluster support:

```matlab
pipeline = LiveEventPipeline(monitors, dsMap, ...
    'SharedRoot', '//network/server/monitoring/');
```

This activates:
* per‑monitor file locking via `TagWriteCoordinator`  
* SQLite‑backed event storage with application‑level retry on lock contention  
* NDJSON logs per tag in `<SharedRoot>/events/<tagKey>.events.ndjson`  
* `SkippedMonitorCount`, `LastTickDurationSec`, and `LastLockContentionEvent` for observability

## Event Objects

Each detection result is an `Event` handle. Key public fields (detailed in the [[Event Detection|API Reference]]):

```matlab
event.StartTime        % datenum
event.EndTime          % datenum (NaN while open)
event.Duration         % days (0 while open)
event.SensorName       % char
event.ThresholdLabel   % char
event.ThresholdValue   % double
event.Direction        % 'upper' | 'lower'

% Statistics (set by detector)
event.PeakValue
event.NumPoints
event.MinValue         % minimum during violation
event.MaxValue
event.MeanValue
event.RmsValue
event.StdValue

% Lifecycle (ISA‑18.2)
event.IsOpen           % true until explicitly closed
event.Id               % unique char assigned by EventStore.append
event.Notes            % free‑form user annotation

% Acknowledgment
event.AckedAt          % datenum ([] if not acked)
event.AckedBy          % struct with fields: user, host, epoch, comment
event.AckComment       % convenience alias

% Classification
event.Severity         % numeric: 1=info, 2=warn, 3=alarm
event.Category         % char: 'alarm','maintenance','process_change','manual_annotation'
event.TagKeys          % cell array of tag keys bound to this event
```

### Opening, Closing, and Escalation

```matlab
% Events are emitted open (IsOpen = true) by MonitorTag.
% Later, when the condition clears or user intervention happens:
store.closeEvent(event.Id, endTime, finalStats);
% finalStats can be [] or a struct with PeakValue, NumPoints, etc.

% Severity escalation (e.g., H → HH)
event.escalateTo('HH Alarm', 95.0);
```

### Acknowledging Events

```matlab
ack = store.acknowledgeEvent(eventId, ...
    'User', 'operator1', ...
    'Comment', 'Checked tank level – safe');
% Now event.AckedAt, AckedBy are populated.
% Visual display state can be obtained:
state = event.computeDisplayState();  % 'unacked-active', etc.
```

## Event Storage and Persistence

`EventStore` provides atomic file operations (or SQLite in cluster mode) with backup rotation.

### Single‑User (.mat File)

```matlab
store = EventStore('events.mat', 'MaxBackups', 5);
store.append(newEventArray);
store.save();
```

The pipeline’s built‑in store (when `'EventFile'` is set) uses the same class automatically.

### Cluster Mode

Use `'SharedRoot'` in the constructor. The store opens a SQLite database at `<SharedRoot>/store.sqlite`. All writes use `BEGIN IMMEDIATE` with a `busyRetryWrap_` loop to handle concurrent access.

```matlab
store = EventStore('events.db', 'SharedRoot', '/network/monitoring/');
store.append(event);
```

### Retrieving Events

```matlab
allEvents = store.getEvents();
% Retrieve only events bound to a tag
tagEvents = store.getEventsForTag('critical_temp');
```

### Loading From a File

```matlab
[events, metadata, changed] = EventStore.loadFile('events.mat');
% metadata includes SensorData, ThresholdColors, PipelineConfig, etc.
```

## Binding Events to Tags

`EventBinding` maintains a many‑to‑many mapping between events and tag keys. This helps group related events (e.g., all alarms for a pump, or all events from a batch).

```matlab
EventBinding.attach(event.Id, 'Batch_2025-04_Unit3');
keys = EventBinding.getTagKeysForEvent(event.Id);
tagEvents = EventBinding.getEventsForTag('Batch_2025-04_Unit3', store);
EventBinding.clear();   % reset all bindings (usually not needed)
```

## Event Visualization

`EventViewer` displays a figure with:

* A **Gantt timeline** – bars coloured by threshold label
* A **filterable table** – filter by sensor, threshold, date range
* Interactive linking: click a bar to highlight its table row
* Auto‑refresh for live dashboards

```matlab
% From a file
viewer = EventViewer.fromFile('events.mat');
viewer.startAutoRefresh(10);  % poll every 10 s

% From workspace arrays
viewer = EventViewer(events, sensorData, thresholdColors);
viewer.update(newEventBatch);
```

## Notification System

`NotificationService` applies priority‑matched `NotificationRule` objects to incoming events, generates optional PNG snapshots, and sends emails (or forwards to a custom function). It supports cooldown windows and dry‑run mode.

### Configuring Rules

```matlab
% Default rule (fallback)
defaultRule = NotificationRule( ...
    'Recipients', {{'ops@example.com'}}, ...
    'Subject', 'Process Event: {sensor}', ...
    'IncludeSnapshot', false);

% Specific sensor rule
tempRule = NotificationRule( ...
    'SensorKey', 'temperature', ...
    'Recipients', {{'thermal@example.com'}}, ...
    'Subject', 'Temperature: {threshold}', ...
    'IncludeSnapshot', true, ...
    'ContextHours', 2);

% Exact match (sensor + threshold label)
criticalRule = NotificationRule( ...
    'SensorKey', 'temperature', ...
    'ThresholdLabel', 'HH Alarm', ...
    'Recipients', {{'safety@example.com'}}, ...
    'Subject', 'CRITICAL: {sensor} {threshold}');
```

### Setting Up the Service

```matlab
ns = NotificationService(...
    'DryRun', true, ...             % test mode – logs to console
    'CooldownMinutes', 5, ...      % suppress repeat alerts within window
    'SnapshotDir', 'snapshots/', ...
    'SnapshotRetention', 7);       % auto‑delete old PNGs after 7 days

ns.setDefaultRule(defaultRule);
ns.addRule(tempRule);
ns.addRule(criticalRule);
pipeline.NotificationService = ns;
```

### Real SMTP vs. Custom Transport

By default, `NotificationService` builds an `EmailTransport` using its own `SmtpServer`, `SmtpPort`, etc. You can inject a pre‑configured `EmailTransport` or a `FunctionTransport` to hand off to an existing corporate mailer:

```matlab
% Use an existing mailer function: companyMail(to, subject, body, attachments)
transport = FunctionTransport(@(to,subj,body,att) companyMail(to,subj,body,att));
ns = NotificationService('Transport', transport, 'CooldownMinutes', 5);
```

### Template Variables

The `Subject` and `Message` strings accept these placeholders:

* `{sensor}`, `{threshold}`, `{direction}`, `{peak}`
* `{startTime}`, `{endTime}`, `{duration}`
* `{mean}`, `{std}`, `{min}`, `{max}`, `{rms}`

### Event Snapshots

Two PNG files are generated per event:

```matlab
files = generateEventSnapshot(event, sensorData, ...
    'OutputDir', 'snapshots/', ...
    'SnapshotSize', [800, 400], ...
    'Padding', 0.1, ...          % extra fraction of event duration
    'ContextHours', 2);          % historical context before the event
% files{1} = detail plot, files{2} = context plot
```

## Utility Functions

* **`eventLogger()`** – returns a function handle that prints a one‑line summary. Use as `OnEventStart` callback.
* **`printEventSummary(events)`** – prints a console table with peak, mean, std, etc.
* **`generateEventSnapshot(...)`** – described above.

## Severity Escalation

When `EscalateSeverity` is enabled (default in both pipeline and `MonitorTag`), an event that starts at a lower threshold (e.g., “H Warning”) may be upgraded to a higher one (e.g., “HH Alarm”) if the signal crosses the higher threshold during the same violation window. This is handled automatically by the `MonitorTag`.

Manual escalation is also possible on any event:
```matlab
event.escalateTo('HH Alarm', 95.0);
```

## Performance Considerations

* **`MinDuration`** – use a positive value to filter out transient noise glitches.
* **`CooldownMinutes`** – prevent notification storms; set per‑(sensor,threshold) cooldown.
* **Backup rotation** – `MaxBackups` limits disk usage.
* **Cluster locking** – if lock contention is high, the pipeline skips a monitor for that tick (SkippedMonitorCount rises). Monitor the count and adjust intervals or hardware.
* **Snapshot generation** – PNG creation is I/O intensive; disable `IncludeSnapshot` for non‑critical notifications or use `SnapshotRetention` to clean up.

## Common Patterns

**Live dashboard with auto‑refresh**
```matlab
pipeline = LiveEventPipeline(monitors, dsMap, 'EventFile', 'dash.mat');
pipeline.start();
viewer = EventViewer.fromFile('dash.mat');
viewer.startAutoRefresh(10);
```

**Acknowledging all open events of a critical tag**
```matlab
evs = EventBinding.getEventsForTag('critical_temp', store);
openIdx = [evs.IsOpen];
arrayfun(@(e) store.acknowledgeEvent(e.Id, 'User','operator1'), evs(openIdx));
```

**Attaching a manual annotation event** (e.g., operator note)
```matlab
manualEvent = Event(now, NaN, 'System', 'operator_note', 0, 'upper');
manualEvent.Category = 'manual_annotation';
manualEvent.Notes = 'Started batch cleaning cycle.';
store.append(manualEvent);
```

## See Also

* [[Sensors]] – Build MonitorTag objects and define thresholds
* [[Event Detection|API Reference: Event Detection]] – Full class and method details
* [[Live Mode Guide]] – Real‑time data streaming with data sources
* [[Dashboard Engine Guide]] – Combine multiple viewers and plots
* [[Examples]] – Complete working examples
