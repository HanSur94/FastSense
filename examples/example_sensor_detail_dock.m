%% SensorDetailPlot Dock — Multi-Tab Dashboard
%
% Demonstrates a FastSenseDock with 4 tabs, each containing multiple plots.
% Tabs mix SensorDetailPlots (with navigators) and plain FastSense tiles.
%
%   Tab 1: Process Overview   — 4 SensorDetailPlots (2x2 grid)
%   Tab 2: Correlation         — 2 SensorDetailPlots + 2 plain FastSenses
%   Tab 3: Event Analysis      — 1 large SensorDetailPlot + event details
%   Tab 4: Trends              — 6 plain FastSenses showing z-score overlays

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

%% ===== Shared data =====
rng(42);  % reproducible

% Time axis: 4 hours at ~10 Hz
tStart = datetime(2026, 3, 11, 6, 0, 0);
tEnd   = datetime(2026, 3, 11, 10, 0, 0);
N = 144000;
tDt = linspace(tStart, tEnd, N);
tNum = datenum(tDt);

% State channel (constant mode=1)
sc = StateChannel('mode');
sc.X = [tNum(1) tNum(end)];
sc.Y = [1 1];

% --- Sensor 1: Temperature ---
d1 = 120 + 12*sin(2*pi*tNum*24/2) + 2*randn(1, N);
d1(40000:40600) = d1(40000:40600) + 35;   % spike ~08:40
d1(100000:100200) = d1(100000:100200) + 40; % spike ~09:47

s1 = Sensor('temp', 'Name', 'Furnace Temperature');
s1.X = tNum; s1.Y = d1;
s1.addStateChannel(sc);
s1.addThresholdRule(struct('mode', 1), 140, ...
    'Direction', 'upper', 'Label', 'H Warning', 'Color', [1 0.75 0]);
s1.addThresholdRule(struct('mode', 1), 155, ...
    'Direction', 'upper', 'Label', 'HH Alarm', 'Color', [1 0 0]);
s1.resolve();

ev1a = Event(tNum(40000), tNum(40600), 'temp', 'HH Alarm', 155, 'upper');
ev1b = Event(tNum(100000), tNum(100200), 'temp', 'HH Alarm', 155, 'upper');

% --- Sensor 2: Pressure ---
d2 = 4.2 + 0.5*sin(2*pi*tNum*24/1.5) + 0.12*randn(1, N);
d2(60000:60400) = d2(60000:60400) - 1.5;  % dip ~07:40

s2 = Sensor('pressure', 'Name', 'Chamber Pressure');
s2.X = tNum; s2.Y = d2;
s2.addStateChannel(sc);
s2.addThresholdRule(struct('mode', 1), 3.2, ...
    'Direction', 'lower', 'Label', 'L Warning', 'Color', [0.3 0.6 1]);
s2.resolve();

ev2 = Event(tNum(60000), tNum(60400), 'pressure', 'L Warning', 3.2, 'lower');

% --- Sensor 3: Vibration ---
d3 = 0.8 + 0.3*sin(2*pi*tNum*24/0.5) + 0.08*randn(1, N);
d3(80000:80300) = d3(80000:80300) + 0.9;  % spike ~08:13

s3 = Sensor('vib', 'Name', 'Motor Vibration');
s3.X = tNum; s3.Y = d3;
s3.addStateChannel(sc);
s3.addThresholdRule(struct('mode', 1), 1.4, ...
    'Direction', 'upper', 'Label', 'H Warning', 'Color', [1 0.75 0]);
s3.resolve();

ev3 = Event(tNum(80000), tNum(80300), 'vib', 'H Warning', 1.4, 'upper');

% --- Sensor 4: Flow Rate ---
d4 = 52 + 6*sin(2*pi*tNum*24/3) + 1.5*randn(1, N);

s4 = Sensor('flow', 'Name', 'Coolant Flow Rate');
s4.X = tNum; s4.Y = d4;

allEvents = [ev1a, ev1b, ev2, ev3];

%% ===== Create Dock =====
dock = FastSenseDock('Theme', 'light', 'Name', 'Sensor Detail Dashboard', ...
    'Position', [50 50 1400 800]);

%% ===== Tab 1: Process Overview (2x2 SensorDetailPlots) =====
fig1 = FastSenseGrid(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'light');

sensors = {s1, s2, s3, s4};
titles  = {'Furnace Temperature', 'Chamber Pressure', ...
           'Motor Vibration', 'Coolant Flow Rate'};
sdps = cell(1, 4);
for i = 1:4
    sdps{i} = SensorDetailPlot(sensors{i}, ...
        'Parent', fig1.tilePanel(i), ...
        'Events', allEvents, ...
        'XType', 'datenum', ...
        'Title', titles{i});
    sdps{i}.render();
end

dock.addTab(fig1, 'Process Overview');

%% ===== Tab 2: Correlation (2 SensorDetailPlots + 2 plain) =====
fig2 = FastSenseGrid(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'light');

% Top row: SensorDetailPlots for temperature and pressure
sdpCorr1 = SensorDetailPlot(s1, 'Parent', fig2.tilePanel(1), ...
    'Events', [ev1a, ev1b], 'XType', 'datenum', 'Title', 'Temperature');
sdpCorr1.render();

sdpCorr2 = SensorDetailPlot(s2, 'Parent', fig2.tilePanel(2), ...
    'Events', ev2, 'XType', 'datenum', 'Title', 'Pressure');
sdpCorr2.render();

% Bottom row: plain FastSenses
% Tile 3: Temperature + Pressure overlay (z-score normalized)
fp3 = fig2.tile(3);
fp3.addLine(tNum, (d1-mean(d1))/std(d1), 'DisplayName', 'Temp (z)', 'XType', 'datenum');
fp3.addLine(tNum, (d2-mean(d2))/std(d2), 'DisplayName', 'Pres (z)', 'XType', 'datenum');
fig2.setTileTitle(3, 'Normalized Overlay');

% Tile 4: Rolling correlation
winSize = 5000;
corrVals = movCorr(d1, d2, winSize);
fp4 = fig2.tile(4);
fp4.addLine(tNum, corrVals, 'DisplayName', 'Correlation', 'XType', 'datenum');
fig2.setTileTitle(4, 'Rolling Correlation');

dock.addTab(fig2, 'Correlation');

%% ===== Tab 3: Event Analysis (1 large + event table) =====
fig3 = FastSenseGrid(1, 2, 'ParentFigure', dock.hFigure, 'Theme', 'light');

% Left: large SensorDetailPlot of temperature
sdpEvent = SensorDetailPlot(s1, 'Parent', fig3.tilePanel(1), ...
    'Events', [ev1a, ev1b], ...
    'XType', 'datenum', ...
    'Title', 'Temperature — Event Focus');
sdpEvent.render();
% Zoom to first event
sdpEvent.setZoomRange(tNum(38000), tNum(42000));

% Right: vibration detail around its event
sdpVib = SensorDetailPlot(s3, 'Parent', fig3.tilePanel(2), ...
    'Events', ev3, ...
    'XType', 'datenum', ...
    'Title', 'Vibration — Event Focus');
sdpVib.render();
sdpVib.setZoomRange(tNum(78000), tNum(82000));

dock.addTab(fig3, 'Event Analysis');

%% ===== Tab 4: Trends (3x2 plain FastSenses) =====
fig4 = FastSenseGrid(3, 2, 'ParentFigure', dock.hFigure, 'Theme', 'light');

% Column 1: Raw signals
rawSensors = {s1, s2, s3};
rawTitles  = {'Temperature (raw)', 'Pressure (raw)', 'Vibration (raw)'};
for i = 1:3
    fp = fig4.tile(i);
    fp.addLine(rawSensors{i}.X, rawSensors{i}.Y, ...
        'DisplayName', rawSensors{i}.Name, 'XType', 'datenum');
    fig4.setTileTitle(i, rawTitles{i});
end

% Column 2: Z-score normalized overlays
zTemp = (d1 - mean(d1)) / std(d1);
zPres = (d2 - mean(d2)) / std(d2);
zVib  = (d3 - mean(d3)) / std(d3);
zFlow = (d4 - mean(d4)) / std(d4);

% Tile 4: Temp + Pressure z-scores
fp4a = fig4.tile(4);
fp4a.addLine(tNum, zTemp, 'DisplayName', 'Temperature', 'XType', 'datenum');
fp4a.addLine(tNum, zPres, 'DisplayName', 'Pressure', 'XType', 'datenum');
fig4.setTileTitle(4, 'Temp + Pressure (z-score)');

% Tile 5: Vibration + Flow z-scores
fp5 = fig4.tile(5);
fp5.addLine(tNum, zVib, 'DisplayName', 'Vibration', 'XType', 'datenum');
fp5.addLine(tNum, zFlow, 'DisplayName', 'Flow', 'XType', 'datenum');
fig4.setTileTitle(5, 'Vib + Flow (z-score)');

% Tile 6: All 4 z-scores
fp6 = fig4.tile(6);
fp6.addLine(tNum, zTemp, 'DisplayName', 'Temp', 'XType', 'datenum');
fp6.addLine(tNum, zPres, 'DisplayName', 'Pressure', 'XType', 'datenum');
fp6.addLine(tNum, zVib,  'DisplayName', 'Vibration', 'XType', 'datenum');
fp6.addLine(tNum, zFlow, 'DisplayName', 'Flow', 'XType', 'datenum');
fig4.setTileTitle(6, 'All Sensors (z-score)');

dock.addTab(fig4, 'Trends');

%% ===== Render =====
dock.renderAll();

fprintf('4-tab dashboard ready.\n');
fprintf('  Tab 1: Process Overview — 4 SensorDetailPlots with navigators\n');
fprintf('  Tab 2: Correlation — SensorDetailPlots + scatter + rolling corr\n');
fprintf('  Tab 3: Event Analysis — zoomed into specific events\n');
fprintf('  Tab 4: Trends — raw signals + z-score overlays\n');

%% ===== Helper =====
function c = movCorr(x, y, w)
    % Simple moving-window Pearson correlation (no toolbox needed)
    c = nan(1, numel(x));
    half = floor(w / 2);
    for i = half+1:numel(x)-half
        xi = x(i-half:i+half);
        yi = y(i-half:i+half);
        xi = xi - mean(xi);
        yi = yi - mean(yi);
        denom = sqrt(sum(xi.^2) * sum(yi.^2));
        if denom > 0
            c(i) = sum(xi .* yi) / denom;
        else
            c(i) = 0;
        end
    end
    % Fill edges
    c(1:half) = c(half+1);
    c(end-half+1:end) = c(end-half);
end
