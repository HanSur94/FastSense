% example_live_pipeline  Live event detection pipeline demo.
%
%   Demonstrates every feature of the live event pipeline:
%
%     Data Sources:
%       - MockDataSource with violations, drift, noise, and state channels
%       - MatFileDataSource reading from a continuously-updated .mat file
%       - DataSourceMap mapping sensor keys to swappable data sources
%
%     Detection:
%       - IncrementalEventDetector with open-event carry-over
%       - Severity escalation (H -> HH when peak exceeds higher threshold)
%       - Multi-sensor parallel detection
%
%     Storage:
%       - EventStore with atomic write and backup rotation
%       - printEventSummary for console inspection
%
%     Notifications:
%       - NotificationRule with priority-based matching (default/sensor/exact)
%       - Template filling ({sensor}, {threshold}, {peak}, {duration}, ...)
%       - generateEventSnapshot producing detail + context PNGs
%       - NotificationService in dry-run mode (logs to console)
%
%     Visualization:
%       - EventViewer with Gantt timeline and filterable table
%       - Auto-refresh from the shared event store file
%
%   The example runs 3 manual cycles (no timer needed), prints a summary,
%   generates snapshot PNGs, then opens the EventViewer.
%
%   To run interactively with the timer afterwards:
%     pipeline.start()    % begins 15s timer-driven cycles
%     pipeline.stop()     % stops the timer

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% ========================================================================
%  1. SENSORS WITH THRESHOLDS (upper + lower, multi-level)
%  ========================================================================

% Threshold colors and styles
warnColor  = [1 0.75 0];   % yellow for warnings (inner)
alarmColor = [1 0 0];      % red for alarms (outer)
warnStyle  = '--';          % dashed for warnings
alarmStyle = '-';           % solid for alarms

% --- Temperature: state-dependent thresholds (truly dynamic) ---
tempSensor = Sensor('temperature', 'Name', 'Chamber Temperature');

% Attach state channel so thresholds adapt to machine mode
tempStateCh = StateChannel('mode');
tempSensor.addStateChannel(tempStateCh);

% Idle mode thresholds (default operating)
tempSensor.addThresholdRule(struct('mode', 'idle'), 120, 'Direction', 'upper', 'Label', 'H Warning',  'Color', warnColor,  'LineStyle', warnStyle);
tempSensor.addThresholdRule(struct('mode', 'idle'), 150, 'Direction', 'upper', 'Label', 'HH Alarm',   'Color', alarmColor, 'LineStyle', alarmStyle);
tempSensor.addThresholdRule(struct('mode', 'idle'), 50,  'Direction', 'lower', 'Label', 'L Warning',  'Color', warnColor,  'LineStyle', warnStyle);
tempSensor.addThresholdRule(struct('mode', 'idle'), 30,  'Direction', 'lower', 'Label', 'LL Alarm',   'Color', alarmColor, 'LineStyle', alarmStyle);

% Heating mode: higher upper limits (more tolerant of heat)
tempSensor.addThresholdRule(struct('mode', 'heating'), 140, 'Direction', 'upper', 'Label', 'H Warning',  'Color', warnColor,  'LineStyle', warnStyle);
tempSensor.addThresholdRule(struct('mode', 'heating'), 170, 'Direction', 'upper', 'Label', 'HH Alarm',   'Color', alarmColor, 'LineStyle', alarmStyle);
tempSensor.addThresholdRule(struct('mode', 'heating'), 40,  'Direction', 'lower', 'Label', 'L Warning',  'Color', warnColor,  'LineStyle', warnStyle);
tempSensor.addThresholdRule(struct('mode', 'heating'), 20,  'Direction', 'lower', 'Label', 'LL Alarm',   'Color', alarmColor, 'LineStyle', alarmStyle);

% Cooling mode: lower upper limits (tighter when cooling)
tempSensor.addThresholdRule(struct('mode', 'cooling'), 100, 'Direction', 'upper', 'Label', 'H Warning',  'Color', warnColor,  'LineStyle', warnStyle);
tempSensor.addThresholdRule(struct('mode', 'cooling'), 130, 'Direction', 'upper', 'Label', 'HH Alarm',   'Color', alarmColor, 'LineStyle', alarmStyle);
tempSensor.addThresholdRule(struct('mode', 'cooling'), 60,  'Direction', 'lower', 'Label', 'L Warning',  'Color', warnColor,  'LineStyle', warnStyle);
tempSensor.addThresholdRule(struct('mode', 'cooling'), 40,  'Direction', 'lower', 'Label', 'LL Alarm',   'Color', alarmColor, 'LineStyle', alarmStyle);

% --- Pressure: unconditional thresholds with warning/alarm colors ---
presSensor = Sensor('pressure', 'Name', 'Chamber Pressure');
presSensor.addThresholdRule(struct(), 5.0, 'Direction', 'upper', 'Label', 'H Warning',  'Color', warnColor,  'LineStyle', warnStyle);
presSensor.addThresholdRule(struct(), 6.5, 'Direction', 'upper', 'Label', 'HH Alarm',   'Color', alarmColor, 'LineStyle', alarmStyle);
presSensor.addThresholdRule(struct(), 1.5, 'Direction', 'lower', 'Label', 'L Warning',  'Color', warnColor,  'LineStyle', warnStyle);
presSensor.addThresholdRule(struct(), 0.8, 'Direction', 'lower', 'Label', 'LL Alarm',   'Color', alarmColor, 'LineStyle', alarmStyle);

% --- Vibration: unconditional thresholds with warning/alarm colors ---
vibSensor = Sensor('vibration', 'Name', 'Motor Vibration');
vibSensor.addThresholdRule(struct(), 8.0,  'Direction', 'upper', 'Label', 'H Warning',  'Color', warnColor,  'LineStyle', warnStyle);
vibSensor.addThresholdRule(struct(), 12.0, 'Direction', 'upper', 'Label', 'HH Alarm',   'Color', alarmColor, 'LineStyle', alarmStyle);
vibSensor.addThresholdRule(struct(), 2.0,  'Direction', 'lower', 'Label', 'L Warning',  'Color', warnColor,  'LineStyle', warnStyle);
vibSensor.addThresholdRule(struct(), 1.0,  'Direction', 'lower', 'Label', 'LL Alarm',   'Color', alarmColor, 'LineStyle', alarmStyle);

sensors = containers.Map();
sensors('temperature') = tempSensor;
sensors('pressure')    = presSensor;
sensors('vibration')   = vibSensor;

%% ========================================================================
%  2. DATA SOURCES — MockDataSource with state channels and drift
%  ========================================================================

dsMap = DataSourceMap();

% Temperature: base=85, normal range ~79-91
%   Dynamic thresholds shift with mode: idle=120/150, heating=140/170, cooling=100/130
%   Violations amplitude 38: in idle barely exceeds H(120), in cooling exceeds H(100) easily.
dsMap.add('temperature', MockDataSource( ...
    'BaseValue', 85, 'NoiseStd', 2, ...
    'DriftRate', 0.00002, ...
    'ViolationProbability', 0.0001, ...         % ~3 violations per day
    'ViolationAmplitude', 38, ...               % dynamic: exceeds H in idle/cooling, not in heating
    'ViolationDuration', 90, ...
    'BacklogDays', 2, ...
    'SampleInterval', 3, ...
    'StateValues', {{'idle', 'heating', 'cooling'}}, ...
    'StateChangeProbability', 0.002, ...
    'Seed', 42));

% Pressure: base=3.2, normal range ~2.9-3.5, thresholds at 1.5/0.8 (low) and 5.0/6.5 (high)
%   Gap to nearest threshold: 1.7 units. Violations amplitude 2.0 barely exceeds H/L Warning.
dsMap.add('pressure', MockDataSource( ...
    'BaseValue', 3.2, 'NoiseStd', 0.1, ...
    'ViolationProbability', 0.0001, ...         % ~3 violations per day
    'ViolationAmplitude', 2.0, ...              % just past H Warning (5.0) or L Warning (1.5)
    'ViolationDuration', 60, ...
    'BacklogDays', 2, ...
    'SampleInterval', 3, ...
    'Seed', 99));

% Vibration: base=4.5, normal range ~3.9-5.1, thresholds at 2.0/1.0 (low) and 8.0/12.0 (high)
%   Gap to nearest threshold: 2.5 units. Violations amplitude 4.0 exceeds H/L Warning.
dsMap.add('vibration', MockDataSource( ...
    'BaseValue', 4.5, 'NoiseStd', 0.2, ...
    'ViolationProbability', 0.00015, ...        % ~4 violations per day
    'ViolationAmplitude', 4.0, ...              % past H Warning (8.0) or near L Warning (2.0)
    'ViolationDuration', 45, ...
    'BacklogDays', 2, ...
    'SampleInterval', 3, ...
    'Seed', 7));

fprintf('DataSourceMap: %d sources configured\n', numel(dsMap.keys()));

%% ========================================================================
%  3. EVENT STORE — atomic write with backup rotation
%  ========================================================================

storeFile = fullfile(tempdir, 'fastsense_live_events.mat');
fprintf('Event store: %s\n', storeFile);

%% ========================================================================
%  4. PIPELINE — orchestrates fetch -> detect -> store -> notify
%  ========================================================================

pipeline = LiveEventPipeline(sensors, dsMap, ...
    'EventFile', storeFile, ...
    'Interval', 15, ...
    'MinDuration', 0, ...
    'EscalateSeverity', true, ...   % H -> HH when peak exceeds HH threshold
    'MaxBackups', 3);               % keep 3 backup copies of event store

%% ========================================================================
%  5. NOTIFICATIONS — rule-based with priority matching and snapshots
%  ========================================================================

snapshotDir = fullfile(tempdir, 'fastsense_snapshots');
fprintf('Snapshot directory: %s\n', snapshotDir);

notif = NotificationService('DryRun', true, 'SnapshotDir', snapshotDir);

% Default rule: catches all events not matched by specific rules (score=1)
notif.setDefaultRule(NotificationRule( ...
    'Recipients', {{'ops-team@company.com'}}, ...
    'Subject', '[FastSense] {sensor}: {threshold} violation', ...
    'Message', ['Sensor {sensor} violated {threshold} ({direction}) ' ...
               'from {startTime} to {endTime}.\n' ...
               'Peak: {peak}, Mean: {mean}, Std: {std}, Duration: {duration}'], ...
    'IncludeSnapshot', false));

% Sensor-specific rule: any temperature event (score=2)
notif.addRule(NotificationRule( ...
    'SensorKey', 'temperature', ...
    'Recipients', {{'thermal-team@company.com'}}, ...
    'Subject', '[THERMAL] {sensor}: {threshold}', ...
    'Message', 'Temperature {direction} violation. Peak: {peak}. Duration: {duration}.', ...
    'IncludeSnapshot', true, ...      % generate detail + context PNGs
    'ContextHours', 4, ...            % 4h of context in the context plot
    'SnapshotSize', [1000, 500]));    % higher resolution snapshots

% Exact match rule: temperature + HH Alarm only (score=3, highest priority)
notif.addRule(NotificationRule( ...
    'SensorKey', 'temperature', ...
    'ThresholdLabel', 'HH Alarm', ...
    'Recipients', {{'safety@company.com', 'manager@company.com'}}, ...
    'Subject', 'CRITICAL: Temperature HH Alarm!', ...
    'Message', ['Temperature exceeded HH limit at {startTime}. ' ...
               'Peak: {peak}. Immediate action required.'], ...
    'IncludeSnapshot', true));

pipeline.NotificationService = notif;

%% ========================================================================
%  6. RUN DETECTION CYCLES (manual — no timer needed for demo)
%  ========================================================================

fprintf('\n--- Running 3 detection cycles ---\n\n');

for cycle = 1:3
    fprintf('=== Cycle %d ===\n', cycle);
    pipeline.runCycle();
    fprintf('\n');
end

%% ========================================================================
%  7. INSPECT RESULTS — printEventSummary + event store stats
%  ========================================================================

fprintf('--- Event Summary ---\n\n');

% Load events from the atomic store file
[events, meta] = EventStore.loadFile(storeFile);
fprintf('Total events in store: %d\n', numel(events));
fprintf('Store last updated: %s\n\n', datestr(meta.lastUpdated));

% Print formatted table
printEventSummary(events);

% Show backup files
[fdir, fname] = fileparts(storeFile);
backups = dir(fullfile(fdir, [fname '_backup_*.mat']));
fprintf('\nBackup files: %d\n', numel(backups));
for i = 1:numel(backups)
    fprintf('  %s\n', backups(i).name);
end

%% ========================================================================
%  8. SNAPSHOT FILES — list generated PNGs
%  ========================================================================

if isfolder(snapshotDir)
    pngs = dir(fullfile(snapshotDir, '*.png'));
    fprintf('\nSnapshot PNGs generated: %d\n', numel(pngs));
    for i = 1:min(numel(pngs), 10)
        fprintf('  %s (%.1f KB)\n', pngs(i).name, pngs(i).bytes / 1024);
    end
    if numel(pngs) > 10
        fprintf('  ... and %d more\n', numel(pngs) - 10);
    end
end

%% ========================================================================
%  9. EVENT VIEWER — Gantt timeline with filterable table
%  ========================================================================

fprintf('\nOpening EventViewer...\n');
viewer = EventViewer.fromFile(storeFile);

fprintf('\nDone. The EventViewer shows a Gantt timeline and filterable table.\n');
fprintf('Use the sensor/threshold dropdowns to filter events.\n');
fprintf('Click a Gantt bar to highlight the corresponding table row.\n');

%% ========================================================================
%  OPTIONAL: Start live timer-driven pipeline
%  ========================================================================

% Uncomment to run the pipeline with a 15-second timer:
%
  pipeline.start();           % starts 15s timer
  viewer.startAutoRefresh(15); % viewer polls store every 15s

% To stop:
  % pipeline.stop();
