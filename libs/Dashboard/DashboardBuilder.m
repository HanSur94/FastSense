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

        % Cached layout values for drag (avoid recalc every mouse move)
        CachedStepW     = 0
        CachedStepH     = 0

        % Lightweight ghost rectangle for drag preview
        hGhost          = []

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

        % Axis label controls (fastsense only)
        hPropXLabel     = []
        hPropYLabel     = []

        % Data source controls
        hSourceType     = []
        hSourceKey      = []
        hSourceBrowse   = []
        hSourceLabel    = []

        % Saved figure callbacks (restored on exit edit)
        OldMotionFcn    = ''
        OldButtonUpFcn  = ''

        % Layout constants (normalized figure coords)
        PaletteWidth    = 0.08
        PropsWidth      = 0.14
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
            obj.destroyGhost();

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

            % Apply axis labels if widget supports them
            if isprop(w, 'XLabel')
                w.XLabel = get(obj.hPropXLabel, 'String');
                w.YLabel = get(obj.hPropYLabel, 'String');
            end

            col = str2double(get(obj.hPropCol, 'String'));
            row = str2double(get(obj.hPropRow, 'String'));
            wid = str2double(get(obj.hPropWidth, 'String'));
            hgt = str2double(get(obj.hPropHeight, 'String'));

            if ~isnan(col) && ~isnan(row) && ~isnan(wid) && ~isnan(hgt)
                col = max(1, min(col, 24));
                row = max(1, row);
                wid = max(1, min(wid, 25 - col));
                hgt = max(1, hgt);
                w.Position = [col, row, wid, hgt];
            end

            % Apply data source
            obj.applyDataSource();

            theme = DashboardTheme(obj.Engine.Theme);
            obj.relayoutWidgets(theme);
            obj.clearOverlays();
            obj.createOverlays(theme);
            obj.selectWidget(obj.SelectedIdx);
        end

        function pos = findNextSlot(obj, type)
            switch type
                case 'fastsense', defW = 12; defH = 3;
                case 'number',   defW = 6; defH = 1;
                case 'status',   defW = 4; defH = 1;
                case 'text',     defW = 6; defH = 1;
                case 'gauge',    defW = 8; defH = 2;
                case 'table',    defW = 8; defH = 2;
                case 'rawaxes',  defW = 8; defH = 2;
                case 'timeline', defW = 24; defH = 2;
                case 'iconcard', defW = 6; defH = 2;
                case 'chipbar',  defW = 12; defH = 1;
                case 'sparkline', defW = 6; defH = 3;
                otherwise,       defW = 8; defH = 2;
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
                'Position', [0.05 0.94 0.9 0.04], ...
                'String', 'Add', ...
                'FontSize', 9, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'center');

            types  = {'fastsense','number','status','text', ...
                      'gauge','table','rawaxes','timeline', ...
                      'iconcard','chipbar','sparkline'};
            labels = {'Plot','Number','Status','Text', ...
                      'Gauge','Table','Axes','Events', ...
                      'Icon Card','Chip Bar','Sparkline'};

            btnH = 0.04;
            btnGap = 0.006;
            startY = 0.93 - btnH;

            for i = 1:numel(types)
                y = startY - (i-1) * (btnH + btnGap);
                t = types{i};
                uicontrol('Parent', obj.hPalette, ...
                    'Style', 'pushbutton', ...
                    'Units', 'normalized', ...
                    'Position', [0.06 y 0.88 btnH], ...
                    'String', labels{i}, ...
                    'FontSize', 8, ...
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
                'Position', [0.04 0.95 0.92 0.04], ...
                'String', 'Properties', ...
                'FontSize', 9, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left');

            obj.hPropLabel = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.04 0.90 0.92 0.04], ...
                'String', 'Select a widget', ...
                'FontSize', 8, ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left');

            lh = 0.025;  % label height
            fh = 0.035;  % field height
            gap = 0.004;
            bg = theme.ToolbarBackground;
            fg = theme.ToolbarFontColor;
            fs = 8;  % font size for labels

            y = 0.85;

            % Title field
            uicontrol('Parent', obj.hPropsPanel, 'Style', 'text', ...
                'Units', 'normalized', 'Position', [0.04 y 0.92 lh], ...
                'String', 'Title:', 'FontSize', fs, ...
                'ForegroundColor', fg, 'BackgroundColor', bg, ...
                'HorizontalAlignment', 'left', ...
                'Visible', 'off', 'Tag', 'propLabel');
            y = y - fh - gap;
            obj.hPropTitle = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.04 y 0.92 fh], 'FontSize', fs, ...
                'String', '', 'Visible', 'off');
            y = y - lh - gap*2;

            % Col / Row
            uicontrol('Parent', obj.hPropsPanel, 'Style', 'text', ...
                'Units', 'normalized', 'Position', [0.04 y 0.44 lh], ...
                'String', 'Col:', 'FontSize', fs, ...
                'ForegroundColor', fg, 'BackgroundColor', bg, ...
                'HorizontalAlignment', 'left', ...
                'Visible', 'off', 'Tag', 'propLabel');
            uicontrol('Parent', obj.hPropsPanel, 'Style', 'text', ...
                'Units', 'normalized', 'Position', [0.5 y 0.44 lh], ...
                'String', 'Row:', 'FontSize', fs, ...
                'ForegroundColor', fg, 'BackgroundColor', bg, ...
                'HorizontalAlignment', 'left', ...
                'Visible', 'off', 'Tag', 'propLabel');
            y = y - fh - gap;
            obj.hPropCol = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.04 y 0.44 fh], 'FontSize', fs, ...
                'String', '', 'Visible', 'off');
            obj.hPropRow = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.5 y 0.44 fh], 'FontSize', fs, ...
                'String', '', 'Visible', 'off');
            y = y - lh - gap*2;

            % Width / Height
            uicontrol('Parent', obj.hPropsPanel, 'Style', 'text', ...
                'Units', 'normalized', 'Position', [0.04 y 0.44 lh], ...
                'String', 'W:', 'FontSize', fs, ...
                'ForegroundColor', fg, 'BackgroundColor', bg, ...
                'HorizontalAlignment', 'left', ...
                'Visible', 'off', 'Tag', 'propLabel');
            uicontrol('Parent', obj.hPropsPanel, 'Style', 'text', ...
                'Units', 'normalized', 'Position', [0.5 y 0.44 lh], ...
                'String', 'H:', 'FontSize', fs, ...
                'ForegroundColor', fg, 'BackgroundColor', bg, ...
                'HorizontalAlignment', 'left', ...
                'Visible', 'off', 'Tag', 'propLabel');
            y = y - fh - gap;
            obj.hPropWidth = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.04 y 0.44 fh], 'FontSize', fs, ...
                'String', '', 'Visible', 'off');
            obj.hPropHeight = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.5 y 0.44 fh], 'FontSize', fs, ...
                'String', '', 'Visible', 'off');
            y = y - fh - gap*2;

            % --- Axis Labels (shown for fastsense) ---
            uicontrol('Parent', obj.hPropsPanel, 'Style', 'text', ...
                'Units', 'normalized', 'Position', [0.04 y 0.44 lh], ...
                'String', 'X:', 'FontSize', fs, ...
                'ForegroundColor', fg, 'BackgroundColor', bg, ...
                'HorizontalAlignment', 'left', ...
                'Visible', 'off', 'Tag', 'propLabel');
            uicontrol('Parent', obj.hPropsPanel, 'Style', 'text', ...
                'Units', 'normalized', 'Position', [0.5 y 0.44 lh], ...
                'String', 'Y:', 'FontSize', fs, ...
                'ForegroundColor', fg, 'BackgroundColor', bg, ...
                'HorizontalAlignment', 'left', ...
                'Visible', 'off', 'Tag', 'propLabel');
            y = y - fh - gap;
            obj.hPropXLabel = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.04 y 0.44 fh], 'FontSize', fs, ...
                'String', '', 'Visible', 'off');
            obj.hPropYLabel = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.5 y 0.44 fh], 'FontSize', fs, ...
                'String', '', 'Visible', 'off');
            y = y - fh - gap*2;

            % --- Data Source section ---
            obj.hSourceLabel = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'text', 'Units', 'normalized', ...
                'Position', [0.04 y 0.92 lh], ...
                'String', 'Source:', 'FontSize', fs, ...
                'ForegroundColor', fg, 'BackgroundColor', bg, ...
                'HorizontalAlignment', 'left', 'FontWeight', 'bold', ...
                'Visible', 'off', 'Tag', 'propLabel');
            y = y - fh - gap;

            % Source type dropdown
            obj.hSourceType = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'popupmenu', 'Units', 'normalized', ...
                'Position', [0.04 y 0.92 fh], 'FontSize', fs, ...
                'String', {'None', 'Sensor', 'MAT File', 'Static'}, ...
                'Value', 1, 'Visible', 'off');
            y = y - fh - gap;

            % Source key / path / value field
            obj.hSourceKey = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.04 y 0.6 fh], 'FontSize', fs, ...
                'String', '', 'Visible', 'off');

            % Browse button (for MAT files)
            obj.hSourceBrowse = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'pushbutton', 'Units', 'normalized', ...
                'Position', [0.66 y 0.3 fh], 'FontSize', 7, ...
                'String', '...', 'Visible', 'off', ...
                'Callback', @(~,~) obj.onSourceBrowse());
            y = y - fh - gap*3;

            % Apply / Delete buttons
            obj.hPropApply = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'pushbutton', 'Units', 'normalized', ...
                'Position', [0.04 y 0.44 fh], 'FontSize', fs, ...
                'String', 'Apply', 'Visible', 'off', ...
                'Callback', @(~,~) obj.applyProperties());

            obj.hPropDelete = uicontrol('Parent', obj.hPropsPanel, ...
                'Style', 'pushbutton', 'Units', 'normalized', ...
                'Position', [0.52 y 0.44 fh], 'FontSize', fs, ...
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
            obj.Engine.setContentArea(contentArea);

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

    end

    methods (Access = public)
        %% Drag and resize callbacks

        function onDragStart(obj, widgetIdx)
            obj.DragMode = 'drag';
            obj.DragIdx = widgetIdx;
            w = obj.Engine.Widgets{widgetIdx};
            obj.DragOrigGrid = w.Position;
            obj.DragOrigNorm = get(w.hPanel, 'Position');

            % Cache step sizes to avoid recalc on every mouse move
            [obj.CachedStepW, obj.CachedStepH] = ...
                obj.Engine.Layout.canvasStepSizes();

            hFig = obj.Engine.hFigure;
            obj.DragStart = get(hFig, 'CurrentPoint');
            obj.selectWidget(widgetIdx);

            % Create lightweight ghost rectangle instead of moving heavy panel
            obj.createGhost(obj.DragOrigNorm);
        end

        function onResizeStart(obj, widgetIdx)
            obj.DragMode = 'resize';
            obj.DragIdx = widgetIdx;
            w = obj.Engine.Widgets{widgetIdx};
            obj.DragOrigGrid = w.Position;
            obj.DragOrigNorm = get(w.hPanel, 'Position');

            [obj.CachedStepW, obj.CachedStepH] = ...
                obj.Engine.Layout.canvasStepSizes();

            hFig = obj.Engine.hFigure;
            obj.DragStart = get(hFig, 'CurrentPoint');
            obj.selectWidget(widgetIdx);

            obj.createGhost(obj.DragOrigNorm);
        end

        function onMouseMove(obj)
            if isempty(obj.DragMode) || obj.DragIdx == 0
                return;
            end

            newGrid = obj.computeSnappedGrid();

            % Snap ghost to grid position (lightweight — no widget rerender)
            layout = obj.Engine.Layout;
            savedRows = layout.TotalRows;
            maxNeeded = newGrid(2) + newGrid(4) - 1;
            if maxNeeded > layout.TotalRows
                layout.TotalRows = maxNeeded;
            end
            pos = layout.computePosition(newGrid);
            layout.TotalRows = savedRows;

            % Move only the ghost outline (not the heavy widget panel)
            if ~isempty(obj.hGhost) && ishandle(obj.hGhost)
                set(obj.hGhost, 'Position', pos);
            end
        end

        function onMouseUp(obj)
            if isempty(obj.DragMode) || obj.DragIdx == 0
                obj.destroyGhost();
                return;
            end

            newGrid = obj.computeSnappedGrid();
            obj.destroyGhost();

            widgetIdx = obj.DragIdx;
            obj.DragMode = '';
            obj.DragIdx = 0;

            layout = obj.Engine.Layout;
            w = obj.Engine.Widgets{widgetIdx};
            oldGrid = w.Position;
            w.Position = newGrid;

            % Check if total rows changed (need full relayout for scroll)
            oldMaxRow = layout.TotalRows;
            newMaxRow = layout.calculateMaxRow(obj.Engine.Widgets);
            rowsChanged = newMaxRow ~= oldMaxRow;

            if rowsChanged
                % Full relayout only when grid dimensions actually changed
                theme = DashboardTheme(obj.Engine.Theme);
                obj.relayoutWidgets(theme);
                obj.clearOverlays();
                obj.createOverlays(theme);
            else
                % Fast path: just reposition the panel and overlays in-place
                pos = layout.computePosition(newGrid);
                set(w.hPanel, 'Position', pos);

                handleH = 0.022;
                rsW = 0.012; rsH = 0.012;
                ov = obj.Overlays{widgetIdx};
                if ishandle(ov.hDragBar)
                    set(ov.hDragBar, 'Position', ...
                        [pos(1), pos(2)+pos(4)-handleH, pos(3), handleH]);
                end
                if ishandle(ov.hResize)
                    set(ov.hResize, 'Position', ...
                        [pos(1)+pos(3)-rsW, pos(2), rsW, rsH]);
                end
            end

            if obj.SelectedIdx > 0
                obj.updatePropertiesDisplay();
            end
        end
    end

    methods (Access = private)
        function newGrid = computeSnappedGrid(obj)
        %COMPUTESNAPPEDGRID Shared snap-to-grid logic for drag and resize.
            hFig = obj.Engine.hFigure;
            cp = get(hFig, 'CurrentPoint');
            dx_fig = cp(1) - obj.DragStart(1);
            dy_fig = cp(2) - obj.DragStart(2);

            layout = obj.Engine.Layout;
            [dx, dy] = layout.figureToCanvasDelta(dx_fig, dy_fig);
            stepW = obj.CachedStepW;
            stepH = obj.CachedStepH;
            origGrid = obj.DragOrigGrid;
            nCols = layout.Columns;

            switch obj.DragMode
                case 'drag'
                    deltaCol = round(dx / stepW);
                    deltaRow = round(-dy / stepH);
                    newCol = max(1, min(origGrid(1) + deltaCol, ...
                        nCols + 1 - origGrid(3)));
                    newRow = max(1, origGrid(2) + deltaRow);
                    newGrid = [newCol, newRow, origGrid(3), origGrid(4)];

                case 'resize'
                    deltaW = round(dx / stepW);
                    deltaH = round(-dy / stepH);
                    newW = max(1, min(origGrid(3) + deltaW, ...
                        nCols + 1 - origGrid(1)));
                    newH = max(1, origGrid(4) + deltaH);
                    newGrid = [origGrid(1), origGrid(2), newW, newH];

                otherwise
                    newGrid = origGrid;
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

            % Populate axis label fields (fastsense only)
            if isprop(w, 'XLabel')
                set(obj.hPropXLabel, 'String', w.XLabel, 'Enable', 'on');
                set(obj.hPropYLabel, 'String', w.YLabel, 'Enable', 'on');
            else
                set(obj.hPropXLabel, 'String', '', 'Enable', 'off');
                set(obj.hPropYLabel, 'String', '', 'Enable', 'off');
            end

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

            % Use computePosition to get grid bounds (consistent with widget placement)
            topLeftPos = layout.computePosition([1, 1, 1, 1]);
            botRightPos = layout.computePosition([cols, rows, 1, 1]);

            xLeft  = padL;
            xRight = xLeft + (cols - 1) * stepW + cellW;
            yBot   = botRightPos(2);
            yTop   = topLeftPos(2) + topLeftPos(4);

            % Transparent axes on canvas for grid lines
            hAx = axes('Parent', hCanvas, ...
                'Units', 'normalized', ...
                'Position', [0 0 1 1], ...
                'XLim', [0 1], 'YLim', [0 1], ...
                'Color', 'none', ...
                'Visible', 'off', ...
                'HitTest', 'off');
            try set(hAx, 'PickableParts', 'none'); catch , end
            hold(hAx, 'on');

            gc = theme.GridLineColor;

            % Build all vertical lines as a single NaN-separated line
            nV = cols + 1;
            xV = zeros(1, nV * 3); yV = zeros(1, nV * 3);
            for c = 1:nV
                if c <= cols
                    x = xLeft + (c - 1) * stepW;
                else
                    x = xRight;
                end
                k = (c-1)*3;
                xV(k+1) = x; yV(k+1) = yBot;
                xV(k+2) = x; yV(k+2) = yTop;
                xV(k+3) = NaN; yV(k+3) = NaN;
            end
            hL = line(hAx, xV, yV, 'Color', gc, ...
                'LineStyle', ':', 'LineWidth', 0.5, 'HitTest', 'off');
            try set(hL, 'PickableParts', 'none'); catch , end

            % Build all horizontal lines as a single NaN-separated line
            nH = rows + 1;
            xH = zeros(1, nH * 3); yH = zeros(1, nH * 3);
            for r = 1:nH
                if r <= rows
                    y = yBot + (r - 1) * stepH;
                else
                    y = yTop;
                end
                k = (r-1)*3;
                xH(k+1) = xLeft;  yH(k+1) = y;
                xH(k+2) = xRight; yH(k+2) = y;
                xH(k+3) = NaN;    yH(k+3) = NaN;
            end
            hL = line(hAx, xH, yH, 'Color', gc, ...
                'LineStyle', ':', 'LineWidth', 0.5, 'HitTest', 'off');
            try set(hL, 'PickableParts', 'none'); catch , end

            hold(hAx, 'off');
            obj.hGridOverlay = hAx;
        end

        function createGhost(obj, pos)
        %CREATEGHOST Lightweight semi-transparent rectangle for drag preview.
            obj.destroyGhost();
            hCanvas = obj.Engine.Layout.hCanvas;
            if isempty(hCanvas) || ~ishandle(hCanvas), return; end

            obj.hGhost = uipanel('Parent', hCanvas, ...
                'Units', 'normalized', ...
                'Position', pos, ...
                'BorderType', 'line', ...
                'BorderWidth', 2, ...
                'ForegroundColor', [0.2 0.5 1], ...
                'BackgroundColor', [0.2 0.5 1], ...
                'HighlightColor', [0.2 0.5 1]);
            % Make it semi-transparent by setting a light background
            % (true alpha not available on uipanels in classic MATLAB)
            try
                set(obj.hGhost, 'BackgroundColor', [0.7 0.85 1]);
            catch
            end
        end

        function destroyGhost(obj)
            if ~isempty(obj.hGhost) && ishandle(obj.hGhost)
                delete(obj.hGhost);
            end
            obj.hGhost = [];
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
            set(obj.hPropXLabel, 'Visible', vis);
            set(obj.hPropYLabel, 'Visible', vis);
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
                case 'fastsense'
                    if ~isempty(w.Sensor)
                        set(obj.hSourceType, 'Value', 2);  % Sensor
                        set(obj.hSourceKey, 'String', w.Sensor.Key);
                    elseif ~isempty(w.File)
                        set(obj.hSourceType, 'Value', 3);  % MAT File
                        set(obj.hSourceKey, 'String', w.File);
                    else
                        set(obj.hSourceType, 'Value', 1);  % None
                        set(obj.hSourceKey, 'String', '');
                    end
                case {'number', 'gauge'}
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
                            if isprop(w, 'Sensor')
                                w.Sensor = sensor;
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

        function t = defaultTitleForType(~, type)
            switch type
                case 'fastsense', t = 'New Plot';
                case 'number',   t = 'New Number';
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
