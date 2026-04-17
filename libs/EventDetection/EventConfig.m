classdef EventConfig < handle
    %EVENTCONFIG Configuration for the event detection system.
    %   cfg = EventConfig()
    %   cfg.MinDuration = 2;
    %   cfg.addSensor(sensor);
    %   events = cfg.runDetection();

    properties
        Sensors           % cell array of Sensor objects
        SensorData        % struct array: name, t, y (for viewer click-to-plot)
        MinDuration       % numeric: debounce (default 0)
        MaxCallsPerEvent  % numeric: callback limit (default 1)
        OnEventStart      % function handle: callback
        ThresholdColors   % containers.Map: label -> [R G B]
        AutoOpenViewer    % logical: auto-open EventViewer after detection
        EscalateSeverity  % logical: escalate events to higher thresholds (default true)
        EventFile         % char: path to .mat file for auto-saving events (empty = disabled)
        MaxBackups        % numeric: number of backup files to keep (default 5, 0 = no backups)
    end

    methods
        function obj = EventConfig()
            obj.Sensors = {};
            obj.SensorData = [];
            obj.MinDuration = 0;
            obj.MaxCallsPerEvent = 1;
            obj.OnEventStart = [];
            obj.ThresholdColors = containers.Map();
            obj.AutoOpenViewer = false;
            obj.EscalateSeverity = true;
            obj.EventFile = '';
            obj.MaxBackups = 5;
        end

        function addSensor(~, ~)
            %ADDSENSOR Legacy entry point -- no longer functional.
            %   The Sensor.resolve() pipeline was deleted in Phase 1011.
            %   Use MonitorTag + EventStore for event detection.
            error('EventConfig:legacyRemoved', ...
                ['addSensor() depended on the deleted Sensor.resolve() pipeline. ', ...
                 'Use MonitorTag + EventStore for event detection.']);
        end

        function setColor(obj, label, rgb)
            %SETCOLOR Set color for a threshold label.
            obj.ThresholdColors(label) = rgb;
        end

        function det = buildDetector(obj)
            %BUILDDETECTOR Create a configured EventDetector.
            args = {'MinDuration', obj.MinDuration, ...
                    'MaxCallsPerEvent', obj.MaxCallsPerEvent};
            if ~isempty(obj.OnEventStart)
                args = [args, {'OnEventStart', obj.OnEventStart}];
            end
            det = EventDetector(args{:});
        end

        function events = runDetection(obj)
            %RUNDETECTION Detect events across all configured sensors.
            det = obj.buildDetector();
            events = [];

            % Legacy Sensor-based detection removed in Phase 1011.
            % EventConfig.runDetection now returns empty events.
            % Use MonitorTag + EventStore for event detection.

            % Post-detection severity escalation
            if obj.EscalateSeverity && ~isempty(events)
                events = obj.escalateEvents(events);
            end

            % Auto-save to .mat file
            if ~isempty(obj.EventFile)
                obj.saveEvents(events);
            end

            if obj.AutoOpenViewer && ~isempty(events)
                if isempty(obj.ThresholdColors) || obj.ThresholdColors.Count == 0
                    EventViewer(events, obj.SensorData);
                else
                    EventViewer(events, obj.SensorData, obj.ThresholdColors);
                end
            end
        end
    end

    methods (Access = private)
        function saveEvents(obj, events)
            %SAVEEVENTS Save events, sensor data, and colors to .mat file via EventStore.
            store = EventStore(obj.EventFile, 'MaxBackups', obj.MaxBackups);
            store.append(events);
            store.SensorData = obj.SensorData;
            store.Timestamp = datetime('now');

            % Convert containers.Map to struct for serialization
            if obj.ThresholdColors.Count > 0
                keys = obj.ThresholdColors.keys();
                vals = obj.ThresholdColors.values();
                colorStruct = struct();
                for i = 1:numel(keys)
                    safeKey = matlab.lang.makeValidName(keys{i});
                    colorStruct.(safeKey) = struct('label', keys{i}, 'rgb', vals{i});
                end
                store.ThresholdColors = colorStruct;
            end

            store.save();
        end

        function events = escalateEvents(~, events)
            %ESCALATEEVENTS Legacy severity escalation -- no-op after Phase 1011.
            %   ResolvedThresholds-based escalation was removed with the
            %   legacy Sensor pipeline.  Returns events unchanged.
        end
    end
end
