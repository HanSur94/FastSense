classdef TestRender < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testCreatesNewFigure(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100), 'DisplayName', 'Test');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyTrue(TestRender.isfigure(fp.hFigure), 'testCreatesNewFigure: hFigure');
            testCase.verifyTrue(TestRender.isaxes(fp.hAxes), 'testCreatesNewFigure: hAxes');
        end

        function testUsesExistingAxes(testCase)
            fig = figure('Visible', 'off');
            testCase.addTeardown(@close, fig);
            ax = axes('Parent', fig);
            fp = FastSense('Parent', ax);
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.verifyEqual(fp.hAxes, ax, 'testUsesExistingAxes');
        end

        function testCreatesLineObjects(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100), 'DisplayName', 'L1');
            fp.addLine(1:100, rand(1,100), 'DisplayName', 'L2');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyEqual(numel(fp.Lines), 2, 'testCreatesLineObjects: count');
            testCase.verifyTrue(isgraphics(fp.Lines(1).hLine, 'line'), 'testCreatesLineObjects: L1');
            testCase.verifyTrue(isgraphics(fp.Lines(2).hLine, 'line'), 'testCreatesLineObjects: L2');
        end

        function testUserDataTagging(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100), 'DisplayName', 'Sensor1');
            fp.addThreshold(0.5, 'Label', 'UpperLim');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            ud = get(fp.Lines(1).hLine, 'UserData');
            testCase.verifyEqual(ud.FastSense.Type, 'data_line', 'testUserDataTagging: Type');
            testCase.verifyEqual(ud.FastSense.Name, 'Sensor1', 'testUserDataTagging: Name');
            testCase.verifyEqual(ud.FastSense.LineIndex, 1, 'testUserDataTagging: LineIndex');
        end

        function testThresholdLineCreated(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.addThreshold(0.5, 'Direction', 'upper', 'Label', 'UL');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyTrue(isgraphics(fp.Thresholds(1).hLine, 'line'), 'testThresholdLineCreated');
            ud = get(fp.Thresholds(1).hLine, 'UserData');
            testCase.verifyEqual(ud.FastSense.Type, 'threshold', 'testThresholdLineCreated: Type');
        end

        function testViolationMarkersCreated(testCase)
            fp = FastSense();
            y = [0.1 0.2 0.8 0.9 0.3 0.1];
            fp.addLine(1:6, y);
            fp.addThreshold(0.5, 'Direction', 'upper', 'ShowViolations', true);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyTrue(isgraphics(fp.Thresholds(1).hMarkers, 'line'), 'testViolationMarkersCreated');
            vx = get(fp.Thresholds(1).hMarkers, 'XData');
            vx = vx(~isnan(vx));
            testCase.verifyTrue(ismember(3, vx), 'testViolationMarkersCreated: x=3');
            testCase.verifyTrue(ismember(4, vx), 'testViolationMarkersCreated: x=4');
        end

        function testDoubleRenderError(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            threw = false;
            try
                fp.render();
            catch e
                threw = true;
            end
            testCase.verifyTrue(threw, 'testDoubleRenderError: should have thrown');
        end

        function testStaticAxisLimits(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyEqual(get(fp.hAxes, 'XLimMode'), 'manual', 'testStaticAxisLimits: XLimMode');
            testCase.verifyEqual(get(fp.hAxes, 'YLimMode'), 'manual', 'testStaticAxisLimits: YLimMode');
        end
    end

    methods (Static, Access = private)
        function result = isfigure(h)
            result = ~isempty(h) && ishandle(h) && strcmp(get(h, 'Type'), 'figure');
        end

        function result = isaxes(h)
            result = ~isempty(h) && ishandle(h) && strcmp(get(h, 'Type'), 'axes');
        end
    end
end
