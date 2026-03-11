classdef IncrementalEventDetector < handle
    % IncrementalEventDetector  Wraps EventDetector with incremental state.
    %   Tracks last-processed index per sensor and carries over open events.

    properties
        MinDuration      = 0
        MaxCallsPerEvent = 1
        OnEventStart     = []
        EscalateSeverity = true
    end

    properties (Access = private)
        sensorState_     % containers.Map: key -> struct
    end

    methods
        function obj = IncrementalEventDetector(varargin)
            p = inputParser();
            p.addParameter('MinDuration', 0);
            p.addParameter('MaxCallsPerEvent', 1);
            p.addParameter('OnEventStart', []);
            p.addParameter('EscalateSeverity', true);
            p.parse(varargin{:});
            obj.MinDuration      = p.Results.MinDuration;
            obj.MaxCallsPerEvent = p.Results.MaxCallsPerEvent;
            obj.OnEventStart     = p.Results.OnEventStart;
            obj.EscalateSeverity = p.Results.EscalateSeverity;
            obj.sensorState_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function newEvents = process(obj, sensorKey, sensor, newX, newY, newStateX, newStateY)
            newEvents = Event.empty();
            if isempty(newX); return; end

            st = obj.getState(sensorKey);

            % Append new data
            st.fullX = [st.fullX, newX];
            st.fullY = [st.fullY, newY];

            % Update state channels if new state data
            if ~isempty(newStateX)
                st.stateX = [st.stateX, newStateX];
                st.stateY = [st.stateY, newStateY];
            end

            % Build a temporary sensor for detection on the full data
            tmpSensor = Sensor(sensorKey);
            tmpSensor.X = st.fullX;
            tmpSensor.Y = st.fullY;

            % Copy threshold rules from the source sensor
            for i = 1:numel(sensor.ThresholdRules)
                rule = sensor.ThresholdRules{i};
                tmpSensor.addThresholdRule(rule.Condition, rule.Value, ...
                    'Direction', rule.Direction, 'Label', rule.Label, ...
                    'Color', rule.Color, 'LineStyle', rule.LineStyle);
            end

            % Copy state channels — use accumulated state data
            for i = 1:numel(sensor.StateChannels)
                origSC = sensor.StateChannels{i};
                if ~isempty(st.stateX)
                    sc = StateChannel(origSC.Key);
                    sc.X = st.stateX;
                    sc.Y = st.stateY;
                else
                    sc = origSC;
                end
                tmpSensor.addStateChannel(sc);
            end

            tmpSensor.resolve();

            % Build detector
            det = EventDetector('MinDuration', obj.MinDuration, ...
                'MaxCallsPerEvent', obj.MaxCallsPerEvent);

            % Detect on full data using existing infrastructure
            allEvents = detectEventsFromSensor(tmpSensor, det);

            % Filter to only events that touch the new data window
            sliceStart = newX(1);
            relevantEvents = Event.empty();
            if ~isempty(allEvents)
                for i = 1:numel(allEvents)
                    ev = allEvents(i);
                    if ev.EndTime >= sliceStart
                        relevantEvents(end+1) = ev;
                    end
                end
            end

            % Handle open events
            completedEvents = Event.empty();
            newOpenEvent = [];

            for i = 1:numel(relevantEvents)
                ev = relevantEvents(i);
                if ev.EndTime >= newX(end) && ...
                   obj.isViolationAtEnd(st.fullY, ev)
                    % Event is still ongoing at end of this batch
                    newOpenEvent = ev;
                else
                    % Check if this merges with previous open event
                    if ~isempty(st.openEvent) && ...
                       strcmp(ev.ThresholdLabel, st.openEvent.ThresholdLabel) && ...
                       ev.StartTime <= st.openEvent.EndTime + 1/86400
                        % Merge: use earlier start, recompute stats
                        merged = Event(st.openEvent.StartTime, ev.EndTime, ...
                            ev.SensorName, ev.ThresholdLabel, ev.ThresholdValue, ev.Direction);
                        idx1 = find(st.fullX >= st.openEvent.StartTime, 1);
                        idx2 = find(st.fullX <= ev.EndTime, 1, 'last');
                        window = st.fullY(idx1:idx2);
                        merged = obj.computeAndSetStats(merged, window, ev.Direction);
                        completedEvents(end+1) = merged;
                    elseif ~obj.isOldEvent(ev, st.lastProcessedTime)
                        completedEvents(end+1) = ev;
                    end
                end
            end

            % Finalize previous open event if it didn't merge
            if ~isempty(st.openEvent) && isempty(completedEvents)
                % Check if open event ended in this batch
                if ~isempty(newOpenEvent) && ...
                   strcmp(newOpenEvent.ThresholdLabel, st.openEvent.ThresholdLabel)
                    % Still open, carry forward
                else
                    % Open event ended
                    completedEvents(end+1) = st.openEvent;
                end
            end

            % Escalate severity
            if obj.EscalateSeverity && ~isempty(completedEvents)
                completedEvents = obj.escalate(completedEvents, sensor);
            end

            % Update state
            st.openEvent = newOpenEvent;
            st.lastProcessedTime = newX(end);
            obj.sensorState_(sensorKey) = st;

            % Fire callbacks
            for i = 1:numel(completedEvents)
                if ~isempty(obj.OnEventStart)
                    obj.OnEventStart(completedEvents(i));
                end
            end

            newEvents = completedEvents;
        end

        function tf = hasOpenEvent(obj, sensorKey)
            tf = false;
            if obj.sensorState_.isKey(sensorKey)
                st = obj.sensorState_(sensorKey);
                tf = ~isempty(st.openEvent);
            end
        end

        function st = getSensorState(obj, sensorKey)
            st = obj.getState(sensorKey);
        end
    end

    methods (Access = private)
        function st = getState(obj, key)
            if obj.sensorState_.isKey(key)
                st = obj.sensorState_(key);
            else
                st = struct('fullX', [], 'fullY', [], ...
                    'stateX', [], 'stateY', {{}}, ...
                    'openEvent', [], 'lastProcessedTime', 0);
                obj.sensorState_(key) = st;
            end
        end

        function tf = isViolationAtEnd(~, fullY, ev)
            % Check if the last data point is still in violation
            lastVal = fullY(end);
            if strcmp(ev.Direction, 'high')
                tf = lastVal > ev.ThresholdValue;
            else
                tf = lastVal < ev.ThresholdValue;
            end
        end

        function tf = isOldEvent(~, ev, lastProcessedTime)
            tf = ev.EndTime <= lastProcessedTime;
        end

        function ev = computeAndSetStats(~, ev, window, direction)
            nPts = numel(window);
            minVal = min(window);
            maxVal = max(window);
            meanVal = mean(window);
            rmsVal = sqrt(mean(window.^2));
            stdVal = std(window);
            if strcmp(direction, 'high')
                peakVal = maxVal;
            else
                peakVal = minVal;
            end
            ev = ev.setStats(peakVal, nPts, minVal, maxVal, meanVal, rmsVal, stdVal);
        end

        function events = escalate(~, events, sensor)
            for i = 1:numel(events)
                ev = events(i);
                for j = 1:numel(sensor.ThresholdRules)
                    rule = sensor.ThresholdRules{j};
                    % Map direction: ThresholdRule uses upper/lower, Event uses high/low
                    ruleDir = rule.Direction;
                    if strcmp(ruleDir, 'upper')
                        evDir = 'high';
                    else
                        evDir = 'low';
                    end
                    if ~strcmp(evDir, ev.Direction)
                        continue;
                    end
                    if strcmp(ev.Direction, 'high') && rule.Value > ev.ThresholdValue && ...
                       ~isempty(ev.PeakValue) && ev.PeakValue > rule.Value
                        events(i) = ev.escalateTo(rule.Label, rule.Value);
                        ev = events(i);
                    elseif strcmp(ev.Direction, 'low') && rule.Value < ev.ThresholdValue && ...
                       ~isempty(ev.PeakValue) && ev.PeakValue < rule.Value
                        events(i) = ev.escalateTo(rule.Label, rule.Value);
                        ev = events(i);
                    end
                end
            end
        end
    end
end
