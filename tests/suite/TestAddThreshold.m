classdef TestAddThreshold < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testAddUpperThreshold(testCase)
            fp = FastSense();
            fp.addThreshold(4.5, 'Direction', 'upper');
            testCase.verifyEqual(numel(fp.Thresholds), 1, 'testAddUpperThreshold: count');
            testCase.verifyEqual(fp.Thresholds(1).Value, 4.5, 'testAddUpperThreshold: value');
            testCase.verifyEqual(fp.Thresholds(1).Direction, 'upper', 'testAddUpperThreshold: direction');
        end

        function testAddLowerThreshold(testCase)
            fp = FastSense();
            fp.addThreshold(-2.0, 'Direction', 'lower');
            testCase.verifyEqual(fp.Thresholds(1).Direction, 'lower', 'testAddLowerThreshold');
        end

        function testDefaults(testCase)
            fp = FastSense();
            fp.addThreshold(5.0);
            testCase.verifyEqual(fp.Thresholds(1).Direction, 'upper', 'testDefaults: direction');
            testCase.verifyEqual(fp.Thresholds(1).ShowViolations, false, 'testDefaults: ShowViolations');
            testCase.verifyEqual(fp.Thresholds(1).LineStyle, '--', 'testDefaults: LineStyle');
            testCase.verifyEqual(fp.Thresholds(1).Label, '', 'testDefaults: Label');
        end

        function testCustomOptions(testCase)
            fp = FastSense();
            fp.addThreshold(3.0, 'Direction', 'lower', ...
                'ShowViolations', true, 'Color', [1 0 0], ...
                'LineStyle', ':', 'Label', 'LowerBound');
            t = fp.Thresholds(1);
            testCase.verifyEqual(t.ShowViolations, true, 'testCustomOptions: ShowViolations');
            testCase.verifyEqual(t.Color, [1 0 0], 'testCustomOptions: Color');
            testCase.verifyEqual(t.LineStyle, ':', 'testCustomOptions: LineStyle');
            testCase.verifyEqual(t.Label, 'LowerBound', 'testCustomOptions: Label');
        end

        function testMultipleThresholds(testCase)
            fp = FastSense();
            fp.addThreshold(1.0);
            fp.addThreshold(2.0);
            fp.addThreshold(3.0);
            testCase.verifyEqual(numel(fp.Thresholds), 3, 'testMultipleThresholds');
        end

        function testTimeVaryingThreshold(testCase)
            fp = FastSense();
            thX = [0 10 20 30];
            thY = [5.0 5.0 7.0 7.0];
            fp.addThreshold(thX, thY, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'StepTh');
            testCase.verifyEqual(numel(fp.Thresholds), 1, 'testTimeVarying: count');
            testCase.verifyEmpty(fp.Thresholds(1).Value, 'testTimeVarying: Value should be empty');
            testCase.verifyEqual(fp.Thresholds(1).X, thX, 'testTimeVarying: X');
            testCase.verifyEqual(fp.Thresholds(1).Y, thY, 'testTimeVarying: Y');
            testCase.verifyEqual(fp.Thresholds(1).Direction, 'upper', 'testTimeVarying: direction');
            testCase.verifyEqual(fp.Thresholds(1).ShowViolations, true, 'testTimeVarying: ShowViolations');
        end

        function testMixedThresholds(testCase)
            fp = FastSense();
            fp.addThreshold(4.5);
            fp.addThreshold([0 10], [3.0 5.0], 'Direction', 'lower');
            testCase.verifyEqual(numel(fp.Thresholds), 2, 'testMixed: count');
            testCase.verifyEqual(fp.Thresholds(1).Value, 4.5, 'testMixed: scalar Value');
            testCase.verifyEmpty(fp.Thresholds(2).Value, 'testMixed: tv Value empty');
        end
    end
end
