function [xViol, yViol] = compute_violations_dynamic(x, y, thX, thY, direction)
%COMPUTE_VIOLATIONS_DYNAMIC Find violations against a time-varying threshold.
%   [xViol, yViol] = COMPUTE_VIOLATIONS_DYNAMIC(x, y, thX, thY, direction)
%   compares data (x, y) against a piecewise-constant (step-function)
%   threshold defined by the knot vectors (thX, thY). At any data point
%   x(i), the effective threshold is the most recent thY value whose
%   corresponding thX is at or before x(i) — i.e., zero-order hold
%   (previous-value) interpolation.
%
%   This function is a private helper for FastPlot.
%
%   Inputs:
%     x         — numeric vector of data X coordinates
%     y         — numeric vector of data Y values (same length as x)
%     thX       — numeric vector of threshold knot X positions (sorted
%                 ascending). Must not be empty.
%     thY       — numeric vector of threshold Y values at each knot
%                 (same length as thX)
%     direction — char, violation direction:
%                   'upper' — violation when y > interpolated threshold
%                   'lower' — violation when y < interpolated threshold
%
%   Outputs:
%     xViol — numeric vector of X coordinates at violating points
%     yViol — numeric vector of Y values at violating points
%             Both are empty 1x0 if no violations exist.
%
%   Algorithm:
%     1. If thX has a single knot, the threshold is constant everywhere
%        (fast path using repmat).
%     2. Otherwise, MATLAB's interp1 with 'previous' method and 'extrap'
%        is used for zero-order-hold interpolation. Data points before the
%        first knot are explicitly assigned thY(1) because interp1's
%        'previous' extrapolation returns NaN for those.
%     3. The violation mask is applied element-wise; NaN values in y are
%        automatically excluded (IEEE 754: NaN comparisons return false).
%
%   See also compute_violations, downsample_violations, violation_cull,
%            FastPlot.addThreshold.

    % Guard: empty data
    if isempty(x)
        xViol = zeros(1, 0);
        yViol = zeros(1, 0);
        return;
    end

    % Interpolate threshold at each data X (piecewise-constant / ZOH)
    if numel(thX) == 1
        % Single knot — constant threshold everywhere (fast path)
        thAtX = repmat(thY(1), size(x));
    else
        % Zero-order hold: each data point gets the threshold value from
        % the most recent knot at or before its X position
        thAtX = interp1(thX, thY, x, 'previous', 'extrap');

        % interp1 'previous' extrapolation returns NaN for points before
        % the first knot — explicitly assign them the first threshold value
        beforeFirst = x < thX(1);
        thAtX(beforeFirst) = thY(1);
    end

    % Build violation mask (NaN in y automatically excluded by IEEE 754)
    if strcmp(direction, 'upper')
        mask = y > thAtX;
    else
        mask = y < thAtX;
    end

    xViol = x(mask);
    yViol = y(mask);
end
