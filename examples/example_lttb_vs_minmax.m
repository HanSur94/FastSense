%% FastPlot LTTB vs MinMax — Compare downsampling methods side by side
% Shows visual difference between MinMax (preserves extremes) and LTTB (preserves shape)

run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));

n = 5e6;
x = linspace(0, 100, n);
y = sin(x * 2*pi / 5) .* exp(-x/50) + 0.2 * randn(1, n);

fig = figure('Name', 'LTTB vs MinMax', 'Position', [100 100 1200 600]);

fprintf('LTTB vs MinMax: %d points, two views...\n', n);
tic;

% Top: MinMax (default)
ax1 = subplot(2,1,1, 'Parent', fig);
fp1 = FastPlot('Parent', ax1, 'LinkGroup', 'compare');
fp1.addLine(x, y, 'DisplayName', 'MinMax', 'Color', [0 0.45 0.74], ...
    'DownsampleMethod', 'minmax');
fp1.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [0.9 0 0], 'LineStyle', '--');
fp1.render();
title(ax1, 'MinMax Downsampling (preserves peaks/valleys)');

% Bottom: LTTB
ax2 = subplot(2,1,2, 'Parent', fig);
fp2 = FastPlot('Parent', ax2, 'LinkGroup', 'compare');
fp2.addLine(x, y, 'DisplayName', 'LTTB', 'Color', [0.85 0.33 0.1], ...
    'DownsampleMethod', 'lttb');
fp2.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [0.9 0 0], 'LineStyle', '--');
fp2.render();
title(ax2, 'LTTB Downsampling (preserves visual shape)');

fprintf('Rendered in %.3f seconds. Zoom to compare!\n', toc);
