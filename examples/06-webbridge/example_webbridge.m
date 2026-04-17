%% WebBridge — Serve Live Sensor Data to Python
% Demonstrates the full MATLAB-to-Python pipeline:
%   1. Creates sensors with live data and thresholds
%   2. Builds a dashboard with FastSense widgets
%   3. Starts the WebBridge (REST API + WebSocket)
%   4. Simulates live data updates every 0.5s
%
% Once running, the bridge exposes:
%   GET  /api/signals              — list available signals
%   GET  /api/signals/{id}/data    — query time series (xMin, xMax, maxPoints)
%   GET  /api/signals/{id}/thresholds
%   POST /api/signals/bulk         — fetch multiple signals at once
%   POST /api/actions/{name}       — invoke MATLAB callbacks
%   POST /api/open-in-matlab/{id}  — export .mat + open analysis script
%   WS   /ws                       — real-time push notifications
%   GET  /docs                     — interactive API documentation
%
% Pair this with examples/06-webbridge/example_webbridge_dashboard.py on the Python side.
%
% Usage:
%   example_webbridge
%
% Prerequisites:
%   pip install fastsense-bridge   (or: cd bridge/python && pip install -e .)

close all force;
clear functions;

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

example_webbridge_run();

function example_webbridge_run()

    %% ========== Create Sensors ==========
    rng('shuffle');
    nSeed = 500;
    tSeed = linspace(-60, 0, nSeed);

    % Temperature sensor
    sTemp = SensorTag('temperature', 'Name', 'Temperature', 'Units', [char(176) 'C'], 'X', tSeed, 'Y', 22 + 3*sin(2*pi*tSeed/30) + randn(1, nSeed)*0.3);

    % Pressure sensor
    sPress = SensorTag('pressure', 'Name', 'Pressure', 'Units', 'bar', 'X', tSeed, 'Y', 4.5 + 0.5*sin(2*pi*tSeed/20) + randn(1, nSeed)*0.1);

    % Vibration sensor
    sVib = SensorTag('vibration', 'Name', 'Vibration', 'Units', 'mm/s', 'X', tSeed, 'Y', 2.0 + 0.8*randn(1, nSeed) + 0.5*sin(2*pi*tSeed/15));

    %% ========== Build Dashboard ==========
    engine = DashboardEngine('Sensor Monitor');
    engine.addWidget('fastsense', ...
        'Position', [1 1 24 8], ...
        'Sensor', sTemp, ...
        'Title', 'Temperature');
    engine.addWidget('fastsense', ...
        'Position', [1 9 12 8], ...
        'Sensor', sPress, ...
        'Title', 'Pressure');
    engine.addWidget('fastsense', ...
        'Position', [13 9 12 8], ...
        'Sensor', sVib, ...
        'Title', 'Vibration');

    %% ========== Start WebBridge ==========
    bridge = WebBridge(engine);

    % Register custom actions that Python clients can invoke
    bridge.registerAction('recalculate', @() recalcAll());
    bridge.registerAction('resetAlarms', @() fprintf('Alarms reset.\n'));

    bridge.serve();

    fprintf('\n');
    fprintf('=== WebBridge Example Running ===\n');
    fprintf('  API:   http://localhost:%d/docs\n', bridge.HttpPort);
    fprintf('  Signals: temperature, pressure, vibration\n');
    fprintf('  Actions: recalculate, resetAlarms, openInMatlab\n');
    fprintf('\n');
    fprintf('  Run the Python dashboard:\n');
    fprintf('    python examples/06-webbridge/example_webbridge_dashboard.py\n');
    fprintf('\n');
    fprintf('  Press Ctrl+C or close the figure to stop.\n');
    fprintf('\n');

    %% ========== Simulate Live Data ==========
    t = timer('ExecutionMode', 'fixedRate', 'Period', 0.5, ...
        'TimerFcn', @(~,~) addLiveData());
    start(t);

    % Clean up on figure close
    cleanupObj = onCleanup(@() cleanup(bridge, t));

    % Keep running until interrupted
    try
        while true
            drawnow;
            pause(0.5);
        end
    catch
        % Ctrl+C or error — cleanup runs automatically
    end

    function addLiveData()
        tNow = tSeed(end) + 0.5;
        tSeed(end+1) = tNow;

        sTemp.addData(tNow, 22 + 3*sin(2*pi*tNow/30) + randn*0.3);
        sPress.addData(tNow, 4.5 + 0.5*sin(2*pi*tNow/20) + randn*0.1);
        sVib.addData(tNow, 2.0 + 0.8*randn + 0.5*sin(2*pi*tNow/15));

        bridge.notifyDataChanged({'temperature', 'pressure', 'vibration'});
    end

    function recalcAll()
        bridge.notifyDataChanged({'temperature', 'pressure', 'vibration'});
        fprintf('All sensors recalculated.\n');
    end

    function cleanup(b, tmr)
        stop(tmr);
        delete(tmr);
        b.stop();
        fprintf('WebBridge stopped.\n');
    end
end
