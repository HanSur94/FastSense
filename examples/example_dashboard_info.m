%% Dashboard Info Page Example
% Demonstrates: DashboardEngine with an Info button that opens a rendered
% Markdown file in the browser.
%
% The InfoFile property links a .md file to the dashboard.  When set, an
% "Info" button appears in the toolbar next to the title.  Clicking it
% renders the Markdown as HTML and opens it in MATLAB's built-in browser.
%
% See also: example_dashboard_engine, example_dashboard_all_widgets.

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

%% 1. Generate sample sensor data
rng(7);
N = 10000;
t = linspace(0, 86400, N);  % 24 hours in seconds

sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = [char(176) 'C'];
sTemp.X = t;
sTemp.Y = 70 + 5*sin(2*pi*t/3600) + randn(1,N)*0.8;
sTemp.addThresholdRule(struct(), 78, 'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'Hi Alarm');
sTemp.resolve();

sPress = Sensor('P-201', 'Name', 'Pressure');
sPress.Units = 'bar';
sPress.X = t;
sPress.Y = 50 + 20*sin(2*pi*t/7200) + randn(1,N)*1.5;
sPress.addThresholdRule(struct(), 65, 'Direction', 'upper', 'Label', 'Hi Warn');
sPress.addThresholdRule(struct(), 70, 'Direction', 'upper', 'Label', 'Hi Alarm');
sPress.resolve();

%% 2. Create dashboard with InfoFile
% The InfoFile points to a Markdown file in the same directory as this
% script.  The Info button will appear in the toolbar.
infoPath = fullfile(fileparts(mfilename('fullpath')), 'example_dashboard_info.md');

d = DashboardEngine('Process Monitoring — Line 4', ...
    'Theme', 'light', ...
    'InfoFile', infoPath);

d.addWidget('fastsense', ...
    'Position', [1 1 16 8], ...
    'Sensor', sTemp);

d.addWidget('fastsense', ...
    'Position', [17 1 8 8], ...
    'Sensor', sPress);

d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [1 9 6 4], ...
    'Units', [char(176) 'C'], ...
    'Sensor', sTemp);

d.addWidget('number', 'Title', 'Pressure', ...
    'Position', [7 9 6 4], ...
    'Units', 'bar', ...
    'Sensor', sPress);

d.addWidget('text', 'Title', 'Notes', ...
    'Position', [13 9 12 4], ...
    'Content', 'Click the Info button in the toolbar to view dashboard documentation.');

d.render();
fprintf('Dashboard rendered. Click the "Info" button next to the title.\n');

%% 3. Save and reload — InfoFile is preserved
jsonPath = fullfile(tempdir, 'example_dashboard_info.json');
d.save(jsonPath);
fprintf('Dashboard saved to: %s\n', jsonPath);

% Verify InfoFile survives the JSON round-trip
jsonText = fileread(jsonPath);
assert(contains(jsonText, 'infoFile'), 'infoFile should be in JSON');
fprintf('JSON contains infoFile field: OK\n');

% Register sensors so that fromStruct can resolve them during load
SensorRegistry.register('T-401', sTemp);
SensorRegistry.register('P-201', sPress);

d2 = DashboardEngine.load(jsonPath);
fprintf('Reloaded InfoFile: %s\n', d2.InfoFile);

% Clean up registry
SensorRegistry.unregister('T-401');
SensorRegistry.unregister('P-201');
