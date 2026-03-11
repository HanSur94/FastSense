classdef LiveEventPipeline < handle
    % LiveEventPipeline  Orchestrates live event detection.

    properties
        Sensors              % containers.Map: key -> Sensor
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
        detector_       % IncrementalEventDetector
        cycleCount_     = 0
    end

    methods
        function obj = LiveEventPipeline(sensors, dataSourceMap, varargin)
            p = inputParser();
            p.addRequired('sensors');
            p.addRequired('dataSourceMap');
            p.addParameter('EventFile', '', @ischar);
            p.addParameter('Interval', 15, @isnumeric);
            p.addParameter('MinDuration', 0, @isnumeric);
            p.addParameter('EscalateSeverity', true, @islogical);
            p.addParameter('MaxBackups', 5, @isnumeric);
            p.addParameter('MaxCallsPerEvent', 1, @isnumeric);
            p.addParameter('OnEventStart', []);
            p.parse(sensors, dataSourceMap, varargin{:});

            obj.Sensors       = sensors;
            obj.DataSourceMap = dataSourceMap;
            obj.Interval      = p.Results.Interval;
            obj.MinDuration   = p.Results.MinDuration;
            obj.EscalateSeverity = p.Results.EscalateSeverity;
            obj.MaxCallsPerEvent = p.Results.MaxCallsPerEvent;
            obj.OnEventStart     = p.Results.OnEventStart;

            if ~isempty(p.Results.EventFile)
                obj.EventStore = EventStore(p.Results.EventFile, ...
                    'MaxBackups', p.Results.MaxBackups);
            end

            obj.detector_ = IncrementalEventDetector( ...
                'MinDuration', obj.MinDuration, ...
                'EscalateSeverity', obj.EscalateSeverity, ...
                'MaxCallsPerEvent', obj.MaxCallsPerEvent, ...
                'OnEventStart', obj.OnEventStart);

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
            allNewEvents = Event.empty();
            hasNewData = false;

            sensorKeys = obj.Sensors.keys();
            for i = 1:numel(sensorKeys)
                key = sensorKeys{i};
                try
                    [newEvents, gotData] = obj.processSensor(key);
                    hasNewData = hasNewData || gotData;
                    if ~isempty(newEvents)
                        allNewEvents = [allNewEvents, newEvents];
                    end
                catch ex
                    fprintf('[PIPELINE WARNING] Sensor "%s" failed: %s\n', key, ex.message);
                end
            end

            % Update sensor data in store only when new data arrived
            if ~isempty(obj.EventStore) && hasNewData
                obj.updateStoreSensorData();
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
                    sd = obj.buildSensorData(ev.SensorName);
                    try
                        obj.NotificationService.notify(ev, sd);
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
        function [newEvents, gotData] = processSensor(obj, key)
            newEvents = Event.empty();
            gotData = false;

            if ~obj.DataSourceMap.has(key)
                return;
            end

            ds = obj.DataSourceMap.get(key);
            result = ds.fetchNew();

            if ~result.changed
                return;
            end

            gotData = true;

            sensor = obj.Sensors(key);

            newEvents = obj.detector_.process(key, sensor, ...
                result.X, result.Y, result.stateX, result.stateY);
        end

        function sd = buildSensorData(obj, sensorKey)
            % Build sensorData struct for snapshot generation
            st = obj.detector_.getSensorState(sensorKey);
            sensor = obj.Sensors(sensorKey);

            thVal = NaN;
            thDir = 'upper';
            if ~isempty(sensor.ThresholdRules)
                thVal = sensor.ThresholdRules{1}.Value;
                thDir = sensor.ThresholdRules{1}.Direction;
            end

            sd = struct('X', st.fullX, 'Y', st.fullY, ...
                'thresholdValue', thVal, 'thresholdDirection', thDir);
        end

        function updateStoreSensorData(obj)
            % Build sensorData struct array from detector state for EventViewer
            sensorKeys = obj.Sensors.keys();
            sd = struct('name', {}, 't', {}, 'y', {}, 'thresholdRules', {});
            for i = 1:numel(sensorKeys)
                key = sensorKeys{i};
                st = obj.detector_.getSensorState(key);
                if ~isempty(st.fullX)
                    sd(end+1).name = key; %#ok<AGROW>
                    sd(end).t = st.fullX;
                    sd(end).y = st.fullY;
                    % Store threshold rules for reconstruction in EventViewer
                    sensor = obj.Sensors(key);
                    rules = {};
                    for j = 1:numel(sensor.ThresholdRules)
                        r = sensor.ThresholdRules{j};
                        rules{j} = struct('Value', r.Value, ...
                            'Direction', r.Direction, ...
                            'Label', r.Label, ...
                            'Color', r.Color, ...
                            'LineStyle', r.LineStyle); %#ok<AGROW>
                    end
                    sd(end).thresholdRules = rules;
                end
            end
            obj.EventStore.SensorData = sd;
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
