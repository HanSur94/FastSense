classdef DashboardBuilder < handle
%DASHBOARDBUILDER Edit mode overlay for dashboard GUI.
%
%   Provides drag/resize overlays, a widget palette sidebar, and a
%   properties panel. Activated via the Edit button in DashboardToolbar.
%
%   builder = DashboardBuilder(engine);
%   builder.enterEditMode();
%   builder.exitEditMode();

    properties (Access = public)
        IsActive = false
    end

    properties (SetAccess = private)
        Engine          = []

        % Sidebar panels
        hPalette        = []
        hPropsPanel     = []

        % Per-widget overlays: cell of structs {hDragBar, hResize}
        Overlays        = {}

        % Drag/resize state
        DragMode        = ''       % '', 'drag', 'resize'
        DragIdx         = 0
        DragStart       = [0 0]
        DragOrigGrid    = [0 0 0 0]
        DragOrigNorm    = [0 0 0 0]

        % Selected widget
        SelectedIdx     = 0

        % Properties panel controls
        hPropTitle      = []
        hPropCol        = []
        hPropRow        = []
        hPropWidth      = []
        hPropHeight     = []
        hPropApply      = []
        hPropDelete     = []
        hPropLabel      = []

        % Layout constants (normalized figure coords)
        PaletteWidth    = 0.12
        PropsWidth      = 0.18

    end

    properties (Access = public)
        % Test support: when non-empty, overrides figure CurrentPoint
        MockCurrentPoint = []
    end

    methods (Access = public)
        function obj = DashboardBuilder(engine)
            obj.Engine = engine;
        end

        function enterEditMode(obj)
            if obj.IsActive, return; end

            eng = obj.Engine;
            if isempty(eng.hFigure) || ~ishandle(eng.hFigure)
                error('DashboardBuilder:noFigure', ...
                    'Dashboard must be rendered before entering edit mode.');
            end

            obj.IsActive = true;
            obj.SelectedIdx = 0;
            eng.stopLive();

            hFig = eng.hFigure;
            theme = DashboardTheme(eng.Theme);

            % Install mouse callbacks
            set(hFig, 'WindowButtonMotionFcn', @(~,~) obj.onMouseMove());
            set(hFig, 'WindowButtonUpFcn', @(~,~) obj.onMouseUp());

            % Create sidebars
            obj.createPalette(hFig, theme);
            obj.createPropertiesPanel(hFig, theme);

            % Re-layout with narrowed content area
            obj.relayoutWidgets(theme);

            % Add edit overlays on each widget
            obj.createOverlays(theme);
        end

        function exitEditMode(obj)
            if ~obj.IsActive, return; end
            obj.IsActive = false;
            obj.SelectedIdx = 0;
            obj.DragMode = '';

            obj.clearOverlays();

            % Delete sidebars
            safeDelete(obj.hPalette);
            obj.hPalette = [];
            safeDelete(obj.hPropsPanel);
            obj.hPropsPanel = [];

            hFig = obj.Engine.hFigure;
            if isempty(hFig) || ~ishandle(hFig)
                return;
            end

            set(hFig, 'WindowButtonMotionFcn', '');
            set(hFig, 'WindowButtonUpFcn', '');

            % Restore full content area and re-render
            theme = DashboardTheme(obj.Engine.Theme);
            obj.Engine.setContentArea(obj.Engine.Toolbar.getContentArea());
            obj.relayoutWidgets(theme);
        end
    end

    methods
        function selectWidget(obj, idx)
            obj.SelectedIdx = idx;
            obj.updatePropertiesDisplay();

            % Highlight selected overlay
            for i = 1:numel(obj.Overlays)
                ov = obj.Overlays{i};
                if ishandle(ov.hDragBar)
                    if i == idx
                        set(ov.hDragBar, 'BorderType', 'line', ...
                            'BorderWidth', 2, ...
                            'ForegroundColor', [1 1 1]);
                    else
                        set(ov.hDragBar, 'BorderType', 'none');
                    end
                end
            end
        end

        function addWidget(obj, type)
            eng = obj.Engine;
            pos = obj.findNextSlot(type);
            defaultTitle = obj.defaultTitleForType(type);
            eng.addWidget(type, 'Title', defaultTitle, 'Position', pos);

            theme = DashboardTheme(eng.Theme);
            obj.relayoutWidgets(theme);
            obj.clearOverlays();
            obj.createOverlays(theme);
            obj.selectWidget(numel(eng.Widgets));
        end

        function deleteWidget(obj, idx)
            eng = obj.Engine;
            eng.removeWidget(idx);

            if obj.SelectedIdx == idx
                obj.SelectedIdx = 0;
            elseif obj.SelectedIdx > idx
                obj.SelectedIdx = obj.SelectedIdx - 1;
            end

            theme = DashboardTheme(eng.Theme);
            obj.relayoutWidgets(theme);
            obj.clearOverlays();
            obj.createOverlays(theme);

            if obj.SelectedIdx > 0
                obj.selectWidget(obj.SelectedIdx);
            else
                obj.updatePropertiesDisplay();
            end
        end

        function deleteSelected(obj)
            if obj.SelectedIdx > 0
                obj.deleteWidget(obj.SelectedIdx);
            end
        end

        function applyProperties(obj)
            if obj.SelectedIdx == 0, return; end

            w = obj.Engine.Widgets{obj.SelectedIdx};
            w.Title = get(obj.hPropTitle, 'String');

            col = str2double(get(obj.hPropCol, 'String'));
            row = str2double(get(obj.hPropRow, 'String'));
            wid = str2double(get(obj.hPropWidth, 'String'));
            hgt = str2double(get(obj.hPropHeight, 'String'));

            if ~isnan(col) && ~isnan(row) && ~isnan(wid) && ~isnan(hgt)
                col = max(1, min(col, 12));
                row = max(1, row);
                wid = max(1, min(wid, 13 - col));
                hgt = max(1, hgt);
                w.Position = [col, row, wid, hgt];
            end

            theme = DashboardTheme(obj.Engine.Theme);
            obj.relayoutWidgets(theme);
            obj.clearOverlays();
            obj.createOverlays(theme);
            obj.selectWidget(obj.SelectedIdx);
        end

        function pos = findNextSlot(obj, type)
            switch type
                case 'fastplot', defW = 6; defH = 3;
                case 'kpi',      defW = 3; defH = 1;
                case 'status',   defW = 2; defH = 1;
                case 'text',     defW = 3; defH = 1;
                case 'gauge',    defW = 4; defH = 2;
                case 'table',    defW = 4; defH = 2;
                case 'rawaxes',  defW = 4; defH = 2;
                case 'timeline', defW = 12; defH = 2;
                otherwise,       defW = 4; defH = 2;
            end

            maxBottom = 0;
            widgets = obj.Engine.Widgets;
            for i = 1:numel(widgets)
                p = widgets{i}.Position;
                bottom = p(2) + p(4) - 1;
                if bottom > maxBottom
                    maxBottom = bottom;
                end
            end

            pos = [1, maxBottom + 1, defW, defH];
        end
    end

    methods (Access = private)
        function cp = getMousePosition(obj)
        %GETMOUSEPOSITION Return current mouse position.
        %   Uses MockCurrentPoint when set (for testing), otherwise
        %   reads from the figure's CurrentPoint property.
            if ~isempty(obj.MockCurrentPoint)
                cp = obj.MockCurrentPoint;
            else
                cp = get(obj.Engine.hFigure, 'CurrentPoint');
            end
        end

        function createPalette(obj, hFig, theme)
            toolbarH = obj.Engine.Toolbar.Height;
            obj.hPalette = uipanel('Parent', hFig, ...
                'Units', 'normalized', ...
                'Position', [0, 0, obj.PaletteWidth, 1 - toolbarH], ...
                'BorderType', 'line', ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'ForegroundColor', theme.WidgetBorderColor);

            % Section title
            uicontrol('Parent', obj.hPalette, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.93 0.9 0.05], ...
                'String', 'Widgets', ...
                'FontSize', theme.HeaderFontSize, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left');

            types  = {'fastplot','kpi','status','text', ...
                      'gauge','table','rawaxes','timeline'};
            labels = {'FastPlot','KPI','Status','Text', ...
                      'Gauge','Table','Raw Axes','Timeline'};

            btnH = 0.05;
            btnGap = 0.01;
            startY = 0.92 - btnH;

            for i = 1:numel(types)
                y = startY - (i-1) * (btnH + btnGap);
                t = types{i};
                uicontrol('Parent', obj.hPalette, ...
                    'Style', 'pushbutton', ...
                    'Units', 'normalized', ...
                    'Position', [0.05 y 0.9 btnH], ...
                    'String', labels{i}, ...
                    'Callback', @(~,~) obj.addWidget(t));
            end
        end

        function createPropertiesPanel(obj, hFig, theme)
            toolbarH = obj.Engine.Toolbar.Height;
            x = 1 - obj.PropsWidth;
            h = 1 - toolbarH;
            obj.hPropsPanel = uipanel('Parent', hFig, ...
                'Units', 'normalized', ...
                'Position', [x, 0, obj.PropsWidth, h], ...
                'BorderType', 'line', ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'ForegroundColor', theme.WidgetBorderColor);

            % Section title
            uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.93 0.9 0.05], ...
                'String', 'Properties', ...
                'FontSize', theme.HeaderFontSize, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left');

            obj.hPropLabel = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.86 0.9 0.05], ...
                'String', 'Select a widget to edit', ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left');

            lh = 0.035;  % label height
            fh = 0.04;   % field height
            gap = 0.005;
            bg = theme.ToolbarBackground;
            fg = theme.ToolbarFontColor;

            y = 0.78;

            % Title field
            uicontrol('Parent', obj.hPropsPanel, 'Style', 'text', ...
                'Units', 'normalized', 'Position', [0.05 y 0.9 lh], ...
                'String', 'Title:', 'ForegroundColor', fg, ...
                'BackgroundColor', bg, 'HorizontalAlignment', 'left', ...
                'Visible', 'off', 'Tag', 'propLabel');
            y = y - fh - gap;
            obj.hPropTitle = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.05 y 0.9 fh], ...
                'String', '', 'Visible', 'off');
            y = y - lh - gap*3;

            % Col / Row
            uicontrol('Parent', obj.hPropsPanel, 'Style', 'text', ...
                'Units', 'normalized', 'Position', [0.05 y 0.4 lh], ...
                'String', 'Col:', 'ForegroundColor', fg, ...
                'BackgroundColor', bg, 'HorizontalAlignment', 'left', ...
                'Visible', 'off', 'Tag', 'propLabel');
            uicontrol('Parent', obj.hPropsPanel, 'Style', 'text', ...
                'Units', 'normalized', 'Position', [0.5 y 0.4 lh], ...
                'String', 'Row:', 'ForegroundColor', fg, ...
                'BackgroundColor', bg, 'HorizontalAlignment', 'left', ...
                'Visible', 'off', 'Tag', 'propLabel');
            y = y - fh - gap;
            obj.hPropCol = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.05 y 0.4 fh], ...
                'String', '', 'Visible', 'off');
            obj.hPropRow = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.5 y 0.4 fh], ...
                'String', '', 'Visible', 'off');
            y = y - lh - gap*3;

            % Width / Height
            uicontrol('Parent', obj.hPropsPanel, 'Style', 'text', ...
                'Units', 'normalized', 'Position', [0.05 y 0.4 lh], ...
                'String', 'Width:', 'ForegroundColor', fg, ...
                'BackgroundColor', bg, 'HorizontalAlignment', 'left', ...
                'Visible', 'off', 'Tag', 'propLabel');
            uicontrol('Parent', obj.hPropsPanel, 'Style', 'text', ...
                'Units', 'normalized', 'Position', [0.5 y 0.4 lh], ...
                'String', 'Height:', 'ForegroundColor', fg, ...
                'BackgroundColor', bg, 'HorizontalAlignment', 'left', ...
                'Visible', 'off', 'Tag', 'propLabel');
            y = y - fh - gap;
            obj.hPropWidth = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.05 y 0.4 fh], ...
                'String', '', 'Visible', 'off');
            obj.hPropHeight = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.5 y 0.4 fh], ...
                'String', '', 'Visible', 'off');
            y = y - fh - gap*4;

            % Apply / Delete buttons
            obj.hPropApply = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'pushbutton', 'Units', 'normalized', ...
                'Position', [0.05 y 0.42 fh], ...
                'String', 'Apply', 'Visible', 'off', ...
                'Callback', @(~,~) obj.applyProperties());

            obj.hPropDelete = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'pushbutton', 'Units', 'normalized', ...
                'Position', [0.52 y 0.42 fh], ...
                'String', 'Delete', 'Visible', 'off', ...
                'Callback', @(~,~) obj.deleteSelected());
        end

        function relayoutWidgets(obj, theme)
            % Delete existing widget panels
            widgets = obj.Engine.Widgets;
            for i = 1:numel(widgets)
                if ~isempty(widgets{i}.hPanel) && ishandle(widgets{i}.hPanel)
                    delete(widgets{i}.hPanel);
                end
            end

            % Compute content area (narrowed when edit mode active)
            toolbarH = obj.Engine.Toolbar.Height;
            if obj.IsActive
                contentArea = [obj.PaletteWidth, 0, ...
                    1 - obj.PaletteWidth - obj.PropsWidth, ...
                    1 - toolbarH];
            else
                contentArea = [0, 0, 1, 1 - toolbarH];
            end
            obj.Engine.setContentArea(contentArea);

            % Re-create all widget panels
            obj.Engine.Layout.createPanels(obj.Engine.hFigure, widgets, theme);
        end

        function createOverlays(obj, theme)
            obj.clearOverlays();
            widgets = obj.Engine.Widgets;
            hFig = obj.Engine.hFigure;

            % Pre-allocate so overlay indices match widget indices
            obj.Overlays = cell(1, numel(widgets));

            for i = 1:numel(widgets)
                w = widgets{i};
                if isempty(w.hPanel) || ~ishandle(w.hPanel)
                    obj.Overlays{i} = struct('hDragBar', [], 'hResize', []);
                    continue;
                end

                panelPos = get(w.hPanel, 'Position');
                ov = struct();
                idx = i;

                % Drag handle bar at top of widget panel
                handleH = 0.022;
                ov.hDragBar = uipanel('Parent', hFig, ...
                    'Units', 'normalized', ...
                    'Position', [panelPos(1), ...
                                 panelPos(2) + panelPos(4) - handleH, ...
                                 panelPos(3), handleH], ...
                    'BackgroundColor', theme.DragHandleColor, ...
                    'BorderType', 'none', ...
                    'ButtonDownFcn', @(~,~) obj.onDragStart(idx));

                % Title label inside drag bar
                ov.hDragLabel = uicontrol('Parent', ov.hDragBar, ...
                    'Style', 'text', ...
                    'Units', 'normalized', ...
                    'Position', [0.02 0 0.72 1], ...
                    'String', w.Title, ...
                    'FontSize', 9, ...
                    'FontWeight', 'bold', ...
                    'ForegroundColor', [1 1 1], ...
                    'BackgroundColor', theme.DragHandleColor, ...
                    'HorizontalAlignment', 'left', ...
                    'Enable', 'inactive', ...
                    'ButtonDownFcn', @(~,~) obj.onDragStart(idx));

                % Delete (X) button in drag bar
                ov.hDeleteBtn = uicontrol('Parent', ov.hDragBar, ...
                    'Style', 'pushbutton', ...
                    'Units', 'normalized', ...
                    'Position', [0.93 0.05 0.065 0.9], ...
                    'String', 'X', ...
                    'FontWeight', 'bold', ...
                    'Callback', @(~,~) obj.deleteWidget(idx));

                % Resize handle at bottom-right corner
                rsW = 0.012;
                rsH = 0.012;
                ov.hResize = uicontrol('Parent', hFig, ...
                    'Style', 'text', ...
                    'Units', 'normalized', ...
                    'Position', [panelPos(1) + panelPos(3) - rsW, ...
                                 panelPos(2), rsW, rsH], ...
                    'String', '/', ...
                    'FontSize', 8, ...
                    'BackgroundColor', theme.DragHandleColor, ...
                    'ForegroundColor', [1 1 1], ...
                    'Enable', 'inactive', ...
                    'ButtonDownFcn', @(~,~) obj.onResizeStart(idx));

                obj.Overlays{i} = ov;
            end
        end

        function clearOverlays(obj)
            for i = 1:numel(obj.Overlays)
                ov = obj.Overlays{i};
                safeDelete(ov.hDragBar);
                safeDelete(ov.hResize);
            end
            obj.Overlays = {};
        end

        %% Drag and resize callbacks

        function onDragStart(obj, widgetIdx)
            obj.DragMode = 'drag';
            obj.DragIdx = widgetIdx;
            w = obj.Engine.Widgets{widgetIdx};
            obj.DragOrigGrid = w.Position;
            obj.DragOrigNorm = get(w.hPanel, 'Position');

            obj.DragStart = obj.getMousePosition();
            obj.selectWidget(widgetIdx);
        end

        function onResizeStart(obj, widgetIdx)
            obj.DragMode = 'resize';
            obj.DragIdx = widgetIdx;
            w = obj.Engine.Widgets{widgetIdx};
            obj.DragOrigGrid = w.Position;
            obj.DragOrigNorm = get(w.hPanel, 'Position');

            obj.DragStart = obj.getMousePosition();
            obj.selectWidget(widgetIdx);
        end

        function onMouseMove(obj)
            if isempty(obj.DragMode) || obj.DragIdx == 0
                return;
            end

            cp = obj.getMousePosition();
            dx = cp(1) - obj.DragStart(1);
            dy = cp(2) - obj.DragStart(2);

            origNorm = obj.DragOrigNorm;
            w = obj.Engine.Widgets{obj.DragIdx};
            ov = obj.Overlays{obj.DragIdx};
            handleH = 0.022;
            rsW = 0.012; rsH = 0.012;

            switch obj.DragMode
                case 'drag'
                    newX = origNorm(1) + dx;
                    newY = origNorm(2) + dy;
                    set(w.hPanel, 'Position', ...
                        [newX, newY, origNorm(3), origNorm(4)]);
                    set(ov.hDragBar, 'Position', ...
                        [newX, newY + origNorm(4) - handleH, ...
                         origNorm(3), handleH]);
                    set(ov.hResize, 'Position', ...
                        [newX + origNorm(3) - rsW, newY, rsW, rsH]);

                case 'resize'
                    newW = max(origNorm(3) + dx, 0.04);
                    newH = max(origNorm(4) - dy, 0.04);
                    newY = origNorm(2) + dy;
                    set(w.hPanel, 'Position', ...
                        [origNorm(1), newY, newW, newH]);
                    set(ov.hDragBar, 'Position', ...
                        [origNorm(1), newY + newH - handleH, ...
                         newW, handleH]);
                    set(ov.hResize, 'Position', ...
                        [origNorm(1) + newW - rsW, newY, rsW, rsH]);
            end
        end

        function onMouseUp(obj)
            if isempty(obj.DragMode) || obj.DragIdx == 0
                return;
            end

            cp = obj.getMousePosition();
            dx = cp(1) - obj.DragStart(1);
            dy = cp(2) - obj.DragStart(2);

            % Compute grid cell size from current layout
            layout = obj.Engine.Layout;
            ca = layout.ContentArea;
            totalW = ca(3) - layout.Padding(1) - layout.Padding(3);
            totalH = ca(4) - layout.Padding(2) - layout.Padding(4);
            cols = layout.Columns;
            rows = max(layout.TotalRows, 1);
            cellW = (totalW - (cols - 1) * layout.GapH) / cols;
            cellH = (totalH - (rows - 1) * layout.GapV) / rows;
            stepW = cellW + layout.GapH;
            stepH = cellH + layout.GapV;

            origGrid = obj.DragOrigGrid;

            switch obj.DragMode
                case 'drag'
                    deltaCol = round(dx / stepW);
                    deltaRow = round(-dy / stepH);
                    newCol = max(1, origGrid(1) + deltaCol);
                    newRow = max(1, origGrid(2) + deltaRow);
                    newCol = min(newCol, 13 - origGrid(3));
                    newGrid = [newCol, newRow, origGrid(3), origGrid(4)];

                case 'resize'
                    deltaW = round(dx / stepW);
                    deltaH = round(-dy / stepH);
                    newW = max(1, origGrid(3) + deltaW);
                    newH = max(1, origGrid(4) + deltaH);
                    newW = min(newW, 13 - origGrid(1));
                    newGrid = [origGrid(1), origGrid(2), newW, newH];
            end

            % Resolve overlaps with other widgets
            existingPositions = {};
            for i = 1:numel(obj.Engine.Widgets)
                if i ~= obj.DragIdx
                    existingPositions{end+1} = obj.Engine.Widgets{i}.Position;
                end
            end
            newGrid = obj.Engine.Layout.resolveOverlap(newGrid, existingPositions);
            obj.Engine.setWidgetPosition(obj.DragIdx, newGrid);

            % Snap to grid by re-laying out
            theme = DashboardTheme(obj.Engine.Theme);
            obj.relayoutWidgets(theme);
            obj.clearOverlays();
            obj.createOverlays(theme);

            obj.DragMode = '';
            obj.DragIdx = 0;

            if obj.SelectedIdx > 0
                obj.updatePropertiesDisplay();
            end
        end

        function updatePropertiesDisplay(obj)
            idx = obj.SelectedIdx;
            if idx == 0 || idx > numel(obj.Engine.Widgets)
                set(obj.hPropLabel, 'String', 'Select a widget to edit');
                obj.showProps('off');
                return;
            end

            w = obj.Engine.Widgets{idx};
            set(obj.hPropLabel, 'String', ...
                sprintf('[%s] %s', w.Type, w.Title));
            set(obj.hPropTitle, 'String', w.Title);
            set(obj.hPropCol, 'String', num2str(w.Position(1)));
            set(obj.hPropRow, 'String', num2str(w.Position(2)));
            set(obj.hPropWidth, 'String', num2str(w.Position(3)));
            set(obj.hPropHeight, 'String', num2str(w.Position(4)));
            obj.showProps('on');
        end

        function showProps(obj, vis)
            set(obj.hPropTitle, 'Visible', vis);
            set(obj.hPropCol, 'Visible', vis);
            set(obj.hPropRow, 'Visible', vis);
            set(obj.hPropWidth, 'Visible', vis);
            set(obj.hPropHeight, 'Visible', vis);
            set(obj.hPropApply, 'Visible', vis);
            set(obj.hPropDelete, 'Visible', vis);

            % Show/hide property labels
            labels = findobj(obj.hPropsPanel, 'Tag', 'propLabel');
            set(labels, 'Visible', vis);
        end

        function t = defaultTitleForType(~, type)
            switch type
                case 'fastplot', t = 'New Plot';
                case 'kpi',      t = 'New KPI';
                case 'status',   t = 'New Status';
                case 'text',     t = 'New Text';
                case 'gauge',    t = 'New Gauge';
                case 'table',    t = 'New Table';
                case 'rawaxes',  t = 'New Axes';
                case 'timeline', t = 'New Timeline';
                otherwise,       t = 'New Widget';
            end
        end

    end
end

function safeDelete(h)
    if ~isempty(h) && ishandle(h)
        delete(h);
    end
end
