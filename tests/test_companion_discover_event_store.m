function test_companion_discover_event_store()
%TEST_COMPANION_DISCOVER_EVENT_STORE Octave-compatible flat test for companionDiscoverEventStore.
%   Delegates to runDiscoverEventStoreTests which lives inside
%   libs/FastSenseCompanion so that MATLAB's private-directory mechanism
%   makes companionDiscoverEventStore accessible (private functions are
%   visible to callers in the same folder).
%
%   See also companionDiscoverEventStore, runDiscoverEventStoreTests.

    add_companion_path_();
    runDiscoverEventStoreTests();
end

function add_companion_path_()
%ADD_COMPANION_PATH_ Add libs to path.
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();
end
