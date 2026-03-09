%% FastPlot Log Scale Examples
% Demonstrates logarithmic axis support: log Y, log X, and log-log

fp = mfilename('fullpath');
if ~isempty(fp)
    addpath(fullfile(fileparts(fp), '..'));
else
    addpath(fullfile(pwd, '..'));
end

%% 1. Log Y — Frequency spectrum (most common use case)
n = 1e6;
f = linspace(1, 50000, n);          % frequency in Hz
mag = 1 ./ (1 + (f / 1000).^4);     % 4th-order low-pass filter response
mag = mag + 0.001 * randn(1, n);     % add noise floor

fp1 = FastPlot('YScale', 'log');
fp1.addLine(f, abs(mag), 'DisplayName', 'Filter Response', 'Color', [0 0.4470 0.7410]);
fp1.addThreshold(0.01, 'Direction', 'lower', 'ShowViolations', false, ...
    'Color', [0.8 0.2 0.2], 'LineStyle', '--', 'Label', 'Noise Floor');
fp1.render();
title(fp1.hAxes, 'Log Y — Low-Pass Filter Magnitude');
xlabel(fp1.hAxes, 'Frequency (Hz)');
ylabel(fp1.hAxes, 'Magnitude');
legend(fp1.hAxes, 'show');
fprintf('Plot 1: Log Y with %d points\n', n);

%% 2. Log X — Signal decay over decades of time
n = 1e6;
t = logspace(-3, 3, n);             % 1ms to 1000s
decay = 5 * exp(-0.5 * t) .* (1 + 0.1 * sin(20 * log10(t)));

fp2 = FastPlot('XScale', 'log');
fp2.addLine(t, decay, 'DisplayName', 'Exponential Decay', 'Color', [0.85 0.33 0.1]);
fp2.addThreshold(0.1, 'Direction', 'lower', 'ShowViolations', false, ...
    'Color', [0.5 0.5 0.5], 'LineStyle', ':', 'Label', 'Detection Limit');
fp2.render();
title(fp2.hAxes, 'Log X — Signal Decay Over Time Decades');
xlabel(fp2.hAxes, 'Time (s)');
ylabel(fp2.hAxes, 'Amplitude');
legend(fp2.hAxes, 'show');
fprintf('Plot 2: Log X with %d points\n', n);

%% 3. Log-Log — Power spectrum density
n = 1e6;
freq = logspace(0, 5, n);           % 1 Hz to 100 kHz
psd = 1e-3 ./ freq.^1.5;           % 1/f^1.5 noise
psd = psd .* (1 + 0.3 * randn(1, n));
psd = abs(psd);                      % keep positive for log scale

fp3 = FastPlot('XScale', 'log', 'YScale', 'log');
fp3.addLine(freq, psd, 'DisplayName', '1/f^{1.5} Noise PSD', 'Color', [0.47 0.67 0.19]);
fp3.render();
title(fp3.hAxes, 'Log-Log — Power Spectral Density');
xlabel(fp3.hAxes, 'Frequency (Hz)');
ylabel(fp3.hAxes, 'PSD (V^2/Hz)');
legend(fp3.hAxes, 'show');
fprintf('Plot 3: Log-Log with %d points\n', n);

fprintf('\nAll 3 log-scale plots rendered. Try zooming and panning!\n');
