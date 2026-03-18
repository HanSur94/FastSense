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

            cla(obj.hAxes);
            if strcmp(obj.Orientation, 'horizontal')
                obj.hBars = barh(obj.hAxes, data);
            else
                obj.hBars = bar(obj.hAxes, data);
            end
            if ~isempty(cats)
                if strcmp(obj.Orientation, 'horizontal')
                    set(obj.hAxes, 'YTick', 1:numel(cats), 'YTickLabel', cats);
                else
                    set(obj.hAxes, 'XTick', 1:numel(cats), 'XTickLabel', cats);
                end
            end
        end

        function t = getType(~)
            t = 'barchart';
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
