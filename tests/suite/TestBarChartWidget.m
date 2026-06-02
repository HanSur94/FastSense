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

        function testDerivedTagRefreshNoCrash(testCase)
        %TESTDERIVEDTAGREFRESHNOCRASH P0-2: a DerivedTag (no public .Y) must refresh via getXY().
            a = SensorTag('a', 'X', 1:10, 'Y', 1:10);
            b = SensorTag('b', 'X', 1:10, 'Y', 2:11);
            d = DerivedTag('d', {a, b}, @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            w = BarChartWidget('Title', 'Bar');
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

        function testBarChartUnresolvedSourceWarns(testCase)
        %TESTBARCHARTUNRESOLVEDSOURCEWARNS P0-3: an unknown source.type warns (no throw).
            s = struct('type', 'barchart', 'title', 'B', ...
                'position', struct('col', 1, 'row', 1, 'width', 8, 'height', 4), ...
                'source', struct('type', 'weirdtype', 'function', '@() 1'));
            lastwarn('');
            w = BarChartWidget.fromStruct(s);
            [~, id] = lastwarn();
            testCase.verifyEqual(id, 'BarChartWidget:sourceUnresolved');
            testCase.verifyEmpty(w.DataFcn);
        end
    end
end
