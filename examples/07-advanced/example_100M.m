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

fprintf('Rendering...\n');
tic;

% DeferDraw (default: false) — when true, skips drawnow during render.
%   Useful in batch/headless workflows. Requires manual drawnow afterward.
% ShowProgress (default: true) — when false, hides the console progress bar.
%   The default shows a live progress bar during render.
% Both are set to their non-default values here to demonstrate the options.
fp = FastSense();
fp.DeferDraw = true;
fp.ShowProgress = false;
fp.addLine(x, y, 'DisplayName', '100M Random Walk', 'Color', [0 0.4 0.8]);
fp.addThreshold(3, 'Direction', 'upper', 'ShowViolations', true);
fp.addThreshold(-3, 'Direction', 'lower', 'ShowViolations', true);
fp.render();
drawnow;  % manual drawnow needed since DeferDraw=true

fprintf('Rendered in %.3f seconds. Zoom in to see detail!\n', toc);
title(fp.hAxes, 'FastSense — 100M Points Stress Test');

%% ConsoleProgressBar — standalone usage for custom batch workflows
% FastSense uses this internally when ShowProgress=true, but you can also
% use it directly for your own long-running loops.
pb = ConsoleProgressBar();
pb.start();
nSteps = 20;
for k = 1:nSteps
    pb.update(k, nSteps, 'Processing');
    pause(0.05);
end
pb.finish();
fprintf('ConsoleProgressBar demo complete.\n');
