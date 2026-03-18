classdef TestAddSensor < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testAddSensorBasic(testCase)
            s = Sensor('pressure', 'Name', 'Chamber Pressure');
            s.X = 1:100;
            s.Y = rand(1, 100) * 10;
            s.resolve();

            fp = FastSense();
            fp.addSensor(s);
            testCase.verifyEqual(numel(fp.Lines), 1, 'testBasic: one line added');
            testCase.verifyEqual(fp.Lines(1).Options.DisplayName, 'Chamber Pressure', 'testBasic: display name');
        end

        function testAddSensorWithThresholds(testCase)
            s = Sensor('pressure', 'Name', 'Pressure');
            s.X = 1:100;
            s.Y = [ones(1,50)*5, ones(1,50)*15];

            sc = StateChannel('machine');
            sc.X = [1 50]; sc.Y = [0 1];
            s.addStateChannel(sc);
            s.addThresholdRule(struct('machine', 1), 10, 'Direction', 'upper', 'Label', 'HH');
            s.resolve();

            fp = FastSense();
            fp.addSensor(s, 'ShowThresholds', true);
            testCase.verifyEqual(numel(fp.Lines), 1, 'testWithThresholds: only data line');
            testCase.verifyTrue(numel(fp.Thresholds) >= 1, 'testWithThresholds: threshold(s) added');
            testCase.verifyEqual(fp.Thresholds(1).ShowViolations, true, 'testWithThresholds: ShowViolations on');
            testCase.verifyNotEmpty(fp.Thresholds(1).X, 'testWithThresholds: time-varying threshold');
        end

        function testAddSensorNoThresholds(testCase)
            s = Sensor('temp', 'Name', 'Temperature');
            s.X = 1:50;
            s.Y = rand(1, 50);
            s.addThresholdRule(struct(), 5, 'Direction', 'upper');
            s.resolve();

            fp = FastSense();
            fp.addSensor(s, 'ShowThresholds', false);
            testCase.verifyEqual(numel(fp.Lines), 1, 'testNoThresholds: only data line');
            testCase.verifyEqual(numel(fp.Thresholds), 0, 'testNoThresholds: no thresholds');
        end

        function testAddSensorUsesKeyAsFallbackName(testCase)
            s = Sensor('flow_rate');
            s.X = 1:10;
            s.Y = rand(1, 10);
            s.resolve();

            fp = FastSense();
            fp.addSensor(s);
            testCase.verifyEqual(fp.Lines(1).Options.DisplayName, 'flow_rate', 'testFallbackName: uses Key');
        end
    end
end
