function test_fastsense_theme()
%TEST_FASTSENSE_THEME Tests for FastSense theme integration.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();
    add_fastsense_private_path();

    % testThemeConstructorString
    fp = FastSense('Theme', 'dark');
    assert(isstruct(fp.Theme), 'testThemeConstructorString: Theme must be struct');
    assert(all(fp.Theme.Background < [0.2 0.2 0.2]), 'testThemeConstructorString: dark bg');

    % testThemeConstructorStruct
    custom = struct('Background', [0.5 0.5 0.5]);
    fp = FastSense('Theme', custom);
    assert(isequal(fp.Theme.Background, [0.5 0.5 0.5]), 'testThemeConstructorStruct');
    assert(isfield(fp.Theme, 'FontSize'), 'testThemeConstructorStruct: inherits defaults');

    % testDefaultThemeWhenNoneSpecified — default is now 'light'
    fp = FastSense();
    assert(isstruct(fp.Theme), 'testDefaultTheme: must have theme');
    assert(all(fp.Theme.Background > [0.9 0.9 0.9]), 'testDefaultTheme: default bg is light');

    % testThemeAppliedOnRender
    fp = FastSense('Theme', 'dark');
    fp.addLine(1:100, rand(1,100));
    fp.render();
    bgColor = get(fp.hFigure, 'Color');
    assert(all(bgColor < [0.2 0.2 0.2]), 'testThemeAppliedOnRender: figure bg');
    axColor = get(fp.hAxes, 'Color');
    assert(all(axColor < [0.25 0.25 0.25]), 'testThemeAppliedOnRender: axes bg');
    close(fp.hFigure);

    % testLegacyPresetAliasedToLight — 'scientific' was removed; it now aliases to 'light'
    fp = FastSense('Theme', 'scientific');
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(all(get(fp.hFigure, 'Color') > [0.9 0.9 0.9]), 'testLegacyPresetAliased: scientific -> light');
    close(fp.hFigure);

    % testThemeWithParentAxes
    fig = figure('Visible', 'off');
    ax = axes('Parent', fig);
    fp = FastSense('Parent', ax, 'Theme', 'dark');
    fp.addLine(1:100, rand(1,100));
    fp.render();
    axColor = get(ax, 'Color');
    assert(all(axColor < [0.25 0.25 0.25]), 'testThemeWithParentAxes: axes bg');
    close(fig);

    % testBackwardCompatNoTheme
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(ishandle(fp.hAxes), 'testBackwardCompatNoTheme');
    close(fp.hFigure);

    % testAutoColorCycling
    fp = FastSense();
    fp.addLine(1:10, rand(1,10));
    fp.addLine(1:10, rand(1,10));
    fp.addLine(1:10, rand(1,10));
    c1 = fp.Lines(1).Options.Color;
    c2 = fp.Lines(2).Options.Color;
    c3 = fp.Lines(3).Options.Color;
    assert(~isequal(c1, c2), 'testAutoColorCycling: colors 1 and 2 differ');
    assert(~isequal(c2, c3), 'testAutoColorCycling: colors 2 and 3 differ');

    % testExplicitColorSkipsCycle
    fp = FastSense();
    fp.addLine(1:10, rand(1,10), 'Color', [1 0 0]);
    fp.addLine(1:10, rand(1,10));
    assert(isequal(fp.Lines(1).Options.Color, [1 0 0]), 'testExplicitColorSkipsCycle: explicit');
    expected2 = fp.Theme.LineColorOrder(1, :);
    assert(isequal(fp.Lines(2).Options.Color, expected2), 'testExplicitColorSkipsCycle: auto gets first');

    % testThresholdUsesThemeDefaults
    fp = FastSense('Theme', struct('ThresholdColor', [0 1 0], 'ThresholdStyle', ':'));
    fp.addThreshold(5.0);
    assert(isequal(fp.Thresholds(1).Color, [0 1 0]), 'testThresholdThemeDefaults: Color');
    assert(strcmp(fp.Thresholds(1).LineStyle, ':'), 'testThresholdThemeDefaults: Style');

    % testThresholdExplicitOverridesTheme
    fp = FastSense('Theme', struct('ThresholdColor', [0 1 0]));
    fp.addThreshold(5.0, 'Color', [1 0 0]);
    assert(isequal(fp.Thresholds(1).Color, [1 0 0]), 'testThresholdOverride: Color');

    fprintf('    All 11 theme integration tests passed.\n');
end
