function test_compare_resolution()
%TEST_COMPARE_RESOLUTION Flat Octave-safe tests for the cross-machine resolution foundation.
%   Covers CanonicalMapper.resolve, Fleet.mapper, buildCompareResolution_ (2- and
%   3-arg forms), and compareSeriesColor_ (CMP-02/03/04 + the CMP-05 resolve seam).
%
%   Delegates to runCompareResolutionTests which lives inside
%   libs/FastSenseCompanion so that MATLAB's private-directory mechanism makes
%   the private helpers buildCompareResolution_ and compareSeriesColor_
%   accessible (private functions are visible to callers in the same folder).
%   Pure logic — no uifigure — so it runs on both MATLAB and Octave.
%
%   See also runCompareResolutionTests, buildCompareResolution_, compareSeriesColor_,
%            CanonicalMapper, Fleet.

    add_companion_path();
    runCompareResolutionTests();
end

function add_companion_path()
%ADD_COMPANION_PATH Add libs to path so the runner + helpers are visible.
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();
end
