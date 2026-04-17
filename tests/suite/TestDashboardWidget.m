classdef TestDashboardWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
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
            w.Position = [1 2 8 3];

            s = w.toStruct();
            testCase.verifyEqual(s.title, 'Test Widget');
            testCase.verifyEqual(s.position, struct('col', 1, 'row', 2, 'width', 8, 'height', 3));

            w2 = MockDashboardWidget.fromStruct(s);
            testCase.verifyEqual(w2.Title, 'Test Widget');
            testCase.verifyEqual(w2.Position, [1 2 8 3]);
        end

        function testDefaultPosition(testCase)
            w = MockDashboardWidget();
            testCase.verifyEqual(w.Position, [1 1 6 2], ...
                'Default position should be [1 1 6 2]');
        end

        function testTypeProperty(testCase)
            w = MockDashboardWidget();
            testCase.verifyEqual(w.Type, 'mock', ...
                'Type should return widget type string');
        end

        function testDescriptionProperty(testCase)
            w = MockDashboardWidget('Description', 'Measures outlet temp');
            testCase.verifyEqual(w.Description, 'Measures outlet temp');
        end

        function testSensorProperty(testCase)
            s = SensorTag('T-401', 'Name', 'Temperature');
            w = MockDashboardWidget('Sensor', s);
            testCase.verifyEqual(w.Sensor.Key, 'T-401');
        end

        function testTitleDefaultsToSensorName(testCase)
            s = SensorTag('T-401', 'Name', 'Temperature');
            w = MockDashboardWidget('Sensor', s);
            testCase.verifyEqual(w.Title, 'Temperature');
        end

        function testTitleOverrideBeatsSensorName(testCase)
            s = SensorTag('T-401', 'Name', 'Temperature');
            w = MockDashboardWidget('Title', 'Custom', 'Sensor', s);
            testCase.verifyEqual(w.Title, 'Custom');
        end

        function testToStructIncludesDescription(testCase)
            w = MockDashboardWidget('Title', 'Test', 'Description', 'Info text');
            s = w.toStruct();
            testCase.verifyEqual(s.description, 'Info text');
        end
    end
end
