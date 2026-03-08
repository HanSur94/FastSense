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
    end
    cfg = cachedCfg;
end
