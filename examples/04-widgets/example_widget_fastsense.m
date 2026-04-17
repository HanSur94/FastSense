%% FastSenseWidget — All Configuration Modes
% Demonstrates every data-binding mode of FastSenseWidget inside
% DashboardEngine on a 24-column grid.
%
% Supported properties:
%   SensorObj   (alias 'Tag')  — Sensor object for data binding
%   DataStoreObj (alias 'DataStore') — FastSenseDataStore for disk-backed data
%   XData, YData                  — inline numeric arrays
%   File, XVar, YVar              — load from .mat file
%   Thresholds                    — 'auto' (default, from Sensor) | false
%   XLabel, YLabel                — axis labels (auto-derived from Sensor)
%   Title                         — widget title (auto-derived from Sensor.Name)
%   Position                      — [col row width height] on 24-column grid
%
% Layout (2x2):
%   Top-left:     Sensor-bound, auto thresholds
%   Top-right:    Sensor-bound, thresholds off
%   Bottom-left:  Inline data, manual labels
%   Bottom-right: Sensor-bound, custom labels

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Generate shared process data
rng(42);
N = 5000;
t = linspace(0, 86400, N);  % 24 hours in seconds

% Machine mode state channel (idle=0, running=1)
scMode = StateTag('machine', 'X', [0, 7200, 43200, 57600], 'Y', [0, 1,    0,     1]);

% Temperature sensor — state-dependent thresholds
baseTemp = zeros(1, N);
for k = 1:N
    if scMode.valueAt(t(k)) == 1
        baseTemp(k) = 74;
    else
        baseTemp(k) = 66;
    end
end
yTemp = baseTemp + 4*sin(2*pi*t/3600) + randn(1,N)*1.5;
sTemp = SensorTag('T-401', 'Name', 'Temperature', 'Units', [char(176) 'C'], 'X', t, 'Y', yTemp);

% Pressure sensor — simple unconditional thresholds
sPress = SensorTag('P-201', 'Name', 'Pressure', 'Units', 'psi', 'X', t, 'Y', 50 + 15*sin(2*pi*t/7200) + randn(1,N)*2);

%% 2. Inline data — synthetic vibration signal (no Sensor)
x = linspace(0, 10, N);
y = 2.5*sin(2*pi*3*x) .* exp(-0.15*x) + 0.3*randn(1,N);

%% 3. Build dashboard — 2x2 grid of FastSenseWidgets
d = DashboardEngine('FastSenseWidget — Configuration Showcase');
d.Theme = 'light';

% Top-left: sensor-bound, auto thresholds + violations
d.addWidget('fastsense', ...
    'Position', [1 1 12 10], ...
    'Tag', sTemp);

% Top-right: sensor-bound, thresholds disabled
d.addWidget('fastsense', ...
    'Position', [13 1 12 10], ...
    'Tag', sPress, ...
    'Thresholds', false);

% Bottom-left: inline XData/YData with manual labels and fixed YLimits
d.addWidget('fastsense', ...
    'Position', [1 11 12 10], ...
    'XData', x, 'YData', y, ...
    'Title', 'Vibration Decay (fixed Y range)', ...
    'XLabel', 'Time [s]', ...
    'YLabel', 'Amplitude [g]', ...
    'YLimits', [-4 4]);

% Bottom-right: sensor-bound with threshold labels and custom axis labels
d.addWidget('fastsense', ...
    'Position', [13 11 12 10], ...
    'Tag', sTemp, ...
    'ShowThresholdLabels', true, ...
    'YLabel', ['Temperature [' char(176) 'F]'], ...
    'XLabel', 'Elapsed [s]');

%% 4. Render and print summary
d.render();

fprintf('Dashboard rendered with %d FastSenseWidgets.\n', numel(d.Widgets));
