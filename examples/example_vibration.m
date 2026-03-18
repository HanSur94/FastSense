%% FastSense Vibration Analysis — High-frequency data with envelope thresholds
% Simulates accelerometer data from a rotating machine

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

n = 20e6;
fs = 50000; % 50 kHz sample rate
x = (0:n-1) / fs; % time in seconds

% Simulate vibration: base frequency + harmonics + bearing defect
rpm = 1800; % shaft speed
f_shaft = rpm / 60;
f_bearing = 5.2 * f_shaft; % BPFO frequency

y = 0.5 * sin(2*pi*f_shaft*x) ...          % 1x shaft
  + 0.2 * sin(2*pi*2*f_shaft*x) ...        % 2x harmonic
  + 0.05 * randn(1, n);                     % noise floor

% Add intermittent bearing defect bursts
burst_times = [50 120 250 350];  % seconds
for bt = burst_times
    idx = round(bt*fs):min(round((bt+2)*fs), n);
    y(idx) = y(idx) + 1.5 * sin(2*pi*f_bearing*x(idx)) .* exp(-(x(idx)-bt)/0.5);
end

fprintf('Vibration: %d points at %d kHz...\n', n, fs/1000);
tic;

fp = FastSense();
fp.addLine(x, y, 'DisplayName', 'Accelerometer', 'Color', [0.1 0.3 0.6]);

% ISO 10816 style velocity thresholds (simplified for displacement)
fp.addThreshold(1.2, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--', 'Label', 'Danger');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [1 0.5 0], 'LineStyle', ':', 'Label', 'Alert');
fp.addThreshold(-0.8, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [1 0.5 0], 'LineStyle', ':');
fp.addThreshold(-1.2, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--');

fp.render();

fprintf('Rendered in %.3f seconds. Zoom into burst regions!\n', toc);
title(fp.hAxes, 'Vibration Analysis — 20M Points @ 50 kHz');
xlabel(fp.hAxes, 'Time (s)');
ylabel(fp.hAxes, 'Acceleration (g)');
legend(fp.hAxes, 'show');
