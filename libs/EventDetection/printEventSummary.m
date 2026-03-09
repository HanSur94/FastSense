function printEventSummary(events)
%PRINTEVENTSUMMARY Print a formatted table of events to the console.
%   printEventSummary(events)

    if isempty(events)
        fprintf('No events detected.\n');
        return;
    end

    % Header
    fprintf('\n');
    fprintf('%-12s %-12s %-10s %-16s %-18s %-6s %10s %6s %10s %10s\n', ...
        'Start', 'End', 'Duration', 'Sensor', 'Threshold', 'Dir', ...
        'Peak', '#Pts', 'Mean', 'Std');
    fprintf('%s\n', repmat('-', 1, 120));

    % Rows
    for i = 1:numel(events)
        e = events(i);
        fprintf('%-12.2f %-12.2f %-10.2f %-16s %-18s %-6s %10.2f %6d %10.2f %10.2f\n', ...
            e.StartTime, e.EndTime, e.Duration, ...
            truncStr(e.SensorName, 16), truncStr(e.ThresholdLabel, 18), ...
            e.Direction, e.PeakValue, e.NumPoints, e.MeanValue, e.StdValue);
    end
    fprintf('\n%d event(s) total.\n\n', numel(events));
end

function s = truncStr(s, maxLen)
    if numel(s) > maxLen
        s = [s(1:maxLen-2), '..'];
    end
end
