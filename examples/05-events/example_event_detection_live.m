% example_event_detection_live  Live event detection with bounded timer + dry-run notifications.
%
%   Pedagogical purpose: demonstrates the Tag-API LIVE pipeline —
%     SensorTag parent -> MonitorTag alarm -> EventStore storage ->
%     LiveEventPipeline (orchestrator) -> NotificationService (dry-run sink) ->
%     DashboardEngine (visualization).
%
%   This is distinct from:
%     - example_sensor_threshold.m (single-sensor static threshold,
%                                   no live data, no events)
%     - example_event_viewer_from_file.m (batch detection +
%                                         persistence + viewer)
%     - example_live_pipeline.m (full notification-rule taxonomy
%                                with manual cycles, no timer)
%
%   Bounded timer: TasksToExecute=5, onCleanup wrapper (DEMO-09).
%   Octave-portable: POSIX timestamps and numeric arrays only (DEMO-06).
%
%   Run:  example_event_detection_live
%   Stop: completes automatically after 5 ticks (~5 seconds).

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

TagRegistry.clear();
EventBinding.clear();

fprintf('\n=== Event Detection Live Demo (Tag-API) ===\n\n');

%% ========================================================================
%  1. SENSOR PARENTS — pressure, temperature, vibration
%  ========================================================================

N0  = 200;
dt  = 1.0;            % 1-second sample interval
t0  = (0:N0-1) * dt;  % POSIX seconds since epoch (numeric, Octave-safe)

sPres = SensorTag('pressure',    'Name', 'Pressure (psi)');
sTemp = SensorTag('temperature', 'Name', 'Temperature (degC)');
sVib  = SensorTag('vibration',   'Name', 'Vibration (Hz)');

sPres.updateData(t0, 80 + 8*sin(t0/10) + 2*randn(1, N0));
sTemp.updateData(t0, 65 + 3*sin(t0/15) + 1.5*randn(1, N0));
sVib.updateData( t0, 30 + 4*sin(t0/8)  + 1*randn(1, N0));

TagRegistry.register('pressure',    sPres);
TagRegistry.register('temperature', sTemp);
TagRegistry.register('vibration',   sVib);

%% ========================================================================
%  2. SHARED EVENT STORE
%  ========================================================================

eventFile = fullfile(tempdir, 'fastsense_phase1016_live.mat');
if exist(eventFile, 'file'); delete(eventFile); end
store = EventStore(eventFile, 'MaxBackups', 3);

%% ========================================================================
%  3. MONITOR TAGS — pressure>100, temperature>80, vibration>50
%  ========================================================================

mPres = MonitorTag('pressure_high',    sPres, @(x, y) y > 100, 'EventStore', store);
mTemp = MonitorTag('temperature_high', sTemp, @(x, y) y > 80,  'EventStore', store);
mVib  = MonitorTag('vibration_high',   sVib,  @(x, y) y > 50,  'EventStore', store);

TagRegistry.register('pressure_high',    mPres);
TagRegistry.register('temperature_high', mTemp);
TagRegistry.register('vibration_high',   mVib);

monitors = containers.Map('KeyType', 'char', 'ValueType', 'any');
monitors('pressure_high')    = mPres;
monitors('temperature_high') = mTemp;
monitors('vibration_high')   = mVib;

%% ========================================================================
%  4. DATA SOURCES — keyed by MONITOR key (not parent key)
%  ========================================================================
%  LiveEventPipeline.processMonitorTag_ iterates MonitorTargets keys and
%  looks up the same key in DataSourceMap, so the map MUST be keyed by
%  monitor key, not parent sensor key.

dsMap = DataSourceMap();
dsMap.add('pressure_high',    MockDataSource('BaseValue', 80, 'NoiseStd', 2, ...
    'ViolationProbability', 0.4, 'ViolationAmplitude', 30, 'ViolationDuration', 5, ...
    'SampleInterval', dt, 'BacklogDays', 0, 'Seed', 42));
dsMap.add('temperature_high', MockDataSource('BaseValue', 65, 'NoiseStd', 1.5, ...
    'ViolationProbability', 0.4, 'ViolationAmplitude', 25, 'ViolationDuration', 4, ...
    'SampleInterval', dt, 'BacklogDays', 0, 'Seed', 99));
dsMap.add('vibration_high',   MockDataSource('BaseValue', 30, 'NoiseStd', 1, ...
    'ViolationProbability', 0.4, 'ViolationAmplitude', 30, 'ViolationDuration', 4, ...
    'SampleInterval', dt, 'BacklogDays', 0, 'Seed', 7));

%% ========================================================================
%  5. LIVE PIPELINE + DRY-RUN NOTIFICATION SERVICE
%  ========================================================================

pipeline = LiveEventPipeline(monitors, dsMap, ...
    'EventFile', eventFile, 'Interval', 1, 'MinDuration', 0, 'MaxBackups', 3);

pipeline.NotificationService = NotificationService('DryRun', true, ...
    'SnapshotDir', fullfile(tempdir, 'fastsense_phase1016_snapshots'));

pipeline.NotificationService.setDefaultRule(NotificationRule( ...
    'Recipients',      {{'ops@example.com'}}, ...
    'Subject',         '[FastSense] {sensor}: {threshold} violation', ...
    'Message',         'Sensor {sensor} violated {threshold} ({direction}) at {startTime}.', ...
    'IncludeSnapshot', false));

%% ========================================================================
%  6. DASHBOARD VISUALIZATION
%  ========================================================================

d = DashboardEngine('Live Event Detection (3 sensors)');
d.addWidget('fastsense', 'Position', [1  1 24 7], 'Tag', sPres);
d.addWidget('fastsense', 'Position', [1  8 24 7], 'Tag', sTemp);
d.addWidget('fastsense', 'Position', [1 15 24 7], 'Tag', sVib);
try
    d.render();
catch err
    fprintf('  (Dashboard render skipped: %s)\n', err.message);
end

%% ========================================================================
%  7. BOUNDED LIVE TIMER — TasksToExecute=5, onCleanup wrapper
%  ========================================================================

fprintf('Starting bounded live demo (5 ticks at 1s spacing)...\n');
liveTimer = timer( ...
    'ExecutionMode',   'fixedSpacing', ...
    'Period',          1.0, ...
    'TasksToExecute',  5, ...
    'TimerFcn',        @(~,~) pipeline.runCycle(), ...
    'StopFcn',         @(~,~) fprintf('Live demo stopped (5 ticks complete).\n'));

cleanup = onCleanup(@() cleanupTimer(liveTimer));   %#ok<NASGU>
start(liveTimer);
wait(liveTimer);   % blocks until TasksToExecute=5 completes

%% ========================================================================
%  8. SUMMARY
%  ========================================================================

evts = store.getEvents();
fprintf('\n=== Demo complete: %d events in store ===\n', numel(evts));

%% ------------------------------------------------------------------------
%  Local function — bounded-timer cleanup helper (DEMO-09)
%  ------------------------------------------------------------------------

function cleanupTimer(t)
    try
        if isvalid(t)
            stop(t);
            delete(t);
        end
    catch
    end
end
