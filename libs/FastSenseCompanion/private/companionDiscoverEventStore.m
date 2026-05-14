function store = companionDiscoverEventStore(sharedRoot, explicitOverride)
%COMPANIONDISCOVEREVENTSTORE Resolve an EventStore for FastSenseCompanion.
%   store = companionDiscoverEventStore()
%   store = companionDiscoverEventStore(sharedRoot)
%   store = companionDiscoverEventStore(sharedRoot, explicitOverride)
%
%   Resolution order (highest precedence first):
%     1. explicitOverride — when non-empty, returned unchanged (constructor
%        'EventStore' NV-pair always wins).
%     2. Registry auto-discovery — first MonitorTag with non-empty EventStore.
%        In cluster mode (sharedRoot non-empty), if the discovered store is
%        already cluster-mode with matching SharedRoot_, return it unchanged.
%     3. Cluster-mode construction — when sharedRoot is non-empty and steps
%        1-2 yielded nothing, construct EventStore('', 'SharedRoot', sharedRoot).
%     4. Otherwise: return [].
%
%   Backward compatibility:
%     Zero-arg calls preserve the original auto-discovery semantics exactly.
%     Single-arg calls with sharedRoot='' also behave as zero-arg.
%
%   Errors from EventStore constructor (e.g. Concurrency:sharedRootUnreachable,
%   Concurrency:identityResolutionFailed on Strict failure) propagate to caller.

    if nargin < 1
        sharedRoot = '';
    end
    if nargin < 2
        explicitOverride = [];
    end

    % 1. Explicit override wins unconditionally.
    if ~isempty(explicitOverride)
        store = explicitOverride;
        return;
    end

    % 2. Registry auto-discovery (preserves existing single-user behaviour).
    store = [];
    allTags = TagRegistry.find(@(t) true);
    if ~isempty(allTags)
        for i = 1:numel(allTags)
            t = allTags{i};
            if isa(t, 'MonitorTag') && ~isempty(t.EventStore)
                candidate = t.EventStore;
                % In cluster mode, accept the discovered store only when its
                % SharedRoot_ matches — otherwise it points at a different
                % cluster root which is a configuration error.
                if ~isempty(sharedRoot)
                    % Read private fields defensively — EventStore's
                    % IsClusterMode_ / SharedRoot_ are Access=private.
                    % accessField_ falls back to [] when blocked.
                    isCm = accessField_(candidate, 'IsClusterMode_');
                    sr   = accessField_(candidate, 'SharedRoot_');
                    if ~isequal(true, isCm) || ...
                            ~strcmp(char(sr), char(sharedRoot))
                        % Discovered store belongs to a different mode/root.
                        % Discard and fall through to construction below.
                        store = [];
                        break;
                    end
                end
                store = candidate;
                return;
            end
        end
    end

    % 3. Cluster-mode construction when sharedRoot is set and steps 1-2 failed.
    if isempty(store) && ~isempty(sharedRoot)
        store = EventStore('', 'SharedRoot', sharedRoot);
    end
end

function v = accessField_(obj, name)
%ACCESSFIELD_ Best-effort private-property accessor used only for
%   cluster-discovery validation. EventStore's IsClusterMode_/SharedRoot_
%   are declared Access=private; MATLAB blocks external reads. This helper
%   falls back to [] on any access error. The caller treats [] / mismatch as
%   "discard discovery and fall through to fresh cluster construction".
    v = [];
    try
        v = obj.(name);
    catch
        % Private field — discard discovery and fall through to construction.
    end
end
