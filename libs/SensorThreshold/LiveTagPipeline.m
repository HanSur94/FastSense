classdef LiveTagPipeline < handle
    %LIVETAGPIPELINE Timer-driven raw-data -> per-tag .mat pipeline.
    %   Mirrors MatFileDataSource's modTime + lastIndex state machine
    %   over raw text files. Does NOT subclass LiveEventPipeline (D-14)
    %   -- borrows the timer ergonomics only.
    %
    %   Live semantics (D-13, D-14, D-18):
    %     - Each tick re-enumerates TagRegistry, stats each tag's RawSource.file.
    %     - Files with advanced mtime are re-parsed ONCE (per-tick file cache).
    %     - New rows (lastIndex+1 : total) are appended to <OutputDir>/<tag.Key>.mat.
    %     - Append uses load->concat->save (Pitfall 2 guard); the writer
    %       never uses the dash-append flag of save (which would clobber
    %       the existing `data` variable rather than merge its fields).
    %     - Per-tag try/catch: one tag's failure does NOT abort the tick.
    %     - tagState_ entries GC'd each tick for tags no longer eligible.
    %
    %   Cluster mode (Phase 1030, Plan 02):
    %     - Enabled by passing 'SharedRoot' NV-pair to constructor.
    %     - All shared .mat writes routed through TagWriteCoordinator +
    %       AtomicWriter for safe multi-process access (REQ CONC-01).
    %     - Single-user mode (no SharedRoot) exercises ZERO Concurrency-
    %       library code paths (Success Criterion 5 / byte-identical guarantee).
    %     - BusyMode='drop' is forced in cluster mode (Pitfall 7).
    %     - Timer period is jittered +-25% in cluster mode (Pitfall 11).
    %     - Lock contention causes per-tag skip-and-defer, not whole-tick block.
    %
    %   Observability (Major-2 / revision-1):
    %     - LastFileParseCount: public SetAccess=private property recording the
    %       number of DISTINCT files parsed in the most recent tick. Captured
    %       BEFORE the per-tick tickCache goes out of scope. Mirrors
    %       BatchTagPipeline's mechanism so tests can assert dedup behavior
    %       via direct property read rather than wrapping readRawDelimited_.
    %
    %   Cluster-mode observability (Phase 1030 Plan 02):
    %     - SkippedTickCount: public SetAccess=private; incremented on lock
    %       contention or BusyMode='drop' skip.
    %     - LastTickDurationSec: public SetAccess=private; wall-clock duration
    %       of the last onTick_ invocation.
    %     - LastLockContentionEvent: public SetAccess=private; most recent
    %       contention event struct {tagKey, holder.{user, host, age}}.
    %
    %   Shares readRawDelimited_ / selectTimeAndValue_ / writeTagMat_ with
    %   BatchTagPipeline -- single source of truth for parse + shape + write.
    %
    %   Example (single-user, unchanged):
    %     SensorTag('p_a', 'RawSource', struct('file', 'live.csv', 'column', 'pressure_a'));
    %     p = LiveTagPipeline('OutputDir', 'out/', 'Interval', 5);
    %     p.start();
    %     % ... while the writer process appends to live.csv, p updates out/p_a.mat ...
    %     p.stop();
    %
    %   Example (cluster mode):
    %     SensorTag('p_a', 'RawSource', struct('file', 'live.csv', 'column', 'pressure_a'));
    %     p = LiveTagPipeline('OutputDir', 'out/', 'SharedRoot', '/mnt/shared/fastsense');
    %     p.start();
    %     % Shared writes land at /mnt/shared/fastsense/tags/p_a.mat via AtomicWriter.
    %     p.stop();
    %
    %   Errors:
    %     TagPipeline:invalidOutputDir, TagPipeline:cannotCreateOutputDir
    %     (at construction). In-tick errors are per-tag-isolated and logged.
    %
    %   See also BatchTagPipeline, SensorTag, StateTag, TagRegistry,
    %            TagWriteCoordinator, AtomicWriter, FileLock.
    %   (MatFileDataSource in libs/EventDetection is the structural reference
    %   for the modTime+lastIndex pattern this class adapts to raw text files;
    %   the timer skeleton in libs/EventDetection is the reference for
    %   start/stop ergonomics -- NOT inherited, only mirrored per D-14.)

    properties
        OutputDir = ''
        Interval  = 15        % seconds
        Status    = 'stopped' % 'stopped' | 'running' | 'error'
        ErrorFcn  = []        % optional @(ex) callback for tick-level errors
        Verbose   = false
    end

    properties (SetAccess = private)
        LastTickReport     = struct('succeeded', {{}}, 'failed', struct([]))
        LastFileParseCount = 0   % Major-2 / revision-1 dedup observability (mirrors BatchTagPipeline)
        % Phase 1030 Plan 02 cluster-mode observability (Pitfall 7 / Pitfall 11)
        SkippedTickCount        = 0    % incremented on lock contention OR BusyMode='drop' skip
        LastTickDurationSec     = 0    % wall-clock duration of last onTick_ (Pitfall 7 ops surface)
        LastLockContentionEvent = []   % struct {tagKey, holder.{user,host,age}} (Phase 1033 UI hook)
    end

    properties (Dependent)
        TagStateCount  % RESEARCH Q3: number of tags currently tracked in tagState_
    end

    properties (Access = private)
        timer_    = []
        tagState_          % containers.Map: key (char) -> struct('lastModTime', d, 'lastIndex', n)
        % Phase 1030 Plan 02 cluster-mode private state
        IsClusterMode_  = false    % gate for cluster-mode code paths (Pitfall 11 design)
        Coordinator_    = []       % TagWriteCoordinator handle (cluster mode only)
        SharedRoot_     = ''       % char; cluster shared root
        LockTimeout_    = 5.0      % seconds; per-tag acquire timeout
        tagMtimeCache_             % containers.Map: abspath -> last-seen mtime (Pitfall 11 mtime change-detect)
    end

    methods
        function obj = LiveTagPipeline(varargin)
            %LIVETAGPIPELINE Construct with OutputDir (required) + options.
            %   p = LiveTagPipeline('OutputDir', dir)
            %   p = LiveTagPipeline('OutputDir', dir, 'Interval', 5, 'Verbose', true)
            %   p = LiveTagPipeline('OutputDir', dir, 'ErrorFcn', @(ex) ...)
            %   p = LiveTagPipeline('OutputDir', dir, 'SharedRoot', root)  % cluster mode
            %   p = LiveTagPipeline('OutputDir', dir, 'SharedRoot', root, 'LockTimeout', 10)
            %
            %   Errors:
            %     TagPipeline:invalidOutputDir      -- OutputDir missing/empty/non-char
            %     TagPipeline:cannotCreateOutputDir -- mkdir failed
            opts = struct('OutputDir', '', 'Interval', 15, ...
                'ErrorFcn', [], 'Verbose', false, ...
                'SharedRoot', '', 'LockTimeout', 5.0);
            for k = 1:2:numel(varargin)
                key = varargin{k};
                if k + 1 > numel(varargin) || ~ischar(key)
                    error('TagPipeline:invalidOutputDir', ...
                        'Options must be name-value pairs with char keys.');
                end
                switch key
                    case 'OutputDir'
                        opts.OutputDir = varargin{k+1};
                    case 'Interval'
                        opts.Interval = varargin{k+1};
                    case 'ErrorFcn'
                        opts.ErrorFcn = varargin{k+1};
                    case 'Verbose'
                        opts.Verbose = logical(varargin{k+1});
                    case 'SharedRoot'
                        opts.SharedRoot = char(varargin{k+1});
                    case 'LockTimeout'
                        opts.LockTimeout = double(varargin{k+1});
                    otherwise
                        error('TagPipeline:invalidOutputDir', ...
                            'Unknown option ''%s''.', key);
                end
            end

            if isempty(opts.OutputDir) || ~ischar(opts.OutputDir)
                error('TagPipeline:invalidOutputDir', ...
                    'OutputDir is required (non-empty char).');
            end
            if ~exist(opts.OutputDir, 'dir')
                [ok, msg] = mkdir(opts.OutputDir);
                if ~ok
                    error('TagPipeline:cannotCreateOutputDir', ...
                        'Cannot create OutputDir ''%s'': %s', opts.OutputDir, msg);
                end
            end
            obj.OutputDir = opts.OutputDir;
            obj.Interval  = opts.Interval;
            obj.ErrorFcn  = opts.ErrorFcn;
            obj.Verbose   = opts.Verbose;
            obj.tagState_ = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % --- Cluster mode resolution (Phase 1030 Plan 02; CONTEXT.md scope) ---
            obj.SharedRoot_    = opts.SharedRoot;
            obj.LockTimeout_   = opts.LockTimeout;
            obj.IsClusterMode_ = ~isempty(opts.SharedRoot);
            obj.tagMtimeCache_ = containers.Map('KeyType', 'char', 'ValueType', 'double');
            if obj.IsClusterMode_
                % Resolve identity strictly -- fail fast on missing user/host (IDENT-01).
                ClusterIdentity.resolve('Strict', true);
                % Ensure shared tags/ and locks/ dirs exist.
                tagsD = SharedPaths.tagsDir(opts.SharedRoot);
                locksD = SharedPaths.locksDir(opts.SharedRoot);
                if ~exist(tagsD, 'dir')
                    mkdir(tagsD);
                end
                if ~exist(locksD, 'dir')
                    mkdir(locksD);
                end
                obj.Coordinator_ = TagWriteCoordinator(opts.SharedRoot);
            end
        end

        function start(obj)
            %START Launch the polling timer and set Status='running'.
            if strcmp(obj.Status, 'running'), return; end
            obj.Status = 'running';
            if obj.IsClusterMode_
                % Force BusyMode='drop' in cluster mode (Pitfall 7 -- prevents
                % timer queue buildup when share I/O is slow).
                obj.timer_ = timer('ExecutionMode', 'fixedSpacing', ...
                    'Period',    obj.Interval, ...
                    'BusyMode',  'drop', ...
                    'Tag',       'LiveTagPipeline', ...
                    'TimerFcn',  @(~,~) obj.onTick_(), ...
                    'ErrorFcn',  @(~,~) obj.onTimerError_());
            else
                obj.timer_ = timer('ExecutionMode', 'fixedSpacing', ...
                    'Period',    obj.Interval, ...
                    'Tag',       'LiveTagPipeline', ...
                    'TimerFcn',  @(~,~) obj.onTick_(), ...
                    'ErrorFcn',  @(~,~) obj.onTimerError_());
            end
            start(obj.timer_);
            if obj.Verbose
                fprintf('[LIVE-TAG-PIPELINE] Started (interval=%ds)\n', obj.Interval);
            end
        end

        function stop(obj)
            %STOP Halt the polling timer; mirrors the pattern used by the
            %   live-event pipeline class in libs/EventDetection/.
            %   Pitfall 8 -- guard with isvalid + try/catch so stop()
            %   during an in-flight tick doesn't cascade errors.
            if ~isempty(obj.timer_)
                try
                    if isvalid(obj.timer_)
                        stop(obj.timer_);
                        delete(obj.timer_);
                    end
                catch
                    % Swallow -- teardown is best-effort (Pitfall 8 guard).
                end
            end
            obj.timer_ = [];
            obj.Status = 'stopped';
            if obj.Verbose
                fprintf('[LIVE-TAG-PIPELINE] Stopped\n');
            end
        end

        function tickOnce(obj)
            %TICKONCE Run one tick synchronously (exposed for tests).
            %   Production callers use start()/stop(); tests call this
            %   to avoid pausing for timer intervals.
            obj.onTick_();
        end

        function n = get.TagStateCount(obj)
            %GET.TAGSTATECOUNT Dependent property exposing tagState_.Count.
            %   RESEARCH Q3 observability -- lets tests verify that entries
            %   for unregistered tags are GC'd between ticks.
            if isempty(obj.tagState_)
                n = 0;
            else
                n = double(obj.tagState_.Count);
            end
        end
    end

    methods (Access = private)
        function onTick_(obj)
            %ONTICK_ One polling cycle. Mirrors MatFileDataSource.fetchNew
            %   per tag, with a per-tick file cache to de-dup shared files
            %   (D-07) and a per-tag try/catch boundary (D-18).
            %
            %   Phase 1030 Plan 02 additions (cluster mode only):
            %     - drawnow limitrate nocallbacks at start (Pitfall 7 reentrancy guard)
            %     - tic/toc measurement for LastTickDurationSec
            %     - Jittered period update at end (Pitfall 11)
            tickStart_ = tic();
            if obj.IsClusterMode_
                drawnow limitrate nocallbacks;  % Pitfall 7 reentrancy guard
            end
            report = struct('succeeded', {{}}, 'failed', struct([]));
            tickCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            try
                tags = obj.eligibleTags_();
                obj.gcStaleTagState_(tags);

                for i = 1:numel(tags)
                    t = tags{i};
                    key = char(t.Key);
                    rs  = t.RawSource;
                    try
                        processed = obj.processTag_(t, rs, key, tickCache);
                        if processed
                            report.succeeded{end+1} = key; %#ok<AGROW>
                        end
                    catch ex
                        if obj.Verbose
                            fprintf(2, '[LIVE-TAG-PIPELINE] %s failed: %s\n', ...
                                key, ex.message);
                        end
                        rsFile = '';
                        try
                            rsFile = rs.file;
                        catch
                            rsFile = '';
                        end
                        entry = struct( ...
                            'key',     key, ...
                            'file',    rsFile, ...
                            'errorId', ex.identifier, ...
                            'message', ex.message);
                        if isempty(report.failed)
                            report.failed = entry;
                        else
                            report.failed(end+1) = entry; %#ok<AGROW>
                        end
                    end
                end
            catch ex
                if ~isempty(obj.ErrorFcn)
                    obj.ErrorFcn(ex);
                else
                    fprintf(2, '[LIVE-TAG-PIPELINE] Tick error: %s\n', ex.message);
                end
            end
            % MAJOR-2 / revision-1: capture parse count BEFORE tickCache goes out of scope.
            % Set OUTSIDE the outer try/catch so the property is updated even
            % on partial failure (tests read it directly post-tickOnce()).
            obj.LastFileParseCount = double(tickCache.Count);
            obj.LastTickReport     = report;
            % Phase 1030 Plan 02: record tick duration (Pitfall 7 ops surface).
            obj.LastTickDurationSec = toc(tickStart_);
            % Pitfall 11 -- jitter next firing in cluster mode to decorrelate
            % thundering-herd timer callbacks across multiple Companions.
            if obj.IsClusterMode_ && ~isempty(obj.timer_) && isvalid(obj.timer_)
                nextPeriod = obj.Interval * (1 + 0.5 * (rand() - 0.5));
                try
                    obj.timer_.Period = max(0.1, nextPeriod);
                catch
                    % Some MATLAB versions disallow Period mutation while running;
                    % swallow -- next start cycle picks up the un-jittered value.
                end
            end
        end

        function processed = processTag_(obj, t, rs, key, tickCache)
            %PROCESSTAG_ Handle one tag within a tick. Returns true iff a write occurred.
            %
            %   Phase 1030 Plan 02 additions (cluster mode only):
            %     - Pitfall 11 mtime cache check (before parse gate)
            %     - Lock acquisition via TagWriteCoordinator
            %     - AtomicWriter.write for the locked section
            %     - tagMtimeCache_ update after successful write
            %   Single-user mode is byte-identical to pre-Phase-1030 behaviour.
            processed = false;
            abspath = obj.absPath_(rs.file);

            % Initialize state on first sight.
            if ~obj.tagState_.isKey(key)
                obj.tagState_(key) = struct('lastModTime', 0, 'lastIndex', 0);
            end
            state = obj.tagState_(key);

            if ~exist(abspath, 'file')
                return;
            end

            info = dir(abspath);
            if isempty(info)
                return;
            end
            modTime = info(1).datenum;
            if modTime <= state.lastModTime
                return;
            end

            % Pitfall 11 mtime change-detect (cluster mode only -- additional layer
            % on top of the existing lastModTime guard; prevents redundant dir()
            % stats from being expensive on SMB when many tags share the same raw
            % source file and the per-tick tickCache hasn't been primed yet).
            if obj.IsClusterMode_ && obj.tagMtimeCache_.isKey(abspath)
                if obj.tagMtimeCache_(abspath) == modTime
                    return;  % no change since last tick -- skip read
                end
            end

            % Parse (de-duped across tags for this tick -- D-07).
            if tickCache.isKey(abspath)
                parsed = tickCache(abspath);
            else
                parsed = obj.dispatchParse_(abspath);
                tickCache(abspath) = parsed;
            end

            [x, y] = selectTimeAndValue_(parsed, rs);

            total = size(x, 1);
            if total <= state.lastIndex
                % File mtime bumped but row count unchanged (truncation /
                % noop touch) -- record the new mtime to avoid repeated
                % re-parses and exit.
                state.lastModTime = modTime;
                obj.tagState_(key) = state;
                return;
            end

            newRange = (state.lastIndex + 1):total;
            newX = x(newRange);
            newY = y(newRange);

            if obj.IsClusterMode_
                % --- Cluster-mode locked write path (Phase 1030 Plan 02) ---
                [lock, ok] = obj.Coordinator_.acquireTag(key, ...
                    struct('Timeout', obj.LockTimeout_));
                if ~ok
                    % Lock contention -- skip-and-defer this tag (NOT block whole tick).
                    % Populate LockContentionEvent for Phase 1033 Companion UI.
                    obj.SkippedTickCount = obj.SkippedTickCount + 1;
                    obj.LastLockContentionEvent = ...
                        LiveTagPipeline.buildContentionEvent_(key, lock);
                    return;
                end
                cleaner = onCleanup(@() lock.release()); %#ok<NASGU>

                % Build the merged payload (replicates writeTagMat_'s 'append' branch)
                % inside the locked section so the temp+rename is atomic and
                % Pitfall-10a-gated via StillHeldByMe predicate.
                outPath  = fullfile(SharedPaths.tagsDir(obj.SharedRoot_), [key, '.mat']);
                identity = ClusterIdentity.resolve();
                AtomicWriter.write(outPath, ...
                    @(p) LiveTagPipeline.writeMergedTagMat_(p, key, outPath, newX, newY), ...
                    identity, ...
                    struct('StillHeldByMe', @() lock.stillHeldByMe()));
            else
                % --- Single-user path (byte-identical to pre-Phase-1030 behaviour) ---
                writeTagMat_(obj.OutputDir, t, newX, newY, 'append');
            end

            state.lastModTime = modTime;
            state.lastIndex   = total;
            obj.tagState_(key) = state;
            % Phase 1030 Plan 02: update mtime cache after successful write (cluster mode).
            if obj.IsClusterMode_
                obj.tagMtimeCache_(abspath) = modTime;
            end
            processed = true;
        end

        function parsed = dispatchParse_(obj, abspath)  %#ok<INUSL>
            %DISPATCHPARSE_ Same internal parser dispatch as BatchTagPipeline (D-02).
            [~, ~, ext] = fileparts(abspath);
            ext = lower(ext);
            switch ext
                case {'.csv', '.txt', '.dat'}
                    parsed = readRawDelimited_(abspath);
                otherwise
                    error('TagPipeline:unknownExtension', ...
                        'Unsupported extension ''%s''. Supported: .csv .txt .dat', ext);
            end
        end

        function tags = eligibleTags_(~)
            %ELIGIBLETAGS_ Query TagRegistry for ingestable tags.
            %   Uses an inline anonymous-function predicate passed to
            %   TagRegistry.find. The lambda body is fully inlined (not a
            %   delegation to a private static method) so Octave's
            %   private-method access check is never triggered -- the
            %   predicate evaluates entirely in anonymous-function scope
            %   and needs no class-private visibility.
            %
            %   D-16 / Pitfall 10 discipline: positive-isa checks only
            %   (SensorTag || StateTag); NEVER a negative check against
            %   Monitor/Composite.  The inline body here must stay
            %   byte-semantically identical to BatchTagPipeline.eligibleTags_
            %   in the companion class -- adding a new eligible tag kind
            %   requires updating BOTH sites in lockstep.
            tags = TagRegistry.find(@(t) ...
                (isa(t, 'SensorTag') || isa(t, 'StateTag')) && ...
                isstruct(t.RawSource) && ...
                isfield(t.RawSource, 'file') && ...
                ~isempty(t.RawSource.file));
        end

        function gcStaleTagState_(obj, tags)
            %GCSTALETAGSTATE_ Drop tagState_ entries whose key is not in `tags` (Q3).
            activeKeys = cell(1, numel(tags));
            for i = 1:numel(tags)
                activeKeys{i} = char(tags{i}.Key);
            end
            stateKeys = obj.tagState_.keys();
            for i = 1:numel(stateKeys)
                if ~any(strcmp(activeKeys, stateKeys{i}))
                    obj.tagState_.remove(stateKeys{i});
                end
            end
        end

        function ap = absPath_(~, path)
            %ABSPATH_ Resolve to an absolute path (pwd-relative fallback).
            if ~isempty(path) && (path(1) == filesep() || ...
                    (ispc() && numel(path) >= 2 && path(2) == ':'))
                ap = path;
            else
                ap = fullfile(pwd(), path);
            end
        end

        function onTimerError_(obj)
            %ONTIMERERROR_ Timer-level ErrorFcn handler -- Pitfall 8 surface.
            obj.Status = 'error';
            fprintf(2, '[LIVE-TAG-PIPELINE] Timer error -- Status=error\n');
        end
    end

    methods (Static, Access = private)

        function ev = buildContentionEvent_(tagKey, lock)
            %BUILDCONTENTIONEVENT_ Construct a LockContentionEvent struct.
            %   Used by processTag_ on ok=false to populate the
            %   LastLockContentionEvent property for downstream UI (Phase 1033).
            %   Best-effort: struct is well-formed even when peek() fails.
            ev = struct('tagKey', tagKey, ...
                'holder', struct('user', '', 'host', '', 'age', NaN));
            ev.timestamp = now(); %#ok<TNOW1>
            try
                info = lock.peek();
                if ~isempty(info) && isfield(info, 'user')
                    ev.holder.user = info.user;
                    ev.holder.host = info.host;
                    % Age derived from heartbeat_at when available; else NaN.
                    if isfield(info, 'heartbeat_at') && ~isempty(info.heartbeat_at)
                        try
                            hbDT = datetime(info.heartbeat_at, ...
                                'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''', ...
                                'TimeZone', 'UTC');
                            nowDT = datetime('now', 'TimeZone', 'UTC');
                            ev.holder.age = seconds(nowDT - hbDT);
                        catch
                            ev.holder.age = NaN;
                        end
                    end
                end
            catch
                % Best-effort; structure is still well-formed on peek failure.
            end
        end

        function writeMergedTagMat_(tempPath, key, finalPath, newX, newY)
            %WRITEMERGEDTAGMAT_ Replicate writeTagMat_'s 'append' branch into temp path.
            %   This is the cluster-mode write payload -- load the existing shared
            %   file, merge new rows, save into temp (caller wraps in
            %   AtomicWriter.write for atomic rename + lock re-validation via
            %   Pitfall-10a StillHeldByMe predicate).
            %
            %   Input:
            %     tempPath  — char; temp file path provided by AtomicWriter.write
            %     key       — char; tag key (MAT variable name)
            %     finalPath — char; the shared .mat path (to load existing prior rows)
            %     newX      — numeric column vector; new time rows
            %     newY      — numeric or cell column vector; new value rows
            priorX = [];
            priorY = [];
            if exist(finalPath, 'file')
                prior = load(finalPath);
                if isfield(prior, key)
                    old = prior.(key);
                    if isstruct(old)
                        if isfield(old, 'x'), priorX = old.x; end
                        if isfield(old, 'y'), priorY = old.y; end
                    end
                end
            end
            % Concatenate, handling cellstr (StateTag) and numeric uniformly.
            if iscell(priorY) || iscell(newY)
                if ~iscell(priorY), priorY = num2cell(priorY(:)); end
                if ~iscell(newY),   newY   = num2cell(newY(:));   end
                mergedY = [priorY(:); newY(:)];
            else
                mergedY = [priorY(:); newY(:)];
            end
            mergedX = [priorX(:); newX(:)];
            % Build payload matching writeTagMat_ contract (struct with x,y fields).
            if iscell(mergedY)
                payload = struct('x', mergedX, 'y', {mergedY});
            else
                payload = struct('x', mergedX, 'y', mergedY);
            end
            wrap = struct();
            wrap.(key) = payload;
            save(tempPath, '-struct', 'wrap');
        end

    end

end
