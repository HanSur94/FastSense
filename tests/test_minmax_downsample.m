function test_minmax_downsample()
%TEST_MINMAX_DOWNSAMPLE Tests for minmax_downsample private function.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();
    add_fastsense_private_path();

    % testBasicReduction: 10 buckets -> 20 output points
    x = 1:100;
    y = sin(linspace(0, 4*pi, 100));
    [xOut, yOut] = minmax_downsample(x, y, 10);
    assert(numel(xOut) == 20, 'testBasicReduction xOut: expected 20, got %d', numel(xOut));
    assert(numel(yOut) == 20, 'testBasicReduction yOut: expected 20, got %d', numel(yOut));

    % testPreservesExtremes: spike and valley must survive
    x = 1:1000;
    y = zeros(1, 1000);
    y(500) = 100;
    y(700) = -50;
    [~, yOut] = minmax_downsample(x, y, 50);
    assert(any(yOut == 100), 'Must preserve spike');
    assert(any(yOut == -50), 'Must preserve valley');

    % testNaNGaps: output should contain NaN separators
    x = 1:20;
    y = [1:8, NaN, NaN, 11:20];
    [xOut, yOut] = minmax_downsample(x, y, 5);
    assert(any(isnan(yOut)), 'Must preserve NaN gaps');
    nonNaN = yOut(~isnan(yOut));
    assert(numel(nonNaN) > 0, 'Must have non-NaN values');

    % testFewPointsPassthrough: fewer points than 2*numBuckets -> pass through
    x = 1:5;
    y = [10 20 30 40 50];
    [xOut, yOut] = minmax_downsample(x, y, 10);
    assert(isequal(xOut, x), 'testFewPointsPassthrough xOut');
    assert(isequal(yOut, y), 'testFewPointsPassthrough yOut');

    % testOutputIsMonotonicX: X within each non-NaN segment must be non-decreasing
    x = linspace(0, 10, 10000);
    y = randn(1, 10000);
    [xOut, ~] = minmax_downsample(x, y, 100);
    % Check monotonicity within segments separated by NaN
    nanIdx = find(isnan(xOut));
    starts = [1, nanIdx + 1];
    ends = [nanIdx - 1, numel(xOut)];
    for i = 1:numel(starts)
        seg = xOut(starts(i):ends(i));
        seg = seg(~isnan(seg));
        if numel(seg) > 1
            assert(all(diff(seg) >= 0), 'X within segment must be non-decreasing');
        end
    end

    % testUnevenSpacing: 3 buckets of 3 elements -> 6 output points
    x = [1 2 3 100 200 300 1000 2000 3000];
    y = [1 2 3 4   5   6   7    8    9];
    [xOut, yOut] = minmax_downsample(x, y, 3);
    assert(numel(xOut) == 6, 'testUnevenSpacing: expected 6, got %d', numel(xOut));

    % testAllNaN
    x = 1:10;
    y = NaN(1, 10);
    [xOut, yOut] = minmax_downsample(x, y, 3);
    assert(all(isnan(yOut)), 'testAllNaN: expected all NaN');

    % testLargeData: 1M points in < 1s
    n = 1e6;
    x = 1:n;
    y = randn(1, n);
    tic;
    [xOut, yOut] = minmax_downsample(x, y, 1000);
    elapsed = toc;
    assert(numel(xOut) == 2000, 'testLargeData: expected 2000, got %d', numel(xOut));
    assert(elapsed < 1.0, 'testLargeData: took %.3f s, must be < 1s', elapsed);

    fprintf('    All 8 minmax_downsample tests passed.\n');
end
