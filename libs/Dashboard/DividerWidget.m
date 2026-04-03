classdef DividerWidget < DashboardWidget
%DIVIDERWIDGET Horizontal divider line for visual section separation.
%
%   DividerWidget renders a horizontal colored line using the theme's
%   WidgetBorderColor (or a custom Color override). It is a static widget
%   with no data binding.
%
%   Usage:
%     d.addWidget('divider');
%     d.addWidget('divider', 'Thickness', 2, 'Position', [1 3 24 1]);
%     w = DividerWidget('Color', [0.8 0.2 0.2]);
%
%   Properties:
%     Thickness  — Relative line thickness (1=thin, 2=medium, 3=thick)
%     Color      — RGB override; empty = use theme WidgetBorderColor
%
%   Methods:
%     render(parentPanel) — creates a uipanel divider line inside parentPanel
%     refresh()           — no-op (static widget)
%     getType()           — returns 'divider'
%     toStruct()          — serializes; omits thickness/color at defaults
%     fromStruct(s)       — static deserializer
%     asciiRender(w,h)    — returns dashes row
%
%   See also: DashboardWidget, TextWidget, DashboardEngine

    properties (Access = public)
        Thickness = 1    % Relative line thickness (1=thin, 2=medium, 3=thick)
        Color     = []   % RGB override; empty = use theme WidgetBorderColor
    end

    properties (SetAccess = private)
        hLine = []       % uipanel handle for the divider line
    end

    methods
        function obj = DividerWidget(varargin)
        %DIVIDERWIDGET Construct a DividerWidget.
        %   obj = DividerWidget() creates with defaults.
        %   obj = DividerWidget('Thickness', 2, 'Color', [1 0 0]) sets props.
            obj = obj@DashboardWidget(varargin{:});
            % Override default Position [1 1 6 2] with full-width single row
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 24 1];
            end
        end

        function render(obj, parentPanel)
        %RENDER Create the divider line inside parentPanel.
        %   render(obj, parentPanel) creates a uipanel that acts as a
        %   horizontal colored line centered vertically in the panel.
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            % Pick color: explicit override or theme WidgetBorderColor
            if ~isempty(obj.Color)
                divColor = obj.Color;
            elseif isfield(theme, 'WidgetBorderColor')
                divColor = theme.WidgetBorderColor;
            else
                divColor = [0.5 0.5 0.5];
            end

            % Map Thickness to normalized panel fraction
            thickFrac = min(1, obj.Thickness * 0.1);
            yPos = (1 - thickFrac) / 2;

            obj.hLine = uipanel(parentPanel, ...
                'Units',           'normalized', ...
                'Position',        [0 yPos 1 thickFrac], ...
                'BackgroundColor', divColor, ...
                'BorderType',      'none');
        end

        function refresh(~)
        %REFRESH No-op for static widget.
        end

        function t = getType(~)
        %GETTYPE Return widget type string.
            t = 'divider';
        end

        function lines = asciiRender(obj, width, height)
        %ASCIIRENDER Return ASCII representation of the divider.
        %   First line is a row of dashes; remaining lines are blank.
            if height <= 0
                lines = {};
                return;
            end
            lines = cell(1, height);
            lines{1} = repmat('-', 1, width);
            blank = repmat(' ', 1, width);
            for i = 2:height
                lines{i} = blank;
            end
        end

        function s = toStruct(obj)
        %TOSTRUCT Serialize to struct.
        %   Omits 'thickness' at default (1) and 'color' when empty.
            s = toStruct@DashboardWidget(obj);
            if obj.Thickness ~= 1
                s.thickness = obj.Thickness;
            end
            if ~isempty(obj.Color)
                s.color = obj.Color;
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
        %FROMSTRUCT Reconstruct DividerWidget from serialized struct.
            obj = DividerWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'description')
                obj.Description = s.description;
            end
            if isfield(s, 'thickness')
                obj.Thickness = s.thickness;
            end
            if isfield(s, 'color')
                obj.Color = s.color;
            end
        end
    end

end
