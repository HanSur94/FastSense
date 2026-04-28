function test_dashboard_events_toggle()
%TEST_DASHBOARD_EVENTS_TOGGLE Coverage for the global Events toolbar
%   toggle (quick 260424-jf5). Exercises:
%     * DashboardEngine.EventMarkersVisible default + setter
%     * DashboardToolbar Events button + setEventsActiveIndicator
%     * FastSense.setShowEventMarkers clears/repopulates EventMarkerHandles_
%     * FastSenseWidget.setEventMarkersVisible pass-through + pre-render no-op
%     * EventTimelineWidget is exempt (no setEventMarkersVisible method)

    add_events_toggle_path();

    % Headless guard: MATLAB needs JVM to render figures; Octave is fine.
    if ~exist('OCTAVE_VERSION', 'builtin') && ~usejava('jvm')
        fprintf('    SKIP: no display available\n');
        return;
    end

    nPassed = 0;
    nFailed = 0;

    % --- Test 1: EventMarkersVisible defaults to true on DashboardEngine ---
    try
        d = DashboardEngine('ToggleDefaultTest');
        assert(isprop(d, 'EventMarkersVisible'), ...
            'DashboardEngine should expose EventMarkersVisible property');
        assert(d.EventMarkersVisible == true, ...
            'EventMarkersVisible should default true (backward compat)');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test1_defaultTrue: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 2: setEventMarkersVisible flips the engine flag ---
    try
        d = DashboardEngine('ToggleFlagFlipTest');
        d.setEventMarkersVisible(false);
        assert(d.EventMarkersVisible == false, ...
            'setEventMarkersVisible(false) should clear the flag');
        d.setEventMarkersVisible(true);
        assert(d.EventMarkersVisible == true, ...
            'setEventMarkersVisible(true) should restore the flag');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test2_flagFlip: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 3: Toolbar exposes Events button with tooltip ---
    try
        d = DashboardEngine('EventsBtnExistsTest');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        assert(~isempty(d.Toolbar.hEventsBtn) && ishandle(d.Toolbar.hEventsBtn), ...
            'Events button handle should be valid after render');
        assert(~isempty(d.Toolbar.hEventsPanel) && ishandle(d.Toolbar.hEventsPanel), ...
            'Events panel handle should be valid after render');
        tip = get(d.Toolbar.hEventsBtn, 'TooltipString');
        assert(~isempty(tip), 'Events button must have a tooltip');

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test3_buttonExists: %s\n', err.message);
        nFailed = nFailed + 1;
        try close(d.hFigure); catch; end
    end

    % --- Test 4: setEventsActiveIndicator swaps panel HighlightColor ---
    try
        d = DashboardEngine('EventsBorderTest');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        themeStruct = d.getCachedTheme();

        d.Toolbar.setEventsActiveIndicator(true);
        onColor = get(d.Toolbar.hEventsPanel, 'HighlightColor');
        assert(max(abs(onColor - themeStruct.InfoColor)) < 1e-6, ...
            'events border should be InfoColor when active');

        d.Toolbar.setEventsActiveIndicator(false);
        offColor = get(d.Toolbar.hEventsPanel, 'HighlightColor');
        assert(max(abs(offColor - themeStruct.ToolbarBackground)) < 1e-6, ...
            'events border should match toolbar bg when inactive');

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test4_indicator: %s\n', err.message);
        nFailed = nFailed + 1;
        try close(d.hFigure); catch; end
    end

    % --- Test 5: FastSense.setShowEventMarkers clears handles when false ---
    try
        EventBinding.clear();
        f = figure('Visible', 'off');
        ax = axes('Parent', f);
        es = EventStore('');
        tag = SensorTag('toggle_t5', 'X', 1:100, 'Y', sin((1:100)/10)*30 + 40);
        tag.EventStore = es;
        tag.addManualEvent(20, 25, 'ev_a', '');
        tag.addManualEvent(60, 65, 'ev_b', '');

        fp = FastSense('Parent', ax);
        fp.EventStore = es;
        fp.addTag(tag);
        fp.render();

        % Toggle OFF: handles should be deleted, flag false
        fp.setShowEventMarkers(false);
        assert(fp.ShowEventMarkers == false, ...
            'ShowEventMarkers should be false after toggle');
        % Count remaining 'o'-marker lines in axes
        nRound = count_round_markers(ax);
        assert(nRound == 0, ...
            sprintf('expected 0 round markers after toggle off, got %d', nRound));

        % Toggle ON: markers repopulate
        fp.setShowEventMarkers(true);
        assert(fp.ShowEventMarkers == true, ...
            'ShowEventMarkers should be true after re-toggle');
        nRound = count_round_markers(ax);
        assert(nRound >= 1, ...
            sprintf('expected at least 1 round marker after toggle on, got %d', nRound));

        close(f);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test5_fastsenseToggle: %s\n', err.message);
        nFailed = nFailed + 1;
        try close(f); catch; end
    end

    % --- Test 6: FastSenseWidget.setEventMarkersVisible safe pre-render ---
    try
        w = FastSenseWidget('Title', 'PreRender', 'Position', [1 1 6 2]);
        % Pre-render there is no FastSenseObj; must not error.
        w.setEventMarkersVisible(false);
        w.setEventMarkersVisible(true);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test6_widgetPreRenderNoOp: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 7: EventTimelineWidget is exempt (no setEventMarkersVisible) ---
    try
        tw = EventTimelineWidget('Title', 'Tml', 'Position', [1 1 6 2]);
        assert(~ismethod(tw, 'setEventMarkersVisible'), ...
            ['EventTimelineWidget must NOT implement setEventMarkersVisible ' ...
             '(its sole purpose is displaying events; the engine fan-out ' ...
             'uses ismethod() to skip it)']);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test7_timelineExempt: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 8: Engine fan-out keeps toolbar indicator in sync ---
    try
        d = DashboardEngine('FanoutIndicatorTest');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        themeStruct = d.getCachedTheme();

        d.setEventMarkersVisible(false);
        borderOff = get(d.Toolbar.hEventsPanel, 'HighlightColor');
        assert(max(abs(borderOff - themeStruct.ToolbarBackground)) < 1e-6, ...
            'engine toggle off should clear the toolbar border');
        assert(d.EventMarkersVisible == false, ...
            'engine flag should be false after toggle');

        d.setEventMarkersVisible(true);
        borderOn = get(d.Toolbar.hEventsPanel, 'HighlightColor');
        assert(max(abs(borderOn - themeStruct.InfoColor)) < 1e-6, ...
            'engine toggle on should light the toolbar border');

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test8_fanoutIndicator: %s\n', err.message);
        nFailed = nFailed + 1;
        try close(d.hFigure); catch; end
    end

    % --- Test 9: TagRegistry.setEventStore / getEventStore round-trip ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        tempPath = [tempname(), '.mat'];
        s = EventStore(tempPath);
        TagRegistry.setEventStore(s);
        got = TagRegistry.getEventStore();
        assert(isequal(got, s), 'getEventStore should return the store just set');
        if exist(tempPath, 'file'); delete(tempPath); end
        nPassed = nPassed + 1;
        fprintf('    PASS testTagRegistryEventStoreRoundTrip\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testTagRegistryEventStoreRoundTrip: %s\n', err.message);
    end

    % --- Test 10: getEventStore returns [] before any set (empty default) ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        assert(isempty(TagRegistry.getEventStore()), ...
            'getEventStore should return [] before any setEventStore call');
        nPassed = nPassed + 1;
        fprintf('    PASS testTagRegistryEventStoreEmptyDefault\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testTagRegistryEventStoreEmptyDefault: %s\n', err.message);
    end

    % --- Test 11: setEventStore second call overwrites first ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        p1 = [tempname(), '.mat']; p2 = [tempname(), '.mat'];
        s1 = EventStore(p1); s2 = EventStore(p2);
        TagRegistry.setEventStore(s1);
        TagRegistry.setEventStore(s2);
        assert(isequal(TagRegistry.getEventStore(), s2), ...
            'getEventStore should return s2 after overwrite');
        if exist(p1, 'file'); delete(p1); end
        if exist(p2, 'file'); delete(p2); end
        nPassed = nPassed + 1;
        fprintf('    PASS testTagRegistryEventStoreOverwrite\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testTagRegistryEventStoreOverwrite: %s\n', err.message);
    end

    % --- Test 12: TagRegistry.clear() resets EventStore slot ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        tempPath = [tempname(), '.mat'];
        TagRegistry.setEventStore(EventStore(tempPath));
        TagRegistry.clear();
        assert(isempty(TagRegistry.getEventStore()), ...
            'getEventStore should return [] after clear()');
        if exist(tempPath, 'file'); delete(tempPath); end
        nPassed = nPassed + 1;
        fprintf('    PASS testTagRegistryClearResetsEventStore\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testTagRegistryClearResetsEventStore: %s\n', err.message);
    end

    % --- Test 13: setEventStore([]) clears slot explicitly ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        tempPath = [tempname(), '.mat'];
        TagRegistry.setEventStore(EventStore(tempPath));
        TagRegistry.setEventStore([]);
        assert(isempty(TagRegistry.getEventStore()), ...
            'getEventStore should return [] after setEventStore([])');
        if exist(tempPath, 'file'); delete(tempPath); end
        nPassed = nPassed + 1;
        fprintf('    PASS testTagRegistryEventStoreSetEmptyClears\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testTagRegistryEventStoreSetEmptyClears: %s\n', err.message);
    end

    % --- Test 14: MonitorTag constructor falls back to registry default ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        tempPath = [tempname(), '.mat'];
        es = EventStore(tempPath);
        TagRegistry.setEventStore(es);
        parent = SensorTag('p');
        parent.updateData([1 2 3], [1 1 1]);
        m = MonitorTag('p.high', parent, @(x, y) y > 5);
        assert(isequal(m.EventStore, es), 'EventStore should equal registry default');
        if exist(tempPath, 'file'); delete(tempPath); end
        nPassed = nPassed + 1;
        fprintf('    PASS testMonitorTagRegistryDefaultFallback\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testMonitorTagRegistryDefaultFallback: %s\n', err.message);
    end

    % --- Test 15: explicit 'EventStore' NV-pair wins over registry default ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        p1 = [tempname(), '.mat']; p2 = [tempname(), '.mat'];
        esRegistry = EventStore(p1);
        esExplicit = EventStore(p2);
        TagRegistry.setEventStore(esRegistry);
        parent = SensorTag('p');
        parent.updateData([1 2 3], [1 1 1]);
        m = MonitorTag('p.high', parent, @(x, y) y > 5, 'EventStore', esExplicit);
        assert(isequal(m.EventStore, esExplicit), 'explicit EventStore should win over registry');
        assert(~isequal(m.EventStore, esRegistry), 'registry default should NOT override explicit');
        if exist(p1, 'file'); delete(p1); end
        if exist(p2, 'file'); delete(p2); end
        nPassed = nPassed + 1;
        fprintf('    PASS testMonitorTagExplicitOverridesRegistry\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testMonitorTagExplicitOverridesRegistry: %s\n', err.message);
    end

    % --- Test 16: dual-key emission — events reachable by parent.Key AND monitor.Key ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        tempPath = [tempname(), '.mat'];
        es = EventStore(tempPath);
        TagRegistry.setEventStore(es);
        parent = SensorTag('reactor.pressure');
        parent.updateData([1 2 3], [1 1 1]);
        m = MonitorTag('reactor.pressure.critical', parent, @(x, y) y > 18);
        parent.updateData([1 2 3 4 5 6], [1 1 1 20 20 1]);
        m.appendData([4 5 6], [20 20 1]);
        byParent = es.getEventsForTag('reactor.pressure');
        byMonitor = es.getEventsForTag('reactor.pressure.critical');
        assert(~isempty(byParent), 'parent.Key lookup returned empty');
        assert(~isempty(byMonitor), 'monitor.Key lookup returned empty');
        if exist(tempPath, 'file'); delete(tempPath); end
        nPassed = nPassed + 1;
        fprintf('    PASS testMonitorTagDualKeyEmission\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testMonitorTagDualKeyEmission: %s\n', err.message);
    end

    % --- Test 17: FastSense registry-default fallback renders without error ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        tempPath = [tempname(), '.mat'];
        es = EventStore(tempPath);
        TagRegistry.setEventStore(es);
        s = SensorTag('s');
        s.updateData([1 2 3 4 5], [1 1 20 20 1]);
        m = MonitorTag('s.high', s, @(x, y) y > 5);
        m.appendData([1 2 3 4 5], [1 1 20 20 1]);
        byParent = es.getEventsForTag('s');
        assert(~isempty(byParent), 'parent key lookup returned empty');
        fig = figure('visible', 'off');
        ax = axes('Parent', fig);
        fp = FastSense('Parent', ax);
        fp.addTag(s);
        fp.ShowEventMarkers = true;
        fp.render();  % must not error; registry tail provides the store
        close(fig);
        if exist(tempPath, 'file'); delete(tempPath); end
        nPassed = nPassed + 1;
        fprintf('    PASS testRegistryDefaultFastSense\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testRegistryDefaultFastSense: %s\n', err.message);
        try close(fig); catch; end
    end

    % --- Test 18: FastSenseWidget forwards registry-default store to inner FastSense ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        tempPath = [tempname(), '.mat'];
        es = EventStore(tempPath);
        TagRegistry.setEventStore(es);
        s = SensorTag('s');
        s.updateData([1 2 3], [1 1 1]);
        d = DashboardEngine('test');
        d.addWidget('fastsense', 'Tag', s, 'ShowEventMarkers', true);
        d.render();
        w = d.Widgets{1};
        assert(isequal(w.FastSenseObj.EventStore, es), 'registry default not forwarded');
        if isfield(d, 'hFigure') && ~isempty(d.hFigure) && ishandle(d.hFigure); close(d.hFigure); end
        if exist(tempPath, 'file'); delete(tempPath); end
        nPassed = nPassed + 1;
        fprintf('    PASS testRegistryDefaultFastSenseWidget\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testRegistryDefaultFastSenseWidget: %s\n', err.message);
        try if isfield(d, 'hFigure') && ~isempty(d.hFigure) && ishandle(d.hFigure); close(d.hFigure); end; catch; end
    end

    % --- Test 19: explicit EventStore NV-pair wins over registry default ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        p1 = [tempname(), '.mat']; p2 = [tempname(), '.mat'];
        esRegistry = EventStore(p1);
        esExplicit = EventStore(p2);
        TagRegistry.setEventStore(esRegistry);
        s = SensorTag('s');
        s.updateData([1 2 3], [1 1 1]);
        d = DashboardEngine('test');
        d.addWidget('fastsense', 'Tag', s, 'ShowEventMarkers', true, ...
            'EventStore', esExplicit);
        d.render();
        w = d.Widgets{1};
        assert(isequal(w.FastSenseObj.EventStore, esExplicit), 'explicit EventStore should win over registry');
        assert(~isequal(w.FastSenseObj.EventStore, esRegistry), 'registry default should NOT override explicit');
        if isfield(d, 'hFigure') && ~isempty(d.hFigure) && ishandle(d.hFigure); close(d.hFigure); end
        if exist(p1, 'file'); delete(p1); end
        if exist(p2, 'file'); delete(p2); end
        nPassed = nPassed + 1;
        fprintf('    PASS testFastSenseWidgetExplicitWinsOverRegistry\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testFastSenseWidgetExplicitWinsOverRegistry: %s\n', err.message);
        try if isfield(d, 'hFigure') && ~isempty(d.hFigure) && ishandle(d.hFigure); close(d.hFigure); end; catch; end
    end

    % --- Test 20: EventTimelineWidget falls back to registry default ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        tempPath = [tempname(), '.mat'];
        es = EventStore(tempPath);
        s = SensorTag('s');
        s.updateData([1 2 3 4 5], [1 1 20 20 1]);
        m = MonitorTag('s.high', s, @(x, y) y > 5, 'EventStore', es);
        m.appendData([1 2 3 4 5], [1 1 20 20 1]);
        TagRegistry.setEventStore(es);
        w = EventTimelineWidget('Title', 'Timeline');
        evts = w.resolveEvents();
        assert(~isempty(evts), 'registry default events not returned');
        if exist(tempPath, 'file'); delete(tempPath); end
        nPassed = nPassed + 1;
        fprintf('    PASS testRegistryDefaultEventTimeline\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testRegistryDefaultEventTimeline: %s\n', err.message);
    end

    % --- Test 21: TableWidget(events) falls back to registry default ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        tempPath = [tempname(), '.mat'];
        es = EventStore(tempPath);
        s = SensorTag('s', 'Name', 's');
        s.updateData([1 2 3 4 5], [1 1 20 20 1]);
        m = MonitorTag('s.high', s, @(x, y) y > 5, 'EventStore', es);
        m.appendData([1 2 3 4 5], [1 1 20 20 1]);
        TagRegistry.setEventStore(es);
        % Construct widget with Mode='events'; EventStoreObj NOT set.
        % Verify refresh does not throw (registry fallback reached).
        fig = figure('visible', 'off');
        w = TableWidget('Title', 'Table', 'Mode', 'events', 'Sensor', s);
        w.render(uipanel(fig));
        w.refresh();
        close(fig);
        if exist(tempPath, 'file'); delete(tempPath); end
        nPassed = nPassed + 1;
        fprintf('    PASS testRegistryDefaultTableWidget\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testRegistryDefaultTableWidget: %s\n', err.message);
        try close(fig); catch; end
    end

    % --- Test 22: explicit EventStoreObj wins over registry default ---
    try
        TagRegistry.clear();
        EventBinding.clear();
        p1 = [tempname(), '.mat']; p2 = [tempname(), '.mat'];
        esRegistry = EventStore(p1);
        esExplicit = EventStore(p2);
        sR = SensorTag('reg.s'); sR.updateData([1 2 3 4 5], [1 1 20 20 1]);
        mR = MonitorTag('reg.s.high', sR, @(x, y) y > 5, 'EventStore', esRegistry);
        mR.appendData([1 2 3 4 5], [1 1 20 20 1]);
        sE = SensorTag('exp.s'); sE.updateData([1 2 3 4 5], [1 1 30 30 1]);
        mE = MonitorTag('exp.s.high', sE, @(x, y) y > 5, 'EventStore', esExplicit);
        mE.appendData([1 2 3 4 5], [1 1 30 30 1]);
        TagRegistry.setEventStore(esRegistry);
        w = EventTimelineWidget('Title', 'Timeline', 'EventStoreObj', esExplicit);
        evts = w.resolveEvents();
        assert(~isempty(evts), 'resolveEvents returned empty with explicit store');
        sNames = arrayfun(@(e) e.label, evts, 'UniformOutput', false);
        hasExplicitMarker = any(cellfun(@(n) ~isempty(strfind(n, 'exp.s')), sNames));
        assert(hasExplicitMarker, 'explicit store events not returned (registry default used instead)');
        if exist(p1, 'file'); delete(p1); end
        if exist(p2, 'file'); delete(p2); end
        nPassed = nPassed + 1;
        fprintf('    PASS testEventTimelineExplicitWinsOverRegistry\n');
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL testEventTimelineExplicitWinsOverRegistry: %s\n', err.message);
    end

    fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
    if nFailed > 0
        error('test_dashboard_events_toggle:fail', ...
            '%d of %d tests failed', nFailed, nPassed + nFailed);
    end
end

function n = count_round_markers(ax)
    % Count line children whose Marker is 'o' (event-layer markers).
    children = allchild(ax);
    n = 0;
    for i = 1:numel(children)
        try
            mk = get(children(i), 'Marker');
            ls = get(children(i), 'LineStyle');
            if strcmp(mk, 'o') && strcmp(ls, 'none')
                n = n + 1;
            end
        catch
            % Non-line children (text, patches, etc.) — ignore.
        end
    end
end

function add_events_toggle_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fullfile(thisDir, '..');
    addpath(repoRoot);
    install();
end
