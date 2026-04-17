%% Dashboard Engine Example — Sensor-Driven
% Demonstrates: DashboardEngine with FastSenseWidgets bound to Sensors,
% dynamic thresholds via StateChannels, JSON save/load.
%
% DashboardEngine uses a 24-column grid.  Widget positions are specified as
%   Position = [col, row, width, height]
% where col and row are 1-based, row 1 = top.  For example,
%   [1 1 24 8] = full-width, 8 rows tall, starting at the top.
%   [13 1 12 4] = right half, 4 rows tall.

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Generate data and create Sensors with thresholds
rng(7);
N = 10000;
t = linspace(0, 86400, N);  % 24 hours in seconds

% Machine mode state channel: idle(0) -> running(1) -> idle(0) -> running(1)
scMode = StateTag('machine', 'X', [0, 7200, 43200, 57600], 'Y', [0, 1,    0,     1]);

% Temperature sensor with mode-dependent thresholds
sTemp = SensorTag('T-401', 'Name', 'Temperature', 'Units', [char(176) 'C'], 'X', t, 'Y', 70 + 5*sin(2*pi*t/3600) + randn(1,N)*0.8);


% Pressure sensor with unconditional thresholds
sPress = SensorTag('P-201', 'Name', 'Pressure', 'Units', 'bar', 'X', t, 'Y', 50 + 20*sin(2*pi*t/7200) + randn(1,N)*1.5);


%% 2. Create dashboard with sensor-bound widgets
d = DashboardEngine('Process Monitoring — Line 4');
d.Theme = 'light';
d.LiveInterval = 5;

d.addWidget('fastsense', ...
    'Position', [1 1 16 8], ...
    'Sensor', sTemp);

d.addWidget('fastsense', ...
    'Position', [17 1 8 8], ...
    'Sensor', sPress);

d.addWidget('fastsense', 'Title', 'Temperature (full view)', ...
    'Position', [1 9 24 8], ...
    'Sensor', sTemp);

d.render();

%% 3. Save to JSON and reload
jsonPath = fullfile(tempdir, 'example_dashboard.json');
d.save(jsonPath);
fprintf('Dashboard saved to: %s\n', jsonPath);

%% 4. Export to .m script
scriptPath = fullfile(tempdir, 'example_dashboard_export.m');
d.exportScript(scriptPath);
fprintf('Dashboard exported to script: %s\n', scriptPath);

%% 5. Programmatic widget management
% setWidgetPosition — move/resize a widget on the 24-column grid
d.setWidgetPosition(2, [1 9 12 8]);  % move pressure widget below, half-width
fprintf('setWidgetPosition: moved pressure widget to [1 9 12 8].\n');

% removeWidget — delete a widget by index
d.removeWidget(3);  % remove the full-view temperature widget
fprintf('removeWidget: removed widget 3 (full-view temperature).\n');

%% 6. Load from JSON (demonstrates roundtrip)
% Loads the original 3-widget layout saved in step 3, before the
% removeWidget/setWidgetPosition mutations above.
% SensorResolver maps sensor keys back to Sensor objects for the loaded config
sensorMap = containers.Map({'T-401', 'P-201'}, {sTemp, sPress});
d2 = DashboardEngine.load(jsonPath, 'SensorResolver', @(key) sensorMap(key));
d2.render();
fprintf('Dashboard reloaded from JSON and rendered in a second figure.\n');
