classdef EventLogConsolidator < handle
%EVENTLOGCONSOLIDATOR Leader-elected NDJSON-to-snapshot consolidator.
%
%   Periodically merges all <sharedRoot>/events/*.events.ndjson logs into
%   the canonical <sharedRoot>/events/events.mat snapshot, gated by a
%   single-leader FileLock so multiple Companions in a cluster cannot step
%   on each other.  Silent skip on lock contention — caller decides when to
%   retry.
%
%   Usage:
%     cons = EventLogConsolidator(sharedRoot);
%     result = cons.consolidate();
%     if result.acquiredLeader
%         fprintf('Consolidated %d events into %s\n', ...
%             result.eventCount, result.snapshotPath);
%     end
%     delete(cons);
%
%   Constructor:
%     cons = EventLogConsolidator(sharedRoot)
%     Throws EventLogConsolidator:invalidSharedRoot if sharedRoot is empty
%     or not an existing folder.
%
%   consolidate() result struct fields:
%     .acquiredLeader   — logical; true iff the leader lock was acquired
%     .snapshotPath     — char; path written on success, '' on contention
%     .eventCount       — double; merged event count on success, 0 on contention
%     .skippedLineCount — double; sum of SkippedLineCount across all log readers
%     .contendedBy      — struct {user, host, age} on contention; [] on success
%     .durationSec      — double; wall time for this pass
%
%   Observability properties (SetAccess=private):
%     LastConsolidationDurationSec
%     LastEventCount
%     LastSkippedLineCount
%     TotalConsolidationCount
%     LastContendedHolder
%     LastSnapshotPath
%
%   Idempotency contract:
%     Running consolidate() twice on the same data produces a snapshot with
%     the SAME event count (deduplication by Id field prevents accumulation).
%
%   Empty-events-dir tolerance:
%     If no .events.ndjson files exist, the consolidator acquires the lock,
%     writes an empty snapshot (events=[]), and releases cleanly.
%
%   Errors:
%     EventLogConsolidator:invalidSharedRoot — sharedRoot empty or not a folder
%
%   See also EventLog, EventLogReader, AtomicWriter, FileLock, SharedPaths.

    properties (SetAccess = private)
        SharedRoot                   = ''    % char; shared filesystem root
        LastConsolidationDurationSec = 0     % double; wall time of last consolidate()
        LastEventCount               = 0     % double; event count from last consolidate()
        LastSkippedLineCount         = 0     % double; cumulative skipped NDJSON lines
        TotalConsolidationCount      = 0     % double; number of successful consolidations
        LastContendedHolder          = []    % struct {user,host,age} or []
        LastSnapshotPath             = ''    % char; path of last written snapshot
    end

    properties (Access = private)
        EventsDir_    = ''          % char; <sharedRoot>/events
        LocksDir_     = ''          % char; <sharedRoot>/locks
        SnapshotPath_ = ''          % char; <sharedRoot>/events/events.mat
        LockKey_      = 'events-consolidator'  % char; leader-election key
    end

    methods

        function obj = EventLogConsolidator(sharedRoot)
            %EVENTLOGCONSOLIDATOR Construct bound to the given shared root.
            %
            %   Input:
            %     sharedRoot — char; non-empty path to an existing folder
            %
            %   Throws:
            %     EventLogConsolidator:invalidSharedRoot — empty, non-char,
            %       or folder does not exist
            if nargin < 1 || isempty(sharedRoot) || ~ischar(sharedRoot)
                error('EventLogConsolidator:invalidSharedRoot', ...
                    'sharedRoot must be a non-empty char.');
            end
            if ~isfolder(sharedRoot)
                error('EventLogConsolidator:invalidSharedRoot', ...
                    'sharedRoot ''%s'' does not exist.', sharedRoot);
            end
            obj.SharedRoot    = sharedRoot;
            obj.EventsDir_    = SharedPaths.eventsDir(sharedRoot);
            obj.LocksDir_     = SharedPaths.locksDir(sharedRoot);
            obj.SnapshotPath_ = fullfile(obj.EventsDir_, 'events.mat');
            if ~isfolder(obj.EventsDir_)
                mkdir(obj.EventsDir_);
            end
            if ~isfolder(obj.LocksDir_)
                mkdir(obj.LocksDir_);
            end
        end

        function result = consolidate(obj)
            %CONSOLIDATE One leader-elected consolidation pass.
            %
            %   Acquires a single-leader FileLock('events-consolidator') and
            %   merges all <sharedRoot>/events/*.events.ndjson logs into the
            %   canonical events.mat snapshot via AtomicWriter.write.  If the
            %   lock is already held by another process, returns immediately
            %   with acquiredLeader=false (silent skip — no error thrown).
            %
            %   Output:
            %     result — struct with fields:
            %       .acquiredLeader   (logical)
            %       .snapshotPath     (char)
            %       .eventCount       (double)
            %       .skippedLineCount (double)
            %       .contendedBy      (struct or [])
            %       .durationSec      (double)
            result = struct('acquiredLeader', false, ...
                'snapshotPath', '', 'eventCount', 0, ...
                'skippedLineCount', 0, 'contendedBy', [], 'durationSec', 0);
            tStart = tic();

            % Attempt non-blocking leader-election lock acquire.
            % Treat nestedLockAcquireForbidden (same-process key conflict) as a
            % contention signal — the semantic is identical: skip silently.
            lock = FileLock(obj.LockKey_, 'LockDir', obj.LocksDir_);
            ok = false;
            try
                [ok, ~] = lock.tryAcquire('Timeout', 0);
            catch ME
                if ~strcmp(ME.identifier, 'Concurrency:nestedLockAcquireForbidden')
                    rethrow(ME);
                end
                % Same-process nested acquire — treat as contention (ok stays false).
            end
            if ~ok
                % Another consolidator is running — skip silently.
                info = lock.peek();
                holder = struct('user', '', 'host', '', 'age', NaN);
                if isstruct(info)
                    if isfield(info, 'user'), holder.user = info.user; end
                    if isfield(info, 'host'), holder.host = info.host; end
                    if isfield(info, 'age'),  holder.age  = info.age;  end
                end
                obj.LastContendedHolder = holder;
                result.contendedBy = holder;
                result.durationSec = toc(tStart);
                delete(lock);
                return;
            end

            % RAII lock release — exception-safe onCleanup mirrors
            % LiveTagPipeline.processTag_ Phase 1030-02 SUMMARY pattern.
            cleaner = onCleanup(@() lock.release());

            % Discover all per-tag NDJSON logs.
            listing = dir(fullfile(obj.EventsDir_, '*.events.ndjson'));
            accumulated = [];
            totalSkipped = 0;
            for i = 1:numel(listing)
                logPath = fullfile(obj.EventsDir_, listing(i).name);
                try
                    reader = EventLogReader(logPath);
                    ev = reader.readAll();
                    totalSkipped = totalSkipped + reader.SkippedLineCount;
                    if ~isempty(ev)
                        accumulated = EventLogConsolidator.mergeEvents_(accumulated, ev);
                    end
                catch ME
                    warning('EventLogConsolidator:readFailed', ...
                        'Read of %s failed: %s', logPath, ME.message);
                end
            end

            % Merge with existing snapshot to preserve cross-run history.
            if isfile(obj.SnapshotPath_)
                try
                    prior = AtomicWriter.readWithRetry(obj.SnapshotPath_, ...
                        @(p) load(p, 'events'));
                    if isstruct(prior) && isfield(prior, 'events') && ~isempty(prior.events)
                        accumulated = EventLogConsolidator.mergeEvents_( ...
                            prior.events, accumulated);
                    end
                catch %#ok<CTCH>
                    % Best-effort — corrupt snapshot is recoverable from NDJSON logs.
                end
            end

            % Deduplicate by Id field (or content-hash fallback).
            accumulated = EventLogConsolidator.dedupById_(accumulated);

            % Atomic snapshot write via AtomicWriter.write.
            % Pass accumulated as a captured value to the static save helper so
            % that save() has a concrete 'events' variable in scope — the plan's
            % @(p) save(p, 'events') pattern requires the static-method closure
            % because MATLAB classdef methods cannot contain nested functions.
            identity = ClusterIdentity.resolve();
            AtomicWriter.write(obj.SnapshotPath_, ...
                @(p) EventLogConsolidator.saveEvents_(p, accumulated), identity, ...
                struct('StillHeldByMe', @() lock.stillHeldByMe()));

            obj.LastEventCount               = numel(accumulated);
            obj.LastSkippedLineCount         = totalSkipped;
            obj.TotalConsolidationCount      = obj.TotalConsolidationCount + 1;
            obj.LastSnapshotPath             = obj.SnapshotPath_;
            obj.LastConsolidationDurationSec = toc(tStart);

            result.acquiredLeader   = true;
            result.snapshotPath     = obj.SnapshotPath_;
            result.eventCount       = obj.LastEventCount;
            result.skippedLineCount = totalSkipped;
            result.durationSec      = obj.LastConsolidationDurationSec;
            % cleaner releases the lock at end of scope
        end

        function delete(obj) %#ok<INUSD>
            % Destructor — no-op.  onCleanup handles lock release inside consolidate().
        end

    end

    methods (Static, Access = private)

        function saveEvents_(p, events) %#ok<INUSL>
            %SAVEEVENTS_ Payload callback for AtomicWriter.write — saves events to p.
            %   Called with a temp path by AtomicWriter.write; the rename step is
            %   handled by AtomicWriter.replace after this function returns.
            %   'events' is the parameter name so save(p, 'events') resolves to
            %   the function's local variable.
            if exist('OCTAVE_VERSION', 'builtin')
                builtin('save', p, 'events');
            else
                builtin('save', p, 'events', '-v7.3');
            end
        end

        function merged = mergeEvents_(a, b)
            %MERGEEVENTS_ Concatenate two event arrays tolerating heterogeneous shapes.
            %   Mirrors EventStore.mergeEventStructs_ semantics — see
            %   libs/EventDetection/EventStore.m for the canonical pattern.
            if isempty(a), merged = b; return; end
            if isempty(b), merged = a; return; end
            try
                merged = [a, b];
            catch %#ok<CTCH>
                % Fall back to field-unification for heterogeneous field sets.
                fA   = fieldnames(a);
                fB   = fieldnames(b);
                allF = union(fA, fB);
                fillFn = @(s) EventLogConsolidator.fillMissingFields_(s, allF);
                merged = [fillFn(a), fillFn(b)];
            end
        end

        function out = fillMissingFields_(s, allF)
            %FILLMISSINGFIELDS_ Add empty fields so heterogeneous struct arrays can concat.
            out = s;
            for i = 1:numel(out)
                for j = 1:numel(allF)
                    f = allF{j};
                    if ~isfield(out(i), f)
                        out(i).(f) = [];
                    end
                end
            end
        end

        function out = dedupById_(events)
            %DEDUPBYID_ Drop duplicate events by .Id field (or content-hash fallback).
            %   Preserves first occurrence; collapses exact duplicates by Id string.
            %   When Id is absent or empty, a content-hash is used so genuinely
            %   different events are not accidentally merged into one.
            if isempty(events), out = events; return; end
            seen     = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            keepMask = false(1, numel(events));
            for i = 1:numel(events)
                if isfield(events(i), 'Id') && ~isempty(events(i).Id)
                    key = char(events(i).Id);
                else
                    % Content-hash fallback — best-effort; prevents accidental
                    % dedup of all-Id-empty events (would collapse into one bucket).
                    try
                        key = sprintf('hash_%d', sum(double(jsonencode(events(i)))));
                    catch %#ok<CTCH>
                        key = sprintf('idx_%d', i);  % defeat dedup if encoding fails
                    end
                end
                if ~seen.isKey(key)
                    seen(key) = true;
                    keepMask(i) = true;
                end
            end
            out = events(keepMask);
        end

    end

end
