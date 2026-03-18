classdef TestSensorRegistry < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testGetReturnsASensor(testCase)
            s = SensorRegistry.get('pressure');
            testCase.verifyTrue(isa(s, 'Sensor'), 'testGet: returns Sensor');
            testCase.verifyEqual(s.Key, 'pressure', 'testGet: correct key');
        end

        function testGetUnknownKeyThrows(testCase)
            threw = false;
            try
                SensorRegistry.get('nonexistent_sensor_xyz');
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'testGetUnknown: should throw');
        end

        function testGetMultiple(testCase)
            sensors = SensorRegistry.getMultiple({'pressure', 'temperature'});
            testCase.verifyEqual(numel(sensors), 2, 'testGetMultiple: count');
            testCase.verifyTrue(isa(sensors{1}, 'Sensor'), 'testGetMultiple: type 1');
            testCase.verifyTrue(isa(sensors{2}, 'Sensor'), 'testGetMultiple: type 2');
        end

        function testList(testCase)
            % Should not error
            SensorRegistry.list();
        end

        function testPrintTable(testCase)
            % Should not error
            SensorRegistry.printTable();
        end

        function testViewer(testCase)
            hFig = SensorRegistry.viewer();
            testCase.addTeardown(@close, hFig);
            testCase.verifyTrue(ishandle(hFig), 'testViewer: returns figure handle');
        end
    end
end
