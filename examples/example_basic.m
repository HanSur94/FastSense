%% FastSense Basic Example — 10M points single line
% Demonstrates basic usage with a large time series

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

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
