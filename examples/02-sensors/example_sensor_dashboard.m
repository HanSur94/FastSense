%% Multi-Sensor Dashboard — FastSenseGrid + TagRegistry
% Demonstrates:
%   - FastSenseGrid tiled layout (2x2 grid)
%   - TagRegistry for predefined sensor definitions
%   - Multiple sensors each with different threshold configurations
%   - Tile titles, labels, and per-tile theming
%   - renderAll() for batch rendering

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

% --- Shared state channel (machine state for all sensors) ---
scMachine = StateTag('machine', 'X', [0  20  50  80], 'Y', [0   1   2   1]);

% ========================================================
% Sensor 1: Chamber Pressure (from registry, add thresholds)
% ========================================================
s1 = TagRegistry.get('pressure');
s1.Units = 'mbar';
t1 = linspace(0, 100, 10000);
s1.updateData(t1, 40 + 20*sin(2*pi*t1/25) + 4*randn(1, numel(t1)));


% ========================================================
% Sensor 2: Chamber Temperature (from registry, static thresholds)
% ========================================================
s2 = TagRegistry.get('temperature');
s2.Units = [char(176) 'C'];
t2 = linspace(0, 100, 8000);
s2_y_ = 22 + 5*sin(2*pi*t2/40) + 1.5*randn(1, numel(t2));
s2_y_(3000:3100) = s2_y_(3000:3100) + 12;  % spike
s2.updateData(t2, s2_y_);


% ========================================================
% Sensor 3: Vibration (manual, static thresholds)
% ========================================================
s3 = SensorTag('vibration', 'Name', 'Motor Vibration', 'ID', 201, 'Units', 'g');
t3 = linspace(0, 100, 12000);
s3_y_ = 3 + 1.2*sin(2*pi*t3/15) + 0.5*randn(1, numel(t3));
s3_y_(7000:7050) = s3_y_(7000:7050) + 5;
s3.updateData(t3, s3_y_);


% ========================================================
% Sensor 4: Gas Flow (manual, state-dependent + lower)
% ========================================================
s4 = SensorTag('flow', 'Name', 'Gas Flow Rate', 'ID', 301, 'Units', 'sccm');
t4 = linspace(0, 100, 10000);
s4_y_ = 50 + 10*sin(2*pi*t4/18) + 3*randn(1, numel(t4));
s4_y_(5000:5200) = s4_y_(5000:5200) - 30;
s4.updateData(t4, s4_y_);


% ========================================================
% Build 2x2 dashboard with FastSenseGrid
% ========================================================
fig = FastSenseGrid(2, 2, 'Name', 'Sensor Dashboard');

% Tile 1: Pressure
fp1 = fig.tile(1);
fp1.addTag(s1, 'ShowThresholds', true);
fig.setTileTitle(1, 'Chamber Pressure');
fig.setTileYLabel(1, 'Pressure [mbar]');

% Tile 2: Temperature
fp2 = fig.tile(2);
fp2.addTag(s2, 'ShowThresholds', true);
fig.setTileTitle(2, 'Chamber Temperature');
fig.setTileYLabel(2, 'Temperature [°C]');

% Tile 3: Vibration
fp3 = fig.tile(3);
fp3.addTag(s3, 'ShowThresholds', true);
fig.setTileTitle(3, 'Motor Vibration');
fig.setTileXLabel(3, 'Time [s]');
fig.setTileYLabel(3, 'Acceleration [g]');

% Tile 4: Gas Flow
fp4 = fig.tile(4);
fp4.addTag(s4, 'ShowThresholds', true);
fig.setTileTitle(4, 'Gas Flow Rate');
fig.setTileXLabel(4, 'Time [s]');
fig.setTileYLabel(4, 'Flow [sccm]');

% Render all tiles at once
fig.renderAll();

% --- Also list available registry sensors ---
fprintf('\n=== TagRegistry catalog ===\n');
TagRegistry.list();
