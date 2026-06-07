function c = normalizeToCell_(x)
%NORMALIZETOCELL_ Normalize jsondecode output to cell array (Fleet-private copy).
%   C = NORMALIZETOCELL_(X) converts struct arrays produced by jsondecode
%   back to cell arrays. jsondecode collapses homogeneous JSON arrays of
%   objects to MATLAB struct arrays; this helper reverses that.
%
%   Fleet-local copy because libs/Dashboard/private/ is not callable from
%   libs/Fleet/ due to MATLAB private-scope rules (Pitfall 2 in 1042-RESEARCH.md).
%   Identical logic to libs/Dashboard/private/normalizeToCell.m; update both
%   sites if the normalization logic ever changes.
%
%   Input:
%     x  - [] (empty), struct array, or cell array
%
%   Output:
%     c  - cell array (empty {} if x is empty)
%
%   See also normalizeToCell (libs/Dashboard/private/), Fleet.load.
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
