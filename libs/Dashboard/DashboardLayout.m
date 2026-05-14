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
        CreateEventCallback = []    % function handle: @(widget) — set by DashboardEngine
                                    %   (260513-snt). Only invoked for FastSenseWidget.
        VisibleRows      = [1 Inf]  % [topRow bottomRow] currently visible
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
            % 260513-sfp — widgets exposing setYLimitMode also need a bar
            % to host the V/A/L YLimit cluster, even if they have neither
            % a Description nor a DetachCallback. Today that's only
            % FastSenseWidget, but the duck-type keeps the chrome generic.
            needsBar = ~isempty(widget.Description) || ...
                       (~isempty(obj.DetachCallback) && ~isa(widget, 'DividerWidget')) || ...
                       ismethod(widget, 'setYLimitMode') || ...
                       (~isempty(obj.CreateEventCallback) && isa(widget, 'FastSenseWidget'));
                       % ^^^ 260513-sfp duck-type for V/A buttons + 260513-snt '+Event' button.

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
                if ~isempty(obj.CreateEventCallback) && isa(widget, 'FastSenseWidget')
                    % 260513-snt — sibling to Detach; positioned LEFT of '^'.
                    obj.addCreateEventButton(widget);
                end
                if ~isempty(obj.DetachCallback) && ~isa(widget, 'DividerWidget')
                    obj.addDetachButton(widget);
                end
                % 260513-sfp — Y-limit-mode buttons. Duck-typed: only
                % widgets that implement setYLimitMode opt in (today
                % only FastSenseWidget). Lives strictly under needsBar
                % because the cluster requires the WidgetButtonBar host.
                if ismethod(widget, 'setYLimitMode')
                    obj.addYLimitButtons_(widget);
                end
                % 260513-snt — settle final right-anchored button positions.
                %   addInfoIcon runs BEFORE addCreateEventButton, so Info's
                %   initial X collides with Create's slot. reflowChrome_ knows
                %   the full layout (3-button vs 2-button right cluster + V/A
                %   left cluster) and re-anchors everything in one pass.
                DashboardLayout.reflowChrome_(widget.hCellPanel, 28, 2);
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

        function addYLimitButtons_(obj, widget)
        %ADDYLIMITBUTTONS_ Inject the 2-button Y-limit-mode cluster.
        %   Only invoked from realizeWidget when ismethod(widget,'setYLimitMode').
        %   Buttons (V, A) are left-anchored relative to the EXISTING
        %   right-anchored Info/Create/Detach buttons, with a 4-px gap
        %   between the clusters:
        %     [V][A]  ...4px gap...  [Info][+][Detach]
        %       24  24                 24  24   24
        %
        %   The 'locked' YLimitMode remains a valid programmatic mode on
        %   FastSenseWidget (setYLimitMode('locked')) but has no UI button.
        %
        %   Active mode is visually highlighted (the button matching
        %   widget.YLimitMode shows the "pressed" background). The active
        %   background is computed from the theme via DashboardLayout's
        %   chooseYLimitActiveBg_ helper, picking the first available of
        %   {PressedBg, SelectedBg, AccentColor} and falling back to a
        %   brightened ToolbarBackground when the theme exposes none.
            if isempty(widget.ParentTheme) || ~isstruct(widget.ParentTheme)
                theme = DashboardTheme('light');
            else
                theme = widget.ParentTheme;
            end
            bar = obj.getOrCreateButtonBar_(widget);
            barPos = get(bar, 'Position');
            barW = barPos(3);

            % Layout (left-to-right):
            %   [V][A]   ...4px gap...   [Info][+][Detach]
            % Right cluster width: when the '+' button is present, the
            % right cluster spans 3 buttons (Info + Create + Detach)
            % rather than 2 (Info + Detach). The V/A cluster anchors to
            % the LEFT of that, so add an extra (bw + gap) on top of the
            % pre-260513-snt math when CreateEventButton is present.
            bw  = 24;
            gap = 4;
            hasCreate = ~isempty(findobj(bar, 'Tag', 'CreateEventButton', '-depth', 1));
            if hasCreate
                xAll = barW - bw - gap - bw - gap - bw - gap - gap - bw;
            else
                xAll = barW - bw - gap - bw - gap - gap - bw;
            end
            xVisible = xAll - bw;

            activeBg = DashboardLayout.chooseYLimitActiveBg_(theme);

            obj.addYLimitButton_(bar, widget, 'auto-visible', xVisible, ...
                'V', 'Auto-fit Y to visible X range', theme, 'YLimitVisibleBtn');
            obj.addYLimitButton_(bar, widget, 'auto-all', xAll, ...
                'A', 'Auto-fit Y to all data', theme, 'YLimitAllBtn');

            % Stash the active-bg + widget handle on the bar's UserData so
            % the static reflowChrome_ handler can restyle/re-anchor after
            % a resize without re-resolving the theme. Weak ref — guarded
            % with isvalid in syncYLimitButtonsState_ in case the widget
            % gets deleted before the bar.
            ud = get(bar, 'UserData');
            if ~isstruct(ud), ud = struct(); end
            ud.YLimitActiveBg = activeBg;
            ud.YLimitWidget   = widget;
            set(bar, 'UserData', ud);

            % Highlight the button matching the current YLimitMode.
            DashboardLayout.syncYLimitButtonsState_(bar, widget.YLimitMode);
        end

        function addYLimitButton_(obj, bar, widget, mode, x, glyph, tip, theme, tagName)
        %ADDYLIMITBUTTON_ Create a single YLimit pushbutton (helper for addYLimitButtons_).
        %   Callback dispatches through onYLimitButtonClicked_ which calls
        %   widget.setYLimitMode(mode), then re-syncs the visual pressed state.
            uicontrol('Parent', bar, ...
                'Style', 'pushbutton', ...
                'String', glyph, ...
                'Units', 'pixels', ...
                'Position', [x, 2, 24, 24], ...
                'FontSize', 9, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'Tag', tagName, ...
                'TooltipString', tip, ...
                'Callback', @(~,~) obj.onYLimitButtonClicked_(widget, mode, bar));
        end

        function onYLimitButtonClicked_(obj, widget, mode, bar) %#ok<INUSL>
        %ONYLIMITBUTTONCLICKED_ Button callback — set mode + sync pressed state.
        %   Errors are warned (not thrown) so a single bad click never
        %   crashes the dashboard refresh loop.
            try
                widget.setYLimitMode(mode);
                DashboardLayout.syncYLimitButtonsState_(bar, mode);
            catch ME
                warning('DashboardLayout:yLimitClickFailed', ...
                    'YLimit button click failed for mode ''%s'': %s', mode, ME.message);
            end
        end

        function addCreateEventButton(obj, widget)
        %ADDCREATEEVENTBUTTON Add a '+Event' button into the FastSenseWidget's button bar (260513-snt).
        %   Sibling to InfoIconButton + DetachButton. Positioned LEFT of the
        %   '^' Detach button: x = barW - 24 - 24 - 4 - 4 (24px wide button,
        %   4px gap from Detach which sits 4px from the right edge).
        %
        %   The callback is wrapped through invokeCreateEventCallback_ so a
        %   throwing dialog never crashes the bar — DashboardLayout logs a
        %   namespaced warning instead.
            if isempty(widget.ParentTheme) || ~isstruct(widget.ParentTheme)
                theme = DashboardTheme('light');
            else
                theme = widget.ParentTheme;
            end
            bar = obj.getOrCreateButtonBar_(widget);
            barPos = get(bar, 'Position');
            xCreate = barPos(3) - 24 - 24 - 4 - 4;
            uicontrol('Parent', bar, ...
                'Style', 'pushbutton', ...
                'String', '+', ...
                'Units', 'pixels', ...
                'Position', [xCreate 2 24 24], ...
                'FontSize', 11, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'Tag', 'CreateEventButton', ...
                'TooltipString', 'Create event from selection / current view', ...
                'Callback', @(~,~) obj.invokeCreateEventCallback_(widget));
        end

        function invokeCreateEventCallback_(obj, widget)
        %INVOKECREATEEVENTCALLBACK_ Defensive callback wrapper for the '+Event' button (260513-snt).
        %   Any throw from the dialog flow is surfaced as a namespaced
        %   warning ('DashboardLayout:createEventCallbackFailed') so the
        %   widget chrome never goes down with a broken dialog. Mirrors
        %   DashboardToolbar's onReset try/catch pattern.
            if isempty(obj.CreateEventCallback), return; end
            try
                obj.CreateEventCallback(widget);
            catch ME
                warning('DashboardLayout:createEventCallbackFailed', ...
                    'Create-Event callback failed: %s', ME.message);
            end
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
                % Layout right-to-left: DetachButton at the far right, then
                % CreateEventButton 28px to its left (260513-snt), then
                % InfoIconButton 28px to the left of that. When barW < ~120px
                % the leftmost buttons may slide off the left edge — same
                % failure mode as pre-260513-snt; documented and accepted.
                det    = findobj(bar(1), 'Tag', 'DetachButton',      '-depth', 1);
                create = findobj(bar(1), 'Tag', 'CreateEventButton', '-depth', 1);
                info   = findobj(bar(1), 'Tag', 'InfoIconButton',    '-depth', 1);
                if ~isempty(det) && ishandle(det(1))
                    set(det(1), 'Position', [barW - 24 - 4, 2, 24, 24]);
                end
                if ~isempty(create) && ishandle(create(1))
                    set(create(1), 'Position', [barW - 24 - 24 - 4 - 4, 2, 24, 24]);
                end
                if ~isempty(info) && ishandle(info(1))
                    if ~isempty(create) && ishandle(create(1))
                        % Info sits LEFT of Create: shift by another 28px.
                        set(info(1), 'Position', [barW - 24 - 24 - 24 - 4 - 4 - 4, 2, 24, 24]);
                    else
                        % No Create button (non-FastSenseWidget): preserve
                        % the legacy two-button layout (Info LEFT of Detach).
                        set(info(1), 'Position', [barW - 24 - 24 - 4 - 4, 2, 24, 24]);
                    end
                end
                % Re-anchor the V/A cluster. Math must match
                % addYLimitButtons_ exactly so resize does not introduce
                % drift. When the '+' button is present, the right cluster
                % widens by one button (Info + Create + Detach instead of
                % Info + Detach), so the V/A cluster shifts left by (bw+gap).
                bw  = 24; gap = 4;
                allBtn     = findobj(bar(1), 'Tag', 'YLimitAllBtn',     '-depth', 1);
                visibleBtn = findobj(bar(1), 'Tag', 'YLimitVisibleBtn', '-depth', 1);
                hasCreate  = ~isempty(create) && ishandle(create(1));
                if hasCreate
                    xAll = barW - bw - gap - bw - gap - bw - gap - gap - bw;
                else
                    xAll = barW - bw - gap - bw - gap - gap - bw;
                end
                xVisible = xAll - bw;
                if ~isempty(allBtn)     && ishandle(allBtn(1))
                    set(allBtn(1),     'Position', [xAll,     2, bw, bw]);
                end
                if ~isempty(visibleBtn) && ishandle(visibleBtn(1))
                    set(visibleBtn(1), 'Position', [xVisible, 2, bw, bw]);
                end
            end
            if ~isempty(content) && ishandle(content(1))
                contentH = max(1, pp(4) - barH - inset);
                set(content(1), 'Units', 'pixels', ...
                    'Position', [0, 0, pp(3), contentH]);
            end
        end

        function bg = chooseYLimitActiveBg_(theme)
        %CHOOSEYLIMITACTIVEBG_ Pick the highlight color for the active YLimit button.
        %   Tries PressedBg / SelectedBg / AccentColor in order, falling
        %   back to ToolbarBackground brightened by 0.15 per channel
        %   (capped at 1) when none are present. No new theme fields are
        %   introduced by 260513-sfp; future themes can opt into a
        %   dedicated PressedBg token without touching layout code.
            if isstruct(theme)
                if isfield(theme, 'PressedBg')
                    bg = theme.PressedBg;  return;
                end
                if isfield(theme, 'SelectedBg')
                    bg = theme.SelectedBg; return;
                end
                if isfield(theme, 'AccentColor')
                    bg = theme.AccentColor; return;
                end
                if isfield(theme, 'ToolbarBackground')
                    bg = min(theme.ToolbarBackground + 0.15, 1);
                    return;
                end
            end
            % Defensive fallback — light grey.
            bg = [0.85 0.85 0.85];
        end

        function syncYLimitButtonsState_(bar, mode)
        %SYNCYLIMITBUTTONSSTATE_ Visually highlight the YLimit button matching mode.
        %   The active button's BackgroundColor becomes the value stashed on
        %   bar.UserData.YLimitActiveBg by addYLimitButtons_; the other two
        %   revert to the theme's ToolbarBackground. Tolerates missing
        %   buttons (no-op if the bar's UserData was never primed).
            if isempty(bar) || ~ishandle(bar), return; end
            ud = get(bar, 'UserData');
            if ~isstruct(ud) || ~isfield(ud, 'YLimitActiveBg')
                return;
            end
            activeBg = ud.YLimitActiveBg;
            % Resolve the inactive background once. Prefer the widget's own
            % ParentTheme (matches button construction); fall back to a
            % default theme if the widget has been deleted out from under us.
            inactiveBg = [];
            if isfield(ud, 'YLimitWidget') && ~isempty(ud.YLimitWidget)
                w = ud.YLimitWidget;
                if isobject(w) && isvalid(w) && ...
                        ~isempty(w.ParentTheme) && isstruct(w.ParentTheme) && ...
                        isfield(w.ParentTheme, 'ToolbarBackground')
                    inactiveBg = w.ParentTheme.ToolbarBackground;
                end
            end
            if isempty(inactiveBg)
                t = DashboardTheme('light');
                inactiveBg = t.ToolbarBackground;
            end
            tagsAndModes = { ...
                'YLimitVisibleBtn', 'auto-visible'; ...
                'YLimitAllBtn',     'auto-all' };
            for i = 1:size(tagsAndModes, 1)
                btn = findobj(bar, 'Tag', tagsAndModes{i, 1}, '-depth', 1);
                if isempty(btn) || ~ishandle(btn(1)), continue; end
                if strcmp(mode, tagsAndModes{i, 2})
                    set(btn(1), 'BackgroundColor', activeBg);
                else
                    set(btn(1), 'BackgroundColor', inactiveBg);
                end
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
