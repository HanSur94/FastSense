function test_fastplot_theme()
%TEST_FASTPLOT_THEME Tests for FastPlot theme integration.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    % testThemeConstructorString
    fp = FastPlot('Theme', 'dark');
    assert(isstruct(fp.Theme), 'testThemeConstructorString: Theme must be struct');
    assert(all(fp.Theme.Background < [0.2 0.2 0.2]), 'testThemeConstructorString: dark bg');

    % testThemeConstructorStruct
    custom = struct('Background', [0.5 0.5 0.5]);
    fp = FastPlot('Theme', custom);
    assert(isequal(fp.Theme.Background, [0.5 0.5 0.5]), 'testThemeConstructorStruct');
    assert(isfield(fp.Theme, 'FontSize'), 'testThemeConstructorStruct: inherits defaults');

    % testDefaultThemeWhenNoneSpecified
    fp = FastPlot();
    assert(isstruct(fp.Theme), 'testDefaultTheme: must have theme');
    assert(isequal(fp.Theme.Background, [1 1 1]), 'testDefaultTheme: default bg');

    % testThemeAppliedOnRender
    fp = FastPlot('Theme', 'dark');
    fp.addLine(1:100, rand(1,100));
    fp.render();
    bgColor = get(fp.hFigure, 'Color');
    assert(all(bgColor < [0.2 0.2 0.2]), 'testThemeAppliedOnRender: figure bg');
    axColor = get(fp.hAxes, 'Color');
    assert(all(axColor < [0.25 0.25 0.25]), 'testThemeAppliedOnRender: axes bg');
    close(fp.hFigure);

    % testThemeFontApplied
    fp = FastPlot('Theme', 'scientific');
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(strcmp(get(fp.hAxes, 'FontName'), 'Times New Roman'), 'testThemeFontApplied');
    close(fp.hFigure);

    % testThemeWithParentAxes
    fig = figure('Visible', 'off');
    ax = axes('Parent', fig);
    fp = FastPlot('Parent', ax, 'Theme', 'dark');
    fp.addLine(1:100, rand(1,100));
    fp.render();
    axColor = get(ax, 'Color');
    assert(all(axColor < [0.25 0.25 0.25]), 'testThemeWithParentAxes: axes bg');
    close(fig);

    % testBackwardCompatNoTheme
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(ishandle(fp.hAxes), 'testBackwardCompatNoTheme');
    close(fp.hFigure);

    % testAutoColorCycling
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10));
    fp.addLine(1:10, rand(1,10));
    fp.addLine(1:10, rand(1,10));
    c1 = fp.Lines(1).Options.Color;
    c2 = fp.Lines(2).Options.Color;
    c3 = fp.Lines(3).Options.Color;
    assert(~isequal(c1, c2), 'testAutoColorCycling: colors 1 and 2 differ');
    assert(~isequal(c2, c3), 'testAutoColorCycling: colors 2 and 3 differ');

    % testExplicitColorSkipsCycle
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10), 'Color', [1 0 0]);
    fp.addLine(1:10, rand(1,10));
    assert(isequal(fp.Lines(1).Options.Color, [1 0 0]), 'testExplicitColorSkipsCycle: explicit');
    expected2 = fp.Theme.LineColorOrder(1, :);
    assert(isequal(fp.Lines(2).Options.Color, expected2), 'testExplicitColorSkipsCycle: auto gets first');

    fprintf('    All 9 theme integration tests passed.\n');
end
