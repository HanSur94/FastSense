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

        function testLayoutReflow(testCase)
            layout = DashboardLayout();
            testCase.verifyTrue(ismethod(layout, 'reflow'));
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
    end
end
