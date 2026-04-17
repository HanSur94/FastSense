%% Dashboard Engine — All Widget Types Demo (Sensor-Driven)
% Demonstrates every widget type in a single dashboard, wired to Sensor
% objects with dynamic thresholds via StateChannels.
%
%   FastSense widgets:  bound to Sensors with resolved thresholds
%   Number/Gauge/Status: driven by sensor data (latest value / threshold check)
%   Text/Table:        static display (no interactivity needed)
%   Timeline:          derived from threshold violations
%   Heatmap:           2D colour grid (DataFcn returning matrix)
%   BarChart:          categorical bar chart (DataFcn returning struct)
%   Histogram:         sensor value distribution with optional normal fit
%   Scatter:           two-sensor X-vs-Y correlation plot
%   Image:             generated test pattern via ImageFcn
%   MultiStatus:       per-sensor status grid (dot indicators)
%
% Usage:
%   example_dashboard_all_widgets
%
% Click "Edit" in the toolbar to enter GUI builder mode.

close all force;
clear functions;  % flush MATLAB function cache

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% ========== Generate realistic process data ==========
rng(42);  % reproducible
N = 10000;
t = linspace(0, 86400, N);  % 24 hours in seconds

% --- Machine mode state channel (idle=0, running=1, maintenance=2) ---
modeChangeTimes = [0, 3600, 7200, 28800, 36000, 72000, 79200, 82800];
modeValues      = [0, 1,    1,    2,     1,     0,     1,     1];

scMode = StateTag('machine', 'X', modeChangeTimes, 'Y', modeValues);

% --- Temperature sensor T-401 ---
% Baseline shifts with machine mode: idle ~68, running ~74, maint ~65
tempBase = zeros(1, N);
for k = 1:N
    mode = scMode.valueAt(t(k));
    switch mode
        case 0, tempBase(k) = 68;
        case 1, tempBase(k) = 74;
        case 2, tempBase(k) = 65;
    end
end
tempNoise = 3*sin(2*pi*t/3600) + randn(1,N)*1.2;
temp = tempBase + tempNoise;
% Inject a brief overshoot event around hour 10
overIdx = t >= 36000 & t <= 38000;
temp(overIdx) = temp(overIdx) + 12;

sTemp = SensorTag('T-401', 'Name', 'Temperature', 'Units', [char(176) 'F'], 'X', t, 'Y', temp);
% Running mode thresholds


% Idle mode threshold (tighter — equipment should be cool)

% --- Pressure sensor P-201 ---
pressBase = zeros(1, N);
for k = 1:N
    mode = scMode.valueAt(t(k));
    switch mode
        case 0, pressBase(k) = 30;
        case 1, pressBase(k) = 55;
        case 2, pressBase(k) = 20;
    end
end
pressNoise = 8*sin(2*pi*t/7200) + randn(1,N)*2;
pressure = pressBase + pressNoise;

sPress = SensorTag('P-201', 'Name', 'Pressure', 'Units', 'psi', 'X', t, 'Y', pressure);


% --- Flow sensor F-301 ---
flowBase = zeros(1, N);
for k = 1:N
    mode = scMode.valueAt(t(k));
    switch mode
        case 0, flowBase(k) = 0;
        case 1, flowBase(k) = 120;
        case 2, flowBase(k) = 0;
    end
end
flowNoise = 5*sin(2*pi*t/1800) + randn(1,N)*3;
flow = max(0, flowBase + flowNoise);

sFlow = SensorTag('F-301', 'Name', 'Flow Rate', 'Units', 'L/min', 'X', t, 'Y', flow);


%% ========== Build alarm log from resolved violations ==========
alarmLog = {};
sensors = {sTemp, sPress, sFlow};
for si = 1:numel(sensors)
    s = sensors{si};
        continue;
    end
        if isempty(v.X)
            continue;
        end
        % Sample up to 3 violation points per rule
        nSample = min(3, numel(v.X));
        idx = round(linspace(1, numel(v.X), nSample));
        for j = 1:nSample
            tSec = v.X(idx(j));
            hours = floor(tSec / 3600);
            mins = floor(mod(tSec, 3600) / 60);
            timeStr = sprintf('%02d:%02d', hours, mins);
            valStr = sprintf('%.1f', v.Y(idx(j)));
            sevStr = v.Label;
            alarmLog(end+1, :) = {timeStr, s.Key, valStr, sevStr}; %#ok<AGROW>
        end
    end
end
% Sort by time
if ~isempty(alarmLog)
    [~, sortIdx] = sort(alarmLog(:, 1));
    alarmLog = alarmLog(sortIdx, :);
    % Limit to last 10 entries
    if size(alarmLog, 1) > 10
        alarmLog = alarmLog(end-9:end, :);
    end
end

%% ========== Build events from state channel transitions ==========
modeLabels = {'Idle', 'Running', 'Maintenance'};
modeColors = {[0.6 0.6 0.6], [0.2 0.7 0.3], [1.0 0.6 0.1]};
nModes = numel(modeChangeTimes);
events = struct('startTime', {}, 'endTime', {}, 'label', {}, 'color', {});
for k = 1:nModes
    tStart = modeChangeTimes(k);
    if k < nModes
        tEnd = modeChangeTimes(k+1);
    else
        tEnd = 86400;
    end
    modeIdx = modeValues(k) + 1;  % 0-based to 1-based
    events(end+1) = struct('startTime', tStart, 'endTime', tEnd, ...
        'label', modeLabels{modeIdx}, 'color', modeColors{modeIdx}); %#ok<AGROW>
end

%% ========== Create Dashboard ==========
% DashboardEngine uses a 24-column grid.  Widget positions are specified as
%   Position = [col, row, width, height]
% where col and row are 1-based, row 1 = top.
d = DashboardEngine('Process Monitoring — Line 4');
d.Theme = 'light';
d.LiveInterval = 5;

% --- Row 1-2: Header + KPIs + Status indicators ---
d.addWidget('text', 'Title', 'Overview', ...
    'Position', [1 1 4 2], ...
    'Content', 'Line 4 — Shift A', ...
    'FontSize', 16, ...
    'Alignment', 'left');

% Sensor-bound number widgets: auto-derive value from Sensor.Y(end),
% Units from Sensor.Units, and trend arrow from recent data.
d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [5 1 5 2], ...
    'Sensor', sTemp, ...
    'Format', '%.1f');

d.addWidget('number', 'Title', 'Pressure', ...
    'Position', [10 1 5 2], ...
    'Sensor', sPress, ...
    'Format', '%.0f');

% Sensor-bound status widgets: auto-derive ok/warning/alarm from
% threshold rules — no custom StatusFcn callback needed.
d.addWidget('status', 'Title', 'Temp', ...
    'Position', [15 1 5 2], ...
    'Sensor', sTemp);

d.addWidget('status', 'Title', 'Press', ...
    'Position', [20 1 5 2], ...
    'Sensor', sPress);

% --- Row 3-10: Sensor-driven FastSense widgets with thresholds ---
d.addWidget('fastsense', ...
    'Position', [1 3 12 8], ...
    'Sensor', sTemp);

d.addWidget('fastsense', ...
    'Position', [13 3 12 8], ...
    'Sensor', sPress);

% --- Row 11-18: Flow plot + Table + Histogram + Gauge ---
d.addWidget('fastsense', ...
    'Position', [1 11 12 8], ...
    'Sensor', sFlow);

% Sensor-bound gauge: auto-derives value, units, and range from sensor.
d.addWidget('gauge', 'Title', 'Flow', ...
    'Position', [13 11 6 6], ...
    'Sensor', sFlow, ...
    'Range', [0 160]);

d.addWidget('rawaxes', 'Title', 'Temp Distribution', ...
    'Position', [19 11 6 6], ...
    'PlotFcn', @(ax) histogram(ax, temp, 50, ...
        'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none'));

d.addWidget('table', 'Title', 'Alarm Log', ...
    'Position', [13 17 12 2], ...
    'ColumnNames', {'Time', 'Tag', 'Value', 'Threshold'}, ...
    'Data', alarmLog);

% --- Event timeline
d.addWidget('timeline', 'Title', 'Machine Mode', ...
    'Position', [1 19 24 3], ...
    'Events', events);

% --- Row 22-27: Phase B widgets — Heatmap, BarChart, Histogram ---

% Heatmap: temperature binned by hour-of-day (24 cols) vs machine mode (3 rows)
% Pre-compute mode at every sample to avoid calling valueAt N*24*3 times.
tMode = zeros(1, N);
for k = 1:N
    tMode(k) = scMode.valueAt(t(k));
end
hourBins = zeros(3, 24);
for h = 0:23
    hourIdx = (floor(t / 3600) == h);
    for m = 0:2
        mIdx = hourIdx & (tMode == m);
        if any(mIdx)
            hourBins(m+1, h+1) = mean(temp(mIdx));
        end
    end
end
hourXLabels = cell(1, 24);
for h = 0:23
    hourXLabels{h+1} = sprintf('%dh', h);
end
d.addWidget('heatmap', 'Title', 'Temp by Hour & Machine Mode', ...
    'Position', [1 22 14 6], ...
    'DataFcn', @() hourBins, ...
    'Colormap', 'jet', ...
    'XLabels', hourXLabels, ...
    'YLabels', {'Idle','Running','Maint'});

% BarChart: alarm counts by sensor tag
alarmCounts = struct( ...
    'categories', {{'T-401','P-201','F-301'}}, ...
d.addWidget('barchart', 'Title', 'Violation Count by Sensor', ...
    'Position', [15 22 10 6], ...
    'DataFcn', @() alarmCounts, ...
    'Orientation', 'vertical');

% --- Row 28-33: Histogram, Scatter, Image, MultiStatus ---

% Histogram: temperature distribution with normal fit
d.addWidget('histogram', 'Title', 'Temperature Distribution', ...
    'Position', [1 28 8 6], ...
    'Sensor', sTemp, ...
    'ShowNormalFit', true, ...
    'NumBins', 40);

% Scatter: temperature vs pressure, color-coded by flow rate
d.addWidget('scatter', 'Title', 'Temp vs Pressure (color=Flow)', ...
    'Position', [9 28 8 6], ...
    'SensorX', sTemp, ...
    'SensorY', sPress, ...
    'SensorColor', sFlow, ...
    'MarkerSize', 4, ...
    'Colormap', 'parula');

% Image: procedural test pattern (no external file dependency)
d.addWidget('image', 'Title', 'Process Diagram', ...
    'Position', [17 28 8 6], ...
    'ImageFcn', @() makePeaksThumb(), ...
    'Caption', 'Elevation map (peaks function)', ...
    'Scaling', 'fit');

% MultiStatus: all three process sensors at a glance
d.addWidget('multistatus', 'Title', 'Sensor Status', ...
    'Position', [1 34 24 3], ...
    'Sensors', {sTemp, sPress, sFlow}, ...
    'Columns', 3, ...
    'IconStyle', 'dot', ...
    'ShowLabels', true);

%% Render
d.render();

fprintf('Dashboard rendered with %d widgets.\n', numel(d.Widgets));
fprintf('Sensors: T-401 (%d violations), P-201 (%d violations), F-301 (%d violations)\n', ...
fprintf('Phase B widgets added: heatmap, barchart, histogram, scatter, image, multistatus.\n');
fprintf('Click "Edit" to enter GUI builder mode.\n');
fprintf('Click "Save" to export as JSON, "Export" to generate .m script.\n');

%% ---- Helper function ----
function img = makePeaksThumb()
% Return a grayscale uint8 image derived from peaks(64).
Z = peaks(64);
Z = Z - min(Z(:));
Z = Z ./ max(Z(:));
img = uint8(round(Z * 255));
end
