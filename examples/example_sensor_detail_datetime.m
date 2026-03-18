%% SensorDetailPlot — Datetime X-Axis Example
%
% Demonstrates SensorDetailPlot with datenum timestamps so the
% x-axis shows human-readable date/time labels.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

%% 1. Create sensor with datetime-based timestamps
% Simulate 2 hours of data at ~10 Hz
tStart = datetime(2026, 3, 11, 8, 0, 0);
tEnd   = datetime(2026, 3, 11, 10, 0, 0);
N = 72000;
tDatetime = linspace(tStart, tEnd, N);
tNum = datenum(tDatetime);  % Sensor.X expects datenum

data = 4.2 + 0.6*sin(2*pi*tNum*24/1.5) + 0.15*randn(1, N);  % bar-ish units

% Inject a pressure spike around 09:15
idx1 = find(tDatetime >= datetime(2026,3,11,9,15,0), 1);
idx2 = find(tDatetime >= datetime(2026,3,11,9,18,0), 1);
data(idx1:idx2) = data(idx1:idx2) + 1.8;

s = Sensor('line_pressure', 'Name', 'Line Pressure');
s.X = tNum;
s.Y = data;

% State channel and threshold
sc = StateChannel('mode');
sc.X = [tNum(1) tNum(end)];
sc.Y = [1 1];
s.addStateChannel(sc);

s.addThresholdRule(struct('mode', 1), 5.2, ...
    'Direction', 'upper', 'Label', 'H Warning', ...
    'Color', [1 0.75 0], 'LineStyle', '--');
s.addThresholdRule(struct('mode', 1), 5.8, ...
    'Direction', 'upper', 'Label', 'HH Alarm', ...
    'Color', [1 0 0], 'LineStyle', '-');

s.resolve();

%% 2. Create an event for the spike
dSpike = data(idx1:idx2);
ev = Event(tNum(idx1), tNum(idx2), 'line_pressure', 'H Warning', 5.2, 'upper');
ev = ev.setStats(max(dSpike), numel(dSpike), min(dSpike), max(dSpike), ...
    mean(dSpike), rms(dSpike), std(dSpike));

%% 3. Plot with datetime formatting
sdp = SensorDetailPlot(s, ...
    'Events', ev, ...
    'Theme', 'light', ...
    'XType', 'datenum', ...
    'Title', 'Line Pressure — 2026-03-11');
sdp.render();

% Zoom to the spike region
sdp.setZoomRange(tNum(idx1) - 0.01, tNum(idx2) + 0.01);

fprintf('SensorDetailPlot with datetime x-axis.\n');
fprintf('  X-axis shows clock time (HH:MM)\n');
fprintf('  Spike visible around 09:15–09:18\n');
