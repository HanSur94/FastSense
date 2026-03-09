function [xViol, yViol] = compute_violations_dynamic(x, y, thX, thY, direction)
%COMPUTE_VIOLATIONS_DYNAMIC Find violations against a time-varying threshold.
%   [xViol, yViol] = compute_violations_dynamic(x, y, thX, thY, direction)
%
%   Compares data (x,y) against a piecewise-constant (step function)
%   threshold defined by (thX, thY). The threshold value at any point
%   is the most recent thY value at or before that X coordinate.
%
%   Inputs:
%     x, y       — data coordinates
%     thX, thY   — threshold step-function knots (must be sorted)
%     direction  — 'upper' (violation when y > threshold)
%                   'lower' (violation when y < threshold)
%
%   See also compute_violations, FastPlot.addThreshold.

    if isempty(x)
        xViol = zeros(1, 0);
        yViol = zeros(1, 0);
        return;
    end

    % Interpolate threshold at each data X (piecewise-constant, hold previous)
    if numel(thX) == 1
        % Single knot — constant threshold everywhere
        thAtX = repmat(thY(1), size(x));
    else
        thAtX = interp1(thX, thY, x, 'previous', 'extrap');
        % Handle points before the first threshold knot
        beforeFirst = x < thX(1);
        thAtX(beforeFirst) = thY(1);
    end

    if strcmp(direction, 'upper')
        mask = y > thAtX;
    else
        mask = y < thAtX;
    end
    % NaN > x and NaN < x are both false in IEEE 754

    xViol = x(mask);
    yViol = y(mask);
end
