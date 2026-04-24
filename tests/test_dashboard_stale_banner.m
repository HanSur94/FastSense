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
