classdef FastSenseWidget < DashboardWidget
%FASTSENSEWIDGET Dashboard widget wrapping a FastSense instance.
%
%   Supports three data binding modes:
%     Sensor:    w = FastSenseWidget('Sensor', sensorObj)
%     DataStore: w = FastSenseWidget('DataStore', dsObj)
%     Inline:    w = FastSenseWidget('XData', x, 'YData', y)
%     File:      w = FastSenseWidget('File', 'path.mat', 'XVar', 'x', 'YVar', 'y')
%
%   When bound to a Sensor, ThresholdRules apply automatically.

    properties (Access = public)
        DataStoreObj = []
        XData        = []
        YData        = []
        File         = ''
        XVar         = ''
        YVar         = ''
        Thresholds   = 'auto'
        XLabel       = ''    % X-axis label (auto-set from Sensor if empty)
        YLabel       = ''    % Y-axis label (auto-set from Sensor if empty)
        YLimits             = []    % Fixed Y-axis range [min max]; empty = auto-scale
        ShowThresholdLabels = false % show inline name labels on threshold lines
    end

    properties (SetAccess = private)
        FastSenseObj = []
        IsSettingTime = false  % guard to distinguish programmatic vs user xlim change
    end

    methods
        function obj = FastSenseWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 12 3];
            end
            if ~isempty(obj.Sensor)
                if isempty(obj.XLabel), obj.XLabel = 'Time'; end
                if isempty(obj.YLabel)
                    if ~isempty(obj.Sensor.Units)
                        obj.YLabel = obj.Sensor.Units;
                    elseif ~isempty(obj.Sensor.Name)
                        obj.YLabel = obj.Sensor.Name;
                    else
                        obj.YLabel = obj.Sensor.Key;
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

            % Create FastSense on this axes
            fp = FastSense('Parent', ax);
            obj.FastSenseObj = fp;
            fp.ShowThresholdLabels = obj.ShowThresholdLabels;

            % Bind data
            if ~isempty(obj.Sensor)
                fp.addSensor(obj.Sensor);
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

            % Apply fixed Y-axis limits if configured
            if ~isempty(obj.YLimits) && numel(obj.YLimits) == 2
                ylim(ax, obj.YLimits);
            end

            % Listen for manual zoom/pan to disable global time for this widget
            try
                addlistener(ax, 'XLim', 'PostSet', @(~,~) obj.onXLimChanged());
            catch
            end
        end

        function refresh(obj)
            % Re-render sensor-bound widgets so updated data + violations show.
            % Preserves current zoom state (xlim) across the rebuild.
            if isempty(obj.Sensor), return; end
            if isempty(obj.hPanel) || ~ishandle(obj.hPanel), return; end

            % Save zoom state before teardown
            savedXLim = [];
            if ~isempty(obj.FastSenseObj) && ~isempty(obj.FastSenseObj.hAxes) && ...
                    ishandle(obj.FastSenseObj.hAxes)
                savedXLim = get(obj.FastSenseObj.hAxes, 'XLim');
            end

            % Delete old axes and FastSense, then rebuild
            if ~isempty(obj.FastSenseObj)
                try delete(obj.FastSenseObj); catch , end
                obj.FastSenseObj = [];
            end
            % Delete any leftover axes in the panel
            ch = findobj(obj.hPanel, 'Type', 'axes');
            delete(ch);

            ax = axes('Parent', obj.hPanel, ...
                'Units', 'normalized', ...
                'Position', [0.08 0.12 0.88 0.78]);

            fp = FastSense('Parent', ax);
            obj.FastSenseObj = fp;
            fp.ShowThresholdLabels = obj.ShowThresholdLabels;
            fp.addSensor(obj.Sensor);

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

            % Apply fixed Y-axis limits if configured
            if ~isempty(obj.YLimits) && numel(obj.YLimits) == 2
                ylim(ax, obj.YLimits);
            end

            % Restore zoom state
            if ~isempty(savedXLim)
                obj.IsSettingTime = true;
                xlim(ax, savedXLim);
                obj.IsSettingTime = false;
            end

            try
                addlistener(ax, 'XLim', 'PostSet', @(~,~) obj.onXLimChanged());
            catch
            end
        end

        function update(obj)
        %UPDATE Incrementally update sensor data without full axes rebuild.
        %   Uses FastSenseObj.updateData() to replace data and re-downsample,
        %   avoiding the expensive delete/recreate cycle of refresh().
        %   Falls back to refresh() if FastSenseObj is not in a renderable state.
            if isempty(obj.Sensor), return; end
            if isempty(obj.hPanel) || ~ishandle(obj.hPanel)
                return;
            end

            % Use incremental path if FastSenseObj is already rendered
            if ~isempty(obj.FastSenseObj) && obj.FastSenseObj.IsRendered
                try
                    obj.FastSenseObj.updateData(1, obj.Sensor.X, obj.Sensor.Y);
                    return;
                catch
                    % Fall through to full refresh on any error
                end
            end

            % Fallback: full rebuild
            obj.refresh();
        end

        function setTimeRange(obj, tStart, tEnd)
            if ~obj.UseGlobalTime
                return;  % widget has its own zoom, skip global time
            end
            if ~isempty(obj.FastSenseObj)
                try
                    ax = obj.FastSenseObj.hAxes;
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
            if ~isempty(obj.Sensor)
                if ~isempty(obj.Sensor.X)
                    tMin = min(obj.Sensor.X);
                    tMax = max(obj.Sensor.X);
                end
            elseif ~isempty(obj.XData)
                tMin = min(obj.XData);
                tMax = max(obj.XData);
            end
        end

        function t = getType(~)
            t = 'fastsense';
        end

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            yData = [];
            if ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Y)
                yData = obj.Sensor.Y;
            elseif ~isempty(obj.YData)
                yData = obj.YData;
            end

            if ~isempty(yData) && height >= 2
                bars = char(9601):char(9608);
                nBars = numel(bars);
                yMin = min(yData); yMax = max(yData);
                if yMax == yMin, yMax = yMin + 1; end
                nPts = min(numel(yData), width);
                idx = round(linspace(1, numel(yData), nPts));
                sampled = yData(idx);
                spark = blanks(nPts);
                for si = 1:nPts
                    level = round((sampled(si) - yMin) / (yMax - yMin) * (nBars - 1)) + 1;
                    level = max(1, min(nBars, level));
                    spark(si) = bars(level);
                end
                if numel(spark) < width
                    spark = [spark, repmat(' ', 1, width - numel(spark))];
                end
                lines{2} = spark(1:width);
            elseif height >= 2
                ph = '[~~ fastsense ~~]';
                if numel(ph) > width, ph = ph(1:width); end
                lines{2} = [ph, repmat(' ', 1, width - numel(ph))];
            end
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.XLabel), s.xLabel = obj.XLabel; end
            if ~isempty(obj.YLabel), s.yLabel = obj.YLabel; end
            if ~isempty(obj.YLimits), s.yLimits = obj.YLimits; end
            if obj.ShowThresholdLabels, s.showThresholdLabels = true; end

            if ~isempty(obj.Sensor)
                % base class handles sensor source
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
            obj = FastSenseWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];

            if isfield(s, 'description')
                obj.Description = s.description;
            end

            if isfield(s, 'source')
                switch s.source.type
                    case 'sensor'
                        if exist('SensorRegistry', 'class')
                            try
                                obj.Sensor = SensorRegistry.get(s.source.name);
                            catch
                                % Sensor not in registry; resolver will
                                % bind it in configToWidgets if provided.
                            end
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
            if isfield(s, 'yLimits')
                obj.YLimits = s.yLimits;
            end
            if isfield(s, 'showThresholdLabels')
                obj.ShowThresholdLabels = s.showThresholdLabels;
            end
        end
    end
end
