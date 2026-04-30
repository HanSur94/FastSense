function test_companion_inspector_resolve_state()
%TEST_COMPANION_INSPECTOR_RESOLVE_STATE Unit tests for inspectorResolveState helper.
%   Octave-compatible. Exercises pure-logic helper plus event payload classes.
%   Delegates to runInspectorResolveStateTests which lives inside libs/FastSenseCompanion/private/
%   so that MATLAB's private-directory mechanism makes inspectorResolveState accessible.
%
%   See also inspectorResolveState, InspectorStateEventData, AdHocPlotEventData.

    add_companion_path();
    runInspectorResolveStateTests();
end

function add_companion_path()
%ADD_COMPANION_PATH Add libs to path.
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();
end
