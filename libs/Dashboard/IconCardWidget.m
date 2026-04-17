classdef IconCardWidget < DashboardWidget
%ICONCARDWIDGET Compact Mushroom Card-style widget with colored icon, value, and label.
%
%   Displays a state-colored circle icon at the left, a primary numeric value in
%   the center, and a secondary label below the value. Icon color reflects the
%   current threshold state (ok/warn/alarm/info/inactive).
%
%   Usage:
%     w = IconCardWidget('Title', 'Temp', 'StaticValue', 23.5, 'Units', 'degC');
%     w = IconCardWidget('Title', 'Pump', 'Sensor', sensorObj, 'StaticState', 'ok');
%     w = IconCardWidget('Title', 'Pressure', 'ValueFcn', @() readPressure());
%
%   Properties (public):
%     IconColor      - RGB triplet or 'auto' (derive color from state)
%     StaticValue    - Fixed numeric value displayed when no Sensor/ValueFcn
%     ValueFcn       - Function handle returning scalar or struct with .value
%     StaticState    - One of 'ok','warn','alarm','info','inactive','' (empty=auto)
%     Units          - Display units string appended after value
%     Format         - sprintf format string for numeric value (default '%.1f')
%     SecondaryLabel - Subtitle text below primary value; defaults to Title
%
%   See also DashboardWidget, StatusWidget, NumberWidget.

    properties (Access = public)
        IconColor      = 'auto'   % RGB triplet or 'auto' (derive from state)
        StaticValue    = []       % Fixed static value (number)
        ValueFcn       = []       % Function handle returning scalar or struct
        StaticState    = ''       % 'ok','warn','alarm','info','inactive',''
        Units          = ''       % Display units string
        Format         = '%.1f'   % sprintf format for numeric value
        SecondaryLabel = ''       % Subtitle text below primary value
        Threshold      = []       % Threshold object or registry key string (per D-01)
    end

    properties (SetAccess = private)
        hIconAx     = []   % Axes handle for icon circle
        hIconShape  = []   % Fill handle for circle
        hValueText  = []   % uicontrol for primary value
        hLabelText  = []   % uicontrol for secondary label
        CurrentValue = []  % Last resolved value
        CurrentState = ''  % Last resolved state string
    end

    methods
        function obj = IconCardWidget(varargin)
        %ICONCARDWIDGET Construct an IconCardWidget with optional name-value pairs.
            for k = 1:2:numel(varargin)
                key = varargin{k};
                if isprop(obj, key)
                    obj.(key) = varargin{k+1};
                else
                    error('IconCardWidget:unknownOption', 'Unknown option: %s', key);
                end
            end
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 6 2];
            end
            % Resolve Threshold key string to Tag object via TagRegistry.
            if ischar(obj.Threshold) || isstring(obj.Threshold)
                try
                    obj.Threshold = TagRegistry.get(obj.Threshold);
                catch
                    warning('IconCardWidget:thresholdNotFound', ...
                        'TagRegistry key ''%s'' not found.', obj.Threshold);
                    obj.Threshold = [];
                end
            end
            % Tag validation + precedence Tag > Threshold > Sensor (v2.0 Tag API).
            % Tag wins via a constructor mutex parallel to the Threshold > Sensor
            % mutex below. Dispatch remains polymorphic — no isa on subclass
            % kinds (Pitfall 1).
            if ~isempty(obj.Tag) && ~isa(obj.Tag, 'Tag')
                error('IconCardWidget:invalidTag', ...
                    'Tag must be a Tag subclass; got %s.', class(obj.Tag));
            end
            if ~isempty(obj.Tag)
                obj.Threshold = [];
                obj.Sensor    = [];
            end
            % Mutual exclusivity: Threshold wins (per D-08)
            if ~isempty(obj.Threshold) && ~isempty(obj.Sensor)
                obj.Sensor = [];
            end
        end

        function render(obj, parentPanel)
        %RENDER Create icon, value text, and label inside parentPanel.
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            bgColor  = theme.WidgetBackground;
            fgColor  = theme.ForegroundColor;
            fontName = theme.FontName;

            % Adaptive font size from panel pixel height
            oldUnits = get(parentPanel, 'Units');
            set(parentPanel, 'Units', 'pixels');
            pxPos = get(parentPanel, 'Position');
            set(parentPanel, 'Units', oldUnits);
            pH = pxPos(4);
            fontSz = max(7, min(14, round(pH * 0.28)));

            % Icon axes — small square at left, circle fits inside unit square
            obj.hIconAx = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.15 0.16 0.70], ...
                'Visible', 'off', ...
                'DataAspectRatio', [1 1 1], ...
                'XLim', [-1.2 1.2], ...
                'YLim', [-1.2 1.2], ...
                'HitTest', 'off');
            try set(obj.hIconAx, 'PickableParts', 'none'); catch , end
            try disableDefaultInteractivity(obj.hIconAx); catch , end
            hold(obj.hIconAx, 'on');

            % Draw filled circle
            theta = linspace(0, 2*pi, 60);
            obj.hIconShape = fill(obj.hIconAx, cos(theta), sin(theta), ...
                [0.5 0.5 0.5], 'EdgeColor', 'none', 'HitTest', 'off');

            % Primary value text — large, bold, center area
            obj.hValueText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '--', ...
                'Units', 'normalized', ...
                'Position', [0.20 0.45 0.75 0.50], ...
                'FontName', fontName, ...
                'FontSize', fontSz + 2, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'center');

            % Secondary label text — smaller, below value
            obj.hLabelText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '', ...
                'Units', 'normalized', ...
                'Position', [0.20 0.05 0.75 0.40], ...
                'FontName', fontName, ...
                'FontSize', max(6, fontSz - 1), ...
                'FontWeight', 'normal', ...
                'ForegroundColor', fgColor * 0.7 + bgColor * 0.3, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'center');

            obj.refresh();
        end

        function refresh(obj)
        %REFRESH Update icon color, value display, and label.
            if isempty(obj.hPanel) || ~ishandle(obj.hPanel)
                return;
            end

            % Resolve value with Tag > Threshold > Sensor > ValueFcn > StaticValue
            % precedence. Tag branch uses polymorphic valueAt(now) on any Tag
            % subclass (Pitfall 1); legacy branches below preserved byte-for-byte.
            if ~isempty(obj.Tag)
                try
                    v = obj.Tag.valueAt(now);
                    if ~isempty(v) && ~any(isnan(v))
                        obj.CurrentValue = v;
                    end
                    if isempty(obj.Units) && isprop(obj.Tag, 'Units') && ~isempty(obj.Tag.Units)
                        obj.Units = obj.Tag.Units;
                    end
                catch
                    % fall through — state branch handles inactive below
                end
            elseif ~isempty(obj.Threshold)
                % Threshold mode: value from ValueFcn or StaticValue (no Sensor)
                if ~isempty(obj.ValueFcn)
                    result = obj.ValueFcn();
                    if isstruct(result)
                        obj.CurrentValue = result.value;
                        if isfield(result, 'unit'), obj.Units = result.unit; end
                    else
                        obj.CurrentValue = result;
                    end
                elseif ~isempty(obj.StaticValue)
                    obj.CurrentValue = obj.StaticValue;
                end
            elseif ~isempty(obj.Sensor)
                if isempty(obj.Sensor.Y), return; end
                obj.CurrentValue = obj.Sensor.Y(end);
                if isempty(obj.Units) && ~isempty(obj.Sensor.Units)
                    obj.Units = obj.Sensor.Units;
                end
            elseif ~isempty(obj.ValueFcn)
                result = obj.ValueFcn();
                if isstruct(result)
                    obj.CurrentValue = result.value;
                    if isfield(result, 'unit'), obj.Units = result.unit; end
                else
                    obj.CurrentValue = result;
                end
            elseif ~isempty(obj.StaticValue)
                obj.CurrentValue = obj.StaticValue;
            end

            % Resolve state with Tag > StaticState > Threshold > Sensor precedence.
            if ~isempty(obj.StaticState)
                obj.CurrentState = obj.StaticState;
            elseif ~isempty(obj.Tag)
                obj.CurrentState = obj.deriveStateFromTag_();
            elseif ~isempty(obj.Threshold)
                obj.CurrentState = obj.deriveStateFromThreshold();
            elseif ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Y)
                obj.CurrentState = obj.deriveStateFromSensor();
            else
                obj.CurrentState = 'inactive';
            end

            % Resolve icon color
            theme = obj.getTheme();
            if ischar(obj.IconColor) && strcmp(obj.IconColor, 'auto')
                resolvedColor = obj.resolveIconColor(theme);
            else
                resolvedColor = obj.IconColor;
            end

            % Update icon circle color
            if ~isempty(obj.hIconShape) && ishandle(obj.hIconShape)
                set(obj.hIconShape, 'FaceColor', resolvedColor);
            end

            % Update primary value text
            if ~isempty(obj.hValueText) && ishandle(obj.hValueText)
                if ~isempty(obj.CurrentValue)
                    valStr = sprintf(obj.Format, obj.CurrentValue);
                    if ~isempty(obj.Units)
                        valStr = [valStr ' ' obj.Units];
                    end
                    set(obj.hValueText, 'String', valStr);
                end
            end

            % Update secondary label
            if ~isempty(obj.hLabelText) && ishandle(obj.hLabelText)
                if ~isempty(obj.SecondaryLabel)
                    set(obj.hLabelText, 'String', obj.SecondaryLabel);
                else
                    set(obj.hLabelText, 'String', obj.Title);
                end
            end
        end

        function t = getType(~)
        %GETTYPE Return widget type string.
            t = 'iconcard';
        end

        function s = toStruct(obj)
        %TOSTRUCT Serialize widget to struct for JSON export.
            s = toStruct@DashboardWidget(obj);
            s.units = obj.Units;
            s.format = obj.Format;
            s.secondaryLabel = obj.SecondaryLabel;
            if ~ischar(obj.IconColor) || ~strcmp(obj.IconColor, 'auto')
                s.iconColor = obj.IconColor;
            end
            if ~isempty(obj.StaticState)
                s.staticState = obj.StaticState;
            end
            % Source routing: Tag > Threshold > Sensor > ValueFcn > StaticValue.
            % Tag branch is already written by toStruct@DashboardWidget (base class,
            % Plan 1009-02) — do not overwrite it below. Legacy branches unchanged.
            if ~isempty(obj.Tag) && ~isempty(obj.Tag.Key)
                % s.source already set by base-class toStruct; pass through.
            elseif ~isempty(obj.Threshold) && ~isempty(obj.Threshold.Key)
                s.source = struct('type', 'threshold', 'key', obj.Threshold.Key);
                if ~isempty(obj.StaticValue)
                    s.value = obj.StaticValue;
                end
            elseif isempty(obj.Sensor)
                if ~isempty(obj.ValueFcn)
                    s.source = struct('type', 'callback', 'function', func2str(obj.ValueFcn));
                elseif ~isempty(obj.StaticValue)
                    s.source = struct('type', 'static', 'value', obj.StaticValue);
                end
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
        %FROMSTRUCT Reconstruct IconCardWidget from a serialized struct.
            obj = IconCardWidget();
            obj.Title = s.title;
            if isfield(s, 'description'), obj.Description = s.description; end
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'units'), obj.Units = s.units; end
            if isfield(s, 'format'), obj.Format = s.format; end
            if isfield(s, 'secondaryLabel'), obj.SecondaryLabel = s.secondaryLabel; end
            if isfield(s, 'iconColor'), obj.IconColor = s.iconColor; end
            if isfield(s, 'staticState'), obj.StaticState = s.staticState; end
            if isfield(s, 'source')
                switch s.source.type
                    case 'tag'
                        if exist('TagRegistry', 'class')
                            try
                                obj.Tag = TagRegistry.get(s.source.key);
                            catch
                                warning('IconCardWidget:tagNotFound', ...
                                    'Could not resolve Tag key ''%s'' on load.', s.source.key);
                            end
                        end
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
                    case 'threshold'
                        if exist('TagRegistry', 'class')
                            try
                                obj.Tag = TagRegistry.get(s.source.key);
                            catch
                                warning('IconCardWidget:thresholdNotFound', ...
                                    'Could not resolve threshold key ''%s'' on load.', s.source.key);
                            end
                        end
                end
            end
            if isfield(s, 'value'), obj.StaticValue = s.value; end
        end
    end

    methods (Access = private)
        function color = resolveIconColor(obj, theme)
        %RESOLVEICONCOLOR Map current state to a theme color.
            switch obj.CurrentState
                case 'ok',       color = theme.StatusOkColor;
                case 'warn',     color = theme.StatusWarnColor;
                case 'alarm',    color = theme.StatusAlarmColor;
                case 'info',     color = theme.InfoColor;
                otherwise,       color = [0.5 0.5 0.5];
            end
        end

        function state = deriveStateFromTag_(obj)
        %DERIVESTATEFROMTAG_ Derive state string from Tag valueAt(now).
        %   Returns 'alarm' when v >= 0.5, 'ok' when v < 0.5, 'inactive'
        %   otherwise. Polymorphic on any Tag subclass — no isa switches
        %   (Pitfall 1 invariant).
            state = 'inactive';
            if isempty(obj.Tag), return; end
            try
                v = obj.Tag.valueAt(now);
            catch
                return;
            end
            if isempty(v) || any(isnan(v)), return; end
            if v >= 0.5
                state = 'alarm';
            else
                state = 'ok';
            end
        end

        function state = deriveStateFromThreshold(obj)
        %DERIVASTATEFROMTHRESHOLD Derive state string from a Threshold object.
            state = 'ok';
            if isempty(obj.Threshold), state = 'inactive'; return; end
            % CompositeThreshold: delegate to computeStatus, no val needed (per D-04)
            if isa(obj.Threshold, 'CompositeThreshold')
                cStatus = obj.Threshold.computeStatus();
                if strcmp(cStatus, 'ok'), state = 'active'; else, state = 'alarm'; end
                return;
            end
            val = obj.CurrentValue;
            if isempty(val), state = 'inactive'; return; end
            tVals = obj.Threshold.allValues();
            for v = 1:numel(tVals)
                if (obj.Threshold.IsUpper && val > tVals(v)) || ...
                        (~obj.Threshold.IsUpper && val < tVals(v))
                    state = 'alarm';
                    return;
                end
            end
        end

        function state = deriveStateFromSensor(obj)
        %DERIVASTATEFROMSENSOR Derive state string from sensor threshold rules.
            state = 'ok';
            if isempty(obj.Sensor) || isempty(obj.Sensor.Y)
                state = 'inactive';
                return;
            end
            if isempty(obj.Sensor.Thresholds)
                return;
            end
            latestY = obj.Sensor.Y(end);
            for i = 1:numel(obj.Sensor.Thresholds)
                t = obj.Sensor.Thresholds{i};
                tVals = t.allValues();
                for v = 1:numel(tVals)
                    if (t.IsUpper && latestY > tVals(v)) || ...
                            (~t.IsUpper && latestY < tVals(v))
                        state = 'alarm';
                        return;
                    end
                end
            end
        end
    end
end
