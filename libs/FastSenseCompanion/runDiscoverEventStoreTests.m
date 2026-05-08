function results = runDiscoverEventStoreTests()
%RUNDISCOVEREVENTRESTORETESTS Execute unit tests for companionDiscoverEventStore.
%   results = runDiscoverEventStoreTests() exercises the private helper
%   companionDiscoverEventStore and returns a struct array, one element per
%   test, with fields:
%     name   — char, test name
%     passed — logical, true if the assertion held
%     msg    — char, failure message (empty when passed)
%
%   This runner lives in libs/FastSenseCompanion/ (same directory as the
%   private/ sub-folder) so that MATLAB's private-directory mechanism makes
%   companionDiscoverEventStore visible.  Tests in TestFastSenseCompanion
%   delegate here via a single call.
%
%   See also companionDiscoverEventStore, TestFastSenseCompanion.

    results = runTest1_emptyRegistry_();
    results(end+1) = runTest2_findsFirstStore_();
    results(end+1) = runTest3_skipsTagsWithoutStore_();
end

% ---------------------------------------------------------------------------

function r = runTest1_emptyRegistry_()
%RUNTEST1_EMPTYREGISTRY_ Empty registry -> [] returned.
    r.name = 'testDiscoverEventStoreReturnsEmptyOnEmptyRegistry';
    r.passed = false;
    r.msg = '';
    TagRegistry.clear();
    try
        store = companionDiscoverEventStore();
        if isempty(store)
            r.passed = true;
        else
            r.msg = 'companionDiscoverEventStore: empty registry must return [].';
        end
    catch e
        r.msg = e.message;
    end
    TagRegistry.clear();
end

function r = runTest2_findsFirstStore_()
%RUNTEST2_FINDSFIRSTSTORE_ MonitorTag with EventStore -> handle returned.
    r.name = 'testDiscoverEventStoreFindsFirstMonitorTagStore';
    r.passed = false;
    r.msg = '';
    TagRegistry.clear();
    try
        parent = SensorTag('p', 'Name', 'P', 'Units', 'u', ...
            'X', [0 1 2], 'Y', [1 2 3]);
        TagRegistry.register('p', parent);

        storePath = [tempname() '.mat'];
        es = EventStore(storePath);

        mon = MonitorTag('m', parent, @(x,y) y > 100, ...
            'EventStore', es);
        TagRegistry.register('m', mon);

        found = companionDiscoverEventStore();
        if ~isempty(found) && found == es
            r.passed = true;
        else
            r.msg = 'companionDiscoverEventStore: must return the MonitorTag''s EventStore.';
        end
    catch e
        r.msg = e.message;
    end
    TagRegistry.clear();
    if exist(storePath, 'file') == 2
        delete(storePath);
    end
end

function r = runTest3_skipsTagsWithoutStore_()
%RUNTEST3_SKIPSTAGSWITHOUSTORE_ MonitorTag without EventStore -> [] returned.
    r.name = 'testDiscoverEventStoreSkipsTagsWithoutStore';
    r.passed = false;
    r.msg = '';
    TagRegistry.clear();
    try
        parent = SensorTag('p', 'Name', 'P', 'Units', 'u', ...
            'X', [0 1 2], 'Y', [1 2 3]);
        TagRegistry.register('p', parent);

        mon = MonitorTag('m', parent, @(x,y) y > 100);   % no EventStore
        TagRegistry.register('m', mon);

        found = companionDiscoverEventStore();
        if isempty(found)
            r.passed = true;
        else
            r.msg = 'companionDiscoverEventStore: must return [] when no monitor has a store.';
        end
    catch e
        r.msg = e.message;
    end
    TagRegistry.clear();
end
