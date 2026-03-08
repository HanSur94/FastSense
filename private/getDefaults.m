function cfg = getDefaults()
%GETDEFAULTS Return cached FastPlotDefaults struct.
%   Uses a persistent variable so FastPlotDefaults() is called only once
%   per MATLAB session. Call clearDefaultsCache() to force a reload.

    persistent cachedCfg;
    if isempty(cachedCfg)
        cachedCfg = FastPlotDefaults();
    end
    cfg = cachedCfg;
end
