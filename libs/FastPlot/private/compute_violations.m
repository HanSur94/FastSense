function [xViol, yViol] = compute_violations(x, y, thresholdValue, direction)
%COMPUTE_VIOLATIONS Find data points that strictly violate a constant threshold.
%   [xViol, yViol] = COMPUTE_VIOLATIONS(x, y, thresholdValue, direction)
%   returns the X and Y coordinates of all points where the data strictly
%   exceeds (or falls below) the given scalar threshold value.
%
%   This function is a private helper for FastPlot.
%
%   Inputs:
%     x              — numeric vector of X coordinates
%     y              — numeric vector of Y values (same length as x)
%     thresholdValue — numeric scalar, the constant threshold level
%     direction      — char, violation direction:
%                        'upper' — violation when y > thresholdValue
%                        'lower' — violation when y < thresholdValue
%
%   Outputs:
%     xViol — numeric row/column vector (same orientation as x) of X
%             coordinates at violating points
%     yViol — numeric row/column vector (same orientation as y) of Y
%             values at violating points
%
%   NaN handling:
%     NaN values in y are never flagged as violations. By IEEE 754,
%     NaN > x and NaN < x both evaluate to false, so no explicit NaN
%     check is needed.
%
%   For time-varying (step-function) thresholds, use
%   compute_violations_dynamic instead.
%
%   See also compute_violations_dynamic, downsample_violations,
%            violation_cull, FastPlot.addThreshold.

    % Build logical mask of violating points
    if strcmp(direction, 'upper')
        mask = y > thresholdValue;
    else
        mask = y < thresholdValue;
    end
    % IEEE 754 guarantees: NaN > x == false and NaN < x == false,
    % so NaN entries are automatically excluded from the mask.

    xViol = x(mask);
    yViol = y(mask);
end
