function fn = eventLogger()
%EVENTLOGGER Factory that returns a function handle for live event logging.
%   logger = eventLogger()
%   monitor = MonitorTag('k', parent, '<', 5, 'OnEventStart', eventLogger());
%
%   Each call to the returned function prints a one-line log message.

    fn = @logEvent;
end

function logEvent(ev)
    fprintf('[EVENT] %s | %s | %s | %.2f -> %.2f (dur=%.2f) | peak=%.2f\n', ...
        ev.SensorName, ev.ThresholdLabel, upper(ev.Direction), ...
        ev.StartTime, ev.EndTime, ev.Duration, ev.PeakValue);
end
