classdef TestSensor < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstructorDefaults(testCase)
            s = Sensor('pressure');
            testCase.verifyEqual(s.Key, 'pressure', 'testConstructor: Key');
            testCase.verifyEqual(s.KeyName, 'pressure', 'testConstructor: KeyName defaults to Key');
            testCase.verifyEmpty(s.Name, 'testConstructor: Name default');
            testCase.verifyEmpty(s.ID, 'testConstructor: ID default');
            testCase.verifyEmpty(s.X, 'testConstructor: X default');
            testCase.verifyEmpty(s.Y, 'testConstructor: Y default');
        end

        function testConstructorWithOptions(testCase)
            s = Sensor('pressure', 'Name', 'Chamber Pressure', 'ID', 101, ...
                'MatFile', 'data.mat', 'KeyName', 'press_ch1', ...
                'Source', 'raw/pressure.dta');
            testCase.verifyEqual(s.Name, 'Chamber Pressure', 'testOptions: Name');
            testCase.verifyEqual(s.ID, 101, 'testOptions: ID');
            testCase.verifyEqual(s.MatFile, 'data.mat', 'testOptions: MatFile');
            testCase.verifyEqual(s.KeyName, 'press_ch1', 'testOptions: KeyName');
            testCase.verifyEqual(s.Source, 'raw/pressure.dta', 'testOptions: Source');
        end

        function testAddStateChannel(testCase)
            s = Sensor('pressure');
            sc = StateChannel('machine_state');
            sc.X = [1 5 10]; sc.Y = [0 1 2];
            s.addStateChannel(sc);
            testCase.verifyEqual(numel(s.StateChannels), 1, 'testAddStateChannel: count');
            testCase.verifyEqual(s.StateChannels{1}.Key, 'machine_state', 'testAddStateChannel: key');
        end

        function testAddThreshold(testCase)
            s = Sensor('pressure');
            t = Threshold('hh', 'Name', 'HH', 'Direction', 'upper');
            t.addCondition(struct('machine', 1), 50);
            s.addThreshold(t);
            testCase.verifyEqual(numel(s.Thresholds), 1, 'testAddThreshold: count');
            testCase.verifyEqual(s.Thresholds{1}.Key, 'hh', 'testAddThreshold: key');
            testCase.verifyEqual(s.Thresholds{1}.conditions_{1}.Value, 50, 'testAddThreshold: value');
            testCase.verifyEqual(s.Thresholds{1}.Name, 'HH', 'testAddThreshold: name');
        end

        function testAddThresholdMultiple(testCase)
            s = Sensor('pressure');
            t1 = Threshold('hh', 'Direction', 'upper');
            t1.addCondition(struct('m', 1), 50);
            t2 = Threshold('h', 'Direction', 'upper');
            t2.addCondition(struct('m', 2), 80);
            t3 = Threshold('ll', 'Direction', 'lower');
            t3.addCondition(struct('m', 1), 10);
            s.addThreshold(t1);
            s.addThreshold(t2);
            s.addThreshold(t3);
            testCase.verifyEqual(numel(s.Thresholds), 3, 'testMultipleThresholds: count');
        end

        function testAddThresholdDuplicate(testCase)
            s = Sensor('pressure');
            t = Threshold('hh', 'Direction', 'upper');
            t.addCondition(struct(), 50);
            s.addThreshold(t);
            % Adding the same threshold again should warn and not grow the list
            testCase.verifyWarning(@() s.addThreshold(t), 'Sensor:duplicateThreshold', ...
                'testDuplicate: warning ID');
            testCase.verifyEqual(numel(s.Thresholds), 1, 'testDuplicate: count unchanged');
        end

        function testRemoveThreshold(testCase)
            s = Sensor('pressure');
            t1 = Threshold('hh', 'Direction', 'upper');
            t1.addCondition(struct(), 50);
            t2 = Threshold('ll', 'Direction', 'lower');
            t2.addCondition(struct(), 10);
            s.addThreshold(t1);
            s.addThreshold(t2);
            testCase.verifyEqual(numel(s.Thresholds), 2, 'testRemove: before');
            s.removeThreshold('hh');
            testCase.verifyEqual(numel(s.Thresholds), 1, 'testRemove: after');
            testCase.verifyEqual(s.Thresholds{1}.Key, 'll', 'testRemove: remaining key');
        end

        function testAddThresholdByKey(testCase)
            % Register a threshold first, then attach by string key
            t = Threshold('press_hh_test', 'Direction', 'upper');
            t.addCondition(struct(), 75);
            ThresholdRegistry.register('press_hh_test', t);
            s = Sensor('pressure');
            s.addThreshold('press_hh_test');
            testCase.verifyEqual(numel(s.Thresholds), 1, 'testByKey: count');
            testCase.verifyEqual(s.Thresholds{1}.Key, 'press_hh_test', 'testByKey: key');
            % Clean up registry
            ThresholdRegistry.unregister('press_hh_test');
        end

        function testUnitsProperty(testCase)
            s = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degC');
            testCase.verifyEqual(s.Units, 'degC');
        end
    end
end
