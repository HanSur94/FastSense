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
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Create 8 sensors in different status states

rng(42);
N = 1000;
t = linspace(0, 3600, N);  % 1 hour

% --- Green (ok) sensors: tail stays within normal range ---

% Temperature — ok (tail = 74, warn @ 80, alarm @ 90)
sTemp = SensorTag('T-401', 'Name', 'Temperature', 'Units', [char(176) 'F'], 'X', t, 'Y', 72 + 1.5*randn(1,N));
sTemp.Y(end-50:end) = 74;

% Flow Rate — ok (tail = 115, lo warn @ 90, hi alarm @ 160)
sFlow = SensorTag('F-301', 'Name', 'Flow Rate', 'Units', 'L/min', 'X', t, 'Y', 120 + 3*randn(1,N));
sFlow.Y(end-50:end) = 115;

% Tank Level — ok (tail = 52, lo warn @ 15, hi warn @ 85, hi alarm @ 95)
sLevel = SensorTag('L-102', 'Name', 'Tank Level', 'Units', '%', 'X', t, 'Y', 50 + 5*randn(1,N));
sLevel.Y(end-50:end) = 52;

% --- Yellow (warning) sensors: tail above warn but below alarm ---

% Pressure — warning (tail = 67, warn @ 65, alarm @ 75)
sPress = SensorTag('P-201', 'Name', 'Pressure', 'Units', 'psi', 'X', t, 'Y', 45 + 3*randn(1,N));
sPress.Y(end-50:end) = 67;

% Humidity — warning (tail = 82, warn @ 80, alarm @ 95)
sHumid = SensorTag('H-601', 'Name', 'Humidity', 'Units', '%RH', 'X', t, 'Y', 55 + 4*randn(1,N));
sHumid.Y(end-50:end) = 82;

% --- Red (alarm) sensors: tail above alarm threshold ---

% Motor Current — alarm (tail = 16, warn @ 12, alarm @ 15)
sCurrent = SensorTag('I-701', 'Name', 'Motor Current', 'Units', 'A', 'X', t, 'Y', 8.5 + 0.5*randn(1,N));
sCurrent.Y(end-50:end) = 16;

% Vibration RMS — alarm (tail = 4.5, warn @ 3, alarm @ 4)
sVib = SensorTag('V-501', 'Name', 'Vibration RMS', 'Units', 'mm/s', 'X', t, 'Y', max(0.1, 1.2 + 0.2*randn(1,N)));
sVib.Y(end-50:end) = 4.5;

% CO Level — alarm (tail = 28, warn @ 15, alarm @ 25)
sCO = SensorTag('GAS-1', 'Name', 'CO Level', 'Units', 'ppm', 'X', t, 'Y', 5 + 2*randn(1,N));
sCO.Y(end-50:end) = 28;

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
