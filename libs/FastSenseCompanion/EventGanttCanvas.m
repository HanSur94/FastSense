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

    properties (Access = private)
        CrosshairFigure_      = []   % uifigure host (set by installCrosshair)
        CrosshairPrevMotion_  = []   % saved figure WindowButtonMotionFcn for chaining
        hCrosshairLine        = []   % vertical line tracking cursor X (created lazily on first move)
        hCrosshairText        = []   % datetime annotation at top of crosshair line
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
                'Color',                obj.Theme.WidgetBackground, ...
                'XColor',               obj.Theme.ForegroundColor, ...
                'YColor',               obj.Theme.ForegroundColor, ...
                'GridColor',            [0.25 0.25 0.25], ...   % dark grey, theme-independent
                'GridAlpha',            0.55, ...
                'XGrid',                'on', ...
                'YGrid',                'on', ...
                'GridLineStyle',        ':', ...
                'Layer',                'top', ...
                'TickLabelInterpreter', 'none');
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
            % Restore figure callbacks before destroying our crosshair handles.
            try; obj.uninstallCrosshair(); catch; end
        end

        function installCrosshair(obj, hFigure)
        %INSTALLCROSSHAIR Wire a vertical crosshair that tracks the cursor over the Gantt axes.
        %   installCrosshair(hFigure) chains onto the figure's existing
        %   WindowButtonMotionFcn so the slider's drag handler keeps working.
        %   No-op if already installed.
            if ~isempty(obj.CrosshairFigure_); return; end
            if isempty(hFigure) || ~isgraphics(hFigure); return; end
            obj.CrosshairFigure_     = hFigure;
            obj.CrosshairPrevMotion_ = get(hFigure, 'WindowButtonMotionFcn');
            set(hFigure, 'WindowButtonMotionFcn', @(s, e) obj.onMouseMove_(s, e));
        end

        function uninstallCrosshair(obj)
        %UNINSTALLCROSSHAIR Restore the previous WindowButtonMotionFcn and delete crosshair graphics.
            if isempty(obj.CrosshairFigure_); return; end
            try
                if isgraphics(obj.CrosshairFigure_)
                    set(obj.CrosshairFigure_, 'WindowButtonMotionFcn', obj.CrosshairPrevMotion_);
                end
            catch
            end
            obj.CrosshairFigure_     = [];
            obj.CrosshairPrevMotion_ = [];
            if ~isempty(obj.hCrosshairLine) && isgraphics(obj.hCrosshairLine)
                delete(obj.hCrosshairLine);
            end
            obj.hCrosshairLine = [];
            if ~isempty(obj.hCrosshairText) && isgraphics(obj.hCrosshairText)
                delete(obj.hCrosshairText);
            end
            obj.hCrosshairText = [];
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

        function onMouseMove_(obj, src, evt)
        %ONMOUSEMOVE_ Update the vertical crosshair when the cursor is over the Gantt axes.
        %   Chains to the previously-saved WindowButtonMotionFcn so other
        %   listeners (TimeRangeSelector slider drag) keep functioning.
            % Always defer to the chained handler first — slider drag must keep
            % responding even when the cursor is outside the Gantt axes.
            try
                if ~isempty(obj.CrosshairPrevMotion_)
                    if isa(obj.CrosshairPrevMotion_, 'function_handle')
                        feval(obj.CrosshairPrevMotion_, src, evt);
                    end
                end
            catch
                % Don't let chained-handler failures crash the crosshair.
            end

            if isempty(obj.hAxes) || ~isgraphics(obj.hAxes); return; end

            % Get cursor position in axes data units.
            cp = get(obj.hAxes, 'CurrentPoint');
            xp = cp(1, 1);
            yp = cp(1, 2);
            xlims = get(obj.hAxes, 'XLim');
            ylims = get(obj.hAxes, 'YLim');

            % Hide crosshair when cursor is outside the axes.
            if xp < xlims(1) || xp > xlims(2) || yp < ylims(1) || yp > ylims(2)
                if ~isempty(obj.hCrosshairLine) && isgraphics(obj.hCrosshairLine)
                    set(obj.hCrosshairLine, 'Visible', 'off');
                end
                if ~isempty(obj.hCrosshairText) && isgraphics(obj.hCrosshairText)
                    set(obj.hCrosshairText, 'Visible', 'off');
                end
                return;
            end

            % Format datetime label for the crosshair.
            try
                dtStr = datestr(xp, 'yyyy-mm-dd HH:MM:SS');
            catch
                dtStr = sprintf('%.4g', xp);
            end

            if isempty(obj.hCrosshairLine) || ~isgraphics(obj.hCrosshairLine)
                hold(obj.hAxes, 'on');
                obj.hCrosshairLine = line([xp xp], ylims, 'Parent', obj.hAxes, ...
                    'Color', [0.5 0.5 0.5], 'LineStyle', '-', 'LineWidth', 1, ...
                    'HandleVisibility', 'off', 'HitTest', 'off', ...
                    'PickableParts', 'none', 'Tag', 'GanttCrosshair');
                obj.hCrosshairText = text(xp, ylims(1), dtStr, 'Parent', obj.hAxes, ...
                    'FontSize', 9, 'HorizontalAlignment', 'left', ...
                    'VerticalAlignment', 'top', 'BackgroundColor', 'w', ...
                    'EdgeColor', [0.5 0.5 0.5], 'Margin', 2, ...
                    'HandleVisibility', 'off', 'HitTest', 'off', ...
                    'PickableParts', 'none', 'Tag', 'GanttCrosshairText');
                hold(obj.hAxes, 'off');
            else
                set(obj.hCrosshairLine, 'XData', [xp xp], 'YData', ylims, 'Visible', 'on');
                set(obj.hCrosshairText, 'Position', [xp ylims(1) 0], 'String', dtStr, 'Visible', 'on');
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
