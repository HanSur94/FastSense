%% Demo: Dashboard time-slider preview overlay (backlog 999.3)
% Renders a dashboard with three FastSenseWidgets and a populated EventStore.
% The lower TimeRangeSelector should show:
%   - faint preview lines for each plotted series
%   - event marker dots
% across the full data range. Drag the selector handles to confirm the
% main plots reflect the selected sub-range while the preview stays full-range.

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

%% 1. Generate synthetic 24h sensor data
rng(7);
N = 5000;
t = linspace(0, 86400, N);                                  % 24h in seconds
yTemp  = 70 + 5*sin(2*pi*t/3600)  + randn(1, N)*0.8;        % °C
yPress = 50 + 20*sin(2*pi*t/7200) + randn(1, N)*1.5;        % bar
yFlow  = 12 + 3*cos(2*pi*t/5400)  + randn(1, N)*0.5;        % L/s

sTemp  = SensorTag('T-401', 'Name', 'Temperature', 'Units', [char(176) 'C'], 'X', t, 'Y', yTemp);
sPress = SensorTag('P-201', 'Name', 'Pressure',    'Units', 'bar',           'X', t, 'Y', yPress);
sFlow  = SensorTag('F-101', 'Name', 'Flow',        'Units', 'L/s',           'X', t, 'Y', yFlow);

TagRegistry.register('T-401', sTemp);
TagRegistry.register('P-201', sPress);
TagRegistry.register('F-101', sFlow);

%% 2. Build an EventStore with a handful of events scattered across 24h
storePath = fullfile(tempdir, 'demo_slider_preview_events.json');
if exist(storePath, 'file'); delete(storePath); end
es = EventStore(storePath);

eventTimes = [3600, 14400, 25200, 43200, 61200, 75600];     % 1h, 4h, 7h, 12h, 17h, 21h
eventDur   = [120,   600,   240,   900,   300,   480];      % seconds
sensorRot  = {'T-401', 'P-201', 'F-101', 'T-401', 'P-201', 'F-101'};
severities = [1, 2, 3, 1, 2, 3];                            % cycle ok/warn/alarm

evs = Event.empty;
for k = 1:numel(eventTimes)
    ev = Event(eventTimes(k), eventTimes(k) + eventDur(k), ...
        sensorRot{k}, 'demo_threshold', 100, 'upper');
    ev.TagKeys = sensorRot(k);
    ev.Severity = severities(k);
    ev.Category = 'alarm';
    evs(end+1) = ev; %#ok<SAGROW>
end
es.append(evs);
fprintf('EventStore: %d events spanning %.1f h\n', es.numEvents(), max(eventTimes)/3600);

%% 3. Build dashboard with widgets that opt into event markers
d = DashboardEngine('Slider Preview Demo — backlog 999.3');
d.Theme = 'dark';

d.addWidget('fastsense', 'Position', [1 1 24 6], ...
    'Tag', sTemp,  'ShowEventMarkers', true, 'EventStore', es);

d.addWidget('fastsense', 'Position', [1 7 12 6], ...
    'Tag', sPress, 'ShowEventMarkers', true, 'EventStore', es);

d.addWidget('fastsense', 'Position', [13 7 12 6], ...
    'Tag', sFlow,  'ShowEventMarkers', true, 'EventStore', es);

d.render();

fprintf('\nDashboard rendered. Look at the lower time-slider track:\n');
fprintf('  - Faint preview lines for Temperature / Pressure / Flow\n');
fprintf('  - %d event markers across 24h, colored by severity:\n', numel(eventTimes));
fprintf('      sev 1 (ok)    -> green\n');
fprintf('      sev 2 (warn)  -> orange\n');
fprintf('      sev 3 (alarm) -> red\n');
fprintf('Drag the slider handles to verify the upper plots respond.\n\n');
