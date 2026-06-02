classdef TestScatterWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = ScatterWidget();
            testCase.verifyEqual(w.getType(), 'scatter');
            testCase.verifyEqual(w.MarkerSize, 6);
            testCase.verifyEqual(w.Colormap, 'parula');
        end

        function testToStruct(testCase)
            w = ScatterWidget('Title', 'Scatter');
            w.MarkerSize = 10;
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'scatter');
            testCase.verifyEqual(s.markerSize, 10);
        end

        function testDerivedTagRefreshNoCrash(testCase)
        %TESTDERIVEDTAGREFRESHNOCRASH P0-2: DerivedTag SensorX/SensorY must refresh via getXY().
            a = SensorTag('a', 'X', 1:10, 'Y', 1:10);
            b = SensorTag('b', 'X', 1:10, 'Y', 2:11);
            dx = DerivedTag('dx', {a, b}, @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            dy = DerivedTag('dy', {a, b}, @(p) deal(p{1}.X, p{2}.Y));
            w = ScatterWidget('Title', 'Scatter');
            w.SensorX = dx;
            w.SensorY = dy;
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            threw = false; msg = '';
            try
                w.render(hp);   % refresh() read obj.SensorX.Y -> threw before P0-2 fix
            catch err
                threw = true; msg = err.message;
            end
            testCase.verifyFalse(threw, msg);
        end

        function testScatterAsciiRenderTags(testCase)
        %TESTSCATTERASCIIRENDERTAGS P0-2: asciiRender probes SensorX/SensorY via getXY().
            a = SensorTag('a', 'X', 1:10, 'Y', 1:10);
            b = SensorTag('b', 'X', 1:10, 'Y', 2:11);
            dx = DerivedTag('dx', {a, b}, @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            dy = DerivedTag('dy', {a, b}, @(p) deal(p{1}.X, p{2}.Y));
            w = ScatterWidget('Title', 'S');
            w.SensorX = dx;
            w.SensorY = dy;
            lines = w.asciiRender(24, 3);
            testCase.verifyEqual(numel(lines), 3);
            testCase.verifyTrue(contains(lines{2}, 'points'));
        end

        function testScatterUnresolvedSensorWarns(testCase)
        %TESTSCATTERUNRESOLVEDSENSORWARNS P0-3: a sensor key absent from TagRegistry warns (no throw).
            TagRegistry.clear();
            testCase.addTeardown(@() TagRegistry.clear());
            s = struct('type', 'scatter', 'title', 'S', ...
                'position', struct('col', 1, 'row', 1, 'width', 8, 'height', 4), ...
                'sensorX', 'missingX', 'sensorY', 'missingY');
            lastwarn('');
            w = ScatterWidget.fromStruct(s);
            [~, id] = lastwarn();
            testCase.verifyEqual(id, 'ScatterWidget:sourceUnresolved');
            testCase.verifyEmpty(w.SensorX);
        end
    end
end
