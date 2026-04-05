%% GroupWidget — All Modes Demo
% Demonstrates GroupWidget as a container for child widgets, covering all
% three grouping modes: panel, collapsible, and tabbed.
%
% NOTE: GroupWidget is defined in the Phase A implementation plan
%   (docs/superpowers/plans/2026-03-18-dashboard-groupwidget-phase-a.md).
%   This example script will run correctly once GroupWidget is implemented
%   and registered in DashboardEngine.  Until then it documents the
%   intended API; uncommenting is the only change needed after Phase A lands.
%
% GroupWidget Properties:
%   Mode          — 'panel' (default) | 'collapsible' | 'tabbed'.
%   Label         — header title string shown in the group header bar.
%   Children      — cell array of DashboardWidget (panel / collapsible modes).
%   Tabs          — cell array of structs with fields 'name' and 'widgets'
%                   (tabbed mode only).
%   ActiveTab     — name of the initially visible tab (tabbed mode).
%   Collapsed     — initial collapsed state (collapsible mode, default false).
%   ChildAutoFlow — auto-arrange children left-to-right (default true).
%   ChildColumns  — column count of the child sub-grid (default 24).
%   Position      — [col row width height] on the 24-column grid.
%
% Usage:
%   example_widget_group

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Create sensors
rng(42);
N = 5000;
t = linspace(0, 86400, N);  % 24 hours

sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = [char(176) 'F'];
sTemp.X = t;
sTemp.Y = 72 + 4*sin(2*pi*t/3600) + randn(1,N)*1.2;
sTemp.Y(end) = 79;  % near warning level
sTemp.addThresholdRule(struct(), 78, ...
    'Direction', 'upper', 'Label', 'Hi Warn', ...
    'Color', [1 0.8 0], 'LineStyle', '--');
sTemp.addThresholdRule(struct(), 85, ...
    'Direction', 'upper', 'Label', 'Hi Alarm', ...
    'Color', [1 0.2 0.2], 'LineStyle', '-');
sTemp.resolve();

sPress = Sensor('P-201', 'Name', 'Pressure');
sPress.Units = 'psi';
sPress.X = t;
sPress.Y = 55 + 8*sin(2*pi*t/7200) + randn(1,N)*1.5;
sPress.addThresholdRule(struct(), 68, ...
    'Direction', 'upper', 'Label', 'Hi Warn', ...
    'Color', [1 0.8 0], 'LineStyle', '--');
sPress.resolve();

sFlow = Sensor('F-301', 'Name', 'Flow Rate');
sFlow.Units = 'L/min';
sFlow.X = t;
sFlow.Y = max(0, 120 + 10*sin(2*pi*t/1800) + randn(1,N)*4);
sFlow.resolve();

sVib = Sensor('V-501', 'Name', 'Vibration RMS');
sVib.Units = 'mm/s';
sVib.X = t;
sVib.Y = max(0.1, 1.5 + 0.4*sin(2*pi*t/5400) + randn(1,N)*0.2);
sVib.resolve();

%% 2. Build dashboard
d = DashboardEngine('Group Widget Demo');
d.Theme = 'light';

%% --- Mode 1: Panel group (default) ---
% A panel group acts as a titled container.  Children auto-flow left to
% right inside the group boundaries.  Equivalent to placing widgets in a
% named section of the dashboard.
%
% g1 = GroupWidget('Label', 'Motor Health', 'Mode', 'panel', ...
%     'Position', [1 1 24 4]);
% g1.addChild(NumberWidget('Sensor', sTemp));
% g1.addChild(NumberWidget('Sensor', sPress));
% g1.addChild(GaugeWidget('Sensor', sTemp, 'Style', 'arc'));
% g1.addChild(GaugeWidget('Sensor', sPress, 'Style', 'arc'));
% d.addWidget('group', 'Label', 'Motor Health', 'Mode', 'panel', ...
%     'Position', [1 1 24 4], ...
%     'Children', {NumberWidget('Sensor', sTemp), ...
%                  NumberWidget('Sensor', sPress), ...
%                  GaugeWidget('Sensor', sTemp, 'Style', 'arc'), ...
%                  GaugeWidget('Sensor', sPress, 'Style', 'arc')});

%% --- Mode 2: Collapsible group ---
% A collapsible group renders a clickable header that hides/shows children.
% Collapse() reduces Position(4) to 1 grid row; DashboardLayout.reflow()
% compacts widgets below it automatically.
%
% d.addWidget('group', 'Label', 'Vibration Details', 'Mode', 'collapsible', ...
%     'Position', [1 5 24 6], ...
%     'Collapsed', false, ...
%     'Children', {FastSenseWidget('Sensor', sVib)});

%% --- Mode 3: Tabbed group ---
% A tabbed group shows one tab at a time.  Each tab gets its own named
% panel.  Tab buttons appear in the header bar.  ActiveTab sets which tab
% is visible on first render.
%
% tab1 = struct('name', 'Overview', 'widgets', {{ ...
%     NumberWidget('Sensor', sTemp), ...
%     NumberWidget('Sensor', sPress), ...
%     StatusWidget('Sensor', sTemp) ...
% }});
% tab2 = struct('name', 'Trends', 'widgets', {{ ...
%     FastSenseWidget('Sensor', sTemp), ...
%     FastSenseWidget('Sensor', sFlow) ...
% }});
% d.addWidget('group', 'Label', 'Process Monitor', 'Mode', 'tabbed', ...
%     'Position', [1 11 24 8], ...
%     'Tabs', {tab1, tab2}, ...
%     'ActiveTab', 'Overview');

%% Fallback: render standalone widgets that mirror GroupWidget children
% This section produces a working dashboard today and will be replaced once
% GroupWidget lands.

% Panel group equivalent — KPI row + gauge row
d.addWidget('number', 'Position', [1  1 6 2], 'Sensor', sTemp);
d.addWidget('number', 'Position', [7  1 6 2], 'Sensor', sPress);
d.addWidget('gauge',  'Position', [13 1 6 4], 'Sensor', sTemp, 'Style', 'arc');
d.addWidget('gauge',  'Position', [19 1 6 4], 'Sensor', sPress, 'Style', 'arc');

% Collapsible group equivalent — vibration detail
d.addWidget('fastsense', 'Position', [1 5 24 6], 'Sensor', sVib);

% Tabbed group equivalent — overview tab (visible) + trends tab (hidden)
d.addWidget('number',    'Position', [1  11 6 2], 'Sensor', sTemp);
d.addWidget('number',    'Position', [7  11 6 2], 'Sensor', sPress);
d.addWidget('status',    'Position', [13 11 5 2], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [1  13 12 6], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [13 13 12 6], 'Sensor', sFlow);

%% 3. Render
d.render();

fprintf('Dashboard rendered with %d widgets.\n', numel(d.Widgets));
fprintf('GroupWidget Phase A required for group/collapsible/tabbed container modes.\n');
fprintf('See: docs/superpowers/plans/2026-03-18-dashboard-groupwidget-phase-a.md\n');
