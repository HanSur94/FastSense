function test_dashboard_engine_event_markers()
%TEST_DASHBOARD_ENGINE_EVENT_MARKERS Octave mirror of the class-based suite.
%   Integration tests for DashboardEngine.computeEventMarkers + the
%   4 hook-site wire-up (render, switchPage, updateGlobalTimeRange,
%   onLiveTick).

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), 'suite'));
    install();

    nPassed = 0;
    nPassed = nPassed + runCase(@() case_render(),                    'render');
    nPassed = nPassed + runCase(@() case_switch_page(),               'switch_page');
    nPassed = nPassed + runCase(@() case_update_global_time_range(),  'update_global');
    nPassed = nPassed + runCase(@() case_on_live_tick(),              'live_tick');
    nPassed = nPassed + runCase(@() case_dedup_and_sort(),            'dedup_sort');
    nPassed = nPassed + runCase(@() case_non_finite_filtered(),       'non_finite');
    nPassed = nPassed + runCase(@() case_empty_widgets_no_crash(),    'empty');
    nPassed = nPassed + runCase(@() case_throwing_widget_swallowed(), 'throwing');

    fprintf('    All %d tests passed.\n', nPassed);
end

function n = runCase(fn, name)
    try
        fn();
        n = 1;
    catch err
        fprintf('  CASE %s FAILED: %s\n', name, err.message);
        rethrow(err);
    end
end

function case_render()
    evts = struct('startTime', {10, 20, 30}, ...
                  'endTime',   {15, 25, 35}, ...
                  'label',     {'A', 'B', 'A'}, ...
                  'color',     {[1 0 0], [0 1 0], [0 0 1]});
    d = DashboardEngine('EvtMarkRender');
    d.addWidget(EventTimelineWidget('Title', 'T', 'Events', evts));
    d.render();
    cleanup = onCleanup(@() closeDashboard(d));
    x = markerXData(d.TimeRangeSelector_);
    assert(isequal(x, [10 20 30]), ...
        sprintf('expected [10 20 30], got %s', mat2str(x)));
end

function case_switch_page()
    e1 = struct('startTime', {5, 15}, 'endTime', {6, 16}, ...
                'label', {'A','B'}, 'color', {[1 0 0],[0 1 0]});
    e2 = struct('startTime', {100, 200, 300}, ...
                'endTime',   {110, 210, 310}, ...
                'label',     {'X','Y','Z'}, ...
                'color',     {[1 0 0],[0 1 0],[0 0 1]});
    d = DashboardEngine('EvtMarkSwitch');
    d.addPage('P1');
    d.addWidget(EventTimelineWidget('Title', 'T1', 'Events', e1));
    d.addPage('P2');
    d.switchPage(2);
    d.addWidget(EventTimelineWidget('Title', 'T2', 'Events', e2));
    d.switchPage(1);
    d.render();
    cleanup = onCleanup(@() closeDashboard(d));
    assert(isequal(markerXData(d.TimeRangeSelector_), [5 15]));
    d.switchPage(2);
    assert(isequal(markerXData(d.TimeRangeSelector_), [100 200 300]));
end

function case_update_global_time_range()
    evts = struct('startTime', {10, 20}, 'endTime', {11, 21}, ...
                  'label', {'A','B'}, 'color', {[1 0 0],[0 1 0]});
    d = DashboardEngine('EvtMarkUpdate');
    w = EventTimelineWidget('Title', 'T', 'Events', evts);
    d.addWidget(w);
    d.render();
    cleanup = onCleanup(@() closeDashboard(d));
    assert(isequal(markerXData(d.TimeRangeSelector_), [10 20]));
    w.Events = struct('startTime', {10, 20, 30}, ...
                      'endTime',   {11, 21, 31}, ...
                      'label',     {'A','B','C'}, ...
                      'color',     {[1 0 0],[0 1 0],[0 0 1]});
    d.updateGlobalTimeRange();
    assert(isequal(markerXData(d.TimeRangeSelector_), [10 20 30]));
end

function case_on_live_tick()
    evts = struct('startTime', {10, 20}, 'endTime', {11, 21}, ...
                  'label', {'A','B'}, 'color', {[1 0 0],[0 1 0]});
    d = DashboardEngine('EvtMarkTick');
    w = EventTimelineWidget('Title', 'T', 'Events', evts);
    d.addWidget(w);
    d.render();
    cleanup = onCleanup(@() closeDashboard(d));
    assert(isequal(markerXData(d.TimeRangeSelector_), [10 20]));
    w.Events = struct('startTime', {10, 20, 30}, ...
                      'endTime',   {11, 21, 31}, ...
                      'label',     {'A','B','C'}, ...
                      'color',     {[1 0 0],[0 1 0],[0 0 1]});
    d.onLiveTick();
    assert(isequal(markerXData(d.TimeRangeSelector_), [10 20 30]));
end

function case_dedup_and_sort()
    e1 = struct('startTime', {50, 10, 30}, ...
                'endTime',   {51, 11, 31}, ...
                'label',     {'A','B','C'}, ...
                'color',     {[1 0 0],[0 1 0],[0 0 1]});
    e2 = struct('startTime', {30, 20}, 'endTime', {31, 21}, ...
                'label', {'X','Y'}, 'color', {[1 0 0],[0 1 0]});
    d = DashboardEngine('EvtMarkDedup');
    d.addWidget(EventTimelineWidget('Title', 'T1', 'Events', e1));
    d.addWidget(EventTimelineWidget('Title', 'T2', 'Events', e2));
    d.render();
    cleanup = onCleanup(@() closeDashboard(d));
    x = markerXData(d.TimeRangeSelector_);
    assert(isequal(x, [10 20 30 50]), ...
        sprintf('expected [10 20 30 50], got %s', mat2str(x)));
end

function case_non_finite_filtered()
    evts = struct('startTime', {10, NaN, 20, Inf, 30}, ...
                  'endTime',   {11, 12, 21, 22, 31}, ...
                  'label',     {'A','B','C','D','E'}, ...
                  'color',     {[1 0 0],[0 1 0],[0 0 1],[1 1 0],[0 1 1]});
    d = DashboardEngine('EvtMarkNaN');
    d.addWidget(EventTimelineWidget('Title', 'T', 'Events', evts));
    d.render();
    cleanup = onCleanup(@() closeDashboard(d));
    assert(isequal(markerXData(d.TimeRangeSelector_), [10 20 30]));
end

function case_empty_widgets_no_crash()
    d = DashboardEngine('EvtMarkEmpty');
    d.addWidget('number', 'Title', 'N', 'ValueFcn', @() 1, ...
        'Position', [1 1 6 1]);
    d.render();
    cleanup = onCleanup(@() closeDashboard(d));
    assert(isempty(d.TimeRangeSelector_.hEventMarkers), ...
        'no event-bearing widgets -> no markers');
end

function case_throwing_widget_swallowed()
    evts = struct('startTime', {10, 20}, 'endTime', {11, 21}, ...
                  'label', {'A','B'}, 'color', {[1 0 0],[0 1 0]});
    d = DashboardEngine('EvtMarkThrow');
    bad = ThrowingEventWidget('Title', 'Bad', 'ValueFcn', @() 1, ...
        'Position', [1 1 6 1]);
    d.addWidget(bad);
    d.addWidget(EventTimelineWidget('Title', 'Good', 'Events', evts));
    ws = warning('off', 'DashboardEngine:getEventTimesFailed');
    wsCleanup = onCleanup(@() warning(ws));
    d.render();
    cleanup = onCleanup(@() closeDashboard(d));
    assert(isequal(markerXData(d.TimeRangeSelector_), [10 20]), ...
        'throwing widget must not block siblings');
end

function x = markerXData(sel)
    x = zeros(1, numel(sel.hEventMarkers));
    for k = 1:numel(sel.hEventMarkers)
        xd = get(sel.hEventMarkers(k), 'XData');
        x(k) = xd(1);
    end
    x = sort(x);
end

function closeDashboard(d)
    try
        if ~isempty(d) && ~isempty(d.hFigure) && ishandle(d.hFigure)
            close(d.hFigure);
        end
    catch
    end
end
