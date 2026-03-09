function [resolvedTh, resolvedViol] = appendResults(resolvedTh, resolvedViol, th, viol)
%APPENDRESULTS Append a threshold entry and its companion violation entry to result arrays.
%   [resolvedTh, resolvedViol] = APPENDRESULTS(resolvedTh, resolvedViol, th, viol)
%   grows the struct arrays resolvedTh and resolvedViol by one element
%   each.  On the first call (when the arrays are empty), the input
%   structs seed the arrays; subsequent calls append via index extension.
%
%   This helper centralizes the struct-array growth pattern used
%   repeatedly during Sensor.resolve() and mergeResolvedByLabel().
%
%   Inputs:
%     resolvedTh   — struct array (or []) of accumulated threshold entries
%     resolvedViol — struct array (or []) of accumulated violation entries
%     th           — scalar struct, new threshold entry to append
%     viol         — scalar struct, new violation entry to append
%
%   Outputs:
%     resolvedTh   — updated struct array with th appended
%     resolvedViol — updated struct array with viol appended
%
%   See also Sensor.resolve, buildThresholdEntry, mergeResolvedByLabel.

    if isempty(resolvedTh)
        % Seed the struct arrays with the first entries
        resolvedTh = th;
        resolvedViol = viol;
    else
        % Append to existing struct arrays
        resolvedTh(end+1) = th;
        resolvedViol(end+1) = viol;
    end
end
