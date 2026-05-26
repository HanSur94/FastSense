classdef PlantLogLiveTail < handle
%PLANTLOGLIVETAIL Periodic re-read live-tail timer for plant-log files.
%   Re-reads SourcePath on every tick via PlantLogReader.openInteractive
%   in Headless mode and appends new entries to the bound PlantLogStore.
%   PlantLogStore's silent dedup keeps duplicates out across re-reads
%   (PLOG-LT-02).
%
%   Constructor:
%     tail = PlantLogLiveTail(store, sourcePath, mapping)
%     tail = PlantLogLiveTail(store, sourcePath, mapping, 'Interval', S)
%     tail = PlantLogLiveTail(store, sourcePath, mapping, 'StartImmediately', true)
%
%   Required positional arguments:
%     store        PlantLogStore handle (validated via isa)
%     sourcePath   non-empty char/string path to a CSV/XLSX file
%     mapping      struct with TimestampColumn + MessageColumn fields
%                  (TimestampFormat field optional; defaults to '')
%
%   Name-value options:
%     'Interval'           positive finite numeric scalar (seconds; default 5)
%     'StartImmediately'   logical (default false); if true, calls start()
%                          at end of construction
%
%   Public API:
%     start()                -- create + start the timer (idempotent)
%     stop()                 -- stop + delete the timer (idempotent)
%     tf = isRunning()       -- returns true while Status == 'running'
%     s = getInterval()      -- returns current Interval (seconds)
%     setInterval(seconds)   -- update Interval; if running, restarts the timer cleanly
%     n = getErrorCount()    -- returns cumulative tick error count
%     delete()               -- destructor: stops timer + cleans Listeners_
%
%   Hidden test seam:
%     tick_()                -- run one tick worth of work synchronously
%                               (callable from tests; bypasses timer events)
%
%   Events:
%     PlantLogTailTick       -- fired after EVERY tick (success or error).
%                               Payload: PlantLogTailEventData with fields
%                               Time, EntriesAdded, TotalCount, ErrorCount.
%
%   Errors:
%     PlantLogLiveTail:invalidInput     -- bad store / sourcePath / mapping / Interval
%     PlantLogLiveTail:unknownOption    -- unrecognized name-value key in constructor
%     PlantLogLiveTail:tickError        -- raised as warning() (not error) on
%                                          per-tick parse/IO failures so the
%                                          timer keeps running (PLOG-LT-05)
%
%   Cleanup contract (PLOG-LT-04):
%     stop() and delete() must leave timerfindall() count at the baseline
%     (no orphan timers attributable to PlantLogLiveTail). Achieved via the
%     `stop(t); delete(t);` ordering inside an outer try/catch, mirroring
%     LiveEventPipeline's precedent.
%
%   Example:
%     s = PlantLogStore('plant.csv');
%     m = struct('TimestampColumn', 'timestamp', ...
%                'MessageColumn',   'message', ...
%                'TimestampFormat', '');
%     tail = PlantLogLiveTail(s, 'plant.csv', m, ...
%         'Interval', 5, 'StartImmediately', true);
%     listener = addlistener(tail, 'PlantLogTailTick', ...
%         @(src, ed) fprintf('tick: +%d (total=%d)\n', ed.EntriesAdded, ed.TotalCount));
%     % ... time passes; rows append to plant.csv; ticks fire ...
%     tail.stop();
%     delete(tail);
%
%   See also PlantLogStore, PlantLogReader, PlantLogTailEventData,
%   LiveEventPipeline.

    events
        PlantLogTailTick  % payload: PlantLogTailEventData(Time, EntriesAdded, TotalCount, ErrorCount)
    end

    properties (SetAccess = private)
        SourcePath = ''
        Status     = 'stopped'
        Interval   = 5
    end

    properties (Access = private)
        Store_       = []        % PlantLogStore handle
        SourcePath_  = ''        % char (mirror of public SourcePath; private trailing-underscore convention)
        Mapping_     = struct()  % mapping struct passed to PlantLogReader.openInteractive
        timer_       = []        % MATLAB timer handle
        ErrorCount_  = 0         % cumulative tick errors
        Listeners_   = {}        % reserved for future addlistener hookups; cleared on delete
    end

    methods
        function obj = PlantLogLiveTail(store, sourcePath, mapping, varargin)
            %PLANTLOGLIVETAIL Construct a live-tail timer bound to (store, sourcePath, mapping).

            % --- Validate positional args ---
            if nargin < 3
                error('PlantLogLiveTail:invalidInput', ...
                    'PlantLogLiveTail requires (store, sourcePath, mapping).');
            end
            if ~isa(store, 'PlantLogStore')
                error('PlantLogLiveTail:invalidInput', ...
                    'store must be a PlantLogStore; got %s.', class(store));
            end
            if isstring(sourcePath)
                sourcePath = char(sourcePath);
            end
            if ~ischar(sourcePath) || isempty(sourcePath)
                error('PlantLogLiveTail:invalidInput', ...
                    'sourcePath must be a non-empty char/string.');
            end
            if ~isstruct(mapping) || ~isfield(mapping, 'TimestampColumn') || ...
                    ~isfield(mapping, 'MessageColumn')
                error('PlantLogLiveTail:invalidInput', ...
                    'mapping must be a struct with TimestampColumn + MessageColumn fields.');
            end

            % --- Parse name-value options ---
            opts = struct('Interval', 5, 'StartImmediately', false);
            if mod(numel(varargin), 2) ~= 0
                error('PlantLogLiveTail:invalidInput', ...
                    'Name-value pairs must come in pairs; got %d.', numel(varargin));
            end
            validKeys = fieldnames(opts);
            for k = 1:2:numel(varargin)
                key = varargin{k};
                if isstring(key)
                    key = char(key);
                end
                if ~ischar(key)
                    error('PlantLogLiveTail:invalidInput', ...
                        'Option key at position %d must be char.', k);
                end
                idx = find(strcmpi(validKeys, key), 1);
                if isempty(idx)
                    error('PlantLogLiveTail:unknownOption', ...
                        'Unknown option ''%s''. Valid: %s.', key, strjoin(validKeys, ', '));
                end
                opts.(validKeys{idx}) = varargin{k+1};
            end
            if ~isnumeric(opts.Interval) || ~isscalar(opts.Interval) || ...
                    ~isfinite(opts.Interval) || opts.Interval <= 0
                error('PlantLogLiveTail:invalidInput', ...
                    'Interval must be a positive finite numeric scalar.');
            end

            obj.Store_      = store;
            obj.SourcePath_ = sourcePath;
            obj.SourcePath  = sourcePath;
            obj.Mapping_    = mapping;
            obj.Interval    = double(opts.Interval);

            if logical(opts.StartImmediately)
                obj.start();
            end
        end

        function start(obj)
            %START Create and start the periodic re-read timer (idempotent).
            if strcmp(obj.Status, 'running')
                return;
            end
            obj.Status = 'running';
            obj.timer_ = timer('ExecutionMode', 'fixedSpacing', ...
                'Period',    obj.Interval, ...
                'TimerFcn',  @(~,~) obj.timerCallback_(), ...
                'ErrorFcn',  @(~,~) obj.timerError_());
            start(obj.timer_);
        end

        function stop(obj)
            %STOP Stop and delete the timer (idempotent).
            if ~isempty(obj.timer_)
                try
                    if isvalid(obj.timer_)
                        stop(obj.timer_);
                        delete(obj.timer_);
                    end
                catch
                end
            end
            obj.timer_ = [];
            obj.Status = 'stopped';
        end

        function tf = isRunning(obj)
            %ISRUNNING True while Status == 'running'.
            tf = strcmp(obj.Status, 'running');
        end

        function s = getInterval(obj)
            %GETINTERVAL Return the current re-read interval in seconds.
            s = obj.Interval;
        end

        function setInterval(obj, seconds)
            %SETINTERVAL Update Interval; restarts the timer cleanly if running.
            if ~isnumeric(seconds) || ~isscalar(seconds) || ...
                    ~isfinite(seconds) || seconds <= 0
                error('PlantLogLiveTail:invalidInput', ...
                    'Interval must be a positive finite numeric scalar.');
            end
            wasRunning = obj.isRunning();
            if wasRunning
                obj.stop();
            end
            obj.Interval = double(seconds);
            if wasRunning
                obj.start();
            end
        end

        function n = getErrorCount(obj)
            %GETERRORCOUNT Return cumulative parse error count since construction.
            n = obj.ErrorCount_;
        end

        function delete(obj)
            %DELETE Destructor: stops timer (idempotent) and cleans Listeners_.
            obj.stop();
            for k = 1:numel(obj.Listeners_)
                try
                    if ~isempty(obj.Listeners_{k}) && isvalid(obj.Listeners_{k})
                        delete(obj.Listeners_{k});
                    end
                catch
                end
            end
            obj.Listeners_ = {};
        end
    end

    methods (Hidden)
        function tick_(obj)
            %TICK_ Hidden test seam: run one tick worth of work synchronously.
            %   Calls PlantLogReader.openInteractive in Headless mode, forwards
            %   non-empty entries to Store_.addEntries, and notifies the
            %   PlantLogTailTick event with a typed payload. Errors are
            %   caught + surfaced as warnings; ErrorCount_ is incremented.
            entriesAdded = 0;
            try
                entries = PlantLogReader.openInteractive( ...
                    obj.SourcePath_, 'Headless', true, 'Mapping', obj.Mapping_);
                if ~isempty(entries)
                    obj.Store_.addEntries(entries);
                    entriesAdded = numel(entries);
                end
            catch err
                obj.ErrorCount_ = obj.ErrorCount_ + 1;
                warning('PlantLogLiveTail:tickError', '%s', err.message);
            end
            payload = struct( ...
                'Time',         now, ...
                'EntriesAdded', entriesAdded, ...
                'TotalCount',   obj.Store_.getCount(), ...
                'ErrorCount',   obj.ErrorCount_);
            try
                notify(obj, 'PlantLogTailTick', PlantLogTailEventData(payload));
            catch
                % Octave fallback: weaker event.EventData support means
                % constructing PlantLogTailEventData may fail. Fall through
                % to a payload-less notify so listeners still fire.
                notify(obj, 'PlantLogTailTick');
            end
        end
    end

    methods (Access = private)
        function timerCallback_(obj)
            %TIMERCALLBACK_ Internal timer TimerFcn; just dispatches to tick_.
            obj.tick_();
        end

        function timerError_(obj)
            %TIMERERROR_ Internal timer ErrorFcn; bumps counter + sets status.
            obj.ErrorCount_ = obj.ErrorCount_ + 1;
            obj.Status = 'error';
        end
    end
end
