classdef PlantLogSliderHover < handle
    %PLANTLOGSLIDERHOVER Hover-driven tooltip on plant-log slider markers.
    %
    %   PHOVER = PLANTLOGSLIDERHOVER(parentFig, sliderAxes, lookupFn) attaches
    %   a chained WindowButtonMotionFcn handler to parentFig that pops a small
    %   transient uipanel tooltip when the cursor sits within ~3 pixels of a
    %   plant-log marker on sliderAxes. lookupFn is invoked as
    %       entries = lookupFn(t0, t1)
    %   and is expected to close over the DashboardEngine's attached
    %   PlantLogStore (typically a thin engine helper that re-reads
    %   PlantLogStoreInternal_ at call time so subsequent store swaps are
    %   reflected immediately).
    %
    %   Phase 1031 PLOG-VIZ-06: hovering a plant-log marker on the slider
    %   pops a tooltip with the entry's timestamp + message. Mirrors the
    %   chained-WindowButtonMotionFcn pattern from libs/FastSense/HoverCrosshair.m
    %   so it coexists with TimeRangeSelector's drag handlers and any other
    %   hover-driven features.
    %
    %   Differences from HoverCrosshair:
    %     - Throttle = 50 ms (vs HoverCrosshair's 25 ms; per CONTEXT.md PLOG-VIZ-06)
    %     - Tooltip is a transient uipanel (not a TeX text annotation in axes)
    %       so it can sit anywhere on the figure
    %     - Proximity check uses a ~3 px tolerance in axes data units
    %     - Auto-hide after ~2 seconds of no mouse motion (cheap 0.5s sweep timer)
    %
    %   Properties (read-only):
    %     ParentFig        — figure handle whose WindowButtonMotionFcn is chained
    %     SliderAxes       — TimeRangeSelector.hAxes (where plant-log markers live)
    %     LookupFn_        — function_handle of signature `entries = f(t0, t1)`
    %     hTooltipPanel    — transient uipanel used to display the tooltip
    %     hTooltipText     — uicontrol(text) inside the panel that shows the message
    %
    %   Public methods:
    %     delete()                          — restore prior WindowButtonMotionFcn,
    %                                         remove tooltip graphics, stop timers
    %
    %   Hidden test seams (methods (Hidden)):
    %     pick = simulateHoverAt_(dataX)    — bypass the WBMFcn pixel hit-test;
    %                                         runs the lookup + tooltip-show logic
    %                                         at the given data X coordinate;
    %                                         returns the picked PlantLogEntry
    %                                         (or [] when no entry within tolerance)
    %     str  = getCurrentTooltipString_()  — read-only access to the tooltip String
    %     tf   = getCurrentTooltipVisible_() — true when tooltip Visible == 'on'
    %
    %   Errors:
    %     PlantLogSliderHover:invalidInput  — bad parentFig / sliderAxes / lookupFn
    %
    %   Cleanup contract (PLOG-VIZ-06):
    %     delete() restores the prior WindowButtonMotionFcn UNCONDITIONALLY
    %     (mirroring HoverCrosshair line 207). '' is a legal callback value,
    %     so the restore is NOT guarded by ~isempty(PrevWBMFcn_).
    %
    %   See also HoverCrosshair, TimeRangeSelector, DashboardEngine, PlantLogStore.

    properties (SetAccess = private)
        ParentFig    = []   % figure / uifigure handle
        SliderAxes   = []   % TimeRangeSelector.hAxes handle
        LookupFn_    = []   % function_handle: entries = lookupFn(t0, t1)
        hTooltipPanel = []  % transient uipanel
        hTooltipText  = []  % uicontrol(text) inside the panel
    end

    properties (Access = private)
        PrevWBMFcn_         = []     % saved WindowButtonMotionFcn (function handle, '' or [])
        LastUpdateTime_     = []     % tic timestamp for throttling (~20 Hz cap)
        IsBusy_             = false  % re-entrancy guard for onFigureMove_
        FigDeleteListener_  = []     % listener handle on figure ObjectBeingDestroyed
        AxDeleteListener_   = []     % listener handle on axes ObjectBeingDestroyed
        HideTimer_          = []     % cheap 0.5s sweep that hides tooltip after 2s of inactivity
        LastShowAt_         = []     % tic timestamp of most-recent showTooltip_ call
        ThrottleSeconds_    = 0.05   % min interval between motion-driven updates (~20 Hz)
        AutoHideSeconds_    = 2.0    % tooltip auto-hide threshold
    end

    methods (Access = public)
        function obj = PlantLogSliderHover(parentFig, sliderAxes, lookupFn)
            %PLANTLOGSLIDERHOVER Construct hover tooltip attached to a slider axes.
            %   obj = PLANTLOGSLIDERHOVER(parentFig, sliderAxes, lookupFn).
            %   Throws PlantLogSliderHover:invalidInput on bad args.
            if nargin < 3
                error('PlantLogSliderHover:invalidInput', ...
                    'Requires (parentFig, sliderAxes, lookupFn).');
            end
            if isempty(parentFig) || ~ishandle(parentFig)
                error('PlantLogSliderHover:invalidInput', ...
                    'parentFig must be a valid figure handle.');
            end
            if isempty(sliderAxes) || ~ishandle(sliderAxes)
                error('PlantLogSliderHover:invalidInput', ...
                    'sliderAxes must be a valid axes handle.');
            end
            if ~isa(lookupFn, 'function_handle')
                error('PlantLogSliderHover:invalidInput', ...
                    'lookupFn must be a function_handle of signature entries = f(t0,t1).');
            end

            obj.ParentFig  = parentFig;
            obj.SliderAxes = sliderAxes;
            obj.LookupFn_  = lookupFn;

            % Save existing handler so we can restore it on delete and chain
            % to it on every motion event. '' is a legal value -- do NOT
            % coerce to [] here.
            obj.PrevWBMFcn_ = get(parentFig, 'WindowButtonMotionFcn');

            % Pre-create tooltip graphics (Visible='off' until first showTooltip_).
            obj.createTooltipGraphics_();

            % Install chained motion handler (mirrors HoverCrosshair line 89).
            set(parentFig, 'WindowButtonMotionFcn', ...
                @(s,e) obj.onFigureMove_(s, e));

            % Listen for figure / axes destruction so we can self-cleanup.
            try
                obj.FigDeleteListener_ = addlistener(parentFig, ...
                    'ObjectBeingDestroyed', @(~,~) obj.onTargetDestroyed_());
            catch
            end
            try
                obj.AxDeleteListener_ = addlistener(sliderAxes, ...
                    'ObjectBeingDestroyed', @(~,~) obj.onTargetDestroyed_());
            catch
            end

            % Auto-hide timer: cheap 0.5s sweep that hides tooltip after 2s
            % of inactivity. Wrapped in try/catch so a uifigure context that
            % rejects timer creation does not break the hover.
            try
                obj.HideTimer_ = timer( ...
                    'ExecutionMode', 'fixedSpacing', ...
                    'Period',        0.5, ...
                    'TimerFcn',      @(~,~) obj.checkAutoHide_());
                start(obj.HideTimer_);
            catch
            end
        end

        function delete(obj)
            %DELETE Restore prior WindowButtonMotionFcn and clean up graphics.
            % Stop + delete the auto-hide timer first so its TimerFcn cannot
            % fire after our state goes invalid.
            if ~isempty(obj.HideTimer_)
                try
                    if isvalid(obj.HideTimer_)
                        stop(obj.HideTimer_);
                        delete(obj.HideTimer_);
                    end
                catch
                end
            end
            obj.HideTimer_ = [];

            % Restore prior WBMFcn UNCONDITIONALLY -- '' is a legal callback,
            % so we must NOT guard with ~isempty(PrevWBMFcn_).
            if ~isempty(obj.ParentFig) && ishandle(obj.ParentFig)
                try
                    set(obj.ParentFig, 'WindowButtonMotionFcn', obj.PrevWBMFcn_);
                catch
                end
            end

            % Delete tooltip graphics.
            if ~isempty(obj.hTooltipPanel) && ishandle(obj.hTooltipPanel)
                try
                    delete(obj.hTooltipPanel);
                catch
                end
            end
            obj.hTooltipPanel = [];
            obj.hTooltipText  = [];

            % Delete listeners.
            if ~isempty(obj.FigDeleteListener_)
                try
                    delete(obj.FigDeleteListener_);
                catch
                end
            end
            obj.FigDeleteListener_ = [];
            if ~isempty(obj.AxDeleteListener_)
                try
                    delete(obj.AxDeleteListener_);
                catch
                end
            end
            obj.AxDeleteListener_ = [];
        end
    end

    methods (Hidden)
        function pick = simulateHoverAt_(obj, dataX)
            %SIMULATEHOVERAT_ Bypass the WBMFcn / pixel hit-test for tests.
            %   Runs the lookup + tooltip-show logic at the given data X
            %   coordinate; returns the picked PlantLogEntry (or [] when no
            %   entry sits within ~3 px in axes data units).
            pick = [];
            if isempty(obj.SliderAxes) || ~ishandle(obj.SliderAxes)
                return;
            end
            xLim = get(obj.SliderAxes, 'XLim');
            try
                axesPosPx = getpixelposition(obj.SliderAxes, true);
            catch
                axesPosPx = [0 0 100 1];
            end
            pxToData = (xLim(2) - xLim(1)) / max(axesPosPx(3), 1);
            tol = 3 * pxToData;
            entries = [];
            try
                entries = obj.LookupFn_(dataX - tol, dataX + tol);
            catch
                entries = [];
            end
            if isempty(entries)
                obj.onLeave_();
                return;
            end
            dt = abs([entries.Timestamp] - dataX);
            [~, k] = min(dt);
            pick = entries(k);
            obj.showTooltip_(pick);
        end

        function s = getCurrentTooltipString_(obj)
            %GETCURRENTTOOLTIPSTRING_ Read-only access to the tooltip String.
            s = '';
            if ~isempty(obj.hTooltipText) && ishandle(obj.hTooltipText)
                s = get(obj.hTooltipText, 'String');
            end
        end

        function tf = getCurrentTooltipVisible_(obj)
            %GETCURRENTTOOLTIPVISIBLE_ True when tooltip Visible == 'on'.
            tf = false;
            if ~isempty(obj.hTooltipPanel) && ishandle(obj.hTooltipPanel)
                tf = strcmp(get(obj.hTooltipPanel, 'Visible'), 'on');
            end
        end
    end

    methods (Access = private)
        function createTooltipGraphics_(obj)
            %CREATETOOLTIPGRAPHICS_ Pre-create the uipanel + uicontrol(text).
            try
                obj.hTooltipPanel = uipanel('Parent', obj.ParentFig, ...
                    'Units',           'pixels', ...
                    'Position',        [0 0 240 44], ...
                    'BackgroundColor', [0.13 0.13 0.16], ...
                    'BorderType',      'line', ...
                    'HighlightColor',  [0.4 0.4 0.45], ...
                    'Visible',         'off');
            catch
                obj.hTooltipPanel = uipanel('Parent', obj.ParentFig, ...
                    'Units',    'pixels', ...
                    'Position', [0 0 240 44], ...
                    'Visible',  'off');
            end
            try
                obj.hTooltipText = uicontrol('Parent', obj.hTooltipPanel, ...
                    'Style',               'text', ...
                    'Units',               'normalized', ...
                    'Position',            [0.02 0.0 0.96 1.0], ...
                    'HorizontalAlignment', 'left', ...
                    'BackgroundColor',     [0.13 0.13 0.16], ...
                    'ForegroundColor',     [0.95 0.95 0.95], ...
                    'String',              '');
            catch
                obj.hTooltipText = uicontrol('Parent', obj.hTooltipPanel, ...
                    'Style',  'text', ...
                    'Units',  'normalized', ...
                    'Position', [0.02 0.0 0.96 1.0], ...
                    'String', '');
            end
        end

        function onFigureMove_(obj, src, evt)
            %ONFIGUREMOVE_ Chained WindowButtonMotionFcn handler.
            %   Order of operations (mirrors HoverCrosshair.onFigureMove_):
            %     1. Validate obj + figure/axes handles BEFORE touching obj
            %        properties (260508-od4: stale closures may fire during
            %        widget teardown).
            %     2. Invoke previous handler (toolbar / overlay coexistence).
            %     3. Throttle to ThrottleSeconds_ (50 ms).
            %     4. Re-entrancy guard.
            %     5. Pixel-bounds hit-test on sliderAxes.
            %     6. If outside, onLeave_; else delegate to simulateHoverAt_
            %        with the cursor's data-X coordinate (so the WBMFcn path
            %        and the test seam share lookup logic).
            if ~isvalid(obj); return; end
            if isempty(obj.ParentFig) || ~ishandle(obj.ParentFig); return; end
            if isempty(obj.SliderAxes) || ~ishandle(obj.SliderAxes); return; end

            % Chain to prior handler (never let it break our hover).
            if isa(obj.PrevWBMFcn_, 'function_handle')
                try
                    obj.PrevWBMFcn_(src, evt);
                catch
                end
            end

            % Throttle (~20 Hz cap).
            if ~isempty(obj.LastUpdateTime_)
                try
                    if toc(obj.LastUpdateTime_) < obj.ThrottleSeconds_
                        return;
                    end
                catch
                    obj.LastUpdateTime_ = [];
                end
            end

            % Re-entrancy guard.
            if obj.IsBusy_; return; end
            obj.IsBusy_ = true;
            cleanupGuard = onCleanup(@() obj.clearBusy_());

            % Read figure CurrentPoint in pixel space (CurrentPoint reports
            % in figure Units, which may be 'normalized' for dashboards).
            try
                prevUnits = get(obj.ParentFig, 'Units');
                if ~strcmp(prevUnits, 'pixels')
                    set(obj.ParentFig, 'Units', 'pixels');
                    figPt = get(obj.ParentFig, 'CurrentPoint');
                    set(obj.ParentFig, 'Units', prevUnits);
                else
                    figPt = get(obj.ParentFig, 'CurrentPoint');
                end
                axPos = getpixelposition(obj.SliderAxes, true);
            catch
                clear cleanupGuard;
                return;
            end

            inX = figPt(1) >= axPos(1) && figPt(1) <= axPos(1) + axPos(3);
            inY = figPt(2) >= axPos(2) && figPt(2) <= axPos(2) + axPos(4);
            if ~(inX && inY)
                obj.onLeave_();
                obj.LastUpdateTime_ = tic;
                clear cleanupGuard;
                return;
            end

            % Convert cursor pixel-X to axes data-X.
            xLim = get(obj.SliderAxes, 'XLim');
            cursorX = xLim(1) + (figPt(1) - axPos(1)) / ...
                max(axPos(3), 1) * (xLim(2) - xLim(1));

            % Reuse the same path the test seam uses (lookup + show).
            pick = obj.simulateHoverAt_(cursorX);
            if ~isempty(pick)
                obj.positionTooltipNearCursor_(figPt);
            end
            obj.LastUpdateTime_ = tic;
            clear cleanupGuard;
        end

        function clearBusy_(obj)
            %CLEARBUSY_ onCleanup guard companion -- releases IsBusy_.
            if isvalid(obj)
                obj.IsBusy_ = false;
            end
        end

        function onLeave_(obj)
            %ONLEAVE_ Hide the tooltip panel.
            if ~isempty(obj.hTooltipPanel) && ishandle(obj.hTooltipPanel)
                try
                    set(obj.hTooltipPanel, 'Visible', 'off');
                catch
                end
            end
        end

        function showTooltip_(obj, pick)
            %SHOWTOOLTIP_ Format + show the tooltip text for a picked entry.
            tsStr = '';
            try
                tsStr = datestr(pick.Timestamp, 'yyyy-mm-dd HH:MM:SS');
            catch
                tsStr = sprintf('%g', pick.Timestamp);
            end
            msgStr = '';
            try
                msgStr = char(pick.Message);
            catch
            end
            str = sprintf('%s\n%s', tsStr, msgStr);
            if ~isempty(obj.hTooltipText) && ishandle(obj.hTooltipText)
                try
                    set(obj.hTooltipText, 'String', str);
                catch
                end
            end
            if ~isempty(obj.hTooltipPanel) && ishandle(obj.hTooltipPanel)
                try
                    set(obj.hTooltipPanel, 'Visible', 'on');
                catch
                end
            end
            obj.LastShowAt_ = tic;
        end

        function positionTooltipNearCursor_(obj, figPt)
            %POSITIONTOOLTIPNEARCURSOR_ Place tooltip near the cursor (offset).
            if isempty(obj.hTooltipPanel) || ~ishandle(obj.hTooltipPanel)
                return;
            end
            try
                figPosPx = getpixelposition(obj.ParentFig, false);
            catch
                figPosPx = [0 0 800 600];
            end
            tipW = 240;
            tipH = 44;
            x = figPt(1) + 12;
            y = figPt(2) - tipH - 12;
            % Flip horizontally if tooltip would overflow the right edge.
            if x + tipW > figPosPx(3)
                x = figPt(1) - tipW - 12;
            end
            % Flip vertically if tooltip would overflow the bottom.
            if y < 0
                y = figPt(2) + 12;
            end
            try
                set(obj.hTooltipPanel, 'Position', [x, y, tipW, tipH]);
            catch
            end
        end

        function checkAutoHide_(obj)
            %CHECKAUTOHIDE_ Cheap 0.5s timer sweep -- hides tooltip after 2s idle.
            if ~isvalid(obj); return; end
            if isempty(obj.LastShowAt_); return; end
            try
                if toc(obj.LastShowAt_) > obj.AutoHideSeconds_
                    obj.onLeave_();
                    obj.LastShowAt_ = [];
                end
            catch
            end
        end

        function onTargetDestroyed_(obj)
            %ONTARGETDESTROYED_ Self-cleanup when figure or axes is destroyed.
            if isvalid(obj)
                try
                    delete(obj);
                catch
                end
            end
        end
    end
end
