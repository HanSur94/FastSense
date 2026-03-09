%% FastPlot.distFig — Distribute figures across the screen
% Creates a mix of standalone plots, a dashboard, and a docked figure,
% then uses FastPlot.distFig() to tile them neatly on screen.
%
% Requires: distFig from MATLAB File Exchange
%   https://www.mathworks.com/matlabcentral/fileexchange/37176

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

fprintf('distFig example: creating 4 figure windows...\n');
tic;

n = 500000;
x = linspace(0, 100, n);

% =========================================================================
% Figure 1: Standalone FastPlot — simple time series
% =========================================================================
fp1 = FastPlot();
fp1.addLine(x, sin(x*2*pi/20) + 0.3*randn(1,n), 'DisplayName', 'Sine');
fp1.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true);
fp1.render();
title(fp1.hAxes, 'Standalone Plot 1');

% =========================================================================
% Figure 2: Standalone FastPlot — multi-line
% =========================================================================
fp2 = FastPlot();
fp2.addLine(x, 5*sin(x*2*pi/30) + randn(1,n), 'DisplayName', 'Channel A');
fp2.addLine(x, 3*cos(x*2*pi/15) + randn(1,n), 'DisplayName', 'Channel B');
fp2.addBand(-4, 4, 'FaceColor', [0.3 0.7 1], 'FaceAlpha', 0.1);
fp2.render();
title(fp2.hAxes, 'Standalone Plot 2');
legend(fp2.hAxes, 'show');

% =========================================================================
% Figure 3: Dashboard (2x2 tiled layout)
% =========================================================================
fig = FastPlotFigure(2, 2, 'Theme', 'dark', 'Name', 'Dashboard');

fp = fig.tile(1);
fp.addLine(x, 70 + 5*sin(x*2*pi/40) + 2*randn(1,n), 'DisplayName', 'Temp');
fp.addThreshold(80, 'Direction', 'upper', 'ShowViolations', true);

fp = fig.tile(2);
fp.addLine(x, 100 + 10*sin(x*2*pi/60) + 3*randn(1,n), 'DisplayName', 'Pressure');

fp = fig.tile(3);
y_vib = 0.5*randn(1,n);
y_vib(round(n*0.4):round(n*0.42)) = y_vib(round(n*0.4):round(n*0.42)) + 3;
fp.addLine(x, y_vib, 'DisplayName', 'Vibration');
fp.addThreshold(2, 'Direction', 'upper', 'ShowViolations', true);

fp = fig.tile(4);
fp.addLine(x, 50 + 0.02*sin(x*2*pi/10) + 0.01*randn(1,n), 'DisplayName', 'Frequency');
fp.addBand(49.95, 50.05, 'FaceColor', [0.3 1 0.3], 'FaceAlpha', 0.12);

fig.renderAll();
fig.tileTitle(1, 'Temperature');
fig.tileTitle(2, 'Pressure');
fig.tileTitle(3, 'Vibration');
fig.tileTitle(4, 'Frequency');

% =========================================================================
% Figure 4: Docked tabs (2 tabs)
% =========================================================================
dock = FastPlotDock('Theme', 'dark', 'Name', 'Docked Tabs');

tab1 = FastPlotFigure(1, 2, 'ParentFigure', dock.hFigure, 'Theme', 'dark');
fp = tab1.tile(1);
fp.addLine(x, 230 + 5*sin(x*2*pi/25) + 2*randn(1,n), 'DisplayName', 'Phase A');
fp.addLine(x, 230 + 5*sin(x*2*pi/25 + 2.09) + 2*randn(1,n), 'DisplayName', 'Phase B');
fp = tab1.tile(2);
fp.addLine(x, abs(3*sin(x*2*pi/30) .* (1 + 0.2*randn(1,n))), 'DisplayName', 'Current');
fp.addFill(x, abs(3*sin(x*2*pi/30) .* (1 + 0.2*randn(1,n))), ...
    'FaceColor', [0.9 0.6 0.1], 'FaceAlpha', 0.2);
dock.addTab(tab1, 'Electrical');

tab2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure, 'Theme', 'dark');
fp = tab2.tile(1);
fp.addLine(x, 22 + 4*sin(x*2*pi/80) + 0.5*randn(1,n), 'DisplayName', 'Room Temp');
fp.addBand(20, 25, 'FaceColor', [0.2 0.6 1], 'FaceAlpha', 0.1);
dock.addTab(tab2, 'Environment');

dock.renderAll();
tab1.tileTitle(1, 'Voltage');
tab1.tileTitle(2, 'Motor Current');
tab2.tileTitle(1, 'Room Temperature');

elapsed = toc;
fprintf('Created 4 figures in %.2f seconds.\n', elapsed);

% =========================================================================
% Distribute all figures on screen
% =========================================================================
fprintf('Distributing figures with FastPlot.distFig()...\n');
FastPlot.distFig();

fprintf('Done! All figures tiled on screen.\n');
fprintf('Try also: FastPlot.distFig(''Rows'', 2, ''Cols'', 2)\n');
