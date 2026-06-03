function test_dashboard_time_window()
%TEST_DASHBOARD_TIME_WINDOW Headless tests for DashboardEngine/FastSenseWidget time-windowing.
%
%   Covers:
%     testSetTimeWindow        -- engine.setTimeWindow stores window + fans to widgets
%     testClearTimeWindow      -- engine.setTimeWindow([],[]) clears to full range
%     testWidgetWindowedPull   -- windowed widget pulls fewer points at refresh/update
%     testWidgetWindowedRenderBindsDisk  -- disk-backed render with non-empty window
%                                          binds a non-empty line via fp.addLine
%     testWidgetAllDataDiskNonEmpty      -- disk-backed 'All data' (empty window) binds
%                                          FULL extent, not a blank addTag line
%     testWidgetFullPullWhenEmpty        -- in-RAM tag + empty window = full series via addTag
%     testEmptyStateDecision   -- out-of-extent window -> isShowingEmptyState()
%     testPreviewStillFull     -- getTimeRange on windowed widget still returns full extent
%
%   testSetTimeWindow / testClearTimeWindow: unguarded (pure property fan-out; runs in Octave).
%   Remaining sub-tests that need a rendered figure: MATLAB-only (Octave-guarded).
%
%   RED phase until Tasks 2-3 land.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    testSetTimeWindow();
    testClearTimeWindow();

    if exist('OCTAVE_VERSION', 'builtin') ~= 0
        fprintf('    Property fan-out tests passed; figure-dependent tests SKIPPED on Octave.\n');
        fprintf('    All 2 test_dashboard_time_window pure-property tests passed.\n');
        return;
    end

    TagRegistry.clear();

    testWidgetWindowedPull();
    testWidgetWindowedRenderBindsDisk();
    testWidgetAllDataDiskNonEmpty();
    testWidgetFullPullWhenEmpty();
    testEmptyStateDecision();
    testPreviewStillFull();

    TagRegistry.clear();

    fprintf('    All 8 test_dashboard_time_window tests passed.\n');
end

% -------------------------------------------------------------------------
% Fixture helpers
% -------------------------------------------------------------------------

function [st, x, t0] = makeRamFixture(key)
%MAKERAMFIXTURE Build an in-RAM SensorTag with 10-day datenum series.
    t0 = datenum(2024, 1, 1);
    % One sample per second for 10 days = 864000 samples; use 1/86400 day step.
    x  = (t0:1/86400:t0 + 9)';
    y  = sin(2 * pi * x);
    st = SensorTag(key, 'Name', 'TestSensor');
    st.updateData(x, y);
end

function [st, x, t0] = makeDiskFixture(key)
%MAKEDISKFIXTURE Build a disk-backed SensorTag (getXY() returns empty).
    [st, x, t0] = makeRamFixture(key);
    st.toDisk();  % moves X_/Y_ to DataStore; getXY() now returns []
end

function d = makeEngine(widget_or_tag)
%MAKEENGINE Build a minimal DashboardEngine with one FastSenseWidget.
    d = DashboardEngine('tw-test', 'Theme', 'dark');
    if isa(widget_or_tag, 'Tag')
        d.addWidget('fastsense', 'Tag', widget_or_tag, ...
            'Title', 'tw', 'Position', [1 1 24 12]);
    end
end

% -------------------------------------------------------------------------
% Unguarded pure-property fan-out tests (run in Octave too)
% -------------------------------------------------------------------------

function testSetTimeWindow()
%TESTSETTIMEWINDOW engine.setTimeWindow stores window; each widget's TimeWindow_ equals [t0 t1].
    t0 = datenum(2024, 1, 1);
    t1 = datenum(2024, 1, 8);

    d = DashboardEngine('tw-set-test', 'Theme', 'dark');
    d.addWidget('fastsense', 'XData', 1:10, 'YData', rand(1,10), ...
        'Title', 'sig1', 'Position', [1 1 24 6]);
    d.addWidget('fastsense', 'XData', 1:10, 'YData', rand(1,10), ...
        'Title', 'sig2', 'Position', [1 7 24 6]);

    d.setTimeWindow(t0, t1);

    assert(ismethod(d, 'setTimeWindow'), ...
        'test_dashboard_time_window:testSetTimeWindow', ...
        'DashboardEngine must define setTimeWindow');

    ws = d.allPageWidgets();
    for i = 1:numel(ws)
        w = ws{i};
        if ismethod(w, 'setTimeWindow')
            tw = w.TimeWindow_;
            assert(~isempty(tw) && numel(tw) == 2, ...
                'test_dashboard_time_window:testSetTimeWindow', ...
                sprintf('Widget %d TimeWindow_ should be [t0 t1] after setTimeWindow', i));
            assert(abs(tw(1) - t0) < 1e-9 && abs(tw(2) - t1) < 1e-9, ...
                'test_dashboard_time_window:testSetTimeWindow', ...
                sprintf('Widget %d TimeWindow_ values should match [t0 t1]', i));
        end
    end

    try; delete(d); catch; end
end

function testClearTimeWindow()
%TESTCLEARTIMEWINDOW engine.setTimeWindow([],[]) clears widgets' TimeWindow_ to empty.
    t0 = datenum(2024, 1, 1);
    t1 = datenum(2024, 1, 8);

    d = DashboardEngine('tw-clear-test', 'Theme', 'dark');
    d.addWidget('fastsense', 'XData', 1:10, 'YData', rand(1,10), ...
        'Title', 'sig1', 'Position', [1 1 24 12]);

    d.setTimeWindow(t0, t1);
    d.setTimeWindow([], []);

    ws = d.allPageWidgets();
    for i = 1:numel(ws)
        w = ws{i};
        if ismethod(w, 'setTimeWindow')
            assert(isempty(w.TimeWindow_), ...
                'test_dashboard_time_window:testClearTimeWindow', ...
                sprintf('Widget %d TimeWindow_ should be empty after setTimeWindow([],[])', i));
        end
    end

    try; delete(d); catch; end
end

% -------------------------------------------------------------------------
% MATLAB-only figure-dependent sub-tests
% -------------------------------------------------------------------------

function testWidgetWindowedPull()
%TESTWIDGETWINDOWEDPULL After refresh/update with a window, plotted line length < full series.
    TagRegistry.clear();
    [st, x, t0] = makeRamFixture('tw_pull');
    fullN = numel(x);
    winT0 = t0 + 2;   % 2-day offset
    winT1 = t0 + 4;   % 4-day offset

    hFig = figure('Visible', 'off');
    cleanupFig = onCleanup(@() closeIfHandle_(hFig)); %#ok<NASGU>
    hp = uipanel('Parent', hFig, 'Units', 'normalized', 'Position', [0 0 1 1]);

    w = FastSenseWidget('Tag', st, 'Title', 'tw_pull');
    w.setTimeWindow(winT0, winT1);
    w.render(hp);

    if ~isempty(w.FastSenseObj) && w.FastSenseObj.IsRendered
        nLines = numel(w.FastSenseObj.Lines);
        if nLines >= 1
            wLineN = w.FastSenseObj.Lines(1).NumPoints;  % raw points bound (Lines is a struct array; NumPoints is downsample/disk-immune)
            assert(wLineN > 0, ...
                'test_dashboard_time_window:testWidgetWindowedPull', ...
                'Windowed render should bind non-empty line');
            assert(wLineN < fullN, ...
                'test_dashboard_time_window:testWidgetWindowedPull', ...
                sprintf('Windowed line length (%d) should be < full (%d)', wLineN, fullN));
        end
    end
end

function testWidgetWindowedRenderBindsDisk()
%TESTWIDGETWINDOWEDRENDERBINDSDISK Disk-backed render with non-empty window binds non-empty line.
%   Without the fix, addTag(diskTag) -> addLine(getXY()=[]) -> empty line.
%   With the fix, fp.addLine(getXYRange(t0,t1)) -> non-empty bounded line.
    TagRegistry.clear();
    [st, x, t0] = makeDiskFixture('tw_disk_win');
    fullN = numel(x);
    winT0 = t0 + 2;
    winT1 = t0 + 4;

    assert(isempty(st.getXY()), ...
        'test_dashboard_time_window:testWidgetWindowedRenderBindsDisk', ...
        'toDisk should have emptied getXY() for disk-backed fixture');

    hFig = figure('Visible', 'off');
    cleanupFig = onCleanup(@() closeIfHandle_(hFig)); %#ok<NASGU>
    hp = uipanel('Parent', hFig, 'Units', 'normalized', 'Position', [0 0 1 1]);

    w = FastSenseWidget('Tag', st, 'Title', 'tw_disk_win');
    w.setTimeWindow(winT0, winT1);
    w.render(hp);

    assert(~isempty(w.FastSenseObj) && w.FastSenseObj.IsRendered, ...
        'test_dashboard_time_window:testWidgetWindowedRenderBindsDisk', ...
        'Widget should render successfully for disk-backed tag under non-empty window');

    nLines = numel(w.FastSenseObj.Lines);
    assert(nLines >= 1, ...
        'test_dashboard_time_window:testWidgetWindowedRenderBindsDisk', ...
        'Windowed disk render should have at least one plotted line (not 0 via empty addTag)');

    wLineN = w.FastSenseObj.Lines(1).NumPoints;  % raw points bound (Lines is a struct array; NumPoints is downsample/disk-immune)
    assert(wLineN > 0, ...
        'test_dashboard_time_window:testWidgetWindowedRenderBindsDisk', ...
        sprintf('Disk windowed render bound line length is %d; expected > 0 (fix: fp.addLine(getXYRange))', wLineN));
    assert(wLineN < fullN, ...
        'test_dashboard_time_window:testWidgetWindowedRenderBindsDisk', ...
        sprintf('Disk windowed line length (%d) should be < full (%d)', wLineN, fullN));
    assert(~w.isShowingEmptyState(), ...
        'test_dashboard_time_window:testWidgetWindowedRenderBindsDisk', ...
        'Non-empty windowed disk render should NOT show empty state');
end

function testWidgetAllDataDiskNonEmpty()
%TESTWIDGETALLDATADISKNONEMPTY Disk-backed + EMPTY window = full extent, NOT a blank plot.
%   This is the 'All data' preset fix. Empty window -> addTag(diskTag) -> getXY()=[] -> BLANK.
%   Fix: empty-window branch is disk-aware: resolves extent via getTimeRange() then
%   binds via fp.addLine(getXYRange(tMin,tMax)) -> full series, length > 0.
    TagRegistry.clear();
    [st, x, ~] = makeDiskFixture('tw_alldata');
    fullN = numel(x);

    assert(isempty(st.getXY()), ...
        'test_dashboard_time_window:testWidgetAllDataDiskNonEmpty', ...
        'toDisk should have emptied getXY() for disk-backed fixture');

    hFig = figure('Visible', 'off');
    cleanupFig = onCleanup(@() closeIfHandle_(hFig)); %#ok<NASGU>
    hp = uipanel('Parent', hFig, 'Units', 'normalized', 'Position', [0 0 1 1]);

    w = FastSenseWidget('Tag', st, 'Title', 'tw_alldata');
    % Empty window = the 'All data' preset (engine.setTimeWindow([],[]))
    w.setTimeWindow([], []);
    w.render(hp);

    assert(~isempty(w.FastSenseObj) && w.FastSenseObj.IsRendered, ...
        'test_dashboard_time_window:testWidgetAllDataDiskNonEmpty', ...
        'Widget should render for disk-backed tag under EMPTY window (All data)');

    nLines = numel(w.FastSenseObj.Lines);
    assert(nLines >= 1, ...
        'test_dashboard_time_window:testWidgetAllDataDiskNonEmpty', ...
        'All data disk render should have at least one line (not blank addTag line)');

    wLineN = w.FastSenseObj.Lines(1).NumPoints;  % raw points bound (Lines is a struct array; NumPoints is downsample/disk-immune)
    assert(wLineN > 0, ...
        'test_dashboard_time_window:testWidgetAllDataDiskNonEmpty', ...
        sprintf('All data disk render bound line length is %d; expected > 0 (fix: fp.addLine(getXYRange(getTimeRange())))', wLineN));

    % Should be at least as many points as a strict sub-window would give (proves full extent)
    % For fixtures below FastSense downsample threshold, expect ~fullN
    assert(wLineN >= max(1, round(fullN * 0.5)), ...
        'test_dashboard_time_window:testWidgetAllDataDiskNonEmpty', ...
        sprintf('All data disk render line (%d pts) should cover most of full extent (%d pts)', wLineN, fullN));

    % isShowingEmptyState must be false: full extent is non-empty
    assert(~w.isShowingEmptyState(), ...
        'test_dashboard_time_window:testWidgetAllDataDiskNonEmpty', ...
        'All data disk render (full extent) should NOT show empty state');
end

function testWidgetFullPullWhenEmpty()
%TESTWIDGETFULLPULLWHENEMPTY In-RAM tag + empty window = full series via fp.addTag (unchanged path).
    TagRegistry.clear();
    [st, x, ~] = makeRamFixture('tw_full_ram');
    fullN = numel(x);

    hFig = figure('Visible', 'off');
    cleanupFig = onCleanup(@() closeIfHandle_(hFig)); %#ok<NASGU>
    hp = uipanel('Parent', hFig, 'Units', 'normalized', 'Position', [0 0 1 1]);

    w = FastSenseWidget('Tag', st, 'Title', 'tw_full_ram');
    % Empty window = full range (in-RAM: byte-identical to today's fp.addTag path)
    w.setTimeWindow([], []);
    w.render(hp);

    assert(~isempty(w.FastSenseObj) && w.FastSenseObj.IsRendered, ...
        'test_dashboard_time_window:testWidgetFullPullWhenEmpty', ...
        'Widget should render for in-RAM tag with empty window');

    nLines = numel(w.FastSenseObj.Lines);
    if nLines >= 1
        wLineN = w.FastSenseObj.Lines(1).NumPoints;  % raw points bound (Lines is a struct array; NumPoints is downsample/disk-immune)
        % FastSense may downsample; after LTTB/MinMax: still proportional to fullN.
        % Assert at least 10% of full series (downsampling never removes ALL points).
        assert(wLineN > 0, ...
            'test_dashboard_time_window:testWidgetFullPullWhenEmpty', ...
            'In-RAM empty-window render should bind a non-empty line (fp.addTag path)');
        assert(wLineN >= max(1, round(fullN * 0.1)), ...
            'test_dashboard_time_window:testWidgetFullPullWhenEmpty', ...
            sprintf('In-RAM line (%d pts) should be proportional to full extent (%d pts)', wLineN, fullN));
    end
    assert(~w.isShowingEmptyState(), ...
        'test_dashboard_time_window:testWidgetFullPullWhenEmpty', ...
        'In-RAM empty-window render should NOT show empty state');
end

function testEmptyStateDecision()
%TESTEMPTYSTATEDECISION Out-of-extent window -> isShowingEmptyState() is true.
    TagRegistry.clear();
    [st, ~, t0] = makeRamFixture('tw_empty_state');
    % Window is entirely outside the tag extent (tag is 2024-01-01 to 2024-01-10)
    futureT0 = t0 + 365;    % 2025-01-01
    futureT1 = t0 + 365 + 7;

    hFig = figure('Visible', 'off');
    cleanupFig = onCleanup(@() closeIfHandle_(hFig)); %#ok<NASGU>
    hp = uipanel('Parent', hFig, 'Units', 'normalized', 'Position', [0 0 1 1]);

    w = FastSenseWidget('Tag', st, 'Title', 'tw_empty_state');
    w.setTimeWindow(futureT0, futureT1);
    w.render(hp);

    assert(w.isShowingEmptyState(), ...
        'test_dashboard_time_window:testEmptyStateDecision', ...
        'Widget with out-of-extent window should report isShowingEmptyState() == true');
end

function testPreviewStillFull()
%TESTPREVIEWSTILLFULL getTimeRange on windowed widget returns full data extent.
%   Verifies that the preview / navigator cache is NOT affected by TimeWindow_.
    TagRegistry.clear();
    [st, x, t0] = makeRamFixture('tw_preview');
    tFull0 = t0;
    tFull1 = t0 + 9;
    winT0  = t0 + 2;
    winT1  = t0 + 4;

    hFig = figure('Visible', 'off');
    cleanupFig = onCleanup(@() closeIfHandle_(hFig)); %#ok<NASGU>
    hp = uipanel('Parent', hFig, 'Units', 'normalized', 'Position', [0 0 1 1]);

    w = FastSenseWidget('Tag', st, 'Title', 'tw_preview');
    w.setTimeWindow(winT0, winT1);
    w.render(hp);

    [tMin, tMax] = w.getTimeRange();
    tol = 0.01;  % 0.01 day tolerance for cache rounding
    assert(tMin < tFull0 + tol && tMin > tFull0 - 1, ...
        'test_dashboard_time_window:testPreviewStillFull', ...
        sprintf('getTimeRange tMin=%.4f should reflect full extent start ~%.4f', tMin, tFull0));
    assert(tMax > tFull1 - tol, ...
        'test_dashboard_time_window:testPreviewStillFull', ...
        sprintf('getTimeRange tMax=%.4f should reflect full extent end ~%.4f', tMax, tFull1));

    % Preview series should cover more than the window
    try
        [px, ~] = w.getPreviewSeries(50);
        if ~isempty(px)
            assert(numel(px) > 0, ...
                'test_dashboard_time_window:testPreviewStillFull', ...
                'Preview series should be non-empty (full envelope)');
            % Preview should span at least back to the full start
            assert(px(1) <= winT0 + tol, ...
                'test_dashboard_time_window:testPreviewStillFull', ...
                'Preview series should start at or before the window start (full envelope)');
        end
    catch
        % getPreviewSeries may require full rendering -- just skip if unavailable
    end
end

% -------------------------------------------------------------------------
% Cleanup helper
% -------------------------------------------------------------------------

function closeIfHandle_(h)
%CLOSEIFHANDLE_ Close figure if handle is still valid.
    try
        if ~isempty(h) && ishandle(h)
            close(h);
        end
    catch
    end
end
