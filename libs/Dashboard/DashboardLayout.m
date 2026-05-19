classdef DashboardLayout < handle
%DASHBOARDLAYOUT Manages 24-column responsive grid positioning.
%
%   Converts widget grid positions [col, row, width, height] to normalized
%   canvas coordinates [x, y, w, h]. Handles overlap resolution, row
%   calculation, and scrollable canvas when content exceeds the viewport.
%
%   Usage:
%     layout = DashboardLayout();
%     layout.ContentArea = [0.0 0.05 1.0 0.95];
%     layout.TotalRows = 4;
%     pos = layout.computePosition([1 1 6 2]);

    properties (Access = public)
        Columns         = 24
        TotalRows       = 4
        ContentArea     = [0 0 1 1]
        Padding         = [0 0 0 0]
        GapH            = 0
        GapV            = 0
        RowHeight       = 0.22
        ScrollbarWidth  = 0.015
        OnScrollCallback = []       % function handle: @(topRow, bottomRow)
        DetachCallback   = []       % function handle: @(widget) — set by DashboardEngine
        VisibleRows      = [1 Inf]  % [topRow bottomRow] currently visible
        EngineRef        = []       % Phase 1032 PLOG-VIZ-05 — back-reference to DashboardEngine for chrome callbacks (addPlantLogToggle)
    end

    properties (SetAccess = private)
        hViewport   = []
        hCanvas     = []
        hScrollbar  = []
    end

    properties (Access = public)
        hFigure           = []  % Figure handle for popup dismiss callbacks
        hInfoPopup        = []  % Handle to active info popup uipanel (at most one)
    end

    properties (Access = private)
        PrevButtonDownFcn = []  % Saved WindowButtonDownFcn before popup open
        PrevKeyPressFcn   = []  % Saved KeyPressFcn before popup open
    end

    methods (Access = public)
        function obj = DashboardLayout(varargin)
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function cr = canvasRatio(obj)
        %CANVASRATIO Ratio of canvas height to viewport height.
        %   Returns 1 when content fits, >1 when scrolling is needed.
            padB = obj.Padding(2);
            padT = obj.Padding(4);
            needed = padB + padT + ...
                obj.TotalRows * obj.RowHeight + ...
                (obj.TotalRows - 1) * obj.GapV;
            cr = max(1, needed);
        end

        function pos = computePosition(obj, gridPos)
        %COMPUTEPOSITION Convert grid position to canvas-normalized coords.
            col = gridPos(1);
            row = gridPos(2);
            wCols = gridPos(3);
            hRows = gridPos(4);

            padL = obj.Padding(1);
            padB = obj.Padding(2);
            padR = obj.Padding(3);
            padT = obj.Padding(4);

            % Horizontal (canvas-relative, no scaling)
            innerW = 1 - padL - padR;
            cellW = (innerW - (obj.Columns - 1) * obj.GapH) / obj.Columns;
            x = padL + (col - 1) * (cellW + obj.GapH);
            w = wCols * cellW + (wCols - 1) * obj.GapH;

            % Vertical (canvas-relative, using square RowHeight)
            cr = obj.canvasRatio();
            if cr <= 1
                % Content fits — use square RowHeight, anchor to top
                cellH = obj.RowHeight;
                gapV = obj.GapV;
                % Align rows to top of viewport (padT from top)
                usedH = obj.TotalRows * cellH + (obj.TotalRows - 1) * gapV;
                yBase = 1 - padT - usedH;
            else
                % Scrolling - fixed row height scaled to canvas
                cellH = obj.RowHeight / cr;
                gapV = obj.GapV / cr;
                yBase = padB / cr;
            end

            y = yBase + (obj.TotalRows - row - hRows + 1) * (cellH + gapV);
            h = hRows * cellH + (hRows - 1) * gapV;

            pos = [x, y, w, h];
        end

        function [stepW, stepH, cellW, cellH] = canvasStepSizes(obj)
        %CANVASSTEPSIZES Grid step sizes in canvas-normalized coords.
            padL = obj.Padding(1);
            padR = obj.Padding(3);
            padB = obj.Padding(2);
            padT = obj.Padding(4);

            innerW = 1 - padL - padR;
            cellW = (innerW - (obj.Columns - 1) * obj.GapH) / obj.Columns;
            stepW = cellW + obj.GapH;

            cr = obj.canvasRatio();
            if cr <= 1
                cellH = obj.RowHeight;
                stepH = cellH + obj.GapV;
            else
                cellH = obj.RowHeight / cr;
                stepH = cellH + obj.GapV / cr;
            end
        end

        function [dx_c, dy_c] = figureToCanvasDelta(obj, dx_fig, dy_fig)
        %FIGURETOCANVASDELTA Convert figure-normalized deltas to canvas deltas.
            ca = obj.ContentArea;
            cr = obj.canvasRatio();
            vpW = ca(3);
            if cr > 1
                vpW = vpW - obj.ScrollbarWidth;
            end
            dx_c = dx_fig / vpW;
            dy_c = dy_fig / (ca(4) * cr);
        end

        function maxRow = calculateMaxRow(obj, widgets)
            maxRow = 1;
            for i = 1:numel(widgets)
                p = widgets{i}.Position;
                bottomRow = p(2) + p(4) - 1;
                if bottomRow > maxRow
                    maxRow = bottomRow;
                end
            end
        end

        function tf = overlaps(obj, posA, posB)
            aLeft   = posA(1);
            aRight  = posA(1) + posA(3) - 1;
            aTop    = posA(2);
            aBottom = posA(2) + posA(4) - 1;

            bLeft   = posB(1);
            bRight  = posB(1) + posB(3) - 1;
            bTop    = posB(2);
            bBottom = posB(2) + posB(4) - 1;

            hOverlap = aLeft <= bRight && aRight >= bLeft;
            vOverlap = aTop <= bBottom && aBottom >= bTop;
            tf = hOverlap && vOverlap;
        end

        function newPos = resolveOverlap(obj, pos, existingPositions)
            newPos = pos;
            changed = true;
            while changed
                changed = false;
                for i = 1:numel(existingPositions)
                    if obj.overlaps(newPos, existingPositions{i})
                        ep = existingPositions{i};
                        newPos(2) = ep(2) + ep(4);
                        changed = true;
                    end
                end
            end
        end

        function ensureViewport(obj, hFigure, theme)
        %ENSUREVIEWPORT Create viewport/canvas/scrollbar only if they do not exist yet.
        %   Idempotent: if the viewport handle is already valid, returns immediately
        %   without deleting or recreating anything. On the first call the viewport,
        %   canvas, and (if needed) scrollbar are created and TotalRows is reset to 0
        %   so that subsequent additive allocatePanels calls accumulate row counts.
            if ~isempty(obj.hViewport) && ishandle(obj.hViewport)
                return;
            end

            obj.hFigure = hFigure;
            obj.TotalRows = 0;

            % Save current scroll state (always default on first creation)
            prevCr = obj.canvasRatio();
            prevScrollVal = 1;  % default = top
            if ~isempty(obj.hScrollbar) && ishandle(obj.hScrollbar)
                prevScrollVal = get(obj.hScrollbar, 'Value');
            end

            % Compute RowHeight so grid cells are square in pixels
            ca = obj.ContentArea;
            oldUnits = get(hFigure, 'Units');
            set(hFigure, 'Units', 'pixels');
            figPx = get(hFigure, 'Position');
            set(hFigure, 'Units', oldUnits);
            vpPxW = figPx(3) * ca(3);
            vpPxH = figPx(4) * ca(4);
            padL = obj.Padding(1); padR = obj.Padding(3);
            innerW = 1 - padL - padR;
            cellW = (innerW - (obj.Columns - 1) * obj.GapH) / obj.Columns;
            if vpPxH > 0
                obj.RowHeight = cellW * vpPxW / vpPxH;
            end
            if vpPxH > 0
                obj.GapV = obj.GapH * vpPxW / vpPxH;
            end

            cr = obj.canvasRatio();

            ca = obj.ContentArea;
            scrollNeeded = cr > 1;
            vpW = ca(3);
            if scrollNeeded
                vpW = ca(3) - obj.ScrollbarWidth;
            end

            % Create viewport (clips content to visible area)
            obj.hViewport = uipanel('Parent', hFigure, ...
                'Units', 'normalized', ...
                'Position', [ca(1), ca(2), vpW, ca(4)], ...
                'BorderType', 'none', ...
                'BackgroundColor', theme.DashboardBackground);

            % Restore scroll position, compensating for canvas ratio change
            if prevCr > 1 && cr > 1
                oldOffset = prevScrollVal * (1 - prevCr);
                scrollVal = max(0, min(1, oldOffset / (1 - cr)));
            else
                scrollVal = max(0, min(1, prevScrollVal));
            end
            canvasY = scrollVal * (1 - cr);

            % Create canvas (may be taller than viewport for scrolling)
            obj.hCanvas = uipanel('Parent', obj.hViewport, ...
                'Units', 'normalized', ...
                'Position', [0, canvasY, 1, max(1, cr)], ...
                'BorderType', 'none', ...
                'BackgroundColor', theme.DashboardBackground);

            % Create scrollbar if content overflows
            if scrollNeeded
                obj.hScrollbar = uicontrol('Parent', hFigure, ...
                    'Style', 'slider', ...
                    'Units', 'normalized', ...
                    'Position', [ca(1) + vpW, ca(2), ...
                                 obj.ScrollbarWidth, ca(4)], ...
                    'Min', 0, 'Max', 1, 'Value', scrollVal, ...
                    'SliderStep', [0.06, 0.2], ...
                    'Callback', @(src,~) obj.onScroll(get(src, 'Value')));
                try
                    set(hFigure, 'WindowScrollWheelFcn', ...
                        @(~,evt) obj.onScrollWheel(evt));
                catch
                end
            else
                obj.hScrollbar = [];
                try set(hFigure, 'WindowScrollWheelFcn', ''); catch , end
            end

            obj.VisibleRows = obj.computeVisibleRows(scrollVal);
        end

        function resetViewport(obj)
        %RESETVIEWPORT Destroy the current viewport so the next ensureViewport call rebuilds it.
        %   Use when a full layout rebuild is required (e.g. single-page reflow).
            if ~isempty(obj.hViewport) && ishandle(obj.hViewport)
                delete(obj.hViewport);
            end
            obj.hViewport = [];
            if ~isempty(obj.hScrollbar) && ishandle(obj.hScrollbar)
                delete(obj.hScrollbar);
            end
            obj.hScrollbar = [];
            obj.hCanvas = [];
            obj.TotalRows = 0;
        end

        function allocatePanels(obj, hFigure, widgets, theme)
        %ALLOCATEPANELS Create placeholder panels for widgets (additive; no viewport destruction).
        %   Calls ensureViewport (idempotent) to guarantee hViewport/hCanvas exist, then
        %   accumulates TotalRows and appends widget panels to the shared canvas.
        %   Multiple calls for different page-widget sets are safe: earlier panels survive.
            % Ensure viewport exists (idempotent — no-op if already live)
            obj.ensureViewport(hFigure, theme);

            % Accumulate TotalRows across additive calls rather than overwriting
            obj.TotalRows = max(obj.TotalRows, obj.calculateMaxRow(widgets));

            % Get current scroll value for VisibleRows update
            scrollVal = 1;
            if ~isempty(obj.hScrollbar) && ishandle(obj.hScrollbar)
                scrollVal = get(obj.hScrollbar, 'Value');
            end

            % Create widget panels on canvas (placeholder only, no render)
            for i = 1:numel(widgets)
                w = widgets{i};
                w.ParentTheme = theme;
                pos = obj.computePosition(w.Position);
                isDivider = isa(w, 'DividerWidget');
                if isDivider
                    hp = uipanel('Parent', obj.hCanvas, ...
                        'Units', 'normalized', ...
                        'Position', pos, ...
                        'BorderType', 'none', ...
                        'BackgroundColor', theme.DashboardBackground);
                else
                    hp = uipanel('Parent', obj.hCanvas, ...
                        'Units', 'normalized', ...
                        'Position', pos, ...
                        'BorderType', 'line', ...
                        'BorderWidth', theme.WidgetBorderWidth, ...
                        'ForegroundColor', theme.WidgetBorderColor, ...
                        'BackgroundColor', theme.WidgetBackground);
                end
                w.hPanel = hp;
                uicontrol('Parent', hp, 'Style', 'text', 'Units', 'normalized', ...
                    'Position', [0.05 0.4 0.9 0.2], ...
                    'String', [w.Title, ' -- Loading...'], ...
                    'HorizontalAlignment', 'center', ...
                    'BackgroundColor', theme.WidgetBackground, ...
                    'ForegroundColor', theme.ToolbarFontColor, ...
                    'Tag', 'placeholder');
            end

            % Update VisibleRows from current scroll position
            obj.VisibleRows = obj.computeVisibleRows(scrollVal);
        end

        function realizeWidget(obj, widget)
        %REALIZEWIDGET Render a single widget into its pre-allocated panel.
        %   Creates the chrome (full-width WidgetButtonBar + WidgetContentPanel
        %   sub-panel below the bar) BEFORE calling widget.render so the
        %   widget's own graphics children (titles, axes, status text, group
        %   headers) land in the visible content area, never under the bar.
        %
        %   Widgets that don't need chrome (no Description AND no
        %   DetachCallback, or DividerWidget) skip both the bar and the
        %   content sub-panel and render directly into the outer cell panel
        %   as before — preserving zero-chrome behavior for visual-only
        %   widgets.
            if widget.Realized, return; end
            if isempty(widget.hPanel) || ~ishandle(widget.hPanel), return; end

            % The outer grid-cell panel was assigned to widget.hPanel by
            % allocatePanels. Pin that handle as hCellPanel so chrome
            % helpers can find it after widget.render reassigns hPanel to
            % the content sub-panel below.
            widget.hCellPanel = widget.hPanel;

            % Remove placeholder from the cell panel before chrome lands.
            ph = findobj(widget.hCellPanel, 'Tag', 'placeholder');
            delete(ph);

            % Decide whether this widget needs chrome.
            needsBar = ~isempty(widget.Description) || ...
                       (~isempty(obj.DetachCallback) && ~isa(widget, 'DividerWidget'));

            if needsBar
                % 1. Create the full-width bar at the top of the cell panel.
                obj.getOrCreateButtonBar_(widget);
                % 2. Create the content sub-panel that fills the cell BELOW the bar.
                contentPanel = obj.createContentPanel_(widget);
                % 3. Render widget content into the content sub-panel.
                %    The widget's render() will assign obj.hPanel = contentPanel,
                %    which is intentional: subsequent refresh/relayout_/findobj
                %    operations on hPanel target the content area, not the cell.
                widget.render(contentPanel);
                % 4. Inject buttons into the existing bar.
                if ~isempty(widget.Description)
                    obj.addInfoIcon(widget);
                end
                if ~isempty(obj.DetachCallback) && ~isa(widget, 'DividerWidget')
                    obj.addDetachButton(widget);
                end
                % Phase 1032 PLOG-VIZ-05: plant-log toggle on FastSenseWidget only.
                if isa(widget, 'FastSenseWidget')
                    try
                        engineRef = obj.EngineRef;
                        obj.addPlantLogToggle(widget, engineRef);
                    catch ME
                        warning('DashboardLayout:plantLogToggleParentMissing', ...
                            'addPlantLogToggle failed during realizeWidget: %s', ME.message);
                    end
                end
            else
                % No chrome — render directly into the cell panel as before.
                widget.render(widget.hCellPanel);
            end

            widget.markRealized();
            widget.Dirty = false;
        end

        function createPanels(obj, hFigure, widgets, theme)
        %CREATEPANELS Create and render all widget panels (legacy path).
            obj.allocatePanels(hFigure, widgets, theme);
            for i = 1:numel(widgets)
                obj.realizeWidget(widgets{i});
            end
        end

        function reflow(obj, hFigure, widgets, theme)
        % Re-run layout after dynamic changes (e.g., group collapse/expand).
        % Tears down and recreates all panels, calling render() on each widget.
            if isempty(hFigure) || ~ishandle(hFigure)
                return;
            end
            obj.closeInfoPopup();    % dismiss any open popup before panel teardown
            % Full rebuild required for reflow: reset the viewport so ensureViewport
            % inside createPanels/allocatePanels recreates it from scratch.
            obj.resetViewport();
            obj.createPanels(hFigure, widgets, theme);
        end

        function onScroll(obj, val)
        %ONSCROLL Adjust canvas position from scrollbar value.
        %   val=1 shows top, val=0 shows bottom.
            cr = obj.canvasRatio();
            if cr <= 1, return; end
            offset = val * (1 - cr);
            set(obj.hCanvas, 'Position', [0, offset, 1, cr]);

            obj.VisibleRows = obj.computeVisibleRows(val);
            if ~isempty(obj.OnScrollCallback)
                obj.OnScrollCallback(obj.VisibleRows(1), obj.VisibleRows(2));
            end
        end

        function rows = computeVisibleRows(obj, scrollVal)
        %COMPUTEVISIBLEROWS Derive visible row range from scroll position.
            cr = obj.canvasRatio();
            if cr <= 1
                rows = [1, obj.TotalRows];
                return;
            end
            canvasY = scrollVal * (1 - cr);
            cellH = obj.RowHeight / cr;
            gapV  = obj.GapV / cr;
            step  = cellH + gapV;
            if step <= 0
                rows = [1, obj.TotalRows];
                return;
            end
            padB = obj.Padding(2);
            yBase = padB / cr;
            % Visible region in canvas-internal [0,1] coords
            visBot = -canvasY / cr;
            visTop = (1 - canvasY) / cr;
            % Row r has bottom at yBase + (TotalRows - r) * step
            % topRow: smallest r where row top >= visBot
            topRow  = obj.TotalRows - ...
                      floor((visTop - yBase) / step);
            % bottomRow: largest r where row bottom <= visTop
            bottomRow = obj.TotalRows - ...
                        ceil((visBot - yBase - cellH) / step);
            topRow    = max(1, topRow);
            bottomRow = min(obj.TotalRows, bottomRow);
            rows = [topRow, bottomRow];
        end

        function vis = isWidgetVisible(obj, gridPos, buffer)
        %ISWIDGETVISIBLE Check if widget rows overlap visible range + buffer.
            if nargin < 3, buffer = 2; end
            wRow = gridPos(2);
            wHeight = gridPos(4);
            wTop = wRow;
            wBottom = wRow + wHeight - 1;
            vTop = obj.VisibleRows(1) - buffer;
            vBottom = obj.VisibleRows(2) + buffer;
            vis = wBottom >= vTop && wTop <= vBottom;
        end
    end

    methods (Access = public)

        function openInfoPopup(obj, widget, theme)
        %OPENINFOPOPUP Open a modal figure window showing widget Description.
            obj.closeInfoPopup();
            descText = widget.Description;
            titleText = widget.Title;
            if isempty(titleText)
                titleText = 'Widget Info';
            end

            % Save current figure callbacks before popup overwrites them
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                obj.PrevButtonDownFcn = get(obj.hFigure, 'WindowButtonDownFcn');
                obj.PrevKeyPressFcn   = get(obj.hFigure, 'KeyPressFcn');
            end

            % Create a standalone modal figure
            fig = figure('Name', ['Info: ' titleText], ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'Units', 'pixels', ...
                'Position', [100 100 420 260], ...
                'Color', theme.WidgetBackground, ...
                'Resize', 'on', ...
                'CloseRequestFcn', @(~,~) obj.closeInfoPopup());
            % Center on screen
            movegui(fig, 'center');

            fgColor = theme.ForegroundColor;

            % Title label
            uicontrol('Parent', fig, ...
                'Style', 'text', ...
                'String', titleText, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.85 0.90 0.12], ...
                'HorizontalAlignment', 'left', ...
                'FontSize', 14, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', theme.WidgetBackground, ...
                'ForegroundColor', fgColor);

            % Description text (multi-line, read-only)
            uicontrol('Parent', fig, ...
                'Style', 'edit', ...
                'Max', 10, 'Min', 0, ...
                'String', descText, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.20 0.90 0.63], ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'inactive', ...
                'FontSize', 11, ...
                'BackgroundColor', theme.WidgetBackground, ...
                'ForegroundColor', fgColor);

            % Close button
            uicontrol('Parent', fig, ...
                'Style', 'pushbutton', ...
                'String', 'Close', ...
                'Units', 'normalized', ...
                'Position', [0.35 0.04 0.30 0.12], ...
                'Callback', @(~,~) obj.closeInfoPopup());

            obj.hInfoPopup = fig;
        end

        function closeInfoPopup(obj)
        %CLOSEINFOPOPUP Close and delete the active info popup panel.
            wasOpen = ~isempty(obj.hInfoPopup) && ishandle(obj.hInfoPopup);
            if wasOpen
                delete(obj.hInfoPopup);
            end
            obj.hInfoPopup = [];
            % Restore prior figure callbacks only if a popup was actually open
            % (i.e. we had previously saved them in openInfoPopup)
            if wasOpen && ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                set(obj.hFigure, 'WindowButtonDownFcn', obj.PrevButtonDownFcn);
                set(obj.hFigure, 'KeyPressFcn', obj.PrevKeyPressFcn);
            end
            obj.PrevButtonDownFcn = [];
            obj.PrevKeyPressFcn   = [];
        end

        function onFigureClickForDismiss(obj)
        %ONFIGURECLICKFORDISMISS Dismiss popup if click was outside the popup panel.
            if isempty(obj.hInfoPopup) || ~ishandle(obj.hInfoPopup)
                obj.closeInfoPopup();
                return;
            end
            clicked = gco;
            insidePopup = false;
            h = clicked;
            while ~isempty(h) && ishandle(h)
                if h == obj.hInfoPopup
                    insidePopup = true;
                    break;
                end
                try
                    h = get(h, 'Parent');
                catch
                    break;
                end
            end
            if ~insidePopup
                obj.closeInfoPopup();
            end
        end

        function onKeyPressForDismiss(obj, eventData)
        %ONKEYPRESSFORDISMISS Dismiss popup when Escape is pressed.
            if strcmp(eventData.Key, 'escape')
                obj.closeInfoPopup();
            end
        end

        function addPlantLogToggle(obj, widget, engine)
        %ADDPLANTLOGTOGGLE Add the per-widget plant-log overlay toggle (Phase 1032 PLOG-VIZ-05).
        %   The toggle is always created (Decision B: always render, disable
        %   when no store); clicking it calls
        %   widget.setShowPlantLog(~widget.ShowPlantLog, engine).
        %   The engine handle is captured by the callback closure.
        %
        %   Idempotent: any prior PlantLogToggleButton on the same bar is
        %   deleted before the new uicontrol is created.
        %
        %   Visibility / pressed-state colors:
        %     - No store attached: Enable='off',  tooltip 'No plant log attached'
        %     - Store, ShowPlantLog=false: Enable='on', tooltip 'Show plant log lines',
        %         bg=theme.ToolbarBackground, fg=theme.ToolbarFontColor
        %     - Store, ShowPlantLog=true:  Enable='on', tooltip 'Hide plant log lines',
        %         bg=theme.MarkerPlantLog ([0 0 0]), fg=[1 1 1]
        %
        %   Errors namespaced 'DashboardLayout:plantLogToggleParentMissing'
        %   for callback-time parent-missing failures.
            if isempty(widget.ParentTheme) || ~isstruct(widget.ParentTheme)
                theme = DashboardTheme('light');
            else
                theme = widget.ParentTheme;
            end
            bar = obj.getOrCreateButtonBar_(widget);
            % Idempotent: clear any prior PlantLogToggleButton on this bar.
            prior = findobj(bar, 'Tag', 'PlantLogToggleButton', '-depth', 1);
            if ~isempty(prior)
                try delete(prior); catch, end
            end
            barPos = get(bar, 'Position');
            % Position from right edge: Detach (offset 4 + 24-wide) + 4 gap +
            % Info (24-wide) + 4 gap + PlantLog (24-wide). LeftMost button x:
            %   x = barW - 24 - 4 - 24 - 4 - 24 - 4 = barW - 84
            xPL = barPos(3) - 24 - 4 - 24 - 4 - 24 - 4;
            % Resolve enabled/disabled state from the engine store.
            storeAttached = false;
            if ~isempty(engine) && isa(engine, 'DashboardEngine')
                try
                    storeAttached = ~isempty(engine.PlantLogStoreInternal_) && ...
                        isa(engine.PlantLogStoreInternal_, 'PlantLogStore');
                catch
                    storeAttached = false;
                end
            end
            if storeAttached
                enableState = 'on';
                if isa(widget, 'FastSenseWidget') && widget.ShowPlantLog
                    tipStr  = 'Hide plant log lines';
                    bgColor = [0 0 0];
                    if isfield(theme, 'MarkerPlantLog')
                        bgColor = theme.MarkerPlantLog;
                    end
                    fgColor = [1 1 1];
                else
                    tipStr  = 'Show plant log lines';
                    bgColor = theme.ToolbarBackground;
                    fgColor = theme.ToolbarFontColor;
                end
            else
                enableState = 'off';
                tipStr  = 'No plant log attached';
                bgColor = theme.ToolbarBackground;
                fgColor = theme.ToolbarFontColor;
            end
            uicontrol('Parent', bar, ...
                'Style',           'pushbutton', ...
                'String',          'L', ...
                'Units',           'pixels', ...
                'Position',        [xPL 2 24 24], ...
                'FontSize',        9, ...
                'FontWeight',      'bold', ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'Enable',          enableState, ...
                'Tag',             'PlantLogToggleButton', ...
                'TooltipString',   tipStr, ...
                'Callback',        @(s, ~) obj.onPlantLogTogglePressed_(s, widget, engine));
        end

        function onPlantLogTogglePressed_(obj, src, widget, engine)
        %ONPLANTLOGTOGGLEPRESSED_ Toggle button callback — wraps setShowPlantLog with try/catch (Phase 1032 PLOG-VIZ-05).
        %   Programmatic force-call paths (tests, automation) need a
        %   software-level guard for Enable='off' because uicontrols only
        %   honor Enable natively for user-driven mouse clicks.
            try
                % Software-level Enable guard: if the button was constructed
                % with Enable='off' (no store), force-calls must be no-ops.
                if ~isempty(src) && ishandle(src)
                    try
                        if strcmp(get(src, 'Enable'), 'off')
                            return;
                        end
                    catch
                    end
                end
                if ~isa(widget, 'FastSenseWidget')
                    error('DashboardLayout:plantLogToggleParentMissing', ...
                        'PlantLog toggle requires a FastSenseWidget parent.');
                end
                widget.setShowPlantLog(~widget.ShowPlantLog, engine);
                % Rebuild the button look (pressed-state colors + tooltip).
                obj.addPlantLogToggle(widget, engine);
            catch ME
                warning('DashboardLayout:plantLogToggleParentMissing', ...
                    'Plant-log toggle callback failed: %s', ME.message);
                % Best-effort: non-blocking uialert if a uifigure ancestor exists.
                try
                    fig = ancestor(src, 'figure');
                    if ~isempty(fig) && ishandle(fig) && isa(fig, 'matlab.ui.Figure')
                        uialert(fig, ME.message, 'Plant log toggle failed', 'Icon', 'error');
                    end
                catch
                end
            end
        end

    end

    methods (Access = private)
        function onScrollWheel(obj, evt)
            if isempty(obj.hScrollbar) || ~ishandle(obj.hScrollbar)
                return;
            end
            val = get(obj.hScrollbar, 'Value');
            step = 0.06 * evt.VerticalScrollCount;
            val = max(0, min(1, val - step));
            set(obj.hScrollbar, 'Value', val);
            obj.onScroll(val);
        end

        function bar = getOrCreateButtonBar_(obj, widget) %#ok<INUSL>
        %GETORCREATEBUTTONBAR_ Return the per-widget button bar uipanel,
        %   creating it the first time. The bar is a full-width opaque
        %   header strip across the top of widget.hCellPanel (28px tall,
        %   inset 2px from cell edges) that hosts the info + detach
        %   buttons. Widgets render into a sibling WidgetContentPanel
        %   sub-panel BELOW the bar (created by DashboardLayout.realizeWidget
        %   via createContentPanel_) so widget content is never overlapped
        %   by the bar. Tag = 'WidgetButtonBar'.
            existing = findobj(widget.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
            if ~isempty(existing) && ishandle(existing(1))
                bar = existing(1);
                return;
            end
            if isempty(widget.ParentTheme) || ~isstruct(widget.ParentTheme)
                theme = DashboardTheme('light');
            else
                theme = widget.ParentTheme;
            end
            % Background: use GroupHeaderBg (explicitly designed as a
            % header-vs-panel contrast token — light blue-gray in light
            % mode, slightly-lighter navy in dark mode), falling back to
            % ToolbarBackground for older themes that don't define it.
            if isfield(theme, 'GroupHeaderBg')
                barBg = theme.GroupHeaderBg;
            else
                barBg = theme.ToolbarBackground;
            end
            % Full-width header strip, 28px tall, left-anchored across the
            % top of the outer cell panel. Inset by 2px from cell edges.
            oldUnits = get(widget.hCellPanel, 'Units');
            set(widget.hCellPanel, 'Units', 'pixels');
            pp = get(widget.hCellPanel, 'Position');
            set(widget.hCellPanel, 'Units', oldUnits);
            barH = 28;
            inset = 2;
            barW = max(1, pp(3) - 2 * inset);
            x = inset;
            y = pp(4) - barH - inset;
            bar = uipanel('Parent', widget.hCellPanel, ...
                'Units', 'pixels', ...
                'Position', [x y barW barH], ...
                'BackgroundColor', barBg, ...
                'BorderType', 'none', ...
                'Tag', 'WidgetButtonBar');
            % Reposition on panel resize so the bar tracks the widget —
            % only when MATLAB has an interactive desktop. Under -batch /
            % -nodesktop / -nodisplay (CI, xvfb), the SizeChangedFcn fires
            % during render of run_demo's 25+ widgets and segfaults R2020b.
            % usejava('desktop') is true only in an interactive Java desktop;
            % batchStartupOptionUsed catches MATLAB -batch on R2019a+.
            isInteractive = false;
            try
                isInteractive = usejava('desktop');
                if exist('batchStartupOptionUsed', 'builtin') == 5 && ...
                        batchStartupOptionUsed
                    isInteractive = false;
                end
            catch
            end
            if isInteractive
                set(widget.hCellPanel, 'SizeChangedFcn', ...
                    @(src, ~) DashboardLayout.reflowChrome_(src, barH, inset));
            end
        end

        function panel = createContentPanel_(obj, widget) %#ok<INUSL>
        %CREATECONTENTPANEL_ Create the WidgetContentPanel sub-panel that
        %   widgets render their content into. Sized to fill the cell panel
        %   BELOW the WidgetButtonBar so widget content never overlaps chrome.
        %   Idempotent: returns the existing panel if already created.
        %   Tag = 'WidgetContentPanel'.
            cell = widget.hCellPanel;
            existing = findobj(cell, 'Tag', 'WidgetContentPanel', '-depth', 1);
            if ~isempty(existing) && ishandle(existing(1))
                panel = existing(1);
                return;
            end
            if isempty(widget.ParentTheme) || ~isstruct(widget.ParentTheme)
                theme = DashboardTheme('light');
            else
                theme = widget.ParentTheme;
            end
            contentBg = theme.WidgetBackground;
            barH = 28;
            inset = 2;
            oldUnits = get(cell, 'Units');
            set(cell, 'Units', 'pixels');
            pp = get(cell, 'Position');
            set(cell, 'Units', oldUnits);
            contentH = max(1, pp(4) - barH - inset);
            panel = uipanel('Parent', cell, ...
                'Units', 'pixels', ...
                'Position', [0, 0, pp(3), contentH], ...
                'BackgroundColor', contentBg, ...
                'BorderType', 'none', ...
                'Tag', 'WidgetContentPanel');
        end

        function addInfoIcon(obj, widget)
        %ADDINFOICON Add a small info button into the widget's button bar.
            if isempty(widget.ParentTheme) || ~isstruct(widget.ParentTheme)
                theme = DashboardTheme('light');
            else
                theme = widget.ParentTheme;
            end
            bar = obj.getOrCreateButtonBar_(widget);
            barPos = get(bar, 'Position');
            % Right-anchored: detach at far right (offset 4), info just to
            % its left. Positions are relative to the bar uipanel.
            xInfo = barPos(3) - 28 - 28 - 4;
            uicontrol('Parent', bar, ...
                'Style', 'pushbutton', ...
                'String', 'i', ...
                'Units', 'pixels', ...
                'Position', [xInfo 2 24 24], ...
                'FontSize', 9, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'Tag', 'InfoIconButton', ...
                'TooltipString', 'Widget info', ...
                'Callback', @(~,~) obj.openInfoPopup(widget, theme));
        end

        function addDetachButton(obj, widget)
        %ADDDETACHBUTTON Add a detach button into the widget's button bar.
            if isempty(widget.ParentTheme) || ~isstruct(widget.ParentTheme)
                theme = DashboardTheme('light');
            else
                theme = widget.ParentTheme;
            end
            bar = obj.getOrCreateButtonBar_(widget);
            barPos = get(bar, 'Position');
            xDet = barPos(3) - 24 - 4;
            uicontrol('Parent', bar, ...
                'Style', 'pushbutton', ...
                'String', '^', ...
                'Units', 'pixels', ...
                'Position', [xDet 2 24 24], ...
                'FontSize', 9, ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'Tag', 'DetachButton', ...
                'TooltipString', 'Detach widget', ...
                'Callback', @(~,~) obj.DetachCallback(widget));
        end
    end

    methods (Static)

        function reflowChrome_(hCell, barH, inset)
        %REFLOWCHROME_ SizeChangedFcn handler — re-anchor the WidgetButtonBar
        %   AND resize the WidgetContentPanel after the parent cell panel
        %   resizes. Public so tests can drive a deterministic resize without
        %   relying on SizeChangedFcn firing under -batch.
        %   No-op when the cell has been deleted or chrome isn't there yet.
            if ~ishandle(hCell), return; end
            bar     = findobj(hCell, 'Tag', 'WidgetButtonBar',    '-depth', 1);
            content = findobj(hCell, 'Tag', 'WidgetContentPanel', '-depth', 1);
            oldUnits = get(hCell, 'Units');
            set(hCell, 'Units', 'pixels');
            pp = get(hCell, 'Position');
            set(hCell, 'Units', oldUnits);
            if ~isempty(bar) && ishandle(bar(1))
                barW = max(1, pp(3) - 2 * inset);
                set(bar(1), 'Units', 'pixels', ...
                    'Position', [inset, pp(4) - barH - inset, barW, barH]);
                % Re-anchor right-aligned buttons inside the bar.
                det  = findobj(bar(1), 'Tag', 'DetachButton',   '-depth', 1);
                info = findobj(bar(1), 'Tag', 'InfoIconButton', '-depth', 1);
                if ~isempty(det) && ishandle(det(1))
                    set(det(1), 'Position', [barW - 24 - 4, 2, 24, 24]);
                end
                if ~isempty(info) && ishandle(info(1))
                    set(info(1), 'Position', [barW - 24 - 24 - 4 - 4, 2, 24, 24]);
                end
                pl = findobj(bar(1), 'Tag', 'PlantLogToggleButton', '-depth', 1);  % Phase 1032 PLOG-VIZ-05
                if ~isempty(pl) && ishandle(pl(1))
                    % Leftmost of the three from the right edge:
                    %   24 detach + 4 + 24 info + 4 + 24 plantlog + 4 = 84.
                    set(pl(1), 'Position', [barW - 24 - 4 - 24 - 4 - 24 - 4, 2, 24, 24]);
                end
            end
            if ~isempty(content) && ishandle(content(1))
                contentH = max(1, pp(4) - barH - inset);
                set(content(1), 'Units', 'pixels', ...
                    'Position', [0, 0, pp(3), contentH]);
            end
        end

        function reflowButtonBar_(hCell, barH, inset)
        %REFLOWBUTTONBAR_ Deprecated alias — forwards to reflowChrome_.
        %   Kept temporarily for any external callers that still reference
        %   the m52-era name.
            DashboardLayout.reflowChrome_(hCell, barH, inset);
        end

    end

    methods (Static, Access = private)

        function anchorTopRight(btn, offsetFromRight)
        %ANCHORTOPRIGHT Position a pixel-sized button at the top-right of its parent.
        %   anchorTopRight(btn, offsetFromRight) places btn so its right edge is
        %   offsetFromRight pixels from the parent's right edge, top-aligned.
            parent = get(btn, 'Parent');
            oldUnits = get(parent, 'Units');
            set(parent, 'Units', 'pixels');
            pp = get(parent, 'Position');
            set(parent, 'Units', oldUnits);
            btnPos = get(btn, 'Position');
            btnW = btnPos(3);
            btnH = btnPos(4);
            x = pp(3) - btnW - offsetFromRight;
            y = pp(4) - btnH - 4;
            set(btn, 'Position', [x y btnW btnH]);
        end

    end
end
