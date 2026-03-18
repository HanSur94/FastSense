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

        function testAddThresholdRule(testCase)
            s = Sensor('pressure');
            s.addThresholdRule(struct('machine', 1), 50, 'Direction', 'upper', 'Label', 'HH');
            testCase.verifyEqual(numel(s.ThresholdRules), 1, 'testAddThresholdRule: count');
            testCase.verifyEqual(s.ThresholdRules{1}.Value, 50, 'testAddThresholdRule: value');
            testCase.verifyEqual(s.ThresholdRules{1}.Label, 'HH', 'testAddThresholdRule: label');
        end

        function testAddMultipleRules(testCase)
            s = Sensor('pressure');
            s.addThresholdRule(struct('m', 1), 50, 'Direction', 'upper');
            s.addThresholdRule(struct('m', 2), 80, 'Direction', 'upper');
            s.addThresholdRule(struct('m', 1), 10, 'Direction', 'lower');
            testCase.verifyEqual(numel(s.ThresholdRules), 3, 'testMultipleRules: count');
        end

        function testUnitsProperty(testCase)
            s = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degC');
            testCase.verifyEqual(s.Units, 'degC');
        end
    end
end
