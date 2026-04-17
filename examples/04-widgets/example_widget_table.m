%% TableWidget Demo — All Configurations
% Demonstrates the three data-source modes of the TableWidget inside a
% DashboardEngine dashboard.
%
% Supported properties:
%   SensorObj      — Sensor object (alias: 'Tag'); shows last N rows
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

sTemp = SensorTag('T-401', 'Name', 'Temperature', 'X', t, 'Y', temp);

%% 2. Build a static alarm log by sampling the sensor at its local peaks
% In the v2.0 Tag model, thresholds live on separate MonitorTag objects
% rather than a Sensor.ResolvedViolations list — so for this TableWidget
% demo we synthesize a compact alarm log by picking the ten highest samples
% and labelling them against two example thresholds.
[~, peakIdx] = maxk(temp, 10);
peakIdx = sort(peakIdx);  % chronological order
alarmLog = cell(numel(peakIdx), 4);
hiWarn  = 76;  % mock "Hi Warn" threshold
hiAlarm = 80;  % mock "Hi Alarm" threshold
for j = 1:numel(peakIdx)
    tSec  = t(peakIdx(j));
    yVal  = temp(peakIdx(j));
    if yVal >= hiAlarm
        label = 'Hi Alarm';
    elseif yVal >= hiWarn
        label = 'Hi Warn';
    else
        label = 'Peak';
    end
    timeStr = sprintf('%02d:%02d', floor(tSec/3600), ...
        floor(mod(tSec, 3600)/60));
    alarmLog(j, :) = {timeStr, 'T-401', sprintf('%.1f', yVal), label};
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
    'Tag', sTemp, ...
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
