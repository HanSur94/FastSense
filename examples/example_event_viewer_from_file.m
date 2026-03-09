function example_event_viewer_from_file()
%EXAMPLE_EVENT_VIEWER_FROM_FILE Demonstrates saving events to file and viewing them later.
%
%   Part 1: Detect events and auto-save to a .mat file
%   Part 2: Open EventViewer from the saved file with refresh controls
%   Part 3: Backup creation on re-detection
%   Part 4: Live refresh — background process updates file, viewer polls it
%
%   Run:  example_event_viewer_from_file()
%   Stop: Close the Event Viewer figure to stop the background timer.

    setup();

    eventFile = fullfile(tempdir, 'demo_event_store.mat');
    fprintf('\n=== Event Store Demo ===\n\n');

    % --- Part 1: Detect events and auto-save ---
    fprintf('--- Part 1: Detecting events and saving to file ---\n');
    fprintf('  File: %s\n\n', eventFile);

    % Create mock sensor data
    N = 500;
    dt = 0.1;
    t = (0:N-1) * dt;

    % Temperature: baseline 70 C, with ramps and spikes
    temp = 70 + 5*sin(t/5) + 2*randn(1, N);
    rampIdx = t >= 20 & t <= 30;
    temp(rampIdx) = temp(rampIdx) + linspace(0, 25, sum(rampIdx));
    spikeIdx = t >= 40 & t <= 42;
    temp(spikeIdx) = temp(spikeIdx) + 30;

    % Pressure: baseline 6 bar, with dips
    pressure = 6 + 0.5*sin(t/3) + 0.3*randn(1, N);
    lowIdx = t >= 15 & t <= 18;
    pressure(lowIdx) = pressure(lowIdx) - 4;

    % Set up sensors
    sTemp = Sensor('temperature', 'Name', 'Temperature');
    sTemp.X = t; sTemp.Y = temp;
    sTemp.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'temp warning');
    sTemp.addThresholdRule(struct(), 95, 'Direction', 'upper', 'Label', 'temp critical');

    sPres = Sensor('pressure', 'Name', 'Pressure');
    sPres.X = t; sPres.Y = pressure;
    sPres.addThresholdRule(struct(), 4, 'Direction', 'lower', 'Label', 'pressure low');

    % Configure detection with auto-save
    cfg = EventConfig();
    cfg.MinDuration = 0.5;
    cfg.EventFile = eventFile;       % <-- enables auto-save
    cfg.MaxBackups = 3;              % <-- keep up to 3 backup files

    cfg.addSensor(sTemp);
    cfg.addSensor(sPres);

    cfg.setColor('temp warning',  [1.0 0.8 0.0]);
    cfg.setColor('temp critical', [1.0 0.2 0.0]);
    cfg.setColor('pressure low',  [0.2 0.5 1.0]);

    % Run detection - events are automatically saved to eventFile
    events = cfg.runDetection();
    fprintf('  Detected %d events, saved to file.\n\n', numel(events));

    % --- Part 2: Open viewer from file (with refresh controls) ---
    fprintf('--- Part 2: Opening EventViewer from saved file ---\n');
    fprintf('  Loading: %s\n', eventFile);

    viewer = EventViewer.fromFile(eventFile);
    fprintf('  Viewer opened with %d events.\n', numel(viewer.Events));
    fprintf('  Figure title shows save timestamp.\n');
    fprintf('  Refresh controls: [Refresh] button, [Auto] checkbox, interval input.\n\n');

    % --- Part 3: Run detection again to demonstrate backup ---
    fprintf('--- Part 3: Running detection again (backup created) ---\n');

    % Add some more data
    tNew = (N:N+99) * dt;
    tempNew = 70 + 5*sin(tNew/5) + 2*randn(1, 100);
    tempNew(40:60) = tempNew(40:60) + 25;
    presNew = 6 + 0.5*sin(tNew/3) + 0.3*randn(1, 100);

    sTemp.X = [t, tNew]; sTemp.Y = [temp, tempNew];
    sPres.X = [t, tNew]; sPres.Y = [pressure, presNew];

    % Update sensor data in config
    cfg.SensorData(1).t = sTemp.X;
    cfg.SensorData(1).y = sTemp.Y;
    cfg.SensorData(2).t = sPres.X;
    cfg.SensorData(2).y = sPres.Y;

    events2 = cfg.runDetection();
    fprintf('  Detected %d events, saved (previous version backed up).\n', numel(events2));

    % Show backup files
    [fDir, fName, fExt] = fileparts(eventFile);
    backups = dir(fullfile(fDir, [fName, '_*', fExt]));
    fprintf('  Backup files:\n');
    for i = 1:numel(backups)
        fprintf('    %s\n', backups(i).name);
    end
    % --- Part 4: Simulate background process updating the file ---
    fprintf('\n--- Part 4: Simulating background data updates ---\n');
    fprintf('  A timer will update the .mat file every 3 seconds.\n');
    fprintf('  Click [Refresh] or enable [Auto] in the viewer to see updates.\n');
    fprintf('  Close the Event Viewer figure to stop.\n\n');

    % Start a background timer that appends data and re-detects
    bgTimer = timer('ExecutionMode', 'fixedRate', 'Period', 3.0, ...
        'TimerFcn', @(~,~) backgroundUpdate(cfg, sTemp, sPres, dt));

    % Stop timer when viewer is closed
    existingDeleteFcn = get(viewer.hFigure, 'DeleteFcn');
    set(viewer.hFigure, 'DeleteFcn', @(src, evt) cleanupAll(src, evt, bgTimer, existingDeleteFcn));

    start(bgTimer);
    fprintf('  Background timer started. Close Event Viewer to stop.\n');
end

function backgroundUpdate(cfg, sTemp, sPres, dt)
    try
        nOld = numel(sTemp.X);
        nNew = 30;
        tNew = (nOld:nOld+nNew-1) * dt;

        newTemp = 70 + 5*sin(tNew/5) + 2*randn(1, nNew);
        newPres = 6 + 0.5*sin(tNew/3) + 0.3*randn(1, nNew);

        % Random chance of violations
        if rand() < 0.3
            vi = randi(nNew); span = min(vi+8, nNew);
            newTemp(vi:span) = newTemp(vi:span) + 25;
        end
        if rand() < 0.2
            vi = randi(nNew); span = min(vi+6, nNew);
            newPres(vi:span) = newPres(vi:span) - 4;
        end

        sTemp.X = [sTemp.X, tNew]; sTemp.Y = [sTemp.Y, newTemp];
        sPres.X = [sPres.X, tNew]; sPres.Y = [sPres.Y, newPres];

        cfg.SensorData(1).t = sTemp.X; cfg.SensorData(1).y = sTemp.Y;
        cfg.SensorData(2).t = sPres.X; cfg.SensorData(2).y = sPres.Y;

        cfg.runDetection();
        fprintf('  [BG] Updated at t=%.1f (%d total points)\n', tNew(end), numel(sTemp.X));
    catch err
        fprintf('  [BG] Error: %s\n', err.message);
    end
end

function cleanupAll(src, evt, bgTimer, existingDeleteFcn)
    if ~isempty(bgTimer) && isvalid(bgTimer)
        stop(bgTimer);
        delete(bgTimer);
    end
    if ~isempty(existingDeleteFcn) && isa(existingDeleteFcn, 'function_handle')
        existingDeleteFcn(src, evt);
    end
    fprintf('\n  Background timer stopped.\n');
end
