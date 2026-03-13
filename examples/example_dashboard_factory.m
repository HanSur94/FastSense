function example_dashboard_factory()
%EXAMPLE_DASHBOARD_FACTORY Dashboard Factory — Templates, Builders, and Multi-Dashboard Workflows
%   Shows reusable patterns for building dashboards at scale:
%     - Factory functions that create standard dashboard layouts
%     - Building N dashboards from a sensor list
%     - Composing layouts row-by-row
%     - JSON round-trip for persistence
%     - Script export for reproducibility
%
%   Usage:
%     example_dashboard_factory

setup();

%% 1. Row-by-row layout builder
%  Build layouts by appending rows — no manual position math.

d = DashboardEngine('Row Builder');
d.Theme = 'dark';

row = 1;

% Row 1: Header (height 1)
d.addWidget('text', 'Title', 'System Overview', ...
    'Position', [1 row 12 1], ...
    'Content', 'Automated Layout', 'FontSize', 18, 'Alignment', 'center');
row = row + 1;

% Row 2: Four equal KPIs (height 1)
labels = {'Temp', 'Pressure', 'Flow', 'Level'};
units  = {[char(176) 'C'], 'bar', 'L/min', 'm'};
values = [72.3, 2.5, 15.7, 4.2];
for i = 1:4
    col = 1 + (i-1)*3;
    d.addWidget('kpi', 'Title', labels{i}, 'Position', [col row 3 1], ...
        'StaticValue', values(i), 'Units', units{i});
end
row = row + 1;

% Row 3-5: Two plots side by side (height 3)
t = linspace(0, 3600, 5000);
d.addWidget('fastplot', 'Title', 'Temperature', 'Position', [1 row 6 3], ...
    'XData', t, 'YData', 70 + 5*sin(2*pi*t/600) + randn(1,5000)*0.3);
d.addWidget('fastplot', 'Title', 'Pressure', 'Position', [7 row 6 3], ...
    'XData', t, 'YData', 50 + 10*sin(2*pi*t/900) + randn(1,5000)*0.5);
row = row + 3;

% Row 6-7: Table + gauge (height 2)
d.addWidget('table', 'Title', 'Alarm Log', 'Position', [1 row 8 2], ...
    'ColumnNames', {'Time', 'Tag', 'Value', 'Status'}, ...
    'Data', {'08:15', 'T-401', '82.3', 'Warning'; ...
             '11:03', 'T-401', '86.1', 'Alarm'; ...
             '14:27', 'P-201', '68.5', 'OK'});
d.addWidget('gauge', 'Title', 'Load', 'Position', [9 row 4 2], ...
    'StaticValue', 67, 'Range', [0 100], 'Units', '%');

d.render();
fprintf('1. Row-by-row layout: %d widgets across %d rows.\n', numel(d.Widgets), row+1);
delete(d.hFigure);

%% 2. Factory function — create dashboards from sensor metadata

sensorList = {
    struct('tag', 'T-401', 'name', 'Reactor Temp',  'unit', [char(176) 'C'], 'nominal', 72,  'alarm', 85)
    struct('tag', 'P-201', 'name', 'Header Press',  'unit', 'bar',           'nominal', 2.5, 'alarm', 4.0)
    struct('tag', 'F-101', 'name', 'Feed Flow',     'unit', 'L/min',         'nominal', 15,  'alarm', 25)
    struct('tag', 'V-301', 'name', 'Motor Speed',   'unit', 'rpm',           'nominal', 1200,'alarm', 1500)
};

d = buildSensorDashboard('Sensor Overview', sensorList, 'industrial');
fprintf('2. Factory built sensor dashboard: %d widgets.\n', numel(d.Widgets));
delete(d.hFigure);

%% 3. Multiple dashboards from the same factory

groups = {
    struct('name', 'Line 1', 'theme', 'dark',       'sensors', {sensorList(1:2)})
    struct('name', 'Line 2', 'theme', 'ocean',      'sensors', {sensorList(3:4)})
    struct('name', 'Line 3', 'theme', 'industrial', 'sensors', {sensorList})
};

for i = 1:numel(groups)
    g = groups{i};
    d = buildSensorDashboard(g.name, g.sensors, g.theme);
    fprintf('3. Dashboard "%s": %d widgets, theme=%s\n', g.name, numel(d.Widgets), g.theme);
    delete(d.hFigure);
end

%% 4. KPI grid builder — N metrics in a responsive grid

metrics = {
    struct('name', 'Temp 1',     'value', 71.2,  'unit', [char(176) 'C'])
    struct('name', 'Temp 2',     'value', 73.8,  'unit', [char(176) 'C'])
    struct('name', 'Pressure A', 'value', 2.41,  'unit', 'bar')
    struct('name', 'Pressure B', 'value', 2.53,  'unit', 'bar')
    struct('name', 'Flow In',    'value', 15.7,  'unit', 'L/min')
    struct('name', 'Flow Out',   'value', 14.9,  'unit', 'L/min')
    struct('name', 'Level',      'value', 4.2,   'unit', 'm')
    struct('name', 'pH',         'value', 7.01,  'unit', '')
    struct('name', 'Conductivity','value', 1.23, 'unit', 'mS/cm')
    struct('name', 'Dissolved O2','value', 8.1,  'unit', 'mg/L')
    struct('name', 'Turbidity',  'value', 0.45,  'unit', 'NTU')
    struct('name', 'ORP',        'value', 215,   'unit', 'mV')
};

d = buildKpiGrid('KPI Wall', metrics, 'dark', 4);  % 4 columns per row
fprintf('4. KPI grid: %d metrics in auto-layout.\n', numel(d.Widgets));
delete(d.hFigure);

%% 5. Dashboard cloning via JSON round-trip

d = DashboardEngine('Original');
d.Theme = 'scientific';
d.addWidget('kpi', 'Title', 'Metric A', 'Position', [1 1 6 1], 'StaticValue', 42);
d.addWidget('kpi', 'Title', 'Metric B', 'Position', [7 1 6 1], 'StaticValue', 99);
d.render();

% Save and reload as a copy
jsonPath = fullfile(tempdir, 'clone_source.json');
d.save(jsonPath);
delete(d.hFigure);

clone = DashboardEngine.load(jsonPath);
clone.Name = 'Cloned Dashboard';
clone.Theme = 'dark';
clone.render();
fprintf('5. Cloned "%s" -> "%s" via JSON.\n', 'Original', clone.Name);
delete(clone.hFigure);

%% 6. Export as MATLAB script

d = DashboardEngine('Export Demo');
d.Theme = 'ocean';
d.addWidget('kpi', 'Title', 'Speed', 'Position', [1 1 4 1], ...
    'StaticValue', 1500, 'Units', 'rpm');
d.addWidget('status', 'Title', 'Motor', 'Position', [5 1 4 1], ...
    'StaticStatus', 'ok');
d.addWidget('gauge', 'Title', 'Torque', 'Position', [9 1 4 2], ...
    'StaticValue', 65, 'Range', [0 100], 'Units', 'Nm');
d.render();

scriptPath = fullfile(tempdir, 'exported_dashboard.m');
d.exportScript(scriptPath);
fprintf('6. Exported to: %s\n', scriptPath);

% Print the exported script
fid = fopen(scriptPath, 'r');
if fid > 0
    script = fread(fid, '*char')';
    fclose(fid);
    fprintf('--- Exported Script ---\n%s\n--- End ---\n', script);
end
delete(d.hFigure);

%% 7. Parameterized status board — equipment list

equipment = {'Pump A', 'Pump B', 'Compressor', 'Chiller', 'Boiler', 'Conveyor'};
d = buildStatusBoard('Equipment Health', equipment, 'industrial');
fprintf('7. Status board: %d equipment items.\n', numel(equipment));
delete(d.hFigure);

fprintf('\nAll 7 factory examples completed.\n');
end

%% ============================================================
%% Factory Functions
%% ============================================================

function d = buildSensorDashboard(name, sensors, theme)
%BUILDSENSORDASHBOARD Create a dashboard from a sensor metadata list.
%   Each sensor gets: KPI card (row 1) + status (row 2) + plot (row 3-5).
    d = DashboardEngine(name);
    d.Theme = theme;
    n = numel(sensors);
    colWidth = max(2, floor(12 / n));

    % Row 1: KPI cards
    for i = 1:n
        s = sensors{i};
        col = 1 + (i-1) * colWidth;
        d.addWidget('kpi', 'Title', s.tag, 'Position', [col 1 colWidth 1], ...
            'StaticValue', s.nominal, 'Units', s.unit, 'Format', '%.1f');
    end

    % Row 2: Status indicators
    for i = 1:n
        s = sensors{i};
        col = 1 + (i-1) * colWidth;
        d.addWidget('status', 'Title', s.name, 'Position', [col 2 colWidth 1], ...
            'StaticStatus', 'ok');
    end

    % Row 3-5: Time-series plots
    t = linspace(0, 3600, 5000);
    for i = 1:n
        s = sensors{i};
        col = 1 + (i-1) * colWidth;
        y = s.nominal + (s.alarm - s.nominal)*0.3*sin(2*pi*t/600) + randn(1,5000)*0.5;
        d.addWidget('fastplot', 'Title', sprintf('%s Trend', s.tag), ...
            'Position', [col 3 colWidth 3], ...
            'XData', t, 'YData', y);
    end

    d.render();
    set(d.hFigure, 'Visible', 'off');
end

function d = buildKpiGrid(name, metrics, theme, cols)
%BUILDKPIGRID Lay out N KPI widgets in a grid with given column count.
    d = DashboardEngine(name);
    d.Theme = theme;
    colWidth = floor(12 / cols);
    n = numel(metrics);

    for i = 1:n
        m = metrics{i};
        c = mod(i-1, cols);
        r = floor((i-1) / cols);
        col = 1 + c * colWidth;
        row = 1 + r;
        d.addWidget('kpi', 'Title', m.name, 'Position', [col row colWidth 1], ...
            'StaticValue', m.value, 'Units', m.unit, 'Format', '%.2f');
    end

    d.render();
    set(d.hFigure, 'Visible', 'off');
end

function d = buildStatusBoard(name, equipmentNames, theme)
%BUILDSTATUSBOARD Create a grid of status indicators for equipment list.
    d = DashboardEngine(name);
    d.Theme = theme;
    n = numel(equipmentNames);
    cols = min(n, 6);
    colWidth = max(2, floor(12 / cols));

    d.addWidget('text', 'Title', name, 'Position', [1 1 12 1], ...
        'Content', sprintf('%d items monitored', n), ...
        'FontSize', 16, 'Alignment', 'center');

    for i = 1:n
        c = mod(i-1, cols);
        r = floor((i-1) / cols);
        col = 1 + c * colWidth;
        row = 2 + r;
        d.addWidget('status', 'Title', equipmentNames{i}, ...
            'Position', [col row colWidth 1], ...
            'StaticStatus', 'ok');
    end

    d.render();
    set(d.hFigure, 'Visible', 'off');
end
