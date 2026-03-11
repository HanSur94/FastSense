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
        BarPositions    % Nx4 matrix: [x, y, w, h] cached from drawTimeline
        BarRects        % rectangle handles for hover detection
        BarEvents       % Event objects corresponding to BarRects
    end

    properties (Access = private)
        hTimelineAxes   % axes for Gantt chart
        hTable          % uitable handle
        hSensorFilter   % popup menu for sensor filter
        hLabelFilter    % popup menu for label filter
        hTooltip        % text object for hover tooltip
        FilteredEvents  % currently displayed events after filtering
        SelectedBarIdx  % index of currently selected bar (0 = none)
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
            obj.ThresholdColors = EventViewer.deserializeThresholdColors(data, obj.SensorData);

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
            if ~isempty(obj.RefreshTimer)
                try
                    if isvalid(obj.RefreshTimer)
                        stop(obj.RefreshTimer);
                        delete(obj.RefreshTimer);
                    end
                catch
                end
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

            thresholdColors = EventViewer.deserializeThresholdColors(data, sensorData);

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
                'Color', [0.96 0.96 0.96]);

            % --- Top panel: Gantt timeline ---
            obj.hTimelineAxes = axes('Parent', obj.hFigure, ...
                'Position', [0.05 0.55 0.9 0.40], ...
                'Color', [1 1 1], ...
                'XColor', [0.2 0.2 0.2], ...
                'YColor', [0.2 0.2 0.2]);
            title(obj.hTimelineAxes, 'Event Timeline', 'Color', [0.1 0.1 0.1]);
            hold(obj.hTimelineAxes, 'on');

            % --- Filter dropdowns ---
            uicontrol('Parent', obj.hFigure, 'Style', 'text', ...
                'String', 'Sensor:', ...
                'Units', 'normalized', 'Position', [0.05 0.48 0.05 0.03], ...
                'BackgroundColor', [0.96 0.96 0.96], 'ForegroundColor', [0.2 0.2 0.2]);

            sensorNames = [{'All'}, obj.getSensorNames()];
            obj.hSensorFilter = uicontrol('Parent', obj.hFigure, 'Style', 'popupmenu', ...
                'String', sensorNames, ...
                'Units', 'normalized', 'Position', [0.10 0.48 0.15 0.03], ...
                'Callback', @(~,~) obj.applyFilters());

            uicontrol('Parent', obj.hFigure, 'Style', 'text', ...
                'String', 'Threshold:', ...
                'Units', 'normalized', 'Position', [0.28 0.48 0.07 0.03], ...
                'BackgroundColor', [0.96 0.96 0.96], 'ForegroundColor', [0.2 0.2 0.2]);

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
                'ColumnWidth', {140 140 75 120 130 45 70 50 70 70 70 70 70}, ...
                'CellSelectionCallback', @(src, evt) obj.onRowClick(src, evt));

            % --- Hover tooltip (hidden initially) ---
            obj.hTooltip = text(obj.hTimelineAxes, 0, 0, '', ...
                'Visible', 'off', ...
                'BackgroundColor', [1 1 1], ...
                'Color', [0.1 0.1 0.1], ...
                'EdgeColor', [0.6 0.6 0.6], ...
                'FontSize', 9, ...
                'FontName', 'FixedWidth', ...
                'Margin', 6, ...
                'VerticalAlignment', 'bottom', ...
                'HorizontalAlignment', 'left', ...
                'Clipping', 'off');

            set(obj.hFigure, 'WindowButtonMotionFcn', @(~,~) obj.onHover());
            set(obj.hFigure, 'WindowButtonDownFcn', @(~,~) obj.onBarClick());

            obj.drawTimeline();
            obj.populateTable();
        end

        function drawTimeline(obj)
            cla(obj.hTimelineAxes);
            events = obj.FilteredEvents;
            obj.BarRects = [];
            obj.BarEvents = [];
            obj.BarPositions = [];

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

                barH = 0.9;
                duration = max(ev.Duration, 1/1440); % min width: 1 minute in datenum
                hRects(i) = rectangle(obj.hTimelineAxes, ...
                    'Position', [ev.StartTime, yPos - barH/2, duration, barH], ...
                    'FaceColor', c, 'EdgeColor', c * 0.7, ...
                    'LineWidth', 1, 'Curvature', [0.1 0.1]);
            end

            obj.BarRects = hRects;
            obj.BarEvents = events;

            % Cache bar positions in a plain matrix for fast hit-testing
            obj.BarPositions = zeros(nEvents, 4);
            for i = 1:nEvents
                obj.BarPositions(i, :) = get(hRects(i), 'Position');
            end

            set(obj.hTimelineAxes, 'YTick', 1:nSensors, ...
                'YTickLabel', flip(sensorNames), ...
                'YLim', [0.3, nSensors + 0.7]);
            xlabel(obj.hTimelineAxes, 'Time', 'Color', [0.2 0.2 0.2]);
            datetick(obj.hTimelineAxes, 'x', 'keeplimits');

            % Enable grid
            set(obj.hTimelineAxes, 'XGrid', 'on', 'YGrid', 'on', ...
                'GridColor', [0.8 0.8 0.8], 'GridAlpha', 0.5);

            % Recreate tooltip (cla destroys it)
            obj.hTooltip = text(obj.hTimelineAxes, 0, 0, '', ...
                'Visible', 'off', ...
                'BackgroundColor', [1 1 1], ...
                'Color', [0.1 0.1 0.1], ...
                'EdgeColor', [0.6 0.6 0.6], ...
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

            % Vectorized datetime conversion
            startStrs = cellstr(datetime([events.StartTime], 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss'));
            endStrs   = cellstr(datetime([events.EndTime],   'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss'));

            data = cell(nEvents, 13);
            for i = 1:nEvents
                ev = events(i);
                data{i,1}  = startStrs{i};
                data{i,2}  = endStrs{i};
                data{i,3}  = obj.formatDuration(ev.Duration);
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
            if isempty(obj.BarRects) || isempty(obj.BarEvents) ...
                    || isempty(obj.hTooltip) || ~ishandle(obj.hTooltip)
                return;
            end

            bestIdx = obj.findBarUnderCursor();

            if bestIdx > 0
                ev = obj.BarEvents(bestIdx);
                cp = get(obj.hTimelineAxes, 'CurrentPoint');
                tipStr = sprintf([ ...
                    'Sensor:    %s\n' ...
                    'Threshold: %s\n' ...
                    'Direction: %s\n' ...
                    'Start:     %s\n' ...
                    'End:       %s\n' ...
                    'Duration:  %s\n' ...
                    'Peak:      %.3f\n' ...
                    'Points:    %d'], ...
                    ev.SensorName, ev.ThresholdLabel, ev.Direction, ...
                    char(datetime(ev.StartTime, 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
                    char(datetime(ev.EndTime, 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
                    obj.formatDuration(ev.Duration), ...
                    ev.PeakValue, ev.NumPoints);
                set(obj.hTooltip, 'Position', [cp(1,1), cp(1,2) + 0.15, 0], ...
                    'String', tipStr, 'Visible', 'on');
                try uistack(obj.hTooltip, 'top'); catch; end %#ok<CTCH>
            else
                set(obj.hTooltip, 'Visible', 'off');
            end
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
                'BackgroundColor', [0.96 0.96 0.96], 'ForegroundColor', [0.2 0.2 0.2], ...
                'Value', 0, ...
                'Callback', @(~,~) obj.onAutoCheckChanged());

            % Interval label
            uicontrol('Parent', obj.hFigure, 'Style', 'text', ...
                'String', 'every', ...
                'Units', 'normalized', 'Position', [0.68 0.48 0.03 0.03], ...
                'BackgroundColor', [0.96 0.96 0.96], 'ForegroundColor', [0.2 0.2 0.2]);

            % Interval edit
            obj.hIntervalEdit = uicontrol('Parent', obj.hFigure, 'Style', 'edit', ...
                'String', '5', ...
                'Units', 'normalized', 'Position', [0.71 0.48 0.04 0.03], ...
                'Callback', @(~,~) obj.onAutoCheckChanged());

            % Seconds label
            uicontrol('Parent', obj.hFigure, 'Style', 'text', ...
                'String', 's', ...
                'Units', 'normalized', 'Position', [0.75 0.48 0.015 0.03], ...
                'BackgroundColor', [0.96 0.96 0.96], 'ForegroundColor', [0.2 0.2 0.2]);

            % Status label
            obj.hStatusLabel = uicontrol('Parent', obj.hFigure, 'Style', 'text', ...
                'String', sprintf('%d events  |  file: %s', numel(obj.Events), obj.SourceFile), ...
                'Units', 'normalized', 'Position', [0.05 0.44 0.9 0.03], ...
                'BackgroundColor', [0.96 0.96 0.96], 'ForegroundColor', [0.4 0.4 0.4], ...
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

        function onBarClick(obj)
            if isempty(obj.BarRects) || isempty(obj.BarEvents)
                return;
            end

            bestIdx = obj.findBarUnderCursor();

            if bestIdx > 0
                obj.selectBar(bestIdx);
            end
        end

        function idx = findBarUnderCursor(obj)
            %FINDBARUNDERCURSOR Find the closest bar to the current mouse position.
            idx = 0;
            if isempty(obj.BarPositions); return; end

            cp = get(obj.hTimelineAxes, 'CurrentPoint');
            mx = cp(1,1);
            my = cp(1,2);

            xl = get(obj.hTimelineAxes, 'XLim');
            yl = get(obj.hTimelineAxes, 'YLim');
            if mx < xl(1) || mx > xl(2) || my < yl(1) || my > yl(2)
                return;
            end

            % Minimum hit width: 5 pixels in data coords
            axPos = get(obj.hTimelineAxes, 'Position');
            figPos = get(obj.hFigure, 'Position');
            axWidthPx = axPos(3) * figPos(3);
            xRange = xl(2) - xl(1);
            minHitW = xRange * 5 / max(axWidthPx, 1);

            bestDist = inf;
            for i = 1:size(obj.BarPositions, 1)
                rx = obj.BarPositions(i,1);
                ry = obj.BarPositions(i,2);
                rw = obj.BarPositions(i,3);
                rh = obj.BarPositions(i,4);
                if my < ry || my > ry + rh; continue; end
                hitW = max(rw, minHitW);
                cx = rx + rw / 2;
                if mx >= cx - hitW/2 && mx <= cx + hitW/2
                    dist = abs(mx - cx);
                    if dist < bestDist
                        bestDist = dist;
                        idx = i;
                    end
                end
            end
        end

        function selectBar(obj, idx)
            % Reset previous selection highlight
            if ~isempty(obj.SelectedBarIdx) && obj.SelectedBarIdx > 0 ...
                    && obj.SelectedBarIdx <= numel(obj.BarRects) ...
                    && ishandle(obj.BarRects(obj.SelectedBarIdx))
                ev = obj.BarEvents(obj.SelectedBarIdx);
                if obj.ThresholdColors.isKey(ev.ThresholdLabel)
                    c = obj.ThresholdColors(ev.ThresholdLabel);
                else
                    sensorNames = obj.getSensorNames();
                    sIdx = find(strcmp(sensorNames, ev.SensorName));
                    defaultColors = [0.2 0.6 1; 1 0.4 0.2; 0.2 0.8 0.4; ...
                                     1 0.8 0; 0.6 0.3 0.8; 0 0.8 0.8];
                    c = defaultColors(mod(sIdx-1, size(defaultColors,1)) + 1, :);
                end
                set(obj.BarRects(obj.SelectedBarIdx), ...
                    'EdgeColor', c * 0.7, 'LineWidth', 1);
            end

            % Highlight selected bar with dark edge (visible on light theme)
            obj.SelectedBarIdx = idx;
            if ishandle(obj.BarRects(idx))
                set(obj.BarRects(idx), 'EdgeColor', [0.1 0.1 0.1], 'LineWidth', 3);
            end

            % Highlight corresponding table row
            nRows = size(get(obj.hTable, 'Data'), 1);
            if nRows > 0 && idx <= nRows
                bgColors = repmat([1 1 1], nRows, 1);
                bgColors(idx, :) = [0.68 0.84 1.0];  % light blue highlight
                set(obj.hTable, 'BackgroundColor', bgColors);

                % Scroll table to make highlighted row visible
                obj.scrollTableToRow(idx);
            end
        end

        function onRowClick(obj, ~, evt)
            if isempty(evt.Indices)
                return;
            end
            row = evt.Indices(1);

            % Always highlight the clicked row and corresponding Gantt bar
            obj.highlightRow(row);

            % Double-click detection via MATLAB's SelectionType
            if strcmp(get(obj.hFigure, 'SelectionType'), 'open')
                obj.openEventPlot(row);
            end
        end

        function highlightRow(obj, row)
            %HIGHLIGHTROW Highlight a table row and the corresponding Gantt bar.
            nRows = size(get(obj.hTable, 'Data'), 1);
            if nRows == 0 || row > nRows; return; end

            if row <= numel(obj.BarRects)
                % selectBar handles both bar and table highlighting
                obj.selectBar(row);
            else
                % No corresponding bar — highlight table row directly
                bgColors = repmat([1 1 1], nRows, 1);
                bgColors(row, :) = [0.68 0.84 1.0];
                set(obj.hTable, 'BackgroundColor', bgColors);
            end
        end

        function openEventPlot(obj, row)
            %OPENEVENTPLOT Open a detail dashboard for the selected event.
            if isempty(obj.SensorData)
                return;
            end
            ev = obj.FilteredEvents(row);

            % Find matching sensor data
            sIdx = find(arrayfun(@(s) strcmp(s.name, ev.SensorName), obj.SensorData), 1);
            if isempty(sIdx); return; end
            sd = obj.SensorData(sIdx);

            % Collect all events for this sensor
            sensorEvents = obj.Events(arrayfun(@(e) strcmp(e.SensorName, ev.SensorName), obj.Events));

            % Build Sensor object with datetime X for axis formatting
            sensor = obj.buildSensor(sd);
            sensor.X = datetime(sd.t, 'ConvertFrom', 'datenum');

            % Y range for shaded event regions (data + thresholds + padding)
            yLo = min(sd.y); yHi = max(sd.y);
            if isfield(sd, 'thresholdRules') && ~isempty(sd.thresholdRules)
                for i = 1:numel(sd.thresholdRules)
                    yLo = min(yLo, sd.thresholdRules{i}.Value);
                    yHi = max(yHi, sd.thresholdRules{i}.Value);
                end
            end
            yPad = max((yHi - yLo) * 0.15, 1);
            yLo = yLo - yPad; yHi = yHi + yPad;

            % Minimum visible event width (1 minute in datenum)
            minWidth = 1 / 1440;

            % --- Dashboard: 2 rows, 1 column (light theme) ---
            dashboard = FastPlotFigure(2, 1, 'Theme', 'light', ...
                'Name', sprintf('Event: %s — %s', ev.SensorName, ev.ThresholdLabel));

            % Get selected event's threshold color
            evColor = obj.getThresholdColor(ev.ThresholdLabel);

            % --- Tile 1: event detail (zoomed) ---
            fp1 = dashboard.tile(1);
            fp1.addSensor(sensor, 'ShowThresholds', true);
            evEnd = max(ev.EndTime, ev.StartTime + minWidth);
            fp1.addShaded([ev.StartTime, evEnd], [yLo, yLo], [yHi, yHi], ...
                'FaceColor', evColor, 'FaceAlpha', 0.20);

            % --- Tile 2: full timeline with all events ---
            fp2 = dashboard.tile(2);
            fp2.addSensor(sensor, 'ShowThresholds', true);
            for i = 1:numel(sensorEvents)
                e = sensorEvents(i);
                eEnd = max(e.EndTime, e.StartTime + minWidth);
                eColor = obj.getThresholdColor(e.ThresholdLabel);
                isSelected = (e.StartTime == ev.StartTime) && ...
                    strcmp(e.ThresholdLabel, ev.ThresholdLabel);
                if isSelected
                    a = 0.4;
                else
                    a = 0.15;
                end
                fp2.addShaded([e.StartTime, eEnd], [yLo, yLo], [yHi, yHi], ...
                    'FaceColor', eColor, 'FaceAlpha', a);
            end

            % Titles and labels (buffered — applied automatically during render)
            durationStr = obj.formatDuration(ev.Duration);
            dashboard.tileTitle(1, sprintf('Event Detail — %s [%s]  (Peak: %.2f, Duration: %s)', ...
                ev.SensorName, ev.ThresholdLabel, ev.PeakValue, durationStr));
            dashboard.tileTitle(2, sprintf('Full Timeline — %s  (%d events)', ...
                ev.SensorName, numel(sensorEvents)));
            dashboard.tileXLabel(1, 'Time');
            dashboard.tileYLabel(1, ev.SensorName);
            dashboard.tileXLabel(2, 'Time');
            dashboard.tileYLabel(2, ev.SensorName);

            dashboard.render();

            % Zoom tile 1 to event timespan with context
            xMargin = max(ev.Duration * 5, 5/1440);  % 5x duration or at least 5 minutes
            set(fp1.hAxes, 'XLim', [ev.StartTime - xMargin, ev.EndTime + xMargin]);

            % Set YLim on both tiles to include all thresholds
            set(fp1.hAxes, 'YLim', [yLo, yHi]);
            set(fp2.hAxes, 'YLim', [yLo, yHi]);

            % Clamp tile 2 X range to full sensor data, max +/- 1 year
            xDataLo = max(sd.t(1), ev.StartTime - 365);
            xDataHi = min(sd.t(end), ev.EndTime + 365);
            set(fp2.hAxes, 'XLim', [xDataLo, xDataHi]);

            % Draw selection rectangle on the full timeline (tile 2)
            evEnd = max(ev.EndTime, ev.StartTime + minWidth);
            rectangle(fp2.hAxes, ...
                'Position', [ev.StartTime, yLo, evEnd - ev.StartTime, yHi - yLo], ...
                'EdgeColor', evColor, 'LineWidth', 2, 'LineStyle', '-', ...
                'HandleVisibility', 'off');

            FastPlotToolbar(fp1);
        end

        function c = getThresholdColor(obj, label)
            %GETTHRESHOLDCOLOR Look up RGB color for a threshold label.
            if obj.ThresholdColors.isKey(label)
                c = obj.ThresholdColors(label);
            else
                c = [0.5 0.5 0.5];  % grey fallback
            end
        end

        function sensor = buildSensor(~, sd)
            %BUILDSENSOR Create a resolved Sensor from sensor data struct.
            sensor = Sensor(sd.name, 'Name', sd.name);
            sensor.X = sd.t;
            sensor.Y = sd.y;
            if isfield(sd, 'thresholdRules') && ~isempty(sd.thresholdRules)
                for i = 1:numel(sd.thresholdRules)
                    r = sd.thresholdRules{i};
                    args = {'Direction', r.Direction, 'Label', r.Label};
                    if ~isempty(r.Color)
                        args = [args, {'Color', r.Color}]; %#ok<AGROW>
                    end
                    if ~isempty(r.LineStyle)
                        args = [args, {'LineStyle', r.LineStyle}]; %#ok<AGROW>
                    end
                    sensor.addThresholdRule(struct(), r.Value, args{:});
                end
            end
            sensor.resolve();
        end

        function scrollTableToRow(obj, row)
            %SCROLLTABLETOROW Scroll uitable so the given row is visible.
            try
                jScrollPane = findjobj(obj.hTable);
                if ~isempty(jScrollPane)
                    jTable = jScrollPane.getViewport().getView();
                    jTable.scrollRectToVisible(jTable.getCellRect(row - 1, 0, true));
                end
            catch
                % findjobj or Java call unavailable — highlight still works
            end
        end
    end

    methods (Static, Access = private)
        function str = formatDuration(dur)
            %FORMATDURATION Convert datenum duration to readable string.
            %   dur is in days (datenum units).
            secs = dur * 86400;
            if secs < 60
                str = sprintf('%.1f s', secs);
            elseif secs < 3600
                str = sprintf('%dm %ds', floor(secs/60), round(mod(secs, 60)));
            else
                str = sprintf('%dh %dm', floor(secs/3600), round(mod(secs, 3600)/60));
            end
        end

        function tc = deserializeThresholdColors(data, sensorData)
            %DESERIALIZETHRESHOLDCOLORS Parse thresholdColors from loaded file data.
            tc = containers.Map();
            if isfield(data, 'thresholdColors') && isstruct(data.thresholdColors) ...
                    && ~isempty(fieldnames(data.thresholdColors))
                fields = fieldnames(data.thresholdColors);
                for i = 1:numel(fields)
                    entry = data.thresholdColors.(fields{i});
                    tc(entry.label) = entry.rgb;
                end
            elseif nargin >= 2 && ~isempty(sensorData)
                tc = EventViewer.extractThresholdColors(sensorData);
            end
        end

        function colors = extractThresholdColors(sensorData)
            %EXTRACTTHRESHOLDCOLORS Build label->RGB map from sensorData threshold rules.
            colors = containers.Map();
            for i = 1:numel(sensorData)
                sd = sensorData(i);
                if ~isfield(sd, 'thresholdRules') || isempty(sd.thresholdRules)
                    continue;
                end
                for j = 1:numel(sd.thresholdRules)
                    r = sd.thresholdRules{j};
                    if ~isempty(r.Color) && ~isempty(r.Label) && ~colors.isKey(r.Label)
                        colors(r.Label) = r.Color;
                    end
                end
            end
        end
    end
end
