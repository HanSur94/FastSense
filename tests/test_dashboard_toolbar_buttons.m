function test_dashboard_toolbar_buttons()
%TEST_DASHBOARD_TOOLBAR_BUTTONS Octave parallel suite for mandatory info btn,
%   live-mode blue border, and tooltips on all toolbar buttons.

    add_dashboard_path();

    nPassed = 0;
    nFailed = 0;

    % Info button is mandatory even without InfoFile
    try
        d = DashboardEngine('NoInfoBtnTest');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');
        assert(~isempty(d.Toolbar.hInfoBtn), ...
            'info button should exist when no InfoFile is set');
        assert(ishandle(d.Toolbar.hInfoBtn), ...
            'info button should be a valid handle');
        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testInfoButtonMandatory: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % showInfo produces a placeholder HTML when InfoFile is empty
    try
        d = DashboardEngine('PlaceholderTest');
        d.showInfo();
        assert(~isempty(d.InfoTempFile), 'temp file should be set');
        assert(exist(d.InfoTempFile, 'file') == 2, 'temp file should exist');
        html = fileread(d.InfoTempFile);
        assert(~isempty(strfind(html, 'PlaceholderTest')), ...
            'placeholder should embed dashboard name');
        assert(~isempty(strfind(html, 'InfoFile')), ...
            'placeholder should reference InfoFile');
        d.cleanupInfoTempFile();
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testShowInfoPlaceholder: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % Every toolbar button has a non-empty TooltipString
    try
        d = DashboardEngine('TooltipTest');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');
        handles = {d.Toolbar.hLiveBtn, ...
            d.Toolbar.hSaveBtn, d.Toolbar.hImageBtn, ...
            d.Toolbar.hExportBtn, d.Toolbar.hSyncBtn, ...
            d.Toolbar.hInfoBtn};
        names = {'Live', 'Save', 'Image', 'Export', 'Sync', 'Info'};
        for i = 1:numel(handles)
            tip = get(handles{i}, 'TooltipString');
            assert(~isempty(tip), ...
                sprintf('button %s missing tooltip', names{i}));
        end
        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testTooltipsPresent: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % Live button panel border turns blue when live mode is toggled on
    try
        d = DashboardEngine('LiveBorderTest');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        assert(~isempty(d.Toolbar.hLivePanel), 'live panel should exist');

        themeStruct = d.getCachedTheme();
        offColor = get(d.Toolbar.hLivePanel, 'HighlightColor');
        assert(max(abs(offColor - themeStruct.ToolbarBackground)) < 1e-6, ...
            'live border should match toolbar bg when off');

        % Exercise the indicator directly (Octave has no timer, so we
        % avoid onLiveToggle's startLive() path and test the visual
        % mechanism in isolation).
        d.Toolbar.setLiveActiveIndicator(true);
        onColor = get(d.Toolbar.hLivePanel, 'HighlightColor');
        assert(max(abs(onColor - themeStruct.InfoColor)) < 1e-6, ...
            'live border should be InfoColor (blue) when on');

        d.Toolbar.setLiveActiveIndicator(false);
        offAgain = get(d.Toolbar.hLivePanel, 'HighlightColor');
        assert(max(abs(offAgain - themeStruct.ToolbarBackground)) < 1e-6, ...
            'live border should clear when toggled back off');

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testLiveBorder: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
    if nFailed > 0
        error('test_dashboard_toolbar_buttons:fail', ...
            '%d of %d tests failed', nFailed, nPassed + nFailed);
    end
end

function add_dashboard_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fullfile(thisDir, '..');
    addpath(repoRoot);
    install();
end
