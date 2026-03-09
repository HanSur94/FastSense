function example_event_detection_live()
%EXAMPLE_EVENT_DETECTION_LIVE Live event detection demo with industrial sensors.
%   Demonstrates the EventDetection library with 3 mock industrial sensors,
%   threshold-based event detection, console logging, EventViewer UI,
%   and a live FastPlot dashboard using startLive for real-time plotting.
%
%   Run:  example_event_detection_live()
%   Stop: Close the Event Viewer or Live Plot figure to stop.

    setup();

    persistent dataTimer liveViewer liveCfg liveN fpTemp fpPres fpVib hPlotFig;
    persistent tempFile presFile vibFile;

    fprintf('\n=== Event Detection Live Demo ===\n\n');

    % --- 1. Create mock sensor data ---
    N = 500;  % initial data points
    dt = 0.1; % sample interval (seconds)
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

    % Vibration: baseline 2 mm/s, with oscillation bursts
    vibration = 2 + 0.3*randn(1, N);
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

    % --- 6. Write initial .mat files for live plotting ---
    liveDir = fullfile(tempdir, 'fastplot_event_live');
    if ~exist(liveDir, 'dir'); mkdir(liveDir); end

    tempFile = fullfile(liveDir, 'temperature.mat');
    presFile = fullfile(liveDir, 'pressure.mat');
    vibFile  = fullfile(liveDir, 'vibration.mat');

    x = t; y = temp;      save(tempFile, 'x', 'y');
    x = t; y = pressure;  save(presFile, 'x', 'y');
    x = t; y = vibration; save(vibFile,  'x', 'y');

    % --- 7. Open live FastPlot dashboard ---
    hPlotFig = figure('Name', 'Live Sensor Dashboard', ...
        'NumberTitle', 'off', 'Position', [150 50 1200 700]);

    % Temperature plot
    ax1 = subplot(3,1,1, 'Parent', hPlotFig);
    fpTemp = FastPlot('Parent', ax1, 'LinkGroup', 'live_demo');
    fpTemp.addLine(t, temp, 'DisplayName', 'Temperature', 'Color', [0.8 0.2 0.1]);
    fpTemp.addThreshold(85, 'Direction', 'upper', 'ShowViolations', true, ...
        'Color', [1 0.8 0], 'LineStyle', '--', 'Label', 'temp warning');
    fpTemp.addThreshold(95, 'Direction', 'upper', 'ShowViolations', true, ...
        'Color', [1 0.2 0], 'LineStyle', '-', 'Label', 'temp critical');
    fpTemp.render();
    title(ax1, 'Temperature (C)');
    ylabel(ax1, 'C');

    % Pressure plot
    ax2 = subplot(3,1,2, 'Parent', hPlotFig);
    fpPres = FastPlot('Parent', ax2, 'LinkGroup', 'live_demo');
    fpPres.addLine(t, pressure, 'DisplayName', 'Pressure', 'Color', [0.2 0.5 1]);
    fpPres.addThreshold(4, 'Direction', 'lower', 'ShowViolations', true, ...
        'Color', [0.2 0.5 1], 'LineStyle', '--', 'Label', 'pressure low');
    fpPres.render();
    title(ax2, 'Pressure (bar)');
    ylabel(ax2, 'bar');

    % Vibration plot
    ax3 = subplot(3,1,3, 'Parent', hPlotFig);
    fpVib = FastPlot('Parent', ax3, 'LinkGroup', 'live_demo');
    fpVib.addLine(t, vibration, 'DisplayName', 'Vibration', 'Color', [0.8 0.3 0.8]);
    fpVib.addThreshold(5, 'Direction', 'upper', 'ShowViolations', true, ...
        'Color', [0.8 0.3 0.8], 'LineStyle', '--', 'Label', 'vibration high');
    fpVib.render();
    title(ax3, 'Vibration (mm/s)');
    ylabel(ax3, 'mm/s');
    xlabel(ax3, 'Time (s)');

    % --- 8. Start FastPlot live mode (polls .mat files, auto-scrolls) ---
    fpTemp.startLive(tempFile, @(fp, d) fp.updateData(1, d.x, d.y), ...
        'Interval', 2, 'ViewMode', 'follow');
    fpPres.startLive(presFile, @(fp, d) fp.updateData(1, d.x, d.y), ...
        'Interval', 2, 'ViewMode', 'follow');
    fpVib.startLive(vibFile,  @(fp, d) fp.updateData(1, d.x, d.y), ...
        'Interval', 2, 'ViewMode', 'follow');

    % --- 9. Start data generation timer ---
    fprintf('Starting live mode (new data every 2 seconds)...\n');
    fprintf('Close the Event Viewer or Live Plot figure to stop.\n\n');

    dataTimer = timer('ExecutionMode', 'fixedRate', ...
        'Period', 2.0, ...
        'TimerFcn', @(~,~) generateData());

    % Stop when EventViewer is closed
    set(liveViewer.hFigure, 'DeleteFcn', @(~,~) stopAll());

    start(dataTimer);

    function generateData()
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

            % Update sensor objects
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

            % Write updated data to .mat files — FastPlot startLive picks them up
            sT = liveCfg.Sensors{1}; x = sT.X; y = sT.Y; save(tempFile, 'x', 'y');
            sP = liveCfg.Sensors{2}; x = sP.X; y = sP.Y; save(presFile, 'x', 'y');
            sV = liveCfg.Sensors{3}; x = sV.X; y = sV.Y; save(vibFile,  'x', 'y');

            % Re-detect events
            fprintf('--- Live Update (t=%.1f) ---\n', tNew(end));
            events = liveCfg.runDetection();

            % Update EventViewer
            if isvalid(liveViewer) && ishandle(liveViewer.hFigure)
                liveViewer.update(events);
            end
        catch err
            fprintf('Live update error: %s\n', err.message);
        end
    end

    function stopAll()
        % Stop data generation timer
        if ~isempty(dataTimer) && isvalid(dataTimer)
            stop(dataTimer);
            delete(dataTimer);
        end
        % Stop FastPlot live timers
        try fpTemp.stopLive(); catch; end
        try fpPres.stopLive(); catch; end
        try fpVib.stopLive();  catch; end
        % Clean up temp files
        try delete(tempFile); catch; end
        try delete(presFile); catch; end
        try delete(vibFile);  catch; end
        fprintf('\nLive mode stopped.\n');
    end
end
