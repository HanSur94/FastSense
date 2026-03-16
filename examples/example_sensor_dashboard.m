%% Multi-Sensor Dashboard — FastPlotFigure + SensorRegistry
% Demonstrates:
%   - FastPlotFigure tiled layout (2x2 grid)
%   - SensorRegistry for predefined sensor definitions
%   - Multiple sensors each with different threshold configurations
%   - Tile titles, labels, and per-tile theming
%   - renderAll() for batch rendering

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

% --- Shared state channel (machine state for all sensors) ---
scMachine = StateChannel('machine');
scMachine.X = [0  20  50  80];
scMachine.Y = [0   1   2   1];

% ========================================================
% Sensor 1: Chamber Pressure (from registry, add thresholds)
% ========================================================
s1 = SensorRegistry.get('pressure');
t1 = linspace(0, 100, 10000);
s1.X = t1;
s1.Y = 40 + 20*sin(2*pi*t1/25) + 4*randn(1, numel(t1));
s1.addStateChannel(scMachine);

s1.addThresholdRule(struct('machine', 0), 75, ...
    'Direction', 'upper', 'Label', 'HH (idle)', ...
    'Color', [0.9 0.4 0.1], 'LineStyle', '--');
s1.addThresholdRule(struct('machine', 1), 60, ...
    'Direction', 'upper', 'Label', 'HH (running)', ...
    'Color', [0.9 0.1 0.1], 'LineStyle', '--');
s1.addThresholdRule(struct('machine', 2), 50, ...
    'Direction', 'upper', 'Label', 'HH (evacuated)', ...
    'Color', [1 0 0], 'LineStyle', '-');
s1.resolve();

% ========================================================
% Sensor 2: Chamber Temperature (from registry, static thresholds)
% ========================================================
s2 = SensorRegistry.get('temperature');
t2 = linspace(0, 100, 8000);
s2.X = t2;
s2.Y = 22 + 5*sin(2*pi*t2/40) + 1.5*randn(1, numel(t2));
s2.Y(3000:3100) = s2.Y(3000:3100) + 12;  % spike

s2.addThresholdRule(struct(), 30, ...
    'Direction', 'upper', 'Label', 'High Temp', ...
    'Color', [0.9 0.1 0.1], 'LineStyle', '--');
s2.addThresholdRule(struct(), 15, ...
    'Direction', 'lower', 'Label', 'Low Temp', ...
    'Color', [0.1 0.1 0.9], 'LineStyle', '--');
s2.resolve();

% ========================================================
% Sensor 3: Vibration (manual, static thresholds)
% ========================================================
s3 = Sensor('vibration', 'Name', 'Motor Vibration', 'ID', 201);
t3 = linspace(0, 100, 12000);
s3.X = t3;
s3.Y = 3 + 1.2*sin(2*pi*t3/15) + 0.5*randn(1, numel(t3));
s3.Y(7000:7050) = s3.Y(7000:7050) + 5;

s3.addThresholdRule(struct(), 5.5, ...
    'Direction', 'upper', 'Label', 'Vib Alarm', ...
    'Color', [0.8 0.2 0], 'LineStyle', '--');
s3.resolve();

% ========================================================
% Sensor 4: Gas Flow (manual, state-dependent + lower)
% ========================================================
s4 = Sensor('flow', 'Name', 'Gas Flow Rate', 'ID', 301);
t4 = linspace(0, 100, 10000);
s4.X = t4;
s4.Y = 50 + 10*sin(2*pi*t4/18) + 3*randn(1, numel(t4));
s4.Y(5000:5200) = s4.Y(5000:5200) - 30;
s4.addStateChannel(scMachine);

s4.addThresholdRule(struct('machine', 1), 65, ...
    'Direction', 'upper', 'Label', 'Flow HH', ...
    'Color', [0.9 0.1 0.1], 'LineStyle', '--');
s4.addThresholdRule(struct('machine', 2), 25, ...
    'Direction', 'lower', 'Label', 'Flow LL', ...
    'Color', [0.1 0.1 0.9], 'LineStyle', '-');
s4.resolve();

% ========================================================
% Build 2x2 dashboard with FastPlotFigure
% ========================================================
fig = FastPlotFigure(2, 2, 'Name', 'Sensor Dashboard');

% Tile 1: Pressure
fp1 = fig.tile(1);
fp1.addSensor(s1, 'ShowThresholds', true);
fig.tileTitle(1, 'Chamber Pressure');
fig.tileYLabel(1, 'Pressure [mbar]');

% Tile 2: Temperature
fp2 = fig.tile(2);
fp2.addSensor(s2, 'ShowThresholds', true);
fig.tileTitle(2, 'Chamber Temperature');
fig.tileYLabel(2, 'Temperature [°C]');

% Tile 3: Vibration
fp3 = fig.tile(3);
fp3.addSensor(s3, 'ShowThresholds', true);
fig.tileTitle(3, 'Motor Vibration');
fig.tileXLabel(3, 'Time [s]');
fig.tileYLabel(3, 'Acceleration [g]');

% Tile 4: Gas Flow
fp4 = fig.tile(4);
fp4.addSensor(s4, 'ShowThresholds', true);
fig.tileTitle(4, 'Gas Flow Rate');
fig.tileXLabel(4, 'Time [s]');
fig.tileYLabel(4, 'Flow [sccm]');

% Render all tiles at once
fig.renderAll();

% --- Also list available registry sensors ---
fprintf('\n=== SensorRegistry catalog ===\n');
SensorRegistry.list();
