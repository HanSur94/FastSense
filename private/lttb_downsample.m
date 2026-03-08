function [xOut, yOut] = lttb_downsample(x, y, numOut)
%LTTB_DOWNSAMPLE Largest Triangle Three Buckets downsampling.
%   [xOut, yOut] = lttb_downsample(x, y, numOut)
%
%   Reduces a time series to numOut points while preserving visual shape.
%   For each bucket, selects the point that maximizes the triangle area
%   formed with the previously selected point and the average of the next
%   bucket — producing perceptually accurate downsampled plots.
%
%   NaN handling:
%     Splits data at NaN boundaries, allocates output points proportional
%     to segment length, downsamples each segment independently, and
%     rejoins with NaN separators.
%
%   Inputs:
%     x      — sorted numeric row vector of timestamps
%     y      — numeric row vector of values (same length as x)
%     numOut — desired number of output points
%
%   Outputs:
%     xOut — downsampled X values (row vector)
%     yOut — downsampled Y values (row vector)
%
%   If n <= numOut, returns data unchanged.
%   Uses MEX (lttb_core_mex) when available for speed.
%
%   Reference:
%     Steinarsson, S. (2013). "Downsampling Time Series for Visual
%     Representation." MSc thesis, University of Iceland.
%
%   See also minmax_downsample, binary_search.

    persistent useMex;
    if isempty(useMex)
        useMex = (exist('lttb_core_mex', 'file') == 3);
    end

    n = numel(y);
    isNan = isnan(y);

    % All NaN
    if all(isNan)
        xOut = x;
        yOut = y;
        return;
    end

    % Passthrough if too few
    if n <= numOut
        xOut = x;
        yOut = y;
        return;
    end

    % Find contiguous non-NaN segments
    nanMask = [true, isNan, true];
    edges = diff(nanMask);
    segStarts = find(edges == -1);
    segEnds   = find(edges == 1) - 1;
    numSegs = numel(segStarts);
    segLens = segEnds - segStarts + 1;
    totalValid = sum(segLens);

    % Distribute output points proportionally
    segOuts = max(2, round(numOut * segLens / totalValid));

    % Pre-allocate
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
            xOut(pos+1:pos+segLen) = segX;
            yOut(pos+1:pos+segLen) = segY;
            pos = pos + segLen;
        else
            if useMex
                [sx, sy] = lttb_core_mex(segX, segY, nout);
            else
                [sx, sy] = lttb_core(segX, segY, nout);
            end
            nPts = numel(sx);
            xOut(pos+1:pos+nPts) = sx;
            yOut(pos+1:pos+nPts) = sy;
            pos = pos + nPts;
        end

        if s < numSegs
            pos = pos + 1;
            % NaN separator already in pre-allocated array
        end
    end

    xOut = xOut(1:pos);
    yOut = yOut(1:pos);
end


function [xOut, yOut] = lttb_core(x, y, numOut)
%LTTB_CORE Core LTTB algorithm on a contiguous (no NaN) segment.
%   [xOut, yOut] = lttb_core(x, y, numOut)
%
%   Always keeps first and last points. For each intermediate bucket,
%   selects the point maximizing triangle area with the previous selected
%   point and the next bucket's centroid. Uses vectorized area computation.
    n = numel(x);

    xOut = zeros(1, numOut);
    yOut = zeros(1, numOut);
    xOut(1) = x(1);
    yOut(1) = y(1);
    xOut(numOut) = x(n);
    yOut(numOut) = y(n);

    bucketSize = (n - 2) / (numOut - 2);

    prevSelectedIdx = 1;

    for i = 2:numOut-1
        bStart = floor((i-2) * bucketSize) + 2;
        bEnd   = min(floor((i-1) * bucketSize) + 1, n-1);

        nStart = floor((i-1) * bucketSize) + 2;
        nEnd   = min(floor(i * bucketSize) + 1, n-1);
        if nEnd < nStart
            nEnd = nStart;
        end
        avgX = mean(x(nStart:nEnd));
        avgY = mean(y(nStart:nEnd));

        % Vectorized triangle area for all candidates in bucket
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
