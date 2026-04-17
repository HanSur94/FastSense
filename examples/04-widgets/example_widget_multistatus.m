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
sTemp = SensorTag('T-401', 'Name', 'Temperature', 'Units', [char(176) 'F']);
sTemp_x_ = t;
sTemp_y_ = 72 + 1.5*randn(1,N);
sTemp_y_(end-50:end) = 74;
sTemp.updateData(sTemp_x_, sTemp_y_);
% Flow Rate — ok (tail = 115, lo warn @ 90, hi alarm @ 160)
sFlow = SensorTag('F-301', 'Name', 'Flow Rate', 'Units', 'L/min');
sFlow_x_ = t;
sFlow_y_ = 120 + 3*randn(1,N);
sFlow_y_(end-50:end) = 115;
sFlow.updateData(sFlow_x_, sFlow_y_);
% Tank Level — ok (tail = 52, lo warn @ 15, hi warn @ 85, hi alarm @ 95)
sLevel = SensorTag('L-102', 'Name', 'Tank Level', 'Units', '%');
sLevel_x_ = t;
sLevel_y_ = 50 + 5*randn(1,N);
sLevel_y_(end-50:end) = 52;
sLevel.updateData(sLevel_x_, sLevel_y_);
% --- Yellow (warning) sensors: tail above warn but below alarm ---

% Pressure — warning (tail = 67, warn @ 65, alarm @ 75)
sPress = SensorTag('P-201', 'Name', 'Pressure', 'Units', 'psi');
sPress_x_ = t;
sPress_y_ = 45 + 3*randn(1,N);
sPress_y_(end-50:end) = 67;
sPress.updateData(sPress_x_, sPress_y_);
% Humidity — warning (tail = 82, warn @ 80, alarm @ 95)
sHumid = SensorTag('H-601', 'Name', 'Humidity', 'Units', '%RH');
sHumid_x_ = t;
sHumid_y_ = 55 + 4*randn(1,N);
sHumid_y_(end-50:end) = 82;
sHumid.updateData(sHumid_x_, sHumid_y_);
% --- Red (alarm) sensors: tail above alarm threshold ---

% Motor Current — alarm (tail = 16, warn @ 12, alarm @ 15)
sCurrent = SensorTag('I-701', 'Name', 'Motor Current', 'Units', 'A');
sCurrent_x_ = t;
sCurrent_y_ = 8.5 + 0.5*randn(1,N);
sCurrent_y_(end-50:end) = 16;
sCurrent.updateData(sCurrent_x_, sCurrent_y_);
% Vibration RMS — alarm (tail = 4.5, warn @ 3, alarm @ 4)
sVib = SensorTag('V-501', 'Name', 'Vibration RMS', 'Units', 'mm/s');
sVib_x_ = t;
sVib_y_ = max(0.1, 1.2 + 0.2*randn(1,N));
sVib_y_(end-50:end) = 4.5;
sVib.updateData(sVib_x_, sVib_y_);
% CO Level — alarm (tail = 28, warn @ 15, alarm @ 25)
sCO = SensorTag('GAS-1', 'Name', 'CO Level', 'Units', 'ppm');
sCO_x_ = t;
sCO_y_ = 5 + 2*randn(1,N);
sCO_y_(end-50:end) = 28;
sCO.updateData(sCO_x_, sCO_y_);
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
