%% Dashboard Engine Example — Phase 1 Core API
% Demonstrates: DashboardEngine with FastPlotWidgets, Sensor binding,
% JSON save/load, and live mode.

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

%% 1. Create dashboard with inline data
d = DashboardEngine('Process Monitoring — Line 4');
d.Theme = 'light';
d.LiveInterval = 5;

% Generate sample data
t = linspace(0, 86400, 10000); % 24 hours in seconds
temp = 70 + 5*sin(2*pi*t/3600) + randn(1,10000)*0.5;
pressure = 50 + 20*sin(2*pi*t/7200) + randn(1,10000)*1.0;

% Add FastPlot widgets
d.addWidget('fastplot', 'Title', 'Temperature', ...
    'Position', [1 1 8 3], ...
    'XData', t, 'YData', temp);

d.addWidget('fastplot', 'Title', 'Pressure', ...
    'Position', [9 1 4 3], ...
    'XData', t, 'YData', pressure);

d.addWidget('fastplot', 'Title', 'Temp vs Pressure Overlay', ...
    'Position', [1 4 12 3], ...
    'XData', t, 'YData', temp);

d.render();

%% 2. Save to JSON
d.save(fullfile(tempdir, 'example_dashboard.json'));
fprintf('Dashboard saved to: %s\n', fullfile(tempdir, 'example_dashboard.json'));

%% 3. Demonstrate Sensor binding (if SensorRegistry available)
% s = Sensor('T-401', 'Name', 'Temperature Sensor');
% s.X = t;
% s.Y = temp;
% s.addThresholdRule(struct(), 78, 'Direction', 'upper', 'Label', 'Hi Warn');
% s.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'Hi Alarm');
% s.resolve();
%
% d2 = DashboardEngine('Sensor Dashboard');
% d2.Theme = 'industrial';
% d2.addWidget('fastplot', 'Sensor', s, 'Position', [1 1 12 4]);
% d2.render();
