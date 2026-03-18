classdef TestComputeViolations < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testUpperViolation(testCase)
            x = 1:10;
            y = [1 2 3 4 5 6 5 4 3 2];
            [xV, yV] = compute_violations(x, y, 4.5, 'upper');
            testCase.verifyEqual(xV, [5 6 7], 'testUpperViolation xV');
            testCase.verifyEqual(yV, [5 6 5], 'testUpperViolation yV');
        end

        function testLowerViolation(testCase)
            x = 1:10;
            y = [5 4 3 2 1 0 1 2 3 4];
            [xV, yV] = compute_violations(x, y, 2.5, 'lower');
            testCase.verifyEqual(xV, [4 5 6 7 8], 'testLowerViolation xV');
            testCase.verifyEqual(yV, [2 1 0 1 2], 'testLowerViolation yV');
        end

        function testNoViolations(testCase)
            x = 1:5;
            y = [1 2 3 2 1];
            [xV, yV] = compute_violations(x, y, 10, 'upper');
            testCase.verifyEmpty(xV, 'testNoViolations xV');
            testCase.verifyEmpty(yV, 'testNoViolations yV');
        end

        function testWithNaN(testCase)
            x = 1:10;
            y = [1 2 NaN 8 9 10 NaN 3 2 1];
            [xV, yV] = compute_violations(x, y, 5, 'upper');
            testCase.verifyEqual(xV, [4 5 6], 'testWithNaN xV');
            testCase.verifyEqual(yV, [8 9 10], 'testWithNaN yV');
        end

        function testExactThreshold(testCase)
            x = 1:5;
            y = [1 5 5 5 1];
            [xV, ~] = compute_violations(x, y, 5, 'upper');
            testCase.verifyEmpty(xV, 'testExactThreshold: exact match should not violate');
        end
    end
end
