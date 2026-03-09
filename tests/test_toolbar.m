function test_toolbar()
%TEST_TOOLBAR Tests for FastPlotToolbar class.

    add_private_path();

    close all force;
    drawnow;

    % testConstructorWithFastPlot
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastPlotToolbar(fp);
    assert(~isempty(tb.hToolbar), 'testConstructorWithFastPlot: hToolbar');
    assert(ishandle(tb.hToolbar), 'testConstructorWithFastPlot: ishandle');
    close(fp.hFigure);

    % testConstructorWithFastPlotFigure
    fig = FastPlotFigure(1, 2);
    fp1 = fig.tile(1); fp1.addLine(1:100, rand(1,100));
    fp2 = fig.tile(2); fp2.addLine(1:100, rand(1,100));
    fig.renderAll();
    tb = FastPlotToolbar(fig);
    assert(~isempty(tb.hToolbar), 'testConstructorWithFPFigure: hToolbar');
    close(fig.hFigure);

    % testToolbarHasSixButtons
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastPlotToolbar(fp);
    children = get(tb.hToolbar, 'Children');
    assert(numel(children) == 9, ...
        sprintf('testToolbarHasNineButtons: got %d', numel(children)));
    close(fp.hFigure);

    % testIconsAre16x16x3
    icons = FastPlotToolbar.makeIcon('grid');
    assert(isequal(size(icons), [16 16 3]), 'testIconsAre16x16x3');

    % testAllIconNames
    names = {'cursor', 'crosshair', 'grid', 'legend', 'autoscale', 'export', 'refresh', 'live', 'metadata', 'theme'};
    for i = 1:numel(names)
        icon = FastPlotToolbar.makeIcon(names{i});
        assert(isequal(size(icon), [16 16 3]), ...
            sprintf('testAllIconNames: %s', names{i}));
    end

    % testIconCaching
    icon1 = FastPlotToolbar.makeIcon('grid');
    icon2 = FastPlotToolbar.makeIcon('grid');
    assert(isequal(icon1, icon2), 'testIconCaching: cached icon should match');

    % testToggleGrid
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastPlotToolbar(fp);
    gridBefore = get(fp.hAxes, 'XGrid');
    tb.toggleGrid();
    gridAfter = get(fp.hAxes, 'XGrid');
    assert(~strcmp(gridBefore, gridAfter), 'testToggleGrid: should toggle');
    close(fp.hFigure);

    % testToggleLegend
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100), 'DisplayName', 'TestLine');
    fp.render();
    tb = FastPlotToolbar(fp);
    tb.toggleLegend();
    hLeg = findobj(fp.hFigure, 'Type', 'axes', 'Tag', 'legend');
    if isempty(hLeg)
        hLeg = legend(fp.hAxes);
    end
    vis1 = get(hLeg, 'Visible');
    tb.toggleLegend();
    vis2 = get(hLeg, 'Visible');
    assert(~strcmp(vis1, vis2), 'testToggleLegend: should toggle');
    close(fp.hFigure);

    % testAutoscaleY
    fp = FastPlot();
    y = [zeros(1,50), 10*ones(1,50)];
    fp.addLine(1:100, y);
    fp.render();
    tb = FastPlotToolbar(fp);
    % Zoom into first half (all zeros)
    set(fp.hAxes, 'XLim', [1 50]);
    drawnow;
    tb.autoscaleY();
    ylims = get(fp.hAxes, 'YLim');
    % Y range should be tight around 0, not spanning 0-10
    assert(ylims(2) < 5, ...
        sprintf('testAutoscaleY: YLim(2) should be < 5, got %.1f', ylims(2)));
    close(fp.hFigure);

    % testExportPNG
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastPlotToolbar(fp);
    tmpFile = [tempname, '.png'];
    tb.exportPNG(tmpFile);
    assert(exist(tmpFile, 'file') == 2, 'testExportPNG: file should exist');
    delete(tmpFile);
    close(fp.hFigure);

    % testCrosshairMode
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastPlotToolbar(fp);
    assert(strcmp(tb.Mode, 'none'), 'testCrosshairMode: initial mode');
    tb.setCrosshair(true);
    assert(strcmp(tb.Mode, 'crosshair'), 'testCrosshairMode: on');
    tb.setCrosshair(false);
    assert(strcmp(tb.Mode, 'none'), 'testCrosshairMode: off');
    close(fp.hFigure);

    % testCrosshairMutualExclusion
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastPlotToolbar(fp);
    tb.setCursor(true);
    assert(strcmp(tb.Mode, 'cursor'), 'testMutualExcl: cursor on');
    tb.setCrosshair(true);
    assert(strcmp(tb.Mode, 'crosshair'), 'testMutualExcl: crosshair replaces cursor');
    assert(strcmp(get(tb.hCursorBtn, 'State'), 'off'), 'testMutualExcl: cursor btn off');
    close(fp.hFigure);

    % testCursorMode
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastPlotToolbar(fp);
    tb.setCursor(true);
    assert(strcmp(tb.Mode, 'cursor'), 'testCursorMode: on');
    tb.setCursor(false);
    assert(strcmp(tb.Mode, 'none'), 'testCursorMode: off');
    close(fp.hFigure);

    % testSnapToNearest
    fp = FastPlot();
    fp.addLine([1 2 3 4 5], [10 20 30 40 50]);
    fp.render();
    tb = FastPlotToolbar(fp);
    [sx, sy, ~] = tb.snapToNearest(fp, 2.8, 25);
    assert(sx == 3, sprintf('testSnapToNearest: x should be 3, got %g', sx));
    assert(sy == 30, sprintf('testSnapToNearest: y should be 30, got %g', sy));
    close(fp.hFigure);

    testToolbarRefreshButton();
    testToolbarLiveToggle();

    fprintf('    All 16 toolbar tests passed.\n');
end

function testToolbarRefreshButton()
    fp = FastPlot();
    fp.addLine(1:100, zeros(1,100));
    fp.render();

    tmpFile = [tempname, '.mat'];
    s.x = 1:100; s.y = ones(1,100) * 7;
    save(tmpFile, '-struct', 's');

    fp.LiveFile = tmpFile;
    fp.LiveUpdateFcn = @(fp, d) fp.updateData(1, d.x, d.y);

    tb = FastPlotToolbar(fp);
    tb.refresh();

    assert(all(fp.Lines(1).Y == 7), 'testToolbarRefresh: data should be 7');
    close(fp.hFigure);
    delete(tmpFile);
end

function testToolbarLiveToggle()
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();

    tmpFile = [tempname, '.mat'];
    s.x = 1:100; s.y = rand(1,100);
    save(tmpFile, '-struct', 's');

    fp.LiveFile = tmpFile;
    fp.LiveUpdateFcn = @(fp, d) fp.updateData(1, d.x, d.y);

    tb = FastPlotToolbar(fp);
    tb.toggleLive();
    assert(fp.LiveIsActive, 'testToolbarLive: should be active after toggle on');
    tb.toggleLive();
    assert(~fp.LiveIsActive, 'testToolbarLive: should be inactive after toggle off');

    close(fp.hFigure);
    delete(tmpFile);
end
