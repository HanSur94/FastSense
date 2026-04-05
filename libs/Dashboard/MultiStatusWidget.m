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

            % Compute aspect ratio correction for circles
            oldUnits = get(obj.hPanel, 'Units');
            set(obj.hPanel, 'Units', 'pixels');
            pxPos = get(obj.hPanel, 'Position');
            set(obj.hPanel, 'Units', oldUnits);
            pxW = pxPos(3);
            pxH = pxPos(4);

            for i = 1:n
                col = mod(i-1, cols);
                row = floor((i-1) / cols);

                cx = (col + 0.5) / cols;
                cy = 1 - (row + 0.5) / rows;

                item = obj.Sensors{i};

                % Draw indicator — aspect-ratio-corrected so circles stay round
                ry = 0.3 / max(cols, rows);
                if pxW > 0 && pxH > 0
                    rx = ry * (pxH / pxW);
                else
                    rx = ry;
                end

                if isstruct(item)
                    % Threshold-binding struct item
                    color = obj.deriveColorFromThreshold(item, okColor, theme);
                    if strcmp(obj.IconStyle, 'square')
                        rectangle(obj.hAxes, 'Position', [cx-rx cy-ry 2*rx 2*ry], ...
                            'FaceColor', color, 'EdgeColor', 'none');
                    else
                        theta = linspace(0, 2*pi, 30);
                        fill(obj.hAxes, cx + rx*cos(theta), cy + ry*sin(theta), ...
                            color, 'EdgeColor', 'none');
                    end
                    if obj.ShowLabels && isfield(item, 'label')
                        text(obj.hAxes, cx, cy - ry - 0.02, item.label, ...
                            'HorizontalAlignment', 'center', ...
                            'FontSize', 8, ...
                            'Color', theme.AxisColor);
                    end
                else
                    % Sensor object item
                    color = obj.deriveColor(item, okColor);
                    if strcmp(obj.IconStyle, 'square')
                        rectangle(obj.hAxes, 'Position', [cx-rx cy-ry 2*rx 2*ry], ...
                            'FaceColor', color, 'EdgeColor', 'none');
                    else
                        theta = linspace(0, 2*pi, 30);
                        fill(obj.hAxes, cx + rx*cos(theta), cy + ry*sin(theta), ...
                            color, 'EdgeColor', 'none');
                    end
                    if obj.ShowLabels && ~isempty(item)
                        name = item.Name;
                        if isempty(name), name = item.Key; end
                        text(obj.hAxes, cx, cy - ry - 0.02, name, ...
                            'HorizontalAlignment', 'center', ...
                            'FontSize', 8, ...
                            'Color', theme.AxisColor);
                    end
                end
            end
            hold(obj.hAxes, 'off');
        end

        function t = getType(~)
            t = 'multistatus';
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
                n = numel(obj.Sensors);
                if n > 0
                    nOk = 0;
                    for k = 1:n
                        s = obj.Sensors{k};
                        % Threshold-binding struct items count as ok (no live data yet)
                        if isstruct(s)
                            nOk = nOk + 1;
                            continue;
                        end
                        if isempty(s) || isempty(s.Y) || isempty(s.ThresholdRules)
                            nOk = nOk + 1;
                            continue;
                        end
                        val = s.Y(end);
                        violated = false;
                        for r = 1:numel(s.ThresholdRules)
                            rule = s.ThresholdRules{r};
                            if (rule.IsUpper && val > rule.Value) || ...
                                    (~rule.IsUpper && val < rule.Value)
                                violated = true;
                                break;
                            end
                        end
                        if ~violated
                            nOk = nOk + 1;
                        end
                    end
                    info = sprintf('%d sensors: %d OK, %d alert', n, nOk, n - nOk);
                else
                    info = '[-- multistatus --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
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
            % Serialize items (mixed Sensor + threshold-binding structs)
            items = cell(1, numel(obj.Sensors));
            for i = 1:numel(obj.Sensors)
                item = obj.Sensors{i};
                if isstruct(item)
                    entry = struct('type', 'threshold');
                    if isfield(item, 'label'), entry.label = item.label; end
                    if isfield(item, 'threshold') && ~isempty(item.threshold)
                        t = item.threshold;
                        if ischar(t) || isstring(t)
                            entry.key = t;
                        elseif isprop(t, 'Key')
                            entry.key = t.Key;
                        end
                    end
                    if isfield(item, 'value'), entry.value = item.value; end
                    items{i} = entry;
                else
                    items{i} = struct('type', 'sensor', 'key', item.Key);
                end
            end
            s.items = items;
        end
    end

    methods (Access = private)
        function color = deriveColorFromThreshold(~, item, defaultColor, theme)
        %DERIVECOLORFROMTHRESHOLD Derive color from a threshold-binding struct item.
            color = defaultColor;
            if ~isfield(item, 'threshold') || isempty(item.threshold), return; end
            t = item.threshold;
            % Resolve string key if needed
            if ischar(t) || isstring(t)
                try
                    t = ThresholdRegistry.get(t);
                catch
                    return;
                end
            end
            % Get value
            val = [];
            if isfield(item, 'valueFcn') && ~isempty(item.valueFcn)
                try val = item.valueFcn(); catch, return; end
            elseif isfield(item, 'value')
                val = item.value;
            end
            if isempty(val), return; end
            % Check violation
            tVals = t.allValues();
            for v = 1:numel(tVals)
                if (t.IsUpper && val >= tVals(v)) || (~t.IsUpper && val <= tVals(v))
                    if ~isempty(t.Color)
                        color = t.Color;
                    else
                        color = theme.StatusAlarmColor;
                    end
                    return;
                end
            end
        end

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
            % Restore items (mixed sensor + threshold-binding structs)
            if isfield(s, 'items')
                rawItems = s.items;
                if isstruct(rawItems)
                    nC = numel(rawItems);
                    tmp = cell(1, nC);
                    for i = 1:nC
                        tmp{i} = rawItems(i);
                    end
                    rawItems = tmp;
                end
                nIt = numel(rawItems);
                entries = cell(1, nIt);
                for i = 1:nIt
                    it = rawItems{i};
                    if isstruct(it) && isfield(it, 'type')
                        switch it.type
                            case 'threshold'
                                entry = struct('label', '');
                                if isfield(it, 'label'), entry.label = it.label; end
                                if isfield(it, 'key') && exist('ThresholdRegistry', 'class')
                                    try
                                        entry.threshold = ThresholdRegistry.get(it.key);
                                    catch
                                    end
                                end
                                if isfield(it, 'value'), entry.value = it.value; end
                                entries{i} = entry;
                            case 'sensor'
                                if isfield(it, 'key') && exist('SensorRegistry', 'class')
                                    try
                                        entries{i} = SensorRegistry.get(it.key);
                                    catch
                                    end
                                end
                        end
                    end
                end
                obj.Sensors = entries;
            end
            % Sensor resolution via resolver in configToWidgets (legacy s.sensors field)
        end
    end
end
