classdef EventLog < handle
%EVENTLOG Append-only NDJSON event log, lock-serialised through TagWriteCoordinator.
%
%   Per Pitfall 5 (NDJSON O_APPEND on SMB/NFS is NOT atomic), every append goes
%   through TagWriteCoordinator.acquireTag(tagKey) to serialise cross-process
%   writes. O_APPEND inside the locked section is defence in depth only.
%
%   First write to a new log file emits a magic-byte + version header line:
%     #FASTSENSE_EVENTLOG_V1
%   followed by a newline.  Subsequent events are pure NDJSON lines encoded via
%   libs/Concurrency/ndjsonEncode.m. ndjsonDecode silently skips comment lines
%   (starting with '#') so the header is transparent to readers.
%
%   Construction:
%     el = EventLog(sharedRoot, tagKey)
%     el = EventLog(sharedRoot, tagKey, opts)   % opts.LockTimeout (default 5 s)
%
%   Public API:
%     ok = el.append(eventStruct)   % returns false on lock contention (skip-and-defer)
%     p  = el.path()                % absolute path to the log file
%     n  = el.LastAppendSkipped     % count of contention skips since construction
%
%   Lock-contention behaviour:
%     When TagWriteCoordinator.acquireTag returns ok=false, append() returns false
%     and increments LastAppendSkipped. The caller is responsible for retry.
%     DO NOT call lock.release() when ok=false (Phase 1030-01 SUMMARY contract).
%
%   Errors:
%     EventLog:invalidSharedRoot — sharedRoot is empty or non-char
%     EventLog:invalidTagKey     — tagKey is empty or non-char/string
%     EventLog:invalidEvent      — eventStruct is not a non-empty scalar struct
%     EventLog:openFailed        — fopen() returned a negative file descriptor
%     EventLog:lockContended     — reserved for callers that prefer a hard error on
%                                  contention; the default ok=false return is the
%                                  skip-and-defer path (Phase 1030-01 SUMMARY contract).
%                                  Callers may throw this ID from their retry loop on
%                                  LastAppendSkipped exceeding a threshold.
%
%   Phase 1031 contingency (SC6): this implementation uses a SINGLE per-tag
%   NDJSON file. If SMB-atomicity stress on the target file server shows torn
%   appends despite the lock, Phase 1033 budget includes time to re-architect
%   to per-writer-file + merge. The append(eventStruct) signature is preserved
%   either way — only the disk layout would change.
%
%   See also TagWriteCoordinator, SharedPaths, ndjsonEncode, EventLogReader.

    properties (Constant)
        MAGIC = '#FASTSENSE_EVENTLOG_V1'
    end

    properties (SetAccess = private)
        SharedRoot          % char; absolute shared filesystem root
        TagKey              % char; per-tag identifier
        LogPath             % char; <sharedRoot>/events/<tagKey>.events.ndjson
        LastAppendSkipped = 0  % double; monotonic count of contention skips
    end

    properties (Access = private)
        Coordinator_        % TagWriteCoordinator; lock facade
        LockTimeout_        % double; seconds to wait for lock (default 5)
        EventsDir_          % char; cached SharedPaths.eventsDir(SharedRoot)
    end

    methods

        function obj = EventLog(sharedRoot, tagKey, opts)
            %EVENTLOG Construct an EventLog for the given shared root and tag key.
            %
            %   Input:
            %     sharedRoot — char; non-empty path to the cluster shared root
            %     tagKey     — char or string; non-empty tag identifier
            %     opts       — (optional) struct; supported fields:
            %                    LockTimeout — double; seconds to wait for the
            %                                  per-tag FileLock (default 5)
            %
            %   Throws:
            %     EventLog:invalidSharedRoot — sharedRoot empty or non-char
            %     EventLog:invalidTagKey     — tagKey empty or non-char/string
            if nargin < 1 || isempty(sharedRoot) || ~ischar(sharedRoot)
                error('EventLog:invalidSharedRoot', ...
                    'sharedRoot must be a non-empty char.');
            end
            if nargin < 2 || isempty(tagKey) || ~(ischar(tagKey) || isstring(tagKey))
                error('EventLog:invalidTagKey', ...
                    'tagKey must be a non-empty char or string.');
            end
            tagKey = char(tagKey);
            if nargin < 3 || isempty(opts)
                opts = struct();
            end

            obj.SharedRoot   = sharedRoot;
            obj.TagKey       = tagKey;
            obj.EventsDir_   = SharedPaths.eventsDir(sharedRoot);
            obj.LogPath      = fullfile(obj.EventsDir_, [tagKey, '.events.ndjson']);
            obj.LockTimeout_ = EventLog.optGet_(opts, 'LockTimeout', 5);
            obj.Coordinator_ = TagWriteCoordinator(sharedRoot);
        end

        function p = path(obj)
            %PATH Return the absolute path to the log file.
            %
            %   Output:
            %     p — char; <sharedRoot>/events/<tagKey>.events.ndjson
            p = obj.LogPath;
        end

        function ok = append(obj, eventStruct)
            %APPEND Append eventStruct as one NDJSON line, lock-serialised.
            %
            %   Acquires the per-tag FileLock via TagWriteCoordinator.acquireTag
            %   before opening the log file. On first write, emits the magic
            %   header line (#FASTSENSE_EVENTLOG_V1) before the JSON payload so
            %   future readers can detect the format version.
            %
            %   Input:
            %     eventStruct — scalar struct; the event to persist
            %
            %   Output:
            %     ok — logical; true on success, false when lock is contended
            %          (skip-and-defer — caller should retry with jitter)
            %
            %   Throws:
            %     EventLog:invalidEvent — eventStruct is not a non-empty scalar struct
            %     EventLog:openFailed   — fopen() returned a negative descriptor
            if ~isstruct(eventStruct) || ~isscalar(eventStruct)
                error('EventLog:invalidEvent', ...
                    'eventStruct must be a non-empty scalar struct.');
            end

            % Lock-serialise the append (Pitfall 5: O_APPEND is NOT atomic on SMB/NFS).
            % Pass a short timeout to avoid long blocking in live pipelines.
            [lock, gotLock] = obj.Coordinator_.acquireTag(obj.TagKey, ...
                struct('Timeout', obj.LockTimeout_));
            if ~gotLock
                % Skip-and-defer — caller may retry after random jitter.
                % Per Phase 1030-01 SUMMARY contract: DO NOT call lock.release()
                % when ok==false (the lock is not held).
                obj.LastAppendSkipped = obj.LastAppendSkipped + 1;
                ok = false;
                return;
            end
            % RAII lock release — exception-safe via onCleanup.
            cleaner = onCleanup(@() lock.release()); %#ok<NASGU>

            % Ensure the events directory exists (idempotent).
            if ~isfolder(obj.EventsDir_)
                mkdir(obj.EventsDir_);
            end

            % Determine whether the magic-byte header must be written.
            % We check BEFORE opening so that a race-free first-writer guarantee
            % is provided by the FileLock rather than by kernel O_CREAT semantics.
            needHeader = ~isfile(obj.LogPath);

            % Open with 'a' (append mode).  On POSIX local FS, O_APPEND gives
            % kernel-level append atomicity within the same host.  On SMB/NFS it
            % does NOT (Pitfall 5) — the FileLock acquired above is the real
            % cross-host serialisation mechanism.  O_APPEND here is defence in depth.
            fid = fopen(obj.LogPath, 'a');
            if fid < 0
                error('EventLog:openFailed', ...
                    'fopen(''%s'', ''a'') failed.', obj.LogPath);
            end
            % RAII file close — exception-safe via onCleanup.
            closer = onCleanup(@() fclose(fid)); %#ok<NASGU>

            % Write magic-byte + version header on first append.
            if needHeader
                fwrite(fid, [EventLog.MAGIC, sprintf('\n')], 'char');
            end

            % Encode and write the event as a single NDJSON line.
            line = ndjsonEncode(eventStruct);
            fwrite(fid, line, 'char');

            ok = true;
        end

    end

    methods (Static, Access = private)

        function v = optGet_(opts, name, default)
            %OPTGET_ Return opts.name if present, otherwise default.
            if isstruct(opts) && isfield(opts, name)
                v = opts.(name);
            else
                v = default;
            end
        end

    end

end
