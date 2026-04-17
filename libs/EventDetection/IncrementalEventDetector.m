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

        function newEvents = process(~, ~, ~, ~, ~, ~, ~) %#ok<STOUT>
            %PROCESS Legacy entry point -- no longer functional.
            %   The Sensor/Threshold/StateChannel pipeline this method relied
            %   on was deleted in Phase 1011.  LiveEventPipeline now uses
            %   MonitorTag.appendData() for incremental detection (Phase 1007
            %   MONITOR-08).  This stub remains so that callers get a clear
            %   error rather than a missing-method crash.
            error('IncrementalEventDetector:legacyRemoved', ...
                ['process() depended on the deleted Sensor/Threshold pipeline. ', ...
                 'Use MonitorTag.appendData() for incremental detection.']);
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

        function events = escalate(~, events, ~)
            %ESCALATE Legacy severity escalation -- no-op after Phase 1011 cleanup.
            %   Threshold-based severity escalation was removed with the
            %   legacy Sensor/Threshold pipeline.  Returns events unchanged.
        end
    end
end
