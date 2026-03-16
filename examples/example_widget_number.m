%% NumberWidget — All Configurations
% Demonstrates every data-source mode of the NumberWidget inside a
% DashboardEngine dashboard.
%
% NumberWidget properties:
%   SensorObj  — Sensor object (alias: 'Sensor').  Auto-derives value from
%                Y(end), Units from Sensor.Units, and trend arrow from
%                recent slope.
%   ValueFcn   — function_handle returning a scalar (displayed as-is) or a
%                struct with fields: value, unit, trend ('up'/'down'/'flat').
%   StaticValue — fixed numeric value (no callback, no sensor).
%   Units       — unit label string.  Auto-populated from Sensor.Units when
%                 empty and a Sensor is bound.
%   Format      — sprintf format string (default '%.1f').
%   Title       — widget title.  Auto-populated from Sensor.Name when empty.
%   Position    — [col row width height] on the 24-column grid.

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

%% 1. Create Sensors
rng(42);
N = 5000;
t = linspace(0, 86400, N);  % 24 h in seconds

sTemp = Sensor('T-401', 'Name', 'Temperature', 'Units', [char(176) 'F']);
sTemp.X = t;
sTemp.Y = 72 + 4*sin(2*pi*t/3600) + randn(1,N)*0.6;

sPress = Sensor('P-201', 'Name', 'Pressure', 'Units', 'psi');
sPress.X = t;
sPress.Y = 55 + 10*sin(2*pi*t/7200) + randn(1,N)*1.2;

sFlow = Sensor('F-301', 'Name', 'Flow Rate', 'Units', 'L/min');
sFlow.X = t;
sFlow.Y = max(0, 120 + 8*sin(2*pi*t/1800) + randn(1,N)*3);

%% 2. Build Dashboard
d = DashboardEngine('NumberWidget Demo');
d.Theme = 'light';

% --- Sensor-bound: auto value + trend + units ---
d.addWidget('number', ...
    'Position', [1 1 5 2], ...
    'Sensor', sTemp);

% --- Sensor-bound with custom format ---
d.addWidget('number', ...
    'Position', [6 1 5 2], ...
    'Sensor', sPress, ...
    'Format', '%.0f');

% --- ValueFcn returning a scalar ---
d.addWidget('number', 'Title', 'Flow Rate', ...
    'Position', [11 1 5 2], ...
    'ValueFcn', @() sFlow.Y(end), ...
    'Units', 'L/min', ...
    'Format', '%.1f');

% --- ValueFcn returning a struct (value + unit + trend) ---
d.addWidget('number', 'Title', 'Temp (struct)', ...
    'Position', [16 1 5 2], ...
    'ValueFcn', @() struct('value', sTemp.Y(end), ...
                           'unit',  [char(176) 'F'], ...
                           'trend', 'up'));

% --- StaticValue (no callback, no sensor) ---
d.addWidget('number', 'Title', 'Batch Count', ...
    'Position', [21 1 4 2], ...
    'StaticValue', 42, ...
    'Units', 'items', ...
    'Format', '%d');

% --- FastPlot for visual context ---
d.addWidget('fastplot', ...
    'Position', [1 3 24 10], ...
    'SensorObj', sTemp);

%% 3. Render
d.render();

fprintf('Dashboard rendered with %d widgets.\n', numel(d.Widgets));
fprintf('  Temperature : %.1f %sF\n', sTemp.Y(end), char(176));
fprintf('  Pressure    : %.0f psi\n', sPress.Y(end));
fprintf('  Flow Rate   : %.1f L/min\n', sFlow.Y(end));
fprintf('  Batch Count : 42 items (static)\n');
