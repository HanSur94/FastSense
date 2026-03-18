classdef TestZoomPan < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testZoomUpdatesPlottedData(testCase)
            fp = FastSense();
            n = 100000;
            x = linspace(0, 100, n);
            y = sin(x);
            fp.addLine(x, y, 'DisplayName', 'sine');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);

            initialPoints = numel(get(fp.Lines(1).hLine, 'XData'));

            % Simulate zoom to [10, 20]
            set(fp.hAxes, 'XLim', [10 20]);
            drawnow;
            pause(0.2);

            zoomedPoints = numel(get(fp.Lines(1).hLine, 'XData'));
            testCase.verifyTrue(zoomedPoints > 0, 'testZoomUpdatesPlottedData: no points after zoom');
        end

        function testLazySkipsRedundantUpdate(testCase)
            fp = FastSense();
            fp.addLine(1:1000, rand(1,1000));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);

            currentXLim = get(fp.hAxes, 'XLim');
            set(fp.hAxes, 'XLim', currentXLim);
            drawnow;
            pause(0.2);

            testCase.verifyTrue(fp.IsRendered, 'testLazySkipsRedundantUpdate: should still be rendered');
        end

        function testViolationsUpdateOnZoom(testCase)
            fp = FastSense();
            y = [zeros(1,500), ones(1,500)*10, zeros(1,500)];
            x = 1:1500;
            fp.addLine(x, y);
            fp.addThreshold(5, 'Direction', 'upper', 'ShowViolations', true);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);

            % Zoom to region with violations
            set(fp.hAxes, 'XLim', [400 1100]);
            drawnow;
            pause(0.2);

            vx = get(fp.Thresholds(1).hMarkers, 'XData');
            vx = vx(~isnan(vx));
            testCase.verifyTrue(numel(vx) > 0, 'Should show violations in zoomed region');

            % Zoom to region without violations
            set(fp.hAxes, 'XLim', [1 200]);
            drawnow;
            pause(0.2);

            vx = get(fp.Thresholds(1).hMarkers, 'XData');
            vx = vx(~isnan(vx));
            testCase.verifyEqual(numel(vx), 0, 'Should show no violations outside violation region');
        end
    end
end
