function aligned = alignStateToTime(stateX, stateY, sensorX)
%ALIGNSTATETOTIME Align state values to sensor timestamps via zero-order hold.
%   aligned = ALIGNSTATETOTIME(stateX, stateY, sensorX) maps each sensor
%   timestamp to the most recent state value, implementing a zero-order
%   hold (a.k.a. sample-and-hold / nearest-previous) interpolation.
%
%   This is the bulk equivalent of StateChannel.valueAt and is used
%   internally to resample an entire state channel onto the sensor's
%   time grid in a single call.
%
%   Three code paths are selected based on the input type:
%     1. Numeric stateY with M > 1: vectorized via interp1('previous').
%     2. Numeric stateY with M == 1: trivial constant fill.
%     3. Cell stateY (char/string): element-wise binary search loop.
%
%   Inputs:
%     stateX  — 1xM double, sorted timestamps of state transitions
%     stateY  — 1xM numeric array or 1xM cell array of char/string,
%               state values at each transition
%     sensorX — 1xN double, sorted sensor timestamps to align to
%
%   Output:
%     aligned — 1xN, same type as stateY; the zero-order-hold value at
%               each sensorX timestamp
%
%   See also StateChannel.valueAt, binary_search.

    n = numel(sensorX);
    isCellY = iscell(stateY);

    % Pre-allocate output with the same type as the input state values
    if isCellY
        aligned = cell(1, n);
    else
        aligned = zeros(1, n);
    end

    m = numel(stateX);

    % --- Path 1: numeric states with multiple transitions ---
    if ~isCellY && m > 1
        % interp1 with 'previous' performs exact zero-order hold
        aligned = interp1(stateX, stateY, sensorX, 'previous', 'extrap');

        % interp1 'previous' + 'extrap' returns NaN for query times that
        % precede the first stateX.  Clamp those to the first state value.
        beforeFirst = sensorX < stateX(1);
        aligned(beforeFirst) = stateY(1);

    % --- Path 2: numeric states with a single transition (constant) ---
    elseif ~isCellY && m == 1
        aligned(:) = stateY(1);

    % --- Path 3: cell/string states -- loop with binary search ---
    else
        for k = 1:n
            idx = binary_search(stateX, sensorX(k), 'right');
            aligned{k} = stateY{idx};
        end
    end
end
