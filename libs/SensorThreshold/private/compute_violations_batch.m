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
%        and applies vectorized comparison within each chunk.
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

    % --- Pure-MATLAB vectorized fallback ---
    nThresholds = numel(thresholdValues);
    nSegs = numel(segLo);
    batchViolIdx = cell(1, nThresholds);

    % Upper-bound buffer size: total data points across all active segments
    totalPoints = sum(segHi - segLo + 1);

    for t = 1:nThresholds
        thVal = thresholdValues(t);
        isUpper = directions(t);

        % Pre-allocate output buffer to the maximum possible size
        idx = zeros(1, totalPoints);
        count = 0;

        for s = 1:nSegs
            lo = segLo(s);
            hi = segHi(s);

            % Extract the segment chunk for vectorized comparison
            chunk = sensorY(lo:hi);

            % Apply direction-dependent threshold comparison
            if isUpper
                mask = chunk > thVal;   % upper violation: value exceeds limit
            else
                mask = chunk < thVal;   % lower violation: value falls below limit
            end

            % Convert local mask indices back to global sensorY indices
            hits = find(mask) + lo - 1;
            nHits = numel(hits);

            % Append hits to the running buffer
            idx(count+1:count+nHits) = hits;
            count = count + nHits;
        end

        % Trim the buffer to the actual number of violations found
        batchViolIdx{t} = idx(1:count);
    end
end
