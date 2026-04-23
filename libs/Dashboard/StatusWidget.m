classdef StatusWidget < DashboardWidget
%STATUSWIDGET Colored dot indicator with sensor value.
%
%   Sensor-first:
%     w = StatusWidget('Sensor', sensorObj);
%
%   Threshold-bound (no Sensor required):
%     w = StatusWidget('Title', 'Temp', 'Threshold', t, 'Value', 85);
%     w = StatusWidget('Title', 'Temp', 'Threshold', 'temp_hi', 'ValueFcn', @getTemp);
%
%   Legacy (still supported):
%     w = StatusWidget('Title', 'Pump 1', 'StatusFcn', @() 'ok');

    properties (Access = public)
        StatusFcn    = []       % function_handle returning 'ok'/'warning'/'alarm' (legacy)
        StaticStatus = ''       % fixed status string (legacy)
        Threshold    = []       % Threshold object or registry key string (per D-01)
        Value        = []       % Scalar numeric value for threshold comparison (per D-03)
        ValueFcn     = []       % Function handle returning scalar value (per D-03, D-09)
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
            % Resolve Threshold key string to Tag object via TagRegistry.
            if ischar(obj.Threshold) || isstring(obj.Threshold)
                try
                    obj.Threshold = TagRegistry.get(obj.Threshold);
                catch
                    warning('StatusWidget:thresholdNotFound', ...
                        'TagRegistry key ''%s'' not found.', obj.Threshold);
                    obj.Threshold = [];
                end
            end
            % Mutual exclusivity: Threshold wins (per D-08)
            if ~isempty(obj.Threshold) && ~isempty(obj.Sensor)
                obj.Sensor = [];
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

            if ~isempty(obj.Threshold)
                % MonitorTag bound as Threshold: it already IS a binary
                % alarm signal (0/1), so query its latest sample directly
                % instead of going through the legacy Value / ValueFcn +
                % threshold-comparison path (which returns [] and early-
                % exits when neither Value nor ValueFcn is supplied — the
                % normal way to wire a MonitorTag-backed indicator).
                if thresholdIsMonitorKind_(obj.Threshold)
                    [obj.CurrentStatus, obj.CurrentColor] = obj.deriveStatusFromMonitorTag_(theme);
                else
                    val = obj.resolveCurrentValue_();
                    if isempty(val), return; end
                    [obj.CurrentStatus, obj.CurrentColor] = obj.deriveStatusFromThreshold(val, theme);
                end
            elseif ~isempty(obj.Sensor)
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
                if ~isempty(obj.Threshold)
                    if thresholdIsMonitorKind_(obj.Threshold)
                        lbl = sprintf('%s: %s', obj.Title, upper(obj.CurrentStatus));
                    else
                        val = obj.resolveCurrentValue_();
                        if ~isempty(val)
                            lbl = sprintf('%s: %.1f', obj.Title, val);
                        else
                            lbl = sprintf('%s: %s', obj.Title, upper(obj.CurrentStatus));
                        end
                    end
                elseif ~isempty(obj.Sensor)
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

            if isempty(status) && ~isempty(obj.Threshold)
                t = obj.Threshold;
                if isa(t, 'CompositeThreshold')
                    cStatus = t.computeStatus();
                    if strcmp(cStatus, 'alarm')
                        status = 'violation';
                    else
                        status = 'ok';
                    end
                else
                    val = obj.resolveCurrentValue_();
                    if ~isempty(val)
                        status = 'ok';
                        tVals = t.allValues();
                        for v = 1:numel(tVals)
                            if (t.IsUpper && val > tVals(v)) || ...
                                    (~t.IsUpper && val < tVals(v))
                                status = 'violation';
                                break;
                            end
                        end
                    end
                end
            elseif isempty(status) && ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Y)
                status = 'ok';
                if ~isempty(obj.Sensor.Thresholds)
                    val = obj.Sensor.Y(end);
                    for k = 1:numel(obj.Sensor.Thresholds)
                        t = obj.Sensor.Thresholds{k};
                        tVals = t.allValues();
                        for v = 1:numel(tVals)
                            if (t.IsUpper && val > tVals(v)) || ...
                                    (~t.IsUpper && val < tVals(v))
                                status = 'violation';
                                break;
                            end
                        end
                        if strcmp(status, 'violation'), break; end
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
            if ~isempty(obj.Threshold) && ~isempty(obj.Threshold.Key)
                s.source = struct('type', 'threshold', 'key', obj.Threshold.Key);
                if ~isempty(obj.Value)
                    s.value = obj.Value;
                end
            elseif isempty(obj.Sensor)
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
                        if exist('TagRegistry', 'class')
                            try
                                obj.Tag = TagRegistry.get(s.source.name);
                            catch, end
                        end
                    case 'threshold'
                        if exist('TagRegistry', 'class')
                            try
                                obj.Tag = TagRegistry.get(s.source.key);
                            catch
                                warning('StatusWidget:thresholdNotFound', ...
                                    'Could not resolve threshold key ''%s'' on load.', s.source.key);
                            end
                        end
                    case 'callback'
                        obj.StatusFcn = str2func(s.source.function);
                    case 'static'
                        obj.StaticStatus = s.source.value;
                end
            end
            if isfield(s, 'value'), obj.Value = s.value; end
        end
    end

    methods (Access = private)
        function val = resolveCurrentValue_(obj)
            %RESOLVECURRENTVALUE_ Return the current scalar value from ValueFcn or Value.
            val = [];
            if ~isempty(obj.ValueFcn)
                try
                    val = obj.ValueFcn();
                catch
                    return;
                end
            elseif ~isempty(obj.Value)
                val = obj.Value;
            end
        end

        function [status, color] = deriveStatusFromMonitorTag_(obj, theme)
            %DERIVESTATUSFROMMONITORTAG_ Map a MonitorTag's latest 0/1
            %   sample to status/color. Triggers the MonitorTag's lazy
            %   recompute (which also appends any new transition events
            %   to the attached EventStore), so the Events page receives
            %   fresh events whenever this widget refreshes.
            status = 'ok';
            color  = theme.StatusOkColor;
            try
                [~, y] = obj.Threshold.getXY();
                if ~isempty(y) && y(end) > 0.5
                    status = 'violation';
                    crit = '';
                    try
                        crit = obj.Threshold.Criticality;
                    catch
                    end
                    if any(strcmp(crit, {'high', 'safety'}))
                        color = theme.StatusAlarmColor;
                    else
                        color = theme.StatusWarnColor;
                    end
                end
            catch
            end
        end

        function [status, color] = deriveStatusFromThreshold(obj, val, theme)
            %DERIVESTATUSFROMTHRESHOLD Check single Threshold against scalar val.
            t = obj.Threshold;
            % CompositeThreshold: delegate to computeStatus, ignore val (per D-04)
            if isa(t, 'CompositeThreshold')
                status = t.computeStatus();
                color = obj.statusToColor(status, theme);
                return;
            end
            status = 'ok';
            color = theme.StatusOkColor;

            tVals = t.allValues();
            if isempty(tVals), return; end

            worstDist = -inf;
            for v = 1:numel(tVals)
                isViolated = false;
                if t.IsUpper && val > tVals(v)
                    isViolated = true;
                elseif ~t.IsUpper && val < tVals(v)
                    isViolated = true;
                end

                if isViolated
                    dist = abs(val - tVals(v));
                    if dist > worstDist
                        worstDist = dist;
                        status = 'violation';
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

        function [status, color] = deriveStatusFromSensor(obj, theme)
            status = 'ok';
            color = theme.StatusOkColor;

            if isempty(obj.Sensor.Y), return; end

            if isempty(obj.Sensor.Thresholds)
                return;
            end

            latestY = obj.Sensor.Y(end);
            worstDist = -inf;

            for i = 1:numel(obj.Sensor.Thresholds)
                t = obj.Sensor.Thresholds{i};
                tVals = t.allValues();
                for v = 1:numel(tVals)
                    isViolated = false;
                    if t.IsUpper && latestY > tVals(v)
                        isViolated = true;
                    elseif ~t.IsUpper && latestY < tVals(v)
                        isViolated = true;
                    end

                    if isViolated
                        dist = abs(latestY - tVals(v));
                        if dist > worstDist
                            worstDist = dist;
                            status = 'violation';
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

function tf = thresholdIsMonitorKind_(t)
    %THRESHOLDISMONITORKIND_ True when t is a Tag reporting kind='monitor'.
    %   Uses Tag.getKind() rather than isa() to stay within the project's
    %   Pitfall 1 convention (no subtype checks in widget code).
    tf = false;
    if isempty(t)
        return;
    end
    try
        tf = strcmp(t.getKind(), 'monitor');
    catch
    end
end
