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

    fprintf('    All 5 updateData tests passed.\n');
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
