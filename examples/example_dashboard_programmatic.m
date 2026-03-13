%% Programmatic Dashboard Building
% Shows how to build dashboards entirely from code — no GUI needed.
% Covers: grid layout, widget configuration, themes, save/load/export,
% and manipulating widgets after creation.
%
% Usage:
%   example_dashboard_programmatic

setup();

%% 1. Minimal dashboard — two lines of code
d = DashboardEngine('Quick Start');
d.addWidget('kpi', 'Title', 'Answer', 'StaticValue', 42, 'Position', [1 1 3 1]);
d.render();
fprintf('1. Minimal dashboard rendered.\n');
delete(d.hFigure);

%% 2. Grid layout — 12-column system
%  Position = [col, row, width, height]
%  col:    1–12, left to right
%  row:    1–N,  top to bottom (auto-expands)
%  width:  span in columns (max 12)
%  height: span in rows

d = DashboardEngine('Grid Layout Demo');
d.Theme = 'dark';

% Full-width header
d.addWidget('text', 'Title', 'System Overview', ...
    'Position', [1 1 12 1], ...
    'Content', 'Shift A — 2026-03-13', ...
    'FontSize', 18, 'Alignment', 'center');

% Three equal KPI cards (4 columns each)
d.addWidget('kpi', 'Title', 'Temperature', 'Position', [1 2 4 1], ...
    'StaticValue', 72.3, 'Units', [char(176) 'F'], 'Format', '%.1f');
d.addWidget('kpi', 'Title', 'Pressure',    'Position', [5 2 4 1], ...
    'StaticValue', 48,   'Units', 'psi',   'Format', '%.0f');
d.addWidget('kpi', 'Title', 'Flow Rate',   'Position', [9 2 4 1], ...
    'StaticValue', 3.14, 'Units', 'L/min', 'Format', '%.2f');

% Two status indicators (2 cols) + one gauge (4 cols) + one plot (4 cols)
d.addWidget('status', 'Title', 'Pump A', 'Position', [1 3 2 1], ...
    'StaticStatus', 'ok');
d.addWidget('status', 'Title', 'Pump B', 'Position', [3 3 2 1], ...
    'StaticStatus', 'warning');
d.addWidget('gauge', 'Title', 'CPU Load', 'Position', [5 3 4 2], ...
    'StaticValue', 67, 'Range', [0 100], 'Units', '%');

t = linspace(0, 3600, 5000);
d.addWidget('fastplot', 'Title', 'Temperature Trend', ...
    'Position', [9 3 4 2], ...
    'XData', t, 'YData', 70 + 5*sin(2*pi*t/600) + randn(1,5000)*0.3);

d.render();
fprintf('2. Grid layout dashboard rendered with %d widgets.\n', numel(d.Widgets));
delete(d.hFigure);

%% 3. Building dashboards from data structures
%  Useful when widget configs come from a database, config file, or API.

widgetSpecs = {
    struct('type', 'kpi',    'title', 'Sensor 1', 'pos', [1 1 3 1], ...
           'props', {{'StaticValue', 100, 'Units', 'rpm'}})
    struct('type', 'kpi',    'title', 'Sensor 2', 'pos', [4 1 3 1], ...
           'props', {{'StaticValue', 200, 'Units', 'rpm'}})
    struct('type', 'status', 'title', 'Health',   'pos', [7 1 3 1], ...
           'props', {{'StaticStatus', 'ok'}})
    struct('type', 'gauge',  'title', 'Utilization', 'pos', [10 1 3 2], ...
           'props', {{'StaticValue', 85, 'Range', [0 100], 'Units', '%'}})
};

d = DashboardEngine('Data-Driven Dashboard');
d.Theme = 'industrial';

for i = 1:numel(widgetSpecs)
    s = widgetSpecs{i};
    d.addWidget(s.type, 'Title', s.title, 'Position', s.pos, s.props{:});
end

d.render();
fprintf('3. Data-driven dashboard: %d widgets from spec array.\n', numel(d.Widgets));
delete(d.hFigure);

%% 4. Theme comparison — same layout, different themes
themes = {'default', 'dark', 'light', 'industrial', 'ocean', 'scientific'};

for i = 1:numel(themes)
    d = DashboardEngine(sprintf('Theme: %s', themes{i}));
    d.Theme = themes{i};
    d.addWidget('kpi', 'Title', 'Value', 'Position', [1 1 4 1], ...
        'StaticValue', 42, 'Units', 'units');
    d.addWidget('gauge', 'Title', 'Gauge', 'Position', [5 1 4 2], ...
        'StaticValue', 65, 'Range', [0 100], 'Units', '%');
    d.addWidget('status', 'Title', 'Status', 'Position', [9 1 4 1], ...
        'StaticStatus', 'ok');
    d.render();
    set(d.hFigure, 'Visible', 'off');
    delete(d.hFigure);
end
fprintf('4. Built %d dashboards across all themes.\n', numel(themes));

%% 5. Per-widget theme overrides
d = DashboardEngine('Theme Overrides');
d.Theme = 'dark';

d.addWidget('kpi', 'Title', 'Normal', 'Position', [1 1 4 1], ...
    'StaticValue', 50);
d.addWidget('kpi', 'Title', 'Custom BG', 'Position', [5 1 4 1], ...
    'StaticValue', 75, ...
    'ThemeOverride', struct('WidgetBackground', [0.15 0.05 0.05]));
d.addWidget('kpi', 'Title', 'Custom Font', 'Position', [9 1 4 1], ...
    'StaticValue', 99, ...
    'ThemeOverride', struct('KpiFontSize', 40, 'ForegroundColor', [0.2 0.9 0.4]));

d.render();
fprintf('5. Per-widget theme overrides applied.\n');
delete(d.hFigure);

%% 6. Manipulating widgets after creation
d = DashboardEngine('Post-Creation Edits');
d.Theme = 'ocean';

d.addWidget('kpi', 'Title', 'Original Title', 'Position', [1 1 6 1], ...
    'StaticValue', 10);
d.addWidget('kpi', 'Title', 'To Delete', 'Position', [7 1 6 1], ...
    'StaticValue', 20);
d.render();

% Rename a widget
d.setWidgetTitle(1, 'Renamed Widget');

% Move a widget
d.setWidgetPosition(1, [1 1 12 1]);  % full width

% Remove a widget
d.removeWidget(2);

% Re-render to see changes
d.rerenderWidgets();
fprintf('6. Widget count after remove: %d\n', numel(d.Widgets));
delete(d.hFigure);

%% 7. Save, load, and export
d = DashboardEngine('Persistence Demo');
d.Theme = 'scientific';
d.addWidget('kpi', 'Title', 'Saved KPI', 'Position', [1 1 6 1], ...
    'StaticValue', 123, 'Units', 'Hz');
d.addWidget('text', 'Title', 'Notes', 'Position', [7 1 6 1], ...
    'Content', 'This dashboard was saved to JSON and reloaded.');
d.render();

% Save to JSON
jsonPath = fullfile(tempdir, 'example_programmatic.json');
d.save(jsonPath);
fprintf('7a. Saved to %s\n', jsonPath);
delete(d.hFigure);

% Load from JSON
d2 = DashboardEngine.load(jsonPath);
d2.render();
fprintf('7b. Loaded back: "%s" with %d widgets.\n', d2.Name, numel(d2.Widgets));
delete(d2.hFigure);

% Export as .m script
scriptPath = fullfile(tempdir, 'example_programmatic_export.m');
d2.exportScript(scriptPath);
fprintf('7c. Exported script to %s\n', scriptPath);

%% 8. RawAxes for custom plots
d = DashboardEngine('Custom Plots');
d.Theme = 'dark';

d.addWidget('rawaxes', 'Title', 'Sine Wave', 'Position', [1 1 6 3], ...
    'PlotFcn', @(ax) plot(ax, linspace(0,4*pi,500), sin(linspace(0,4*pi,500)), 'LineWidth', 2));
d.addWidget('rawaxes', 'Title', 'Scatter', 'Position', [7 1 6 3], ...
    'PlotFcn', @(ax) scatter(ax, randn(1,200), randn(1,200), 20, 'filled'));
d.addWidget('rawaxes', 'Title', 'Bar Chart', 'Position', [1 4 4 3], ...
    'PlotFcn', @(ax) bar(ax, 1:6, [23 45 12 67 34 56]));
d.addWidget('rawaxes', 'Title', 'Staircase', 'Position', [5 4 4 3], ...
    'PlotFcn', @(ax) stairs(ax, 0:20, cumsum(randn(1,21)), 'LineWidth', 2));
d.addWidget('rawaxes', 'Title', 'Stem Plot', 'Position', [9 4 4 3], ...
    'PlotFcn', @(ax) stem(ax, 1:20, randn(1,20)));

d.render();
fprintf('8. Custom plot dashboard with %d RawAxes widgets.\n', numel(d.Widgets));
delete(d.hFigure);

%% 9. Table widget with structured data
d = DashboardEngine('Data Tables');
d.Theme = 'industrial';

d.addWidget('table', 'Title', 'Sensor Readings', 'Position', [1 1 6 3], ...
    'ColumnNames', {'Tag', 'Value', 'Unit', 'Status'}, ...
    'Data', {'T-401', '72.3', [char(176) 'F'], 'Normal'; ...
             'P-201', '48.1', 'psi',           'Normal'; ...
             'F-101', '3.14', 'L/min',         'Low'; ...
             'V-301', '1205', 'rpm',           'High'; ...
             'H-501', '45.0', '%RH',           'Normal'});

d.addWidget('table', 'Title', 'Alarm History', 'Position', [7 1 6 3], ...
    'ColumnNames', {'Time', 'Tag', 'Message'}, ...
    'Data', {'08:15', 'T-401', 'High temperature warning'; ...
             '09:42', 'V-301', 'Vibration exceeded limit'; ...
             '11:03', 'F-101', 'Flow rate below setpoint'; ...
             '14:27', 'T-401', 'Temperature returned to normal'});

d.render();
fprintf('9. Table dashboard rendered.\n');
delete(d.hFigure);

%% 10. Event timeline
d = DashboardEngine('Process Timeline');
d.Theme = 'dark';

% Define process events with start/end times (in seconds)
events = struct( ...
    'startTime', {0,     1800,  5400,  9000, 14400, 18000}, ...
    'endTime',   {1800,  5400,  9000, 14400, 18000, 21600}, ...
    'label',     {'Startup', 'Heating', 'Hold', 'Cooling', 'Heating', 'Shutdown'}, ...
    'color',     {[0.5 0.5 0.5], [1 0.3 0.1], [0.2 0.8 0.4], ...
                  [0.1 0.5 1], [1 0.3 0.1], [0.5 0.5 0.5]});

d.addWidget('timeline', 'Title', 'Batch Process', 'Position', [1 1 12 2], ...
    'Events', events);

d.addWidget('kpi', 'Title', 'Batch Duration', 'Position', [1 3 4 1], ...
    'StaticValue', 6, 'Units', 'hrs', 'Format', '%.0f');
d.addWidget('kpi', 'Title', 'Phases', 'Position', [5 3 4 1], ...
    'StaticValue', 6, 'Format', '%.0f');
d.addWidget('status', 'Title', 'Batch Status', 'Position', [9 3 4 1], ...
    'StaticStatus', 'ok');

d.render();
fprintf('10. Timeline dashboard rendered.\n');
delete(d.hFigure);

fprintf('\nAll 10 programmatic dashboard examples completed.\n');

