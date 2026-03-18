function test_zoom_pan()
%TEST_ZOOM_PAN Tests for zoom/pan callbacks.
%   Requires PostSet listeners (MATLAB only, skipped on Octave).

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
    add_fastsense_private_path();

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIPPED: Octave lacks PostSet listeners for axes properties.\n');
        return;
    end

    % testZoomUpdatesPlottedData
    fp = FastSense();
    n = 100000;
    x = linspace(0, 100, n);
    y = sin(x);
    fp.addLine(x, y, 'DisplayName', 'sine');
    fp.render();

    initialPoints = numel(get(fp.Lines(1).hLine, 'XData'));

    % Simulate zoom to [10, 20]
    set(fp.hAxes, 'XLim', [10 20]);
    drawnow;
    pause(0.2);

    zoomedPoints = numel(get(fp.Lines(1).hLine, 'XData'));
    assert(zoomedPoints > 0, 'testZoomUpdatesPlottedData: no points after zoom');

    close(fp.hFigure);

    % testLazySkipsRedundantUpdate
    fp = FastSense();
    fp.addLine(1:1000, rand(1,1000));
    fp.render();

    currentXLim = get(fp.hAxes, 'XLim');
    set(fp.hAxes, 'XLim', currentXLim);
    drawnow;
    pause(0.2);

    assert(fp.IsRendered, 'testLazySkipsRedundantUpdate: should still be rendered');
    close(fp.hFigure);

    % testViolationsUpdateOnZoom
    fp = FastSense();
    y = [zeros(1,500), ones(1,500)*10, zeros(1,500)];
    x = 1:1500;
    fp.addLine(x, y);
    fp.addThreshold(5, 'Direction', 'upper', 'ShowViolations', true);
    fp.render();

    % Zoom to region with violations
    set(fp.hAxes, 'XLim', [400 1100]);
    drawnow;
    pause(0.2);

    vx = get(fp.Thresholds(1).hMarkers, 'XData');
    vx = vx(~isnan(vx));
    assert(numel(vx) > 0, 'Should show violations in zoomed region');

    % Zoom to region without violations
    set(fp.hAxes, 'XLim', [1 200]);
    drawnow;
    pause(0.2);

    vx = get(fp.Thresholds(1).hMarkers, 'XData');
    vx = vx(~isnan(vx));
    assert(numel(vx) == 0, 'Should show no violations outside violation region');

    close(fp.hFigure);

    fprintf('    All 3 zoom/pan tests passed.\n');
end
