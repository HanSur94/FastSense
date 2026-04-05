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
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = [char(176) 'F'];
sTemp.X = t;
sTemp.Y = 72 + 4*sin(2*pi*t/3600) + randn(1,N)*1.5;
tHiWarnTemp = Threshold('hi_warn', 'Name', 'Hi Warn', ...
    'Direction', 'upper', 'Color', [1 0.8 0], 'LineStyle', '--');
tHiWarnTemp.addCondition(struct(), 78);
sTemp.addThreshold(tHiWarnTemp);

tHiAlarmTemp = Threshold('hi_alarm', 'Name', 'Hi Alarm', ...
    'Direction', 'upper', 'Color', [1 0.2 0.2], 'LineStyle', '-');
tHiAlarmTemp.addCondition(struct(), 85);
sTemp.addThreshold(tHiAlarmTemp);
sTemp.resolve();

% Pressure — bimodal (two machine modes)
sPress = Sensor('P-201', 'Name', 'Pressure');
sPress.Units = 'psi';
sPress.X = t;
modeA = t < 43200;  % first 12 hours: lower pressure
modeB = t >= 43200; % second 12 hours: higher pressure
sPress.Y = zeros(1, N);
sPress.Y(modeA) = 30 + randn(1, sum(modeA))*3;
sPress.Y(modeB) = 55 + randn(1, sum(modeB))*4;
tHiWarnPress = Threshold('hi_warn', 'Name', 'Hi Warn', ...
    'Direction', 'upper', 'Color', [1 0.8 0], 'LineStyle', '--');
tHiWarnPress.addCondition(struct(), 65);
sPress.addThreshold(tHiWarnPress);
sPress.resolve();

% Vibration — log-normal (positively skewed)
sVib = Sensor('V-501', 'Name', 'Vibration RMS');
sVib.Units = 'mm/s';
sVib.X = t;
sVib.Y = max(0.1, exp(0.5 + 0.4*randn(1,N)));  % log-normal
sVib.resolve();

% Custom DataFcn — batch cycle times (gamma-like)
cycleTimes = 28 + 15*abs(randn(1, 800)) + 5*randn(1,800);

%% 2. Build dashboard
d = DashboardEngine('Histogram Widget Demo');
d.Theme = 'light';

% Row 1-6: Temperature — sensor-bound, auto bins, with normal fit
d.addWidget('histogram', 'Title', 'Temperature Distribution', ...
    'Position', [1 1 12 6], ...
    'Sensor', sTemp, ...
    'ShowNormalFit', true);

% Row 1-6: Pressure — sensor-bound, custom bin count (30), no fit
d.addWidget('histogram', 'Title', 'Pressure Distribution (30 bins)', ...
    'Position', [13 1 12 6], ...
    'Sensor', sPress, ...
    'NumBins', 30, ...
    'ShowNormalFit', false);

% Row 7-12: Vibration — sensor-bound, auto bins, with normal fit (skew visible)
d.addWidget('histogram', 'Title', 'Vibration RMS — Log-Normal Shape', ...
    'Position', [1 7 12 6], ...
    'Sensor', sVib, ...
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
