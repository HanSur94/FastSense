classdef TestDatastore < matlab.unittest.TestCase
%TestDatastore Unit tests for FastSenseDataStore class.
%   Tests the SQLite/binary-backed data storage used by FastSense to handle
%   large datasets without running out of memory. Covers creation, range
%   queries, slice reads, edge cases, and cleanup.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testCreateStore(testCase)
            % basic construction stores metadata correctly
            x = linspace(0, 100, 10000);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            testCase.verifyEqual(ds.NumPoints, 10000, 'testCreateStore: NumPoints');
            testCase.verifyEqual(ds.XMin, x(1), 'testCreateStore: XMin');
            testCase.verifyEqual(ds.XMax, x(end), 'testCreateStore: XMax');
            testCase.verifyEqual(ds.HasNaN, false, 'testCreateStore: HasNaN should be false');
        end

        function testCreateStoreWithNaN(testCase)
            % detects NaN in Y data
            x = linspace(0, 100, 10000);
            y = sin(x);
            y(500) = NaN;
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            testCase.verifyEqual(ds.HasNaN, true, 'testCreateStoreWithNaN: HasNaN should be true');
        end

        function testEmptyConstruction(testCase)
            % empty construction returns valid zero-state
            ds = FastSenseDataStore();
            testCase.addTeardown(@() ds.cleanup());
            testCase.verifyEqual(ds.NumPoints, 0, 'testEmptyConstruction: NumPoints');
            testCase.verifyTrue(isnan(ds.XMin), 'testEmptyConstruction: XMin should be NaN');
        end

        function testColumnVectorInput(testCase)
            % accepts column vectors
            ds = FastSenseDataStore((1:100)', rand(100,1));
            testCase.addTeardown(@() ds.cleanup());
            testCase.verifyEqual(ds.NumPoints, 100, 'testColumnVectorInput: NumPoints');
        end

        function testGetRangeMiddle(testCase)
            % query a middle range returns correct data
            x = linspace(0, 100, 50000);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [xr, yr] = ds.getRange(20, 40);
            testCase.verifyNotEmpty(xr, 'testGetRangeMiddle: should return data');
            % All interior points must be within range (edges may have 1-pt padding)
            testCase.verifyTrue(xr(2) >= 20, 'testGetRangeMiddle: interior start >= 20');
            testCase.verifyTrue(xr(end-1) <= 40, 'testGetRangeMiddle: interior end <= 40');
            % Padding: first point should be <= 20, last should be >= 40
            testCase.verifyTrue(xr(1) <= 20, 'testGetRangeMiddle: left padding');
            testCase.verifyTrue(xr(end) >= 40, 'testGetRangeMiddle: right padding');
        end

        function testGetRangeFullSpan(testCase)
            % range covering entire dataset returns all points
            x = 1:1000;
            y = rand(1, 1000);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [xr, yr] = ds.getRange(1, 1000);
            testCase.verifyEqual(numel(xr), 1000, 'testGetRangeFullSpan: should get all points');
            testCase.verifyEqual(xr, x, 'testGetRangeFullSpan: X data must match');
            tol = 1e-12;
            testCase.verifyLessThan(max(abs(yr - y)), tol, 'testGetRangeFullSpan: Y data must match');
        end

        function testGetRangeSmall(testCase)
            % small range on large dataset returns correct subset
            n = 200000;
            x = linspace(0, 1000, n);
            y = cumsum(randn(1, n));
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [xr, yr] = ds.getRange(500, 501);
            % Should get a reasonable number of points (not all 200K)
            testCase.verifyTrue(numel(xr) > 10, 'testGetRangeSmall: too few points');
            testCase.verifyTrue(numel(xr) < n, 'testGetRangeSmall: should not return all points');
            % All returned X values (interior) should be near the range
            testCase.verifyTrue(all(xr >= 499), 'testGetRangeSmall: X values too low');
            testCase.verifyTrue(all(xr <= 502), 'testGetRangeSmall: X values too high');
        end

        function testGetRangeOutside(testCase)
            % range outside data returns empty or edge points
            x = 1:100;
            y = rand(1, 100);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [xr, ~] = ds.getRange(200, 300);
            % Should either be empty or contain only the last data point
            testCase.verifyTrue(numel(xr) <= 1, 'testGetRangeOutside: should be empty or single edge');
        end

        function testReadSliceExact(testCase)
            % reading a specific index range returns correct data
            x = 1:5000;
            y = (1:5000) * 2;
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [xs, ys] = ds.readSlice(100, 200);
            testCase.verifyEqual(numel(xs), 101, 'testReadSliceExact: count');
            testCase.verifyEqual(xs(1), 100, 'testReadSliceExact: first X');
            testCase.verifyEqual(xs(end), 200, 'testReadSliceExact: last X');
            testCase.verifyEqual(ys(1), 200, 'testReadSliceExact: first Y');
            testCase.verifyEqual(ys(end), 400, 'testReadSliceExact: last Y');
        end

        function testReadSliceFullRange(testCase)
            % reading entire range matches original data
            x = linspace(0, 10, 1000);
            y = cos(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [xs, ys] = ds.readSlice(1, 1000);
            tol = 1e-12;
            testCase.verifyLessThan(max(abs(xs - x)), tol, 'testReadSliceFullRange: X mismatch');
            testCase.verifyLessThan(max(abs(ys - y)), tol, 'testReadSliceFullRange: Y mismatch');
        end

        function testReadSliceClamped(testCase)
            % out-of-bounds indices are clamped
            ds = FastSenseDataStore(1:100, rand(1, 100));
            testCase.addTeardown(@() ds.cleanup());
            [xs, ~] = ds.readSlice(-5, 200);
            testCase.verifyEqual(numel(xs), 100, 'testReadSliceClamped: should clamp to full range');
            testCase.verifyEqual(xs(1), 1, 'testReadSliceClamped: start clamped');
            testCase.verifyEqual(xs(end), 100, 'testReadSliceClamped: end clamped');
        end

        function testDataIntegrity(testCase)
            % stored data matches original exactly
            rng(42);
            n = 150000;
            x = sort(rand(1, n)) * 1000;
            y = randn(1, n);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [xAll, yAll] = ds.readSlice(1, n);
            tol = 1e-12;
            testCase.verifyLessThan(max(abs(xAll - x)), tol, 'testDataIntegrity: X drift');
            testCase.verifyLessThan(max(abs(yAll - y)), tol, 'testDataIntegrity: Y drift');
        end

        function testDataIntegrityNaN(testCase)
            % NaN values are preserved
            x = 1:100;
            y = rand(1, 100);
            y([10, 50, 90]) = NaN;
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            [~, yr] = ds.readSlice(1, 100);
            testCase.verifyTrue(isnan(yr(10)), 'testDataIntegrityNaN: NaN at 10');
            testCase.verifyTrue(isnan(yr(50)), 'testDataIntegrityNaN: NaN at 50');
            testCase.verifyTrue(isnan(yr(90)), 'testDataIntegrityNaN: NaN at 90');
        end

        function testOutputShape(testCase)
            % getRange and readSlice return row vectors
            ds = FastSenseDataStore(1:1000, rand(1, 1000));
            testCase.addTeardown(@() ds.cleanup());
            [xr, yr] = ds.getRange(100, 200);
            testCase.verifyTrue(isrow(xr), 'testOutputShape: getRange X must be row');
            testCase.verifyTrue(isrow(yr), 'testOutputShape: getRange Y must be row');
            [xs, ys] = ds.readSlice(1, 100);
            testCase.verifyTrue(isrow(xs), 'testOutputShape: readSlice X must be row');
            testCase.verifyTrue(isrow(ys), 'testOutputShape: readSlice Y must be row');
        end

        function testCleanupDeletesFile(testCase)
            % cleanup removes temp files from disk
            ds = FastSenseDataStore(1:1000, rand(1, 1000));
            % Store the path(s) before cleanup
            hasDb = ~isempty(ds.DbPath) && exist(ds.DbPath, 'file');
            hasBin = ~isempty(ds.BinPath) && exist(ds.BinPath, 'file');
            testCase.verifyTrue(hasDb || hasBin, 'testCleanupDeletesFile: should have a temp file');
            if hasDb
                fpath = ds.DbPath;
            else
                fpath = ds.BinPath;
            end
            ds.cleanup();
            testCase.verifyTrue(~exist(fpath, 'file'), 'testCleanupDeletesFile: file should be gone');
        end

        function testDestructorCleanup(testCase)
            % deleting the object cleans up temp files
            ds = FastSenseDataStore(1:1000, rand(1, 1000));
            if ~isempty(ds.DbPath) && exist(ds.DbPath, 'file')
                fpath = ds.DbPath;
            else
                fpath = ds.BinPath;
            end
            delete(ds);
            testCase.verifyTrue(~exist(fpath, 'file'), 'testDestructorCleanup: file should be gone');
        end

        function testLargeDataset(testCase)
            % 500K points — query performance and correctness
            n = 500000;
            x = linspace(0, 10000, n);
            y = sin(x / 100) + randn(1, n) * 0.1;
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            testCase.verifyEqual(ds.NumPoints, n, 'testLargeDataset: NumPoints');

            % Query a narrow range — should be fast and return correct subset
            tic;
            [xr, yr] = ds.getRange(5000, 5010);
            queryTime = toc;
            testCase.verifyNotEmpty(xr, 'testLargeDataset: should return data');
            testCase.verifyTrue(numel(xr) < n, 'testLargeDataset: should not return everything');
            testCase.verifyTrue(all(xr(2:end-1) >= 5000 & xr(2:end-1) <= 5010), ...
                'testLargeDataset: interior points in range');
            % Query should be much faster than loading all data
            testCase.verifyLessThan(queryTime, 2.0, ...
                sprintf('testLargeDataset: query too slow (%.3fs)', queryTime));
        end
    end
end
