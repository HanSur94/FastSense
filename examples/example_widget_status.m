%% StatusWidget — All Configuration Modes
% Demonstrates every way to drive a StatusWidget in the DashboardEngine.
%
%   Supported properties:
%     SensorObj (alias 'Sensor') — auto-derives ok/warning/alarm from the
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
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

%% 1. Create sensors with thresholds tuned for each status zone
rng(42);
N = 5000;
t = linspace(0, 3600, N);  % 1 hour

% Temperature — last value above Hi Alarm => red/alarm
sTemp = Sensor('T-401', 'Name', 'Temperature', 'Units', [char(176) 'C']);
sTemp.X = t;
sTemp.Y = 70 + 4*sin(2*pi*t/600) + randn(1,N)*0.5;
sTemp.Y(end-200:end) = 92 + randn(1,201)*0.3;        % push tail into alarm
sTemp.addThresholdRule(struct(), 80, 'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.addThresholdRule(struct(), 90, 'Direction', 'upper', 'Label', 'Hi Alarm');
sTemp.resolve();

% Pressure — last value between Hi Warn and Hi Alarm => yellow/warning
sPress = Sensor('P-201', 'Name', 'Pressure', 'Units', 'bar');
sPress.X = t;
sPress.Y = 48 + 3*sin(2*pi*t/900) + randn(1,N)*0.8;
sPress.Y(end-100:end) = 67 + randn(1,101)*0.4;       % push tail into warning
sPress.addThresholdRule(struct(), 65, 'Direction', 'upper', 'Label', 'Hi Warn');
sPress.addThresholdRule(struct(), 75, 'Direction', 'upper', 'Label', 'Hi Alarm');
sPress.resolve();

% Flow — last value well within limits => green/ok
sFlow = Sensor('F-301', 'Name', 'Flow Rate', 'Units', 'L/min');
sFlow.X = t;
sFlow.Y = 120 + 5*sin(2*pi*t/1200) + randn(1,N)*1.0;
sFlow.addThresholdRule(struct(), 140, 'Direction', 'upper', 'Label', 'Hi Alarm');
sFlow.addThresholdRule(struct(), 90,  'Direction', 'lower', 'Label', 'Lo Alarm');
sFlow.resolve();

%% 2. Build dashboard
d = DashboardEngine('Status Widget Demo');

% --- Row 1: status indicators across 24 columns ---
d.addWidget('status', 'Position', [1  1 5 1], 'Sensor', sTemp);   % alarm
d.addWidget('status', 'Position', [6  1 5 1], 'Sensor', sPress);  % warning
d.addWidget('status', 'Position', [11 1 5 1], 'Sensor', sFlow);   % ok

d.addWidget('status', 'Position', [16 1 5 1], ...
    'Title', 'Custom Check', 'StatusFcn', @() 'warning');

d.addWidget('status', 'Position', [21 1 4 1], ...
    'Title', 'Manual Override', 'StaticStatus', 'ok');

% --- Row 3+: FastPlot widgets showing the underlying sensor data ---
d.addWidget('fastplot', 'Position', [1  3 8 6], 'SensorObj', sTemp);
d.addWidget('fastplot', 'Position', [9  3 8 6], 'SensorObj', sPress);
d.addWidget('fastplot', 'Position', [17 3 8 6], 'SensorObj', sFlow);

%% 3. Render
d.render();

fprintf('Status demo: T-401=alarm, P-201=warning, F-301=ok\n');
fprintf('Violations: T-401=%d  P-201=%d  F-301=%d\n', ...
    sTemp.countViolations(), sPress.countViolations(), sFlow.countViolations());
