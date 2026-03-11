classdef NavigatorOverlay < handle
    % NavigatorOverlay  Zoom rectangle, dimming, and drag interaction on navigator axes.
    %
    %   ov = NavigatorOverlay(hAxes)
    %
    %   Properties (read-only):
    %     hRegion, hDimLeft, hDimRight, hEdgeLeft, hEdgeRight — graphics handles
    %
    %   Methods:
    %     setRange(xMin, xMax) — update the visible region rectangle
    %     delete()             — clean up all handles and callbacks

    properties (SetAccess = private)
        hAxes           % Navigator axes handle
        hRegion         % Patch: semi-transparent rectangle over visible range
        hDimLeft        % Patch: gray overlay left of region
        hDimRight       % Patch: gray overlay right of region
        hEdgeLeft       % Line: left boundary grab handle
        hEdgeRight      % Line: right boundary grab handle
    end

    properties
        OnRangeChanged  % Callback: @(xMin, xMax)
    end

    properties (Access = private)
        hFig            % Parent figure handle
        DragState       % 'idle', 'panning', 'resizeLeft', 'resizeRight'
        DragStartX      % X position at drag start (data units)
        DragStartRange  % [xMin, xMax] at drag start
        CurrentRange    % [xMin, xMax] current visible range
        DataXLim        % [xMin, xMax] full data range (axes XLim at construction)
        MinWidthFrac    % Minimum region width as fraction of full range
        EdgeTolPx       % Edge hit tolerance in pixels
        EdgeTolData     % Edge hit tolerance in data units (recomputed on resize)
        RegionColor     % RGB for region patch
        DimColor        % RGB for dim patches
        DimAlpha        % Alpha for dim patches
        RegionAlpha     % Alpha for region patch
        OldWindowButtonDownFcn
        OldWindowButtonMotionFcn
        OldWindowButtonUpFcn
        OldResizeFcn
    end

    methods
        function obj = NavigatorOverlay(hAxes, varargin)
            obj.hAxes = hAxes;
            obj.hFig = ancestor(hAxes, 'figure');
            obj.DragState = 'idle';
            obj.MinWidthFrac = 0.005;  % 0.5% of range
            obj.EdgeTolPx = 12;
            obj.RegionColor = [0.2 0.4 0.8];
            obj.DimColor = [0.5 0.5 0.5];
            obj.DimAlpha = 0.4;
            obj.RegionAlpha = 0.15;
            obj.OnRangeChanged = [];

            obj.DataXLim = get(hAxes, 'XLim');
            yLim = get(hAxes, 'YLim');

            % Initialize patches — all start at zero width
            xL = obj.DataXLim(1);
            xR = obj.DataXLim(2);
            yB = yLim(1);
            yT = yLim(2);

            wasHeld = ishold(hAxes);
            hold(hAxes, 'on');

            % Dim left
            obj.hDimLeft = patch(hAxes, ...
                [xL xL xL xL], [yB yT yT yB], obj.DimColor, ...
                'FaceAlpha', obj.DimAlpha, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off', 'HitTest', 'off', 'PickableParts', 'none');

            % Dim right
            obj.hDimRight = patch(hAxes, ...
                [xR xR xR xR], [yB yT yT yB], obj.DimColor, ...
                'FaceAlpha', obj.DimAlpha, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off', 'HitTest', 'off', 'PickableParts', 'none');

            % Region highlight
            obj.hRegion = patch(hAxes, ...
                [xL xL xR xR], [yB yT yT yB], obj.RegionColor, ...
                'FaceAlpha', obj.RegionAlpha, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off', 'HitTest', 'off', 'PickableParts', 'none');

            % Edge lines
            obj.hEdgeLeft = line(hAxes, [xL xL], [yB yT], ...
                'Color', obj.RegionColor, 'LineWidth', 1.5, ...
                'HandleVisibility', 'off', 'HitTest', 'off', 'PickableParts', 'none');
            obj.hEdgeRight = line(hAxes, [xR xR], [yB yT], ...
                'Color', obj.RegionColor, 'LineWidth', 1.5, ...
                'HandleVisibility', 'off', 'HitTest', 'off', 'PickableParts', 'none');

            obj.CurrentRange = [xL xR];

            % Restore hold state
            if ~wasHeld; hold(hAxes, 'off'); end

            % Compute initial edge tolerance
            obj.recomputeEdgeTolerance();

            % Install mouse callbacks
            obj.installCallbacks();

            % Listen for figure resize to recompute edge tolerance
            obj.OldResizeFcn = get(obj.hFig, 'ResizeFcn');
            set(obj.hFig, 'ResizeFcn', @(s,e) obj.onFigureResize(s,e));
        end

        function setRange(obj, xMin, xMax)
            % Clamp to data limits
            xMin = max(xMin, obj.DataXLim(1));
            xMax = min(xMax, obj.DataXLim(2));

            % Enforce minimum width
            fullRange = obj.DataXLim(2) - obj.DataXLim(1);
            minWidth = fullRange * obj.MinWidthFrac;
            if (xMax - xMin) < minWidth
                mid = (xMin + xMax) / 2;
                xMin = mid - minWidth / 2;
                xMax = mid + minWidth / 2;
                % Re-clamp after expansion
                if xMin < obj.DataXLim(1)
                    xMin = obj.DataXLim(1);
                    xMax = xMin + minWidth;
                end
                if xMax > obj.DataXLim(2)
                    xMax = obj.DataXLim(2);
                    xMin = xMax - minWidth;
                end
            end

            obj.CurrentRange = [xMin xMax];
            obj.updatePatches();

            % Fire callback
            if ~isempty(obj.OnRangeChanged)
                obj.OnRangeChanged(xMin, xMax);
            end
        end

        function delete(obj)
            % Restore original figure callbacks unconditionally.
            % Old values may be '' (empty char) which isempty() considers
            % empty, so we must not guard with ~isempty.
            if ~isempty(obj.hFig) && ishandle(obj.hFig)
                set(obj.hFig, 'WindowButtonDownFcn', obj.OldWindowButtonDownFcn);
                set(obj.hFig, 'WindowButtonMotionFcn', obj.OldWindowButtonMotionFcn);
                set(obj.hFig, 'WindowButtonUpFcn', obj.OldWindowButtonUpFcn);
                if ~isempty(obj.OldResizeFcn)
                    set(obj.hFig, 'ResizeFcn', obj.OldResizeFcn);
                else
                    set(obj.hFig, 'ResizeFcn', '');
                end
            end

            % Delete graphics
            handles = [obj.hRegion, obj.hDimLeft, obj.hDimRight, obj.hEdgeLeft, obj.hEdgeRight];
            for h = handles
                if ~isempty(h) && ishandle(h)
                    delete(h);
                end
            end
        end
    end

    methods (Access = private)
        function updatePatches(obj)
            if ~ishandle(obj.hAxes); return; end

            yLim = get(obj.hAxes, 'YLim');
            yB = yLim(1);
            yT = yLim(2);
            xMin = obj.CurrentRange(1);
            xMax = obj.CurrentRange(2);
            xL = obj.DataXLim(1);
            xR = obj.DataXLim(2);

            % Update region
            set(obj.hRegion, 'XData', [xMin xMin xMax xMax], ...
                             'YData', [yB yT yT yB]);

            % Update dim left
            set(obj.hDimLeft, 'XData', [xL xL xMin xMin], ...
                              'YData', [yB yT yT yB]);

            % Update dim right
            set(obj.hDimRight, 'XData', [xMax xMax xR xR], ...
                               'YData', [yB yT yT yB]);

            % Update edge lines
            set(obj.hEdgeLeft, 'XData', [xMin xMin], 'YData', [yB yT]);
            set(obj.hEdgeRight, 'XData', [xMax xMax], 'YData', [yB yT]);
        end

        function recomputeEdgeTolerance(obj)
            if ~ishandle(obj.hAxes); return; end
            % Convert pixel tolerance to data units
            pos = getpixelposition(obj.hAxes);
            axesWidthPx = pos(3);
            dataRange = obj.DataXLim(2) - obj.DataXLim(1);
            if axesWidthPx > 0
                obj.EdgeTolData = obj.EdgeTolPx * (dataRange / axesWidthPx);
            else
                obj.EdgeTolData = dataRange * 0.01;
            end
        end

        function installCallbacks(obj)
            % Save existing callbacks to chain them
            obj.OldWindowButtonDownFcn = get(obj.hFig, 'WindowButtonDownFcn');
            obj.OldWindowButtonMotionFcn = get(obj.hFig, 'WindowButtonMotionFcn');
            obj.OldWindowButtonUpFcn = get(obj.hFig, 'WindowButtonUpFcn');

            set(obj.hFig, 'WindowButtonDownFcn', @(s,e) obj.onMouseDown(s,e));
            set(obj.hFig, 'WindowButtonMotionFcn', @(s,e) obj.onMouseMove(s,e));
            set(obj.hFig, 'WindowButtonUpFcn', @(s,e) obj.onMouseUp(s,e));
        end

        function onMouseDown(obj, src, evt)
            % Pixel-based hit test: verify click is actually on THIS axes
            % (CurrentPoint projects onto all axes, causing false positives
            % when multiple NavigatorOverlays share a figure)
            if ~obj.isClickOnMyAxes()
                % Not our axes — chain to old callback
                if ~isempty(obj.OldWindowButtonDownFcn) && isa(obj.OldWindowButtonDownFcn, 'function_handle')
                    obj.OldWindowButtonDownFcn(src, evt);
                end
                return;
            end

            % Get click position in navigator axes data coordinates
            cp = get(obj.hAxes, 'CurrentPoint');
            clickX = cp(1,1);

            xMin = obj.CurrentRange(1);
            xMax = obj.CurrentRange(2);
            tol = obj.EdgeTolData;

            if abs(clickX - xMin) <= tol
                % Left edge
                obj.DragState = 'resizeLeft';
                obj.DragStartX = clickX;
                obj.DragStartRange = obj.CurrentRange;
            elseif abs(clickX - xMax) <= tol
                % Right edge
                obj.DragState = 'resizeRight';
                obj.DragStartX = clickX;
                obj.DragStartRange = obj.CurrentRange;
            elseif clickX > xMin && clickX < xMax
                % Inside region — pan
                obj.DragState = 'panning';
                obj.DragStartX = clickX;
                obj.DragStartRange = obj.CurrentRange;
            else
                % Outside region — click to center
                width = xMax - xMin;
                newMin = clickX - width / 2;
                newMax = clickX + width / 2;
                obj.setRange(newMin, newMax);
                % Start panning from new position
                obj.DragState = 'panning';
                obj.DragStartX = clickX;
                obj.DragStartRange = obj.CurrentRange;
            end
        end

        function onMouseMove(obj, ~, ~)
            if strcmp(obj.DragState, 'idle'); return; end
            if ~ishandle(obj.hAxes); return; end

            cp = get(obj.hAxes, 'CurrentPoint');
            currentX = cp(1,1);
            deltaX = currentX - obj.DragStartX;

            switch obj.DragState
                case 'panning'
                    newMin = obj.DragStartRange(1) + deltaX;
                    newMax = obj.DragStartRange(2) + deltaX;
                    obj.setRange(newMin, newMax);

                case 'resizeLeft'
                    newMin = obj.DragStartRange(1) + deltaX;
                    obj.setRange(newMin, obj.DragStartRange(2));

                case 'resizeRight'
                    newMax = obj.DragStartRange(2) + deltaX;
                    obj.setRange(obj.DragStartRange(1), newMax);
            end
        end

        function onMouseUp(obj, ~, ~)
            obj.DragState = 'idle';
        end

        function hit = isClickOnMyAxes(obj)
            % Check if the current click is within this axes' pixel bounds.
            % This is essential when multiple overlays share a figure,
            % because get(ax, 'CurrentPoint') projects onto ALL axes.
            if ~ishandle(obj.hFig) || ~ishandle(obj.hAxes)
                hit = false;
                return;
            end
            figPt = get(obj.hFig, 'CurrentPoint');  % [x, y] in figure pixels
            axPos = getpixelposition(obj.hAxes, true);  % [l, b, w, h] relative to figure
            hit = figPt(1) >= axPos(1) && figPt(1) <= axPos(1) + axPos(3) && ...
                  figPt(2) >= axPos(2) && figPt(2) <= axPos(2) + axPos(4);
        end

        function onFigureResize(obj, src, evt)
            obj.recomputeEdgeTolerance();
            % Chain to old callback
            if ~isempty(obj.OldResizeFcn)
                if isa(obj.OldResizeFcn, 'function_handle')
                    obj.OldResizeFcn(src, evt);
                end
            end
        end
    end
end
