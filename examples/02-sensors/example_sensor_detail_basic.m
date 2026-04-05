%% SensorDetailPlot — Minimal Quick-Start
% Simplest possible SensorDetailPlot: one sensor, no events, default options.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% Create a sensor with some data
t = linspace(0, 60, 20000);  % 1 minute at ~333 Hz
data = 25 + 5*sin(2*pi*t/15) + randn(1, numel(t));

s = Sensor('vibration', 'Name', 'Motor Vibration');
s.X = t;
s.Y = data;

%% Plot it — one line is all you need
sdp = SensorDetailPlot(s);
sdp.render();

fprintf('SensorDetailPlot with defaults.\n');
fprintf('  - Zoom/pan in the upper panel\n');
fprintf('  - Drag the navigator highlight in the lower panel\n');
fprintf('  - Drag the edges to resize the visible range\n');
fprintf('  - Click outside the highlight to jump\n');

%% Programmatic zoom
fprintf('\nZooming to t=[10, 30]...\n');
sdp.setZoomRange(10, 30);

%% Query current range
[xMin, xMax] = sdp.getZoomRange();
fprintf('Current zoom range: [%.1f, %.1f]\n', xMin, xMax);
