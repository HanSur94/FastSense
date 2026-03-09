function theme = resolveTheme(val, fallbackName)
%RESOLVETHEME Normalize a theme specification to a complete theme struct.
%   theme = resolveTheme(val, fallbackName)
%
%   Handles multiple input formats for flexible theme specification:
%     []       — uses FastPlotTheme(fallbackName)
%     char     — treated as preset name: FastPlotTheme(val)
%     struct   — treated as overrides: FastPlotTheme(val)
%     other    — assumed to be a pre-built theme struct, returned as-is
%
%   Inputs:
%     val          — theme spec (char | struct | [] | pre-built)
%     fallbackName — preset name used when val is empty
%
%   Output:
%     theme — complete theme struct ready for use
%
%   See also FastPlotTheme, mergeTheme.

    if isempty(val)
        theme = FastPlotTheme(fallbackName);
    elseif ischar(val) || isstruct(val)
        theme = FastPlotTheme(val);
    else
        theme = val;
    end
end
