function example_event_viewer_from_file()
%EXAMPLE_EVENT_VIEWER_FROM_FILE Demonstrates saving events to file and viewing them later.
%
%   Part 1: Detect events from 6 industrial sensors and auto-save to .mat
%   Part 2: Open EventViewer from the saved file with refresh controls
%   Part 3: Backup creation on re-detection
%   Part 4: Live refresh — background process updates file, viewer polls it
%
%   Run:  example_event_viewer_from_file()
%   Stop: Close the Event Viewer figure to stop the background timer.

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    run(fullfile(projectRoot, 'install.m'));

    persistent sensorData;

    eventFile = fullfile(tempdir, 'demo_event_store.mat');
    fprintf('\n=== Event Store Demo (6 sensors) ===\n\n');

    % --- Part 1: Detect events and auto-save ---
    fprintf('--- Part 1: Detecting events and saving to file ---\n');
    fprintf('  File: %s\n\n', eventFile);

    N = 500;
    dt = 0.1;
    t = (0:N-1) * dt;

    % Temperature: baseline 70 C, ramps and spikes
    temp = 70 + 5*sin(t/5) + 2*randn(1, N);
    temp(t >= 20 & t <= 30) = temp(t >= 20 & t <= 30) + linspace(0, 25, sum(t >= 20 & t <= 30));
    temp(t >= 40 & t <= 42) = temp(t >= 40 & t <= 42) + 30;

    % Pressure: baseline 6 bar, dips
    pressure = 6 + 0.5*sin(t/3) + 0.3*randn(1, N);
    pressure(t >= 15 & t <= 18) = pressure(t >= 15 & t <= 18) - 4;

    % Vibration: baseline 2 mm/s, oscillation bursts
    vibration = 2 + 0.3*randn(1, N);
    vibration(t >= 35 & t <= 45) = vibration(t >= 35 & t <= 45) + 4*abs(sin((t(t >= 35 & t <= 45)-35)*3));

    % Flow Rate: baseline 120 L/min, drops
    flow = 120 + 8*sin(t/4) + 3*randn(1, N);
    flow(t >= 10 & t <= 14) = flow(t >= 10 & t <= 14) - 40;
    flow(t >= 38 & t <= 40) = flow(t >= 38 & t <= 40) - 50;

    % Humidity: baseline 45%, spikes
    humidity = 45 + 3*sin(t/6) + 1.5*randn(1, N);
    humidity(t >= 25 & t <= 32) = humidity(t >= 25 & t <= 32) + 20;

    % Current: baseline 15 A, overloads
    current = 15 + 2*sin(t/7) + randn(1, N);
    current(t >= 5 & t <= 8) = current(t >= 5 & t <= 8) + 12;
    current(t >= 42 & t <= 46) = current(t >= 42 & t <= 46) + 15;

    % --- Create SensorTag objects ---
    sTemp = SensorTag('temperature', 'Name', 'Temperature', 'X', t, 'Y', temp);
    sPres = SensorTag('pressure', 'Name', 'Pressure', 'X', t, 'Y', pressure);
    sVib = SensorTag('vibration', 'Name', 'Vibration', 'X', t, 'Y', vibration);
    sFlow = SensorTag('flow', 'Name', 'Flow Rate', 'X', t, 'Y', flow);
    sHum = SensorTag('humidity', 'Name', 'Humidity', 'X', t, 'Y', humidity);
    sCur = SensorTag('current', 'Name', 'Current', 'X', t, 'Y', current);

    sensors = {sTemp, sPres, sVib, sFlow, sHum, sCur};

    % Keep mutable data copies for live update
    sensorData = struct();
    yArrays = {temp, pressure, vibration, flow, humidity, current};
    for i = 1:numel(sensors)
        sensorData(i).x = t;
        sensorData(i).y = yArrays{i};
    end

    % --- Configure detection with auto-save ---
    cfg = EventConfig();
    cfg.MinDuration = 0.5;
    cfg.EventFile = eventFile;
    cfg.MaxBackups = 3;

    for i = 1:numel(sensors)
        cfg.addTag(sensors{i});
    end

    cfg.setColor('temp warning',     [1.0 0.8 0.0]);
    cfg.setColor('temp critical',    [1.0 0.2 0.0]);
    cfg.setColor('pressure low',     [0.2 0.5 1.0]);
    cfg.setColor('vibration high',   [0.8 0.3 0.8]);
    cfg.setColor('flow low',         [0.3 0.7 0.5]);
    cfg.setColor('humidity high',    [0.0 0.8 0.8]);
    cfg.setColor('current warning',  [1.0 0.6 0.2]);
    cfg.setColor('current overload', [0.9 0.1 0.1]);

    events = cfg.runDetection();
    fprintf('  Detected %d events across 6 sensors, saved to file.\n\n', numel(events));

    % --- Part 2: Open viewer from file ---
    fprintf('--- Part 2: Opening EventViewer from saved file ---\n');
    viewer = EventViewer.fromFile(eventFile);
    fprintf('  Viewer opened with %d events.\n', numel(viewer.Events));
    fprintf('  Refresh controls: [Refresh] button, [Auto] checkbox, interval input.\n\n');

    % --- Part 3: Run detection again to demonstrate backup ---
    fprintf('--- Part 3: Running detection again (backup created) ---\n');
    tNew = (N:N+99) * dt;
    for i = 1:numel(sensors)
        [~, yOld] = sensors{i}.getXY();
        newY = yOld(end) + randn(1, 100) * 2;
        sensorData(i).x = [sensorData(i).x, tNew];
        sensorData(i).y = [sensorData(i).y, newY];
        sensors{i}.updateData(sensorData(i).x, sensorData(i).y);
        cfg.SensorData(i).t = sensorData(i).x;
        cfg.SensorData(i).y = sensorData(i).y;
    end
    events2 = cfg.runDetection();
    fprintf('  Detected %d events, saved (previous version backed up).\n', numel(events2));

    [fDir, fName, fExt] = fileparts(eventFile);
    backups = dir(fullfile(fDir, [fName, '_*', fExt]));
    fprintf('  Backup files:\n');
    for i = 1:numel(backups)
        fprintf('    %s\n', backups(i).name);
    end

    % --- Part 4: Simulate background process ---
    fprintf('\n--- Part 4: Simulating background data updates ---\n');
    fprintf('  A timer will update the .mat file every 3 seconds.\n');
    fprintf('  Click [Refresh] or enable [Auto] in the viewer to see updates.\n');
    fprintf('  Close the Event Viewer figure to stop.\n\n');

    bgTimer = timer('ExecutionMode', 'fixedRate', 'Period', 3.0, ...
        'TimerFcn', @(~,~) backgroundUpdate(cfg, sensors, sensorData, dt));

    existingDeleteFcn = get(viewer.hFigure, 'DeleteFcn');
    set(viewer.hFigure, 'DeleteFcn', @(src, evt) cleanupAll(src, evt, bgTimer, existingDeleteFcn));

    start(bgTimer);
    fprintf('  Background timer started. Close Event Viewer to stop.\n');
end

function backgroundUpdate(cfg, sensors, sensorData, dt)
    try
        nOld = numel(sensorData(1).x);
        nNew = 30;
        tNew = (nOld:nOld+nNew-1) * dt;

        for i = 1:numel(sensors)
            baseVal = mean(sensorData(i).y(max(1,end-50):end));
            newY = baseVal + randn(1, nNew) * 2;

            % Random violations per sensor
            if rand() < 0.25
                vi = randi(nNew); span = min(vi+8, nNew);
                switch sensors{i}.Key
                    case 'temperature'
                        newY(vi:span) = newY(vi:span) + 25;
                    case 'pressure'
                        newY(vi:span) = newY(vi:span) - 4;
                    case 'vibration'
                        newY(vi:span) = newY(vi:span) + 5;
                    case 'flow'
                        newY(vi:span) = newY(vi:span) - 40;
                    case 'humidity'
                        newY(vi:span) = newY(vi:span) + 20;
                    case 'current'
                        newY(vi:span) = newY(vi:span) + 15;
                end
            end

            sensorData(i).x = [sensorData(i).x, tNew];
            sensorData(i).y = [sensorData(i).y, newY];
            sensors{i}.updateData(sensorData(i).x, sensorData(i).y);
            cfg.SensorData(i).t = sensorData(i).x;
            cfg.SensorData(i).y = sensorData(i).y;
        end

        cfg.runDetection();
        fprintf('  [BG] Updated at t=%.1f (%d total points)\n', tNew(end), numel(sensorData(1).x));
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
