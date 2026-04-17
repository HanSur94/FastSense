%% RawAxesWidget Demo — All PlotFcn Signatures
% Demonstrates every configuration of the RawAxesWidget, which lets you
% drop any custom MATLAB plot into a DashboardEngine tile.
%
% Supported properties:
%   PlotFcn      — function_handle with flexible call signatures:
%                    @(ax)                 basic: axes handle only
%                    @(ax, sensor)         sensor-aware: axes + SensorObj
%                    @(ax, sensor, tRange) time-aware: axes + sensor + [tMin tMax]
%                    @(ax, tRange)         time-only: axes + [tMin tMax], no sensor
%   SensorObj    — Sensor bound to the widget (alias: 'Tag'); passed
%                  to PlotFcn as the second argument when present
%   DataRangeFcn — @() returning [tMin tMax] for global time-range detection
%   Title        — widget title string
%   Position     — [col row width height] on the 24-column grid
%
% Usage:
%   example_widget_rawaxes

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% Create a temperature sensor with synthetic data
rng(42);
N   = 2000;
t   = linspace(0, 86400, N);
y   = 70 + 6*sin(2*pi*t/7200) + randn(1, N)*1.5;

s = SensorTag('T-401', 'Name', 'Temperature', 'X', t, 'Y', y);

%% Build dashboard — 2x2 grid of RawAxes widgets
d = DashboardEngine('RawAxes Widget Demo');
d.Theme = 'light';

% 1. Simple @(ax) — histogram of sensor data (no sensor binding)
d.addWidget('rawaxes', 'Title', 'Temperature Histogram', ...
    'Position', [1 1 12 10], ...
    'PlotFcn', @(ax) plotHistogram(ax, y));

% 2. Sensor-aware @(ax, sensor) — scatter of Y vs sample index
d.addWidget('rawaxes', 'Title', 'Scatter (Sensor-Aware)', ...
    'Position', [13 1 12 10], ...
    'Tag', s, ...
    'PlotFcn', @(ax, sensor) plotScatter(ax, sensor));

% 3. Simple @(ax) — bar chart of summary statistics
d.addWidget('rawaxes', 'Title', 'Summary Statistics', ...
    'Position', [1 11 12 10], ...
    'PlotFcn', @(ax) plotBarStats(ax, y));

% 4. Sensor + DataRangeFcn — time-aware plot with global range detection
d.addWidget('rawaxes', 'Title', 'Time-Aware (DataRangeFcn)', ...
    'Position', [13 11 12 10], ...
    'Tag', s, ...
    'DataRangeFcn', @() [0 86400], ...
    'PlotFcn', @(ax, sensor) plotDistribution(ax, sensor));

d.render();

%% ======================== local functions ========================

function plotHistogram(ax, data)
    histogram(ax, data, 40, 'FaceColor', [0.20 0.60 0.86], 'EdgeColor', 'none');
    xlabel(ax, 'Temperature'); ylabel(ax, 'Count');
end

function plotScatter(ax, sensor)
    scatter(ax, 1:numel(sensor.Y), sensor.Y, 8, sensor.Y, 'filled');
    colormap(ax, parula); colorbar(ax);
    xlabel(ax, 'Sample Index'); ylabel(ax, sensor.Name);
end

function plotBarStats(ax, data)
    stats  = [min(data), median(data), mean(data), max(data)];
    labels = {'Min', 'Median', 'Mean', 'Max'};
    b = bar(ax, stats, 'FaceColor', 'flat');
    b.CData = [0.20 0.73 0.56; 0.35 0.55 0.85; 0.55 0.38 0.78; 0.91 0.33 0.33];
    set(ax, 'XTickLabel', labels);
    ylabel(ax, 'Value');
end

function plotDistribution(ax, sensor)
    % Toolbox-free quartile computation (Statistics Toolbox's quantile() is
    % unavailable in the project's CI environment — per CLAUDE.md, FastSense
    % must be toolbox-free).
    q = quartilesNoToolbox(sensor.Y);
    mu = mean(sensor.Y);
    vals  = [q(1), q(2), q(3), mu];
    names = {'Q1', 'Median', 'Q3', 'Mean'};
    stem(ax, 1:4, vals, 'filled', 'LineWidth', 2, 'MarkerSize', 8, ...
        'Color', [0.17 0.63 0.52]);
    set(ax, 'XTick', 1:4, 'XTickLabel', names);
    ylabel(ax, sensor.Name);
    yline(ax, q(2), '--', 'Median', 'Color', [0.5 0.5 0.5]);
end

function q = quartilesNoToolbox(y)
%QUARTILESNOTOOLBOX [Q1, Median, Q3] via linear interpolation (no Statistics Toolbox).
    y = sort(y(:));
    n = numel(y);
    q = zeros(1, 3);
    for i = 1:3
        p = 0.25 * i;
        h = (n - 1) * p + 1;
        lo = floor(h);
        hi = min(lo + 1, n);
        q(i) = y(lo) + (h - lo) * (y(hi) - y(lo));
    end
end
