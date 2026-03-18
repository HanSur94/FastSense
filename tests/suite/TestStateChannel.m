classdef TestStateChannel < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstructorDefaults(testCase)
            sc = StateChannel('machine_state', 'MatFile', 'data/states.mat');
            testCase.verifyEqual(sc.Key, 'machine_state', 'testConstructor: Key');
            testCase.verifyEqual(sc.MatFile, 'data/states.mat', 'testConstructor: MatFile');
            testCase.verifyEqual(sc.KeyName, 'machine_state', 'testConstructor: KeyName defaults to Key');
        end

        function testConstructorCustomKeyName(testCase)
            sc = StateChannel('ms', 'MatFile', 'data/states.mat', 'KeyName', 'machine_state');
            testCase.verifyEqual(sc.Key, 'ms', 'testCustomKeyName: Key');
            testCase.verifyEqual(sc.KeyName, 'machine_state', 'testCustomKeyName: KeyName');
        end

        function testValueAtNumeric(testCase)
            sc = StateChannel('state');
            sc.X = [1 5 10 20];
            sc.Y = [0 1 2 3];
            testCase.verifyEqual(sc.valueAt(0), 0, 'testValueAt: before first -> first value');
            testCase.verifyEqual(sc.valueAt(1), 0, 'testValueAt: at first timestamp');
            testCase.verifyEqual(sc.valueAt(3), 0, 'testValueAt: between 1 and 5');
            testCase.verifyEqual(sc.valueAt(5), 1, 'testValueAt: at second timestamp');
            testCase.verifyEqual(sc.valueAt(7), 1, 'testValueAt: between 5 and 10');
            testCase.verifyEqual(sc.valueAt(15), 2, 'testValueAt: between 10 and 20');
            testCase.verifyEqual(sc.valueAt(100), 3, 'testValueAt: after last');
        end

        function testValueAtString(testCase)
            sc = StateChannel('mode');
            sc.X = [1 5 10];
            sc.Y = {'off', 'running', 'evacuated'};
            testCase.verifyEqual(sc.valueAt(3), 'off', 'testValueAtString: before change');
            testCase.verifyEqual(sc.valueAt(7), 'running', 'testValueAtString: after change');
            testCase.verifyEqual(sc.valueAt(15), 'evacuated', 'testValueAtString: last');
        end

        function testValueAtBulk(testCase)
            sc = StateChannel('state');
            sc.X = [1 5 10];
            sc.Y = [0 1 2];
            vals = sc.valueAt([0 3 5 7 15]);
            testCase.verifyEqual(vals, [0 0 1 1 2], 'testValueAtBulk');
        end
    end
end
