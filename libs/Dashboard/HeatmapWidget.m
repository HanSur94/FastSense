classdef HeatmapWidget < DashboardWidget
    properties (Access = public)
        DataFcn     = []           % function_handle returning matrix
        Colormap    = 'parula'     % colormap name or Nx3 matrix
        ShowColorbar = true
        XLabels     = {}           % cell array of axis labels
        YLabels     = {}           % cell array of axis labels
    end

    properties (SetAccess = private)
        hAxes       = []
        hImage      = []
        hColorbar   = []
    end

    methods
        function obj = HeatmapWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 8 4];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();
            bg = theme.WidgetBackground;

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.1 0.1 0.8 0.8], ...
                'Color', bg, ...
                'XColor', theme.AxisColor, ...
                'YColor', theme.AxisColor);

            obj.refresh();
        end

        function refresh(obj)
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            data = [];
            if ~isempty(obj.Sensor)
                if isempty(obj.Sensor.Y), return; end
                data = obj.Sensor.Y;
            elseif ~isempty(obj.DataFcn)
                data = obj.DataFcn();
            end
            if isempty(data), return; end

            % Ensure data is 2D matrix
            if isvector(data)
                data = data(:)';
            end

            obj.hImage = imagesc(obj.hAxes, data);
            colormap(obj.hAxes, obj.Colormap);
            if obj.ShowColorbar
                obj.hColorbar = colorbar(obj.hAxes);
            end
            if ~isempty(obj.XLabels)
                set(obj.hAxes, 'XTick', 1:numel(obj.XLabels), ...
                    'XTickLabel', obj.XLabels);
            end
            if ~isempty(obj.YLabels)
                set(obj.hAxes, 'YTick', 1:numel(obj.YLabels), ...
                    'YTickLabel', obj.YLabels);
            end
        end

        function t = getType(~)
            t = 'heatmap';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.colormap = obj.Colormap;
            s.showColorbar = obj.ShowColorbar;
            if ~isempty(obj.XLabels), s.xLabels = obj.XLabels; end
            if ~isempty(obj.YLabels), s.yLabels = obj.YLabels; end
            if ~isempty(obj.DataFcn) && isempty(obj.Sensor)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.DataFcn));
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = HeatmapWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'colormap'), obj.Colormap = s.colormap; end
            if isfield(s, 'showColorbar'), obj.ShowColorbar = s.showColorbar; end
            if isfield(s, 'xLabels'), obj.XLabels = s.xLabels; end
            if isfield(s, 'yLabels'), obj.YLabels = s.yLabels; end
        end
    end
end
