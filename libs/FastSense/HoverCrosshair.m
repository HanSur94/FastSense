classdef HoverCrosshair < handle
    %HOVERCROSSHAIR Hover-driven vertical crosshair + multi-line datatip for FastSense.
    %
    %   hc = HOVERCROSSHAIR(fp) attaches a hover crosshair to a rendered
    %   FastSense instance fp. While the mouse is over fp.hAxes, a vertical
    %   line tracks the cursor's x position and a small datatip near the
    %   cursor shows the formatted x value plus one row per visible line
    %   (DisplayName + interpolated y at hovered x via binary_search).
    %
    %   The handler is *chained*: any pre-existing WindowButtonMotionFcn
    %   on the figure is preserved and invoked first on every motion event,
    %   so this class coexists with other hover-driven features
    %   (FastSenseToolbar crosshair toggle, NavigatorOverlay drag, etc.).
    %
    %   Properties (read-only):
    %     Target           — FastSense instance
    %     hFigure, hAxes   — cached graphics handles
    %     hLineV           — vertical crosshair line
    %     hTipBox          — text annotation acting as datatip box
    %
    %   Methods:
    %     onMove(xQuery)   — update + show crosshair at xQuery (data coords)
    %     onLeave()        — hide crosshair + datatip
    %     delete()         — restore prior WindowButtonMotionFcn and clean up
    %
    %   Coexistence with FastSenseToolbar:
    %     The toolbar's setCrosshair() also swaps WindowButtonMotionFcn at
    %     activation. Because we only chain whatever handler was installed
    %     when our constructor ran, when the toolbar later overwrites the
    %     callback our hover handler is temporarily detached (toolbar mode
    %     wins). When the toolbar deactivates and restores its saved
    %     callback (which is *our* chained handler), hover resumes
    %     automatically.
    %
    %   See also FastSense, FastSenseToolbar, NavigatorOverlay.

    properties (SetAccess = private)
        Target          = []  % FastSense instance (handle)
        hFigure         = []  % cached figure handle
        hAxes           = []  % cached axes handle
        hLineV          = []  % vertical crosshair line
        hTipBox         = []  % datatip text annotation
    end

    properties (Access = private)
        PrevWBMFcn_     = []   % saved WindowButtonMotionFcn (function handle, '' or [])
        LastUpdateTime  = []   % tic timestamp for throttling (~40 Hz cap)
        IsBusy          = false % re-entrancy guard for onFigureMove_
        FigDeleteListener = []  % listener handle on figure ObjectBeingDestroyed
        AxDeleteListener  = []  % listener handle on axes ObjectBeingDestroyed
        ThrottleSeconds = 0.025 % minimum interval between motion-driven updates
    end

    methods (Access = public)
        function obj = HoverCrosshair(fp)
            %HOVERCROSSHAIR Construct hover crosshair attached to a FastSense.
            %   hc = HOVERCROSSHAIR(fp) requires fp to be a rendered FastSense
            %   handle. Throws HoverCrosshair:invalidTarget if not.

            if nargin < 1 || ~isa(fp, 'FastSense')
                error('HoverCrosshair:invalidTarget', ...
                    'HoverCrosshair requires a FastSense instance.');
            end
            if ~fp.IsRendered
                error('HoverCrosshair:notRendered', ...
                    'FastSense must be rendered before attaching HoverCrosshair.');
            end
            if isempty(fp.hAxes) || ~ishandle(fp.hAxes)
                error('HoverCrosshair:invalidAxes', ...
                    'FastSense.hAxes is empty or invalid.');
            end

            obj.Target  = fp;
            obj.hAxes   = fp.hAxes;
            obj.hFigure = ancestor(fp.hAxes, 'figure');
            if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
                error('HoverCrosshair:noFigure', ...
                    'Could not resolve ancestor figure for FastSense axes.');
            end

            % Save existing handler (may be '' or function_handle) so we can
            % restore it on delete and chain to it on each motion event.
            obj.PrevWBMFcn_ = get(obj.hFigure, 'WindowButtonMotionFcn');

            % Pre-create graphics (Visible='off' until first onMove).
            obj.createGraphics_();

            % Install chained motion handler.
            set(obj.hFigure, 'WindowButtonMotionFcn', ...
                @(s,e) obj.onFigureMove_(s, e));

            % Listen for figure / axes destruction so we can self-clean up.
            try %#ok<TRYNC>
                obj.FigDeleteListener = addlistener(obj.hFigure, ...
                    'ObjectBeingDestroyed', @(~,~) obj.onTargetDestroyed_());
            end
            try %#ok<TRYNC>
                obj.AxDeleteListener = addlistener(obj.hAxes, ...
                    'ObjectBeingDestroyed', @(~,~) obj.onTargetDestroyed_());
            end
        end

        function onMove(obj, xQuery)
            %ONMOVE Update + show the crosshair at data x-coordinate xQuery.
            %   Public so tests can drive motion deterministically without
            %   needing real mouse input.
            if ~isvalid(obj); return; end
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes); return; end
            if isempty(obj.hLineV) || ~ishandle(obj.hLineV); return; end
            if isempty(obj.hTipBox) || ~ishandle(obj.hTipBox); return; end

            fp = obj.Target;
            if isempty(fp) || ~isvalid(fp); return; end

            yLim = get(obj.hAxes, 'YLim');
            xLim = get(obj.hAxes, 'XLim');

            % Update vertical line
            set(obj.hLineV, 'XData', [xQuery xQuery], 'YData', yLim, ...
                'Visible', 'on');

            % Build tip rows
            xType = fp.XType;
            try
                header = FastSenseToolbar.formatX(xQuery, xType);
            catch
                header = sprintf('%.6g', xQuery);
            end

            % Theme colors needed early for the foreground TeX color reset
            theme = fp.Theme;
            [bgColor, fgColor, edgeColor, fontName, fontSize] = ...
                obj.themeColors_(theme);

            nLines = numel(fp.Lines);
            rows = cell(1, nLines + 1);
            rows{1} = header;
            for i = 1:nLines
                lineRec = fp.Lines(i);
                yStr = obj.computeYAtX_(lineRec, xQuery);
                displayName = obj.lineDisplayName_(lineRec, i);
                lineColor = obj.resolveLineColor_(lineRec, fgColor);
                % TeX interpreter: colored bullet then reset to fg color.
                rows{i + 1} = sprintf( ...
                    '\\color[rgb]{%.4f,%.4f,%.4f}\\bullet \\color[rgb]{%.4f,%.4f,%.4f}%s: %s', ...
                    lineColor(1), lineColor(2), lineColor(3), ...
                    fgColor(1), fgColor(2), fgColor(3), ...
                    obj.escapeTeX_(displayName), yStr);
            end

            % Position the tip box. Use a small offset (~3% of axes width)
            % so it does not sit directly on top of the cursor.
            xRange = xLim(2) - xLim(1);
            yRange = yLim(2) - yLim(1);
            if xRange <= 0; xRange = 1; end
            if yRange <= 0; yRange = 1; end
            offX = 0.02 * xRange;
            offY = 0.04 * yRange;

            % Flip horizontal alignment when datatip would overflow right edge
            tipX = xQuery + offX;
            horizAlign = 'left';
            if tipX > xLim(1) + 0.65 * xRange
                tipX = xQuery - offX;
                horizAlign = 'right';
            end
            tipY = yLim(2) - offY;

            try
                set(obj.hTipBox, ...
                    'Position', [tipX, tipY, 0], ...
                    'String', rows, ...
                    'Interpreter', 'tex', ...
                    'Color', fgColor, ...
                    'BackgroundColor', bgColor, ...
                    'EdgeColor', edgeColor, ...
                    'FontName', fontName, ...
                    'FontSize', fontSize, ...
                    'HorizontalAlignment', horizAlign, ...
                    'VerticalAlignment', 'top', ...
                    'Margin', 4, ...
                    'Visible', 'on');
            catch
                % Some Octave configurations don't support all text props
                set(obj.hTipBox, ...
                    'Position', [tipX, tipY, 0], ...
                    'String', rows, ...
                    'Visible', 'on');
            end
        end

        function onLeave(obj)
            %ONLEAVE Hide the crosshair line + datatip.
            if ~isvalid(obj); return; end
            if ~isempty(obj.hLineV) && ishandle(obj.hLineV)
                set(obj.hLineV, 'Visible', 'off');
            end
            if ~isempty(obj.hTipBox) && ishandle(obj.hTipBox)
                set(obj.hTipBox, 'Visible', 'off');
            end
        end

        function delete(obj)
            %DELETE Restore prior WindowButtonMotionFcn and remove graphics.
            % Restore unconditionally — '' is a legal callback value, so
            % we must NOT guard with ~isempty(PrevWBMFcn_).
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                try %#ok<TRYNC>
                    set(obj.hFigure, 'WindowButtonMotionFcn', obj.PrevWBMFcn_);
                end
            end

            % Delete graphics
            if ~isempty(obj.hLineV) && ishandle(obj.hLineV)
                try delete(obj.hLineV); catch; end %#ok<TRYNC>
            end
            if ~isempty(obj.hTipBox) && ishandle(obj.hTipBox)
                try delete(obj.hTipBox); catch; end %#ok<TRYNC>
            end

            % Delete listeners
            if ~isempty(obj.FigDeleteListener)
                try delete(obj.FigDeleteListener); catch; end %#ok<TRYNC>
            end
            if ~isempty(obj.AxDeleteListener)
                try delete(obj.AxDeleteListener); catch; end %#ok<TRYNC>
            end
        end
    end

    methods (Access = private)
        function createGraphics_(obj)
            %CREATEGRAPHICS_ Pre-create crosshair line + datatip text (hidden).
            theme = [];
            if ~isempty(obj.Target) && isvalid(obj.Target)
                theme = obj.Target.Theme;
            end
            [bgColor, fgColor, edgeColor, fontName, fontSize] = ...
                obj.themeColors_(theme);

            yLim = get(obj.hAxes, 'YLim');

            % Crosshair vertical line — match toolbar crosshair styling
            % ([0.5 0.5 0.5] dotted) but use theme grid color when available.
            wasHeld = ishold(obj.hAxes);
            hold(obj.hAxes, 'on');
            obj.hLineV = line(obj.hAxes, [NaN NaN], yLim, ...
                'Color', edgeColor, ...
                'LineStyle', ':', ...
                'LineWidth', 1.0, ...
                'HitTest', 'off', ...
                'PickableParts', 'none', ...
                'HandleVisibility', 'off', ...
                'Visible', 'off');
            if ~wasHeld; hold(obj.hAxes, 'off'); end

            % Datatip text box (TeX interpreter so per-row colored bullets
            % can be rendered via \color[rgb]{...}\bullet directives).
            obj.hTipBox = text(obj.hAxes, ...
                mean(get(obj.hAxes, 'XLim')), ...
                mean(get(obj.hAxes, 'YLim')), ...
                '', ...
                'Interpreter', 'tex', ...
                'Color', fgColor, ...
                'BackgroundColor', bgColor, ...
                'EdgeColor', edgeColor, ...
                'FontName', fontName, ...
                'FontSize', fontSize, ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'top', ...
                'Margin', 4, ...
                'HitTest', 'off', ...
                'PickableParts', 'none', ...
                'HandleVisibility', 'off', ...
                'Visible', 'off');
        end

        function onFigureMove_(obj, src, evt)
            %ONFIGUREMOVE_ Chained WindowButtonMotionFcn handler.
            %   Order of operations:
            %     1. Always invoke previous handler first (toolbar / overlay
            %        coexistence).
            %     2. Throttle to ThrottleSeconds.
            %     3. Re-entrancy guard.
            %     4. Pixel-bounds hit-test on hAxes.
            %     5. If outside, onLeave; else onMove(currentX).
            if isa(obj.PrevWBMFcn_, 'function_handle')
                try
                    obj.PrevWBMFcn_(src, evt);
                catch
                    % Swallow — never let chained handler break our hover
                end
            end

            if ~isvalid(obj); return; end
            if isempty(obj.hFigure) || ~ishandle(obj.hFigure); return; end
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes); return; end

            % Throttle (~40 Hz cap)
            if ~isempty(obj.LastUpdateTime)
                try
                    if toc(obj.LastUpdateTime) < obj.ThrottleSeconds
                        return;
                    end
                catch
                    obj.LastUpdateTime = [];
                end
            end

            % Re-entrancy guard
            if obj.IsBusy; return; end
            obj.IsBusy = true;
            cleanupGuard = onCleanup(@() obj.clearBusy_());

            % Pixel-bounds hit test. CurrentPoint is reported in the
            % figure's Units, which may be 'normalized' (e.g. dashboards).
            % getpixelposition() always returns pixels, so coerce both into
            % pixel space by reading CurrentPoint with Units='pixels'.
            try
                prevUnits = get(obj.hFigure, 'Units');
                if ~strcmp(prevUnits, 'pixels')
                    set(obj.hFigure, 'Units', 'pixels');
                    figPt = get(obj.hFigure, 'CurrentPoint');
                    set(obj.hFigure, 'Units', prevUnits);
                else
                    figPt = get(obj.hFigure, 'CurrentPoint');
                end
                axPos = getpixelposition(obj.hAxes, true);
            catch
                return;
            end
            inX = figPt(1) >= axPos(1) && figPt(1) <= axPos(1) + axPos(3);
            inY = figPt(2) >= axPos(2) && figPt(2) <= axPos(2) + axPos(4);
            if ~(inX && inY)
                obj.onLeave();
                obj.LastUpdateTime = tic;
                return;
            end

            % Walk parent chain to skip hidden tabs/panels
            p = get(obj.hAxes, 'Parent');
            while ~isempty(p) && p ~= obj.hFigure
                if isprop(p, 'Visible') && strcmp(get(p, 'Visible'), 'off')
                    obj.onLeave();
                    obj.LastUpdateTime = tic;
                    return;
                end
                p = get(p, 'Parent');
            end

            try
                cp = get(obj.hAxes, 'CurrentPoint');
                xQuery = cp(1, 1);
            catch
                return;
            end

            obj.onMove(xQuery);
            obj.LastUpdateTime = tic;

            % cleanupGuard releases IsBusy on function exit
            clear cleanupGuard;
        end

        function clearBusy_(obj)
            if isvalid(obj)
                obj.IsBusy = false;
            end
        end

        function onTargetDestroyed_(obj)
            %ONTARGETDESTROYED_ Self-cleanup when figure or axes is destroyed.
            if isvalid(obj)
                try delete(obj); catch; end %#ok<TRYNC>
            end
        end
    end

    methods (Static, Access = private)
        function yStr = computeYAtX_(lineRec, xQuery)
            %COMPUTEYATX_ Return formatted y string at xQuery (em-dash if OOR/NaN).
            DASH = char(8212);
            xData = lineRec.X;
            yData = lineRec.Y;
            if isempty(xData) || isempty(yData)
                yStr = DASH;
                return;
            end
            if xQuery < xData(1) || xQuery > xData(end)
                yStr = DASH;
                return;
            end
            try
                idx = binary_search(xData, xQuery, 'left');
            catch
                yStr = DASH;
                return;
            end
            idx = max(1, min(idx, numel(xData)));
            yVal = yData(idx);
            if isnan(yVal)
                yStr = DASH;
            else
                yStr = sprintf('%.4g', yVal);
            end
        end

        function name = lineDisplayName_(lineRec, fallbackIdx)
            %LINEDISPLAYNAME_ Resolve a line's DisplayName with fallback.
            name = sprintf('Line %d', fallbackIdx);
            try
                opts = lineRec.Options;
                hasName = isstruct(opts) && isfield(opts, 'DisplayName') && ~isempty(opts.DisplayName);
                if hasName
                    name = char(opts.DisplayName);
                end
            catch
                % keep fallback
            end
        end

        function color = resolveLineColor_(lineRec, fallback)
            %RESOLVELINECOLOR_ Best-effort RGB color for a line record.
            %   Order: rendered handle 'Color' -> Options.Color -> fallback.
            color = fallback;
            try
                if isfield(lineRec, 'hLine') && ~isempty(lineRec.hLine) ...
                        && ishandle(lineRec.hLine)
                    c = get(lineRec.hLine, 'Color');
                    if isnumeric(c) && numel(c) == 3
                        color = double(c(:)');
                        return;
                    end
                end
            catch
            end
            try
                if isfield(lineRec, 'Options') && isstruct(lineRec.Options) ...
                        && isfield(lineRec.Options, 'Color') ...
                        && ~isempty(lineRec.Options.Color)
                    c = lineRec.Options.Color;
                    if isnumeric(c) && numel(c) == 3
                        color = double(c(:)');
                    end
                end
            catch
            end
        end

        function s = escapeTeX_(s)
            %ESCAPETEX_ Escape TeX special chars in plain text labels.
            if ~ischar(s) && ~isstring(s); s = char(s); end
            s = strrep(s, '\', '\\');
            s = strrep(s, '_', '\_');
            s = strrep(s, '^', '\^');
            s = strrep(s, '{', '\{');
            s = strrep(s, '}', '\}');
            s = strrep(s, '$', '\$');
            s = strrep(s, '&', '\&');
            s = strrep(s, '#', '\#');
            s = strrep(s, '%', '\%');
        end

        function [bgColor, fgColor, edgeColor, fontName, fontSize] = ...
                themeColors_(theme)
            %THEMECOLORS_ Resolve theme colors with safe defaults.
            bgColor   = [1 1 1];
            fgColor   = [0.2 0.2 0.2];
            edgeColor = [0.5 0.5 0.5];
            fontName  = 'Helvetica';
            fontSize  = 9;
            if isempty(theme); return; end
            try
                if isstruct(theme) || isobject(theme)
                    if isfield_or_prop(theme, 'Background')
                        bgColor = theme.Background;
                    end
                    if isfield_or_prop(theme, 'ForegroundColor')
                        fgColor = theme.ForegroundColor;
                    end
                    if isfield_or_prop(theme, 'GridColor')
                        edgeColor = theme.GridColor;
                    end
                    if isfield_or_prop(theme, 'FontName')
                        fontName = theme.FontName;
                    end
                    if isfield_or_prop(theme, 'FontSize')
                        fontSize = max(7, theme.FontSize - 1);
                    end
                end
            catch
                % keep defaults
            end
        end
    end
end

function tf = isfield_or_prop(s, name)
%ISFIELD_OR_PROP True if s is a struct with field name, or object with prop.
    tf = false;
    try
        if isstruct(s)
            tf = isfield(s, name);
        elseif isobject(s)
            tf = isprop(s, name);
        end
    catch
        tf = false;
    end
end
