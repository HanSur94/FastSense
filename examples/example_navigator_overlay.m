%% NavigatorOverlay — Standalone Usage
% Demonstrates using NavigatorOverlay independently on any MATLAB axes.
% NavigatorOverlay adds a draggable zoom-rectangle overlay to an axes,
% firing a callback when the range changes. It can be used to build
% custom overview+detail views.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

%% Create a figure with two axes: overview (bottom) + detail (top)
fig = figure('Name', 'NavigatorOverlay Demo', 'Position', [100 100 900 500]);

axDetail = axes('Parent', fig, 'Units', 'normalized', ...
    'Position', [0.08 0.35 0.88 0.60]);
axOverview = axes('Parent', fig, 'Units', 'normalized', ...
    'Position', [0.08 0.05 0.88 0.22]);

%% Generate data
t = linspace(0, 100, 50000);
y = sin(2*pi*t/10) + 0.5*sin(2*pi*t/3) + 0.3*randn(1, numel(t));

%% Plot the same data in both axes
plot(axDetail, t, y, 'Color', [0.2 0.5 0.8]);
title(axDetail, 'Detail View (zoom controlled by navigator)');
xlabel(axDetail, 'Time');

plot(axOverview, t, y, 'Color', [0.5 0.5 0.5]);
title(axOverview, 'Overview — drag the highlight');
xlim(axOverview, [0 100]);

%% Create NavigatorOverlay on the overview axes
ov = NavigatorOverlay(axOverview);

% Wire the callback: when the navigator range changes, update detail xlim
ov.OnRangeChanged = @(xMin, xMax) set(axDetail, 'XLim', [xMin xMax]);

% Set an initial zoomed view
ov.setRange(20, 50);

fprintf('NavigatorOverlay demo:\n');
fprintf('  - Drag the blue highlight to pan\n');
fprintf('  - Drag the edges to resize\n');
fprintf('  - Click outside the highlight to jump\n');
