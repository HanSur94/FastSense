function test_fastsense_follow_toggle()
%TEST_FASTSENSE_FOLLOW_TOGGLE Tests for the Follow toggle button on FastSenseToolbar.
%
%   Covers:
%     - Button exists, initial State='off'
%     - Enable mirrors LiveViewMode availability
%     - setFollow(true) sets LiveViewMode='follow' and snaps XLim to tail when needed
%     - setFollow(true) does NOT touch XLim when the tail is already visible
%     - setFollow(false) reverts to 'preserve'
%     - User-initiated pan auto-disengages Follow
%     - Live-tick (applyViewMode) does NOT auto-disengage
%     - FastSenseWidget.LiveViewMode default ('preserve' per 260513-ovt) is untouched

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();

    % Skip on headless: uitoggletool requires a figure with a uitoolbar.
    if ~usejava('desktop')
        fprintf('    test_fastsense_follow_toggle: skipped (no java desktop).\n');
        return;
    end

    nPassed = 0; nFailed = 0;
    cleanupAll = onCleanup(@() close('all', 'force')); %#ok<NASGU>

    % --- test_followButtonExists ---
    try
        fp = makeFp_();
        tb = FastSenseToolbar(fp);
        assert(~isempty(tb.hFollowBtn) && ishandle(tb.hFollowBtn), ...
            'hFollowBtn missing or not a handle');
        close(fp.hFigure); nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_followButtonExists: %s\n', err.message);
    end

    % --- test_followInitialStateOff ---
    try
        fp = makeFp_();
        tb = FastSenseToolbar(fp);
        assert(strcmp(get(tb.hFollowBtn, 'State'), 'off'), 'initial State should be off');
        close(fp.hFigure); nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1; fprintf('    FAIL test_followInitialStateOff: %s\n', err.message);
    end

    % --- test_followDisabledWhenLiveViewModeEmpty ---
    try
        fp = makeFp_();  % default LiveViewMode = ''
        tb = FastSenseToolbar(fp);
        assert(strcmp(get(tb.hFollowBtn, 'Enable'), 'off'), ...
            'Enable should be off when LiveViewMode empty');
        close(fp.hFigure); nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_followDisabledWhenLiveViewModeEmpty: %s\n', err.message);
    end

    % --- test_followEnabledWhenLiveViewModeSet ---
    try
        fp = makeFp_();
        fp.LiveViewMode = 'preserve';
        tb = FastSenseToolbar(fp);
        assert(strcmp(get(tb.hFollowBtn, 'Enable'), 'on'), ...
            'Enable should be on when LiveViewMode set');
        close(fp.hFigure); nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1; fprintf('    FAIL test_followEnabledWhenLiveViewModeSet: %s\n', err.message);
    end

    % --- test_setFollowOnSnapsToTail ---
    try
        fp = makeFp_();
        fp.LiveViewMode = 'preserve';
        tb = FastSenseToolbar(fp);
        % Pan to the front half: [1, 500] when data ranges 1:1000
        set(fp.hAxes, 'XLim', [1, 500]);
        tb.setFollow(true);
        assert(strcmp(fp.LiveViewMode, 'follow'), 'LiveViewMode should be follow');
        xl = get(fp.hAxes, 'XLim');
        % Expect snap to [1000-499, 1000] = [501, 1000]
        assert(abs(xl(2) - 1000) < 1e-6 && abs(xl(1) - 501) < 1e-6, ...
            sprintf('expected XLim near [501, 1000], got [%g, %g]', xl(1), xl(2)));
        close(fp.hFigure); nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1; fprintf('    FAIL test_setFollowOnSnapsToTail: %s\n', err.message);
    end

    % --- test_setFollowOnNoSnapWhenTailVisible ---
    try
        fp = makeFp_();
        fp.LiveViewMode = 'preserve';
        tb = FastSenseToolbar(fp);
        % XLim already includes x(end)=1000
        set(fp.hAxes, 'XLim', [800, 1100]);
        xlBefore = get(fp.hAxes, 'XLim');
        tb.setFollow(true);
        xlAfter = get(fp.hAxes, 'XLim');
        assert(strcmp(fp.LiveViewMode, 'follow'), 'LiveViewMode should be follow');
        assert(isequal(xlBefore, xlAfter), 'XLim must not change when tail already visible');
        close(fp.hFigure); nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1; fprintf('    FAIL test_setFollowOnNoSnapWhenTailVisible: %s\n', err.message);
    end

    % --- test_setFollowOffSetsPreserve ---
    try
        fp = makeFp_();
        fp.LiveViewMode = 'follow';
        tb = FastSenseToolbar(fp);
        set(tb.hFollowBtn, 'State', 'on');  % match the model
        tb.setFollow(false);
        assert(strcmp(fp.LiveViewMode, 'preserve'), 'should revert to preserve');
        assert(strcmp(get(tb.hFollowBtn, 'State'), 'off'), 'button should be off');
        close(fp.hFigure); nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1; fprintf('    FAIL test_setFollowOffSetsPreserve: %s\n', err.message);
    end

    % --- test_userPanDisengagesFollow ---
    try
        fp = makeFp_();
        fp.LiveViewMode = 'preserve';
        tb = FastSenseToolbar(fp);
        % NOTE: onXLimChanged needs syncFollowState to find the toolbar.
        % FastSenseToolbar(fp) does NOT setappdata — only attacher call sites
        % do. Stash it here to exercise the visual-sync path.
        setappdata(fp.hFigure, 'FastSenseToolbar', tb);
        tb.setFollow(true);
        % Simulate user pan: bare set triggers onXLimChanged via the
        % XLim PostSet listener.
        set(fp.hAxes, 'XLim', [1, 500]);
        drawnow;
        assert(strcmp(fp.LiveViewMode, 'preserve'), ...
            sprintf('user pan should disengage, got LiveViewMode=%s', fp.LiveViewMode));
        assert(strcmp(get(tb.hFollowBtn, 'State'), 'off'), ...
            'button should be off after user pan');
        close(fp.hFigure); nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1; fprintf('    FAIL test_userPanDisengagesFollow: %s\n', err.message);
    end

    % --- test_programmaticPanDoesNotDisengage ---
    % Drive the live-tick code path via updateData (which calls applyViewMode
    % internally, which sets IsPropagating=true around the XLim set).
    try
        fp = makeFp_();
        fp.LiveViewMode = 'follow';
        tb = FastSenseToolbar(fp);
        setappdata(fp.hFigure, 'FastSenseToolbar', tb);
        set(tb.hFollowBtn, 'State', 'on');
        % Append more samples — applyViewMode 'follow' branch will slide XLim
        % with IsPropagating=true, so the auto-disengage hook must NOT fire.
        fp.updateData(1, 1:1100, sin(1:1100));
        drawnow;
        assert(strcmp(fp.LiveViewMode, 'follow'), ...
            sprintf('live tick must not disengage, got LiveViewMode=%s', fp.LiveViewMode));
        assert(strcmp(get(tb.hFollowBtn, 'State'), 'on'), ...
            'button should stay on after live tick');
        close(fp.hFigure); nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1; fprintf('    FAIL test_programmaticPanDoesNotDisengage: %s\n', err.message);
    end

    % --- test_dashboardWidgetDefaultIsPreserve ---
    % Default flipped from 'reset' to 'preserve' in 260513-ovt so Live mode
    % no longer silently resets the user's X view every tick.
    try
        w = FastSenseWidget('XData', 1:100, 'YData', sin(1:100));
        assert(strcmp(w.LiveViewMode, 'preserve'), ...
            sprintf('FastSenseWidget.LiveViewMode default must be preserve, got %s', w.LiveViewMode));
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1; fprintf('    FAIL test_dashboardWidgetDefaultIsPreserve: %s\n', err.message);
    end

    % --- Summary ---
    fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
    if nFailed > 0
        error('test_fastsense_follow_toggle:failures', '%d test(s) failed.', nFailed);
    end
end

function fp = makeFp_()
%MAKEFP_ Build a rendered FastSense over x=1:1000 (the snap-math tests need a known tail).
    fp = FastSense();
    fp.addLine(1:1000, sin(1:1000));
    fp.render();
end
