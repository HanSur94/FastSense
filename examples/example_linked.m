%% FastSense Linked Axes Example
% Demonstrates synchronized zoom/pan across subplots

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

n = 5e6;
x = linspace(0, 100, n);

fig = figure('Name', 'FastSense Linked Axes', 'Position', [100 100 1200 600]);

% Top plot
ax1 = subplot(3,1,1, 'Parent', fig);
fp1 = FastSense('Parent', ax1, 'LinkGroup', 'sync');
fp1.addLine(x, sin(x * 2 * pi / 5) + 0.2*randn(1,n), ...
    'DisplayName', 'Pressure', 'Color', 'b');
fp1.addThreshold(1.2, 'Direction', 'upper', 'ShowViolations', true);
fp1.render();
title(ax1, 'Pressure');

% Middle plot
ax2 = subplot(3,1,2, 'Parent', fig);
fp2 = FastSense('Parent', ax2, 'LinkGroup', 'sync');
fp2.addLine(x, cos(x * 2 * pi / 8) + 0.3*randn(1,n), ...
    'DisplayName', 'Temperature', 'Color', [0.8 0.3 0]);
fp2.render();
title(ax2, 'Temperature');

% Bottom plot
ax3 = subplot(3,1,3, 'Parent', fig);
fp3 = FastSense('Parent', ax3, 'LinkGroup', 'sync');
fp3.addLine(x, cumsum(randn(1,n))/sqrt(n), ...
    'DisplayName', 'Vibration', 'Color', [0 0.6 0]);
fp3.render();
title(ax3, 'Vibration');

fprintf('All 3 plots linked. Zoom one — all follow!\n');
