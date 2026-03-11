function test_figure_layout()
%TEST_FIGURE_LAYOUT Tests for FastPlotFigure layout manager.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
    add_fastplot_private_path();

    % testConstruction
    fig = FastPlotFigure(2, 3);
    assert(isequal(fig.Grid, [2 3]), 'testConstruction: Grid');
    assert(~isempty(fig.hFigure), 'testConstruction: hFigure');
    assert(ishandle(fig.hFigure), 'testConstruction: hFigure valid');
    close(fig.hFigure);

    % testTileReturnsFastPlot
    fig = FastPlotFigure(2, 1);
    fp = fig.tile(1);
    assert(isa(fp, 'FastPlot'), 'testTileReturnsFastPlot');
    close(fig.hFigure);

    % testTileLazy
    fig = FastPlotFigure(2, 1);
    fp1a = fig.tile(1);
    fp1b = fig.tile(1);
    % In Octave, handle == isn't always defined; check axes handle identity
    fp1a.addLine(1:10, rand(1,10));
    assert(numel(fp1b.Lines) == 1, 'testTileLazy: same object on repeat call');
    close(fig.hFigure);

    % testTileCreatesAxes
    fig = FastPlotFigure(2, 1);
    fp = fig.tile(1);
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(~isempty(fp.hAxes), 'testTileCreatesAxes: axes exist');
    assert(ishandle(fp.hAxes), 'testTileCreatesAxes: axes valid');
    close(fig.hFigure);

    % testMultipleTiles
    fig = FastPlotFigure(2, 2);
    for i = 1:4
        fp = fig.tile(i);
        fp.addLine(1:50, rand(1,50));
    end
    fig.renderAll();
    for i = 1:4
        fp = fig.tile(i);
        assert(fp.IsRendered, sprintf('testMultipleTiles: tile %d rendered', i));
    end
    close(fig.hFigure);

    % testRenderAllSkipsRendered
    fig = FastPlotFigure(2, 1);
    fp1 = fig.tile(1);
    fp1.addLine(1:10, rand(1,10));
    fp1.render();
    fp2 = fig.tile(2);
    fp2.addLine(1:10, rand(1,10));
    fig.renderAll();  % should not error on already-rendered tile 1
    assert(fp2.IsRendered, 'testRenderAllSkipsRendered: tile 2');
    close(fig.hFigure);

    % testOutOfBoundsTileErrors
    fig = FastPlotFigure(2, 2);
    threw = false;
    try
        fig.tile(5);  % only 4 tiles in 2x2
    catch
        threw = true;
    end
    assert(threw, 'testOutOfBoundsTileErrors');
    close(fig.hFigure);

    % testTileSpanning
    fig = FastPlotFigure(2, 2);
    fig.setTileSpan(1, [1 2]);  % tile 1 spans both columns
    fp1 = fig.tile(1);
    fp1.addLine(1:50, rand(1,50));
    fp1.render();
    pos = get(fp1.hAxes, 'Position');
    % Spanning tile should be wider than half the figure
    assert(pos(3) > 0.4, 'testTileSpanning: wide enough');
    close(fig.hFigure);

    % testFigureThemePassedToTiles
    fig = FastPlotFigure(2, 1, 'Theme', 'dark');
    fp = fig.tile(1);
    assert(all(fp.Theme.Background < [0.2 0.2 0.2]), 'testFigureThemePassedToTiles');
    close(fig.hFigure);

    % testTileThemeOverride
    fig = FastPlotFigure(2, 1, 'Theme', 'dark');
    fig.setTileTheme(1, struct('AxesColor', [0.3 0 0]));
    fp = fig.tile(1);
    assert(isequal(fp.Theme.AxesColor, [0.3 0 0]), 'testTileThemeOverride: AxesColor');
    assert(all(fp.Theme.Background < [0.2 0.2 0.2]), 'testTileThemeOverride: inherits bg');
    close(fig.hFigure);

    % testFigureProperties
    fig = FastPlotFigure(1, 1, 'Name', 'MyDash', 'Position', [50 50 800 600]);
    name = get(fig.hFigure, 'Name');
    assert(strcmp(name, 'MyDash'), 'testFigureProperties: Name');
    close(fig.hFigure);

    % testTileLabels
    fig = FastPlotFigure(2, 1);
    fp = fig.tile(1);
    fp.addLine(1:50, rand(1,50));
    fp.render();
    fig.tileTitle(1, 'My Title');
    fig.tileYLabel(1, 'Y Axis');
    fig.tileXLabel(1, 'X Axis');
    % No error = pass
    close(fig.hFigure);

    % testAxesReturnsRawAxes
    fig = FastPlotFigure(2, 2);
    ax = fig.axes(1);
    assert(ishandle(ax), 'testAxesReturnsRawAxes: valid handle');
    assert(strcmp(get(ax, 'Type'), 'axes'), 'testAxesReturnsRawAxes: is axes');
    close(fig.hFigure);

    % testAxesLazy
    fig = FastPlotFigure(2, 1);
    ax1 = fig.axes(1);
    ax2 = fig.axes(1);
    assert(isequal(ax1, ax2), 'testAxesLazy: same handle on repeat call');
    close(fig.hFigure);

    % testTileThenAxesErrors
    fig = FastPlotFigure(2, 1);
    fig.tile(1);
    threw = false;
    try
        fig.axes(1);
    catch
        threw = true;
    end
    assert(threw, 'testTileThenAxesErrors');
    close(fig.hFigure);

    % testAxesThenTileErrors
    fig = FastPlotFigure(2, 1);
    fig.axes(1);
    threw = false;
    try
        fig.tile(1);
    catch
        threw = true;
    end
    assert(threw, 'testAxesThenTileErrors');
    close(fig.hFigure);

    % testMixedRenderAll
    fig = FastPlotFigure(2, 2);
    fig.tile(1).addLine(1:50, rand(1,50));
    ax2 = fig.axes(2); bar(ax2, [1 2 3], [10 20 15]);
    fig.tile(3).addLine(1:50, rand(1,50));
    ax4 = fig.axes(4); plot(ax4, 1:10, rand(1,10));
    fig.renderAll();
    assert(fig.tile(1).IsRendered, 'testMixedRenderAll: tile 1 rendered');
    assert(fig.tile(3).IsRendered, 'testMixedRenderAll: tile 3 rendered');
    % Raw axes tiles should still have valid handles
    assert(ishandle(ax2), 'testMixedRenderAll: ax2 valid');
    assert(ishandle(ax4), 'testMixedRenderAll: ax4 valid');
    close(fig.hFigure);

    % testAxesThemeApplied
    fig = FastPlotFigure(1, 1, 'Theme', 'dark');
    ax = fig.axes(1);
    bgColor = get(ax, 'Color');
    assert(all(bgColor < [0.3 0.3 0.3]), 'testAxesThemeApplied: dark background');
    close(fig.hFigure);

    % testLabelsOnRawAxes
    fig = FastPlotFigure(2, 1);
    ax = fig.axes(1);
    bar(ax, [1 2 3], [10 20 15]);
    fig.tileTitle(1, 'Bar Chart');
    fig.tileXLabel(1, 'Category');
    fig.tileYLabel(1, 'Value');
    % No error = pass; verify title text
    titleObj = get(ax, 'Title');
    assert(strcmp(get(titleObj, 'String'), 'Bar Chart'), 'testLabelsOnRawAxes: title');
    close(fig.hFigure);

    % testAxesOutOfBounds
    fig = FastPlotFigure(2, 2);
    threw = false;
    try
        fig.axes(5);
    catch
        threw = true;
    end
    assert(threw, 'testAxesOutOfBounds');
    close(fig.hFigure);

    % testAxesTileSpanning
    fig = FastPlotFigure(2, 2);
    fig.setTileSpan(1, [1 2]);
    ax = fig.axes(1);
    pos = get(ax, 'Position');
    assert(pos(3) > 0.4, 'testAxesTileSpanning: wide enough');
    close(fig.hFigure);

    fprintf('    All 21 figure layout tests passed.\n');
end
