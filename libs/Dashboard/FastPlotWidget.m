classdef FastPlotWidget < DashboardWidget
%FASTPLOTWIDGET Dashboard widget wrapping a FastPlot instance.
%
%   Supports three data binding modes:
%     Sensor:    w = FastPlotWidget('Sensor', sensorObj)
%     DataStore: w = FastPlotWidget('DataStore', dsObj)
%     Inline:    w = FastPlotWidget('XData', x, 'YData', y)
%     File:      w = FastPlotWidget('File', 'path.mat', 'XVar', 'x', 'YVar', 'y')
%
%   When bound to a Sensor, ThresholdRules apply automatically.

    properties (Access = public)
        SensorObj    = []
        DataStoreObj = []
        XData        = []
        YData        = []
        File         = ''
        XVar         = ''
        YVar         = ''
        Thresholds   = 'auto'
        XLabel       = ''    % X-axis label (auto-set from Sensor if empty)
        YLabel       = ''    % Y-axis label (auto-set from Sensor if empty)
    end

    properties (SetAccess = private)
        FastPlotObj = []
        IsSettingTime = false  % guard to distinguish programmatic vs user xlim change
    end

    methods
        function obj = FastPlotWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 12 3]; % default size for FastPlot

            % Parse name-value pairs
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end

            % Default title and labels from Sensor
            if ~isempty(obj.SensorObj)
                if isempty(obj.Title)
                    if ~isempty(obj.SensorObj.Name)
                        obj.Title = obj.SensorObj.Name;
                    else
                        obj.Title = obj.SensorObj.Key;
                    end
                end
                if isempty(obj.XLabel)
                    obj.XLabel = 'Time';
                end
                if isempty(obj.YLabel)
                    if ~isempty(obj.SensorObj.Name)
                        obj.YLabel = obj.SensorObj.Name;
                    else
                        obj.YLabel = obj.SensorObj.Key;
                    end
                end
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;

            % Create axes inside the panel
            ax = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.08 0.12 0.88 0.78]);

            % Create FastPlot on this axes
            fp = FastPlot('Parent', ax);
            obj.FastPlotObj = fp;

            % Bind data
            if ~isempty(obj.SensorObj)
                fp.addSensor(obj.SensorObj);
            elseif ~isempty(obj.DataStoreObj)
                fp.addLine([], [], 'DataStore', obj.DataStoreObj);
            elseif ~isempty(obj.File)
                data = load(obj.File);
                x = data.(obj.XVar);
                y = data.(obj.YVar);
                fp.addLine(x, y);
            elseif ~isempty(obj.XData) && ~isempty(obj.YData)
                fp.addLine(obj.XData, obj.YData);
            end

            % Set title and axis labels
            if ~isempty(obj.Title)
                title(ax, obj.Title, 'Color', get(ax, 'XColor'));
            end
            if ~isempty(obj.XLabel)
                xlabel(ax, obj.XLabel, 'Color', get(ax, 'XColor'));
            end
            if ~isempty(obj.YLabel)
                ylabel(ax, obj.YLabel, 'Color', get(ax, 'XColor'));
            end

            fp.render();

            % Listen for manual zoom/pan to disable global time for this widget
            try
                addlistener(ax, 'XLim', 'PostSet', @(~,~) obj.onXLimChanged());
            catch
            end
        end

        function refresh(obj)
            % Re-render sensor-bound widgets so updated data + violations show.
            if isempty(obj.SensorObj), return; end
            if isempty(obj.hPanel) || ~ishandle(obj.hPanel), return; end

            % Delete old axes and FastPlot, then rebuild
            if ~isempty(obj.FastPlotObj)
                try delete(obj.FastPlotObj); catch, end
                obj.FastPlotObj = [];
            end
            % Delete any leftover axes in the panel
            ch = findobj(obj.hPanel, 'Type', 'axes');
            delete(ch);

            ax = axes('Parent', obj.hPanel, ...
                'Units', 'normalized', ...
                'Position', [0.08 0.12 0.88 0.78]);

            fp = FastPlot('Parent', ax);
            obj.FastPlotObj = fp;
            fp.addSensor(obj.SensorObj);

            if ~isempty(obj.Title)
                title(ax, obj.Title, 'Color', get(ax, 'XColor'));
            end
            if ~isempty(obj.XLabel)
                xlabel(ax, obj.XLabel, 'Color', get(ax, 'XColor'));
            end
            if ~isempty(obj.YLabel)
                ylabel(ax, obj.YLabel, 'Color', get(ax, 'XColor'));
            end

            fp.render();

            try
                addlistener(ax, 'XLim', 'PostSet', @(~,~) obj.onXLimChanged());
            catch
            end
        end

        function configure(obj) %#ok<MANU>
            % Placeholder for edit mode properties panel
        end

        function setTimeRange(obj, tStart, tEnd)
            if ~obj.UseGlobalTime
                return;  % widget has its own zoom, skip global time
            end
            if ~isempty(obj.FastPlotObj)
                try
                    ax = obj.FastPlotObj.hAxes;
                    if ~isempty(ax) && ishandle(ax)
                        obj.IsSettingTime = true;
                        xlim(ax, [tStart tEnd]);
                        obj.IsSettingTime = false;
                    end
                catch
                    obj.IsSettingTime = false;
                end
            end
        end

        function onXLimChanged(obj)
            % If xlim changed by user zoom/pan (not by setTimeRange),
            % detach this widget from global time.
            if ~obj.IsSettingTime
                obj.UseGlobalTime = false;
            end
        end

        function [tMin, tMax] = getTimeRange(obj)
            tMin = inf; tMax = -inf;
            if ~isempty(obj.SensorObj)
                if ~isempty(obj.SensorObj.X)
                    tMin = min(obj.SensorObj.X);
                    tMax = max(obj.SensorObj.X);
                end
            elseif ~isempty(obj.XData)
                tMin = min(obj.XData);
                tMax = max(obj.XData);
            end
        end

        function t = getType(~)
            t = 'fastplot';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.XLabel), s.xLabel = obj.XLabel; end
            if ~isempty(obj.YLabel), s.yLabel = obj.YLabel; end

            if ~isempty(obj.SensorObj)
                s.source = struct('type', 'sensor', 'name', obj.SensorObj.Key);
                s.thresholds = obj.Thresholds;
            elseif ~isempty(obj.File)
                s.source = struct('type', 'file', 'path', obj.File, ...
                                  'xVar', obj.XVar, 'yVar', obj.YVar);
            elseif ~isempty(obj.XData)
                s.source = struct('type', 'data', 'x', obj.XData, 'y', obj.YData);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = FastPlotWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];

            if isfield(s, 'source')
                switch s.source.type
                    case 'sensor'
                        if exist('SensorRegistry', 'class')
                            obj.SensorObj = SensorRegistry.get(s.source.name);
                        end
                    case 'file'
                        obj.File = s.source.path;
                        obj.XVar = s.source.xVar;
                        obj.YVar = s.source.yVar;
                    case 'data'
                        obj.XData = s.source.x;
                        obj.YData = s.source.y;
                end
            end

            if isfield(s, 'thresholds')
                obj.Thresholds = s.thresholds;
            end
            if isfield(s, 'xLabel')
                obj.XLabel = s.xLabel;
            end
            if isfield(s, 'yLabel')
                obj.YLabel = s.yLabel;
            end
        end
    end
end
