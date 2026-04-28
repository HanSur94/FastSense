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
