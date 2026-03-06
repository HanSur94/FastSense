%% FastPlot Toolbar Demo
% Demonstrates the interactive toolbar: data cursor, crosshair,
% grid toggle, legend toggle, autoscale Y, and PNG export.

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

n = 1e6;
x = linspace(0, 100, n);
y1 = sin(x * 2*pi/10) + 0.3*randn(1,n);
y2 = cos(x * 2*pi/15) + 0.3*randn(1,n);

fprintf('Toolbar example: %d points, 2 lines...\n', n);
tic;

fp = FastPlot('Theme', 'dark');
fp.addLine(x, y1, 'DisplayName', 'Sine');
fp.addLine(x, y2, 'DisplayName', 'Cosine');
fp.addThreshold(1.2, 'Direction', 'upper', 'ShowViolations', true);
fp.render();

tb = FastPlotToolbar(fp);

fprintf('Rendered with toolbar in %.3f seconds.\n', toc);
fprintf('Try: Data Cursor (click), Crosshair (hover), Grid, Legend, Autoscale Y, Export PNG\n');

%% Dashboard with toolbar
fig = FastPlotFigure(1, 2, 'Theme', 'industrial');
fp1 = fig.tile(1);
fp1.addLine(x, y1, 'DisplayName', 'Pressure');
fp1.addThreshold(1.0, 'Direction', 'upper', 'ShowViolations', true);
fp2 = fig.tile(2);
fp2.addLine(x, y2, 'DisplayName', 'Temperature');
fig.renderAll();
fig.tileTitle(1, 'Pressure');
fig.tileTitle(2, 'Temperature');

tb2 = FastPlotToolbar(fig);
fprintf('Dashboard with toolbar ready.\n');
