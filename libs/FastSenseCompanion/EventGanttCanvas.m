classdef EventGanttCanvas < handle
%EVENTGANTTCANVAS Gantt drawing + hit-testing helper for CompanionEventViewer.
%
%   Constructor: canvas = EventGanttCanvas(hAxes, theme)
%   Public:
%     canvas.draw(events, theme)              — redraw all bars (Task 5)
%     canvas.OnSingleClick / OnDoubleClick    — function handles (Task 5)
%   Static:
%     [map, keys] = EventGanttCanvas.computeRows(events)
%     rgb = EventGanttCanvas.severityColor(sev)
%     x   = EventGanttCanvas.eventEndOrNow(ev, nowRef)
%
%   See also CompanionEventViewer.

    properties (SetAccess = private)
        hAxes           % axes handle
        Theme           % CompanionTheme struct
        BarHandles      % rectangle/patch handles, Nx1
        BarEvents       % Event objects mirrored to handles, Nx1
    end

    properties
        OnSingleClick = []
        OnDoubleClick = []
    end

    methods
        function obj = EventGanttCanvas(hAxes, theme)
            %EVENTGANTTCANVAS Construct with a target axes and a CompanionTheme.
            obj.hAxes      = hAxes;
            obj.Theme      = theme;
            obj.BarHandles = [];
            obj.BarEvents  = Event.empty;
        end

        function draw(obj, events, theme)
        %DRAW Repaint the axes from scratch with the given event list + theme.
        %   Open events render with a dashed right edge extending to "now".
            if nargin >= 3 && ~isempty(theme); obj.Theme = theme; end

            % Clear prior handles.
            for i = 1:numel(obj.BarHandles)
                if isgraphics(obj.BarHandles(i)); delete(obj.BarHandles(i)); end
            end
            obj.BarHandles = [];
            obj.BarEvents  = Event.empty;

            cla(obj.hAxes);
            set(obj.hAxes, ...
                'Color',     obj.Theme.WidgetBackground, ...
                'XColor',    obj.Theme.ForegroundColor, ...
                'YColor',    obj.Theme.ForegroundColor, ...
                'GridColor', obj.Theme.WidgetBorderColor);
            hold(obj.hAxes, 'on');

            if isempty(events)
                set(obj.hAxes, 'YTick', [], 'YTickLabel', {});
                hold(obj.hAxes, 'off');
                return;
            end

            [rowMap, keys] = EventGanttCanvas.computeRows(events);
            barH = 0.6;
            nowRef = now;     % wall-clock reference for open events

            for i = 1:numel(events)
                ev = events(i);
                if ~isempty(ev.TagKeys)
                    rowKey = ev.TagKeys{1};
                else
                    rowKey = ev.SensorName;
                end
                if ~isKey(rowMap, rowKey); continue; end
                y = rowMap(rowKey);
                x0 = ev.StartTime;
                x1 = EventGanttCanvas.eventEndOrNow(ev, nowRef);
                rgb = EventGanttCanvas.severityColor(ev.Severity);
                hRect = patch(obj.hAxes, ...
                    [x0 x1 x1 x0], [y-barH/2 y-barH/2 y+barH/2 y+barH/2], ...
                    rgb, ...
                    'EdgeColor', 'none', ...
                    'FaceAlpha', 0.85, ...
                    'Tag',       'GanttBar', ...
                    'UserData',  i);

                if ev.IsOpen || isnan(ev.EndTime)
                    line(obj.hAxes, [x1 x1], [y-barH/2 y+barH/2], ...
                        'Color',     rgb, ...
                        'LineStyle', '--', ...
                        'LineWidth', 1.5, ...
                        'Tag',       'OpenEdge', ...
                        'UserData',  i);
                end
                obj.BarHandles(end+1) = hRect; %#ok<AGROW>
                obj.BarEvents(end+1)  = ev;     %#ok<AGROW>
            end

            set(obj.hAxes, ...
                'YDir',       'reverse', ...
                'YTick',      1:numel(keys), ...
                'YTickLabel', keys, ...
                'YLim',       [0.5, numel(keys) + 0.5]);

            % Datetime tick labels on the X axis (event times are datenums).
            try
                datetick(obj.hAxes, 'x', 'keeplimits');
            catch
            end

            hold(obj.hAxes, 'off');

            % Wire bar click handler — single + double click distinguished
            % via figure SelectionType in the callback.
            for i = 1:numel(obj.BarHandles)
                set(obj.BarHandles(i), 'ButtonDownFcn', @(src, ~) obj.onBarButtonDown_(src));
            end
        end

        function delete(obj)
        %DELETE Tear down handles. Theme/axes lifecycle owned by parent.
            for i = 1:numel(obj.BarHandles)
                if isgraphics(obj.BarHandles(i)); delete(obj.BarHandles(i)); end
            end
            obj.BarHandles = [];
            obj.BarEvents  = Event.empty;
        end
    end

    methods (Access = private)
        function onBarButtonDown_(obj, src)
            try
                idx = get(src, 'UserData');
                if ~isnumeric(idx) || idx < 1 || idx > numel(obj.BarEvents); return; end
                ev = obj.BarEvents(idx);
                fig = ancestor(obj.hAxes, 'figure');
                selType = '';
                if isgraphics(fig); selType = get(fig, 'SelectionType'); end
                if strcmp(selType, 'open')
                    if ~isempty(obj.OnDoubleClick); obj.OnDoubleClick(ev); end
                else
                    if ~isempty(obj.OnSingleClick); obj.OnSingleClick(ev); end
                end
            catch
                % Click handlers must never crash drawing.
            end
        end
    end

    methods (Static)
        function [map, keys] = computeRows(events)
            %COMPUTEROWS Build row-index map from an array of Event objects.
            %   [map, keys] = EventGanttCanvas.computeRows(events)
            %   map  - containers.Map: key (char) -> row index (double)
            %   keys - sorted column cellstr of unique row keys
            map = containers.Map('KeyType', 'char', 'ValueType', 'double');
            if isempty(events)
                keys = cell(0, 1);
                return;
            end
            allKeys = {};
            for i = 1:numel(events)
                ev = events(i);
                if ~isempty(ev.TagKeys)
                    allKeys = [allKeys; ev.TagKeys(:)]; %#ok<AGROW>
                else
                    allKeys = [allKeys; {ev.SensorName}]; %#ok<AGROW>
                end
            end
            keys = unique(allKeys);          % returns sorted column cellstr
            for i = 1:numel(keys)
                map(keys{i}) = i;
            end
        end

        function rgb = severityColor(sev)
            %SEVERITYCOLOR Return an RGB triple for the given severity level.
            %   rgb = EventGanttCanvas.severityColor(sev)
            %   sev = 1 -> green (info/ok)
            %   sev = 2 -> orange (warn)
            %   sev = 3 -> red (alarm)
            %   otherwise -> grey fallback
            switch double(sev)
                case 1,    rgb = [0.20 0.70 0.30];   % green  (info/ok)
                case 2,    rgb = [0.95 0.60 0.10];   % orange (warn)
                case 3,    rgb = [0.85 0.20 0.20];   % red    (alarm)
                otherwise, rgb = [0.50 0.50 0.50];   % grey   fallback
            end
        end

        function x = eventEndOrNow(ev, nowRef)
            %EVENTENDORNOW Return the display end time for an event.
            %   x = EventGanttCanvas.eventEndOrNow(ev, nowRef)
            %   For closed events returns ev.EndTime; for open or NaN-ended
            %   events returns nowRef so the bar extends to the current time.
            if ev.IsOpen || isnan(ev.EndTime)
                x = nowRef;
            else
                x = ev.EndTime;
            end
        end
    end
end
