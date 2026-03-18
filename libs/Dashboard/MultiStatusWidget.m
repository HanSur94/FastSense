classdef MultiStatusWidget < DashboardWidget
    properties (Access = public)
        Sensors    = {}         % Cell array of Sensor objects
        Columns    = []         % Grid columns (empty = auto)
        ShowLabels = true
        IconStyle  = 'dot'      % 'dot', 'square', 'icon'
    end

    properties (SetAccess = private)
        hAxes = []
    end

    methods
        function obj = MultiStatusWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 8 3];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.02 0.96 0.96], ...
                'Visible', 'off', ...
                'XLim', [0 1], 'YLim', [0 1]);
            obj.refresh();
        end

        function refresh(obj)
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            n = numel(obj.Sensors);
            if n == 0, return; end

            cols = obj.Columns;
            if isempty(cols)
                cols = ceil(sqrt(n));
            end
            rows = ceil(n / cols);

            cla(obj.hAxes);
            hold(obj.hAxes, 'on');

            theme = obj.getTheme();
            okColor = theme.StatusOkColor;
            warnColor = theme.StatusWarnColor;
            alarmColor = theme.StatusAlarmColor;

            for i = 1:n
                col = mod(i-1, cols);
                row = floor((i-1) / cols);

                cx = (col + 0.5) / cols;
                cy = 1 - (row + 0.5) / rows;

                sensor = obj.Sensors{i};
                color = obj.deriveColor(sensor, okColor);

                % Draw indicator
                r = 0.3 / max(cols, rows);
                if strcmp(obj.IconStyle, 'square')
                    rectangle(obj.hAxes, 'Position', [cx-r cy-r 2*r 2*r], ...
                        'FaceColor', color, 'EdgeColor', 'none');
                else
                    theta = linspace(0, 2*pi, 30);
                    fill(obj.hAxes, cx + r*cos(theta), cy + r*sin(theta), ...
                        color, 'EdgeColor', 'none');
                end

                % Label
                if obj.ShowLabels && ~isempty(sensor)
                    name = sensor.Name;
                    if isempty(name), name = sensor.Key; end
                    text(obj.hAxes, cx, cy - r - 0.02, name, ...
                        'HorizontalAlignment', 'center', ...
                        'FontSize', 8, ...
                        'Color', theme.AxisColor);
                end
            end
            hold(obj.hAxes, 'off');
        end

        function t = getType(~)
            t = 'multistatus';
        end

        function s = toStruct(obj)
            % Fully override — does not use base Sensor property
            s = struct();
            s.type = 'multistatus';
            s.title = obj.Title;
            s.description = obj.Description;
            s.position = struct('col', obj.Position(1), 'row', obj.Position(2), ...
                'width', obj.Position(3), 'height', obj.Position(4));
            if ~isempty(fieldnames(obj.ThemeOverride))
                s.themeOverride = obj.ThemeOverride;
            end
            s.columns = obj.Columns;
            s.showLabels = obj.ShowLabels;
            s.iconStyle = obj.IconStyle;
            % Serialize sensor keys
            keys = cell(1, numel(obj.Sensors));
            for i = 1:numel(obj.Sensors)
                keys{i} = obj.Sensors{i}.Key;
            end
            s.sensors = keys;
        end
    end

    methods (Access = private)
        function color = deriveColor(~, sensor, defaultColor)
            color = defaultColor;
            if isempty(sensor) || isempty(sensor.Y)
                return;
            end
            val = sensor.Y(end);
            if isempty(sensor.ThresholdRules)
                return;
            end
            for k = 1:numel(sensor.ThresholdRules)
                rule = sensor.ThresholdRules{k};
                if isempty(rule.Color), continue; end
                if rule.IsUpper && val >= rule.Value
                    color = rule.Color;
                elseif ~rule.IsUpper && val <= rule.Value
                    color = rule.Color;
                end
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = MultiStatusWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'columns'), obj.Columns = s.columns; end
            if isfield(s, 'showLabels'), obj.ShowLabels = s.showLabels; end
            if isfield(s, 'iconStyle'), obj.IconStyle = s.iconStyle; end
            % Sensor resolution happens via resolver in configToWidgets
        end
    end
end
