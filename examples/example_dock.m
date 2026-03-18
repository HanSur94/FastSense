%% FastSenseDock — Tabbed Dashboard Example
% Five dashboards docked in a single window with tab switching.
% All tabs use datetime X axes (auto-detected by FastSense).

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

% Suppress MATLAB Variable Editor warnings during datetime/linspace
wState = warning('off', 'all');
restoreWarn = onCleanup(@() warning(wState));

fprintf('Docked Tabs: 5 dashboards in 1 window...\n');
tic;

dock = FastSenseDock('Theme', 'light', 'Name', 'Control Room', ...
    'Position', [50 50 1400 800]);

% Common time base: 1 hour of data starting now
t0 = datetime(2026, 3, 8, 8, 0, 0);
t1 = datetime(2026, 3, 8, 9, 0, 0);

% Helper: seconds since t0 for signal generation
sec = @(t) seconds(t - t0);

% =========================================================================
% Tab 1: Temperature Monitoring (2x2)
% =========================================================================
fig1 = FastSenseGrid(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'light');

fp = fig1.tile(1);
n = 2e6; t = linspace(t0, t1, n); s = sec(t);
meta1.datenum  = datenum([t0, t0+minutes(15), t0+minutes(30), t0+minutes(45)]);
meta1.operator = {'Alice', 'Bob', 'Alice', 'Charlie'};
meta1.shift    = {'Day', 'Day', 'Day', 'Night'};
meta1.status   = {'normal', 'calibrating', 'normal', 'maintenance'};
fp.addLine(t, 72 + 6*sin(s*2*pi/600) + 1.5*randn(1,n), 'DisplayName', 'Sensor A', 'Metadata', meta1);
fp.addLine(t, 68 + 5*sin(s*2*pi/600 + 0.5) + 1.2*randn(1,n), 'DisplayName', 'Sensor B');
fp.addThreshold(82, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'High');

fp = fig1.tile(2);
n = 1e6; t = linspace(t0, t1, n); s = sec(t);
fp.addLine(t, 45 + 8*sin(s*2*pi/900) + 3*randn(1,n), 'DisplayName', 'Coolant Flow');
fp.addThreshold(55, 'Direction', 'upper', 'ShowViolations', true);
fp.addThreshold(35, 'Direction', 'lower', 'ShowViolations', true);

fp = fig1.tile(3);
n = 500000; t = linspace(t0, t1, n); s = sec(t);
fp.addLine(t, 101 + 12*sin(s*2*pi/1200) + 3*randn(1,n), 'DisplayName', 'Pressure');
fp.addBand(90, 115, 'FaceColor', [0.3 0.7 1], 'FaceAlpha', 0.12);

fp = fig1.tile(4);
n = 800000; t = linspace(t0, t1, n); s = sec(t);
y = 0.4*randn(1,n);
y(round(n*0.3):round(n*0.32)) = y(round(n*0.3):round(n*0.32)) + 2.5;
fp.addLine(t, y, 'DisplayName', 'Vibration');
fp.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', true);

dock.addTab(fig1, 'Temperature');

% =========================================================================
% Tab 2: Power Systems (1x2)
% =========================================================================
fig2 = FastSenseGrid(1, 2, 'ParentFigure', dock.hFigure, 'Theme', 'light');

fp = fig2.tile(1);
n = 3e6; t = linspace(t0, t1, n); s = sec(t);
fp.addLine(t, abs(3*sin(s*2*pi/400) .* (1 + 0.2*randn(1,n))), 'DisplayName', 'Motor Current');
fp.addFill(t, abs(3*sin(s*2*pi/400) .* (1 + 0.2*randn(1,n))), ...
    'FaceColor', [0.9 0.6 0.1], 'FaceAlpha', 0.2);

fp = fig2.tile(2);
n = 1e6; t = linspace(t0, t1, n); s = sec(t);
fp.addLine(t, 1500 + 300*sin(s*2*pi/900) + 50*randn(1,n), ...
    'DisplayName', 'RPM', 'DownsampleMethod', 'lttb');

dock.addTab(fig2, 'Power Systems');

% =========================================================================
% Tab 3: Hydraulics (2x1)
% =========================================================================
fig3 = FastSenseGrid(2, 1, 'ParentFigure', dock.hFigure, 'Theme', 'light');

fp = fig3.tile(1);
n = 1.5e6; t = linspace(t0, t1, n); s = sec(t);
fp.addLine(t, 220 + 30*sin(s*2*pi/500) + 10*randn(1,n), 'DisplayName', 'Hydraulic Pressure');
fp.addLine(t, 200 + 25*sin(s*2*pi/500 + 1) + 8*randn(1,n), 'DisplayName', 'Return Line');
fp.addBand(180, 260, 'FaceColor', [0.2 0.8 0.4], 'FaceAlpha', 0.08);

fp = fig3.tile(2);
n = 1e6; t = linspace(t0, t1, n); s = sec(t);
meta3.datenum  = datenum([t0, t0+minutes(20), t0+minutes(40)]);
meta3.oil_type = {'Synthetic 5W-30', 'Synthetic 5W-30', 'Mineral 10W-40'};
meta3.filter   = {'new', 'used', 'new'};
fp.addLine(t, 55 + 10*sin(s*2*pi/1800) + 2*randn(1,n), 'DisplayName', 'Oil Temp', 'Metadata', meta3);
fp.addThreshold(70, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'Overheat');

dock.addTab(fig3, 'Hydraulics');

% =========================================================================
% Tab 4: Electrical Grid (1x3)
% =========================================================================
fig4 = FastSenseGrid(1, 3, 'ParentFigure', dock.hFigure, 'Theme', 'light');

fp = fig4.tile(1);
n = 2e6; t = linspace(t0, t1, n); s = sec(t);
fp.addLine(t, 230 + 5*sin(s*2*pi/120) + 2*randn(1,n), 'DisplayName', 'Phase A');
fp.addLine(t, 230 + 5*sin(s*2*pi/120 + 2.09) + 2*randn(1,n), 'DisplayName', 'Phase B');
fp.addLine(t, 230 + 5*sin(s*2*pi/120 + 4.19) + 2*randn(1,n), 'DisplayName', 'Phase C');

fp = fig4.tile(2);
n = 1e6; t = linspace(t0, t1, n); s = sec(t);
fp.addLine(t, 50 + 0.02*sin(s*2*pi/60) + 0.005*randn(1,n), 'DisplayName', 'Frequency');
fp.addBand(49.95, 50.05, 'FaceColor', [0.3 1 0.3], 'FaceAlpha', 0.1);

fp = fig4.tile(3);
n = 800000; t = linspace(t0, t1, n); s = sec(t);
load = 450 + 150*sin(s*2*pi/3600) + 30*randn(1,n);
fp.addLine(t, load, 'DisplayName', 'Load (kW)');
fp.addFill(t, load, 'FaceColor', [0.8 0.3 0.3], 'FaceAlpha', 0.15);
fp.addThreshold(600, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'Peak');

dock.addTab(fig4, 'Electrical Grid');

% =========================================================================
% Tab 5: Environment (2x2) — 24h span
% =========================================================================
fig5 = FastSenseGrid(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'light');

te0 = datetime(2026, 3, 8, 0, 0, 0);
te1 = datetime(2026, 3, 8, 23, 59, 59);
secE = @(t) seconds(t - te0);

fp = fig5.tile(1);
n = 1e6; t = linspace(te0, te1, n); s = secE(t);
fp.addLine(t, 22 + 4*sin(s*2*pi/86400) + 0.5*randn(1,n), 'DisplayName', 'Room Temp');
fp.addBand(20, 25, 'FaceColor', [0.2 0.6 1], 'FaceAlpha', 0.1);

fp = fig5.tile(2);
n = 800000; t = linspace(te0, te1, n); s = secE(t);
fp.addLine(t, 45 + 15*sin(s*2*pi/43200) + 5*randn(1,n), 'DisplayName', 'Humidity %');
fp.addThreshold(65, 'Direction', 'upper', 'ShowViolations', true);

fp = fig5.tile(3);
n = 500000; t = linspace(te0, te1, n); s = secE(t);
fp.addLine(t, 35 + 8*sin(s*2*pi/7200) + 3*randn(1,n), 'DisplayName', 'dB Level');
fp.addThreshold(50, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'Loud');

fp = fig5.tile(4);
n = 600000; t = linspace(te0, te1, n); s = secE(t);
co2 = 400 + 100*sin(s*2*pi/43200) + 20*randn(1,n);
fp.addLine(t, co2, 'DisplayName', 'CO2 (ppm)');
fp.addThreshold(800, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'Ventilate');

dock.addTab(fig5, 'Environment');

% =========================================================================
% Render and label
% =========================================================================
dock.renderAll();

fig1.setTileTitle(1, 'Temperature (2M pts)');
fig1.setTileYLabel(1, 'Temp (°F)');
fig1.setTileTitle(2, 'Coolant Flow (1M pts)');
fig1.setTileYLabel(2, 'Flow (L/min)');
fig1.setTileTitle(3, 'Reactor Pressure (500K pts)');
fig1.setTileYLabel(3, 'Pressure (kPa)');
fig1.setTileTitle(4, 'Vibration (800K pts)');
fig1.setTileYLabel(4, 'Amplitude (g)');

fig2.setTileTitle(1, 'Motor Current (3M pts)');
fig2.setTileYLabel(1, 'Current (A)');
fig2.setTileTitle(2, 'RPM — LTTB (1M pts)');
fig2.setTileYLabel(2, 'RPM');

fig3.setTileTitle(1, 'Hydraulic Pressure (1.5M pts)');
fig3.setTileYLabel(1, 'Pressure (bar)');
fig3.setTileTitle(2, 'Oil Temperature (1M pts)');
fig3.setTileYLabel(2, 'Temp (°C)');

fig4.setTileTitle(1, 'Three-Phase Voltage (2M pts)');
fig4.setTileYLabel(1, 'Voltage (V)');
fig4.setTileTitle(2, 'Grid Frequency (1M pts)');
fig4.setTileYLabel(2, 'Freq (Hz)');
fig4.setTileTitle(3, 'Load (800K pts)');
fig4.setTileYLabel(3, 'Power (kW)');

fig5.setTileTitle(1, 'Room Temperature (1M pts)');
fig5.setTileYLabel(1, 'Temp (°C)');
fig5.setTileTitle(2, 'Humidity (800K pts)');
fig5.setTileYLabel(2, 'RH (%)');
fig5.setTileTitle(3, 'Noise Level (500K pts)');
fig5.setTileYLabel(3, 'Level (dB)');
fig5.setTileTitle(4, 'CO2 (600K pts)');
fig5.setTileYLabel(4, 'CO2 (ppm)');

elapsed = toc;
fprintf('Docked tabs rendered in %.2f seconds (~21M total pts).\n', elapsed);
fprintf('Click tabs at top to switch between 5 dashboards.\n');
