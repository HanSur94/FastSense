function result = mergeTheme(base, overrides)
%MERGETHEME Merge theme overrides into a base theme struct.
%   result = MERGETHEME(base, overrides) copies every field from overrides
%   into base, replacing existing values where field names collide. Fields
%   in base that do not appear in overrides are preserved unchanged. This
%   is a shallow (non-recursive) merge — nested structs are replaced
%   wholesale, not recursively merged.
%
%   This function is a private helper for FastSense.
%
%   Inputs:
%     base      — scalar struct, the complete theme with all fields present
%                 (typically produced by FastSenseTheme)
%     overrides — scalar struct, partial set of fields whose values should
%                 replace those in base. May contain any subset of fields
%                 from base, or even new fields.
%
%   Outputs:
%     result — scalar struct with the same fields as base, updated with
%              the values from overrides
%
%   Example:
%     base.Color = 'k'; base.FontSize = 12; base.Grid = true;
%     ov.Color = 'w';
%     result = mergeTheme(base, ov);
%     % result.Color == 'w', result.FontSize == 12, result.Grid == true
%
%   See also FastSenseTheme, resolveTheme, getDefaults.

    result = base;
    fnames = fieldnames(overrides);
    for i = 1:numel(fnames)
        % Overwrite the base value with the override value
        result.(fnames{i}) = overrides.(fnames{i});
    end
end
