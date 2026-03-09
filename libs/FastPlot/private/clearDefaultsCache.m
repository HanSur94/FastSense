function clearDefaultsCache()
%CLEARDEFAULTSCACHE Force getDefaults to reload FastPlotDefaults on next call.
%   clearDefaultsCache()
%
%   Clears the persistent variable in getDefaults(), so the next call
%   re-executes FastPlotDefaults(). Use this after editing
%   FastPlotDefaults.m during a MATLAB session.
%
%   See also getDefaults, FastPlotDefaults.

    clear getDefaults;
end
