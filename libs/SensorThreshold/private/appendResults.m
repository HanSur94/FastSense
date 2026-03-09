function [resolvedTh, resolvedViol] = appendResults(resolvedTh, resolvedViol, th, viol)
%APPENDRESULTS Append threshold and violation to result arrays.
    if isempty(resolvedTh)
        resolvedTh = th;
        resolvedViol = viol;
    else
        resolvedTh(end+1) = th;
        resolvedViol(end+1) = viol;
    end
end
