function clearDefaultsCache()
%CLEARDEFAULTSCACHE Force getDefaults to reload FastPlotDefaults on next call.
%   Use after editing FastPlotDefaults.m during a session.

    clear getDefaults;
end
