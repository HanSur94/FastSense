%% EventTimelineWidget — All Configurations
% Demonstrates every data-source mode of the EventTimelineWidget inside a
% DashboardEngine dashboard.
%
% EventTimelineWidget properties:
%   EventStoreObj  — EventStore handle (primary data source).  Events are
%                    read via store.getEvents() and auto-converted to the
%                    rendering struct format.
%   Events         — struct array with fields: startTime, endTime, label,
%                    color (each a 1x3 RGB vector).  Also accepts an array
%                    of Event objects (auto-converted internally).
%   EventFcn       — function_handle returning an events struct array.
%                    Called on every refresh.
%   FilterSensors  — cell array of sensor name strings.  Only events whose
%                    label contains one of these strings are displayed.
%   ColorSource    — 'event' (use the event's color field) or 'theme'
%                    (cycle through theme status colors).
%   Title          — widget title string.
%   Position       — [col row width height] on the 24-column grid.

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

%% 1. Sample Data
rng(42);
tBase = 0;          % timeline in seconds
day   = 86400;

% --- Machine-mode events (struct array) ---
modeEvents = struct( ...
    'startTime', {tBase,      7200,       28800,   50400,       72000}, ...
    'endTime',   {7200,       28800,      50400,   72000,       day  }, ...
    'label',     {'Idle',     'Running',  'Idle',  'Running',   'Maintenance'}, ...
    'color',     {[.55 .55 .55], [.2 .7 .3], [.55 .55 .55], [.2 .7 .3], [.95 .6 .1]});

% --- Event objects (threshold violations) ---
violationEvents = [ ...
    Event(9000,  9600,  'T-401', 'Hi Warn',  78, 'high'), ...
    Event(18000, 19200, 'T-401', 'Hi Alarm', 85, 'high'), ...
    Event(36000, 36900, 'P-201', 'Hi Warn',  65, 'high'), ...
    Event(54000, 55800, 'T-401', 'Hi Warn',  78, 'high')];

% --- EventStore with appended events ---
storePath = fullfile(tempdir, 'example_timeline_store.mat');
store = EventStore(storePath);
store.append(Event(10800, 12600, 'T-401', 'Hi Warn',  78, 'high'));
store.append(Event(43200, 45000, 'P-201', 'Hi Alarm', 70, 'high'));
store.append(Event(61200, 63000, 'T-401', 'Hi Alarm', 85, 'high'));

%% 2. Build Dashboard
d = DashboardEngine('Timeline Widget Demo');

% Row 1 — Static struct events (machine mode timeline)
d.addWidget('timeline', 'Title', 'Machine Modes (struct)', ...
    'Position', [1 1 24 3], ...
    'Events', modeEvents);

% Row 2 — Event objects (auto-converted)
d.addWidget('timeline', 'Title', 'Violations (Event objects)', ...
    'Position', [1 4 24 3], ...
    'Events', violationEvents);

% Row 3 — EventStore binding
d.addWidget('timeline', 'Title', 'Store Events (EventStore)', ...
    'Position', [1 7 24 3], ...
    'EventStoreObj', store);

% Row 4 — EventFcn callback
d.addWidget('timeline', 'Title', 'Callback Events (EventFcn)', ...
    'Position', [1 10 24 3], ...
    'EventFcn', @() getEvents());

% Row 5 — EventStore with FilterSensors (only T-401)
d.addWidget('timeline', 'Title', 'Filtered — T-401 only', ...
    'Position', [1 13 24 3], ...
    'EventStoreObj', store, ...
    'FilterSensors', {{'T-401'}});

%% 3. Render
d.render();

fprintf('Dashboard rendered with %d timeline widgets.\n', numel(d.Widgets));

%% Helper — EventFcn data source
function evts = getEvents()
    evts = struct( ...
        'startTime', {3600,    21600,   43200,   64800}, ...
        'endTime',   {7200,    25200,   46800,   68400}, ...
        'label',     {'Warm-up','Steady','Cool-down','Steady'}, ...
        'color',     {[.95 .5 .2],[.2 .6 .9],[.4 .3 .8],[.2 .6 .9]});
end
