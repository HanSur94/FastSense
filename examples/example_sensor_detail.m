%% example_sensor_detail.m — SensorDetailPlot demo
%
% Demonstrates:
%   1. Standalone sensor detail plot with thresholds
%   2. Adding events from EventStore
%   3. Embedding in a FastSenseGrid tile

%% Setup path
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

%% 1. Create sensor with realistic data
t = linspace(0, 300, 100000);  % 5 minutes at ~333 Hz
data = 50 + 8*sin(2*pi*t/60) + 3*randn(1, numel(t));

% Add a few spikes to trigger events
data(30000:30200) = data(30000:30200) + 20;  % spike at t~90
data(70000:70300) = data(70000:70300) + 25;  % bigger spike at t~210
data(50000:50100) = data(50000:50100) - 18;  % dip at t~150

s = Sensor('temperature', 'Name', 'Chamber Temperature');
s.X = t;
s.Y = data;

% Add state channel (constant state for simplicity)
sc = StateChannel('mode');
sc.X = [0 300];
sc.Y = [1 1];
s.addStateChannel(sc);

% Add threshold rules
s.addThresholdRule(struct('mode', 1), 62, ...
    'Direction', 'upper', 'Label', 'H Warning', ...
    'Color', [1 0.75 0], 'LineStyle', '--');
s.addThresholdRule(struct('mode', 1), 70, ...
    'Direction', 'upper', 'Label', 'HH Alarm', ...
    'Color', [1 0 0], 'LineStyle', '-');
s.addThresholdRule(struct('mode', 1), 38, ...
    'Direction', 'lower', 'Label', 'L Warning', ...
    'Color', [0.3 0.6 1], 'LineStyle', '--');

s.resolve();

%% 2. Create events matching the spikes
% Event is a handle class — setStats(peak, numPoints, min, max, mean, rms, std)
d1 = data(30000:30200);
ev1 = Event(t(30000), t(30200), 'temperature', 'H Warning', 62, 'upper');
ev1 = ev1.setStats(max(d1), numel(d1), min(d1), max(d1), mean(d1), rms(d1), std(d1));

d2 = data(70000:70300);
ev2 = Event(t(70000), t(70300), 'temperature', 'HH Alarm', 70, 'upper');
ev2 = ev2.setStats(max(d2), numel(d2), min(d2), max(d2), mean(d2), rms(d2), std(d2));

d3 = data(50000:50100);
ev3 = Event(t(50000), t(50100), 'temperature', 'L Warning', 38, 'lower');
ev3 = ev3.setStats(min(d3), numel(d3), min(d3), max(d3), mean(d3), rms(d3), std(d3));

events = [ev1, ev2, ev3];

%% 3. Standalone with events
fprintf('=== SensorDetailPlot: Standalone with events ===\n');
sdp = SensorDetailPlot(s, ...
    'Theme', 'light', ...
    'Events', events, ...
    'Title', 'Chamber Temperature — Detail View');
sdp.render();

% Programmatic zoom to the first event
sdp.setZoomRange(t(29000), t(31500));

fprintf('  Try: zoom/pan in the main plot, or drag the navigator highlight.\n');
fprintf('  Press any key to continue...\n');
pause;

%% 4. Standalone without events (thresholds only)
fprintf('=== SensorDetailPlot: Thresholds only ===\n');
sdp2 = SensorDetailPlot(s, ...
    'Theme', 'light', ...
    'NavigatorHeight', 0.25, ...
    'Title', 'Chamber Temperature — Thresholds Only');
sdp2.render();

fprintf('  Press any key to continue...\n');
pause;

%% 5. Embedded in FastSenseGrid
fprintf('=== SensorDetailPlot: Embedded in FastSenseGrid ===\n');
fig = FastSenseGrid(1, 2, 'Theme', 'light', 'Name', 'Sensor Dashboard');
sdp3 = SensorDetailPlot(s, 'Parent', fig.tilePanel(1), ...
    'Events', events, 'Title', 'Temperature');
sdp3.render();

% Second tile: plain FastSense for comparison
fp = fig.tile(2);
fp.addLine(t, data, 'DisplayName', 'Raw Data');
fig.setTileTitle(2, 'Raw Data');
fig.renderAll();

fprintf('  Two tiles: SensorDetailPlot + plain FastSense\n');
fprintf('  Press any key to exit...\n');
pause;

fprintf('Done.\n');
