function test_figure_layout()
%TEST_FIGURE_LAYOUT Tests for FastPlotFigure layout manager.

    run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));
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

    fprintf('    All 12 figure layout tests passed.\n');
end
