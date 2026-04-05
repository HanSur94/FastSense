%% Multi-Sensor Detail Dashboard
% Demonstrates embedding multiple SensorDetailPlots into a FastSenseGrid
% grid using tilePanel(), each with independent navigators.

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% Create shared state channel
sc = StateChannel('mode');
sc.X = [0 200];
sc.Y = [1 1];

%% Sensor 1: Temperature
t1 = linspace(0, 200, 80000);
d1 = 120 + 15*sin(2*pi*t1/40) + 3*randn(1, numel(t1));
d1(25000:25300) = d1(25000:25300) + 30;  % spike

s1 = Sensor('temp', 'Name', 'Furnace Temperature');
s1.Units = [char(176) 'C'];
s1.X = t1; s1.Y = d1;
s1.addStateChannel(sc);
tHWarning1 = Threshold('h_warning', 'Name', 'H Warning', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tHWarning1.addCondition(struct('mode', 1), 140);
s1.addThreshold(tHWarning1);

tHhAlarm1 = Threshold('hh_alarm', 'Name', 'HH Alarm', ...
    'Direction', 'upper', 'Color', [1 0 0]);
tHhAlarm1.addCondition(struct('mode', 1), 155);
s1.addThreshold(tHhAlarm1);
s1.resolve();

ev1 = Event(t1(25000), t1(25300), 'temp', 'HH Alarm', 155, 'upper');

%% Sensor 2: Pressure
t2 = linspace(0, 200, 60000);
d2 = 2.5 + 0.8*sin(2*pi*t2/30) + 0.2*randn(1, numel(t2));
d2(40000:40150) = d2(40000:40150) - 1.5;  % dip

s2 = Sensor('pressure', 'Name', 'Chamber Pressure');
s2.Units = 'bar';
s2.X = t2; s2.Y = d2;
s2.addStateChannel(sc);
tLWarning2 = Threshold('l_warning', 'Name', 'L Warning', ...
    'Direction', 'lower', 'Color', [0.3 0.6 1]);
tLWarning2.addCondition(struct('mode', 1), 1.0);
s2.addThreshold(tLWarning2);
s2.resolve();

ev2 = Event(t2(40000), t2(40150), 'pressure', 'L Warning', 1.0, 'lower');

%% Sensor 3: Vibration (no thresholds, no events — minimal)
t3 = linspace(0, 200, 50000);
d3 = 0.5 + 0.3*sin(2*pi*t3/8) + 0.1*randn(1, numel(t3));

s3 = Sensor('vib', 'Name', 'Motor Vibration');
s3.Units = 'mm/s';
s3.X = t3; s3.Y = d3;

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
