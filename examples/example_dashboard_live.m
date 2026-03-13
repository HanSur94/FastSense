function example_dashboard_live()
%EXAMPLE_DASHBOARD_LIVE Live Dashboard — Dynamic Data with Callbacks
%   Shows how to build dashboards that update automatically using ValueFcn,
%   StatusFcn, PlotFcn, and DataFcn callbacks.  Each widget's callback is
%   re-invoked every LiveInterval seconds.
%
%   Usage:
%     example_dashboard_live
%
%   Press "Live" in the toolbar to start/stop auto-refresh.

setup();

%% 1. KPI widgets with ValueFcn
%  ValueFcn returns either:
%    - a scalar
%    - a struct with fields: value, unit, trend ('up'/'down'/'flat')

d = DashboardEngine('Live KPI Dashboard');
d.Theme = 'dark';
d.LiveInterval = 2;

% Simple scalar callback
d.addWidget('kpi', 'Title', 'Random Value', 'Position', [1 1 3 1], ...
    'Units', 'units', ...
    'ValueFcn', @() randi(100));

% Struct callback with trend indicator (arrow shows up/down/flat)
d.addWidget('kpi', 'Title', 'Temperature', 'Position', [4 1 3 1], ...
    'Units', [char(176) 'C'], ...
    'Format', '%.1f', ...
    'ValueFcn', @() makeKpiResult(70 + 5*randn(), [char(176) 'C']));

d.addWidget('kpi', 'Title', 'Pressure', 'Position', [7 1 3 1], ...
    'Units', 'bar', ...
    'Format', '%.2f', ...
    'ValueFcn', @() makeKpiResult(2.5 + 0.3*randn(), 'bar'));

d.addWidget('kpi', 'Title', 'Flow Rate', 'Position', [10 1 3 1], ...
    'Units', 'L/min', ...
    'Format', '%.1f', ...
    'ValueFcn', @() makeKpiResult(15 + 2*randn(), 'L/min'));

d.render();
fprintf('1. Live KPI dashboard — press "Live" to start auto-refresh.\n');
delete(d.hFigure);

%% 2. Status widgets with StatusFcn
%  StatusFcn returns 'ok', 'warning', or 'alarm'.

d = DashboardEngine('Equipment Status Board');
d.Theme = 'industrial';
d.LiveInterval = 3;

d.addWidget('text', 'Title', 'Plant Floor', 'Position', [1 1 12 1], ...
    'Content', 'Equipment Health Monitor', ...
    'FontSize', 18, 'Alignment', 'center');

% Each pump has a random status that changes on refresh
pumps = {'Pump A', 'Pump B', 'Pump C', 'Pump D', 'Pump E', 'Pump F'};
for i = 1:numel(pumps)
    col = 1 + (i-1)*2;
    d.addWidget('status', 'Title', pumps{i}, 'Position', [col 2 2 1], ...
        'StatusFcn', @() randomStatus());
end

d.render();
fprintf('2. Equipment status board — 6 pumps with live status.\n');
delete(d.hFigure);

%% 3. Gauge widgets with ValueFcn

d = DashboardEngine('Gauge Panel');
d.Theme = 'dark';
d.LiveInterval = 2;

d.addWidget('gauge', 'Title', 'CPU', 'Position', [1 1 3 2], ...
    'Range', [0 100], 'Units', '%', ...
    'ValueFcn', @() 30 + 40*rand());

d.addWidget('gauge', 'Title', 'Memory', 'Position', [4 1 3 2], ...
    'Range', [0 64], 'Units', 'GB', ...
    'ValueFcn', @() 20 + 20*rand());

d.addWidget('gauge', 'Title', 'Disk I/O', 'Position', [7 1 3 2], ...
    'Range', [0 500], 'Units', 'MB/s', ...
    'ValueFcn', @() 50 + 200*rand());

d.addWidget('gauge', 'Title', 'Network', 'Position', [10 1 3 2], ...
    'Range', [0 1000], 'Units', 'Mbps', ...
    'ValueFcn', @() 100 + 500*rand());

d.render();
fprintf('3. Four live gauges rendered.\n');
delete(d.hFigure);

%% 4. Table with DataFcn — refreshable tabular data

d = DashboardEngine('Live Data Table');
d.Theme = 'ocean';
d.LiveInterval = 3;

d.addWidget('table', 'Title', 'Sensor Readings', 'Position', [1 1 12 4], ...
    'ColumnNames', {'Tag', 'Value', 'Unit', 'Timestamp', 'Status'}, ...
    'DataFcn', @() generateSensorTable());

d.render();
fprintf('4. Live table dashboard — data refreshes every 3 seconds.\n');
delete(d.hFigure);

%% 5. RawAxes with refreshing PlotFcn
%  PlotFcn is re-called on every refresh — the axes is cleared first.

d = DashboardEngine('Live Custom Plots');
d.Theme = 'dark';
d.LiveInterval = 2;

d.addWidget('rawaxes', 'Title', 'Random Walk', 'Position', [1 1 6 3], ...
    'PlotFcn', @(ax) plotRandomWalk(ax));
d.addWidget('rawaxes', 'Title', 'Noise Histogram', 'Position', [7 1 6 3], ...
    'PlotFcn', @(ax) plotNoiseHistogram(ax));

d.render();
fprintf('5. Live custom plots — new random data each refresh.\n');
delete(d.hFigure);

%% 6. EventTimeline with EventFcn — dynamic events

d = DashboardEngine('Live Event Timeline');
d.Theme = 'dark';
d.LiveInterval = 5;

d.addWidget('timeline', 'Title', 'Process Events (last hour)', ...
    'Position', [1 1 12 3], ...
    'EventFcn', @() generateRandomEvents());

d.addWidget('kpi', 'Title', 'Active Events', 'Position', [1 4 4 1], ...
    'ValueFcn', @() randi([1 5]));
d.addWidget('status', 'Title', 'System', 'Position', [5 4 4 1], ...
    'StatusFcn', @() randomStatus());
d.addWidget('gauge', 'Title', 'Uptime', 'Position', [9 4 4 2], ...
    'Range', [0 100], 'Units', '%', ...
    'ValueFcn', @() 95 + 5*rand());

d.render();
fprintf('6. Live event timeline dashboard.\n');
delete(d.hFigure);

%% 7. Combined live dashboard — realistic control room
d = DashboardEngine('Control Room');
d.Theme = 'dark';
d.LiveInterval = 2;

% Row 1: Title + live KPIs
d.addWidget('text', 'Title', 'Plant Control Room', 'Position', [1 1 4 1], ...
    'Content', 'Line 4 — Live', 'FontSize', 16);
d.addWidget('kpi', 'Title', 'Temp', 'Position', [5 1 2 1], ...
    'Units', [char(176) 'C'], 'Format', '%.1f', ...
    'ValueFcn', @() 70 + 5*randn());
d.addWidget('kpi', 'Title', 'Pressure', 'Position', [7 1 2 1], ...
    'Units', 'bar', 'Format', '%.2f', ...
    'ValueFcn', @() 2.5 + 0.3*randn());
d.addWidget('status', 'Title', 'Reactor', 'Position', [9 1 2 1], ...
    'StatusFcn', @() randomStatus());
d.addWidget('gauge', 'Title', 'Load', 'Position', [11 1 2 2], ...
    'Range', [0 100], 'Units', '%', ...
    'ValueFcn', @() 50 + 30*rand());

% Row 2-4: Time-series plots
t = linspace(0, 3600, 5000);
d.addWidget('fastplot', 'Title', 'Temperature (24h)', ...
    'Position', [1 2 5 3], ...
    'XData', t, 'YData', 70 + 5*sin(2*pi*t/600) + randn(1,5000)*0.5);
d.addWidget('fastplot', 'Title', 'Pressure (24h)', ...
    'Position', [6 2 5 3], ...
    'XData', t, 'YData', 50 + 10*sin(2*pi*t/900) + randn(1,5000)*1.0);

% Row 5: Table + status row
d.addWidget('table', 'Title', 'Recent Alarms', 'Position', [1 5 6 2], ...
    'ColumnNames', {'Time', 'Tag', 'Message'}, ...
    'DataFcn', @() generateAlarmTable());

d.addWidget('rawaxes', 'Title', 'Distribution', 'Position', [7 5 6 2], ...
    'PlotFcn', @(ax) plotNoiseHistogram(ax));

d.render();
fprintf('7. Full control room dashboard with %d live widgets.\n', numel(d.Widgets));
delete(d.hFigure);

fprintf('\nAll 7 live dashboard examples completed.\n');
end

%% ---- Callback helper functions ----

function result = makeKpiResult(value, unit)
%MAKEKPIRESULT Build a KPI struct with random trend direction.
    trends = {'up', 'down', 'flat'};
    result = struct('value', value, 'unit', unit, ...
        'trend', trends{randi(3)});
end

function s = randomStatus()
%RANDOMSTATUS Return a random status string.
    options = {'ok', 'ok', 'ok', 'warning', 'alarm'};
    s = options{randi(numel(options))};
end

function data = generateSensorTable()
%GENERATESENSORTABLE Return a cell array of sensor readings.
    tags   = {'T-401', 'P-201', 'F-101', 'V-301', 'H-501'};
    units  = {[char(176) 'C'], 'bar', 'L/min', 'rpm', '%RH'};
    values = [70+5*randn(), 2.5+0.3*randn(), 15+2*randn(), ...
              1200+50*randn(), 45+5*randn()];
    statuses = {'ok', 'ok', 'warning', 'ok', 'alarm'};

    now_str = datestr(now, 'HH:MM:SS');
    data = cell(numel(tags), 5);
    for i = 1:numel(tags)
        data{i,1} = tags{i};
        data{i,2} = sprintf('%.1f', values(i));
        data{i,3} = units{i};
        data{i,4} = now_str;
        data{i,5} = statuses{randi(numel(statuses))};
    end
end

function data = generateAlarmTable()
%GENERATEALARMTABLE Return a cell array of recent alarms.
    tags = {'T-401', 'P-201', 'F-101', 'V-301'};
    msgs = {'High temperature warning', 'Pressure spike detected', ...
            'Flow rate below setpoint', 'Vibration exceeded limit'};
    n = randi([2, 4]);
    data = cell(n, 3);
    for i = 1:n
        data{i,1} = datestr(now - (n-i)*1/1440, 'HH:MM:SS');
        idx = randi(numel(tags));
        data{i,2} = tags{idx};
        data{i,3} = msgs{idx};
    end
end

function events = generateRandomEvents()
%GENERATERANDOMEVENTS Return a struct array of random process events.
    labels = {'Heating', 'Cooling', 'Hold', 'Transfer', 'Idle'};
    colors = {[1 0.3 0.1], [0.1 0.5 1], [0.2 0.8 0.4], ...
              [0.9 0.7 0.1], [0.5 0.5 0.5]};
    n = randi([3 6]);
    startTimes = sort(randi(3600, 1, n));
    durations = randi([300 900], 1, n);

    events = struct('startTime', {}, 'endTime', {}, 'label', {}, 'color', {});
    for i = 1:n
        idx = randi(numel(labels));
        events(i).startTime = startTimes(i);
        events(i).endTime = startTimes(i) + durations(i);
        events(i).label = labels{idx};
        events(i).color = colors{idx};
    end
end

function plotRandomWalk(ax)
%PLOTRANDOMWALK Plot a cumulative random walk.
    y = cumsum(randn(1, 500));
    plot(ax, y, 'LineWidth', 1.5, 'Color', [0.31 0.80 0.64]);
    title(ax, '');
end

function plotNoiseHistogram(ax)
%PLOTNOISEHISTOGRAM Plot a histogram of random noise.
    data = randn(1, 1000);
    if exist('histogram', 'file')
        histogram(ax, data, 30, 'FaceColor', [0.90 0.49 0.13], 'EdgeColor', 'none');
    else
        hist(ax, data, 30);
    end
    title(ax, '');
end
