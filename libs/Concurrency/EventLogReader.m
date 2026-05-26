classdef EventLogReader < handle
%EVENTLOGREADER Read an EventLog NDJSON file with mtime cache and torn-read retry.
%
%   Composes:
%     - ndjsonDecode (Plan 1031-01) for corrupt-line-tolerant parsing
%     - AtomicWriter.readWithRetry (Phase 1029-04) for torn-rename window
%       tolerance (Pitfall 12: MAT v7.3 partial-read window)
%     - Per-instance mtime cache to skip redundant re-parses on unchanged files
%       (Pitfall 11 second-gate: hoisted from EventStore.loadFile's static
%       containers.Map pattern at libs/EventDetection/EventStore.m:181-223
%       into a per-instance class so multiple concurrent readers have
%       independent cache invalidation paths)
%
%   Construction:
%     r = EventLogReader(logPath)
%     r = EventLogReader(logPath, opts)   % opts.Retries  (default 3)
%                                         %      .BackoffMs (default 50)
%
%   Public API:
%     events                = r.readAll()
%     events                = r.tail(n)
%     [events, parseStats]  = r.readAllWithStats()
%     skipped               = r.SkippedLineCount       % cumulative across reads
%     hit                   = r.LastReadCacheHit       % logical
%     dur                   = r.LastReadDurationSec    % seconds
%
%   Notes:
%     - SkippedLineCount is cumulative — gives operators a way to track
%       corruption trends over time. Phase 1033 Companion UI may surface it
%       as a status badge.
%     - Cache stores allEvents (full file). Subsequent tail(m) for different m
%       operates on the cached full array without re-reading the file.
%     - File does not exist -> returns [] without error (not an error state).
%
%   See also ndjsonDecode, AtomicWriter, EventLog, SharedPaths.

    properties (SetAccess = private)
        LogPath              (1,:) char   = ''    % absolute path to .events.ndjson
        SkippedLineCount     (1,1) double = 0     % cumulative across all reads
        LastReadCacheHit     (1,1) logical = false % true iff last read was a cache hit
        LastReadDurationSec  (1,1) double = 0     % wall time of last read() call
    end

    properties (Access = private)
        Retries_    (1,1) double = 3
        BackoffMs_  (1,1) double = 50
        mtimeCache_                   % double scalar: datenum of last parse (NaN = never)
        eventsCache_                  % struct array (1xN) or [] from last successful parse
    end

    methods

        function obj = EventLogReader(logPath, opts)
            %EVENTLOGREADER Construct a reader for the given NDJSON log file.
            %   r = EventLogReader(logPath)
            %   r = EventLogReader(logPath, opts)
            %
            %   Input:
            %     logPath — char; absolute path to a *.events.ndjson file.
            %               File need not exist at construction time.
            %     opts    — (optional) struct with fields:
            %                 .Retries   (default 3)
            %                 .BackoffMs (default 50)
            if nargin < 1 || isempty(logPath)
                error('EventLogReader:invalidPath', ...
                    'logPath must be a non-empty char.');
            end
            if ~ischar(logPath)
                error('EventLogReader:invalidPath', ...
                    'logPath must be a non-empty char.');
            end
            if nargin < 2 || isempty(opts)
                opts = struct();
            end
            obj.LogPath    = logPath;
            obj.Retries_   = EventLogReader.optGet_(opts, 'Retries',   3);
            obj.BackoffMs_ = EventLogReader.optGet_(opts, 'BackoffMs', 50);
            obj.mtimeCache_  = NaN;
            obj.eventsCache_ = [];
        end

        function events = readAll(obj)
            %READALL Read all events from the log file.
            %   events = r.readAll()
            %
            %   Returns a struct array (1xN) or [] if the file does not exist
            %   or contains no valid events.  Uses mtime cache to skip re-parse
            %   of unchanged files.  Retries on torn-rename windows (Pitfall 12).
            events = obj.read_(Inf);
        end

        function events = tail(obj, n)
            %TAIL Return the last N events from the log file.
            %   events = r.tail(n)
            %
            %   If the file has fewer than n events, returns all events.
            %   Internally reads and caches the full file so subsequent
            %   tail(m) calls for different m avoid re-reading the file.
            if nargin < 2 || isempty(n)
                n = Inf;
            end
            events = obj.read_(n);
        end

        function [events, parseStats] = readAllWithStats(obj)
            %READALLWITHSTATS Read all events and return per-call parseStats.
            %   [events, parseStats] = r.readAllWithStats()
            %
            %   Always performs a fresh read (bypasses the mtime cache) so that
            %   parseStats reflects the current file content accurately.
            %   Use when diagnostics are needed (e.g. Phase 1033 Companion UI).
            %
            %   parseStats mirrors ndjsonDecode output:
            %     .SkippedLineCount  (double)
            %     .SkippedLines      (cell of {lineNo, rawText, errMsg} triples)
            parseStats = struct('SkippedLineCount', 0, 'SkippedLines', {{}});

            if ~isfile(obj.LogPath)
                events = [];
                return;
            end

            retryOpts = struct('Retries', obj.Retries_, 'BackoffMs', obj.BackoffMs_);

            % Use a containers.Map as a mutable-by-reference accumulator so that
            % the anonymous loader closure can write back parse statistics.
            % containers.Map is a handle class: mutations inside the closure are
            % visible to the outer scope (identical pattern to TestAtomicWriter line 119).
            acc = containers.Map({'count'}, {0});

            events = AtomicWriter.readWithRetry(obj.LogPath, ...
                @(p) EventLogReader.parseLog_(p, acc), retryOpts);

            parseStats.SkippedLineCount = acc('count');
            obj.SkippedLineCount = obj.SkippedLineCount + parseStats.SkippedLineCount;
        end

    end

    methods (Access = private)

        function events = read_(obj, n)
            %READ_ Shared implementation for readAll() and tail().
            t0 = tic();

            if ~isfile(obj.LogPath)
                events                  = [];
                obj.LastReadCacheHit    = false;
                obj.LastReadDurationSec = toc(t0);
                return;
            end

            % mtime cache gate — hoisted from EventStore.loadFile:181-205
            % (static containers.Map pattern) into a per-instance property so
            % multiple concurrent EventLogReader instances stay independent.
            info    = dir(obj.LogPath);
            modTime = info(1).datenum;

            if ~isnan(obj.mtimeCache_) && modTime <= obj.mtimeCache_
                % File unchanged since last successful parse.
                events                  = EventLogReader.trimTail_(obj.eventsCache_, n);
                obj.LastReadCacheHit    = true;
                obj.LastReadDurationSec = toc(t0);
                return;
            end

            % Parse with retry on torn-rename window (Pitfall 12).
            % containers.Map is a handle class: the anonymous loader mutates it;
            % the outer scope reads the final SkippedLineCount after readWithRetry
            % returns. This avoids nested functions (not valid in classdef methods).
            retryOpts = struct('Retries', obj.Retries_, 'BackoffMs', obj.BackoffMs_);
            skipMap = containers.Map({'count'}, {0});

            allEvents = AtomicWriter.readWithRetry(obj.LogPath, ...
                @(p) EventLogReader.parseLog_(p, skipMap), retryOpts);

            obj.SkippedLineCount = obj.SkippedLineCount + skipMap('count');

            % Update cache AFTER successful parse.
            obj.mtimeCache_  = modTime;
            obj.eventsCache_ = allEvents;

            obj.LastReadCacheHit    = false;
            obj.LastReadDurationSec = toc(t0);

            events = EventLogReader.trimTail_(allEvents, n);
        end

    end

    methods (Static, Access = private)

        function out = parseLog_(p, skipMap)
            %PARSELOG_ Load NDJSON file and accumulate skip count via handle Map.
            %   Called by AtomicWriter.readWithRetry on each retry attempt.
            %   skipMap is a containers.Map handle (mutable reference).
            text = fileread(p);   % may throw mid-rename; readWithRetry catches
            [out, ps] = ndjsonDecode(text);
            skipMap('count') = skipMap('count') + ps.SkippedLineCount; %#ok<NASGU>
        end

        function out = trimTail_(events, n)
            %TRIMTAIL_ Return the last n elements of events, or all if numel <= n.
            if isempty(events) || isinf(n) || numel(events) <= n
                out = events;
                return;
            end
            out = events(end - n + 1:end);
        end

        function v = optGet_(opts, name, default)
            %OPTGET_ Extract a field from opts struct with fallback to default.
            if isstruct(opts) && isfield(opts, name)
                v = opts.(name);
            else
                v = default;
            end
        end

    end

end
