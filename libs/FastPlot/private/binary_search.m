function idx = binary_search(x, val, direction)
%BINARY_SEARCH Find index in sorted array via binary search.
%   idx = BINARY_SEARCH(x, val, 'left') returns the first (leftmost)
%   index where x(idx) >= val (lower bound).
%
%   idx = BINARY_SEARCH(x, val, 'right') returns the last (rightmost)
%   index where x(idx) <= val (upper bound).
%
%   This function is a private helper for FastPlot, used extensively by
%   the downsampling and viewport-clipping routines.
%
%   Inputs:
%     x         — numeric vector, sorted in ascending order. Must not be
%                 empty. Behavior is undefined for unsorted input.
%     val       — numeric scalar, the value to search for
%     direction — char, either 'left' or 'right':
%                   'left'  — find first index i such that x(i) >= val
%                   'right' — find last  index i such that x(i) <= val
%
%   Outputs:
%     idx — integer scalar, index into x. Result is clamped to [1, n]
%           and never returns out-of-bounds:
%             - 'left':  returns n if all elements are < val
%             - 'right': returns 1 if all elements are > val
%
%   Algorithm:
%     Standard iterative binary search with O(log n) comparisons. Each
%     iteration halves the search interval [lo, hi] using floor-midpoint
%     to avoid overflow on large arrays. The 'left' variant records the
%     last position satisfying x(mid) >= val and narrows right; the
%     'right' variant records the last position satisfying x(mid) <= val
%     and narrows left.
%
%   Uses compiled MEX (binary_search_mex) when available for speed;
%   otherwise falls back to this pure MATLAB implementation.
%
%   See also minmax_downsample, lttb_downsample, binary_search_mex.

    % Check once whether the compiled MEX is available on this machine
    persistent useMex;
    if isempty(useMex)
        useMex = (exist('binary_search_mex', 'file') == 3);
    end

    % Fast path: MEX implementation
    if useMex
        idx = binary_search_mex(x, val, direction);
        return;
    end

    % ---- Pure MATLAB fallback ----
    n = numel(x);

    if strcmp(direction, 'left')
        % Lower bound: first index where x(idx) >= val
        lo = 1;
        hi = n;
        idx = n;  % default: if all elements < val, clamp to last index
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) >= val
                idx = mid;       % candidate found — try to find an earlier one
                hi = mid - 1;
            else
                lo = mid + 1;    % too small — search right half
            end
        end
    else
        % Upper bound: last index where x(idx) <= val
        lo = 1;
        hi = n;
        idx = 1;  % default: if all elements > val, clamp to first index
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) <= val
                idx = mid;       % candidate found — try to find a later one
                lo = mid + 1;
            else
                hi = mid - 1;    % too large — search left half
            end
        end
    end
end
