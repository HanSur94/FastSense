classdef SparklineCardWidget < DashboardWidget
%SPARKLINECARDWIDGET KPI card combining a big-number display with a mini sparkline chart and delta indicator.
%
%   w = SparklineCardWidget('Title', 'CPU', 'StaticValue', 42.0, ...
%                           'SparkData', cpuHistory, 'Units', '%');
%
%   The card is divided into three zones:
%     Top row   — title (left) and delta indicator (right)
%     Middle    — large primary value
%     Bottom    — sparkline mini-chart (bottom 35% of card)
%
%   Data binding (three-path, resolved in priority order):
%     1. Sensor   — uses Sensor.Y for both value and sparkline
%     2. ValueFcn — function_handle returning scalar or struct
%     3. StaticValue + SparkData — static numeric value with separate sparkline vector
%
%   Properties:
%     StaticValue  — fixed scalar value
%     ValueFcn     — function handle returning scalar or struct(.value, .unit)
%     Units        — display unit string
%     Format       — sprintf format for primary value (default '%.1f')
%     NSparkPoints — number of tail points shown in sparkline (default 50)
%     ShowDelta    — show delta indicator (default true)
%     DeltaFormat  — sprintf format for delta (default '%+.1f')
%     SparkColor   — sparkline line color; empty => theme.DragHandleColor
%     SparkData    — numeric vector for sparkline (used when no Sensor)
%
%   See also DashboardWidget, NumberWidget

    properties (Access = public)
        StaticValue  = []        % Fixed scalar value displayed in the card
        ValueFcn     = []        % Function handle returning scalar or struct
        Units        = ''        % Unit label appended to primary value
        Format       = '%.1f'    % sprintf format string for primary value
        NSparkPoints = 50        % Number of tail data points in sparkline
        ShowDelta    = true      % Whether to show the delta indicator
        DeltaFormat  = '%+.1f'  % sprintf format string for delta value
        SparkColor   = []        % Sparkline line color (empty = theme default)
        SparkData    = []        % Numeric vector for sparkline (alternative to Sensor)
    end

    properties (SetAccess = private)
        CurrentValue = []        % Last resolved numeric value
        hTitleText   = []        % uicontrol — title label (top-left)
        hDeltaText   = []        % uicontrol — delta indicator (top-right)
        hValueText   = []        % uicontrol — large primary value (middle)
        hSparkAx     = []        % axes handle for sparkline (bottom 35%)
        hSparkLine   = []        % line handle inside hSparkAx
    end

    methods
        function obj = SparklineCardWidget(varargin)
        %SPARKLINECARDWIDGET Construct a SparklineCardWidget.
        %   Accepts name-value pairs for any public property.
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 6 2];
            end
            if isempty(obj.Units) && ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Units)
                obj.Units = obj.Sensor.Units;
            end
        end

        function render(obj, parentPanel)
        %RENDER Create all graphics objects inside parentPanel.
            obj.hPanel = parentPanel;
            theme      = obj.getTheme();
            bgColor    = theme.WidgetBackground;
            fgColor    = theme.ForegroundColor;
            fontName   = theme.FontName;

            % Adaptive font size from panel pixel height
            oldUnits = get(parentPanel, 'Units');
            set(parentPanel, 'Units', 'pixels');
            pxPos = get(parentPanel, 'Position');
            set(parentPanel, 'Units', oldUnits);
            pH = pxPos(4);
            fontSz = max(7, min(14, round(pH * 0.13)));

            % Title label — top-left
            obj.hTitleText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', obj.Title, ...
                'Units', 'normalized', ...
                'Position', [0.03 0.70 0.55 0.25], ...
                'FontName', fontName, ...
                'FontSize', fontSz, ...
                'FontWeight', 'normal', ...
                'ForegroundColor', fgColor * 0.7 + bgColor * 0.3, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'left');

            % Delta indicator — top-right
            obj.hDeltaText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '', ...
                'Units', 'normalized', ...
                'Position', [0.58 0.70 0.39 0.25], ...
                'FontName', fontName, ...
                'FontSize', fontSz, ...
                'FontWeight', 'normal', ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'right');

            % Large primary value — middle band
            obj.hValueText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '--', ...
                'Units', 'normalized', ...
                'Position', [0.03 0.38 0.94 0.32], ...
                'FontName', fontName, ...
                'FontSize', fontSz + 4, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'left');

            % Sparkline axes — bottom 35%
            obj.hSparkAx = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.02 0.96 0.35], ...
                'Visible', 'off', ...
                'HitTest', 'off');
            try set(obj.hSparkAx, 'PickableParts', 'none'); catch, end
            try disableDefaultInteractivity(obj.hSparkAx); catch, end
            hold(obj.hSparkAx, 'on');

            obj.refresh();
        end

        function refresh(obj)
        %REFRESH Update displayed value, sparkline, and delta indicator.
            if isempty(obj.hPanel) || ~ishandle(obj.hPanel)
                return;
            end

            % --- Resolve primary value ---
            if ~isempty(obj.Sensor)
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

            % Update primary value text
            if ~isempty(obj.CurrentValue) && ~isempty(obj.hValueText) && ishandle(obj.hValueText)
                valStr = sprintf(obj.Format, obj.CurrentValue);
                if ~isempty(obj.Units)
                    valStr = [valStr ' ' obj.Units];
                end
                set(obj.hValueText, 'String', valStr);
            end

            % --- Resolve sparkline data ---
            if ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Y)
                yData = obj.Sensor.Y;
            elseif ~isempty(obj.SparkData)
                yData = obj.SparkData;
            else
                return;
            end

            nPts  = min(obj.NSparkPoints, numel(yData));
            ySnip = yData(end - nPts + 1:end);

            % Flat-data guard — ensure y-range is non-zero
            yMin   = min(ySnip);
            yMax   = max(ySnip);
            yRange = yMax - yMin;
            if yRange == 0
                yRange = 1;
            end

            if ~isempty(obj.hSparkAx) && ishandle(obj.hSparkAx)
                set(obj.hSparkAx, 'XLim', [1 nPts], ...
                    'YLim', [yMin - 0.1 * yRange, yMax + 0.1 * yRange]);
            end

            % Resolve sparkline color
            theme = obj.getTheme();
            if ~isempty(obj.SparkColor)
                lineColor = obj.SparkColor;
            else
                lineColor = theme.DragHandleColor;
            end

            % Create or update sparkline line
            if isempty(obj.hSparkLine) || ~ishandle(obj.hSparkLine)
                if ~isempty(obj.hSparkAx) && ishandle(obj.hSparkAx)
                    obj.hSparkLine = line(obj.hSparkAx, 1:nPts, ySnip, ...
                        'Color', lineColor, 'LineWidth', 1.5);
                end
            else
                set(obj.hSparkLine, 'XData', 1:nPts, 'YData', ySnip);
            end

            % --- Compute and display delta ---
            if obj.ShowDelta && nPts >= 2 && ~isempty(obj.hDeltaText) && ishandle(obj.hDeltaText)
                delta    = ySnip(end) - ySnip(1);
                deltaStr = sprintf(obj.DeltaFormat, delta);
                if delta > 0
                    deltaStr   = [deltaStr ' ' char(9650)];
                    deltaColor = theme.StatusOkColor;
                elseif delta < 0
                    deltaStr   = [deltaStr ' ' char(9660)];
                    deltaColor = theme.StatusAlarmColor;
                else
                    deltaStr   = [deltaStr ' ' char(9654)];
                    deltaColor = theme.ForegroundColor;
                end
                set(obj.hDeltaText, 'String', deltaStr);
                try set(obj.hDeltaText, 'ForegroundColor', deltaColor); catch, end
            end
        end

        function t = getType(~)
        %GETTYPE Return widget type string.
            t = 'sparkline';
        end

        function s = toStruct(obj)
        %TOSTRUCT Serialize widget to a struct for JSON export.
            s = toStruct@DashboardWidget(obj);
            s.units        = obj.Units;
            s.format       = obj.Format;
            s.nSparkPoints = obj.NSparkPoints;
            s.showDelta    = obj.ShowDelta;
            s.deltaFormat  = obj.DeltaFormat;
            if ~isempty(obj.SparkColor)
                s.sparkColor = obj.SparkColor;
            end
            % Source routing: Sensor > ValueFcn > StaticValue
            if isempty(obj.Sensor)
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
        %FROMSTRUCT Deserialize a SparklineCardWidget from a struct.
            obj = SparklineCardWidget();
            obj.Title = s.title;
            if isfield(s, 'description'), obj.Description = s.description; end
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'units'),        obj.Units        = s.units;        end
            if isfield(s, 'format'),       obj.Format       = s.format;       end
            if isfield(s, 'nSparkPoints'), obj.NSparkPoints = s.nSparkPoints; end
            if isfield(s, 'showDelta'),    obj.ShowDelta    = s.showDelta;    end
            if isfield(s, 'deltaFormat'),  obj.DeltaFormat  = s.deltaFormat;  end
            if isfield(s, 'sparkColor'),   obj.SparkColor   = s.sparkColor;   end
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
