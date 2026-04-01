classdef TestDashboardMSerializer < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testSaveProducesMFile(testCase)
            d = DashboardEngine('SaveTest');
            d.Theme = 'dark';
            d.LiveInterval = 3;
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', 1:10);

            filepath = fullfile(tempdir, 'test_save_dash.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            testCase.verifyTrue(exist(filepath, 'file') == 2);
            content = fileread(filepath);
            testCase.verifyFalse(isempty(strfind(content, 'DashboardEngine')));
            testCase.verifyFalse(isempty(strfind(content, 'function')));
        end

        function testLoadFromMFile(testCase)
            d = DashboardEngine('LoadTest');
            d.Theme = 'dark';
            d.LiveInterval = 3;
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', 1:10);

            filepath = fullfile(tempdir, 'test_load_dash.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(d2.Name, 'LoadTest');
            testCase.verifyEqual(d2.Theme, 'dark');
            testCase.verifyEqual(d2.LiveInterval, 3);
            testCase.verifyEqual(numel(d2.Widgets), 1);
        end

        function testAddWidgetReturnsHandle(testCase)
            d = DashboardEngine('ReturnTest');
            w = d.addWidget('number', 'Title', 'RPM', ...
                'Position', [1 1 6 1]);
            testCase.verifyClass(w, 'NumberWidget');
            testCase.verifyEqual(w.Title, 'RPM');
        end

        function testGroupWithChildrenRoundTrip(testCase)
            d = DashboardEngine('GroupPanel');
            g = d.addWidget('group', 'Label', 'Motors', 'Mode', 'panel', ...
                'Position', [1 1 24 4]);
            g.addChild(TextWidget('Title', 'RPM', 'Position', [1 1 6 1]));
            g.addChild(TextWidget('Title', 'Temp', 'Position', [7 1 6 1]));

            filepath = fullfile(tempdir, 'test_group_children.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(numel(d2.Widgets), 1);
            testCase.verifyClass(d2.Widgets{1}, 'GroupWidget');
            testCase.verifyEqual(numel(d2.Widgets{1}.Children), 2);
            testCase.verifyEqual(d2.Widgets{1}.Children{1}.Title, 'RPM');
            testCase.verifyEqual(d2.Widgets{1}.Children{2}.Title, 'Temp');
        end

        function testGroupTabbedRoundTrip(testCase)
            d = DashboardEngine('GroupTabbed');
            g = d.addWidget('group', 'Label', 'Analysis', 'Mode', 'tabbed', ...
                'Position', [1 1 24 4]);
            g.addChild(TextWidget('Title', 'Overview', 'Position', [1 1 12 2]), 'Tab1');
            g.addChild(TextWidget('Title', 'Details', 'Position', [1 1 12 2]), 'Tab2');

            filepath = fullfile(tempdir, 'test_group_tabbed.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(numel(d2.Widgets), 1);
            g2 = d2.Widgets{1};
            testCase.verifyClass(g2, 'GroupWidget');
            testCase.verifyEqual(g2.Mode, 'tabbed');
            testCase.verifyEqual(numel(g2.Tabs), 2);
            testCase.verifyEqual(g2.Tabs{1}.name, 'Tab1');
            testCase.verifyEqual(numel(g2.Tabs{1}.widgets), 1);
            testCase.verifyEqual(g2.Tabs{2}.name, 'Tab2');
            testCase.verifyEqual(numel(g2.Tabs{2}.widgets), 1);
        end
    end
end
