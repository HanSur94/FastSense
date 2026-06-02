classdef TestIsThresholdViolated < matlab.unittest.TestCase
%TESTISTHRESHOLDVIOLATED Tests the shared strict threshold-violation predicate.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testUpperStrict(testCase)
            t = MockThreshold(true, 10);
            testCase.verifyTrue(isThresholdViolated(t, 11));    % strictly above -> violated
            testCase.verifyFalse(isThresholdViolated(t, 10));   % exactly on limit -> NOT violated
            testCase.verifyFalse(isThresholdViolated(t, 9));    % below -> ok
        end

        function testLowerStrict(testCase)
            t = MockThreshold(false, 5);
            testCase.verifyTrue(isThresholdViolated(t, 4));     % strictly below -> violated
            testCase.verifyFalse(isThresholdViolated(t, 5));    % exactly on limit -> NOT violated
            testCase.verifyFalse(isThresholdViolated(t, 6));    % above -> ok
        end

        function testMultipleValues(testCase)
            t = MockThreshold(true, [10 20 30]);
            testCase.verifyTrue(isThresholdViolated(t, 25));    % 25 > 10 -> violated
            testCase.verifyFalse(isThresholdViolated(t, 5));    % below all limits -> ok
            % Clean boundary test: single value so "on limit" is unambiguous.
            tSingle = MockThreshold(true, 30);
            testCase.verifyFalse(isThresholdViolated(tSingle, 30));  % exactly on -> NOT violated (strict)
            testCase.verifyTrue(isThresholdViolated(tSingle, 31));   % just above -> violated
        end

        function testEmptyGuards(testCase)
            testCase.verifyFalse(isThresholdViolated([], 5));
            testCase.verifyFalse(isThresholdViolated(MockThreshold(true, 10), []));
            % Composite threshold (no condition values) -> never violated here.
            testCase.verifyFalse(isThresholdViolated(MockThreshold(true, []), 5));
        end
    end
end
