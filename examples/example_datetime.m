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
tic;

fp = FastPlot('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Temperature', 'XType', 'datenum');
fp.render();
title(fp.hAxes, 'Datetime Axis — zoom to see format change');

tb = FastPlotToolbar(fp);

fprintf('Rendered in %.3f seconds.\n', toc);
fprintf('Zoom in: tick labels adapt from "mmm dd HH:MM" to "HH:MM" to "HH:MM:SS"\n');
fprintf('Try the crosshair and data cursor — they show datetime values too.\n');
