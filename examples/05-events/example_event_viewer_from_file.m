% example_event_viewer_from_file  Batch event detection -> EventStore.save -> EventViewer.fromFile.
%
%   Pedagogical purpose: demonstrates the PERSISTENCE narrative —
%     batch-build (synthetic data with known violations) ->
%     MonitorTag computes events ->
%     EventStore.save writes to .mat file ->
%     EventViewer.fromFile reopens it ->
%     click-to-plot detail flow on the Gantt timeline.
%
%   This is distinct from:
%     - example_event_detection_live.m (live timer-driven detection)
%     - example_live_pipeline.m (notification rules, manual cycles)
%     - example_sensor_threshold.m (single sensor, no events)
%
%   No live timer, no script-scope state retained between runs; uses
%   POSIX seconds + numeric arrays only (DEMO-03, DEMO-06, DEMO-09).
%
%   Run:  example_event_viewer_from_file
%   Stop: close the EventViewer figure.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

TagRegistry.clear();
EventBinding.clear();

fprintf('\n=== Event Viewer From File Demo (Tag-API) ===\n\n');

%% ========================================================================
%  1. SYNTHETIC DATA WITH PLANTED VIOLATIONS (POSIX seconds)
%  ========================================================================

N  = 1000;
dt = 1.0;
t  = (0:N-1) * dt;

% Pressure: baseline 80 psi, two planted violation windows (> 100)
pres = 80 + 5*sin(t/20) + 1.5*randn(1, N);
pres(t >= 100 & t <= 130) = pres(t >= 100 & t <= 130) + 30;
pres(t >= 600 & t <= 640) = pres(t >= 600 & t <= 640) + 35;

% Temperature: baseline 65 degC, one ramp violation (> 80)
temp = 65 + 3*sin(t/30) + 1*randn(1, N);
ramp = t >= 300 & t <= 380;
temp(ramp) = temp(ramp) + linspace(0, 25, sum(ramp));

% Vibration: baseline 30 Hz, multiple short violations (> 50)
vib = 30 + 2*sin(t/10) + 0.8*randn(1, N);
for vstart = [50, 250, 500, 800]
    idx = t >= vstart & t <= vstart + 8;
    vib(idx) = vib(idx) + 25;
end

%% ========================================================================
%  2. SENSOR PARENTS
%  ========================================================================

sPres = SensorTag('pressure',    'Name', 'Pressure (psi)');
sTemp = SensorTag('temperature', 'Name', 'Temperature (degC)');
sVib  = SensorTag('vibration',   'Name', 'Vibration (Hz)');
sPres.updateData(t, pres);
sTemp.updateData(t, temp);
sVib.updateData( t, vib);

TagRegistry.register('pressure',    sPres);
TagRegistry.register('temperature', sTemp);
TagRegistry.register('vibration',   sVib);

%% ========================================================================
%  3. EVENT STORE + 3 MONITOR TAGS WIRED TO IT
%  ========================================================================

eventFile = fullfile(tempdir, 'fastsense_phase1016_viewer.mat');
if exist(eventFile, 'file'); delete(eventFile); end
store = EventStore(eventFile, 'MaxBackups', 3);

mPres = MonitorTag('pressure_high',    sPres, @(x, y) y > 100, 'EventStore', store);
mTemp = MonitorTag('temperature_high', sTemp, @(x, y) y > 80,  'EventStore', store);
mVib  = MonitorTag('vibration_high',   sVib,  @(x, y) y > 50,  'EventStore', store);
TagRegistry.register('pressure_high',    mPres);
TagRegistry.register('temperature_high', mTemp);
TagRegistry.register('vibration_high',   mVib);

%% ========================================================================
%  4. TRIGGER EVENT COMPUTATION (lazy MonitorTag)
%  ========================================================================
%  getXY runs the pipeline on the parent's grid and emits events into
%  the bound EventStore via fireEventsOnRisingEdges_.

fprintf('Computing events for 3 sensors...\n');
mPres.getXY();
mTemp.getXY();
mVib.getXY();

fprintf('  Detected %d events.\n', store.numEvents());

%% ========================================================================
%  5. SAVE TO DISK
%  ========================================================================

store.save();
fprintf('Events saved to: %s\n', eventFile);

%% ========================================================================
%  6. REOPEN VIA EventViewer.fromFile (DEMO-03)
%  ========================================================================

fprintf('Opening EventViewer.fromFile(...)...\n');
viewer = EventViewer.fromFile(eventFile);   %#ok<NASGU>
fprintf('Viewer opened. Click any Gantt bar or list row to inspect an event.\n');
fprintf('(Click-to-plot detail flow — see EventViewer.openEventPlot.)\n');
