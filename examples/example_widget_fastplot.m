%% FastPlotWidget — All Configuration Modes
% Demonstrates every data-binding mode of FastPlotWidget inside
% DashboardEngine on a 24-column grid.
%
% Supported properties:
%   SensorObj   (alias 'Sensor')  — Sensor object for data binding
%   DataStoreObj (alias 'DataStore') — FastPlotDataStore for disk-backed data
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
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

%% 1. Generate shared process data
rng(42);
N = 5000;
t = linspace(0, 86400, N);  % 24 hours in seconds

% Machine mode state channel (idle=0, running=1)
scMode = StateChannel('machine');
scMode.X = [0, 7200, 43200, 57600];
scMode.Y = [0, 1,    0,     1    ];

% Temperature sensor — state-dependent thresholds
sTemp = Sensor('T-401', 'Name', 'Temperature', 'Units', [char(176) 'C']);
sTemp.X = t;
baseTemp = zeros(1, N);
for k = 1:N
    if scMode.valueAt(t(k)) == 1
        baseTemp(k) = 74;
    else
        baseTemp(k) = 66;
    end
end
sTemp.Y = baseTemp + 4*sin(2*pi*t/3600) + randn(1,N)*1.5;
sTemp.addStateChannel(scMode);
sTemp.addThresholdRule(struct('machine', 1), 80, ...
    'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.addThresholdRule(struct('machine', 1), 86, ...
    'Direction', 'upper', 'Label', 'Hi Alarm');
sTemp.addThresholdRule(struct('machine', 0), 72, ...
    'Direction', 'upper', 'Label', 'Idle Hi');
sTemp.resolve();

% Pressure sensor — simple unconditional thresholds
sPress = Sensor('P-201', 'Name', 'Pressure', 'Units', 'psi');
sPress.X = t;
sPress.Y = 50 + 15*sin(2*pi*t/7200) + randn(1,N)*2;
sPress.addThresholdRule(struct(), 62, ...
    'Direction', 'upper', 'Label', 'Hi Warn');
sPress.addThresholdRule(struct(), 68, ...
    'Direction', 'upper', 'Label', 'Hi Alarm');
sPress.resolve();

%% 2. Inline data — synthetic vibration signal (no Sensor)
x = linspace(0, 10, N);
y = 2.5*sin(2*pi*3*x) .* exp(-0.15*x) + 0.3*randn(1,N);

%% 3. Build dashboard — 2x2 grid of FastPlotWidgets
d = DashboardEngine('FastPlotWidget — Configuration Showcase');
d.Theme = 'light';

% Top-left: sensor-bound, auto thresholds + violations
d.addWidget('fastplot', ...
    'Position', [1 1 12 10], ...
    'Sensor', sTemp);

% Top-right: sensor-bound, thresholds disabled
d.addWidget('fastplot', ...
    'Position', [13 1 12 10], ...
    'Sensor', sPress, ...
    'Thresholds', false);

% Bottom-left: inline XData/YData with manual labels
d.addWidget('fastplot', ...
    'Position', [1 11 12 10], ...
    'XData', x, 'YData', y, ...
    'Title', 'Vibration Decay', ...
    'XLabel', 'Time [s]', ...
    'YLabel', 'Amplitude [g]');

% Bottom-right: sensor-bound with custom axis labels
d.addWidget('fastplot', ...
    'Position', [13 11 12 10], ...
    'Sensor', sTemp, ...
    'YLabel', ['Temperature [' char(176) 'F]'], ...
    'XLabel', 'Elapsed [s]');

%% 4. Render and print summary
d.render();

fprintf('Dashboard rendered with %d FastPlotWidgets.\n', numel(d.Widgets));
fprintf('Temperature violations: %d\n', sTemp.countViolations());
fprintf('Pressure violations:    %d\n', sPress.countViolations());
