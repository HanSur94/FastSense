function example_event_markers
    %EXAMPLE_EVENT_MARKERS Phase 1012 demo — live event markers + click-details on FastSenseWidget.
    %
    %   Two sensors share a single EventStore:
    %     1. pump_a_pressure (threshold y > 5) — one sustained violation
    %     2. motor_b_temperature (threshold y > 85) — multiple short spikes
    %
    %   Each sensor has its own MonitorTag emitting events. Both widgets
    %   have ShowEventMarkers=true so click-to-details works on any marker.
    %   Notes entered in the popup persist to tempdir/phase1012_demo_events.mat.
    %
    %   Usage:
    %     example_event_markers
    %
    %   See also FastSenseWidget, MonitorTag, EventStore.
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root); install();

    % --- Shared EventStore with disk persistence for notes ---
    storePath = fullfile(tempdir, 'phase1012_demo_events.mat');
    es = EventStore(storePath);
    if isfile(storePath)
        try
            prior = EventStore.loadFile(storePath);
            if ~isempty(prior); es.append(prior); end
        catch
            % ignore corrupt prior file
        end
    end

    % --- Sensor 1: pump_a_pressure — one sustained violation (open -> closed) ---
    pump = SensorTag('pump_a_pressure');
    pump.updateData([0 1 2 3 4 5], [1 1 1 1 1 1]);
    monPump = MonitorTag('pump_a_high', pump, @(x, y) y > 5, 'EventStore', es);

    % --- Sensor 2: motor_b_temperature — multiple short spikes over threshold 85 ---
    motor = SensorTag('motor_b_temperature');
    motor.updateData(0:5, [72 71 73 70 72 71]);   % cool baseline
    monMotor = MonitorTag('motor_b_overheat', motor, @(x, y) y > 85, 'EventStore', es);

    % --- Dashboard with two FastSense widgets sharing the EventStore ---
    d = DashboardEngine('Phase 1012 demo');
    d.addWidget('fastsense', 'Title', 'Pump A Pressure', ...
        'Tag', pump, 'Position', [1 1 12 4], ...
        'ShowEventMarkers', true, 'EventStore', es);
    d.addWidget('fastsense', 'Title', 'Motor B Temperature', ...
        'Tag', motor, 'Position', [1 5 12 4], ...
        'ShowEventMarkers', true, 'EventStore', es);
    d.render();

    % --- Overlay threshold reference lines on both widgets ---
    drawThreshold(d.Widgets{1}, 5,  'y > 5 (pump_a_high)');
    drawThreshold(d.Widgets{2}, 85, 'y > 85 (motor_b_overheat)');

    % ===== Live ticks =====

    fprintf('Tick 1 — pump rising edge (open event); motor first spike...\n');
    pause(1);
    pumpAppend(pump, monPump, [6 7 8 9], [1 10 10 10]);           % pump open at t=7
    motorAppend(motor, monMotor, [6 7 8 9], [73 92 75 72]);       % spike at t=7 (90 > 85)
    d.onLiveTick(); tickAll(d); drawnow;

    fprintf('Tick 2 — pump falling edge (event closes); motor second spike...\n');
    pause(2);
    pumpAppend(pump, monPump, [10 11 12 13], [10 10 1 1]);         % pump closes at t=12
    motorAppend(motor, monMotor, [10 11 12 13], [74 95 78 70]);    % spike at t=11 (95 > 85)
    d.onLiveTick(); tickAll(d); drawnow;

    fprintf('Tick 3 — motor third spike (pump quiet)...\n');
    pause(1.5);
    pumpAppend(pump, monPump, [14 15 16 17], [1 1 1 1]);
    motorAppend(motor, monMotor, [14 15 16 17], [72 88 91 73]);    % double spike at t=15,16
    d.onLiveTick(); tickAll(d); drawnow;

    % Assign severity per event based on how far the peak exceeded the
    % threshold. Peak is read from the parent SensorTag directly (doesn't
    % rely on ev.PeakValue being populated by the MonitorTag stats path).
    assignSeverityByPeak(es, 'pump_a_high',      pump,  5);
    assignSeverityByPeak(es, 'motor_b_overheat', motor, 85);
    d.onLiveTick(); tickAll(d); drawnow;

    fprintf('Done. Click any marker to open the details popup.\n');
    fprintf('  Pump should have 1 marker (filled) at t=7.\n');
    fprintf('  Motor should have 3 markers (filled) — spikes at t=7, 11, 15.\n');
    fprintf('Edit the Notes and click Save — the text persists to %s.\n', storePath);
end

% -------------------- helpers --------------------

function pumpAppend(tag, mon, newX, newY)
    tag.updateData([tag.X, newX], [tag.Y, newY]);
    mon.appendData(newX, newY);
end

function motorAppend(tag, mon, newX, newY)
    tag.updateData([tag.X, newX], [tag.Y, newY]);
    mon.appendData(newX, newY);
end

function drawThreshold(widget, value, label)
    %DRAWTHRESHOLD Draw a dashed horizontal reference line on a widget's axes.
    if isempty(widget.FastSenseObj) || isempty(widget.FastSenseObj.hAxes); return; end
    ax = widget.FastSenseObj.hAxes;
    xr = get(ax, 'XLim');
    hold(ax, 'on');
    line(ax, xr, [value value], 'LineStyle', '--', 'Color', [0.95 0.40 0.25], ...
         'LineWidth', 1.2, 'HandleVisibility', 'off', 'Tag', 'demoThreshold', ...
         'UserData', value);
    text(ax, xr(2), value, ['  ' label], ...
         'Color', [0.95 0.40 0.25], 'VerticalAlignment', 'bottom', ...
         'HorizontalAlignment', 'right', 'Tag', 'demoThresholdLabel', ...
         'UserData', value);
    hold(ax, 'off');
end

function assignSeverityByPeak(es, tagKey, sensorTag, threshold)
    %ASSIGNSEVERITYBYPEAK Map peak-over-threshold ratio to Severity 1/2/3.
    %   Computes the peak by reading the SensorTag's Y data directly in
    %   the window [StartTime, EndTime] — independent of ev.PeakValue
    %   (which the MonitorTag running-stats pipeline may or may not have
    %   populated by the time we call this).
    %
    %   ratio = peak / threshold
    %     >= 1.5   -> 3 (alarm,  red)
    %     >= 1.1   -> 2 (warn,   orange)
    %     else     -> 1 (info,   green)
    events = es.getEventsForTag(tagKey);
    if threshold == 0 || isempty(sensorTag); return; end
    xs = sensorTag.X;
    ys = sensorTag.Y;
    for k = 1:numel(events)
        ev = events(k);
        % Window: StartTime -> EndTime (or to end of data if still open)
        t0 = ev.StartTime;
        t1 = ev.EndTime;
        if isnan(t1) || isempty(t1); t1 = xs(end); end
        mask = xs >= t0 & xs <= t1;
        if ~any(mask); continue; end
        peak = max(ys(mask));
        % Persist back to the event so the details popup shows it
        if isempty(ev.PeakValue); ev.setStats(peak, nnz(mask), [], [], [], [], []); end
        ratio = peak / threshold;
        if ratio >= 1.5
            ev.Severity = 3;
        elseif ratio >= 1.1
            ev.Severity = 2;
        else
            ev.Severity = 1;
        end
    end
end

function tickAll(d)
    %TICKALL Autoscale Y + stretch threshold reference lines on every FS widget.
    for i = 1:numel(d.Widgets)
        w = d.Widgets{i};
        if ~isa(w, 'FastSenseWidget') || isempty(w.FastSenseObj) || ...
                isempty(w.FastSenseObj.hAxes) || ~ishandle(w.FastSenseObj.hAxes)
            continue;
        end
        ax = w.FastSenseObj.hAxes;
        ylim(ax, 'auto');
        xr = get(ax, 'XLim');
        thrs = findobj(ax, 'Tag', 'demoThreshold');
        for k = 1:numel(thrs)
            v = get(thrs(k), 'UserData');
            set(thrs(k), 'XData', xr, 'YData', [v v]);
        end
        lbls = findobj(ax, 'Tag', 'demoThresholdLabel');
        for k = 1:numel(lbls)
            v = get(lbls(k), 'UserData');
            set(lbls(k), 'Position', [xr(2), v, 0]);
        end
    end
end
