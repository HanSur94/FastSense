classdef TestComputeViolationsDynamic < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testUpperStepFunction(testCase)
            thX = [0 10 20];
            thY = [5  8  8];
            x = 1:20;
            y = [3 4 6 7 4 5 6 7 8 9   3 4 5 6 7 8 9 10 7 6];
            [xV, yV] = compute_violations_dynamic(x, y, thX, thY, 'upper');
            expectedX = [3 4 7 8 9 10 17 18];
            expectedY = [6 7 6 7 8  9  9 10];
            testCase.verifyEqual(xV, expectedX, sprintf('testUpperStep: xV mismatch, got [%s]', num2str(xV)));
            testCase.verifyEqual(yV, expectedY, 'testUpperStep: yV mismatch');
        end

        function testLowerStepFunction(testCase)
            thX = [0 10];
            thY = [3  6];
            x = 1:15;
            y = [1 2 3 4 5 1 2 3 4 5  4 5 6 7 8];
            [xV, yV] = compute_violations_dynamic(x, y, thX, thY, 'lower');
            testCase.verifyEqual(xV, [1 2 6 7 10 11 12], 'testLowerStep: xV');
            testCase.verifyEqual(yV, [1 2 1 2 5 4 5], 'testLowerStep: yV');
        end

        function testNoViolations(testCase)
            thX = [0 10];
            thY = [100 100];
            x = 1:10;
            y = ones(1, 10);
            [xV, yV] = compute_violations_dynamic(x, y, thX, thY, 'upper');
            testCase.verifyEmpty(xV, 'testNoViolations: xV');
            testCase.verifyEmpty(yV, 'testNoViolations: yV');
        end

        function testWithNaN(testCase)
            thX = [0 10];
            thY = [5 5];
            x = 1:5;
            y = [6 NaN 7 NaN 8];
            [xV, yV] = compute_violations_dynamic(x, y, thX, thY, 'upper');
            testCase.verifyEqual(xV, [1 3 5], 'testWithNaN: xV');
            testCase.verifyEqual(yV, [6 7 8], 'testWithNaN: yV');
        end

        function testScalarEquivalence(testCase)
            thX = [0];
            thY = [5];
            x = 1:10;
            y = [1 2 3 4 5 6 7 8 9 10];
            [xV1, yV1] = compute_violations_dynamic(x, y, thX, thY, 'upper');
            [xV2, yV2] = compute_violations(x, y, 5, 'upper');
            testCase.verifyEqual(xV1, xV2, 'testScalarEquiv: xV');
            testCase.verifyEqual(yV1, yV2, 'testScalarEquiv: yV');
        end

        function testDataOutsideThresholdRange(testCase)
            thX = [5 10];
            thY = [3  6];
            x = 1:12;
            y = [4 4 4 4 4 4 4 4 4 4 7 7];
            [xV, ~] = compute_violations_dynamic(x, y, thX, thY, 'upper');
            testCase.verifyEqual(xV, [1 2 3 4 5 6 7 8 9 11 12], 'testExtrapolate: xV');
        end
    end
end
