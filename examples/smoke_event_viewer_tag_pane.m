function v = smoke_event_viewer_tag_pane()
%SMOKE_EVENT_VIEWER_TAG_PANE Open the event viewer with a populated registry and store.
%   Returns the viewer handle so the caller can inspect / close it.
%
%   Use to visually confirm: the left tag pane is present, search/pills
%   work, selecting tags filters the Gantt, and the slider drag works.
    install();

    nowRef = now;
    % Synthesize 5 days of sensor data at 5-minute resolution so the
    % drill-down dashboard's FastSense plot can overlay the event markers
    % on a meaningful signal. ~1440 samples per sensor.
    tStart = nowRef - 5.0;
    tEnd   = nowRef;
    tVec   = linspace(tStart, tEnd, 1440);
    rng(42, 'twister');   % deterministic noise so the smoke looks the same each run
    yPressureA    = 4 + 0.6*sin(2*pi*(tVec - tStart)/0.5) + 0.4*randn(size(tVec));
    yPressureB    = 5 + 0.8*cos(2*pi*(tVec - tStart)/1.0) + 0.5*randn(size(tVec));
    yTemperatureA = 22 + 3*sin(2*pi*(tVec - tStart)/2.5) + 0.7*randn(size(tVec));

    TagRegistry.clear();
    TagRegistry.register('pressure_a', SensorTag('pressure_a', ...
        'Name', 'Pressure A', 'Units', 'bar', ...
        'X', tVec, 'Y', yPressureA));
    TagRegistry.register('pressure_b', SensorTag('pressure_b', ...
        'Name', 'Pressure B', 'Units', 'bar', ...
        'X', tVec, 'Y', yPressureB));
    TagRegistry.register('temperature_a', SensorTag('temperature_a', ...
        'Name', 'Temperature A', 'Units', 'C', ...
        'X', tVec, 'Y', yTemperatureA));

    storePath = [tempname() '.mat'];
    es = EventStore(storePath);
    % 15 events across the 3 sensors over a 5-day window, with varied
    % severities, durations, overlap, and one open event at the end.
    rows = { ...
        % start                end                 sensor          label   value dir       sev  open
        { nowRef-5.0,          nowRef-4.95,        'pressure_a',   'high',  5.0, 'upper',  1,   false }, ...
        { nowRef-4.8,          nowRef-4.7,         'pressure_b',   'low',   2.0, 'lower',  1,   false }, ...
        { nowRef-4.5,          nowRef-4.0,         'temperature_a','high',  0.8, 'upper',  2,   false }, ...
        { nowRef-3.9,          nowRef-3.85,        'pressure_a',   'high',  5.5, 'upper',  3,   false }, ...
        { nowRef-3.7,          nowRef-3.6,         'temperature_a','low', -0.5, 'lower',  2,   false }, ...
        { nowRef-3.0,          nowRef-2.6,         'pressure_b',   'high',  6.0, 'upper',  3,   false }, ...
        { nowRef-2.7,          nowRef-2.65,        'pressure_a',   'low',   1.0, 'lower',  1,   false }, ...
        { nowRef-2.5,          nowRef-2.0,         'temperature_a','high',  0.9, 'upper',  3,   false }, ...
        { nowRef-2.1,          nowRef-2.05,        'pressure_b',   'low',   1.5, 'lower',  2,   false }, ...
        { nowRef-1.8,          nowRef-1.4,         'pressure_a',   'high',  5.2, 'upper',  2,   false }, ...
        { nowRef-1.2,          nowRef-1.15,        'temperature_a','low', -0.3, 'lower',  1,   false }, ...
        { nowRef-1.0,          nowRef-0.5,         'pressure_b',   'high',  6.5, 'upper',  3,   false }, ...
        { nowRef-0.8,          nowRef-0.78,        'pressure_a',   'low',   0.8, 'lower',  1,   false }, ...
        { nowRef-0.4,          nowRef-0.35,        'temperature_a','high',  1.0, 'upper',  2,   false }, ...
        { nowRef-0.1,          NaN,                'pressure_b',   'high',  7.0, 'upper',  3,   true  }};
    evs = Event.empty;
    for k = 1:numel(rows)
        r = rows{k};
        ev = Event(r{1}, r{2}, r{3}, r{4}, r{5}, r{6});
        ev.TagKeys = {r{3}};
        ev.Severity = r{7};
        ev.IsOpen   = r{8};
        evs(end+1) = ev; %#ok<AGROW>
    end
    es.append(evs);

    comp = FastSenseCompanion('EventStore', es);
    v    = CompanionEventViewer(es, TagRegistry, comp);
    % Viewer defaults to "All" on construction — no need to setTimeRange here.
    v.refresh();

    fprintf('Smoke: viewer opened with 15 events (one open). Tag pane shows 3 tags.\n');
    fprintf('  Try: search "pressure", toggle a kind pill, select a tag.\n');
    fprintf('  The slider preview shows event durations as translucent bands.\n');
    fprintf('  Toggle Gantt/Table at the top right.\n');
    fprintf('  Close the viewer; the companion''s "Events" button re-enables.\n');
    fprintf('  Close with: close(v.hFigure); comp.close();\n');
end
