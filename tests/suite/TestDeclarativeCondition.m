classdef TestDeclarativeCondition < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testStructCondition(testCase)
            rule = ThresholdRule(struct('machine', 1), 50, 'Direction', 'upper');
            testCase.verifyTrue(isstruct(rule.Condition), 'struct condition stored');
            testCase.verifyEqual(rule.Condition.machine, 1, 'field value stored');
            testCase.verifyEqual(rule.Value, 50, 'threshold value');
            testCase.verifyEqual(rule.Direction, 'upper', 'direction');
        end

        function testMultiFieldCondition(testCase)
            rule = ThresholdRule(struct('machine', 1, 'vacuum', 2), 80);
            testCase.verifyEqual(rule.Condition.machine, 1, 'multi: machine');
            testCase.verifyEqual(rule.Condition.vacuum, 2, 'multi: vacuum');
        end

        function testMatchesStateSingleField(testCase)
            rule = ThresholdRule(struct('machine', 1), 50);
            testCase.verifyTrue(rule.matchesState(struct('machine', 1)), 'match true');
            testCase.verifyTrue(~rule.matchesState(struct('machine', 0)), 'match false');
            testCase.verifyTrue(rule.matchesState(struct('machine', 1, 'zone', 2)), 'match ignores extra');
        end

        function testMatchesStateMultiField(testCase)
            rule = ThresholdRule(struct('machine', 1, 'vacuum', 2), 50);
            testCase.verifyTrue(rule.matchesState(struct('machine', 1, 'vacuum', 2)), 'multi match');
            testCase.verifyTrue(~rule.matchesState(struct('machine', 1, 'vacuum', 0)), 'multi partial');
            testCase.verifyTrue(~rule.matchesState(struct('machine', 0, 'vacuum', 2)), 'multi other partial');
        end

        function testEmptyCondition(testCase)
            rule = ThresholdRule(struct(), 50, 'Direction', 'upper');
            testCase.verifyTrue(rule.matchesState(struct('machine', 1)), 'empty always true');
            testCase.verifyTrue(rule.matchesState(struct()), 'empty vs empty');
        end

        function testDefaults(testCase)
            rule = ThresholdRule(struct('m', 1), 50);
            testCase.verifyEqual(rule.Direction, 'upper', 'default direction');
            testCase.verifyEqual(rule.LineStyle, '--', 'default line style');
            testCase.verifyEmpty(rule.Label, 'default label');
            testCase.verifyEmpty(rule.Color, 'default color');
        end
    end
end
