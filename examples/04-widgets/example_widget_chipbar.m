%% ChipBarWidget — All Chip Configuration Modes
% Demonstrates every way to configure chips inside a ChipBarWidget.
%
% ChipBarWidget properties:
%   Chips     — cell array of chip structs. Each chip may contain:
%                 label      (required) — string displayed below the circle
%                 statusFcn  (optional) — @() returning 'ok'|'warn'|'alarm'|'info'|'inactive'
%                 sensor     (optional) — Sensor object; state auto-derived from thresholds
%                 iconColor  (optional) — [r g b] explicit color override (skips state logic)
%   Position  — [col row width height] on the 24-column grid (1-based).
%               Default full-width single row: [1 1 24 1].
%
% Color resolution priority per chip:
%   1. chip.iconColor  — explicit RGB override (highest priority)
%   2. chip.statusFcn  — function returning state string -> theme color
%   3. chip.sensor     — derive state from ThresholdRules -> theme color
%   4. gray [0.5 0.5 0.5] (inactive fallback)

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Create sensors with thresholds (used by sensor-bound chips)
rng(42);
N = 3000;
t = linspace(0, 3600, N);

% Sensor 1 — ok (no violation)
sA = SensorTag('S-001', 'Name', 'Reactor A', 'Units', 'bar');
sA.updateData(t, 8 + 0.3*sin(2*pi*t/600) + randn(1,N)*0.05);

% Sensor 2 — alarm (last value above threshold)
sB = SensorTag('S-002', 'Name', 'Reactor B', 'Units', 'bar');
sB_y_ = 8 + 0.3*sin(2*pi*t/600) + randn(1,N)*0.05;
sB_y_(end-100:end) = 14 + randn(1,101)*0.1;   % push tail into alarm
sB.updateData(t, sB_y_);

% Sensor 3 — ok
sC = SensorTag('S-003', 'Name', 'Cooler', 'Units', [char(176) 'C']);
sC.updateData(t, 38 + 2*sin(2*pi*t/1200) + randn(1,N)*0.3);

%% 2. Build Dashboard
d = DashboardEngine('ChipBarWidget Demo');
d.Theme = 'dark';

% --- Bar 1: statusFcn chips (mix of all states) ---
bar1 = ChipBarWidget('Title', 'System Health (statusFcn)', 'Position', [1 1 24 2]);
bar1.Chips = {
    struct('label', 'Pump A',   'statusFcn', @() 'ok'),
    struct('label', 'Pump B',   'statusFcn', @() 'warn'),
    struct('label', 'Valve 1',  'statusFcn', @() 'alarm'),
    struct('label', 'Valve 2',  'statusFcn', @() 'ok'),
    struct('label', 'Fan',      'statusFcn', @() 'info'),
    struct('label', 'Heater',   'statusFcn', @() 'ok'),
    struct('label', 'Cooler',   'statusFcn', @() 'inactive'),
    struct('label', 'Conveyor', 'statusFcn', @() 'ok'),
};
d.addWidget(bar1);

% --- Bar 2: sensor-bound chips (state auto-derived from ThresholdRules) ---
bar2 = ChipBarWidget('Title', 'Reactor Status (sensor-bound)', 'Position', [1 4 24 2]);
bar2.Chips = {
    struct('label', 'Reactor A', 'sensor', sA),   % ok   — value below threshold
    struct('label', 'Reactor B', 'sensor', sB),   % alarm — value above threshold
    struct('label', 'Cooler',    'sensor', sC),   % ok   — value below threshold
};
d.addWidget(bar2);

% --- Bar 3: explicit iconColor override on every chip ---
bar3 = ChipBarWidget('Title', 'Custom Colors (iconColor)', 'Position', [1 7 24 2]);
bar3.Chips = {
    struct('label', 'Zone 1', 'iconColor', [0.20 0.80 0.40]),
    struct('label', 'Zone 2', 'iconColor', [0.95 0.75 0.10]),
    struct('label', 'Zone 3', 'iconColor', [0.90 0.25 0.25]),
    struct('label', 'Zone 4', 'iconColor', [0.25 0.55 0.95]),
    struct('label', 'Zone 5', 'iconColor', [0.65 0.40 0.90]),
    struct('label', 'Zone 6', 'iconColor', [0.95 0.55 0.15]),
};
d.addWidget(bar3);

% --- FastSense widgets below for context ---
d.addWidget('fastsense', 'Position', [1  10 8 8], 'Sensor', sA);
d.addWidget('fastsense', 'Position', [9  10 8 8], 'Sensor', sB);
d.addWidget('fastsense', 'Position', [17 10 8 8], 'Sensor', sC);

%% 3. Render
d.render();

fprintf('Dashboard rendered with %d widgets.\n', numel(d.Widgets));
fprintf('  Bar 1 (statusFcn): 8 chips with mixed ok/warn/alarm/info/inactive\n');
fprintf('  Bar 2 (sensor)   : 3 chips — Reactor A=ok, Reactor B=alarm, Cooler=ok\n');
fprintf('  Bar 3 (iconColor): 6 chips with explicit RGB color overrides\n');
