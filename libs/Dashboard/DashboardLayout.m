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
        Padding         = [0.02 0.02 0.02 0.02]
        GapH            = 0.008
        GapV            = 0.015
        RowHeight       = 0.22
        ScrollbarWidth  = 0.015
        OnScrollCallback = []       % function handle: @(topRow, bottomRow)
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

        function allocatePanels(obj, hFigure, widgets, theme)
        %ALLOCATEPANELS Create viewport, canvas, scrollbar and placeholder panels.
        %   Like createPanels but does NOT call widget.render(). Instead,
        %   each widget gets its hPanel assigned and a placeholder label.
            obj.hFigure = hFigure;
            % Save current scroll state before any updates
            prevCr = obj.canvasRatio();
            prevScrollVal = 1;  % default = top
            if ~isempty(obj.hScrollbar) && ishandle(obj.hScrollbar)
                prevScrollVal = get(obj.hScrollbar, 'Value');
            end

            obj.TotalRows = obj.calculateMaxRow(widgets);

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
            % cellW is in normalized viewport width; convert to pixel ratio
            if vpPxH > 0
                obj.RowHeight = cellW * vpPxW / vpPxH;
            end
            obj.GapV = obj.GapH * vpPxW / vpPxH;

            cr = obj.canvasRatio();

            % Clean up old viewport/canvas/scrollbar
            if ~isempty(obj.hViewport) && ishandle(obj.hViewport)
                delete(obj.hViewport);
            end
            if ~isempty(obj.hScrollbar) && ishandle(obj.hScrollbar)
                delete(obj.hScrollbar);
            end

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
                % Convert old scroll offset to proportional position, then
                % map to new canvas ratio so the same content stays visible
                oldOffset = prevScrollVal * (1 - prevCr);
                scrollVal = max(0, min(1, oldOffset / (1 - cr)));
            else
                scrollVal = max(0, min(1, prevScrollVal));
            end
            canvasY = scrollVal * (1 - cr);

            % Create canvas (may be taller than viewport for scrolling)
            obj.hCanvas = uipanel('Parent', obj.hViewport, ...
                'Units', 'normalized', ...
                'Position', [0, canvasY, 1, cr], ...
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

            % Create widget panels on canvas (placeholder only, no render)
            for i = 1:numel(widgets)
                w = widgets{i};
                w.ParentTheme = theme;
                pos = obj.computePosition(w.Position);
                hp = uipanel('Parent', obj.hCanvas, ...
                    'Units', 'normalized', ...
                    'Position', pos, ...
                    'BorderType', 'line', ...
                    'BorderWidth', theme.WidgetBorderWidth, ...
                    'ForegroundColor', theme.WidgetBorderColor, ...
                    'BackgroundColor', theme.WidgetBackground);
                w.hPanel = hp;
                uicontrol('Parent', hp, 'Style', 'text', 'Units', 'normalized', ...
                    'Position', [0.05 0.4 0.9 0.2], ...
                    'String', [w.Title, ' -- Loading...'], ...
                    'HorizontalAlignment', 'center', ...
                    'BackgroundColor', theme.WidgetBackground, ...
                    'ForegroundColor', theme.ToolbarFontColor, ...
                    'Tag', 'placeholder');
            end

            % Compute initial VisibleRows from scrollbar value
            obj.VisibleRows = obj.computeVisibleRows(scrollVal);
        end

        function realizeWidget(obj, widget)
        %REALIZEWIDGET Render a single widget into its pre-allocated panel.
            if widget.Realized, return; end
            if isempty(widget.hPanel) || ~ishandle(widget.hPanel), return; end
            % Remove placeholder
            ph = findobj(widget.hPanel, 'Tag', 'placeholder');
            delete(ph);
            % Render actual content
            widget.render(widget.hPanel);
            widget.Realized = true;
            widget.Dirty = false;
            % Inject info icon when widget has a description
            if ~isempty(widget.Description)
                obj.addInfoIcon(widget);
            end
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
        %OPENINFOPOPUP Open an info popup panel on widget.hPanel showing Description.
            obj.closeInfoPopup();
            descText = widget.Description;
            popupPanel = uipanel('Parent', widget.hPanel, ...
                'Units', 'normalized', ...
                'Position', [0.0 0.0 1.0 0.88], ...
                'BackgroundColor', theme.WidgetBackground, ...
                'BorderType', 'line', ...
                'ForegroundColor', theme.WidgetBorderColor, ...
                'Tag', 'InfoPopupPanel');
            if isfield(theme, 'ForegroundColor')
                fgColor = theme.ForegroundColor;
            else
                fgColor = theme.ToolbarFontColor;
            end
            uicontrol('Parent', popupPanel, ...
                'Style', 'edit', ...
                'Max', 10, 'Min', 0, ...
                'String', descText, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.10 0.96 0.82], ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'inactive', ...
                'FontSize', 10, ...
                'BackgroundColor', theme.WidgetBackground, ...
                'ForegroundColor', fgColor);
            uicontrol('Parent', popupPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Close', ...
                'Units', 'normalized', ...
                'Position', [0.35 0.01 0.30 0.08], ...
                'Callback', @(~,~) obj.closeInfoPopup());
            obj.hInfoPopup = popupPanel;
            % Wire figure callbacks for dismiss-on-click and dismiss-on-Escape
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                obj.PrevButtonDownFcn = get(obj.hFigure, 'WindowButtonDownFcn');
                obj.PrevKeyPressFcn   = get(obj.hFigure, 'KeyPressFcn');
                set(obj.hFigure, 'WindowButtonDownFcn', @(~,~) obj.onFigureClickForDismiss());
                set(obj.hFigure, 'KeyPressFcn', @(~,e) obj.onKeyPressForDismiss(e));
            end
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

        function addInfoIcon(obj, widget)
        %ADDINFOICON Add a small info button to widget.hPanel for Description display.
            if isempty(widget.ParentTheme) || ~isstruct(widget.ParentTheme)
                theme = DashboardTheme('light');
            else
                theme = widget.ParentTheme;
            end
            iconBg = theme.ToolbarBackground;
            iconFg = theme.ToolbarFontColor;
            uicontrol('Parent', widget.hPanel, ...
                'Style', 'pushbutton', ...
                'String', 'i', ...
                'Units', 'normalized', ...
                'Position', [0.90 0.90 0.08 0.08], ...
                'FontSize', 9, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', iconFg, ...
                'BackgroundColor', iconBg, ...
                'Tag', 'InfoIconButton', ...
                'TooltipString', 'Widget info', ...
                'Callback', @(~,~) obj.openInfoPopup(widget, theme));
        end
    end
end
