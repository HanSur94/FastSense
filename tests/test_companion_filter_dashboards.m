function test_companion_filter_dashboards()
%TEST_COMPANION_FILTER_DASHBOARDS Unit tests for filterDashboards helper.
%   Octave-compatible. Exercises pure-logic helper with no UI dependencies.
%   Delegates to runFilterDashboardsTests which lives inside libs/FastSenseCompanion/private/
%   so that MATLAB's private-directory mechanism makes filterDashboards accessible
%   (private functions are visible to callers in the same folder).
%
%   See also filterDashboards, runFilterDashboardsTests.

    add_companion_path();
    runFilterDashboardsTests();
end

function add_companion_path()
%ADD_COMPANION_PATH Add libs to path.
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();
end
