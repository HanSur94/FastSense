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
            try disableDefaultInteractivity(obj.hAxes); catch , end

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
            if ~isempty(obj.Sensor) && ~isempty(obj.Sensor.X)
                tMin = min(obj.Sensor.X);
                tMax = max(obj.Sensor.X);
            elseif ~isempty(obj.DataRangeFcn)
                r = obj.DataRangeFcn();
                tMin = r(1); tMax = r(2);
            end
        end

        function t = getType(~)
            t = 'rawaxes';
        end

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                info = '[custom axes]';
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.Sensor)
                s.source = struct('type', 'sensor', 'name', obj.Sensor.Key);
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
                        if exist('TagRegistry', 'class')
                            try
                                obj.Tag = TagRegistry.get(s.source.name);
                            catch, end
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
            if ~isempty(obj.Sensor)
                if ~isempty(obj.TimeRange) && nArgs >= 3
                    obj.PlotFcn(obj.hAxes, obj.Sensor, obj.TimeRange);
                elseif nArgs >= 2
                    obj.PlotFcn(obj.hAxes, obj.Sensor);
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
