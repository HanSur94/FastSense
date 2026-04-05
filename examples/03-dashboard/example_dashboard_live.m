%% Dashboard Engine — Live Mode Demo
% Demonstrates every widget type updating in real time. A background timer
% simulates incoming sensor data, and the dashboard refreshes automatically.
%
%   Widget types shown:
%     text       — static header
%     number     — sensor-bound big number with trend arrow
%     status     — sensor-bound colored indicator (auto ok/warning/alarm)
%     fastsense   — sensor-bound plots with thresholds + violation markers
%     gauge      — sensor-bound arc gauge
%     rawaxes    — live histogram via PlotFcn
%     table      — alarm log driven by DataFcn
%     timeline   — violation events from EventStore
%
% Usage:
%   example_dashboard_live
%
% Press "Live" in the toolbar to start/stop the update timer.
% Close the figure to clean up the background data timer.

close all force;
clear functions;

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

example_dashboard_live_run();

function example_dashboard_live_run()
%EXAMPLE_DASHBOARD_LIVE_RUN Main function — nested functions share workspace
%   so all callbacks see the latest state without handle-class boilerplate.

    %% ========== Create Sensors with thresholds ==========
    rng('shuffle');
    nSeed = 200;
    tSeed = linspace(-20, 0, nSeed);

    % Temperature sensor T-401 (4 thresholds: upper/lower warn + alarm)
    sTemp = Sensor('T-401', 'Name', 'Temperature');
    sTemp.Units = [char(176) 'F'];
    sTemp.X = tSeed;
    sTemp.Y = 70 + 2*sin(2*pi*tSeed/10) + randn(1, nSeed)*0.5;
    tHiWarnTemp = Threshold('hi_warn', 'Name', 'Hi Warn', ...
        'Direction', 'upper', 'Color', [1 0.8 0], 'LineStyle', '--');
    tHiWarnTemp.addCondition(struct(), 78);
    sTemp.addThreshold(tHiWarnTemp);

    tHiAlarmTemp = Threshold('hi_alarm', 'Name', 'Hi Alarm', ...
        'Direction', 'upper', 'Color', [1 0.2 0.2], 'LineStyle', '-');
    tHiAlarmTemp.addCondition(struct(), 82);
    sTemp.addThreshold(tHiAlarmTemp);

    tLoWarnTemp = Threshold('lo_warn', 'Name', 'Lo Warn', ...
        'Direction', 'lower', 'Color', [1 0.8 0], 'LineStyle', '--');
    tLoWarnTemp.addCondition(struct(), 62);
    sTemp.addThreshold(tLoWarnTemp);

    tLoAlarmTemp = Threshold('lo_alarm', 'Name', 'Lo Alarm', ...
        'Direction', 'lower', 'Color', [1 0.2 0.2], 'LineStyle', '-');
    tLoAlarmTemp.addCondition(struct(), 58);
    sTemp.addThreshold(tLoAlarmTemp);
    sTemp.resolve();

    % Pressure sensor P-201 (4 thresholds: upper/lower warn + alarm)
    sPress = Sensor('P-201', 'Name', 'Pressure');
    sPress.Units = 'psi';
    sPress.X = tSeed;
    sPress.Y = 50 + 5*sin(2*pi*tSeed/15) + randn(1, nSeed)*1.0;
    tHiWarnPress = Threshold('hi_warn', 'Name', 'Hi Warn', ...
        'Direction', 'upper', 'Color', [1 0.8 0], 'LineStyle', '--');
    tHiWarnPress.addCondition(struct(), 64);
    sPress.addThreshold(tHiWarnPress);

    tHiAlarmPress = Threshold('hi_alarm', 'Name', 'Hi Alarm', ...
        'Direction', 'upper', 'Color', [1 0.2 0.2], 'LineStyle', '-');
    tHiAlarmPress.addCondition(struct(), 68);
    sPress.addThreshold(tHiAlarmPress);

    tLoWarnPress = Threshold('lo_warn', 'Name', 'Lo Warn', ...
        'Direction', 'lower', 'Color', [1 0.8 0], 'LineStyle', '--');
    tLoWarnPress.addCondition(struct(), 36);
    sPress.addThreshold(tLoWarnPress);

    tLoAlarmPress = Threshold('lo_alarm', 'Name', 'Lo Alarm', ...
        'Direction', 'lower', 'Color', [1 0.2 0.2], 'LineStyle', '-');
    tLoAlarmPress.addCondition(struct(), 32);
    sPress.addThreshold(tLoAlarmPress);
    sPress.resolve();

    % Flow sensor F-301 (4 thresholds: upper/lower warn + alarm)
    sFlow = Sensor('F-301', 'Name', 'Flow Rate');
    sFlow.Units = 'L/min';
    sFlow.X = tSeed;
    sFlow.Y = max(0, 120 + 8*sin(2*pi*tSeed/8) + randn(1, nSeed)*2.0);
    tHiWarnFlow = Threshold('hi_warn', 'Name', 'Hi Warn', ...
        'Direction', 'upper', 'Color', [1 0.8 0], 'LineStyle', '--');
    tHiWarnFlow.addCondition(struct(), 135);
    sFlow.addThreshold(tHiWarnFlow);

    tHiAlarmFlow = Threshold('hi_alarm', 'Name', 'Hi Alarm', ...
        'Direction', 'upper', 'Color', [1 0.2 0.2], 'LineStyle', '-');
    tHiAlarmFlow.addCondition(struct(), 145);
    sFlow.addThreshold(tHiAlarmFlow);

    tLoWarnFlow = Threshold('lo_warn', 'Name', 'Lo Warn', ...
        'Direction', 'lower', 'Color', [1 0.8 0], 'LineStyle', '--');
    tLoWarnFlow.addCondition(struct(), 95);
    sFlow.addThreshold(tLoWarnFlow);

    tLoAlarmFlow = Threshold('lo_alarm', 'Name', 'Lo Alarm', ...
        'Direction', 'lower', 'Color', [1 0.2 0.2], 'LineStyle', '-');
    tLoAlarmFlow.addCondition(struct(), 85);
    sFlow.addThreshold(tLoAlarmFlow);
    sFlow.resolve();

    %% ========== EventStore for violation events ==========
    store = EventStore(fullfile(tempdir, 'dashboard_live_events.mat'));

    %% ========== Shared state for non-sensor widgets ==========
    S.mode = 'idle';
    S.alarms = {};

    % Mode schedule: cycle through modes
    modeSchedule = {'idle', 'running', 'running', 'maintenance', 'running', 'idle'};
    modeDurations = [15, 30, 25, 10, 30, 20];

    %% ========== Data generation timer (10 Hz) ==========
    tStart = tic;
    hDataTimer = timer('ExecutionMode', 'fixedRate', ...
        'Period', 0.1, ...
        'TimerFcn', @(~,~) updateState());

    %% ========== Build Dashboard ==========
    d = DashboardEngine('Live Process Monitoring');
    d.Theme = 'light';
    d.LiveInterval = 1;

    % --- Row 1-2: Header + KPIs + Status ---
    % DashboardEngine uses a 24-column grid: Position = [col row width height].
    d.addWidget('text', 'Title', 'Live Monitor', ...
        'Position', [1 1 4 2], ...
        'Content', 'Simulated Process', ...
        'FontSize', 14, ...
        'Alignment', 'left');

    % Sensor-bound: auto-derives value + trend from Sensor.Y
    d.addWidget('number', 'Title', 'Temperature', ...
        'Position', [5 1 5 2], ...
        'Sensor', sTemp, ...
        'Format', '%.1f');

    d.addWidget('number', 'Title', 'Pressure', ...
        'Position', [10 1 5 2], ...
        'Sensor', sPress, ...
        'Format', '%.0f');

    % Sensor-bound: auto-derives ok/warning/alarm from threshold rules
    d.addWidget('status', 'Title', 'Temp', ...
        'Position', [15 1 5 2], ...
        'Sensor', sTemp);

    d.addWidget('status', 'Title', 'Press', ...
        'Position', [20 1 5 2], ...
        'Sensor', sPress);

    % --- Row 3-10: Sensor-bound FastSense widgets (thresholds + violations) ---
    d.addWidget('fastsense', ...
        'Position', [1 3 12 8], ...
        'Sensor', sTemp);

    d.addWidget('fastsense', ...
        'Position', [13 3 12 8], ...
        'Sensor', sPress);

    % --- Row 11-18: Flow + Gauges ---
    d.addWidget('fastsense', ...
        'Position', [1 11 12 8], ...
        'Sensor', sFlow);

    % Sensor-bound gauges: auto-derives value from Sensor.Y(end)
    d.addWidget('gauge', 'Title', 'Temperature', ...
        'Position', [13 11 4 4], ...
        'Sensor', sTemp, ...
        'Range', [50 90]);

    d.addWidget('gauge', 'Title', 'Pressure', ...
        'Position', [17 11 4 4], ...
        'Sensor', sPress, ...
        'Range', [20 80]);

    d.addWidget('gauge', 'Title', 'Flow', ...
        'Position', [21 11 4 4], ...
        'Sensor', sFlow, ...
        'Range', [0 170]);

    % Status indicator for flow
    d.addWidget('status', 'Title', 'Flow', ...
        'Position', [13 15 4 2], ...
        'Sensor', sFlow);

    % Sensor-bound number for flow
    d.addWidget('number', 'Title', 'Flow Rate', ...
        'Position', [17 15 4 2], ...
        'Sensor', sFlow, ...
        'Format', '%.1f');

    d.addWidget('rawaxes', 'Title', 'Temp Distribution', ...
        'Position', [21 15 4 2], ...
        'PlotFcn', @plotHist);

    % --- Row 17-18: Table, Row 19-21: Timeline (EventStore) ---
    d.addWidget('table', 'Title', 'Alarm Log', ...
        'Position', [13 17 12 2], ...
        'ColumnNames', {'Time', 'Tag', 'Value', 'Severity'}, ...
        'DataFcn', @getAlarms);

    d.addWidget('timeline', 'Title', 'Violation Events', ...
        'Position', [1 19 24 3], ...
        'EventStoreObj', store);

    %% ========== Render and go live ==========
    d.render();
    start(hDataTimer);
    d.startLive();

    fprintf('Dashboard is LIVE — data at 10 Hz, display refreshes every %d s.\n', ...
        d.LiveInterval);
    fprintf('Sensors have thresholds — violation markers will appear on plots.\n');
    fprintf('Close the figure to stop.\n');

    % Clean up data timer when figure closes (engine handles its own timer)
    origCloseFcn = get(d.hFigure, 'CloseRequestFcn');
    set(d.hFigure, 'CloseRequestFcn', ...
        @(src,~) cleanupAndClose(hDataTimer, origCloseFcn, src));

    %% ==================== Nested: data update ====================
    function updateState()
        elapsed = toc(tStart);

        % Determine current mode from schedule
        cumDur = cumsum(modeDurations);
        cycleT = mod(elapsed, cumDur(end));
        mIdx = find(cycleT < cumDur, 1);
        S.mode = modeSchedule{mIdx};

        % Generate sensor values based on mode
        switch S.mode
            case 'idle',        tB = 68; pB = 30; fB = 5;
            case 'running',     tB = 76; pB = 58; fB = 125;
            case 'maintenance', tB = 64; pB = 20; fB = 0;
            otherwise,          tB = 70; pB = 40; fB = 60;
        end

        newT = tB + 3*sin(2*pi*elapsed/10) + randn*0.8;
        newP = pB + 6*sin(2*pi*elapsed/15) + randn*1.2;
        newF = max(0, fB + 8*sin(2*pi*elapsed/8) + randn*3);

        % Append to sensors
        sTemp.X(end+1)  = elapsed;
        sTemp.Y(end+1)  = newT;
        sPress.X(end+1) = elapsed;
        sPress.Y(end+1) = newP;
        sFlow.X(end+1)  = elapsed;
        sFlow.Y(end+1)  = newF;

        % Re-resolve thresholds so violation markers update
        sTemp.resolve();
        sPress.resolve();
        sFlow.resolve();

        % Check thresholds and create Event objects + alarm log
        checkAndLog(elapsed, sTemp, newT, 82, 78, 62, 58);
        checkAndLog(elapsed, sPress, newP, 68, 64, 36, 32);
        checkAndLog(elapsed, sFlow, newF, 145, 135, 95, 85);
    end

    function checkAndLog(elapsed, sensor, val, hiAlarm, hiWarn, loWarn, loAlarm)
        if val > hiAlarm
            logEvent(elapsed, sensor, val, 'Hi Alarm', hiAlarm, 'upper');
        elseif val > hiWarn
            logEvent(elapsed, sensor, val, 'Hi Warn', hiWarn, 'upper');
        elseif val < loAlarm
            logEvent(elapsed, sensor, val, 'Lo Alarm', loAlarm, 'lower');
        elseif val < loWarn
            logEvent(elapsed, sensor, val, 'Lo Warn', loWarn, 'lower');
        end
    end

    function logEvent(elapsed, sensor, val, label, thVal, dir)
        % Add to alarm log table
        mins = floor(elapsed / 60);
        secs = floor(mod(elapsed, 60));
        S.alarms(end+1, :) = {sprintf('%02d:%02d', mins, secs), ...
            sensor.Key, sprintf('%.1f', val), label};
        if size(S.alarms, 1) > 12
            S.alarms = S.alarms(end-11:end, :);
        end

        % Add Event to EventStore
        ev = Event(elapsed, elapsed, sensor.Key, label, thVal, dir);
        ev = ev.setStats(val, 1, val, val, val, val, 0);
        store.append(ev);
    end

    %% ==================== Nested: value callbacks ====================
    function a = getAlarms(), a = S.alarms; end

    %% ==================== Nested: plot callbacks ====================
    function plotHist(ax)
        if numel(sTemp.Y) < 2, return; end
        nH = min(numel(sTemp.Y), 600);
        histogram(ax, sTemp.Y(end-nH+1:end), 30, ...
            'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none');
        xlabel(ax, [char(176) 'F']);
        ylabel(ax, 'Count');
        title(ax, 'Temp Distribution');
    end
end

%% ========== Cleanup ==========
function cleanupAndClose(hTimer, origCloseFcn, src)
    if strcmp(hTimer.Running, 'on')
        stop(hTimer);
    end
    delete(hTimer);
    % Call the engine's original CloseRequestFcn (stops live timer + deletes figure)
    if isa(origCloseFcn, 'function_handle')
        origCloseFcn(src, []);
    else
        delete(src);
    end
end
