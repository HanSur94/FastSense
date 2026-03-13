classdef TextWidget < DashboardWidget
%TEXTWIDGET Static text label or section header.
%
%   w = TextWidget('Title', 'Section A', 'Content', 'Sensor overview');

    properties (Access = public)
        Content   = ''       % body text
        FontSize  = 0        % 0 = use theme default
        Alignment = 'left'   % 'left', 'center', 'right'
    end

    properties (SetAccess = private)
        hTitleText   = []
        hContentText = []
    end

    methods
        function obj = TextWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 3 1];
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            bgColor = theme.WidgetBackground;
            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;
            fontSize = obj.FontSize;
            if fontSize == 0
                fontSize = theme.WidgetTitleFontSize;
            end

            hasTitle = ~isempty(obj.Title);
            hasContent = ~isempty(obj.Content);

            if hasTitle && hasContent
                obj.hTitleText = uicontrol('Parent', parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Title, ...
                    'Units', 'normalized', ...
                    'Position', [0.05 0.55 0.9 0.4], ...
                    'FontName', fontName, ...
                    'FontSize', fontSize + 2, ...
                    'FontWeight', 'bold', ...
                    'ForegroundColor', fgColor, ...
                    'BackgroundColor', bgColor, ...
                    'HorizontalAlignment', obj.Alignment);

                obj.hContentText = uicontrol('Parent', parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Content, ...
                    'Units', 'normalized', ...
                    'Position', [0.05 0.05 0.9 0.45], ...
                    'FontName', fontName, ...
                    'FontSize', fontSize, ...
                    'ForegroundColor', fgColor * 0.7 + bgColor * 0.3, ...
                    'BackgroundColor', bgColor, ...
                    'HorizontalAlignment', obj.Alignment);
            elseif hasTitle
                obj.hTitleText = uicontrol('Parent', parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Title, ...
                    'Units', 'normalized', ...
                    'Position', [0.05 0.1 0.9 0.8], ...
                    'FontName', fontName, ...
                    'FontSize', fontSize + 2, ...
                    'FontWeight', 'bold', ...
                    'ForegroundColor', fgColor, ...
                    'BackgroundColor', bgColor, ...
                    'HorizontalAlignment', obj.Alignment);
            elseif hasContent
                obj.hContentText = uicontrol('Parent', parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Content, ...
                    'Units', 'normalized', ...
                    'Position', [0.05 0.1 0.9 0.8], ...
                    'FontName', fontName, ...
                    'FontSize', fontSize, ...
                    'ForegroundColor', fgColor, ...
                    'BackgroundColor', bgColor, ...
                    'HorizontalAlignment', obj.Alignment);
            end
        end

        function refresh(~)
            % Static widget — nothing to refresh
        end

        function configure(~)
        end

        function t = getType(~)
            t = 'text';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.content = obj.Content;
            s.fontSize = obj.FontSize;
            s.alignment = obj.Alignment;
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = TextWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'content')
                obj.Content = s.content;
            end
            if isfield(s, 'fontSize')
                obj.FontSize = s.fontSize;
            end
            if isfield(s, 'alignment')
                obj.Alignment = s.alignment;
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
