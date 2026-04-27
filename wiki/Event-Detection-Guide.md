<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Event Detection Guide

The Event Detection system in FastSense provides comprehensive threshold-based monitoring with live detection, notification services, and visual event management. It bridges sensor data with real-time event pipelines, storage, and notifications through a flexible tag-based architecture.

## When to Use Event Detection

- **Real-time monitoring**: Detect threshold violations as they occur in live data streams
- **Historical analysis**: Analyze events from recorded sensor data with statistical summaries
- **Alert systems**: Configure rule-based notifications with email and snapshot generation
- **Event visualization**: View events in Gantt timelines and filterable tables
- **Data archival**: Store events with automatic backup rotation and atomic file operations

## Core Workflow

The event detection workflow follows these steps:

1. **Configure tags and thresholds** using the [[Sensors]] library
2. **Set up data sources** to fetch new sensor data (live files, mock data, etc.)
3. **Configure event detection** with minimum duration, callbacks, and escalation
4. **Run detection** to find threshold violations and generate Event objects
5. **Store and visualize** events using EventStore and EventViewer

## Basic Event Detection

### Event Objects

Each detected event is represented by an [[Event Detection|Event]] object:

```matlab
% Create event manually (typically done by EventDetector)
event = Event(startTime, endTime, 'temperature', 'high alarm', 85, 'upper');

% Event properties (read-only after creation)
event.StartTime       % datenum of violation start
event.EndTime         % datenum of violation end  
event.Duration        % duration in days
event.SensorName      % sensor identifier
event.ThresholdLabel  % threshold name
event.ThresholdValue  % threshold numeric value
event.Direction       % 'upper' or 'lower'

% Set statistical properties
event.setStats(87.5, 42, 82.1, 87.5, 84.3, 84.5, 1.8);

% Event statistics (populated by detector)
event.PeakValue      % most extreme value during violation
event.NumPoints      % number of data points in violation
event.MinValue       % minimum value during violation
event.MaxValue       % maximum value during violation
event.MeanValue      % mean value during violation
event.RmsValue       % RMS value during violation
event.StdValue       % standard deviation during violation

% Phase 1012 features
event.IsOpen = false  % true while event is still open (EndTime = NaN)
event.Notes = ''      % free-form user annotation
event.Id = ''         % unique id assigned by EventStore
event.TagKeys = {}    % tag keys bound to this event
event.Severity = 1    % 1=info, 2=warn, 3=alarm
event.Category = ''   % alarm|maintenance|process_change|manual_annotation
```

### EventDetector - Core Detection Engine

The [[Event Detection|EventDetector]] finds threshold violations in tag data:

```matlab
% Create detector with configuration
detector = EventDetector('MinDuration', 2, ...     % 2-day minimum
                        'MaxCallsPerEvent', 1, ...  % limit callbacks
                        'OnEventStart', eventLogger());

% Detect events from a tag and threshold
events = detector.detect(tag, threshold);
```

### EventConfig - Legacy Configuration

Note: EventConfig is largely non-functional as of Phase 1011. The `addSensor()` and `runDetection()` methods rely on deleted sensor pipeline functionality:

```matlab
% EventConfig still supports color management and detector building
cfg = EventConfig();
cfg.MinDuration = 1.5;              % Debounce short violations
cfg.EscalateSeverity = true;        % Enable severity escalation
cfg.setColor('temp warning', [1 0.8 0]);
cfg.setColor('temp critical', [1 0.2 0]);

% Build a configured detector
detector = cfg.buildDetector();

% Auto-save configuration (still functional)
cfg.EventFile = 'my_events.mat';
cfg.MaxBackups = 5;
```

## Live Event Detection

### Data Sources

Data sources provide the interface between your data and the event detection system:

```matlab
% Mock data source for testing
mockDS = MockDataSource('BaseValue', 100, 'NoiseStd', 2, ...
    'ViolationProbability', 0.001, 'ViolationAmplitude', 25, ...
    'Seed', 12345);

% File-based data source for live monitoring
fileDS = MatFileDataSource('sensors/temp.mat', 'XVar', 'time', 'YVar', 'temp');

% Map sensors to data sources
dsMap = DataSourceMap();
dsMap.add('temperature', mockDS);
dsMap.add('pressure', fileDS);

% Check data source mappings
keys = dsMap.keys();
hasTempDS = dsMap.has('temperature');
tempDS = dsMap.get('temperature');
```

### MockDataSource Features

The MockDataSource generates realistic industrial signals:

```matlab
mockDS = MockDataSource( ...
    'BaseValue', 100, ...                    % nominal value
    'NoiseStd', 1, ...                      % gaussian noise
    'DriftRate', 0.1, ...                   % drift per second
    'SampleInterval', 3, ...                % seconds between points
    'BacklogDays', 3, ...                   % history on first fetch
    'ViolationProbability', 0.005, ...      % chance per point
    'ViolationAmplitude', 20, ...           % violation magnitude
    'ViolationDuration', 60, ...            % seconds per episode
    'StateValues', {{'idle', 'running'}}, ...  % discrete states
    'StateChangeProbability', 0.001, ...    % state transition rate
    'PipelineInterval', 15);                % fetch cycle period

% Fetch new data (returns struct with X, Y, stateX, stateY, changed)
result = mockDS.fetchNew();
```

### Live Pipeline

The [[Event Detection|LiveEventPipeline]] orchestrates continuous monitoring using MonitorTag objects:

```matlab
% Create monitor tags (Phase 1007 streaming architecture)
monitorMap = containers.Map();
monitorMap('temperature') = tempMonitorTag;
monitorMap('pressure') = pressureMonitorTag;

% Create pipeline
pipeline = LiveEventPipeline(monitorMap, dsMap, ...
    'EventFile', 'live_events.mat', ...
    'Interval', 15, ...              % 15-second polling
    'MinDuration', 5, ...            % 5-day minimum events
    'EscalateSeverity', true);       % H -> HH escalation

% Configure notifications
notifService = NotificationService('DryRun', true);
pipeline.NotificationService = notifService;

% Start/stop live monitoring
pipeline.start();   % begins timer-driven cycles
pipeline.stop();    % stops timer

% Manual cycle execution
pipeline.runCycle();
```

### Incremental Detection (Legacy)

Note: IncrementalEventDetector is non-functional as of Phase 1011:

```matlab
% IncrementalEventDetector.process() is disabled
detector = IncrementalEventDetector('MinDuration', 2, ...
    'EscalateSeverity', true);

% This will error - use MonitorTag.appendData() instead
% newEvents = detector.process('temp_01', sensor, newX, newY, [], []);

% State checking still works
if detector.hasOpenEvent('temp_01')
    state = detector.getSensorState('temp_01');
    fprintf('Open event since %.2f\n', state.openEventStart);
end
```

## Event Storage and Persistence

### EventStore - Atomic File Operations

The [[Event Detection|EventStore]] provides thread-safe event persistence:

```matlab
% Create event store with backup rotation
store = EventStore('events.mat', 'MaxBackups', 3);

% Configure metadata for EventViewer
store.SensorData = sensorDataStruct;         % for click-to-plot
store.ThresholdColors = thresholdColorsMap;  % for color consistency
store.PipelineConfig = struct('version', 1); % pipeline metadata

% Append new events (atomic operation)
store.append(newEvents);
store.save();

% Close an open event
store.closeEvent('event_123', endTime, finalStats);

% Query events
allEvents = store.getEvents();
tempEvents = store.getEventsForTag('temp_monitor');
numEvents = store.numEvents();

% Load from file (static method)
[events, metadata, changed] = EventStore.loadFile('events.mat');
```

### Event-Tag Binding System

The EventBinding system provides many-to-many relationships between events and tags:

```matlab
% Bind events to tags (typically done automatically)
EventBinding.attach('event_123', 'temp_monitor');

% Query bindings
tagKeys = EventBinding.getTagKeysForEvent('event_123');
events = EventBinding.getEventsForTag('temp_monitor', eventStore);

% Clear all bindings (for testing)
EventBinding.clear();
```

### Event Lifecycle Management

```matlab
% Create and manage open events
event = Event(now, NaN, 'temperature', 'high', 85, 'upper');
event.IsOpen = true;

% Close event with final statistics
finalStats = struct('PeakValue', 87.5, 'NumPoints', 42, ...
    'MinValue', 82.1, 'MaxValue', 87.5, 'MeanValue', 84.3, ...
    'RmsValue', 84.5, 'StdValue', 1.8);
event.close(now, finalStats);

% Escalate to higher severity
event.escalateTo('critical alarm', 95);
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

% Manual refresh from source file
viewer.refreshFromFile();

% Update with new events
viewer.update(newEvents);

% Query viewer data
sensorNames = viewer.getSensorNames();
thresholdLabels = viewer.getThresholdLabels();
```

The EventViewer features:
- **Gantt timeline**: Visual event bars colored by threshold
- **Filterable table**: Filter by sensor, threshold, date range
- **Click interaction**: Click Gantt bars to highlight table rows
- **Auto-refresh**: Polls the source file for live updates
- **Export**: Context menu options for data export
- **Hover detection**: Interactive bar highlighting

## Notification System

### Notification Rules

Configure rule-based notifications with priority matching:

```matlab
% Default rule (catches all events) - priority 1
defaultRule = NotificationRule('Recipients', {{'ops@company.com'}}, ...
    'Subject', 'Event: {sensor} - {threshold}', ...
    'IncludeSnapshot', false);

% Sensor-specific rule - priority 2
tempRule = NotificationRule('SensorKey', 'temperature', ...
    'Recipients', {{'thermal@company.com'}}, ...
    'Subject', 'Temperature Event: {threshold}', ...
    'IncludeSnapshot', true, ...
    'ContextHours', 2, ...
    'SnapshotPadding', 0.1, ...
    'SnapshotSize', [800, 400]);

% Exact match rule - priority 3 (highest)
criticalRule = NotificationRule('SensorKey', 'temperature', ...
    'ThresholdLabel', 'critical', ...
    'Recipients', {{'safety@company.com', 'manager@company.com'}}, ...
    'Subject', 'CRITICAL: {sensor} {threshold}!');

% Check rule matching
score = tempRule.matches(event);  % Returns 0-3 based on specificity
```

### NotificationService

The [[Event Detection|NotificationService]] manages rule-based notifications:

```matlab
notif = NotificationService('DryRun', true, ... % test mode
    'SnapshotDir', 'snapshots/', ...
    'SnapshotRetention', 7, ...      % days
    'SmtpServer', 'mail.company.com', ...
    'SmtpPort', 587, ...
    'FromAddress', 'alerts@company.com');

notif.setDefaultRule(defaultRule);
notif.addRule(tempRule);
notif.addRule(criticalRule);

% Find best matching rule for an event
bestRule = notif.findBestRule(event);

% Send notification (called by pipeline)
notif.notify(event, sensorData);

% Cleanup old snapshots
notif.cleanupSnapshots();

% Check service stats
fprintf('Sent %d notifications\n', notif.NotificationCount);
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

% Template variable expansion
subject = rule.fillTemplate(rule.Subject, event);
message = rule.fillTemplate(rule.Message, event);
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
fprintf('Generated: %s\n', files{1});  % detail plot
fprintf('Generated: %s\n', files{2});  % context plot
```

## Severity Escalation

Events can escalate to higher severity levels when peaks exceed multiple thresholds:

```matlab
% Configure escalation in detector
detector = EventDetector('EscalateSeverity', true);

% Events escalate automatically based on peak values
% If violation starts at 87 (warning) but peaks at 97 (alarm):
% 1. Initial event: "warning" threshold
% 2. Escalated event: "alarm" threshold (same time span, higher severity)

% Manual escalation
event.escalateTo('critical alarm', 95);
```

## Utility Functions

### Event Logging

Simple console logging for development:

```matlab
% Create event logger callback
logger = eventLogger();

% Use in detector
detector = EventDetector('OnEventStart', eventLogger());

% Logs format: [EVENT] Temperature | temp high | UPPER | 123.45 -> 125.67 (dur=0.02) | peak=126.83
```

### Event Summary

Formatted console output for analysis:

```matlab
printEventSummary(events);

% Example output:
% Start        End          Duration   Sensor           Threshold          Dir    Peak   #Pts   Mean       Std       
% ------------------------------------------------------------------------------------------------------------------------
% 738156.50    738156.51    0.01       temperature      high warning       upper  87.50  42     84.30      1.80      
% 738157.25    738157.27    0.02       pressure         critical alarm     upper  105.20 18     102.45     2.10      
% 
% 2 event(s) total.
```

### DataSource Utilities

```matlab
% Empty result structure for custom data sources
emptyResult = DataSource.emptyResult();
% Returns: struct('X', [], 'Y', [], 'stateX', [], 'stateY', [], 'changed', false)
```

## Performance Considerations

- **MinDuration**: Use appropriate debounce times to filter noise
- **MaxCallsPerEvent**: Limit callback overhead in high-frequency scenarios  
- **Backup rotation**: Configure MaxBackups to manage disk usage
- **MonitorTag streaming**: Use MonitorTag.appendData() for efficient incremental updates
- **File polling**: Balance refresh intervals with system load
- **Snapshot generation**: PNG creation can be expensive; use sparingly
- **Event binding**: EventBinding uses O(1) lookup for tag-event relationships

## Common Patterns

### Live Monitoring with Notifications

```matlab
% Set up complete live pipeline with MonitorTags
monitorMap = containers.Map();
monitorMap('temperature') = tempMonitor;
monitorMap('pressure') = pressureMonitor;

% Create pipeline
pipeline = LiveEventPipeline(monitorMap, dataSourceMap, ...
    'EventFile', 'monitoring.mat', ...
    'Interval', 30, ...
    'MinDuration', 5/86400, ...      % 5 seconds in days
    'EscalateSeverity', true);

% Configure notifications
notifService = NotificationService('DryRun', false);
notifService.setDefaultRule(defaultRule);
pipeline.NotificationService = notifService;

% Start monitoring
pipeline.start();
```

### Event Analysis Workflow

```matlab
% Load and analyze saved events
[events, metadata] = EventStore.loadFile('historical_events.mat');

% Filter events
tempEvents = events(strcmp({events.SensorName}, 'temperature'));
criticalEvents = events(strcmp({events.ThresholdLabel}, 'critical'));

% Statistical analysis
durations = [events.Duration] * 86400;  % convert to seconds
peakValues = [events.PeakValue];
meanDuration = mean(durations);

% View events interactively
viewer = EventViewer.fromFile('historical_events.mat');

% Print summary
printEventSummary(criticalEvents);
```

### Mock Data Testing

```matlab
% Create realistic test data
mockDS = MockDataSource('BaseValue', 100, ...
    'ViolationProbability', 0.01, ...       % frequent violations
    'ViolationAmplitude', 25, ...
    'BacklogDays', 1);                      % 1 day of history

% Simulate multiple fetch cycles
for i = 1:10
    result = mockDS.fetchNew();
    if result.changed
        fprintf('Cycle %d: %d new points\n', i, length(result.X));
    end
    pause(0.1);
end
```

## Migration Notes (Phase 1011)

Several components have been deprecated or modified:

- **EventConfig.addSensor()** and **EventConfig.runDetection()**: Non-functional due to deleted sensor pipeline
- **IncrementalEventDetector.process()**: Disabled, use MonitorTag.appendData() instead
- **Event binding**: Now uses EventBinding singleton for many-to-many relationships
- **Tag-based architecture**: Event detection now works with Tag/MonitorTag objects instead of Sensor objects

For new development, use the LiveEventPipeline with MonitorTag objects for optimal performance and functionality.

## See Also

- [[Sensors]] - Tag and threshold configuration
- [[Live Mode Guide]] - Real-time data streaming patterns
- [[Dashboard Engine Guide]] - Multi-plot coordination
- [[Examples]] - Complete working examples
