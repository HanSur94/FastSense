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

    properties (Access = private)
        timer_
        cycleCount_     = 0
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
        end

        function start(obj)
            if strcmp(obj.Status, 'running'); return; end
            obj.Status = 'running';
            obj.timer_ = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', obj.Interval, ...
                'TimerFcn', @(~,~) obj.timerCallback(), ...
                'ErrorFcn', @(~,~) obj.timerError());
            start(obj.timer_);
            fprintf('[PIPELINE] Started (interval=%ds)\n', obj.Interval);
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
            obj.cycleCount_ = obj.cycleCount_ + 1;
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
                            allNewEvents = [allNewEvents, newEvents];
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
end
