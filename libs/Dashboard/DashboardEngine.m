classdef DashboardEngine < handle
%DASHBOARDENGINE Top-level dashboard orchestrator.
%
%   Usage:
%     d = DashboardEngine('My Dashboard');
%     d.Theme = 'dark';
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
        Theme        = 'default'
        LiveInterval = 5
    end

    properties (SetAccess = private)
        Widgets    = {}
        hFigure    = []
        Layout     = []
        Toolbar    = []
        LiveTimer  = []
        IsLive     = false
        FilePath   = ''
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
                'Visible', 'off', ...
                'OuterPosition', [0.05 0.05 0.9 0.9], ...
                'CloseRequestFcn', @(~,~) obj.onClose());

            obj.Toolbar = DashboardToolbar(obj, obj.hFigure, themeStruct);
            obj.Layout.ContentArea = obj.Toolbar.getContentArea();
            obj.Layout.createPanels(obj.hFigure, obj.Widgets, themeStruct);

            % Show the figure after all widgets are created
            set(obj.hFigure, 'Visible', 'on');
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

        function setWidgetTitle(obj, idx, title)
        %SETWIDGETTITLE Set the title of a widget by index.
            obj.Widgets{idx}.Title = title;
        end

        function setWidgetPosition(obj, idx, pos)
        %SETWIDGETPOSITION Set the grid position of a widget by index.
            obj.Widgets{idx}.Position = pos;
        end

        function setContentArea(obj, contentArea)
        %SETCONTENTAREA Update the Layout content area.
        %   Provided so that DashboardBuilder can modify the layout
        %   without direct write-access to the Layout property (required
        %   for Octave compatibility).
            obj.Layout.ContentArea = contentArea;
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

        function delete(obj)
            obj.stopLive();
        end
    end

    methods (Access = private)
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
