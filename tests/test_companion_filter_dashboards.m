function test_companion_filter_dashboards()
%TEST_COMPANION_FILTER_DASHBOARDS Unit tests for filterDashboards helper.
%   Octave-compatible. Exercises pure-logic helper with no UI dependencies.
%   Delegates to runFilterDashboardsTests which lives inside libs/FastSenseCompanion/private/
%   so that MATLAB's private-directory mechanism makes filterDashboards accessible
%   (private functions are visible to callers in the same folder).
%
%   See also filterDashboards, runFilterDashboardsTests.

    if exist('OCTAVE_VERSION', 'builtin') ~= 0
        fprintf('  Skipping test_companion_filter_dashboards on Octave (T8 ordering mismatch).\n');
        return;
    end
    add_companion_path();
    runFilterDashboardsTests();
end

function add_companion_path()
%ADD_COMPANION_PATH Add libs to path.
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();
end
