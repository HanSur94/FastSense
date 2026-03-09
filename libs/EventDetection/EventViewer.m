classdef EventViewer < handle
    %EVENTVIEWER Figure-based event viewer with Gantt timeline and filterable table.
    %   viewer = EventViewer(events)
    %   viewer = EventViewer(events, sensorData)
    %   viewer = EventViewer(events, sensorData, thresholdColors)
    %   viewer.update(newEvents)

    properties
        Events          % Event array
        SensorData      % struct array: name, t, y (for click-to-plot)
        ThresholdColors % containers.Map: label -> [R G B]
        hFigure         % figure handle
    end

    properties (Access = private)
        hTimelineAxes   % axes for Gantt chart
        hTable          % uitable handle
        hSensorFilter   % popup menu for sensor filter
        hLabelFilter    % popup menu for label filter
        hTooltip        % text object for hover tooltip
        FilteredEvents  % currently displayed events after filtering
        BarRects        % rectangle handles for hover detection
        BarEvents       % Event objects corresponding to BarRects
        SourceFile      % char: path to .mat file (for refresh)
        RefreshTimer    % timer object for auto-refresh
        hRefreshBtn     % push button: manual refresh
        hAutoCheck      % checkbox: auto-refresh toggle
        hIntervalEdit   % edit field: refresh interval in seconds
        hStatusLabel    % text: last refresh timestamp
    end

    methods
        function obj = EventViewer(events, sensorData, thresholdColors)
            obj.Events = events;
            obj.FilteredEvents = events;

            if nargin >= 2
                obj.SensorData = sensorData;
            else
                obj.SensorData = [];
            end

            if nargin >= 3
                obj.ThresholdColors = thresholdColors;
            else
                obj.ThresholdColors = containers.Map();
            end

            obj.buildFigure();
        end

        function update(obj, events)
            %UPDATE Refresh the viewer with new events.
            obj.Events = events;
            obj.applyFilters();
        end

        function names = getSensorNames(obj)
            %GETSENSORNAMES Get unique sensor names from events.
            names = unique(arrayfun(@(e) e.SensorName, obj.Events, 'UniformOutput', false));
        end

        function labels = getThresholdLabels(obj)
            %GETTHRESHOLDLABELS Get unique threshold labels from events.
            labels = unique(arrayfun(@(e) e.ThresholdLabel, obj.Events, 'UniformOutput', false));
        end

        function refreshFromFile(obj)
            %REFRESHFROMFILE Reload events from the source .mat file.
            if isempty(obj.SourceFile)
                return;
            end
            if ~exist(obj.SourceFile, 'file')
                return;
            end

            data = load(obj.SourceFile);
            if ~isfield(data, 'events')
                return;
            end

            obj.Events = data.events;
            if isfield(data, 'sensorData')
                obj.SensorData = data.sensorData;
            end
            if isfield(data, 'thresholdColors') && isstruct(data.thresholdColors) ...
                    && ~isempty(fieldnames(data.thresholdColors))
                fields = fieldnames(data.thresholdColors);
                obj.ThresholdColors = containers.Map();
                for i = 1:numel(fields)
                    entry = data.thresholdColors.(fields{i});
                    obj.ThresholdColors(entry.label) = entry.rgb;
                end
            end

            obj.applyFilters();

            % Update status
            if ~isempty(obj.hStatusLabel) && ishandle(obj.hStatusLabel)
                set(obj.hStatusLabel, 'String', ...
                    sprintf('Last refresh: %s  |  %d events', ...
                    datestr(now, 'HH:MM:SS'), numel(obj.Events))); %#ok<TNOW1,DATST>
            end

            % Update title
            if isfield(data, 'timestamp')
                set(obj.hFigure, 'Name', ...
                    sprintf('Event Viewer — %s', char(data.timestamp)));
            end
        end

        function startAutoRefresh(obj, interval)
            %STARTAUTOREFRESH Start polling the source file at given interval.
            %   obj.startAutoRefresh(5)  % refresh every 5 seconds
            if isempty(obj.SourceFile)
                return;
            end
            obj.stopAutoRefresh();
            obj.RefreshTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', interval, ...
                'TimerFcn', @(~,~) obj.onAutoRefreshTick());
            start(obj.RefreshTimer);
        end

        function stopAutoRefresh(obj)
            %STOPAUTOREFRESH Stop the auto-refresh timer.
            if ~isempty(obj.RefreshTimer) && isvalid(obj.RefreshTimer)
                stop(obj.RefreshTimer);
                delete(obj.RefreshTimer);
            end
            obj.RefreshTimer = [];
        end
    end

    methods (Static)
        function viewer = fromFile(filepath)
            %FROMFILE Open EventViewer from a saved .mat event store file.
            %   viewer = EventViewer.fromFile('events.mat')
            if ~exist(filepath, 'file')
                error('EventViewer:fileNotFound', 'File not found: %s', filepath);
            end

            data = load(filepath);

            if ~isfield(data, 'events')
                error('EventViewer:invalidFile', 'File does not contain an events field.');
            end

            events = data.events;
            sensorData = [];
            if isfield(data, 'sensorData')
                sensorData = data.sensorData;
            end

            thresholdColors = containers.Map();
            if isfield(data, 'thresholdColors') && ~isempty(fieldnames(data.thresholdColors))
                fields = fieldnames(data.thresholdColors);
                for i = 1:numel(fields)
                    entry = data.thresholdColors.(fields{i});
                    thresholdColors(entry.label) = entry.rgb;
                end
            end

            viewer = EventViewer(events, sensorData, thresholdColors);
            viewer.SourceFile = filepath;
            viewer.buildRefreshToolbar();

            if isfield(data, 'timestamp')
                set(viewer.hFigure, 'Name', ...
                    sprintf('Event Viewer — %s', char(data.timestamp)));
            end
        end
    end

    methods (Access = private)
        function buildFigure(obj)
            obj.hFigure = figure('Name', 'Event Viewer', ...
                'NumberTitle', 'off', ...
                'Position', [100 100 1200 700], ...
                'Color', [0.15 0.15 0.18]);

            % --- Top panel: Gantt timeline ---
            obj.hTimelineAxes = axes('Parent', obj.hFigure, ...
                'Position', [0.05 0.55 0.9 0.40], ...
                'Color', [0.2 0.2 0.23], ...
                'XColor', [0.8 0.8 0.8], ...
                'YColor', [0.8 0.8 0.8]);
            title(obj.hTimelineAxes, 'Event Timeline', 'Color', [0.9 0.9 0.9]);
            hold(obj.hTimelineAxes, 'on');

            % --- Filter dropdowns ---
            uicontrol('Parent', obj.hFigure, 'Style', 'text', ...
                'String', 'Sensor:', ...
                'Units', 'normalized', 'Position', [0.05 0.48 0.05 0.03], ...
                'BackgroundColor', [0.15 0.15 0.18], 'ForegroundColor', [0.8 0.8 0.8]);

            sensorNames = [{'All'}, obj.getSensorNames()];
            obj.hSensorFilter = uicontrol('Parent', obj.hFigure, 'Style', 'popupmenu', ...
                'String', sensorNames, ...
                'Units', 'normalized', 'Position', [0.10 0.48 0.15 0.03], ...
                'Callback', @(~,~) obj.applyFilters());

            uicontrol('Parent', obj.hFigure, 'Style', 'text', ...
                'String', 'Threshold:', ...
                'Units', 'normalized', 'Position', [0.28 0.48 0.07 0.03], ...
                'BackgroundColor', [0.15 0.15 0.18], 'ForegroundColor', [0.8 0.8 0.8]);

            threshLabels = [{'All'}, obj.getThresholdLabels()];
            obj.hLabelFilter = uicontrol('Parent', obj.hFigure, 'Style', 'popupmenu', ...
                'String', threshLabels, ...
                'Units', 'normalized', 'Position', [0.35 0.48 0.15 0.03], ...
                'Callback', @(~,~) obj.applyFilters());

            % --- Bottom panel: event table ---
            columnNames = {'Start', 'End', 'Duration', 'Sensor', 'Threshold', ...
                'Dir', 'Peak', '#Pts', 'Min', 'Max', 'Mean', 'RMS', 'Std'};
            obj.hTable = uitable('Parent', obj.hFigure, ...
                'Units', 'normalized', 'Position', [0.05 0.03 0.9 0.42], ...
                'ColumnName', columnNames, ...
                'ColumnWidth', {70 70 65 120 130 45 70 50 70 70 70 70 70}, ...
                'CellSelectionCallback', @(src, evt) obj.onRowClick(src, evt));

            % --- Hover tooltip (hidden initially) ---
            obj.hTooltip = text(obj.hTimelineAxes, 0, 0, '', ...
                'Visible', 'off', ...
                'BackgroundColor', [0.1 0.1 0.12], ...
                'Color', [0.95 0.95 0.95], ...
                'EdgeColor', [0.5 0.5 0.5], ...
                'FontSize', 9, ...
                'FontName', 'FixedWidth', ...
                'Margin', 6, ...
                'VerticalAlignment', 'bottom', ...
                'HorizontalAlignment', 'left', ...
                'Clipping', 'off');

            set(obj.hFigure, 'WindowButtonMotionFcn', @(~,~) obj.onHover());

            obj.drawTimeline();
            obj.populateTable();
        end

        function drawTimeline(obj)
            cla(obj.hTimelineAxes);
            events = obj.FilteredEvents;
            obj.BarRects = [];
            obj.BarEvents = [];

            if isempty(events)
                return;
            end

            sensorNames = obj.getSensorNames();
            nSensors = numel(sensorNames);

            % Default colors
            defaultColors = [0.2 0.6 1; 1 0.4 0.2; 0.2 0.8 0.4; ...
                             1 0.8 0; 0.6 0.3 0.8; 0 0.8 0.8];

            nEvents = numel(events);
            hRects = gobjects(nEvents, 1);

            for i = 1:nEvents
                ev = events(i);
                sIdx = find(strcmp(sensorNames, ev.SensorName));
                yPos = nSensors - sIdx + 1;

                % Get color
                if obj.ThresholdColors.isKey(ev.ThresholdLabel)
                    c = obj.ThresholdColors(ev.ThresholdLabel);
                else
                    c = defaultColors(mod(sIdx-1, size(defaultColors,1)) + 1, :);
                end

                barH = 0.6;
                duration = max(ev.Duration, 0.5); % min width for visibility
                hRects(i) = rectangle(obj.hTimelineAxes, ...
                    'Position', [ev.StartTime, yPos - barH/2, duration, barH], ...
                    'FaceColor', c, 'EdgeColor', c * 0.7, ...
                    'LineWidth', 1, 'Curvature', [0.1 0.1]);
            end

            obj.BarRects = hRects;
            obj.BarEvents = events;

            set(obj.hTimelineAxes, 'YTick', 1:nSensors, ...
                'YTickLabel', flip(sensorNames), ...
                'YLim', [0.3, nSensors + 0.7]);
            xlabel(obj.hTimelineAxes, 'Time', 'Color', [0.8 0.8 0.8]);

            % Enable grid
            set(obj.hTimelineAxes, 'XGrid', 'on', 'YGrid', 'on', ...
                'GridColor', [0.4 0.4 0.4], 'GridAlpha', 0.5);

            % Recreate tooltip (cla destroys it)
            obj.hTooltip = text(obj.hTimelineAxes, 0, 0, '', ...
                'Visible', 'off', ...
                'BackgroundColor', [0.1 0.1 0.12], ...
                'Color', [0.95 0.95 0.95], ...
                'EdgeColor', [0.5 0.5 0.5], ...
                'FontSize', 9, ...
                'FontName', 'FixedWidth', ...
                'Margin', 6, ...
                'VerticalAlignment', 'bottom', ...
                'HorizontalAlignment', 'left', ...
                'Clipping', 'off');
        end

        function populateTable(obj)
            events = obj.FilteredEvents;

            if isempty(events)
                set(obj.hTable, 'Data', {});
                return;
            end

            nEvents = numel(events);
            data = cell(nEvents, 13);
            for i = 1:nEvents
                ev = events(i);
                data{i,1}  = ev.StartTime;
                data{i,2}  = ev.EndTime;
                data{i,3}  = ev.Duration;
                data{i,4}  = ev.SensorName;
                data{i,5}  = ev.ThresholdLabel;
                data{i,6}  = ev.Direction;
                data{i,7}  = ev.PeakValue;
                data{i,8}  = ev.NumPoints;
                data{i,9}  = ev.MinValue;
                data{i,10} = ev.MaxValue;
                data{i,11} = ev.MeanValue;
                data{i,12} = ev.RmsValue;
                data{i,13} = ev.StdValue;
            end
            set(obj.hTable, 'Data', data);
        end

        function applyFilters(obj)
            events = obj.Events;

            if isempty(events)
                obj.FilteredEvents = [];
                obj.drawTimeline();
                obj.populateTable();
                return;
            end

            % Sensor filter
            sensorIdx = get(obj.hSensorFilter, 'Value');
            sensorNames = get(obj.hSensorFilter, 'String');
            if sensorIdx > 1
                selectedSensor = sensorNames{sensorIdx};
                mask = arrayfun(@(e) strcmp(e.SensorName, selectedSensor), events);
                events = events(mask);
            end

            % Label filter
            labelIdx = get(obj.hLabelFilter, 'Value');
            labelNames = get(obj.hLabelFilter, 'String');
            if labelIdx > 1
                selectedLabel = labelNames{labelIdx};
                mask = arrayfun(@(e) strcmp(e.ThresholdLabel, selectedLabel), events);
                events = events(mask);
            end

            obj.FilteredEvents = events;
            obj.drawTimeline();
            obj.populateTable();
        end

        function onHover(obj)
            if isempty(obj.BarRects) || isempty(obj.BarEvents)
                set(obj.hTooltip, 'Visible', 'off');
                return;
            end

            cp = get(obj.hTimelineAxes, 'CurrentPoint');
            mx = cp(1,1);
            my = cp(1,2);

            % Check if mouse is within axes bounds
            xl = get(obj.hTimelineAxes, 'XLim');
            yl = get(obj.hTimelineAxes, 'YLim');
            if mx < xl(1) || mx > xl(2) || my < yl(1) || my > yl(2)
                set(obj.hTooltip, 'Visible', 'off');
                return;
            end

            % Check each bar rectangle for hit
            for i = 1:numel(obj.BarRects)
                if ~ishandle(obj.BarRects(i)); continue; end
                pos = get(obj.BarRects(i), 'Position');
                rx = pos(1); ry = pos(2); rw = pos(3); rh = pos(4);
                if mx >= rx && mx <= rx + rw && my >= ry && my <= ry + rh
                    ev = obj.BarEvents(i);
                    tipStr = sprintf([ ...
                        'Sensor:    %s\n' ...
                        'Threshold: %s\n' ...
                        'Direction: %s\n' ...
                        'Start:     %.2f\n' ...
                        'End:       %.2f\n' ...
                        'Duration:  %.2f\n' ...
                        'Peak:      %.3f\n' ...
                        'Points:    %d'], ...
                        ev.SensorName, ev.ThresholdLabel, ev.Direction, ...
                        ev.StartTime, ev.EndTime, ev.Duration, ...
                        ev.PeakValue, ev.NumPoints);
                    set(obj.hTooltip, 'Position', [mx, my + 0.15, 0], ...
                        'String', tipStr, 'Visible', 'on');
                    uistack(obj.hTooltip, 'top');
                    return;
                end
            end

            set(obj.hTooltip, 'Visible', 'off');
        end

        function buildRefreshToolbar(obj)
            %BUILDREFRESHTOOLBAR Add refresh controls below the filter row.
            % Shift table down slightly to make room
            set(obj.hTable, 'Position', [0.05 0.03 0.9 0.40]);

            % Refresh button
            obj.hRefreshBtn = uicontrol('Parent', obj.hFigure, 'Style', 'pushbutton', ...
                'String', 'Refresh', ...
                'Units', 'normalized', 'Position', [0.55 0.48 0.07 0.03], ...
                'Callback', @(~,~) obj.refreshFromFile());

            % Auto-refresh checkbox
            obj.hAutoCheck = uicontrol('Parent', obj.hFigure, 'Style', 'checkbox', ...
                'String', 'Auto', ...
                'Units', 'normalized', 'Position', [0.63 0.48 0.05 0.03], ...
                'BackgroundColor', [0.15 0.15 0.18], 'ForegroundColor', [0.8 0.8 0.8], ...
                'Value', 0, ...
                'Callback', @(~,~) obj.onAutoCheckChanged());

            % Interval label
            uicontrol('Parent', obj.hFigure, 'Style', 'text', ...
                'String', 'every', ...
                'Units', 'normalized', 'Position', [0.68 0.48 0.03 0.03], ...
                'BackgroundColor', [0.15 0.15 0.18], 'ForegroundColor', [0.8 0.8 0.8]);

            % Interval edit
            obj.hIntervalEdit = uicontrol('Parent', obj.hFigure, 'Style', 'edit', ...
                'String', '5', ...
                'Units', 'normalized', 'Position', [0.71 0.48 0.04 0.03], ...
                'Callback', @(~,~) obj.onAutoCheckChanged());

            % Seconds label
            uicontrol('Parent', obj.hFigure, 'Style', 'text', ...
                'String', 's', ...
                'Units', 'normalized', 'Position', [0.75 0.48 0.015 0.03], ...
                'BackgroundColor', [0.15 0.15 0.18], 'ForegroundColor', [0.8 0.8 0.8]);

            % Status label
            obj.hStatusLabel = uicontrol('Parent', obj.hFigure, 'Style', 'text', ...
                'String', sprintf('%d events  |  file: %s', numel(obj.Events), obj.SourceFile), ...
                'Units', 'normalized', 'Position', [0.05 0.44 0.9 0.03], ...
                'BackgroundColor', [0.15 0.15 0.18], 'ForegroundColor', [0.6 0.6 0.6], ...
                'HorizontalAlignment', 'left', 'FontSize', 8);

            % Stop timer and clean up on figure close
            set(obj.hFigure, 'DeleteFcn', @(~,~) obj.onFigureClose());
        end

        function onAutoCheckChanged(obj)
            if get(obj.hAutoCheck, 'Value')
                intervalStr = get(obj.hIntervalEdit, 'String');
                interval = str2double(intervalStr);
                if isnan(interval) || interval < 1
                    interval = 5;
                    set(obj.hIntervalEdit, 'String', '5');
                end
                obj.startAutoRefresh(interval);
            else
                obj.stopAutoRefresh();
            end
        end

        function onAutoRefreshTick(obj)
            try
                if isvalid(obj) && ishandle(obj.hFigure)
                    obj.refreshFromFile();
                else
                    obj.stopAutoRefresh();
                end
            catch
                obj.stopAutoRefresh();
            end
        end

        function onFigureClose(obj)
            obj.stopAutoRefresh();
        end

        function onRowClick(obj, ~, evt)
            if isempty(evt.Indices)
                return;
            end
            row = evt.Indices(1);
            ev = obj.FilteredEvents(row);

            % Find matching sensor data
            if isempty(obj.SensorData)
                return;
            end

            sIdx = [];
            for i = 1:numel(obj.SensorData)
                if strcmp(obj.SensorData(i).name, ev.SensorName)
                    sIdx = i;
                    break;
                end
            end

            if isempty(sIdx)
                return;
            end

            sd = obj.SensorData(sIdx);

            % Open FastPlot for this sensor, zoomed to event
            fp = FastPlot();
            fp.addLine(sd.t, sd.y, 'DisplayName', sd.name);

            % Add threshold line
            fp.addThreshold(ev.ThresholdValue, ...
                'Label', ev.ThresholdLabel, ...
                'Direction', ev.Direction);

            % Zoom to event with 20% padding
            margin = ev.Duration * 0.2;
            if margin == 0
                margin = 5;
            end
            fp.render();
            set(fp.hAxes, 'XLim', [ev.StartTime - margin, ev.EndTime + margin]);
        end
    end
end
