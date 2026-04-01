function c = normalizeToCell(x)
%NORMALIZETOCELL Normalize jsondecode output to cell array.
%   C = NORMALIZETOCELL(X) converts struct arrays produced by jsondecode
%   back to cell arrays for consistent {i} indexing. jsondecode converts
%   homogeneous JSON arrays of objects to MATLAB struct arrays; this helper
%   reverses that conversion.
%
%   Input:
%     x  - [] (empty), struct array, or cell array
%
%   Output:
%     c  - cell array (empty {} if x is empty)
%
%   Used by: GroupWidget.fromStruct, DashboardSerializer.loadJSON,
%            and any future phase code that decodes nested JSON arrays.
    if isempty(x)
        c = {};
    elseif isstruct(x)
        c = cell(1, numel(x));
        for k = 1:numel(x)
            c{k} = x(k);
        end
    else
        c = x;
    end
end
