function test_dashboard_time_sync_all_pages()
%TEST_DASHBOARD_TIME_SYNC_ALL_PAGES Regression for cross-page time
%   broadcast (260508-llw). broadcastTimeRange and resetGlobalTime
%   must apply to widgets on every page, not just the active one.
%   Newly-realized widgets on tab-switch must inherit the current
%   synced range. Manually-zoomed widgets (UseGlobalTime=false)
%   remain detached.
%
%   Five sub-tests:
%     1. case_active_and_inactive_pages_receive_broadcast (LLW-01)
%     2. case_reset_global_time_reattaches_all_pages       (LLW-02)
%     3. case_unrealized_widget_on_tab_switch_inherits_synced_range (LLW-03)
%     4. case_manual_zoom_widget_opts_out_of_broadcast      (per-widget contract)
%     5. case_single_page_dashboard_unaffected              (allPageWidgets fallthrough)
    if exist('OCTAVE_VERSION', 'builtin')
        % Octave's __axis_limits__ wraps xlim() in a `addlistener(..., 'PostSet', ...)`
        % path that requires the MATLAB Property Event system; on Octave it
        % errors with `'PostSet' undefined`. The broadcastTimeRange code path
        % under test ends in xlim(), so this entire suite is unreachable on
        % Octave through no fault of the implementation. Verified manually
        % via MATLAB; same coverage exists in suite/TestDashboardTimeSync.
        fprintf('  SKIPPED on Octave (xlim() PostSet listener not supported by __axis_limits__).\n');
        return;
    end
    add_paths_();

    nPassed = 0;
    nFailed = 0;
    tests = { ...
        @case_active_and_inactive_pages_receive_broadcast, ...
        @case_reset_global_time_reattaches_all_pages, ...
        @case_unrealized_widget_on_tab_switch_inherits_synced_range, ...
        @case_manual_zoom_widget_opts_out_of_broadcast, ...
        @case_single_page_dashboard_unaffected};
    for i = 1:numel(tests)
        try
            tests{i}();
            nPassed = nPassed + 1;
        catch err
            nFailed = nFailed + 1;
            fprintf('  FAIL: %s\n    %s\n', func2str(tests{i}), err.message);
        end
    end
    try close(findall(0, 'Type', 'figure')); catch, end
    fprintf('    %d/%d tests passed.\n', nPassed, nPassed + nFailed);
    if nFailed > 0
        error('test_dashboard_time_sync_all_pages:failed', '%d test(s) failed', nFailed);
    end
end

% -------------------------------------------------------------------------

function add_paths_()
    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(thisDir);
    addpath(rootDir);
    run(fullfile(rootDir, 'install.m'));
end

function d = build_two_page_dashboard_(name)
    %BUILD_TWO_PAGE_DASHBOARD_ Construct a 2-page dashboard with one
    %   FastSenseWidget per page. After this returns:
    %     - Page 1 active. Page-1 widget is realized.
    %     - Page-2 widget is unrealized (lazy realization on switchPage).
    %   Disjoint sensor X ranges per page so we can detect "default xlim"
    %   easily: page-1 widget defaults near [0 100], page-2 near [20 120].
    x1 = linspace(0,  100, 500);
    y1 = sin(x1 * 0.1);
    x2 = linspace(20, 120, 500);
    y2 = cos(x2 * 0.1);

    d = DashboardEngine(name);
    d.addPage('P1');
    d.switchPage(1);
    d.addWidget('fastsense', 'Title', 'wP1', 'XData', x1, 'YData', y1);
    d.addPage('P2');
    d.switchPage(2);
    d.addWidget('fastsense', 'Title', 'wP2', 'XData', x2, 'YData', y2);
    d.switchPage(1);
    evalc('d.render();');
    try set(d.hFigure, 'Visible', 'off'); catch, end
    drawnow;
end

function case_active_and_inactive_pages_receive_broadcast()
    %CASE_ACTIVE_AND_INACTIVE_PAGES_RECEIVE_BROADCAST LLW-01.
    %   After broadcastTimeRangeNow on page 1, switching to page 2
    %   reveals its widget at the SAME synced xlim — not its sensor
    %   default. Pre-realize page 2 so we exercise the cross-page
    %   broadcast path (separate from LLW-03's lazy-realize re-broadcast).
    d = build_two_page_dashboard_('llw-broadcast-active-inactive');
    cleanup = onCleanup(@() safe_close_(d));  %#ok<NASGU>

    % Pre-realize page 2 so its FastSenseObj.hAxes exists for the assertion.
    d.switchPage(2);
    drawnow;
    d.switchPage(1);
    drawnow;

    d.broadcastTimeRangeNow(30, 70);

    ax1 = d.Pages{1}.Widgets{1}.FastSenseObj.hAxes;
    assert_xlim_(ax1, [30 70], 'page 1 (active) broadcast');

    ax2 = d.Pages{2}.Widgets{1}.FastSenseObj.hAxes;
    assert_xlim_(ax2, [30 70], 'page 2 (inactive) broadcast');

    % Cache assertion: LastSyncedTimeRange_ must be populated.
    assert(isequal(d.LastSyncedTimeRange_, [30 70]), ...
        sprintf('LastSyncedTimeRange_ mismatch: got %s, expected [30 70]', ...
                mat2str(d.LastSyncedTimeRange_)));
end

function case_reset_global_time_reattaches_all_pages()
    %CASE_RESET_GLOBAL_TIME_REATTACHES_ALL_PAGES LLW-02.
    %   Set UseGlobalTime=false on widgets across both pages, then call
    %   resetGlobalTime() — both must flip back to true.
    d = build_two_page_dashboard_('llw-reset-all-pages');
    cleanup = onCleanup(@() safe_close_(d));  %#ok<NASGU>

    % Pre-realize page 2.
    d.switchPage(2);
    drawnow;
    d.switchPage(1);
    drawnow;

    d.Pages{1}.Widgets{1}.UseGlobalTime = false;
    d.Pages{2}.Widgets{1}.UseGlobalTime = false;

    d.resetGlobalTime();

    assert(d.Pages{1}.Widgets{1}.UseGlobalTime == true, ...
        'page 1 widget UseGlobalTime not restored to true after resetGlobalTime');
    assert(d.Pages{2}.Widgets{1}.UseGlobalTime == true, ...
        'page 2 widget UseGlobalTime not restored to true after resetGlobalTime');
end

function case_unrealized_widget_on_tab_switch_inherits_synced_range()
    %CASE_UNREALIZED_WIDGET_ON_TAB_SWITCH_INHERITS_SYNCED_RANGE LLW-03.
    %   Build a dashboard where page-2 widget is unrealized; broadcast on
    %   page 1; switch to page 2; assert the now-realized page-2 widget
    %   shows xlim==[40 60], NOT its construction default.
    d = build_two_page_dashboard_('llw-tab-switch-inherits');
    cleanup = onCleanup(@() safe_close_(d));  %#ok<NASGU>

    % Confirm pre-conditions: page 2 widget is currently NOT realized.
    assert(~d.Pages{2}.Widgets{1}.Realized, ...
        'pre-cond: page 2 widget should be unrealized (lazy) before switchPage');

    d.broadcastTimeRangeNow(40, 60);

    d.switchPage(2);
    drawnow;

    assert(d.Pages{2}.Widgets{1}.Realized, ...
        'page 2 widget should be realized after switchPage(2)');

    ax2 = d.Pages{2}.Widgets{1}.FastSenseObj.hAxes;
    assert_xlim_(ax2, [40 60], 'page 2 widget post-tab-switch re-broadcast');
end

function case_manual_zoom_widget_opts_out_of_broadcast()
    %CASE_MANUAL_ZOOM_WIDGET_OPTS_OUT_OF_BROADCAST Per-widget contract.
    %   Pre-realize page 2, set UseGlobalTime=false on its widget, then
    %   broadcast from page 1. Page-2 widget xlim must NOT be [30 70] —
    %   FastSenseWidget.setTimeRange short-circuits when UseGlobalTime is
    %   false.
    d = build_two_page_dashboard_('llw-manual-zoom-optout');
    cleanup = onCleanup(@() safe_close_(d));  %#ok<NASGU>

    % Pre-realize page 2 so we can grab its widget axes and detach it.
    d.switchPage(2);
    drawnow;
    detachedWidget = d.Pages{2}.Widgets{1};
    detachedWidget.UseGlobalTime = false;
    % Snapshot the manual xlim BEFORE the broadcast so we can compare.
    ax2 = detachedWidget.FastSenseObj.hAxes;
    preBroadcastXLim = get(ax2, 'XLim');
    d.switchPage(1);
    drawnow;

    d.broadcastTimeRangeNow(30, 70);

    % Page-1 widget WAS following global time -> takes the broadcast.
    ax1 = d.Pages{1}.Widgets{1}.FastSenseObj.hAxes;
    assert_xlim_(ax1, [30 70], 'page 1 (UseGlobalTime=true) follows broadcast');

    % Page-2 widget had UseGlobalTime=false -> stays at its prior xlim.
    actual = get(ax2, 'XLim');
    if abs(actual(1) - 30) < 1e-9 && abs(actual(2) - 70) < 1e-9
        error(['manual-zoom widget incorrectly followed broadcast: ' ...
               'xlim=[%g %g] but UseGlobalTime was false'], actual(1), actual(2));
    end
    % And it should still match its pre-broadcast xlim (the per-widget
    % opt-out is a no-op, not a fallback to construction default).
    assert(abs(actual(1) - preBroadcastXLim(1)) < 1e-9 && ...
           abs(actual(2) - preBroadcastXLim(2)) < 1e-9, ...
        sprintf('manual-zoom widget xlim drifted from [%g %g] to [%g %g]', ...
                preBroadcastXLim(1), preBroadcastXLim(2), actual(1), actual(2)));
end

function case_single_page_dashboard_unaffected()
    %CASE_SINGLE_PAGE_DASHBOARD_UNAFFECTED allPageWidgets() fallthrough.
    %   On a no-Pages dashboard, allPageWidgets() returns obj.Widgets, so
    %   broadcast still hits every widget.
    x = linspace(0, 100, 500);
    y1 = sin(x * 0.1);
    y2 = cos(x * 0.1);

    d = DashboardEngine('llw-single-page');
    d.addWidget('fastsense', 'Title', 'sw1', 'XData', x, 'YData', y1);
    d.addWidget('fastsense', 'Title', 'sw2', 'XData', x, 'YData', y2);
    evalc('d.render();');
    try set(d.hFigure, 'Visible', 'off'); catch, end
    drawnow;
    cleanup = onCleanup(@() safe_close_(d));  %#ok<NASGU>

    d.broadcastTimeRangeNow(30, 70);

    ax1 = d.Widgets{1}.FastSenseObj.hAxes;
    ax2 = d.Widgets{2}.FastSenseObj.hAxes;
    assert_xlim_(ax1, [30 70], 'single-page widget 1 broadcast');
    assert_xlim_(ax2, [30 70], 'single-page widget 2 broadcast');
end

% -------------------------------------------------------------------------

function assert_xlim_(ax, expected, label)
    actual = get(ax, 'XLim');
    if abs(actual(1) - expected(1)) > 1e-9 || abs(actual(2) - expected(2)) > 1e-9
        error('xlim mismatch (%s): got [%g %g], expected [%g %g]', ...
            label, actual(1), actual(2), expected(1), expected(2));
    end
end

function safe_close_(d)
    try
        if ~isempty(d) && ~isempty(d.hFigure) && ishandle(d.hFigure)
            close(d.hFigure);
        end
    catch
    end
end
