function test_time_range_selector_event_markers()
%TEST_TIME_RANGE_SELECTOR_EVENT_MARKERS Octave mirror of the class-based suite.
%   Exercises TimeRangeSelector.setEventMarkers and the getEventTimes
%   overrides on DashboardWidget / EventTimelineWidget / FastSenseWidget.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    hFig = figure('Visible', 'off');
    cleanup = onCleanup(@() safeClose(hFig));

    nPassed = 0;
    nPassed = nPassed + runCase(@() case_draws_lines(hFig),                'draws_lines');
    nPassed = nPassed + runCase(@() case_empty_clears(hFig),               'empty_clears');
    nPassed = nPassed + runCase(@() case_nan_filtered(hFig),               'nan_filtered');
    nPassed = nPassed + runCase(@() case_replaces_previous(hFig),          'replaces_previous');
    nPassed = nPassed + runCase(@() case_not_clickable(hFig),              'not_clickable');
    nPassed = nPassed + runCase(@() case_behind_selection(hFig),           'behind_selection');
    nPassed = nPassed + runCase(@() case_widget_base_empty(),              'base_empty');
    nPassed = nPassed + runCase(@() case_timeline_static(),                'timeline_static');
    nPassed = nPassed + runCase(@() case_timeline_filter(),                'timeline_filter');
    nPassed = nPassed + runCase(@() case_fastsense_no_store(hFig),         'fastsense_no_store');
    nPassed = nPassed + runCase(@() case_fastsense_never_throws(),         'fastsense_never_throws');
    nPassed = nPassed + runCase(@() case_fastsense_with_store(hFig),       'fastsense_with_store');

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

function sel = makeSelector(hFig)
    clf(hFig);
    hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
    sel = TimeRangeSelector(hp);
    sel.setDataRange(0, 100);
end

function case_draws_lines(hFig)
    sel = makeSelector(hFig);
    sel.setEventMarkers([10 25 60 90]);
    assert(numel(sel.hEventMarkers) == 4, ...
        sprintf('expected 4 markers, got %d', numel(sel.hEventMarkers)));
    xs = markerX(sel);
    assert(isequal(sort(xs), [10 25 60 90]), 'X positions mismatch');
    delete(sel);
end

function case_empty_clears(hFig)
    sel = makeSelector(hFig);
    sel.setEventMarkers([10 20 30]);
    assert(numel(sel.hEventMarkers) == 3);
    sel.setEventMarkers([]);
    assert(isempty(sel.hEventMarkers), 'empty input should clear markers');
    delete(sel);
end

function case_nan_filtered(hFig)
    sel = makeSelector(hFig);
    sel.setEventMarkers([10 NaN 20 Inf -Inf 30]);
    assert(numel(sel.hEventMarkers) == 3, ...
        sprintf('expected 3 (finite only), got %d', numel(sel.hEventMarkers)));
    xs = markerX(sel);
    assert(isequal(sort(xs), [10 20 30]));
    delete(sel);
end

function case_replaces_previous(hFig)
    sel = makeSelector(hFig);
    sel.setEventMarkers([10 20]);
    old = sel.hEventMarkers;
    sel.setEventMarkers([40 50 60]);
    assert(numel(sel.hEventMarkers) == 3);
    for k = 1:numel(old)
        assert(~ishandle(old(k)), 'old marker handle should be deleted');
    end
    xs = markerX(sel);
    assert(isequal(sort(xs), [40 50 60]));
    delete(sel);
end

function case_not_clickable(hFig)
    sel = makeSelector(hFig);
    sel.setEventMarkers(50);
    h = sel.hEventMarkers(1);
    assert(strcmp(get(h, 'HitTest'),       'off'));
    assert(strcmp(get(h, 'PickableParts'), 'none'));
    delete(sel);
end

function case_behind_selection(hFig)
    sel = makeSelector(hFig);
    sel.setEventMarkers(50);
    h = sel.hEventMarkers(1);
    ch = get(sel.hAxes, 'Children');
    idxSel = find(ch == sel.hSelection, 1);
    idxMk  = find(ch == h, 1);
    assert(~isempty(idxSel) && ~isempty(idxMk));
    % Lower index in Children = drawn on top in MATLAB/Octave axes order.
    assert(idxSel < idxMk, 'selection patch must render above event markers');
    delete(sel);
end

function case_widget_base_empty()
    w = NumberWidget('Title', 'Base', 'ValueFcn', @() 1);
    assert(isempty(w.getEventTimes()), 'base getEventTimes must be []');
end

function case_timeline_static()
    evts = struct('startTime', {10, 20, 30}, ...
                  'endTime',   {15, 25, 35}, ...
                  'label',     {'A', 'B', 'A'}, ...
                  'color',     {[1 0 0], [0 1 0], [0 0 1]});
    w = EventTimelineWidget('Title', 'Static', 'Events', evts);
    t = w.getEventTimes();
    assert(isequal(sort(t), [10 20 30]));
    assert(size(t, 1) == 1, 'must be a row vector');
end

function case_timeline_filter()
    evts = struct('startTime', {10, 20, 30}, ...
                  'endTime',   {15, 25, 35}, ...
                  'label',     {'Pump-101', 'Valve-202', 'Pump-101'}, ...
                  'color',     {[1 0 0], [0 1 0], [0 0 1]});
    w = EventTimelineWidget('Title', 'Filter', ...
        'Events', evts, 'FilterSensors', {'Pump-101'});
    t = w.getEventTimes();
    assert(isequal(sort(t), [10 30]));
end

function case_fastsense_no_store(hFig)
    clf(hFig);
    hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
    w = FastSenseWidget('Title', 'NoStore', ...
        'XData', 1:10, 'YData', rand(1, 10));
    w.render(hp);
    t = w.getEventTimes();
    assert(isempty(t), 'FastSenseWidget without EventStore must be []');
end

function case_fastsense_never_throws()
    w = FastSenseWidget('Title', 'Unrendered', ...
        'XData', 1:5, 'YData', 1:5);
    t = w.getEventTimes();
    assert(isempty(t));
end

function case_fastsense_with_store(hFig)
    % Live round-trip: bind a real EventStore to the rendered FastSense
    % and confirm getEventTimes() returns the StartTime values
    % (PascalCase path) and surfaces appends on the next call.
    clf(hFig);
    hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
    w = FastSenseWidget('Title', 'WithStore', ...
        'XData', 1:10, 'YData', rand(1, 10));
    w.render(hp);
    store = EventStore('');
    store.append(struct( ...
        'StartTime',      {10, 25, 40}, ...
        'EndTime',        {12, 27, 42}, ...
        'SensorName',     {'s1', 's1', 's2'}, ...
        'ThresholdLabel', {'high', 'high', 'low'}, ...
        'Severity',       {'warn', 'warn', 'crit'}));
    % Extract local handle: Octave forbids dot-chain assignment
    % through a SetAccess=private parent. Mutating through a local
    % handle still updates the same FastSense instance.
    fp = w.FastSenseObj;
    fp.EventStore = store;
    t = w.getEventTimes();
    assert(isequal(sort(t), [10 25 40]), ...
        'FastSenseWidget must read StartTime (PascalCase) from EventStore.getEvents');
    assert(size(t, 1) == 1, 'must be a row vector');
    % Live append surfaces in the next call.
    store.append(struct( ...
        'StartTime',      55, ...
        'EndTime',        57, ...
        'SensorName',     's1', ...
        'ThresholdLabel', 'high', ...
        'Severity',       'warn'));
    t2 = w.getEventTimes();
    assert(isequal(sort(t2), [10 25 40 55]), ...
        'live append must surface in the next getEventTimes call');
end

function xs = markerX(sel)
    xs = zeros(1, numel(sel.hEventMarkers));
    for k = 1:numel(sel.hEventMarkers)
        xd = get(sel.hEventMarkers(k), 'XData');
        xs(k) = xd(1);
    end
end

function safeClose(hFig)
    try
        if ishandle(hFig), close(hFig); end
    catch
    end
end
