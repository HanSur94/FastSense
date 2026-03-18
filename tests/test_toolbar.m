function test_toolbar()
%TEST_TOOLBAR Tests for FastSenseToolbar class.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); setup();
    add_fastsense_private_path();

    close all force;
    drawnow;

    % testConstructorWithFastSense
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastSenseToolbar(fp);
    assert(~isempty(tb.hToolbar), 'testConstructorWithFastSense: hToolbar');
    assert(ishandle(tb.hToolbar), 'testConstructorWithFastSense: ishandle');
    close(fp.hFigure);

    % testConstructorWithFastSenseGrid
    fig = FastSenseGrid(1, 2);
    fp1 = fig.tile(1); fp1.addLine(1:100, rand(1,100));
    fp2 = fig.tile(2); fp2.addLine(1:100, rand(1,100));
    fig.renderAll();
    tb = FastSenseToolbar(fig);
    assert(~isempty(tb.hToolbar), 'testConstructorWithFPFigure: hToolbar');
    close(fig.hFigure);

    % testToolbarHasAllButtons (cursor, crosshair, grid, legend, autoscale, export, refresh, live, metadata, theme)
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastSenseToolbar(fp);
    children = get(tb.hToolbar, 'Children');
    assert(numel(children) == 11, ...
        sprintf('testToolbarHasAllButtons: got %d', numel(children)));
    close(fp.hFigure);

    % testIconsAre16x16x3
    icons = FastSenseToolbar.makeIcon('grid');
    assert(isequal(size(icons), [16 16 3]), 'testIconsAre16x16x3');

    % testAllIconNames
    names = {'cursor', 'crosshair', 'grid', 'legend', 'autoscale', 'export', 'violations'};
    for i = 1:numel(names)
        icon = FastSenseToolbar.makeIcon(names{i});
        assert(isequal(size(icon), [16 16 3]), ...
            sprintf('testAllIconNames: %s', names{i}));
    end

    % testToggleGrid
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastSenseToolbar(fp);
    gridBefore = get(fp.hAxes, 'XGrid');
    tb.toggleGrid();
    gridAfter = get(fp.hAxes, 'XGrid');
    assert(~strcmp(gridBefore, gridAfter), 'testToggleGrid: should toggle');
    close(fp.hFigure);

    % testToggleLegend
    fp = FastSense();
    fp.addLine(1:100, rand(1,100), 'DisplayName', 'TestLine');
    fp.render();
    tb = FastSenseToolbar(fp);
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
    fp = FastSense();
    y = [zeros(1,50), 10*ones(1,50)];
    fp.addLine(1:100, y);
    fp.render();
    tb = FastSenseToolbar(fp);
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
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastSenseToolbar(fp);
    tmpFile = [tempname, '.png'];
    tb.exportPNG(tmpFile);
    assert(exist(tmpFile, 'file') == 2, 'testExportPNG: file should exist');
    delete(tmpFile);
    close(fp.hFigure);

    % testCrosshairMode
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastSenseToolbar(fp);
    assert(strcmp(tb.Mode, 'none'), 'testCrosshairMode: initial mode');
    tb.setCrosshair(true);
    assert(strcmp(tb.Mode, 'crosshair'), 'testCrosshairMode: on');
    tb.setCrosshair(false);
    assert(strcmp(tb.Mode, 'none'), 'testCrosshairMode: off');
    close(fp.hFigure);

    % testCrosshairMutualExclusion
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastSenseToolbar(fp);
    tb.setCursor(true);
    assert(strcmp(tb.Mode, 'cursor'), 'testMutualExcl: cursor on');
    tb.setCrosshair(true);
    assert(strcmp(tb.Mode, 'crosshair'), 'testMutualExcl: crosshair replaces cursor');
    assert(strcmp(get(tb.hCursorBtn, 'State'), 'off'), 'testMutualExcl: cursor btn off');
    close(fp.hFigure);

    % testCursorMode
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastSenseToolbar(fp);
    tb.setCursor(true);
    assert(strcmp(tb.Mode, 'cursor'), 'testCursorMode: on');
    tb.setCursor(false);
    assert(strcmp(tb.Mode, 'none'), 'testCursorMode: off');
    close(fp.hFigure);

    % testSnapToNearest
    fp = FastSense();
    fp.addLine([1 2 3 4 5], [10 20 30 40 50]);
    fp.render();
    tb = FastSenseToolbar(fp);
    [sx, sy, ~] = tb.snapToNearest(fp, 2.8, 25);
    assert(sx == 3, sprintf('testSnapToNearest: x should be 3, got %g', sx));
    assert(sy == 30, sprintf('testSnapToNearest: y should be 30, got %g', sy));
    close(fp.hFigure);

    % testViolationsToggle
    fp = FastSense();
    fp.addLine(1:100, [ones(1,50)*2, ones(1,50)*8]);
    fp.addThreshold(5, 'Direction', 'upper', 'ShowViolations', true);
    fp.render();
    tb = FastSenseToolbar(fp);
    % Violations should be visible initially
    assert(fp.ViolationsVisible, 'testViolationsToggle: default true');
    hM = fp.Thresholds(1).hMarkers;
    assert(strcmp(get(hM, 'Visible'), 'on'), 'testViolationsToggle: markers visible');
    % Toggle off via toolbar callback
    tb.setViolationsVisible(false);
    assert(~fp.ViolationsVisible, 'testViolationsToggle: now false');
    assert(strcmp(get(hM, 'Visible'), 'off'), 'testViolationsToggle: markers hidden');
    % Toggle back on
    tb.setViolationsVisible(true);
    assert(strcmp(get(hM, 'Visible'), 'on'), 'testViolationsToggle: markers back');
    close(fp.hFigure);

    fprintf('    All 14 toolbar tests passed.\n');
end
