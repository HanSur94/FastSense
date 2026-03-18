%% MultiStatusWidget — All Configurations Demo
% Demonstrates MultiStatusWidget with 8 sensors covering all three status
% zones (ok / warning / alarm) and compares 'dot' vs 'square' icon styles.
%
% MultiStatusWidget Properties:
%   Sensors    — cell array of Sensor objects, each with ThresholdRules.
%                Status colour is derived from the worst active threshold
%                violation at Y(end).
%   Columns    — number of columns in the indicator grid (default auto).
%   ShowLabels — show sensor Name below each indicator (default true).
%   IconStyle  — 'dot' (default) | 'square'.
%   Title      — widget title.
%   Position   — [col row width height] on the 24-column grid.
%
% Status derivation:
%   - No threshold violated → green  (ok)
%   - At least one Warning rule violated → yellow  (warning)
%   - At least one Alarm rule violated   → red     (alarm)
%
% Usage:
%   example_widget_multistatus

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

%% 1. Create 8 sensors in different status states

rng(42);
N = 1000;
t = linspace(0, 3600, N);  % 1 hour

% --- Green (ok) sensors: tail stays within normal range ---

% Temperature — ok (tail = 74, warn @ 80, alarm @ 90)
sTemp = Sensor('T-401', 'Name', 'Temperature', 'Units', [char(176) 'F']);
sTemp.X = t;
sTemp.Y = 72 + 1.5*randn(1,N);
sTemp.Y(end-50:end) = 74;
sTemp.addThresholdRule(struct(), 80, 'Direction', 'upper', 'Label', 'Hi Warn', ...
    'Color', [1 0.8 0], 'LineStyle', '--');
sTemp.addThresholdRule(struct(), 90, 'Direction', 'upper', 'Label', 'Hi Alarm', ...
    'Color', [1 0.2 0.2], 'LineStyle', '-');
sTemp.resolve();

% Flow Rate — ok (tail = 115, lo warn @ 90, hi alarm @ 160)
sFlow = Sensor('F-301', 'Name', 'Flow Rate', 'Units', 'L/min');
sFlow.X = t;
sFlow.Y = 120 + 3*randn(1,N);
sFlow.Y(end-50:end) = 115;
sFlow.addThresholdRule(struct(), 90,  'Direction', 'lower', 'Label', 'Lo Warn', ...
    'Color', [0.2 0.6 1], 'LineStyle', '--');
sFlow.addThresholdRule(struct(), 160, 'Direction', 'upper', 'Label', 'Hi Alarm', ...
    'Color', [1 0.2 0.2], 'LineStyle', '-');
sFlow.resolve();

% Tank Level — ok (tail = 52, lo warn @ 15, hi warn @ 85, hi alarm @ 95)
sLevel = Sensor('L-102', 'Name', 'Tank Level', 'Units', '%');
sLevel.X = t;
sLevel.Y = 50 + 5*randn(1,N);
sLevel.Y(end-50:end) = 52;
sLevel.addThresholdRule(struct(), 15, 'Direction', 'lower', 'Label', 'Lo Warn', ...
    'Color', [0.2 0.6 1], 'LineStyle', '--');
sLevel.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'Hi Warn', ...
    'Color', [1 0.8 0], 'LineStyle', '--');
sLevel.addThresholdRule(struct(), 95, 'Direction', 'upper', 'Label', 'Hi Alarm', ...
    'Color', [1 0.2 0.2], 'LineStyle', '-');
sLevel.resolve();

% --- Yellow (warning) sensors: tail above warn but below alarm ---

% Pressure — warning (tail = 67, warn @ 65, alarm @ 75)
sPress = Sensor('P-201', 'Name', 'Pressure', 'Units', 'psi');
sPress.X = t;
sPress.Y = 45 + 3*randn(1,N);
sPress.Y(end-50:end) = 67;
sPress.addThresholdRule(struct(), 65, 'Direction', 'upper', 'Label', 'Hi Warn', ...
    'Color', [1 0.8 0], 'LineStyle', '--');
sPress.addThresholdRule(struct(), 75, 'Direction', 'upper', 'Label', 'Hi Alarm', ...
    'Color', [1 0.2 0.2], 'LineStyle', '-');
sPress.resolve();

% Humidity — warning (tail = 82, warn @ 80, alarm @ 95)
sHumid = Sensor('H-601', 'Name', 'Humidity', 'Units', '%RH');
sHumid.X = t;
sHumid.Y = 55 + 4*randn(1,N);
sHumid.Y(end-50:end) = 82;
sHumid.addThresholdRule(struct(), 80, 'Direction', 'upper', 'Label', 'Hi Warn', ...
    'Color', [1 0.8 0], 'LineStyle', '--');
sHumid.addThresholdRule(struct(), 95, 'Direction', 'upper', 'Label', 'Hi Alarm', ...
    'Color', [1 0.2 0.2], 'LineStyle', '-');
sHumid.resolve();

% --- Red (alarm) sensors: tail above alarm threshold ---

% Motor Current — alarm (tail = 16, warn @ 12, alarm @ 15)
sCurrent = Sensor('I-701', 'Name', 'Motor Current', 'Units', 'A');
sCurrent.X = t;
sCurrent.Y = 8.5 + 0.5*randn(1,N);
sCurrent.Y(end-50:end) = 16;
sCurrent.addThresholdRule(struct(), 12, 'Direction', 'upper', 'Label', 'Hi Warn', ...
    'Color', [1 0.8 0], 'LineStyle', '--');
sCurrent.addThresholdRule(struct(), 15, 'Direction', 'upper', 'Label', 'Hi Alarm', ...
    'Color', [1 0.2 0.2], 'LineStyle', '-');
sCurrent.resolve();

% Vibration RMS — alarm (tail = 4.5, warn @ 3, alarm @ 4)
sVib = Sensor('V-501', 'Name', 'Vibration RMS', 'Units', 'mm/s');
sVib.X = t;
sVib.Y = max(0.1, 1.2 + 0.2*randn(1,N));
sVib.Y(end-50:end) = 4.5;
sVib.addThresholdRule(struct(), 3, 'Direction', 'upper', 'Label', 'Hi Warn', ...
    'Color', [1 0.8 0], 'LineStyle', '--');
sVib.addThresholdRule(struct(), 4, 'Direction', 'upper', 'Label', 'Hi Alarm', ...
    'Color', [1 0.2 0.2], 'LineStyle', '-');
sVib.resolve();

% CO Level — alarm (tail = 28, warn @ 15, alarm @ 25)
sCO = Sensor('GAS-1', 'Name', 'CO Level', 'Units', 'ppm');
sCO.X = t;
sCO.Y = 5 + 2*randn(1,N);
sCO.Y(end-50:end) = 28;
sCO.addThresholdRule(struct(), 15, 'Direction', 'upper', 'Label', 'Hi Warn', ...
    'Color', [1 0.8 0], 'LineStyle', '--');
sCO.addThresholdRule(struct(), 25, 'Direction', 'upper', 'Label', 'Hi Alarm', ...
    'Color', [1 0.2 0.2], 'LineStyle', '-');
sCO.resolve();

allSensors = {sTemp, sFlow, sLevel, sPress, sHumid, sCurrent, sVib, sCO};

%% 2. Build dashboard
d = DashboardEngine('Multi-Status Widget Demo');
d.Theme = 'light';

% Row 1-5: dot style (default) — 8 sensors, 4-column grid
d.addWidget('multistatus', 'Title', 'Plant Status Overview — Dot Style', ...
    'Position', [1 1 12 5], ...
    'Sensors', allSensors, ...
    'Columns', 4, ...
    'IconStyle', 'dot', ...
    'ShowLabels', true);

% Row 1-5: square style — same 8 sensors, 4-column grid
d.addWidget('multistatus', 'Title', 'Plant Status Overview — Square Style', ...
    'Position', [13 1 12 5], ...
    'Sensors', allSensors, ...
    'Columns', 4, ...
    'IconStyle', 'square', ...
    'ShowLabels', true);

% Row 6-8: compact dot — 8 sensors, 8-column grid, no labels
d.addWidget('multistatus', 'Title', 'Compact Status (no labels)', ...
    'Position', [1 6 24 3], ...
    'Sensors', allSensors, ...
    'Columns', 8, ...
    'IconStyle', 'dot', ...
    'ShowLabels', false);

% Row 9-14: FastSense context — one ok sensor, one alarm sensor
d.addWidget('fastsense', 'Position', [1 9 12 6], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [13 9 12 6], 'Sensor', sCurrent);

%% 3. Render
d.render();

fprintf('Dashboard rendered with %d widgets.\n', numel(d.Widgets));
fprintf('Status summary (8 sensors):\n');
fprintf('  ok:      T-401 (Temperature), F-301 (Flow Rate), L-102 (Tank Level)\n');
fprintf('  warning: P-201 (Pressure), H-601 (Humidity)\n');
fprintf('  alarm:   I-701 (Motor Current), V-501 (Vibration), GAS-1 (CO Level)\n');
