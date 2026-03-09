function batchViolIdx = compute_violations_batch(sensorY, segLo, segHi, thresholdValues, directions)
%COMPUTE_VIOLATIONS_BATCH Vectorized batch violation detection.
%   batchViolIdx = compute_violations_batch(sensorY, segLo, segHi, thresholdValues, directions)
%
%   For each threshold, finds indices where sensorY violates the threshold
%   within the given segment ranges [segLo(s), segHi(s)].
%
%   Uses MEX if available, otherwise pure-MATLAB vectorized fallback.
%
%   Inputs:
%     sensorY         — 1xN double, sensor Y data
%     segLo, segHi    — 1xS int, active segment index ranges (1-based)
%     thresholdValues  — 1xT double, threshold values
%     directions       — 1xT logical, true=upper (y > th), false=lower (y < th)
%
%   Output:
%     batchViolIdx    — 1xT cell, each cell contains violation indices

    persistent useMex;
    if isempty(useMex)
        useMex = (exist('compute_violations_mex', 'file') == 3);
    end

    if useMex
        batchViolIdx = compute_violations_mex(sensorY, double(segLo), double(segHi), ...
            double(thresholdValues), double(directions));
        return;
    end

    % Pure-MATLAB vectorized fallback
    nThresholds = numel(thresholdValues);
    nSegs = numel(segLo);
    batchViolIdx = cell(1, nThresholds);

    % Pre-compute total capacity upper bound
    totalPoints = sum(segHi - segLo + 1);

    for t = 1:nThresholds
        thVal = thresholdValues(t);
        isUpper = directions(t);
        idx = zeros(1, totalPoints);
        count = 0;

        for s = 1:nSegs
            lo = segLo(s);
            hi = segHi(s);
            chunk = sensorY(lo:hi);

            if isUpper
                mask = chunk > thVal;
            else
                mask = chunk < thVal;
            end

            hits = find(mask) + lo - 1;
            nHits = numel(hits);
            idx(count+1:count+nHits) = hits;
            count = count + nHits;
        end

        batchViolIdx{t} = idx(1:count);
    end
end
