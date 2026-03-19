classdef StatusWidget < DashboardWidget
%STATUSWIDGET Colored dot indicator with sensor value.
%
%   Sensor-first:
%     w = StatusWidget('Sensor', sensorObj);
%
%   Legacy (still supported):
%     w = StatusWidget('Title', 'Pump 1', 'StatusFcn', @() 'ok');

    properties (Access = public)
        StatusFcn    = []       % function_handle returning 'ok'/'warning'/'alarm' (legacy)
        StaticStatus = ''       % fixed status string (legacy)
    end

    properties (SetAccess = private)
        CurrentStatus = ''
        CurrentColor  = [0.5 0.5 0.5]
        hAxes        = []
        hCircle      = []
        hLabelText   = []
    end

    methods
        function obj = StatusWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 4 1]; % default compact size
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            bgColor = theme.WidgetBackground;
            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;

            % Adaptive font size
            oldUnits = get(parentPanel, 'Units');
            set(parentPanel, 'Units', 'pixels');
            pxPos = get(parentPanel, 'Position');
            set(parentPanel, 'Units', oldUnits);
            pH = pxPos(4);
            fontSz = max(7, min(14, round(pH * 0.28)));

            % Layout: [dot] [Name: value Units]
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.1 0.12 0.8], ...
                'Visible', 'off', ...
                'XLim', [-1.3 1.3], 'YLim', [-1.3 1.3], ...
                'DataAspectRatio', [1 1 1], ...
                'HitTest', 'off');
            try set(obj.hAxes, 'PickableParts', 'none'); catch , end
            try disableDefaultInteractivity(obj.hAxes); catch , end
            hold(obj.hAxes, 'on');

            theta = linspace(0, 2*pi, 60);
            obj.hCircle = fill(obj.hAxes, cos(theta), sin(theta), ...
                [0.5 0.5 0.5], 'EdgeColor', 'none', 'HitTest', 'off');

            obj.hLabelText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '', ...
                'Units', 'normalized', ...
                'Position', [0.16 0.02 0.82 0.96], ...
                'FontName', fontName, ...
                'FontSize', fontSz, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'left');

            obj.refresh();
        end

        function refresh(obj)
            theme = obj.getTheme();

            if ~isempty(obj.Sensor)
                if isempty(obj.Sensor.Y), return; end
                [obj.CurrentStatus, obj.CurrentColor] = obj.deriveStatusFromSensor(theme);
            elseif ~isempty(obj.StatusFcn)
                obj.CurrentStatus = obj.StatusFcn();
                obj.CurrentColor = obj.statusToColor(obj.CurrentStatus, theme);
            elseif ~isempty(obj.StaticStatus)
                obj.CurrentStatus = obj.StaticStatus;
                obj.CurrentColor = obj.statusToColor(obj.CurrentStatus, theme);
            else
                return;
            end

            % Update dot color
            if ~isempty(obj.hCircle) && ishandle(obj.hCircle)
                set(obj.hCircle, 'FaceColor', obj.CurrentColor);
            end

            % Update label
            if ~isempty(obj.hLabelText) && ishandle(obj.hLabelText)
                if ~isempty(obj.Sensor)
                    val = obj.Sensor.Y(end);
                    units = '';
                    if ~isempty(obj.Sensor.Units)
                        units = [' ' obj.Sensor.Units];
                    end
                    lbl = sprintf('%s: %.1f%s', obj.Title, val, units);
                else
                    lbl = sprintf('%s: %s', obj.Title, upper(obj.CurrentStatus));
                end
                set(obj.hLabelText, 'String', lbl);
            end
        end

        function t = getType(~)
            t = 'status';
        end

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            dot = char(9679);
            status = obj.StaticStatus;
            if isempty(status) && ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Y)
                status = 'ok';
                if ~isempty(obj.Sensor.ThresholdRules)
                    val = obj.Sensor.Y(end);
                    for k = 1:numel(obj.Sensor.ThresholdRules)
                        rule = obj.Sensor.ThresholdRules{k};
                        if (rule.IsUpper && val > rule.Value) || ...
                                (~rule.IsUpper && val < rule.Value)
                            status = 'violation';
                            break;
                        end
                    end
                end
            end

            if ~isempty(status)
                displayStatus = upper(status);
                if strcmp(status, 'violation'), displayStatus = 'ALARM'; end
                label = sprintf('%s %s: %s', dot, obj.Title, displayStatus);
            else
                label = sprintf('%s %s', dot, obj.Title);
            end
            if numel(label) > width, label = label(1:width); end
            lines{1} = [label, repmat(' ', 1, width - numel(label))];

            if isempty(status) && height >= 2
                ph = '[-- status --]';
                if numel(ph) > width, ph = ph(1:width); end
                lines{2} = [ph, repmat(' ', 1, width - numel(ph))];
            end
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if isempty(obj.Sensor)
                if ~isempty(obj.StatusFcn)
                    s.source = struct('type', 'callback', ...
                        'function', func2str(obj.StatusFcn));
                elseif ~isempty(obj.StaticStatus)
                    s.source = struct('type', 'static', 'value', obj.StaticStatus);
                end
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = StatusWidget();
            obj.Title = s.title;
            if isfield(s, 'description'), obj.Description = s.description; end
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'source')
                switch s.source.type
                    case 'sensor'
                        if exist('SensorRegistry', 'class')
                            obj.Sensor = SensorRegistry.get(s.source.name);
                        end
                    case 'callback'
                        obj.StatusFcn = str2func(s.source.function);
                    case 'static'
                        obj.StaticStatus = s.source.value;
                end
            end
        end
    end

    methods (Access = private)
        function [status, color] = deriveStatusFromSensor(obj, theme)
            status = 'ok';
            color = theme.StatusOkColor;

            if isempty(obj.Sensor.Y), return; end

            if isempty(obj.Sensor.ThresholdRules)
                return;
            end

            latestY = obj.Sensor.Y(end);
            worstDist = -inf;

            for i = 1:numel(obj.Sensor.ThresholdRules)
                rule = obj.Sensor.ThresholdRules{i};
                isViolated = false;
                if rule.IsUpper && latestY > rule.Value
                    isViolated = true;
                elseif ~rule.IsUpper && latestY < rule.Value
                    isViolated = true;
                end

                if isViolated
                    dist = abs(latestY - rule.Value);
                    if dist > worstDist
                        worstDist = dist;
                        status = 'violation';
                        if ~isempty(rule.Color)
                            color = rule.Color;
                        elseif rule.IsUpper
                            color = theme.StatusAlarmColor;
                        else
                            color = theme.StatusWarnColor;
                        end
                    end
                end
            end
        end

        function color = statusToColor(~, status, theme)
            switch status
                case 'ok',      color = theme.StatusOkColor;
                case 'warning', color = theme.StatusWarnColor;
                case 'alarm',   color = theme.StatusAlarmColor;
                otherwise,      color = [0.5 0.5 0.5];
            end
        end
    end
end
