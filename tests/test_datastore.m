function test_datastore()
%TEST_DATASTORE Unit tests for FastSenseDataStore class.
%   Tests the SQLite/binary-backed data storage used by FastSense to handle
%   large datasets without running out of memory. Covers creation, range
%   queries, slice reads, edge cases, and cleanup.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); setup();

    % --- Construction ---

    % testCreateStore: basic construction stores metadata correctly
    x = linspace(0, 100, 10000);
    y = sin(x);
    ds = FastSenseDataStore(x, y);
    assert(ds.NumPoints == 10000, 'testCreateStore: NumPoints');
    assert(ds.XMin == x(1), 'testCreateStore: XMin');
    assert(ds.XMax == x(end), 'testCreateStore: XMax');
    assert(ds.HasNaN == false, 'testCreateStore: HasNaN should be false');
    ds.cleanup();

    % testCreateStoreWithNaN: detects NaN in Y data
    y2 = y; y2(500) = NaN;
    ds = FastSenseDataStore(x, y2);
    assert(ds.HasNaN == true, 'testCreateStoreWithNaN: HasNaN should be true');
    ds.cleanup();

    % testEmptyConstruction: empty construction returns valid zero-state
    ds = FastSenseDataStore();
    assert(ds.NumPoints == 0, 'testEmptyConstruction: NumPoints');
    assert(isnan(ds.XMin), 'testEmptyConstruction: XMin should be NaN');
    ds.cleanup();

    % testColumnVectorInput: accepts column vectors
    ds = FastSenseDataStore((1:100)', rand(100,1));
    assert(ds.NumPoints == 100, 'testColumnVectorInput: NumPoints');
    ds.cleanup();

    % --- Range Queries (getRange) ---

    % testGetRangeMiddle: query a middle range returns correct data
    x = linspace(0, 100, 50000);
    y = sin(x);
    ds = FastSenseDataStore(x, y);
    [xr, yr] = ds.getRange(20, 40);
    assert(~isempty(xr), 'testGetRangeMiddle: should return data');
    % All interior points must be within range (edges may have 1-pt padding)
    assert(xr(2) >= 20, 'testGetRangeMiddle: interior start >= 20');
    assert(xr(end-1) <= 40, 'testGetRangeMiddle: interior end <= 40');
    % Padding: first point should be <= 20, last should be >= 40
    assert(xr(1) <= 20, 'testGetRangeMiddle: left padding');
    assert(xr(end) >= 40, 'testGetRangeMiddle: right padding');
    ds.cleanup();

    % testGetRangeFullSpan: range covering entire dataset returns all points
    x = 1:1000;
    y = rand(1, 1000);
    ds = FastSenseDataStore(x, y);
    [xr, yr] = ds.getRange(1, 1000);
    assert(numel(xr) == 1000, 'testGetRangeFullSpan: should get all points');
    assert(isequal(xr, x), 'testGetRangeFullSpan: X data must match');
    tol = 1e-12;
    assert(max(abs(yr - y)) < tol, 'testGetRangeFullSpan: Y data must match');
    ds.cleanup();

    % testGetRangeSmall: small range on large dataset returns correct subset
    n = 200000;
    x = linspace(0, 1000, n);
    y = cumsum(randn(1, n));
    ds = FastSenseDataStore(x, y);
    [xr, yr] = ds.getRange(500, 501);
    % Should get a reasonable number of points (not all 200K)
    assert(numel(xr) > 10, 'testGetRangeSmall: too few points');
    assert(numel(xr) < n, 'testGetRangeSmall: should not return all points');
    % All returned X values (interior) should be near the range
    assert(all(xr >= 499), 'testGetRangeSmall: X values too low');
    assert(all(xr <= 502), 'testGetRangeSmall: X values too high');
    ds.cleanup();

    % testGetRangeOutside: range outside data returns empty or edge points
    x = 1:100;
    y = rand(1, 100);
    ds = FastSenseDataStore(x, y);
    [xr, ~] = ds.getRange(200, 300);
    % Should either be empty or contain only the last data point
    assert(numel(xr) <= 1, 'testGetRangeOutside: should be empty or single edge');
    ds.cleanup();

    % --- Slice Reads (readSlice) ---

    % testReadSliceExact: reading a specific index range returns correct data
    x = 1:5000;
    y = (1:5000) * 2;
    ds = FastSenseDataStore(x, y);
    [xs, ys] = ds.readSlice(100, 200);
    assert(numel(xs) == 101, 'testReadSliceExact: count');
    assert(xs(1) == 100, 'testReadSliceExact: first X');
    assert(xs(end) == 200, 'testReadSliceExact: last X');
    assert(ys(1) == 200, 'testReadSliceExact: first Y');
    assert(ys(end) == 400, 'testReadSliceExact: last Y');
    ds.cleanup();

    % testReadSliceFullRange: reading entire range matches original data
    x = linspace(0, 10, 1000);
    y = cos(x);
    ds = FastSenseDataStore(x, y);
    [xs, ys] = ds.readSlice(1, 1000);
    tol = 1e-12;
    assert(max(abs(xs - x)) < tol, 'testReadSliceFullRange: X mismatch');
    assert(max(abs(ys - y)) < tol, 'testReadSliceFullRange: Y mismatch');
    ds.cleanup();

    % testReadSliceClamped: out-of-bounds indices are clamped
    ds = FastSenseDataStore(1:100, rand(1, 100));
    [xs, ~] = ds.readSlice(-5, 200);
    assert(numel(xs) == 100, 'testReadSliceClamped: should clamp to full range');
    assert(xs(1) == 1, 'testReadSliceClamped: start clamped');
    assert(xs(end) == 100, 'testReadSliceClamped: end clamped');
    ds.cleanup();

    % --- Data Integrity ---

    % testDataIntegrity: stored data matches original exactly
    rng(42);
    n = 150000;
    x = sort(rand(1, n)) * 1000;
    y = randn(1, n);
    ds = FastSenseDataStore(x, y);
    [xAll, yAll] = ds.readSlice(1, n);
    tol = 1e-12;
    assert(max(abs(xAll - x)) < tol, 'testDataIntegrity: X drift');
    assert(max(abs(yAll - y)) < tol, 'testDataIntegrity: Y drift');
    ds.cleanup();

    % testDataIntegrityNaN: NaN values are preserved
    x = 1:100;
    y = rand(1, 100);
    y([10, 50, 90]) = NaN;
    ds = FastSenseDataStore(x, y);
    [~, yr] = ds.readSlice(1, 100);
    assert(isnan(yr(10)), 'testDataIntegrityNaN: NaN at 10');
    assert(isnan(yr(50)), 'testDataIntegrityNaN: NaN at 50');
    assert(isnan(yr(90)), 'testDataIntegrityNaN: NaN at 90');
    ds.cleanup();

    % --- Range query returns row vectors ---

    % testOutputShape: getRange and readSlice return row vectors
    ds = FastSenseDataStore(1:1000, rand(1, 1000));
    [xr, yr] = ds.getRange(100, 200);
    assert(isrow(xr), 'testOutputShape: getRange X must be row');
    assert(isrow(yr), 'testOutputShape: getRange Y must be row');
    [xs, ys] = ds.readSlice(1, 100);
    assert(isrow(xs), 'testOutputShape: readSlice X must be row');
    assert(isrow(ys), 'testOutputShape: readSlice Y must be row');
    ds.cleanup();

    % --- Cleanup ---

    % testCleanupDeletesFile: cleanup removes temp files from disk
    ds = FastSenseDataStore(1:1000, rand(1, 1000));
    % Store the path(s) before cleanup
    hasDb = ~isempty(ds.DbPath) && exist(ds.DbPath, 'file');
    hasBin = ~isempty(ds.BinPath) && exist(ds.BinPath, 'file');
    assert(hasDb || hasBin, 'testCleanupDeletesFile: should have a temp file');
    if hasDb
        fpath = ds.DbPath;
    else
        fpath = ds.BinPath;
    end
    ds.cleanup();
    assert(~exist(fpath, 'file'), 'testCleanupDeletesFile: file should be gone');

    % testDestructorCleanup: deleting the object cleans up temp files
    ds = FastSenseDataStore(1:1000, rand(1, 1000));
    if ~isempty(ds.DbPath) && exist(ds.DbPath, 'file')
        fpath = ds.DbPath;
    else
        fpath = ds.BinPath;
    end
    delete(ds);
    assert(~exist(fpath, 'file'), 'testDestructorCleanup: file should be gone');

    % --- Large dataset stress test ---

    % testLargeDataset: 500K points — query performance and correctness
    n = 500000;
    x = linspace(0, 10000, n);
    y = sin(x / 100) + randn(1, n) * 0.1;
    ds = FastSenseDataStore(x, y);
    assert(ds.NumPoints == n, 'testLargeDataset: NumPoints');

    % Query a narrow range — should be fast and return correct subset
    tic;
    [xr, yr] = ds.getRange(5000, 5010);
    queryTime = toc;
    assert(numel(xr) > 0, 'testLargeDataset: should return data');
    assert(numel(xr) < n, 'testLargeDataset: should not return everything');
    assert(all(xr(2:end-1) >= 5000 & xr(2:end-1) <= 5010), ...
        'testLargeDataset: interior points in range');
    % Query should be much faster than loading all data
    assert(queryTime < 2.0, ...
        sprintf('testLargeDataset: query too slow (%.3fs)', queryTime));
    ds.cleanup();

    fprintf('    All 16 datastore tests passed.\n');
end
