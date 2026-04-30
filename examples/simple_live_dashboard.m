function ctx = simple_live_dashboard()
%SIMPLE_LIVE_DASHBOARD Minimal one-FastSensePlot dashboard with live mode + events.
%
%   Shows the smallest possible DashboardEngine setup that exercises both
%   live refresh and threshold-driven event markers:
%     - one SensorTag fed by a writer timer (1 sample / second)
%     - one MonitorTag tripping when y > 5 (drives the EventStore)
%     - one FastSenseWidget on the dashboard with ShowEventMarkers=true
%     - engine.startLive() refreshes the plot every LiveInterval
%
%   Returns:
%     ctx — struct with fields:
%       engine       — DashboardEngine handle (rendered, live)
%       writerTimer  — MATLAB timer pushing synthetic samples
%       tag          — SensorTag streaming the signal
%       monitor      — MonitorTag tripping on y > 5
%       store        — EventStore receiving events
%
%   Teardown is wired to the figure's CloseRequestFcn — closing the
%   window stops the writer + live timer cleanly. Calling
%   simple_live_dashboard_teardown(ctx) does the same explicitly.
%
%   Example:
%     ctx = simple_live_dashboard();
%     pause(60);                                 % watch a few cycles
%     evts = ctx.store.getEventsForTag('demo.signal.high');
%
%   See also DashboardEngine, FastSenseWidget, MonitorTag, EventStore,
%            example_event_markers.

    install();

    % --- Domain objects --------------------------------------------------
    es = EventStore();
    tag = SensorTag('demo.signal', 'Name', 'Demo Signal', 'Units', 'units');
    mon = MonitorTag('demo.signal.high', tag, @(x, y) y > 5, ...
        'EventStore', es, 'MinDuration', 0);

    % --- Dashboard with a single FastSenseWidget -------------------------
    engine = DashboardEngine('Simple Live Dashboard', ...
        'Theme', 'light', 'LiveInterval', 1.0);
    engine.addWidget('fastsense', ...
        'Title',            'Demo Signal (threshold y > 5)', ...
        'Tag',              tag, ...
        'ShowEventMarkers', true, ...
        'EventStore',       es, ...
        'Position',         [1 1 24 8]);
    engine.render();
    engine.startLive();

    % --- Writer timer: one synthetic sample per second -------------------
    % Slow sine swinging 1..7, crossing the y=5 threshold roughly every
    % 15 s — gives the user a steady cadence of events to watch.
    t0 = posixtime(datetime('now'));
    writer = timer( ...
        'ExecutionMode', 'fixedRate', ...
        'Period',        1.0, ...
        'BusyMode',      'drop', ...
        'TimerFcn',      @(~,~) writeOne_(), ...
        'ErrorFcn',      @(~,~) []);
    start(writer);

    ctx = struct( ...
        'engine',      engine, ...
        'writerTimer', writer, ...
        'tag',         tag, ...
        'monitor',     mon, ...
        'store',       es);

    % --- Wire CloseRequestFcn so X-button cleans up ----------------------
    if ~isempty(engine.hFigure) && ishandle(engine.hFigure)
        set(engine.hFigure, 'CloseRequestFcn', @(s, ~) closeAll_(s));
    end

    % ===== nested helpers ==============================================

    function writeOne_()
        try
            elapsed = posixtime(datetime('now')) - t0;
            y = 4 + 3 * sin(elapsed * 2 * pi / 30);
            tag.updateData([tag.X, elapsed], [tag.Y, y]);
            mon.appendData(elapsed, y);
        catch
            % Writer ticks must never crash the timer.
        end
    end

    function closeAll_(fig)
        try
            if ~isempty(writer) && isvalid(writer)
                if strcmp(writer.Running, 'on'); stop(writer); end
                delete(writer);
            end
        catch
        end
        try
            if ~isempty(engine) && isvalid(engine) ...
                    && ismethod(engine, 'stopLive')
                engine.stopLive();
            end
        catch
        end
        try; delete(fig); catch; end
    end
end
