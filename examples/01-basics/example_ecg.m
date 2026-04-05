%% FastSense ECG — Simulated heart rhythm with arrhythmia detection
% Demonstrates high sample rate biomedical data with tight thresholds

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

n = 5e6;
fs = 1000; % 1 kHz ECG sample rate
x = (0:n-1) / fs; % time in seconds (83 min recording)

% Generate synthetic ECG-like signal
heart_rate = 72; % bpm
beat_period = fs * 60 / heart_rate;
y = zeros(1, n);

for beat_start = 1:round(beat_period):n
    % QRS complex
    qrs_len = round(0.08 * fs);
    idx = beat_start:min(beat_start + qrs_len - 1, n);
    t_local = linspace(0, pi, numel(idx));
    y(idx) = y(idx) + 1.2 * sin(t_local);

    % T wave
    t_start = beat_start + round(0.2 * fs);
    t_len = round(0.15 * fs);
    idx = t_start:min(t_start + t_len - 1, n);
    if ~isempty(idx)
        t_local = linspace(0, pi, numel(idx));
        y(idx) = y(idx) + 0.3 * sin(t_local);
    end
end

% Add baseline wander and noise
y = y + 0.1 * sin(2*pi*0.15*x) + 0.05 * randn(1, n);

% Inject PVCs (premature ventricular contractions)
pvc_times = [300 900 1500 2400 3800];
for pt = pvc_times
    idx = round(pt*fs):min(round(pt*fs) + round(0.12*fs), n);
    t_local = linspace(0, pi, numel(idx));
    y(idx) = y(idx) + 1.5 * sin(t_local); % taller, wider QRS
end

fprintf('ECG: %d points at %d Hz (%.0f min recording)...\n', n, fs, n/fs/60);
tic;

fp = FastSense();
fp.addLine(x, y, 'DisplayName', 'ECG Lead II', 'Color', [0 0.5 0]);

% Arrhythmia detection thresholds
fp.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--', 'Label', 'High Amplitude');
fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [1 0.6 0], 'LineStyle', ':', 'Label', 'Elevated');
fp.addThreshold(-0.5, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [0.6 0 0.6], 'LineStyle', ':', 'Label', 'ST Depression');

fp.render();

fprintf('Rendered in %.3f seconds. Zoom to see individual QRS complexes!\n', toc);
title(fp.hAxes, 'ECG Recording — 5M Points');
xlabel(fp.hAxes, 'Time (s)');
ylabel(fp.hAxes, 'mV');
legend(fp.hAxes, 'show');
