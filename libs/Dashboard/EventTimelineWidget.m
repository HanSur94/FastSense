classdef EventTimelineWidget < DashboardWidget
%EVENTTIMELINEWIDGET Displays events as colored bars on a timeline.
%
%   Preferred: bind to an EventStore from the event detection system:
%     w = EventTimelineWidget('Title', 'Events', 'EventStoreObj', store);
%
%   Legacy (still supported for backwards compatibility):
%     w = EventTimelineWidget('Title', 'Events', 'EventFcn', @() getEvents());
%     w = EventTimelineWidget('Title', 'Events', 'Events', eventArray);
%
%   Events must be a struct array with fields:
%     startTime, endTime, label, color (optional)

    properties (Access = public)
        EventStoreObj = []  % EventStore handle — primary data source
        Events    = []      % struct array of events (legacy)
        EventFcn  = []      % function_handle returning events (legacy)
    end

    properties (SetAccess = private)
        hAxes     = []
        hBars     = {}
        IsSettingTime = false  % guard for programmatic vs user xlim change
    end

    methods
        function obj = EventTimelineWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 24 2];
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.06 0.15 0.9 0.7], ...
                'FontName', fontName, ...
                'FontSize', theme.WidgetTitleFontSize - 1, ...
                'XColor', fgColor, ...
                'YColor', fgColor, ...
                'Color', theme.AxesColor, ...
                'YDir', 'reverse');
            hold(obj.hAxes, 'on');

            if ~isempty(obj.Title)
                title(obj.hAxes, obj.Title, ...
                    'Color', fgColor, ...
                    'FontSize', theme.WidgetTitleFontSize);
            end

            obj.refresh();

            % Listen for manual zoom/pan to detach from global time
            try
                addlistener(obj.hAxes, 'XLim', 'PostSet', @(~,~) obj.onXLimChanged());
            catch
            end
        end

        function setTimeRange(obj, tStart, tEnd)
            if ~obj.UseGlobalTime
                return;
            end
            if ~isempty(obj.hAxes) && ishandle(obj.hAxes)
                obj.IsSettingTime = true;
                xlim(obj.hAxes, [tStart tEnd]);
                obj.IsSettingTime = false;
            end
        end

        function [tMin, tMax] = getTimeRange(obj)
            tMin = inf; tMax = -inf;
            evts = obj.resolveEvents();
            if ~isempty(evts)
                for i = 1:numel(evts)
                    if evts(i).startTime < tMin, tMin = evts(i).startTime; end
                    if evts(i).endTime > tMax, tMax = evts(i).endTime; end
                end
            end
        end

        function refresh(obj)
            events = obj.resolveEvents();

            if isempty(events) || isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            % Clear old bars
            for i = 1:numel(obj.hBars)
                if ishandle(obj.hBars{i})
                    delete(obj.hBars{i});
                end
            end
            obj.hBars = {};

            theme = obj.getTheme();
            defaultColors = [theme.StatusOkColor; theme.StatusWarnColor; theme.StatusAlarmColor];

            % Get unique labels for y-axis lanes
            labels = {};
            for i = 1:numel(events)
                if isfield(events(i), 'label') && ~isempty(events(i).label)
                    if ~any(strcmp(labels, events(i).label))
                        labels{end+1} = events(i).label;
                    end
                end
            end
            if isempty(labels)
                labels = {'Events'};
            end

            barHeight = 0.6;
            for i = 1:numel(events)
                ev = events(i);
                x = ev.startTime;
                w = ev.endTime - ev.startTime;
                if w <= 0
                    w = 1;
                end

                % Find lane
                lane = 1;
                if isfield(ev, 'label') && ~isempty(ev.label)
                    lane = find(strcmp(labels, ev.label), 1);
                    if isempty(lane)
                        lane = 1;
                    end
                end

                y = lane - barHeight/2;

                % Color
                if isfield(ev, 'color') && ~isempty(ev.color)
                    c = ev.color;
                else
                    c = defaultColors(mod(i-1, size(defaultColors,1)) + 1, :);
                end

                hBar = fill(obj.hAxes, ...
                    [x, x+w, x+w, x], ...
                    [y, y, y+barHeight, y+barHeight], ...
                    c, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
                obj.hBars{end+1} = hBar;
            end

            set(obj.hAxes, 'YTick', 1:numel(labels), 'YTickLabel', labels);
            set(obj.hAxes, 'YLim', [0.3, numel(labels) + 0.7]);
        end

        function configure(~)
        end

        function t = getType(~)
            t = 'timeline';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.EventStoreObj)
                s.source = struct('type', 'eventstore', ...
                    'path', obj.EventStoreObj.FilePath);
            elseif ~isempty(obj.EventFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.EventFcn));
            elseif ~isempty(obj.Events)
                s.source = struct('type', 'static', 'events', obj.Events);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = EventTimelineWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'source')
                if strcmp(s.source.type, 'eventstore') && isfield(s.source, 'path')
                    obj.EventStoreObj = EventStore(s.source.path);
                elseif strcmp(s.source.type, 'callback')
                    obj.EventFcn = str2func(s.source.function);
                elseif strcmp(s.source.type, 'static') && isfield(s.source, 'events')
                    obj.Events = s.source.events;
                end
            end
        end
    end

    methods (Access = private)
        function evts = resolveEvents(obj)
        %RESOLVEEVENTS Get events from the best available source.
        %   Priority: EventStoreObj > EventFcn > Events (static)
            evts = [];
            if ~isempty(obj.EventStoreObj)
                evts = obj.eventStoreToStructs();
            elseif ~isempty(obj.EventFcn)
                evts = obj.EventFcn();
            elseif ~isempty(obj.Events)
                evts = obj.Events;
            end
        end

        function evts = eventStoreToStructs(obj)
        %EVENTSTORETOSTRUCTS Convert Event objects from EventStore to
        %   the struct format used for rendering (startTime, endTime, label, color).
            evts = struct('startTime', {}, 'endTime', {}, 'label', {}, 'color', {});
            raw = obj.EventStoreObj.getEvents();
            if isempty(raw), return; end

            theme = obj.getTheme();
            alarmColor = theme.StatusAlarmColor;
            warnColor  = theme.StatusWarnColor;

            for i = 1:numel(raw)
                ev = raw(i);
                lbl = ev.SensorName;
                if ~isempty(ev.ThresholdLabel)
                    lbl = [ev.SensorName ' — ' ev.ThresholdLabel];
                end
                % Color based on direction/severity hint in label
                if ~isempty(strfind(lower(ev.ThresholdLabel), 'alarm')) %#ok<STREMP>
                    clr = alarmColor;
                else
                    clr = warnColor;
                end
                evts(end+1) = struct('startTime', ev.StartTime, ...
                    'endTime', ev.EndTime, 'label', lbl, 'color', clr); %#ok<AGROW>
            end
        end

        function onXLimChanged(obj)
            if ~obj.IsSettingTime
                obj.UseGlobalTime = false;
            end
        end

        function theme = getTheme(obj)
            theme = DashboardTheme();
            if ~isempty(fieldnames(obj.ThemeOverride))
                fns = fieldnames(obj.ThemeOverride);
                for i = 1:numel(fns)
                    theme.(fns{i}) = obj.ThemeOverride.(fns{i});
                end
            end
        end
    end
end
