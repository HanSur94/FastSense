function test_datastore_edge_cases()
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (known Octave classdef limitation)\n');
        return;
    end
%TEST_DATASTORE_EDGE_CASES Edge-case and stress tests for FastSenseDataStore.
%   Covers: boundary conditions, special values (Inf, NaN), single-point
%   datasets, repeated X values, multi-chunk queries, and binary fallback.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); setup();

    fprintf('  --- DataStore edge cases ---\n');

    % 1. Single-point dataset
    ds = FastSenseDataStore(5, 10);
    assert(ds.NumPoints == 1, 'singlePoint: NumPoints');
    assert(ds.XMin == 5, 'singlePoint: XMin');
    assert(ds.XMax == 5, 'singlePoint: XMax');
    [xr, yr] = ds.getRange(0, 100);
    assert(numel(xr) == 1 && xr == 5, 'singlePoint: getRange X');
    assert(yr == 10, 'singlePoint: getRange Y');
    [xs, ys] = ds.readSlice(1, 1);
    assert(xs == 5 && ys == 10, 'singlePoint: readSlice');
    ds.cleanup();
    fprintf('    single-point dataset: PASS\n');

    % 2. Two-point dataset
    ds = FastSenseDataStore([1, 100], [10, 20]);
    [xr, yr] = ds.getRange(1, 100);
    assert(numel(xr) == 2, 'twoPoint: getRange count');
    assert(xr(1) == 1 && xr(2) == 100, 'twoPoint: getRange X');
    ds.cleanup();
    fprintf('    two-point dataset: PASS\n');

    % 3. Inf values in Y data
    x = 1:100;
    y = rand(1, 100);
    y(25) = Inf; y(75) = -Inf;
    ds = FastSenseDataStore(x, y);
    [~, yr] = ds.readSlice(1, 100);
    assert(isinf(yr(25)) && yr(25) > 0, 'infValues: +Inf preserved');
    assert(isinf(yr(75)) && yr(75) < 0, 'infValues: -Inf preserved');
    ds.cleanup();
    fprintf('    Inf values in Y: PASS\n');

    % 4. All-NaN Y data
    x = 1:50;
    y = nan(1, 50);
    ds = FastSenseDataStore(x, y);
    assert(ds.HasNaN == true, 'allNaN: HasNaN');
    [~, yr] = ds.readSlice(1, 50);
    assert(all(isnan(yr)), 'allNaN: all values NaN');
    ds.cleanup();
    fprintf('    all-NaN Y data: PASS\n');

    % 5. Constant X (degenerate — all same timestamp)
    x = ones(1, 100) * 42;
    y = rand(1, 100);
    ds = FastSenseDataStore(x, y);
    assert(ds.XMin == 42 && ds.XMax == 42, 'constantX: XMin==XMax');
    [xr, yr] = ds.getRange(41, 43);
    assert(numel(xr) == 100, 'constantX: getRange returns all');
    ds.cleanup();
    fprintf('    constant X values: PASS\n');

    % 6. Repeated X values (duplicates)
    x = sort(repmat(1:50, 1, 3));  % [1 1 1 2 2 2 ... 50 50 50]
    y = rand(1, 150);
    ds = FastSenseDataStore(x, y);
    [xr, ~] = ds.getRange(10, 20);
    assert(all(xr >= 9 & xr <= 21), 'duplicateX: range respected');
    ds.cleanup();
    fprintf('    repeated X values: PASS\n');

    % 7. getRange with inverted range (xMin > xMax)
    ds = FastSenseDataStore(1:1000, rand(1, 1000));
    [xr, ~] = ds.getRange(500, 100);
    assert(isempty(xr), 'invertedRange: should return empty');
    ds.cleanup();
    fprintf('    inverted range query: PASS\n');

    % 8. getRange at exact data boundaries
    x = linspace(0, 100, 10000);
    y = sin(x);
    ds = FastSenseDataStore(x, y);
    [xr, ~] = ds.getRange(0, 0);  % exact start
    assert(numel(xr) >= 1, 'exactBoundary: at start');
    [xr, ~] = ds.getRange(100, 100);  % exact end
    assert(numel(xr) >= 1, 'exactBoundary: at end');
    ds.cleanup();
    fprintf('    exact boundary queries: PASS\n');

    % 9. readSlice with startIdx == endIdx (single point)
    ds = FastSenseDataStore(1:1000, (1:1000)*3);
    [xs, ys] = ds.readSlice(500, 500);
    assert(numel(xs) == 1, 'singleSlice: count');
    assert(xs == 500 && ys == 1500, 'singleSlice: values');
    ds.cleanup();
    fprintf('    single-point slice: PASS\n');

    % 10. readSlice at very end of dataset
    n = 5000;
    x = 1:n;
    y = x * 2;
    ds = FastSenseDataStore(x, y);
    [xs, ys] = ds.readSlice(n-2, n);
    assert(numel(xs) == 3, 'endSlice: count');
    assert(xs(end) == n, 'endSlice: last X');
    assert(ys(end) == n*2, 'endSlice: last Y');
    ds.cleanup();
    fprintf('    end-of-data slice: PASS\n');

    % 11. readSlice at very start of dataset
    ds = FastSenseDataStore(1:5000, (1:5000)*2);
    [xs, ys] = ds.readSlice(1, 3);
    assert(numel(xs) == 3, 'startSlice: count');
    assert(xs(1) == 1 && ys(1) == 2, 'startSlice: first values');
    ds.cleanup();
    fprintf('    start-of-data slice: PASS\n');

    % 12. Multiple getRange calls on same DataStore (caching/state)
    x = linspace(0, 100, 50000);
    y = sin(x);
    ds = FastSenseDataStore(x, y);
    [xr1, ~] = ds.getRange(10, 20);
    [xr2, ~] = ds.getRange(50, 60);
    [xr3, ~] = ds.getRange(10, 20);  % repeat first query
    assert(isequal(xr1, xr3), 'repeatQuery: same query same result');
    assert(~isequal(xr1, xr2), 'repeatQuery: different queries differ');
    ds.cleanup();
    fprintf('    repeated queries consistent: PASS\n');

    % 13. Large number of small getRange calls (stress)
    x = linspace(0, 1000, 100000);
    y = sin(x);
    ds = FastSenseDataStore(x, y);
    tic;
    for i = 1:100
        xStart = rand * 900;
        ds.getRange(xStart, xStart + 10);
    end
    elapsed = toc;
    assert(elapsed < 10, sprintf('stressQueries: 100 queries took %.1fs', elapsed));
    ds.cleanup();
    fprintf('    100 random range queries: PASS (%.2fs)\n', elapsed);

    % 14. cleanup is idempotent (calling twice doesn't error)
    ds = FastSenseDataStore(1:100, rand(1, 100));
    ds.cleanup();
    ds.cleanup();  % should not throw
    fprintf('    idempotent cleanup: PASS\n');

    % 15. Operations after cleanup — storage file is gone
    ds = FastSenseDataStore(1:100, rand(1, 100));
    if ~isempty(ds.DbPath); fpath = ds.DbPath; else; fpath = ds.BinPath; end
    ds.cleanup();
    assert(~exist(fpath, 'file'), 'afterCleanup: file should be gone');
    fprintf('    post-cleanup state: PASS\n');

    % 16. Very large Y values (1e300)
    x = 1:100;
    y = ones(1, 100) * 1e300;
    ds = FastSenseDataStore(x, y);
    [~, yr] = ds.readSlice(1, 100);
    assert(all(yr == 1e300), 'largeValues: preserved');
    ds.cleanup();
    fprintf('    very large Y values: PASS\n');

    % 17. Very small Y values (1e-300)
    y = ones(1, 100) * 1e-300;
    ds = FastSenseDataStore(x, y);
    [~, yr] = ds.readSlice(1, 100);
    assert(all(abs(yr - 1e-300) < 1e-312), 'smallValues: preserved');
    ds.cleanup();
    fprintf('    very small Y values: PASS\n');

    % 18. Negative X values (descending not required but negative ok)
    x = linspace(-100, -1, 500);
    y = sin(x);
    ds = FastSenseDataStore(x, y);
    assert(ds.XMin == -100 && ds.XMax == -1, 'negativeX: range');
    [xr, ~] = ds.getRange(-60, -40);
    assert(all(xr >= -61 & xr <= -39), 'negativeX: range query');
    ds.cleanup();
    fprintf('    negative X values: PASS\n');

    % 19. Cross-chunk boundary query (data spans multiple chunks)
    % Use enough points to guarantee multiple chunks
    n = 200000;
    x = linspace(0, 1000, n);
    y = x .* 3;  % simple linear for verification
    ds = FastSenseDataStore(x, y);
    % Query range that spans chunk boundaries
    [xr, yr] = ds.getRange(400, 600);
    % Verify Y = 3*X relationship holds across chunks
    maxErr = max(abs(yr - xr * 3));
    assert(maxErr < 1e-10, 'crossChunk: Y != 3*X across chunks');
    ds.cleanup();
    fprintf('    cross-chunk boundary query: PASS\n');

    % 20. Monotonicity of returned X data
    n = 100000;
    x = linspace(0, 1000, n);
    y = randn(1, n);
    ds = FastSenseDataStore(x, y);
    [xr, ~] = ds.getRange(200, 800);
    assert(all(diff(xr) >= 0), 'monotonicity: X must be non-decreasing');
    ds.cleanup();
    fprintf('    X monotonicity in results: PASS\n');

    fprintf('\n    All 20 datastore edge-case tests passed.\n');
end
