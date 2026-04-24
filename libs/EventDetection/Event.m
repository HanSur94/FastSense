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
        TagKeys   = {}       % cell of char: tag keys bound to this event (EVENT-01)
        Severity  = 1        % numeric: 1=ok/info, 2=warn, 3=alarm (EVENT-04)
        Category  = ''       % char: alarm|maintenance|process_change|manual_annotation (EVENT-05)
        Id        = ''       % char: unique id assigned by EventStore.append (EVENT-02)
        IsOpen    = false    % logical: true while event is still open (EndTime = NaN) — Phase 1012
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
            if ~isnan(endTime) && endTime < startTime
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

        function obj = close(obj, endTime, finalStats)
            %CLOSE Close an open event in place; update EndTime, Duration, and optional running stats.
            %   ev.close(endTime, finalStats) mutates the SetAccess=private
            %   fields EndTime and Duration and optionally populates stats
            %   from a struct with fields {PeakValue, NumPoints, MinValue,
            %   MaxValue, MeanValue, RmsValue, StdValue}. Toggles IsOpen
            %   false. Called by EventStore.closeEvent.
            %
            %   finalStats may be [] (empty) to skip stats update.
            %
            %   Errors:
            %     Event:closedOpenEvent — called on an event whose IsOpen is already false
            if ~obj.IsOpen
                error('Event:closedOpenEvent', ...
                    'Event is already closed; close() called twice.');
            end
            obj.EndTime  = endTime;
            obj.Duration = endTime - obj.StartTime;
            obj.IsOpen   = false;
            if nargin >= 3 && ~isempty(finalStats) && isstruct(finalStats)
                if isfield(finalStats, 'PeakValue'), obj.PeakValue = finalStats.PeakValue; end
                if isfield(finalStats, 'NumPoints'), obj.NumPoints = finalStats.NumPoints; end
                if isfield(finalStats, 'MinValue'),  obj.MinValue  = finalStats.MinValue;  end
                if isfield(finalStats, 'MaxValue'),  obj.MaxValue  = finalStats.MaxValue;  end
                if isfield(finalStats, 'MeanValue'), obj.MeanValue = finalStats.MeanValue; end
                if isfield(finalStats, 'RmsValue'),  obj.RmsValue  = finalStats.RmsValue;  end
                if isfield(finalStats, 'StdValue'),  obj.StdValue  = finalStats.StdValue;  end
            end
        end

        function obj = escalateTo(obj, newLabel, newThresholdValue)
            %ESCALATETOP Escalate event to a higher severity threshold.
            obj.ThresholdLabel = newLabel;
            obj.ThresholdValue = newThresholdValue;
        end
    end
end
