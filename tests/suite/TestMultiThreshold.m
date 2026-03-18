classdef TestMultiThreshold < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testEachThresholdGetsOwnLine(testCase)
            fp = FastSense();
            fp.addLine(1:100, randn(1,100));
            fp.addThreshold(2.0, 'Direction', 'upper', 'Color', 'r', 'LineStyle', '--');
            fp.addThreshold(1.0, 'Direction', 'upper', 'Color', [1 0.6 0], 'LineStyle', ':');
            fp.addThreshold(-1.0, 'Direction', 'lower', 'Color', [1 0.6 0], 'LineStyle', ':');
            fp.addThreshold(-2.0, 'Direction', 'lower', 'Color', 'r', 'LineStyle', '--');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);

            testCase.verifyEqual(numel(fp.Thresholds), 4, 'Should have 4 thresholds');
            for t = 1:4
                testCase.verifyTrue(isgraphics(fp.Thresholds(t).hLine, 'line'), ...
                    sprintf('Threshold %d should have its own line handle', t));
            end

            % Verify colors are distinct
            c1 = get(fp.Thresholds(1).hLine, 'Color');
            c2 = get(fp.Thresholds(2).hLine, 'Color');
            testCase.verifyTrue(~isequal(c1, c2), 'Threshold 1 and 2 should have different colors');

            % Verify line styles are distinct
            ls1 = get(fp.Thresholds(1).hLine, 'LineStyle');
            ls2 = get(fp.Thresholds(2).hLine, 'LineStyle');
            testCase.verifyTrue(~strcmp(ls1, ls2), 'Threshold 1 and 2 should have different line styles');
        end

        function testEachThresholdGetsOwnViolationMarkers(testCase)
            fp = FastSense();
            y = [0 0 0 1.5 1.5 0 0 0 2.5 2.5 0 0];
            fp.addLine(1:12, y);
            fp.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
            fp.addThreshold(1.0, 'Direction', 'upper', 'ShowViolations', true, 'Color', [1 0.6 0]);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);

            % Alarm threshold (2.0) markers: indices 9,10 (y=2.5)
            testCase.verifyTrue(isgraphics(fp.Thresholds(1).hMarkers, 'line'), 'Alarm should have markers');
            vx1 = get(fp.Thresholds(1).hMarkers, 'XData');
            vx1 = vx1(~isnan(vx1));
            testCase.verifyTrue(all(ismember([9 10], vx1)), 'Alarm markers should include x=9,10');

            % Warning threshold (1.0) markers: indices 4,5,9,10 (y=1.5 and 2.5)
            testCase.verifyTrue(isgraphics(fp.Thresholds(2).hMarkers, 'line'), 'Warning should have markers');
            vx2 = get(fp.Thresholds(2).hMarkers, 'XData');
            vx2 = vx2(~isnan(vx2));
            testCase.verifyTrue(all(ismember([4 5 9 10], vx2)), 'Warning markers should include x=4,5,9,10');

            % Verify marker colors match threshold colors
            mc1 = get(fp.Thresholds(1).hMarkers, 'Color');
            mc2 = get(fp.Thresholds(2).hMarkers, 'Color');
            testCase.verifyTrue(~isequal(mc1, mc2), 'Marker colors should differ between thresholds');
        end

        function testThresholdWithoutViolationsGetsNoMarkers(testCase)
            fp = FastSense();
            fp.addLine(1:10, zeros(1,10));
            fp.addThreshold(5.0, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);

            % hMarkers should exist but show NaN (invisible)
            testCase.verifyTrue(isgraphics(fp.Thresholds(1).hMarkers, 'line'), 'Should still have marker handle');
            vx = get(fp.Thresholds(1).hMarkers, 'XData');
            vx = vx(~isnan(vx));
            testCase.verifyEqual(numel(vx), 0, 'Should have no visible markers');
        end

        function testShowViolationsFalseGetsNoMarkerHandle(testCase)
            fp = FastSense();
            fp.addLine(1:10, 5*ones(1,10));
            fp.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', false, 'Color', 'r');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);

            testCase.verifyEmpty(fp.Thresholds(1).hMarkers, 'ShowViolations=false should have no marker handle');
        end

        function testViolationsUpdateOnZoomPerThreshold(testCase)
            fp = FastSense();
            y = [zeros(1,100), 1.5*ones(1,100), zeros(1,100), 2.5*ones(1,100), zeros(1,100)];
            x = 1:500;
            fp.addLine(x, y);
            fp.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
            fp.addThreshold(1.0, 'Direction', 'upper', 'ShowViolations', true, 'Color', [1 0.6 0]);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);

            % Zoom to region with only warning violations (x=101:200, y=1.5)
            set(fp.hAxes, 'XLim', [90 210]);
            drawnow;
            pause(0.2);

            vx_alarm = get(fp.Thresholds(1).hMarkers, 'XData');
            vx_alarm = vx_alarm(~isnan(vx_alarm));
            testCase.verifyEqual(numel(vx_alarm), 0, 'Alarm markers should be empty in warning-only region');

            vx_warn = get(fp.Thresholds(2).hMarkers, 'XData');
            vx_warn = vx_warn(~isnan(vx_warn));
            testCase.verifyTrue(numel(vx_warn) > 0, 'Warning markers should show in warning region');
        end

        function testUserDataTagging(testCase)
            fp = FastSense();
            fp.addLine(1:100, randn(1,100));
            fp.addThreshold(1.0, 'Direction', 'upper', 'Label', 'AlarmHi', 'Color', 'r');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);

            ud = get(fp.Thresholds(1).hLine, 'UserData');
            testCase.verifyEqual(ud.FastSense.Type, 'threshold', 'UserData Type');
            testCase.verifyEqual(ud.FastSense.Name, 'AlarmHi', 'UserData Name');
            testCase.verifyEqual(ud.FastSense.ThresholdValue, 1.0, 'UserData ThresholdValue');
        end
    end
end
