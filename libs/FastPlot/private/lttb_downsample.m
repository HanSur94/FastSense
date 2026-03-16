function [xOut, yOut] = lttb_downsample(x, y, numOut, logX, logY)
%LTTB_DOWNSAMPLE Largest Triangle Three Buckets downsampling.
%   [xOut, yOut] = LTTB_DOWNSAMPLE(x, y, numOut) reduces a time series to
%   numOut points while preserving the visual shape of the signal. For each
%   bucket, the algorithm selects the point that maximizes the triangle
%   area formed with the previously selected point and the centroid of the
%   next bucket, producing perceptually accurate downsampled plots.
%
%   [xOut, yOut] = LTTB_DOWNSAMPLE(x, y, numOut, logX, logY) uses
%   log-transformed coordinates for the area computation when logX or logY
%   is true, yielding visually accurate point selection on logarithmic
%   axes. Output values remain in original (linear) space.
%
%   This function is a private helper for FastPlot.
%
%   Inputs:
%     x      — sorted numeric row vector of X coordinates (ascending)
%     y      — numeric row vector of Y values (same length as x)
%     numOut — positive integer, desired number of output points
%     logX   — (optional) logical scalar. When true, area computation uses
%              log10(X). Default: false.
%     logY   — (optional) logical scalar. When true, area computation uses
%              log10(Y). Default: false.
%
%   Outputs:
%     xOut — downsampled X values (row vector, length <= numOut)
%     yOut — downsampled Y values (row vector, same length as xOut)
%
%   NaN handling:
%     Splits data at NaN boundaries, allocates output points proportional
%     to each segment's length (minimum 2 per segment), downsamples each
%     segment independently via lttb_core, and rejoins with NaN separators
%     to preserve gap rendering in plots.
%
%   If n <= numOut, returns data unchanged (no downsampling needed).
%   Uses MEX (lttb_core_mex) when compiled and available, for linear mode
%   only (logX == false && logY == false).
%
%   Reference:
%     Steinarsson, S. (2013). "Downsampling Time Series for Visual
%     Representation." MSc thesis, University of Iceland.
%
%   See also minmax_downsample, binary_search, lttb_core_mex.

    % Check once whether the compiled MEX is available on this machine
    persistent useMex;
    if isempty(useMex)
        useMex = (exist('lttb_core_mex', 'file') == 3);
    end

    n = numel(y);
    isNan = isnan(y);

    % All-NaN data: nothing meaningful to downsample
    if all(isNan)
        xOut = x;
        yOut = y;
        return;
    end

    % Passthrough: data already within budget
    if n <= numOut
        xOut = x;
        yOut = y;
        return;
    end

    if nargin < 4; logX = false; end
    if nargin < 5; logY = false; end

    % ---- Detect contiguous non-NaN segments ----
    % Sentinel-padded diff trick (same approach as minmax_downsample)
    nanMask = [true, isNan, true];
    edges = diff(nanMask);
    segStarts = find(edges == -1);
    segEnds   = find(edges == 1) - 1;
    numSegs = numel(segStarts);
    segLens = segEnds - segStarts + 1;
    totalValid = sum(segLens);

    % Distribute output points proportionally (min 2 per segment for LTTB)
    segOuts = max(2, round(numOut * segLens / totalValid));

    % Pre-allocate output with NaN fill (NaN separators come for free)
    maxOut = sum(segOuts) + (numSegs - 1);
    xOut = NaN(1, maxOut);
    yOut = NaN(1, maxOut);
    pos = 0;

    for s = 1:numSegs
        si = segStarts(s);
        ei = segEnds(s);
        segX = x(si:ei);
        segY = y(si:ei);
        segLen = ei - si + 1;
        nout = segOuts(s);

        if segLen <= nout
            % Segment is small enough — copy directly
            xOut(pos+1:pos+segLen) = segX;
            yOut(pos+1:pos+segLen) = segY;
            pos = pos + segLen;
        else
            % Downsample this segment
            if useMex && ~logX && ~logY
                % MEX path: fastest, linear mode only
                [sx, sy] = lttb_core_mex(segX, segY, nout);
            else
                % MATLAB path: supports log-transformed area computation
                [sx, sy] = lttb_core(segX, segY, nout, logX, logY);
            end
            nPts = numel(sx);
            xOut(pos+1:pos+nPts) = sx;
            yOut(pos+1:pos+nPts) = sy;
            pos = pos + nPts;
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

function [xOut, yOut] = lttb_core(x, y, numOut, logX, logY)
%LTTB_CORE Core LTTB algorithm on a contiguous (no NaN) segment.
%   [xOut, yOut] = LTTB_CORE(x, y, numOut, logX, logY) performs the
%   Largest Triangle Three Buckets point selection on a NaN-free data
%   segment. The first and last points are always kept. For each
%   intermediate bucket, the point maximizing the triangle area with the
%   previously selected point and the next bucket's centroid is chosen.
%
%   This function is a local helper for lttb_downsample.
%
%   Inputs:
%     x      — sorted numeric row vector of X coordinates (no NaN)
%     y      — numeric row vector of Y values (no NaN, same length as x)
%     numOut — positive integer >= 2, desired number of output points
%     logX   — (optional) logical. Use log10(X) for area computation.
%              Default: false.
%     logY   — (optional) logical. Use log10(Y) for area computation.
%              Default: false.
%
%   Outputs:
%     xOut — 1-by-numOut row vector of selected X values
%     yOut — 1-by-numOut row vector of selected Y values
%
%   Algorithm:
%     1. Divide the N-2 interior points into (numOut-2) equal-sized
%        buckets (fractional boundaries handled via floor).
%     2. For bucket i, compute the centroid (avgX, avgY) of the *next*
%        bucket (look-ahead).
%     3. For each candidate point in bucket i, compute the triangle area
%        formed by (previousSelected, candidate, centroid) using the
%        cross-product formula:
%          area = |((px - ax)*(cy - py) - (px - cx)*(ay - py))| / 2
%        The factor of 2 is omitted since only relative magnitude matters.
%     4. Select the candidate with the largest area.
%     5. When logX/logY are true, area computation uses log-transformed
%        coordinates but output values remain in original space.
%
%   See also lttb_downsample, lttb_core_mex.

    if nargin < 4; logX = false; end
    if nargin < 5; logY = false; end

    n = numel(x);

    % Build log-transformed coordinate arrays for area computation
    if logX
        xArea = log10(max(x, eps));  % clamp to eps to avoid log10(0)
    else
        xArea = x;
    end
    if logY
        yArea = log10(max(y, eps));
    else
        yArea = y;
    end

    % Pre-allocate output; first and last points are always kept
    xOut = zeros(1, numOut);
    yOut = zeros(1, numOut);
    xOut(1) = x(1);
    yOut(1) = y(1);
    xOut(numOut) = x(n);
    yOut(numOut) = y(n);

    % Fractional bucket size for the (numOut-2) interior buckets
    bucketSize = (n - 2) / (numOut - 2);

    prevSelectedIdx = 1;

    for i = 2:numOut-1
        % Current bucket range (indices into x/y)
        bStart = floor((i-2) * bucketSize) + 2;
        bEnd   = min(floor((i-1) * bucketSize) + 1, n-1);

        % Next bucket range (for centroid / look-ahead)
        nStart = floor((i-1) * bucketSize) + 2;
        nEnd   = min(floor(i * bucketSize) + 1, n-1);
        if nEnd < nStart
            nEnd = nStart;
        end

        % Centroid of the next bucket (the "third point" of the triangle)
        avgX = mean(xArea(nStart:nEnd));
        avgY = mean(yArea(nStart:nEnd));

        % Vectorized triangle area for all candidates in the current bucket
        pX = xArea(prevSelectedIdx);
        pY = yArea(prevSelectedIdx);
        candidates = bStart:bEnd;
        areas = abs((pX - avgX) .* (yArea(candidates) - pY) ...
                   - (pX - xArea(candidates)) .* (avgY - pY));

        % Pick the candidate with the largest triangle area
        [~, bestLocal] = max(areas);
        bestIdx = candidates(bestLocal);

        % Store the selected point in original (non-log) coordinates
        xOut(i) = x(bestIdx);
        yOut(i) = y(bestIdx);
        prevSelectedIdx = bestIdx;
    end
end
