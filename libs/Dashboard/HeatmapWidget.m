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

            if ~isempty(obj.hImage) && ishandle(obj.hImage)
                set(obj.hImage, 'CData', data);
            else
                obj.hImage = imagesc(obj.hAxes, data);
                colormap(obj.hAxes, obj.Colormap);
                if obj.ShowColorbar
                    obj.hColorbar = colorbar(obj.hAxes);
                end
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

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                nX = numel(obj.XLabels);
                nY = numel(obj.YLabels);
                if nX > 0 && nY > 0
                    info = sprintf('%dx%d heatmap', nY, nX);
                else
                    info = '[-- heatmap --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
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
