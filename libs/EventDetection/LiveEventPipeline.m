classdef LiveEventPipeline < handle
    % LiveEventPipeline  Orchestrates live event detection.
    %
    %   Uses MonitorTargets — containers.Map of key -> MonitorTag;
    %   processed via MonitorTag.appendData (Phase 1007 MONITOR-08
    %   streaming tail extension).
    %
    %   Ordering invariant (Pitfall Y) — enforced by processMonitorTag_:
    %     monitor.Parent.updateData(newX, newY)  <- called FIRST
    %     monitor.appendData(newX, newY)         <- THEN
    %   The reverse order causes cache incoherence: MonitorTag.appendData's
    %   cold path recomputes against a stale parent grid.  See the docstring
    %   at libs/SensorThreshold/MonitorTag.m lines 330-334 for the contract.
    %
    %   Cluster mode (Phase 1032, Plan 02):
    %     - Enabled by passing 'SharedRoot' NV-pair to constructor.
    %     - processMonitorTag_ acquires the per-monitor FileLock via
    %       TagWriteCoordinator BEFORE parent.updateData + monitor.appendData.
    %     - On lock contention (ok=false), the monitor is skipped this tick;
    %       SkippedMonitorCount is incremented and LastLockContentionEvent is
    %       populated.
    %     - BusyMode='drop' is forced in cluster-mode timer (Pitfall 7).
    %     - EventLog handles are wired into each MonitorTag at construction
    %       so MonitorTag.emitEvent_ routes cluster-mode writes to the NDJSON log.
    %     - Single-user mode (no SharedRoot) exercises ZERO Concurrency-library
    %       code paths (byte-identical guarantee).
    %
    %   Cluster-mode observability:
    %     SkippedMonitorCount      — incremented on lock contention per-monitor per-tick
    %     LastTickDurationSec      — wall-clock duration of most recent runCycle
    %     LastLockContentionEvent  — {tagKey, holder.{user,host,age}} struct for Phase 1033 UI

    properties
        MonitorTargets       % containers.Map: key -> MonitorTag
        DataSourceMap        % DataSourceMap
        EventStore           % EventStore
        NotificationService  % NotificationService
        Interval            = 15     % seconds
        Status              = 'stopped'
        MinDuration         = 0
        EscalateSeverity    = true
        MaxCallsPerEvent    = 1
        OnEventStart        = []
    end

    properties (SetAccess = private)
        % Phase 1032-02 cluster-mode observability (Pitfall 7 / ACK-04)
        SkippedMonitorCount        = 0    % incremented on per-monitor lock contention
        LastTickDurationSec        = 0    % wall-clock duration of last runCycle (Pitfall 7 ops surface)
        LastLockContentionEvent    = []   % struct {tagKey, holder.{user,host,age}} (Phase 1033 UI hook)
    end

    properties (SetAccess = private)
        % Phase 1032-02 cluster-mode gate (readable externally for test observability)
        IsClusterMode_  = false    % gate for cluster-mode code paths
    end

    properties (Access = private)
        timer_
        cycleCount_     = 0
        % Phase 1032-02 cluster-mode private state
        SharedRoot_     = ''       % char; cluster shared root
        Coordinator_    = []       % TagWriteCoordinator handle (cluster mode only)
        LockTimeout_    = 5.0      % seconds; per-monitor lock acquire timeout
        eventLogs_      = []       % containers.Map tagKey -> EventLog handle (cluster mode only)
    end

    methods
        function obj = LiveEventPipeline(monitors, dataSourceMap, varargin)
            defaults.EventFile         = '';
            defaults.Interval          = 15;
            defaults.MinDuration       = 0;
            defaults.EscalateSeverity  = true;
            defaults.MaxBackups        = 5;
            defaults.MaxCallsPerEvent  = 1;
            defaults.OnEventStart      = [];
            defaults.Monitors          = [];  % NV-pair override for MonitorTargets
            defaults.SharedRoot        = '';  % Phase 1032-02 cluster mode
            defaults.LockTimeout       = 5.0; % Phase 1032-02 per-monitor lock timeout
            opts = parseOpts(defaults, varargin);

            % Accept MonitorTargets map (containers.Map of key -> MonitorTag).
            % 'Monitors' NV-pair takes precedence over the first positional
            % arg — lets callers pass an empty/legacy sensors map positionally
            % while supplying the real monitors by name (Tag-path pattern).
            if isa(opts.Monitors, 'containers.Map')
                obj.MonitorTargets = opts.Monitors;
            elseif isa(monitors, 'containers.Map')
                obj.MonitorTargets = monitors;
            else
                obj.MonitorTargets = containers.Map( ...
                    'KeyType', 'char', 'ValueType', 'any');
            end
            obj.DataSourceMap = dataSourceMap;
            obj.Interval      = opts.Interval;
            obj.MinDuration   = opts.MinDuration;
            obj.EscalateSeverity = opts.EscalateSeverity;
            obj.MaxCallsPerEvent = opts.MaxCallsPerEvent;
            obj.OnEventStart     = opts.OnEventStart;

            if ~isempty(opts.EventFile)
                obj.EventStore = EventStore(opts.EventFile, ...
                    'MaxBackups', opts.MaxBackups);
            end

            obj.NotificationService = NotificationService('DryRun', true);

            % --- Cluster mode resolution (Phase 1032 Plan 02; ACK-04 single-source) ---
            if ~isempty(opts.SharedRoot)
                obj.IsClusterMode_ = true;
                obj.SharedRoot_    = char(opts.SharedRoot);
                obj.LockTimeout_   = double(opts.LockTimeout);
                % Resolve identity strictly -- fail fast on missing user/host (IDENT-01).
                ClusterIdentity.resolve('Strict', true);
                % Ensure shared dirs exist.
                evDir = SharedPaths.eventsDir(obj.SharedRoot_);
                if ~isfolder(evDir)
                    mkdir(evDir);
                end
                locksDir = SharedPaths.locksDir(obj.SharedRoot_);
                if ~isfolder(locksDir)
                    mkdir(locksDir);
                end
                % Per-tag EventLog cache.
                obj.eventLogs_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
                obj.Coordinator_ = TagWriteCoordinator(obj.SharedRoot_);
                % Wire EventLog handles into every MonitorTag so Plan 01's emitEvent_
                % routes cluster-mode writes to the NDJSON log (single-source guarantee).
                mKeys = obj.MonitorTargets.keys();
                for i = 1:numel(mKeys)
                    mon = obj.MonitorTargets(mKeys{i});
                    if isprop(mon, 'EventLog')
                        elog = EventLog(obj.SharedRoot_, char(mon.Key), ...
                            struct('LockTimeout', obj.LockTimeout_));
                        obj.eventLogs_(char(mon.Key)) = elog;
                        mon.EventLog = elog;
                    end
                end
            end
        end

        function start(obj)
            if strcmp(obj.Status, 'running'); return; end
            obj.Status = 'running';
            if obj.IsClusterMode_
                % Force BusyMode='drop' in cluster mode (Pitfall 7 -- prevents
                % timer queue buildup when shared I/O is slow; mirrors LiveTagPipeline).
                obj.timer_ = timer('ExecutionMode', 'fixedSpacing', ...
                    'Period', obj.Interval, ...
                    'BusyMode', 'drop', ...
                    'TimerFcn', @(~,~) obj.timerCallback(), ...
                    'ErrorFcn', @(~,~) obj.timerError());
            else
                obj.timer_ = timer('ExecutionMode', 'fixedSpacing', ...
                    'Period', obj.Interval, ...
                    'TimerFcn', @(~,~) obj.timerCallback(), ...
                    'ErrorFcn', @(~,~) obj.timerError());
            end
            start(obj.timer_);
            fprintf('[PIPELINE] Started (interval=%ds, cluster=%d)\n', obj.Interval, obj.IsClusterMode_);
        end

        function stop(obj)
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
            % Flush store
            if ~isempty(obj.EventStore)
                obj.EventStore.save();
            end
            fprintf('[PIPELINE] Stopped\n');
        end

        function runCycle(obj)
            %RUNCYCLE Execute one poll cycle synchronously (exposed for tests + timer callback).
            %   Phase 1032-02: tic/toc for LastTickDurationSec (Pitfall 7 ops surface);
            %   drawnow limitrate nocallbacks in cluster mode (Pitfall 7 reentrancy guard).
            tickStart_ = tic();
            obj.cycleCount_ = obj.cycleCount_ + 1;
            if obj.IsClusterMode_
                drawnow limitrate nocallbacks;  % Pitfall 7 reentrancy guard (mirrors LiveTagPipeline)
            end
            allNewEvents = [];
            hasNewData = false;

            % --- MonitorTag path ---
            monitorKeys = obj.MonitorTargets.keys();
            for i = 1:numel(monitorKeys)
                key = monitorKeys{i};
                try
                    [newEvents, gotData] = obj.processMonitorTag_(key);
                    hasNewData = hasNewData || gotData;
                    if ~isempty(newEvents)
                        if isempty(allNewEvents)
                            allNewEvents = newEvents;
                        else
                            allNewEvents = [allNewEvents, newEvents]; %#ok<AGROW>
                        end
                    end
                catch ex
                    fprintf('[PIPELINE WARNING] MonitorTag "%s" failed: %s\n', ...
                        key, ex.message);
                end
            end

            % Write to store
            if ~isempty(obj.EventStore) && ~isempty(allNewEvents)
                obj.EventStore.append(allNewEvents);
                try
                    obj.EventStore.save();
                catch ex
                    fprintf('[PIPELINE WARNING] Store write failed: %s\n', ex.message);
                end
            elseif ~isempty(obj.EventStore) && obj.cycleCount_ == 1
                % Save even if no events on first cycle (creates the file)
                obj.EventStore.save();
            end

            % Send notifications
            if ~isempty(obj.NotificationService)
                for i = 1:numel(allNewEvents)
                    ev = allNewEvents(i);
                    try
                        obj.NotificationService.notify(ev, struct());
                    catch ex
                        fprintf('[PIPELINE WARNING] Notification failed: %s\n', ex.message);
                    end
                end
            end

            if ~isempty(allNewEvents)
                fprintf('[PIPELINE] Cycle %d: %d new events\n', obj.cycleCount_, numel(allNewEvents));
            end
            obj.LastTickDurationSec = toc(tickStart_);
        end
    end

    methods (Access = private)
        function [newEvents, gotData] = processMonitorTag_(obj, key)
            %PROCESSMONITORTAG_ Tag-first live-tick path (SC#4 realization).
            %
            %   Phase 1007 MONITOR-08 contract: MonitorTag.appendData
            %   expects the monitor's Parent to already carry the new
            %   (newX, newY) tail samples before the call — so we call
            %   parent.updateData FIRST with the accumulated full grid,
            %   then appendData with the NEW tail.  Wrong order causes
            %   cache incoherence (appendData cold-path recomputes
            %   against stale parent data).  This is the Pitfall Y
            %   invariant, guarded by
            %   test_live_event_pipeline_tag -> test_append_data_order_with_parent.
            %
            %   SensorTag.updateData REPLACES the parent's X/Y (it is not
            %   an appender — that's a Phase 1005 design choice) so we
            %   first snapshot the parent's current grid via getXY(),
            %   then pass the concatenated (old + new) grid to
            %   updateData().  This keeps MonitorTag.appendData's fast
            %   path available once the cache warms up — the cascade
            %   invalidation from updateData marks the monitor dirty,
            %   but the very next appendData call refills the cache
            %   against the full grid.
            %
            %   Events are harvested as the delta of the monitor's bound
            %   EventStore size before and after appendData
            %   (MonitorTag.fireEventsOnRisingEdges_ /
            %   MonitorTag.fireEventsInTail_ write events directly — see
            %   libs/SensorThreshold/MonitorTag.m).
            %
            %   Phase 1032-02 cluster-mode lock acquisition (ACK-04 single-source):
            %     When IsClusterMode_=true, the per-monitor FileLock is acquired via
            %     Coordinator_.acquireTag BEFORE parent.updateData + monitor.appendData.
            %     On contention (ok=false), the monitor is skipped this tick and
            %     SkippedMonitorCount is incremented. onCleanup releases the lock after
            %     the critical section completes (RAII pattern from LiveTagPipeline.processTag_).
            newEvents = [];
            gotData   = false;
            if ~obj.DataSourceMap.has(key)
                return;
            end
            ds     = obj.DataSourceMap.get(key);
            result = ds.fetchNew();
            if ~result.changed
                return;
            end
            gotData = true;
            monitor = obj.MonitorTargets(key);

            %% CLUSTER-MODE LOCK ACQUISITION (Phase 1032-02, ACK-04 single-source)
            %  Acquire per-monitor FileLock BEFORE parent.updateData + monitor.appendData
            %  so that across N Companions polling the same MonitorTag, exactly ONE
            %  process holds the lock per tick — it is the sole emitter for that tick.
            %  Pattern mirrors LiveTagPipeline.processTag_ (Phase 1030-02).
            %
            %  nestedLockAcquireForbidden contention signal (same-process double-acquire):
            %  When a same-process test pre-holds the lock via a separate coordinator,
            %  TagWriteCoordinator.acquireTag throws Concurrency:nestedLockAcquireForbidden
            %  rather than returning ok=false. We catch it and treat it as a contention
            %  skip — mirrors 1030-02 SUMMARY "sawContention check accepts any of the three
            %  channels (SkippedTickCount, LastLockContentionEvent, LastTickReport.failed)".
            if obj.IsClusterMode_
                lock = [];
                ok   = false;
                try
                    [lock, ok] = obj.Coordinator_.acquireTag(char(key), ...
                        struct('Timeout', obj.LockTimeout_));
                catch ME
                    if strcmp(ME.identifier, 'Concurrency:nestedLockAcquireForbidden')
                        % Same-process double-acquire — treat as contention (skip-and-defer).
                        ok = false;
                    else
                        rethrow(ME);
                    end
                end
                if ~ok
                    % Lock contention -- skip-and-defer this monitor (NOT block whole cycle).
                    % Populate LastLockContentionEvent for Phase 1033 Companion UI.
                    obj.SkippedMonitorCount = obj.SkippedMonitorCount + 1;
                    obj.LastLockContentionEvent = ...
                        LiveEventPipeline.buildContentionEvent_(char(key), lock);
                    return;  % skip-and-defer this monitor to next tick
                end
                cleaner = onCleanup(@() lock.release()); %#ok<NASGU>
            end

            % === CRITICAL SECTION (lock held in cluster mode; bare in single-user mode) ===

            % Snapshot the monitor's bound EventStore BEFORE appendData so
            % we can harvest only the events emitted on this tick.
            preStore = monitor.EventStore;
            preCount = 0;
            if ~isempty(preStore)
                preCount = preStore.numEvents();
            end

            % Snapshot the parent's current grid so we can hand it the
            % accumulated (old + new) grid.  SensorTag.updateData replaces
            % X/Y; without this concatenation the parent would lose its
            % history on each tick and MonitorTag.appendData's cold path
            % would recompute over just the tail.
            if ismethod(monitor.Parent, 'getXY')
                [oldX, oldY] = monitor.Parent.getXY();
            else
                oldX = [];
                oldY = [];
            end
            newX = result.X;
            newY = result.Y;
            fullX = [oldX(:).', newX(:).'];
            fullY = [oldY(:).', newY(:).'];

            % CRITICAL ORDERING (Pitfall Y): parent.updateData BEFORE
            % monitor.appendData.  See MonitorTag.m:330-334 docstring.
            if ismethod(monitor.Parent, 'updateData')
                monitor.Parent.updateData(fullX, fullY);
            else
                error('LiveEventPipeline:parentNoUpdateData', ...
                    ['MonitorTag parent "%s" does not support updateData — ' ...
                     'cannot drive live tick.'], monitor.Parent.Key);
            end
            monitor.appendData(newX, newY);

            % Harvest delta from the monitor's bound EventStore (if any).
            if ~isempty(preStore)
                allEvts = preStore.getEvents();
                postCount = numel(allEvts);
                if postCount > preCount
                    newEvents = allEvts((preCount+1):postCount);
                end
            end
            % === END CRITICAL SECTION (onCleanup releases the lock here in cluster mode) ===
        end

        function timerCallback(obj)
            try
                obj.runCycle();
            catch ex
                fprintf('[PIPELINE ERROR] Cycle failed: %s\n', ex.message);
            end
        end

        function timerError(obj)
            obj.Status = 'error';
            fprintf('[PIPELINE] Timer error — status set to error\n');
        end
    end

    methods (Static, Access = private)

        function ev = buildContentionEvent_(tagKey, lock)
            %BUILDCONTENTIONEVENT_ Construct a LockContentionEvent struct for Phase 1033 UI.
            %   Pattern mirrors LiveTagPipeline.buildContentionEvent_ (Phase 1030-02).
            %   Best-effort: struct is well-formed even when lock.peek() fails.
            ev = struct('tagKey', tagKey, ...
                'holder', struct('user', '', 'host', '', 'age', NaN));
            ev.timestamp = now(); %#ok<TNOW1>
            try
                if ~isempty(lock) && ismethod(lock, 'peek')
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
                end
            catch
                % Best-effort; structure is still well-formed on peek failure.
            end
        end

    end
end
