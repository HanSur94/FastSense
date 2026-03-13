classdef RawAxesWidget < DashboardWidget
%RAWAXESWIDGET User-supplied plot function on raw MATLAB axes.
%
%   w = RawAxesWidget('Title', 'Histogram', ...
%       'PlotFcn', @(ax) histogram(ax, randn(1,1000)));

    properties (Access = public)
        PlotFcn = []    % function_handle receiving axes handle: @(ax) plot(ax, ...)
    end

    properties (SetAccess = private)
        hAxes = []
    end

    methods
        function obj = RawAxesWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 4 2];
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
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

            if ~isempty(obj.Title)
                title(obj.hAxes, obj.Title, ...
                    'Color', fgColor, ...
                    'FontSize', theme.WidgetTitleFontSize);
            end

            if ~isempty(obj.PlotFcn)
                obj.PlotFcn(obj.hAxes);
            end
        end

        function refresh(obj)
            if ~isempty(obj.PlotFcn) && ~isempty(obj.hAxes) && ishandle(obj.hAxes)
                cla(obj.hAxes);
                obj.PlotFcn(obj.hAxes);
                if ~isempty(obj.Title)
                    theme = obj.getTheme();
                    title(obj.hAxes, obj.Title, 'Color', theme.ForegroundColor);
                end
            end
        end

        function configure(~)
        end

        function t = getType(~)
            t = 'rawaxes';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.PlotFcn)
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
            if isfield(s, 'source') && strcmp(s.source.type, 'callback')
                obj.PlotFcn = str2func(s.source.function);
            end
        end
    end

    methods (Access = private)
        function theme = getTheme(obj)
            theme = DashboardTheme();
            if ~isempty(fieldnames(obj.ThemeOverride))
                fns = fieldnames(obj.ThemeOverride);
                for i = 1:numel(fns)
                    theme.(fns{i}) = obj.ThemeOverride.(fns{i});
                end
            end
        end
    end
end
