classdef Event < handle
    %EVENT Represents a single detected threshold violation event.
    %   e = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)
    %   e.setStats(peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal)

    properties (SetAccess = private)
        StartTime       % numeric: first violation timestamp
        EndTime         % numeric: last violation timestamp
        Duration        % numeric: EndTime - StartTime
        SensorName      % char: sensor/channel name
        ThresholdLabel  % char: threshold label
        ThresholdValue  % numeric: threshold value that was violated
        Direction       % char: 'upper' or 'lower'
        PeakValue       % numeric: worst violation value
        NumPoints       % numeric: number of data points in event window
        MinValue        % numeric: minimum signal value during event
        MaxValue        % numeric: maximum signal value during event
        MeanValue       % numeric: mean signal value during event
        RmsValue        % numeric: root mean square of signal during event
        StdValue        % numeric: standard deviation of signal during event
    end

    properties
        TagKeys   = {}   % cell of char: tag keys bound to this event (EVENT-01)
        Severity  = 1    % numeric: 1=ok/info, 2=warn, 3=alarm (EVENT-04)
        Category  = ''   % char: alarm|maintenance|process_change|manual_annotation (EVENT-05)
        Id        = ''   % char: unique id assigned by EventStore.append (EVENT-02)
    end

    properties (Constant)
        DIRECTIONS = {'upper', 'lower'}
    end

    methods
        function obj = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)
            if ~ismember(direction, Event.DIRECTIONS)
                error('Event:invalidDirection', ...
                    'Direction must be ''upper'' or ''lower'', got ''%s''.', direction);
            end
            if endTime < startTime
                error('Event:invalidTimeRange', ...
                    'EndTime (%g) must be >= StartTime (%g).', endTime, startTime);
            end
            obj.StartTime = startTime;
            obj.EndTime = endTime;
            obj.Duration = endTime - startTime;
            obj.SensorName = sensorName;
            obj.ThresholdLabel = thresholdLabel;
            obj.ThresholdValue = thresholdValue;
            obj.Direction = direction;
            obj.PeakValue = [];
            obj.NumPoints = 0;
            obj.MinValue = [];
            obj.MaxValue = [];
            obj.MeanValue = [];
            obj.RmsValue = [];
            obj.StdValue = [];
        end

        function obj = setStats(obj, peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal)
            %SETSTATS Set event statistics.
            obj.PeakValue = peakValue;
            obj.NumPoints = numPoints;
            obj.MinValue = minVal;
            obj.MaxValue = maxVal;
            obj.MeanValue = meanVal;
            obj.RmsValue = rmsVal;
            obj.StdValue = stdVal;
        end

        function obj = escalateTo(obj, newLabel, newThresholdValue)
            %ESCALATETOP Escalate event to a higher severity threshold.
            obj.ThresholdLabel = newLabel;
            obj.ThresholdValue = newThresholdValue;
        end
    end
end
