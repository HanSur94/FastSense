classdef EventStore < handle
    % EventStore  Atomic read/write of events to a shared .mat file.
    %
    %   Single-user mode (default):
    %     es = EventStore(filePath)
    %     es = EventStore(filePath, 'MaxBackups', 3)
    %   Events are stored in a MAT file via atomic temp+rename.  All
    %   existing tests exercise this path unchanged.
    %
    %   Cluster mode (opt-in):
    %     es = EventStore(filePath, 'SharedRoot', sharedMountPath)
    %   Opens (or creates) <SharedRoot>/events/store.sqlite via mksqlite
    %   with journal_mode=DELETE + busy_timeout=10000 + locking_mode=NORMAL.
    %   All cluster writes use BEGIN IMMEDIATE + application-level retry on
    %   'database is locked' (see STACK.md §2, PITFALLS Pitfall 6).
    %   The local-per-user FastSenseDataStore continues to use WAL — only
    %   the cluster-mode EventStore switches to rollback mode.
    %
    %   Errors (cluster mode only):
    %     EventStore:mksqliteUnavailable — mksqlite MEX not compiled
    %     EventStore:notClusterMode      — cluster method called in single-user mode
    %     EventStore:invalidAckRecord    — rec is not a scalar struct
    %     EventStore:appendAckFailed     — INSERT retries exhausted on database lock
    %     EventStore:retryExhausted      — busyRetryWrap_ ran 10 attempts and still hit 'database is locked'
    %     EventStore:mergeShapeMismatch  — getEvents cluster-merge could not concatenate heterogeneous shapes (warning, not error)
    %
    %   busyRetryWrap_ is exposed as a public Static method so that test harnesses
    %   can call it with synthetic fn arguments.  In production it is called only
    %   from within EventStore cluster-mode transactions.

    properties
        FilePath        = ''
        MaxBackups      = 5
        PipelineConfig  = struct()
        SensorData      = []   % struct array: name, t, y (for EventViewer click-to-plot)
        ThresholdColors = struct()  % serialized threshold colors struct
        Timestamp       = []        % datetime: when events were saved
    end

    properties (Access = private)
        events_         = []
        acks_           = []  % single-user: struct array of {eventId, by_user, by_host, epoch, comment, action='ack'}.
                              % Cluster mode: in-memory mirror of SQLite ack_records (updated on every acknowledgeEvent
                              % call AND on every getAckRecordsForEvent query).  Canonical source in cluster mode is SQLite.
        nextId_         = 0
        IsClusterMode_  = false     % gate; true iff 'SharedRoot' NV-pair was non-empty
        SharedRoot_     = ''        % char; copy of NV-pair for diagnostics
        DbPath_         = ''        % char; cluster-mode SQLite path
        DbId_           = []        % mksqlite handle (int64 db id) or []
    end

    methods
        function obj = EventStore(filePath, varargin)
            defaults.MaxBackups = 5;
            defaults.SharedRoot = '';
            opts = parseOpts(defaults, varargin);
            obj.FilePath   = filePath;
            obj.MaxBackups = opts.MaxBackups;

            if ~isempty(opts.SharedRoot)
                % Cluster mode — open shared SQLite with rollback (DELETE) journaling.
                obj.IsClusterMode_ = true;
                obj.SharedRoot_    = char(opts.SharedRoot);
                % IDENT-01 fail-fast guard (mirrors LiveTagPipeline cluster init).
                ClusterIdentity.resolve('Strict', true);
                evDir = SharedPaths.eventsDir(obj.SharedRoot_);
                if ~isfolder(evDir), mkdir(evDir); end
                obj.DbPath_ = fullfile(evDir, 'store.sqlite');
                obj.openClusterDb_();
            end
        end

        function delete(obj)
            %DELETE Close mksqlite connection on object destruction.
            if obj.IsClusterMode_ && ~isempty(obj.DbId_)
                try
                    mksqlite(obj.DbId_, 'close');
                catch
                end
                obj.DbId_ = [];
            end
        end

        function append(obj, newEvents)
            if isempty(newEvents); return; end
            for i = 1:numel(newEvents)
                obj.nextId_ = obj.nextId_ + 1;
                newEvents(i).Id = sprintf('evt_%d', obj.nextId_);
                if isempty(obj.events_)
                    obj.events_ = newEvents(i);
                else
                    obj.events_(end+1) = newEvents(i);
                end
            end
        end

        function events = getEvents(obj)
            %GETEVENTS Return all events.
            %   Single-user mode: returns in-memory events_ (unchanged from pre-plan).
            %   Cluster mode: merges in-memory events_ with per-tag NDJSON logs under
            %   <sharedRoot>/events/*.events.ndjson via EventLogReader.readAll().
            %   Best-effort merge — if NDJSON read fails, falls back to in-memory only.
            events = obj.events_;
            if ~obj.IsClusterMode_, return; end
            % Cluster mode: merge in per-tag NDJSON event logs under sharedRoot/events/
            try
                evDir = SharedPaths.eventsDir(obj.SharedRoot_);
                d = dir(fullfile(evDir, '*.events.ndjson'));
                for i = 1:numel(d)
                    logPath = fullfile(evDir, d(i).name);
                    reader = EventLogReader(logPath);
                    tagEvents = reader.readAll();
                    if ~isempty(tagEvents)
                        events = EventStore.mergeEventStructs_(events, tagEvents);
                    end
                end
            catch ME
                fprintf('[EventStore] cluster-merge getEvents failed: %s\n', ME.message);
                % Best-effort: fall back to in-memory snapshot
            end
        end

        function closeEvent(obj, eventId, endTime, finalStats)
            %CLOSEEVENT Close an open event in place.
            %   es.closeEvent(eventId, endTime, finalStats) locates an open
            %   Event by Id, delegates to ev.close(endTime, finalStats) for
            %   the in-place mutation, and returns. finalStats may be []
            %   (empty) to skip stats update. Does NOT call save() — consumers
            %   decide when to persist (Pitfall 2).
            %
            %   Errors:
            %     EventStore:unknownEventId — eventId not in store
            %     EventStore:alreadyClosed  — forwarded from Event:closedOpenEvent
            if nargin < 4, finalStats = []; end
            if isempty(obj.events_)
                error('EventStore:unknownEventId', ...
                    'No events in store; id ''%s'' not found.', eventId);
            end
            eventId = char(eventId);
            for i = 1:numel(obj.events_)
                ev = obj.events_(i);
                if isa(ev, 'Event') && strcmp(ev.Id, eventId)
                    if ~ev.IsOpen
                        error('EventStore:alreadyClosed', ...
                            'Event ''%s'' is not open.', eventId);
                    end
                    % Delegate in-place mutation to Event.close (SSOT at D1).
                    ev.close(endTime, finalStats);
                    return;
                end
            end
            error('EventStore:unknownEventId', ...
                'Event id ''%s'' not found in store.', eventId);
        end

        function events = getEventsForTag(obj, tagKey)
        %GETEVENTSFORTAG Return events bound to tagKey via EventBinding + carrier fallback.
        %   Primary path: uses EventBinding.getEventsForTag for events
        %   with non-empty Id (Phase 1010 EVENT-01/EVENT-03).
        %   Fallback path: carrier-field matching (SensorName/ThresholdLabel)
        %   for events without Id (backward compat, Pitfall 4).
        %   Cluster mode: merges the in-memory/EventBinding result with events from
        %   the per-tag NDJSON log (<sharedRoot>/events/<tagKey>.events.ndjson).
        %
        %   Errors:
        %     EventStore:invalidTagKey — tagKey not char / string
            events = [];
            if isempty(obj.events_) && ~obj.IsClusterMode_, return; end
            if ~ischar(tagKey) && ~isstring(tagKey)
                error('EventStore:invalidTagKey', ...
                    'tagKey must be char or string; got %s.', class(tagKey));
            end
            tagKey = char(tagKey);

            if ~isempty(obj.events_)
                % Primary path: EventBinding-based lookup
                boundEvents = EventBinding.getEventsForTag(tagKey, obj);
                % Fallback path: carrier-field matching (SensorName/ThresholdLabel)
                % for events NOT already found by EventBinding
                keep = false(1, numel(obj.events_));
                for i = 1:numel(obj.events_)
                    ev = obj.events_(i);
                    % Check if this event was already found by EventBinding (by Id)
                    alreadyBound = false;
                    evId = '';
                    if isa(ev, 'Event') && ~isempty(ev.Id)
                        evId = ev.Id;
                    end
                    if ~isempty(evId)
                        for bi = 1:numel(boundEvents)
                            if strcmp(evId, boundEvents(bi).Id)
                                alreadyBound = true;
                                break;
                            end
                        end
                    end
                    if alreadyBound
                        continue;
                    end
                    sn = '';
                    tl = '';
                    if isa(ev, 'Event')
                        sn = ev.SensorName;
                        tl = ev.ThresholdLabel;
                    elseif isstruct(ev)
                        if isfield(ev, 'SensorName'), sn = ev.SensorName; end
                        if isfield(ev, 'ThresholdLabel'), tl = ev.ThresholdLabel; end
                    end
                    keep(i) = strcmp(sn, tagKey) || strcmp(tl, tagKey);
                end
                carrierEvents = obj.events_(keep);
                % Combine: EventBinding results + carrier fallback (dedup by handle ==)
                if isempty(boundEvents) && isempty(carrierEvents)
                    events = [];
                elseif isempty(boundEvents)
                    events = carrierEvents;
                elseif isempty(carrierEvents)
                    events = boundEvents;
                else
                    events = [boundEvents, carrierEvents];
                end
            end

            % Cluster mode: merge per-tag NDJSON log into results.
            if obj.IsClusterMode_
                try
                    evDir  = SharedPaths.eventsDir(obj.SharedRoot_);
                    logPath = fullfile(evDir, [tagKey, '.events.ndjson']);
                    reader = EventLogReader(logPath);
                    tagEvents = reader.readAll();
                    if ~isempty(tagEvents)
                        events = EventStore.mergeEventStructs_(events, tagEvents);
                    end
                catch ME
                    fprintf('[EventStore] cluster-merge getEventsForTag failed: %s\n', ME.message);
                    % Best-effort
                end
            end
        end

        function save(obj)
            if isempty(obj.FilePath); return; end

            % Backup existing file
            if isfile(obj.FilePath) && obj.MaxBackups > 0
                obj.createBackup();
            end

            % Atomic write: save to temp, then rename
            tmpFile = [obj.FilePath '.tmp'];
            events = obj.events_; %#ok<PROPLC,NASGU>
            lastUpdated = now; %#ok<NASGU>
            pipelineConfig = obj.PipelineConfig; %#ok<PROPLC,NASGU>
            sensorData = obj.SensorData; %#ok<PROPLC,NASGU>
            thresholdColors = obj.ThresholdColors; %#ok<PROPLC,NASGU>
            timestamp = obj.Timestamp; %#ok<PROPLC,NASGU>
            acks = obj.acks_; %#ok<PROPLC,NASGU>

            varList = {'events', 'lastUpdated', 'pipelineConfig'};
            if ~isempty(sensorData)
                varList{end+1} = 'sensorData';
            end
            if isstruct(thresholdColors) && ~isempty(fieldnames(thresholdColors))
                varList{end+1} = 'thresholdColors';
            end
            if ~isempty(timestamp)
                varList{end+1} = 'timestamp';
            end
            if ~isempty(acks)
                varList{end+1} = 'acks';
            end
            if exist('OCTAVE_VERSION', 'builtin')
                builtin('save', tmpFile, varList{:});
            else
                builtin('save', tmpFile, varList{:}, '-v7.3');
            end
            movefile(tmpFile, obj.FilePath);
        end

        function n = numEvents(obj)
            n = numel(obj.events_);
        end

        function appendAckRecord(obj, rec)
        %APPENDACKRECORD Insert an ack/comment row in cluster mode.
        %   rec — struct with fields: eventId (char), by_user (char),
        %         by_host (char), epoch (double), comment (char, optional)
        %
        %   Single-user mode: throws EventStore:notClusterMode.  The Phase
        %   1032 ack workflow will route through this method only when
        %   running with 'SharedRoot' set.
        %
        %   Cluster-mode retry: delegates to busyRetryWrap_ which catches
        %   mksqlite:sqlError with 'database is locked' substring (per
        %   1029-PROBES.md) and retries up to 10 times with exponential
        %   backoff 50/100/200/400/800/1600/2000ms capped (PITFALLS Pitfall 6).
            if ~obj.IsClusterMode_
                error('EventStore:notClusterMode', ...
                    ['appendAckRecord is cluster-mode only.  ', ...
                     'Construct with ''SharedRoot'' NV-pair to enable.']);
            end
            if ~isstruct(rec) || ~isscalar(rec)
                error('EventStore:invalidAckRecord', ...
                    'rec must be a scalar struct.');
            end
            comment = '';
            if isfield(rec, 'comment'), comment = char(rec.comment); end

            try
                EventStore.busyRetryWrap_(@() obj.doInsertAckRecord_(rec, comment));
            catch ME
                if strcmp(ME.identifier, 'EventStore:retryExhausted')
                    % Re-wrap to the legacy error ID expected by existing tests.
                    error('EventStore:appendAckFailed', ...
                        'INSERT exhausted retries on database lock: %s', ME.message);
                else
                    rethrow(ME);
                end
            end
        end

        function rows = getAckRecords(obj)
        %GETACKRECORDS Return all ack rows from cluster-mode store.
        %   Returns a struct array with fields: event_id, by_user, by_host,
        %   epoch, comment.  Cluster mode only.
        %
        %   Errors:
        %     EventStore:notClusterMode — called in single-user mode
            if ~obj.IsClusterMode_
                error('EventStore:notClusterMode', ...
                    'getAckRecords is cluster-mode only.');
            end
            rows = mksqlite(obj.DbId_, ...
                'SELECT event_id, by_user, by_host, epoch, comment FROM ack_records');
        end

        function ack = acknowledgeEvent(obj, eventId, opts)
            %ACKNOWLEDGEEVENT Record an acknowledgement for an event (ACK-01/03 + IDENT-02).
            %   ack = es.acknowledgeEvent(eventId, opts)
            %
            %   opts struct fields (all optional):
            %     comment — char (default '')
            %     user    — char (default = ClusterIdentity.resolve().user; empty if unresolvable)
            %     host    — char (default = ClusterIdentity.resolve().host)
            %     epoch   — double (default = now)
            %
            %   Behavior:
            %     - Single-user mode: appends to obj.acks_ AND mutates the in-memory Event
            %       (sets AckedAt / AckedBy / AckComment). save() persists acks_ in the saved .mat.
            %     - Cluster mode: calls appendAckRecord (Phase 1031-04, retry-wrapped via Plan 03).
            %       Also mutates the in-memory Event for current-session reads (mirror).
            %
            %   Errors:
            %     EventStore:unknownEventId — eventId not found in events_ (single-user only)
            %
            %   ACK-01 (~5s propagation): ack lands in SQLite (cluster) or events.mat (single-user).
            %   ACK-02 (three-state visual): Event.AckedAt + Event.IsOpen drive computeDisplayState().
            %   ACK-03 (comment): opts.comment plumbed end-to-end.
            %   IDENT-02 (audit trail): every ack stamped with {user, host, epoch, comment}.
            if nargin < 3, opts = struct(); end
            eventId = char(eventId);

            % Identity defaults — use ClusterIdentity if available, else empty (non-strict).
            identityUser = ''; identityHost = ''; identityEpoch = now;
            try
                id = ClusterIdentity.resolve();   % non-strict; tolerates failure
                if isstruct(id)
                    if isfield(id, 'user'),  identityUser  = id.user;  end
                    if isfield(id, 'host'),  identityHost  = id.host;  end
                    if isfield(id, 'epoch')
                        ep = id.epoch;
                        if isa(ep, 'datetime')
                            identityEpoch = datenum(ep);
                        else
                            identityEpoch = double(ep);
                        end
                    end
                end
            catch
                % stay with defaults — single-user mode tolerates identity failure
            end
            if isfield(opts, 'user'),  identityUser  = char(opts.user);    end
            if isfield(opts, 'host'),  identityHost  = char(opts.host);    end
            if isfield(opts, 'epoch'), identityEpoch = double(opts.epoch); end
            comment = '';
            if isfield(opts, 'comment'), comment = char(opts.comment); end

            ack = struct( ...
                'eventId', eventId, ...
                'by_user', identityUser, ...
                'by_host', identityHost, ...
                'epoch',   identityEpoch, ...
                'comment', comment, ...
                'action',  'ack');

            % Find the Event and mutate AckedAt/AckedBy/AckComment (in-memory mirror).
            found = false;
            if ~isempty(obj.events_)
                for i = 1:numel(obj.events_)
                    ev = obj.events_(i);
                    evId = '';
                    if isa(ev, 'Event'),         evId = ev.Id;
                    elseif isstruct(ev) && isfield(ev, 'Id'), evId = ev.Id; end
                    if strcmp(evId, eventId)
                        if isa(ev, 'Event')
                            ev.AckedAt    = identityEpoch;
                            ev.AckedBy    = struct('user', identityUser, 'host', identityHost, ...
                                'epoch', identityEpoch, 'comment', comment);
                            ev.AckComment = comment;
                        end
                        found = true;
                        break;
                    end
                end
            end

            if ~found
                % In cluster mode the event may live ONLY in the NDJSON log, not in events_.
                % We tolerate "event not in memory" only when cluster mode is on; single-user
                % strict mode throws.
                if ~obj.IsClusterMode_
                    error('EventStore:unknownEventId', ...
                        'Event id ''%s'' not found in store.', eventId);
                end
            end

            % Persist the ack.
            if obj.IsClusterMode_
                obj.appendAckRecord(ack);   % retry-wrapped via Plan 03
            else
                % Single-user: append to acks_ in-memory array (persisted by save()).
                if isempty(obj.acks_)
                    obj.acks_ = ack;
                else
                    obj.acks_(end+1) = ack; %#ok<AGROW>
                end
            end
        end

        function rows = getAckRecordsForEvent(obj, eventId)
            %GETACKRECORDSFOREVENT Return ack records for a specific event.
            %   Single-user: filters obj.acks_; cluster: queries SQLite WHERE event_id = ?.
            eventId = char(eventId);
            if obj.IsClusterMode_
                rows = EventStore.busyRetryWrap_(@() ...
                    mksqlite(obj.DbId_, ...
                        ['SELECT event_id, by_user, by_host, epoch, comment ', ...
                         'FROM ack_records WHERE event_id = ?'], eventId));
            else
                rows = [];
                if isempty(obj.acks_), return; end
                keep = false(1, numel(obj.acks_));
                for i = 1:numel(obj.acks_)
                    if strcmp(obj.acks_(i).eventId, eventId)
                        keep(i) = true;
                    end
                end
                rows = obj.acks_(keep);
            end
        end
    end

    methods (Static)
        function [events, meta, changed] = loadFile(filePath)
            persistent lastModTime lastData;
            if isempty(lastModTime)
                lastModTime = containers.Map('KeyType', 'char', 'ValueType', 'double');
                lastData = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end

            events = [];
            meta = struct();
            changed = false;

            if ~isfile(filePath); return; end

            info = dir(filePath);
            modTime = info.datenum;

            if lastModTime.isKey(filePath) && modTime <= lastModTime(filePath)
                % Unchanged — return cached results without re-reading file
                if lastData.isKey(filePath)
                    cached = lastData(filePath);
                    events = cached.events;
                    meta = cached.meta;
                end
                return;
            end

            lastModTime(filePath) = modTime;
            changed = true;

            data = builtin('load', filePath);
            if isfield(data, 'events')
                events = data.events;
            end
            if isfield(data, 'lastUpdated')
                meta.lastUpdated = data.lastUpdated;
            end
            if isfield(data, 'pipelineConfig')
                meta.pipelineConfig = data.pipelineConfig;
            end
            if isfield(data, 'acks')
                meta.acks = data.acks;
            end

            % Cache for future unchanged calls
            lastData(filePath) = struct('events', events, 'meta', meta);
        end

        function out = busyRetryWrap_(fn)
        %BUSYRETRYWRAP_ Generalised SQLite "database is locked" retry loop (Pitfall 6).
        %   out = EventStore.busyRetryWrap_(@() doSomeMksqliteTransaction())
        %
        %   Retries on mksqlite errors whose message contains 'database is locked'
        %   (per 1029-PROBES.md captured string). Backoff schedule (seconds):
        %     0.05, 0.10, 0.20, 0.40, 0.80, 1.60, 2.00, 2.00, 2.00
        %   Total: up to 10 attempts (9 backoff waits between them).
        %   Other errors propagate immediately (no retry).
        %
        %   Throws EventStore:retryExhausted on final exhaustion.
        %
        %   This method is public-static so test harnesses can call it with
        %   synthetic fn arguments (e.g. testRetryHelperBackoffSchedule).
            backoffs  = [0.05, 0.10, 0.20, 0.40, 0.80, 1.60, 2.00, 2.00, 2.00]; % 9 waits = 10 attempts
            lastErr   = MException('EventStore:retryExhausted', 'no prior attempt');
            nAttempts = numel(backoffs) + 1;   % 10
            for attempt = 1:nAttempts
                try
                    out = fn();
                    return;
                catch ME
                    lastErr = ME;
                    isBusy = strcmp(ME.identifier, 'mksqlite:sqlError') && ...
                             contains(ME.message, 'database is locked');
                    if ~isBusy
                        rethrow(ME);   % unrelated errors propagate immediately
                    end
                    if attempt <= numel(backoffs)
                        pause(backoffs(attempt));
                    end
                end
            end
            error('EventStore:retryExhausted', ...
                'mksqlite transaction exhausted %d retries on database lock: %s', ...
                nAttempts, lastErr.message);
        end

        function out = mergeEventStructs_(a, b)
        %MERGEEVENTSTRUCTS_ Concatenate two event collections tolerating shape heterogeneity.
        %   Best-effort concatenation — if types are incompatible (Event handle vs struct),
        %   returns a unchanged with a warning.  Phase 1033's snapshot consolidator will
        %   unify the shape canonically.
            if isempty(a),    out = b;  return; end
            if isempty(b),    out = a;  return; end
            if ~strcmp(class(a), class(b))
                warning('EventStore:mergeShapeMismatch', ...
                    'Cannot merge %s and %s — returning first arg.', class(a), class(b));
                out = a;
                return;
            end
            try
                out = [a, b];
            catch
                warning('EventStore:mergeShapeMismatch', ...
                    'Concatenation failed — returning first arg.');
                out = a;
            end
        end
    end

    methods (Access = private)
        function openClusterDb_(obj)
        %OPENCLUSTERDB_ Open <SharedRoot>/events/store.sqlite in rollback mode.
        %   Uses journal_mode=DELETE + busy_timeout=10000 + locking_mode=NORMAL,
        %   per STACK.md §2 — the only mode SQLite docs document as workable
        %   over network filesystems.
        %
        %   The local-per-user FastSenseDataStore continues to use WAL — only
        %   the cluster-mode shared EventStore uses DELETE.
            if exist('mksqlite', 'file') ~= 3
                error('EventStore:mksqliteUnavailable', ...
                    'Cluster-mode EventStore requires mksqlite MEX.');
            end
            obj.DbId_ = mksqlite('open', obj.DbPath_);
            mksqlite(obj.DbId_, 'PRAGMA journal_mode = DELETE');
            mksqlite(obj.DbId_, 'PRAGMA locking_mode = NORMAL');
            mksqlite(obj.DbId_, 'PRAGMA busy_timeout = 10000');
            mksqlite(obj.DbId_, ...
                ['CREATE TABLE IF NOT EXISTS ack_records (', ...
                 'event_id TEXT, by_user TEXT, by_host TEXT, ', ...
                 'epoch REAL, comment TEXT)']);
            % Note: 'events' table is intentionally NOT created here.  Phase 1031
            % canonicalises NDJSON-per-tag as the event write surface (EventLog).
            % This table is the ACK and audit-trail surface that Phase 1032's
            % single-source emission path uses for IDENT-02.
        end

        function out = doInsertAckRecord_(obj, rec, comment)
        %DOINSERTACKRECORD_ Single attempt at INSERT inside BEGIN IMMEDIATE.
        %   Called by busyRetryWrap_ — performs exactly one transaction attempt.
        %   Rolls back on any error and rethrows so busyRetryWrap_ can classify
        %   and retry (or propagate) the exception.
        %
        %   Returns a dummy value so it is callable from an LHS-assignment
        %   context (e.g. `out = fn();` inside busyRetryWrap_). Without an
        %   `out` argument, anonymous-wrapped invocation trips MATLAB:maxlhs.
            try
                mksqlite(obj.DbId_, 'BEGIN IMMEDIATE');
                mksqlite(obj.DbId_, ...
                    'INSERT INTO ack_records VALUES (?,?,?,?,?)', ...
                    char(rec.eventId), char(rec.by_user), ...
                    char(rec.by_host), double(rec.epoch), comment);
                mksqlite(obj.DbId_, 'COMMIT');
            catch ME
                try
                    mksqlite(obj.DbId_, 'ROLLBACK');
                catch
                end
                rethrow(ME);
            end
            out = [];
        end

        function createBackup(obj)
            [fdir, fname, fext] = fileparts(obj.FilePath);
            stamp = datestr(now, 'yyyymmdd_HHMMSS');
            backupName = fullfile(fdir, [fname '_backup_' stamp fext]);
            copyfile(obj.FilePath, backupName);
            obj.pruneBackups();
        end

        function pruneBackups(obj)
            [fdir, fname] = fileparts(obj.FilePath);
            pattern = fullfile(fdir, [fname '_backup_*.mat']);
            backups = dir(pattern);
            if numel(backups) > obj.MaxBackups
                [~, idx] = sort([backups.datenum]);
                toDelete = backups(idx(1:end - obj.MaxBackups));
                for i = 1:numel(toDelete)
                    delete(fullfile(fdir, toDelete(i).name));
                end
            end
        end
    end
end
