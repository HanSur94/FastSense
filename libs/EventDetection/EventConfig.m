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

        function addSensor(obj, sensor)
            %ADDSENSOR Register a sensor with its data.
            sensor.resolve();
            obj.Sensors{end+1} = sensor;

            % Store data for viewer
            if ~isempty(sensor.Name)
                name = sensor.Name;
            else
                name = sensor.Key;
            end
            entry.name = name;
            entry.t = sensor.X;
            entry.y = sensor.Y;

            if isempty(obj.SensorData)
                obj.SensorData = entry;
            else
                obj.SensorData(end+1) = entry;
            end
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

            for i = 1:numel(obj.Sensors)
                newEvents = detectEventsFromSensor(obj.Sensors{i}, det);
                if isempty(events)
                    events = newEvents;
                elseif ~isempty(newEvents)
                    events = [events, newEvents];
                end
            end

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

        function events = escalateEvents(obj, events)
            %ESCALATEEVENTS Escalate events whose peak exceeds a higher threshold.

            % Build threshold map: key = 'SensorName|Direction' -> struct array {Label, Value}
            threshMap = containers.Map();
            for i = 1:numel(obj.Sensors)
                s = obj.Sensors{i};
                if ~isempty(s.Name); sName = s.Name; else; sName = s.Key; end
                if isempty(s.ResolvedThresholds); continue; end
                for j = 1:numel(s.ResolvedThresholds)
                    th = s.ResolvedThresholds(j);
                    if strcmp(th.Direction, 'upper'); dir = 'high'; else; dir = 'low'; end
                    key = [sName, '|', dir];
                    validY = th.Y(~isnan(th.Y));
                    if isempty(validY); continue; end
                    entry.Label = th.Label;
                    entry.Value = validY(1);
                    if threshMap.isKey(key)
                        threshMap(key) = [threshMap(key), entry];
                    else
                        threshMap(key) = entry;
                    end
                end
            end

            % Escalate each event
            for i = 1:numel(events)
                ev = events(i);
                key = [ev.SensorName, '|', ev.Direction];
                if ~threshMap.isKey(key); continue; end

                thresholds = threshMap(key);
                bestLabel = ev.ThresholdLabel;
                bestValue = ev.ThresholdValue;

                for j = 1:numel(thresholds)
                    th = thresholds(j);
                    if strcmp(ev.Direction, 'high')
                        % For 'high': escalate if peak exceeds a higher threshold
                        if th.Value > ev.ThresholdValue && ev.PeakValue >= th.Value
                            if th.Value > bestValue
                                bestValue = th.Value;
                                bestLabel = th.Label;
                            end
                        end
                    else
                        % For 'low': escalate if peak is below a lower threshold
                        if th.Value < ev.ThresholdValue && ev.PeakValue <= th.Value
                            if th.Value < bestValue
                                bestValue = th.Value;
                                bestLabel = th.Label;
                            end
                        end
                    end
                end

                if ~strcmp(bestLabel, ev.ThresholdLabel)
                    events(i) = ev.escalateTo(bestLabel, bestValue);
                end
            end

            % Deduplicate: remove events contained within another with same label
            remove = false(1, numel(events));
            for i = 1:numel(events)
                if remove(i); continue; end
                for j = i+1:numel(events)
                    if remove(j); continue; end
                    ei = events(i); ej = events(j);
                    if ~strcmp(ei.SensorName, ej.SensorName); continue; end
                    if ~strcmp(ei.ThresholdLabel, ej.ThresholdLabel); continue; end
                    % Check containment
                    if ei.StartTime <= ej.StartTime && ei.EndTime >= ej.EndTime
                        remove(j) = true;
                    elseif ej.StartTime <= ei.StartTime && ej.EndTime >= ei.EndTime
                        remove(i) = true;
                        break;
                    end
                end
            end
            events = events(~remove);
        end
    end
end
