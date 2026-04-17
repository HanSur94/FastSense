%% Dashboard Groups — Panel, Collapsible, and Tabbed Modes
% Demonstrates GroupWidget usage with DashboardEngine.
%
%   - Panel group:       always-visible container
%   - Collapsible group: can be hidden/shown with a click
%   - Tabbed group:      multiple views sharing one space
%
% Usage:
%   example_dashboard_groups

close all force;
clear functions;

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% Create sample sensors
rng(7);
N = 101;
t = linspace(0, 10, N);

% RPM sensor
s_rpm = SensorTag('rpm_main', 'Name', 'Main RPM');
s_rpm.Units = 'rpm';
s_rpm.updateData(t, 100 + 20*sin(t));

% Bearing temperature sensor with thresholds
s_temp = SensorTag('temp_bearing', 'Name', 'Bearing Temp');
s_temp.Units = [char(176) 'C'];
s_temp.updateData(t, 60 + 5*randn(1, N));

% Line pressure sensor
s_pres = SensorTag('pressure', 'Name', 'Line Pressure');
s_pres.Units = 'bar';
s_pres.updateData(t, 2.5 + 0.3*randn(1, N));

%% Build dashboard
d = DashboardEngine('GroupWidget Demo', 'Theme', 'light');

% 1. Panel group — always visible
d.addWidget('group', 'Label', 'Motor Overview', 'Mode', 'panel', ...
    'Position', [1 1 12 4]);
g1 = d.Widgets{end};
g1.addChild(NumberWidget('Sensor', s_rpm, 'Title', 'RPM'));
g1.addChild(GaugeWidget('Sensor', s_temp, 'Title', 'Temperature'));
g1.addChild(StatusWidget('Sensor', s_temp, 'Title', 'Temp Status'));

% 2. Collapsible group — can be hidden
d.addWidget('group', 'Label', 'Pressure Detail', 'Mode', 'collapsible', ...
    'Position', [13 1 12 4]);
g2 = d.Widgets{end};
g2.addChild(FastSenseWidget('Sensor', s_pres, 'Title', 'Pressure Over Time'));

% 3. Tabbed group — multiple views in one space
d.addWidget('group', 'Label', 'Analysis', 'Mode', 'tabbed', ...
    'Position', [1 5 24 5]);
g3 = d.Widgets{end};
g3.addChild(FastSenseWidget('Sensor', s_rpm, 'Title', 'RPM Trend'), 'Trends');
g3.addChild(FastSenseWidget('Sensor', s_temp, 'Title', 'Temp Trend'), 'Trends');
g3.addChild(NumberWidget('Sensor', s_rpm, 'Title', 'Current RPM'), 'Summary');
g3.addChild(NumberWidget('Sensor', s_temp, 'Title', 'Current Temp'), 'Summary');
g3.addChild(StatusWidget('Sensor', s_temp, 'Title', 'Status'), 'Summary');

%% Render
d.render();

fprintf('Dashboard rendered with %d widgets (%d groups).\n', ...
    numel(d.Widgets), 3);
fprintf('Click the collapsible header to toggle visibility.\n');
fprintf('Click tab buttons in the Analysis group to switch views.\n');
