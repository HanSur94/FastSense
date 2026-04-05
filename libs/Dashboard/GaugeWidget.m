classdef GaugeWidget < DashboardWidget
%GAUGEWIDGET Gauge widget with arc, donut, bar, and thermometer styles.
%
%   w = GaugeWidget('Title', 'Pressure', 'ValueFcn', @() getPressure(), ...
%                   'Range', [0 100], 'Units', 'bar');
%   w = GaugeWidget('Sensor', mySensor, 'Style', 'donut');
%   w = GaugeWidget('Threshold', t, 'StaticValue', 50);

    properties (Access = public)
        ValueFcn    = []
        Range       = []         % Empty default for auto-derivation cascade
        Units       = ''
        StaticValue = []
        Style       = 'arc'      % 'arc', 'donut', 'bar', 'thermometer'
        Threshold   = []         % Threshold object or registry key string (per D-01)
    end

    properties (SetAccess = private)
        CurrentValue = []
        hAxes       = []
        hArcBg      = []
        hArcFg      = []
        hNeedle     = []
        hValueText  = []
        hTitleText  = []
        hMinText    = []
        hMaxText    = []
    end

    methods
        function obj = GaugeWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 6 4];
            end
            % Resolve Threshold key string to object (per D-07)
            if ischar(obj.Threshold) || isstring(obj.Threshold)
                try
                    obj.Threshold = ThresholdRegistry.get(obj.Threshold);
                catch
                    warning('GaugeWidget:thresholdNotFound', ...
                        'ThresholdRegistry key ''%s'' not found.', obj.Threshold);
                    obj.Threshold = [];
                end
            end
            % Mutual exclusivity: Threshold wins (per D-08)
            if ~isempty(obj.Threshold) && ~isempty(obj.Sensor)
                obj.Sensor = [];
            end
            % Derive from Sensor
            if ~isempty(obj.Sensor)
                if isempty(obj.Units) && ~isempty(obj.Sensor.Units)
                    obj.Units = obj.Sensor.Units;
                end
                if isempty(obj.Range)
                    obj.Range = obj.deriveRange();
                end
            end
            % Threshold-based range derivation (per Pattern 4 from RESEARCH)
            if isempty(obj.Range) && ~isempty(obj.Threshold)
                if isa(obj.Threshold, 'CompositeThreshold')
                    % Composites have no numeric range; skip range derivation
                else
                    tVals = obj.Threshold.allValues();
                    if ~isempty(tVals)
                        obj.Range = [min(tVals), max(tVals)];
                    end
                end
            end
            if isempty(obj.Range)
                obj.Range = [0 100]; % ultimate fallback
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            switch obj.Style
                case 'arc',          obj.renderArc(parentPanel);
                case 'donut',        obj.renderDonut(parentPanel);
                case 'bar',          obj.renderBar(parentPanel);
                case 'thermometer',  obj.renderThermometer(parentPanel);
                otherwise
                    error('GaugeWidget:unknownStyle', 'Unknown style: %s', obj.Style);
            end
            obj.refresh();
        end

        function refresh(obj)
            if ~isempty(obj.Threshold)
                if ~isempty(obj.ValueFcn)
                    obj.CurrentValue = obj.ValueFcn();
                elseif ~isempty(obj.StaticValue)
                    obj.CurrentValue = obj.StaticValue;
                else
                    return;
                end
            elseif ~isempty(obj.Sensor)
                if isempty(obj.Sensor.Y), return; end
                obj.CurrentValue = obj.Sensor.Y(end);
                if isempty(obj.Units) && ~isempty(obj.Sensor.Units)
                    obj.Units = obj.Sensor.Units;
                end
            elseif ~isempty(obj.ValueFcn)
                obj.CurrentValue = obj.ValueFcn();
            elseif ~isempty(obj.StaticValue)
                obj.CurrentValue = obj.StaticValue;
            else
                return;
            end
            obj.updateDisplay();
        end

        function t = getType(~)
            t = 'gauge';
        end

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            val = obj.StaticValue;
            if isempty(val) && ~isempty(obj.Threshold)
                if ~isempty(obj.ValueFcn)
                    try
                        val = obj.ValueFcn();
                    catch
                    end
                end
            end
            if isempty(val) && ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Y)
                val = obj.Sensor.Y(end);
            end

            if ~isempty(val) && height >= 2
                rng = obj.Range;
                frac = max(0, min(1, (val - rng(1)) / (rng(2) - rng(1))));
                barW = max(1, width - 10);
                filled = round(frac * barW);
                barStr = repmat(char(9608), 1, filled);
                emptyStr = repmat(char(9617), 1, barW - filled);
                valStr = sprintf(' %.0f%%', frac * 100);
                gauge = [barStr, emptyStr, valStr];
                if numel(gauge) > width, gauge = gauge(1:width); end
                if numel(gauge) < width
                    gauge = [gauge, repmat(' ', 1, width - numel(gauge))];
                end
                lines{2} = gauge;

                if height >= 3
                    if ~isempty(obj.Units)
                        info = sprintf('%.1f %s  [%.0f - %.0f]', val, obj.Units, rng(1), rng(2));
                    else
                        info = sprintf('%.1f  [%.0f - %.0f]', val, rng(1), rng(2));
                    end
                    if numel(info) > width, info = info(1:width); end
                    lines{3} = [info, repmat(' ', 1, width - numel(info))];
                end
            elseif height >= 2
                ph = '[-- gauge --]';
                if numel(ph) > width, ph = ph(1:width); end
                lines{2} = [ph, repmat(' ', 1, width - numel(ph))];
            end
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.range = obj.Range;
            s.units = obj.Units;
            s.style = obj.Style;
            if ~isempty(obj.Threshold) && ~isempty(obj.Threshold.Key)
                s.source = struct('type', 'threshold', 'key', obj.Threshold.Key);
            elseif isempty(obj.Sensor)
                if ~isempty(obj.ValueFcn)
                    s.source = struct('type', 'callback', ...
                        'function', func2str(obj.ValueFcn));
                elseif ~isempty(obj.StaticValue)
                    s.source = struct('type', 'static', 'value', obj.StaticValue);
                end
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = GaugeWidget();
            obj.Title = s.title;
            if isfield(s, 'description'), obj.Description = s.description; end
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'range'), obj.Range = s.range; end
            if isfield(s, 'units'), obj.Units = s.units; end
            if isfield(s, 'style'), obj.Style = s.style; end
            if isfield(s, 'source')
                switch s.source.type
                    case 'sensor'
                        if exist('SensorRegistry', 'class')
                            obj.Sensor = SensorRegistry.get(s.source.name);
                        end
                    case 'threshold'
                        if exist('ThresholdRegistry', 'class')
                            try
                                obj.Threshold = ThresholdRegistry.get(s.source.key);
                            catch
                                warning('GaugeWidget:thresholdNotFound', ...
                                    'Could not resolve threshold key ''%s'' on load.', s.source.key);
                            end
                        end
                    case 'callback'
                        obj.ValueFcn = str2func(s.source.function);
                    case 'static'
                        obj.StaticValue = s.source.value;
                end
            end
        end
    end

    methods (Access = private)
        function rng = deriveRange(obj)
            if ~isempty(obj.Sensor.Thresholds)
                allVals = [];
                for i = 1:numel(obj.Sensor.Thresholds)
                    allVals = [allVals, obj.Sensor.Thresholds{i}.allValues()]; %#ok<AGROW>
                end
                if ~isempty(allVals)
                    rng = [min(allVals), max(allVals)];
                    return;
                end
            end
            if ~isempty(obj.Sensor.Y)
                rng = [min(obj.Sensor.Y), max(obj.Sensor.Y)];
            else
                rng = [0 100];
            end
        end

        function color = getValueColor(obj, frac, theme)
            if ~isempty(obj.Threshold)
                t = obj.Threshold;
                if isa(t, 'CompositeThreshold')
                    % CompositeThreshold: derive color from computeStatus (per D-04)
                    cStatus = t.computeStatus();
                    switch cStatus
                        case 'ok',    color = theme.StatusOkColor;
                        case 'alarm', color = theme.StatusAlarmColor;
                        otherwise,    color = theme.StatusWarnColor;
                    end
                else
                    val = obj.CurrentValue;
                    color = theme.StatusOkColor;
                    tVals = t.allValues();
                    worstDist = -inf;
                    for v = 1:numel(tVals)
                        violated = (t.IsUpper && val > tVals(v)) || ...
                                   (~t.IsUpper && val < tVals(v));
                        if violated
                            dist = abs(val - tVals(v));
                            if dist > worstDist
                                worstDist = dist;
                                if ~isempty(t.Color)
                                    color = t.Color;
                                elseif t.IsUpper
                                    color = theme.StatusAlarmColor;
                                else
                                    color = theme.StatusWarnColor;
                                end
                            end
                        end
                    end
                end
            elseif ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Thresholds)
                val = obj.CurrentValue;
                color = theme.StatusOkColor;
                worstDist = -inf;
                for i = 1:numel(obj.Sensor.Thresholds)
                    t = obj.Sensor.Thresholds{i};
                    tVals = t.allValues();
                    for v = 1:numel(tVals)
                        violated = (t.IsUpper && val > tVals(v)) || ...
                                   (~t.IsUpper && val < tVals(v));
                        if violated
                            dist = abs(val - tVals(v));
                            if dist > worstDist
                                worstDist = dist;
                                if ~isempty(t.Color)
                                    color = t.Color;
                                elseif t.IsUpper
                                    color = theme.StatusAlarmColor;
                                else
                                    color = theme.StatusWarnColor;
                                end
                            end
                        end
                    end
                end
            else
                if frac < 0.6
                    color = theme.StatusOkColor;
                elseif frac < 0.85
                    color = theme.StatusWarnColor;
                else
                    color = theme.StatusAlarmColor;
                end
            end
        end

        function renderArc(obj, parentPanel)
            theme = obj.getTheme();
            fgColor = theme.ForegroundColor;
            bgColor = theme.WidgetBackground;
            fontName = theme.FontName;
            arcWidth = theme.GaugeArcWidth;

            % Axes for gauge arc (non-interactive)
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.1 0.15 0.8 0.7], ...
                'Visible', 'off', ...
                'XLim', [-1.4 1.4], 'YLim', [-0.5 1.5], ...
                'DataAspectRatio', [1 1 1], ...
                'HitTest', 'off');
            try set(obj.hAxes, 'PickableParts', 'none'); catch , end
            try disableDefaultInteractivity(obj.hAxes); catch , end
            hold(obj.hAxes, 'on');

            % Draw background arc (240 degrees from 210 to -30)
            startAngle = deg2rad(210);
            endAngle = deg2rad(-30);
            nPts = 80;
            angles = linspace(startAngle, endAngle, nPts);
            rOuter = 1.0;
            rInner = 1.0 - arcWidth * 0.02;

            xOuter = rOuter * cos(angles);
            yOuter = rOuter * sin(angles);
            xInner = rInner * cos(fliplr(angles));
            yInner = rInner * sin(fliplr(angles));

            obj.hArcBg = fill(obj.hAxes, ...
                [xOuter, xInner], [yOuter, yInner], ...
                fgColor * 0.15 + bgColor * 0.85, 'EdgeColor', 'none');

            % Foreground arc (colored, updated by refresh)
            obj.hArcFg = fill(obj.hAxes, [0 0], [0 0], ...
                theme.StatusOkColor, 'EdgeColor', 'none');

            % Needle line
            obj.hNeedle = line(obj.hAxes, [0 0], [0 0.9], ...
                'Color', fgColor, 'LineWidth', 2);

            % Value text
            obj.hValueText = text(obj.hAxes, 0, -0.15, '--', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', theme.KpiFontSize * 0.7, ...
                'FontWeight', 'bold', ...
                'FontName', fontName, ...
                'Color', fgColor);

            % Title
            obj.hTitleText = text(obj.hAxes, 0, 1.35, obj.Title, ...
                'HorizontalAlignment', 'center', ...
                'FontSize', theme.WidgetTitleFontSize, ...
                'FontWeight', 'bold', ...
                'FontName', fontName, ...
                'Color', fgColor);

            % Min/max labels
            xMin = rOuter * cos(startAngle);
            yMin = rOuter * sin(startAngle);
            obj.hMinText = text(obj.hAxes, xMin - 0.15, yMin - 0.1, ...
                sprintf('%.0f', obj.Range(1)), ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 8, 'FontName', fontName, ...
                'Color', fgColor * 0.6 + bgColor * 0.4);

            xMax = rOuter * cos(endAngle);
            yMax = rOuter * sin(endAngle);
            obj.hMaxText = text(obj.hAxes, xMax + 0.15, yMax - 0.1, ...
                sprintf('%.0f', obj.Range(2)), ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 8, 'FontName', fontName, ...
                'Color', fgColor * 0.6 + bgColor * 0.4);
        end

        function renderDonut(obj, parentPanel)
            theme = obj.getTheme();
            fgColor = theme.ForegroundColor;
            bgColor = theme.WidgetBackground;
            fontName = theme.FontName;

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.1 0.1 0.8 0.75], ...
                'Visible', 'off', ...
                'XLim', [-1.5 1.5], 'YLim', [-1.5 1.5], ...
                'DataAspectRatio', [1 1 1], ...
                'HitTest', 'off');
            try set(obj.hAxes, 'PickableParts', 'none'); catch , end
            try disableDefaultInteractivity(obj.hAxes); catch , end
            hold(obj.hAxes, 'on');

            % Full circle background ring
            nPts = 120;
            angles = linspace(0, 2*pi, nPts);
            rOuter = 1.0;
            rInner = 0.70;
            xO = rOuter * cos(angles);
            yO = rOuter * sin(angles);
            xI = rInner * cos(fliplr(angles));
            yI = rInner * sin(fliplr(angles));
            obj.hArcBg = fill(obj.hAxes, [xO, xI], [yO, yI], ...
                fgColor * 0.15 + bgColor * 0.85, 'EdgeColor', 'none');

            % Foreground arc (starts empty, updated by updateDonut)
            obj.hArcFg = fill(obj.hAxes, [0 0], [0 0], ...
                theme.StatusOkColor, 'EdgeColor', 'none');

            % Value text centered in ring
            obj.hValueText = text(obj.hAxes, 0, 0, '--', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', theme.KpiFontSize * 0.7, ...
                'FontWeight', 'bold', ...
                'FontName', fontName, ...
                'Color', fgColor);

            % Title above
            obj.hTitleText = text(obj.hAxes, 0, 1.35, obj.Title, ...
                'HorizontalAlignment', 'center', ...
                'FontSize', theme.WidgetTitleFontSize, ...
                'FontWeight', 'bold', ...
                'FontName', fontName, ...
                'Color', fgColor);
        end

        function renderBar(obj, parentPanel)
            theme = obj.getTheme();
            fgColor = theme.ForegroundColor;
            bgColor = theme.WidgetBackground;
            fontName = theme.FontName;

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.1 0.25 0.8 0.35], ...
                'Visible', 'off', ...
                'XLim', [0 1], 'YLim', [0 1], ...
                'HitTest', 'off');
            try set(obj.hAxes, 'PickableParts', 'none'); catch , end
            try disableDefaultInteractivity(obj.hAxes); catch , end
            hold(obj.hAxes, 'on');

            % Background rectangle
            obj.hArcBg = fill(obj.hAxes, [0 1 1 0], [0 0 1 1], ...
                fgColor * 0.15 + bgColor * 0.85, 'EdgeColor', 'none');

            % Foreground fill (starts empty)
            obj.hArcFg = fill(obj.hAxes, [0 0 0 0], [0 0 1 1], ...
                theme.StatusOkColor, 'EdgeColor', 'none');

            % Value text above bar
            obj.hValueText = text(obj.hAxes, 0.5, 1.3, '--', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', theme.KpiFontSize * 0.7, ...
                'FontWeight', 'bold', ...
                'FontName', fontName, ...
                'Color', fgColor);

            % Min/max labels at ends
            obj.hMinText = text(obj.hAxes, 0, -0.3, ...
                sprintf('%.0f', obj.Range(1)), ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 8, 'FontName', fontName, ...
                'Color', fgColor * 0.6 + bgColor * 0.4);
            obj.hMaxText = text(obj.hAxes, 1, -0.3, ...
                sprintf('%.0f', obj.Range(2)), ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 8, 'FontName', fontName, ...
                'Color', fgColor * 0.6 + bgColor * 0.4);

            % Title at top
            obj.hTitleText = text(obj.hAxes, 0.5, 2.0, obj.Title, ...
                'HorizontalAlignment', 'center', ...
                'FontSize', theme.WidgetTitleFontSize, ...
                'FontWeight', 'bold', ...
                'FontName', fontName, ...
                'Color', fgColor);
        end

        function renderThermometer(obj, parentPanel)
            theme = obj.getTheme();
            fgColor = theme.ForegroundColor;
            bgColor = theme.WidgetBackground;
            fontName = theme.FontName;

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.3 0.15 0.4 0.7], ...
                'Visible', 'off', ...
                'XLim', [-0.5 1.5], 'YLim', [-0.3 1.3], ...
                'DataAspectRatio', [1 2 1], ...
                'HitTest', 'off');
            try set(obj.hAxes, 'PickableParts', 'none'); catch , end
            try disableDefaultInteractivity(obj.hAxes); catch , end
            hold(obj.hAxes, 'on');

            % Vertical background rectangle
            obj.hArcBg = fill(obj.hAxes, [0 0.4 0.4 0], [0 0 1 1], ...
                fgColor * 0.15 + bgColor * 0.85, 'EdgeColor', 'none');

            % Foreground fill from bottom (starts empty)
            obj.hArcFg = fill(obj.hAxes, [0 0.4 0.4 0], [0 0 0 0], ...
                theme.StatusOkColor, 'EdgeColor', 'none');

            % Bulb circle at bottom
            nPts = 40;
            th = linspace(0, 2*pi, nPts);
            bulbR = 0.15;
            bulbX = 0.2 + bulbR * cos(th);
            bulbY = -0.15 + bulbR * sin(th);
            fill(obj.hAxes, bulbX, bulbY, ...
                fgColor * 0.15 + bgColor * 0.85, 'EdgeColor', 'none');

            % Value text above
            obj.hValueText = text(obj.hAxes, 0.2, 1.15, '--', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', theme.KpiFontSize * 0.7, ...
                'FontWeight', 'bold', ...
                'FontName', fontName, ...
                'Color', fgColor);

            % Title above
            obj.hTitleText = text(obj.hAxes, 0.5, 1.25, obj.Title, ...
                'HorizontalAlignment', 'center', ...
                'FontSize', theme.WidgetTitleFontSize, ...
                'FontWeight', 'bold', ...
                'FontName', fontName, ...
                'Color', fgColor);

            % Min/max labels on right side
            obj.hMinText = text(obj.hAxes, 0.55, 0, ...
                sprintf('%.0f', obj.Range(1)), ...
                'HorizontalAlignment', 'left', ...
                'FontSize', 8, 'FontName', fontName, ...
                'Color', fgColor * 0.6 + bgColor * 0.4);
            obj.hMaxText = text(obj.hAxes, 0.55, 1, ...
                sprintf('%.0f', obj.Range(2)), ...
                'HorizontalAlignment', 'left', ...
                'FontSize', 8, 'FontName', fontName, ...
                'Color', fgColor * 0.6 + bgColor * 0.4);
        end

        function updateDisplay(obj)
            theme = obj.getTheme();
            val = obj.CurrentValue;
            rng = obj.Range;
            if rng(2) == rng(1)
                frac = 0.5;
            else
                frac = max(0, min(1, (val - rng(1)) / (rng(2) - rng(1))));
            end
            arcColor = obj.getValueColor(frac, theme);

            % Update value text
            if ~isempty(obj.hValueText) && ishandle(obj.hValueText)
                if isempty(obj.Units)
                    valStr = sprintf('%.1f', val);
                else
                    valStr = sprintf('%.1f %s', val, obj.Units);
                end
                set(obj.hValueText, 'String', valStr);
            end

            switch obj.Style
                case 'arc',          obj.updateArc(frac, arcColor, theme);
                case 'donut',        obj.updateDonut(frac, arcColor);
                case 'bar',          obj.updateBar(frac, arcColor);
                case 'thermometer',  obj.updateThermometer(frac, arcColor);
            end
        end

        function updateArc(obj, frac, arcColor, theme)
            % Update foreground arc
            startAngle = deg2rad(210);
            endAngle = deg2rad(-30);
            totalSweep = endAngle - startAngle;
            currentEnd = startAngle + frac * totalSweep;

            nPts = max(3, round(80 * frac));
            angles = linspace(startAngle, currentEnd, nPts);
            arcWidth = theme.GaugeArcWidth;
            rOuter = 1.0;
            rInner = 1.0 - arcWidth * 0.02;

            xOuter = rOuter * cos(angles);
            yOuter = rOuter * sin(angles);
            xInner = rInner * cos(fliplr(angles));
            yInner = rInner * sin(fliplr(angles));

            if ~isempty(obj.hArcFg) && ishandle(obj.hArcFg)
                set(obj.hArcFg, ...
                    'XData', [xOuter, xInner], ...
                    'YData', [yOuter, yInner], ...
                    'FaceColor', arcColor);
            end

            % Update needle
            needleAngle = startAngle + frac * totalSweep;
            if ~isempty(obj.hNeedle) && ishandle(obj.hNeedle)
                set(obj.hNeedle, ...
                    'XData', [0, 0.85 * cos(needleAngle)], ...
                    'YData', [0, 0.85 * sin(needleAngle)]);
            end
        end

        function updateDonut(obj, frac, arcColor)
            % Sweep from 90 deg (top) clockwise proportional to frac
            if ~isempty(obj.hArcFg) && ishandle(obj.hArcFg)
                nPts = max(3, round(120 * frac));
                % Start at top (90 deg), go clockwise (decreasing angle)
                startA = pi/2;
                endA = pi/2 - frac * 2 * pi;
                angles = linspace(startA, endA, nPts);
                rOuter = 1.0;
                rInner = 0.70;
                xO = rOuter * cos(angles);
                yO = rOuter * sin(angles);
                xI = rInner * cos(fliplr(angles));
                yI = rInner * sin(fliplr(angles));
                set(obj.hArcFg, ...
                    'XData', [xO, xI], ...
                    'YData', [yO, yI], ...
                    'FaceColor', arcColor);
            end
        end

        function updateBar(obj, frac, arcColor)
            if ~isempty(obj.hArcFg) && ishandle(obj.hArcFg)
                set(obj.hArcFg, ...
                    'XData', [0 frac frac 0], ...
                    'YData', [0 0 1 1], ...
                    'FaceColor', arcColor);
            end
        end

        function updateThermometer(obj, frac, arcColor)
            if ~isempty(obj.hArcFg) && ishandle(obj.hArcFg)
                set(obj.hArcFg, ...
                    'XData', [0 0.4 0.4 0], ...
                    'YData', [0 0 frac frac], ...
                    'FaceColor', arcColor);
            end
        end
    end

end
