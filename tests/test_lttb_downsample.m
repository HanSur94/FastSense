function test_lttb_downsample()
%TEST_LTTB_DOWNSAMPLE Tests for lttb_downsample private function.

    run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));
    add_fastplot_private_path();

    % testOutputSize
    x = 1:1000;
    y = sin(linspace(0, 4*pi, 1000));
    [xOut, yOut] = lttb_downsample(x, y, 50);
    assert(numel(xOut) == 50, 'testOutputSize xOut: expected 50, got %d', numel(xOut));
    assert(numel(yOut) == 50, 'testOutputSize yOut: expected 50, got %d', numel(yOut));

    % testPreservesEndpoints
    x = 1:1000;
    y = rand(1, 1000);
    [xOut, yOut] = lttb_downsample(x, y, 50);
    assert(xOut(1) == x(1), 'testPreservesEndpoints: first x');
    assert(xOut(end) == x(end), 'testPreservesEndpoints: last x');
    assert(yOut(1) == y(1), 'testPreservesEndpoints: first y');
    assert(yOut(end) == y(end), 'testPreservesEndpoints: last y');

    % testMonotonicX
    x = linspace(0, 10, 5000);
    y = randn(1, 5000);
    [xOut, ~] = lttb_downsample(x, y, 100);
    assert(all(diff(xOut) > 0), 'testMonotonicX: X must be strictly increasing');

    % testFewPointsPassthrough
    x = 1:5;
    y = [10 20 30 40 50];
    [xOut, yOut] = lttb_downsample(x, y, 10);
    assert(isequal(xOut, x), 'testFewPointsPassthrough xOut');
    assert(isequal(yOut, y), 'testFewPointsPassthrough yOut');

    % testNaNGaps
    x = 1:20;
    y = [1:8, NaN, NaN, 11:20];
    [xOut, yOut] = lttb_downsample(x, y, 8);
    assert(any(isnan(yOut)), 'Must preserve NaN gaps');

    % testPerformance
    n = 1e6;
    x = 1:n;
    y = randn(1, n);
    tic;
    lttb_downsample(x, y, 1000);
    elapsed = toc;
    assert(elapsed < 2.0, 'testPerformance: took %.3f s, must be < 2s', elapsed);

    fprintf('    All 6 lttb_downsample tests passed.\n');
end
