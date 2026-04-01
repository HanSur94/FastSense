classdef TestDashboardPage < matlab.unittest.TestCase
    %TESTDASHBOARDPAGE TDD RED tests for DashboardPage handle class.
    %   These tests verify basic DashboardPage construction, addWidget, and toStruct.
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            pg = DashboardPage();
            testCase.verifyEqual(pg.Name, '');
            testCase.verifyEqual(pg.Widgets, {});
        end

        function testNamedConstruction(testCase)
            pg = DashboardPage('Overview');
            testCase.verifyEqual(pg.Name, 'Overview');
        end

        function testIsHandle(testCase)
            pg = DashboardPage();
            testCase.verifyTrue(isa(pg, 'handle'));
        end

        function testIsDashboardPage(testCase)
            pg = DashboardPage();
            testCase.verifyTrue(isa(pg, 'DashboardPage'));
        end

        function testAddWidget(testCase)
            pg = DashboardPage('Test');
            w = MockDashboardWidget('Title', 'W1');
            pg.addWidget(w);
            testCase.verifyEqual(numel(pg.Widgets), 1);
        end

        function testAddWidgetMultiple(testCase)
            pg = DashboardPage('Test');
            w1 = MockDashboardWidget('Title', 'W1');
            w2 = MockDashboardWidget('Title', 'W2');
            pg.addWidget(w1);
            pg.addWidget(w2);
            testCase.verifyEqual(numel(pg.Widgets), 2);
        end

        function testToStruct(testCase)
            pg = DashboardPage('Details');
            w = MockDashboardWidget('Title', 'W1');
            pg.addWidget(w);
            s = pg.toStruct();
            testCase.verifyEqual(s.name, 'Details');
            testCase.verifyEqual(numel(s.widgets), 1);
        end
    end
end
