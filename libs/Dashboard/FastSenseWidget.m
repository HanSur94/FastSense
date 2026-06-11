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
        ShowPlantLog        = false % Phase 1032 PLOG-VIZ-03 — opt-in per-widget plant-log vertical-line overlay
        % Forwarded to FastSense.LiveViewMode on render:
        %   'preserve' — DEFAULT (260513-ovt). Frozen at the initial X
        %                range: live ticks append data without changing
        %                XLim. The user opts into seeing new data via the
        %                Follow toggle, by dragging the slider, or by
        %                clicking the toolbar's Reset/Sync-All button.
        %                This makes Live mode a "data flows in, my view
        %                stays put" experience.
        %   'follow'   — window of current width tracks the latest sample
        %                (use for long-running deployments where the full
        %                range would exhaust memory / downsampling budget;
        %                also what the Follow toolbar toggle switches to)
        %   'reset'    — window covers the full X range every tick (former
        %                default; XLim grows automatically to show every
        %                sample since session start — useful for short
        %                demos where you want to see the chart fill up)
        LiveViewMode = 'preserve'

        % YLimitMode — Y-axis rescale strategy applied by autoScaleY_:
        %   'auto-visible' (DEFAULT) — rescale to cover data inside the
        %                              current X window. Reproduces the
        %                              pre-260513-sfp behaviour exactly
        %                              (so old dashboards behave identically).
        %   'auto-all'              — rescale to cover ALL data the bound
        %                              Tag exposes, regardless of current
        %                              XLim. Equivalent to a global "fit Y
        %                              to the whole timeline" command.
        %   'locked'                — freeze current YLim. Live ticks /
        %                              refresh / update no longer call
        %                              set(ax, 'YLim', ...).
        %
        % Precedence (autoScaleY_ guards, top-to-bottom):
        %   1. Non-empty YLimits pin -> always wins (explicit numeric pin).
        %   2. UserZoomedY latch     -> mouse-zoom freezes autoscale until
        %                               user explicitly re-clicks a mode
        %                               (setYLimitMode clears this latch).
        %   3. FastSenseObj.LiveViewMode == 'follow' -> Follow toggle wins
        %                               (260513-ovt: tail-track in X only,
        %                               keep Y frozen).
        %   4. YLimitMode dispatch:    'locked' -> no-op; otherwise
        %                              auto-visible / auto-all branches run.
        YLimitMode = 'auto-visible'

        % CrosshairLinked — when true this widget joins the active-page
        %   crosshair-link set (260602-mri). Moving the hover crosshair
        %   over any linked FastSenseWidget broadcasts the data-x to all
        %   OTHER linked widgets on the same page, so each mirrors the
        %   crosshair + per-series datatip at that x for cross-plot
        %   comparison. Default false -> backward-compatible (existing
        %   dashboards and serialized JSON are byte-identical).
        CrosshairLinked = false
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
        TimeWindow_        = []    % [t0 t1] datenum pushed by DashboardEngine.setTimeWindow; [] = full range
        ShowingEmptyState_ = false % true while 'No data in selected range' label is rendered
        % 260609-v5p data-unchanged fast path. Fingerprint is [numel(x), x(1),
        % x(end), y(end)] — valid ONLY under the APPEND-ONLY assumption shared
        % with PreviewCacheKey_. Reset to [] by setTimeWindow and rebuildForTag_
        % so a window change or tag rebuild forces a full update on the next tick.
        LastDataFingerprint_ = []
        % 260610-ov3 render-scoped Tag-data cache. Stores struct('x',x,'y',y)
        % for the duration of a single render()/rebuildForTag_() pass so the
        % probe-pull, bind, yInit, updateTimeRangeCache, and getPreviewSeries
        % steps all consume the SAME resolved arrays without calling Tag.getXY
        % or getXYRange more than once per render pass.
        % Cleared at the end of render()/rebuildForTag_() and never read by
        % refresh()/update() — the live tick paths keep their own 260609-v5p
        % fingerprint fast-path.
        RenderDataCache_ = []
    end

    % Phase 1032 — XLim listener slot. Public READ (tests + engine
    % observe); WRITE via the Hidden setPlantLogXLimListenerForEngine_
    % setter just below. Plain SetAccess = private avoids the
    % friend-access classdef syntax that Octave's parser is fussy with
    % (mirrors the FastSenseDataStore Octave-safe idiom — Hidden over
    % {?ClassName}).
    properties (SetAccess = private)
        PlantLogXLimListener_ = [] % Phase 1032 — addlistener handle for XLim PostSet refresh; non-empty when ShowPlantLog=true and widget is rendered
        CurrentViewXLimListener_ = [] % Phase 1039 — addlistener handle for the current-view-box XLim PostSet notify; engine owns lifecycle
    end

    properties (Hidden)
        % Phase 1039 test seam. When non-empty (1x2), getCurrentXLim returns it
        % verbatim instead of reading the live axes. Lets integration tests drive
        % the engine's current-view decision deterministically — FastSense rebuilds
        % its axes on zoom-re-resolve, so a raw programmatic xlim() poke is not a
        % durable way to simulate "this widget is showing a sub-window" under the
        % unittest runner's event flushing. The real axes<->getCurrentXLim path is
        % covered separately by TestFastSenseWidgetCurrentXLim. Empty in production.
        CurrentXLimOverrideForTest_ = []
        % 260609-v5p test seam. Set to true by the fast path when a live tick
        % detected unchanged data fingerprint and skipped the full update path.
        % Set to false when new samples are detected and the full path runs.
        LastTickSkipped_ = false
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

    methods (Hidden)
        function c = getRenderCacheForTest_(obj)
        %GETRENDERCACHEFORTEST_ 260610-ov3 test seam — return RenderDataCache_ value.
        %   Hidden (not public) so the DashboardWidget contract is unchanged.
        %   Used by test_fastsense_widget_render_cache.m and
        %   test_dashboard_load_perf.m to verify the cache lifecycle (cold on
        %   construction, warm after render(), cleared by live-tick entry).
            c = obj.RenderDataCache_;
        end

        function setRenderCacheForTest_(obj, x, y)
        %SETRENDERCACHEFORTEST_ 260610-ov3 test seam — force-warm RenderDataCache_.
        %   Lets test_dashboard_load_perf.m call getPreviewSeries with a
        %   warm cache without going through render(), verifying the
        %   consume-once reuse. Passing empty x AND y clears the cache.
            if isempty(x) && isempty(y)
                obj.clearRenderCache_();
            else
                obj.RenderDataCache_ = struct('x', x, 'y', y);
            end
        end
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
            obj.ShowingEmptyState_ = false;

            % Early empty-state check for Tag-bound windowed or disk-backed paths.
            % For a NON-EMPTY window: probe via pullData_() = getXYRange(t0,t1).
            % For an EMPTY window on a DISK-backed tag: probe full extent via
            % getTimeRange() + getXYRange(tMin,tMax) (the 'All data' disk fix).
            % If the probed data is empty, render the 'No data in selected range'
            % label directly into parentPanel and return before creating axes.
            % Cache the probed [xw,yw] so the bind block below can reuse them
            % without a second getXYRange call.
            xw = [];
            yw = [];
            needsProbeCheck_ = false;
            if ~isempty(obj.Tag)
                if ~isempty(obj.TimeWindow_)
                    needsProbeCheck_ = true;
                    try
                        [xw, yw] = obj.pullData_();
                    catch
                        xw = [];
                        yw = [];
                    end
                elseif ismethod(obj.Tag, 'isOnDisk') && obj.Tag.isOnDisk()
                    needsProbeCheck_ = true;
                    try
                        [tMin, tMax] = obj.Tag.getTimeRange();
                        [xw, yw] = obj.Tag.getXYRange(tMin, tMax);
                    catch
                        xw = [];
                        yw = [];
                    end
                end
                if needsProbeCheck_ && isempty(xw)
                    obj.renderEmptyState_(parentPanel);
                    obj.ShowingEmptyState_ = true;
                    return;
                end
                % 260610-ov3: seed render cache with the probe result so
                % the bind block, yInit, and updateTimeRangeCache all reuse
                % the SAME resolved arrays without a second Tag.getXY /
                % getXYRange call.  Only seed when the probe block ran
                % (needsProbeCheck_=true) and produced non-empty data;
                % in-RAM non-disk branches (3) pull via pullDataCached_()
                % on first access below.
                if needsProbeCheck_ && ~isempty(xw)
                    obj.cacheRenderData_(xw, yw);
                end
            end

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
            % Phase 1017: resolve EventStore via registry default if no
            % explicit per-widget handle was provided. This ensures the
            % inner FastSense receives the registry-default store at
            % render time even when ShowEventMarkers was not explicitly
            % set true on the widget.
            esForward = obj.EventStore;
            if isempty(esForward)
                esForward = TagRegistry.getEventStore();
            end
            if obj.ShowEventMarkers || ~isempty(esForward)
                fp.ShowEventMarkers = obj.ShowEventMarkers;
                fp.EventStore       = esForward;
            end

            % Slide the X window as new samples arrive on updateData().
            % Forwarded from the widget-level LiveViewMode property:
            %   'preserve' — DEFAULT (260513-ovt): frozen at the initial
            %                X range; live ticks append data only
            %   'follow'   — fixed-width window tracking the latest sample
            %   'reset'    — window grows to cover all samples since
            %                session start (former default)
            fp.LiveViewMode = obj.LiveViewMode;

            % Bind data — Tag-first dispatch (v2.0).
            % THREE-WAY branch on the Tag path (Phase 1041-03):
            %   (1) TimeWindow_ non-empty  -> bind windowed arrays via fp.addLine.
            %       getXYRange routes through DataStore.getRange for disk-backed
            %       sensors (overlapping chunks only) and binary-search-slices in RAM.
            %       xw/yw were probed above — reuse to avoid a second call.
            %   (2) TimeWindow_ empty AND tag is disk-backed ('All data' preset fix):
            %       getXY() is EMPTY on disk; fp.addTag would bind a BLANK line.
            %       Resolve full extent via getXYRange(getTimeRange()) -> fp.addLine.
            %       xw/yw were probed above — reuse here too.
            %   (3) TimeWindow_ empty AND tag is NOT disk-backed (in-RAM SensorTag,
            %       Derived/Composite/State/Monitor): byte-identical to today.
            if ~isempty(obj.Tag)
                if ~isempty(obj.TimeWindow_)
                    % (1) Windowed: xw already fetched by the probe block above.
                    % Empty case was caught there (returned early), so xw is non-empty here.
                    fp.addLine(xw, yw, 'DisplayName', obj.Tag.Name);
                elseif ismethod(obj.Tag, 'isOnDisk') && obj.Tag.isOnDisk()
                    % (2) Empty window + DISK-backed: xw is full-extent data from above.
                    fp.addLine(xw, yw, 'DisplayName', obj.Tag.Name);
                else
                    % (3) Empty window + in-RAM tag: 260610-ov3 — resolve ONCE via
                    % pullDataCached_() and bind via fp.addLine so the same arrays
                    % flow to yInit and updateTimeRangeCache without a second pull.
                    % EXCEPTION: State tags use fp.addTag so their staircase rendering
                    % (to_step_function_mex / state-change dispatch) is preserved.
                    % ismethod guard keeps non-standard Tag subclasses on the safe
                    % fp.addTag path if they do not expose getKind().
                    isStateLike = ismethod(obj.Tag, 'getKind') && ...
                                  strcmp(obj.Tag.getKind(), 'state');
                    if isStateLike
                        fp.addTag(obj.Tag);
                    else
                        try
                            [xb, yb] = obj.pullDataCached_();
                            fp.addLine(xb, yb, 'DisplayName', obj.Tag.Name);
                        catch
                            fp.addTag(obj.Tag);  % safe fallback
                        end
                    end
                end
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
            %                                entries may instead carry X/Y vectors for a
            %                                time-varying limit: struct('X',..,'Y',..,'Direction',..)
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
                        % 260610-ov3: reuse render cache (warm since bind above);
                        % avoids a redundant getXY/getXYRange call for yInit.
                        [~, yInit] = obj.pullDataCached_();
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
            % 260610-ov3: pass cached x when the cache is warm so
            % updateTimeRangeCache does not call Tag.getXY a second time.
            obj.LastTagRef = obj.Tag;
            if ~isempty(obj.Tag) && ~isempty(obj.RenderDataCache_)
                try
                    [xc, ~] = obj.pullDataCached_();
                    obj.updateTimeRangeCache(xc);
                catch
                    obj.updateTimeRangeCache();
                end
            else
                obj.updateTimeRangeCache();
            end

            % 260610-ov3: the render cache stays warm here on purpose — the
            % engine's post-render preview pass (computePreviewEnvelope ->
            % getPreviewSeries) consumes and clears it. refresh()/update()
            % clear it on entry so live ticks never see render-time data.

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
            % 260610-ov3: live ticks must never read render-scoped data.
            obj.clearRenderCache_();
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
            if tagUnchanged && ~obj.ShowingEmptyState_ && fpValid
                try
                    [x, y] = obj.pullData_();
                    % 260609-v5p data-unchanged fast path. Build a compact
                    % fingerprint [n, x(1), x(end), y(end)]; NaN slots when
                    % the array is empty so isequal comparisons stay scalar.
                    % ASSUMES append-only time series (same contract as
                    % PreviewCacheKey_). A window change or rebuild resets
                    % LastDataFingerprint_ to [] to force the full path.
                    n = numel(x);
                    if n > 0
                        fp = [n, x(1), x(end), y(end)];
                    else
                        fp = [0, NaN, NaN, NaN];
                    end
                    if isequal(fp, obj.LastDataFingerprint_)
                        % Data unchanged — skip the expensive update path.
                        obj.LastTickSkipped_ = true;
                        obj.refreshEventMarkers_();  % events change independently
                        return;
                    end
                    obj.LastDataFingerprint_ = fp;
                    obj.LastTickSkipped_ = false;
                    obj.FastSenseObj.updateData(1, x, y);
                    % autoScaleY_(y) removed (260513-ovt): live ticks must
                    % not rescale Y — the user's Y view is preserved
                    % unless they explicitly pan/zoom or pin YLimits.
                    obj.updateTimeRangeCache(x);
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
        %   (260513-ovt) Per-tick Y autoscale removed from this path so
        %   Live mode never silently mutates the user's Y view.

            if isempty(obj.Tag), return; end
            if isempty(obj.hPanel) || ~ishandle(obj.hPanel), return; end
            % 260610-ov3: live ticks must never read render-scoped data.
            obj.clearRenderCache_();
            if ~obj.ShowingEmptyState_ && ~isempty(obj.FastSenseObj) && obj.FastSenseObj.IsRendered
                try
                    [x, y] = obj.pullData_();
                    % 260609-v5p data-unchanged fast path (mirrors refresh()).
                    % Fingerprint is [n, x(1), x(end), y(end)] under the
                    % append-only assumption shared with PreviewCacheKey_.
                    n = numel(x);
                    if n > 0
                        fp = [n, x(1), x(end), y(end)];
                    else
                        fp = [0, NaN, NaN, NaN];
                    end
                    if isequal(fp, obj.LastDataFingerprint_)
                        obj.LastTickSkipped_ = true;
                        obj.refreshEventMarkers_();  % events change independently
                        return;
                    end
                    obj.LastDataFingerprint_ = fp;
                    obj.LastTickSkipped_ = false;
                    obj.FastSenseObj.updateData(1, x, y);
                    % autoScaleY_(y) removed (260513-ovt): live ticks must
                    % not rescale Y — see refresh() above for rationale.
                    obj.updateTimeRangeCache(x);
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

        % Phase 1032 PLOG-VIZ-04
        function setPlantLogMarkers(obj, times, entries) %#ok<INUSD>
            %SETPLANTLOGMARKERS Draw or clear per-widget plant-log vertical lines.
            %   Phase 1032 PLOG-VIZ-04. Draws one xline per finite timestamp
            %   on the widget's inner FastSense axes (Tag = 'WidgetPlantLogMarker',
            %   1 px solid line with theme.MarkerPlantLog color, default
            %   [0 0 0]). Empty / no-arg input clears every existing marker
            %   via tag-based delete. Non-finite timestamps are silently
            %   dropped (mirrors TimeRangeSelector.setPlantLogMarkers shape).
            %
            %   `entries` is currently unused at the draw layer (hover
            %   lookup goes through the live store, not this snapshot —
            %   see Plan 02). Accepted in the signature for forward-compat
            %   with the engine's refresh helper call site and the Plan 02
            %   hover wiring.
            %
            %   Z-order: after drawing, plant-log lines are pushed to the
            %   BOTTOM (above sensor trace via FastSense draw-order, below
            %   any FastSenseEventMarker which is re-stacked to the top).
            %   Net stack: sensor trace (back) -> plant-log lines (middle)
            %   -> event badges (front).
            %
            %   On failure, fires the namespaced warning
            %   FastSenseWidget:plantLogToggleFailed (mirrors the
            %   setEventMarkersVisible error-handling style) and returns.
            try
                if isempty(obj.FastSenseObj) || ...
                        ~isa(obj.FastSenseObj, 'FastSense') || ...
                        ~obj.FastSenseObj.IsRendered
                    return;
                end
                ax = obj.FastSenseObj.hAxes;
                if isempty(ax) || ~ishandle(ax)
                    return;
                end
                % Tag-based delete of stale markers (mirrors FastSense
                % renderEventLayer_'s FastSenseEventMarker pattern).
                delete(findobj(ax, 'Tag', 'WidgetPlantLogMarker'));
                if nargin < 2 || isempty(times)
                    return;
                end
                times = times(:).';
                times = times(isfinite(times));
                if isempty(times)
                    return;
                end
                % Resolve marker color from theme; default black per
                % CONTEXT.md decision C ("crisp dividers, not subtle
                % highlights" — full opacity, no dashing).
                theme = obj.getTheme();
                markerColor = [0 0 0];
                if isstruct(theme) && isfield(theme, 'MarkerPlantLog')
                    markerColor = theme.MarkerPlantLog;
                end
                % Draw one xline per timestamp. HitTest='on' +
                % PickableParts='all' so Plan 02's hover helper can pick
                % the line.
                for i = 1:numel(times)
                    xline(ax, times(i), '-', ...
                        'Color', markerColor, ...
                        'LineWidth', 1, ...
                        'Tag', 'WidgetPlantLogMarker', ...
                        'HitTest', 'on', ...
                        'PickableParts', 'all');
                end
                % Z-order: send plant-log lines below event badges (CONTEXT
                % decision H). uistack('bottom') puts them behind everything
                % drawn afterwards; explicit uistack('top') on
                % FastSenseEventMarker keeps badges visible above plant-log
                % lines for every (entry, badge) crossing.
                h = findobj(ax, 'Tag', 'WidgetPlantLogMarker');
                if ~isempty(h)
                    uistack(h, 'bottom');
                    evt = findobj(ax, 'Tag', 'FastSenseEventMarker');
                    if ~isempty(evt)
                        uistack(evt, 'top');
                    end
                end
            catch ME
                warning('FastSenseWidget:plantLogToggleFailed', ...
                    'setPlantLogMarkers failed: %s', ME.message);
            end
        end

        % Hidden — DashboardEngine writes PlantLogXLimListener_ via this
        % seam since the property is SetAccess=private. Hidden methods
        % are callable from anywhere (Octave-safe idiom from
        % FastSenseDataStore). The listener handle is opaque to the
        % widget; the engine owns its lifecycle.
        function setPlantLogXLimListenerForEngine_(obj, lis)
            obj.PlantLogXLimListener_ = lis;
        end

        % Hidden — DashboardEngine writes CurrentViewXLimListener_ via this seam
        % (Phase 1039) since the property is SetAccess=private. Hidden methods are
        % callable from anywhere (Octave-safe idiom). The engine owns the handle's
        % lifecycle; the widget only stores it so delete() can release it.
        function setCurrentViewXLimListenerForEngine_(obj, lis)
            obj.CurrentViewXLimListener_ = lis;
        end

        function setShowPlantLog(obj, tf, engine)
        %SETSHOWPLANTLOG Toggle the per-widget plant-log overlay (Phase 1032 PLOG-VIZ-03).
        %   tf     — boolean; true enables overlay + attaches XLim listener,
        %            false disables overlay + tears down listener + clears markers.
        %   engine — DashboardEngine handle; required so refresh + listener
        %            wiring can route through engine.refreshPlantLogOverlayForWidget_
        %            and engine.attachPlantLogXLimListener_.
        %
        %   On failure, ShowPlantLog is REVERTED to its prior value and a
        %   non-blocking warning fires with namespace
        %   FastSenseWidget:plantLogToggleFailed (matches existing
        %   setEventMarkersVisible error-handling style).
            priorState = obj.ShowPlantLog;
            try
                if isempty(engine) || ~isa(engine, 'DashboardEngine')
                    error('FastSenseWidget:plantLogToggleFailed', ...
                        'engine must be a DashboardEngine handle.');
                end
                obj.ShowPlantLog = logical(tf);
                if obj.ShowPlantLog
                    engine.attachPlantLogXLimListener_(obj);
                    engine.refreshPlantLogOverlayForWidget_(obj);
                    engine.attachPlantLogWidgetHover_(obj);  % Phase 1032 PLOG-VIZ-07
                else
                    if ~isempty(obj.PlantLogXLimListener_)
                        try delete(obj.PlantLogXLimListener_); catch, end
                        obj.PlantLogXLimListener_ = [];
                    end
                    engine.detachPlantLogWidgetHover_(obj);  % Phase 1032 PLOG-VIZ-07
                    obj.setPlantLogMarkers([], []);  % clear without engine round-trip
                end
            catch ME
                obj.ShowPlantLog = priorState;
                warning('FastSenseWidget:plantLogToggleFailed', ...
                    'setShowPlantLog(%s) failed: %s', mat2str(logical(tf)), ME.message);
            end
        end

        function setYLimitMode(obj, mode)
        %SETYLIMITMODE Set the Y-axis rescale strategy and re-fit if rendered.
        %   mode is one of:
        %     'auto-visible' - rescale to data inside the current X window
        %     'auto-all'     - rescale to all data the bound Tag exposes
        %     'locked'       - freeze YLim; no further rescale on tick/refresh
        %
        %   Side effects (260513-sfp):
        %     - Clears UserZoomedY so an explicit click re-engages autoscale
        %       (the latch is treated as "I want to override autoscale" — a
        %       deliberate click on the V/A/L buttons reverses that intent).
        %     - Fetches the appropriate y window for the new mode and calls
        %       autoScaleY_(y) so the Y axis snaps immediately. 'locked' mode
        %       passes empty y; autoScaleY_'s mode dispatch short-circuits.
        %
        %   Does NOT override the YLimits pin (autoScaleY_'s guards stay).
            valid = {'auto-visible', 'auto-all', 'locked'};
            if ~(ischar(mode) || (isstring(mode) && isscalar(mode))) || ...
                    ~ismember(char(mode), valid)
                error('FastSenseWidget:invalidYLimitMode', ...
                    'YLimitMode must be one of {''auto-visible'',''auto-all'',''locked''}.');
            end
            obj.YLimitMode = char(mode);

            % Explicit click clears the user-zoom latch. The latch exists
            % to stop autoScaleY_ from fighting a mouse-zoom; a deliberate
            % click on V/A/L is the user re-engaging autoscale on purpose,
            % which means the latch must drop.
            obj.UserZoomedY = false;

            % Snap Y immediately so the user sees the click take effect
            % (no need to wait for the next refresh tick). Only meaningful
            % when the widget has been rendered.
            if isempty(obj.FastSenseObj) || ~obj.FastSenseObj.IsRendered
                return;
            end
            switch obj.YLimitMode
                case 'auto-visible'
                    y = obj.getYInVisibleXWindow_();
                    obj.autoScaleY_(y);
                case 'auto-all'
                    y = obj.getYFromTagOrInline_();
                    obj.autoScaleY_(y);
                case 'locked'
                    % autoScaleY_'s mode dispatch treats 'locked' as no-op.
                    obj.autoScaleY_([]);
            end
        end

        function setTimeWindow(obj, t0, t1)
        %SETTIMEWINDOW Set the load window for this widget's data pulls.
        %   t0, t1 datenum scalars; both [] resets to full range.
        %   The DashboardEngine pushes this before re-rendering. Data is
        %   pulled via Tag.getXYRange when set, Tag.getXY when empty.
            if nargin < 3 || isempty(t0) || isempty(t1)
                obj.TimeWindow_ = [];
            else
                obj.TimeWindow_ = [t0, t1];
            end
            % 260609-v5p: window change shifts what pullData_ returns, so the
            % old fingerprint is no longer valid. Reset to force a full update.
            obj.LastDataFingerprint_ = [];
        end

        function tf = isShowingEmptyState(obj)
        %ISSHOWINGEMPYSTATE Returns true when 'No data in selected range' is displayed.
        %   False when the widget has plotted data, or when no render has occurred.
            tf = obj.ShowingEmptyState_;
        end

        function setCrosshairLink(obj, tf)
        %SETCROSSHAIRLINK Set the crosshair-link flag (260602-mri).
        %   setCrosshairLink(obj, tf) sets CrosshairLinked to logical(tf).
        %   tf must be a logical scalar or a numeric 0/1 scalar.
        %   Does NOT touch graphics — the engine owns broadcast wiring.
        %   Throws FastSenseWidget:invalidCrosshairLink for invalid input.
        %
        %   This method is the duck-type hook: DashboardLayout calls
        %   ismethod(widget,'setCrosshairLink') to decide whether to render
        %   the crosshair-link toggle button on the WidgetButtonBar.
            if ~((islogical(tf) || isnumeric(tf)) && isscalar(tf) && ...
                    (tf == 0 || tf == 1 || islogical(tf)))
                error('FastSenseWidget:invalidCrosshairLink', ...
                    'CrosshairLinked must be a logical scalar (or numeric 0/1); got %s.', ...
                    class(tf));
            end
            obj.CrosshairLinked = logical(tf);
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
        %     - YLimitMode == 'locked' — the user explicitly froze Y limits
        %       via the L button on the WidgetButtonBar (260513-sfp).
        %
        %   Mode dispatch (after the guards above pass):
        %     'auto-visible' - use y as given (legacy behaviour). The caller
        %                      either passes data already filtered to the
        %                      visible X window, or full data — both work.
        %     'auto-all'     - replace y with full data from
        %                      getYFromTagOrInline_() so "fit all" ignores
        %                      whatever window the caller filtered to.
        %     'locked'       - return without rescaling.
            if ~isempty(obj.YLimits)
                return;
            end
            if obj.UserZoomedY
                return;
            end
            % Octave 7+ has no isvalid() for classdef handles, so treat the
            % FastSense handle as valid there and let downstream property
            % access surface real failures.
            isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
            if ~isempty(obj.FastSenseObj) && (isOctave || isvalid(obj.FastSenseObj)) && ...
                    strcmp(obj.FastSenseObj.LiveViewMode, 'follow')
                return;
            end
            if isempty(obj.FastSenseObj) || ~obj.FastSenseObj.IsRendered
                return;
            end
            ax = obj.FastSenseObj.hAxes;
            if isempty(ax) || ~ishandle(ax)
                return;
            end
            % Mode dispatch (260513-sfp). 'locked' short-circuits regardless
            % of the y argument; 'auto-all' replaces y with full data so the
            % caller's window filter is bypassed.
            switch obj.YLimitMode
                case 'locked'
                    return;
                case 'auto-all'
                    yAll = obj.getYFromTagOrInline_();
                    if ~isempty(yAll)
                        y = yAll;
                    end
                otherwise
                    % 'auto-visible' (default) — use y argument as-is.
            end
            if isempty(y)
                return;
            end
            yMin = min(y(:));
            yMax = max(y(:));
            if iscell(obj.Thresholds)
                for i = 1:numel(obj.Thresholds)
                    e = obj.Thresholds{i};
                    if isstruct(e) && isfield(e, 'Value') && ...
                            ~isempty(e.Value) && isfinite(e.Value)
                        yMin = min(yMin, e.Value);
                        yMax = max(yMax, e.Value);
                    elseif isstruct(e) && isfield(e, 'Y') && ...
                            ~isempty(e.Y) && any(isfinite(e.Y(:)))
                        yMin = min(yMin, min(e.Y(:), [], 'omitnan'));
                        yMax = max(yMax, max(e.Y(:), [], 'omitnan'));
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

        function xl = getCurrentXLim(obj)
        %GETCURRENTXLIM Live x-limits of the wrapped FastSense axes (Phase 1039).
        %   Returns the 1x2 [xMin xMax] the plot is CURRENTLY showing — the
        %   actual view window, read live from the axes via get(ax,'XLim').
        %   Returns [] when the widget is not rendered (no FastSenseObj, not
        %   IsRendered, or no valid axes).
        %
        %   This is deliberately NOT getTimeRange(): getTimeRange returns the
        %   cached DATA extent (CachedXMin/CachedXMax), which does not move
        %   when the user zooms/pans. The current-view box (DashboardEngine.
        %   updateCurrentViewIndicator_) needs the live view, so it calls this.
            xl = [];
            % Phase 1039 test seam: a forced value bypasses the live-axes read.
            if ~isempty(obj.CurrentXLimOverrideForTest_)
                v = obj.CurrentXLimOverrideForTest_;
                if numel(v) == 2 && all(isfinite(v)) && v(2) > v(1)
                    xl = [v(1), v(2)];
                end
                return;
            end
            if isempty(obj.FastSenseObj) || ~isa(obj.FastSenseObj, 'FastSense') || ...
                    ~obj.FastSenseObj.IsRendered
                return;
            end
            ax = obj.FastSenseObj.hAxes;
            if isempty(ax) || ~ishandle(ax)
                return;
            end
            try
                v = get(ax, 'XLim');
            catch
                return;
            end
            if numel(v) == 2 && all(isfinite(v)) && v(2) > v(1)
                xl = [v(1), v(2)];
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
                % 260610-ov3: when the render-scoped cache is warm (the engine's
                % post-render computePreviewEnvelope pass), reuse the already-
                % resolved arrays without calling Tag.getXY again, then clear —
                % the cache is consume-once so later calls (live ticks, detach
                % mirrors) always re-resolve and stay byte-identical to the
                % pre-260610-ov3 behavior.
                x = []; y = [];
                if ~isempty(obj.Tag)
                    try
                        if ~isempty(obj.RenderDataCache_) && ...
                                isstruct(obj.RenderDataCache_) && ...
                                isfield(obj.RenderDataCache_, 'x') && ...
                                isfield(obj.RenderDataCache_, 'y')
                            x = obj.RenderDataCache_.x;
                            y = obj.RenderDataCache_.y;
                            obj.clearRenderCache_();
                        else
                            [x, y] = obj.Tag.getXY();
                        end
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

                % 260610-g0w: derive the pair count from the OUTPUT length
                % instead of asserting the requested count. The minmax core
                % may BUMP the bucket count internally (260512 bucket-math:
                % nb_eff = floor(n/floor(n/nb)) >= nb, so output is
                % 2*nb_eff or 2*nb_eff+1 with the tail anchor). The old
                % equality check against 2*nBucketsEff silently returned []
                % for most n above PreviewRawThreshold_ — slider preview
                % lines vanished and the cache never stored.
                %
                % Odd length = tail anchor present (260512-c5x). Capture it
                % BEFORE the drop so it can be threaded to xCenters(end);
                % the reshape below needs an even-length vector. (260512-cxc:
                % without the capture the preview tail freezes at the
                % interior midpoint under live growth.)
                anchorX = [];
                anchorY = []; %#ok<NASGU>  % captured for future symmetry;
                                           % yMinB/yMaxB already include
                                           % the anchor's y because
                                           % minmax_core_mex scans the
                                           % full last bucket.
                if numel(xOut) ~= numel(yOut) || numel(xOut) < 2
                    return;
                end
                if mod(numel(xOut), 2) == 1
                    anchorX = xOut(end);
                    anchorY = yOut(end); %#ok<NASGU>
                    xOut = xOut(1:end - 1);
                    yOut = yOut(1:end - 1);
                end
                nbOut = numel(xOut) / 2;

                % Interleaved (min,max) or (max,min) pairs per bucket.
                xPairs = reshape(xOut, 2, nbOut);
                yPairs = reshape(yOut, 2, nbOut);
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

                % 260609-v5p: preallocate numeric arrays to avoid per-element
                % AGROW. 260610-g0w: attempt whole-array field extraction
                % first — [raw.StartTime] is one call instead of N property
                % reads + 2N isprop probes per tick (profiled at 8k isprop
                % calls per 20 ticks on a 200-event store). Falls back to
                % the defensive per-element loop on any irregular shape.
                n = numel(raw);
                tArr  = nan(1, n);
                sevArr = ones(1, n);
                fastOk = false;
                try
                    tFast   = [raw.StartTime];
                    sevFast = [raw.Severity];
                    % Both fields must extract to exactly one scalar per
                    % event — a shrunk vector (some events carry empty
                    % Severity) routes to the per-element loop so partial
                    % severities are not silently defaulted.
                    if isnumeric(tFast) && numel(tFast) == n && ...
                            isnumeric(sevFast) && numel(sevFast) == n
                        tArr = double(tFast(:).');
                        sevArr = double(sevFast(:).');
                        sevArr(~isfinite(sevArr)) = 1;
                        fastOk = true;
                    end
                catch
                    fastOk = false;
                end
                if ~fastOk
                    % Hoist the field/property probes out of the loop —
                    % shapes are homogeneous within one raw array.
                    isStructRaw = isstruct(raw);
                    if isStructRaw
                        hasST  = isfield(raw, 'StartTime');
                        hasSt2 = isfield(raw, 'startTime');
                        hasSv  = isfield(raw, 'Severity');
                        hasSv2 = isfield(raw, 'severity');
                    else
                        hasST  = isprop(raw(1), 'StartTime');
                        hasSt2 = false;
                        hasSv  = isprop(raw(1), 'Severity');
                        hasSv2 = false;
                    end
                    for i = 1:n
                        tVal = NaN;
                        sevVal = 1;
                        if hasST
                            tVal = raw(i).StartTime;
                        elseif hasSt2
                            tVal = raw(i).startTime;
                        end
                        if hasSv && ~isempty(raw(i).Severity)
                            sevVal = raw(i).Severity;
                        elseif hasSv2 && ~isempty(raw(i).severity)
                            sevVal = raw(i).severity;
                        end
                        if isnumeric(tVal) && isfinite(tVal)
                            tArr(i) = tVal;
                        end
                        if ~isnumeric(sevVal) || isempty(sevVal) || ~isfinite(sevVal(1))
                            sevArr(i) = 1;
                        else
                            sevArr(i) = sevVal(1);
                        end
                    end
                end
                % Discard entries where time was non-finite.
                valid = isfinite(tArr);
                tArr   = tArr(valid);
                sevArr = sevArr(valid);
                if isempty(tArr)
                    return;
                end
                % Compute color once per unique severity level (typical range: 1..3).
                uSev = unique(sevArr);
                colorMap = zeros(numel(uSev), 3);
                for si = 1:numel(uSev)
                    colorMap(si, :) = severityColor(theme, uSev(si));
                end
                % Build per-element color cell from the lookup.
                colorCell = cell(1, numel(tArr));
                for i = 1:numel(tArr)
                    si = find(uSev == sevArr(i), 1);
                    colorCell{i} = colorMap(si, :);
                end
                % Build struct array in one shot (no AGROW).
                m = struct('Time', num2cell(tArr), ...
                           'Severity', num2cell(sevArr), ...
                           'Color', colorCell);
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
            if obj.ShowPlantLog, s.showPlantLog = true; end  % v3.1 Phase 1032 PLOG-VIZ-03
            % v4.0 — emit yLimitMode only when non-default so pre-260513-sfp JSON
            % stays byte-identical (keeps diffs invisible for old
            % dashboards that never opted into a mode).
            if ~strcmp(obj.YLimitMode, 'auto-visible')
                s.yLimitMode = obj.YLimitMode;
            end
            % 260602-mri — emit crosshairLinked only when true so legacy
            % JSON stays byte-identical for old dashboards (default false).
            if obj.CrosshairLinked
                s.crosshairLinked = true;
            end
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
            % Phase 1032 — release XLim PostSet listener before FastSenseObj
            % teardown deletes the axes the listener is bound to.
            if ~isempty(obj.PlantLogXLimListener_)
                try delete(obj.PlantLogXLimListener_); catch, end
                obj.PlantLogXLimListener_ = [];
            end
            % Phase 1039 — release the current-view XLim listener before FastSenseObj
            % teardown destroys the axes the listener is bound to.
            if ~isempty(obj.CurrentViewXLimListener_)
                try delete(obj.CurrentViewXLimListener_); catch, end
                obj.CurrentViewXLimListener_ = [];
            end
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
        function [x, y] = pullData_(obj)
        %PULLDATA_ Windowed data pull. Honors TimeWindow_ via getXYRange;
        %   full series via getXY when no window is set.
            if ~isempty(obj.TimeWindow_)
                [x, y] = obj.Tag.getXYRange(obj.TimeWindow_(1), obj.TimeWindow_(2));
            else
                [x, y] = obj.Tag.getXY();
            end
        end

        function [x, y] = pullDataCached_(obj)
        %PULLDATACACHED_ 260610-ov3 render-scoped cache wrapper around pullData_.
        %   Returns RenderDataCache_.x/.y when the cache is warm (set by
        %   cacheRenderData_); otherwise calls pullData_(), caches the result,
        %   and returns it.  The cache lives until the engine's post-render
        %   preview pass consumes it (getPreviewSeries), the end of
        %   rebuildForTag_(), or a live refresh()/update() tick clears it on
        %   entry — live paths always see a cold cache.
            if ~isempty(obj.RenderDataCache_) && ...
                    isstruct(obj.RenderDataCache_) && ...
                    isfield(obj.RenderDataCache_, 'x') && ...
                    isfield(obj.RenderDataCache_, 'y')
                x = obj.RenderDataCache_.x;
                y = obj.RenderDataCache_.y;
            else
                [x, y] = obj.pullData_();
                obj.cacheRenderData_(x, y);
            end
        end

        function cacheRenderData_(obj, x, y)
        %CACHERENDERDATA_ 260610-ov3 — store [x, y] in the render-scoped cache.
        %   Called once per render pass (either from the probe block or from the
        %   first pullDataCached_() call).  Subsequent calls in the same pass are
        %   handled by pullDataCached_() returning the warm cache without entering
        %   here.
            obj.RenderDataCache_ = struct('x', x, 'y', y);
        end

        function clearRenderCache_(obj)
        %CLEARRENDERCACHE_ 260610-ov3 — reset RenderDataCache_ to [].
        %   Called when getPreviewSeries consumes the warm cache, at the end of
        %   rebuildForTag_(), and on entry to refresh()/update() so live ticks
        %   never read render-scoped data.
            obj.RenderDataCache_ = [];
        end

        function renderEmptyState_(obj, parentPanel)
        %RENDEREMPTYSTATE_ Render 'No data in selected range' centered placeholder.
        %   Uses an invisible axes + centered text rather than uigridlayout/
        %   uilabel: those are uifigure-only and error ('MATLAB:ui:GridLayout:
        %   unknownInput') when the widget renders into a classic figure() — the
        %   ad-hoc / SensorDetailPlot path and the R2020b CI baseline. axes+text
        %   work in classic figures, uifigures, and Octave. Called when a
        %   windowed pull yields empty data.
            theme = struct('WidgetBackground', [0.15 0.15 0.17], ...
                           'PlaceholderTextColor', [0.5 0.5 0.55]);
            try
                t = obj.getTheme();
                if isstruct(t)
                    if isfield(t, 'WidgetBackground')
                        theme.WidgetBackground = t.WidgetBackground;
                    end
                    if isfield(t, 'PlaceholderTextColor')
                        theme.PlaceholderTextColor = t.PlaceholderTextColor;
                    end
                end
            catch
            end
            try
                parentPanel.BackgroundColor = theme.WidgetBackground;
            catch
            end
            ax = axes('Parent', parentPanel, 'Units', 'normalized', ...
                      'Position', [0 0 1 1]);
            set(ax, 'Visible', 'off');
            text(ax, 0.5, 0.5, 'No data in selected range', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'Color', theme.PlaceholderTextColor);
        end

        function y = getYFromTagOrInline_(obj)
        %GETYFROMTAGORINLINE_ Full y vector from Tag (preferred) or inline YData.
        %   Returns [] when neither source yields data. Used by the
        %   'auto-all' branch of autoScaleY_ / setYLimitMode so the rescale
        %   spans the entire timeline regardless of the current X window.
            y = [];
            if ~isempty(obj.Tag)
                try
                    [~, y] = obj.Tag.getXY();
                catch
                    y = [];
                end
                return;
            end
            if ~isempty(obj.YData)
                y = obj.YData;
            end
        end

        function y = getYInVisibleXWindow_(obj)
        %GETYINVISIBLEXWINDOW_ y values whose x is inside the current XLim.
        %   Used by the 'auto-visible' branch of setYLimitMode so an
        %   explicit click on the V button rescales to the data the user
        %   can actually see right now. Falls back to the full y vector
        %   when the axes XLim is unavailable, when the data is too sparse
        %   to filter meaningfully, or when no samples fall inside the
        %   window (e.g. live data has not yet caught up with a panned-
        %   ahead XLim).
            y = obj.getYFromTagOrInline_();
            if isempty(y) || isempty(obj.FastSenseObj) || ...
                    ~obj.FastSenseObj.IsRendered
                return;
            end
            ax = obj.FastSenseObj.hAxes;
            if isempty(ax) || ~ishandle(ax)
                return;
            end
            try
                xl = get(ax, 'XLim');
            catch
                return;
            end
            if numel(xl) ~= 2 || ~all(isfinite(xl)) || xl(2) <= xl(1)
                return;
            end
            x = [];
            if ~isempty(obj.Tag)
                try
                    [x, ~] = obj.Tag.getXY();
                catch
                    x = [];
                end
            elseif ~isempty(obj.XData)
                x = obj.XData;
            end
            if isempty(x) || numel(x) ~= numel(y)
                return;
            end
            mask = x >= xl(1) & x <= xl(2);
            if any(mask)
                y = y(mask);
            end
        end

        function refreshEventMarkers_(obj)
            %REFRESHEVENTMARKERS_ Diff LastEventIds_/LastEventOpen_ vs current EventStore state.
            %   Triggers inner FastSense.refreshEventLayer() on any change: added/removed
            %   events, or open-to-closed transitions. Always updates the cache.
            %
            %   260609-v5p: replaced the O(nE^2) nested strcmp/find loop with a
            %   single conservative isequal comparison on the parallel arrays. The
            %   comparison is ORDER-SENSITIVE, so a pure reorder may trigger one
            %   extra redundant redraw, but a real change is NEVER missed. This is
            %   the correct trade-off for a live-tick hot path.
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
            changed = ~isequal(ids, obj.LastEventIds_) || ...
                      ~isequal(openFlags, obj.LastEventOpen_) || ...
                      ~isequal(sevs, obj.LastEventSeverity_);
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
            % 260609-v5p: replace per-tick loop with a single vectorized call.
            % xt is in seconds; serial-date day = seconds / 86400.
            % cellstr(datestr(...)) returns a Kx1 cell on both MATLAB and Octave.
            lbl = cellstr(datestr(xt(:) ./ 86400, fmt));
            set(ax, 'XTickMode', 'manual', 'XTickLabelMode', 'manual', ...
                'XTickLabel', lbl);
        end

        function updateTimeRangeCache(obj, x)
        %UPDATETIMERANGECACHE Maintain CachedXMin/CachedXMax incrementally.
        %   For sorted time arrays (the common case) the last element is the
        %   max candidate and the first is the min candidate, so this avoids
        %   a full-array scan on every live tick.
        %
        %   updateTimeRangeCache(obj, x) — 260609-v5p additive optional arg.
        %   When x is supplied (nargin >= 2) it is used directly, skipping a
        %   second Tag.getXY() call on the fast path. All other callers (e.g.
        %   rebuildForTag_, fromStruct) call updateTimeRangeCache(obj) with
        %   no second arg and get the existing pull behavior unchanged.
            if ~isempty(obj.Tag)
                try
                    if nargin >= 2 && ~isempty(x)
                        % Use the already-pulled x — avoids a redundant getXY().
                        n = numel(x);
                        tMin = x(1);
                        tMax = x(n);
                    elseif ismethod(obj.Tag, 'getTimeRange')
                        % 260610-ov3: only the extent is needed here, so ask the
                        % Tag for its range instead of pulling the full arrays.
                        % O(1) for SensorTag/StateTag; disk-backed sensors read
                        % the DataStore extent (getXY returns empty for those,
                        % which previously left the cache at inf/-inf).
                        [tMin, tMax] = obj.Tag.getTimeRange();
                        n = double(isscalar(tMin) && isscalar(tMax) && ...
                                   ~isnan(tMin) && ~isnan(tMax));
                    else
                        [x, ~] = obj.Tag.getXY();
                        n = numel(x);
                        if n > 0
                            tMin = x(1);
                            tMax = x(n);
                        end
                    end
                    if n == 0
                        obj.CachedXMin = inf;
                        obj.CachedXMax = -inf;
                        return;
                    end
                    obj.CachedXMax = tMax;
                    if isinf(obj.CachedXMin)
                        obj.CachedXMin = tMin;
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
            % 260609-v5p: full rebuild invalidates the data fingerprint so the
            % first tick after rebuild always runs the full update path.
            obj.LastDataFingerprint_ = [];
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
            % Phase 1017: resolve EventStore via registry default if not explicitly set.
            esForward = obj.EventStore;
            if isempty(esForward)
                esForward = TagRegistry.getEventStore();
            end
            if obj.ShowEventMarkers || ~isempty(esForward)
                fp.ShowEventMarkers = obj.ShowEventMarkers;
                fp.EventStore       = esForward;
            end
            % 260610-ov3: same single-resolve approach as render() branch (3).
            % Resolve once via pullDataCached_() and bind via fp.addLine so
            % yInit and updateTimeRangeCache below reuse the cached arrays.
            % State tags keep fp.addTag for staircase rendering (same guard as
            % render(); ismethod guard keeps non-standard tags on safe path).
            isStateLike = ismethod(obj.Tag, 'getKind') && ...
                          strcmp(obj.Tag.getKind(), 'state');
            if isStateLike
                fp.addTag(obj.Tag);
            else
                try
                    [xrb, yrb] = obj.pullDataCached_();
                    fp.addLine(xrb, yrb, 'DisplayName', obj.Tag.Name);
                catch
                    fp.addTag(obj.Tag);  % safe fallback
                end
            end

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
            % 260610-ov3: pass cached x to updateTimeRangeCache to avoid an
            % extra Tag.getXY call (mirrors the render() treatment).
            if ~isempty(obj.Tag) && ~isempty(obj.RenderDataCache_)
                try
                    [xrc, ~] = obj.pullDataCached_();
                    obj.updateTimeRangeCache(xrc);
                catch
                    obj.updateTimeRangeCache();
                end
            else
                obj.updateTimeRangeCache();
            end
            obj.invalidatePreviewCache_();   % 260508-das
            % 260610-ov3: clear render-scoped cache so live refresh/update
            % paths never see stale rebuild-time data.
            obj.clearRenderCache_();

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
            if isfield(s, 'showPlantLog')  % v3.1 Phase 1032 PLOG-VIZ-03
                obj.ShowPlantLog = s.showPlantLog;
            end
            % v4.0 260513-sfp — restore YLimitMode if serialized. Absent means
            % "legacy dashboard, default to 'auto-visible'" so behaviour
            % is byte-identical for old configs.
            if isfield(s, 'yLimitMode')
                try
                    obj.setYLimitMode(s.yLimitMode);
                catch
                    % Invalid serialized value; keep default 'auto-visible'.
                end
            end
            % 260602-mri — restore CrosshairLinked if serialized. Absent means
            % "legacy dashboard, default false" so JSON round-trip is byte-identical.
            % Do NOT call setCrosshairLink here (fromStruct runs pre-render;
            % graphics wiring is the engine's responsibility at realize time).
            if isfield(s, 'crosshairLinked')
                obj.CrosshairLinked = logical(s.crosshairLinked);
            end
        end
    end
end

function applyThresholds_(fp, spec)
    %APPLYTHRESHOLDS_ Push a Thresholds spec into a FastSense instance.
    %   Accepts 'auto' / [] (no-op), numeric scalar/vector (upper lines),
    %   or a cell of structs: Value (scalar limit) or X / Y vectors
    %   (time-varying step limit; NaN Y = no limit), plus optional
    %   Direction / Label / Color / LineStyle (severity styling).
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
            if ~isstruct(e)
                continue;
            end
            isTimeVarying = isfield(e, 'X') && isfield(e, 'Y') && ...
                ~isempty(e.X) && ~isempty(e.Y);
            if ~isTimeVarying && ~isfield(e, 'Value')
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
            args = {'Direction', dir};
            if ~isempty(lbl)
                args = [args, {'Label', lbl}]; %#ok<AGROW>
            end
            if isfield(e, 'Color') && ~isempty(e.Color)
                args = [args, {'Color', e.Color}]; %#ok<AGROW>
            end
            if isfield(e, 'LineStyle') && ~isempty(e.LineStyle)
                args = [args, {'LineStyle', e.LineStyle}]; %#ok<AGROW>
            end
            if isTimeVarying
                % Time-varying entry — forward to the core step-function
                % form addThreshold(thX, thY, ...). NaN samples in Y break
                % the line where no limit applies (state-dependent limits).
                fp.addThreshold(e.X, e.Y, args{:});
            else
                fp.addThreshold(e.Value, args{:});
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
