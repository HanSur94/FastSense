classdef HistogramWidget < DashboardWidget
    properties (Access = public)
        DataFcn       = []
        NumBins       = []       % empty = auto
        ShowNormalFit = false
        EdgeColor     = []       % RGB or empty for default
    end

    properties (SetAccess = private)
        hAxes = []
    end

    methods
        function obj = HistogramWidget(varargin)
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
            if ~obj.Dirty
                return;
            end

            data = [];
            if ~isempty(obj.Sensor)
                if isempty(obj.Sensor.Y), return; end
                data = obj.Sensor.Y(:)';
            elseif ~isempty(obj.DataFcn)
                data = obj.DataFcn();
                data = data(:)';
            end
            if isempty(data), return; end

            nBins = obj.NumBins;
            if isempty(nBins)
                nBins = max(10, round(sqrt(numel(data))));
            end

            [counts, edges] = histcounts(data, nBins);
            centers = (edges(1:end-1) + edges(2:end)) / 2;

            cla(obj.hAxes);
            bar(obj.hAxes, centers, counts, 1);

            if obj.ShowNormalFit && numel(data) > 2
                hold(obj.hAxes, 'on');
                mu = mean(data);
                sigma = std(data);
                xFit = linspace(min(data), max(data), 100);
                binWidth = edges(2) - edges(1);
                yFit = numel(data) * binWidth * ...
                    (1 / (sigma * sqrt(2*pi))) * exp(-0.5 * ((xFit - mu) / sigma).^2);
                plot(obj.hAxes, xFit, yFit, 'r-', 'LineWidth', 1.5);
                hold(obj.hAxes, 'off');
            end
            obj.Dirty = false;
        end

        function t = getType(~)
            t = 'histogram';
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
                hasData = (~isempty(obj.Sensor) && ~isempty(obj.Sensor.Y)) || ...
                          ~isempty(obj.DataFcn);
                if hasData && ~isempty(obj.Sensor)
                    info = sprintf('%d data points', numel(obj.Sensor.Y));
                else
                    info = '[-- histogram --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.NumBins), s.numBins = obj.NumBins; end
            s.showNormalFit = obj.ShowNormalFit;
            if ~isempty(obj.EdgeColor), s.edgeColor = obj.EdgeColor; end
            if ~isempty(obj.DataFcn) && isempty(obj.Sensor)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.DataFcn));
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = HistogramWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'numBins'), obj.NumBins = s.numBins; end
            if isfield(s, 'showNormalFit'), obj.ShowNormalFit = s.showNormalFit; end
            if isfield(s, 'edgeColor'), obj.EdgeColor = s.edgeColor; end
        end
    end
end
