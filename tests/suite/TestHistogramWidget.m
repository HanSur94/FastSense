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

        function testDerivedTagRefreshNoCrash(testCase)
        %TESTDERIVEDTAGREFRESHNOCRASH P0-2: a DerivedTag (no public .Y) must refresh via getXY().
            a = SensorTag('a', 'X', 1:10, 'Y', 1:10);
            b = SensorTag('b', 'X', 1:10, 'Y', 2:11);
            d = DerivedTag('d', {a, b}, @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            w = HistogramWidget('Title', 'Hist');
            w.Tag = d;
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            threw = false; msg = '';
            try
                w.render(hp);   % refresh() read obj.Sensor.Y -> threw before P0-2 fix
            catch err
                threw = true; msg = err.message;
            end
            testCase.verifyFalse(threw, msg);
        end
    end
end
