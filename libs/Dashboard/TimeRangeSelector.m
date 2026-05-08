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
        hEnvelope   = []   % single patch for aggregate min/max envelope (legacy)
        hPreviewLines = []  % array of line handles, one per widget preview
        hEventMarkers = []  % array of line handles, one per event marker
        hSelection  = []   % patch for selection rectangle
        hEdgeLeft   = []   % line: left drag handle
        hEdgeRight  = []   % line: right drag handle
        hLabelLeft  = []   % text object attached to left edge
        hLabelRight = []   % text object attached to right edge
        LeftLabelText  = ''
        RightLabelText = ''
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
            %   Programmatic — does NOT fire OnRangeChanged; only user
            %   drag interactions do.
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
            prev = obj.OnRangeChanged;
            obj.OnRangeChanged = [];
            cleanupCb = onCleanup(@() obj.restoreCallback_(prev));
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

        function setLabels(obj, leftText, rightText)
            %setLabels  Update the inline edge labels that track the selection.
            %   Pass empty strings to hide a side's label. The text sits at the
            %   mid-height of the selector, inside each edge handle.
            if nargin < 2 || isempty(leftText),  leftText  = ''; end
            if nargin < 3 || isempty(rightText), rightText = ''; end
            obj.LeftLabelText  = char(leftText);
            obj.RightLabelText = char(rightText);
            obj.redraw_();
        end

        function setEnvelope(obj, xC, yMin, yMax)
            %setEnvelope  (Legacy) Draw the aggregate min/max preview envelope.
            %   Kept for backward compat with tests. New code should prefer
            %   setPreviewLines for per-widget line previews.
            if isempty(xC) || isempty(yMin) || isempty(yMax)
                set(obj.hEnvelope, 'Visible', 'off');
                return;
            end
            xC = xC(:).'; yMin = yMin(:).'; yMax = yMax(:).';
            xv = [xC, fliplr(xC)];
            yv = [yMin, fliplr(yMax)];
            set(obj.hEnvelope, 'XData', xv, 'YData', yv, 'Visible', 'on');
        end

        function setPreviewLines(obj, lines)
            %setPreviewLines  Draw one downsampled line per widget preview.
            %   lines is a cell array of structs, each with fields x and y
            %   (equal-length row vectors; y already normalized to [0,1]).
            %   Each line is rendered with a distinct color from a fixed
            %   palette, placed behind the selection rectangle so drag
            %   interactions remain unaffected.
            % Clear previous preview lines.
            for k = 1:numel(obj.hPreviewLines)
                if ishandle(obj.hPreviewLines(k))
                    delete(obj.hPreviewLines(k));
                end
            end
            obj.hPreviewLines = [];
            % Hide the legacy envelope patch.
            set(obj.hEnvelope, 'Visible', 'off');
            if isempty(lines), return; end
            palette = [ ...
                0.00 0.45 0.70    % blue
                0.90 0.40 0.20    % orange
                0.20 0.60 0.20    % green
                0.70 0.20 0.50    % purple
                0.85 0.70 0.20    % mustard
                0.30 0.70 0.70    % teal
                0.70 0.30 0.30]; % brick
            handles = [];
            for i = 1:numel(lines)
                L = lines{i};
                if ~isstruct(L) || ~isfield(L, 'x') || ~isfield(L, 'y'), continue; end
                if isempty(L.x) || isempty(L.y) || numel(L.x) ~= numel(L.y), continue; end
                c = palette(mod(i - 1, size(palette, 1)) + 1, :);
                h = line(obj.hAxes, L.x(:).', L.y(:).', ...
                    'Color', c, 'LineWidth', 1, ...
                    'HitTest', 'off', 'PickableParts', 'none');
                handles(end + 1) = h; %#ok<AGROW>
            end
            obj.hPreviewLines = handles;
            % Send preview lines to the BACK so the selection patch, edges,
            % and labels stay on top. Works in MATLAB and Octave.
            if ~isempty(handles) && ishandle(obj.hAxes)
                ch = get(obj.hAxes, 'Children');
                mask = true(size(ch));
                for k = 1:numel(handles)
                    mask(ch == handles(k)) = false;
                end
                others = ch(mask);
                set(obj.hAxes, 'Children', [others(:); handles(:)]);
            end
        end

        function setEventMarkers(obj, times, colors)
            %setEventMarkers  Draw a faint full-height line per event time.
            %   setEventMarkers(times) clears any existing markers and draws
            %   one vertical line per finite time in `times`. Non-finite
            %   values (NaN, +/-Inf) are silently dropped. Empty input just
            %   clears the markers.
            %
            %   setEventMarkers(times, colors) accepts an optional Nx3 RGB
            %   matrix index-matched to `times`. Each row supplies the base
            %   color for the marker at the corresponding time; the same
            %   35/65 AxesColor blend used by the uniform path is applied
            %   per-row to preserve the translucent feel. If `colors` is
            %   omitted or empty, the existing uniform path runs unchanged
            %   (no behavior change for legacy 1-arg callers). Size mismatch
            %   between `times` and `colors` triggers a one-shot
            %   `TimeRangeSelector:colorSizeMismatch` warning and a
            %   fallback to the uniform path.
            %
            %   Markers are purely visual — they have HitTest='off' and
            %   PickableParts='none' so they never intercept drag/pan/resize
            %   of the selection window. They are sent to the BACK of the
            %   axes children list so the selection patch, edges, and labels
            %   remain visible on top.
            %
            %   For MATLAB/Octave parity we do NOT use an RGBA 4-tuple on
            %   Color (Octave 7 support is inconsistent). Instead the marker
            %   colour is blended toward the theme's AxesColor to produce a
            %   near-background shade that reads as translucent.
            %
            %   Z-order note: this method (and setPreviewLines) both push their
            %   handles to the BACK of hAxes.Children. Whichever is called
            %   *last* ends up furthest back. DashboardEngine calls
            %   computePreviewEnvelope BEFORE computeEventMarkers at every
            %   hook site, so markers sit behind preview lines, and both sit
            %   behind the selection patch + edges + labels. If you swap that
            %   order in DashboardEngine, markers will appear in front of the
            %   preview envelope.
            % Clear previous marker handles.
            for k = 1:numel(obj.hEventMarkers)
                if ishandle(obj.hEventMarkers(k))
                    delete(obj.hEventMarkers(k));
                end
            end
            obj.hEventMarkers = [];
            if nargin < 2 || isempty(times)
                return;
            end
            timesIn = times(:).';
            finiteMask = isfinite(timesIn);
            times = timesIn(finiteMask);
            if isempty(times)
                return;
            end

            % Decide whether the per-event-color path is engaged.
            usePerColor = false;
            if nargin >= 3 && ~isempty(colors)
                if isnumeric(colors) && ismatrix(colors) && size(colors, 2) == 3 ...
                        && size(colors, 1) == numel(timesIn) && all(isfinite(colors(:)))
                    % Apply the SAME finite mask used on `times` so colors
                    % stay index-matched after dropping NaN/Inf entries.
                    colors = colors(finiteMask, :);
                    usePerColor = true;
                else
                    warning('TimeRangeSelector:colorSizeMismatch', ...
                        'colors must be an Nx3 finite numeric matrix matched to times; falling back to uniform.');
                end
            end

            % Derive uniform marker colour from theme (foreground/toolbar
            % font) and blend toward the axes background to get a
            % translucent feel. Used both for the legacy 1-arg path and as
            % the fallback when the colors argument is missing/invalid.
            markerColor = [0.55 0.55 0.55];
            if isstruct(obj.Theme) && isfield(obj.Theme, 'ToolbarFontColor')
                markerColor = obj.Theme.ToolbarFontColor;
            end
            haveBg = isstruct(obj.Theme) && isfield(obj.Theme, 'AxesColor');
            if haveBg
                bg = obj.Theme.AxesColor;
                try
                    markerColor = 0.35 * markerColor + 0.65 * bg;
                catch
                    haveBg = false; % defensive — bg malformed
                end
            end

            handles = [];
            for i = 1:numel(times)
                t = times(i);
                if usePerColor
                    lineColor = colors(i, :);
                    if haveBg
                        % Same 35/65 blend the uniform path applies, just
                        % per-row instead of once.
                        lineColor = 0.35 * lineColor + 0.65 * bg;
                    end
                else
                    lineColor = markerColor;
                end
                h = line(obj.hAxes, [t t], [0 1], ...
                    'Color', lineColor, 'LineWidth', 1, ...
                    'HitTest', 'off', 'PickableParts', 'none');
                handles(end + 1) = h; %#ok<AGROW>
            end
            obj.hEventMarkers = handles;
            % Send markers to the BACK so the selection patch, edges, and
            % labels stay on top. Works in MATLAB and Octave.
            if ~isempty(handles) && ishandle(obj.hAxes)
                ch = get(obj.hAxes, 'Children');
                mask = true(size(ch));
                for k = 1:numel(handles)
                    mask(ch == handles(k)) = false;
                end
                others = ch(mask);
                set(obj.hAxes, 'Children', [others(:); handles(:)]);
            end
        end

        function delete(obj)
            %delete  Restore figure WindowButton* callbacks saved at construction.
            obj.restoreCallbacks_();
        end
    end

    methods (Access = private)
        function restoreCallback_(obj, cb)
            %restoreCallback_  Restore OnRangeChanged after temporary suppression.
            %   isvalid() on a classdef handle is not implemented in Octave 7+;
            %   wrap in try/catch matching the EventViewer pattern.
            try
                if isvalid(obj)
                    obj.OnRangeChanged = cb;
                end
            catch
                % Octave: isvalid() unsupported for classdef handles.
                % Restore unconditionally — if obj is deleted, the assignment
                % is a no-op since the handle is invalid.
                try
                    obj.OnRangeChanged = cb;
                catch
                end
            end
        end

        function buildGraphics_(obj)
            %buildGraphics_  Construct axes and graphics handles inside hPanel.
            obj.hAxes = axes('Parent', obj.hPanel, ...
                'Units', 'normalized', ...
                'Position', [0.045 0.1 0.94 0.85], ...
                'XTick', [], 'YTick', [], ...
                'Box', 'on', ...
                'YLim', [0 1], 'XLim', obj.DataRange + [-1, 1] * 0.05 * (obj.DataRange(2) - obj.DataRange(1)));
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
            % Edge-tracking time labels: small text objects that follow
            % the selection edges as the user drags. Positioned at the
            % middle of the selector height; anchored so they sit to the
            % right of the left handle and to the left of the right handle.
            labelColor = envColor;
            obj.hLabelLeft = text(obj.hAxes, 0, 0.5, '', ...
                'Color', labelColor, 'FontSize', 9, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
                'BackgroundColor', 'none', ...
                'HitTest', 'off', 'PickableParts', 'none');
            obj.hLabelRight = text(obj.hAxes, 0, 0.5, '', ...
                'Color', labelColor, 'FontSize', 9, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
                'BackgroundColor', 'none', ...
                'HitTest', 'off', 'PickableParts', 'none');
        end

        function redraw_(obj)
            %redraw_  Push current DataRange/Selection to the graphics handles.
            %   Pads the axes XLim with 5% of the span on each side so the
            %   selection window's edge handles remain visible even when the
            %   selection equals the full DataRange.
            if ~ishandle(obj.hAxes), return; end
            span = obj.DataRange(2) - obj.DataRange(1);
            pad = span * 0.05;
            set(obj.hAxes, 'XLim', [obj.DataRange(1) - pad, obj.DataRange(2) + pad]);
            xL = obj.Selection(1); xR = obj.Selection(2);
            set(obj.hSelection, 'XData', [xL xL xR xR], 'YData', [0 1 1 0]);
            set(obj.hEdgeLeft,  'XData', [xL xL], 'YData', [0 1]);
            set(obj.hEdgeRight, 'XData', [xR xR], 'YData', [0 1]);
            % Place edge labels just inside each selection edge so they
            % stay visible even when the selection is at the full range.
            if ishandle(obj.hLabelLeft)
                set(obj.hLabelLeft, 'Position', [xL, 0.5, 0], ...
                    'String', obj.LeftLabelText);
            end
            if ishandle(obj.hLabelRight)
                set(obj.hLabelRight, 'Position', [xR, 0.5, 0], ...
                    'String', obj.RightLabelText);
            end
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
            % Map the axes-relative fraction through the CURRENT XLim —
            % not DataRange — because redraw_ pads the XLim by 5% on each
            % side to keep edge handles visually accessible. Using
            % DataRange here would misalign hit-testing with the rendered
            % selection rectangle.
            xl = get(obj.hAxes, 'XLim');
            xData = xl(1) + frac * (xl(2) - xl(1));
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
