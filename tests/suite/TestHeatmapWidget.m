classdef TestHeatmapWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = HeatmapWidget();
            testCase.verifyEqual(w.getType(), 'heatmap');
            testCase.verifyEqual(w.Colormap, 'parula');
            testCase.verifyEqual(w.ShowColorbar, true);
        end

        function testRender(testCase)
            w = HeatmapWidget('Title', 'Test Heatmap');
            w.DataFcn = @() magic(5);

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hPanel);
        end

        function testToStructRoundTrip(testCase)
            w = HeatmapWidget('Title', 'Heat');
            w.Colormap = 'jet';
            w.ShowColorbar = false;
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'heatmap');
            testCase.verifyEqual(s.colormap, 'jet');
            testCase.verifyEqual(s.showColorbar, false);
        end
    end
end
