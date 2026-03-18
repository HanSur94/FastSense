classdef TestDownsampleViolations < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testBasicDownsample(testCase)
            xV = [1.0, 1.1, 1.2, 2.0, 2.1, 2.2, 3.0, 3.1, 3.2, 3.3];
            yV = [5.0, 5.5, 5.2, 6.0, 6.3, 6.1, 7.0, 7.5, 7.2, 7.8];
            pixelWidth = 1.0;
            threshVal = 4.0;
            [xD, yD] = downsample_violations(xV, yV, pixelWidth, threshVal, 0.0);
            testCase.verifyEqual(numel(xD), 3, sprintf('testBasicDownsample: expected 3 points, got %d', numel(xD)));
            testCase.verifyEqual(xD(1), 1.1, 'testBasicDownsample: wrong x for col 1');
            testCase.verifyEqual(yD(1), 5.5, 'testBasicDownsample: wrong y for col 1');
            testCase.verifyEqual(xD(2), 2.1, 'testBasicDownsample: wrong x for col 2');
            testCase.verifyEqual(yD(2), 6.3, 'testBasicDownsample: wrong y for col 2');
            testCase.verifyEqual(xD(3), 3.3, 'testBasicDownsample: wrong x for col 3');
            testCase.verifyEqual(yD(3), 7.8, 'testBasicDownsample: wrong y for col 3');
        end

        function testLowerThreshold(testCase)
            xV = [1.0, 1.1, 2.0, 2.1];
            yV = [3.0, 2.5, 1.0, 1.5];
            pixelWidth = 1.0;
            threshVal = 4.0;
            [xD, yD] = downsample_violations(xV, yV, pixelWidth, threshVal, 0.0);
            testCase.verifyEqual(numel(xD), 2, 'testLowerThreshold: expected 2 points');
            testCase.verifyEqual(yD(1), 2.5, 'testLowerThreshold: wrong y for col 1');
            testCase.verifyEqual(yD(2), 1.0, 'testLowerThreshold: wrong y for col 2');
        end

        function testEmpty(testCase)
            [xD, yD] = downsample_violations([], [], 1.0, 5.0, 0.0);
            testCase.verifyEmpty(xD, 'testEmpty xD');
            testCase.verifyEmpty(yD, 'testEmpty yD');
        end

        function testSinglePoint(testCase)
            [xD, yD] = downsample_violations(5, 10, 1.0, 4.0, 0.0);
            testCase.verifyEqual(xD, 5, 'testSinglePoint xD');
            testCase.verifyEqual(yD, 10, 'testSinglePoint yD');
        end

        function testAlreadySparse(testCase)
            xV = [1, 3, 5, 7, 9];
            yV = [6, 7, 8, 9, 10];
            [xD, yD] = downsample_violations(xV, yV, 1.0, 5.0, 0.0);
            testCase.verifyEqual(numel(xD), 5, 'testAlreadySparse: expected 5 points');
        end

        function testWithNaN(testCase)
            xV = [1.0, 1.1, NaN, 3.0, 3.1];
            yV = [5.0, 5.5, NaN, 7.0, 7.5];
            [xD, yD] = downsample_violations(xV, yV, 1.0, 4.0, 0.0);
            testCase.verifyEqual(numel(xD), 2, sprintf('testWithNaN: expected 2 points, got %d', numel(xD)));
        end

        function testLargeOffset(testCase)
            xV = [1e6 + 0.1, 1e6 + 0.2, 1e6 + 1.1, 1e6 + 1.2];
            yV = [5.0, 5.5, 6.0, 6.3];
            [xD, yD] = downsample_violations(xV, yV, 1.0, 4.0, 1e6);
            testCase.verifyEqual(numel(xD), 2, sprintf('testLargeOffset: expected 2 points, got %d', numel(xD)));
            testCase.verifyEqual(yD(1), 5.5, 'testLargeOffset: wrong y for col 1');
            testCase.verifyEqual(yD(2), 6.3, 'testLargeOffset: wrong y for col 2');
        end
    end
end
