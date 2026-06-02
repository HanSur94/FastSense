<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Event Detection Guide

The Event Detection system in FastSense provides comprehensive threshold‑based monitoring with live detection, notification services, and visual event management. It bridges the [[Sensors]] library for threshold analysis with real-time event pipelines, storage, notifications, and headless operation.

## When to Use Event Detection

- **Real-time monitoring**: Detect threshold violations as they occur in live data streams
- **Historical analysis**: Analyze events from recorded sensor data with statistical summaries
- **Alert systems**: Configure rule-based notifications with email and snapshot generation
- **Event visualization**: View events in Gantt timelines and filterable tables
- **Data archival**: Store events with automatic backup rotation and atomic file operations
- **Headless operation**: Run unsupervised background monitoring with `runBackgroundMonitoring`

## Core Workflow

The event detection workflow follows these steps:

1. **Configure sensors** with thresholds using the [[Sensors]] library
2. **Set up data sources** to fetch new sensor data (live files, mock data, etc.)
3. **Configure event detection** with minimum duration, callbacks, and escalation
4. **Run detection** to find threshold violations and generate Event objects
5. **Store and visualize** events using EventStore and EventViewer

## Basic Event Detection

### Quick Start Example

```matlab
% Create a sensor with threshold
sensor = Sensor('temperature');
sensor.X = 1:100;
sensor.Y = 70 + 10*sin((1:100)/10) + randn(1,100);
sensor.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'temp high');

% Configure and run detection
cfg = EventConfig();
cfg.MinDuration = 2;  % 2-second minimum
cfg.addSensor(sensor);
events = cfg.runDetection();

% Print summary
printEventSummary(events);
```

### EventConfig – Central Configuration

The [[Event Detection|API Reference: Event Detection]] `EventConfig` class orchestrates all event detection:

```matlab
cfg = EventConfig();
cfg.MinDuration = 1.5;              % Debounce short violations
cfg.MaxCallsPerEvent = 2;           % Limit callback invocations
cfg.EscalateSeverity = true;        % H → HH when peak exceeds higher threshold
cfg.AutoOpenViewer = true;          % Open EventViewer after detection
cfg.OnEventStart = eventLogger();   % Console logging callback

% Auto-save events to file with backup rotation
cfg.EventFile = 'my_events.mat';
cfg.MaxBackups = 5;

% Add sensors
cfg.addSensor(temperatureSensor);
cfg.addSensor(pressureSensor);

% Set threshold colors for visualization
cfg.setColor('temp warning', [1 0.8 0]);
cfg.setColor('temp critical', [1 0.2 0]);

% Run detection
events = cfg.runDetection();
```

### Event Objects

Each detected event is represented by an [[Event Detection|Event]] object. Key properties:

```matlab
% Basic identification
event.StartTime       % datenum of violation start
event.EndTime         % datenum of violation end  
event.Duration        % duration in days
event.SensorName      % sensor identifier
event.ThresholdLabel  % threshold name
event.ThresholdValue  % numeric value
event.Direction       % 'upper' or 'lower'

% Statistical properties (set by detector)
event.PeakValue      % most extreme value during violation
event.NumPoints      % number of data points in violation
event.MinValue       % minimum value during violation
event.MaxValue       % maximum value during violation
event.MeanValue      % mean value
event.RmsValue       % RMS value
event.StdValue       % standard deviation

% Extended identity and tracking (Phase 1012+)
event.Id             % unique identifier assigned by EventStore
event.IsOpen         % true while event is still active
event.Notes          % free-form user annotation
event.Severity       % numeric severity level (1=info, 2=warn, 3=alarm)
event.Category       % alarm|maintenance|process_change|manual_annotation
event.TagKeys        % cell of tag keys bound to this event

% Acknowledgment support
event.AckedAt        % datenum of acknowledgment; [] if unacked
event.AckedBy        % struct with user, host, epoch, comment
event.AckComment     % convenience alias for AckedBy.comment
```

New events can be created manually if needed:

```matlab
ev = Event(datenum(now), datenum(now)+1/1440, 'Temp', 'High', 85, 'upper');
ev.setStats(92.3, 120, 70, 92.3, 80.1, 82.5, 5.2);
```

### Converting Sensor Violations to Events

The detector can work directly with sensor threshold violations:

```matlab
events = detectEventsFromSensor(sensor);
% or with a custom detector
events = detectEventsFromSensor(sensor, customDetector);
```

## Live Event Detection

### Data Sources

Data sources provide the interface between your data and the event detection system:

```matlab
% Mock data source for testing – realistic industrial signals
mockDS = MockDataSource('BaseValue', 100, 'NoiseStd', 2, ...
    'ViolationProbability', 0.001, 'ViolationAmplitude', 25);

% File-based data source for live monitoring from a continuously‑updated .mat
fileDS = MatFileDataSource('sensors/temp.mat', 'XVar', 'time', 'YVar', 'temp');

% Map sensor keys to data sources
dsMap = DataSourceMap();
dsMap.add('temperature', mockDS);
dsMap.add('pressure', fileDS);
```

### Live Pipeline

`LiveEventPipeline` orchestrates continuous monitoring using `MonitorTag` objects and data sources:

```matlab
% Create monitors from your sensors (built from SensorThreshold library)
% monitors = ... % containers.Map of key -> MonitorTag

% Create pipeline
pipeline = LiveEventPipeline(monitors, dsMap, ...
    'EventFile', 'live_events.mat', ...
    'Interval', 15, ...              % 15‑second polling
    'MinDuration', 5, ...            % minimum event duration (seconds)
    'EscalateSeverity', true);

% Configure notifications
notifService = NotificationService('DryRun', true);
pipeline.NotificationService = notifService;

% Start/stop live monitoring
pipeline.start();   % begins timer-driven cycles
pipeline.stop();    % stops timer
```

### Incremental Detection

For manual update loops or low-level control, use `IncrementalEventDetector`:

```matlab
detector = IncrementalEventDetector('MinDuration', 2, ...
    'EscalateSeverity', true);

% Process incremental updates
newEvents = detector.process('temp_01', sensor, newX, newY, [], []);

% Check for ongoing (open) events
if detector.hasOpenEvent('temp_01')
    state = detector.getSensorState('temp_01');
    fprintf('Open event since %.2f\n', state.openEventStart);
end
```

## Event Storage and Persistence

### EventStore – Atomic File Operations

`EventStore` provides thread-safe event persistence with backup rotation:

```matlab
% Create event store
store = EventStore('events.mat', 'MaxBackups', 3);

% Attach sensor data for EventViewer context
store.SensorData = cfg.SensorData;
store.ThresholdColors = cfg.ThresholdColors;

% Append new events (atomic temp+rename)
store.append(newEvents);
store.save();

% Load from file
[events, metadata, changed] = EventStore.loadFile('events.mat');
```

For cluster/shared environments, EventStore supports a central SQLite database (`'SharedRoot'` parameter), but the single-user file mode remains the default.

### Acknowledging Events

Events can be acknowledged to track operator response (ISA‑18.2 / EEMUA‑191 compliance):

```matlab
ack = store.acknowledgeEvent(eventId, ...
    'by_user', 'operator1', 'by_host', 'controlroom');

% Read back
rows = store.getAckRecordsForEvent(eventId);
disp(rows.comment);
```

The `Event` object’s `computeDisplayState` method returns one of:
- `'unacked-active'` – still open, not acknowledged
- `'acked-active'` – open but acknowledged
- `'acked-cleared'` – closed and acknowledged
- `'unacked-cleared'` – closed but never acknowledged

### Closing Open Events

When a threshold violation ends, the event must be closed:

```matlab
store.closeEvent(eventId, endTime, finalStats);
```

`finalStats` is a struct with fields like `PeakValue`, `NumPoints`, `MeanValue`, etc. (can be empty to skip stats update).

## Event Visualization

### EventViewer – Interactive Timeline

`EventViewer` provides a Gantt timeline and filterable table:

```matlab
% Create from arrays
viewer = EventViewer(events, sensorData, thresholdColors);

% Or load directly from a saved file
viewer = EventViewer.fromFile('events.mat');

% Auto-refresh from the source file
viewer.startAutoRefresh(10);  % refresh every 10 seconds
viewer.stopAutoRefresh();

% Manual refresh
viewer.refreshFromFile();

% Append new events
viewer.update(newEvents);
```

Features:
- **Gantt timeline** with coloured bars per threshold
- **Filterable table** by sensor, threshold, date range, or display state
- **Click interaction** – click a Gantt bar to highlight its row
- **Auto‑refresh** for live monitoring
- **Export** options via context menus

## Notification System

### Notification Rules

Configure rule-based notifications with priority matching:

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

% Exact match rule (highest priority)  
criticalRule = NotificationRule('SensorKey', 'temperature', ...
    'ThresholdLabel', 'critical', ...
    'Recipients', {{'safety@company.com', 'manager@company.com'}}, ...
    'Subject', 'CRITICAL: {sensor} {threshold}!');
```

### NotificationService

`NotificationService` manages rule matching, cooldown, snapshot generation, and sending:

```matlab
notif = NotificationService( ...
    'DryRun', true, ...             % test mode
    'SnapshotDir', 'snapshots/', ...
    'SmtpServer', 'mail.company.com', ...
    'CooldownMinutes', 5);          % avoid repeated alerts

notif.setDefaultRule(defaultRule);
notif.addRule(tempRule);
notif.addRule(criticalRule);

% Notify on event
notif.notify(event, sensorData);
```

### Using a Custom Email Function

If you have an existing email sending function, use `FunctionTransport` to bypass SMTP configuration:

```matlab
transport = FunctionTransport(@(to,subject,body,att) companyMail(to,subject,body));
notif.Transport = transport;
```

This adapts any 4‑argument function to the transport interface.

### Email Templates

Templates support substituted variables:

```matlab
rule = NotificationRule( ...
    'Subject', 'Alert: {sensor} exceeded {threshold}', ...
    'Message', ['Sensor: {sensor}\n' ...
               'Threshold: {threshold} ({direction})\n' ...
               'Time: {startTime} to {endTime}\n' ...
               'Duration: {duration}\n' ...
               'Peak: {peak}\n' ...
               'Statistics: mean={mean}, std={std}']);
```

Available variables: `{sensor}`, `{threshold}`, `{direction}`, `{peak}`, `{startTime}`, `{endTime}`, `{duration}`, `{mean}`, `{std}`, `{min}`, `{max}`, `{rms}`.

### Event Snapshots

Generate PNG snapshots showing the event in detail and context:

```matlab
files = generateEventSnapshot(event, sensorData, ...
    'OutputDir', 'snapshots/', ...
    'SnapshotSize', [800, 400], ...
    'Padding', 0.1, ...          % 10% padding around event
    'ContextHours', 2);          % 2 hours before event

% Returns {detailFile, contextFile}
```

Snapshots correctly handle still‑open events (EndTime=NaN) by clamping to the last data point.

## Severity Escalation

When a violation peaks beyond a higher threshold, a new event with the higher severity label replaces the original (escalation). Example:

```matlab
% Sensor with two thresholds
sensor.addThresholdRule(struct(), 85, 'Label', 'H Warning');
sensor.addThresholdRule(struct(), 95, 'Label', 'HH Alarm');

detector = EventDetector('EscalateSeverity', true);
% If violation starts at 87 (H Warning) but peaks at 97,
% the original event will be superseded by an event labelled 'HH Alarm'
events = detectEventsFromSensor(sensor, detector);
```

The escalated event keeps the same time span but reports the higher threshold value and label.

## Utility Functions

### Event Logging

A simple console logger for development:

```matlab
cfg.OnEventStart = eventLogger();
% Output: [EVENT] Temperature | temp high | UPPER | 123.45 → 125.67 (dur=0.02) | peak=126.83
```

### Event Summary

Print a formatted table to the console:

```matlab
printEventSummary(events);
% prints columns: Start, End, Duration, Sensor, Threshold, Dir, Peak, #Pts, Mean, Std
```

### Headless Background Monitoring

`runBackgroundMonitoring` is the entry point for unattended operation (launchd, systemd, cron):

```matlab
% User‑defined setup function (e.g., my_setup.m)
function p = my_setup()
    % build monitors, dsMap, notification service …
    p = LiveEventPipeline(monitors, dsMap, ...
        'EventFile', '/var/log/fastsense/events.mat', 'Interval', 30);
    p.NotificationService = NotificationService('DryRun', false, ...
        'SmtpServer', getenv('FASTSENSE_SMTP_SERVER'));
end

% Invocation:
% matlab -batch "runBackgroundMonitoring(@my_setup, 'PollSec', 60, 'MaxRuntimeSec', 86400)"
```

The function installs a safe‑stop cleanup, prints heartbeats, and respects a runtime cap.

## Performance Considerations

- **MinDuration**: Use appropriate debounce to filter noise
- **MaxCallsPerEvent**: Limit callback overhead
- **Backup rotation**: Configure MaxBackups to manage disk usage
- **Incremental detection**: Use `IncrementalEventDetector` to avoid reprocessing full datasets
- **File polling**: Balance refresh intervals with system load
- **Snapshot generation**: PNG creation can be expensive; use sparingly
- **Cluster mode**: In shared environments, configure `SharedRoot` only if multi‑writer access is needed

## Common Patterns

### Multi-Sensor Dashboard with Events

```matlab
cfg = EventConfig();
cfg.addSensor(temperatureSensor);
cfg.addSensor(pressureSensor);
cfg.addSensor(vibrationSensor);
cfg.AutoOpenViewer = true;
events = cfg.runDetection();
```

### Live Monitoring with Notifications

```matlab
pipeline = LiveEventPipeline(monitors, dataSourceMap, ...
    'EventFile', 'monitoring.mat', 'Interval', 30);
pipeline.NotificationService = notificationService;
pipeline.start();
```

### Event Analysis Workflow

```matlab
viewer = EventViewer.fromFile('historical_events.mat');

% Programmatic analysis
[events, meta] = EventStore.loadFile('historical_events.mat');
tempEvents = events(strcmp({events.SensorName}, 'Temperature'));
criticalEvents = events(strcmp({events.ThresholdLabel}, 'critical'));
printEventSummary(criticalEvents);
```

### Bind Events to Tags

```matlab
% Tags can be attached to events for categorisation
EventBinding.attach(event.Id, 'maintenance');
boundEvents = EventBinding.getEventsForTag('maintenance', store);
```

## See Also

- [[Sensors]] – Configure thresholds and violations
- [[Live Mode Guide]] – Real-time data streaming patterns
- [[Dashboard Engine Guide]] – Multi-plot coordination
- [[Event Detection|API Reference: Event Detection]] – Full class and method reference
- [[Examples]] – Complete working examples
