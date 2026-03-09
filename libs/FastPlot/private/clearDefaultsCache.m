function clearDefaultsCache()
%CLEARDEFAULTSCACHE Force getDefaults to reload FastPlotDefaults on next call.
%   CLEARDEFAULTSCACHE() invalidates the persistent cache held by
%   getDefaults() so that the next call to getDefaults() re-executes
%   FastPlotDefaults() and rebuilds the configuration from scratch.
%
%   This function is a private helper for FastPlot.
%
%   Use this after editing FastPlotDefaults.m or any custom theme file
%   during a MATLAB session, so that subsequent FastPlot constructions
%   pick up the new settings without restarting MATLAB.
%
%   Inputs:
%     (none)
%
%   Outputs:
%     (none — side effect only)
%
%   Implementation note:
%     CLEAR <functionName> clears the persistent variables inside that
%     function, effectively resetting its cached state.
%
%   See also getDefaults, FastPlotDefaults.

    % Clear the persistent variable inside getDefaults
    clear getDefaults;
end
