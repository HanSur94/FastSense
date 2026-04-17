%% SparklineCardWidget — All Binding Modes
% Demonstrates every data-source and display configuration of the
% SparklineCardWidget inside a DashboardEngine dashboard.
%
% SparklineCardWidget properties:
%   StaticValue  — Fixed scalar value when no Sensor or ValueFcn is provided.
%   ValueFcn     — function_handle returning a scalar or a struct with .value
%                  (and optionally .unit for runtime unit override).
%   Units        — Display unit string appended after the primary value.
%                  Auto-populated from Sensor.Units when a Sensor is bound.
%   Format       — sprintf format string for the primary value (default '%.1f').
%   NSparkPoints — Number of tail data points shown in sparkline (default 50).
%   ShowDelta    — Whether to show the delta indicator in the top-right corner
%                  (default true).  Delta = last point minus first sparkline point.
%   DeltaFormat  — sprintf format for the delta value (default '%+.1f').
%   SparkColor   — [r g b] sparkline line color; empty => theme DragHandleColor.
%   SparkData    — Numeric vector for the sparkline when no Sensor is bound.
%   Position     — [col row width height] on the 24-column grid (1-based).
%
% Data binding priority: Sensor > ValueFcn > StaticValue + SparkData.

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Create Sensors with varied signal shapes
rng(42);
N = 500;
t = linspace(0, 3600, N);

sCpu = SensorTag('CPU-1', 'Name', 'CPU Load', 'Units', '%');
sCpu.updateData(t, 55 + 20*sin(2*pi*t/900) + randn(1,N)*3);
[sCpu_x_, sCpu_y_] = sCpu.getXY();
sCpu_y_ = max(0, min(100, sCpu_y_));

sMem = SensorTag('MEM-1', 'Name', 'Memory', 'Units', 'GB');
sMem.updateData(t, 12 + 4*sin(2*pi*t/1800) + randn(1,N)*0.2);
[sMem_x_, sMem_y_] = sMem.getXY();

sNet = SensorTag('NET-1', 'Name', 'Network I/O', 'Units', 'MB/s');
sNet.updateData(t, max(0, 85 + 50*randn(1,N)*0.1 + 30*sin(2*pi*t/300)));

%% 2. Build Dashboard
d = DashboardEngine('SparklineCardWidget Demo');
d.Theme = 'dark';

% --- Row 1: four SparklineCardWidget cards ---

% Card 1: Sensor-bound (auto value + sparkline from Sensor.Y, auto units)
d.addWidget('sparkline', ...
    'Title', 'CPU Load', ...
    'Position', [1 1 6 3], ...
    'Sensor', sCpu);

% Card 2: ValueFcn + explicit SparkData vector (separate sparkline source)
sparkHistory = 60 + 10*sin(linspace(0, 4*pi, 80)) + randn(1,80)*2;
d.addWidget('sparkline', 'Title', 'Disk I/O', ...
    'Position', [7 1 6 3], ...
    'ValueFcn', @() 47.3, ...
    'Units', 'MB/s', ...
    'SparkData', sparkHistory, ...
    'NSparkPoints', 80);

% Card 3: StaticValue + SparkData with custom SparkColor and DeltaFormat
staticSpark = cumsum(randn(1,60)) + 30;
d.addWidget('sparkline', 'Title', 'Queue Depth', ...
    'Position', [13 1 6 3], ...
    'StaticValue', staticSpark(end), ...
    'Units', 'jobs', ...
    'Format', '%d', ...
    'SparkData', staticSpark, ...
    'SparkColor', [0.95 0.55 0.15], ...
    'DeltaFormat', '%+.0f');

% Card 4: ShowDelta=false variant (no delta indicator, just value + sparkline)
d.addWidget('sparkline', 'Title', 'Memory', ...
    'Position', [19 1 6 3], ...
    'Sensor', sMem, ...
    'ShowDelta', false, ...
    'SparkColor', [0.30 0.75 0.95]);

%% 3. FastSense plots for context
d.addWidget('fastsense', 'Position', [1  5 8 8], 'Sensor', sCpu);
d.addWidget('fastsense', 'Position', [9  5 8 8], 'Sensor', sMem);
d.addWidget('fastsense', 'Position', [17 5 8 8], 'Sensor', sNet);

%% 4. Render
d.render();

fprintf('Dashboard rendered with %d widgets.\n', numel(d.Widgets));
fprintf('  CPU Load   : %.1f %% (sensor-bound, auto sparkline)\n', sCpu_y_(end));
fprintf('  Disk I/O   : 47.3 MB/s (ValueFcn + explicit SparkData)\n');
fprintf('  Queue Depth: %d jobs  (StaticValue + SparkData + custom SparkColor)\n', round(staticSpark(end)));
fprintf('  Memory     : %.1f GB (Sensor, ShowDelta=false)\n', sMem_y_(end));
