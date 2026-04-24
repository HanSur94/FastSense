classdef BarChartWidget < DashboardWidget
    properties (Access = public)
        DataFcn      = []           % @() struct('categories',{},'values',[])
        Orientation  = 'vertical'   % 'vertical' or 'horizontal'
        Stacked      = false
    end

    properties (SetAccess = private)
        hAxes = []
        hBars = []
    end

    methods
        function obj = BarChartWidget(varargin)
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
                'Position', [0.12 0.15 0.82 0.75], ...
                'Color', theme.WidgetBackground, ...
                'XColor', theme.AxisColor, ...
                'YColor', theme.AxisColor);
            if ~isempty(obj.Title)
                title(obj.hAxes, obj.Title, ...
                    'Color', theme.ForegroundColor, ...
                    'FontSize', theme.WidgetTitleFontSize);
            end
            obj.refresh();
        end

        function refresh(obj)
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            data = [];
            cats = {};
            if ~isempty(obj.Sensor)
                if isempty(obj.Sensor.Y), return; end
                data = obj.Sensor.Y;
            elseif ~isempty(obj.DataFcn)
                result = obj.DataFcn();
                if isstruct(result)
                    cats = result.categories;
                    data = result.values;
                else
                    data = result;
                end
            end
            if isempty(data), return; end

            if ~isempty(obj.hBars) && all(ishandle(obj.hBars))
                try
                    if numel(get(obj.hBars(1), 'YData')) == numel(data)
                        for bi = 1:numel(obj.hBars)
                            set(obj.hBars(bi), 'YData', data);
                        end
                    else
                        error('size:mismatch', 'fall through');
                    end
                catch
                    cla(obj.hAxes);
                    if strcmp(obj.Orientation, 'horizontal')
                        obj.hBars = barh(obj.hAxes, data);
                    else
                        obj.hBars = bar(obj.hAxes, data);
                    end
                end
            else
                cla(obj.hAxes);
                if strcmp(obj.Orientation, 'horizontal')
                    obj.hBars = barh(obj.hAxes, data);
                else
                    obj.hBars = bar(obj.hAxes, data);
                end
            end
            if ~isempty(cats)
                if strcmp(obj.Orientation, 'horizontal')
                    set(obj.hAxes, 'YTick', 1:numel(cats), 'YTickLabel', cats);
                else
                    set(obj.hAxes, 'XTick', 1:numel(cats), 'XTickLabel', cats);
                end
            end
            % Re-apply title after plot commands (bar/barh may clear via newplot)
            if ~isempty(obj.Title)
                theme = obj.getTheme();
                title(obj.hAxes, obj.Title, ...
                    'Color', theme.ForegroundColor, ...
                    'FontSize', theme.WidgetTitleFontSize);
            end
        end

        function t = getType(~)
            t = 'barchart';
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
                info = sprintf('[%s barchart]', obj.Orientation);
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.orientation = obj.Orientation;
            s.stacked = obj.Stacked;
            if ~isempty(obj.DataFcn) && isempty(obj.Sensor)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.DataFcn));
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = BarChartWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'orientation'), obj.Orientation = s.orientation; end
            if isfield(s, 'stacked'), obj.Stacked = s.stacked; end
        end
    end
end
