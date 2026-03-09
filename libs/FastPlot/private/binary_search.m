function idx = binary_search(x, val, direction)
%BINARY_SEARCH Find index in sorted array via binary search.
%   idx = binary_search(x, val, 'left')
%   idx = binary_search(x, val, 'right')
%
%   For 'left': returns the first index where x(idx) >= val.
%   For 'right': returns the last index where x(idx) <= val.
%
%   Result is clamped to [1, numel(x)] — never returns out-of-bounds.
%   Uses compiled MEX (binary_search_mex) when available for speed,
%   otherwise falls back to pure MATLAB implementation.
%
%   Inputs:
%     x         — sorted numeric vector (ascending)
%     val       — scalar value to search for
%     direction — 'left' or 'right'
%
%   Output:
%     idx — integer index into x
%
%   See also minmax_downsample, lttb_downsample.

    persistent useMex;
    if isempty(useMex)
        useMex = (exist('binary_search_mex', 'file') == 3);
    end

    if useMex
        idx = binary_search_mex(x, val, direction);
        return;
    end

    n = numel(x);

    if strcmp(direction, 'left')
        % Find first index where x(idx) >= val
        lo = 1;
        hi = n;
        idx = n; % default if all < val
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) >= val
                idx = mid;
                hi = mid - 1;
            else
                lo = mid + 1;
            end
        end
    else
        % Find last index where x(idx) <= val
        lo = 1;
        hi = n;
        idx = 1; % default if all > val
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) <= val
                idx = mid;
                lo = mid + 1;
            else
                hi = mid - 1;
            end
        end
    end
end
