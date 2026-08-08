<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Event Detection Guide

The Event Detection system in FastSense provides comprehensive threshold-based monitoring with live detection, notification services, and visual event management. It bridges the [[Sensors]] library for threshold analysis with real-time event pipelines, storage, and notifications.

## When to Use Event Detection

- **Real-time monitoring**: Detect threshold violations as they occur in live data streams
- **Historical analysis**: Analyze events from recorded sensor data with statistical summaries
- **Alert systems**: Configure rule-based notifications with email and snapshot generation
- **Event visualization**: View events in Gantt timelines and filterable tables
- **Data archival**: Store events with automatic backup rotation and atomic file operations

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

### EventConfig - Central Configuration

The [[Event Detection|EventConfig]] class orchestrates all event detection:

```matlab
cfg = EventConfig();
cfg.MinDuration = 1.5;              % Debounce short violations
cfg.MaxCallsPerEvent = 2;           % Limit callback invocations
cfg.EscalateSeverity = true;        % H -> HH when peak exceeds
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

Each detected event is represented by an [[Event Detection|Event]] object:

```matlab
% Event properties (read-only after creation)
event.StartTime       % datenum of violation start
event.EndTime         % datenum of violation end  
event.Duration        % duration in days
event.SensorName      % sensor identifier
event.ThresholdLabel  % threshold name
event.ThresholdValue  % threshold numeric value
event.Direction       % 'upper' or 'lower'

% Statistical properties (set by detector)
event.PeakValue      % most extreme value during violation
event.NumPoints      % number of data points in violation
event.MinValue       % minimum value during violation
event.MaxValue       % maximum value during violation
event.MeanValue      % mean value during violation
event.RmsValue       % RMS value during violation
event.StdValue       % standard deviation during violation
```

## Live Event Detection

### Data Sources

Data sources provide the interface between your data and the event detection system:

```matlab
% Mock data source for testing
mockDS = MockDataSource('BaseValue', 100, 'NoiseStd', 2, ...
    'ViolationProbability', 0.001, 'ViolationAmplitude', 25);

% File-based data source for live monitoring
fileDS = MatFileDataSource('sensors/temp.mat', 'XVar', 'time', 'YVar', 'temp');

% Map sensors to data sources
dsMap = DataSourceMap();
dsMap.add('temperature', mockDS);
dsMap.add('pressure', fileDS);
```

### Live Pipeline

The [[Event Detection|LiveEventPipeline]] orchestrates continuous monitoring:

```matlab
% Create pipeline
pipeline = LiveEventPipeline(sensors, dsMap, ...
    'EventFile', 'live_events.mat', ...
    'Interval', 15, ...              % 15-second polling
    'MinDuration', 5, ...            % 5-second minimum events
    'EscalateSeverity', true);       % H -> HH escalation

% Configure notifications
notifService = NotificationService('DryRun', true);
pipeline.NotificationService = notifService;

% Start/stop live monitoring
pipeline.start();   % begins timer-driven cycles
pipeline.stop();    % stops timer
```

### Incremental Detection

For live scenarios, use [[Event Detection|IncrementalEventDetector]] to maintain state between updates:

```matlab
detector = IncrementalEventDetector('MinDuration', 2, ...
    'EscalateSeverity', true);

% Process incremental updates
newEvents = detector.process('temp_01', sensor, newX, newY, [], []);

% Check for ongoing events
if detector.hasOpenEvent('temp_01')
    state = detector.getSensorState('temp_01');
    fprintf('Open event since %.2f\n', state.openEventStart);
end
```

## Event Storage and Persistence

### EventStore - Atomic File Operations

The [[Event Detection|EventStore]] provides thread-safe event persistence:

```matlab
% Create event store
store = EventStore('events.mat', 'MaxBackups', 3);

% Configure metadata for EventViewer
store.SensorData = cfg.SensorData;           % for click-to-plot
store.ThresholdColors = cfg.ThresholdColors; % for color consistency

% Append new events (atomic operation)
store.append(newEvents);
store.save();

% Load from file (static method)
[events, metadata, changed] = EventStore.loadFile('events.mat');
```

### Auto-Save Configuration

EventConfig can automatically save events to a file:

```matlab
cfg.EventFile = 'auto_events.mat';  % Enable auto-save
cfg.MaxBackups = 5;                  % Backup rotation

% Events saved automatically after cfg.runDetection()
events = cfg.runDetection();
```

## Event Visualization

### EventViewer - Interactive Timeline

The [[Event Detection|EventViewer]] provides a Gantt timeline and filterable table:

```matlab
% Create viewer with full context
viewer = EventViewer(events, sensorData, thresholdColors);

% Or load from saved file
viewer = EventViewer.fromFile('events.mat');

% Auto-refresh from file
viewer.startAutoRefresh(10);  % refresh every 10 seconds
viewer.stopAutoRefresh();

% Manual refresh
viewer.refreshFromFile();

% Update with new events
viewer.update(newEvents);

% Save the rendered timeline as an image (format inferred from extension)
viewer.exportImage('events.png');
viewer.exportImage('events.jpg', 'jpeg');
```

The EventViewer features:
- **Gantt timeline**: Visual event bars colored by threshold
- **Filterable table**: Filter by sensor, threshold, date range
- **Click interaction**: Click Gantt bars to highlight table rows
- **Auto-refresh**: Polls the source file for live updates
- **Image export**: `exportImage(filepath, format)` saves the rendered timeline figure as PNG or JPEG at 150 DPI (format inferred from the file extension when omitted). Requires the viewer figure to be open — raises `EventViewer:notRendered` otherwise, or `EventViewer:unknownImageFormat` for an unsupported format.

## Notification System

### Notification Rules

Configure rule-based notifications with priority matching:

```matlab
% Default rule (catches all events)
defaultRule = NotificationRule('Recipients', {{'ops@company.com'}}, ...
    'Subject', 'Event: {sensor} - {threshold}', ...
    'IncludeSnapshot', false);

% Sensor-specific rule (higher priority)
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

The [[Event Detection|NotificationService]] manages rule-based notifications:

```matlab
notif = NotificationService('DryRun', true, ... % test mode
    'SnapshotDir', 'snapshots/', ...
    'SmtpServer', 'mail.company.com');

notif.setDefaultRule(defaultRule);
notif.addRule(tempRule);
notif.addRule(criticalRule);

% Notify on event (called by pipeline)
notif.notify(event, sensorData);
```

### Email Templates

Notification templates support variable substitution:

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

Available template variables:
- `{sensor}`, `{threshold}`, `{direction}`, `{peak}`
- `{startTime}`, `{endTime}`, `{duration}`
- `{mean}`, `{std}`, `{min}`, `{max}`, `{rms}`

### Event Snapshots

Generate PNG snapshots showing event context:

```matlab
% Generate detail and context plots
files = generateEventSnapshot(event, sensorData, ...
    'OutputDir', 'snapshots/', ...
    'SnapshotSize', [800, 400], ...
    'Padding', 0.1, ...          % 10% padding around event
    'ContextHours', 2);          % 2 hours before event

% Returns: {detailFile, contextFile}
```

## Severity Escalation

Events can escalate to higher severity levels when peaks exceed multiple thresholds:

```matlab
% Configure escalation
detector = EventDetector('EscalateSeverity', true);

% Sensor with multiple thresholds
sensor.addThresholdRule(struct(), 85, 'Label', 'H Warning');
sensor.addThresholdRule(struct(), 95, 'Label', 'HH Alarm');

% If violation starts at 87 (H Warning) but peaks at 97:
% 1. Initial event: "H Warning" 
% 2. Escalated event: "HH Alarm" (same time span, higher severity)
events = detectEventsFromSensor(sensor, detector);
```

## Utility Functions

### Event Logging

Simple console logging for development:

```matlab
cfg.OnEventStart = eventLogger();

% Logs: [EVENT] Temperature | temp high | UPPER | 123.45 -> 125.67 (dur=0.02) | peak=126.83
```

### Event Summary

Formatted console output for analysis:

```matlab
printEventSummary(events);

% Outputs table with columns:
% Start | End | Duration | Sensor | Threshold | Dir | Peak | #Pts | Mean | Std
```

### Bridging with Sensors

Convert from sensor violations to events:

```matlab
% Uses sensor.ResolvedViolations and sensor.ResolvedThresholds
events = detectEventsFromSensor(sensor);
events = detectEventsFromSensor(sensor, customDetector);
```

## Performance Considerations

- **MinDuration**: Use appropriate debounce times to filter noise
- **MaxCallsPerEvent**: Limit callback overhead in high-frequency scenarios  
- **Backup rotation**: Configure MaxBackups to manage disk usage
- **Incremental detection**: Use IncrementalEventDetector for live scenarios to avoid reprocessing
- **File polling**: Balance refresh intervals with system load
- **Snapshot generation**: PNG creation can be expensive; use sparingly

## Common Patterns

### Multi-Sensor Dashboard with Events

```matlab
% Configure multiple sensors
cfg = EventConfig();
cfg.addSensor(temperatureSensor);
cfg.addSensor(pressureSensor);  
cfg.addSensor(vibrationSensor);
cfg.AutoOpenViewer = true;

% Run detection and view results
events = cfg.runDetection();
```

### Live Monitoring with Notifications

```matlab
% Set up complete live pipeline
pipeline = LiveEventPipeline(sensors, dataSourceMap, ...
    'EventFile', 'monitoring.mat', ...
    'Interval', 30);

% Configure notifications
pipeline.NotificationService = notificationService;

% Start monitoring
pipeline.start();
```

### Event Analysis Workflow

```matlab
% Load saved events
viewer = EventViewer.fromFile('historical_events.mat');

% Analyze programmatically
[events, meta] = EventStore.loadFile('historical_events.mat');
tempEvents = events(strcmp({events.SensorName}, 'Temperature'));
criticalEvents = events(strcmp({events.ThresholdLabel}, 'critical'));

printEventSummary(criticalEvents);
```

## See Also

- [[Sensors]] - Configure thresholds and violations
- [[Live Mode Guide]] - Real-time data streaming patterns
- [[Dashboard Engine Guide]] - Multi-plot coordination
- [[Examples]] - Complete working examples
