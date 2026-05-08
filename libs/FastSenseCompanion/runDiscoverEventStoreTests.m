function runDiscoverEventStoreTests()
%RUNDISCOVEREVENTSTORETESTS Execute unit tests for companionDiscoverEventStore.
%   Called by tests/test_companion_discover_event_store.m.  Lives here
%   (inside libs/FastSenseCompanion) so that MATLAB's private-directory
%   mechanism makes companionDiscoverEventStore visible (private functions
%   are accessible to callers in the same folder).
%
%   See also companionDiscoverEventStore, TestFastSenseCompanion.

    nPassed = 0;

    % --- Test 1: empty registry -> [] returned ---
    TagRegistry.clear();
    store = companionDiscoverEventStore();
    assert(isempty(store), ...
        'Test 1: companionDiscoverEventStore must return [] for an empty registry.');
    TagRegistry.clear();
    nPassed = nPassed + 1;

    % --- Test 2: MonitorTag with EventStore -> handle returned ---
    storePath = '';
    TagRegistry.clear();
    try
        parent = SensorTag('p', 'Name', 'P', 'Units', 'u', ...
            'X', [0 1 2], 'Y', [1 2 3]);
        TagRegistry.register('p', parent);

        storePath = [tempname() '.mat'];
        es = EventStore(storePath);

        mon = MonitorTag('m', parent, @(x, y) y > 100, ...
            'EventStore', es);
        TagRegistry.register('m', mon);

        found = companionDiscoverEventStore();
        % Portable handle-identity check: MATLAB auto-defines == on handle
        % classes but Octave doesn't (errors with "eq method not defined").
        % Mutate a property on `es` and confirm the same change is visible
        % through `found` — proves both references point at the same object
        % without relying on overloaded operators.
        es.MaxBackups = 1337;
        assert(~isempty(found) && isa(found, 'EventStore') && ...
            found.MaxBackups == 1337, ...
            'Test 2: companionDiscoverEventStore must return the MonitorTag''s EventStore.');
    catch e
        TagRegistry.clear();
        if exist(storePath, 'file') == 2
            delete(storePath);
        end
        rethrow(e);
    end
    TagRegistry.clear();
    if exist(storePath, 'file') == 2
        delete(storePath);
    end
    nPassed = nPassed + 1;

    % --- Test 3: MonitorTag without EventStore -> [] returned ---
    TagRegistry.clear();
    parent = SensorTag('p', 'Name', 'P', 'Units', 'u', ...
        'X', [0 1 2], 'Y', [1 2 3]);
    TagRegistry.register('p', parent);

    mon = MonitorTag('m', parent, @(x, y) y > 100);   % no EventStore
    TagRegistry.register('m', mon);

    found = companionDiscoverEventStore();
    assert(isempty(found), ...
        'Test 3: companionDiscoverEventStore must return [] when no monitor has a store.');
    TagRegistry.clear();
    nPassed = nPassed + 1;

    fprintf('    All %d tests passed.\n', nPassed);
end
