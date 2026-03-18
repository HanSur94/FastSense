classdef TestDatastoreEdgeCases < matlab.unittest.TestCase
%TestDatastoreEdgeCases Edge-case and stress tests for FastSenseDataStore.
%   Covers: boundary conditions, special values (Inf, NaN), single-point
%   datasets, repeated X values, multi-chunk queries, and binary fallback.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testSinglePointDataset(testCase)
            ds = FastSenseDataStore(5, 10);
            testCase.addTeardown(@() ds.cleanup());
            testCase.verifyEqual(ds.NumPoints, 1, 'singlePoint: NumPoints');
            testCase.verifyEqual(ds.XMin, 5, 'singlePoint: XMin');
            testCase.verifyEqual(ds.XMax, 5, 'singlePoint: XMax');
            [xr, yr] = ds.getRange(0, 100);
            testCase.verifyTrue(numel(xr) == 1 && xr == 5, 'singlePoint: getRange X');
            testCase.verifyEqual(yr, 10, 'singlePoint: getRange Y');
            [xs, ys] = ds.readSlice(1, 1);
            testCase.verifyTrue(xs == 5 && ys == 10, 'singlePoint: readSlice');
        end

        function testTwoPointDataset(testCase)
            ds = FastSenseDataStore([1, 100], [10, 20]);
            testCase.addTeardown(@() ds.cleanup());
            [xr, yr] = ds.getRange(1, 100);
            testCase.verifyEqual(numel(xr), 2, 'twoPoint: getRange count');
            testCase.verifyTrue(xr(1) == 1 && xr(2) == 100, 'twoPoint: getRange X');
        end

        function testInfValuesInY(testCase)
            x = 1:100;
            y = rand(1, 100);
            y(25) = Inf; y(75) = -Inf;
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [~, yr] = ds.readSlice(1, 100);
            testCase.verifyTrue(isinf(yr(25)) && yr(25) > 0, 'infValues: +Inf preserved');
            testCase.verifyTrue(isinf(yr(75)) && yr(75) < 0, 'infValues: -Inf preserved');
        end

        function testAllNaNYData(testCase)
            x = 1:50;
            y = nan(1, 50);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            testCase.verifyEqual(ds.HasNaN, true, 'allNaN: HasNaN');
            [~, yr] = ds.readSlice(1, 50);
            testCase.verifyTrue(all(isnan(yr)), 'allNaN: all values NaN');
        end

        function testConstantX(testCase)
            x = ones(1, 100) * 42;
            y = rand(1, 100);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            testCase.verifyTrue(ds.XMin == 42 && ds.XMax == 42, 'constantX: XMin==XMax');
            [xr, yr] = ds.getRange(41, 43);
            testCase.verifyEqual(numel(xr), 100, 'constantX: getRange returns all');
        end

        function testRepeatedXValues(testCase)
            x = sort(repmat(1:50, 1, 3));  % [1 1 1 2 2 2 ... 50 50 50]
            y = rand(1, 150);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [xr, ~] = ds.getRange(10, 20);
            testCase.verifyTrue(all(xr >= 9 & xr <= 21), 'duplicateX: range respected');
        end

        function testInvertedRange(testCase)
            ds = FastSenseDataStore(1:1000, rand(1, 1000));
            testCase.addTeardown(@() ds.cleanup());
            [xr, ~] = ds.getRange(500, 100);
            testCase.verifyEmpty(xr, 'invertedRange: should return empty');
        end

        function testExactBoundaryQueries(testCase)
            x = linspace(0, 100, 10000);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [xr, ~] = ds.getRange(0, 0);  % exact start
            testCase.verifyTrue(numel(xr) >= 1, 'exactBoundary: at start');
            [xr, ~] = ds.getRange(100, 100);  % exact end
            testCase.verifyTrue(numel(xr) >= 1, 'exactBoundary: at end');
        end

        function testSinglePointSlice(testCase)
            ds = FastSenseDataStore(1:1000, (1:1000)*3);
            testCase.addTeardown(@() ds.cleanup());
            [xs, ys] = ds.readSlice(500, 500);
            testCase.verifyEqual(numel(xs), 1, 'singleSlice: count');
            testCase.verifyTrue(xs == 500 && ys == 1500, 'singleSlice: values');
        end

        function testEndSlice(testCase)
            n = 5000;
            x = 1:n;
            y = x * 2;
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [xs, ys] = ds.readSlice(n-2, n);
            testCase.verifyEqual(numel(xs), 3, 'endSlice: count');
            testCase.verifyEqual(xs(end), n, 'endSlice: last X');
            testCase.verifyEqual(ys(end), n*2, 'endSlice: last Y');
        end

        function testStartSlice(testCase)
            ds = FastSenseDataStore(1:5000, (1:5000)*2);
            testCase.addTeardown(@() ds.cleanup());
            [xs, ys] = ds.readSlice(1, 3);
            testCase.verifyEqual(numel(xs), 3, 'startSlice: count');
            testCase.verifyTrue(xs(1) == 1 && ys(1) == 2, 'startSlice: first values');
        end

        function testRepeatedQueriesConsistent(testCase)
            x = linspace(0, 100, 50000);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [xr1, ~] = ds.getRange(10, 20);
            [xr2, ~] = ds.getRange(50, 60);
            [xr3, ~] = ds.getRange(10, 20);  % repeat first query
            testCase.verifyEqual(xr1, xr3, 'repeatQuery: same query same result');
            testCase.verifyTrue(~isequal(xr1, xr2), 'repeatQuery: different queries differ');
        end

        function testStressQueries(testCase)
            x = linspace(0, 1000, 100000);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            tic;
            for i = 1:100
                xStart = rand * 900;
                ds.getRange(xStart, xStart + 10);
            end
            elapsed = toc;
            testCase.verifyLessThan(elapsed, 10, sprintf('stressQueries: 100 queries took %.1fs', elapsed));
        end

        function testIdempotentCleanup(testCase)
            ds = FastSenseDataStore(1:100, rand(1, 100));
            ds.cleanup();
            ds.cleanup();  % should not throw
            testCase.verifyTrue(true, 'idempotent cleanup: no error on double cleanup');
        end

        function testPostCleanupState(testCase)
            ds = FastSenseDataStore(1:100, rand(1, 100));
            if ~isempty(ds.DbPath); fpath = ds.DbPath; else; fpath = ds.BinPath; end
            ds.cleanup();
            testCase.verifyTrue(~exist(fpath, 'file'), 'afterCleanup: file should be gone');
        end

        function testVeryLargeYValues(testCase)
            x = 1:100;
            y = ones(1, 100) * 1e300;
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [~, yr] = ds.readSlice(1, 100);
            testCase.verifyTrue(all(yr == 1e300), 'largeValues: preserved');
        end

        function testVerySmallYValues(testCase)
            x = 1:100;
            y = ones(1, 100) * 1e-300;
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [~, yr] = ds.readSlice(1, 100);
            testCase.verifyTrue(all(abs(yr - 1e-300) < 1e-312), 'smallValues: preserved');
        end

        function testNegativeXValues(testCase)
            x = linspace(-100, -1, 500);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            testCase.verifyTrue(ds.XMin == -100 && ds.XMax == -1, 'negativeX: range');
            [xr, ~] = ds.getRange(-60, -40);
            testCase.verifyTrue(all(xr >= -61 & xr <= -39), 'negativeX: range query');
        end

        function testCrossChunkBoundaryQuery(testCase)
            % Use enough points to guarantee multiple chunks
            n = 200000;
            x = linspace(0, 1000, n);
            y = x .* 3;  % simple linear for verification
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            % Query range that spans chunk boundaries
            [xr, yr] = ds.getRange(400, 600);
            % Verify Y = 3*X relationship holds across chunks
            maxErr = max(abs(yr - xr * 3));
            testCase.verifyLessThan(maxErr, 1e-10, 'crossChunk: Y != 3*X across chunks');
        end

        function testXMonotonicity(testCase)
            n = 100000;
            x = linspace(0, 1000, n);
            y = randn(1, n);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [xr, ~] = ds.getRange(200, 800);
            testCase.verifyTrue(all(diff(xr) >= 0), 'monotonicity: X must be non-decreasing');
        end
    end
end
