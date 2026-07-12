classdef ScatterWidget < DashboardWidget
    properties (Access = public)
        SensorX     = []       % Sensor for X axis
        SensorY     = []       % Sensor for Y axis
        SensorColor = []       % Optional: color-code by third sensor
        MarkerSize  = 6
        Colormap    = 'parula'
    end

    properties (SetAccess = private)
        hAxes = []
        hScatter = []
    end

    methods
        function obj = ScatterWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 8 4];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.12 0.13 0.82 0.65], ...
                'Color', theme.WidgetBackground, ...
                'XColor', theme.AxisColor, ...
                'YColor', theme.AxisColor);
            % Phase 3 — title as a header band above the axes (no in-axes overlap).
            obj.drawPanelTitle_(parentPanel, theme);
            obj.refresh();
        end

        function refresh(obj)
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            xData = [];
            yData = [];
            if ~isempty(obj.SensorX) && ~isempty(obj.SensorY)
                % Read via the Tag.getXY() contract (Derived/Composite tags have no .Y).
                [~, yx] = obj.SensorX.getXY();
                [~, yy] = obj.SensorY.getXY();
                if isempty(yx) || isempty(yy), return; end
                n = min(numel(yx), numel(yy));
                xData = yx(1:n);
                yData = yy(1:n);
            end
            if isempty(xData), return; end

            % In-place update: avoid cla() + full object recreation on every tick.
            % A live scatter grows by appending new samples, so we can update
            % XData/YData on the existing graphics object rather than destroying
            % and rebuilding it.  Fall back to full rebuild when:
            %   - no existing handle yet (first render, or handle was deleted)
            %   - SensorColor is wired (CData must stay consistent with new n;
            %     simpler to rebuild than splice in new color rows)
            canUpdateInPlace = ~isempty(obj.hScatter) && ishandle(obj.hScatter) && ...
                isempty(obj.SensorColor);
            if canUpdateInPlace
                try
                    set(obj.hScatter, 'XData', xData, 'YData', yData);
                    return;
                catch
                    % Handle invalidated — fall through to full rebuild.
                end
            end

            cla(obj.hAxes);
            cData = [];
            if ~isempty(obj.SensorColor)
                [~, yc] = obj.SensorColor.getXY();
                if ~isempty(yc)
                    cData = yc(1:min(numel(yc), numel(xData)));
                end
            end
            if ~isempty(cData)
                % Use line with markers for Octave compatibility
                obj.hScatter = scatter(obj.hAxes, xData, yData, obj.MarkerSize, cData, 'filled');
                colormap(obj.hAxes, obj.Colormap);
                colorbar(obj.hAxes);
            else
                obj.hScatter = line(xData, yData, ...
                    'Parent', obj.hAxes, ...
                    'LineStyle', 'none', ...
                    'Marker', '.', ...
                    'MarkerSize', obj.MarkerSize);
            end

            % Auto-derive axis labels from SensorX/SensorY if present.
            % Only set them on first build (not on every in-place update).
            if ~isempty(obj.SensorX)
                xl = obj.axisLabelForSensor_(obj.SensorX);
                if ~isempty(xl), xlabel(obj.hAxes, xl); end
            end
            if ~isempty(obj.SensorY)
                yl = obj.axisLabelForSensor_(obj.SensorY);
                if ~isempty(yl), ylabel(obj.hAxes, yl); end
            end

            % Re-apply theme after plot commands. cla()/scatter() run newplot,
            % which resets the axes background + axis colors to their light-mode
            % defaults — leaving a glaring white box with dark-on-dark labels in
            % dark mode. Restore the themed colors (axes, ticks, labels, title)
            % on every rebuild. (The in-place update path above returns early and
            % never replots, so it needs no restore.)
            theme = obj.getTheme();
            set(obj.hAxes, 'Color', theme.WidgetBackground, ...
                'XColor', theme.AxisColor, 'YColor', theme.AxisColor);
            set(get(obj.hAxes, 'XLabel'), 'Color', theme.ForegroundColor);
            set(get(obj.hAxes, 'YLabel'), 'Color', theme.ForegroundColor);
            if ~isempty(obj.Title)
                title(obj.hAxes, obj.Title, ...
                    'Color', theme.ForegroundColor, ...
                    'FontSize', theme.WidgetTitleFontSize);
            end
        end

        function t = getType(~)
            t = 'scatter';
        end

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                yx = []; yy = [];
                if ~isempty(obj.SensorX), [~, yx] = obj.SensorX.getXY(); end
                if ~isempty(obj.SensorY), [~, yy] = obj.SensorY.getXY(); end
                if ~isempty(yx) && ~isempty(yy)
                    n = min(numel(yx), numel(yy));
                    info = sprintf('%d points', n);
                else
                    info = '[-- scatter --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.markerSize = obj.MarkerSize;
            s.colormap = obj.Colormap;
            % Override source with dual-sensor info
            if ~isempty(obj.SensorX)
                s.sensorX = obj.SensorX.Key;
            end
            if ~isempty(obj.SensorY)
                s.sensorY = obj.SensorY.Key;
            end
            if ~isempty(obj.SensorColor)
                s.sensorColor = obj.SensorColor.Key;
            end
        end
    end

    methods (Access = private)
        function lbl = axisLabelForSensor_(~, s)
        %AXISLABELFORSENSOR_ Build "Name (Units)" label with graceful fallbacks.
            lbl = '';
            if isempty(s), return; end
            name = '';
            if isprop(s, 'Name') && ~isempty(s.Name)
                name = s.Name;
            elseif isprop(s, 'Key') && ~isempty(s.Key)
                name = s.Key;
            end
            if isempty(name), return; end
            units = '';
            if isprop(s, 'Units') && ~isempty(s.Units)
                units = s.Units;
            end
            if isempty(units)
                lbl = name;
            else
                lbl = sprintf('%s (%s)', name, units);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = ScatterWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'markerSize'), obj.MarkerSize = s.markerSize; end
            if isfield(s, 'colormap'), obj.Colormap = s.colormap; end
            % Restore the dual-sensor bindings via TagRegistry — dropped before P0-3.
            % Old structs without these keys load with no binding and no warning.
            if isfield(s, 'sensorX'), obj.SensorX = ScatterWidget.resolveTag_(s.sensorX, obj.Title); end
            if isfield(s, 'sensorY'), obj.SensorY = ScatterWidget.resolveTag_(s.sensorY, obj.Title); end
            if isfield(s, 'sensorColor'), obj.SensorColor = ScatterWidget.resolveTag_(s.sensorColor, obj.Title); end
        end

        function t = resolveTag_(key, title)
        %RESOLVETAG_ Resolve a Tag key via TagRegistry; warn (no throw) if absent.
        %   Mirrors FastSenseWidget:tagNotFound semantics: a missing key yields []
        %   and a namespaced warning rather than an error, so a dashboard saved
        %   against a different registry still loads.
            t = [];
            if isempty(key), return; end
            if exist('TagRegistry', 'class')
                try
                    t = TagRegistry.get(key);
                catch
                    t = [];
                    warning('ScatterWidget:sourceUnresolved', ...
                        'Unresolved sensor ''%s'' for Scatter ''%s''.', key, title);
                end
            end
        end
    end
end
