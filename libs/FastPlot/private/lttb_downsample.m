function [xOut, yOut] = lttb_downsample(x, y, numOut)
%LTTB_DOWNSAMPLE Largest Triangle Three Buckets downsampling.
%   [xOut, yOut] = lttb_downsample(x, y, numOut)
%
%   Selects numOut points that best preserve the visual shape of the data
%   by maximizing the triangle area formed between consecutive selected points.
%
%   Handles NaN gaps: splits into segments, distributes output points
%   proportionally, then rejoins with NaN separators.

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
%LTTB_CORE Core LTTB on a contiguous (no NaN) segment. Vectorized inner loop.
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
