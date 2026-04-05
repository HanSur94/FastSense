%EXAMPLE_SENSOR_THRESHOLD Demonstrates the Sensor/Threshold system with FastSense.
%   Shows dynamic thresholds that change based on machine state.

% Setup paths
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

% --- Create sensor with synthetic data ---
s = Sensor('pressure', 'Name', 'Chamber Pressure', 'ID', 101);
t = linspace(0, 100, 10000);
s.X = t;
s.Y = 40 + 20*sin(2*pi*t/30) + 5*randn(1, numel(t));

% --- Create state channel (machine state changes over time) ---
sc = StateChannel('machine_state');
sc.X = [0 25 50 75];
sc.Y = [0 1 2 1];  % 0=idle, 1=running, 2=evacuated
s.addStateChannel(sc);

% --- Define dynamic thresholds per state ---
% Idle: threshold at 70
tHhIdle = Threshold('hh_idle', 'Name', 'HH (idle)', ...
    'Direction', 'upper', 'Color', [0.8 0 0], 'LineStyle', '--');
tHhIdle.addCondition(struct('machine_state', 0), 70);
s.addThreshold(tHhIdle);

% Running: stricter threshold at 55
tHhRunning = Threshold('hh_running', 'Name', 'HH (running)', ...
    'Direction', 'upper', 'Color', [1 0.3 0], 'LineStyle', '--');
tHhRunning.addCondition(struct('machine_state', 1), 55);
s.addThreshold(tHhRunning);

% Evacuated: very strict threshold at 45
tHhEvacuated = Threshold('hh_evacuated', 'Name', 'HH (evacuated)', ...
    'Direction', 'upper', 'Color', [1 0 0], 'LineStyle', '-');
tHhEvacuated.addCondition(struct('machine_state', 2), 45);
s.addThreshold(tHhEvacuated);

% --- Precompute everything ---
s.resolve();

% --- Plot with FastSense ---
fp = FastSense();
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title('Chamber Pressure with Dynamic Thresholds');
xlabel('Time');
ylabel('Pressure [mbar]');
