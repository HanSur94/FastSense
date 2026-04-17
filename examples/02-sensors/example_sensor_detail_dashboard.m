%% Multi-Sensor Detail Dashboard
% Demonstrates embedding multiple SensorDetailPlots into a FastSenseGrid
% grid using tilePanel(), each with independent navigators.

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% Create shared state channel
sc = StateTag('mode', 'X', [0 200], 'Y', [1 1]);

%% Sensor 1: Temperature
t1 = linspace(0, 200, 80000);
d1 = 120 + 15*sin(2*pi*t1/40) + 3*randn(1, numel(t1));
d1(25000:25300) = d1(25000:25300) + 30;  % spike

s1 = SensorTag('temp', 'Name', 'Furnace Temperature', 'Units', [char(176) 'C']);
s1.updateData(t1, d1);


ev1 = Event(t1(25000), t1(25300), 'temp', 'HH Alarm', 155, 'upper');

%% Sensor 2: Pressure
t2 = linspace(0, 200, 60000);
d2 = 2.5 + 0.8*sin(2*pi*t2/30) + 0.2*randn(1, numel(t2));
d2(40000:40150) = d2(40000:40150) - 1.5;  % dip

s2 = SensorTag('pressure', 'Name', 'Chamber Pressure', 'Units', 'bar');
s2.updateData(t2, d2);

ev2 = Event(t2(40000), t2(40150), 'pressure', 'L Warning', 1.0, 'lower');

%% Sensor 3: Vibration (no thresholds, no events — minimal)
t3 = linspace(0, 200, 50000);
d3 = 0.5 + 0.3*sin(2*pi*t3/8) + 0.1*randn(1, numel(t3));

s3 = SensorTag('vib', 'Name', 'Motor Vibration', 'Units', 'mm/s');
s3.updateData(t3, d3);

%% Build 2x2 dashboard: 3 SensorDetailPlots + 1 plain FastSense
fig = FastSenseGrid(2, 2, 'Theme', 'light', 'Name', 'Multi-Sensor Dashboard');

% Tile 1: Temperature with events
sdp1 = SensorDetailPlot(s1, 'Parent', fig.tilePanel(1), ...
    'Events', ev1, 'Title', 'Furnace Temperature');
sdp1.render();

% Tile 2: Pressure with events
sdp2 = SensorDetailPlot(s2, 'Parent', fig.tilePanel(2), ...
    'Events', ev2, 'Title', 'Chamber Pressure');
sdp2.render();

% Tile 3: Vibration — no thresholds, no events
sdp3 = SensorDetailPlot(s3, 'Parent', fig.tilePanel(3), ...
    'ShowThresholds', false, 'ShowThresholdBands', false, ...
    'NavigatorHeight', 0.15, 'Title', 'Motor Vibration');
sdp3.render();

% Tile 4: Plain FastSense comparison overlay
fp = fig.tile(4);
fp.addLine(t1, (d1 - mean(d1))/std(d1), 'DisplayName', 'Temp (z-score)');
fp.addLine(t2, (d2 - mean(d2))/std(d2), 'DisplayName', 'Pressure (z-score)');
fig.setTileTitle(4, 'Normalized Overlay');
fig.renderAll();

fprintf('Multi-sensor dashboard with 3 SensorDetailPlots + 1 FastSense.\n');
fprintf('Each navigator operates independently.\n');
