classdef EventTimelineWidget < DashboardWidget
%EVENTTIMELINEWIDGET Displays events as colored bars on a timeline.
%
%   w = EventTimelineWidget('Title', 'Events', 'Events', eventArray);
%   w = EventTimelineWidget('Title', 'Events', 'EventFcn', @() getEvents());
%
%   Events must be a struct array with fields:
%     startTime, endTime, label, color (optional)

    properties (Access = public)
        Events    = []      % struct array of events
        EventFcn  = []      % function_handle returning events
    end

    properties (SetAccess = private)
        hAxes     = []
        hBars     = {}
    end

    methods
        function obj = EventTimelineWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 12 2];
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
        end

        function refresh(obj)
            events = [];
            if ~isempty(obj.EventFcn)
                events = obj.EventFcn();
            elseif ~isempty(obj.Events)
                events = obj.Events;
            end

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
            if ~isempty(obj.EventFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.EventFcn));
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = EventTimelineWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'source') && strcmp(s.source.type, 'callback')
                obj.EventFcn = str2func(s.source.function);
            end
        end
    end

    methods (Access = private)
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
