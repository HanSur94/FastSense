classdef Event < handle
    %EVENT Represents a single detected threshold violation event.
    %   e = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)
    %   e.setStats(peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal)
    %
    %   Phase 1032 additions:
    %     Identity (struct, default empty)        — IDENT-02 audit trail; populated at emission
    %     AckedAt  (numeric, default [])          — datenum of ack; [] = unacked
    %     AckedBy  (struct, default empty struct) — {user, host, epoch, comment}; populated by EventStore.acknowledgeEvent
    %     AckComment (char, default '')           — convenience alias for AckedBy.comment
    %   Method:
    %     computeDisplayState — returns 'unacked-active' | 'acked-active' | 'acked-cleared' | 'unacked-cleared' (ISA-18.2 §5.4)
    %   Static helper:
    %     Event.fromStructSafe(s)  — promote legacy struct to Event with safe field defaults

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
        TagKeys    = {}       % cell of char: tag keys bound to this event (EVENT-01)
        Severity   = 1        % numeric: 1=ok/info, 2=warn, 3=alarm (EVENT-04)
        Category   = ''       % char: alarm|maintenance|process_change|manual_annotation (EVENT-05)
        Id         = ''       % char: unique id assigned by EventStore.append (EVENT-02)
        IsOpen     = false    % logical: true while event is still open (EndTime = NaN) — Phase 1012
        Notes      = ''       % char: free-form user annotation edited via details popup — Phase 1012
        % Identity: Phase 1032 {user, host, epoch} captured at emission time (IDENT-02 audit
        % trail). Empty struct in single-user mode AND on backward-compat load of legacy events.
        Identity   = struct()
        AckedAt    = []       % numeric epoch (datenum); [] means unacked. Set by EventStore.acknowledgeEvent
        AckedBy    = struct() % {user, host, epoch, comment}; populated by EventStore.acknowledgeEvent
        AckComment = ''       % char: convenience alias; mirrors AckedBy.comment after acknowledgeEvent
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

        function s = computeDisplayState(obj)
            %COMPUTEDISPLAYSTATE Return the ISA-18.2 / EEMUA-191 three-state alarm visual state name.
            %   States:
            %     'unacked-active'  — event is still open (IsOpen=true) AND not acked
            %     'acked-active'    — event is still open AND acked (operator saw it but condition persists)
            %     'acked-cleared'   — event has been closed AND acked (normal happy-path closure)
            %     'unacked-cleared' — event closed but never acked (audit-trail anomaly; UI may render distinctly)
            %
            %   Per ISA-18.2 §5.4 / FEATURES.md research, condition state and ack state are
            %   orthogonal — this method returns the four-cell product (the v4.0 acceptance
            %   criterion ACK-02 explicitly enumerates three of the four; the fourth — closed
            %   but never acked — is included for completeness and UI ergonomics).
            isAcked = ~isempty(obj.AckedAt) && ~(isnumeric(obj.AckedAt) && all(isnan(obj.AckedAt)));
            if obj.IsOpen
                if isAcked
                    s = 'acked-active';
                else
                    s = 'unacked-active';
                end
            else
                if isAcked
                    s = 'acked-cleared';
                else
                    s = 'unacked-cleared';
                end
            end
        end
    end

    methods (Static)
        function ev = fromStructSafe(s)
            %FROMSTRUCTSAFE Promote a struct (legacy or v4.0) to an Event instance with field defaults.
            %   Used by EventStore.getEvents() merge code AND by Phase 1033 consolidator
            %   to unify mixed struct/Event arrays.  Missing fields default safely:
            %     Identity   = struct()
            %     AckedAt    = []
            %     AckedBy    = struct()
            %     AckComment = ''
            %   (i.e., the same defaults as the property declarations).
            if isa(s, 'Event')
                ev = s;
                return;
            end
            % Tolerate missing optional fields with defaults.
            sn    = '';       if isfield(s, 'SensorName'),     sn  = s.SensorName;     end
            tl    = '';       if isfield(s, 'ThresholdLabel'), tl  = s.ThresholdLabel;  end
            tv    = NaN;      if isfield(s, 'ThresholdValue'), tv  = s.ThresholdValue;  end
            dir   = 'upper';  if isfield(s, 'Direction') && ~isempty(s.Direction), dir = s.Direction; end
            startT = 0;       if isfield(s, 'StartTime'),      startT = s.StartTime;    end
            endT   = NaN;     if isfield(s, 'EndTime'),        endT   = s.EndTime;      end
            ev = Event(startT, endT, sn, tl, tv, dir);
            for fld = {'TagKeys','Severity','Category','Id','IsOpen','Notes', ...
                       'Identity','AckedAt','AckedBy','AckComment'}
                if isfield(s, fld{1})
                    try
                        ev.(fld{1}) = s.(fld{1});
                    catch
                    end
                end
            end
            if isfield(s, 'PeakValue') || isfield(s, 'NumPoints')
                pk = NaN; np = 0; mn = NaN; mx = NaN; me = NaN; rm = NaN; sd = NaN;
                if isfield(s, 'PeakValue'), pk = s.PeakValue; end
                if isfield(s, 'NumPoints'), np = s.NumPoints; end
                if isfield(s, 'MinValue'),  mn = s.MinValue;  end
                if isfield(s, 'MaxValue'),  mx = s.MaxValue;  end
                if isfield(s, 'MeanValue'), me = s.MeanValue; end
                if isfield(s, 'RmsValue'),  rm = s.RmsValue;  end
                if isfield(s, 'StdValue'),  sd = s.StdValue;  end
                ev.setStats(pk, np, mn, mx, me, rm, sd);
            end
        end
    end
end
