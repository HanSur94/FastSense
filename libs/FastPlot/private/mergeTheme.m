function result = mergeTheme(base, overrides)
%MERGETHEME Merge theme overrides into a base theme struct.
%   result = mergeTheme(base, overrides)
%
%   Copies all fields from overrides into base, replacing any existing
%   values. Fields in base that are not in overrides remain unchanged.
%
%   Inputs:
%     base      — complete theme struct (all fields present)
%     overrides — partial struct with fields to replace
%
%   Output:
%     result — merged theme struct
%
%   See also FastPlotTheme, resolveTheme.

    result = base;
    fnames = fieldnames(overrides);
    for i = 1:numel(fnames)
        result.(fnames{i}) = overrides.(fnames{i});
    end
end
