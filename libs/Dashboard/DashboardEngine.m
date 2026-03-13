classdef DashboardEngine < handle
%DASHBOARDENGINE Top-level dashboard orchestrator.
%
%   Usage:
%     d = DashboardEngine('My Dashboard');
%     d.Theme = 'light';
%     d.LiveInterval = 5;
%     d.addWidget('fastplot', 'Title', 'Temp', 'Position', [1 1 6 3], ...
%                 'Sensor', SensorRegistry.get('T-401'));
%     d.render();
%
%   Loading from JSON:
%     d = DashboardEngine.load('path/to/dashboard.json');
%     d.render();

    properties (Access = public)
        Name         = ''
        Theme        = 'light'
        LiveInterval = 5
    end

    properties (SetAccess = private)
        Widgets        = {}
        hFigure        = []
        Layout         = []
        Toolbar        = []
        LiveTimer      = []
        IsLive         = false
        FilePath       = ''
        % Time control
        TimePanelHeight = 0.06
        DataTimeRange   = [0 1]    % [tMin tMax] across all widget data
        hTimePanel      = []
        hTimeSliderL    = []       % Left (start) slider
        hTimeSliderR    = []       % Right (end) slider
        hTimeStart      = []
        hTimeEnd        = []
    end

    methods (Access = public)
        function obj = DashboardEngine(name, varargin)
            if nargin >= 1
                obj.Name = name;
            end
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
            obj.Layout = DashboardLayout();
        end

        function addWidget(obj, type, varargin)
            switch type
                case 'fastplot'
                    w = FastPlotWidget(varargin{:});
                case 'kpi'
                    w = KpiWidget(varargin{:});
                case 'status'
                    w = StatusWidget(varargin{:});
                case 'text'
                    w = TextWidget(varargin{:});
                case 'gauge'
                    w = GaugeWidget(varargin{:});
                case 'table'
                    w = TableWidget(varargin{:});
                case 'rawaxes'
                    w = RawAxesWidget(varargin{:});
                case 'timeline'
                    w = EventTimelineWidget(varargin{:});
                otherwise
                    error('DashboardEngine:unknownType', ...
                        'Unknown widget type: %s', type);
            end

            existingPositions = cell(1, numel(obj.Widgets));
            for i = 1:numel(obj.Widgets)
                existingPositions{i} = obj.Widgets{i}.Position;
            end
            w.Position = obj.Layout.resolveOverlap(w.Position, existingPositions);

            obj.Widgets{end+1} = w;
        end

        function render(obj)
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                return;
            end

            themeStruct = DashboardTheme(obj.Theme);

            obj.hFigure = figure('Name', obj.Name, ...
                'NumberTitle', 'off', ...
                'Color', themeStruct.DashboardBackground, ...
                'Units', 'normalized', ...
                'OuterPosition', [0.05 0.05 0.9 0.9], ...
                'CloseRequestFcn', @(~,~) obj.onClose());

            obj.Toolbar = DashboardToolbar(obj, obj.hFigure, themeStruct);

            % Create time control panel at bottom
            obj.createTimePanel(themeStruct);

            % Content area between toolbar and time panel
            toolbarH = obj.Toolbar.Height;
            obj.Layout.ContentArea = [0, obj.TimePanelHeight, ...
                1, 1 - toolbarH - obj.TimePanelHeight];
            obj.Layout.createPanels(obj.hFigure, obj.Widgets, themeStruct);

            % Auto-detect time range from data
            obj.updateGlobalTimeRange();
        end

        function startLive(obj)
            if obj.IsLive
                return;
            end
            obj.IsLive = true;
            obj.LiveTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', obj.LiveInterval, ...
                'TimerFcn', @(~,~) obj.onLiveTick());
            start(obj.LiveTimer);
        end

        function stopLive(obj)
            if ~isempty(obj.LiveTimer)
                stop(obj.LiveTimer);
                delete(obj.LiveTimer);
                obj.LiveTimer = [];
            end
            obj.IsLive = false;
        end

        function save(obj, filepath)
            config = DashboardSerializer.widgetsToConfig( ...
                obj.Name, obj.Theme, obj.LiveInterval, obj.Widgets);
            DashboardSerializer.save(config, filepath);
            obj.FilePath = filepath;
        end

        function exportScript(obj, filepath)
            config = DashboardSerializer.widgetsToConfig( ...
                obj.Name, obj.Theme, obj.LiveInterval, obj.Widgets);
            DashboardSerializer.exportScript(config, filepath);
        end

        function removeWidget(obj, idx)
        %REMOVEWIDGET Remove widget at given index.
            if idx >= 1 && idx <= numel(obj.Widgets)
                w = obj.Widgets{idx};
                if ~isempty(w.hPanel) && ishandle(w.hPanel)
                    delete(w.hPanel);
                end
                obj.Widgets(idx) = [];
            end
        end

        function rerenderWidgets(obj)
        %RERENDERWIDGETS Delete all widget panels and recreate them.
            theme = DashboardTheme(obj.Theme);
            for i = 1:numel(obj.Widgets)
                w = obj.Widgets{i};
                if ~isempty(w.hPanel) && ishandle(w.hPanel)
                    delete(w.hPanel);
                end
            end
            obj.Layout.createPanels(obj.hFigure, obj.Widgets, theme);
        end

        function updateGlobalTimeRange(obj)
        %UPDATEGLOBALTIMERANGE Scan all widgets for data time bounds.
            tMin = inf; tMax = -inf;
            for i = 1:numel(obj.Widgets)
                [wMin, wMax] = obj.Widgets{i}.getTimeRange();
                if wMin < tMin, tMin = wMin; end
                if wMax > tMax, tMax = wMax; end
            end
            if isinf(tMin) || isinf(tMax)
                tMin = 0; tMax = 1;
            end
            obj.DataTimeRange = [tMin, tMax];

            % Reset sliders to full range
            if ~isempty(obj.hTimeSliderL) && ishandle(obj.hTimeSliderL)
                set(obj.hTimeSliderL, 'Value', 0);
                set(obj.hTimeSliderR, 'Value', 1);
            end

            obj.updateTimeLabels(tMin, tMax);
        end

        function broadcastTimeRange(obj, tStart, tEnd)
        %BROADCASTTIMERANGE Push time range to widgets using global time.
            for i = 1:numel(obj.Widgets)
                try
                    obj.Widgets{i}.setTimeRange(tStart, tEnd);
                catch
                end
            end
        end

        function resetGlobalTime(obj)
        %RESETGLOBALTIME Re-attach all widgets to global time and apply.
            for i = 1:numel(obj.Widgets)
                obj.Widgets{i}.UseGlobalTime = true;
            end
            obj.onTimeSlidersChanged();
        end

        function delete(obj)
            obj.stopLive();
        end
    end

    methods (Access = private)
        function createTimePanel(obj, theme)
            tH = obj.TimePanelHeight;

            % Simple uipanel + dual sliders. NavigatorOverlay doesn't
            % work reliably in dashboard context (axes interaction
            % handlers, z-order, uipanel isolation). Sliders just work.
            obj.hTimePanel = uipanel('Parent', obj.hFigure, ...
                'Units', 'normalized', ...
                'Position', [0, 0, 1, tH], ...
                'BorderType', 'line', ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'ForegroundColor', theme.WidgetBorderColor);

            % Start time label
            obj.hTimeStart = uicontrol('Parent', obj.hTimePanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.005 0.55 0.12 0.4], ...
                'String', '', ...
                'FontSize', 9, ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left');

            % End time label
            obj.hTimeEnd = uicontrol('Parent', obj.hTimePanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.88 0.55 0.115 0.4], ...
                'String', '', ...
                'FontSize', 9, ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'right');

            % "From" / "To" labels
            uicontrol('Parent', obj.hTimePanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.005 0.05 0.04 0.45], ...
                'String', 'From:', ...
                'FontSize', 8, ...
                'ForegroundColor', theme.ToolbarFontColor * 0.7 + ...
                    theme.ToolbarBackground * 0.3, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left');

            uicontrol('Parent', obj.hTimePanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.50 0.05 0.03 0.45], ...
                'String', 'To:', ...
                'FontSize', 8, ...
                'ForegroundColor', theme.ToolbarFontColor * 0.7 + ...
                    theme.ToolbarBackground * 0.3, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left');

            % Left slider (range start): 0 = data start, 1 = data end
            obj.hTimeSliderL = uicontrol('Parent', obj.hTimePanel, ...
                'Style', 'slider', ...
                'Units', 'normalized', ...
                'Position', [0.045 0.1 0.45 0.42], ...
                'Min', 0, 'Max', 1, 'Value', 0, ...
                'SliderStep', [0.01 0.1], ...
                'Callback', @(src,~) obj.onTimeSlidersChanged());

            % Right slider (range end): 0 = data start, 1 = data end
            obj.hTimeSliderR = uicontrol('Parent', obj.hTimePanel, ...
                'Style', 'slider', ...
                'Units', 'normalized', ...
                'Position', [0.535 0.1 0.45 0.42], ...
                'Min', 0, 'Max', 1, 'Value', 1, ...
                'SliderStep', [0.01 0.1], ...
                'Callback', @(src,~) obj.onTimeSlidersChanged());
        end

        function onTimeSlidersChanged(obj)
            valL = get(obj.hTimeSliderL, 'Value');
            valR = get(obj.hTimeSliderR, 'Value');

            % Enforce left < right
            if valL >= valR
                valR = min(1, valL + 0.01);
                set(obj.hTimeSliderR, 'Value', valR);
            end

            tr = obj.DataTimeRange;
            span = tr(2) - tr(1);
            tStart = tr(1) + valL * span;
            tEnd   = tr(1) + valR * span;

            obj.broadcastTimeRange(tStart, tEnd);
            obj.updateTimeLabels(tStart, tEnd);
        end

        function updateTimeLabels(obj, tStart, tEnd)
            if isempty(obj.hTimeStart), return; end
            set(obj.hTimeStart, 'String', obj.formatTimeVal(tStart));
            set(obj.hTimeEnd, 'String', obj.formatTimeVal(tEnd));
        end

        function str = formatTimeVal(~, t)
            % Detect datenum (modern dates are > 700000)
            if t > 700000
                if t > 730000
                    str = datestr(t, 'yyyy-mm-dd HH:MM');
                else
                    str = datestr(t, 'HH:MM:SS');
                end
            else
                % Raw numeric (seconds, samples, etc.)
                if abs(t) >= 86400
                    str = sprintf('%.1f d', t / 86400);
                elseif abs(t) >= 3600
                    str = sprintf('%.1f h', t / 3600);
                elseif abs(t) >= 60
                    str = sprintf('%.1f m', t / 60);
                else
                    str = sprintf('%.1f s', t);
                end
            end
        end

        function onClose(obj)
            obj.stopLive();
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                delete(obj.hFigure);
            end
        end

        function onLiveTick(obj)
            for i = 1:numel(obj.Widgets)
                try
                    obj.Widgets{i}.refresh();
                catch ME
                    warning('DashboardEngine:refreshError', ...
                        'Widget "%s" refresh failed: %s', ...
                        obj.Widgets{i}.Title, ME.message);
                end
            end
        end
    end

    methods (Static)
        function obj = load(filepath)
            config = DashboardSerializer.load(filepath);
            obj = DashboardEngine(config.name);
            if isfield(config, 'theme')
                obj.Theme = config.theme;
            end
            if isfield(config, 'liveInterval')
                obj.LiveInterval = config.liveInterval;
            end
            obj.FilePath = filepath;

            widgets = DashboardSerializer.configToWidgets(config);
            for i = 1:numel(widgets)
                w = widgets{i};
                existingPositions = cell(1, numel(obj.Widgets));
                for j = 1:numel(obj.Widgets)
                    existingPositions{j} = obj.Widgets{j}.Position;
                end
                w.Position = obj.Layout.resolveOverlap(w.Position, existingPositions);
                obj.Widgets{end+1} = w;
            end
        end
    end
end
