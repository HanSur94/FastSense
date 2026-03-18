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
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

%% 1. Generate data and create Sensors with thresholds
rng(7);
N = 10000;
t = linspace(0, 86400, N);  % 24 hours in seconds

% Machine mode state channel: idle(0) -> running(1) -> idle(0) -> running(1)
scMode = StateChannel('machine');
scMode.X = [0, 7200, 43200, 57600];
scMode.Y = [0, 1,    0,     1    ];

% Temperature sensor with mode-dependent thresholds
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = [char(176) 'C'];
sTemp.X = t;
sTemp.Y = 70 + 5*sin(2*pi*t/3600) + randn(1,N)*0.8;
sTemp.addStateChannel(scMode);
sTemp.addThresholdRule(struct('machine', 1), 78, ...
    'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.addThresholdRule(struct('machine', 1), 85, ...
    'Direction', 'upper', 'Label', 'Hi Alarm');
sTemp.addThresholdRule(struct('machine', 0), 73, ...
    'Direction', 'upper', 'Label', 'Idle Hi');
sTemp.resolve();

% Pressure sensor with unconditional thresholds
sPress = Sensor('P-201', 'Name', 'Pressure');
sPress.Units = 'bar';
sPress.X = t;
sPress.Y = 50 + 20*sin(2*pi*t/7200) + randn(1,N)*1.5;
sPress.addThresholdRule(struct(), 65, ...
    'Direction', 'upper', 'Label', 'Hi Warn');
sPress.addThresholdRule(struct(), 70, ...
    'Direction', 'upper', 'Label', 'Hi Alarm');
sPress.resolve();

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
fprintf('Temperature violations: %d\n', sTemp.countViolations());
fprintf('Pressure violations: %d\n', sPress.countViolations());

%% 4. Load from JSON (demonstrates roundtrip)
% d2 = DashboardEngine.load(jsonPath);
% d2.render();  % opens a second figure from the saved config
