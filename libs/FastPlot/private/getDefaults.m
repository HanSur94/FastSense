function cfg = getDefaults()
%GETDEFAULTS Return cached FastPlotDefaults struct.
%   cfg = GETDEFAULTS() returns the FastPlot configuration struct produced
%   by FastPlotDefaults(). The result is cached in a persistent variable so
%   that FastPlotDefaults() is called only once per MATLAB session, avoiding
%   repeated file parsing on every FastPlot construction.
%
%   This function is a private helper for FastPlot.
%
%   On the first call the cache is populated by:
%     1. Calling FastPlotDefaults() to obtain the base configuration.
%     2. Calling loadCustomThemes() to scan cfg.ThemeDir for user themes.
%
%   Inputs:
%     (none)
%
%   Outputs:
%     cfg — scalar struct of FastPlot default settings, including a
%           CustomThemes field populated from the user's theme directory
%
%   Call clearDefaultsCache() to invalidate the cache and force a fresh
%   reload on the next invocation (e.g., after editing FastPlotDefaults.m).
%
%   See also FastPlotDefaults, clearDefaultsCache, loadCustomThemes.

    persistent cachedCfg;
    if isempty(cachedCfg)
        % First call: build and cache the configuration
        cachedCfg = FastPlotDefaults();
        cachedCfg.CustomThemes = loadCustomThemes(cachedCfg);
    end
    cfg = cachedCfg;
end

function themes = loadCustomThemes(cfg)
%LOADCUSTOMTHEMES Scan ThemeDir for .m theme files and collect results.
%   themes = LOADCUSTOMTHEMES(cfg) discovers all .m files in the directory
%   specified by cfg.ThemeDir, executes each as a function, and stores the
%   returned struct under a field named after the file (without extension).
%
%   This function is a local helper for getDefaults.
%
%   Inputs:
%     cfg — FastPlotDefaults struct (must contain field ThemeDir)
%
%   Outputs:
%     themes — struct whose field names are theme file basenames and whose
%              values are the theme structs returned by those files.
%              Returns struct() (empty) if ThemeDir is unset or not found.
%
%   Path resolution:
%     If cfg.ThemeDir is not an absolute folder, it is resolved relative to
%     the FastPlot library root (one level above this private/ directory).
%
%   Error handling:
%     Broken or non-struct-returning theme files are silently skipped.
%
%   See also getDefaults, resolveTheme, mergeTheme.

    themes = struct();

    % Early return if no theme directory is configured
    if isempty(cfg.ThemeDir)
        return;
    end

    % Resolve relative paths against FastPlot root
    themeDir = cfg.ThemeDir;
    if ~isfolder(themeDir)
        root = fileparts(mfilename('fullpath'));
        % getDefaults lives in private/, go up one level to the lib root
        root = fileparts(root);
        themeDir = fullfile(root, cfg.ThemeDir);
    end

    % Bail out if the resolved directory still does not exist
    if ~isfolder(themeDir)
        return;
    end

    files = dir(fullfile(themeDir, '*.m'));
    for i = 1:numel(files)
        [~, name] = fileparts(files(i).name);
        try
            % Temporarily add theme dir to the path so str2func can find it
            oldPath = addpath(themeDir);
            restorePath = onCleanup(@() path(oldPath));

            % Execute the theme file as a zero-argument function
            fn = str2func(name);
            t = fn();

            % Only accept struct outputs; ignore scripts or invalid returns
            if isstruct(t)
                themes.(name) = t;
            end
        catch
            % Skip broken theme files silently
        end
    end
end
