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

        % Grid overlay axes (edit mode)
        hGridOverlay    = []

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

        % Data source controls
        hSourceType     = []
        hSourceKey      = []
        hSourceBrowse   = []
        hSourceLabel    = []

        % Saved figure callbacks (restored on exit edit)
        OldMotionFcn    = ''
        OldButtonUpFcn  = ''

        % Layout constants (normalized figure coords)
        PaletteWidth    = 0.12
        PropsWidth      = 0.18
    end

    methods (Access = public)
        function obj = DashboardBuilder(engine)
            obj.Engine = engine;
        end

        function enterEditMode(obj)
            if obj.IsActive, return; end
            obj.IsActive = true;
            obj.SelectedIdx = 0;

            eng = obj.Engine;
            eng.stopLive();

            hFig = eng.hFigure;
            theme = DashboardTheme(eng.Theme);

            % Save existing callbacks (e.g. NavigatorOverlay) and install ours
            obj.OldMotionFcn = get(hFig, 'WindowButtonMotionFcn');
            obj.OldButtonUpFcn = get(hFig, 'WindowButtonUpFcn');
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

            hFig = obj.Engine.hFigure;
            set(hFig, 'WindowButtonMotionFcn', obj.OldMotionFcn);
            set(hFig, 'WindowButtonUpFcn', obj.OldButtonUpFcn);
            obj.OldMotionFcn = '';
            obj.OldButtonUpFcn = '';

            obj.clearOverlays();
            obj.clearGrid();

            % Delete sidebars
            safeDelete(obj.hPalette);
            obj.hPalette = [];
            safeDelete(obj.hPropsPanel);
            obj.hPropsPanel = [];

            % Restore full content area and re-render
            theme = DashboardTheme(obj.Engine.Theme);
            obj.Engine.Layout.ContentArea = obj.Engine.Toolbar.getContentArea();
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
            eng.addWidget(type, 'Title', type, 'Position', pos);

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
                obj.updatePropertiesDisplay();
            elseif obj.SelectedIdx > idx
                obj.SelectedIdx = obj.SelectedIdx - 1;
            end

            theme = DashboardTheme(eng.Theme);
            obj.relayoutWidgets(theme);
            obj.clearOverlays();
            obj.createOverlays(theme);
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

            % Apply data source
            obj.applyDataSource();

            theme = DashboardTheme(obj.Engine.Theme);
            obj.relayoutWidgets(theme);
            obj.clearOverlays();
            obj.createOverlays(theme);
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

            % --- Data Source section ---
            y = y - lh - gap*2;
            obj.hSourceLabel = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'text', 'Units', 'normalized', ...
                'Position', [0.05 y 0.9 lh], ...
                'String', 'Data Source:', 'ForegroundColor', fg, ...
                'BackgroundColor', bg, 'HorizontalAlignment', 'left', ...
                'FontWeight', 'bold', ...
                'Visible', 'off', 'Tag', 'propLabel');
            y = y - fh - gap;

            % Source type dropdown
            obj.hSourceType = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'popupmenu', 'Units', 'normalized', ...
                'Position', [0.05 y 0.9 fh], ...
                'String', {'None', 'Sensor', 'MAT File', 'Static Value'}, ...
                'Value', 1, 'Visible', 'off');
            y = y - fh - gap;

            % Source key / path / value field
            obj.hSourceKey = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.05 y 0.65 fh], ...
                'String', '', 'Visible', 'off');

            % Browse button (for MAT files)
            obj.hSourceBrowse = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'pushbutton', 'Units', 'normalized', ...
                'Position', [0.72 y 0.23 fh], ...
                'String', 'Browse', 'Visible', 'off', ...
                'Callback', @(~,~) obj.onSourceBrowse());
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
            timePanelH = obj.Engine.TimePanelHeight;
            if obj.IsActive
                contentArea = [obj.PaletteWidth, timePanelH, ...
                    1 - obj.PaletteWidth - obj.PropsWidth, ...
                    1 - toolbarH - timePanelH];
            else
                contentArea = [0, timePanelH, 1, 1 - toolbarH - timePanelH];
            end
            obj.Engine.Layout.ContentArea = contentArea;

            % Re-create viewport, canvas, and widget panels
            obj.Engine.Layout.createPanels(obj.Engine.hFigure, widgets, theme);

            % Draw grid overlay in edit mode (on new canvas, after panels)
            if obj.IsActive
                obj.drawGrid(theme);
            end
        end

        function createOverlays(obj, theme)
            obj.clearOverlays();
            widgets = obj.Engine.Widgets;
            hCanvas = obj.Engine.Layout.hCanvas;

            for i = 1:numel(widgets)
                w = widgets{i};
                if isempty(w.hPanel) || ~ishandle(w.hPanel)
                    continue;
                end

                panelPos = get(w.hPanel, 'Position');
                ov = struct();
                idx = i;

                % Drag handle bar at top of widget panel
                handleH = 0.022;
                ov.hDragBar = uipanel('Parent', hCanvas, ...
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
                ov.hResize = uicontrol('Parent', hCanvas, ...
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

                obj.Overlays{end+1} = ov;
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

    end

    methods (Access = public)
        %% Drag and resize callbacks

        function onDragStart(obj, widgetIdx)
            obj.DragMode = 'drag';
            obj.DragIdx = widgetIdx;
            w = obj.Engine.Widgets{widgetIdx};
            obj.DragOrigGrid = w.Position;
            obj.DragOrigNorm = get(w.hPanel, 'Position');

            hFig = obj.Engine.hFigure;
            obj.DragStart = get(hFig, 'CurrentPoint');
            obj.selectWidget(widgetIdx);
        end

        function onResizeStart(obj, widgetIdx)
            obj.DragMode = 'resize';
            obj.DragIdx = widgetIdx;
            w = obj.Engine.Widgets{widgetIdx};
            obj.DragOrigGrid = w.Position;
            obj.DragOrigNorm = get(w.hPanel, 'Position');

            hFig = obj.Engine.hFigure;
            obj.DragStart = get(hFig, 'CurrentPoint');
            obj.selectWidget(widgetIdx);
        end

        function onMouseMove(obj)
            if isempty(obj.DragMode) || obj.DragIdx == 0
                return;
            end

            hFig = obj.Engine.hFigure;
            cp = get(hFig, 'CurrentPoint');
            dx_fig = cp(1) - obj.DragStart(1);
            dy_fig = cp(2) - obj.DragStart(2);

            % Convert figure deltas to canvas deltas
            layout = obj.Engine.Layout;
            [dx, dy] = layout.figureToCanvasDelta(dx_fig, dy_fig);
            [stepW, stepH] = layout.canvasStepSizes();

            origGrid = obj.DragOrigGrid;
            w = obj.Engine.Widgets{obj.DragIdx};
            ov = obj.Overlays{obj.DragIdx};
            handleH = 0.022;
            rsW = 0.012; rsH = 0.012;

            switch obj.DragMode
                case 'drag'
                    deltaCol = round(dx / stepW);
                    deltaRow = round(-dy / stepH);
                    newCol = max(1, min(origGrid(1) + deltaCol, ...
                        13 - origGrid(3)));
                    newRow = max(1, origGrid(2) + deltaRow);
                    newGrid = [newCol, newRow, origGrid(3), origGrid(4)];

                case 'resize'
                    deltaW = round(dx / stepW);
                    deltaH = round(-dy / stepH);
                    newW = max(1, min(origGrid(3) + deltaW, ...
                        13 - origGrid(1)));
                    newH = max(1, origGrid(4) + deltaH);
                    newGrid = [origGrid(1), origGrid(2), newW, newH];
            end

            % Snap to exact grid position via computePosition
            savedRows = layout.TotalRows;
            maxNeeded = newGrid(2) + newGrid(4) - 1;
            if maxNeeded > layout.TotalRows
                layout.TotalRows = maxNeeded;
            end
            pos = layout.computePosition(newGrid);
            layout.TotalRows = savedRows;

            set(w.hPanel, 'Position', pos);
            set(ov.hDragBar, 'Position', ...
                [pos(1), pos(2) + pos(4) - handleH, pos(3), handleH]);
            set(ov.hResize, 'Position', ...
                [pos(1) + pos(3) - rsW, pos(2), rsW, rsH]);
        end

        function onMouseUp(obj)
            if isempty(obj.DragMode) || obj.DragIdx == 0
                return;
            end

            hFig = obj.Engine.hFigure;
            cp = get(hFig, 'CurrentPoint');
            dx_fig = cp(1) - obj.DragStart(1);
            dy_fig = cp(2) - obj.DragStart(2);

            % Convert figure deltas to canvas deltas
            layout = obj.Engine.Layout;
            [dx, dy] = layout.figureToCanvasDelta(dx_fig, dy_fig);
            [stepW, stepH] = layout.canvasStepSizes();

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

            obj.Engine.Widgets{obj.DragIdx}.Position = newGrid;

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
    end

    methods (Access = private)
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

            % Populate data source controls
            obj.populateSourceControls(w);

            obj.showProps('on');
        end

        function drawGrid(obj, theme)
            obj.clearGrid();

            layout = obj.Engine.Layout;
            hCanvas = layout.hCanvas;
            if isempty(hCanvas) || ~ishandle(hCanvas)
                return;
            end

            [stepW, stepH, cellW, cellH] = layout.canvasStepSizes();

            padL = layout.Padding(1);
            padB = layout.Padding(2);
            cols = layout.Columns;
            rows = max(layout.TotalRows, 1);

            cr = layout.canvasRatio();
            if cr <= 1
                yBase = padB;
            else
                yBase = padB / cr;
            end

            xLeft  = padL;
            yBot   = yBase;
            xRight = xLeft + (cols - 1) * stepW + cellW;
            yTop   = yBot  + (rows - 1) * stepH + cellH;

            % Transparent axes on canvas for grid lines
            hAx = axes('Parent', hCanvas, ...
                'Units', 'normalized', ...
                'Position', [0 0 1 1], ...
                'XLim', [0 1], 'YLim', [0 1], ...
                'Color', 'none', ...
                'Visible', 'off', ...
                'HitTest', 'off');
            try set(hAx, 'PickableParts', 'none'); catch, end
            hold(hAx, 'on');

            gc = theme.GridLineColor;

            % Vertical lines (column boundaries)
            for c = 1:(cols + 1)
                if c <= cols
                    x = xLeft + (c - 1) * stepW;
                else
                    x = xRight;
                end
                hL = line(hAx, [x x], [yBot yTop], 'Color', gc, ...
                    'LineStyle', ':', 'LineWidth', 0.5, ...
                    'HitTest', 'off');
                try set(hL, 'PickableParts', 'none'); catch, end
            end

            % Horizontal lines (row boundaries)
            for r = 1:(rows + 1)
                if r <= rows
                    y = yBot + (r - 1) * stepH;
                else
                    y = yTop;
                end
                hL = line(hAx, [xLeft xRight], [y y], 'Color', gc, ...
                    'LineStyle', ':', 'LineWidth', 0.5, ...
                    'HitTest', 'off');
                try set(hL, 'PickableParts', 'none'); catch, end
            end

            hold(hAx, 'off');
            obj.hGridOverlay = hAx;
        end

        function clearGrid(obj)
            if ~isempty(obj.hGridOverlay) && ishandle(obj.hGridOverlay)
                delete(obj.hGridOverlay);
            end
            obj.hGridOverlay = [];
        end

        function showProps(obj, vis)
            set(obj.hPropTitle, 'Visible', vis);
            set(obj.hPropCol, 'Visible', vis);
            set(obj.hPropRow, 'Visible', vis);
            set(obj.hPropWidth, 'Visible', vis);
            set(obj.hPropHeight, 'Visible', vis);
            set(obj.hPropApply, 'Visible', vis);
            set(obj.hPropDelete, 'Visible', vis);
            set(obj.hSourceType, 'Visible', vis);
            set(obj.hSourceKey, 'Visible', vis);
            set(obj.hSourceBrowse, 'Visible', vis);

            % Show/hide property labels
            labels = findobj(obj.hPropsPanel, 'Tag', 'propLabel');
            set(labels, 'Visible', vis);
        end

        function populateSourceControls(obj, w)
            switch w.Type
                case 'fastplot'
                    if ~isempty(w.SensorObj)
                        set(obj.hSourceType, 'Value', 2);  % Sensor
                        set(obj.hSourceKey, 'String', w.SensorObj.Key);
                    elseif ~isempty(w.File)
                        set(obj.hSourceType, 'Value', 3);  % MAT File
                        set(obj.hSourceKey, 'String', w.File);
                    else
                        set(obj.hSourceType, 'Value', 1);  % None
                        set(obj.hSourceKey, 'String', '');
                    end
                case {'kpi', 'gauge'}
                    if ~isempty(w.StaticValue)
                        set(obj.hSourceType, 'Value', 4);  % Static
                        set(obj.hSourceKey, 'String', num2str(w.StaticValue));
                    else
                        set(obj.hSourceType, 'Value', 1);
                        set(obj.hSourceKey, 'String', '');
                    end
                otherwise
                    set(obj.hSourceType, 'Value', 1);
                    set(obj.hSourceKey, 'String', '');
            end
        end

        function applyDataSource(obj)
            if obj.SelectedIdx == 0, return; end
            w = obj.Engine.Widgets{obj.SelectedIdx};
            srcType = get(obj.hSourceType, 'Value');
            srcKey = strtrim(get(obj.hSourceKey, 'String'));

            switch srcType
                case 2  % Sensor
                    if ~isempty(srcKey)
                        try
                            sensor = SensorRegistry.get(srcKey);
                            if isprop(w, 'SensorObj')
                                w.SensorObj = sensor;
                            end
                        catch ME
                            warning('DashboardBuilder:sensorNotFound', ...
                                'Sensor "%s" not found: %s', srcKey, ME.message);
                        end
                    end
                case 3  % MAT File
                    if ~isempty(srcKey) && isprop(w, 'File')
                        w.File = srcKey;
                        % Auto-detect variable names if not set
                        if isempty(w.XVar) || isempty(w.YVar)
                            try
                                info = whos('-file', srcKey);
                                names = {info.name};
                                if numel(names) >= 2
                                    w.XVar = names{1};
                                    w.YVar = names{2};
                                end
                            catch
                            end
                        end
                    end
                case 4  % Static Value
                    val = str2double(srcKey);
                    if ~isnan(val) && isprop(w, 'StaticValue')
                        w.StaticValue = val;
                    end
            end

            % Re-render to apply data binding
            theme = DashboardTheme(obj.Engine.Theme);
            obj.relayoutWidgets(theme);
            obj.clearOverlays();
            obj.createOverlays(theme);

            % Update global time range
            obj.Engine.updateGlobalTimeRange();
        end

        function onSourceBrowse(obj)
            [file, path] = uigetfile('*.mat', 'Select MAT file');
            if file ~= 0
                set(obj.hSourceKey, 'String', fullfile(path, file));
                set(obj.hSourceType, 'Value', 3);  % MAT File
            end
        end

    end
end

function safeDelete(h)
    if ~isempty(h) && ishandle(h)
        delete(h);
    end
end
