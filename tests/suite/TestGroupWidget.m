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
    end
end
