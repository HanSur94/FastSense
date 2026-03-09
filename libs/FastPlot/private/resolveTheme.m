function theme = resolveTheme(val, fallbackName)
%RESOLVETHEME Normalize a theme specification to a complete theme struct.
%   theme = RESOLVETHEME(val, fallbackName) accepts a theme specification
%   in one of several flexible formats and returns a fully populated theme
%   struct suitable for FastPlot rendering.
%
%   This function is a private helper for FastPlot.
%
%   Supported input formats for val:
%     []       — empty: uses FastPlotTheme(fallbackName) to load the named
%                preset specified by fallbackName
%     char     — character vector: treated as a preset name and passed to
%                FastPlotTheme(val) (e.g., 'dark', 'light')
%     struct   — partial struct of theme overrides: passed to
%                FastPlotTheme(val) which merges them onto the base theme
%     other    — any other type is assumed to be a pre-built, complete
%                theme struct and is returned as-is
%
%   Inputs:
%     val          — theme specification (char | struct | [] | pre-built)
%     fallbackName — char, preset name used when val is empty
%
%   Outputs:
%     theme — complete theme struct with all required fields populated,
%             ready for use in FastPlot rendering
%
%   See also FastPlotTheme, mergeTheme, getDefaults.

    if isempty(val)
        % No theme specified — load the fallback preset
        theme = FastPlotTheme(fallbackName);
    elseif ischar(val) || isstruct(val)
        % Preset name or partial overrides — delegate to FastPlotTheme
        theme = FastPlotTheme(val);
    else
        % Pre-built theme object — pass through unchanged
        theme = val;
    end
end
