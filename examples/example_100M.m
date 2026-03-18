%% FastSense Stress Test — 100M points
% Demonstrates performance at maximum scale

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

n = 100e6;
fprintf('Generating %d data points (~800 MB)...\n', n);
tic;
x = linspace(0, 1000, n);
y = cumsum(randn(1, n)) / sqrt(n);  % random walk
fprintf('Data generated in %.1f seconds.\n', toc);

fprintf('Rendering...\n');
tic;

fp = FastSense();
fp.addLine(x, y, 'DisplayName', '100M Random Walk', 'Color', [0 0.4 0.8]);
fp.addThreshold(3, 'Direction', 'upper', 'ShowViolations', true);
fp.addThreshold(-3, 'Direction', 'lower', 'ShowViolations', true);
fp.render();

fprintf('Rendered in %.3f seconds. Zoom in to see detail!\n', toc);
title(fp.hAxes, 'FastSense — 100M Points Stress Test');
