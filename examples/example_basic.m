%% FastSense Basic Example — 10M points single line
% Demonstrates basic usage with a large time series dataset, plus setScale
% for logarithmic axes.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

n = 10e6;
x = linspace(0, 100, n);
y = sin(x * 2 * pi / 10) + 0.5 * randn(1, n);

fprintf('Creating FastSense with %d points...\n', n);
tic;

fp = FastSense();
fp.addLine(x, y, 'DisplayName', 'Noisy Sine', 'Color', [0 0.4470 0.7410]);

% Alarm thresholds (red, dashed)
fp.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', 'r', 'LineStyle', '--', 'Label', 'Alarm Hi');
fp.addThreshold(-2.0, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', 'r', 'LineStyle', '--', 'Label', 'Alarm Lo');

% Warning thresholds (orange, dotted)
fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [1 0.6 0], 'LineStyle', ':', 'Label', 'Warn Hi');
fp.addThreshold(-1.5, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [1 0.6 0], 'LineStyle', ':', 'Label', 'Warn Lo');

fp.render();

fprintf('Rendered in %.3f seconds. Try zooming and panning!\n', toc);
title(fp.hAxes, 'FastSense — 10M Points');
legend(fp.hAxes, 'show');

%% setScale — logarithmic Y axis
% Exponential growth data is best viewed with log scaling
n2 = 1e6;
x2 = linspace(1, 1000, n2);
base2 = exp(x2 / 200);
y2 = base2 .* (1 + 0.1 * abs(randn(1, n2)));

fp2 = FastSense();
fp2.addLine(x2, y2, 'DisplayName', 'Exponential Growth');
fp2.addThreshold(100, 'Direction', 'upper', 'ShowViolations', true, ...
    'Label', 'Warning');
fp2.render();

% Switch Y axis to log scale (can be called before or after render).
% Try fp2.setScale('YScale', 'linear') to toggle back.
fp2.setScale('YScale', 'log');
title(fp2.hAxes, 'setScale — Logarithmic Y Axis');
fprintf('setScale() demo: Y axis switched to log scale.\n');

%% updateData — replace line data on an already-rendered plot
newY = cos(x * 2*pi/15) + 0.4*randn(1, n);
fp.updateData(1, x, newY);
title(fp.hAxes, 'updateData — line data replaced in-place');
fprintf('updateData() replaced 10M-point line data on the first plot.\n');
