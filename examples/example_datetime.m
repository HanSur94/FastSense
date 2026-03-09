%% FastPlot Datetime X-Axis Demo
% Demonstrates auto-formatted date/time tick labels that adapt to zoom level.

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

%% ~579 days of temperature data at 1-second resolution
n = 50000000;
x = datenum(2024,1,1) + (0:n-1)/86400;  % ~579 days
t = (0:n-1) / 86400;  % time in days
y = 20 + 5*sin(t * 2*pi - pi/2) ...  % daily cycle (peak at midday)
    + 0.3*sin(t * 2*pi*24) ...        % hourly ripple
    + 0.1*randn(1,n);                 % sensor noise

fprintf('Datetime example: %dM points (~579 days, 1-second resolution)...\n', n/1e6);

%% Plot 1: With datetime X axis + toolbar
tic;
fp1 = FastPlot('Theme', 'dark');
fp1.addLine(x, y, 'DisplayName', 'Temperature', 'XType', 'datenum');
fp1.addThreshold(24, 'Direction', 'upper', 'ShowViolations', true);
fp1.render();
title(fp1.hAxes, 'With datenum + toolbar');
tb1 = FastPlotToolbar(fp1);
fprintf('Datetime + toolbar rendered in %.3f seconds.\n', toc);

%% Plot 2: Plain numeric X axis + toolbar
tic;
fp2 = FastPlot('Theme', 'dark');
fp2.addLine(x, y, 'DisplayName', 'Temperature');
fp2.addThreshold(24, 'Direction', 'upper', 'ShowViolations', true);
fp2.render();
title(fp2.hAxes, 'Without datenum + toolbar');
tb2 = FastPlotToolbar(fp2);
fprintf('Numeric + toolbar rendered in %.3f seconds.\n', toc);

%% Plot 3: With datetime X axis, no toolbar
tic;
fp3 = FastPlot('Theme', 'dark');
fp3.addLine(x, y, 'DisplayName', 'Temperature', 'XType', 'datenum');
fp3.addThreshold(24, 'Direction', 'upper', 'ShowViolations', true);
fp3.render();
title(fp3.hAxes, 'With datenum — no toolbar');
fprintf('Datetime, no toolbar rendered in %.3f seconds.\n', toc);

%% Plot 4: Plain numeric X axis, no toolbar
tic;
fp4 = FastPlot('Theme', 'dark');
fp4.addLine(x, y, 'DisplayName', 'Temperature');
fp4.addThreshold(24, 'Direction', 'upper', 'ShowViolations', true);
fp4.render();
title(fp4.hAxes, 'Without datenum — no toolbar');
fprintf('Numeric, no toolbar rendered in %.3f seconds.\n', toc);

fprintf('Compare all four windows — same data, different configurations.\n');
