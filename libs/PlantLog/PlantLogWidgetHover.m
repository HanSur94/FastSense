classdef PlantLogWidgetHover < handle
    %PLANTLOGWIDGETHOVER Hover-driven tooltip on per-widget plant-log markers.
    %
    %   PHOVER = PLANTLOGWIDGETHOVER(parentFig, widgetAxes, lookupFn) attaches
    %   a chained WindowButtonMotionFcn handler to parentFig that pops a
    %   transient uipanel tooltip when the cursor sits within ~3 pixels of a
    %   plant-log line on widgetAxes. lookupFn is invoked as
    %       entries = lookupFn(t0, t1)
    %   and is expected to close over the DashboardEngine's attached
    %   PlantLogStore (typically a thin engine helper that re-reads
    %   PlantLogStoreInternal_ at call time so subsequent store swaps are
    %   reflected immediately).
    %
    %   Phase 1032 PLOG-VIZ-07: hovering a plant-log line on a per-widget
    %   axes pops a tooltip with the entry's timestamp + message + every
    %   metadata column (insertion order, value truncated to 40 chars with
    %   ellipsis when longer, embedded newlines collapsed to single space).
    %   When multiple entries fall in the same 3px hit zone, entries are
    %   stacked as separated blocks (header '-- ts --' per block) sorted by
    %   Timestamp ASC; cap at 10 blocks with '+N more entries near this
    %   point' footer when count > 10.
    %
    %   Mirrors PlantLogSliderHover's chained-WBMFcn pattern exactly — only
    %   the tooltip layout differs (full metadata + overlap stacking).
    %
    %   Differences from PlantLogSliderHover:
    %     - Tooltip uipanel initial size [0 0 320 180] (wider/taller for the
    %       metadata stack)
    %     - showTooltip_ accepts a PlantLogEntry ARRAY (single entry layout
    %       when numel==1, stacked-block layout when numel>1)
    %     - simulateHoverAt_ returns the FULL entry array within tolerance
    %       (not just the nearest pick) so overlap stacking lights up
    %     - Error namespace PlantLogWidgetHover:invalidInput
    %
    %   Properties (read-only):
    %     ParentFig        — figure handle whose WindowButtonMotionFcn is chained
    %     WidgetAxes       — widget's inner FastSenseObj.hAxes
    %     LookupFn_        — function_handle entries = f(t0, t1)
    %     hTooltipPanel    — transient uipanel used to display the tooltip
    %     hTooltipText     — uicontrol(text) inside the panel
    %
    %   Public methods:
    %     delete()                          — restore prior WindowButtonMotionFcn,
    %                                         remove tooltip graphics, stop timers
    %
    %   Hidden test seams:
    %     picks = simulateHoverAt_(dataX)   — bypass the WBMFcn pixel hit-test;
    %                                         runs the lookup + tooltip-show
    %                                         logic at the given data X; returns
    %                                         the FULL entry array within tolerance
    %                                         (or [] when no entry in range)
    %     str   = getCurrentTooltipString_() — read-only access to tooltip String
    %     tf    = getCurrentTooltipVisible_() — true when tooltip Visible == 'on'
    %
    %   Errors:
    %     PlantLogWidgetHover:invalidInput  — bad parentFig / widgetAxes / lookupFn
    %
    %   Cleanup contract:
    %     delete() restores the prior WindowButtonMotionFcn UNCONDITIONALLY
    %     (mirrors PlantLogSliderHover line 207). '' is a legal callback value,
    %     so the restore is NOT guarded by ~isempty(PrevWBMFcn_).
    %
    %   See also PlantLogSliderHover, FastSenseWidget, DashboardEngine,
    %            PlantLogStore.

    properties (SetAccess = private)
        ParentFig    = []   % figure / uifigure handle
        WidgetAxes   = []   % FastSenseObj.hAxes handle (widget's inner axes)
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
        function obj = PlantLogWidgetHover(parentFig, widgetAxes, lookupFn)
            %PLANTLOGWIDGETHOVER Construct hover tooltip attached to a widget axes.
            %   obj = PLANTLOGWIDGETHOVER(parentFig, widgetAxes, lookupFn).
            %   Throws PlantLogWidgetHover:invalidInput on bad args.
            if nargin < 3
                error('PlantLogWidgetHover:invalidInput', ...
                    'Requires (parentFig, widgetAxes, lookupFn).');
            end
            if isempty(parentFig) || ~ishandle(parentFig)
                error('PlantLogWidgetHover:invalidInput', ...
                    'parentFig must be a valid figure handle.');
            end
            if isempty(widgetAxes) || ~ishandle(widgetAxes)
                error('PlantLogWidgetHover:invalidInput', ...
                    'widgetAxes must be a valid axes handle.');
            end
            if ~isa(lookupFn, 'function_handle')
                error('PlantLogWidgetHover:invalidInput', ...
                    'lookupFn must be a function_handle of signature entries = f(t0,t1).');
            end

            obj.ParentFig  = parentFig;
            obj.WidgetAxes = widgetAxes;
            obj.LookupFn_  = lookupFn;

            % Save existing handler so we can restore it on delete and chain
            % to it on every motion event. '' is a legal value -- do NOT
            % coerce to [] here.
            obj.PrevWBMFcn_ = get(parentFig, 'WindowButtonMotionFcn');

            % Pre-create tooltip graphics (Visible='off' until first showTooltip_).
            obj.createTooltipGraphics_();

            % Install chained motion handler.
            set(parentFig, 'WindowButtonMotionFcn', ...
                @(s,e) obj.onFigureMove_(s, e));

            % Listen for figure / axes destruction so we can self-cleanup.
            try
                obj.FigDeleteListener_ = addlistener(parentFig, ...
                    'ObjectBeingDestroyed', @(~,~) obj.onTargetDestroyed_());
            catch
            end
            try
                obj.AxDeleteListener_ = addlistener(widgetAxes, ...
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
        function picks = simulateHoverAt_(obj, dataX)
            %SIMULATEHOVERAT_ Bypass WBMFcn pixel hit-test — returns ALL entries within hit zone (Phase 1032 PLOG-VIZ-07).
            %   Returns the full PlantLogEntry array within ~3 px (in axes
            %   data units) of dataX so showTooltip_ can stack overlapping
            %   entries. Returns [] when no entries within tolerance.
            picks = [];
            if isempty(obj.WidgetAxes) || ~ishandle(obj.WidgetAxes)
                return;
            end
            xLim = get(obj.WidgetAxes, 'XLim');
            try
                axesPosPx = getpixelposition(obj.WidgetAxes, true);
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
            picks = entries;
            obj.showTooltip_(picks);
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
                    'Position',        [0 0 320 180], ...
                    'BackgroundColor', [0.13 0.13 0.16], ...
                    'BorderType',      'line', ...
                    'HighlightColor',  [0.4 0.4 0.45], ...
                    'Visible',         'off');
            catch
                obj.hTooltipPanel = uipanel('Parent', obj.ParentFig, ...
                    'Units',    'pixels', ...
                    'Position', [0 0 320 180], ...
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
                    'Style',    'text', ...
                    'Units',    'normalized', ...
                    'Position', [0.02 0.0 0.96 1.0], ...
                    'String',   '');
            end
        end

        function onFigureMove_(obj, src, evt)
            %ONFIGUREMOVE_ Chained WindowButtonMotionFcn handler.
            %   Mirrors PlantLogSliderHover.onFigureMove_ exactly — bounds
            %   check on widget axes pixel position, convert cursor X to
            %   axes data X, delegate to simulateHoverAt_.
            if ~isvalid(obj); return; end
            if isempty(obj.ParentFig) || ~ishandle(obj.ParentFig); return; end
            if isempty(obj.WidgetAxes) || ~ishandle(obj.WidgetAxes); return; end

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

            % Read figure CurrentPoint in pixel space.
            try
                prevUnits = get(obj.ParentFig, 'Units');
                if ~strcmp(prevUnits, 'pixels')
                    set(obj.ParentFig, 'Units', 'pixels');
                    figPt = get(obj.ParentFig, 'CurrentPoint');
                    set(obj.ParentFig, 'Units', prevUnits);
                else
                    figPt = get(obj.ParentFig, 'CurrentPoint');
                end
                axPos = getpixelposition(obj.WidgetAxes, true);
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
            xLim = get(obj.WidgetAxes, 'XLim');
            cursorX = xLim(1) + (figPt(1) - axPos(1)) / ...
                max(axPos(3), 1) * (xLim(2) - xLim(1));

            picks = obj.simulateHoverAt_(cursorX);
            if ~isempty(picks)
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

        function showTooltip_(obj, picks)
            %SHOWTOOLTIP_ Format full-metadata tooltip for one OR more picked entries (Phase 1032 PLOG-VIZ-07).
            %   picks: PlantLogEntry array. When numel(picks)==1, the layout
            %   is timestamp + message + metadata (no header decoration).
            %   When numel(picks)>1, picks are sorted by Timestamp ASC and
            %   stacked as separated blocks each headed by '-- ts --'. Cap
            %   at 10 blocks; '+N more entries near this point' footer when
            %   total > 10.
            if isempty(picks)
                obj.onLeave_();
                return;
            end
            % Sort by Timestamp ASC.
            tsAll = [picks.Timestamp];
            [~, sidx] = sort(tsAll);
            picks = picks(sidx);

            totalCount = numel(picks);
            displayed  = min(totalCount, 10);
            lines = {};

            singleEntry = (totalCount == 1);
            for i = 1:displayed
                p = picks(i);
                tsStr = '';
                try
                    tsStr = datestr(p.Timestamp, 'yyyy-mm-dd HH:MM:SS'); %#ok<DATST>
                catch
                    tsStr = sprintf('%g', p.Timestamp);
                end
                if singleEntry
                    lines{end+1} = tsStr; %#ok<AGROW>
                else
                    lines{end+1} = sprintf('-- %s --', tsStr); %#ok<AGROW>
                end
                msgStr = '';
                try
                    msgStr = char(p.Message);
                catch
                end
                lines{end+1} = msgStr; %#ok<AGROW>
                % Metadata in insertion order.
                try
                    if isstruct(p.Metadata) && ~isempty(fieldnames(p.Metadata))
                        fnames = fieldnames(p.Metadata);
                        for k = 1:numel(fnames)
                            key = fnames{k};
                            val = p.Metadata.(key);
                            try
                                val = char(val);
                            catch
                                val = sprintf('%g', val);
                            end
                            % Collapse embedded newlines to single space.
                            val = regexprep(val, '[\r\n]+', ' ');
                            % Truncate to 40 chars + ellipsis when longer.
                            if numel(val) > 40
                                val = [val(1:39), char(8230)];  % char(8230) = '…'
                            end
                            lines{end+1} = sprintf('%s: %s', key, val); %#ok<AGROW>
                        end
                    end
                catch
                end
            end
            if totalCount > 10
                lines{end+1} = sprintf('+%d more entries near this point', totalCount - 10);
            end
            str = strjoin(lines, newline);
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
            tipW = 320;
            tipH = 180;
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
