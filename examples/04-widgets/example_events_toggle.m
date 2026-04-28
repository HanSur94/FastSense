%% Events Toggle Button - Global Event Marker On/Off
% Demonstrates the Events toolbar button that globally shows/hides event
% markers across every widget in the dashboard.
%
% The button controls two render paths simultaneously:
%   1. Round event markers on FastSenseWidget charts (drawn by FastSense
%      when a bound Tag has an EventStore).
%   2. Coloured bars on EventTimelineWidget.
%
% Click the "Events" button in the top toolbar to toggle.  Button has a
% blue border when markers are ON, no border when OFF.  Default = ON.

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Synthetic sensor data (1 hour, 2 kHz-ish)
rng(42);
N = 4000;
t = linspace(0, 3600, N);

tempY  = 72 + 6*sin(2*pi*t/900)  + 1.0*randn(1,N);   % drifts above 78
pressY = 50 + 8*sin(2*pi*t/1200) + 1.5*randn(1,N);   % occasional spikes

sTemp  = SensorTag('T-401', 'Name', 'Temperature', 'Units', [char(176) 'C'], ...
                   'X', t, 'Y', tempY);
sPress = SensorTag('P-201', 'Name', 'Pressure',    'Units', 'psi', ...
                   'X', t, 'Y', pressY);

%% 2. EventStore with warn + alarm events across both tags
storePath = fullfile(tempdir, 'example_events_toggle_store.mat');
if exist(storePath, 'file'), delete(storePath); end
store = EventStore(storePath);

evts = [ ...
    Event(600,  900,  'T-401', 'Hi Warn',  78, 'upper'), ...
    Event(1500, 1800, 'T-401', 'Hi Alarm', 85, 'upper'), ...
    Event(2400, 2700, 'T-401', 'Hi Warn',  78, 'upper'), ...
    Event(900,  1200, 'P-201', 'Hi Warn',  65, 'upper'), ...
    Event(2100, 2400, 'P-201', 'Hi Alarm', 72, 'upper'), ...
    Event(3000, 3300, 'P-201', 'Hi Warn',  65, 'upper')];

% Paint severities so round markers get the warn/alarm colours.
sevByLabel = {'Hi Warn', 2; 'Hi Alarm', 3};
for k = 1:numel(evts)
    for s = 1:size(sevByLabel,1)
        if strcmp(evts(k).ThresholdLabel, sevByLabel{s,1})
            evts(k).Severity = sevByLabel{s,2};
        end
    end
    store.append(evts(k));
end

% Bind store to tags so FastSense auto-discovers it for round markers.
sTemp.EventStore  = store;
sPress.EventStore = store;

%% 3. Build dashboard
d = DashboardEngine('Events Toggle Demo');
d.Theme = 'light';

% Two FastSenseWidgets - round event markers appear via bound EventStore.
d.addWidget('fastsense', 'Position', [1  1 12 8], 'Tag', sTemp);
d.addWidget('fastsense', 'Position', [13 1 12 8], 'Tag', sPress);

% One EventTimelineWidget - coloured bars driven by the same store.
d.addWidget('timeline', 'Title', 'All Events', ...
    'Position', [1 9 24 4], ...
    'EventStoreObj', store);

d.render();

fprintf('\n');
fprintf('====================================================\n');
fprintf('  Events toggle demo ready.\n');
fprintf('====================================================\n');
fprintf('  Click the "Events" button in the top toolbar:\n');
fprintf('    ON  (blue border): round markers + timeline bars visible\n');
fprintf('    OFF (no border):   both cleared; live ticks will not redraw them\n');
fprintf('  Default = ON, matching pre-toggle behaviour.\n');
fprintf('====================================================\n');
