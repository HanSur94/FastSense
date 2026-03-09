function cfg = getDefaults()
%GETDEFAULTS Return cached FastPlotDefaults struct.
%   cfg = getDefaults()
%
%   Uses a persistent variable so FastPlotDefaults() is called only once
%   per MATLAB session. This avoids re-parsing the defaults file on every
%   FastPlot construction. Call clearDefaultsCache() to force a reload
%   after editing FastPlotDefaults.m.
%
%   See also FastPlotDefaults, clearDefaultsCache.

    persistent cachedCfg;
    if isempty(cachedCfg)
        cachedCfg = FastPlotDefaults();
        cachedCfg.CustomThemes = loadCustomThemes(cachedCfg);
    end
    cfg = cachedCfg;
end

function themes = loadCustomThemes(cfg)
%LOADCUSTOMTHEMES Scan ThemeDir for .m files, call each, return struct.
    themes = struct();
    if isempty(cfg.ThemeDir)
        return;
    end
    % Resolve relative paths against FastPlot root
    themeDir = cfg.ThemeDir;
    if ~isfolder(themeDir)
        root = fileparts(mfilename('fullpath'));
        % getDefaults lives in private/, go up one level
        root = fileparts(root);
        themeDir = fullfile(root, cfg.ThemeDir);
    end
    if ~isfolder(themeDir)
        return;
    end
    files = dir(fullfile(themeDir, '*.m'));
    for i = 1:numel(files)
        [~, name] = fileparts(files(i).name);
        try
            oldPath = addpath(themeDir);
            restorePath = onCleanup(@() path(oldPath));
            fn = str2func(name);
            t = fn();
            if isstruct(t)
                themes.(name) = t;
            end
        catch
            % skip broken theme files
        end
    end
end
