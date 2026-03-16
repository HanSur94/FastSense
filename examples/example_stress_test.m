%% FastPlot Stress Test — 5-Tab FastPlotDock with Sensors & Thresholds
% Demonstrates:
%   - FastPlotDock with 5 tabbed dashboards + FastPlotToolbar
%   - 26 sensor tiles, each with 4 dynamic thresholds (Warn HH/LL, Alarm HH/LL)
%   - State-dependent thresholds that step at machine state transitions
%   - ~86M total data points across all tabs
%   - Tests rendering, downsampling, threshold resolve, and zoom/pan

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

fprintf('\n=== FastPlot Stress Test: 5 Tabbed Dashboards ===\n');
totalTic = tic;

% --- Shared state channels (reused across dashboards) ---
scMachine = StateChannel('machine');
scMachine.X = [0 600 1800 2700 3600];
scMachine.Y = [0 1 2 1 0];

scVacuum = StateChannel('vacuum');
scVacuum.X = [0 900 2400 3200];
scVacuum.Y = [0 1 0 1];

scZone = StateChannel('zone');
scZone.X = [0 1200 2400];
scZone.Y = [0 1 2];

% --- Create dock ---
dock = FastPlotDock('Theme', 'light', 'Name', 'Stress Test — 26 Sensors, 104 Thresholds', ...
    'Position', [50 50 1800 1000]);

% =========================================================================
% TAB 1: Vacuum Chamber — 3x2 grid, 6 sensors
% =========================================================================
fig1 = FastPlotGrid(3, 2, 'ParentFigure', dock.hFigure, 'Theme', 'light');

% 1.1: Chamber Pressure — 5M pts
s = make_sensor('pressure', 'Chamber Pressure', 5e6, 40, 18, 800, 4, {scMachine, scVacuum});
add_4_thresholds(s, scMachine, 55, 25, 65, 15);
s.resolve();
fig1.tile(1).addSensor(s);

% 1.2: Base Pressure — 5M pts
s = make_sensor('base_pressure', 'Base Pressure', 5e6, 1e-3, 5e-4, 1200, 2e-4, {scMachine});
inject_event(s, 2e6, 2.1e6, 3e-3);
add_4_thresholds(s, scMachine, 1.8e-3, 3e-4, 2.5e-3, 1e-4);
s.resolve();
fig1.tile(2).addSensor(s);

% 1.3: Gate Valve — 3M pts
s = make_sensor('gate_valve', 'Gate Valve Position', 3e6, 50, 45, 900, 2, {scMachine});
add_4_thresholds(s, scMachine, 88, 12, 95, 5);
s.resolve();
fig1.tile(3).addSensor(s);

% 1.4: Gas Flow — 5M pts, multi-state
s = make_sensor('gas_flow', 'Gas Flow', 5e6, 100, 30, 600, 8, {scMachine, scZone});
add_4_thresholds(s, scMachine, 130, 70, 140, 60);
s.resolve();
fig1.tile(4).addSensor(s);

% 1.5: RF Power — 4M pts
s = make_sensor('rf_power', 'RF Power', 4e6, 200, 80, 700, 15, {scMachine});
add_4_thresholds(s, scMachine, 280, 120, 310, 90);
s.resolve();
fig1.tile(5).addSensor(s);

% 1.6: Substrate Temp — 3M pts
s = make_sensor('substrate_temp', 'Substrate Temp', 3e6, 350, 40, 1000, 8, {scMachine});
add_4_thresholds(s, scMachine, 390, 310, 410, 290);
s.resolve();
fig1.tile(6).addSensor(s);

dock.addTab(fig1, 'Vacuum Chamber');

% =========================================================================
% TAB 2: Motor Diagnostics — 2x3 grid, 6 sensors
% =========================================================================
fig2 = FastPlotGrid(2, 3, 'ParentFigure', dock.hFigure, 'Theme', 'light');

% 2.1: Motor Current A — 5M pts
s = make_sensor('motor_A', 'Motor Current A', 5e6, 12, 4, 400, 1.5, {scMachine});
inject_event(s, 1.5e6, 1.55e6, 8);
add_4_thresholds(s, scMachine, 16, 8, 19, 5);
s.resolve();
fig2.tile(1).addSensor(s);

% 2.2: Motor Current B — 5M pts
s = make_sensor('motor_B', 'Motor Current B', 5e6, 12, 4, 400, 1.5, {scMachine});
add_4_thresholds(s, scMachine, 16, 8, 19, 5);
s.resolve();
fig2.tile(2).addSensor(s);

% 2.3: Motor Current C — 5M pts
s = make_sensor('motor_C', 'Motor Current C', 5e6, 12, 4, 400, 1.5, {scMachine});
add_4_thresholds(s, scMachine, 16, 8, 19, 5);
s.resolve();
fig2.tile(3).addSensor(s);

% 2.4: Vibration X — 3M pts
s = make_sensor('vib_x', 'Vibration X', 3e6, 0, 0.3, 500, 0.5, {scMachine});
inject_burst(s, [500 1200 2600], 40, 3);
add_4_thresholds(s, scMachine, 1.5, -1.5, 2.5, -2.5);
s.resolve();
fig2.tile(4).addSensor(s);

% 2.5: Spindle RPM — 2M pts
s = make_sensor('rpm', 'Spindle RPM', 2e6, 3000, 500, 900, 80, {scMachine});
add_4_thresholds(s, scMachine, 3400, 2600, 3700, 2300);
s.resolve();
fig2.tile(5).addSensor(s);

% 2.6: Bearing Temp — 3M pts
s = make_sensor('bearing_temp', 'Bearing Temp', 3e6, 65, 10, 1200, 3, {scMachine});
inject_event(s, 1.2e6, 1.25e6, 20);
add_4_thresholds(s, scMachine, 80, 50, 95, 40);
s.resolve();
fig2.tile(6).addSensor(s);

dock.addTab(fig2, 'Motor Diagnostics');

% =========================================================================
% TAB 3: Environmental — 2x2 grid, 4 sensors
% =========================================================================
fig3 = FastPlotGrid(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'light');

% 3.1: Cleanroom Temp — 5M pts
s = make_sensor('room_temp', 'Cleanroom Temp', 5e6, 22, 1.5, 1800, 0.3, {scMachine});
inject_event(s, 3e6, 3.05e6, 3);
add_4_thresholds(s, scMachine, 23.5, 20.5, 25, 19);
s.resolve();
fig3.tile(1).addSensor(s);

% 3.2: Humidity — 5M pts
s = make_sensor('humidity', 'Humidity', 5e6, 45, 8, 2400, 2, {scMachine});
add_4_thresholds(s, scMachine, 52, 38, 58, 32);
s.resolve();
fig3.tile(2).addSensor(s);

% 3.3: Particle Count — 3M pts
s = make_sensor('particles', 'Particle Count', 3e6, 200, 80, 600, 40, {scMachine, scVacuum});
inject_event(s, 1e6, 1.02e6, 500);
add_4_thresholds(s, scMachine, 300, 80, 400, 50);
s.resolve();
fig3.tile(3).addSensor(s);

% 3.4: Differential Pressure — 3M pts
s = make_sensor('diff_pressure', 'Differential Pressure', 3e6, 12.5, 2, 900, 0.8, {scMachine});
add_4_thresholds(s, scMachine, 14, 11, 16, 9);
s.resolve();
fig3.tile(4).addSensor(s);

dock.addTab(fig3, 'Environmental');

% =========================================================================
% TAB 4: Gas Delivery — 3x2 grid, 6 sensors
% =========================================================================
fig4 = FastPlotGrid(3, 2, 'ParentFigure', dock.hFigure, 'Theme', 'light');

gasNames   = {'Argon', 'Nitrogen', 'Oxygen', 'CF4', 'CHF3', 'Helium'};
gasNominal = [200    150     80     50    30    500];
gasAmp     = [15     12       8      5     3     25];
gasPeriod  = [600    500    700    400   300    800];
gasNoise   = [5       4       3      2   1.5     8];
gasSizes   = [3e6   3e6    2e6    2e6   2e6    3e6];
gasWarnOff = [25     20      15     8     5     40];
gasAlarmOff= [40     35      25    14    10     65];

for gi = 1:6
    s = make_sensor(lower(gasNames{gi}), [gasNames{gi} ' Flow'], ...
        gasSizes(gi), gasNominal(gi), gasAmp(gi), gasPeriod(gi), gasNoise(gi), ...
        {scMachine, scVacuum});
    excStart = round(gasSizes(gi) * (0.3 + 0.08*gi));
    excEnd = min(excStart + round(gasSizes(gi)*0.02), numel(s.Y));
    s.Y(excStart:excEnd) = s.Y(excStart:excEnd) + gasAlarmOff(gi)*1.2;
    add_4_thresholds(s, scMachine, ...
        gasNominal(gi) + gasWarnOff(gi), gasNominal(gi) - gasWarnOff(gi), ...
        gasNominal(gi) + gasAlarmOff(gi), gasNominal(gi) - gasAlarmOff(gi));
    s.resolve();
    fig4.tile(gi).addSensor(s);
end

dock.addTab(fig4, 'Gas Delivery');

% =========================================================================
% TAB 5: Power & Cooling — 2x2 grid, 4 sensors
% =========================================================================
fig5 = FastPlotGrid(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'light');

% 5.1: Chiller Supply — 3M pts
s = make_sensor('chiller_supply', 'Chiller Supply', 3e6, 18, 2, 1200, 0.5, {scMachine});
add_4_thresholds(s, scMachine, 20, 16, 22, 14);
s.resolve();
fig5.tile(1).addSensor(s);

% 5.2: Chiller Return — 3M pts
s = make_sensor('chiller_return', 'Chiller Return', 3e6, 24, 3, 1200, 0.8, {scMachine});
inject_event(s, 2e6, 2.05e6, 5);
add_4_thresholds(s, scMachine, 27, 21, 30, 18);
s.resolve();
fig5.tile(2).addSensor(s);

% 5.3: Mains Voltage — 2M pts (no state dependency)
s = make_sensor('mains_v', 'Mains Voltage', 2e6, 230, 5, 600, 2, {});
inject_event(s, 8e5, 8.1e5, -15);
add_4_thresholds(s, [], 237, 223, 242, 218);
s.resolve();
fig5.tile(3).addSensor(s);

% 5.4: UPS Load — 2M pts
s = make_sensor('ups_load', 'UPS Load', 2e6, 60, 15, 1800, 5, {scMachine});
add_4_thresholds(s, scMachine, 75, 40, 88, 30);
s.resolve();
fig5.tile(4).addSensor(s);

dock.addTab(fig5, 'Power & Cooling');

% =========================================================================
% Render all tabs with hierarchical progress + toolbar
% =========================================================================
dock.renderAll();

% Add titles and labels
fig1.setTileTitle(1, 'Chamber Pressure (5M)');  fig1.setTileYLabel(1, 'mbar');
fig1.setTileTitle(2, 'Base Pressure (5M)');     fig1.setTileYLabel(2, 'mbar');
fig1.setTileTitle(3, 'Gate Valve (3M)');        fig1.setTileYLabel(3, '%');
fig1.setTileTitle(4, 'Gas Flow (5M)');          fig1.setTileYLabel(4, 'sccm');
fig1.setTileTitle(5, 'RF Power (4M)');          fig1.setTileYLabel(5, 'W');
fig1.setTileTitle(6, 'Substrate Temp (3M)');    fig1.setTileYLabel(6, '°C');

fig2.setTileTitle(1, 'Current A (5M)');         fig2.setTileYLabel(1, 'A');
fig2.setTileTitle(2, 'Current B (5M)');         fig2.setTileYLabel(2, 'A');
fig2.setTileTitle(3, 'Current C (5M)');         fig2.setTileYLabel(3, 'A');
fig2.setTileTitle(4, 'Vibration X (3M)');       fig2.setTileYLabel(4, 'mm/s');
fig2.setTileTitle(5, 'Spindle RPM (2M)');       fig2.setTileYLabel(5, 'RPM');
fig2.setTileTitle(6, 'Bearing Temp (3M)');      fig2.setTileYLabel(6, '°C');

fig3.setTileTitle(1, 'Cleanroom Temp (5M)');    fig3.setTileYLabel(1, '°C');
fig3.setTileTitle(2, 'Humidity (5M)');          fig3.setTileYLabel(2, '%RH');
fig3.setTileTitle(3, 'Particles (3M)');         fig3.setTileYLabel(3, 'ct/m³');
fig3.setTileTitle(4, 'Diff Pressure (3M)');     fig3.setTileYLabel(4, 'Pa');

fig4.setTileTitle(1, 'Argon (3M)');     fig4.setTileYLabel(1, 'sccm');
fig4.setTileTitle(2, 'Nitrogen (3M)');  fig4.setTileYLabel(2, 'sccm');
fig4.setTileTitle(3, 'Oxygen (2M)');    fig4.setTileYLabel(3, 'sccm');
fig4.setTileTitle(4, 'CF4 (2M)');       fig4.setTileYLabel(4, 'sccm');
fig4.setTileTitle(5, 'CHF3 (2M)');      fig4.setTileYLabel(5, 'sccm');
fig4.setTileTitle(6, 'Helium (3M)');    fig4.setTileYLabel(6, 'sccm');

fig5.setTileTitle(1, 'Chiller Supply (3M)');    fig5.setTileYLabel(1, '°C');
fig5.setTileTitle(2, 'Chiller Return (3M)');    fig5.setTileYLabel(2, '°C');
fig5.setTileTitle(3, 'Mains Voltage (2M)');     fig5.setTileYLabel(3, 'V');
fig5.setTileTitle(4, 'UPS Load (2M)');          fig5.setTileYLabel(4, '%');

totalTime = toc(totalTic);
totalPts = 5e6*6 + 3e6*6 + 4e6 + 2e6*6 + sum(gasSizes);
fprintf('\n=== Stress Test Complete ===\n');
fprintf('  5 tabs, 26 sensors, 104 dynamic thresholds\n');
fprintf('  %.1fM total data points\n', totalPts/1e6);
fprintf('  Total time: %.2f seconds\n', totalTime);
fprintf('  Toolbar: cursor, crosshair, grid, legend, autoscale, export\n');

% =========================================================================
% Helper functions
% =========================================================================

function s = make_sensor(id, name, N, nominal, amp, period, noise, stateChannels)
%MAKE_SENSOR Create a Sensor with synthetic data and state channels.
    t = linspace(0, 3600, N);
    s = Sensor(id, 'Name', name);
    s.X = t;
    s.Y = nominal + amp*sin(2*pi*t/period) + noise*randn(1, N);
    for i = 1:numel(stateChannels)
        s.addStateChannel(stateChannels{i});
    end
end

function add_4_thresholds(s, scM, warnHi, warnLo, alarmHi, alarmLo)
%ADD_4_THRESHOLDS Add Warn HH/LL + Alarm HH/LL threshold rules.
%   If scM is provided, adds rules for each machine state so that
%   resolve() produces continuous step-function threshold lines:
%     machine=0 (idle):      relaxed limits (+10% offset)
%     machine=1 (running):   nominal limits
%     machine=2 (evacuated): tighter limits (-10% offset)
%   If scM is empty, adds unconditional flat thresholds.
%
%   Rules sharing the same Label+Direction are merged by resolve() into
%   a single continuous threshold line — no NaN gaps.

    if isempty(scM)
        add_rule_set(s, struct(), warnHi, warnLo, alarmHi, alarmLo);
        return;
    end

    warnRange  = warnHi - warnLo;
    alarmRange = alarmHi - alarmLo;

    % Get unique state values from the state channel
    states = unique(scM.Y);

    for i = 1:numel(states)
        state = states(i);
        switch state
            case 0; f =  0.10;   % idle — relaxed
            case 1; f =  0;      % running — nominal
            case 2; f = -0.10;   % evacuated — tighter
            otherwise; f = 0;
        end
        add_rule_set(s, struct('machine', state), ...
            warnHi  + f*warnRange,  warnLo  - f*warnRange, ...
            alarmHi + f*alarmRange, alarmLo - f*alarmRange);
    end
end

function add_rule_set(s, cond, warnHi, warnLo, alarmHi, alarmLo)
%ADD_RULE_SET Add one set of 4 threshold rules for a single condition.
    s.addThresholdRule(cond, warnHi, 'Direction', 'upper', ...
        'Label', 'Warn HH', 'Color', [0.95 0.65 0.1], 'LineStyle', '--');
    s.addThresholdRule(cond, warnLo, 'Direction', 'lower', ...
        'Label', 'Warn LL', 'Color', [0.95 0.65 0.1], 'LineStyle', '--');
    s.addThresholdRule(cond, alarmHi, 'Direction', 'upper', ...
        'Label', 'Alarm HH', 'Color', [0.9 0.15 0.1], 'LineStyle', '-');
    s.addThresholdRule(cond, alarmLo, 'Direction', 'lower', ...
        'Label', 'Alarm LL', 'Color', [0.9 0.15 0.1], 'LineStyle', '-');
end

function inject_event(s, idxStart, idxEnd, magnitude)
%INJECT_EVENT Add a transient excursion to sensor data.
    idxEnd = min(idxEnd, numel(s.Y));
    s.Y(idxStart:idxEnd) = s.Y(idxStart:idxEnd) + magnitude;
end

function inject_burst(s, times, duration, amplitude)
%INJECT_BURST Add noise bursts at specified times.
    N = numel(s.Y);
    for i = 1:numel(times)
        lo = max(1, round(times(i) * N / 3600));
        hi = min(lo + round(duration * N / 3600), N);
        s.Y(lo:hi) = s.Y(lo:hi) + amplitude * randn(1, hi - lo + 1);
    end
end
