%% FastSenseDock — Disk-Backed Dashboard with Dynamic Thresholds
%
% Five dashboards in a tabbed dock window, all using disk-backed storage.
% Each sensor has state-dependent (dynamic) thresholds that change with
% operating mode.  Data sizes range from 1M to 10M points per tile.
%
% Total: ~100M data points across 5 tabs, 18 tiles, 35 sensors.
%
%   Tab 1: Turbine Monitoring     — 2x2, 4 tiles, 8 sensors   (~28M pts)
%   Tab 2: Chemical Process       — 2x2, 4 tiles, 8 sensors   (~22M pts)
%   Tab 3: Compressor Station     — 1x3, 3 tiles, 6 sensors   (~18M pts)
%   Tab 4: Power Generation       — 2x2, 4 tiles, 8 sensors   (~24M pts)
%   Tab 5: Environmental          — 1x3, 3 tiles, 5 sensors   (~11M pts)

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

wState = warning('off', 'all');
restoreWarn = onCleanup(@() warning(wState));

fprintf('=== Disk-Backed Dock Dashboard ===\n');
fprintf('Generating ~100M data points across 5 tabs (all disk-backed)...\n\n');
tic;

dock = FastSenseDock('Theme', 'dark', 'Name', 'Plant Control Room — Disk Mode', ...
    'Position', [50 50 1500 900]);

% ---------- Shared time base: 8h shift ----------
t0 = datetime(2026, 3, 12,  6, 0, 0);
t1 = datetime(2026, 3, 12, 14, 0, 0);
tdn0 = datenum(t0);
tdn1 = datenum(t1);

% =========================================================================
% Tab 1: Turbine Monitoring (2x2) — ~28M points
% =========================================================================
fprintf('Tab 1: Turbine Monitoring...\n');
fig1 = FastSenseGrid(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

% Turbine operates in 3 modes over the shift
scTurbine = StateTag('turbine', 'X', [tdn0, tdn0 + 1/24, tdn0 + 3/24, tdn0 + 6/24], 'Y', [0, 1, 2, 1];  % 0=startup, 1=running, 2=high-load);

% --- Tile 1: Exhaust Gas Temperature (3 sensors, 10M pts) ---
n = 10e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s1a = SensorTag('egt_a', 'Name', 'EGT Channel A');
s1a_y_ = 580 + 40*sin(2*pi*sec/3600) + 15*randn(1,n);
s1a_y_(round(n*0.35):round(n*0.36)) = s1a_y_(round(n*0.35):round(n*0.36)) + 80;
s1a.updateData(tdn, s1a_y_);

s1a.toDisk();

s1b = SensorTag('egt_b', 'Name', 'EGT Channel B');
s1b.updateData(tdn, 575 + 38*sin(2*pi*sec/3600 + 0.3) + 12*randn(1,n));
s1b.toDisk();

fp = fig1.tile(1);
fp.addTag(s1a, 'ShowThresholds', true);
fp.addTag(s1b, 'ShowThresholds', true);
fig1.setTileTitle(1, 'Exhaust Gas Temperature (10M pts)');
fig1.setTileYLabel(1, 'Temp (°C)');

% --- Tile 2: Bearing Vibration (2 sensors, 8M pts) ---
n = 8e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s2a = SensorTag('vib_de', 'Name', 'DE Bearing');
s2a_y_ = 2.1 + 0.8*sin(2*pi*sec/1800) + 0.3*randn(1,n);
s2a_y_(round(n*0.6):round(n*0.62)) = s2a_y_(round(n*0.6):round(n*0.62)) + 3.5;
s2a.updateData(tdn, s2a_y_);


s2a.toDisk();

s2b = SensorTag('vib_nde', 'Name', 'NDE Bearing');
s2b.updateData(tdn, 1.8 + 0.6*sin(2*pi*sec/1800 + 1) + 0.25*randn(1,n));
s2b.toDisk();

fp = fig1.tile(2);
fp.addTag(s2a, 'ShowThresholds', true);
fp.addTag(s2b, 'ShowThresholds', true);
fig1.setTileTitle(2, 'Bearing Vibration (8M pts)');
fig1.setTileYLabel(2, 'Velocity (mm/s)');

% --- Tile 3: Lube Oil (3 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s3a = SensorTag('oil_temp', 'Name', 'Oil Temperature');
s3a.updateData(tdn, 62 + 8*sin(2*pi*sec/7200) + 2*randn(1,n));

s3a.toDisk();

s3b = SensorTag('oil_press', 'Name', 'Oil Pressure');
s3b.updateData(tdn, 3.8 + 0.5*sin(2*pi*sec/5400) + 0.15*randn(1,n));
s3b.toDisk();

s3c = SensorTag('oil_flow', 'Name', 'Oil Flow');
s3c.updateData(tdn, 45 + 5*sin(2*pi*sec/3600) + 2*randn(1,n));
s3c.toDisk();

fp = fig1.tile(3);
fp.addTag(s3a, 'ShowThresholds', true);
fp.addTag(s3b, 'ShowThresholds', true);
fp.addTag(s3c, 'ShowThresholds', true);
fig1.setTileTitle(3, 'Lube Oil System (5M pts)');
fig1.setTileYLabel(3, 'Mixed Units');

% --- Tile 4: Speed / Power (1 sensor, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s4a = SensorTag('rpm', 'Name', 'Shaft Speed');
s4a.updateData(tdn, 3000 + 50*sin(2*pi*sec/14400) + 15*randn(1,n));


s4a.toDisk();

fp = fig1.tile(4);
fp.addTag(s4a, 'ShowThresholds', true);
fig1.setTileTitle(4, 'Shaft Speed (5M pts)');
fig1.setTileYLabel(4, 'RPM');

dock.addTab(fig1, 'Turbine');

% =========================================================================
% Tab 2: Chemical Process (2x2) — ~22M points
% =========================================================================
fprintf('Tab 2: Chemical Process...\n');
fig2 = FastSenseGrid(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

% Reactor modes: batch phases
scReactor = StateTag('phase', 'X', [tdn0, tdn0+1/24, tdn0+2.5/24, tdn0+5/24, tdn0+6.5/24], 'Y', [0, 1, 2, 3, 1];  % 0=idle, 1=heat, 2=react, 3=cool);

% --- Tile 1: Reactor Temperature (2 sensors, 8M pts) ---
n = 8e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s5a = SensorTag('rx_temp', 'Name', 'Reactor Core');
s5a_y_ = 180 + 30*sin(2*pi*sec/7200) + 5*randn(1,n);
s5a_y_(round(n*0.25):round(n*0.27)) = s5a_y_(round(n*0.25):round(n*0.27)) + 40;
s5a.updateData(tdn, s5a_y_);


s5a.toDisk();

s5b = SensorTag('rx_jacket', 'Name', 'Jacket Temp');
s5b.updateData(tdn, 170 + 25*sin(2*pi*sec/7200 + 0.5) + 4*randn(1,n));
s5b.toDisk();

fp = fig2.tile(1);
fp.addTag(s5a, 'ShowThresholds', true);
fp.addTag(s5b, 'ShowThresholds', true);
fig2.setTileTitle(1, 'Reactor Temperature (8M pts)');
fig2.setTileYLabel(1, 'Temp (°C)');

% --- Tile 2: Reactor Pressure (2 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s6a = SensorTag('rx_press', 'Name', 'Vessel Pressure');
s6a.updateData(tdn, 12 + 3*sin(2*pi*sec/5400) + 0.8*randn(1,n));

s6a.toDisk();

s6b = SensorTag('rx_dp', 'Name', 'Delta-P');
s6b.updateData(tdn, 0.8 + 0.3*sin(2*pi*sec/3600) + 0.1*randn(1,n));
s6b.toDisk();

fp = fig2.tile(2);
fp.addTag(s6a, 'ShowThresholds', true);
fp.addTag(s6b, 'ShowThresholds', true);
fig2.setTileTitle(2, 'Reactor Pressure (5M pts)');
fig2.setTileYLabel(2, 'bar / bar');

% --- Tile 3: pH + Conductivity (2 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s7a = SensorTag('ph', 'Name', 'pH');
s7a.updateData(tdn, 7.0 + 0.8*sin(2*pi*sec/10800) + 0.15*randn(1,n));

s7a.toDisk();

s7b = SensorTag('cond', 'Name', 'Conductivity');
s7b.updateData(tdn, 450 + 80*sin(2*pi*sec/5400) + 20*randn(1,n));
s7b.toDisk();

fp = fig2.tile(3);
fp.addTag(s7a, 'ShowThresholds', true);
fp.addTag(s7b, 'ShowThresholds', true);
fig2.setTileTitle(3, 'pH & Conductivity (5M pts)');
fig2.setTileYLabel(3, 'pH / µS/cm');

% --- Tile 4: Agitator (2 sensors, 4M pts) ---
n = 4e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s8a = SensorTag('agit_rpm', 'Name', 'Agitator RPM');
s8a.updateData(tdn, 120 + 15*sin(2*pi*sec/3600) + 5*randn(1,n));

s8a.toDisk();

s8b = SensorTag('agit_torque', 'Name', 'Agitator Torque');
s8b.updateData(tdn, 85 + 20*sin(2*pi*sec/5400) + 8*randn(1,n));
s8b.toDisk();

fp = fig2.tile(4);
fp.addTag(s8a, 'ShowThresholds', true);
fp.addTag(s8b, 'ShowThresholds', true);
fig2.setTileTitle(4, 'Agitator (4M pts)');
fig2.setTileYLabel(4, 'RPM / N·m');

dock.addTab(fig2, 'Chemical');

% =========================================================================
% Tab 3: Compressor Station (1x3) — ~18M points
% =========================================================================
fprintf('Tab 3: Compressor Station...\n');
fig3 = FastSenseGrid(1, 3, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

% Compressor modes
scComp = StateTag('stage', 'X', [tdn0, tdn0+0.5/24, tdn0+2/24, tdn0+5/24, tdn0+7/24], 'Y', [0, 1, 2, 1, 2];  % 0=off, 1=single-stage, 2=dual-stage);

% --- Tile 1: Suction/Discharge (3 sensors, 8M pts) ---
n = 8e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s9a = SensorTag('suct_press', 'Name', 'Suction Pressure');
s9a.updateData(tdn, 2.5 + 0.4*sin(2*pi*sec/3600) + 0.1*randn(1,n));

s9a.toDisk();

s9b = SensorTag('disc_press', 'Name', 'Discharge Pressure');
s9b_y_ = 14 + 2*sin(2*pi*sec/2700) + 0.5*randn(1,n);
s9b_y_(round(n*0.55):round(n*0.56)) = s9b_y_(round(n*0.55):round(n*0.56)) + 5;
s9b.updateData(tdn, s9b_y_);

s9b.toDisk();

s9c = SensorTag('comp_ratio', 'Name', 'Compression Ratio');
s9c.updateData(tdn, 5.5 + 0.8*sin(2*pi*sec/5400) + 0.2*randn(1,n));
s9c.toDisk();

fp = fig3.tile(1);
fp.addTag(s9a, 'ShowThresholds', true);
fp.addTag(s9b, 'ShowThresholds', true);
fp.addTag(s9c, 'ShowThresholds', true);
fig3.setTileTitle(1, 'Pressures (8M pts)');
fig3.setTileYLabel(1, 'bar');

% --- Tile 2: Temperatures (2 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s10a = SensorTag('disc_temp', 'Name', 'Discharge Temp');
s10a.updateData(tdn, 140 + 20*sin(2*pi*sec/5400) + 5*randn(1,n));

s10a.toDisk();

s10b = SensorTag('intercool', 'Name', 'Intercooler Out');
s10b.updateData(tdn, 45 + 8*sin(2*pi*sec/3600) + 2*randn(1,n));
s10b.toDisk();

fp = fig3.tile(2);
fp.addTag(s10a, 'ShowThresholds', true);
fp.addTag(s10b, 'ShowThresholds', true);
fig3.setTileTitle(2, 'Temperatures (5M pts)');
fig3.setTileYLabel(2, 'Temp (°C)');

% --- Tile 3: Anti-Surge (1 sensor, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s11a = SensorTag('surge_margin', 'Name', 'Surge Margin');
s11a_y_ = 25 + 8*sin(2*pi*sec/1800) + 3*randn(1,n);
s11a_y_(round(n*0.4):round(n*0.41)) = s11a_y_(round(n*0.4):round(n*0.41)) - 20;
s11a.updateData(tdn, s11a_y_);


s11a.toDisk();

fp = fig3.tile(3);
fp.addTag(s11a, 'ShowThresholds', true);
fig3.setTileTitle(3, 'Surge Margin (5M pts)');
fig3.setTileYLabel(3, 'Margin (%)');

dock.addTab(fig3, 'Compressor');

% =========================================================================
% Tab 4: Power Generation (2x2) — ~24M points
% =========================================================================
fprintf('Tab 4: Power Generation...\n');
fig4 = FastSenseGrid(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

% Generator modes
scGen = StateTag('gen', 'X', [tdn0, tdn0+0.5/24, tdn0+3/24, tdn0+6/24], 'Y', [0, 1, 2, 1];  % 0=sync, 1=base-load, 2=peak);

% --- Tile 1: Three-Phase Voltage (3 sensors, 9M pts) ---
n = 3e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

phases = {'A', 'B', 'C'};
phaseShifts = [0, 2*pi/3, 4*pi/3];
for p = 1:3
    sV = SensorTag(sprintf('v_phase_%s', phases{p}), 'Name', sprintf('Phase %s', phases{p}), 'X', tdn, 'Y', 400 + 8*sin(2*pi*sec/1200 + phaseShifts(p)) + 3*randn(1,n));

    sV.toDisk();
    fp = fig4.tile(1);
    fp.addTag(sV, 'ShowThresholds', true);
end
fig4.setTileTitle(1, 'Three-Phase Voltage (9M pts)');
fig4.setTileYLabel(1, 'Voltage (V)');

% --- Tile 2: Frequency + Power Factor (2 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s13a = SensorTag('freq', 'Name', 'Grid Frequency');
s13a.updateData(tdn, 50 + 0.03*sin(2*pi*sec/600) + 0.008*randn(1,n));


s13a.toDisk();

s13b = SensorTag('pf', 'Name', 'Power Factor');
s13b.updateData(tdn, 0.95 + 0.03*sin(2*pi*sec/3600) + 0.005*randn(1,n));
s13b.toDisk();

fp = fig4.tile(2);
fp.addTag(s13a, 'ShowThresholds', true);
fp.addTag(s13b, 'ShowThresholds', true);
fig4.setTileTitle(2, 'Frequency & PF (5M pts)');
fig4.setTileYLabel(2, 'Hz / PF');

% --- Tile 3: Active Power (1 sensor, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s14 = SensorTag('mw', 'Name', 'Active Power');
s14.updateData(tdn, 180 + 40*sin(2*pi*sec/7200) + 10*randn(1,n));


s14.toDisk();

fp = fig4.tile(3);
fp.addTag(s14, 'ShowThresholds', true);
fig4.setTileTitle(3, 'Active Power (5M pts)');
fig4.setTileYLabel(3, 'MW');

% --- Tile 4: Stator + Rotor Temp (2 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s15a = SensorTag('stator_temp', 'Name', 'Stator Winding');
s15a.updateData(tdn, 95 + 15*sin(2*pi*sec/7200) + 3*randn(1,n));

s15a.toDisk();

s15b = SensorTag('rotor_temp', 'Name', 'Rotor');
s15b.updateData(tdn, 85 + 12*sin(2*pi*sec/7200 + 0.3) + 3*randn(1,n));
s15b.toDisk();

fp = fig4.tile(4);
fp.addTag(s15a, 'ShowThresholds', true);
fp.addTag(s15b, 'ShowThresholds', true);
fig4.setTileTitle(4, 'Generator Temps (5M pts)');
fig4.setTileYLabel(4, 'Temp (°C)');

dock.addTab(fig4, 'Power Gen');

% =========================================================================
% Tab 5: Environmental (1x3) — ~11M points
% =========================================================================
fprintf('Tab 5: Environmental...\n');
fig5 = FastSenseGrid(1, 3, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

% HVAC modes
scHvac = StateTag('hvac', 'X', [tdn0, tdn0+1/24, tdn0+4/24, tdn0+7/24], 'Y', [0, 1, 2, 1];  % 0=night, 1=normal, 2=boost);

% --- Tile 1: Air Quality (2 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s16a = SensorTag('co2', 'Name', 'CO₂');
s16a.updateData(tdn, 450 + 150*sin(2*pi*sec/14400) + 30*randn(1,n));


s16a.toDisk();

s16b = SensorTag('pm25', 'Name', 'PM2.5');
s16b.updateData(tdn, 8 + 5*sin(2*pi*sec/10800) + 2*randn(1,n));
s16b.toDisk();

fp = fig5.tile(1);
fp.addTag(s16a, 'ShowThresholds', true);
fp.addTag(s16b, 'ShowThresholds', true);
fig5.setTileTitle(1, 'Air Quality (5M pts)');
fig5.setTileYLabel(1, 'ppm / µg/m³');

% --- Tile 2: Temperature & Humidity (2 sensors, 3M pts) ---
n = 3e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s17a = SensorTag('room_temp', 'Name', 'Room Temp');
s17a.updateData(tdn, 22 + 3*sin(2*pi*sec/14400) + 0.5*randn(1,n));

s17a.toDisk();

s17b = SensorTag('rh', 'Name', 'Rel. Humidity');
s17b.updateData(tdn, 45 + 12*sin(2*pi*sec/10800) + 3*randn(1,n));

s17b.toDisk();

fp = fig5.tile(2);
fp.addTag(s17a, 'ShowThresholds', true);
fp.addTag(s17b, 'ShowThresholds', true);
fig5.setTileTitle(2, 'Temp & Humidity (3M pts)');
fig5.setTileYLabel(2, '°C / %RH');

% --- Tile 3: Noise Level (1 sensor, 3M pts) ---
n = 3e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s18 = SensorTag('noise', 'Name', 'Noise Level');
s18_y_ = 55 + 10*sin(2*pi*sec/7200) + 4*randn(1,n);
s18_y_(round(n*0.5):round(n*0.52)) = s18_y_(round(n*0.5):round(n*0.52)) + 25;
s18.updateData(tdn, s18_y_);


s18.toDisk();

fp = fig5.tile(3);
fp.addTag(s18, 'ShowThresholds', true);
fig5.setTileTitle(3, 'Noise Level (3M pts)');
fig5.setTileYLabel(3, 'dB(A)');

dock.addTab(fig5, 'Environmental');

% =========================================================================
% Render all tabs
% =========================================================================
fprintf('\nRendering all 5 tabs...\n');
dock.renderAll();

elapsed = toc;
fprintf('\n=== Dock dashboard ready in %.1f seconds ===\n', elapsed);
fprintf('  5 tabs, 18 tiles, 35 sensors, ~103M points (all disk-backed)\n');
fprintf('  Every sensor has state-dependent dynamic thresholds.\n');
fprintf('  Click tabs to switch dashboards. Zoom/pan to explore.\n');
