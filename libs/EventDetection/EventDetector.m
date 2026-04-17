classdef EventDetector < handle
    %EVENTDETECTOR Detects events from threshold violations.
    %   det = EventDetector()
    %   det = EventDetector('MinDuration', 2, 'OnEventStart', @myCallback)
    %
    %   Call shape:
    %     events = det.detect(tag, threshold)   % 2-arg Tag overload
    %
    %   Reads (X, Y) from tag.getXY() and derives threshold metadata
    %   from the Threshold handle; forwards to the private detect_ body.
    %   Dispatch is entry-level on isa(arg, 'Tag') — the ABSTRACT BASE —
    %   matching the FastSense.addTag precedent (Pitfall 1: NO subclass
    %   isa anywhere in this file).

    properties
        MinDuration      % numeric: minimum event duration (default 0)
        OnEventStart     % function handle: callback f(event) on new event
        MaxCallsPerEvent % numeric: max callback invocations per event (default 1)
    end

    methods
        function obj = EventDetector(varargin)
            obj.MinDuration = 0;
            obj.OnEventStart = [];
            obj.MaxCallsPerEvent = 1;

            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'MinDuration',      obj.MinDuration = varargin{i+1};
                    case 'OnEventStart',     obj.OnEventStart = varargin{i+1};
                    case 'MaxCallsPerEvent', obj.MaxCallsPerEvent = varargin{i+1};
                    otherwise
                        error('EventDetector:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end

        function events = detect(obj, tag, threshold)
            %DETECT Find events from threshold violations.
            %   events = det.detect(tag, threshold)
            %
            %   Pulls (t, values) from tag.getXY() and derives
            %   (thresholdValue, direction, thresholdLabel, sensorName)
            %   from the Threshold + Tag handles, then forwards to the
            %   private detect_() body.

            if ~isa(tag, 'Tag')
                error('EventDetector:invalidTag', ...
                    'First argument must be a Tag object; got %s.', class(tag));
            end

            [t, values] = tag.getXY();
            if isempty(t)
                events = [];
                return;
            end
            tVals = threshold.allValues();
            if isempty(tVals)
                events = [];
                return;
            end
            thresholdValue = tVals(1);
            direction      = threshold.Direction;
            thresholdLabel = threshold.Name;
            if isempty(thresholdLabel)
                thresholdLabel = threshold.Key;
            end
            sensorName = tag.Name;
            if isempty(sensorName)
                sensorName = tag.Key;
            end
            events = obj.detect_(t, values, thresholdValue, direction, ...
                thresholdLabel, sensorName);
        end
    end

    methods (Access = private)
        function events = detect_(obj, t, values, thresholdValue, direction, thresholdLabel, sensorName)
            %DETECT_ Core detection body.
            %   Private implementation used by the Tag-overload dispatch.

            groups = groupViolations(t, values, thresholdValue, direction);
            events = [];

            if isempty(groups)
                return;
            end

            for i = 1:numel(groups)
                si = groups(i).startIdx;
                ei = groups(i).endIdx;

                startTime = t(si);
                endTime   = t(ei);
                duration  = endTime - startTime;

                % Debounce filter
                if duration < obj.MinDuration
                    continue;
                end

                ev = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction);

                % Compute stats over all points in event window
                windowValues = values(si:ei);
                nPts    = numel(windowValues);
                minVal  = min(windowValues);
                maxVal  = max(windowValues);
                meanVal = mean(windowValues);
                rmsVal  = sqrt(mean(windowValues.^2));
                stdVal  = std(windowValues);

                if strcmp(direction, 'upper')
                    peakVal = maxVal;
                else
                    peakVal = minVal;
                end

                ev = ev.setStats(peakVal, nPts, minVal, maxVal, meanVal, rmsVal, stdVal);

                if isempty(events)
                    events = ev;
                else
                    events(end+1) = ev; %#ok<AGROW>
                end

                % Callback (MaxCallsPerEvent limits per-event; each event seen once)
                if ~isempty(obj.OnEventStart) && obj.MaxCallsPerEvent > 0
                    obj.OnEventStart(ev);
                end
            end
        end
    end
end
