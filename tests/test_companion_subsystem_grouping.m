function test_companion_subsystem_grouping()
%TEST_COMPANION_SUBSYSTEM_GROUPING Regression tests for subsystem-aware tag grouping.
%   Verifies the fix for event-viewer-tag-grouping:
%     (a) SensorTag/StateTag/MonitorTag/CompositeTag are grouped by Labels{1}
%         (the classification field); empty Labels -> 'Ungrouped'.
%     (b) Case variants (FeedLine/Feedline) merge into exactly one group via
%         the case-insensitive merge pass in filterTags/groupByLabel.
%
%   Octave-compatible. Exercises pure-logic helpers with no UI dependencies.
%   Delegates to runFilterTagsTests which lives inside libs/FastSenseCompanion
%   so that MATLAB's private-directory mechanism makes filterTags and
%   groupByLabel accessible (private functions are visible to callers in
%   the same folder).
%
%   The full regression set is embedded in runFilterTagsTests (Tests 17-19).
%   This file is a convenience entry point matching the tests/ naming convention.
%
%   See also filterTags, groupByLabel, runFilterTagsTests.

    add_companion_path_();
    runFilterTagsTests();
end

function add_companion_path_()
%ADD_COMPANION_PATH_ Add project libs to MATLAB path.
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();
end
