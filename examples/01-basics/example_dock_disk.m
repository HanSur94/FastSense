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
scTurbine = StateChannel('turbine');
scTurbine.X = [tdn0, tdn0 + 1/24, tdn0 + 3/24, tdn0 + 6/24];
scTurbine.Y = [0, 1, 2, 1];  % 0=startup, 1=running, 2=high-load

% --- Tile 1: Exhaust Gas Temperature (3 sensors, 10M pts) ---
n = 10e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s1a = Sensor('egt_a', 'Name', 'EGT Channel A');
s1a.X = tdn; s1a.Y = 580 + 40*sin(2*pi*sec/3600) + 15*randn(1,n);
s1a.Y(round(n*0.35):round(n*0.36)) = s1a.Y(round(n*0.35):round(n*0.36)) + 80;
s1a.addStateChannel(scTurbine);
tHAlarmRun = Threshold('h_alarm_run', 'Name', 'H Alarm (Run)', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tHAlarmRun.addCondition(struct('turbine', 1), 640);
s1a.addThreshold(tHAlarmRun);

tHAlarmHiLoad = Threshold('h_alarm_hiload', 'Name', 'H Alarm (HiLoad)', ...
    'Direction', 'upper', 'Color', [1 0 0]);
tHAlarmHiLoad.addCondition(struct('turbine', 2), 620);
s1a.addThreshold(tHAlarmHiLoad);
s1a.toDisk();

s1b = Sensor('egt_b', 'Name', 'EGT Channel B');
s1b.X = tdn; s1b.Y = 575 + 38*sin(2*pi*sec/3600 + 0.3) + 12*randn(1,n);
s1b.addStateChannel(scTurbine);
tHAlarmS1b = Threshold('h_alarm', 'Name', 'H Alarm', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tHAlarmS1b.addCondition(struct('turbine', 1), 640);
s1b.addThreshold(tHAlarmS1b);
s1b.toDisk();

fp = fig1.tile(1);
fp.addSensor(s1a, 'ShowThresholds', true);
fp.addSensor(s1b, 'ShowThresholds', true);
fig1.setTileTitle(1, 'Exhaust Gas Temperature (10M pts)');
fig1.setTileYLabel(1, 'Temp (°C)');

% --- Tile 2: Bearing Vibration (2 sensors, 8M pts) ---
n = 8e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s2a = Sensor('vib_de', 'Name', 'DE Bearing');
s2a.X = tdn; s2a.Y = 2.1 + 0.8*sin(2*pi*sec/1800) + 0.3*randn(1,n);
s2a.Y(round(n*0.6):round(n*0.62)) = s2a.Y(round(n*0.6):round(n*0.62)) + 3.5;
s2a.addStateChannel(scTurbine);
tWarnRun = Threshold('warn_run', 'Name', 'Warn (Run)', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tWarnRun.addCondition(struct('turbine', 1), 4.0);
s2a.addThreshold(tWarnRun);

tWarnHiLoad = Threshold('warn_hiload', 'Name', 'Warn (HiLoad)', ...
    'Direction', 'upper', 'Color', [1 0.4 0]);
tWarnHiLoad.addCondition(struct('turbine', 2), 3.5);
s2a.addThreshold(tWarnHiLoad);

tTripRun = Threshold('trip_run', 'Name', 'Trip (Run)', ...
    'Direction', 'upper', 'Color', [1 0 0]);
tTripRun.addCondition(struct('turbine', 1), 6.0);
s2a.addThreshold(tTripRun);
s2a.toDisk();

s2b = Sensor('vib_nde', 'Name', 'NDE Bearing');
s2b.X = tdn; s2b.Y = 1.8 + 0.6*sin(2*pi*sec/1800 + 1) + 0.25*randn(1,n);
s2b.addStateChannel(scTurbine);
tWarnS2b = Threshold('warn', 'Name', 'Warn', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tWarnS2b.addCondition(struct('turbine', 1), 4.0);
s2b.addThreshold(tWarnS2b);
s2b.toDisk();

fp = fig1.tile(2);
fp.addSensor(s2a, 'ShowThresholds', true);
fp.addSensor(s2b, 'ShowThresholds', true);
fig1.setTileTitle(2, 'Bearing Vibration (8M pts)');
fig1.setTileYLabel(2, 'Velocity (mm/s)');

% --- Tile 3: Lube Oil (3 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s3a = Sensor('oil_temp', 'Name', 'Oil Temperature');
s3a.X = tdn; s3a.Y = 62 + 8*sin(2*pi*sec/7200) + 2*randn(1,n);
s3a.addStateChannel(scTurbine);
tHighTemp = Threshold('high_temp', 'Name', 'High Temp', ...
    'Direction', 'upper', 'Color', [1 0.5 0]);
tHighTemp.addCondition(struct('turbine', 1), 75);
s3a.addThreshold(tHighTemp);

tColdStart = Threshold('cold_start', 'Name', 'Cold Start', ...
    'Direction', 'lower', 'Color', [0.3 0.6 1]);
tColdStart.addCondition(struct('turbine', 0), 40);
s3a.addThreshold(tColdStart);
s3a.toDisk();

s3b = Sensor('oil_press', 'Name', 'Oil Pressure');
s3b.X = tdn; s3b.Y = 3.8 + 0.5*sin(2*pi*sec/5400) + 0.15*randn(1,n);
s3b.addStateChannel(scTurbine);
tLowPress = Threshold('low_press', 'Name', 'Low Press', ...
    'Direction', 'lower', 'Color', [1 0 0]);
tLowPress.addCondition(struct('turbine', 1), 3.0);
s3b.addThreshold(tLowPress);
s3b.toDisk();

s3c = Sensor('oil_flow', 'Name', 'Oil Flow');
s3c.X = tdn; s3c.Y = 45 + 5*sin(2*pi*sec/3600) + 2*randn(1,n);
s3c.addStateChannel(scTurbine);
tLowFlow = Threshold('low_flow', 'Name', 'Low Flow', ...
    'Direction', 'lower', 'Color', [1 0.75 0]);
tLowFlow.addCondition(struct('turbine', 1), 38);
s3c.addThreshold(tLowFlow);
s3c.toDisk();

fp = fig1.tile(3);
fp.addSensor(s3a, 'ShowThresholds', true);
fp.addSensor(s3b, 'ShowThresholds', true);
fp.addSensor(s3c, 'ShowThresholds', true);
fig1.setTileTitle(3, 'Lube Oil System (5M pts)');
fig1.setTileYLabel(3, 'Mixed Units');

% --- Tile 4: Speed / Power (1 sensor, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s4a = Sensor('rpm', 'Name', 'Shaft Speed');
s4a.X = tdn; s4a.Y = 3000 + 50*sin(2*pi*sec/14400) + 15*randn(1,n);
s4a.addStateChannel(scTurbine);
tOverspeedWarn = Threshold('overspeed_warn', 'Name', 'Overspeed Warn', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tOverspeedWarn.addCondition(struct('turbine', 1), 3100);
s4a.addThreshold(tOverspeedWarn);

tOverspeedTrip = Threshold('overspeed_trip', 'Name', 'Overspeed Trip', ...
    'Direction', 'upper', 'Color', [1 0 0]);
tOverspeedTrip.addCondition(struct('turbine', 1), 3150);
s4a.addThreshold(tOverspeedTrip);

tUnderspeed = Threshold('underspeed', 'Name', 'Underspeed', ...
    'Direction', 'lower', 'Color', [0.3 0.6 1]);
tUnderspeed.addCondition(struct('turbine', 0), 2800);
s4a.addThreshold(tUnderspeed);
s4a.toDisk();

fp = fig1.tile(4);
fp.addSensor(s4a, 'ShowThresholds', true);
fig1.setTileTitle(4, 'Shaft Speed (5M pts)');
fig1.setTileYLabel(4, 'RPM');

dock.addTab(fig1, 'Turbine');

% =========================================================================
% Tab 2: Chemical Process (2x2) — ~22M points
% =========================================================================
fprintf('Tab 2: Chemical Process...\n');
fig2 = FastSenseGrid(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

% Reactor modes: batch phases
scReactor = StateChannel('phase');
scReactor.X = [tdn0, tdn0+1/24, tdn0+2.5/24, tdn0+5/24, tdn0+6.5/24];
scReactor.Y = [0, 1, 2, 3, 1];  % 0=idle, 1=heat, 2=react, 3=cool

% --- Tile 1: Reactor Temperature (2 sensors, 8M pts) ---
n = 8e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s5a = Sensor('rx_temp', 'Name', 'Reactor Core');
s5a.X = tdn; s5a.Y = 180 + 30*sin(2*pi*sec/7200) + 5*randn(1,n);
s5a.Y(round(n*0.25):round(n*0.27)) = s5a.Y(round(n*0.25):round(n*0.27)) + 40;
s5a.addStateChannel(scReactor);
tHeatHh = Threshold('heat_hh', 'Name', 'Heat HH', ...
    'Direction', 'upper', 'Color', [1 0 0]);
tHeatHh.addCondition(struct('phase', 1), 220);
s5a.addThreshold(tHeatHh);

tReactHh = Threshold('react_hh', 'Name', 'React HH', ...
    'Direction', 'upper', 'Color', [1 0.4 0]);
tReactHh.addCondition(struct('phase', 2), 200);
s5a.addThreshold(tReactHh);

tCoolLl = Threshold('cool_ll', 'Name', 'Cool LL', ...
    'Direction', 'lower', 'Color', [0.3 0.6 1]);
tCoolLl.addCondition(struct('phase', 3), 100);
s5a.addThreshold(tCoolLl);
s5a.toDisk();

s5b = Sensor('rx_jacket', 'Name', 'Jacket Temp');
s5b.X = tdn; s5b.Y = 170 + 25*sin(2*pi*sec/7200 + 0.5) + 4*randn(1,n);
s5b.addStateChannel(scReactor);
tJacketHh = Threshold('jacket_hh', 'Name', 'Jacket HH', ...
    'Direction', 'upper', 'Color', [1 0.5 0]);
tJacketHh.addCondition(struct('phase', 2), 210);
s5b.addThreshold(tJacketHh);
s5b.toDisk();

fp = fig2.tile(1);
fp.addSensor(s5a, 'ShowThresholds', true);
fp.addSensor(s5b, 'ShowThresholds', true);
fig2.setTileTitle(1, 'Reactor Temperature (8M pts)');
fig2.setTileYLabel(1, 'Temp (°C)');

% --- Tile 2: Reactor Pressure (2 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s6a = Sensor('rx_press', 'Name', 'Vessel Pressure');
s6a.X = tdn; s6a.Y = 12 + 3*sin(2*pi*sec/5400) + 0.8*randn(1,n);
s6a.addStateChannel(scReactor);
tReactHhPress = Threshold('react_hh', 'Name', 'React HH', ...
    'Direction', 'upper', 'Color', [1 0 0]);
tReactHhPress.addCondition(struct('phase', 2), 16);
s6a.addThreshold(tReactHhPress);

tHeatH = Threshold('heat_h', 'Name', 'Heat H', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tHeatH.addCondition(struct('phase', 1), 14);
s6a.addThreshold(tHeatH);
s6a.toDisk();

s6b = Sensor('rx_dp', 'Name', 'Delta-P');
s6b.X = tdn; s6b.Y = 0.8 + 0.3*sin(2*pi*sec/3600) + 0.1*randn(1,n);
s6b.addStateChannel(scReactor);
tDpHigh = Threshold('dp_high', 'Name', 'dP High', ...
    'Direction', 'upper', 'Color', [1 0.5 0]);
tDpHigh.addCondition(struct('phase', 2), 1.5);
s6b.addThreshold(tDpHigh);
s6b.toDisk();

fp = fig2.tile(2);
fp.addSensor(s6a, 'ShowThresholds', true);
fp.addSensor(s6b, 'ShowThresholds', true);
fig2.setTileTitle(2, 'Reactor Pressure (5M pts)');
fig2.setTileYLabel(2, 'bar / bar');

% --- Tile 3: pH + Conductivity (2 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s7a = Sensor('ph', 'Name', 'pH');
s7a.X = tdn; s7a.Y = 7.0 + 0.8*sin(2*pi*sec/10800) + 0.15*randn(1,n);
s7a.addStateChannel(scReactor);
tPhHigh = Threshold('ph_high', 'Name', 'pH High', ...
    'Direction', 'upper', 'Color', [1 0.4 0]);
tPhHigh.addCondition(struct('phase', 2), 8.0);
s7a.addThreshold(tPhHigh);

tPhLow = Threshold('ph_low', 'Name', 'pH Low', ...
    'Direction', 'lower', 'Color', [0.3 0.6 1]);
tPhLow.addCondition(struct('phase', 2), 6.0);
s7a.addThreshold(tPhLow);
s7a.toDisk();

s7b = Sensor('cond', 'Name', 'Conductivity');
s7b.X = tdn; s7b.Y = 450 + 80*sin(2*pi*sec/5400) + 20*randn(1,n);
s7b.addStateChannel(scReactor);
tCondHigh = Threshold('cond_high', 'Name', 'Cond High', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tCondHigh.addCondition(struct('phase', 1), 600);
s7b.addThreshold(tCondHigh);
s7b.toDisk();

fp = fig2.tile(3);
fp.addSensor(s7a, 'ShowThresholds', true);
fp.addSensor(s7b, 'ShowThresholds', true);
fig2.setTileTitle(3, 'pH & Conductivity (5M pts)');
fig2.setTileYLabel(3, 'pH / µS/cm');

% --- Tile 4: Agitator (2 sensors, 4M pts) ---
n = 4e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s8a = Sensor('agit_rpm', 'Name', 'Agitator RPM');
s8a.X = tdn; s8a.Y = 120 + 15*sin(2*pi*sec/3600) + 5*randn(1,n);
s8a.addStateChannel(scReactor);
tRpmHigh = Threshold('rpm_high', 'Name', 'RPM High', ...
    'Direction', 'upper', 'Color', [1 0.5 0]);
tRpmHigh.addCondition(struct('phase', 2), 145);
s8a.addThreshold(tRpmHigh);

tRpmLow = Threshold('rpm_low', 'Name', 'RPM Low', ...
    'Direction', 'lower', 'Color', [0.3 0.6 1]);
tRpmLow.addCondition(struct('phase', 0), 80);
s8a.addThreshold(tRpmLow);
s8a.toDisk();

s8b = Sensor('agit_torque', 'Name', 'Agitator Torque');
s8b.X = tdn; s8b.Y = 85 + 20*sin(2*pi*sec/5400) + 8*randn(1,n);
s8b.addStateChannel(scReactor);
tTorqueHh = Threshold('torque_hh', 'Name', 'Torque HH', ...
    'Direction', 'upper', 'Color', [1 0 0]);
tTorqueHh.addCondition(struct('phase', 2), 120);
s8b.addThreshold(tTorqueHh);
s8b.toDisk();

fp = fig2.tile(4);
fp.addSensor(s8a, 'ShowThresholds', true);
fp.addSensor(s8b, 'ShowThresholds', true);
fig2.setTileTitle(4, 'Agitator (4M pts)');
fig2.setTileYLabel(4, 'RPM / N·m');

dock.addTab(fig2, 'Chemical');

% =========================================================================
% Tab 3: Compressor Station (1x3) — ~18M points
% =========================================================================
fprintf('Tab 3: Compressor Station...\n');
fig3 = FastSenseGrid(1, 3, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

% Compressor modes
scComp = StateChannel('stage');
scComp.X = [tdn0, tdn0+0.5/24, tdn0+2/24, tdn0+5/24, tdn0+7/24];
scComp.Y = [0, 1, 2, 1, 2];  % 0=off, 1=single-stage, 2=dual-stage

% --- Tile 1: Suction/Discharge (3 sensors, 8M pts) ---
n = 8e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s9a = Sensor('suct_press', 'Name', 'Suction Pressure');
s9a.X = tdn; s9a.Y = 2.5 + 0.4*sin(2*pi*sec/3600) + 0.1*randn(1,n);
s9a.addStateChannel(scComp);
tSuctLowS1 = Threshold('suct_low_s1', 'Name', 'Suct Low (S1)', ...
    'Direction', 'lower', 'Color', [0.3 0.6 1]);
tSuctLowS1.addCondition(struct('stage', 1), 1.8);
s9a.addThreshold(tSuctLowS1);

tSuctLowS2 = Threshold('suct_low_s2', 'Name', 'Suct Low (S2)', ...
    'Direction', 'lower', 'Color', [0 0.4 1]);
tSuctLowS2.addCondition(struct('stage', 2), 2.0);
s9a.addThreshold(tSuctLowS2);
s9a.toDisk();

s9b = Sensor('disc_press', 'Name', 'Discharge Pressure');
s9b.X = tdn; s9b.Y = 14 + 2*sin(2*pi*sec/2700) + 0.5*randn(1,n);
s9b.Y(round(n*0.55):round(n*0.56)) = s9b.Y(round(n*0.55):round(n*0.56)) + 5;
s9b.addStateChannel(scComp);
tDiscHighS1 = Threshold('disc_high_s1', 'Name', 'Disc High (S1)', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tDiscHighS1.addCondition(struct('stage', 1), 17);
s9b.addThreshold(tDiscHighS1);

tDiscHighS2 = Threshold('disc_high_s2', 'Name', 'Disc High (S2)', ...
    'Direction', 'upper', 'Color', [1 0.4 0]);
tDiscHighS2.addCondition(struct('stage', 2), 19);
s9b.addThreshold(tDiscHighS2);
s9b.toDisk();

s9c = Sensor('comp_ratio', 'Name', 'Compression Ratio');
s9c.X = tdn; s9c.Y = 5.5 + 0.8*sin(2*pi*sec/5400) + 0.2*randn(1,n);
s9c.addStateChannel(scComp);
tRatioHigh = Threshold('ratio_high', 'Name', 'Ratio High', ...
    'Direction', 'upper', 'Color', [1 0 0]);
tRatioHigh.addCondition(struct('stage', 2), 7.0);
s9c.addThreshold(tRatioHigh);
s9c.toDisk();

fp = fig3.tile(1);
fp.addSensor(s9a, 'ShowThresholds', true);
fp.addSensor(s9b, 'ShowThresholds', true);
fp.addSensor(s9c, 'ShowThresholds', true);
fig3.setTileTitle(1, 'Pressures (8M pts)');
fig3.setTileYLabel(1, 'bar');

% --- Tile 2: Temperatures (2 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s10a = Sensor('disc_temp', 'Name', 'Discharge Temp');
s10a.X = tdn; s10a.Y = 140 + 20*sin(2*pi*sec/5400) + 5*randn(1,n);
s10a.addStateChannel(scComp);
tTempHhS1 = Threshold('temp_hh_s1', 'Name', 'Temp HH (S1)', ...
    'Direction', 'upper', 'Color', [1 0 0]);
tTempHhS1.addCondition(struct('stage', 1), 170);
s10a.addThreshold(tTempHhS1);

tTempHhS2 = Threshold('temp_hh_s2', 'Name', 'Temp HH (S2)', ...
    'Direction', 'upper', 'Color', [1 0.3 0]);
tTempHhS2.addCondition(struct('stage', 2), 165);
s10a.addThreshold(tTempHhS2);
s10a.toDisk();

s10b = Sensor('intercool', 'Name', 'Intercooler Out');
s10b.X = tdn; s10b.Y = 45 + 8*sin(2*pi*sec/3600) + 2*randn(1,n);
s10b.addStateChannel(scComp);
tIcHigh = Threshold('ic_high', 'Name', 'IC High', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tIcHigh.addCondition(struct('stage', 2), 60);
s10b.addThreshold(tIcHigh);
s10b.toDisk();

fp = fig3.tile(2);
fp.addSensor(s10a, 'ShowThresholds', true);
fp.addSensor(s10b, 'ShowThresholds', true);
fig3.setTileTitle(2, 'Temperatures (5M pts)');
fig3.setTileYLabel(2, 'Temp (°C)');

% --- Tile 3: Anti-Surge (1 sensor, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s11a = Sensor('surge_margin', 'Name', 'Surge Margin');
s11a.X = tdn; s11a.Y = 25 + 8*sin(2*pi*sec/1800) + 3*randn(1,n);
s11a.Y(round(n*0.4):round(n*0.41)) = s11a.Y(round(n*0.4):round(n*0.41)) - 20;
s11a.addStateChannel(scComp);
tSurgeWarnS1 = Threshold('surge_warn_s1', 'Name', 'Surge Warn (S1)', ...
    'Direction', 'lower', 'Color', [1 0.75 0]);
tSurgeWarnS1.addCondition(struct('stage', 1), 10);
s11a.addThreshold(tSurgeWarnS1);

tSurgeWarnS2 = Threshold('surge_warn_s2', 'Name', 'Surge Warn (S2)', ...
    'Direction', 'lower', 'Color', [1 0.4 0]);
tSurgeWarnS2.addCondition(struct('stage', 2), 12);
s11a.addThreshold(tSurgeWarnS2);

tSurgeTrip = Threshold('surge_trip', 'Name', 'Surge Trip', ...
    'Direction', 'lower', 'Color', [1 0 0]);
tSurgeTrip.addCondition(struct('stage', 1), 5);
s11a.addThreshold(tSurgeTrip);
s11a.toDisk();

fp = fig3.tile(3);
fp.addSensor(s11a, 'ShowThresholds', true);
fig3.setTileTitle(3, 'Surge Margin (5M pts)');
fig3.setTileYLabel(3, 'Margin (%)');

dock.addTab(fig3, 'Compressor');

% =========================================================================
% Tab 4: Power Generation (2x2) — ~24M points
% =========================================================================
fprintf('Tab 4: Power Generation...\n');
fig4 = FastSenseGrid(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

% Generator modes
scGen = StateChannel('gen');
scGen.X = [tdn0, tdn0+0.5/24, tdn0+3/24, tdn0+6/24];
scGen.Y = [0, 1, 2, 1];  % 0=sync, 1=base-load, 2=peak

% --- Tile 1: Three-Phase Voltage (3 sensors, 9M pts) ---
n = 3e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

phases = {'A', 'B', 'C'};
phaseShifts = [0, 2*pi/3, 4*pi/3];
for p = 1:3
    sV = Sensor(sprintf('v_phase_%s', phases{p}), 'Name', sprintf('Phase %s', phases{p}));
    sV.X = tdn;
    sV.Y = 400 + 8*sin(2*pi*sec/1200 + phaseShifts(p)) + 3*randn(1,n);
    sV.addStateChannel(scGen);
    tOverV = Threshold(sprintf('%s_over_v', lower(phases{p})), ...
        'Name', sprintf('%s Over-V', phases{p}), ...
        'Direction', 'upper', 'Color', [1 0.75 0]);
    tOverV.addCondition(struct('gen', 1), 415);
    sV.addThreshold(tOverV);

    tUnderV = Threshold(sprintf('%s_under_v', lower(phases{p})), ...
        'Name', sprintf('%s Under-V', phases{p}), ...
        'Direction', 'lower', 'Color', [0.3 0.6 1]);
    tUnderV.addCondition(struct('gen', 1), 385);
    sV.addThreshold(tUnderV);
    sV.toDisk();
    fp = fig4.tile(1);
    fp.addSensor(sV, 'ShowThresholds', true);
end
fig4.setTileTitle(1, 'Three-Phase Voltage (9M pts)');
fig4.setTileYLabel(1, 'Voltage (V)');

% --- Tile 2: Frequency + Power Factor (2 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s13a = Sensor('freq', 'Name', 'Grid Frequency');
s13a.X = tdn; s13a.Y = 50 + 0.03*sin(2*pi*sec/600) + 0.008*randn(1,n);
s13a.addStateChannel(scGen);
tOverFreq = Threshold('over_freq', 'Name', 'Over-Freq', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tOverFreq.addCondition(struct('gen', 1), 50.1);
s13a.addThreshold(tOverFreq);

tUnderFreq = Threshold('under_freq', 'Name', 'Under-Freq', ...
    'Direction', 'lower', 'Color', [0.3 0.6 1]);
tUnderFreq.addCondition(struct('gen', 1), 49.9);
s13a.addThreshold(tUnderFreq);

tOverFreqPeak = Threshold('over_freq_peak', 'Name', 'Over-Freq (Peak)', ...
    'Direction', 'upper', 'Color', [1 0 0]);
tOverFreqPeak.addCondition(struct('gen', 2), 50.15);
s13a.addThreshold(tOverFreqPeak);
s13a.toDisk();

s13b = Sensor('pf', 'Name', 'Power Factor');
s13b.X = tdn; s13b.Y = 0.95 + 0.03*sin(2*pi*sec/3600) + 0.005*randn(1,n);
s13b.addStateChannel(scGen);
tPfLow = Threshold('pf_low', 'Name', 'PF Low', ...
    'Direction', 'lower', 'Color', [1 0.4 0]);
tPfLow.addCondition(struct('gen', 1), 0.90);
s13b.addThreshold(tPfLow);
s13b.toDisk();

fp = fig4.tile(2);
fp.addSensor(s13a, 'ShowThresholds', true);
fp.addSensor(s13b, 'ShowThresholds', true);
fig4.setTileTitle(2, 'Frequency & PF (5M pts)');
fig4.setTileYLabel(2, 'Hz / PF');

% --- Tile 3: Active Power (1 sensor, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s14 = Sensor('mw', 'Name', 'Active Power');
s14.X = tdn; s14.Y = 180 + 40*sin(2*pi*sec/7200) + 10*randn(1,n);
s14.addStateChannel(scGen);
tOverloadBase = Threshold('overload_base', 'Name', 'Overload (Base)', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tOverloadBase.addCondition(struct('gen', 1), 230);
s14.addThreshold(tOverloadBase);

tOverloadPeak = Threshold('overload_peak', 'Name', 'Overload (Peak)', ...
    'Direction', 'upper', 'Color', [1 0 0]);
tOverloadPeak.addCondition(struct('gen', 2), 250);
s14.addThreshold(tOverloadPeak);

tUnderload = Threshold('underload', 'Name', 'Underload', ...
    'Direction', 'lower', 'Color', [0.3 0.6 1]);
tUnderload.addCondition(struct('gen', 1), 120);
s14.addThreshold(tUnderload);
s14.toDisk();

fp = fig4.tile(3);
fp.addSensor(s14, 'ShowThresholds', true);
fig4.setTileTitle(3, 'Active Power (5M pts)');
fig4.setTileYLabel(3, 'MW');

% --- Tile 4: Stator + Rotor Temp (2 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s15a = Sensor('stator_temp', 'Name', 'Stator Winding');
s15a.X = tdn; s15a.Y = 95 + 15*sin(2*pi*sec/7200) + 3*randn(1,n);
s15a.addStateChannel(scGen);
tStatorH = Threshold('stator_h', 'Name', 'Stator H', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tStatorH.addCondition(struct('gen', 1), 120);
s15a.addThreshold(tStatorH);

tStatorHPeak = Threshold('stator_h_peak', 'Name', 'Stator H (Peak)', ...
    'Direction', 'upper', 'Color', [1 0.4 0]);
tStatorHPeak.addCondition(struct('gen', 2), 115);
s15a.addThreshold(tStatorHPeak);
s15a.toDisk();

s15b = Sensor('rotor_temp', 'Name', 'Rotor');
s15b.X = tdn; s15b.Y = 85 + 12*sin(2*pi*sec/7200 + 0.3) + 3*randn(1,n);
s15b.addStateChannel(scGen);
tRotorH = Threshold('rotor_h', 'Name', 'Rotor H', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tRotorH.addCondition(struct('gen', 1), 110);
s15b.addThreshold(tRotorH);
s15b.toDisk();

fp = fig4.tile(4);
fp.addSensor(s15a, 'ShowThresholds', true);
fp.addSensor(s15b, 'ShowThresholds', true);
fig4.setTileTitle(4, 'Generator Temps (5M pts)');
fig4.setTileYLabel(4, 'Temp (°C)');

dock.addTab(fig4, 'Power Gen');

% =========================================================================
% Tab 5: Environmental (1x3) — ~11M points
% =========================================================================
fprintf('Tab 5: Environmental...\n');
fig5 = FastSenseGrid(1, 3, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

% HVAC modes
scHvac = StateChannel('hvac');
scHvac.X = [tdn0, tdn0+1/24, tdn0+4/24, tdn0+7/24];
scHvac.Y = [0, 1, 2, 1];  % 0=night, 1=normal, 2=boost

% --- Tile 1: Air Quality (2 sensors, 5M pts) ---
n = 5e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s16a = Sensor('co2', 'Name', 'CO₂');
s16a.X = tdn; s16a.Y = 450 + 150*sin(2*pi*sec/14400) + 30*randn(1,n);
s16a.addStateChannel(scHvac);
tCo2High = Threshold('co2_high', 'Name', 'CO2 High', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tCo2High.addCondition(struct('hvac', 1), 800);
s16a.addThreshold(tCo2High);

tCo2HighBoost = Threshold('co2_high_boost', 'Name', 'CO2 High (Boost)', ...
    'Direction', 'upper', 'Color', [1 0.4 0]);
tCo2HighBoost.addCondition(struct('hvac', 2), 600);
s16a.addThreshold(tCo2HighBoost);

tCo2Alarm = Threshold('co2_alarm', 'Name', 'CO2 Alarm', ...
    'Direction', 'upper', 'Color', [1 0 0]);
tCo2Alarm.addCondition(struct('hvac', 1), 1000);
s16a.addThreshold(tCo2Alarm);
s16a.toDisk();

s16b = Sensor('pm25', 'Name', 'PM2.5');
s16b.X = tdn; s16b.Y = 8 + 5*sin(2*pi*sec/10800) + 2*randn(1,n);
s16b.addStateChannel(scHvac);
tPm25High = Threshold('pm25_high', 'Name', 'PM2.5 High', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tPm25High.addCondition(struct('hvac', 1), 15);
s16b.addThreshold(tPm25High);
s16b.toDisk();

fp = fig5.tile(1);
fp.addSensor(s16a, 'ShowThresholds', true);
fp.addSensor(s16b, 'ShowThresholds', true);
fig5.setTileTitle(1, 'Air Quality (5M pts)');
fig5.setTileYLabel(1, 'ppm / µg/m³');

% --- Tile 2: Temperature & Humidity (2 sensors, 3M pts) ---
n = 3e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s17a = Sensor('room_temp', 'Name', 'Room Temp');
s17a.X = tdn; s17a.Y = 22 + 3*sin(2*pi*sec/14400) + 0.5*randn(1,n);
s17a.addStateChannel(scHvac);
tTempHighHvac = Threshold('temp_high', 'Name', 'Temp High', ...
    'Direction', 'upper', 'Color', [1 0.5 0]);
tTempHighHvac.addCondition(struct('hvac', 1), 26);
s17a.addThreshold(tTempHighHvac);

tTempLowHvac = Threshold('temp_low', 'Name', 'Temp Low', ...
    'Direction', 'lower', 'Color', [0.3 0.6 1]);
tTempLowHvac.addCondition(struct('hvac', 1), 18);
s17a.addThreshold(tTempLowHvac);
s17a.toDisk();

s17b = Sensor('rh', 'Name', 'Rel. Humidity');
s17b.X = tdn; s17b.Y = 45 + 12*sin(2*pi*sec/10800) + 3*randn(1,n);
s17b.addStateChannel(scHvac);
tRhHigh = Threshold('rh_high', 'Name', 'RH High', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tRhHigh.addCondition(struct('hvac', 1), 65);
s17b.addThreshold(tRhHigh);

tRhLow = Threshold('rh_low', 'Name', 'RH Low', ...
    'Direction', 'lower', 'Color', [0.3 0.6 1]);
tRhLow.addCondition(struct('hvac', 1), 30);
s17b.addThreshold(tRhLow);
s17b.toDisk();

fp = fig5.tile(2);
fp.addSensor(s17a, 'ShowThresholds', true);
fp.addSensor(s17b, 'ShowThresholds', true);
fig5.setTileTitle(2, 'Temp & Humidity (3M pts)');
fig5.setTileYLabel(2, '°C / %RH');

% --- Tile 3: Noise Level (1 sensor, 3M pts) ---
n = 3e6;
tdn = linspace(tdn0, tdn1, n);
sec = (tdn - tdn0) * 86400;

s18 = Sensor('noise', 'Name', 'Noise Level');
s18.X = tdn; s18.Y = 55 + 10*sin(2*pi*sec/7200) + 4*randn(1,n);
s18.Y(round(n*0.5):round(n*0.52)) = s18.Y(round(n*0.5):round(n*0.52)) + 25;
s18.addStateChannel(scHvac);
tNoiseWarn = Threshold('noise_warn', 'Name', 'Noise Warn', ...
    'Direction', 'upper', 'Color', [1 0.75 0]);
tNoiseWarn.addCondition(struct('hvac', 1), 75);
s18.addThreshold(tNoiseWarn);

tNoiseAlarm = Threshold('noise_alarm', 'Name', 'Noise Alarm', ...
    'Direction', 'upper', 'Color', [1 0 0]);
tNoiseAlarm.addCondition(struct('hvac', 1), 85);
s18.addThreshold(tNoiseAlarm);

tNightLimit = Threshold('night_limit', 'Name', 'Night Limit', ...
    'Direction', 'upper', 'Color', [0.6 0.3 1]);
tNightLimit.addCondition(struct('hvac', 0), 65);
s18.addThreshold(tNightLimit);
s18.toDisk();

fp = fig5.tile(3);
fp.addSensor(s18, 'ShowThresholds', true);
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
