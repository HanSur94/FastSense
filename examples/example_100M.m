%% FastSense Stress Test — 100M points
% Demonstrates performance at maximum scale, DeferDraw, and ShowProgress.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

n = 100e6;
fprintf('Generating %d data points (~800 MB)...\n', n);
tic;
x = linspace(0, 1000, n);
y = cumsum(randn(1, n)) / sqrt(n);  % random walk
fprintf('Data generated in %.1f seconds.\n', toc);

fprintf('Rendering with ShowProgress=true (default)...\n');
tic;

fp = FastSense();
fp.ShowProgress = true;   % show console progress bar during render (default)
fp.DeferDraw = false;     % allow incremental drawing (default)
fp.addLine(x, y, 'DisplayName', '100M Random Walk', 'Color', [0 0.4 0.8]);
fp.addThreshold(3, 'Direction', 'upper', 'ShowViolations', true);
fp.addThreshold(-3, 'Direction', 'lower', 'ShowViolations', true);
fp.render();

fprintf('Rendered in %.3f seconds. Zoom in to see detail!\n', toc);
title(fp.hAxes, 'FastSense — 100M Points Stress Test');

fprintf('\nDeferDraw=true skips drawnow during render (useful in batch/headless).\n');
fprintf('ShowProgress=false hides the console progress bar.\n');
