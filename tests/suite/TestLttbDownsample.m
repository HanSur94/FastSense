classdef TestLttbDownsample < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testOutputSize(testCase)
            x = 1:1000;
            y = sin(linspace(0, 4*pi, 1000));
            [xOut, yOut] = lttb_downsample(x, y, 50);
            testCase.verifyEqual(numel(xOut), 50, sprintf('testOutputSize xOut: expected 50, got %d', numel(xOut)));
            testCase.verifyEqual(numel(yOut), 50, sprintf('testOutputSize yOut: expected 50, got %d', numel(yOut)));
        end

        function testPreservesEndpoints(testCase)
            x = 1:1000;
            y = rand(1, 1000);
            [xOut, yOut] = lttb_downsample(x, y, 50);
            testCase.verifyEqual(xOut(1), x(1), 'testPreservesEndpoints: first x');
            testCase.verifyEqual(xOut(end), x(end), 'testPreservesEndpoints: last x');
            testCase.verifyEqual(yOut(1), y(1), 'testPreservesEndpoints: first y');
            testCase.verifyEqual(yOut(end), y(end), 'testPreservesEndpoints: last y');
        end

        function testMonotonicX(testCase)
            x = linspace(0, 10, 5000);
            y = randn(1, 5000);
            [xOut, ~] = lttb_downsample(x, y, 100);
            testCase.verifyTrue(all(diff(xOut) > 0), 'testMonotonicX: X must be strictly increasing');
        end

        function testFewPointsPassthrough(testCase)
            x = 1:5;
            y = [10 20 30 40 50];
            [xOut, yOut] = lttb_downsample(x, y, 10);
            testCase.verifyEqual(xOut, x, 'testFewPointsPassthrough xOut');
            testCase.verifyEqual(yOut, y, 'testFewPointsPassthrough yOut');
        end

        function testNaNGaps(testCase)
            x = 1:20;
            y = [1:8, NaN, NaN, 11:20];
            [xOut, yOut] = lttb_downsample(x, y, 8);
            testCase.verifyTrue(any(isnan(yOut)), 'Must preserve NaN gaps');
        end

        function testPerformance(testCase)
            n = 1e6;
            x = 1:n;
            y = randn(1, n);
            tic;
            lttb_downsample(x, y, 1000);
            elapsed = toc;
            testCase.verifyLessThan(elapsed, 2.0, sprintf('testPerformance: took %.3f s, must be < 2s', elapsed));
        end
    end
end
