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
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 6 1];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            bgColor = theme.WidgetBackground;
            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;

            % Adaptive font size based on panel pixel height
            oldUnits = get(parentPanel, 'Units');
            set(parentPanel, 'Units', 'pixels');
            pxPos = get(parentPanel, 'Position');
            set(parentPanel, 'Units', oldUnits);
            pH = pxPos(4);

            baseFontSz = obj.FontSize;
            if baseFontSz == 0
                baseFontSz = max(7, min(14, round(pH * 0.28)));
            end
            titleFontSz = max(8, min(18, round(baseFontSz * 1.2)));

            hasTitle = ~isempty(obj.Title);
            hasContent = ~isempty(obj.Content);

            if hasTitle && hasContent
                obj.hTitleText = uicontrol('Parent', parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Title, ...
                    'Units', 'normalized', ...
                    'Position', [0.02 0.02 0.40 0.96], ...
                    'FontName', fontName, ...
                    'FontSize', titleFontSz, ...
                    'FontWeight', 'bold', ...
                    'ForegroundColor', fgColor, ...
                    'BackgroundColor', bgColor, ...
                    'HorizontalAlignment', obj.Alignment);

                obj.hContentText = uicontrol('Parent', parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Content, ...
                    'Units', 'normalized', ...
                    'Position', [0.43 0.02 0.55 0.96], ...
                    'FontName', fontName, ...
                    'FontSize', baseFontSz, ...
                    'ForegroundColor', fgColor * 0.7 + bgColor * 0.3, ...
                    'BackgroundColor', bgColor, ...
                    'HorizontalAlignment', obj.Alignment);
            elseif hasTitle
                obj.hTitleText = uicontrol('Parent', parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Title, ...
                    'Units', 'normalized', ...
                    'Position', [0.02 0.02 0.96 0.96], ...
                    'FontName', fontName, ...
                    'FontSize', titleFontSz, ...
                    'FontWeight', 'bold', ...
                    'ForegroundColor', fgColor, ...
                    'BackgroundColor', bgColor, ...
                    'HorizontalAlignment', obj.Alignment);
            elseif hasContent
                obj.hContentText = uicontrol('Parent', parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Content, ...
                    'Units', 'normalized', ...
                    'Position', [0.02 0.02 0.96 0.96], ...
                    'FontName', fontName, ...
                    'FontSize', baseFontSz, ...
                    'ForegroundColor', fgColor, ...
                    'BackgroundColor', bgColor, ...
                    'HorizontalAlignment', obj.Alignment);
            end
        end

        function refresh(~)
            % Static widget — nothing to refresh
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
            if isfield(s, 'description')
                obj.Description = s.description;
            end
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

end
