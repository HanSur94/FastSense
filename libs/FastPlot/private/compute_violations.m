function [xViol, yViol] = compute_violations(x, y, thresholdValue, direction)
%COMPUTE_VIOLATIONS Find data points that strictly violate a threshold.
%   [xViol, yViol] = compute_violations(x, y, thresholdValue, direction)
%
%   direction: 'upper' — violation when y > thresholdValue
%              'lower' — violation when y < thresholdValue
%
%   NaN values in y are never violations (NaN comparisons return false).

    if strcmp(direction, 'upper')
        mask = y > thresholdValue;
    else
        mask = y < thresholdValue;
    end
    % NaN > x and NaN < x are both false in IEEE 754, so no NaN check needed

    xViol = x(mask);
    yViol = y(mask);
end
