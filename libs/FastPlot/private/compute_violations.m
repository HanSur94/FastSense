function [xViol, yViol] = compute_violations(x, y, thresholdValue, direction)
%COMPUTE_VIOLATIONS Find data points that strictly violate a threshold.
%   [xViol, yViol] = compute_violations(x, y, thresholdValue, direction)
%
%   Returns the X and Y coordinates of all points where the data exceeds
%   (or falls below) the given threshold value.
%
%   Inputs:
%     x              — numeric vector of X coordinates
%     y              — numeric vector of Y values (same length as x)
%     thresholdValue — scalar threshold
%     direction      — 'upper' (violation when y > threshold)
%                       'lower' (violation when y < threshold)
%
%   Outputs:
%     xViol — X coordinates of violating points
%     yViol — Y coordinates of violating points
%
%   NaN values in y are never flagged as violations (IEEE 754: NaN > x
%   and NaN < x both return false).
%
%   See also FastPlot.addThreshold.

    if strcmp(direction, 'upper')
        mask = y > thresholdValue;
    else
        mask = y < thresholdValue;
    end
    % NaN > x and NaN < x are both false in IEEE 754, so no NaN check needed

    xViol = x(mask);
    yViol = y(mask);
end
