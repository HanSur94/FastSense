function test_dashboard_stale_banner()
%TEST_DASHBOARD_STALE_BANNER Octave parallel suite for live-mode stale-data banner.
%
%   Covers:
%     - Banner + text + close button created during render, initially hidden.
%     - showStaleBanner lists the stale widget names.
%     - detectStaleWidgets returns titles of widgets whose tMax did not advance.
%     - Close button callback hides the banner + sets the dismissal flag.
%     - stopLive hides the banner and clears dismissal.

    add_dashboard_path();

    nPassed = 0;
    nFailed = 0;

    % testBannerCreatedHidden
    try
        d = DashboardEngine('StaleBanner');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        assert(~isempty(d.hStaleBanner), 'banner panel should be created');
        assert(ishandle(d.hStaleBanner), 'banner panel should be a live handle');
        assert(~isempty(d.hStaleBannerText) && ishandle(d.hStaleBannerText), ...
            'banner text child should exist');
        assert(~isempty(d.hStaleBannerClose) && ishandle(d.hStaleBannerClose), ...
            'banner close button should exist');
        assert(strcmp(get(d.hStaleBanner, 'Visible'), 'off'), ...
            'banner should start hidden');

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testBannerCreatedHidden: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testShowListsStaleTitles
    try
        d = DashboardEngine('ListNames');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        d.showStaleBanner({'SensorA', 'SensorB'});
        msg = get(d.hStaleBannerText, 'String');
        assert(~isempty(strfind(msg, 'SensorA')), ...
            sprintf('banner should list SensorA, got: %s', msg));
        assert(~isempty(strfind(msg, 'SensorB')), ...
            sprintf('banner should list SensorB, got: %s', msg));
        assert(strcmp(get(d.hStaleBanner, 'Visible'), 'on'), ...
            'banner should be visible after show');
        d.hideStaleBanner();

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testShowListsStaleTitles: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testShowCollapsesLongList
    try
        d = DashboardEngine('CollapseLong');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        titles = {'S1', 'S2', 'S3', 'S4', 'S5'};
        d.showStaleBanner(titles);
        msg = get(d.hStaleBannerText, 'String');
        assert(~isempty(strfind(msg, '5 widgets')), ...
            sprintf('banner should count 5 widgets, got: %s', msg));
        assert(~isempty(strfind(msg, '+2 more')), ...
            sprintf('banner should collapse to "+N more", got: %s', msg));
        d.hideStaleBanner();

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testShowCollapsesLongList: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testDetectStaleWithFrozenSensor
    try
        nSeed = 50;
        tSeed = linspace(-10, 0, nSeed);
        sFrozen = SensorTag('FROZEN', 'Name', 'Frozen', 'Units', '', ...
            'X', tSeed, 'Y', randn(1, nSeed));

        d = DashboardEngine('FrozenDetect');
        d.addWidget('fastsense', 'Title', 'Frozen Sensor', ...
            'Position', [1 1 6 3], 'Tag', sFrozen);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        ws = {d.Widgets{:}};
        % First pass populates LastTMaxPerWidget_ but nothing is "stale yet"
        first = d.detectStaleWidgets(ws);
        assert(isempty(first), ...
            sprintf('first detect() pass should have no baseline yet, got %d', ...
                numel(first)));

        % Second pass with no data change → stale
        second = d.detectStaleWidgets(ws);
        assert(numel(second) == 1, ...
            sprintf('second pass should detect 1 stale widget, got %d', ...
                numel(second)));
        assert(strcmp(second{1}, 'Frozen Sensor'), ...
            sprintf('stale title should be "Frozen Sensor", got: %s', second{1}));

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testDetectStaleWithFrozenSensor: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testCloseButtonDismisses
    try
        d = DashboardEngine('DismissTest');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        d.showStaleBanner({'Something'});
        assert(strcmp(get(d.hStaleBanner, 'Visible'), 'on'), ...
            'banner should be visible before dismiss');
        assert(~d.StaleBannerDismissed_, 'dismissed flag should start false');

        d.onStaleBannerClose();
        assert(strcmp(get(d.hStaleBanner, 'Visible'), 'off'), ...
            'banner should hide after close click');
        assert(d.StaleBannerDismissed_, 'dismissed flag should flip to true');

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testCloseButtonDismisses: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testStopLiveHidesBannerAndClearsDismissal
    try
        d = DashboardEngine('StopClear');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        d.showStaleBanner({'A'});
        d.onStaleBannerClose();
        assert(d.StaleBannerDismissed_, 'precondition: dismissed should be true');

        d.stopLive();
        assert(strcmp(get(d.hStaleBanner, 'Visible'), 'off'), ...
            'stopLive should keep banner hidden');
        assert(~d.StaleBannerDismissed_, ...
            'stopLive should clear dismissal flag');

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testStopLiveHidesBannerAndClearsDismissal: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testBannerInReservedStripAboveAllChrome
    %   Banner now lives in a permanent reserved strip at the figure top.
    %   Toolbar, page tabs, and content area sit BELOW the strip — the
    %   banner is never an overlay. This test pins that invariant for a
    %   2-page dashboard and asserts content-area stability across
    %   show/hide.
    try
        d = DashboardEngine('BannerReservedStrip');
        d.addPage('A');
        d.addPage('B');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        caBefore = d.Layout.ContentArea;
        d.showStaleBanner({'X'});

        bannerPos  = get(d.hStaleBanner,   'Position');
        toolbarPos = get(d.Toolbar.hPanel, 'Position');
        pageBarPos = get(d.hPageBar,       'Position');

        % Banner sits in the reserved top strip: Y == 1 - BannerHeight,
        % top edge at 1.0.
        assert(abs(bannerPos(2) - (1 - d.BannerHeight)) < 1e-6, ...
            sprintf('banner Y %.6f must equal 1 - BannerHeight = %.6f', ...
                bannerPos(2), 1 - d.BannerHeight));
        assert(abs((bannerPos(2) + bannerPos(4)) - 1.0) < 1e-6, ...
            sprintf('banner top %.6f must equal 1.0', ...
                bannerPos(2) + bannerPos(4)));

        % Banner sits ABOVE toolbar (no overlap).
        toolbarTop = toolbarPos(2) + toolbarPos(4);
        assert(bannerPos(2) >= toolbarTop - 1e-6, ...
            sprintf('banner bottom %.6f must be >= toolbar top %.6f', ...
                bannerPos(2), toolbarTop));

        % Toolbar sits directly below the reserved strip.
        assert(abs(toolbarTop - (1 - d.BannerHeight)) < 1e-6, ...
            sprintf('toolbar top %.6f must equal 1 - BannerHeight = %.6f', ...
                toolbarTop, 1 - d.BannerHeight));
        toolbarBot = toolbarPos(2);
        assert(abs(toolbarBot - (1 - d.BannerHeight - d.Toolbar.Height)) < 1e-6, ...
            sprintf('toolbar bottom %.6f must equal 1 - BannerHeight - Toolbar.Height = %.6f', ...
                toolbarBot, 1 - d.BannerHeight - d.Toolbar.Height));

        % Page bar sits below toolbar.
        pageBarTop = pageBarPos(2) + pageBarPos(4);
        assert(pageBarTop <= toolbarBot + 1e-6, ...
            sprintf('page-bar top %.6f must be <= toolbar bottom %.6f', ...
                pageBarTop, toolbarBot));

        % Content area must NOT extend into the reserved strip.
        ca = d.Layout.ContentArea;
        assert(ca(2) + ca(4) <= 1 - d.BannerHeight + 1e-6, ...
            sprintf('content area top %.6f must be <= 1 - BannerHeight = %.6f', ...
                ca(2) + ca(4), 1 - d.BannerHeight));

        % Banner visibility does NOT change content area (no overlay shrink).
        assert(isequal(d.Layout.ContentArea, caBefore), ...
            'ContentArea must be unchanged when banner is shown (reserved strip is permanent)');

        % Page bar still visible while banner is shown.
        assert(strcmp(get(d.hPageBar, 'Visible'), 'on'), ...
            'page bar must remain visible while banner is shown');

        d.hideStaleBanner();
        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testBannerInReservedStripAboveAllChrome: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testReservedStripStableWhenHidden
    %   Toggling the banner visibility must not shift toolbar, page bar,
    %   or content-area positions — the reserved strip is permanent.
    try
        d = DashboardEngine('ReservedStripStable');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        % Snapshot positions while banner is hidden.
        toolbarHidden = get(d.Toolbar.hPanel, 'Position');
        pageBarHidden = get(d.hPageBar,       'Position');
        caHidden      = d.Layout.ContentArea;
        bannerHidden  = get(d.hStaleBanner,   'Position');

        % Show then hide the banner.
        d.showStaleBanner({'A'});
        d.hideStaleBanner();

        % Positions must be byte-identical across the visibility toggle.
        assert(isequal(get(d.Toolbar.hPanel, 'Position'), toolbarHidden), ...
            'toolbar Position must be byte-identical after show/hide');
        assert(isequal(get(d.hPageBar, 'Position'), pageBarHidden), ...
            'page-bar Position must be byte-identical after show/hide');
        assert(isequal(d.Layout.ContentArea, caHidden), ...
            'Layout.ContentArea must be byte-identical after show/hide');

        % Reserved strip is parked at [0, 1 - BannerHeight, 1, BannerHeight]
        % even when Visible='off'.
        expected = [0, 1 - d.BannerHeight, 1, d.BannerHeight];
        assert(max(abs(bannerHidden - expected)) < 1e-9, ...
            sprintf('hidden banner Position [%g %g %g %g] must equal [0 %g 1 %g]', ...
                bannerHidden(1), bannerHidden(2), bannerHidden(3), bannerHidden(4), ...
                1 - d.BannerHeight, d.BannerHeight));

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testReservedStripStableWhenHidden: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testBannerHeightProperty
    %   BannerHeight is a public, readable property with a sane default.
    try
        d = DashboardEngine('BannerHeightProp');

        assert(isprop(d, 'BannerHeight'), ...
            'DashboardEngine must expose a BannerHeight property');
        assert(abs(d.BannerHeight - 0.035) < 1e-12, ...
            sprintf('default BannerHeight must be 0.035, got %.6f', d.BannerHeight));
        assert(d.BannerHeight > 0 && d.BannerHeight < 0.1, ...
            'BannerHeight must lie in (0, 0.1)');

        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testBannerHeightProperty: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
    if nFailed > 0
        error('test_dashboard_stale_banner:fail', ...
            '%d of %d tests failed', nFailed, nPassed + nFailed);
    end
end

function add_dashboard_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fullfile(thisDir, '..');
    addpath(repoRoot);
    install();
end
