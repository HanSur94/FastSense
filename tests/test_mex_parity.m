function test_mex_parity()
%TEST_MEX_PARITY Verify MEX functions produce identical results to MATLAB.
%   Runs both MEX and MATLAB implementations side-by-side and compares.
%   Skips if MEX files are not compiled.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
    add_fastplot_private_path();

    has_bs  = (exist('binary_search_mex', 'file') == 3);
    has_mm  = (exist('minmax_core_mex', 'file') == 3);
    has_lt  = (exist('lttb_core_mex', 'file') == 3);
    has_vc  = (exist('violation_cull_mex', 'file') == 3);

    if ~has_bs && ~has_mm && ~has_lt && ~has_vc
        fprintf('    SKIPPED: No MEX files compiled. Run build_mex() first.\n');
        return;
    end

    tol = 1e-12;
    n_passed = 0;

    % ---- binary_search parity ----
    if has_bs
        x = [1 3 5 7 9 11 13 15 17 19];

        test_cases = {
            4,   'left',  3;
            6,   'right', 3;
            5,   'left',  3;
            5,   'right', 3;
            0,   'left',  1;
            100, 'right', 10;
            100, 'left',  10;
            0,   'right', 1;
        };

        for t = 1:size(test_cases, 1)
            val = test_cases{t, 1};
            dir = test_cases{t, 2};
            expected = test_cases{t, 3};
            result = binary_search_mex(x, val, dir);
            assert(result == expected, ...
                'binary_search_mex(%g, ''%s''): expected %d, got %d', ...
                val, dir, expected, result);
        end

        % Large array parity
        x_large = linspace(0, 1000, 1e6);
        vals = [0.001, 50.5, 500, 999.999];
        for v = 1:numel(vals)
            idx_m = binary_search_matlab(x_large, vals(v), 'left');
            idx_c = binary_search_mex(x_large, vals(v), 'left');
            assert(idx_m == idx_c, ...
                'binary_search parity failed for left val=%g: matlab=%d mex=%d', ...
                vals(v), idx_m, idx_c);

            idx_m = binary_search_matlab(x_large, vals(v), 'right');
            idx_c = binary_search_mex(x_large, vals(v), 'right');
            assert(idx_m == idx_c, ...
                'binary_search parity failed for right val=%g: matlab=%d mex=%d', ...
                vals(v), idx_m, idx_c);
        end

        fprintf('    binary_search_mex parity: PASSED\n');
        n_passed = n_passed + 1;
    end

    % ---- minmax_core parity ----
    if has_mm
        sizes = [100, 1000, 10000, 100000];
        buckets_list = [5, 50, 100, 500];

        for s = 1:numel(sizes)
            n = sizes(s);
            nb = buckets_list(s);
            x = linspace(0, 100, n);
            y = sin(x * 2 * pi / 10) + 0.3 * randn(1, n);

            [xm, ym] = minmax_core_matlab(x, y, nb);
            [xc, yc] = minmax_core_mex(x, y, nb);

            assert(numel(xm) == numel(xc), ...
                'minmax_core output size mismatch at n=%d', n);
            assert(max(abs(xm - xc)) < tol, ...
                'minmax_core X mismatch at n=%d, maxdiff=%g', n, max(abs(xm - xc)));
            assert(max(abs(ym - yc)) < tol, ...
                'minmax_core Y mismatch at n=%d, maxdiff=%g', n, max(abs(ym - yc)));
        end

        fprintf('    minmax_core_mex parity: PASSED\n');
        n_passed = n_passed + 1;
    end

    % ---- lttb_core parity ----
    if has_lt
        sizes = [100, 1000, 10000];
        outs_list = [10, 50, 200];

        for s = 1:numel(sizes)
            n = sizes(s);
            nout = outs_list(s);
            x = linspace(0, 100, n);
            y = sin(x * 2 * pi / 10) + 0.3 * randn(1, n);

            [xm, ym] = lttb_core_matlab(x, y, nout);
            [xc, yc] = lttb_core_mex(x, y, nout);

            assert(numel(xm) == numel(xc), ...
                'lttb_core output size mismatch at n=%d', n);
            assert(max(abs(xm - xc)) < tol, ...
                'lttb_core X mismatch at n=%d, maxdiff=%g', n, max(abs(xm - xc)));
            assert(max(abs(ym - yc)) < tol, ...
                'lttb_core Y mismatch at n=%d, maxdiff=%g', n, max(abs(ym - yc)));
        end

        fprintf('    lttb_core_mex parity: PASSED\n');
        n_passed = n_passed + 1;
    end

    % ---- violation_cull parity ----
    if has_vc
        x = linspace(0, 100, 10000);
        y = sin(x) * 5;
        % Scalar
        [xm, ym] = violation_cull(x, y, 0, 3.0, 'upper', 0.1, 0);
        [xc, yc] = violation_cull_mex(x, y, 0, 3.0, 1, 0.1, 0);
        assert(numel(xm) == numel(xc), 'violation_cull scalar: count mismatch');
        assert(max(abs(xm - xc)) < tol, 'violation_cull scalar: X mismatch');
        % Time-varying
        [xm, ym] = violation_cull(x, y, [0 50], [3 4], 'upper', 0.1, 0);
        [xc, yc] = violation_cull_mex(x, y, [0 50], [3 4], 1, 0.1, 0);
        assert(numel(xm) == numel(xc), 'violation_cull tv: count mismatch');
        assert(max(abs(xm - xc)) < tol, 'violation_cull tv: X mismatch');
        fprintf('    violation_cull_mex parity: PASSED\n');
        n_passed = n_passed + 1;
    end

    fprintf('    All %d MEX parity tests passed.\n', n_passed);
end

% ---- Pure MATLAB reference implementations (copied from private/) ----

function idx = binary_search_matlab(x, val, direction)
    n = numel(x);
    if strcmp(direction, 'left')
        lo = 1; hi = n; idx = n;
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) >= val; idx = mid; hi = mid - 1;
            else; lo = mid + 1; end
        end
    else
        lo = 1; hi = n; idx = 1;
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) <= val; idx = mid; lo = mid + 1;
            else; hi = mid - 1; end
        end
    end
end

function [xOut, yOut] = minmax_core_matlab(segX, segY, nb)
    segLen = numel(segY);
    bucketSize = floor(segLen / nb);
    usable = bucketSize * nb;
    yMat = reshape(segY(1:usable), bucketSize, nb);
    [yMinVals, iMin] = min(yMat, [], 1);
    [yMaxVals, iMax] = max(yMat, [], 1);
    offsets = (0:nb-1) * bucketSize;
    gMin = iMin + offsets;
    gMax = iMax + offsets;
    if usable < segLen
        remY = segY(usable+1:end);
        [remMinVal, remMinIdx] = min(remY);
        [remMaxVal, remMaxIdx] = max(remY);
        if remMinVal < yMinVals(nb)
            yMinVals(nb) = remMinVal;
            gMin(nb) = remMinIdx + usable;
        end
        if remMaxVal > yMaxVals(nb)
            yMaxVals(nb) = remMaxVal;
            gMax(nb) = remMaxIdx + usable;
        end
    end
    xMinVals = segX(gMin);
    xMaxVals = segX(gMax);
    minFirst = gMin <= gMax;
    xOut = zeros(1, 2*nb);
    yOut = zeros(1, 2*nb);
    odd  = 1:2:2*nb;
    even = 2:2:2*nb;
    xOut(odd(minFirst))   = xMinVals(minFirst);
    yOut(odd(minFirst))   = yMinVals(minFirst);
    xOut(even(minFirst))  = xMaxVals(minFirst);
    yOut(even(minFirst))  = yMaxVals(minFirst);
    xOut(odd(~minFirst))  = xMaxVals(~minFirst);
    yOut(odd(~minFirst))  = yMaxVals(~minFirst);
    xOut(even(~minFirst)) = xMinVals(~minFirst);
    yOut(even(~minFirst)) = yMinVals(~minFirst);
end

function [xOut, yOut] = lttb_core_matlab(x, y, numOut)
    n = numel(x);
    xOut = zeros(1, numOut);
    yOut = zeros(1, numOut);
    xOut(1) = x(1); yOut(1) = y(1);
    xOut(numOut) = x(n); yOut(numOut) = y(n);
    bucketSize = (n - 2) / (numOut - 2);
    prevSelectedIdx = 1;
    for i = 2:numOut-1
        bStart = floor((i-2) * bucketSize) + 2;
        bEnd   = min(floor((i-1) * bucketSize) + 1, n-1);
        nStart = floor((i-1) * bucketSize) + 2;
        nEnd   = min(floor(i * bucketSize) + 1, n-1);
        if nEnd < nStart; nEnd = nStart; end
        avgX = mean(x(nStart:nEnd));
        avgY = mean(y(nStart:nEnd));
        pX = x(prevSelectedIdx);
        pY = y(prevSelectedIdx);
        candidates = bStart:bEnd;
        areas = abs((pX - avgX) .* (y(candidates) - pY) - (pX - x(candidates)) .* (avgY - pY));
        [~, bestLocal] = max(areas);
        bestIdx = candidates(bestLocal);
        xOut(i) = x(bestIdx);
        yOut(i) = y(bestIdx);
        prevSelectedIdx = bestIdx;
    end
end
