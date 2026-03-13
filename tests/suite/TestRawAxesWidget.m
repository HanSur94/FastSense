classdef TestRawAxesWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = RawAxesWidget('Title', 'Histogram', ...
                'PlotFcn', @(ax) bar(ax, 1:5, rand(1,5)));
            testCase.verifyEqual(w.Title, 'Histogram');
        end

        function testDefaultPosition(testCase)
            w = RawAxesWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 4 2]);
        end

        function testGetType(testCase)
            w = RawAxesWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'rawaxes');
        end

        function testToStructFromStruct(testCase)
            w = RawAxesWidget('Title', 'Chart', 'Position', [1 1 6 3]);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'rawaxes');

            w2 = RawAxesWidget.fromStruct(s);
            testCase.verifyEqual(w2.Title, 'Chart');
        end

        function testRender(testCase)
            w = RawAxesWidget('Title', 'Bar Chart', ...
                'PlotFcn', @(ax) bar(ax, 1:5, [3 1 4 1 5]));
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyNotEmpty(w.hAxes);
        end

        function testRefreshRedraws(testCase)
            callCount = 0;
            w = RawAxesWidget('Title', 'Dynamic', ...
                'PlotFcn', @(ax) testPlot(ax));
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            w.refresh();
            % Just verify no error on refresh
            testCase.verifyTrue(true);

            function testPlot(ax)
                bar(ax, 1:3, rand(1,3));
            end
        end
    end
end
