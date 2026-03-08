%% FastPlotDock — Tabbed Dashboard Example
% Five dashboards docked in a single window with tab switching.

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

fprintf('Docked Tabs: 5 dashboards in 1 window...\n');
tic;

dock = FastPlotDock('Theme', 'dark', 'Name', 'Control Room', ...
    'Position', [50 50 1400 800]);

% =========================================================================
% Tab 1: Temperature Monitoring (2x2)
% =========================================================================
fig1 = FastPlotFigure(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

fp = fig1.tile(1);
n = 2e6; x = linspace(0, 3600, n);
fp.addLine(x, 72 + 6*sin(x*2*pi/600) + 1.5*randn(1,n), 'DisplayName', 'Sensor A');
fp.addLine(x, 68 + 5*sin(x*2*pi/600 + 0.5) + 1.2*randn(1,n), 'DisplayName', 'Sensor B');
fp.addThreshold(82, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'High');

fp = fig1.tile(2);
n = 1e6; x = linspace(0, 3600, n);
fp.addLine(x, 45 + 8*sin(x*2*pi/900) + 3*randn(1,n), 'DisplayName', 'Coolant Flow');
fp.addThreshold(55, 'Direction', 'upper', 'ShowViolations', true);
fp.addThreshold(35, 'Direction', 'lower', 'ShowViolations', true);

fp = fig1.tile(3);
n = 500000; x = linspace(0, 3600, n);
fp.addLine(x, 101 + 12*sin(x*2*pi/1200) + 3*randn(1,n), 'DisplayName', 'Pressure');
fp.addBand(90, 115, 'FaceColor', [0.3 0.7 1], 'FaceAlpha', 0.12);

fp = fig1.tile(4);
n = 800000; x = linspace(0, 3600, n);
y = 0.4*randn(1,n);
y(round(n*0.3):round(n*0.32)) = y(round(n*0.3):round(n*0.32)) + 2.5;
fp.addLine(x, y, 'DisplayName', 'Vibration');
fp.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', true);

dock.addTab(fig1, 'Temperature');

% =========================================================================
% Tab 2: Power Systems (1x2)
% =========================================================================
fig2 = FastPlotFigure(1, 2, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

fp = fig2.tile(1);
n = 3e6; x = linspace(0, 3600, n);
fp.addLine(x, abs(3*sin(x*2*pi/400) .* (1 + 0.2*randn(1,n))), 'DisplayName', 'Motor Current');
fp.addFill(x, abs(3*sin(x*2*pi/400) .* (1 + 0.2*randn(1,n))), ...
    'FaceColor', [0.9 0.6 0.1], 'FaceAlpha', 0.2);

fp = fig2.tile(2);
n = 1e6; x = linspace(0, 3600, n);
fp.addLine(x, 1500 + 300*sin(x*2*pi/900) + 50*randn(1,n), ...
    'DisplayName', 'RPM', 'DownsampleMethod', 'lttb');

dock.addTab(fig2, 'Power Systems');

% =========================================================================
% Tab 3: Hydraulics (2x1)
% =========================================================================
fig3 = FastPlotFigure(2, 1, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

fp = fig3.tile(1);
n = 1.5e6; x = linspace(0, 3600, n);
fp.addLine(x, 220 + 30*sin(x*2*pi/500) + 10*randn(1,n), 'DisplayName', 'Hydraulic Pressure');
fp.addLine(x, 200 + 25*sin(x*2*pi/500 + 1) + 8*randn(1,n), 'DisplayName', 'Return Line');
fp.addBand(180, 260, 'FaceColor', [0.2 0.8 0.4], 'FaceAlpha', 0.08);

fp = fig3.tile(2);
n = 1e6; x = linspace(0, 3600, n);
fp.addLine(x, 55 + 10*sin(x*2*pi/1800) + 2*randn(1,n), 'DisplayName', 'Oil Temp');
fp.addThreshold(70, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'Overheat');

dock.addTab(fig3, 'Hydraulics');

% =========================================================================
% Tab 4: Electrical Grid (1x3)
% =========================================================================
fig4 = FastPlotFigure(1, 3, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

fp = fig4.tile(1);
n = 2e6; x = linspace(0, 3600, n);
fp.addLine(x, 230 + 5*sin(x*2*pi/120) + 2*randn(1,n), 'DisplayName', 'Phase A');
fp.addLine(x, 230 + 5*sin(x*2*pi/120 + 2.09) + 2*randn(1,n), 'DisplayName', 'Phase B');
fp.addLine(x, 230 + 5*sin(x*2*pi/120 + 4.19) + 2*randn(1,n), 'DisplayName', 'Phase C');

fp = fig4.tile(2);
n = 1e6; x = linspace(0, 3600, n);
fp.addLine(x, 50 + 0.02*sin(x*2*pi/60) + 0.005*randn(1,n), 'DisplayName', 'Frequency');
fp.addBand(49.95, 50.05, 'FaceColor', [0.3 1 0.3], 'FaceAlpha', 0.1);

fp = fig4.tile(3);
n = 800000; x = linspace(0, 3600, n);
load = 450 + 150*sin(x*2*pi/3600) + 30*randn(1,n);
fp.addLine(x, load, 'DisplayName', 'Load (kW)');
fp.addFill(x, load, 'FaceColor', [0.8 0.3 0.3], 'FaceAlpha', 0.15);
fp.addThreshold(600, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'Peak');

dock.addTab(fig4, 'Electrical Grid');

% =========================================================================
% Tab 5: Environment (2x2)
% =========================================================================
fig5 = FastPlotFigure(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

fp = fig5.tile(1);
n = 1e6; x = linspace(0, 86400, n);
fp.addLine(x, 22 + 4*sin(x*2*pi/86400) + 0.5*randn(1,n), 'DisplayName', 'Room Temp');
fp.addBand(20, 25, 'FaceColor', [0.2 0.6 1], 'FaceAlpha', 0.1);

fp = fig5.tile(2);
n = 800000; x = linspace(0, 86400, n);
fp.addLine(x, 45 + 15*sin(x*2*pi/43200) + 5*randn(1,n), 'DisplayName', 'Humidity %');
fp.addThreshold(65, 'Direction', 'upper', 'ShowViolations', true);

fp = fig5.tile(3);
n = 500000; x = linspace(0, 86400, n);
fp.addLine(x, 35 + 8*sin(x*2*pi/7200) + 3*randn(1,n), 'DisplayName', 'dB Level');
fp.addThreshold(50, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'Loud');

fp = fig5.tile(4);
n = 600000; x = linspace(0, 86400, n);
co2 = 400 + 100*sin(x*2*pi/43200) + 20*randn(1,n);
fp.addLine(x, co2, 'DisplayName', 'CO2 (ppm)');
fp.addThreshold(800, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'Ventilate');

dock.addTab(fig5, 'Environment');

% =========================================================================
% Render and label
% =========================================================================
dock.render();

fig1.tileTitle(1, 'Temperature (2M pts)');
fig1.tileXLabel(1, 'Time (s)'); fig1.tileYLabel(1, 'Temp (°F)');
fig1.tileTitle(2, 'Coolant Flow (1M pts)');
fig1.tileXLabel(2, 'Time (s)'); fig1.tileYLabel(2, 'Flow (L/min)');
fig1.tileTitle(3, 'Reactor Pressure (500K pts)');
fig1.tileXLabel(3, 'Time (s)'); fig1.tileYLabel(3, 'Pressure (kPa)');
fig1.tileTitle(4, 'Vibration (800K pts)');
fig1.tileXLabel(4, 'Time (s)'); fig1.tileYLabel(4, 'Amplitude (g)');

fig2.tileTitle(1, 'Motor Current (3M pts)');
fig2.tileXLabel(1, 'Time (s)'); fig2.tileYLabel(1, 'Current (A)');
fig2.tileTitle(2, 'RPM — LTTB (1M pts)');
fig2.tileXLabel(2, 'Time (s)'); fig2.tileYLabel(2, 'RPM');

fig3.tileTitle(1, 'Hydraulic Pressure (1.5M pts)');
fig3.tileXLabel(1, 'Time (s)'); fig3.tileYLabel(1, 'Pressure (bar)');
fig3.tileTitle(2, 'Oil Temperature (1M pts)');
fig3.tileXLabel(2, 'Time (s)'); fig3.tileYLabel(2, 'Temp (°C)');

fig4.tileTitle(1, 'Three-Phase Voltage (2M pts)');
fig4.tileXLabel(1, 'Time (s)'); fig4.tileYLabel(1, 'Voltage (V)');
fig4.tileTitle(2, 'Grid Frequency (1M pts)');
fig4.tileXLabel(2, 'Time (s)'); fig4.tileYLabel(2, 'Freq (Hz)');
fig4.tileTitle(3, 'Load (800K pts)');
fig4.tileXLabel(3, 'Time (s)'); fig4.tileYLabel(3, 'Power (kW)');

fig5.tileTitle(1, 'Room Temperature (1M pts)');
fig5.tileXLabel(1, 'Time (s)'); fig5.tileYLabel(1, 'Temp (°C)');
fig5.tileTitle(2, 'Humidity (800K pts)');
fig5.tileXLabel(2, 'Time (s)'); fig5.tileYLabel(2, 'RH (%)');
fig5.tileTitle(3, 'Noise Level (500K pts)');
fig5.tileXLabel(3, 'Time (s)'); fig5.tileYLabel(3, 'Level (dB)');
fig5.tileTitle(4, 'CO2 (600K pts)');
fig5.tileXLabel(4, 'Time (s)'); fig5.tileYLabel(4, 'CO2 (ppm)');

elapsed = toc;
fprintf('Docked tabs rendered in %.2f seconds (~%.1fM total pts).\n', elapsed, 21.2);
fprintf('Click tabs at top to switch between 5 dashboards.\n');
