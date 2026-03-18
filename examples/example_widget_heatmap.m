%% HeatmapWidget — All Configurations Demo
% Demonstrates HeatmapWidget in three configurations:
%   1. Temperature grid: hour-of-day vs day-of-week (DataFcn + 'jet' colormap)
%   2. Correlation matrix: six process variables (custom labels, 'hot' colormap)
%   3. Sensor-bound: wraps a sensor Y vector as a 2D matrix
%
% HeatmapWidget Properties:
%   DataFcn      — function_handle returning a 2D matrix (polled on refresh).
%   Sensor       — Sensor object; Y vector reshaped to 2D.
%   Colormap     — colormap name or Nx3 matrix (default 'parula').
%   ShowColorbar — show/hide colorbar (default true).
%   XLabels      — cell array of column-axis tick labels.
%   YLabels      — cell array of row-axis tick labels.
%   Title        — widget title.
%   Position     — [col row width height] on the 24-column grid.
%
% Usage:
%   example_widget_heatmap

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

%% 1. Build data sources

% --- Temperature grid: 7 rows (Mon-Sun) x 24 cols (hour 0-23) ---
rng(42);
dayBase   = [68 72 74 72 70 66 64];   % Mon-Sun baseline in degF
hourShape = sin(pi * (0:23) / 23);    % gentle bell across the day
tempGrid = bsxfun(@plus, dayBase', bsxfun(@times, 6 * hourShape, ones(7,1)));
tempGrid = tempGrid + 2*randn(7, 24);  % process noise

hourLabels = {'0h','1h','2h','3h','4h','5h','6h','7h','8h','9h', ...
              '10h','11h','12h','13h','14h','15h','16h','17h','18h','19h', ...
              '20h','21h','22h','23h'};
dayLabels  = {'Mon','Tue','Wed','Thu','Fri','Sat','Sun'};

% --- Correlation matrix (6 variables) ---
vars   = {'Temp','Press','Flow','RPM','Vibr','Power'};
nVars  = numel(vars);
corrMat = eye(nVars);
corrMat(1,2) = 0.82;  corrMat(2,1) = 0.82;
corrMat(1,3) = -0.55; corrMat(3,1) = -0.55;
corrMat(2,3) = -0.40; corrMat(3,2) = -0.40;
corrMat(1,4) = 0.30;  corrMat(4,1) = 0.30;
corrMat(2,4) = 0.65;  corrMat(4,2) = 0.65;
corrMat(3,4) = 0.71;  corrMat(4,3) = 0.71;
corrMat(1,5) = 0.20;  corrMat(5,1) = 0.20;
corrMat(2,5) = 0.45;  corrMat(5,2) = 0.45;
corrMat(4,5) = 0.88;  corrMat(5,4) = 0.88;
corrMat(4,6) = 0.95;  corrMat(6,4) = 0.95;
corrMat(1,6) = 0.28;  corrMat(6,1) = 0.28;
corrMat(2,6) = 0.60;  corrMat(6,2) = 0.60;
corrMat(3,6) = -0.38; corrMat(6,3) = -0.38;
corrMat(5,6) = 0.90;  corrMat(6,5) = 0.90;

% --- Sensor-bound (vibration RMS over time, reshaped 8x16) ---
N = 5000;
t = linspace(0, 86400, N);
sVib = Sensor('V-501', 'Name', 'Vibration RMS');
sVib.Units = 'mm/s';
sVib.X = t;
sVib.Y = 1.5 + 0.8*sin(2*pi*t/7200) + randn(1,N)*0.15;
sVib.Y(t > 43200 & t < 46800) = sVib.Y(t > 43200 & t < 46800) + 1.2;
sVib.resolve();

%% 2. Build dashboard
d = DashboardEngine('Heatmap Widget Demo');
d.Theme = 'light';

% Row 1-6: Temperature grid — hour-of-day vs day-of-week, 'jet' colormap
d.addWidget('heatmap', 'Title', 'Temperature by Hour & Day', ...
    'Position', [1 1 14 6], ...
    'DataFcn', @() tempGrid, ...
    'Colormap', 'jet', ...
    'ShowColorbar', true, ...
    'XLabels', hourLabels, ...
    'YLabels', dayLabels);

% Row 1-6: Correlation matrix, 'hot' colormap, no colorbar
d.addWidget('heatmap', 'Title', 'Process Variable Correlations', ...
    'Position', [15 1 10 6], ...
    'DataFcn', @() corrMat, ...
    'Colormap', 'hot', ...
    'ShowColorbar', false, ...
    'XLabels', vars, ...
    'YLabels', vars);

% Row 7-12: Sensor-bound — vibration data reshaped into 2D
d.addWidget('heatmap', 'Title', 'Vibration RMS Pattern', ...
    'Position', [1 7 14 6], ...
    'Sensor', sVib, ...
    'Colormap', 'parula');

%% 3. Render
d.render();
fprintf('Dashboard rendered with %d heatmap widgets.\n', numel(d.Widgets));
fprintf('Sensor %s: %d points, range [%.2f, %.2f] %s\n', ...
    sVib.Key, numel(sVib.Y), min(sVib.Y), max(sVib.Y), sVib.Units);
