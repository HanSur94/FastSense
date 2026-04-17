%% HistogramWidget — All Configurations Demo
% Demonstrates HistogramWidget with sensor-bound data, normal curve overlay,
% custom bin counts, and a DataFcn source.
%
% HistogramWidget Properties:
%   Sensor        — Sensor object; Y values are binned on refresh.
%   DataFcn       — function_handle returning a numeric vector.
%   NumBins       — number of bins (default auto = max(10, sqrt(N))).
%   ShowNormalFit — overlay a scaled normal distribution curve (default false).
%   EdgeColor     — bin edge RGB color; [] uses theme default.
%   Title         — widget title.
%   Position      — [col row width height] on the 24-column grid.
%
% Usage:
%   example_widget_histogram

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Create sensors and data

rng(42);
N = 5000;
t = linspace(0, 86400, N);  % 24 hours in seconds

% Temperature — nearly normal distribution
sTemp = SensorTag('T-401', 'Name', 'Temperature', 'Units', [char(176) 'F'], 'X', t, 'Y', 72 + 4*sin(2*pi*t/3600) + randn(1,N)*1.5);

% Pressure — bimodal (two machine modes)
modeA = t < 43200;  % first 12 hours: lower pressure
modeB = t >= 43200; % second 12 hours: higher pressure
yPress = zeros(1, N);
yPress(modeA) = 30 + randn(1, sum(modeA))*3;
yPress(modeB) = 55 + randn(1, sum(modeB))*4;
sPress = SensorTag('P-201', 'Name', 'Pressure', 'Units', 'psi', 'X', t, 'Y', yPress);

% Vibration — log-normal (positively skewed)
sVib = SensorTag('V-501', 'Name', 'Vibration RMS', 'Units', 'mm/s', 'X', t, 'Y', max(0.1, exp(0.5 + 0.4*randn(1,N))));  % log-normal

% Custom DataFcn — batch cycle times (gamma-like)
cycleTimes = 28 + 15*abs(randn(1, 800)) + 5*randn(1,800);

%% 2. Build dashboard
d = DashboardEngine('Histogram Widget Demo');
d.Theme = 'light';

% Row 1-6: Temperature — sensor-bound, auto bins, with normal fit
d.addWidget('histogram', 'Title', 'Temperature Distribution', ...
    'Position', [1 1 12 6], ...
    'Tag', sTemp, ...
    'ShowNormalFit', true);

% Row 1-6: Pressure — sensor-bound, custom bin count (30), no fit
d.addWidget('histogram', 'Title', 'Pressure Distribution (30 bins)', ...
    'Position', [13 1 12 6], ...
    'Tag', sPress, ...
    'NumBins', 30, ...
    'ShowNormalFit', false);

% Row 7-12: Vibration — sensor-bound, auto bins, with normal fit (skew visible)
d.addWidget('histogram', 'Title', 'Vibration RMS — Log-Normal Shape', ...
    'Position', [1 7 12 6], ...
    'Tag', sVib, ...
    'ShowNormalFit', true);

% Row 7-12: Cycle times — DataFcn, custom bins, EdgeColor override
d.addWidget('histogram', 'Title', 'Batch Cycle Times (red edges)', ...
    'Position', [13 7 12 6], ...
    'DataFcn', @() cycleTimes, ...
    'NumBins', 40, ...
    'EdgeColor', [0.8 0.2 0.2], ...
    'ShowNormalFit', false);

%% 3. Render
d.render();
fprintf('Dashboard rendered with %d histogram widgets.\n', numel(d.Widgets));
fprintf('Temperature: mean=%.1f std=%.1f (N=%d)\n', ...
    mean(sTemp.Y), std(sTemp.Y), numel(sTemp.Y));
fprintf('Pressure:    mean=%.1f std=%.1f (bimodal)\n', ...
    mean(sPress.Y), std(sPress.Y));
fprintf('Vibration:   mean=%.2f std=%.2f (log-normal)\n', ...
    mean(sVib.Y), std(sVib.Y));
