function [xOut, yOut] = minmax_downsample(x, y, numBuckets, hasNaN)
%MINMAX_DOWNSAMPLE Reduce time series to min/max pairs per bucket.
%   [xOut, yOut] = minmax_downsample(x, y, numBuckets)
%   [xOut, yOut] = minmax_downsample(x, y, numBuckets, hasNaN)
%
%   Divides the data into numBuckets equal-width bins and keeps only the
%   minimum and maximum Y values per bin, preserving X monotonicity.
%   This produces 2*numBuckets output points that accurately represent
%   the signal envelope.
%
%   NaN handling:
%     Splits data at NaN boundaries, downsamples each contiguous segment
%     independently with proportional bucket allocation, and rejoins with
%     NaN separators to preserve gap rendering.
%
%   Inputs:
%     x          — sorted numeric row vector of timestamps
%     y          — numeric row vector of values (same length as x)
%     numBuckets — desired number of bins (output ≈ 2*numBuckets points)
%     hasNaN     — (optional) logical, skip NaN scan when known false
%
%   Outputs:
%     xOut — downsampled X values (row vector)
%     yOut — downsampled Y values (row vector)
%
%   If total non-NaN points <= 2*numBuckets, returns data unchanged.
%   Uses MEX (minmax_core_mex) when available for speed.
%
%   See also lttb_downsample, binary_search.

    persistent useMex;
    if isempty(useMex)
        useMex = (exist('minmax_core_mex', 'file') == 3);
    end

    n = numel(y);

    % Fast path: no NaN (common case)
    if nargin < 4
        hasNaN = any(isnan(y));
    end

    if ~hasNaN
        if n <= 2 * numBuckets
            xOut = x;
            yOut = y;
            return;
        end
        if useMex
            [xOut, yOut] = minmax_core_mex(x, y, numBuckets);
        else
            [xOut, yOut] = minmax_core(x, y, numBuckets);
        end
        return;
    end

    % --- NaN-aware path ---
    isNan = isnan(y);

    % All NaN
    if all(isNan)
        xOut = x;
        yOut = y;
        return;
    end

    % Find start/end of contiguous non-NaN segments
    nanMask = [true, isNan, true];
    edges = diff(nanMask);
    segStarts = find(edges == -1);
    segEnds   = find(edges == 1) - 1;
    numSegs = numel(segStarts);

    totalValid = sum(~isNan);

    if totalValid <= 2 * numBuckets
        xOut = x;
        yOut = y;
        return;
    end

    % Distribute buckets proportionally across segments
    segLens = segEnds - segStarts + 1;
    segBuckets = max(1, round(numBuckets * segLens / totalValid));

    % Pre-allocate output
    maxOut = sum(segBuckets) * 2 + (numSegs - 1);
    xOut = NaN(1, maxOut);
    yOut = NaN(1, maxOut);
    pos = 0;

    for s = 1:numSegs
        si = segStarts(s);
        ei = segEnds(s);
        nb = segBuckets(s);
        segX = x(si:ei);
        segY = y(si:ei);
        segLen = ei - si + 1;

        if segLen <= 2 * nb
            xOut(pos+1:pos+segLen) = segX;
            yOut(pos+1:pos+segLen) = segY;
            pos = pos + segLen;
        else
            if useMex
                [sx, sy] = minmax_core_mex(segX, segY, nb);
            else
                [sx, sy] = minmax_core(segX, segY, nb);
            end
            nOut = numel(sx);
            xOut(pos+1:pos+nOut) = sx;
            yOut(pos+1:pos+nOut) = sy;
            pos = pos + nOut;
        end

        if s < numSegs
            pos = pos + 1;
            % NaN separator already there from pre-allocation
        end
    end

    xOut = xOut(1:pos);
    yOut = yOut(1:pos);
end


function [xOut, yOut] = minmax_core(segX, segY, nb)
%MINMAX_CORE Vectorized min/max downsampling of a contiguous (no NaN) segment.
%   [xOut, yOut] = minmax_core(segX, segY, nb)
%
%   Reshapes data into a matrix of nb columns, finds min/max per column,
%   handles remainder points, and interleaves results in X-monotonic order.
    segLen = numel(segY);
    bucketSize = floor(segLen / nb);

    % Reshape into matrix: each column is one bucket
    usable = bucketSize * nb;
    yMat = reshape(segY(1:usable), bucketSize, nb);

    [yMinVals, iMin] = min(yMat, [], 1);
    [yMaxVals, iMax] = max(yMat, [], 1);

    % Convert local indices to global segment indices
    offsets = (0:nb-1) * bucketSize;
    gMin = iMin + offsets;
    gMax = iMax + offsets;

    % Handle remainder: fold into last bucket
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

    % Build output in x-order (preserve monotonicity)
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
