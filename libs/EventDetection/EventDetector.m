classdef EventDetector < handle
    %EVENTDETECTOR Detects events from threshold violations.
    %   det = EventDetector()
    %   det = EventDetector('MinDuration', 2, 'OnEventStart', @myCallback)
    %
    %   Two call shapes for detect():
    %     events = det.detect(t, values, thresholdValue, direction, thresholdLabel, sensorName)   % LEGACY 6-arg
    %     events = det.detect(tag, threshold)                                                      % NEW v2.0 Tag overload
    %
    %   The Tag overload (Phase 1009 Plan 03) reads (X, Y) from
    %   tag.getXY() and derives threshold metadata from the Threshold
    %   handle; it then forwards to the same private detect_ body used
    %   by the legacy 6-arg path, so event semantics are identical.
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

        function events = detect(obj, varargin)
            %DETECT Find events from threshold violations.
            %   Two call shapes:
            %     events = det.detect(t, values, thresholdValue, direction, thresholdLabel, sensorName)   % LEGACY
            %     events = det.detect(tag, threshold)                                                      % NEW v2.0 Tag overload
            %
            %   The Tag overload pulls (t, values) from tag.getXY() and
            %   derives (thresholdValue, direction, thresholdLabel,
            %   sensorName) from the Threshold + Tag handles, then
            %   forwards to the private detect_() body.  The legacy 6-arg
            %   path is preserved byte-for-byte.

            if numel(varargin) == 2 && isa(varargin{1}, 'Tag') ...
                    && isa(varargin{2}, 'Threshold')
                tag       = varargin{1};
                threshold = varargin{2};
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
                return;
            end

            % Legacy 6-arg shape — forward verbatim.
            events = obj.detect_(varargin{:});
        end
    end

    methods (Access = private)
        function events = detect_(obj, t, values, thresholdValue, direction, thresholdLabel, sensorName)
            %DETECT_ Legacy 6-arg detection body (byte-for-byte preserved).
            %   Private implementation shared by both the legacy 6-arg
            %   detect() call and the Tag-overload dispatch.

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
