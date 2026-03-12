classdef TestDashboardWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testIsAbstract(testCase)
            testCase.verifyError(@() DashboardWidget(), ...
                'MATLAB:class:abstract', ...
                'DashboardWidget should be abstract');
        end

        function testToStructFromStructRoundTrip(testCase)
            w = MockDashboardWidget();
            w.Title = 'Test Widget';
            w.Position = [1 2 4 3];

            s = w.toStruct();
            testCase.verifyEqual(s.title, 'Test Widget');
            testCase.verifyEqual(s.position, struct('col', 1, 'row', 2, 'width', 4, 'height', 3));

            w2 = MockDashboardWidget.fromStruct(s);
            testCase.verifyEqual(w2.Title, 'Test Widget');
            testCase.verifyEqual(w2.Position, [1 2 4 3]);
        end

        function testDefaultPosition(testCase)
            w = MockDashboardWidget();
            testCase.verifyEqual(w.Position, [1 1 3 2], ...
                'Default position should be [1 1 3 2]');
        end

        function testTypeProperty(testCase)
            w = MockDashboardWidget();
            testCase.verifyEqual(w.Type, 'mock', ...
                'Type should return widget type string');
        end
    end
end
