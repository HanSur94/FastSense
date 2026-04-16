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
            newEvents = [];
            if isempty(newX); return; end

            st = obj.getState(sensorKey);

            % Append new data (kept for EventViewer click-to-plot)
            st.fullX = [st.fullX, newX];
            st.fullY = [st.fullY, newY];

            % Update state channels if new state data
            if ~isempty(newStateX)
                st.stateX = [st.stateX, newStateX];
                st.stateY = [st.stateY, newStateY];
            end

            % Determine slice start: open event start or new data start
            if ~isempty(st.openEvent)
                sliceStart = st.openEvent.StartTime;
            else
                sliceStart = newX(1);
            end

            % Find slice index in accumulated data
            sliceIdx = binary_search(st.fullX, sliceStart, 'left');
            sliceX = st.fullX(sliceIdx:end);
            sliceY = st.fullY(sliceIdx:end);

            % Build a temporary sensor for detection on the slice
            tmpSensor = Sensor(sensorKey);
            tmpSensor.X = sliceX;
            tmpSensor.Y = sliceY;

            % Copy threshold handles from the source sensor
            for i = 1:numel(sensor.Thresholds)
                tmpSensor.addThreshold(sensor.Thresholds{i});
            end

            % Copy state channels — use accumulated state data (sliced)
            for i = 1:numel(sensor.StateChannels)
                origSC = sensor.StateChannels{i};
                if ~isempty(st.stateX)
                    sc = StateChannel(origSC.Key);
                    % Slice state data to match time window
                    stSliceIdx = binary_search(st.stateX, sliceStart, 'left');
                    sc.X = st.stateX(stSliceIdx:end);
                    sc.Y = st.stateY(stSliceIdx:end);
                else
                    sc = origSC;
                end
                tmpSensor.addStateChannel(sc);
            end

            tmpSensor.resolve();

            % Build detector
            det = EventDetector('MinDuration', obj.MinDuration, ...
                'MaxCallsPerEvent', obj.MaxCallsPerEvent);

            % Detect on slice using existing infrastructure
            allEvents = detectEventsFromSensor(tmpSensor, det);

            % Filter to only events that touch the new data window
            sliceStartTime = newX(1);
            relevantEvents = [];
            if ~isempty(allEvents)
                for i = 1:numel(allEvents)
                    ev = allEvents(i);
                    if ev.EndTime >= sliceStartTime
                        if isempty(relevantEvents)
                            relevantEvents = ev;
                        else
                            relevantEvents(end+1) = ev;
                        end
                    end
                end
            end

            % Handle open events
            completedEvents = [];
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
                        if isempty(completedEvents)
                            completedEvents = merged;
                        else
                            completedEvents(end+1) = merged;
                        end
                    elseif ~obj.isOldEvent(ev, st.lastProcessedTime)
                        if isempty(completedEvents)
                            completedEvents = ev;
                        else
                            completedEvents(end+1) = ev;
                        end
                    end
                end
            end

            % Finalize previous open event if it didn't merge
            if ~isempty(st.openEvent) && isempty(completedEvents)
                if ~isempty(newOpenEvent) && ...
                   strcmp(newOpenEvent.ThresholdLabel, st.openEvent.ThresholdLabel)
                    % Still open, carry forward
                else
                    % Open event ended
                    completedEvents = st.openEvent;
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
            if strcmp(ev.Direction, 'upper')
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
            if strcmp(direction, 'upper')
                peakVal = maxVal;
            else
                peakVal = minVal;
            end
            ev = ev.setStats(peakVal, nPts, minVal, maxVal, meanVal, rmsVal, stdVal);
        end

        function events = escalate(~, events, sensor)
            for i = 1:numel(events)
                ev = events(i);
                for j = 1:numel(sensor.Thresholds)
                    t = sensor.Thresholds{j};
                    if ~strcmp(t.Direction, ev.Direction)
                        continue;
                    end
                    tVals = t.allValues();
                    for k = 1:numel(tVals)
                        tVal = tVals(k);
                        if strcmp(ev.Direction, 'upper') && tVal > ev.ThresholdValue && ...
                           ~isempty(ev.PeakValue) && ev.PeakValue > tVal
                            ev.escalateTo(t.Name, tVal);
                        elseif strcmp(ev.Direction, 'lower') && tVal < ev.ThresholdValue && ...
                           ~isempty(ev.PeakValue) && ev.PeakValue < tVal
                            ev.escalateTo(t.Name, tVal);
                        end
                    end
                end
            end
        end
    end
end
