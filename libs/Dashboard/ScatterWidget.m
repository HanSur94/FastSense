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

            xData = [];
            yData = [];
            if ~isempty(obj.SensorX) && ~isempty(obj.SensorY)
                if isempty(obj.SensorX.Y) || isempty(obj.SensorY.Y), return; end
                n = min(numel(obj.SensorX.Y), numel(obj.SensorY.Y));
                xData = obj.SensorX.Y(1:n);
                yData = obj.SensorY.Y(1:n);
            end
            if isempty(xData), return; end

            cla(obj.hAxes);
            if ~isempty(obj.SensorColor) && ~isempty(obj.SensorColor.Y)
                cData = obj.SensorColor.Y(1:min(numel(obj.SensorColor.Y), numel(xData)));
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
        end

        function t = getType(~)
            t = 'scatter';
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
        end
    end
end
