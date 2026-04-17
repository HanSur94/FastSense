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

sTemp = SensorTag('T-401', 'Name', 'Temperature', 'Units', [char(176) 'F'], 'X', t, 'Y', 72 + 4*sin(2*pi*t/3600) + randn(1,N)*1.2);
sTemp.Y(end) = 79;  % near warning level


sPress = SensorTag('P-201', 'Name', 'Pressure', 'Units', 'psi', 'X', t, 'Y', 55 + 8*sin(2*pi*t/7200) + randn(1,N)*1.5);

sFlow = SensorTag('F-301', 'Name', 'Flow Rate', 'Units', 'L/min', 'X', t, 'Y', max(0, 120 + 10*sin(2*pi*t/1800) + randn(1,N)*4));

sVib = SensorTag('V-501', 'Name', 'Vibration RMS', 'Units', 'mm/s', 'X', t, 'Y', max(0.1, 1.5 + 0.4*sin(2*pi*t/5400) + randn(1,N)*0.2));

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
% g1.addChild(NumberWidget('Tag', sTemp));
% g1.addChild(NumberWidget('Tag', sPress));
% g1.addChild(GaugeWidget('Tag', sTemp, 'Style', 'arc'));
% g1.addChild(GaugeWidget('Tag', sPress, 'Style', 'arc'));
% d.addWidget('group', 'Label', 'Motor Health', 'Mode', 'panel', ...
%     'Position', [1 1 24 4], ...
%     'Children', {NumberWidget('Tag', sTemp), ...
%                  NumberWidget('Tag', sPress), ...
%                  GaugeWidget('Tag', sTemp, 'Style', 'arc'), ...
%                  GaugeWidget('Tag', sPress, 'Style', 'arc')});

%% --- Mode 2: Collapsible group ---
% A collapsible group renders a clickable header that hides/shows children.
% Collapse() reduces Position(4) to 1 grid row; DashboardLayout.reflow()
% compacts widgets below it automatically.
%
% d.addWidget('group', 'Label', 'Vibration Details', 'Mode', 'collapsible', ...
%     'Position', [1 5 24 6], ...
%     'Collapsed', false, ...
%     'Children', {FastSenseWidget('Tag', sVib)});

%% --- Mode 3: Tabbed group ---
% A tabbed group shows one tab at a time.  Each tab gets its own named
% panel.  Tab buttons appear in the header bar.  ActiveTab sets which tab
% is visible on first render.
%
% tab1 = struct('name', 'Overview', 'widgets', {{ ...
%     NumberWidget('Tag', sTemp), ...
%     NumberWidget('Tag', sPress), ...
%     StatusWidget('Tag', sTemp) ...
% }});
% tab2 = struct('name', 'Trends', 'widgets', {{ ...
%     FastSenseWidget('Tag', sTemp), ...
%     FastSenseWidget('Tag', sFlow) ...
% }});
% d.addWidget('group', 'Label', 'Process Monitor', 'Mode', 'tabbed', ...
%     'Position', [1 11 24 8], ...
%     'Tabs', {tab1, tab2}, ...
%     'ActiveTab', 'Overview');

%% Fallback: render standalone widgets that mirror GroupWidget children
% This section produces a working dashboard today and will be replaced once
% GroupWidget lands.

% Panel group equivalent — KPI row + gauge row
d.addWidget('number', 'Position', [1  1 6 2], 'Tag', sTemp);
d.addWidget('number', 'Position', [7  1 6 2], 'Tag', sPress);
d.addWidget('gauge',  'Position', [13 1 6 4], 'Tag', sTemp, 'Style', 'arc');
d.addWidget('gauge',  'Position', [19 1 6 4], 'Tag', sPress, 'Style', 'arc');

% Collapsible group equivalent — vibration detail
d.addWidget('fastsense', 'Position', [1 5 24 6], 'Tag', sVib);

% Tabbed group equivalent — overview tab (visible) + trends tab (hidden)
d.addWidget('number',    'Position', [1  11 6 2], 'Tag', sTemp);
d.addWidget('number',    'Position', [7  11 6 2], 'Tag', sPress);
d.addWidget('status',    'Position', [13 11 5 2], 'Tag', sTemp);
d.addWidget('fastsense', 'Position', [1  13 12 6], 'Tag', sTemp);
d.addWidget('fastsense', 'Position', [13 13 12 6], 'Tag', sFlow);

%% 3. Render
d.render();

fprintf('Dashboard rendered with %d widgets.\n', numel(d.Widgets));
fprintf('GroupWidget Phase A required for group/collapsible/tabbed container modes.\n');
fprintf('See: docs/superpowers/plans/2026-03-18-dashboard-groupwidget-phase-a.md\n');
