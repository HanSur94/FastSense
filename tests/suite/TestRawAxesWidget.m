classdef TestRawAxesWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = RawAxesWidget('Title', 'My Axes');
            testCase.verifyEqual(w.Title, 'My Axes');
            testCase.verifyEmpty(w.PlotFcn);
            testCase.verifyEmpty(w.DataRangeFcn);
        end

        function testDefaultPosition(testCase)
            w = RawAxesWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 8 2], ...
                'RawAxesWidget default position should be [1 1 8 2]');
        end

        function testRender(testCase)
            w = RawAxesWidget('Title', 'Bar Chart', ...
                'PlotFcn', @(ax) bar(ax, 1:5, [3 1 4 1 5]));
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyNotEmpty(w.hAxes, ...
                'Axes handle should be created after render');
        end

        function testRenderWithoutPlotFcn(testCase)
            w = RawAxesWidget('Title', 'No PlotFcn');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            testCase.verifyWarningFree(@() w.render(hp), ...
                'Rendering without a PlotFcn should not error');
            testCase.verifyNotEmpty(w.hAxes);
        end

        function testRefresh(testCase)
            callCount = 0;
            function plotIt(ax)
                callCount = callCount + 1;
                plot(ax, 1:5, rand(1,5));
            end
            w = RawAxesWidget('Title', 'Refresh Test', ...
                'PlotFcn', @plotIt);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);  % first call
            countAfterRender = callCount;
            w.refresh();   % second call
            testCase.verifyGreaterThan(callCount, countAfterRender, ...
                'refresh should re-invoke PlotFcn');
        end

        function testToStruct(testCase)
            w = RawAxesWidget('Title', 'Histogram', ...
                'PlotFcn', @(ax) histogram(ax, randn(1,100)), ...
                'Position', [5 3 8 4]);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'rawaxes');
            testCase.verifyEqual(s.title, 'Histogram');
            testCase.verifyEqual(s.position, ...
                struct('col', 5, 'row', 3, 'width', 8, 'height', 4));
            testCase.verifyEqual(s.source.type, 'callback');
        end

        function testFromStruct(testCase)
            w = RawAxesWidget('Title', 'Original', ...
                'PlotFcn', @(ax) plot(ax, 1:3, 1:3), ...
                'Position', [2 1 10 3]);
            s = w.toStruct();
            w2 = RawAxesWidget.fromStruct(s);
            testCase.verifyEqual(w2.Title, 'Original');
            testCase.verifyEqual(w2.Position, [2 1 10 3]);
            testCase.verifyClass(w2.PlotFcn, 'function_handle');
        end

        function testGetType(testCase)
            w = RawAxesWidget();
            testCase.verifyEqual(w.getType(), 'rawaxes');
        end
    end
end
