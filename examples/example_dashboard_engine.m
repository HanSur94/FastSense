%% Dashboard Engine Example — Sensor-Driven
% Demonstrates: DashboardEngine with FastPlotWidgets bound to Sensors,
% dynamic thresholds via StateChannels, JSON save/load.

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

%% 1. Generate data and create Sensors with thresholds
rng(7);
N = 10000;
t = linspace(0, 86400, N);  % 24 hours in seconds

% Machine mode state channel: idle(0) -> running(1) -> idle(0) -> running(1)
scMode = StateChannel('machine');
scMode.X = [0, 7200, 43200, 57600];
scMode.Y = [0, 1,    0,     1    ];

% Temperature sensor with mode-dependent thresholds
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.X = t;
sTemp.Y = 70 + 5*sin(2*pi*t/3600) + randn(1,N)*0.8;
sTemp.addStateChannel(scMode);
sTemp.addThresholdRule(struct('machine', 1), 78, ...
    'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.addThresholdRule(struct('machine', 1), 85, ...
    'Direction', 'upper', 'Label', 'Hi Alarm');
sTemp.addThresholdRule(struct('machine', 0), 73, ...
    'Direction', 'upper', 'Label', 'Idle Hi');
sTemp.resolve();

% Pressure sensor with unconditional thresholds
sPress = Sensor('P-201', 'Name', 'Pressure');
sPress.X = t;
sPress.Y = 50 + 20*sin(2*pi*t/7200) + randn(1,N)*1.5;
sPress.addThresholdRule(struct(), 65, ...
    'Direction', 'upper', 'Label', 'Hi Warn');
sPress.addThresholdRule(struct(), 70, ...
    'Direction', 'upper', 'Label', 'Hi Alarm');
sPress.resolve();

%% 2. Create dashboard with sensor-bound widgets
d = DashboardEngine('Process Monitoring — Line 4');
d.Theme = 'light';
d.LiveInterval = 5;

d.addWidget('fastplot', ...
    'Position', [1 1 16 8], ...
    'SensorObj', sTemp);

d.addWidget('fastplot', ...
    'Position', [17 1 8 8], ...
    'SensorObj', sPress);

d.addWidget('fastplot', 'Title', 'Temperature (full view)', ...
    'Position', [1 9 24 8], ...
    'SensorObj', sTemp);

d.render();

%% 3. Save to JSON
d.save(fullfile(tempdir, 'example_dashboard.json'));
fprintf('Dashboard saved to: %s\n', fullfile(tempdir, 'example_dashboard.json'));
fprintf('Temperature violations: %d\n', countViol(sTemp));
fprintf('Pressure violations: %d\n', countViol(sPress));

function n = countViol(s)
    n = 0;
    if ~isempty(s.ResolvedViolations)
        for k = 1:numel(s.ResolvedViolations)
            n = n + numel(s.ResolvedViolations(k).X);
        end
    end
end
