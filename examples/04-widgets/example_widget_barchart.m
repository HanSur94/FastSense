%% BarChartWidget — All Configurations Demo
% Demonstrates BarChartWidget with vertical and horizontal orientations,
% DataFcn data sources, and a sensor-bound mode.
%
% BarChartWidget Properties:
%   DataFcn     — function_handle returning a struct with fields:
%                   categories — cell array of category labels
%                   values     — numeric vector of bar heights
%                 or returning a plain numeric vector (no labels).
%   Sensor      — Sensor object; Y vector used directly as bar values.
%   Orientation — 'vertical' (default) or 'horizontal'.
%   Stacked     — stacked bars when multiple value columns (default false).
%   Title       — widget title.
%   Position    — [col row width height] on the 24-column grid.
%
% Usage:
%   example_widget_barchart

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Define data sources

% --- Production output per shift (vertical bar chart) ---
shiftData = struct( ...
    'categories', {{'Shift A', 'Shift B', 'Shift C', 'Shift D'}}, ...
    'values',     [412, 387, 455, 398]);

% --- Alarm counts by sensor (horizontal — long category labels) ---
alarmData = struct( ...
    'categories', {{'Temperature T-401', 'Pressure P-201', 'Flow F-301', ...
                    'Level L-102', 'Vibration V-501'}}, ...
    'values',     [8, 3, 12, 1, 5]);

% --- Weekly throughput — plain numeric, no labels ---
weeklyValues = [1820 1975 1843 2010 1965 1750 1410];

% --- Sensor-bound: hourly flow averages (8 buckets) ---
rng(42);
N = 5000;
t = linspace(0, 28800, N);  % 8 hours in seconds
sFlow = SensorTag('F-301', 'Name', 'Flow Rate', 'Units', 'L/min', 'X', t, 'Y', max(0, 120 + 20*sin(2*pi*t/3600) + randn(1,N)*5));

%% 2. Build dashboard
d = DashboardEngine('Bar Chart Widget Demo');
d.Theme = 'light';

% Row 1-5: Vertical — production by shift
d.addWidget('barchart', 'Title', 'Production by Shift', ...
    'Position', [1 1 12 5], ...
    'DataFcn', @() shiftData, ...
    'Orientation', 'vertical');

% Row 1-5: Horizontal — alarm counts by sensor tag
d.addWidget('barchart', 'Title', 'Alarm Count by Sensor', ...
    'Position', [13 1 12 5], ...
    'DataFcn', @() alarmData, ...
    'Orientation', 'horizontal');

% Row 6-10: Vertical, no labels — plain numeric vector
d.addWidget('barchart', 'Title', 'Weekly Throughput (Mon-Sun)', ...
    'Position', [1 6 12 5], ...
    'DataFcn', @() weeklyValues, ...
    'Orientation', 'vertical');

% Row 6-10: Sensor-bound (uses Sensor.Y values directly as bar data)
d.addWidget('barchart', 'Title', 'Flow Distribution (sensor)', ...
    'Position', [13 6 12 5], ...
    'Tag', sFlow, ...
    'Orientation', 'vertical');

%% 3. Render
d.render();
fprintf('Dashboard rendered with %d bar chart widgets.\n', numel(d.Widgets));
fprintf('Flow sensor %s: latest %.1f %s\n', ...
    sFlow.Key, sFlow.Y(end), sFlow.Units);
