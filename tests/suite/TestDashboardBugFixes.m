classdef TestDashboardBugFixes < matlab.unittest.TestCase
%TESTDASHBOARDBUGFIXES Tests that expose and verify fixes for dashboard bugs.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        %% Bug 1: KpiWidget.getTheme() replaces theme instead of merging
        function testKpiWidgetThemeOverrideMerge(testCase)
            % Setting one ThemeOverride field should not lose base theme fields.
            w = KpiWidget('Title', 'Test KPI', 'StaticValue', 42);
            w.ThemeOverride = struct('KpiFontSize', 36);

            % getTheme is private, so test indirectly via render.
            % If getTheme replaces instead of merging, render will error
            % because ForegroundColor, FontName, WidgetBackground etc. are missing.
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig);

            % This should NOT error
            testCase.verifyWarningFree(@() w.render(hp));
        end

        %% Bug 2: StatusWidget.getTheme() replaces theme instead of merging
        function testStatusWidgetThemeOverrideMerge(testCase)
            w = StatusWidget('Title', 'Test Status', 'StaticStatus', 'ok');
            w.ThemeOverride = struct('StatusOkColor', [0 1 0]);

            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig);

            testCase.verifyWarningFree(@() w.render(hp));
        end

        %% Bug 3: TableWidget.toStruct() doesn't serialize static Data
        function testTableWidgetStaticDataSerialization(testCase)
            w = TableWidget('Title', 'Test Table', ...
                'Data', {{'A', 1; 'B', 2}}, ...
                'ColumnNames', {'Name', 'Value'});

            s = w.toStruct();

            % source.type should be 'static' AND the data must be present
            testCase.verifyTrue(isfield(s, 'source'), ...
                'toStruct should have a source field for static data');
            testCase.verifyEqual(s.source.type, 'static');
            testCase.verifyTrue(isfield(s.source, 'data'), ...
                'Static source should include the data field');
        end

        %% Bug 4: EventTimelineWidget.toStruct() doesn't serialize static Events
        function testEventTimelineStaticEventsSerialization(testCase)
            events = struct('startTime', {0, 10}, ...
                            'endTime', {5, 20}, ...
                            'label', {'A', 'B'});

            w = EventTimelineWidget('Title', 'Timeline', 'Events', events);
            s = w.toStruct();

            testCase.verifyTrue(isfield(s, 'source'), ...
                'toStruct should have a source field for static events');
            testCase.verifyEqual(s.source.type, 'static');
            testCase.verifyTrue(isfield(s.source, 'events'), ...
                'Static source should include events data');
        end

        %% Bug 5: configToWidgets leaves empty cells for unknown types
        function testConfigToWidgetsUnknownTypeFiltered(testCase)
            config = struct();
            config.name = 'Test';
            config.theme = 'default';
            config.liveInterval = 1;
            config.grid = struct('columns', 12);

            ws1 = struct('type', 'kpi', 'title', 'KPI 1', ...
                'position', struct('col', 1, 'row', 1, 'width', 3, 'height', 1));
            ws2 = struct('type', 'nonexistent_widget', 'title', 'Bad', ...
                'position', struct('col', 4, 'row', 1, 'width', 3, 'height', 1));
            ws3 = struct('type', 'text', 'title', 'Text 1', ...
                'position', struct('col', 7, 'row', 1, 'width', 3, 'height', 1));
            config.widgets = {ws1, ws2, ws3};

            widgets = DashboardSerializer.configToWidgets(config);

            % No cell should be empty — unknown widgets should be filtered out
            for i = 1:numel(widgets)
                testCase.verifyFalse(isempty(widgets{i}), ...
                    sprintf('Widget cell %d should not be empty', i));
            end
        end

        %% Bug 6: DashboardBuilder overlay indices mismatch widget indices
        function testBuilderOverlayIndexAlignment(testCase)
            d = DashboardEngine('Overlay Test');
            d.addWidget('kpi', 'Title', 'KPI 1', 'Position', [1 1 3 1], ...
                'StaticValue', 10);
            d.addWidget('kpi', 'Title', 'KPI 2', 'Position', [4 1 3 1], ...
                'StaticValue', 20);
            d.addWidget('kpi', 'Title', 'KPI 3', 'Position', [7 1 3 1], ...
                'StaticValue', 30);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            builder = DashboardBuilder(d);
            builder.enterEditMode();
            testCase.addTeardown(@() builder.exitEditMode());

            % Overlays count must equal widget count
            testCase.verifyEqual(numel(builder.Overlays), numel(d.Widgets), ...
                'Number of overlays should match number of widgets');

            % Verify selecting widget 3 highlights the correct overlay
            builder.selectWidget(3);
            testCase.verifyEqual(builder.SelectedIdx, 3);
        end

        %% Usability: applyProperties preserves selection highlight
        function testApplyPropertiesPreservesSelection(testCase)
            d = DashboardEngine('Apply Test');
            d.addWidget('kpi', 'Title', 'KPI', 'Position', [1 1 3 1], ...
                'StaticValue', 42);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            b = DashboardBuilder(d);
            b.enterEditMode();
            b.selectWidget(1);

            % Change title and apply
            set(b.hPropTitle, 'String', 'Updated KPI');
            set(b.hPropCol, 'String', '2');
            set(b.hPropRow, 'String', '1');
            set(b.hPropWidth, 'String', '4');
            set(b.hPropHeight, 'String', '1');
            b.applyProperties();

            % Selection should still be active after apply
            testCase.verifyEqual(b.SelectedIdx, 1, ...
                'SelectedIdx should be preserved after applyProperties');

            % Properties panel should show the actual (possibly clamped) values
            testCase.verifyEqual(get(b.hPropCol, 'String'), '2');
            testCase.verifyEqual(get(b.hPropWidth, 'String'), '4');
        end

        %% Usability: deleteWidget preserves selection of other widget
        function testDeleteWidgetPreservesOtherSelection(testCase)
            d = DashboardEngine('Delete Test');
            d.addWidget('kpi', 'Title', 'A', 'Position', [1 1 3 1], ...
                'StaticValue', 1);
            d.addWidget('kpi', 'Title', 'B', 'Position', [4 1 3 1], ...
                'StaticValue', 2);
            d.addWidget('kpi', 'Title', 'C', 'Position', [7 1 3 1], ...
                'StaticValue', 3);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            b = DashboardBuilder(d);
            b.enterEditMode();
            b.selectWidget(3);  % select widget C

            b.deleteWidget(1);  % delete widget A

            % Widget C is now at index 2; selection should track it
            testCase.verifyEqual(b.SelectedIdx, 2, ...
                'SelectedIdx should adjust when earlier widget is deleted');
            testCase.verifyEqual(d.Widgets{2}.Title, 'C');
        end

        %% Usability: addWidget from palette gives readable default title
        function testAddWidgetDefaultTitle(testCase)
            d = DashboardEngine('Title Test');
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            b = DashboardBuilder(d);
            b.enterEditMode();
            b.addWidget('kpi');

            testCase.verifyEqual(d.Widgets{1}.Title, 'New KPI', ...
                'Default title should be human-readable, not raw type');
        end

        %% Usability: enterEditMode errors when figure not rendered
        function testEnterEditModeWithoutRenderErrors(testCase)
            d = DashboardEngine('No Render');
            b = DashboardBuilder(d);

            testCase.verifyError(@() b.enterEditMode(), ...
                'DashboardBuilder:noFigure');
        end

        %% Usability: exitEditMode handles closed figure gracefully
        function testExitEditModeAfterFigureClose(testCase)
            d = DashboardEngine('Close Test');
            d.addWidget('kpi', 'Title', 'M', 'Position', [1 1 3 1], ...
                'StaticValue', 1);
            d.render();
            set(d.hFigure, 'Visible', 'off');

            b = DashboardBuilder(d);
            b.enterEditMode();

            % Simulate figure being closed externally
            delete(d.hFigure);

            % exitEditMode should not crash
            testCase.verifyWarningFree(@() b.exitEditMode());
            testCase.verifyFalse(b.IsActive);
        end

        %% Bug FIX-02: GroupWidget.refresh() should skip children when Collapsed
        function testGroupWidgetCollapsedRefreshSkipsChildren(testCase)
            % Create a collapsible group that is already collapsed
            g = GroupWidget('Mode', 'collapsible', 'Collapsed', true, 'Label', 'G');
            % TextWidget.refresh() is safe to call unrendered (has early-return guard)
            child = TextWidget('Title', 'Child');
            g.addChild(child);
            % Should complete without error — collapsed guard prevents child iteration
            testCase.verifyWarningFree(@() g.refresh());
        end

        %% Bug FIX-05: GroupWidget.getTimeRange() must aggregate children and tabs
        function testGroupWidgetGetTimeRange(testCase)
            % Base case: no children — should return [inf, -inf] (same as base class)
            g = GroupWidget('Label', 'G');
            [tMin, tMax] = g.getTimeRange();
            testCase.verifyEqual(tMin, inf);
            testCase.verifyEqual(tMax, -inf);
            % With a child added — child base class also returns [inf, -inf]
            child = TextWidget('Title', 'C');
            g.addChild(child);
            [tMin2, tMax2] = g.getTimeRange();
            testCase.verifyEqual(tMin2, inf);
            testCase.verifyEqual(tMax2, -inf);
        end
    end
end
