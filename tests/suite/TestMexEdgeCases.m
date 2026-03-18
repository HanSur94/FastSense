classdef TestMexEdgeCases < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testBinarySearchSingleElement(testCase)
            testCase.assumeTrue(exist('binary_search_mex', 'file') == 3, 'MEX not compiled');

            testCase.verifyEqual(binary_search_mex([5], 3, 'left'), 1);
            testCase.verifyEqual(binary_search_mex([5], 7, 'right'), 1);
            testCase.verifyEqual(binary_search_mex([5], 5, 'left'), 1);
            testCase.verifyEqual(binary_search_mex([5], 5, 'right'), 1);
        end

        function testBinarySearchTwoElements(testCase)
            testCase.assumeTrue(exist('binary_search_mex', 'file') == 3, 'MEX not compiled');

            testCase.verifyEqual(binary_search_mex([1 10], 5, 'left'), 2);
            testCase.verifyEqual(binary_search_mex([1 10], 5, 'right'), 1);
        end

        function testBinarySearchExactBoundary(testCase)
            testCase.assumeTrue(exist('binary_search_mex', 'file') == 3, 'MEX not compiled');

            x = [1 2 3 4 5];
            testCase.verifyEqual(binary_search_mex(x, 1, 'left'), 1);
            testCase.verifyEqual(binary_search_mex(x, 5, 'right'), 5);
        end

        function testBinarySearchDuplicates(testCase)
            testCase.assumeTrue(exist('binary_search_mex', 'file') == 3, 'MEX not compiled');

            x = [1 1 1 3 3 3 5 5 5];
            testCase.verifyEqual(binary_search_mex(x, 1, 'left'), 1);
            testCase.verifyEqual(binary_search_mex(x, 3, 'left'), 4);
            testCase.verifyEqual(binary_search_mex(x, 1, 'right'), 3);
            testCase.verifyEqual(binary_search_mex(x, 3, 'right'), 6);
        end

        function testMinmaxCoreMinimumSize(testCase)
            testCase.assumeTrue(exist('minmax_core_mex', 'file') == 3, 'MEX not compiled');

            [xo, yo] = minmax_core_mex([1 2], [10 20], 1);
            testCase.verifyEqual(numel(xo), 2);
            testCase.verifyEqual(numel(yo), 2);
            testCase.verifyEqual(xo(1), 1);
            testCase.verifyEqual(xo(2), 2);
            testCase.verifyEqual(yo(1), 10);
            testCase.verifyEqual(yo(2), 20);
        end

        function testMinmaxCoreAllSameValues(testCase)
            testCase.assumeTrue(exist('minmax_core_mex', 'file') == 3, 'MEX not compiled');

            x = 1:100;
            y = ones(1, 100) * 42;
            [~, yo] = minmax_core_mex(x, y, 10);
            testCase.verifyTrue(all(yo == 42), 'All-same values: expected all 42');
        end

        function testMinmaxCoreNegativeValues(testCase)
            testCase.assumeTrue(exist('minmax_core_mex', 'file') == 3, 'MEX not compiled');

            x = 1:100;
            y = -50 + (1:100) * 0.1;
            [~, yo] = minmax_core_mex(x, y, 10);
            testCase.verifyTrue(min(yo) >= -50 && max(yo) <= -40);
        end

        function testMinmaxCoreLargeArray(testCase)
            testCase.assumeTrue(exist('minmax_core_mex', 'file') == 3, 'MEX not compiled');

            n = 1e7;
            x = linspace(0, 100, n);
            y = sin(x);
            [xo, yo] = minmax_core_mex(x, y, 1000);
            testCase.verifyEqual(numel(xo), 2000, sprintf('Large: expected 2000 points, got %d', numel(xo)));
            testCase.verifyTrue(max(yo) <= 1.0 + 1e-10 && min(yo) >= -1.0 - 1e-10, ...
                'Large: y values out of sine range');
        end

        function testMinmaxCoreRemainderHandling(testCase)
            testCase.assumeTrue(exist('minmax_core_mex', 'file') == 3, 'MEX not compiled');

            x = 1:17;
            y = [5 3 8 1 9 2 7 4 6 10 11 12 13 14 15 16 17];
            [~, yo] = minmax_core_mex(x, y, 3);
            testCase.verifyEqual(numel(yo), 6);
        end

        function testLttbCoreMinimumEndpoints(testCase)
            testCase.assumeTrue(exist('lttb_core_mex', 'file') == 3, 'MEX not compiled');

            [xo, yo] = lttb_core_mex([1 2 3 4 5], [10 20 30 40 50], 2);
            testCase.verifyEqual(numel(xo), 2);
            testCase.verifyEqual(xo(1), 1);
            testCase.verifyEqual(xo(2), 5);
            testCase.verifyEqual(yo(1), 10);
            testCase.verifyEqual(yo(2), 50);
        end

        function testLttbCoreNumOutThree(testCase)
            testCase.assumeTrue(exist('lttb_core_mex', 'file') == 3, 'MEX not compiled');

            x = 1:10;
            y = [0 0 0 0 10 0 0 0 0 0];
            [xo, yo] = lttb_core_mex(x, y, 3);
            testCase.verifyEqual(numel(xo), 3);
            testCase.verifyEqual(xo(1), 1);
            testCase.verifyEqual(xo(end), 10);
        end

        function testLttbCoreMonotonicData(testCase)
            testCase.assumeTrue(exist('lttb_core_mex', 'file') == 3, 'MEX not compiled');

            x = 1:1000;
            y = (1:1000) * 0.001;
            [xo, ~] = lttb_core_mex(x, y, 50);
            testCase.verifyTrue(all(diff(xo) > 0), 'Monotonic X violated');
        end

        function testLttbCoreLargeArray(testCase)
            testCase.assumeTrue(exist('lttb_core_mex', 'file') == 3, 'MEX not compiled');

            n = 1e6;
            x = linspace(0, 100, n);
            y = sin(x);
            [xo, yo] = lttb_core_mex(x, y, 500);
            testCase.verifyEqual(numel(xo), 500);
            testCase.verifyEqual(xo(1), x(1));
            testCase.verifyEqual(xo(end), x(end));
        end
    end
end
