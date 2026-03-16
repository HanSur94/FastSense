function test_violation_cull_mex()
%TEST_VIOLATION_CULL_MEX Parity tests: MEX vs MATLAB fallback.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
    add_fastplot_private_path();

    hasMex = (exist('violation_cull_mex', 'file') == 3);
    if ~hasMex
        fprintf('    SKIPPED: violation_cull_mex not compiled.\n');
        return;
    end

    tol = 1e-12;

    % testScalarUpperParity
    x = 1:1000;
    y = sin(x / 50) * 10;
    thX = 0; thY = 3.0;
    pw = 0.5; xmin = 1;
    [xM, yM] = matlab_violation_cull(x, y, thX, thY, 'upper', pw, xmin);
    [xC, yC] = violation_cull_mex(x, y, thX, thY, 1, pw, xmin);
    assert(numel(xM) == numel(xC), 'scalarUpper: count mismatch %d vs %d', numel(xM), numel(xC));
    assert(max(abs(xM - xC)) < tol, 'scalarUpper: X mismatch');
    assert(max(abs(yM - yC)) < tol, 'scalarUpper: Y mismatch');

    % testScalarLowerParity
    [xM, yM] = matlab_violation_cull(x, y, thX, thY, 'lower', pw, xmin);
    [xC, yC] = violation_cull_mex(x, y, thX, thY, 0, pw, xmin);
    assert(numel(xM) == numel(xC), 'scalarLower: count mismatch');
    assert(max(abs(xM - xC)) < tol, 'scalarLower: X mismatch');

    % testTimeVaryingParity
    thX2 = [0 500 800];
    thY2 = [3.0 6.0 2.0];
    pw2 = 1.0; xmin2 = 1;
    [xM, yM] = matlab_violation_cull(x, y, thX2, thY2, 'upper', pw2, xmin2);
    [xC, yC] = violation_cull_mex(x, y, thX2, thY2, 1, pw2, xmin2);
    assert(numel(xM) == numel(xC), 'timeVarying: count mismatch %d vs %d', numel(xM), numel(xC));
    assert(max(abs(xM - xC)) < tol, 'timeVarying: X mismatch');
    assert(max(abs(yM - yC)) < tol, 'timeVarying: Y mismatch');

    % testEmptyInput
    [xC, yC] = violation_cull_mex([], [], 0, 5, 1, 1.0, 0);
    assert(isempty(xC), 'empty: xC');
    assert(isempty(yC), 'empty: yC');

    % testNoViolations
    x3 = 1:100;
    y3 = zeros(1, 100);
    [xC, yC] = violation_cull_mex(x3, y3, 0, 5, 1, 1.0, 1);
    assert(isempty(xC), 'noViolations: xC should be empty');

    % testNaNSkipped
    x4 = 1:10;
    y4 = [6 NaN 7 NaN 8 NaN 9 NaN 10 NaN];
    [xC, yC] = violation_cull_mex(x4, y4, 0, 5, 1, 1.0, 1);
    % All non-NaN values > 5, each in its own pixel bucket (pw=1)
    assert(numel(xC) == 5, 'NaN: should have 5 violations, got %d', numel(xC));

    % testLargeArrayParity — stress test
    n = 1000000;
    x5 = linspace(0, 10000, n);
    y5 = sin(x5 / 100) * 10 + randn(1, n) * 0.5;
    thX5 = [0 3000 7000];
    thY5 = [4 6 3];
    pw5 = 10000 / 1920;  % typical 1920px display
    [xM, yM] = matlab_violation_cull(x5, y5, thX5, thY5, 'upper', pw5, 0);
    [xC, yC] = violation_cull_mex(x5, y5, thX5, thY5, 1, pw5, 0);
    assert(numel(xM) == numel(xC), 'large: count mismatch %d vs %d', numel(xM), numel(xC));
    assert(max(abs(xM - xC)) < tol, 'large: X mismatch');
    assert(max(abs(yM - yC)) < tol, 'large: Y mismatch');

    fprintf('    All 7 violation_cull_mex parity tests passed.\n');
end

function [xOut, yOut] = matlab_violation_cull(x, y, thX, thY, direction, pw, xmin)
%MATLAB_VIOLATION_CULL Reference implementation matching MEX behavior.
    if isempty(x) || pw <= 0
        xOut = zeros(1, 0);
        yOut = zeros(1, 0);
        return;
    end

    % Step 1: compute violations (matches compute_violations / _dynamic)
    if numel(thX) == 1
        thAtX = repmat(thY(1), size(x));
    else
        thAtX = interp1(thX, thY, x, 'previous', 'extrap');
        beforeFirst = x < thX(1);
        thAtX(beforeFirst) = thY(1);
    end

    if strcmp(direction, 'upper')
        mask = y > thAtX;
    else
        mask = y < thAtX;
    end

    xV = x(mask);
    yV = y(mask);
    thV = thAtX(mask);

    if isempty(xV)
        xOut = zeros(1, 0);
        yOut = zeros(1, 0);
        return;
    end

    % Step 2: pixel-density cull (matches downsample_violations logic)
    buckets = floor((xV - xmin) / pw);
    deviation = abs(yV - thV);

    [uBuckets, ~, ic] = unique(buckets);
    nB = numel(uBuckets);
    xOut = zeros(1, nB);
    yOut = zeros(1, nB);

    for b = 1:nB
        m = (ic == b);
        devs = deviation(m);
        [~, bestIdx] = max(devs);
        bx = xV(m);
        by = yV(m);
        xOut(b) = bx(bestIdx);
        yOut(b) = by(bestIdx);
    end
end
