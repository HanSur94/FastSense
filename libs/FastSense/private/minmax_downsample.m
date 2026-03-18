function [xOut, yOut] = minmax_downsample(x, y, numBuckets, hasNaN, logX)
%MINMAX_DOWNSAMPLE Reduce time series to min/max pairs per bucket.
%   [xOut, yOut] = MINMAX_DOWNSAMPLE(x, y, numBuckets) divides the data
%   into numBuckets equal-width bins along the X axis and keeps only the
%   minimum and maximum Y values per bin. This produces approximately
%   2*numBuckets output points that faithfully represent the signal
%   envelope for visual rendering.
%
%   [xOut, yOut] = MINMAX_DOWNSAMPLE(x, y, numBuckets, hasNaN) allows the
%   caller to skip the internal NaN scan when hasNaN is known to be false.
%
%   [xOut, yOut] = MINMAX_DOWNSAMPLE(x, y, numBuckets, hasNaN, logX) uses
%   logarithmically-spaced bucket edges when logX is true, producing
%   visually uniform bin widths on a log-scale X axis.
%
%   This function is a private helper for FastSense.
%
%   Inputs:
%     x          — sorted numeric row vector of X coordinates (ascending)
%     y          — numeric row vector of Y values (same length as x)
%     numBuckets — positive integer, desired number of bins
%                  (output length is approximately 2*numBuckets)
%     hasNaN     — (optional) logical scalar. When false, skips the NaN
%                  scan for a faster code path. Default: any(isnan(y)).
%     logX       — (optional) logical scalar. When true, bucket edges are
%                  uniform in log10(X) space. Default: false.
%
%   Outputs:
%     xOut — downsampled X values (row vector)
%     yOut — downsampled Y values (row vector)
%
%   Algorithm:
%     NaN-free path:
%       Delegates to minmax_core (or minmax_core_mex if compiled, or
%       minmax_core_logx for log axes). Each bin's min and max are found
%       via vectorized reshape + min/max, and output pairs are ordered to
%       preserve X monotonicity.
%     NaN-aware path:
%       1. Finds contiguous non-NaN segments using diff on a NaN mask.
%       2. Allocates output buckets proportionally to segment length.
%       3. Downsamples each segment independently.
%       4. Rejoins segments with NaN separators to preserve gap rendering.
%
%   If total non-NaN points <= 2*numBuckets, returns data unchanged
%   (no downsampling needed).
%
%   See also lttb_downsample, binary_search, minmax_core_mex.

    % Check once whether the compiled MEX is available on this machine
    persistent useMex;
    if isempty(useMex)
        useMex = (exist('minmax_core_mex', 'file') == 3);
    end

    n = numel(y);

    % Default optional arguments
    if nargin < 4
        hasNaN = any(isnan(y));
    end
    if nargin < 5
        logX = false;
    end

    % ---- Fast path: no NaN values (common case) ----
    if ~hasNaN
        % Passthrough when data is already small enough
        if n <= 2 * numBuckets
            xOut = x;
            yOut = y;
            return;
        end
        % Dispatch to the appropriate core implementation
        if logX
            [xOut, yOut] = minmax_core_logx(x, y, numBuckets);
        elseif useMex
            [xOut, yOut] = minmax_core_mex(x, y, numBuckets);
        else
            [xOut, yOut] = minmax_core(x, y, numBuckets);
        end
        return;
    end

    % ---- NaN-aware path: split at NaN gaps, downsample each segment ----
    isNan = isnan(y);

    % All-NaN data: nothing to downsample
    if all(isNan)
        xOut = x;
        yOut = y;
        return;
    end

    % Detect contiguous non-NaN segments using sentinel-padded diff trick:
    %   Pad with true on both ends so that a transition true->false marks a
    %   segment start (-1) and false->true marks a segment end (+1).
    nanMask = [true, isNan, true];
    edges = diff(nanMask);
    segStarts = find(edges == -1);
    segEnds   = find(edges == 1) - 1;
    numSegs = numel(segStarts);

    totalValid = sum(~isNan);

    % If valid point count is already within budget, return as-is
    if totalValid <= 2 * numBuckets
        xOut = x;
        yOut = y;
        return;
    end

    % Distribute buckets proportionally to each segment's length
    segLens = segEnds - segStarts + 1;
    segBuckets = max(1, round(numBuckets * segLens / totalValid));

    % Pre-allocate output arrays with NaN (NaN separators come for free)
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
            % Segment is small enough — copy directly
            xOut(pos+1:pos+segLen) = segX;
            yOut(pos+1:pos+segLen) = segY;
            pos = pos + segLen;
        else
            % Downsample this segment using the appropriate core
            if logX
                [sx, sy] = minmax_core_logx(segX, segY, nb);
            elseif useMex
                [sx, sy] = minmax_core_mex(segX, segY, nb);
            else
                [sx, sy] = minmax_core(segX, segY, nb);
            end
            nOut = numel(sx);
            xOut(pos+1:pos+nOut) = sx;
            yOut(pos+1:pos+nOut) = sy;
            pos = pos + nOut;
        end

        % Leave a NaN gap between segments (pre-allocated as NaN)
        if s < numSegs
            pos = pos + 1;
        end
    end

    % Trim pre-allocated tail
    xOut = xOut(1:pos);
    yOut = yOut(1:pos);
end

function [xOut, yOut] = minmax_core(segX, segY, nb)
%MINMAX_CORE Vectorized min/max downsampling of a contiguous segment.
%   [xOut, yOut] = MINMAX_CORE(segX, segY, nb) performs min/max envelope
%   extraction on a NaN-free data segment using fully vectorized matrix
%   operations (no per-bucket loop).
%
%   This function is a local helper for minmax_downsample.
%
%   Inputs:
%     segX — sorted numeric row vector of X coordinates (no NaN)
%     segY — numeric row vector of Y values (no NaN, same length as segX)
%     nb   — positive integer, number of buckets
%
%   Outputs:
%     xOut — 1x(2*nb) row vector of downsampled X values
%     yOut — 1x(2*nb) row vector of downsampled Y values
%
%   Algorithm:
%     1. Compute bucketSize = floor(N / nb). Reshape the first
%        bucketSize*nb points into a (bucketSize x nb) matrix.
%     2. Find min and max of each column — gives one min/max pair per
%        bucket in O(N) total work.
%     3. Remainder points (N mod nb) are folded into the last bucket:
%        if the remainder has a more extreme min or max, it replaces the
%        last bucket's value.
%     4. For each bucket, the min and max are emitted in the order of
%        their original X positions (min-first or max-first) to preserve
%        strict X monotonicity in the output.

    segLen = numel(segY);
    bucketSize = floor(segLen / nb);

    % Reshape into matrix: each column is one bucket for vectorized min/max
    usable = bucketSize * nb;
    yMat = reshape(segY(1:usable), bucketSize, nb);

    [yMinVals, iMin] = min(yMat, [], 1);
    [yMaxVals, iMax] = max(yMat, [], 1);

    % Convert column-local indices to segment-global indices
    offsets = (0:nb-1) * bucketSize;
    gMin = iMin + offsets;
    gMax = iMax + offsets;

    % Handle remainder points that don't fill a complete bucket:
    % fold them into the last bucket and update extremes if needed
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

    % Interleave min/max pairs in X-monotonic order:
    %   If the min occurs before the max in the original data, emit
    %   (min, max); otherwise emit (max, min).
    minFirst = gMin <= gMax;

    xOut = zeros(1, 2*nb);
    yOut = zeros(1, 2*nb);

    odd  = 1:2:2*nb;   % slot indices for the first point of each pair
    even = 2:2:2*nb;   % slot indices for the second point of each pair

    % Buckets where min comes first in X
    xOut(odd(minFirst))   = xMinVals(minFirst);
    yOut(odd(minFirst))   = yMinVals(minFirst);
    xOut(even(minFirst))  = xMaxVals(minFirst);
    yOut(even(minFirst))  = yMaxVals(minFirst);

    % Buckets where max comes first in X
    xOut(odd(~minFirst))  = xMaxVals(~minFirst);
    yOut(odd(~minFirst))  = yMaxVals(~minFirst);
    xOut(even(~minFirst)) = xMinVals(~minFirst);
    yOut(even(~minFirst)) = yMinVals(~minFirst);
end

function [xOut, yOut] = minmax_core_logx(segX, segY, nb)
%MINMAX_CORE_LOGX Min/max downsampling with logarithmically-spaced buckets.
%   [xOut, yOut] = MINMAX_CORE_LOGX(segX, segY, nb) performs min/max
%   envelope extraction using bucket edges that are uniformly spaced in
%   log10(X), producing visually even bin widths on a logarithmic X axis.
%
%   This function is a local helper for minmax_downsample.
%
%   Inputs:
%     segX — sorted numeric row vector of positive X coordinates (no NaN)
%     segY — numeric row vector of Y values (no NaN, same length as segX)
%     nb   — positive integer, number of buckets
%
%   Outputs:
%     xOut — row vector of downsampled X values (length <= 2*nb)
%     yOut — row vector of downsampled Y values (same length as xOut)
%
%   Algorithm:
%     Computes nb+1 edges in log10 space via linspace, converts back to
%     linear space, then iterates over buckets. Each bucket uses a mask to
%     select its points, finds min/max, and emits them in X-monotonic
%     order. Empty buckets (possible with non-uniform X spacing) are
%     skipped, so the output may be shorter than 2*nb.
%
%   See also minmax_core, minmax_downsample.

    % Compute bucket edges uniformly in log10 space
    logMin = log10(segX(1));
    logMax = log10(segX(end));
    logEdges = linspace(logMin, logMax, nb + 1);
    edges = 10 .^ logEdges;

    % Pre-allocate for worst case; trim later
    xOut = zeros(1, 2*nb);
    yOut = zeros(1, 2*nb);
    pos = 0;

    for b = 1:nb
        % Last bucket uses closed right edge to include the final point
        if b == nb
            mask = segX >= edges(b) & segX <= edges(b+1);
        else
            mask = segX >= edges(b) & segX < edges(b+1);
        end

        % Skip empty buckets (can happen with clustered data)
        if ~any(mask)
            continue;
        end

        bx = segX(mask);
        by = segY(mask);

        [yMinVal, iMin] = min(by);
        [yMaxVal, iMax] = max(by);

        % Emit min/max pair in X-monotonic order
        if iMin <= iMax
            pos = pos + 1; xOut(pos) = bx(iMin); yOut(pos) = yMinVal;
            pos = pos + 1; xOut(pos) = bx(iMax); yOut(pos) = yMaxVal;
        else
            pos = pos + 1; xOut(pos) = bx(iMax); yOut(pos) = yMaxVal;
            pos = pos + 1; xOut(pos) = bx(iMin); yOut(pos) = yMinVal;
        end
    end

    % Trim unused pre-allocated tail
    xOut = xOut(1:pos);
    yOut = yOut(1:pos);
end
