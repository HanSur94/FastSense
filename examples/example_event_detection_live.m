function example_event_detection_live()
%EXAMPLE_EVENT_DETECTION_LIVE Live event detection demo with industrial sensors.
%   Demonstrates the EventDetection library with 3 mock industrial sensors,
%   threshold-based event detection, console logging, EventViewer UI,
%   and a MATLAB timer for live data updates.
%
%   Run:  example_event_detection_live()
%   Stop: Close the Event Viewer figure to stop live mode.

    setup();

    persistent liveTimer liveViewer liveCfg liveN;

    fprintf('\n=== Event Detection Live Demo ===\n\n');

    % --- 1. Create mock sensor data ---
    N = 500;  % initial data points
    dt = 0.1; % sample interval (seconds)
    t = (0:N-1) * dt;

    % Temperature: baseline 70 C, with ramps and spikes
    temp = 70 + 5*sin(t/5) + 2*randn(1, N);
    % Inject a ramp violation at t=20-30
    rampIdx = t >= 20 & t <= 30;
    temp(rampIdx) = temp(rampIdx) + linspace(0, 25, sum(rampIdx));
    % Inject a spike at t=40
    spikeIdx = t >= 40 & t <= 42;
    temp(spikeIdx) = temp(spikeIdx) + 30;

    % Pressure: baseline 6 bar, with dips
    pressure = 6 + 0.5*sin(t/3) + 0.3*randn(1, N);
    % Inject a low-pressure event at t=15-18
    lowIdx = t >= 15 & t <= 18;
    pressure(lowIdx) = pressure(lowIdx) - 4;

    % Vibration: baseline 2 mm/s, with oscillation bursts
    vibration = 2 + 0.3*randn(1, N);
    % Inject oscillation burst at t=35-45
    burstIdx = t >= 35 & t <= 45;
    vibration(burstIdx) = vibration(burstIdx) + 4 * abs(sin((t(burstIdx)-35)*3));

    % --- 2. Create Sensor objects ---
    sTemp = Sensor('temperature', 'Name', 'Temperature');
    sTemp.X = t; sTemp.Y = temp;
    sTemp.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'temp warning');
    sTemp.addThresholdRule(struct(), 95, 'Direction', 'upper', 'Label', 'temp critical');

    sPres = Sensor('pressure', 'Name', 'Pressure');
    sPres.X = t; sPres.Y = pressure;
    sPres.addThresholdRule(struct(), 4, 'Direction', 'lower', 'Label', 'pressure low');

    sVib = Sensor('vibration', 'Name', 'Vibration');
    sVib.X = t; sVib.Y = vibration;
    sVib.addThresholdRule(struct(), 5, 'Direction', 'upper', 'Label', 'vibration high');

    % --- 3. Configure event detection ---
    cfg = EventConfig();
    cfg.MinDuration = 0.5;
    cfg.OnEventStart = eventLogger();
    cfg.MaxCallsPerEvent = 2;

    cfg.addSensor(sTemp);
    cfg.addSensor(sPres);
    cfg.addSensor(sVib);

    cfg.setColor('temp warning',  [1.0 0.8 0.0]);
    cfg.setColor('temp critical', [1.0 0.2 0.0]);
    cfg.setColor('pressure low',  [0.2 0.5 1.0]);
    cfg.setColor('vibration high',[0.8 0.3 0.8]);

    % --- 4. Initial detection ---
    fprintf('--- Initial Detection ---\n');
    events = cfg.runDetection();

    fprintf('\n--- Event Summary ---\n');
    printEventSummary(events);

    % --- 5. Open EventViewer ---
    liveViewer = EventViewer(events, cfg.SensorData, cfg.ThresholdColors);
    liveCfg = cfg;
    liveN = N;

    % --- 6. Start live timer ---
    fprintf('Starting live mode (new data every 2 seconds)...\n');
    fprintf('Close the Event Viewer figure to stop.\n\n');

    liveTimer = timer('ExecutionMode', 'fixedRate', ...
        'Period', 2.0, ...
        'TimerFcn', @(~,~) liveUpdate());

    % Stop when figure is closed
    set(liveViewer.hFigure, 'DeleteFcn', @(~,~) stopLive());

    start(liveTimer);

    function liveUpdate()
        try
            % Append 50 new data points
            nNew = 50;
            liveN = liveN + nNew;
            tNew = ((liveN - nNew):(liveN - 1)) * dt;

            % Generate new data with occasional violations
            newTemp = 70 + 5*sin(tNew/5) + 2*randn(1, nNew);
            newPres = 6 + 0.5*sin(tNew/3) + 0.3*randn(1, nNew);
            newVib  = 2 + 0.3*randn(1, nNew);

            % Random chance of violations
            if rand() < 0.3
                vi = randi(nNew);
                span = min(vi+10, nNew);
                newTemp(vi:span) = newTemp(vi:span) + 20;
            end
            if rand() < 0.2
                vi = randi(nNew);
                span = min(vi+8, nNew);
                newPres(vi:span) = newPres(vi:span) - 4;
            end

            % Update sensors
            for i = 1:numel(liveCfg.Sensors)
                s = liveCfg.Sensors{i};
                switch s.Key
                    case 'temperature'
                        s.X = [s.X, tNew]; s.Y = [s.Y, newTemp];
                    case 'pressure'
                        s.X = [s.X, tNew]; s.Y = [s.Y, newPres];
                    case 'vibration'
                        s.X = [s.X, tNew]; s.Y = [s.Y, newVib];
                end
                liveCfg.SensorData(i).t = s.X;
                liveCfg.SensorData(i).y = s.Y;
            end

            % Re-detect
            fprintf('--- Live Update (t=%.1f) ---\n', tNew(end));
            events = liveCfg.runDetection();

            % Update viewer
            if isvalid(liveViewer) && ishandle(liveViewer.hFigure)
                liveViewer.update(events);
            end
        catch err
            fprintf('Live update error: %s\n', err.message);
        end
    end

    function stopLive()
        if ~isempty(liveTimer) && isvalid(liveTimer)
            stop(liveTimer);
            delete(liveTimer);
            fprintf('\nLive mode stopped.\n');
        end
    end
end
