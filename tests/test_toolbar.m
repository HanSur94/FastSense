function test_toolbar()
%TEST_TOOLBAR Tests for FastSenseToolbar class.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();
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
    assert(numel(children) == 12, ...
        sprintf('testToolbarHasAllButtons: got %d', numel(children)));
    close(fp.hFigure);

    % testIconsAre16x16x3
    icons = FastSenseToolbar.makeIcon('grid');
    assert(isequal(size(icons), [16 16 3]), 'testIconsAre16x16x3');

    % testAllIconNames
    names = {'cursor', 'crosshair', 'grid', 'legend', 'autoscale', 'export', 'exportdata', 'violations'};
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

    % testExportCSV
    fp = FastSense();
    fp.addLine([1 2 3 4 5], [10 20 30 40 50], 'DisplayName', 'Temp');
    fp.render();
    tmpFile = [tempname, '.csv'];
    fp.exportData(tmpFile, 'csv');
    assert(exist(tmpFile, 'file') == 2, 'testExportCSV: file should exist');
    fid = fopen(tmpFile, 'r');
    header = fgetl(fid);
    fclose(fid);
    assert(~isempty(strfind(header, 'time')), 'testExportCSV: header has time');
    assert(~isempty(strfind(header, 'Temp')), 'testExportCSV: header has DisplayName');
    delete(tmpFile);
    close(fp.hFigure);

    % testExportMAT
    fp = FastSense();
    fp.addLine([1 2 3], [10 20 30], 'DisplayName', 'Pressure');
    fp.addThreshold(25, 'Direction', 'upper', 'Label', 'High');
    fp.render();
    tmpFile = [tempname, '.mat'];
    fp.exportData(tmpFile, 'mat');
    assert(exist(tmpFile, 'file') == 2, 'testExportMAT: file should exist');
    S = load(tmpFile);
    assert(isfield(S, 'lines'), 'testExportMAT: has lines');
    assert(isfield(S, 'thresholds'), 'testExportMAT: has thresholds');
    assert(numel(S.lines) == 1, 'testExportMAT: one line');
    assert(strcmp(S.lines(1).Name, 'Pressure'), 'testExportMAT: line name');
    assert(S.thresholds(1).Value == 25, 'testExportMAT: threshold value');
    assert(strcmp(S.thresholds(1).Direction, 'upper'), 'testExportMAT: threshold dir');
    delete(tmpFile);
    close(fp.hFigure);

    % testExportCSVMismatchedX
    fp = FastSense();
    fp.addLine([1 2 3], [10 20 30], 'DisplayName', 'A');
    fp.addLine([2 3 4], [40 50 60], 'DisplayName', 'B');
    fp.render();
    tmpFile = [tempname, '.csv'];
    fp.exportData(tmpFile, 'csv');
    fid = fopen(tmpFile, 'r');
    header = fgetl(fid);
    lines = {};
    while true
        L = fgetl(fid);
        if isequal(L, -1); break; end
        if L(1) == '#'; continue; end
        lines{end+1} = L;
    end
    fclose(fid);
    % Should have 4 rows: x=1,2,3,4 (union)
    assert(numel(lines) == 4, sprintf('testExportCSVMismatchedX: expected 4 rows, got %d', numel(lines)));
    % First row (x=1): A has value, B should be NaN
    vals1 = strsplit(lines{1}, ',');
    assert(strcmp(vals1{3}, 'NaN'), 'testExportCSVMismatchedX: B is NaN at x=1');
    % Last row (x=4): A should be NaN, B has value
    vals4 = strsplit(lines{4}, ',');
    assert(strcmp(vals4{2}, 'NaN'), 'testExportCSVMismatchedX: A is NaN at x=4');
    delete(tmpFile);
    close(fp.hFigure);

    % testExportCSVDatetime (MATLAB only — datetime not in Octave base)
    if ~exist('OCTAVE_VERSION', 'builtin')
        fp = FastSense();
        t = datetime(2024, 1, 1) + hours(0:2);
        fp.addLine(t, [1 2 3], 'DisplayName', 'Sensor');
        fp.render();
        tmpFile = [tempname, '.csv'];
        fp.exportData(tmpFile, 'csv');
        fid = fopen(tmpFile, 'r');
        header = fgetl(fid);
        fclose(fid);
        assert(~isempty(strfind(header, 'time_datenum')), 'testExportCSVDatetime: has time_datenum');
        assert(~isempty(strfind(header, 'time_iso8601')), 'testExportCSVDatetime: has time_iso8601');
        delete(tmpFile);
        close(fp.hFigure);
    end

    % testExportNoLines
    fp = FastSense();
    tmpFile = [tempname, '.csv'];
    threw = false;
    try
        fp.exportData(tmpFile, 'csv');
    catch e
        threw = true;
        assert(strcmp(e.identifier, 'FastSense:exportData:noLines'), ...
            sprintf('testExportNoLines: wrong ID: %s', e.identifier));
    end
    assert(threw, 'testExportNoLines: should have thrown');

    fprintf('    All 19 toolbar tests passed.\n');
end
