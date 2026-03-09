%% Sensor with Static Thresholds — Simplest Usage
% Demonstrates the SensorThreshold library without any state channels.
% Static thresholds apply everywhere (condition is always true).

run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));

% --- Create sensor with synthetic vibration data ---
s = Sensor('vibration', 'Name', 'Motor Vibration', 'ID', 201);
t = linspace(0, 60, 50000);
s.X = t;
s.Y = 2 + 0.8*sin(2*pi*t/8) + 0.3*randn(1, numel(t));

% Add a few spikes to trigger violations
spikes = [1200 2500 3800 4100 4200];
s.Y(spikes) = s.Y(spikes) + 3;

% --- Static upper threshold (always active) ---
s.addThresholdRule(struct(), 4.0, ...
    'Direction', 'upper', 'Label', 'High Alarm', ...
    'Color', [0.9 0.1 0.1], 'LineStyle', '--');

% --- Static lower threshold (always active) ---
s.addThresholdRule(struct(), 0.5, ...
    'Direction', 'lower', 'Label', 'Low Alarm', ...
    'Color', [0.1 0.1 0.9], 'LineStyle', '--');

% --- Resolve and plot ---
s.resolve();

fp = FastPlot();
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title('Motor Vibration — Static Upper & Lower Thresholds');
xlabel('Time [s]');
ylabel('Acceleration [g]');
