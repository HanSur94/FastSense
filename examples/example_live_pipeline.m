% example_live_pipeline  Live event detection pipeline demo.
%
%   Demonstrates the full pipeline:
%     1. MockDataSource generates multi-day industrial sensor data
%     2. LiveEventPipeline runs 15s detection cycles
%     3. Events are saved to a shared .mat file
%     4. EventViewer polls the file and auto-refreshes
%     5. Notifications are logged (dry-run mode)
%
%   To stop: pipeline.stop()

setup();

%% 1. Define sensors with thresholds
tempSensor = Sensor('temperature', 'Name', 'Chamber Temperature');
tempSensor.addThresholdRule(struct(), 120, 'Direction', 'upper', 'Label', 'H Warning');
tempSensor.addThresholdRule(struct(), 150, 'Direction', 'upper', 'Label', 'HH Alarm');
tempSensor.addThresholdRule(struct(), 40,  'Direction', 'lower', 'Label', 'L Warning');
tempSensor.addThresholdRule(struct(), 20,  'Direction', 'lower', 'Label', 'LL Alarm');

presSensor = Sensor('pressure', 'Name', 'Chamber Pressure');
presSensor.addThresholdRule(struct(), 5.0, 'Direction', 'upper', 'Label', 'H Warning');
presSensor.addThresholdRule(struct(), 6.5, 'Direction', 'upper', 'Label', 'HH Alarm');
presSensor.addThresholdRule(struct(), 1.0, 'Direction', 'lower', 'Label', 'LL Alarm');

vibSensor = Sensor('vibration', 'Name', 'Motor Vibration');
vibSensor.addThresholdRule(struct(), 8.0, 'Direction', 'upper', 'Label', 'H Warning');
vibSensor.addThresholdRule(struct(), 12.0, 'Direction', 'upper', 'Label', 'HH Alarm');

sensors = containers.Map();
sensors('temperature') = tempSensor;
sensors('pressure')    = presSensor;
sensors('vibration')   = vibSensor;

%% 2. Create mock data sources
dsMap = DataSourceMap();
dsMap.add('temperature', MockDataSource( ...
    'BaseValue', 85, 'NoiseStd', 3, 'DriftRate', 0.0001, ...
    'ViolationProbability', 0.003, 'ViolationAmplitude', 50, ...
    'ViolationDuration', 120, 'BacklogDays', 2, ...
    'SampleInterval', 3, 'Seed', 42));

dsMap.add('pressure', MockDataSource( ...
    'BaseValue', 3.2, 'NoiseStd', 0.2, 'DriftRate', 0, ...
    'ViolationProbability', 0.002, 'ViolationAmplitude', 4, ...
    'ViolationDuration', 90, 'BacklogDays', 2, ...
    'SampleInterval', 3, 'Seed', 99));

dsMap.add('vibration', MockDataSource( ...
    'BaseValue', 4.5, 'NoiseStd', 0.8, 'DriftRate', 0, ...
    'ViolationProbability', 0.004, 'ViolationAmplitude', 6, ...
    'ViolationDuration', 60, 'BacklogDays', 2, ...
    'SampleInterval', 3, 'Seed', 7));

%% 3. Configure event store
storeFile = fullfile(tempdir, 'fastplot_live_events.mat');
fprintf('Event store: %s\n', storeFile);

%% 4. Create pipeline
pipeline = LiveEventPipeline(sensors, dsMap, ...
    'EventFile', storeFile, ...
    'Interval', 15, ...
    'MinDuration', 0);

%% 5. Configure notifications (dry-run mode — logs to console)
notif = NotificationService('DryRun', true);
notif.setDefaultRule(NotificationRule( ...
    'Recipients', {{'ops-team@company.com'}}, ...
    'Subject', '[FastPlot] {sensor}: {threshold} violation', ...
    'Message', 'Sensor {sensor} violated {threshold} ({direction}) from {startTime} to {endTime}. Peak: {peak}', ...
    'IncludeSnapshot', false));

% Temperature-specific critical alert
notif.addRule(NotificationRule( ...
    'SensorKey', 'temperature', 'ThresholdLabel', 'HH Alarm', ...
    'Recipients', {{'safety@company.com', 'manager@company.com'}}, ...
    'Subject', 'CRITICAL: Temperature HH Alarm!', ...
    'Message', 'Temperature exceeded HH limit. Peak: {peak}. Immediate action required.'));

pipeline.NotificationService = notif;

%% 6. Start the pipeline
fprintf('\nStarting live event detection pipeline...\n');
fprintf('Press Ctrl+C or run pipeline.stop() to stop.\n\n');
pipeline.start();

%% 7. Open EventViewer (client side)
% Wait for first cycle to create the store file
pause(2);
pipeline.runCycle();  % run first cycle immediately

if isfile(storeFile)
    viewer = EventViewer.fromFile(storeFile);
    viewer.startAutoRefresh(15);
    fprintf('EventViewer opened and auto-refreshing every 15s.\n');
end
