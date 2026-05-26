function test_companion_tile_close_buttons()
%TEST_COMPANION_TILE_CLOSE_BUTTONS Tile + Close-all toolbar buttons for FastSenseCompanion.
%
%   Covers S0Y-01 (Tile windows) and S0Y-02 (Close all windows). Uses a
%   hidden uifigure (Visible='off' set immediately after construction) and
%   classical figures with Visible='off' so the test runner stays quiet.
%
%   The test reads private state through the friend accessors
%   FastSenseCompanion.getOpenedFiguresForTest_ and feeds figures in via
%   trackOpenedFigureForTest_ so we exercise the same code path as the real
%   onOpenDashboardRequested_ / onOpenAdHocPlotRequested_ hooks without
%   spinning up a full DashboardListPane.
%
%   See also FastSenseCompanion, openAdHocPlot, test_companion_filter_tags.

    add_paths_();
    if exist('OCTAVE_VERSION', 'builtin') ~= 0
        fprintf('Octave detected -- FastSenseCompanion is MATLAB-only; skipping.\n');
        return;
    end

    nPassed = 0; nTotal = 0;

    [p, t] = test_tracking_on_dashboard_open_();   nPassed = nPassed + p; nTotal = nTotal + t;
    [p, t] = test_tracking_dedupes_same_figure_(); nPassed = nPassed + p; nTotal = nTotal + t;
    [p, t] = test_pruning_after_external_close_(); nPassed = nPassed + p; nTotal = nTotal + t;
    [p, t] = test_tile_geometry_no_overlap_();     nPassed = nPassed + p; nTotal = nTotal + t;
    [p, t] = test_close_all_clears_tracking_();    nPassed = nPassed + p; nTotal = nTotal + t;
    [p, t] = test_outside_figures_not_touched_();  nPassed = nPassed + p; nTotal = nTotal + t;
    [p, t] = test_toolbar_buttons_present_();      nPassed = nPassed + p; nTotal = nTotal + t;
    [p, t] = test_sync_pulls_prerendered_engine_(); nPassed = nPassed + p; nTotal = nTotal + t;
    [p, t] = test_public_trackopenedfigure_hook_(); nPassed = nPassed + p; nTotal = nTotal + t;

    if nPassed == nTotal
        fprintf('    All %d tests passed.\n', nTotal);
    else
        error('test_companion_tile_close_buttons: %d / %d passed', nPassed, nTotal);
    end
end

% -------------------------------------------------------------------------
% Sub-tests
% -------------------------------------------------------------------------

function [passed, total] = test_tracking_on_dashboard_open_()
%TEST_TRACKING_ON_DASHBOARD_OPEN_ trackOpenedFigure_ appends DashboardEngine figures.
    total = 1; passed = 0;
    [app, cleanup] = make_app_(); %#ok<ASGLU>

    d = DashboardEngine('S0Y-track-1');
    d.render();
    set(d.hFigure, 'Visible', 'off');
    figureCleanup = onCleanup(@() safe_delete_fig_(d.hFigure)); %#ok<NASGU>

    app.trackOpenedFigureForTest_(d.hFigure);

    figs = app.getOpenedFiguresForTest_();
    assert(numel(figs) == 1, 'expected 1 tracked figure, got %d', numel(figs));
    assert(figs(1) == d.hFigure, 'tracked figure must equal d.hFigure');

    passed = 1;
end

function [passed, total] = test_tracking_dedupes_same_figure_()
%TEST_TRACKING_DEDUPES_SAME_FIGURE_ Calling trackOpenedFigure_ twice on the same handle is a no-op.
    total = 1; passed = 0;
    [app, cleanup] = make_app_(); %#ok<ASGLU>

    d = DashboardEngine('S0Y-dedupe');
    d.render();
    set(d.hFigure, 'Visible', 'off');
    figureCleanup = onCleanup(@() safe_delete_fig_(d.hFigure)); %#ok<NASGU>

    app.trackOpenedFigureForTest_(d.hFigure);
    app.trackOpenedFigureForTest_(d.hFigure);   % duplicate -- must NOT double-add
    app.trackOpenedFigureForTest_(d.hFigure);

    figs = app.getOpenedFiguresForTest_();
    assert(numel(figs) == 1, ...
        'dedupe failed: expected 1 entry, got %d', numel(figs));

    passed = 1;
end

function [passed, total] = test_pruning_after_external_close_()
%TEST_PRUNING_AFTER_EXTERNAL_CLOSE_ Closed handles are dropped from tracking.
    total = 1; passed = 0;
    [app, cleanup] = make_app_(); %#ok<ASGLU>

    % Make two classical figures, track them, close one externally, then
    % call tileOpenedWindows and confirm the dead handle is gone.
    f1 = figure('Visible', 'off', 'NumberTitle', 'off', 'Name', 'S0Y-prune-1');
    f2 = figure('Visible', 'off', 'NumberTitle', 'off', 'Name', 'S0Y-prune-2');
    cleanupFigs = onCleanup(@() safe_delete_fig_([f1 f2])); %#ok<NASGU>

    app.trackOpenedFigureForTest_(f1);
    app.trackOpenedFigureForTest_(f2);
    assert(numel(app.getOpenedFiguresForTest_()) == 2, 'pre-close: expected 2 tracked');

    % Close f1 outside the companion's lifecycle.
    close(f1);

    % Tile should not error AND must drop the dead handle.
    app.tileOpenedWindows();

    figs = app.getOpenedFiguresForTest_();
    assert(numel(figs) == 1, ...
        'pruning failed: expected 1 tracked after close(f1), got %d', numel(figs));
    assert(figs(1) == f2, 'remaining tracked handle must be f2');

    passed = 1;
end

function [passed, total] = test_tile_geometry_no_overlap_()
%TEST_TILE_GEOMETRY_NO_OVERLAP_ After tile, the 4 figures form a non-overlapping grid.
    total = 1; passed = 0;
    [app, cleanup] = make_app_(); %#ok<ASGLU>

    figs = gobjects(4, 1);
    for k = 1:4
        figs(k) = figure( ...
            'Visible',     'off', ...
            'NumberTitle', 'off', ...
            'Name',        sprintf('S0Y-tile-%d', k), ...
            'Position',    [100 100 800 600]);
        app.trackOpenedFigureForTest_(figs(k));
    end
    cleanupFigs = onCleanup(@() safe_delete_fig_(figs)); %#ok<NASGU>

    app.tileOpenedWindows();

    % Read back positions AFTER tile.
    rects = zeros(4, 4);
    for k = 1:4
        rects(k, :) = get(figs(k), 'Position');
    end

    % Pairwise non-overlap check.
    for i = 1:4
        for j = i+1:4
            assert(~rects_overlap_(rects(i,:), rects(j,:)), ...
                'tile geometry: rect %d and %d overlap [%s] vs [%s]', ...
                i, j, mat2str(rects(i,:)), mat2str(rects(j,:)));
        end
    end

    % Every rect must have positive width and height.
    for k = 1:4
        assert(rects(k, 3) > 0 && rects(k, 4) > 0, ...
            'rect %d has non-positive size: %s', k, mat2str(rects(k,:)));
    end

    passed = 1;
end

function [passed, total] = test_close_all_clears_tracking_()
%TEST_CLOSE_ALL_CLEARS_TRACKING_ closeAllOpenedWindows closes every tracked fig + empties list.
    total = 1; passed = 0;
    [app, cleanup] = make_app_(); %#ok<ASGLU>

    figs = gobjects(3, 1);
    for k = 1:3
        figs(k) = figure('Visible', 'off', ...
            'NumberTitle', 'off', ...
            'Name', sprintf('S0Y-closeall-%d', k));
        app.trackOpenedFigureForTest_(figs(k));
    end
    cleanupFigs = onCleanup(@() safe_delete_fig_(figs)); %#ok<NASGU>

    app.closeAllOpenedWindows();

    for k = 1:3
        assert(~ishandle(figs(k)), ...
            'closeAll: figure %d still alive', k);
    end
    assert(isempty(app.getOpenedFiguresForTest_()), ...
        'closeAll: tracking list not cleared');
    % Companion's own uifigure must still be alive.
    assert(isvalid(app), 'companion app handle must survive closeAll');

    passed = 1;
end

function [passed, total] = test_outside_figures_not_touched_()
%TEST_OUTSIDE_FIGURES_NOT_TOUCHED_ Figures opened outside the companion are not moved or closed.
    total = 1; passed = 0;
    [app, cleanup] = make_app_(); %#ok<ASGLU>

    % One TRACKED figure (the companion opens it).
    fTracked = figure('Visible', 'off', ...
        'NumberTitle', 'off', 'Name', 'S0Y-tracked', ...
        'Position', [200 200 500 400]);
    app.trackOpenedFigureForTest_(fTracked);

    % One OUTSIDE figure (user opened it; companion never sees it).
    fOutside = figure('Visible', 'off', ...
        'NumberTitle', 'off', 'Name', 'S0Y-outside', ...
        'Position', [350 350 500 400]);

    cleanupFigs = onCleanup(@() safe_delete_fig_([fTracked fOutside])); %#ok<NASGU>

    origOutsidePos = get(fOutside, 'Position');

    app.tileOpenedWindows();
    assert(isequal(get(fOutside, 'Position'), origOutsidePos), ...
        'outside figure was moved by tile -- it must not be touched');

    app.closeAllOpenedWindows();
    assert(~ishandle(fTracked), 'tracked figure must be closed by closeAll');
    assert(ishandle(fOutside), ...
        'outside figure must survive closeAll -- it was not tracked');

    passed = 1;
end

function [passed, total] = test_toolbar_buttons_present_()
%TEST_TOOLBAR_BUTTONS_PRESENT_ Two new uibutton handles exist with the expected labels.
    total = 1; passed = 0;
    [app, cleanup] = make_app_(); %#ok<ASGLU>

    % Probe via findall on the uifigure for buttons whose Text matches.
    fig = app.getFigForTest_();
    btns = findall(fig, 'Type', 'uibutton');
    texts = arrayfun(@(b) char(b.Text), btns, 'UniformOutput', false);

    assert(any(strcmp(texts, 'Tile')), ...
        'toolbar: Tile button missing. Found buttons: %s', strjoin(texts, ', '));
    assert(any(strcmp(texts, 'Close all')), ...
        'toolbar: Close all button missing. Found buttons: %s', strjoin(texts, ', '));

    passed = 1;
end

function [passed, total] = test_sync_pulls_prerendered_engine_()
%TEST_SYNC_PULLS_PRERENDERED_ENGINE_ Engines rendered BEFORE construction get tracked.
%   Reproduces the live-demo bug: run_demo builds + renders a DashboardEngine,
%   THEN passes it to FastSenseCompanion. The OpenDashboardRequested event
%   never fires for that engine, so the lazy tracking hook misses it. The
%   eager syncOpenedFigures_ helper (called at the top of tileOpenedWindows
%   and closeAllOpenedWindows) must pull the figure from Engines_ on first
%   click so Tile / Close all work for the demo's initial dashboard.
    total = 1; passed = 0;

    % Build + render the engine BEFORE the companion exists.
    d = DashboardEngine('S0Y-sync-prerender');
    d.render();
    set(d.hFigure, 'Visible', 'off');
    figCleanup = onCleanup(@() safe_delete_fig_(d.hFigure)); %#ok<NASGU>

    % Construct companion over the already-rendered engine; do not fire
    % OpenDashboardRequested ourselves.
    app = FastSenseCompanion('Dashboards', {d}, 'Theme', 'dark');
    try
        fig = app.getFigForTest_();
        if ~isempty(fig) && isvalid(fig); fig.Visible = 'off'; end
    catch
    end
    appCleanup = onCleanup(@() safe_close_app_(app)); %#ok<NASGU>

    % Before any sync, OpenedFigures_ is empty -- nothing has tracked yet.
    pre = app.getOpenedFiguresForTest_();
    assert(isempty(pre), ...
        'expected OpenedFigures_ empty before first sync, got %d entries', numel(pre));

    % Calling tile triggers syncOpenedFigures_, which pulls d.hFigure from
    % Engines_. Read the tracking list right after and verify.
    app.tileOpenedWindows();
    post = app.getOpenedFiguresForTest_();
    assert(numel(post) == 1, ...
        'sync must surface 1 engine figure on Tile, got %d', numel(post));
    assert(post(1) == d.hFigure, ...
        'tracked figure must equal the engine''s hFigure');

    % Snapshot the figure handle BEFORE closeAll -- DashboardEngine's
    % CloseRequestFcn (stopLive + delete) may clear d.hFigure, leaving
    % d.hFigure == [], and ishandle([]) returns [] which is not convertible
    % to a scalar logical for assert().
    hFigSnap = d.hFigure;
    app.closeAllOpenedWindows();
    assert(~ishandle(hFigSnap), ...
        'closeAllOpenedWindows must close the pre-rendered engine''s figure');

    passed = 1;
end

function [passed, total] = test_public_trackopenedfigure_hook_()
%TEST_PUBLIC_TRACKOPENEDFIGURE_HOOK_ Public trackOpenedFigure surfaces a foreign figure.
%   Reproduces the live-demo gap reported after the sync fix shipped: a user
%   opens a sensor detail plot via the inspector's "Open detail" button, which
%   calls openAdHocPlot DIRECTLY (not via the OpenAdHocPlotRequested event).
%   The pane now captures the returned hFig and forwards to the orchestrator's
%   PUBLIC trackOpenedFigure method. Same hook is used by CompanionEventViewer's
%   openEventDashboard_. This test exercises the public hook itself.
    total = 1; passed = 0;
    [app, cleanup] = make_app_(); %#ok<ASGLU>

    f = figure('Visible', 'off', 'Name', 'S0Y-public-hook');
    figCleanup = onCleanup(@() safe_delete_fig_(f)); %#ok<NASGU>

    % BEFORE the public hook is called -- not tracked.
    pre = app.getOpenedFiguresForTest_();
    assert(isempty(pre), 'expected empty pre, got %d', numel(pre));

    % Public hook -- the same call InspectorPane.onOpenDetail_ and
    % CompanionEventViewer.openEventDashboard_ make.
    app.trackOpenedFigure(f);

    post = app.getOpenedFiguresForTest_();
    assert(numel(post) == 1, 'expected 1 tracked figure, got %d', numel(post));
    assert(post(1) == f, 'tracked figure must equal the one we passed in');

    % Dedupe: calling the public hook twice on the same handle still yields 1.
    app.trackOpenedFigure(f);
    post2 = app.getOpenedFiguresForTest_();
    assert(numel(post2) == 1, 'expected dedupe, got %d', numel(post2));

    % Close all closes it.
    app.closeAllOpenedWindows();
    assert(~ishandle(f), 'closeAllOpenedWindows must close the publicly tracked figure');

    passed = 1;
end

% -------------------------------------------------------------------------
% Helpers
% -------------------------------------------------------------------------

function [app, cleanup] = make_app_()
%MAKE_APP_ Build a hidden FastSenseCompanion and return (app, onCleanup).
    app = FastSenseCompanion('Dashboards', {}, 'Theme', 'dark');
    % Hide immediately to keep CI quiet -- the constructor turns Visible on
    % at the end of construction, so flip it back here.
    try
        fig = app.getFigForTest_();
        if ~isempty(fig) && isvalid(fig)
            fig.Visible = 'off';
        end
    catch
    end
    cleanup = onCleanup(@() safe_close_app_(app));
end

function safe_close_app_(app)
%SAFE_CLOSE_APP_ Best-effort companion teardown for onCleanup.
    try
        if isobject(app) && isvalid(app)
            app.close();
        end
    catch
    end
end

function safe_delete_fig_(figs)
%SAFE_DELETE_FIG_ Delete any still-valid figure handles. figs may be a vector.
    for k = 1:numel(figs)
        try
            h = figs(k);
            if ishandle(h)
                delete(h);
            end
        catch
        end
    end
end

function tf = rects_overlap_(a, b)
%RECTS_OVERLAP_ True iff rectangles a and b overlap in 2-D ([x y w h] form).
    tf = ~(a(1)+a(3) <= b(1) || b(1)+b(3) <= a(1) || ...
           a(2)+a(4) <= b(2) || b(2)+b(4) <= a(2));
end

function add_paths_()
%ADD_PATHS_ Make sure libs/ are on path; install if needed.
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    if isempty(which('FastSenseCompanion'))
        install();
    end
end
