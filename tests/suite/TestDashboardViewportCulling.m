classdef TestDashboardViewportCulling < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testOnScrollCallbackProperty(testCase)
            layout = DashboardLayout();
            testCase.verifyEmpty(layout.OnScrollCallback);
        end

        function testVisibleRowsProperty(testCase)
            layout = DashboardLayout();
            testCase.verifyEqual(layout.VisibleRows, [1 Inf]);
        end

        function testComputeVisibleRows(testCase)
            layout = DashboardLayout();
            layout.TotalRows = 20;
            layout.RowHeight = 0.22;
            layout.GapV = 0.015;
            % scrollVal=1 (top) should give rows starting at 1
            rows = layout.computeVisibleRows(1);
            testCase.verifyGreaterThanOrEqual(rows(1), 1);
            testCase.verifyLessThanOrEqual(rows(2), 20);
        end

        function testComputeVisibleRowsNoScroll(testCase)
            layout = DashboardLayout();
            layout.TotalRows = 3;
            layout.RowHeight = 0.22;
            layout.GapV = 0.015;
            % Few rows - canvasRatio <= 1, should return [1, TotalRows]
            rows = layout.computeVisibleRows(1);
            testCase.verifyEqual(rows, [1, 3]);
        end

        function testIsWidgetVisible(testCase)
            layout = DashboardLayout();
            layout.VisibleRows = [3 8];
            % Widget at row 5, height 2 -> rows 5-6, visible
            testCase.verifyTrue(layout.isWidgetVisible([1 5 6 2], 2));
            % Widget at row 12, height 2 -> rows 12-13, not visible
            testCase.verifyFalse(layout.isWidgetVisible([1 12 6 2], 2));
            % Widget at row 1, height 2 -> rows 1-2, within buffer of 2
            testCase.verifyTrue(layout.isWidgetVisible([1 1 6 2], 2));
        end

        function testIsWidgetVisibleDefaultBuffer(testCase)
            layout = DashboardLayout();
            layout.VisibleRows = [5 10];
            % Widget at row 3, height 1 -> row 3, within default buffer=2
            testCase.verifyTrue(layout.isWidgetVisible([1 3 6 1]));
            % Widget at row 1, height 1 -> row 1, outside default buffer=2
            testCase.verifyFalse(layout.isWidgetVisible([1 1 6 1]));
        end

        function testAllocatePanelsDoesNotCallRender(testCase)
            d = DashboardEngine('DeferredTest');
            d.addWidget('fastsense', 'Title', 'P1', ...
                'Position', [1 1 24 3], 'XData', 1:10, 'YData', rand(1,10));
            d.addWidget('fastsense', 'Title', 'P2', ...
                'Position', [1 4 24 3], 'XData', 1:10, 'YData', rand(1,10));
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            % Visible widgets should be realized after render
            testCase.verifyTrue(d.Widgets{1}.Realized);
        end
    end
end
