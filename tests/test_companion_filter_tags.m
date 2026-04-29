function test_companion_filter_tags()
%TEST_COMPANION_FILTER_TAGS Unit tests for filterTags and groupByLabel helpers.
%   Octave-compatible. Exercises pure-logic helpers with no UI dependencies.
%   Delegates to runFilterTagsTests which lives inside libs/FastSenseCompanion
%   so that MATLAB's private-directory mechanism makes filterTags and
%   groupByLabel accessible (private functions are visible to callers in
%   the same folder).
%
%   See also filterTags, groupByLabel, runFilterTagsTests.

    add_companion_path();
    runFilterTagsTests();
end

function add_companion_path()
%ADD_COMPANION_PATH Add libs to path.
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();
end
