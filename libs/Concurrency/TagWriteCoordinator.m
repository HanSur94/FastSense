classdef TagWriteCoordinator < handle
%TAGWRITECOORDINATOR Per-tag-key FileLock facade for the v4.0 cluster-mode write path.
%
%   Wraps libs/Concurrency/FileLock so the caller passes only a tag key — the
%   facade derives the lockfile path under <sharedRoot>/locks/<tagKey>.lock.
%   The single seam consumed by LiveTagPipeline.processTag_ in cluster mode.
%
%   Per ARCHITECTURE.md §Q2: the lock is taken in the pipeline (processTag_),
%   not inside the Tag itself, because the Tag is a domain object and the
%   coordinator is a deployment-mode concern.
%
%   Usage:
%       coord = TagWriteCoordinator('/mnt/shared/fastsense');
%       [lock, ok] = coord.acquireTag('pressure_a');
%       if ok
%           cleaner = onCleanup(@() lock.release());
%           % ... AtomicWriter.write(...) ...
%       end
%
%   Constructor:
%       coord = TagWriteCoordinator(sharedRoot)
%
%   Methods:
%       [lock, ok] = acquireTag(tagKey)
%       [lock, ok] = acquireTag(tagKey, opts)   % opts: struct with Timeout/StaleTimeout/HeartbeatInterval
%
%   Errors:
%       TagWriteCoordinator:invalidSharedRoot — sharedRoot empty or non-char
%       TagWriteCoordinator:invalidTagKey     — tagKey empty or non-char
%
%   See also FileLock, SharedPaths, LiveTagPipeline.

    properties (SetAccess = private)
        SharedRoot  % char; absolute or working-directory-relative cluster root
        LocksDir    % char; SharedPaths.locksDir(SharedRoot) cache
    end

    methods

        function obj = TagWriteCoordinator(sharedRoot)
            %TAGWRITECOORDINATOR Construct the facade for the given shared root.
            %
            %   Input:
            %     sharedRoot — char; non-empty path to the cluster shared root
            %
            %   Throws:
            %     TagWriteCoordinator:invalidSharedRoot — sharedRoot empty or non-char
            if nargin < 1 || isempty(sharedRoot) || ~ischar(sharedRoot)
                error('TagWriteCoordinator:invalidSharedRoot', ...
                    'sharedRoot must be a non-empty char.');
            end
            obj.SharedRoot = sharedRoot;
            obj.LocksDir   = SharedPaths.locksDir(sharedRoot);
        end

        function [lock, ok] = acquireTag(obj, tagKey, opts)
            %ACQUIRETAG Construct a FileLock for tagKey under <SharedRoot>/locks/ and try to acquire.
            %
            %   [lock, ok] = coord.acquireTag(tagKey)
            %   [lock, ok] = coord.acquireTag(tagKey, opts)
            %
            %   Input:
            %     tagKey — char or string; non-empty tag identifier
            %     opts   — (optional) struct with fields:
            %                Timeout          — double; seconds to retry (default 0)
            %                StaleTimeout     — double; stale threshold seconds (default 90)
            %                HeartbeatInterval — double; heartbeat seconds (default 10)
            %   Output:
            %     lock   — FileLock handle; always returned (held iff ok==true)
            %     ok     — logical; true on success, false on contention
            %
            %   Note: if ok==false, the lock is NOT held — caller MUST NOT call release().
            %
            %   Throws:
            %     TagWriteCoordinator:invalidTagKey — tagKey empty or non-char/string
            if nargin < 2 || isempty(tagKey) || ~(ischar(tagKey) || isstring(tagKey))
                error('TagWriteCoordinator:invalidTagKey', ...
                    'tagKey must be a non-empty char or string.');
            end
            tagKey = char(tagKey);

            % Parse opts struct with defaults.
            if nargin < 3 || isempty(opts)
                opts = struct();
            end
            tSec     = optGet_(opts, 'Timeout',            0);
            staleTo  = optGet_(opts, 'StaleTimeout',       90);
            hbInterv = optGet_(opts, 'HeartbeatInterval',  10);

            % Construct FileLock with LockDir scoped to <SharedRoot>/locks/.
            lock = FileLock(tagKey, ...
                'LockDir',           obj.LocksDir, ...
                'StaleTimeout',      staleTo, ...
                'HeartbeatInterval', hbInterv);

            % Try to acquire; ok=false on contention, ok=true on success.
            [ok, ~] = lock.tryAcquire('Timeout', tSec);
        end

    end

end

% --- local helper (not a method; private function in same file) ---
function v = optGet_(opts, name, default)
%OPTGET_ Return opts.name if present, otherwise default.
    if isstruct(opts) && isfield(opts, name)
        v = opts.(name);
    else
        v = default;
    end
end
