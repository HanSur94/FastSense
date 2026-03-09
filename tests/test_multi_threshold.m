function test_multi_threshold()
%TEST_MULTI_THRESHOLD Tests for per-threshold rendering with independent colors/markers.

    run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));
    add_fastplot_private_path();

    % testEachThresholdGetsOwnLine
    fp = FastPlot();
    fp.addLine(1:100, randn(1,100));
    fp.addThreshold(2.0, 'Direction', 'upper', 'Color', 'r', 'LineStyle', '--');
    fp.addThreshold(1.0, 'Direction', 'upper', 'Color', [1 0.6 0], 'LineStyle', ':');
    fp.addThreshold(-1.0, 'Direction', 'lower', 'Color', [1 0.6 0], 'LineStyle', ':');
    fp.addThreshold(-2.0, 'Direction', 'lower', 'Color', 'r', 'LineStyle', '--');
    fp.render();

    assert(numel(fp.Thresholds) == 4, 'Should have 4 thresholds');
    for t = 1:4
        assert(isgraphics(fp.Thresholds(t).hLine, 'line'), ...
            sprintf('Threshold %d should have its own line handle', t));
    end

    % Verify colors are distinct
    c1 = get(fp.Thresholds(1).hLine, 'Color');
    c2 = get(fp.Thresholds(2).hLine, 'Color');
    assert(~isequal(c1, c2), 'Threshold 1 and 2 should have different colors');

    % Verify line styles are distinct
    ls1 = get(fp.Thresholds(1).hLine, 'LineStyle');
    ls2 = get(fp.Thresholds(2).hLine, 'LineStyle');
    assert(~strcmp(ls1, ls2), 'Threshold 1 and 2 should have different line styles');

    close(fp.hFigure);

    % testEachThresholdGetsOwnViolationMarkers
    fp = FastPlot();
    y = [0 0 0 1.5 1.5 0 0 0 2.5 2.5 0 0];
    fp.addLine(1:12, y);
    fp.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
    fp.addThreshold(1.0, 'Direction', 'upper', 'ShowViolations', true, 'Color', [1 0.6 0]);
    fp.render();

    % Alarm threshold (2.0) markers: indices 9,10 (y=2.5)
    assert(isgraphics(fp.Thresholds(1).hMarkers, 'line'), 'Alarm should have markers');
    vx1 = get(fp.Thresholds(1).hMarkers, 'XData');
    vx1 = vx1(~isnan(vx1));
    assert(all(ismember([9 10], vx1)), 'Alarm markers should include x=9,10');

    % Warning threshold (1.0) markers: indices 4,5,9,10 (y=1.5 and 2.5)
    assert(isgraphics(fp.Thresholds(2).hMarkers, 'line'), 'Warning should have markers');
    vx2 = get(fp.Thresholds(2).hMarkers, 'XData');
    vx2 = vx2(~isnan(vx2));
    assert(all(ismember([4 5 9 10], vx2)), 'Warning markers should include x=4,5,9,10');

    % Verify marker colors match threshold colors
    mc1 = get(fp.Thresholds(1).hMarkers, 'Color');
    mc2 = get(fp.Thresholds(2).hMarkers, 'Color');
    assert(~isequal(mc1, mc2), 'Marker colors should differ between thresholds');

    close(fp.hFigure);

    % testThresholdWithoutViolationsGetsNoMarkers
    fp = FastPlot();
    fp.addLine(1:10, zeros(1,10));
    fp.addThreshold(5.0, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
    fp.render();

    % hMarkers should exist but show NaN (invisible)
    assert(isgraphics(fp.Thresholds(1).hMarkers, 'line'), 'Should still have marker handle');
    vx = get(fp.Thresholds(1).hMarkers, 'XData');
    vx = vx(~isnan(vx));
    assert(numel(vx) == 0, 'Should have no visible markers');

    close(fp.hFigure);

    % testShowViolationsFalseGetsNoMarkerHandle
    fp = FastPlot();
    fp.addLine(1:10, 5*ones(1,10));
    fp.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', false, 'Color', 'r');
    fp.render();

    assert(isempty(fp.Thresholds(1).hMarkers), 'ShowViolations=false should have no marker handle');

    close(fp.hFigure);

    % testViolationsUpdateOnZoomPerThreshold
    fp = FastPlot();
    y = [zeros(1,100), 1.5*ones(1,100), zeros(1,100), 2.5*ones(1,100), zeros(1,100)];
    x = 1:500;
    fp.addLine(x, y);
    fp.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
    fp.addThreshold(1.0, 'Direction', 'upper', 'ShowViolations', true, 'Color', [1 0.6 0]);
    fp.render();

    % Zoom to region with only warning violations (x=101:200, y=1.5)
    set(fp.hAxes, 'XLim', [90 210]);
    drawnow;
    pause(0.2);

    vx_alarm = get(fp.Thresholds(1).hMarkers, 'XData');
    vx_alarm = vx_alarm(~isnan(vx_alarm));
    assert(numel(vx_alarm) == 0, 'Alarm markers should be empty in warning-only region');

    vx_warn = get(fp.Thresholds(2).hMarkers, 'XData');
    vx_warn = vx_warn(~isnan(vx_warn));
    assert(numel(vx_warn) > 0, 'Warning markers should show in warning region');

    close(fp.hFigure);

    % testUserDataTagging
    fp = FastPlot();
    fp.addLine(1:100, randn(1,100));
    fp.addThreshold(1.0, 'Direction', 'upper', 'Label', 'AlarmHi', 'Color', 'r');
    fp.render();

    ud = get(fp.Thresholds(1).hLine, 'UserData');
    assert(strcmp(ud.FastPlot.Type, 'threshold'), 'UserData Type');
    assert(strcmp(ud.FastPlot.Name, 'AlarmHi'), 'UserData Name');
    assert(ud.FastPlot.ThresholdValue == 1.0, 'UserData ThresholdValue');

    close(fp.hFigure);

    fprintf('    All 6 multi-threshold tests passed.\n');
end
