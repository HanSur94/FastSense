classdef TestFastSenseWidgetUpdate < matlab.unittest.TestCase
    methods (TestClassSetup)
        function gateHeadlessLinux(testCase)
            %GATEHEADLESSLINUX Skip on Linux CI runners (xvfb / -batch).
            %   MATLAB segfaults during 'Running TestFastSenseWidgetUpdate'
            %   on both R2020b and R2021b headless Linux — stack lands in
            %   libmex.so + libmwm_dispatcher.so (MATLAB internals).
            %   PR #109 already bumped CI from R2020b -> R2021b for similar
            %   reasons; the dispatcher bug carried over. The update path
            %   exercised here (DashboardEngine + FastSenseWidget +
            %   SensorTag.updateData round-trip) is also covered by
            %   TestFastSenseWidgetTag and TestFastSenseWidget. Interactive
            %   MATLAB / macOS / Windows CI continue running this suite.
            if exist('OCTAVE_VERSION', 'builtin'); return; end
            isHeadlessLinux = ~ispc && ~ismac && ~usejava('desktop');
            testCase.assumeFalse(isHeadlessLinux, ...
                'TestFastSenseWidgetUpdate segfaults MATLAB headless on Linux — covered by sibling widget tests');
        end

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
