classdef RawAxesWidget < DashboardWidget
%RAWAXESWIDGET User-supplied plot function on raw MATLAB axes.
%
%   w = RawAxesWidget('Title', 'Histogram', ...
%       'PlotFcn', @(ax) histogram(ax, randn(1,1000)));
%
%   When bound to a Sensor, the PlotFcn receives (ax, sensor) or
%   (ax, sensor, timeRange) depending on its nargin.

    properties (Access = public)
        PlotFcn    = []    % @(ax) or @(ax, sensor[, tRange]) or @(ax, tRange)
        DataRangeFcn = []  % @() returning [tMin tMax] for global time range detection
    end

    properties (SetAccess = private)
        hAxes      = []
        TimeRange  = []    % [tMin tMax] set by global time controls
        IsSettingTime = false
    end

    methods
        function obj = RawAxesWidget(varargin)
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'Sensor')
                    varargin{k} = 'SensorObj';
                end
            end
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 8 2];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.12 0.12 0.82 0.76], ...
                'FontName', fontName, ...
                'FontSize', theme.WidgetTitleFontSize - 1, ...
                'XColor', fgColor, ...
                'YColor', fgColor, ...
                'Color', theme.AxesColor);
            try disableDefaultInteractivity(obj.hAxes); catch, end

            if ~isempty(obj.Title)
                title(obj.hAxes, obj.Title, ...
                    'Color', fgColor, ...
                    'FontSize', theme.WidgetTitleFontSize);
            end

            obj.callPlotFcn();
        end

        function refresh(obj)
            if ~isempty(obj.PlotFcn) && ~isempty(obj.hAxes) && ishandle(obj.hAxes)
                cla(obj.hAxes);
                obj.callPlotFcn();
                if ~isempty(obj.Title)
                    theme = obj.getTheme();
                    title(obj.hAxes, obj.Title, 'Color', theme.ForegroundColor);
                end
            end
        end

        function setTimeRange(obj, tStart, tEnd)
            if ~obj.UseGlobalTime, return; end
            obj.TimeRange = [tStart tEnd];
            if ~isempty(obj.hAxes) && ishandle(obj.hAxes)
                obj.IsSettingTime = true;
                cla(obj.hAxes);
                obj.callPlotFcn();
                if ~isempty(obj.Title)
                    theme = obj.getTheme();
                    title(obj.hAxes, obj.Title, 'Color', theme.ForegroundColor);
                end
                obj.IsSettingTime = false;
            end
        end

        function [tMin, tMax] = getTimeRange(obj)
            tMin = inf; tMax = -inf;
            if ~isempty(obj.SensorObj) && ~isempty(obj.SensorObj.X)
                tMin = min(obj.SensorObj.X);
                tMax = max(obj.SensorObj.X);
            elseif ~isempty(obj.DataRangeFcn)
                r = obj.DataRangeFcn();
                tMin = r(1); tMax = r(2);
            end
        end

        function configure(~)
        end

        function t = getType(~)
            t = 'rawaxes';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.SensorObj)
                s.source = struct('type', 'sensor', 'name', obj.SensorObj.Key);
            elseif ~isempty(obj.PlotFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.PlotFcn));
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = RawAxesWidget();
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
                            obj.SensorObj = SensorRegistry.get(s.source.name);
                        end
                    case 'callback'
                        obj.PlotFcn = str2func(s.source.function);
                end
            end
        end
    end

    methods (Access = private)
        function callPlotFcn(obj)
            if isempty(obj.PlotFcn), return; end
            nArgs = nargin(obj.PlotFcn);
            if ~isempty(obj.SensorObj)
                if ~isempty(obj.TimeRange) && nArgs >= 3
                    obj.PlotFcn(obj.hAxes, obj.SensorObj, obj.TimeRange);
                elseif nArgs >= 2
                    obj.PlotFcn(obj.hAxes, obj.SensorObj);
                else
                    obj.PlotFcn(obj.hAxes);
                end
            else
                if ~isempty(obj.TimeRange) && nArgs >= 2
                    obj.PlotFcn(obj.hAxes, obj.TimeRange);
                else
                    obj.PlotFcn(obj.hAxes);
                end
            end
        end

    end
end
