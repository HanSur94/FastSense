%EXAMPLE_SENSOR_THRESHOLD Demonstrates the Sensor/Threshold system with FastPlot.
%   Shows dynamic thresholds that change based on machine state.

% Setup paths
run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));

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
s.addThresholdRule(@(st) st.machine_state == 0, 70, ...
    'Direction', 'upper', 'Label', 'HH (idle)', ...
    'Color', [0.8 0 0], 'LineStyle', '--');

% Running: stricter threshold at 55
s.addThresholdRule(@(st) st.machine_state == 1, 55, ...
    'Direction', 'upper', 'Label', 'HH (running)', ...
    'Color', [1 0.3 0], 'LineStyle', '--');

% Evacuated: very strict threshold at 45
s.addThresholdRule(@(st) st.machine_state == 2, 45, ...
    'Direction', 'upper', 'Label', 'HH (evacuated)', ...
    'Color', [1 0 0], 'LineStyle', '-');

% --- Precompute everything ---
s.resolve();

% --- Plot with FastPlot ---
fp = FastPlot();
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title('Chamber Pressure with Dynamic Thresholds');
xlabel('Time');
ylabel('Pressure [mbar]');
