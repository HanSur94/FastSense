function events = detectEventsFromSensor(sensor, detector)
%DETECTEVENTSFROMSENSOR Detect events from a Sensor object's resolved violations.
%   events = detectEventsFromSensor(sensor)
%   events = detectEventsFromSensor(sensor, detector)
%
%   Bridges the SensorThreshold and EventDetection libraries.
%   Uses sensor.ResolvedViolations and sensor.ResolvedThresholds to
%   detect events for each threshold independently.

    if nargin < 2
        detector = EventDetector();
    end

    % Use sensor Name if available, otherwise Key
    if ~isempty(sensor.Name)
        sensorName = sensor.Name;
    else
        sensorName = sensor.Key;
    end

    events = [];
    resolved = sensor.ResolvedViolations;

    if isempty(resolved)
        return;
    end

    for i = 1:numel(resolved)
        viol = resolved(i);
        vX = viol.X;
        vY = viol.Y;

        if isempty(vX)
            continue;
        end

        % Map SensorThreshold direction to EventDetection direction
        if strcmp(viol.Direction, 'upper')
            direction = 'high';
        else
            direction = 'low';
        end

        label = viol.Label;

        % Get threshold value from ResolvedThresholds
        thresholdValue = NaN;
        if ~isempty(sensor.ResolvedThresholds)
            for j = 1:numel(sensor.ResolvedThresholds)
                th = sensor.ResolvedThresholds(j);
                if strcmp(th.Label, label) && strcmp(th.Direction, viol.Direction)
                    % Use the non-NaN threshold value
                    validY = th.Y(~isnan(th.Y));
                    if ~isempty(validY)
                        thresholdValue = validY(1);
                    end
                    break;
                end
            end
        end

        % Detect events from the full sensor signal against this threshold
        newEvents = detector.detect(sensor.X, sensor.Y, thresholdValue, direction, label, sensorName);

        if isempty(events)
            events = newEvents;
        elseif ~isempty(newEvents)
            events = [events, newEvents];
        end
    end
end
