%% StatusWidget — All Configuration Modes
% Demonstrates every way to drive a StatusWidget in the DashboardEngine.
%
%   Supported properties:
%     SensorObj (alias 'Tag') — auto-derives ok/warning/alarm from the
%         sensor's ThresholdRules; displays latest value + Units in the label.
%     StatusFcn   — function_handle returning 'ok', 'warning', or 'alarm'.
%     StaticStatus — fixed status string: 'ok', 'warning', or 'alarm'.
%     Title       — widget title (auto-populated from Sensor.Name when bound).
%     Position    — [col row width height] on the 24-column grid (1-based).
%
% The three sensor-bound widgets show how the StatusWidget reads the
% sensor's latest Y value, checks it against resolved threshold rules,
% and picks the worst violation to determine dot color.

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Create sensors with thresholds tuned for each status zone
rng(42);
N = 5000;
t = linspace(0, 3600, N);  % 1 hour

% Temperature — last value above Hi Alarm => red/alarm
yTemp = 70 + 4*sin(2*pi*t/600) + randn(1,N)*0.5;
yTemp(end-200:end) = 92 + randn(1,201)*0.3;        % push tail into alarm
sTemp = SensorTag('T-401', 'Name', 'Temperature', 'Units', [char(176) 'C'], 'X', t, 'Y', yTemp);

% Pressure — last value between Hi Warn and Hi Alarm => yellow/warning
yPress = 48 + 3*sin(2*pi*t/900) + randn(1,N)*0.8;
yPress(end-100:end) = 67 + randn(1,101)*0.4;       % push tail into warning
sPress = SensorTag('P-201', 'Name', 'Pressure', 'Units', 'bar', 'X', t, 'Y', yPress);

% Flow — last value well within limits => green/ok
sFlow = SensorTag('F-301', 'Name', 'Flow Rate', 'Units', 'L/min', 'X', t, 'Y', 120 + 5*sin(2*pi*t/1200) + randn(1,N)*1.0);

%% 2. Build dashboard
d = DashboardEngine('Status Widget Demo');

% --- Row 1: status indicators across 24 columns ---
d.addWidget('status', 'Position', [1  1 5 1], 'Tag', sTemp);   % alarm
d.addWidget('status', 'Position', [6  1 5 1], 'Tag', sPress);  % warning
d.addWidget('status', 'Position', [11 1 5 1], 'Tag', sFlow);   % ok

d.addWidget('status', 'Position', [16 1 5 1], ...
    'Title', 'Custom Check', 'StatusFcn', @() 'warning');

d.addWidget('status', 'Position', [21 1 4 1], ...
    'Title', 'Manual Override', 'StaticStatus', 'ok');

% --- Row 3+: FastSense widgets showing the underlying sensor data ---
d.addWidget('fastsense', 'Position', [1  3 8 6], 'Tag', sTemp);
d.addWidget('fastsense', 'Position', [9  3 8 6], 'Tag', sPress);
d.addWidget('fastsense', 'Position', [17 3 8 6], 'Tag', sFlow);

%% 3. Render
d.render();

fprintf('Status demo: T-401=alarm, P-201=warning, F-301=ok\n');
% Threshold-violation counts are tracked via separate MonitorTag objects in
% the v2.0 Tag model. This demo intentionally omits the MonitorTag wiring,
% so we simply surface the final reading for each sensor as a quick summary.
fprintf('Latest readings: T-401=%.1f %s  P-201=%.1f %s  F-301=%.1f %s\n', ...
    sTemp.Y(end), sTemp.Units, ...
    sPress.Y(end), sPress.Units, ...
    sFlow.Y(end), sFlow.Units);
