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

        function testDerivedTagRefreshNoCrash(testCase)
        %TESTDERIVEDTAGREFRESHNOCRASH P0-2: a DerivedTag (no public .Y) must refresh via getXY().
            a = SensorTag('a', 'X', 1:10, 'Y', 1:10);
            b = SensorTag('b', 'X', 1:10, 'Y', 2:11);
            d = DerivedTag('d', {a, b}, @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            w = HeatmapWidget('Title', 'Heat');
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

        function testHeatmapCallbackRoundTrip(testCase)
        %TESTHEATMAPCALLBACKROUNDTRIP P0-3: DataFcn survives toStruct/fromStruct.
            w = HeatmapWidget('Title', 'H');
            w.DataFcn = @() magic(4);
            w2 = HeatmapWidget.fromStruct(w.toStruct());
            testCase.verifyNotEmpty(w2.DataFcn);
            testCase.verifyEqual(func2str(w2.DataFcn), func2str(w.DataFcn));
        end
    end
end
