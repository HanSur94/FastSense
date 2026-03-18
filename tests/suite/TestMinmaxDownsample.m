classdef TestMinmaxDownsample < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testBasicReduction(testCase)
            x = 1:100;
            y = sin(linspace(0, 4*pi, 100));
            [xOut, yOut] = minmax_downsample(x, y, 10);
            testCase.verifyEqual(numel(xOut), 20, 'testBasicReduction xOut: expected 20');
            testCase.verifyEqual(numel(yOut), 20, 'testBasicReduction yOut: expected 20');
        end

        function testPreservesExtremes(testCase)
            x = 1:1000;
            y = zeros(1, 1000);
            y(500) = 100;
            y(700) = -50;
            [~, yOut] = minmax_downsample(x, y, 50);
            testCase.verifyTrue(any(yOut == 100), 'Must preserve spike');
            testCase.verifyTrue(any(yOut == -50), 'Must preserve valley');
        end

        function testNaNGaps(testCase)
            x = 1:20;
            y = [1:8, NaN, NaN, 11:20];
            [xOut, yOut] = minmax_downsample(x, y, 5);
            testCase.verifyTrue(any(isnan(yOut)), 'Must preserve NaN gaps');
            nonNaN = yOut(~isnan(yOut));
            testCase.verifyNotEmpty(nonNaN, 'Must have non-NaN values');
        end

        function testFewPointsPassthrough(testCase)
            x = 1:5;
            y = [10 20 30 40 50];
            [xOut, yOut] = minmax_downsample(x, y, 10);
            testCase.verifyEqual(xOut, x, 'testFewPointsPassthrough xOut');
            testCase.verifyEqual(yOut, y, 'testFewPointsPassthrough yOut');
        end

        function testOutputIsMonotonicX(testCase)
            x = linspace(0, 10, 10000);
            y = randn(1, 10000);
            [xOut, ~] = minmax_downsample(x, y, 100);
            nanIdx = find(isnan(xOut));
            starts = [1, nanIdx + 1];
            ends = [nanIdx - 1, numel(xOut)];
            for i = 1:numel(starts)
                seg = xOut(starts(i):ends(i));
                seg = seg(~isnan(seg));
                if numel(seg) > 1
                    testCase.verifyTrue(all(diff(seg) >= 0), 'X within segment must be non-decreasing');
                end
            end
        end

        function testUnevenSpacing(testCase)
            x = [1 2 3 100 200 300 1000 2000 3000];
            y = [1 2 3 4   5   6   7    8    9];
            [xOut, yOut] = minmax_downsample(x, y, 3);
            testCase.verifyEqual(numel(xOut), 6, sprintf('testUnevenSpacing: expected 6, got %d', numel(xOut)));
        end

        function testAllNaN(testCase)
            x = 1:10;
            y = NaN(1, 10);
            [xOut, yOut] = minmax_downsample(x, y, 3);
            testCase.verifyTrue(all(isnan(yOut)), 'testAllNaN: expected all NaN');
        end

        function testLargeData(testCase)
            n = 1e6;
            x = 1:n;
            y = randn(1, n);
            tic;
            [xOut, yOut] = minmax_downsample(x, y, 1000);
            elapsed = toc;
            testCase.verifyEqual(numel(xOut), 2000, sprintf('testLargeData: expected 2000, got %d', numel(xOut)));
            testCase.verifyLessThan(elapsed, 1.0, sprintf('testLargeData: took %.3f s, must be < 1s', elapsed));
        end
    end
end
