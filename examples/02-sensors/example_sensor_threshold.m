%EXAMPLE_SENSOR_THRESHOLD Demonstrates the Sensor/Threshold system with FastSense.
%   Shows dynamic thresholds that change based on machine state.

% Setup paths
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

% --- Create sensor with synthetic data ---
s = SensorTag('pressure', 'Name', 'Chamber Pressure', 'ID', 101);
t = linspace(0, 100, 10000);
s.updateData(t, 40 + 20*sin(2*pi*t/30) + 5*randn(1, numel(t)));

% --- Create state channel (machine state changes over time) ---
sc = StateTag('machine_state', 'X', [0 25 50 75], 'Y', [0 1 2 1];  % 0=idle, 1=running, 2=evacuated);

% --- Define dynamic thresholds per state ---
% Idle: threshold at 70

% Running: stricter threshold at 55

% Evacuated: very strict threshold at 45

% --- Precompute everything ---

% --- Plot with FastSense ---
fp = FastSense();
fp.addTag(s, 'ShowThresholds', true);
fp.render();
title('Chamber Pressure with Dynamic Thresholds');
xlabel('Time');
ylabel('Pressure [mbar]');
