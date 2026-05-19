function store = companionDiscoverEventStore()
%COMPANIONDISCOVEREVENTSTORE Walk TagRegistry for the first MonitorTag with a non-empty EventStore.
%   store = companionDiscoverEventStore() returns the EventStore handle of
%   the first MonitorTag in the global TagRegistry whose EventStore
%   property is non-empty. Returns [] if the registry is empty or no such
%   MonitorTag exists.
%
%   This is the auto-discovery path for FastSenseCompanion's EventStore
%   wiring. Explicit 'EventStore' constructor option always wins over
%   discovery; this helper is invoked only when no override is supplied.
%
%   Iteration order matches TagRegistry.find() — for the industrial plant
%   demo this is the registration order, which means the first registered
%   MonitorTag wins (all share ctx.store, so any of them is correct).

    store = [];
    allTags = TagRegistry.find(@(t) true);
    if isempty(allTags); return; end
    for i = 1:numel(allTags)
        t = allTags{i};
        if isa(t, 'MonitorTag') && ~isempty(t.EventStore)
            store = t.EventStore;
            return;
        end
    end
end
