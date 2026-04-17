%% Sensor with Static Thresholds — Simplest Usage
% Demonstrates the SensorThreshold library without any state channels.
% Static thresholds apply everywhere (condition is always true).

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

% --- Create sensor with synthetic vibration data ---
s = SensorTag('vibration', 'Name', 'Motor Vibration', 'ID', 201);
t = linspace(0, 60, 50000);
s.updateData(t, 2 + 0.8*sin(2*pi*t/8) + 0.3*randn(1, numel(t)));
[s_x_, s_y_] = s.getXY();

% Add a few spikes to trigger violations
spikes = [1200 2500 3800 4100 4200];
s_y_(spikes) = s_y_(spikes) + 3;

% --- Static upper threshold (always active) ---

% --- Static lower threshold (always active) ---

% --- Resolve and inspect ---

% currentStatus — check the sensor's latest-value status

% countViolations — total number of violation points

% --- Plot ---
fp = FastSense();
s.updateData(s_x_, s_y_);
fp.addTag(s);
fp.render();
title('Motor Vibration — Static Upper & Lower Thresholds');
xlabel('Time [s]');
ylabel('Acceleration [g]');
