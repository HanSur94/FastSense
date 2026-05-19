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
        LastFsStatCount    = 0   % Phase 1028 plan 06: number of fs-stat syscalls in the most recent
                                 %   tick. With fsCoalesceActive_=true this equals the number of UNIQUE
                                 %   parent directories enumerated in the tick (one dir() per parent).
                                 %   With fsCoalesceActive_=false this equals the number of per-tag
                                 %   exist+dir calls (≈ 2 × #eligible-tags). Captured BEFORE the per-tick
                                 %   fsCache goes out of scope. Mirrors LastFileParseCount.
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
        writeFn_  = @writeTagMat_   % Phase 1028 plan 02b: DI seam for .mat I/O suppression in benchmarks.
                                    % Default routes to libs/SensorThreshold/private/writeTagMat_ (production path,
                                    % unchanged write-on-every-tick cadence per D-12). The handle is created in this
                                    % class's scope so the resolution to the private/ helper is captured at class
                                    % load time. Tests/benchmarks override via setWriteFnForTesting_ (Hidden).
        cachedWriteFn_ = @writeTagMatCached_   % Phase 1028 plan 02d: cached append helper that skips load().
                                               % Captured at class load time so resolution to the private/ helper
                                               % is bound. Disabled by setting cacheActive_ = false (Hidden setter).
        priorState_                 % Phase 1028 plan 02d: containers.Map keyed by tag key.
                                    %   Value: struct('X', priorX, 'Y', priorY) reflecting the last save
                                    %   for that tag. Empty/absent until the first warm tick. The cache is
                                    %   refreshed after every successful write so subsequent ticks can skip
                                    %   the on-disk load() inside writeTagMat_('append', ...).
        cacheActive_ = true         % Phase 1028 plan 02d: production-default. The cache is opt-out via
                                    %   the Hidden setCacheActiveForTesting_ setter so benchmarks can run
                                    %   the cache-off comparison; production callers always benefit.
        writeFnIsProduction_ = true % Phase 1028 plan 02d: explicit flag tracking whether writeFn_ is the
                                    %   default (production) handle. Set false by setWriteFnForTesting_ when
                                    %   the bench swaps in a no-op writer. Used to gate the cache: if writeFn_
                                    %   does not actually write to disk (NoIO benchmark mode), the cache must
                                    %   be bypassed because there is no on-disk state to load back. We use an
                                    %   explicit flag rather than `isequal(writeFn_, @writeTagMat_)` because
                                    %   function-handle equality is unreliable for private/ helpers across
                                    %   MATLAB / Octave versions.
        coalesceActive_ = true      % Phase 1028 plan 05: production-default for A1+A2 listener fan-out
                                    %   coalescing. When true, onTick_ accumulates SensorTag handles whose
                                    %   processTag_ returned true and calls Tag.invalidateBatch_(updatedSet)
                                    %   once at end-of-tick rather than relying solely on per-tag listener
                                    %   cascade. Default true (mirrors cacheActive_); Hidden setter flips for
                                    %   benchmark comparison (cache-off / coalesce-off measurement). NOTE:
                                    %   in the LiveTagPipeline today, processTag_ writes to .mat files and
                                    %   does NOT call tag.updateData() — so the upstream listener fan-out is
                                    %   inert in this code path. The coalesced batch call is therefore a
                                    %   forward-compatible seam: it has zero observable effect when the
                                    %   updated SensorTags have no listeners (the case for raw-source-only
                                    %   sensors typical of the pipeline), and amortizes overhead when
                                    %   downstream MonitorTags/CompositeTags ARE wired against pipeline
                                    %   sensors (the Companion / dashboard wiring). See VERIFICATION.md
                                    %   §"Post-Plan-05 tBreakdown" for measured before/after numbers.
        fsCoalesceActive_ = true    % Phase 1028 plan 06: production-default for per-tick filesystem
                                    %   stat coalescing. When true, onTick_ pre-builds a per-tick map
                                    %   of `parent directory -> map(basename -> struct('mtime', datenum))`
                                    %   via ONE dir(parentDir) call per unique parent directory, and
                                    %   processTag_ consults that map instead of issuing per-tag
                                    %   exist/dir/datenum calls. At 1000-tag scale with 8 source CSV
                                    %   files (the bench fixture), this reduces ~1000 syscalls/tick
                                    %   (1000 × {exist, dir} = 2000 stats) to ONE dir() per unique
                                    %   parent directory (8 in the bench) -- ~250× reduction in
                                    %   per-tag fs-stat overhead. The mid-tick snapshot is FROZEN:
                                    %   a file appearing or having its mtime advance between the
                                    %   tick-start dir() and a later per-tag lookup is NOT visible
                                    %   in this tick, and is picked up on the NEXT tick. This matches
                                    %   the de facto semantics already in place — the per-tag mtime
                                    %   check vs lastModTime serialises ingestion at tick boundaries.
                                    %   Hidden setFsCoalesceForTesting_ flips the flag for the bench's
                                    %   --fs-coalesce-off regression measurement; production is on.
                                    %   Mirrors Plan 02b setWriteFnForTesting_ / Plan 02d
                                    %   setCacheActiveForTesting_ / Plan 05 setCoalesceActiveForTesting_.
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
            obj.tagState_  = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.priorState_ = containers.Map('KeyType', 'char', 'ValueType', 'any');

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

    methods (Hidden)
        function setWriteFnForTesting_(obj, fn)
            %SETWRITEFNFORTESTING_ Internal-only DI seam for .mat write suppression.
            %   Phase 1028 plan 02b: replace the default @writeTagMat_ with a
            %   user-supplied function handle (e.g., a no-op for benchmark NoIO
            %   measurement). Production callers MUST NOT use this — the
            %   default cadence per D-12 is write-on-every-tick.
            %
            %   Why this exists: addpath(-begin) cannot shadow private/ helpers
            %   because MATLAB/Octave scope private/ to the parent directory.
            %   A function-handle property captured at class-load time is the
            %   one mechanism that reliably reaches into the private/ caller.
            %
            %   The fn must accept the same signature as writeTagMat_:
            %     fn(outputDir, tag, x, y, mode)
            %
            %   Public API note: this is marked Hidden so it does not appear
            %   in tab-completion, doc(), or properties() listings. It is not
            %   considered part of the public surface (D-10).
            if ~isa(fn, 'function_handle')
                error('TagPipeline:invalidWriteFn', ...
                    'setWriteFnForTesting_ requires a function_handle (got %s)', class(fn));
            end
            obj.writeFn_ = fn;
            % Phase 1028 plan 02d: flip the production-handle flag so the
            % cache wiring knows the writer no longer touches disk and the
            % seed-from-disk path must be bypassed (NoIO mode is meaningless
            % under cache because there's no .mat to read back).
            obj.writeFnIsProduction_ = false;
        end

        function setFsCoalesceForTesting_(obj, tf)
            %SETFSCOALESCEFORTESTING_ Internal-only setter for per-tick fs-stat coalescing.
            %   Phase 1028 plan 06: enable/disable the per-tick coalesced
            %   filesystem-stat lookup inside onTick_. When ON (production
            %   default), onTick_ issues ONE dir(parentDir) call per unique
            %   raw-source parent directory at tick start and stores the
            %   resulting basename->struct map; processTag_ consults that map
            %   instead of issuing per-tag exist/dir/datenum syscalls. When
            %   OFF, the per-tag fallback path runs (one exist + one dir per
            %   tag) — used by the benchmark to isolate the coalescing win.
            %
            %   Production callers MUST NOT use this — fs-coalesce is the
            %   production default (D-10). The bench flips it off for the
            %   `--fs-coalesce-off` measurement. Hidden so it does not appear
            %   in tab-completion / doc(). Mirrors the plan-02b
            %   setWriteFnForTesting_, plan-02d setCacheActiveForTesting_,
            %   and plan-05 setCoalesceActiveForTesting_ patterns.
            if ~(islogical(tf) && isscalar(tf))
                error('TagPipeline:invalidFsCoalesce', ...
                    'setFsCoalesceForTesting_ requires a logical scalar (got %s).', class(tf));
            end
            obj.fsCoalesceActive_ = tf;
        end

        function setCoalesceActiveForTesting_(obj, tf)
            %SETCOALESCEACTIVEFORTESTING_ Internal-only setter for end-of-tick listener coalescing.
            %   Phase 1028 plan 05: enable/disable the A1+A2 end-of-tick
            %   Tag.invalidateBatch_(updatedSet) call inside onTick_.
            %   Production callers MUST NOT use this — coalescing-on is the
            %   production default (coalesceActive_ = true). The setter exists
            %   so the bench can measure the coalesce-on vs coalesce-off
            %   delta against the dominant `other` bucket (per-tag dispatch +
            %   listener cascade — see Plan 02d VERIFICATION.md). Hidden so
            %   it does not appear in tab-completion / doc() (D-10). Mirrors
            %   the plan-02b setWriteFnForTesting_ and plan-02d
            %   setCacheActiveForTesting_ patterns.
            if ~(islogical(tf) && isscalar(tf))
                error('TagPipeline:invalidCoalesceActive', ...
                    'setCoalesceActiveForTesting_ requires a logical scalar (got %s).', class(tf));
            end
            obj.coalesceActive_ = tf;
        end

        function setCacheActiveForTesting_(obj, tf)
            %SETCACHEACTIVEFORTESTING_ Internal-only setter for the prior-state cache.
            %   Phase 1028 plan 02d: enable/disable the in-memory priorState_ cache
            %   used to skip the on-disk load() in writeTagMat_('append',...).
            %   Production callers MUST NOT use this — the cache is the production
            %   default (cacheActive_ = true) and is byte-for-byte parity-tested
            %   against the cache-off path. Disabling it is a benchmark feature for
            %   measuring the load()-only cost (see bench_tag_pipeline_1k --cache-off).
            %
            %   Side effect: clears the existing priorState_ map so the next write
            %   per tag re-seeds from disk via the standard append path (D-09).
            %
            %   Public API note: marked Hidden so it does not appear in
            %   tab-completion, doc(), or properties() listings (D-10). Mirrors the
            %   plan-02b setWriteFnForTesting_ pattern.
            if ~(islogical(tf) && isscalar(tf))
                error('TagPipeline:invalidCacheActive', ...
                    'setCacheActiveForTesting_ requires a logical scalar (got %s).', class(tf));
            end
            obj.cacheActive_ = tf;
            % Re-seed: clearing the cache is safe because the next write per tag
            % falls back to writeFn_(...,'append',...) which load()s from disk.
            obj.priorState_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end
    end

    methods (Access = private)
        function onTick_(obj)
            %ONTICK_ One polling cycle. Mirrors MatFileDataSource.fetchNew
            %   per tag, with a per-tick file cache to de-dup shared files
            %   (D-07) and a per-tag try/catch boundary (D-18).
            %
            %   Phase 1028 plan 05 (A1+A2 seam): the loop accumulates the
            %   handle of every tag whose processTag_ returned true into
            %   updatedSet. When coalesceActive_ is true (production
            %   default), the end-of-tick block calls
            %   Tag.invalidateBatch_(updatedSet) — fanning listener
            %   invalidate() out across the union of unique downstream
            %   listeners (MonitorTags / CompositeTags) in a single walk.
            %
            %   IMPORTANT — current semantics: the pipeline writes new
            %   rows to .mat files via writeFn_ / cachedWriteFn_; it
            %   does NOT update the in-memory SensorTag's X_/Y_ fields.
            %   Downstream MonitorTag/CompositeTag caches read from
            %   parent.X_/Y_ (in-memory). Therefore, calling
            %   invalidateBatch_ here clears monitor caches even though
            %   the data those caches summarize hasn't moved in memory.
            %   The recomputed result on next getXY() is bit-for-bit
            %   identical to the cached one — invalidating is
            %   semantically a no-op (just wasted work).
            %
            %   This makes coalesceActive_ a forward-compatible seam:
            %   when a future refactor wires processTag_ to also call
            %   tag.updateData(newX, newY) for in-memory propagation
            %   (so dashboards don't need explicit tag.load()), the
            %   end-of-tick batched fan-out is already in place and
            %   eliminates per-tag cascade cost. For NOW, both
            %   coalesce-on and coalesce-off produce identical
            %   downstream observable behavior; coalesce-on adds the
            %   cost of walking listener lists and clearing caches that
            %   would be cleared again by the eventual in-memory update
            %   path. See VERIFICATION.md §"Post-Plan-05 tBreakdown"
            %   for measured cost numbers and the plan-06 follow-up
            %   pointer (in-memory propagation refactor).
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
            % Phase 1028 plan 06: per-tick fs-stat cache. Keyed by parent
            % directory (absolute path). Value: containers.Map from basename
            % (char) to struct('mtime', datenum, 'fullpath', char). Built
            % lazily inside processTag_ via lookupFsEntry_; one dir(parentDir)
            % per unique parent directory. fsStatCount_ counts the actual
            % syscalls used (one per unique parent dir in coalesce-on mode;
            % one per tag in coalesce-off mode) so the bench can verify the
            % expected reduction in the CI artifact.
            fsCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            fsStatCount = 0;
            updatedSet = {};   % collect tag handles with processed==true
            try
                tags = obj.eligibleTags_();
                obj.gcStaleTagState_(tags);

                for i = 1:numel(tags)
                    t = tags{i};
                    key = char(t.Key);
                    rs  = t.RawSource;
                    try
                        [processed, fsStatCount] = obj.processTag_(t, rs, key, tickCache, fsCache, fsStatCount);
                        if processed
                            report.succeeded{end+1} = key; %#ok<AGROW>
                            updatedSet{end+1} = t;          %#ok<AGROW>
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

                % Phase 1028 plan 05 A1+A2: end-of-tick coalesced
                % invalidate. Skipped when coalesceActive_ is false (the
                % bench's --coalesce-off mode for measurement).
                if obj.coalesceActive_ && ~isempty(updatedSet)
                    Tag.invalidateBatch_(updatedSet);
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
            % Phase 1028 plan 06: expose fs-stat syscall count so the bench
            % artifact can verify the expected O(#parent-dirs) coalesced cost
            % vs the O(#tags) un-coalesced baseline.
            obj.LastFsStatCount    = fsStatCount;
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

        function [processed, fsStatCount] = processTag_(obj, t, rs, key, tickCache, fsCache, fsStatCount)
            %PROCESSTAG_ Handle one tag within a tick. Returns true iff a write occurred.
            %   Phase 1028 plan 06: takes fsCache + fsStatCount as in/out
            %   arguments so the per-tick fs-stat coalescing can amortise
            %   the dir() syscall across all tags sharing a parent directory.
            %   fsCache is a containers.Map keyed by parent-directory absolute
            %   path; value is itself a containers.Map from basename -> struct
            %   ('mtime', datenum, 'fullpath', abspath). When fsCoalesceActive_
            %   is false, the per-tag exist+dir fallback path runs (legacy
            %   behaviour, used by the bench --fs-coalesce-off measurement).
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

            % Phase 1028 plan 06: resolve file existence + mtime via the
            % per-tick coalesced fs cache. fsStatCount is incremented inside
            % lookupFsEntry_ only when a real dir()/exist() syscall is issued.
            [exists, modTime, fsStatCount] = obj.lookupFsEntry_(abspath, fsCache, fsStatCount);
            if ~exists
                return;
            end
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
                % --- Single-user path with Phase 1028 plan 02d cache + Plan 06 fs-coalesce ---
                % Phase 1028 plan 02d: prefer the cached append path when the cache
                % is active AND we have a warm entry for this tag. Cold cache (first
                % write per tag) AND cache-off both fall through to the writeFn_
                % path, which is the same load+concat+save sequence as before. The
                % cache is then refreshed from the merged result so the next tick
                % takes the warm path. Because writeTagMatCached_ produces byte-equal
                % .mat files to writeTagMat_('append',...) for the same priorX/priorY,
                % crash-recovery semantics at the tick boundary are preserved (D-12).
                useCache = obj.cacheActive_ && ...
                    obj.writeFnIsProduction_ && ...
                    obj.priorState_.isKey(key);
                if useCache
                    prior = obj.priorState_(key);
                    [mergedX, mergedY] = obj.cachedWriteFn_( ...
                        obj.OutputDir, t, newX, newY, prior.X, prior.Y);
                    obj.priorState_(key) = struct('X', mergedX, 'Y', mergedY);
                else
                    outPath = fullfile(obj.OutputDir, [key '.mat']);
                    fileExistedBefore = (exist(outPath, 'file') == 2);
                    obj.writeFn_(obj.OutputDir, t, newX, newY, 'append');
                    if obj.cacheActive_ && obj.writeFnIsProduction_
                        if ~fileExistedBefore
                            % Fresh file: writeTagMat_('append',...) just saved
                            % (newX, newY) without loading anything. Seed the
                            % cache directly — no extra disk read.
                            obj.priorState_(key) = struct('X', newX(:), 'Y', newY(:));
                        else
                            % Existing file (process restart / cache eviction):
                            % read back the merged file once to seed. This load
                            % happens at most once per tag per pipeline-instance
                            % lifetime; subsequent ticks skip load() entirely.
                            try
                                loaded = load(outPath);
                                if isfield(loaded, key) && isstruct(loaded.(key)) && ...
                                        isfield(loaded.(key), 'x') && isfield(loaded.(key), 'y')
                                    obj.priorState_(key) = struct( ...
                                        'X', loaded.(key).x, ...
                                        'Y', loaded.(key).y);
                                end
                            catch
                                % Best-effort: if seed read fails the next tick
                                % retries the cold path, which is correct.
                            end
                        end
                    end
                end
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

        function [exists, modTime, fsStatCount] = lookupFsEntry_(obj, abspath, fsCache, fsStatCount)
            %LOOKUPFSENTRY_ Resolve (exists, mtime) for abspath via per-tick fs cache.
            %   Phase 1028 plan 06: when fsCoalesceActive_ is true, one
            %   dir(parentDir) call enumerates ALL files in the parent
            %   directory the first time any tag asks; subsequent tags whose
            %   raw file lives in the same parent directory consult the
            %   pre-built map of basename -> modtime.
            %
            %   When fsCoalesceActive_ is false, falls back to the legacy
            %   per-tag exist+dir code path (used by --fs-coalesce-off).
            %
            %   Returns:
            %     exists      logical scalar
            %     modTime     numeric (datenum); 0 when ~exists
            %     fsStatCount updated counter (each real syscall increments)
            %
            %   The mid-tick freeze: a file that materialises after the first
            %   dir() of its parent directory in this tick will NOT be visible
            %   in this tick (the map was sampled then). The next tick re-runs
            %   the fs-cache build from scratch, so the next-tick refresh
            %   semantic is preserved.
            exists  = false;
            modTime = 0;
            if ~obj.fsCoalesceActive_
                % Legacy fallback path (--fs-coalesce-off): per-tag stat.
                fsStatCount = fsStatCount + 1;   % exist()
                if ~exist(abspath, 'file')
                    return;
                end
                fsStatCount = fsStatCount + 1;   % dir()
                info = dir(abspath);
                if isempty(info)
                    return;
                end
                exists  = true;
                modTime = info(1).datenum;
                return;
            end

            % Coalesced path: build parent-directory listing lazily.
            [parentDir, base, ext] = fileparts(abspath);
            basename = [base ext];
            if isempty(parentDir)
                parentDir = pwd();
            end
            if fsCache.isKey(parentDir)
                entries = fsCache(parentDir);
            else
                % One dir() syscall per unique parent directory per tick.
                fsStatCount = fsStatCount + 1;
                listing = dir(parentDir);
                entries = containers.Map('KeyType', 'char', 'ValueType', 'any');
                for j = 1:numel(listing)
                    if listing(j).isdir
                        continue;
                    end
                    entries(listing(j).name) = struct( ...
                        'mtime',    listing(j).datenum, ...
                        'fullpath', fullfile(parentDir, listing(j).name));
                end
                fsCache(parentDir) = entries;
            end
            if entries.isKey(basename)
                hit     = entries(basename);
                exists  = true;
                modTime = hit.mtime;
            end
        end

        function parsed = dispatchParse_(obj, abspath)  %#ok<INUSL>
            %DISPATCHPARSE_ Same internal parser dispatch as BatchTagPipeline (D-02).
            %   Routes through dispatchDelimitedParse_ which prefers the
            %   compiled delimited_parse_mex (Phase 1028 K1) and falls back
            %   to readRawDelimited_ when the MEX binary is absent (D-09).
            [~, ~, ext] = fileparts(abspath);
            ext = lower(ext);
            switch ext
                case {'.csv', '.txt', '.dat'}
                    parsed = dispatchDelimitedParse_(abspath);
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
