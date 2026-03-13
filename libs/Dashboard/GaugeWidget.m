classdef GaugeWidget < DashboardWidget
%GAUGEWIDGET Circular arc gauge with range.
%
%   w = GaugeWidget('Title', 'Pressure', 'ValueFcn', @() getPressure(), ...
%                   'Range', [0 100], 'Units', 'bar');

    properties (Access = public)
        ValueFcn    = []
        Range       = [0 100]
        Units       = ''
        StaticValue = []
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
            obj = obj@DashboardWidget();
            obj.Position = [1 1 4 2]; % default gauge size
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            fgColor = theme.ForegroundColor;
            bgColor = theme.WidgetBackground;
            fontName = theme.FontName;
            arcWidth = theme.GaugeArcWidth;

            % Axes for gauge arc
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.1 0.15 0.8 0.7], ...
                'Visible', 'off', ...
                'XLim', [-1.4 1.4], 'YLim', [-0.5 1.5], ...
                'DataAspectRatio', [1 1 1]);
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

            obj.refresh();
        end

        function refresh(obj)
            if ~isempty(obj.ValueFcn)
                obj.CurrentValue = obj.ValueFcn();
            elseif ~isempty(obj.StaticValue)
                obj.CurrentValue = obj.StaticValue;
            else
                return;
            end

            theme = obj.getTheme();
            val = obj.CurrentValue;
            rng = obj.Range;
            frac = (val - rng(1)) / (rng(2) - rng(1));
            frac = max(0, min(1, frac));  % clamp 0-1

            % Update value text
            if ~isempty(obj.hValueText) && ishandle(obj.hValueText)
                if isempty(obj.Units)
                    set(obj.hValueText, 'String', sprintf('%.1f', val));
                else
                    set(obj.hValueText, 'String', ...
                        sprintf('%.1f %s', val, obj.Units));
                end
            end

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
                if frac < 0.6
                    arcColor = theme.StatusOkColor;
                elseif frac < 0.85
                    arcColor = theme.StatusWarnColor;
                else
                    arcColor = theme.StatusAlarmColor;
                end
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

        function configure(~)
        end

        function t = getType(~)
            t = 'gauge';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.range = obj.Range;
            s.units = obj.Units;
            if ~isempty(obj.ValueFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.ValueFcn));
            elseif ~isempty(obj.StaticValue)
                s.source = struct('type', 'static', 'value', obj.StaticValue);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = GaugeWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'range')
                obj.Range = s.range;
            end
            if isfield(s, 'units')
                obj.Units = s.units;
            end
            if isfield(s, 'source')
                switch s.source.type
                    case 'callback'
                        obj.ValueFcn = str2func(s.source.function);
                    case 'static'
                        obj.StaticValue = s.source.value;
                end
            end
        end
    end

    methods (Access = private)
        function theme = getTheme(obj)
            theme = DashboardTheme();
            if ~isempty(fieldnames(obj.ThemeOverride))
                fns = fieldnames(obj.ThemeOverride);
                for i = 1:numel(fns)
                    theme.(fns{i}) = obj.ThemeOverride.(fns{i});
                end
            end
        end
    end
end
