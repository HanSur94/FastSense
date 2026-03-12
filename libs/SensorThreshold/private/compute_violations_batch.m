function [batchViolX, batchViolY] = compute_violations_batch(sensorX, sensorY, segLo, segHi, thresholdValues, directions)
%COMPUTE_VIOLATIONS_BATCH Vectorized batch violation detection across segments.
%   [batchViolX, batchViolY] = COMPUTE_VIOLATIONS_BATCH(sensorX, sensorY,
%       segLo, segHi, thresholdValues, directions) identifies the X/Y
%   coordinates of sensorY that violate each threshold within the specified
%   active segment ranges.  This is the inner computational kernel of
%   Sensor.resolve().
%
%   Two code paths are available:
%     1. MEX path: delegates to compute_violations_mex (SIMD-accelerated C)
%        which returns X/Y directly, avoiding costly MATLAB random-access
%        indexing into large arrays.
%     2. Pure-MATLAB fallback: iterates over segments once and checks all
%        thresholds per chunk (single-pass over data).
%
%   Inputs:
%     sensorX         — 1xN double, the full sensor X data vector
%     sensorY         — 1xN double, the full sensor Y data vector
%     segLo           — 1xS integer, start indices of active segments
%                        (1-based, inclusive)
%     segHi           — 1xS integer, end indices of active segments
%                        (1-based, inclusive)
%     thresholdValues — 1xT double, threshold value for each rule
%     directions      — 1xT logical, true = upper (violation when
%                        y > threshold), false = lower (violation when
%                        y < threshold)
%
%   Outputs:
%     batchViolX — 1xT cell array; batchViolX{t} is a 1xK double vector
%                  of violation X coordinates for threshold t
%     batchViolY — 1xT cell array; batchViolY{t} is a 1xK double vector
%                  of violation Y coordinates for threshold t
%
%   See also Sensor.resolve, binary_search.

    % --- MEX availability flag (cached across calls) ---
    persistent useMex;
    if isempty(useMex)
        useMex = (exist('compute_violations_mex', 'file') == 3);
    end

    % --- MEX fast path: returns X/Y directly ---
    if useMex
        [batchViolX, batchViolY] = compute_violations_mex( ...
            sensorX, sensorY, double(segLo), double(segHi), ...
            double(thresholdValues), double(directions));
        return;
    end

    % --- Pure-MATLAB single-pass fallback ---
    % Instead of iterating (nThresholds * nSegs), iterate over segments
    % once and check all thresholds per chunk.  This is faster because
    % each chunk is extracted from sensorY only once.
    nThresholds = numel(thresholdValues);
    nSegs = numel(segLo);
    batchViolX = cell(1, nThresholds);
    batchViolY = cell(1, nThresholds);

    % Upper-bound buffer size: total data points across all active segments
    totalPoints = sum(segHi - segLo + 1);

    % Pre-allocate X and Y output buffers for all thresholds at once
    bufsX = zeros(nThresholds, totalPoints);
    bufsY = zeros(nThresholds, totalPoints);
    counts = zeros(1, nThresholds);

    % Separate upper and lower thresholds for vectorized comparison
    upperMask = logical(directions);
    lowerMask = ~upperMask;
    upperIdx = find(upperMask);
    lowerIdx = find(lowerMask);

    for s = 1:nSegs
        lo = segLo(s);
        hi = segHi(s);

        % Extract X and Y chunks once for all thresholds
        chunkX = sensorX(lo:hi);
        chunkY = sensorY(lo:hi);

        % Process all upper thresholds against this chunk
        for ui = 1:numel(upperIdx)
            t = upperIdx(ui);
            mask = chunkY > thresholdValues(t);
            hitsX = chunkX(mask);
            hitsY = chunkY(mask);
            nHits = numel(hitsX);
            if nHits > 0
                bufsX(t, counts(t)+1:counts(t)+nHits) = hitsX;
                bufsY(t, counts(t)+1:counts(t)+nHits) = hitsY;
                counts(t) = counts(t) + nHits;
            end
        end

        % Process all lower thresholds against this chunk
        for li = 1:numel(lowerIdx)
            t = lowerIdx(li);
            mask = chunkY < thresholdValues(t);
            hitsX = chunkX(mask);
            hitsY = chunkY(mask);
            nHits = numel(hitsX);
            if nHits > 0
                bufsX(t, counts(t)+1:counts(t)+nHits) = hitsX;
                bufsY(t, counts(t)+1:counts(t)+nHits) = hitsY;
                counts(t) = counts(t) + nHits;
            end
        end
    end

    % Trim the buffers to the actual number of violations found
    for t = 1:nThresholds
        batchViolX{t} = bufsX(t, 1:counts(t));
        batchViolY{t} = bufsY(t, 1:counts(t));
    end
end
