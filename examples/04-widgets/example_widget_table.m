%% TableWidget Demo — All Configurations
% Demonstrates the three data-source modes of the TableWidget inside a
% DashboardEngine dashboard.
%
% Supported properties:
%   SensorObj      — Sensor object (alias: 'Sensor'); shows last N rows
%   DataFcn        — function_handle returning a cell array of table data
%   Data           — static cell array (rows x cols)
%   ColumnNames    — cell array of column header strings
%   Mode           — 'data' (default) or 'events'
%   N              — number of rows to display (default 10)
%   EventStoreObj  — EventStore object for 'events' mode
%   Title          — widget title string
%   Position       — [col row width height] on the 24-column grid

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Create a Sensor with threshold violations
rng(42);
N = 5000;
t = linspace(0, 86400, N);  % 24 hours in seconds
temp = 70 + 6*sin(2*pi*t/3600) + randn(1, N)*1.5;

sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.X = t;
sTemp.Y = temp;
tHiWarn = Threshold('hi_warn', 'Name', 'Hi Warn', 'Direction', 'upper');
tHiWarn.addCondition(struct(), 78);
sTemp.addThreshold(tHiWarn);

tHiAlarm = Threshold('hi_alarm', 'Name', 'Hi Alarm', 'Direction', 'upper');
tHiAlarm.addCondition(struct(), 82);
sTemp.addThreshold(tHiAlarm);
sTemp.resolve();

%% 2. Build a static alarm log from resolved violations
alarmLog = {};
for vi = 1:numel(sTemp.ResolvedViolations)
    v = sTemp.ResolvedViolations(vi);
    if isempty(v.X), continue; end
    nSample = min(5, numel(v.X));
    idx = round(linspace(1, numel(v.X), nSample));
    for j = 1:nSample
        tSec = v.X(idx(j));
        timeStr = sprintf('%02d:%02d', floor(tSec/3600), ...
            floor(mod(tSec, 3600)/60));
        alarmLog(end+1, :) = {timeStr, 'T-401', ...
            sprintf('%.1f', v.Y(idx(j))), v.Label}; %#ok<AGROW>
    end
end
if size(alarmLog, 1) > 10
    alarmLog = alarmLog(end-9:end, :);
end

%% 3. Create dashboard with three table configurations
d = DashboardEngine('Table Widget Demo');
d.Theme = 'light';

% --- Static Data table ---
d.addWidget('table', 'Title', 'Alarm Log (static)', ...
    'Position', [1 1 24 6], ...
    'Data', alarmLog, ...
    'ColumnNames', {'Time', 'Tag', 'Value', 'Severity'});

% --- DataFcn callback table ---
d.addWidget('table', 'Title', 'System Status (callback)', ...
    'Position', [1 7 24 6], ...
    'DataFcn', @() getLatestData(), ...
    'ColumnNames', {'Subsystem', 'Status', 'Uptime (h)', 'CPU %'});

% --- Sensor-bound table (last 8 readings) ---
d.addWidget('table', 'Title', 'Temperature — Last 8 Readings', ...
    'Position', [1 13 24 6], ...
    'Sensor', sTemp, ...
    'N', 8);

%% Render
d.render();

%% ---- Helper function ---------------------------------------------------
function data = getLatestData()
%GETLATESTDATA Return a cell array of mock system status rows.
    names   = {'Compressor', 'Chiller', 'Pump A', 'Pump B', 'HMI'};
    states  = {'Running', 'Running', 'Standby', 'Running', 'Running'};
    uptime  = {124.3, 89.7, 0.0, 212.5, 340.1};
    cpu     = {45, 62, 0, 38, 12};
    data = [names(:), states(:), uptime(:), cpu(:)];
end
