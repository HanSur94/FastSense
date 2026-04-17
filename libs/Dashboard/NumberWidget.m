classdef NumberWidget < DashboardWidget
%NUMBERWIDGET Dashboard widget showing a big number with label and trend.
%
%   w = NumberWidget('Title', 'Temp', 'ValueFcn', @() readTemp(), 'Units', 'degC');
%
%   ValueFcn returns either:
%     - A scalar (displayed as-is)
%     - A struct with fields: value, unit, trend ('up'/'down'/'flat')

    properties (Access = public)
        ValueFcn     = []       % function_handle returning scalar or struct
        Units        = ''       % unit label string
        Format       = '%.1f'   % sprintf format for value
        StaticValue  = []       % fixed value (no callback needed)
    end

    properties (SetAccess = private)
        CurrentValue = []
        CurrentTrend = ''
        hValueText   = []
        hUnitText    = []
        hTrendText   = []
        hTitleText   = []
    end

    methods
        function obj = NumberWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            % Set default position for NumberWidget if base default wasn't overridden
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 6 1];
            end
            % Derive Units from Sensor if not explicitly set
            if isempty(obj.Units) && ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Units)
                obj.Units = obj.Sensor.Units;
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            bgColor = theme.WidgetBackground;
            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;

            % Adaptive font sizes based on panel pixel height
            oldUnits = get(parentPanel, 'Units');
            set(parentPanel, 'Units', 'pixels');
            pxPos = get(parentPanel, 'Position');
            set(parentPanel, 'Units', oldUnits);
            pH = pxPos(4);  % panel height in pixels

            valueFontSz = max(8, min(28, round(pH * 0.45)));
            titleFontSz = max(7, min(14, round(pH * 0.22)));
            trendFontSz = max(6, min(16, round(pH * 0.25)));

            % Horizontal layout: [Title | Value+Trend | Units]
            obj.hTitleText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', obj.Title, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.02 0.28 0.96], ...
                'FontName', fontName, ...
                'FontSize', titleFontSz, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', fgColor * 0.7 + bgColor * 0.3, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'right');

            obj.hValueText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '--', ...
                'Units', 'normalized', ...
                'Position', [0.31 0.02 0.40 0.96], ...
                'FontName', fontName, ...
                'FontSize', valueFontSz, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'center');

            obj.hTrendText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '', ...
                'Units', 'normalized', ...
                'Position', [0.72 0.02 0.08 0.96], ...
                'FontName', fontName, ...
                'FontSize', trendFontSz, ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'center');

            obj.hUnitText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', obj.Units, ...
                'Units', 'normalized', ...
                'Position', [0.80 0.02 0.18 0.96], ...
                'FontName', fontName, ...
                'FontSize', titleFontSz, ...
                'ForegroundColor', fgColor * 0.5 + bgColor * 0.5, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'left');

            obj.refresh();
        end

        function refresh(obj)
            if ~isempty(obj.Sensor)
                if isempty(obj.Sensor.Y), return; end
                obj.CurrentValue = obj.Sensor.Y(end);
                if isempty(obj.Units) && ~isempty(obj.Sensor.Units)
                    obj.Units = obj.Sensor.Units;
                end
                obj.CurrentTrend = obj.computeTrend();
            elseif ~isempty(obj.ValueFcn)
                result = obj.ValueFcn();
                if isstruct(result)
                    obj.CurrentValue = result.value;
                    if isfield(result, 'unit'), obj.Units = result.unit; end
                    if isfield(result, 'trend'), obj.CurrentTrend = result.trend; end
                else
                    obj.CurrentValue = result;
                end
            elseif ~isempty(obj.StaticValue)
                obj.CurrentValue = obj.StaticValue;
            else
                return;
            end

            % Update display
            if ~isempty(obj.hValueText) && ishandle(obj.hValueText)
                set(obj.hValueText, 'String', sprintf(obj.Format, obj.CurrentValue));
            end
            if ~isempty(obj.hUnitText) && ishandle(obj.hUnitText)
                set(obj.hUnitText, 'String', obj.Units);
            end
            if ~isempty(obj.hTrendText) && ishandle(obj.hTrendText)
                switch obj.CurrentTrend
                    case 'up',    set(obj.hTrendText, 'String', char(9650));
                    case 'down',  set(obj.hTrendText, 'String', char(9660));
                    case 'flat',  set(obj.hTrendText, 'String', char(9654));
                    otherwise,    set(obj.hTrendText, 'String', '');
                end
            end
        end

        function t = getType(~)
            t = 'number';
        end

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            val = obj.StaticValue;
            units = obj.Units;
            if isempty(val) && ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Y)
                val = obj.Sensor.Y(end);
                if isempty(units) && ~isempty(obj.Sensor.Units)
                    units = obj.Sensor.Units;
                end
            end

            if ~isempty(val)
                valStr = sprintf(obj.Format, val);
                if ~isempty(units)
                    valStr = sprintf('%s %s', valStr, units);
                end
                label = sprintf('%s  %s', obj.Title, valStr);
            else
                label = obj.Title;
            end
            if numel(label) > width, label = label(1:width); end
            lines{1} = [label, repmat(' ', 1, width - numel(label))];

            if isempty(val) && height >= 2
                ph = '[-- number --]';
                if numel(ph) > width, ph = ph(1:width); end
                lines{2} = [ph, repmat(' ', 1, width - numel(ph))];
            end
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.units = obj.Units;
            s.format = obj.Format;
            if isempty(obj.Sensor)
                if ~isempty(obj.ValueFcn)
                    s.source = struct('type', 'callback', 'function', func2str(obj.ValueFcn));
                elseif ~isempty(obj.StaticValue)
                    s.source = struct('type', 'static', 'value', obj.StaticValue);
                end
            end
        end
    end

    methods (Access = private)
        function trend = computeTrend(obj)
            trend = '';
            if isempty(obj.Sensor) || numel(obj.Sensor.Y) < 3
                return;
            end
            n = numel(obj.Sensor.Y);
            nTrend = max(3, round(n * 0.1));
            yRecent = obj.Sensor.Y(end-nTrend+1:end);
            slope = (yRecent(end) - yRecent(1)) / nTrend;
            yRange = max(obj.Sensor.Y) - min(obj.Sensor.Y);
            if yRange == 0, return; end
            threshold = yRange * 0.01;
            if slope > threshold
                trend = 'up';
            elseif slope < -threshold
                trend = 'down';
            else
                trend = 'flat';
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = NumberWidget();
            obj.Title = s.title;
            if isfield(s, 'description'), obj.Description = s.description; end
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'units'), obj.Units = s.units; end
            if isfield(s, 'format'), obj.Format = s.format; end
            if isfield(s, 'source')
                switch s.source.type
                    case 'sensor'
                        if exist('TagRegistry', 'class')
                            try
                                obj.Tag = TagRegistry.get(s.source.name);
                            catch, end
                        end
                    case 'callback'
                        obj.ValueFcn = str2func(s.source.function);
                    case 'static'
                        obj.StaticValue = s.source.value;
                end
            end
        end
    end

end
