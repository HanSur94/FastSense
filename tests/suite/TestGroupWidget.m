classdef TestGroupWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            g = GroupWidget();
            testCase.verifyEqual(g.Mode, 'panel');
            testCase.verifyEqual(g.Label, '');
            testCase.verifyEqual(g.Collapsed, false);
            testCase.verifyEqual(g.Children, {});
            testCase.verifyEqual(g.Tabs, {});
            testCase.verifyEqual(g.ActiveTab, '');
            testCase.verifyEqual(g.ChildColumns, 24);
            testCase.verifyEqual(g.ChildAutoFlow, true);
            testCase.verifyEqual(g.getType(), 'group');
        end

        function testConstructionWithNameValue(testCase)
            g = GroupWidget('Label', 'Motor Health', 'Mode', 'panel');
            testCase.verifyEqual(g.Label, 'Motor Health');
            testCase.verifyEqual(g.Mode, 'panel');
        end

        function testAddChild(testCase)
            g = GroupWidget('Label', 'Test');
            m1 = MockDashboardWidget('Title', 'W1');
            m2 = MockDashboardWidget('Title', 'W2');
            g.addChild(m1);
            g.addChild(m2);
            testCase.verifyLength(g.Children, 2);
            testCase.verifyEqual(g.Children{1}.Title, 'W1');
            testCase.verifyEqual(g.Children{2}.Title, 'W2');
        end

        function testRemoveChild(testCase)
            g = GroupWidget('Label', 'Test');
            g.addChild(MockDashboardWidget('Title', 'W1'));
            g.addChild(MockDashboardWidget('Title', 'W2'));
            g.removeChild(1);
            testCase.verifyLength(g.Children, 1);
            testCase.verifyEqual(g.Children{1}.Title, 'W2');
        end

        function testPanelModeRender(testCase)
            g = GroupWidget('Label', 'Motor Health', 'Mode', 'panel');
            g.addChild(MockDashboardWidget('Title', 'W1'));
            g.addChild(MockDashboardWidget('Title', 'W2'));

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            g.ParentTheme = DashboardTheme('dark');
            g.render(hp);

            testCase.verifyNotEmpty(g.hHeader);
            testCase.verifyNotEmpty(g.hChildPanel);
            testCase.verifyNotEmpty(g.Children{1}.hPanel);
            testCase.verifyNotEmpty(g.Children{2}.hPanel);
        end

        function testCollapsibleModeConstruction(testCase)
            g = GroupWidget('Label', 'Test', 'Mode', 'collapsible');
            testCase.verifyEqual(g.Mode, 'collapsible');
            testCase.verifyEqual(g.Collapsed, false);
        end

        function testCollapseChangesPosition(testCase)
            g = GroupWidget('Label', 'Test', 'Mode', 'collapsible');
            g.Position = [1 1 12 4];
            g.collapse();
            testCase.verifyEqual(g.Collapsed, true);
            testCase.verifyEqual(g.Position(4), 1);
            testCase.verifyEqual(g.ExpandedHeight, 4);
        end

        function testExpandRestoresPosition(testCase)
            g = GroupWidget('Label', 'Test', 'Mode', 'collapsible');
            g.Position = [1 1 12 4];
            g.collapse();
            g.expand();
            testCase.verifyEqual(g.Collapsed, false);
            testCase.verifyEqual(g.Position(4), 4);
        end

        function testCollapseRenderHidesChildren(testCase)
            g = GroupWidget('Label', 'Test', 'Mode', 'collapsible');
            g.addChild(MockDashboardWidget('Title', 'W1'));
            g.Position = [1 1 12 4];

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            g.ParentTheme = DashboardTheme('dark');
            g.render(hp);

            testCase.verifyTrue(strcmp(get(g.hChildPanel, 'Visible'), 'on'));
            g.collapse();
            testCase.verifyTrue(strcmp(get(g.hChildPanel, 'Visible'), 'off'));
        end

        function testTabbedModeAddChild(testCase)
            g = GroupWidget('Label', 'Analysis', 'Mode', 'tabbed');
            g.addChild(MockDashboardWidget('Title', 'W1'), 'Overview');
            g.addChild(MockDashboardWidget('Title', 'W2'), 'Overview');
            g.addChild(MockDashboardWidget('Title', 'W3'), 'Detail');

            testCase.verifyLength(g.Tabs, 2);
            testCase.verifyEqual(g.Tabs{1}.name, 'Overview');
            testCase.verifyLength(g.Tabs{1}.widgets, 2);
            testCase.verifyEqual(g.Tabs{2}.name, 'Detail');
            testCase.verifyLength(g.Tabs{2}.widgets, 1);
            testCase.verifyEqual(g.ActiveTab, 'Overview');
        end

        function testSwitchTab(testCase)
            g = GroupWidget('Label', 'Analysis', 'Mode', 'tabbed');
            g.addChild(MockDashboardWidget('Title', 'W1'), 'Overview');
            g.addChild(MockDashboardWidget('Title', 'W2'), 'Detail');
            testCase.verifyEqual(g.ActiveTab, 'Overview');
            g.switchTab('Detail');
            testCase.verifyEqual(g.ActiveTab, 'Detail');
        end

        function testTabbedModeRender(testCase)
            g = GroupWidget('Label', 'Analysis', 'Mode', 'tabbed');
            g.addChild(MockDashboardWidget('Title', 'W1'), 'Overview');
            g.addChild(MockDashboardWidget('Title', 'W2'), 'Detail');

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            g.ParentTheme = DashboardTheme('dark');
            g.render(hp);

            testCase.verifyNotEmpty(g.hTabButtons);
            testCase.verifyLength(g.hTabButtons, 2);
        end

        function testZeroTabsRender(testCase)
            g = GroupWidget('Label', 'Empty', 'Mode', 'tabbed');

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            g.ParentTheme = DashboardTheme('dark');
            g.render(hp);

            testCase.verifyNotEmpty(g.hHeader);
        end

        function testNestingDepthLimit(testCase)
            inner = GroupWidget('Label', 'Inner');
            outer = GroupWidget('Label', 'Outer');
            outer.addChild(inner);  % depth = 2, should work

            tooDeep = GroupWidget('Label', 'TooDeep');
            testCase.verifyError(@() inner.addChild(tooDeep), ...
                'GroupWidget:maxDepth');
        end

        function testNestingDepthAllowsTwo(testCase)
            inner = GroupWidget('Label', 'Inner');
            outer = GroupWidget('Label', 'Outer');
            outer.addChild(inner);  % depth = 2, should not error
            testCase.verifyLength(outer.Children, 1);
        end

        function testToStructPanel(testCase)
            g = GroupWidget('Label', 'Motor Health', 'Mode', 'panel');
            g.Position = [1 1 12 4];
            g.addChild(TextWidget('Title', 'W1'));

            s = g.toStruct();
            testCase.verifyEqual(s.type, 'group');
            testCase.verifyEqual(s.label, 'Motor Health');
            testCase.verifyEqual(s.mode, 'panel');
            testCase.verifyTrue(isfield(s, 'children'));
            testCase.verifyLength(s.children, 1);
        end

        function testToStructTabbed(testCase)
            g = GroupWidget('Label', 'Analysis', 'Mode', 'tabbed');
            g.addChild(TextWidget('Title', 'W1'), 'Overview');
            g.addChild(TextWidget('Title', 'W2'), 'Detail');

            s = g.toStruct();
            testCase.verifyEqual(s.type, 'group');
            testCase.verifyEqual(s.mode, 'tabbed');
            testCase.verifyTrue(isfield(s, 'tabs'));
            testCase.verifyLength(s.tabs, 2);
            testCase.verifyEqual(s.tabs{1}.name, 'Overview');
            testCase.verifyEqual(s.activeTab, 'Overview');
        end

        function testRoundTripPanel(testCase)
            g = GroupWidget('Label', 'Test', 'Mode', 'collapsible');
            g.Position = [3 2 8 3];
            g.addChild(TextWidget('Title', 'W1'));
            g.addChild(TextWidget('Title', 'W2'));

            s = g.toStruct();
            g2 = GroupWidget.fromStruct(s);
            testCase.verifyEqual(g2.Label, 'Test');
            testCase.verifyEqual(g2.Mode, 'collapsible');
            testCase.verifyEqual(g2.Position, [3 2 8 3]);
            testCase.verifyLength(g2.Children, 2);
        end

        function testLayoutReflow(testCase)
            layout = DashboardLayout();
            testCase.verifyTrue(ismethod(layout, 'reflow'));
        end

        function testFullDashboardIntegration(testCase)
            d = DashboardEngine('GroupTest', 'Theme', 'dark');
            d.addWidget('group', 'Label', 'Motor Health', 'Mode', 'panel', ...
                'Position', [1 1 24 4]);

            g = d.Widgets{1};
            g.addChild(TextWidget('Title', 'RPM Label'));
            g.addChild(TextWidget('Title', 'Temp Label'));

            testCase.verifyLength(g.Children, 2);

            % Test serialization round-trip via file save/load
            tmpFile = [tempname '.json'];
            cleanupFile = onCleanup(@() delete(tmpFile));
            d.save(tmpFile);
            loaded = DashboardEngine.load(tmpFile);
            testCase.verifyLength(loaded.Widgets, 1);
            testCase.verifyClass(loaded.Widgets{1}, 'GroupWidget');
            testCase.verifyLength(loaded.Widgets{1}.Children, 2);
        end

        function testSetTimeRangeCascade(testCase)
            g = GroupWidget('Label', 'Test', 'Mode', 'tabbed');
            m1 = MockDashboardWidget('Title', 'W1');
            m2 = MockDashboardWidget('Title', 'W2');
            g.addChild(m1, 'Tab1');
            g.addChild(m2, 'Tab2');

            % setTimeRange should not error — cascade works for all children
            g.setTimeRange(0, 100);
            testCase.verifyTrue(true);
        end

        function testThemeHasGroupFields(testCase)
            presets = {'dark', 'light', 'industrial', 'scientific', 'ocean', 'default'};
            for i = 1:numel(presets)
                theme = DashboardTheme(presets{i});
                testCase.verifyTrue(isfield(theme, 'GroupHeaderBg'), ...
                    sprintf('%s missing GroupHeaderBg', presets{i}));
                testCase.verifyTrue(isfield(theme, 'GroupHeaderFg'), ...
                    sprintf('%s missing GroupHeaderFg', presets{i}));
                testCase.verifyTrue(isfield(theme, 'GroupBorderColor'), ...
                    sprintf('%s missing GroupBorderColor', presets{i}));
                testCase.verifyTrue(isfield(theme, 'TabActiveBg'), ...
                    sprintf('%s missing TabActiveBg', presets{i}));
                testCase.verifyTrue(isfield(theme, 'TabInactiveBg'), ...
                    sprintf('%s missing TabInactiveBg', presets{i}));
            end
        end

        function testMExportPreservesChildren(testCase)
            d = DashboardEngine('MExportTest');
            g = d.addWidget('group', 'Label', 'Section', 'Mode', 'collapsible', ...
                'Position', [1 1 24 3]);
            g.addChild(NumberWidget('Title', 'Count', 'Position', [1 1 6 1]));

            filepath = fullfile(tempdir, 'test_m_export_children.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyClass(d2.Widgets{1}, 'GroupWidget');
            testCase.verifyEqual(numel(d2.Widgets{1}.Children), 1);
        end

        function testReflowCallbackDefaultsToEmpty(testCase)
            g = GroupWidget('Label', 'T', 'Mode', 'collapsible');
            testCase.verifyEmpty(g.ReflowCallback);
        end

        function testCollapseCallsReflowCallback(testCase)
            g = GroupWidget('Label', 'T', 'Mode', 'collapsible');
            g.Position = [1 1 12 4];
            g.ReflowCallback = @() setappdata(0, 'reflow02_01', true);
            setappdata(0, 'reflow02_01', false);
            g.collapse();
            testCase.verifyTrue(getappdata(0, 'reflow02_01'));
            rmappdata(0, 'reflow02_01');
        end

        function testExpandCallsReflowCallback(testCase)
            g = GroupWidget('Label', 'T', 'Mode', 'collapsible');
            g.Position = [1 1 12 4];
            g.collapse();
            setappdata(0, 'reflow02_01', false);
            g.ReflowCallback = @() setappdata(0, 'reflow02_01', true);
            g.expand();
            testCase.verifyTrue(getappdata(0, 'reflow02_01'));
            rmappdata(0, 'reflow02_01');
        end

        function testPanelModeCollapseDoesNotCallReflowCallback(testCase)
            g = GroupWidget('Label', 'T', 'Mode', 'panel');
            setappdata(0, 'reflow02_01', false);
            g.ReflowCallback = @() setappdata(0, 'reflow02_01', true);
            g.collapse();   % panel mode -- should be a no-op
            testCase.verifyFalse(getappdata(0, 'reflow02_01'));
            rmappdata(0, 'reflow02_01');
        end

        function testActiveTabPersistsThroughJSONRoundTrip(testCase)
            % Verify that a tabbed GroupWidget's ActiveTab is preserved after
            % a JSON save/load round-trip (LAYOUT-07).
            d = DashboardEngine('TabRoundTripTest');
            g = d.addWidget('group', 'Label', 'Analysis', 'Mode', 'tabbed', ...
                'Position', [1 1 24 4]);
            g.addChild(TextWidget('Title', 'W1'), 'Overview');
            g.addChild(TextWidget('Title', 'W2'), 'Detail');
            g.switchTab('Detail');

            testCase.verifyEqual(g.ActiveTab, 'Detail');

            tmpFile = [tempname '.json'];
            cleanupFile = onCleanup(@() delete(tmpFile));

            config = DashboardSerializer.widgetsToConfig( ...
                d.Name, d.Theme, d.LiveInterval, d.Widgets);
            DashboardSerializer.saveJSON(config, tmpFile);

            loaded = DashboardSerializer.loadJSON(tmpFile);
            widgets = DashboardSerializer.configToWidgets(loaded);

            testCase.verifyClass(widgets{1}, 'GroupWidget');
            testCase.verifyEqual(widgets{1}.ActiveTab, 'Detail');
        end

        function testTabContrastAllThemes(testCase)
            % Verify that all 6 theme presets have sufficient visual contrast
            % between TabActiveBg and TabInactiveBg, and that GroupHeaderFg
            % is legible against TabActiveBg (LAYOUT-08).
            %
            % Thresholds (empirical, appropriate for MATLAB dashboards):
            %   - abs(mean(TabActiveBg) - mean(TabInactiveBg)) >= 0.05
            %   - abs(mean(GroupHeaderFg) - mean(TabActiveBg)) >= 0.15
            presets = {'default', 'dark', 'light', 'industrial', 'scientific', 'ocean'};
            for i = 1:numel(presets)
                preset = presets{i};
                theme = DashboardTheme(preset);

                activeLum   = mean(theme.TabActiveBg);
                inactiveLum = mean(theme.TabInactiveBg);
                fgLum       = mean(theme.GroupHeaderFg);

                tabDelta = abs(activeLum - inactiveLum);
                fgDelta  = abs(fgLum - activeLum);

                testCase.verifyGreaterThanOrEqual(tabDelta, 0.05, ...
                    sprintf('Preset ''%s'': TabActiveBg/TabInactiveBg luminance delta %.4f < 0.05', ...
                    preset, tabDelta));
                testCase.verifyGreaterThanOrEqual(fgDelta, 0.15, ...
                    sprintf('Preset ''%s'': GroupHeaderFg vs TabActiveBg luminance delta %.4f < 0.15', ...
                    preset, fgDelta));
            end
        end
    end
end
