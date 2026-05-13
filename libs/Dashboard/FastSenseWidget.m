classdef FastSenseWidget < DashboardWidget
%FASTSENSEWIDGET Dashboard widget wrapping a FastSense instance.
%
%   Supports data binding modes:
%     Tag:       w = FastSenseWidget('Tag', tagObj)
%     DataStore: w = FastSenseWidget('DataStore', dsObj)
%     Inline:    w = FastSenseWidget('XData', x, 'YData', y)
%     File:      w = FastSenseWidget('File', 'path.mat', 'XVar', 'x', 'YVar', 'y')

    properties (Access = public)
        DataStoreObj = []
        XData        = []
        YData        = []
        File         = ''
        XVar         = ''
        YVar         = ''
        Thresholds   = 'auto'
        XLabel       = ''    % X-axis label (auto-set from Sensor if empty)
        YLabel       = ''    % Y-axis label (auto-set from Sensor if empty)
        YLimits             = []    % Fixed Y-axis range [min max]; empty = auto-scale
        ShowThresholdLabels = false % show inline name labels on threshold lines
        ShowEventMarkers    = false % Phase 1012 — toggle event round-marker overlay
        EventStore          = []    % Phase 1012 — EventStore handle forwarded to inner FastSense
        % Forwarded to FastSense.LiveViewMode on render:
        %   'reset'    — window covers the full X range every tick (default:
        %                matches dashboard-demo expectation that users see
        %                every sample since session start)
        %   'follow'   — window of current width tracks the latest sample
        %                (use for long-running deployments where the full
        %                range would exhaust memory / downsampling budget)
        %   'preserve' — frozen at the initial X range (legacy behaviour)
        LiveViewMode = 'reset'
    end
    %   (Tag property now lives on the DashboardWidget base class — Plan 1009-02.)

    properties (SetAccess = private)
        FastSenseObj  = []
        IsSettingTime = false  % guard to distinguish programmatic vs user xlim change
        IsSettingYLim = false  % guard so autoScaleY_ does not flip UserZoomedY
        UserZoomedY   = false  % true after user mouse-zooms Y; suspends autoScaleY_
        CachedXMin    = inf    % cached minimum of X data for O(1) getTimeRange()
        CachedXMax    = -inf   % cached maximum of X data for O(1) getTimeRange()
        LastTagRef    = []     % Tag handle snapshot for cache-invalidation
        LastEventIds_      = {}    % Phase 1012 — cell of event Ids at last refresh
        LastEventOpen_     = []    % Phase 1012 — logical array parallel to LastEventIds_
        LastEventSeverity_ = []    % Phase 1012 — numeric array parallel to LastEventIds_
        PreviewCache_      = []    % 260508-das — cached getPreviewSeries result
        PreviewCacheKey_   = []    % [numel(x), x(1), x(end), nBucketsEff] sentinel
    end

    properties (Access = private, Constant)
        % PREVIEWRAWTHRESHOLD_ Sample-count threshold below which
        %   getPreviewSeries skips downsampling and renders one bucket
        %   per raw sample. Chosen as 100 because:
        %     - small enough that raw rendering remains cheap (<= 100
        %       points -> ~200 line vertices after min/max pairing);
        %     - large enough that downsampling only kicks in once a
        %       slider preview is dense enough to genuinely benefit.
        %   Adjust here if user feedback warrants a different cut-off.
        PreviewRawThreshold_ = 100
    end

    methods
        function obj = FastSenseWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 12 3];
            end

            % Tag cascade (v2.0 Tag API).
            if ~isempty(obj.Tag)
                if ~isa(obj.Tag, 'Tag')
                    error('FastSenseWidget:invalidTag', ...
                        'Tag must be a Tag subclass; got %s.', class(obj.Tag));
                end
                if isempty(obj.XLabel), obj.XLabel = 'Time'; end
                if isempty(obj.YLabel)
                    if isprop(obj.Tag, 'Units') && ~isempty(obj.Tag.Units)
                        obj.YLabel = obj.Tag.Units;
                    elseif ~isempty(obj.Tag.Name)
                        obj.YLabel = obj.Tag.Name;
                    else
                        obj.YLabel = obj.Tag.Key;
                    end
                end
                obj.LastTagRef = obj.Tag;
                obj.updateTimeRangeCache();
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;

            % Create axes inside the panel
            ax = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.08 0.12 0.88 0.78]);

            % Create FastSense on this axes
            fp = FastSense('Parent', ax);
            obj.FastSenseObj = fp;
            fp.ShowThresholdLabels = obj.ShowThresholdLabels;
            % Phase 1012 — guarded forwarding of event-marker state to inner FastSense.
            % FastSense.ShowEventMarkers defaults to TRUE (shipped by Phase 1010).
            % FastSenseWidget.ShowEventMarkers defaults to FALSE (back-compat for
            % dashboards that never opted into the overlay). If we unconditionally
            % forwarded widget->inner here, we'd silently HIDE markers on any
            % pre-1012 widget dashboard that had set fp.EventStore directly
            % (rare but possible via low-level access to FastSenseObj). The guard
            % below forwards only when the widget has explicitly opted in
            % (ShowEventMarkers=true OR EventStore has been configured at the
            % widget level). Otherwise we leave the inner FastSense's own
            % properties untouched — preserving the Phase-1010 default-true
            % behaviour for consumers that bypassed the widget API.
            if obj.ShowEventMarkers || ~isempty(obj.EventStore)
                fp.ShowEventMarkers = obj.ShowEventMarkers;
                fp.EventStore       = obj.EventStore;
            end

            % Slide the X window as new samples arrive on updateData().
            % Forwarded from the widget-level LiveViewMode property so
            % callers can swap between 'reset' (default: window grows to
            % cover all samples — best for short demos), 'follow' (fixed-
            % width window tracking the latest sample — best for long-
            % running deployments), and 'preserve' (frozen at the initial
            % X range — legacy behaviour).
            fp.LiveViewMode = obj.LiveViewMode;

            % Bind data — Tag-first dispatch (v2.0).
            if ~isempty(obj.Tag)
                fp.addTag(obj.Tag);
            elseif ~isempty(obj.DataStoreObj)
                fp.addLine([], [], 'DataStore', obj.DataStoreObj);
            elseif ~isempty(obj.File)
                data = load(obj.File);
                x = data.(obj.XVar);
                y = data.(obj.YVar);
                fp.addLine(x, y);
            elseif ~isempty(obj.XData) && ~isempty(obj.YData)
                fp.addLine(obj.XData, obj.YData);
            end

            % Datenum auto-promotion happens inside FastSense.addLine when
            % the probed X values sit in the MATLAB datenum range
            % (697000..769000 ≈ 1910-2100). No explicit XType handoff
            % needed here.

            % Apply thresholds — must be BEFORE fp.render() (FastSense
            % rejects addThreshold calls after render). Accepted forms:
            %   'auto'                     — no-op (default)
            %   numeric scalar/vector      — one upper threshold per value
            %   cell of structs            — {struct('Value',..,'Direction',..,'Label',..), ...}
            applyThresholds_(fp, obj.Thresholds);

            % Set title and axis labels.
            % Title sits ABOVE the (light) axes area against the panel
            % background, so its color must come from the dashboard theme
            % (ToolbarFontColor) — using ax.XColor leaves the title dark on
            % the dark widget panel in dark mode. XLabel/YLabel sit inside
            % the axes margins but still touch the panel; same fix.
            % Prefer GroupHeaderFg (near-white in dark / near-black in light)
            % over ToolbarFontColor for stronger contrast against the panel.
            titleColor = get(ax, 'XColor');
            try
                t = obj.getTheme();
                if isstruct(t)
                    if isfield(t, 'GroupHeaderFg')
                        titleColor = t.GroupHeaderFg;
                    elseif isfield(t, 'ToolbarFontColor')
                        titleColor = t.ToolbarFontColor;
                    end
                end
            catch
            end
            if ~isempty(obj.Title)
                title(ax, obj.Title, 'Color', titleColor);
            end
            if ~isempty(obj.XLabel)
                xlabel(ax, obj.XLabel, 'Color', titleColor);
            end
            if ~isempty(obj.YLabel)
                ylabel(ax, obj.YLabel, 'Color', titleColor);
            end

            fp.render();

            % Re-apply title/label/tick colors AFTER fp.render(), which
            % restyles the axes using FastSense's own theme (axes-internal
            % colors — dark on white). The title sits ABOVE the axes box,
            % the x/ylabels sit in the OUTSIDE margins, AND the tick labels
            % render in the margins too — so against the dark widget panel
            % they all need the dashboard theme's foreground color.
            try
                if ~isempty(obj.Title),  set(get(ax, 'Title'),  'Color', titleColor); end
                if ~isempty(obj.XLabel), set(get(ax, 'XLabel'), 'Color', titleColor); end
                if ~isempty(obj.YLabel), set(get(ax, 'YLabel'), 'Color', titleColor); end
                % Tick label color (XColor/YColor also control axis line +
                % tick marks; the axes box color stays via FastSense's own
                % styling — only the tick text + line color follow the panel
                % background).
                set(ax, 'XColor', titleColor, 'YColor', titleColor);
            catch
            end

            % Reformat time-axis ticks to HH:MM:SS / MM:SS for readability
            % (main branch addition from #66 / datetime axis migration).
            try obj.formatTimeAxis_(ax); catch, end

            % Apply fixed Y-axis limits if configured; otherwise expand the
            % auto-computed range so threshold lines stay visible even when
            % the initial data range is narrower than the threshold value.
            if ~isempty(obj.YLimits) && numel(obj.YLimits) == 2
                ylim(ax, obj.YLimits);
            else
                yInit = [];
                try
                    if ~isempty(obj.Tag)
                        [~, yInit] = obj.Tag.getXY();
                    elseif ~isempty(obj.YData)
                        yInit = obj.YData;
                    end
                catch
                end
                if ~isempty(yInit)
                    obj.autoScaleY_(yInit);
                end
            end

            % Update time range cache and data-source identity snapshots
            obj.LastTagRef = obj.Tag;
            obj.updateTimeRangeCache();

            % Listen for manual zoom/pan to disable global time for this widget
            try
                addlistener(ax, 'XLim', 'PostSet', @(~,~) obj.onXLimChanged());
            catch
            end
            % Listen for manual Y zoom so autoScaleY_ stops fighting the
            % user after a scroll / drag / programmatic ylim.
            try
                addlistener(ax, 'YLim', 'PostSet', @(~,~) obj.onYLimChanged());
            catch
            end
        end

        function refresh(obj)
            % Re-render Tag-bound widgets so updated data shows.
            % Uses incremental updateData() path when tag identity is unchanged
            % (PERF2-01); falls back to full teardown/rebuild on first render,
            % tag swap, or error.  Zoom state (xlim) is preserved in both paths.

            if isempty(obj.Tag), return; end
            if isempty(obj.hPanel) || ~ishandle(obj.hPanel), return; end
            % Handle identity: MATLAB overloads == for handle subclasses;
            % Octave does not, so fall back to Key-equality (Phase 1006
            % precedent) — semantically equivalent for the refresh fast-path
            % because the only way two tags share a Key is if they were
            % registered through TagRegistry under the same name.
            try
                tagUnchanged = ~isempty(obj.LastTagRef) && obj.Tag == obj.LastTagRef;
            catch
                tagUnchanged = ~isempty(obj.LastTagRef) && ...
                               isa(obj.LastTagRef, 'Tag') && ...
                               strcmp(char(obj.Tag.Key), char(obj.LastTagRef.Key));
            end
            fpValid = ~isempty(obj.FastSenseObj) && ...
                      obj.FastSenseObj.IsRendered && ...
                      ~isempty(obj.FastSenseObj.hAxes) && ...
                      ishandle(obj.FastSenseObj.hAxes);
            if tagUnchanged && fpValid
                try
                    [x, y] = obj.Tag.getXY();
                    obj.FastSenseObj.updateData(1, x, y);
                    obj.autoScaleY_(y);
                    obj.updateTimeRangeCache();
                    obj.invalidatePreviewCache_();   % 260508-das
                    obj.refreshEventMarkers_();      % Phase 1012
                    obj.formatTimeAxis_(obj.FastSenseObj.hAxes);
                    return;
                catch
                    % fall through to full teardown/rebuild
                end
            end
            obj.rebuildForTag_();
            obj.refreshEventMarkers_();  % Phase 1012
        end

        function update(obj)
        %UPDATE Incrementally update Tag data without full axes rebuild.
        %   Uses FastSenseObj.updateData() to replace data and re-downsample,
        %   avoiding the expensive delete/recreate cycle of refresh().
        %   Falls back to refresh() if FastSenseObj is not in a renderable state.

            if isempty(obj.Tag), return; end
            if isempty(obj.hPanel) || ~ishandle(obj.hPanel), return; end
            if ~isempty(obj.FastSenseObj) && obj.FastSenseObj.IsRendered
                try
                    [x, y] = obj.Tag.getXY();
                    obj.FastSenseObj.updateData(1, x, y);
                    obj.autoScaleY_(y);
                    obj.updateTimeRangeCache();
                    obj.invalidatePreviewCache_();   % 260508-das
                    obj.refreshEventMarkers_();      % Phase 1012
                    obj.formatTimeAxis_(obj.FastSenseObj.hAxes);
                    return;
                catch
                    % fall through to refresh()
                end
            end
            obj.refresh();
        end

        function setEventMarkersVisible(obj, tf)
            %SETEVENTMARKERSVISIBLE Pass-through to FastSense event-marker toggle.
            %   No-op when no FastSense instance exists yet (pre-render).
            %   When rendered, delegates to FastSense.setShowEventMarkers
            %   which re-draws the overlay in place without disturbing
            %   zoom state or live refresh cadence.
            %
            %   Also mirrors the runtime visibility into obj.ShowEventMarkers
            %   so that the property is the single source of truth — required
            %   for detach (toStruct/fromStruct round-trip) to reflect the
            %   user's current toggle state instead of the construction-time
            %   default. (260508-eu2 follow-up.)
            obj.ShowEventMarkers = logical(tf);
            if ~isempty(obj.FastSenseObj)
                try
                    obj.FastSenseObj.setShowEventMarkers(tf);
                catch ME
                    warning('FastSenseWidget:eventMarkerToggleFailed', ...
                        'Failed to toggle event markers: %s', ME.message);
                end
            end
        end

        function autoScaleY_(obj, y)
        %AUTOSCALEY_ Rescale the Y axis to cover current data + thresholds.
        %   FastSense locks YLim to manual mode at first render, so new
        %   samples outside the initial range would fall off the chart.
        %   This helper recomputes the Y extent every tick (including any
        %   threshold values so MonitorTag lines stay visible) and updates
        %   the axes. Skipped when:
        %     - the widget has a user-pinned YLimits NV-pair, or
        %     - the user manually zoomed Y via mouse (UserZoomedY), or
        %     - the dashboard's Follow toggle is engaged
        %       (FastSenseObj.LiveViewMode == 'follow') — Follow is an
        %       explicit user intent to track the data tail in X only and
        %       keep the rest of the view (including Y) frozen. (260513-ovt)
        %   so we never fight an explicit human interaction.
            if ~isempty(obj.YLimits)
                return;
            end
            if obj.UserZoomedY
                return;
            end
            if ~isempty(obj.FastSenseObj) && isvalid(obj.FastSenseObj) ...
                    && strcmp(obj.FastSenseObj.LiveViewMode, 'follow')
                return;
            end
            if isempty(obj.FastSenseObj) || ~obj.FastSenseObj.IsRendered
                return;
            end
            ax = obj.FastSenseObj.hAxes;
            if isempty(ax) || ~ishandle(ax)
                return;
            end
            if isempty(y)
                return;
            end
            yMin = min(y(:));
            yMax = max(y(:));
            if iscell(obj.Thresholds)
                for i = 1:numel(obj.Thresholds)
                    e = obj.Thresholds{i};
                    if isstruct(e) && isfield(e, 'Value') && isfinite(e.Value)
                        yMin = min(yMin, e.Value);
                        yMax = max(yMax, e.Value);
                    end
                end
            elseif isnumeric(obj.Thresholds) && ~isempty(obj.Thresholds)
                yMin = min(yMin, min(obj.Thresholds(:)));
                yMax = max(yMax, max(obj.Thresholds(:)));
            end
            if ~isfinite(yMin) || ~isfinite(yMax)
                return;
            end
            if yMax > yMin
                pad = (yMax - yMin) * 0.08;
            else
                pad = max(abs(yMax) * 0.1, 1);
            end
            obj.IsSettingYLim = true;
            try
                set(ax, 'YLim', [yMin - pad, yMax + pad]);
            catch
            end
            obj.IsSettingYLim = false;
        end

        function onYLimChanged(obj)
        %ONYLIMCHANGED Detach widget from automatic Y rescale after user zoom.
        %   Fired by the YLim PostSet listener. When the YLim change came
        %   from inside autoScaleY_ (IsSettingYLim==true) we ignore it; any
        %   other source — mouse scroll, drag, zoom toolbar, programmatic
        %   ylim() from user code — counts as a manual override and
        %   latches UserZoomedY so live ticks stop fighting the user.
            if obj.IsSettingYLim
                return;
            end
            obj.UserZoomedY = true;
        end

        function setTimeRange(obj, tStart, tEnd)
            if ~obj.UseGlobalTime
                return;  % widget has its own zoom, skip global time
            end
            if ~isempty(obj.FastSenseObj)
                try
                    obj.IsSettingTime = true;
                    % Use setXLimQuiet to suppress the XLimMode PostSet
                    % listener (onXLimModeChanged -> scheduleDeferredXLimCheck
                    % -> timer creation) that fires on every plain xlim() call.
                    % This avoids ~4 ms of timer-creation overhead per widget
                    % per live tick when the dashboard broadcasts a time sync.
                    obj.FastSenseObj.setXLimQuiet(tStart, tEnd);
                    obj.IsSettingTime = false;
                catch
                    obj.IsSettingTime = false;
                end
            end
        end

        function onXLimChanged(obj)
            % If xlim changed by user zoom/pan (not by setTimeRange),
            % detach this widget from global time.
            if ~obj.IsSettingTime
                obj.UseGlobalTime = false;
            end
        end

        function [tMin, tMax] = getTimeRange(obj)
            % Return cached min/max in O(1). Cache is kept up to date by
            % updateTimeRangeCache() which is called from render/refresh/update.
            tMin = obj.CachedXMin;
            tMax = obj.CachedXMax;
            if isinf(tMin) || isinf(tMax)
                tMin = inf; tMax = -inf;
            end
        end

        function series = getPreviewSeries(obj, nBuckets)
        %GETPREVIEWSERIES Per-bucket min/max preview for the dashboard envelope.
        %   series = getPreviewSeries(obj, nBuckets) returns a struct with
        %   fields xCenters, yMin, yMax — each a 1xnBucketsEff row vector;
        %   yMin and yMax are normalized into [0,1] across the widget's own
        %   current y-range. Returns [] only when no data is bound or when
        %   the sample count is genuinely too sparse (<4) to downsample.
        %
        %   The bucket count is adaptive: when the caller asks for more
        %   buckets than there are samples, we fall back to
        %   `floor(numel(x)/2)` so live widgets that have only collected a
        %   few hundred samples still render a meaningful preview line on
        %   the slider track. (Backlog 999.3.)
        %
        %   Uses minmax_core_mex (or a pure-MATLAB fallback) for the same
        %   downsampling strategy FastSense rendering uses.
        %
        %   Cached: a private PreviewCache_ short-circuits repeat calls
        %   when (numel(x), x(1), x(end), nBucketsEff) is unchanged; the
        %   cache is invalidated by invalidatePreviewCache_().
            series = [];
            try
                if nargin < 2 || isempty(nBuckets) || ~isfinite(nBuckets) || nBuckets < 1
                    return;
                end
                nBuckets = double(floor(nBuckets));

                % Fetch raw [x, y] from Tag, or from XData/YData.
                x = []; y = [];
                if ~isempty(obj.Tag)
                    try
                        [x, y] = obj.Tag.getXY();
                    catch
                        x = []; y = [];
                    end
                elseif ~isempty(obj.XData) && ~isempty(obj.YData)
                    x = obj.XData;
                    y = obj.YData;
                end

                if isempty(x) || isempty(y) || numel(x) ~= numel(y)
                    return;
                end
                % Adaptive bucket count: never bail on small datasets.
                % Live widgets typically have <200 samples for the first
                % minute of operation; the previous hard floor
                % (numel(x) < nBuckets => return) blanked the slider for
                % the entire warm-up period. We require at least 4 raw
                % samples to bother downsampling at all.
                if numel(x) < 4
                    return;
                end
                if numel(x) <= obj.PreviewRawThreshold_
                    % Below this threshold, render one bucket per raw
                    % sample — full fidelity for small / freshly-live
                    % datasets where downsampling artefacts dominate
                    % the visible slider preview line.
                    nBucketsEff = numel(x);
                else
                    nBucketsEff = max(1, min(nBuckets, floor(numel(x) / 2)));
                end

                % Cache lookup — bit-identical for unchanged data shape.
                cacheKey = [double(numel(x)), double(x(1)), double(x(end)), double(nBucketsEff)];
                if ~isempty(obj.PreviewCache_) && isequal(obj.PreviewCacheKey_, cacheKey)
                    series = obj.PreviewCache_;
                    return;
                end

                % Ensure row vectors of doubles (minmax_core_mex requires double).
                x = double(x(:).');
                y = double(y(:).');

                % Drop NaN pairs (the preview is best-effort, no segmenting).
                nanMask = isnan(x) | isnan(y);
                if any(nanMask)
                    x = x(~nanMask);
                    y = y(~nanMask);
                    if numel(x) < 4
                        return;
                    end
                    if numel(x) <= obj.PreviewRawThreshold_
                        nBucketsEff = numel(x);
                    else
                        nBucketsEff = max(1, min(nBuckets, floor(numel(x) / 2)));
                    end
                end

                % Call MEX when available; otherwise compute per-bucket
                % min/max inline (pure-MATLAB fallback identical in shape).
                useMex = (exist('minmax_core_mex', 'file') == 3);
                if useMex
                    try
                        [xOut, yOut] = minmax_core_mex(x, y, nBucketsEff);
                    catch
                        useMex = false;
                    end
                end
                if ~useMex
                    [xOut, yOut] = localMinMaxBuckets_(x, y, nBucketsEff);
                end

                % Accept BOTH 2*nb (no tail anchor) and 2*nb+1 (anchor
                % appended by minmax cores — 260512-c5x). The slider
                % preview only needs paired (min, max) per bucket; the
                % anchor is informational for the main chart and is
                % safely dropped here before the reshape (drops the
                % single trailing anchor (x, y) pair tail).
                %
                % 260512-cxc: capture the tail anchor BEFORE the drop so we
                % can thread it through to xCenters(end). The drop itself
                % is still required because reshape(xOut, 2, nb) below
                % needs an even-length vector. Without this capture, the
                % slider preview's last bucket freezes at the interior
                % min/max midpoint and never advances under live data
                % growth (visible "stuck preview tail" on the industrial
                % plant demo's reactor.pressure widget).
                anchorX = [];
                anchorY = []; %#ok<NASGU>  % captured for future symmetry;
                                           % yMinB/yMaxB already include
                                           % the anchor's y because
                                           % minmax_core_mex scans the
                                           % full last bucket.
                if numel(xOut) == 2 * nBucketsEff + 1 && numel(yOut) == 2 * nBucketsEff + 1
                    anchorX = xOut(end);
                    anchorY = yOut(end); %#ok<NASGU>
                    xOut = xOut(1:end - 1);
                    yOut = yOut(1:end - 1);
                end
                if numel(xOut) ~= 2 * nBucketsEff || numel(yOut) ~= 2 * nBucketsEff
                    return;
                end

                % Interleaved (min,max) or (max,min) pairs per bucket.
                xPairs = reshape(xOut, 2, nBucketsEff);
                yPairs = reshape(yOut, 2, nBucketsEff);
                yMinB  = min(yPairs, [], 1);
                yMaxB  = max(yPairs, [], 1);
                xCenters = (xPairs(1, :) + xPairs(2, :)) / 2;

                % 260512-cxc: snap the trailing xCenter to the tail anchor
                % when the downsampler appended one. The bucket's interior
                % (min-X, max-X) midpoint can be hundreds of seconds
                % behind segX(end) under steady-state live data — the
                % main chart's tail-anchor fix (260512-c5x) made the
                % rendered line advance, but the slider preview was still
                % reading the interior midpoint. Guard against
                % anchorX <= xCenters(end) to preserve strict monotonicity
                % (the drop-and-override is purely additive in the X
                % dimension).
                if ~isempty(anchorX) && anchorX > xCenters(end)
                    xCenters(end) = anchorX;
                end

                % Determine y-range: prefer current axes YLim; fallback to data.
                yRange = [];
                if ~isempty(obj.FastSenseObj) && ~isempty(obj.FastSenseObj.hAxes) && ...
                        ishandle(obj.FastSenseObj.hAxes)
                    try
                        yl = get(obj.FastSenseObj.hAxes, 'YLim');
                        if numel(yl) == 2 && all(isfinite(yl)) && yl(2) > yl(1)
                            yRange = [yl(1), yl(2)];
                        end
                    catch
                    end
                end
                if isempty(yRange)
                    yMn = min(y); yMx = max(y);
                    if isfinite(yMn) && isfinite(yMx) && yMx > yMn
                        yRange = [yMn, yMx];
                    end
                end
                if isempty(yRange) || (yRange(2) - yRange(1)) == 0
                    return;
                end

                denom = yRange(2) - yRange(1);
                yMinN = (yMinB - yRange(1)) / denom;
                yMaxN = (yMaxB - yRange(1)) / denom;
                % Clamp to [0, 1].
                yMinN = max(0, min(1, yMinN));
                yMaxN = max(0, min(1, yMaxN));

                series = struct('xCenters', xCenters, ...
                                'yMin',     yMinN, ...
                                'yMax',     yMaxN);
                obj.PreviewCache_    = series;
                obj.PreviewCacheKey_ = cacheKey;
            catch
                % Best-effort: swallow any error and opt out of envelope.
                series = [];
            end
        end

        function t = getEventTimes(obj)
        %GETEVENTTIMES Event start times for the dashboard time-slider markers.
        %   Looks up events in this priority order:
        %     1. obj.EventStore  (widget-level — the modern attachment point)
        %     2. obj.FastSenseObj.EventStore  (legacy: events on inner FastSense)
        %     3. obj.FastSenseObj.Events / .EventTimes  (defensive: extra hooks)
        %
        %   Returns [] (and never throws) when no source yields events.
        %   The widget-level lookup was added in 260508-das after the
        %   slider markers regressed: most modern dashboards attach an
        %   EventStore on the widget (which is then forwarded to the
        %   inner FastSense at render time), but some pre-render flows
        %   would already query getEventTimes before that forwarding had
        %   run.
            t = [];
            try
                raw = [];
                % Priority 1: widget-level EventStore (modern path).
                if ~isempty(obj.EventStore)
                    try
                        raw = obj.EventStore.getEvents();
                    catch
                        raw = [];
                    end
                end
                % Priority 2: inner FastSense's EventStore.
                if isempty(raw) && ~isempty(obj.FastSenseObj) && ...
                        isa(obj.FastSenseObj, 'FastSense') && ...
                        isprop(obj.FastSenseObj, 'EventStore') && ...
                        ~isempty(obj.FastSenseObj.EventStore)
                    try
                        raw = obj.FastSenseObj.EventStore.getEvents();
                    catch
                        raw = [];
                    end
                end
                % Priority 3: defensive — bare struct array on FastSense.
                if isempty(raw) && ~isempty(obj.FastSenseObj) && ...
                        isa(obj.FastSenseObj, 'FastSense')
                    if isprop(obj.FastSenseObj, 'Events') && ~isempty(obj.FastSenseObj.Events)
                        raw = obj.FastSenseObj.Events;
                    end
                end
                if isempty(raw), return; end
                n = numel(raw);
                tmp = zeros(1, n);
                for i = 1:n
                    if isstruct(raw)
                        if isfield(raw, 'StartTime')
                            tmp(i) = raw(i).StartTime;
                        elseif isfield(raw, 'startTime')
                            tmp(i) = raw(i).startTime;
                        else
                            tmp(i) = NaN;
                        end
                    else
                        % Object array (Event/Event-like)
                        if isprop(raw(i), 'StartTime')
                            tmp(i) = raw(i).StartTime;
                        else
                            tmp(i) = NaN;
                        end
                    end
                end
                tmp = tmp(isfinite(tmp));
                t = tmp(:).';
            catch
                t = [];
            end
        end

        function m = getEventMarkers(obj)
        %GETEVENTMARKERS Per-event time + severity + color for slider markers.
        %   m = getEventMarkers(obj) returns a struct array with fields:
        %     m(k).Time     — numeric timestamp (StartTime)
        %     m(k).Severity — numeric severity in {1,2,3} (default 1 if absent)
        %     m(k).Color    — 1x3 RGB triplet from severityColor(theme, sev)
        %
        %   Walks the same priority chain as getEventTimes (widget-level
        %   EventStore -> inner FastSense.EventStore -> bare Events array),
        %   so the slider markers stay in sync with whatever events the
        %   widget would otherwise display. Always returns an empty struct
        %   array (struct('Time',{},'Severity',{},'Color',{})) when no
        %   source yields events; never throws.
        %
        %   The Color is the *base* per-severity palette color — the
        %   TimeRangeSelector blends it toward AxesColor at draw time.
        %   Tiebreaker on duplicate Times across widgets is resolved by
        %   DashboardEngine.computeEventMarkers using the Severity field.
            m = struct('Time', {}, 'Severity', {}, 'Color', {});
            try
                raw = [];
                if ~isempty(obj.EventStore)
                    try
                        raw = obj.EventStore.getEvents();
                    catch
                        raw = [];
                    end
                end
                if isempty(raw) && ~isempty(obj.FastSenseObj) && ...
                        isa(obj.FastSenseObj, 'FastSense') && ...
                        isprop(obj.FastSenseObj, 'EventStore') && ...
                        ~isempty(obj.FastSenseObj.EventStore)
                    try
                        raw = obj.FastSenseObj.EventStore.getEvents();
                    catch
                        raw = [];
                    end
                end
                if isempty(raw) && ~isempty(obj.FastSenseObj) && ...
                        isa(obj.FastSenseObj, 'FastSense')
                    if isprop(obj.FastSenseObj, 'Events') && ~isempty(obj.FastSenseObj.Events)
                        raw = obj.FastSenseObj.Events;
                    end
                end
                if isempty(raw), return; end

                % Resolve theme once — getTheme() is inherited from
                % DashboardWidget. Tolerate failures (returns []).
                theme = [];
                try
                    theme = obj.getTheme();
                catch
                    theme = [];
                end

                n = numel(raw);
                for i = 1:n
                    t = NaN;
                    sev = 1;
                    if isstruct(raw)
                        if isfield(raw, 'StartTime')
                            t = raw(i).StartTime;
                        elseif isfield(raw, 'startTime')
                            t = raw(i).startTime;
                        end
                        if isfield(raw, 'Severity') && ~isempty(raw(i).Severity)
                            sev = raw(i).Severity;
                        elseif isfield(raw, 'severity') && ~isempty(raw(i).severity)
                            sev = raw(i).severity;
                        end
                    else
                        if isprop(raw(i), 'StartTime')
                            t = raw(i).StartTime;
                        end
                        if isprop(raw(i), 'Severity') && ~isempty(raw(i).Severity)
                            sev = raw(i).Severity;
                        end
                    end
                    if ~isnumeric(t) || ~isfinite(t)
                        continue;
                    end
                    if ~isnumeric(sev) || isempty(sev) || ~isfinite(sev(1))
                        sev = 1;
                    else
                        sev = sev(1);
                    end
                    m(end + 1) = struct( ...
                        'Time',     t, ...
                        'Severity', sev, ...
                        'Color',    severityColor(theme, sev)); %#ok<AGROW>
                end
            catch
                m = struct('Time', {}, 'Severity', {}, 'Color', {});
            end
        end

        function invalidatePreviewCache_(obj)
        %INVALIDATEPREVIEWCACHE_ Clear PreviewCache_ so getPreviewSeries recomputes.
        %   Called from refresh() / update() / rebuildForTag_() whenever
        %   the underlying data may have changed. Cheap (no graphics).
            obj.PreviewCache_    = [];
            obj.PreviewCacheKey_ = [];
        end

        function t = getType(~)
            t = 'fastsense';
        end

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            yData = [];
            if ~isempty(obj.Tag)
                try
                    [~, yData] = obj.Tag.getXY();
                catch
                    yData = [];
                end
            elseif ~isempty(obj.YData)
                yData = obj.YData;
            end

            if ~isempty(yData) && height >= 2
                bars = char(9601):char(9608);
                nBars = numel(bars);
                yMin = min(yData); yMax = max(yData);
                if yMax == yMin, yMax = yMin + 1; end
                nPts = min(numel(yData), width);
                idx = round(linspace(1, numel(yData), nPts));
                sampled = yData(idx);
                spark = blanks(nPts);
                for si = 1:nPts
                    level = round((sampled(si) - yMin) / (yMax - yMin) * (nBars - 1)) + 1;
                    level = max(1, min(nBars, level));
                    spark(si) = bars(level);
                end
                if numel(spark) < width
                    spark = [spark, repmat(' ', 1, width - numel(spark))];
                end
                lines{2} = spark(1:width);
            elseif height >= 2
                ph = '[~~ fastsense ~~]';
                if numel(ph) > width, ph = ph(1:width); end
                lines{2} = [ph, repmat(' ', 1, width - numel(ph))];
            end
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.XLabel), s.xLabel = obj.XLabel; end
            if ~isempty(obj.YLabel), s.yLabel = obj.YLabel; end
            if ~isempty(obj.YLimits), s.yLimits = obj.YLimits; end
            if obj.ShowThresholdLabels, s.showThresholdLabels = true; end
            if obj.ShowEventMarkers, s.showEventMarkers = true; end
            % NOTE: EventStore is a runtime handle — intentionally NOT serialized (Pitfall E).

            if ~isempty(obj.Tag) && ~isempty(obj.Tag.Key)
                s.source = struct('type', 'tag', 'key', obj.Tag.Key);
                s.thresholds = obj.Thresholds;
            elseif ~isempty(obj.File)
                s.source = struct('type', 'file', 'path', obj.File, ...
                                  'xVar', obj.XVar, 'yVar', obj.YVar);
            elseif ~isempty(obj.XData)
                s.source = struct('type', 'data', 'x', obj.XData, 'y', obj.YData);
            end
        end

        function delete(obj)
            % Explicitly stop FastSense timers (hRefineTimer, LiveTimer,
            % DeferredTimer) before the base-class delete() destroys hPanel.
            % Without this, an errored singleShot hRefineTimer can survive
            % after teardownDemo and show up in timerfindall().
            if ~isempty(obj.FastSenseObj)
                try delete(obj.FastSenseObj); catch, end
                obj.FastSenseObj = [];
            end
            delete@DashboardWidget(obj);
        end
    end

    methods (Access = private)
        function refreshEventMarkers_(obj)
            %REFRESHEVENTMARKERS_ Diff LastEventIds_/LastEventOpen_ vs current EventStore state.
            %   Triggers inner FastSense.refreshEventLayer() on any change: added/removed
            %   events, or open-to-closed transitions. Always updates the cache.
            if ~obj.ShowEventMarkers || isempty(obj.EventStore) || isempty(obj.Tag), return; end
            if isempty(obj.FastSenseObj) || ~obj.FastSenseObj.IsRendered, return; end
            events = obj.EventStore.getEventsForTag(char(obj.Tag.Key));
            nE = numel(events);
            ids = cell(1, nE);
            openFlags = false(1, nE);
            sevs      = zeros(1, nE);
            for k = 1:nE
                ids{k} = events(k).Id;
                openFlags(k) = logical(events(k).IsOpen);
                sevs(k)      = double(events(k).Severity);
            end
            changed = false;
            if numel(ids) ~= numel(obj.LastEventIds_)
                changed = true;
            else
                for k = 1:nE
                    if ~any(strcmp(ids{k}, obj.LastEventIds_))
                        changed = true; break;
                    end
                    idx = find(strcmp(ids{k}, obj.LastEventIds_), 1);
                    if isempty(idx); continue; end
                    if obj.LastEventOpen_(idx) ~= openFlags(k)
                        changed = true; break;   % open <-> closed transition
                    end
                    if ~isempty(obj.LastEventSeverity_) && ...
                            idx <= numel(obj.LastEventSeverity_) && ...
                            obj.LastEventSeverity_(idx) ~= sevs(k)
                        changed = true; break;   % severity bumped -> re-color
                    end
                end
            end
            if changed
                obj.FastSenseObj.refreshEventLayer();
            end
            obj.LastEventIds_      = ids;
            obj.LastEventOpen_     = openFlags;
            obj.LastEventSeverity_ = sevs;
        end

        function formatTimeAxis_(~, ax)
        %FORMATTIMEAXIS_ Replace numeric-seconds x-ticks with HH:MM:SS labels.
        %   No-op when range <= 300s (raw seconds readable) or ax invalid.
            if isempty(ax) || ~ishandle(ax), return; end
            xl = get(ax, 'XLim');
            rangeSec = xl(2) - xl(1);
            if rangeSec <= 300, return; end
            xt = get(ax, 'XTick');
            if isempty(xt), return; end
            if rangeSec >= 3600
                fmt = 'HH:MM:SS';
            else
                fmt = 'MM:SS';
            end
            lbl = cell(1, numel(xt));
            for i = 1:numel(xt)
                % xt(i) is seconds; serial-date day = seconds / 86400
                lbl{i} = datestr(xt(i) / 86400, fmt);
            end
            set(ax, 'XTickMode', 'manual', 'XTickLabelMode', 'manual', ...
                'XTickLabel', lbl);
        end

        function updateTimeRangeCache(obj)
        %UPDATETIMERANGECACHE Maintain CachedXMin/CachedXMax incrementally.
        %   For sorted time arrays (the common case) the last element is the
        %   max candidate and the first is the min candidate, so this avoids
        %   a full-array scan on every live tick.
            if ~isempty(obj.Tag)
                try
                    [x, ~] = obj.Tag.getXY();
                    n = numel(x);
                    if n == 0
                        obj.CachedXMin = inf;
                        obj.CachedXMax = -inf;
                        return;
                    end
                    obj.CachedXMax = x(n);
                    if isinf(obj.CachedXMin)
                        obj.CachedXMin = x(1);
                    end
                catch
                    obj.CachedXMin = inf;
                    obj.CachedXMax = -inf;
                end
                return;
            end
            if ~isempty(obj.XData)
                obj.CachedXMin = min(obj.XData);
                obj.CachedXMax = max(obj.XData);
            else
                obj.CachedXMin = inf;
                obj.CachedXMax = -inf;
            end
        end

        function rebuildForTag_(obj)
        %REBUILDFORTAG_ Full teardown + rebuild FastSense from obj.Tag.
        %   Preserves zoom state (xlim) across the rebuild.
            % Save zoom state before teardown
            savedXLim = [];
            if ~isempty(obj.FastSenseObj) && ~isempty(obj.FastSenseObj.hAxes) && ...
                    ishandle(obj.FastSenseObj.hAxes)
                savedXLim = get(obj.FastSenseObj.hAxes, 'XLim');
            end

            % Delete old FastSense + leftover axes in the panel
            if ~isempty(obj.FastSenseObj)
                try delete(obj.FastSenseObj); catch, end
                obj.FastSenseObj = [];
            end
            ch = findobj(obj.hPanel, 'Type', 'axes');
            delete(ch);

            ax = axes('Parent', obj.hPanel, ...
                'Units', 'normalized', ...
                'Position', [0.08 0.12 0.88 0.78]);

            fp = FastSense('Parent', ax);
            obj.FastSenseObj = fp;
            fp.ShowThresholdLabels = obj.ShowThresholdLabels;
            % Phase 1012 — guarded forwarding (see render() comment above).
            if obj.ShowEventMarkers || ~isempty(obj.EventStore)
                fp.ShowEventMarkers = obj.ShowEventMarkers;
                fp.EventStore       = obj.EventStore;
            end
            fp.addTag(obj.Tag);

            % See render() — title sits above the axes against the panel,
            % so use the dashboard theme's ToolbarFontColor for legibility.
            % Prefer GroupHeaderFg (near-white in dark / near-black in light)
            % over ToolbarFontColor for stronger contrast against the panel.
            titleColor = get(ax, 'XColor');
            try
                t = obj.getTheme();
                if isstruct(t)
                    if isfield(t, 'GroupHeaderFg')
                        titleColor = t.GroupHeaderFg;
                    elseif isfield(t, 'ToolbarFontColor')
                        titleColor = t.ToolbarFontColor;
                    end
                end
            catch
            end
            if ~isempty(obj.Title)
                title(ax, obj.Title, 'Color', titleColor);
            end
            if ~isempty(obj.XLabel)
                xlabel(ax, obj.XLabel, 'Color', titleColor);
            end
            if ~isempty(obj.YLabel)
                ylabel(ax, obj.YLabel, 'Color', titleColor);
            end

            fp.render();

            % Reformat time-axis ticks to HH:MM:SS / MM:SS for readability.
            obj.formatTimeAxis_(ax);

            if ~isempty(obj.YLimits) && numel(obj.YLimits) == 2
                ylim(ax, obj.YLimits);
            end

            obj.LastTagRef = obj.Tag;
            obj.updateTimeRangeCache();
            obj.invalidatePreviewCache_();   % 260508-das

            if ~isempty(savedXLim)
                obj.IsSettingTime = true;
                xlim(ax, savedXLim);
                obj.IsSettingTime = false;
            end

            try
                addlistener(ax, 'XLim', 'PostSet', @(~,~) obj.onXLimChanged());
            catch
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = FastSenseWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];

            if isfield(s, 'description')
                obj.Description = s.description;
            end

            if isfield(s, 'source')
                switch s.source.type
                    case 'tag'
                        if exist('TagRegistry', 'class')
                            try
                                obj.Tag = TagRegistry.get(s.source.key);
                            catch
                                warning('FastSenseWidget:tagNotFound', ...
                                    'TagRegistry key ''%s'' not found.', s.source.key);
                            end
                        end
                    case 'sensor'
                        % Backward compat: old JSON with type='sensor' resolves via TagRegistry.
                        if exist('TagRegistry', 'class')
                            try
                                obj.Tag = TagRegistry.get(s.source.name);
                            catch
                                % Tag not in registry; resolver will
                                % bind it in configToWidgets if provided.
                            end
                        end
                    case 'file'
                        obj.File = s.source.path;
                        obj.XVar = s.source.xVar;
                        obj.YVar = s.source.yVar;
                    case 'data'
                        obj.XData = s.source.x(:).';
                        obj.YData = s.source.y(:).';
                end
            end

            if isfield(s, 'thresholds')
                obj.Thresholds = s.thresholds;
            end
            if isfield(s, 'xLabel')
                obj.XLabel = s.xLabel;
            end
            if isfield(s, 'yLabel')
                obj.YLabel = s.yLabel;
            end
            if isfield(s, 'yLimits')
                obj.YLimits = s.yLimits;
            end
            if isfield(s, 'showThresholdLabels')
                obj.ShowThresholdLabels = s.showThresholdLabels;
            end
            if isfield(s, 'showEventMarkers')
                obj.ShowEventMarkers = s.showEventMarkers;
            end
        end
    end
end

function applyThresholds_(fp, spec)
    %APPLYTHRESHOLDS_ Push a Thresholds spec into a FastSense instance.
    %   Accepts 'auto' / [] (no-op), numeric scalar/vector (upper lines),
    %   or a cell of structs with fields Value / Direction / Label.
    if isempty(spec)
        return;
    end
    if ischar(spec) || (isstring(spec) && isscalar(spec))
        % 'auto' (or any other string) means "no thresholds wired".
        return;
    end
    if isnumeric(spec)
        for i = 1:numel(spec)
            fp.addThreshold(spec(i), 'Direction', 'upper');
        end
        return;
    end
    if iscell(spec)
        for i = 1:numel(spec)
            e = spec{i};
            if ~isstruct(e) || ~isfield(e, 'Value')
                continue;
            end
            dir = 'upper';
            if isfield(e, 'Direction') && ~isempty(e.Direction)
                dir = e.Direction;
            end
            lbl = '';
            if isfield(e, 'Label') && ~isempty(e.Label)
                lbl = e.Label;
            end
            if isempty(lbl)
                fp.addThreshold(e.Value, 'Direction', dir);
            else
                fp.addThreshold(e.Value, 'Direction', dir, 'Label', lbl);
            end
        end
    end
end

function [xOut, yOut] = localMinMaxBuckets_(x, y, nb)
    %LOCALMINMAXBUCKETS_ Pure-MATLAB fallback for minmax_core_mex.
    %   Returns [xOut, yOut] of length 2*nb interleaved as (min, max) or
    %   (max, min) per bucket, preserving X monotonicity. This mirrors the
    %   behavior of FastSense's private minmax_core without depending on
    %   its private folder.
    n = numel(y);
    bucketSize = floor(n / nb);
    if bucketSize < 1
        xOut = [];
        yOut = [];
        return;
    end
    usable = bucketSize * nb;
    yMat = reshape(y(1:usable), bucketSize, nb);

    [yMinVals, iMin] = min(yMat, [], 1);
    [yMaxVals, iMax] = max(yMat, [], 1);

    offsets = (0:nb-1) * bucketSize;
    gMin = iMin + offsets;
    gMax = iMax + offsets;

    if usable < n
        remY = y(usable+1:end);
        [remMinVal, remMinIdx] = min(remY);
        [remMaxVal, remMaxIdx] = max(remY);
        if remMinVal < yMinVals(nb)
            yMinVals(nb) = remMinVal;
            gMin(nb) = remMinIdx + usable;
        end
        if remMaxVal > yMaxVals(nb)
            yMaxVals(nb) = remMaxVal;
            gMax(nb) = remMaxIdx + usable;
        end
    end

    xMinVals = x(gMin);
    xMaxVals = x(gMax);
    minFirst = gMin <= gMax;

    xOut = zeros(1, 2 * nb);
    yOut = zeros(1, 2 * nb);
    odd  = 1:2:2*nb;
    even = 2:2:2*nb;

    xOut(odd(minFirst))   = xMinVals(minFirst);
    yOut(odd(minFirst))   = yMinVals(minFirst);
    xOut(even(minFirst))  = xMaxVals(minFirst);
    yOut(even(minFirst))  = yMaxVals(minFirst);

    xOut(odd(~minFirst))  = xMaxVals(~minFirst);
    yOut(odd(~minFirst))  = yMaxVals(~minFirst);
    xOut(even(~minFirst)) = xMinVals(~minFirst);
    yOut(even(~minFirst)) = yMinVals(~minFirst);

    % Tail-anchor (260512-c5x): mirrors minmax_core_mex.c — append
    % (x(end), y(end)) iff its X strictly exceeds the last emitted X
    % so the rendered line pins to the data tail. Output length:
    % 2*nb or 2*nb+1.
    if x(end) > xOut(end)
        xOut(end + 1) = x(end);
        yOut(end + 1) = y(end);
    end
end
