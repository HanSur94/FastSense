function [xOut, yOut] = violation_cull(x, y, thX, thY, direction, pixelWidth, xmin)
%VIOLATION_CULL Fused violation detection and pixel-density culling.
%   [xOut, yOut] = VIOLATION_CULL(x, y, thX, thY, direction, pixelWidth,
%   xmin) detects threshold violations and immediately culls the results
%   to at most one marker per pixel column, combining the work of
%   compute_violations (or compute_violations_dynamic) and
%   downsample_violations in a single call.
%
%   This function is a private helper for FastSense.
%
%   Inputs:
%     x          — numeric vector of data X coordinates
%     y          — numeric vector of data Y values (same length as x)
%     thX        — numeric vector of threshold knot X positions (sorted).
%                  If scalar, a constant threshold is used. If multi-
%                  element, a piecewise-constant (step-function) threshold
%                  is interpolated.
%     thY        — numeric vector of threshold Y values at each knot
%                  (same length as thX)
%     direction  — char, violation direction:
%                    'upper' — violation when y > threshold
%                    'lower' — violation when y < threshold
%     pixelWidth — positive scalar, X-axis span per pixel
%                  (diff(xlim) / axesWidthInPixels)
%     xmin       — numeric scalar, left edge of the current axis X range,
%                  used as the pixel-column bucket anchor
%
%   Outputs:
%     xOut — 1-by-M row vector of culled violation X coordinates
%     yOut — 1-by-M row vector of culled violation Y values
%            Both are empty 1x0 if no violations exist.
%
%   Algorithm:
%     1. Pre-clean the threshold step-function arrays: strip NaN entries
%        and deduplicate X values (keeping the last Y for each X).
%     2. If a compiled MEX (violation_cull_mex) is available, delegate the
%        entire fused operation for maximum throughput.
%     3. Otherwise, fall back to a two-step MATLAB path:
%        a. Detect violations via compute_violations (constant threshold)
%           or compute_violations_dynamic (step-function threshold).
%        b. Cull the result via downsample_violations to one marker per
%           pixel column, keeping the most extreme deviation per column.
%
%   See also compute_violations, compute_violations_dynamic,
%            downsample_violations, violation_cull_mex.

    % ---- Pre-clean threshold arrays ----
    % Strip NaN entries and deduplicate X (keep last Y for each X), which
    % can occur when thresholds are updated incrementally in live mode.
    if numel(thX) > 1
        valid = ~isnan(thX) & ~isnan(thY);
        thX = thX(valid);
        thY = thY(valid);
        if numel(thX) > 1
            [thX, ia] = unique(thX, 'last');
            thY = thY(ia);
        end
    end

    % Check once whether the compiled MEX is available on this machine
    persistent useMex;
    if isempty(useMex)
        useMex = (exist('violation_cull_mex', 'file') == 3);
    end

    % ---- MEX fast path: fused detection + culling in compiled C ----
    if useMex
        % MEX expects direction as an integer: 1 = upper, 0 = lower
        if strcmp(direction, 'upper')
            dirNum = 1;
        else
            dirNum = 0;
        end
        [xOut, yOut] = violation_cull_mex(x, y, thX, thY, dirNum, pixelWidth, xmin);
        return;
    end

    % ---- MATLAB fallback: two-step detect + downsample ----
    if numel(thX) <= 1
        % Constant threshold (scalar)
        thVal = thY(1);
        [xV, yV] = compute_violations(x, y, thVal, direction);
    else
        % Time-varying (step-function) threshold
        [xV, yV] = compute_violations_dynamic(x, y, thX, thY, direction);
        % Use median threshold value as the reference for deviation ranking
        thVal = median(thY(~isnan(thY)));
    end

    % No violations found — return empty arrays
    if isempty(xV)
        xOut = zeros(1, 0);
        yOut = zeros(1, 0);
        return;
    end

    % Cull to one marker per pixel column
    [xOut, yOut] = downsample_violations(xV, yV, pixelWidth, thVal, xmin);
end
