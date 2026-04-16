%% Sensor with Static Thresholds — Simplest Usage
% Demonstrates the SensorThreshold library without any state channels.
% Static thresholds apply everywhere (condition is always true).

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

% --- Create sensor with synthetic vibration data ---
s = Sensor('vibration', 'Name', 'Motor Vibration', 'ID', 201);
t = linspace(0, 60, 50000);
s.X = t;
s.Y = 2 + 0.8*sin(2*pi*t/8) + 0.3*randn(1, numel(t));

% Add a few spikes to trigger violations
spikes = [1200 2500 3800 4100 4200];
s.Y(spikes) = s.Y(spikes) + 3;

% --- Static upper threshold (always active) ---
tHighAlarm = Threshold('high_alarm', 'Name', 'High Alarm', ...
    'Direction', 'upper', 'Color', [0.9 0.1 0.1], 'LineStyle', '--');
tHighAlarm.addCondition(struct(), 4.0);
s.addThreshold(tHighAlarm);

% --- Static lower threshold (always active) ---
tLowAlarm = Threshold('low_alarm', 'Name', 'Low Alarm', ...
    'Direction', 'lower', 'Color', [0.1 0.1 0.9], 'LineStyle', '--');
tLowAlarm.addCondition(struct(), 0.5);
s.addThreshold(tLowAlarm);

% --- Resolve and inspect ---
s.resolve();

% currentStatus — check the sensor's latest-value status
fprintf('Sensor status: %s\n', s.currentStatus());

% countViolations — total number of violation points
fprintf('Total violations: %d\n', s.countViolations());

% --- Plot ---
fp = FastSense();
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title('Motor Vibration — Static Upper & Lower Thresholds');
xlabel('Time [s]');
ylabel('Acceleration [g]');
