classdef TimeRangeSelector < handle
    %TimeRangeSelector  Single-window time-range selector with data-preview envelope.
    %
    %   selector = TimeRangeSelector(hPanel) attaches a time-range selector to a
    %   uipanel. The selector owns its own axes inside the panel and draws:
    %
    %       * an (optional) aggregate min/max envelope patch behind the selection,
    %       * a semi-transparent selection rectangle that can be panned by dragging
    %         its middle and resized by dragging either of its two edge handles,
    %       * two line handles at the left and right edges of the selection window.
    %
    %   Interaction uses figure-level WindowButton{Down,Motion,Up}Fcn. Any previously
    %   installed callbacks are saved on construction and restored on delete().
    %
    %   Usage (the contract plan 03 uses to wire this into DashboardEngine):
    %
    %       selector = TimeRangeSelector(hPanel, ...
    %           'OnRangeChanged', @(tStart, tEnd) onRangeChanged(tStart, tEnd), ...
    %           'Theme',          themeStruct);
    %       selector.setDataRange(tMin, tMax);        % full extent user can scrub
    %       selector.setSelection(tStart, tEnd);      % fires OnRangeChanged
    %       selector.setEnvelope(xC, yMin, yMax);     % optional preview
    %       [tS, tE] = selector.getSelection();
    %       delete(selector);                         % restores figure callbacks
    %
    %   Properties (public, configurable):
    %       OnRangeChanged  Function handle @(tStart, tEnd). May be [].
    %       Theme           Theme struct (or []).
    %       MinWidthFrac    Minimum selection width as fraction of DataRange span.
    %       EdgeTolPx       Pixel tolerance for edge hit-testing.
    %
    %   Properties (read-only, set internally):
    %       hPanel, hFigure, hAxes, hEnvelope, hSelection, hEdgeLeft, hEdgeRight
    %       DataRange       1x2 [tMin tMax].
    %       Selection       1x2 [tStart tEnd].
    %       DragState       'idle' | 'panning' | 'resizeLeft' | 'resizeRight'.
    %
    %   Methods:
    %       setDataRange(tMin, tMax)         Set full extent; rescales selection.
    %       setSelection(tStart, tEnd)       Set/clamp/reorder selection; fires callback.
    %       getSelection()                   Return [tStart, tEnd].
    %       setEnvelope(xC, yMin, yMax)      Update or hide aggregate envelope.
    %       delete()                         Restore saved figure callbacks.
    %
    %   Compatible with MATLAB R2020b+ and Octave 7+ (D-11): uses only axes, patch,
    %   line, uipanel primitives and WindowButton{Down,Motion,Up}Fcn — no
    %   matlab.graphics.*, no uifigure/uiaxes, no addlistener on primitive properties.
    %
    %   See also DashboardEngine, DashboardTheme, FastSenseWidget.

    properties (Access = public)
        OnRangeChanged = []    % function handle @(tStart, tEnd)
        Theme          = []    % struct from DashboardTheme, or []
        MinWidthFrac   = 0.005 % minimum selection width as fraction of DataRange span
        EdgeTolPx      = 10    % pixel tolerance for edge hit-test
    end

    properties (SetAccess = private)
        hPanel      = []   % parent uipanel
        hFigure     = []   % ancestor figure
        hAxes       = []
        hEnvelope   = []   % single patch for aggregate min/max envelope
        hSelection  = []   % patch for selection rectangle
        hEdgeLeft   = []   % line: left drag handle
        hEdgeRight  = []   % line: right drag handle
        DataRange   = [0 1]
        Selection   = [0 1]
        DragState   = 'idle'       % 'idle' | 'panning' | 'resizeLeft' | 'resizeRight'
        DragStartX  = []           % axes-data-units at drag start
        DragStartSel = []
    end

    properties (Access = private)
        OldWindowButtonDownFcn   = []
        OldWindowButtonMotionFcn = []
        OldWindowButtonUpFcn     = []
        % NOTE: No OldResizeFcn. Resize events are not observed by this class —
        % all pixel/data conversions are computed on demand from current geometry,
        % so there is no cached resize-dependent state to invalidate.
    end

    methods (Access = public)
        function obj = TimeRangeSelector(hPanel, varargin)
            %TimeRangeSelector  Construct a selector attached to a uipanel.
            if nargin < 1 || isempty(hPanel) || ~ishandle(hPanel)
                error('TimeRangeSelector:invalidPanel', ...
                      'First argument must be a valid uipanel handle.');
            end
            obj.hPanel = hPanel;
            obj.hFigure = ancestor(hPanel, 'figure');
            for k = 1:2:numel(varargin)
                key = varargin{k};
                if ischar(key)
                    keyStr = key;
                    isKnown = isprop(obj, key);
                else
                    keyStr = '<non-string>';
                    isKnown = false;
                end
                if ~isKnown
                    error('TimeRangeSelector:invalidOption', ...
                          'Unknown option ''%s''.', keyStr);
                end
                obj.(key) = varargin{k+1};
            end
            obj.buildGraphics_();
            obj.installCallbacks_();
            obj.redraw_();
        end

        function setDataRange(obj, tMin, tMax)
            %setDataRange  Set the full extent the user can scrub over.
            %   The current selection is rescaled proportionally so that a
            %   50%-selected window remains 50% wide after the change.
            if ~(isfinite(tMin) && isfinite(tMax)) || tMax <= tMin
                error('TimeRangeSelector:invalidRange', ...
                      'DataRange requires finite tMax > tMin.');
            end
            oldSpan = obj.DataRange(2) - obj.DataRange(1);
            if oldSpan > 0
                frac0 = (obj.Selection(1) - obj.DataRange(1)) / oldSpan;
                frac1 = (obj.Selection(2) - obj.DataRange(1)) / oldSpan;
            else
                frac0 = 0; frac1 = 1;
            end
            obj.DataRange = [tMin tMax];
            newSpan = tMax - tMin;
            obj.setSelection(tMin + frac0 * newSpan, tMin + frac1 * newSpan);
        end

        function setSelection(obj, tStart, tEnd)
            %setSelection  Update the selection window, clamping and reordering.
            %   Swapped inputs (tStart > tEnd) are reordered. Values outside
            %   DataRange are clamped. Widths smaller than MinWidthFrac * span
            %   are widened around the requested midpoint. Fires OnRangeChanged
            %   with the final [tStart, tEnd] (if the callback is set).
            % Reorder swapped bounds (tStart < tEnd).
            if tStart > tEnd
                tmp = tStart; tStart = tEnd; tEnd = tmp;
            end
            % Clamp to DataRange.
            tStart = max(tStart, obj.DataRange(1));
            tEnd   = min(tEnd,   obj.DataRange(2));
            % Enforce minimum width.
            span = obj.DataRange(2) - obj.DataRange(1);
            minW = obj.MinWidthFrac * span;
            if (tEnd - tStart) < minW
                mid = (tStart + tEnd) / 2;
                tStart = max(obj.DataRange(1), mid - minW/2);
                tEnd   = min(obj.DataRange(2), tStart + minW);
                if tEnd > obj.DataRange(2)
                    tEnd = obj.DataRange(2);
                    tStart = tEnd - minW;
                end
            end
            obj.Selection = [tStart tEnd];
            obj.redraw_();
            if ~isempty(obj.OnRangeChanged)
                try
                    feval(obj.OnRangeChanged, tStart, tEnd);
                catch err
                    warning('TimeRangeSelector:callbackFailed', ...
                            'OnRangeChanged callback failed: %s', err.message);
                end
            end
        end

        function [tStart, tEnd] = getSelection(obj)
            %getSelection  Return the current selection as [tStart, tEnd].
            tStart = obj.Selection(1);
            tEnd   = obj.Selection(2);
        end

        function setEnvelope(obj, xC, yMin, yMax)
            %setEnvelope  Draw the aggregate min/max preview envelope.
            %   xC, yMin, yMax must be equal-length vectors. Passing any empty
            %   vector hides the envelope patch.
            if isempty(xC) || isempty(yMin) || isempty(yMax)
                set(obj.hEnvelope, 'Visible', 'off');
                return;
            end
            xC = xC(:).'; yMin = yMin(:).'; yMax = yMax(:).';
            xv = [xC, fliplr(xC)];
            yv = [yMin, fliplr(yMax)];
            set(obj.hEnvelope, 'XData', xv, 'YData', yv, 'Visible', 'on');
        end

        function delete(obj)
            %delete  Restore figure WindowButton* callbacks saved at construction.
            obj.restoreCallbacks_();
        end
    end

    methods (Access = private)
        function buildGraphics_(obj)
            %buildGraphics_  Construct axes and graphics handles inside hPanel.
            obj.hAxes = axes('Parent', obj.hPanel, ...
                'Units', 'normalized', ...
                'Position', [0.045 0.1 0.94 0.85], ...
                'XTick', [], 'YTick', [], ...
                'Box', 'on', ...
                'YLim', [0 1], 'XLim', obj.DataRange);
            hold(obj.hAxes, 'on');
            envColor = [0.55 0.55 0.55];
            selColor = [0.2 0.4 0.8];
            if isstruct(obj.Theme)
                % Reuse theme tokens if available; fall back to defaults.
                if isfield(obj.Theme, 'ToolbarFontColor')
                    envColor = obj.Theme.ToolbarFontColor;
                end
            end
            obj.hEnvelope  = patch(obj.hAxes, NaN, NaN, envColor, ...
                'FaceAlpha', 0.25, 'EdgeColor', 'none', ...
                'HitTest', 'off', 'PickableParts', 'none', 'Visible', 'off');
            obj.hSelection = patch(obj.hAxes, NaN, NaN, selColor, ...
                'FaceAlpha', 0.20, 'EdgeColor', 'none', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hEdgeLeft  = line(obj.hAxes, [NaN NaN], [0 1], ...
                'Color', selColor, 'LineWidth', 2, ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hEdgeRight = line(obj.hAxes, [NaN NaN], [0 1], ...
                'Color', selColor, 'LineWidth', 2, ...
                'HitTest', 'off', 'PickableParts', 'none');
        end

        function redraw_(obj)
            %redraw_  Push current DataRange/Selection to the graphics handles.
            if ~ishandle(obj.hAxes), return; end
            set(obj.hAxes, 'XLim', obj.DataRange);
            xL = obj.Selection(1); xR = obj.Selection(2);
            set(obj.hSelection, 'XData', [xL xL xR xR], 'YData', [0 1 1 0]);
            set(obj.hEdgeLeft,  'XData', [xL xL], 'YData', [0 1]);
            set(obj.hEdgeRight, 'XData', [xR xR], 'YData', [0 1]);
        end

        function installCallbacks_(obj)
            %installCallbacks_  Save and replace figure WindowButton* callbacks.
            obj.OldWindowButtonDownFcn   = get(obj.hFigure, 'WindowButtonDownFcn');
            obj.OldWindowButtonMotionFcn = get(obj.hFigure, 'WindowButtonMotionFcn');
            obj.OldWindowButtonUpFcn     = get(obj.hFigure, 'WindowButtonUpFcn');
            set(obj.hFigure, 'WindowButtonDownFcn',   @(~,~) obj.onButtonDown_());
            set(obj.hFigure, 'WindowButtonMotionFcn', @(~,~) obj.onButtonMotion_());
            set(obj.hFigure, 'WindowButtonUpFcn',     @(~,~) obj.onButtonUp_());
        end

        function restoreCallbacks_(obj)
            %restoreCallbacks_  Restore previously-saved figure WindowButton* callbacks.
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                set(obj.hFigure, 'WindowButtonDownFcn',   obj.OldWindowButtonDownFcn);
                set(obj.hFigure, 'WindowButtonMotionFcn', obj.OldWindowButtonMotionFcn);
                set(obj.hFigure, 'WindowButtonUpFcn',     obj.OldWindowButtonUpFcn);
            end
        end

        function [inAxes, xData] = pointerInAxes_(obj)
            %pointerInAxes_  Convert figure CurrentPoint to axes data units.
            %   Returns inAxes=false if the pointer is outside the axes'
            %   normalized bounding box. Works in both MATLAB and Octave by
            %   normalizing the figure units on demand.
            cp = get(obj.hFigure, 'CurrentPoint');           % figure units
            figUnits = get(obj.hFigure, 'Units');
            % Get axes position in figure-normalized coords.
            oldUnitsA = get(obj.hAxes, 'Units');
            set(obj.hAxes, 'Units', 'normalized');
            axPos = get(obj.hAxes, 'Position');              % relative to parent panel
            set(obj.hAxes, 'Units', oldUnitsA);
            % Compose panel position into figure coords.
            oldUnitsP = get(obj.hPanel, 'Units');
            set(obj.hPanel, 'Units', 'normalized');
            pnPos = get(obj.hPanel, 'Position');
            set(obj.hPanel, 'Units', oldUnitsP);
            axX = pnPos(1) + axPos(1) * pnPos(3);
            axY = pnPos(2) + axPos(2) * pnPos(4);
            axW = axPos(3) * pnPos(3);
            axH = axPos(4) * pnPos(4);
            fx = cp(1); fy = cp(2);
            % fig units may be pixels; normalize if so.
            if ~strcmp(figUnits, 'normalized')
                oldUnitsF = get(obj.hFigure, 'Units');
                set(obj.hFigure, 'Units', 'normalized');
                cpN = get(obj.hFigure, 'CurrentPoint');
                set(obj.hFigure, 'Units', oldUnitsF);
                fx = cpN(1); fy = cpN(2);
            end
            inAxes = (fx >= axX) && (fx <= axX + axW) && ...
                     (fy >= axY) && (fy <= axY + axH);
            frac = 0;
            if axW > 0
                frac = (fx - axX) / axW;
            end
            xData = obj.DataRange(1) + frac * (obj.DataRange(2) - obj.DataRange(1));
        end

        function tolData = edgeTolData_(obj)
            %edgeTolData_  Convert EdgeTolPx to data units for current figure size.
            oldUnits = get(obj.hFigure, 'Units');
            set(obj.hFigure, 'Units', 'pixels');
            figPx = get(obj.hFigure, 'Position');
            set(obj.hFigure, 'Units', oldUnits);
            oldUnitsA = get(obj.hAxes, 'Units');
            set(obj.hAxes, 'Units', 'normalized');
            axPos = get(obj.hAxes, 'Position');
            set(obj.hAxes, 'Units', oldUnitsA);
            oldUnitsP = get(obj.hPanel, 'Units');
            set(obj.hPanel, 'Units', 'normalized');
            pnPos = get(obj.hPanel, 'Position');
            set(obj.hPanel, 'Units', oldUnitsP);
            axWpx = axPos(3) * pnPos(3) * figPx(3);
            span  = obj.DataRange(2) - obj.DataRange(1);
            if axWpx <= 0
                tolData = span * 0.01;
            else
                tolData = (obj.EdgeTolPx / axWpx) * span;
            end
        end

        function onButtonDown_(obj)
            %onButtonDown_  Begin a drag if the pointer is inside the axes.
            [inAxes, xData] = obj.pointerInAxes_();
            if ~inAxes
                return;
            end
            if strcmp(get(obj.hFigure, 'SelectionType'), 'open')
                % Double-click resets to full range.
                obj.setSelection(obj.DataRange(1), obj.DataRange(2));
                return;
            end
            tol = obj.edgeTolData_();
            xL = obj.Selection(1); xR = obj.Selection(2);
            if abs(xData - xL) <= tol
                obj.DragState = 'resizeLeft';
            elseif abs(xData - xR) <= tol
                obj.DragState = 'resizeRight';
            elseif xData > xL && xData < xR
                obj.DragState = 'panning';
            else
                return;
            end
            obj.DragStartX   = xData;
            obj.DragStartSel = obj.Selection;
        end

        function onButtonMotion_(obj)
            %onButtonMotion_  Dispatch an in-flight drag to resize or pan.
            if strcmp(obj.DragState, 'idle')
                return;
            end
            [~, xData] = obj.pointerInAxes_();
            dx = xData - obj.DragStartX;
            s0 = obj.DragStartSel;
            switch obj.DragState
                case 'resizeLeft'
                    obj.setSelection(s0(1) + dx, s0(2));
                case 'resizeRight'
                    obj.setSelection(s0(1), s0(2) + dx);
                case 'panning'
                    width = s0(2) - s0(1);
                    newStart = s0(1) + dx;
                    newStart = max(obj.DataRange(1), min(newStart, obj.DataRange(2) - width));
                    obj.setSelection(newStart, newStart + width);
            end
        end

        function onButtonUp_(obj)
            %onButtonUp_  End the current drag and reset drag-start caches.
            obj.DragState = 'idle';
            obj.DragStartX = [];
            obj.DragStartSel = [];
        end
    end
end
