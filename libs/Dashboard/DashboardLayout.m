classdef DashboardLayout < handle
%DASHBOARDLAYOUT Manages 12-column responsive grid positioning.
%
%   Converts widget grid positions [col, row, width, height] to normalized
%   figure coordinates [x, y, w, h]. Handles overlap resolution and
%   row calculation.
%
%   Usage:
%     layout = DashboardLayout();
%     layout.ContentArea = [0.0 0.05 1.0 0.95];
%     layout.TotalRows = 4;
%     pos = layout.computePosition([1 1 6 2]);

    properties (Access = public)
        Columns     = 12
        TotalRows   = 4
        ContentArea = [0 0 1 1]
        Padding     = [0.02 0.02 0.02 0.02]
        GapH        = 0.008
        GapV        = 0.015
        Widgets     = {}
    end

    methods (Access = public)
        function obj = DashboardLayout(varargin)
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function pos = computePosition(obj, gridPos)
            col = gridPos(1);
            row = gridPos(2);
            wCols = gridPos(3);
            hRows = gridPos(4);

            ca = obj.ContentArea;
            padL = obj.Padding(1);
            padB = obj.Padding(2);
            padR = obj.Padding(3);
            padT = obj.Padding(4);

            totalW = ca(3) - padL - padR;
            totalH = ca(4) - padB - padT;

            cellW = (totalW - (obj.Columns - 1) * obj.GapH) / obj.Columns;
            cellH = (totalH - (obj.TotalRows - 1) * obj.GapV) / obj.TotalRows;

            x = ca(1) + padL + (col - 1) * (cellW + obj.GapH);
            y = ca(2) + padB + (obj.TotalRows - row - hRows + 1) * (cellH + obj.GapV);

            w = wCols * cellW + (wCols - 1) * obj.GapH;
            h = hRows * cellH + (hRows - 1) * obj.GapV;

            pos = [x, y, w, h];
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

        function createPanels(obj, hFigure, widgets, theme)
            obj.Widgets = widgets;
            obj.TotalRows = obj.calculateMaxRow(widgets);

            for i = 1:numel(widgets)
                w = widgets{i};
                pos = obj.computePosition(w.Position);
                hp = uipanel('Parent', hFigure, ...
                    'Units', 'normalized', ...
                    'Position', pos, ...
                    'BorderType', 'line', ...
                    'BorderWidth', theme.WidgetBorderWidth, ...
                    'HighlightColor', theme.WidgetBorderColor, ...
                    'BackgroundColor', theme.WidgetBackground);
                w.render(hp);
            end
        end
    end
end
