function batchViolIdx = compute_violations_batch(sensorY, segLo, segHi, thresholdValues, directions)
%COMPUTE_VIOLATIONS_BATCH Vectorized batch violation detection across segments.
%   batchViolIdx = COMPUTE_VIOLATIONS_BATCH(sensorY, segLo, segHi,
%       thresholdValues, directions) identifies the indices of sensorY
%   that violate each threshold within the specified active segment
%   ranges.  This is the inner computational kernel of Sensor.resolve().
%
%   Two code paths are available:
%     1. MEX path (not yet wired up): delegates to compute_violations_mex
%        for maximum throughput on large datasets.
%     2. Pure-MATLAB fallback (current default): iterates over segments
%        once and checks all thresholds per chunk (single-pass over data).
%
%   The MATLAB fallback pre-allocates a buffer sized to the total number
%   of points across all active segments (upper bound), then fills it
%   with a running count to avoid repeated dynamic array growth.
%
%   Inputs:
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
%   Output:
%     batchViolIdx — 1xT cell array; batchViolIdx{t} is a 1xK integer
%                    vector of 1-based indices into sensorY where the
%                    t-th threshold is violated
%
%   See also Sensor.resolve, binary_search.

    % --- MEX availability flag (cached across calls) ---
    persistent useMex;
    if isempty(useMex)
        useMex = false;  % TODO: wire up violation_cull_mex for batch path
    end

    % --- MEX fast path ---
    if useMex
        batchViolIdx = compute_violations_mex(sensorY, double(segLo), double(segHi), ...
            double(thresholdValues), double(directions));
        return;
    end

    % --- Pure-MATLAB single-pass fallback ---
    % Instead of iterating (nThresholds * nSegs), iterate over segments
    % once and check all thresholds per chunk.  This is faster because
    % each chunk is extracted from sensorY only once.
    nThresholds = numel(thresholdValues);
    nSegs = numel(segLo);
    batchViolIdx = cell(1, nThresholds);

    % Upper-bound buffer size: total data points across all active segments
    totalPoints = sum(segHi - segLo + 1);

    % Pre-allocate output buffers for all thresholds at once
    buffers = zeros(nThresholds, totalPoints);
    counts = zeros(1, nThresholds);

    % Separate upper and lower thresholds for vectorized comparison
    upperMask = logical(directions);
    lowerMask = ~upperMask;
    upperIdx = find(upperMask);
    lowerIdx = find(lowerMask);

    for s = 1:nSegs
        lo = segLo(s);
        hi = segHi(s);

        % Extract the segment chunk once for all thresholds
        chunk = sensorY(lo:hi);
        chunkLen = hi - lo + 1;
        globalIdx = lo:hi;

        % Process all upper thresholds against this chunk
        for ui = 1:numel(upperIdx)
            t = upperIdx(ui);
            mask = chunk > thresholdValues(t);
            hits = globalIdx(mask);
            nHits = numel(hits);
            if nHits > 0
                buffers(t, counts(t)+1:counts(t)+nHits) = hits;
                counts(t) = counts(t) + nHits;
            end
        end

        % Process all lower thresholds against this chunk
        for li = 1:numel(lowerIdx)
            t = lowerIdx(li);
            mask = chunk < thresholdValues(t);
            hits = globalIdx(mask);
            nHits = numel(hits);
            if nHits > 0
                buffers(t, counts(t)+1:counts(t)+nHits) = hits;
                counts(t) = counts(t) + nHits;
            end
        end
    end

    % Trim the buffers to the actual number of violations found
    for t = 1:nThresholds
        batchViolIdx{t} = buffers(t, 1:counts(t));
    end
end
