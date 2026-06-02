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
    end
end
