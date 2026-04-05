%% GaugeWidget — All Configurations Demo
% Demonstrates every GaugeWidget configuration in the DashboardEngine.
%
% GaugeWidget Properties:
%   SensorObj  (or 'Sensor' alias) — auto-derives value, units, and range
%              from the bound Sensor object and its ThresholdRules.
%   ValueFcn   — function_handle returning a scalar (polled on refresh).
%   StaticValue — fixed numeric value (no refresh needed).
%   Range      — [min max]; auto-derived from Sensor thresholds/data if [].
%   Units      — unit label string; auto-derived from Sensor.Units if ''.
%   Style      — 'arc' (default) | 'donut' | 'bar' | 'thermometer'.
%   Title      — widget title; auto-derived from Sensor.Name if empty.
%   Position   — [col row width height] on the 24-column grid.
%
% Layout: 2 rows x 3 columns of gauges showing each style plus ValueFcn
% and StaticValue data sources.
%
% Usage:
%   example_widget_gauge

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Create a Sensor with thresholds
rng(42);
N = 5000;
t = linspace(0, 86400, N);  % 24 hours in seconds

sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = [char(176) 'F'];
sTemp.X = t;
sTemp.Y = 70 + 4*sin(2*pi*t/3600) + randn(1, N)*0.8;
sTemp.Y(end) = 76;  % near warning — interesting gauge position

% State-independent thresholds (empty condition struct)
sTemp.addThresholdRule(struct(), 78, ...
    'Direction', 'upper', 'Label', 'Hi Warn', ...
    'Color', [1 0.8 0], 'LineStyle', '--');
sTemp.addThresholdRule(struct(), 85, ...
    'Direction', 'upper', 'Label', 'Hi Alarm', ...
    'Color', [1 0.2 0.2], 'LineStyle', '-');
sTemp.resolve();

%% 2. Build dashboard with 6 gauges (4 styles + 2 data sources)
d = DashboardEngine('Gauge Widget Demo');

% Row 1 — four styles, all sensor-bound
d.addWidget('gauge', ...
    'Position', [1 1 8 8], ...
    'Sensor', sTemp, ...
    'Style', 'arc');

d.addWidget('gauge', ...
    'Position', [9 1 8 8], ...
    'Sensor', sTemp, ...
    'Style', 'donut');

d.addWidget('gauge', ...
    'Position', [17 1 8 8], ...
    'Sensor', sTemp, ...
    'Style', 'bar');

% Row 2 — thermometer style + alternative data sources
d.addWidget('gauge', ...
    'Position', [1 9 8 8], ...
    'Sensor', sTemp, ...
    'Style', 'thermometer');

d.addWidget('gauge', 'Title', 'Efficiency', ...
    'Position', [9 9 8 8], ...
    'ValueFcn', @() 72.5, ...
    'Range', [0 100], ...
    'Units', '%');

d.addWidget('gauge', 'Title', 'Setpoint', ...
    'Position', [17 9 8 8], ...
    'StaticValue', 42, ...
    'Range', [0 50], ...
    'Units', 'psi');

%% 3. Render
d.render();

fprintf('Dashboard rendered with %d gauge widgets.\n', numel(d.Widgets));
fprintf('Sensor %s latest value: %.1f %s (Hi Warn @ 78, Hi Alarm @ 85)\n', ...
    sTemp.Key, sTemp.Y(end), sTemp.Units);
