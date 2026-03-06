%% FastPlot Datetime X-Axis Demo
% Demonstrates auto-formatted date/time tick labels that adapt to zoom level.

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

%% Multi-day temperature-like signal at 1-second resolution
n = 1000000;
x = datenum(2024,1,1) + (0:n-1)/86400;  % ~11.6 days
t = (0:n-1) / 86400;  % time in days
y = 20 + 5*sin(t * 2*pi - pi/2) ...  % daily cycle (peak at midday)
    + 0.3*sin(t * 2*pi*24) ...        % hourly ripple
    + 0.1*randn(1,n);                 % sensor noise

fprintf('Datetime example: %d points (~11.6 days, 1-second resolution)...\n', n);

%% Plot 1: With datetime X axis
tic;
fp1 = FastPlot('Theme', 'dark');
fp1.addLine(x, y, 'DisplayName', 'Temperature', 'XType', 'datenum');
fp1.render();
title(fp1.hAxes, 'With datenum — zoom to see format change');
tb1 = FastPlotToolbar(fp1);
fprintf('Datetime plot rendered in %.3f seconds.\n', toc);

%% Plot 2: Same data, plain numeric X axis (for comparison)
tic;
fp2 = FastPlot('Theme', 'dark');
fp2.addLine(x, y, 'DisplayName', 'Temperature');
fp2.render();
title(fp2.hAxes, 'Without datenum — same data, raw numeric axis');
tb2 = FastPlotToolbar(fp2);
fprintf('Numeric plot rendered in %.3f seconds.\n', toc);

fprintf('Compare both windows — same data, different X axis formatting.\n');
