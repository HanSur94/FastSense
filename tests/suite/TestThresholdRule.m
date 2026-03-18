classdef TestThresholdRule < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstructorDefaults(testCase)
            rule = ThresholdRule(struct('x', 1), 50);
            testCase.verifyEqual(rule.Value, 50, 'testConstructorDefaults: Value');
            testCase.verifyEqual(rule.Direction, 'upper', 'testConstructorDefaults: Direction default');
            testCase.verifyEmpty(rule.Label, 'testConstructorDefaults: Label default');
            testCase.verifyEmpty(rule.Color, 'testConstructorDefaults: Color default');
            testCase.verifyEqual(rule.LineStyle, '--', 'testConstructorDefaults: LineStyle default');
        end

        function testConstructorWithOptions(testCase)
            rule = ThresholdRule(struct('x', 2), 100, ...
                'Direction', 'lower', 'Label', 'Low Alarm', ...
                'Color', [1 0 0], 'LineStyle', ':');
            testCase.verifyEqual(rule.Value, 100, 'testConstructorWithOptions: Value');
            testCase.verifyEqual(rule.Direction, 'lower', 'testConstructorWithOptions: Direction');
            testCase.verifyEqual(rule.Label, 'Low Alarm', 'testConstructorWithOptions: Label');
            testCase.verifyEqual(rule.Color, [1 0 0], 'testConstructorWithOptions: Color');
            testCase.verifyEqual(rule.LineStyle, ':', 'testConstructorWithOptions: LineStyle');
        end

        function testConditionEvaluation(testCase)
            rule = ThresholdRule(struct('machine', 1, 'zone', 0), 50);
            testCase.verifyTrue(rule.matchesState(struct('machine', 1, 'zone', 0)), 'testConditionEval: true case');
            testCase.verifyTrue(~rule.matchesState(struct('machine', 2, 'zone', 0)), 'testConditionEval: false case');
        end

        function testInvalidDirection(testCase)
            threw = false;
            try
                ThresholdRule(struct(), 50, 'Direction', 'sideways');
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'testInvalidDirection: should throw');
        end
    end
end
