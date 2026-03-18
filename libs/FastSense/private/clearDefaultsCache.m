function clearDefaultsCache()
%CLEARDEFAULTSCACHE Force getDefaults to reload FastSenseDefaults on next call.
%   CLEARDEFAULTSCACHE() invalidates the persistent cache held by
%   getDefaults() so that the next call to getDefaults() re-executes
%   FastSenseDefaults() and rebuilds the configuration from scratch.
%
%   This function is a private helper for FastSense.
%
%   Use this after editing FastSenseDefaults.m or any custom theme file
%   during a MATLAB session, so that subsequent FastSense constructions
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
%   See also getDefaults, FastSenseDefaults.

    % Clear the persistent variable inside getDefaults
    clear getDefaults;
end
