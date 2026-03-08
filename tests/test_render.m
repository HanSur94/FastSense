function test_render()
%TEST_RENDER Tests for FastPlot.render method.

    add_private_path();

    % testCreatesNewFigure
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100), 'DisplayName', 'Test');
    fp.render();
    assert(isfigure(fp.hFigure), 'testCreatesNewFigure: hFigure');
    assert(isaxes(fp.hAxes), 'testCreatesNewFigure: hAxes');
    close(fp.hFigure);

    % testUsesExistingAxes
    fig = figure('Visible', 'off');
    ax = axes('Parent', fig);
    fp = FastPlot('Parent', ax);
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(fp.hAxes == ax, 'testUsesExistingAxes');
    close(fig);

    % testCreatesLineObjects
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100), 'DisplayName', 'L1');
    fp.addLine(1:100, rand(1,100), 'DisplayName', 'L2');
    fp.render();
    assert(numel(fp.Lines) == 2, 'testCreatesLineObjects: count');
    assert(isgraphics(fp.Lines(1).hLine, 'line'), 'testCreatesLineObjects: L1');
    assert(isgraphics(fp.Lines(2).hLine, 'line'), 'testCreatesLineObjects: L2');
    close(fp.hFigure);

    % testUserDataTagging
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100), 'DisplayName', 'Sensor1');
    fp.addThreshold(0.5, 'Label', 'UpperLim');
    fp.render();
    ud = get(fp.Lines(1).hLine, 'UserData');
    assert(strcmp(ud.FastPlot.Type, 'data_line'), 'testUserDataTagging: Type');
    assert(strcmp(ud.FastPlot.Name, 'Sensor1'), 'testUserDataTagging: Name');
    assert(ud.FastPlot.LineIndex == 1, 'testUserDataTagging: LineIndex');
    close(fp.hFigure);

    % testThresholdLineCreated (per-threshold)
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.addThreshold(0.5, 'Direction', 'upper', 'Label', 'UL');
    fp.render();
    assert(isgraphics(fp.Thresholds(1).hLine, 'line'), 'testThresholdLineCreated');
    ud = get(fp.Thresholds(1).hLine, 'UserData');
    assert(strcmp(ud.FastPlot.Type, 'threshold'), 'testThresholdLineCreated: Type');
    close(fp.hFigure);

    % testViolationMarkersCreated (per-threshold)
    fp = FastPlot();
    y = [0.1 0.2 0.8 0.9 0.3 0.1];
    fp.addLine(1:6, y);
    fp.addThreshold(0.5, 'Direction', 'upper', 'ShowViolations', true);
    fp.render();
    assert(isgraphics(fp.Thresholds(1).hMarkers, 'line'), 'testViolationMarkersCreated');
    vx = get(fp.Thresholds(1).hMarkers, 'XData');
    vx = vx(~isnan(vx));
    assert(ismember(3, vx), 'testViolationMarkersCreated: x=3');
    assert(ismember(4, vx), 'testViolationMarkersCreated: x=4');
    close(fp.hFigure);

    % testDoubleRenderError
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10));
    fp.render();
    threw = false;
    try
        fp.render();
    catch e
        threw = true;
    end
    assert(threw, 'testDoubleRenderError: should have thrown');
    close(fp.hFigure);

    % testStaticAxisLimits
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(strcmp(get(fp.hAxes, 'XLimMode'), 'manual'), 'testStaticAxisLimits: XLimMode');
    assert(strcmp(get(fp.hAxes, 'YLimMode'), 'manual'), 'testStaticAxisLimits: YLimMode');
    close(fp.hFigure);

    % testDeferDraw
    fig = figure('Visible', 'off');
    ax = axes('Parent', fig);
    fp = FastPlot('Parent', ax);
    fp.addLine(1:100, rand(1,100));
    fp.DeferDraw = true;
    fp.render();
    assert(fp.IsRendered, 'testDeferDraw: should be rendered');
    assert(ishandle(fp.Lines(1).hLine), 'testDeferDraw: line created');
    assert(strcmp(get(fig, 'Visible'), 'off'), 'testDeferDraw: figure stays invisible');
    close(fig);

    % testStridePreviewLargeData
    fp = FastPlot();
    x = 1:100000;
    y = sin(x/1000);
    fp.addLine(x, y, 'DisplayName', 'Big');
    fp.render();
    xd = get(fp.Lines(1).hLine, 'XData');
    assert(numel(xd) < numel(x), 'testStridePreview: should be downsampled');
    assert(numel(xd) > 100, 'testStridePreview: should have reasonable points');
    close(fp.hFigure);

    % testSmallDataNoStride
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100), 'DisplayName', 'Small');
    fp.render();
    xd = get(fp.Lines(1).hLine, 'XData');
    assert(numel(xd) == 100, 'testSmallDataNoStride: all points shown');
    close(fp.hFigure);

    % testRefineTimerCleanupOnDelete
    fp = FastPlot();
    fp.addLine(1:100000, rand(1,100000));
    fp.render();
    fig = fp.hFigure;
    delete(fp);
    close(fig);
    % No error means timer was cleaned up properly

    fprintf('    All 12 render tests passed.\n');
end

function result = isfigure(h)
    result = ~isempty(h) && ishandle(h) && strcmp(get(h, 'Type'), 'figure');
end

function result = isaxes(h)
    result = ~isempty(h) && ishandle(h) && strcmp(get(h, 'Type'), 'axes');
end
