%% FastPlotDock — Tabbed Dashboard Example
% Two dashboards docked in a single window with tab switching.

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

fprintf('Docked Tabs: 2 dashboards in 1 window...\n');
tic;

% =========================================================================
% Dashboard 1: Temperature Monitoring (2x2)
% =========================================================================
dock = FastPlotDock('Theme', 'dark', 'Name', 'Control Room', ...
    'Position', [50 50 1400 800]);

fig1 = FastPlotFigure(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

fp = fig1.tile(1);
n = 2e6;
x = linspace(0, 3600, n);
fp.addLine(x, 72 + 6*sin(x*2*pi/600) + 1.5*randn(1,n), 'DisplayName', 'Sensor A');
fp.addLine(x, 68 + 5*sin(x*2*pi/600 + 0.5) + 1.2*randn(1,n), 'DisplayName', 'Sensor B');
fp.addThreshold(82, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'High');

fp = fig1.tile(2);
n = 1e6;
x = linspace(0, 3600, n);
fp.addLine(x, 45 + 8*sin(x*2*pi/900) + 3*randn(1,n), 'DisplayName', 'Coolant Flow');
fp.addThreshold(55, 'Direction', 'upper', 'ShowViolations', true);
fp.addThreshold(35, 'Direction', 'lower', 'ShowViolations', true);

fp = fig1.tile(3);
n = 500000;
x = linspace(0, 3600, n);
fp.addLine(x, 101 + 12*sin(x*2*pi/1200) + 3*randn(1,n), 'DisplayName', 'Pressure');
fp.addBand(90, 115, 'FaceColor', [0.3 0.7 1], 'FaceAlpha', 0.12);

fp = fig1.tile(4);
n = 800000;
x = linspace(0, 3600, n);
y = 0.4*randn(1,n);
y(round(n*0.3):round(n*0.32)) = y(round(n*0.3):round(n*0.32)) + 2.5;
fp.addLine(x, y, 'DisplayName', 'Vibration');
fp.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', true);

dock.addTab(fig1, 'Temperature');

% =========================================================================
% Dashboard 2: Power Systems (1x2)
% =========================================================================
fig2 = FastPlotFigure(1, 2, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

fp = fig2.tile(1);
n = 3e6;
x = linspace(0, 3600, n);
fp.addLine(x, abs(3*sin(x*2*pi/400) .* (1 + 0.2*randn(1,n))), 'DisplayName', 'Motor Current');
fp.addFill(x, abs(3*sin(x*2*pi/400) .* (1 + 0.2*randn(1,n))), ...
    'FaceColor', [0.9 0.6 0.1], 'FaceAlpha', 0.2);

fp = fig2.tile(2);
n = 1e6;
x = linspace(0, 3600, n);
fp.addLine(x, 1500 + 300*sin(x*2*pi/900) + 50*randn(1,n), ...
    'DisplayName', 'RPM', 'DownsampleMethod', 'lttb');

dock.addTab(fig2, 'Power Systems');

% =========================================================================
% Render and label
% =========================================================================
dock.render();

fig1.tileTitle(1, 'Temperature (2M pts)');
fig1.tileTitle(2, 'Coolant Flow (1M pts)');
fig1.tileTitle(3, 'Reactor Pressure (500K pts)');
fig1.tileTitle(4, 'Vibration (800K pts)');

fig2.tileTitle(1, 'Motor Current (3M pts)');
fig2.tileTitle(2, 'RPM — LTTB (1M pts)');

elapsed = toc;
fprintf('Docked tabs rendered in %.2f seconds.\n', elapsed);
fprintf('Click tabs at top to switch between dashboards.\n');
