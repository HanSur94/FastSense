classdef TestHistogramWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = HistogramWidget();
            testCase.verifyEqual(w.getType(), 'histogram');
            testCase.verifyEqual(w.ShowNormalFit, false);
            testCase.verifyEmpty(w.NumBins);
        end

        function testRender(testCase)
            w = HistogramWidget('Title', 'Test Hist');
            w.DataFcn = @() randn(1, 100);

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hPanel);
        end

        function testToStruct(testCase)
            w = HistogramWidget('Title', 'Hist');
            w.NumBins = 20;
            w.ShowNormalFit = true;
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'histogram');
            testCase.verifyEqual(s.numBins, 20);
            testCase.verifyEqual(s.showNormalFit, true);
        end
    end
end
