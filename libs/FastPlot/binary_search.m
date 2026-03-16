function idx = binary_search(x, val, direction)
%BINARY_SEARCH Find an index in a sorted array via binary search.
%   idx = BINARY_SEARCH(x, val, 'left') returns the first (leftmost)
%   index where x(idx) >= val. If every element is less than val, idx
%   equals numel(x).
%
%   idx = BINARY_SEARCH(x, val, 'right') returns the last (rightmost)
%   index where x(idx) <= val. If every element is greater than val,
%   idx equals 1.
%
%   The result is always clamped to [1, numel(x)], so it never returns
%   an out-of-bounds index.
%
%   A compiled MEX implementation (binary_search_mex) is used when
%   available on the MATLAB path; otherwise a pure-MATLAB fallback
%   executes. The MEX availability check is performed once per session
%   and cached in a persistent variable.
%
%   Inputs:
%     x         — 1-D numeric array, sorted in ascending order. The
%                 caller is responsible for ensuring the array is sorted;
%                 unsorted input produces undefined results.
%     val       — numeric scalar; the value to search for
%     direction — char; 'left' for lower-bound search (first index
%                 where x >= val) or 'right' for upper-bound search
%                 (last index where x <= val)
%
%   Output:
%     idx — positive integer scalar; the found index in the range
%           [1, numel(x)]
%
%   Algorithm:
%     Standard iterative binary search with O(log n) time complexity
%     and O(1) auxiliary space.
%
%   Example:
%     x = [1 3 5 7 9 11];
%     binary_search(x, 6, 'left')    % returns 4 (x(4) = 7 >= 6)
%     binary_search(x, 6, 'right')   % returns 3 (x(3) = 5 <= 6)
%
%   See also binary_search_mex, build_mex.

    % Check once per session whether the compiled MEX is on the path
    persistent useMex;
    if isempty(useMex)
        useMex = (exist('binary_search_mex', 'file') == 3);
    end

    % Delegate to MEX for speed when available
    if useMex
        idx = binary_search_mex(x, val, char(direction));
        return;
    end

    % --- Pure-MATLAB fallback (iterative binary search) ---
    n = numel(x);

    if strcmp(direction, 'left')
        % Lower-bound search: find first index where x(idx) >= val.
        % Invariant: the answer is always in [lo, hi] or idx retains
        % the last candidate found.
        lo = 1;
        hi = n;
        idx = n; % safe default: rightmost position if all elements < val
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) >= val
                idx = mid;       % mid is a candidate; try to find earlier one
                hi = mid - 1;
            else
                lo = mid + 1;    % mid is too small; search right half
            end
        end
    else
        % Upper-bound search: find last index where x(idx) <= val.
        lo = 1;
        hi = n;
        idx = 1; % safe default: leftmost position if all elements > val
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) <= val
                idx = mid;       % mid is a candidate; try to find later one
                lo = mid + 1;
            else
                hi = mid - 1;    % mid is too large; search left half
            end
        end
    end
end
