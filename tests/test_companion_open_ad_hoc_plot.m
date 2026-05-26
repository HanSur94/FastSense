function test_companion_open_ad_hoc_plot()
%TEST_COMPANION_OPEN_AD_HOC_PLOT Unit tests for openAdHocPlot helper.
%   MATLAB-only (helper calls FastSense which depends on MEX). Skipped on Octave.
%   Delegates to runOpenAdHocPlotTests inside libs/FastSenseCompanion/private/
%   per MATLAB's private-folder visibility rules.
%
%   See also openAdHocPlot, runOpenAdHocPlotTests, MockPlottableTag.

    if exist('OCTAVE_VERSION', 'builtin') ~= 0
        fprintf('  Skipping test_companion_open_ad_hoc_plot on Octave.\n');
        return;
    end
    add_companion_path();
    runOpenAdHocPlotTests();
end

function add_companion_path()
%ADD_COMPANION_PATH Add libs and tests/suite to path.
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), 'suite'));
    install();
end
