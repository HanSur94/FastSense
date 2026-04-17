%% IconCardWidget — All Binding Modes
% Demonstrates every data-source mode of the IconCardWidget inside a
% DashboardEngine dashboard.
%
% IconCardWidget properties:
%   IconColor      - RGB triplet [r g b] or 'auto' (derive color from threshold state).
%                    'auto' maps: ok=green, warn=yellow, alarm=red, info=blue, inactive=gray.
%   StaticValue    - Fixed numeric value displayed when no Sensor or ValueFcn is set.
%   ValueFcn       - function_handle returning a scalar or a struct with field .value
%                    (and optionally .unit for runtime unit override).
%   StaticState    - Override state string: 'ok','warn','alarm','info','inactive',''.
%                    Empty string = derive state automatically from thresholds.
%   Units          - Display units string appended after the numeric value.
%                    Auto-populated from Sensor.Units when a Sensor is bound.
%   Format         - sprintf format string for the numeric value (default '%.1f').
%   SecondaryLabel - Subtitle text below the primary value; defaults to Title when empty.
%   Position       - [col row width height] on the 24-column grid (1-based).

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Create Sensors with thresholds to drive state color
rng(42);
N = 5000;
t = linspace(0, 3600, N);  % 1 hour in seconds

% Pump speed — last value above Hi Alarm => alarm (red)
sPump = SensorTag('M-101', 'Name', 'Pump Speed', 'Units', 'RPM', 'X', t, 'Y', 2800 + 150*sin(2*pi*t/600) + randn(1,N)*20);
sPump.Y(end-200:end) = 3250 + randn(1,201)*10;   % push tail into alarm

% Coolant temp — last value within normal range => ok (green)
sCool = SensorTag('T-202', 'Name', 'Coolant Temp', 'Units', [char(176) 'C'], 'X', t, 'Y', 45 + 5*sin(2*pi*t/900) + randn(1,N)*0.5);

%% 2. Build Dashboard
d = DashboardEngine('IconCardWidget Demo');
d.Theme = 'dark';

% --- Sensor-bound: alarm state (icon auto-red, value from Sensor.Y) ---
d.addWidget('iconcard', ...
    'Title', 'Pump Speed', ...
    'Position', [1 1 6 2], ...
    'Sensor', sPump);

% --- Sensor-bound: ok state (icon auto-green) ---
d.addWidget('iconcard', ...
    'Title', 'Coolant Temp', ...
    'Position', [7 1 6 2], ...
    'Sensor', sCool);

% --- ValueFcn returning a scalar + explicit StaticState override ---
d.addWidget('iconcard', 'Title', 'Batch Count', ...
    'Position', [13 1 6 2], ...
    'ValueFcn', @() 147, ...
    'Units', 'parts', ...
    'Format', '%d', ...
    'StaticState', 'info');

% --- StaticValue with explicit IconColor [r g b] override (no state) ---
d.addWidget('iconcard', 'Title', 'Oil Level', ...
    'Position', [19 1 6 2], ...
    'StaticValue', 82.4, ...
    'Units', '%', ...
    'IconColor', [0.2 0.6 0.9], ...
    'StaticState', 'inactive');

% --- StaticValue with SecondaryLabel override (no sensor, no callback) ---
d.addWidget('iconcard', 'Title', 'Efficiency', ...
    'Position', [1 3 6 2], ...
    'StaticValue', 94.7, ...
    'Units', '%', ...
    'Format', '%.1f', ...
    'SecondaryLabel', 'Last 24 h avg', ...
    'StaticState', 'ok');

% --- ValueFcn returning struct (.value + .unit) with warn state ---
d.addWidget('iconcard', 'Title', 'Vibration', ...
    'Position', [7 3 6 2], ...
    'ValueFcn', @() struct('value', 4.7, 'unit', 'mm/s'), ...
    'StaticState', 'warn');

% --- FastSense widget below for visual context ---
d.addWidget('fastsense', ...
    'Position', [1 5 12 8], ...
    'Sensor', sPump);

d.addWidget('fastsense', ...
    'Position', [13 5 12 8], ...
    'Sensor', sCool);

%% 3. Render
d.render();

fprintf('Dashboard rendered with %d widgets.\n', numel(d.Widgets));
fprintf('  Pump Speed  : %.1f RPM  (state: alarm — above 3100 RPM threshold)\n', sPump.Y(end));
fprintf('  Coolant Temp: %.1f %sC   (state: ok — well below 70 deg threshold)\n', sCool.Y(end), char(176));
fprintf('  Batch Count : 147 parts (state: info — explicit StaticState)\n');
fprintf('  Oil Level   : 82.4 %%    (state: inactive — explicit IconColor override)\n');
fprintf('  Efficiency  : 94.7 %%    (state: ok — SecondaryLabel="Last 24 h avg")\n');
fprintf('  Vibration   : 4.7 mm/s  (state: warn — explicit StaticState)\n');
