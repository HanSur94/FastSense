classdef NotificationRule < handle
    % NotificationRule  Configures notification for sensor/threshold events.

    properties
        SensorKey       = ''
        ThresholdLabel  = ''
        Recipients      = {{}}
        Subject         = 'Event: {sensor} - {threshold}'
        Message         = '{sensor} exceeded {threshold} ({direction}) at {startTime}. Peak: {peak}'
        IncludeSnapshot = true
        ContextHours    = 2
        SnapshotPadding = 0.1
        SnapshotSize    = [800, 400]
    end

    methods
        function obj = NotificationRule(varargin)
            p = inputParser();
            p.addParameter('SensorKey', '', @ischar);
            p.addParameter('ThresholdLabel', '', @ischar);
            p.addParameter('Recipients', {{}});
            p.addParameter('Subject', 'Event: {sensor} - {threshold}', @ischar);
            p.addParameter('Message', '{sensor} exceeded {threshold} ({direction}) at {startTime}. Peak: {peak}', @ischar);
            p.addParameter('IncludeSnapshot', true, @islogical);
            p.addParameter('ContextHours', 2, @isnumeric);
            p.addParameter('SnapshotPadding', 0.1, @isnumeric);
            p.addParameter('SnapshotSize', [800 400], @isnumeric);
            p.parse(varargin{:});
            flds = fieldnames(p.Results);
            for i = 1:numel(flds)
                obj.(flds{i}) = p.Results.(flds{i});
            end
        end

        function score = matches(obj, event)
            % Returns match score: 3=sensor+threshold, 2=sensor, 1=default, 0=no match
            hasSensor = ~isempty(obj.SensorKey);
            hasThreshold = ~isempty(obj.ThresholdLabel);

            if hasSensor && ~strcmp(event.SensorName, obj.SensorKey)
                score = 0; return;
            end
            if hasThreshold && ~strcmp(event.ThresholdLabel, obj.ThresholdLabel)
                score = 0; return;
            end

            if hasSensor && hasThreshold
                score = 3;
            elseif hasSensor
                score = 2;
            else
                score = 1;  % default rule
            end
        end

        function txt = fillTemplate(~, template, event)
            txt = template;
            txt = strrep(txt, '{sensor}', event.SensorName);
            txt = strrep(txt, '{threshold}', event.ThresholdLabel);
            txt = strrep(txt, '{direction}', event.Direction);
            % Open events (still in violation) carry EndTime=NaN and therefore
            % Duration=NaN. datestr(NaN) throws ("Date number out of range" on
            % MATLAB / "monthlength(nan)" on Octave), which would make EVERY
            % notification for an open event fail.  Guard both date fields and
            % the duration so live/background monitoring can email on open events.
            txt = strrep(txt, '{startTime}', NotificationRule.formatTimeOrOpen_(event.StartTime));
            txt = strrep(txt, '{endTime}', NotificationRule.formatTimeOrOpen_(event.EndTime));
            durSecs = event.Duration * 86400;
            if isnan(durSecs)
                durStr = '(ongoing)';
            elseif durSecs < 60
                durStr = sprintf('%.1fs', durSecs);
            elseif durSecs < 3600
                durStr = sprintf('%dm %ds', floor(durSecs/60), round(mod(durSecs, 60)));
            else
                durStr = sprintf('%dh %dm', floor(durSecs/3600), round(mod(durSecs, 3600)/60));
            end
            txt = strrep(txt, '{duration}', durStr);
            txt = strrep(txt, '{peak}', sprintf('%.4g', event.PeakValue));
            txt = strrep(txt, '{mean}', sprintf('%.4g', event.MeanValue));
            txt = strrep(txt, '{rms}', sprintf('%.4g', event.RmsValue));
            txt = strrep(txt, '{std}', sprintf('%.4g', event.StdValue));
            txt = strrep(txt, '{thresholdValue}', sprintf('%.4g', event.ThresholdValue));
        end
    end

    methods (Static, Access = private)
        function s = formatTimeOrOpen_(t)
            %FORMATTIMEOROPEN_ datestr(t), or '(open)' when t is NaN/empty.
            %   Open events carry EndTime=NaN; datestr(NaN) throws on both
            %   MATLAB and Octave, so callers must guard it here.
            if isempty(t) || any(isnan(t))
                s = '(open)';
            else
                s = datestr(t, 'yyyy-mm-dd HH:MM:SS');
            end
        end
    end
end
