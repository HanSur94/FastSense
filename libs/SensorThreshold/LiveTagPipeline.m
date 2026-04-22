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
    %   Observability (Major-2 / revision-1):
    %     - LastFileParseCount: public SetAccess=private property recording the
    %       number of DISTINCT files parsed in the most recent tick. Captured
    %       BEFORE the per-tick tickCache goes out of scope. Mirrors
    %       BatchTagPipeline's mechanism so tests can assert dedup behavior
    %       via direct property read rather than wrapping readRawDelimited_.
    %
    %   Shares readRawDelimited_ / selectTimeAndValue_ / writeTagMat_ with
    %   BatchTagPipeline -- single source of truth for parse + shape + write.
    %
    %   Example:
    %     SensorTag('p_a', 'RawSource', struct('file', 'live.csv', 'column', 'pressure_a'));
    %     p = LiveTagPipeline('OutputDir', 'out/', 'Interval', 5);
    %     p.start();
    %     % ... while the writer process appends to live.csv, p updates out/p_a.mat ...
    %     p.stop();
    %
    %   Errors:
    %     TagPipeline:invalidOutputDir, TagPipeline:cannotCreateOutputDir
    %     (at construction). In-tick errors are per-tag-isolated and logged.
    %
    %   See also BatchTagPipeline, SensorTag, StateTag, TagRegistry.
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
    end

    properties (Dependent)
        TagStateCount  % RESEARCH Q3: number of tags currently tracked in tagState_
    end

    properties (Access = private)
        timer_    = []
        tagState_          % containers.Map: key (char) -> struct('lastModTime', d, 'lastIndex', n)
    end

    methods
        function obj = LiveTagPipeline(varargin)
            %LIVETAGPIPELINE Construct with OutputDir (required) + options.
            %   p = LiveTagPipeline('OutputDir', dir)
            %   p = LiveTagPipeline('OutputDir', dir, 'Interval', 5, 'Verbose', true)
            %   p = LiveTagPipeline('OutputDir', dir, 'ErrorFcn', @(ex) ...)
            %
            %   Errors:
            %     TagPipeline:invalidOutputDir      -- OutputDir missing/empty/non-char
            %     TagPipeline:cannotCreateOutputDir -- mkdir failed
            opts = struct('OutputDir', '', 'Interval', 15, ...
                'ErrorFcn', [], 'Verbose', false);
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
        end

        function start(obj)
            %START Launch the polling timer and set Status='running'.
            if strcmp(obj.Status, 'running'), return; end
            obj.Status = 'running';
            obj.timer_ = timer('ExecutionMode', 'fixedSpacing', ...
                'Period',    obj.Interval, ...
                'TimerFcn',  @(~,~) obj.onTick_(), ...
                'ErrorFcn',  @(~,~) obj.onTimerError_());
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
        end

        function processed = processTag_(obj, t, rs, key, tickCache)
            %PROCESSTAG_ Handle one tag within a tick. Returns true iff a write occurred.
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
            if iscell(y)
                newY = y(newRange);
            else
                newY = y(newRange);
            end

            writeTagMat_(obj.OutputDir, t, newX, newY, 'append');

            state.lastModTime = modTime;
            state.lastIndex   = total;
            obj.tagState_(key) = state;
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
            %   Mirrors BatchTagPipeline.isIngestable_ semantics via an
            %   anonymous-function predicate passed to TagRegistry.find.
            %   The lambda body is fully inlined (not a delegation to a
            %   private static method) so Octave's private-method access
            %   check is never triggered -- the predicate evaluates
            %   entirely in anonymous-function scope and needs no
            %   class-private visibility.
            %
            %   D-16 / Pitfall 10 discipline: positive-isa checks only
            %   (SensorTag || StateTag); NEVER a negative check against
            %   Monitor/Composite.  The inline body here must stay
            %   byte-semantically identical to
            %   BatchTagPipeline.isIngestable_ in the companion class --
            %   adding a new eligible tag kind requires updating BOTH
            %   sites in lockstep.
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

end
