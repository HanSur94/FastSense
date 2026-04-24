classdef TestFastSenseWidgetUpdate < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testUpdateMethodExists(testCase)
            s = SensorTag('T-1', 'Name', 'Temp');
            s.updateData(1:100, rand(1, 100));

            d = DashboardEngine('UpdateTest');
            d.addWidget('fastsense', 'Sensor', s, 'Position', [1 1 24 3]);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            w = d.Widgets{1};
            % After render + refresh, FastSenseObj should be rendered
            w.refresh();
            testCase.verifyTrue(w.FastSenseObj.IsRendered);

            % update() should not error when FastSenseObj is rendered
            s.updateData(1:200, rand(1, 200));
            w.update();
        end

        function testUpdateFallsBackToRefreshWhenNotRendered(testCase)
            s = SensorTag('T-2', 'Name', 'Pressure');
            s.updateData(1:50, rand(1, 50));

            w = FastSenseWidget('Sensor', s, 'Position', [1 1 12 3]);
            % FastSenseObj is empty — update() should fall back to refresh()
            % This will be a no-op since hPanel is empty, but should not error
            w.update();
        end
    end
end
