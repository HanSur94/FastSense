function test_live()
%TEST_LIVE Tests for live mode functionality.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    close all force;
    drawnow;

    testUpdateDataReplacesLineData();
    testUpdateDataRedownsamples();
    testUpdateDataUpdatesViolations();
    testUpdateDataDifferentLength();
    testUpdateDataInvalidIndex();
    testStartLiveSetsProperties();
    testStopLiveClearsTimer();
    testRefreshLoadsFile();
    testSetViewMode();
    testStartLiveRequiresRender();
    testRunLiveExitsWhenNotActive();
    testFigureStartLive();
    testFigureStopLive();
    testFigureRefresh();
    testFigureRunLiveExitsWhenNotActive();

    fprintf('    All 15 live mode tests passed.\n');
end

function testUpdateDataReplacesLineData()
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100), 'DisplayName', 'A');
    fp.addLine(1:100, rand(1,100), 'DisplayName', 'B');
    fp.render();

    newX = 1:200;
    newY = rand(1,200);
    fp.updateData(1, newX, newY);

    assert(isequal(fp.Lines(1).X, newX), 'updateData: X not replaced');
    assert(isequal(fp.Lines(1).Y, newY), 'updateData: Y not replaced');
    % Line 2 should be untouched
    assert(numel(fp.Lines(2).X) == 100, 'updateData: line 2 should be untouched');
    close(fp.hFigure);
end

function testUpdateDataRedownsamples()
    fp = FastPlot();
    n = 100000;
    fp.addLine(linspace(0,100,n), rand(1,n));
    fp.render();

    newN = 200000;
    fp.updateData(1, linspace(0,200,newN), rand(1,newN));

    displayed = numel(get(fp.Lines(1).hLine, 'XData'));
    assert(displayed < newN, 'updateData: should downsample after update');
    assert(displayed > 0, 'updateData: should have some displayed points');
    close(fp.hFigure);
end

function testUpdateDataUpdatesViolations()
    fp = FastPlot();
    fp.addLine(1:1000, zeros(1,1000));
    fp.addThreshold(5, 'Direction', 'upper', 'ShowViolations', true);
    fp.render();

    % Initially no violations
    vx = get(fp.Thresholds(1).hMarkers, 'XData');
    vx = vx(~isnan(vx));
    assert(numel(vx) == 0, 'updateData violations: should start with 0');

    % Update with data that has violations
    newY = [zeros(1,500), 10*ones(1,500)];
    fp.updateData(1, 1:1000, newY);

    vx = get(fp.Thresholds(1).hMarkers, 'XData');
    vx = vx(~isnan(vx));
    assert(numel(vx) > 0, 'updateData violations: should show violations after update');
    close(fp.hFigure);
end

function testUpdateDataDifferentLength()
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();

    % Shorter data
    fp.updateData(1, 1:50, rand(1,50));
    assert(numel(fp.Lines(1).X) == 50, 'updateData shorter: X length');

    % Longer data
    fp.updateData(1, 1:500, rand(1,500));
    assert(numel(fp.Lines(1).X) == 500, 'updateData longer: X length');
    close(fp.hFigure);
end

function testUpdateDataInvalidIndex()
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();

    threw = false;
    try
        fp.updateData(5, 1:100, rand(1,100));
    catch e
        threw = true;
        assert(~isempty(strfind(e.message, 'out of range')), 'Wrong error msg');
    end
    assert(threw, 'updateData: should throw for invalid index');
    close(fp.hFigure);
end

function testStartLiveSetsProperties()
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();

    tmpFile = [tempname, '.mat'];
    s.x = 1:100; s.y = rand(1,100);
    save(tmpFile, '-struct', 's');

    updateFcn = @(fp, data) fp.updateData(1, data.x, data.y);
    fp.startLive(tmpFile, updateFcn, 'Interval', 3, 'ViewMode', 'preserve');

    assert(fp.LiveIsActive, 'startLive: should be active');
    assert(strcmp(fp.LiveFile, tmpFile), 'startLive: file path');
    assert(fp.LiveInterval == 3, 'startLive: interval');
    assert(strcmp(fp.LiveViewMode, 'preserve'), 'startLive: view mode');

    fp.stopLive();
    close(fp.hFigure);
    delete(tmpFile);
end

function testStopLiveClearsTimer()
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();

    tmpFile = [tempname, '.mat'];
    s.x = 1:100; s.y = rand(1,100);
    save(tmpFile, '-struct', 's');

    fp.startLive(tmpFile, @(fp, d) fp.updateData(1, d.x, d.y));
    fp.stopLive();

    assert(~fp.LiveIsActive, 'stopLive: should not be active');

    close(fp.hFigure);
    delete(tmpFile);
end

function testRefreshLoadsFile()
    fp = FastPlot();
    fp.addLine(1:100, zeros(1,100));
    fp.render();

    tmpFile = [tempname, '.mat'];
    s.x = 1:100; s.y = ones(1,100) * 42;
    save(tmpFile, '-struct', 's');

    fp.LiveFile = tmpFile;
    fp.LiveUpdateFcn = @(fp, d) fp.updateData(1, d.x, d.y);
    fp.refresh();

    assert(all(fp.Lines(1).Y == 42), 'refresh: data should be updated to 42');

    close(fp.hFigure);
    delete(tmpFile);
end

function testSetViewMode()
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();

    fp.setViewMode('follow');
    assert(strcmp(fp.LiveViewMode, 'follow'), 'setViewMode: should be follow');

    fp.setViewMode('reset');
    assert(strcmp(fp.LiveViewMode, 'reset'), 'setViewMode: should be reset');

    close(fp.hFigure);
end

function testStartLiveRequiresRender()
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));

    threw = false;
    try
        fp.startLive('dummy.mat', @(fp, d) disp('nope'));
    catch
        threw = true;
    end
    assert(threw, 'startLive: should throw before render');
end

function testRunLiveExitsWhenNotActive()
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();

    % runLive should return immediately when LiveIsActive is false
    tic;
    fp.runLive();
    elapsed = toc;
    assert(elapsed < 1, 'runLive: should return immediately when not active');
    close(fp.hFigure);
end

function testFigureStartLive()
    fig = FastPlotFigure(1, 2);
    fp1 = fig.tile(1); fp1.addLine(1:100, rand(1,100));
    fp2 = fig.tile(2); fp2.addLine(1:100, rand(1,100));
    fig.renderAll();

    tmpFile = [tempname, '.mat'];
    s.x = 1:100; s.y1 = rand(1,100); s.y2 = rand(1,100);
    save(tmpFile, '-struct', 's');

    updateFcn = @(fig, d) updateBothTiles(fig, d);
    fig.startLive(tmpFile, updateFcn, 'Interval', 2);

    assert(fig.LiveIsActive, 'fig startLive: should be active');
    fig.stopLive();
    close(fig.hFigure);
    delete(tmpFile);
end

function updateBothTiles(fig, d)
    fig.tile(1).updateData(1, d.x, d.y1);
    fig.tile(2).updateData(1, d.x, d.y2);
end

function testFigureStopLive()
    fig = FastPlotFigure(1, 1);
    fp1 = fig.tile(1); fp1.addLine(1:100, rand(1,100));
    fig.renderAll();

    tmpFile = [tempname, '.mat'];
    s.x = 1:100; s.y = rand(1,100);
    save(tmpFile, '-struct', 's');

    fig.startLive(tmpFile, @(fig, d) fig.tile(1).updateData(1, d.x, d.y));
    fig.stopLive();

    assert(~fig.LiveIsActive, 'fig stopLive: should not be active');
    close(fig.hFigure);
    delete(tmpFile);
end

function testFigureRefresh()
    fig = FastPlotFigure(1, 1);
    fp1 = fig.tile(1); fp1.addLine(1:100, zeros(1,100));
    fig.renderAll();

    tmpFile = [tempname, '.mat'];
    s.x = 1:100; s.y = ones(1,100) * 99;
    save(tmpFile, '-struct', 's');

    fig.LiveFile = tmpFile;
    fig.LiveUpdateFcn = @(fig, d) fig.tile(1).updateData(1, d.x, d.y);
    fig.refresh();

    assert(all(fig.tile(1).Lines(1).Y == 99), 'fig refresh: data should be 99');
    close(fig.hFigure);
    delete(tmpFile);
end

function testFigureRunLiveExitsWhenNotActive()
    fig = FastPlotFigure(1, 1);
    fp1 = fig.tile(1); fp1.addLine(1:100, rand(1,100));
    fig.renderAll();

    tic;
    fig.runLive();
    elapsed = toc;
    assert(elapsed < 1, 'fig runLive: should return immediately when not active');
    close(fig.hFigure);
end
