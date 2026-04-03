%% ScatterWidget — All Configurations Demo
% Demonstrates ScatterWidget with two sensors (X vs Y), an optional
% color-coding third sensor, and customised marker size.
%
% ScatterWidget Properties:
%   SensorX     — Sensor object for the X axis.
%   SensorY     — Sensor object for the Y axis.
%   SensorColor — Optional Sensor object; values drive point color (colormap).
%   MarkerSize  — scatter marker size in points (default 6).
%   Colormap    — colormap name or Nx3 matrix used with SensorColor (default 'parula').
%   Title       — widget title.
%   Position    — [col row width height] on the 24-column grid.
%
% Usage:
%   example_widget_scatter

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

%% 1. Create sensors

rng(42);
N = 3000;
t = linspace(0, 86400, N);  % 24 hours in seconds

% Temperature and Pressure — positively correlated (higher temp = higher press)
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = [char(176) 'F'];
sTemp.X = t;
sTemp.Y = 72 + 6*sin(2*pi*t/7200) + randn(1,N)*1.5;
sTemp.addThresholdRule(struct(), 82, ...
    'Direction', 'upper', 'Label', 'Hi Warn', ...
    'Color', [1 0.8 0], 'LineStyle', '--');
sTemp.resolve();

sPress = Sensor('P-201', 'Name', 'Pressure');
sPress.Units = 'psi';
sPress.X = t;
% Deliberately correlated with temperature
sPress.Y = 40 + 0.8*(sTemp.Y - 72) + randn(1,N)*2;
sPress.addThresholdRule(struct(), 46, ...
    'Direction', 'upper', 'Label', 'Hi Warn', ...
    'Color', [1 0.8 0], 'LineStyle', '--');
sPress.resolve();

% Flow Rate — weaker correlation with temperature
sFlow = Sensor('F-301', 'Name', 'Flow Rate');
sFlow.Units = 'L/min';
sFlow.X = t;
sFlow.Y = max(0, 100 + 0.4*(sTemp.Y - 72) + randn(1,N)*10);
sFlow.addThresholdRule(struct(), 130, ...
    'Direction', 'upper', 'Label', 'Hi Alarm', ...
    'Color', [1 0.2 0.2], 'LineStyle', '-');
sFlow.resolve();

% Vibration — used as color sensor (highlights operating regime)
sVib = Sensor('V-501', 'Name', 'Vibration RMS');
sVib.Units = 'mm/s';
sVib.X = t;
sVib.Y = max(0.1, 1.2 + 0.06*(sPress.Y - 40) + randn(1,N)*0.3);
sVib.resolve();

%% 2. Build dashboard
d = DashboardEngine('Scatter Widget Demo');
d.Theme = 'light';

% Row 1-8: Temperature vs Pressure — two sensors, no color (dot markers)
d.addWidget('scatter', 'Title', 'Temperature vs Pressure', ...
    'Position', [1 1 12 8], ...
    'SensorX', sTemp, ...
    'SensorY', sPress, ...
    'MarkerSize', 5);

% Row 1-8: Temperature vs Flow — color-coded by Vibration (parula colormap)
d.addWidget('scatter', 'Title', 'Temperature vs Flow (color = Vibration)', ...
    'Position', [13 1 12 8], ...
    'SensorX', sTemp, ...
    'SensorY', sFlow, ...
    'SensorColor', sVib, ...
    'MarkerSize', 6, ...
    'Colormap', 'parula');

% Row 9-16: Pressure vs Flow — color-coded by Temperature, larger markers
d.addWidget('scatter', 'Title', 'Pressure vs Flow (color = Temperature)', ...
    'Position', [1 9 12 8], ...
    'SensorX', sPress, ...
    'SensorY', sFlow, ...
    'SensorColor', sTemp, ...
    'MarkerSize', 8, ...
    'Colormap', 'hot');

% Row 9-16: Flow vs Vibration — no color sensor, small markers
d.addWidget('scatter', 'Title', 'Flow vs Vibration', ...
    'Position', [13 9 12 8], ...
    'SensorX', sFlow, ...
    'SensorY', sVib, ...
    'MarkerSize', 4);

%% 3. Render
d.render();
fprintf('Dashboard rendered with %d scatter widgets.\n', numel(d.Widgets));
% Pearson correlation (toolbox-free)
r_tp = corrcoef(sTemp.Y(:), sPress.Y(:)); r_tp = r_tp(1,2);
r_tf = corrcoef(sTemp.Y(:), sFlow.Y(:));  r_tf = r_tf(1,2);
r_pf = corrcoef(sPress.Y(:), sFlow.Y(:)); r_pf = r_pf(1,2);
fprintf('Correlation T-P: %.2f  T-F: %.2f  P-F: %.2f\n', r_tp, r_tf, r_pf);
