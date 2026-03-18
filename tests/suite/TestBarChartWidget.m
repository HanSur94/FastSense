classdef TestBarChartWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = BarChartWidget();
            testCase.verifyEqual(w.getType(), 'barchart');
            testCase.verifyEqual(w.Orientation, 'vertical');
            testCase.verifyEqual(w.Stacked, false);
        end

        function testRender(testCase)
            w = BarChartWidget('Title', 'Test Bar');
            w.DataFcn = @() struct('categories', {{'A','B','C'}}, 'values', [10 20 30]);

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hPanel);
        end

        function testToStruct(testCase)
            w = BarChartWidget('Title', 'Bar');
            w.Orientation = 'horizontal';
            w.Stacked = true;
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'barchart');
            testCase.verifyEqual(s.orientation, 'horizontal');
            testCase.verifyEqual(s.stacked, true);
        end
    end
end
