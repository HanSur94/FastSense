% example_live_pipeline  Full notification-rule taxonomy + manual-cycle live pipeline.
%
%   Pedagogical purpose: demonstrates the FULL feature surface of the
%   live pipeline — manual cycles (no timer), 3 priority-tiered
%   NotificationRules (default / sensor-specific / exact-match),
%   EventStore atomic write + backup rotation, and EventViewer
%   auto-refresh.
%
%   This is distinct from:
%     - example_event_detection_live.m (bounded timer, 3-sensor demo)
%     - example_event_viewer_from_file.m (batch detect -> save -> view)
%     - example_sensor_threshold.m (single sensor, no events)
%
%   Octave-portable: numeric POSIX timestamps and arrays only (DEMO-06).
%   No module-level state; no unbounded timers (DEMO-09).
%
%   The example runs 3 manual cycles, prints a summary, generates
%   snapshot PNGs, then opens the EventViewer.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

TagRegistry.clear();
EventBinding.clear();

fprintf('\n=== Live Pipeline Demo (manual cycles, full notification taxonomy) ===\n\n');

%% ========================================================================
%  1. SENSOR PARENTS — temperature, pressure, vibration
%  ========================================================================

tempSensor = SensorTag('temperature', 'Name', 'Chamber Temperature');
presSensor = SensorTag('pressure',    'Name', 'Chamber Pressure');
vibSensor  = SensorTag('vibration',   'Name', 'Motor Vibration');

%% ========================================================================
%  2. EVENT STORE — atomic write with backup rotation
%  ========================================================================

storeFile = fullfile(tempdir, 'fastsense_phase1016_pipeline.mat');
if exist(storeFile, 'file'); delete(storeFile); end
eventStore = EventStore(storeFile, 'MaxBackups', 3);
fprintf('Event store: %s\n', storeFile);

%% ========================================================================
%  3. MONITOR TAGS — one per sensor + severity (H / HH)
%  ========================================================================
%  Each MonitorTag is a derived 0/1 binary signal that fires events
%  on rising edges into the bound EventStore.

mTempH  = MonitorTag('temp_H',   tempSensor, @(x, y) y > 120, 'EventStore', eventStore);
mTempHH = MonitorTag('temp_HH',  tempSensor, @(x, y) y > 150, 'EventStore', eventStore);
mPresH  = MonitorTag('pres_H',   presSensor, @(x, y) y > 5.0, 'EventStore', eventStore);
mPresHH = MonitorTag('pres_HH',  presSensor, @(x, y) y > 6.5, 'EventStore', eventStore);
mVibH   = MonitorTag('vib_H',    vibSensor,  @(x, y) y > 8.0, 'EventStore', eventStore);
mVibHH  = MonitorTag('vib_HH',   vibSensor,  @(x, y) y > 12.0,'EventStore', eventStore);

TagRegistry.register('temperature', tempSensor);
TagRegistry.register('pressure',    presSensor);
TagRegistry.register('vibration',   vibSensor);
TagRegistry.register('temp_H',  mTempH);
TagRegistry.register('temp_HH', mTempHH);
TagRegistry.register('pres_H',  mPresH);
TagRegistry.register('pres_HH', mPresHH);
TagRegistry.register('vib_H',   mVibH);
TagRegistry.register('vib_HH',  mVibHH);

monitors = containers.Map('KeyType', 'char', 'ValueType', 'any');
monitors('temp_H')  = mTempH;
monitors('temp_HH') = mTempHH;
monitors('pres_H')  = mPresH;
monitors('pres_HH') = mPresHH;
monitors('vib_H')   = mVibH;
monitors('vib_HH')  = mVibHH;

%% ========================================================================
%  4. DATA SOURCES — keyed by MONITOR key (not parent key)
%  ========================================================================
%  LiveEventPipeline.processMonitorTag_ iterates MonitorTargets keys and
%  looks each up in DataSourceMap. Sharing one MockDataSource handle
%  across two monitors of the same parent is safe — fetchNew advances
%  the source's internal pointer; both monitors observe the same tail
%  samples on each cycle.

tempDS = MockDataSource('BaseValue', 85, 'NoiseStd', 2, 'DriftRate', 0.00002, ...
    'ViolationProbability', 0.0001, 'ViolationAmplitude', 38, 'ViolationDuration', 90, ...
    'BacklogDays', 2, 'SampleInterval', 3, ...
    'StateValues', {{'idle', 'heating', 'cooling'}}, ...
    'StateChangeProbability', 0.002, 'Seed', 42);
presDS = MockDataSource('BaseValue', 3.2, 'NoiseStd', 0.1, ...
    'ViolationProbability', 0.0001, 'ViolationAmplitude', 2.0, 'ViolationDuration', 60, ...
    'BacklogDays', 2, 'SampleInterval', 3, 'Seed', 99);
vibDS  = MockDataSource('BaseValue', 4.5, 'NoiseStd', 0.2, ...
    'ViolationProbability', 0.00015, 'ViolationAmplitude', 4.0, 'ViolationDuration', 45, ...
    'BacklogDays', 2, 'SampleInterval', 3, 'Seed', 7);

dsMap = DataSourceMap();
dsMap.add('temp_H',  tempDS);   dsMap.add('temp_HH', tempDS);
dsMap.add('pres_H',  presDS);   dsMap.add('pres_HH', presDS);
dsMap.add('vib_H',   vibDS);    dsMap.add('vib_HH',  vibDS);

fprintf('DataSourceMap: %d sources configured\n', numel(dsMap.keys()));

%% ========================================================================
%  5. PIPELINE — orchestrates fetch -> detect -> store -> notify
%  ========================================================================

pipeline = LiveEventPipeline(monitors, dsMap, ...
    'EventFile', storeFile, ...
    'Interval', 15, ...
    'MinDuration', 0, ...
    'EscalateSeverity', true, ...
    'MaxBackups', 3);

% Ensure pipeline shares the SAME EventStore the MonitorTags write into
% (LiveEventPipeline constructs its own from EventFile; replace with ours
% so harvested deltas line up with monitor writes).
pipeline.EventStore = eventStore;

%% ========================================================================
%  6. NOTIFICATIONS — rule-based with priority matching and snapshots
%  ========================================================================

snapshotDir = fullfile(tempdir, 'fastsense_phase1016_snapshots');
fprintf('Snapshot directory: %s\n', snapshotDir);

notif = NotificationService('DryRun', true, 'SnapshotDir', snapshotDir);

% Default rule: catches all events not matched by specific rules (score=1)
notif.setDefaultRule(NotificationRule( ...
    'Recipients', {{'ops-team@company.com'}}, ...
    'Subject', '[FastSense] {sensor}: {threshold} violation', ...
    'Message', ['Sensor {sensor} violated {threshold} ({direction}) ' ...
               'from {startTime} to {endTime}.\n' ...
               'Peak: {peak}, Mean: {mean}, Std: {std}'], ...
    'IncludeSnapshot', false));

% Sensor-specific rule: any temperature event (score=2)
notif.addRule(NotificationRule( ...
    'SensorKey', 'temperature', ...
    'Recipients', {{'thermal-team@company.com'}}, ...
    'Subject', '[THERMAL] {sensor}: {threshold}', ...
    'Message', 'Temperature {direction} violation. Peak: {peak} at {startTime}.', ...
    'IncludeSnapshot', true, ...
    'ContextHours', 4, ...
    'SnapshotSize', [1000, 500]));

% Exact match rule: temperature + HH only (score=3, highest priority)
notif.addRule(NotificationRule( ...
    'SensorKey', 'temperature', ...
    'ThresholdLabel', 'temp_HH', ...
    'Recipients', {{'safety@company.com', 'manager@company.com'}}, ...
    'Subject', 'CRITICAL: Temperature HH exceeded!', ...
    'Message', ['Temperature exceeded HH limit at {startTime}. ' ...
               'Peak: {peak}. Immediate action required.'], ...
    'IncludeSnapshot', true));

pipeline.NotificationService = notif;

%% ========================================================================
%  7. RUN DETECTION CYCLES (manual — no timer, DEMO-09)
%  ========================================================================

fprintf('\n--- Running 3 detection cycles ---\n\n');

for cycle = 1:3
    fprintf('=== Cycle %d ===\n', cycle);
    pipeline.runCycle();
    fprintf('\n');
end

%% ========================================================================
%  8. INSPECT RESULTS — printEventSummary + event store stats
%  ========================================================================

fprintf('--- Event Summary ---\n\n');

[events, meta] = EventStore.loadFile(storeFile);
fprintf('Total events in store: %d\n', numel(events));
fprintf('Store last updated: %s\n\n', datestr(meta.lastUpdated));

if ~isempty(events)
    printEventSummary(events);
end

% Show backup files
[fdir, fname] = fileparts(storeFile);
backups = dir(fullfile(fdir, [fname '_backup_*.mat']));
fprintf('\nBackup files: %d\n', numel(backups));
for i = 1:numel(backups)
    fprintf('  %s\n', backups(i).name);
end

%% ========================================================================
%  9. SNAPSHOT FILES — list generated PNGs
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
%  10. EVENT VIEWER — Gantt timeline with filterable list
%  ========================================================================

fprintf('\nOpening EventViewer...\n');
try
    viewer = EventViewer.fromFile(storeFile);   %#ok<NASGU>
catch err
    fprintf('  (EventViewer skipped: %s)\n', err.message);
end

% NOTE: This demo runs MANUAL cycles only (DEMO-09 — no unbounded timers).
%       For a bounded timer-driven demo see example_event_detection_live.m.
fprintf('\n=== Demo complete: 3 manual cycles run, EventViewer open ===\n');
