classdef TestDashboardDirtyFlag < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testNewWidgetIsDirty(testCase)
            w = MockDashboardWidget();
            testCase.verifyTrue(w.Dirty, ...
                'Newly created widget should be dirty');
        end

        function testMarkDirty(testCase)
            w = MockDashboardWidget();
            w.Dirty = false;
            w.markDirty();
            testCase.verifyTrue(w.Dirty);
        end

        function testRealizedDefaultFalse(testCase)
            w = MockDashboardWidget();
            testCase.verifyFalse(w.Realized, ...
                'Newly created widget should not be realized');
        end

        function testLiveTickSkipsCleanWidgets(testCase)
            d = DashboardEngine('DirtyTest');
            d.addWidget('fastsense', 'Title', 'Plot 1', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', rand(1,10));
            d.addWidget('fastsense', 'Title', 'Plot 2', ...
                'Position', [13 1 12 3], 'XData', 1:10, 'YData', rand(1,10));
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            % After render, widgets are dirty (default). Clear them.
            for i = 1:numel(d.Widgets)
                d.Widgets{i}.Dirty = false;
            end

            % Mark only the first widget dirty
            d.Widgets{1}.markDirty();

            % After live tick, only dirty widget should be cleared
            d.onLiveTick();
            testCase.verifyFalse(d.Widgets{1}.Dirty, ...
                'Refreshed widget should have Dirty cleared');
            % Widget 2 was already clean — it stays clean
            testCase.verifyFalse(d.Widgets{2}.Dirty);
        end

        function testMarkAllDirty(testCase)
            d = DashboardEngine('DirtyTest');
            d.addWidget('fastsense', 'Title', 'P1', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', rand(1,10));
            d.addWidget('fastsense', 'Title', 'P2', ...
                'Position', [13 1 12 3], 'XData', 1:10, 'YData', rand(1,10));

            for i = 1:numel(d.Widgets)
                d.Widgets{i}.Dirty = false;
            end

            d.markAllDirty();
            for i = 1:numel(d.Widgets)
                testCase.verifyTrue(d.Widgets{i}.Dirty);
            end
        end

        function testResizeRepositionsPanels(testCase)
            % Phase 1006 E10: onResize no longer marks widgets dirty (Phase 1000-02 decision:
            % repositionPanels no longer calls markDirty — position change alone does not
            % require data refresh). Test updated to verify repositioning behaviour instead.
            d = DashboardEngine('ResizeTest');
            d.addWidget('fastsense', 'Title', 'P1', ...
                'Position', [1 1 24 3], 'XData', 1:10, 'YData', rand(1,10));
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            % Clear dirty flags
            for i = 1:numel(d.Widgets)
                d.Widgets{i}.Dirty = false;
            end

            % Trigger resize callback — should reposition panels without error
            testCase.verifyWarningFree(@() d.onResize());

            % Panel handle must remain valid after repositioning
            testCase.verifyTrue(ishandle(d.Widgets{1}.hPanel), ...
                'Widget panel handle must remain valid after resize');

            % Dirty flag should NOT be set (repositionPanels is data-neutral)
            testCase.verifyFalse(d.Widgets{1}.Dirty, ...
                'onResize should not mark widgets dirty — data did not change');
        end
    end
end
