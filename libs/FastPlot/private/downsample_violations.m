function [xOut, yOut] = downsample_violations(xViol, yViol, pixelWidth, thresholdValue, xmin)
%DOWNSAMPLE_VIOLATIONS Cull violation markers to at most one per pixel column.
%   [xOut, yOut] = DOWNSAMPLE_VIOLATIONS(xViol, yViol, pixelWidth,
%   thresholdValue, xmin) bins violation points into pixel-width columns
%   and keeps only the point with the maximum absolute deviation from the
%   threshold in each column. This preserves the visually most extreme
%   violations while eliminating sub-pixel overlap that would waste GPU
%   marker-rendering budget.
%
%   This function is a private helper for FastPlot.
%
%   Inputs:
%     xViol          — numeric vector of violation X coordinates (from
%                      compute_violations or compute_violations_dynamic)
%     yViol          — numeric vector of violation Y values (same length)
%     pixelWidth     — positive scalar, X-axis span per pixel, computed as
%                      diff(xlim) / axesWidthInPixels
%     thresholdValue — numeric scalar, the threshold level. Used to
%                      compute |y - threshold| for selecting the most
%                      extreme point per pixel column.
%     xmin           — numeric scalar, left edge of the current axis X
%                      range, used as the anchor (origin) for pixel-column
%                      bucket assignment
%
%   Outputs:
%     xOut — 1-by-M row vector of culled violation X coordinates (one per
%            occupied pixel column, M <= numel(xViol))
%     yOut — 1-by-M row vector of culled violation Y values
%
%   Algorithm:
%     1. Strip NaN entries (segment separators) from the input.
%     2. Assign each point to a pixel-column bucket:
%          bucket = floor((x - xmin) / pixelWidth)
%     3. For each unique bucket, keep the point with max |y - threshold|.
%
%   See also compute_violations, compute_violations_dynamic, violation_cull,
%            FastPlot.updateViolations.

    % Guard: empty input or degenerate pixel width
    if isempty(xViol) || pixelWidth <= 0
        xOut = xViol(:)';
        yOut = yViol(:)';
        return;
    end

    % Remove NaN entries (used as segment separators) before binning
    nanMask = isnan(xViol) | isnan(yViol);
    xClean = xViol(~nanMask);
    yClean = yViol(~nanMask);

    if isempty(xClean)
        xOut = zeros(1, 0);
        yOut = zeros(1, 0);
        return;
    end

    % Assign each point to a pixel-column bucket anchored at the view's
    % left edge, so bucket boundaries align with on-screen pixel columns
    buckets = floor((xClean - xmin) / pixelWidth);

    % Identify unique pixel columns and map each point to its column
    [uBuckets, ~, ic] = unique(buckets); %#ok<ASGLU> uBuckets unused
    nBuckets = numel(uBuckets);
    xOut = zeros(1, nBuckets);
    yOut = zeros(1, nBuckets);

    % For each pixel column, keep the point with the largest deviation
    % from the threshold — this is the most visually significant violation
    deviation = abs(yClean - thresholdValue);
    for b = 1:nBuckets
        mask = (ic == b);
        devs = deviation(mask);
        [~, bestIdx] = max(devs);
        bx = xClean(mask);
        by = yClean(mask);
        xOut(b) = bx(bestIdx);
        yOut(b) = by(bestIdx);
    end
end
