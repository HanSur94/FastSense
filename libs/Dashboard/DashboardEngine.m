classdef DashboardEngine < handle
%DASHBOARDENGINE Top-level dashboard orchestrator.
%
%   Usage:
%     d = DashboardEngine('My Dashboard');
%     d.Theme = 'light';
%     d.LiveInterval = 5;
%     d.addWidget('fastsense', 'Title', 'Temp', 'Position', [1 1 6 3], ...
%                 'Tag', TagRegistry.get('temperature'));
%     d.render();
%
%   One-liner with name-value options:
%     d = DashboardEngine('My Dashboard', 'Theme', 'dark', 'LiveInterval', 5);
%
%   Loading from JSON:
%     d = DashboardEngine.load('path/to/dashboard.json');
%     d.render();
%
%   For a lightweight tiled grid of FastSense charts without widgets,
%   see FastSenseGrid.

    properties (Access = public)
        Name          = ''
        Theme         = 'light'
        LiveInterval  = 5
        InfoFile      = ''
        ProgressMode  = 'auto'   % 'auto' | 'on' | 'off' — render progress bar visibility
        ShowTimePanel = true     % hide the bottom time slider panel
        EventMarkersVisible = true  % global toggle for event markers across all widgets (runtime UI state, not serialized)
        DebugPreview_ = false    % 260508-das — opt-in: surface preview/marker pipeline failures as warnings
        % Reserved vertical strip at the figure top for the stale-data banner
        % (normalized units). The banner is no longer an overlay — its space
        % is permanently reserved, so toolbar / page-bar / content-area all
        % shift down by BannerHeight. Single source of truth for the banner
        % strip height (260508-jyh).
        BannerHeight  = 0.035
    end

    properties (SetAccess = private)
        Widgets        = {}
        Pages          = {}   % Cell array of DashboardPage (multi-page mode)
        ActivePage     = 0    % Index into Pages; 0 = no pages defined
        PageBarHeight  = 0.04 % Normalized height of PageBar (same as Toolbar.Height)
        hPageBar       = []   % uipanel handle for PageBar
        hPageButtons   = {}   % Cell array of uicontrol handles for page buttons
        hFigure        = []
        Layout         = []
        Toolbar        = []
        LiveTimer      = []
        IsLive         = false
        LastUpdateTime = []
        FilePath        = ''
        InfoTempFile    = ''
        InfoModalFigure_ = []  % Cached modal uifigure handle for in-app info display (260508-n8h)
        DetachedMirrors = {}   % Cell array of DetachedMirror objects
        % Theme caching
        ThemeCache_        = []  % Cached DashboardTheme struct; lazy-computed by getCachedTheme()
        ThemeCachePreset_  = ''  % Theme preset string that ThemeCache_ was built for
        % Widget dispatch table
        WidgetTypeMap_     = []  % containers.Map: type string -> constructor function handle
        % Time control
        TimePanelHeight = 0.085   % bumped from 0.06 to fit data-range labels below slider (260512-hrn-followup)
        DataTimeRange   = [0 1]    % [tMin tMax] across all widget data
        hTimePanel      = []
        hTimeSliderL    = []       % Shim handle — points at TimeRangeSelector_ (D-10)
        hTimeSliderR    = []       % Shim handle — points at TimeRangeSelector_ (D-10)
        hTimeStart      = []
        hTimeEnd        = []
        hTimeResetBtn   = []       % Reset button on time panel (260508-f7p — needed for theme switch)
        SliderDebounceTimer = []   % MATLAB timer for coalescing rapid slider events
        ResizeDebounceTimer = []   % MATLAB timer for coalescing rapid resize events (260513-q7w)
        ResizeFinalRedrawTimer = [] % Longer-period backstop timer: unconditional rerenderWidgets after resize fully settles (260513-q7w fu)
        IsRerendering_ = false   % true while rerenderWidgets is in flight — suppresses spurious resize-timer scheduling that the panel teardown/recreate cascade would otherwise trigger (260513-q7w fu2)
        TimeRangeSelector_  = []   % TimeRangeSelector handle (replaces dual sliders)
        % [tStart tEnd] cache of most recent broadcast (260508-llw); used by
        % switchPage to re-apply the current synced window to widgets that
        % get realized on tab-switch.
        LastSyncedTimeRange_ = []
        Progress_           = []   % DashboardProgress instance (active during render)
        % Stale-data banner (shown during live mode when a widget's tMax stops advancing)
        hStaleBanner         = []  % uipanel overlay; hidden unless live+stale+!dismissed
        hStaleBannerText     = []  % uicontrol text child of hStaleBanner
        hStaleBannerClose    = []  % uicontrol 'X' pushbutton child of hStaleBanner
        LastTMaxPerWidget_   = []  % containers.Map: widget title -> last observed tMax
        StaleBannerDismissed_ = false  % true after user clicks X; reset when data flows again
        PreviewNBuckets_     = 0   % Cached nBuckets from last figure-pixel query; 0 = uncached
        % Slider overlay caches — avoid deleting/recreating line handles when
        % the underlying data hasn't changed between ticks (260508-slider-stuck).
        % Each cache stores the last value passed to the selector so the
        % comparisons below can skip the expensive delete/recreate cycle.
        EventMarkerTimesCache_  = []   % last uTimes passed to setEventMarkers
        EventMarkerColorsCache_ = []   % last uColors (Nx3) passed to setEventMarkers
        PreviewLinesCache_      = {}   % last linesList (cell of structs) passed to setPreviewLines
        FigureDestroyedListener_ = []  % event.listener — fires onFigureDestroyed_ when obj.hFigure is destroyed (260511-mjb)
        % Phase 1031 PLOG-VIZ-01..09: plant-log slider overlay test seam.
        % These three properties are the temporary integration point used by
        % setPlantLogStoreForTest_ / setPlantLogLiveTailForTest_; Phase 1033
        % will replace the seam with the public attachPlantLog/detachPlantLog API.
        PlantLogStoreInternal_    = []  % PlantLogStore handle (or [])
        PlantLogLiveTailInternal_ = []  % PlantLogLiveTail handle (or [])
        PlantLogTickListener_     = []  % addlistener handle for PlantLogLiveTail.PlantLogTailTick
        % Phase 1031 PLOG-VIZ-06: hover tooltip on plant-log slider markers.
        % Lazily constructed in setPlantLogStoreForTest_ when a non-empty
        % store is attached AND TimeRangeSelector_ is rendered. Torn down
        % on every store change (so stale store-handle closures cannot
        % survive a store swap), on store-detach, and in delete().
        PlantLogSliderHover_      = []  % PlantLogSliderHover handle (or [])
    end

    methods (Access = public)
        function obj = DashboardEngine(name, varargin)
            if nargin >= 1
                obj.Name = name;
            end
            for k = 1:2:numel(varargin)
                key = varargin{k};
                if ~isprop(obj, key)
                    error('DashboardEngine:invalidOption', ...
                        'Unknown option ''%s''. Valid options: %s', ...
                        key, strjoin(properties(obj), ', '));
                end
                obj.(key) = varargin{k+1};
            end
            obj.Layout = DashboardLayout();
            obj.Layout.EngineRef = obj;  % Phase 1032 PLOG-VIZ-05 — used by addPlantLogToggle callback
            obj.WidgetTypeMap_ = containers.Map({ ...
                'fastsense',   'number',     'status',    'text', ...
                'gauge',       'table',      'rawaxes',   'timeline', ...
                'group',       'heatmap',    'barchart',  'histogram', ...
                'scatter',     'image',      'multistatus', 'divider', ...
                'iconcard',    'chipbar',    'sparkline'}, ...
                {@FastSenseWidget, @NumberWidget, @StatusWidget, @TextWidget, ...
                 @GaugeWidget, @TableWidget, @RawAxesWidget, @EventTimelineWidget, ...
                 @GroupWidget, @HeatmapWidget, @BarChartWidget, @HistogramWidget, ...
                 @ScatterWidget, @ImageWidget, @MultiStatusWidget, @DividerWidget, ...
                 @IconCardWidget, @ChipBarWidget, @SparklineCardWidget});
        end

        function pg = addPage(obj, name)
        %ADDPAGE Add a named page and make it the active page for addWidget.
        %   pg = d.addPage('Overview') creates a DashboardPage and appends it to Pages.
        %   Sets ActivePage to the last-added page index.
        %   When Pages is non-empty, addWidget routes to the active page.
            if nargin < 2
                name = '';
            end
            pg = DashboardPage(name);
            obj.Pages{end+1} = pg;
            % Set ActivePage to 1 on first addPage call; subsequent pages
            % don't change ActivePage — use switchPage() to navigate.
            if obj.ActivePage == 0
                obj.ActivePage = 1;
            end
            % Refresh the preview envelope (D-07). Safe before render():
            % computePreviewEnvelope guards on TimeRangeSelector_ presence.
            try obj.computePreviewEnvelope(); catch err
                if obj.DebugPreview_, warning('DashboardEngine:previewFailed', 'computePreviewEnvelope: %s', err.message); end
            end
            try obj.computeEventMarkers();    catch err
                if obj.DebugPreview_, warning('DashboardEngine:eventMarkersFailed', 'computeEventMarkers: %s', err.message); end
            end
            % Phase 1031 PLOG-VIZ-01/08: refresh plant-log slider markers too.
            try obj.computePlantLogMarkers(); catch err
                if obj.DebugPreview_, warning('DashboardEngine:plantLogMarkersFailed', 'computePlantLogMarkers: %s', err.message); end
            end
        end

        function setEventMarkersVisible(obj, tf)
            %SETEVENTMARKERSVISIBLE Globally show/hide event markers on every widget.
            %   Iterates every widget (across all pages in multi-page mode)
            %   and calls setEventMarkersVisible(tf) on any widget that
            %   implements it. Unsupported widgets are silently skipped.
            %   Also updates the toolbar indicator if a Toolbar is present.
            %   Default state on dashboard create is true so existing
            %   scripts are unaffected.
            tf = logical(tf);
            obj.EventMarkersVisible = tf;
            ws = obj.allPageWidgets();
            for i = 1:numel(ws)
                w = ws{i};
                if ismethod(w, 'setEventMarkersVisible')
                    try
                        w.setEventMarkersVisible(tf);
                    catch ME
                        warning('DashboardEngine:eventToggleWidgetFailed', ...
                            'Widget "%s" failed event toggle: %s', w.Title, ME.message);
                    end
                end
            end
            if ~isempty(obj.Toolbar) && ismethod(obj.Toolbar, 'setEventsActiveIndicator')
                obj.Toolbar.setEventsActiveIndicator(tf);
            end
            % Refresh slider preview markers so the toolbar toggle is
            % reflected in the time-panel track too (260508 follow-up).
            try obj.computeEventMarkers(); catch err
                if obj.DebugPreview_, warning('DashboardEngine:eventMarkersFailed', 'computeEventMarkers: %s', err.message); end
            end
            % Phase 1031 PLOG-VIZ-01/08: refresh plant-log slider markers too.
            try obj.computePlantLogMarkers(); catch err
                if obj.DebugPreview_, warning('DashboardEngine:plantLogMarkersFailed', 'computePlantLogMarkers: %s', err.message); end
            end
        end

        function switchPage(obj, pageIdx)
        %SWITCHPAGE Switch the active page using panel visibility toggling.
        %   d.switchPage(2) sets ActivePage = 2 and toggles panel visibility.
            if ~obj.isObjValid_()
                return;  % uicontrol callback fired after engine was deleted
            end
            if pageIdx < 1 || pageIdx > numel(obj.Pages)
                return;
            end
            % Cancel any pending resize-debounce timers from a prior resize.
            % If the user resized then immediately clicked a different tab,
            % the in-flight backstop would fire ~1.2s later and rerender
            % the wrong page (the NEW active page), destroying its
            % freshly-realized panels mid-flight and leaving widgets
            % white. (260513-q7w fu2)
            obj.cancelResizeTimers_();
            % If a rerenderWidgets is currently in flight (the backstop
            % fired and is mid-flight, with internal drawnow calls letting
            % this uicontrol callback interrupt it), serialize: spin
            % drawnow until the rerender completes. Running switchPage
            % INSIDE a rerender races with the realizeWidget loop and
            % leaves the previous page's widgets visible (chrome created
            % inside their outer cells AFTER switchPage hid them) and
            % the new page's widgets white. Spin with a 3 s safety
            % timeout. (260513-q7w fu3)
            if obj.IsRerendering_
                waitStart = tic;
                while obj.IsRerendering_ && toc(waitStart) < 3
                    drawnow;
                end
            end
            obj.ActivePage = pageIdx;
            % Update button colors if PageBar exists
            if ~isempty(obj.hPageButtons)
                themeStruct = obj.getCachedTheme();
                for i = 1:numel(obj.hPageButtons)
                    if ~isempty(obj.hPageButtons{i}) && ishandle(obj.hPageButtons{i})
                        if i == obj.ActivePage
                            set(obj.hPageButtons{i}, ...
                                'BackgroundColor', themeStruct.TabActiveBg, ...
                                'ForegroundColor', themeStruct.GroupHeaderFg);
                        else
                            set(obj.hPageButtons{i}, ...
                                'BackgroundColor', themeStruct.TabInactiveBg, ...
                                'ForegroundColor', themeStruct.ToolbarFontColor);
                        end
                    end
                end
            end
            % Toggle panel visibility instead of full rerender
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                % Show active page panels, hide others
                for pgIdx = 1:numel(obj.Pages)
                    pgWidgets = obj.Pages{pgIdx}.Widgets;
                    for wi = 1:numel(pgWidgets)
                        % Toggle visibility on the OUTER cell panel so the
                        % WidgetButtonBar (a sibling of the WidgetContentPanel)
                        % is hidden alongside widget content. Fall back to
                        % hPanel for widgets that haven't been realized yet
                        % (hCellPanel is set during realizeWidget).
                        cellH = pgWidgets{wi}.hCellPanel;
                        if isempty(cellH) || ~ishandle(cellH)
                            cellH = pgWidgets{wi}.hPanel;
                        end
                        if ~isempty(cellH) && ishandle(cellH)
                            if pgIdx == obj.ActivePage
                                set(cellH, 'Visible', 'on');
                            else
                                set(cellH, 'Visible', 'off');
                            end
                        end
                    end
                end
                % Batch-realize any not-yet-realized widgets on the now-active page
                hasUnrealized = false;
                activeWs = obj.Pages{obj.ActivePage}.Widgets;
                for wi = 1:numel(activeWs)
                    if ~activeWs{wi}.Realized
                        hasUnrealized = true;
                        break;
                    end
                end
                if hasUnrealized
                    obj.realizeBatch(5);
                end
            end
            % Re-apply the current synced time range so widgets that just
            % realized on this tab inherit the dashboard-wide window
            % instead of their construction default. (260508-llw)
            if ~isempty(obj.LastSyncedTimeRange_)
                rng = obj.LastSyncedTimeRange_;
                obj.broadcastTimeRange(rng(1), rng(2));
            end
            % Refresh the preview envelope on the newly active page (D-07).
            % Do NOT clear the slider overlay caches before calling compute.
            % The dirty-check in computePreviewEnvelopeReturning_ and
            % computeEventMarkers uses isequal() to detect whether the new
            % page's data differs from what's currently drawn. If it differs
            % (different widgets, different events), the compute functions
            % invoke setPreviewLines/setEventMarkers automatically. Clearing
            % the caches here was redundant and harmful: it forced a full
            % delete/recreate of 129+ line handles synchronously inside
            % switchPage(), blocking the MATLAB event queue long enough to
            % drop the user's next mouse event (slider drag). (260508-slider-stuck)
            try obj.computePreviewEnvelope(); catch err
                if obj.DebugPreview_, warning('DashboardEngine:previewFailed', 'computePreviewEnvelope: %s', err.message); end
            end
            try obj.computeEventMarkers();    catch err
                if obj.DebugPreview_, warning('DashboardEngine:eventMarkersFailed', 'computeEventMarkers: %s', err.message); end
            end
            % Phase 1031 PLOG-VIZ-01/08: refresh plant-log slider markers too.
            try obj.computePlantLogMarkers(); catch err
                if obj.DebugPreview_, warning('DashboardEngine:plantLogMarkersFailed', 'computePlantLogMarkers: %s', err.message); end
            end
        end

        function w = addWidget(obj, type, varargin)
            % Accept a pre-constructed widget object directly
            if isa(type, 'DashboardWidget')
                w = type;
            else
                % Handle deprecated 'kpi' type
                if strcmp(type, 'kpi')
                    warning('DashboardEngine:deprecated', ...
                        '''kpi'' type is deprecated, use ''number'' instead.');
                    type = 'number';
                end

                if isKey(obj.WidgetTypeMap_, type)
                    ctor = obj.WidgetTypeMap_(type);
                    w = ctor(varargin{:});
                else
                    error('DashboardEngine:unknownType', ...
                        'Unknown widget type: %s', type);
                end

                % Preserve timeline no-store warning
                if strcmp(type, 'timeline') && isempty(w.EventStoreObj) && isempty(w.EventFcn) && isempty(w.Events)
                    warning('DashboardEngine:timelineNoStore', ...
                        'Timeline widget "%s" has no data source. Bind via EventStoreObj.', ...
                        w.Title);
                end
            end

            % Inject ReflowCallback into collapsible GroupWidgets (before page routing)
            if isa(w, 'GroupWidget') && strcmp(w.Mode, 'collapsible')
                w.ReflowCallback = @() obj.reflowAfterCollapse();
            end

            % Route to active page when in multi-page mode
            if ~isempty(obj.Pages)
                if obj.ActivePage < 1
                    error('DashboardEngine:noActivePage', ...
                        'Pages is non-empty but ActivePage is 0. Call addPage() first.');
                end
                obj.Pages{obj.ActivePage}.addWidget(w);
                obj.wireListeners(w);
                return;
            end

            existingPositions = cell(1, numel(obj.Widgets));
            for i = 1:numel(obj.Widgets)
                existingPositions{i} = obj.Widgets{i}.Position;
            end
            w.Position = obj.Layout.resolveOverlap(w.Position, existingPositions);

            obj.Widgets{end+1} = w;
            obj.wireListeners(w);
        end

        function w = addCollapsible(obj, label, children, varargin)
        %ADDCOLLAPSIBLE Convenience: add a GroupWidget with Mode='collapsible'.
        %   w = d.addCollapsible('Sensors', {w1, w2})
        %   w = d.addCollapsible('Sensors', {w1, w2}, 'Collapsed', true)
            w = obj.addWidget('group', 'Label', label, 'Mode', 'collapsible', varargin{:});
            for i = 1:numel(children)
                w.addChild(children{i});
            end
        end

        function t = getCachedTheme(obj)
        %GETCACHEDTHEME Return cached theme struct, recomputing only when Theme changes.
            if isempty(obj.ThemeCache_) || ~strcmp(obj.ThemeCachePreset_, obj.Theme)
                obj.ThemeCache_ = DashboardTheme(obj.Theme);
                obj.ThemeCachePreset_ = obj.Theme;
            end
            t = obj.ThemeCache_;
        end

        function render(obj)
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                return;
            end

            themeStruct = obj.getCachedTheme();

            obj.hFigure = figure('Name', obj.Name, ...
                'NumberTitle', 'off', ...
                'Color', themeStruct.DashboardBackground, ...
                'Units', 'normalized', ...
                'OuterPosition', [0.05 0.05 0.9 0.9], ...
                'CloseRequestFcn', @(~,~) obj.onClose());
            % Safety net: any figure-destruction path (delete(hf), close all force,
            % parent teardown) must also stop the live timer. CloseRequestFcn ->
            % onClose() already handles the normal close path; this listener
            % covers everything else (260511-mjb).
            try
                obj.FigureDestroyedListener_ = addlistener(obj.hFigure, ...
                    'ObjectBeingDestroyed', @(~,~) obj.onFigureDestroyed_());
            catch
                obj.FigureDestroyedListener_ = [];
            end
            set(obj.hFigure, 'ResizeFcn', @(~,~) obj.onResize());

            obj.Toolbar = DashboardToolbar(obj, obj.hFigure, themeStruct);

            % Create PageBar for multi-page dashboards
            toolbarH = obj.Toolbar.Height;
            if numel(obj.Pages) > 1
                obj.renderPageBar(themeStruct);
                pageBarH = obj.PageBarHeight;
            else
                % Create hidden PageBar placeholder so hPageBar is always valid.
                % Y accounts for the reserved banner strip at the figure top.
                obj.hPageBar = uipanel('Parent', obj.hFigure, ...
                    'Units', 'normalized', ...
                    'Position', [0, 1 - obj.BannerHeight - toolbarH - obj.PageBarHeight, 1, obj.PageBarHeight], ...
                    'BorderType', 'none', ...
                    'BackgroundColor', themeStruct.ToolbarBackground, ...
                    'Visible', 'off');
                pageBarH = 0;
            end

            % Create time control panel at bottom
            obj.createTimePanel(themeStruct);

            % Create the stale-data banner (hidden by default; toggled by live tick)
            obj.createStaleBanner(themeStruct, toolbarH);

            % Apply visibility flags + compute content area based on effective
            % heights. BannerHeight is reserved at the top regardless of
            % banner Visible state — toolbar/pagebar/content-area all shift
            % down so the banner is never an overlay (260508-jyh).
            [effToolbarH, effPageBarH, effTimeH] = obj.applyChromeVisibility(toolbarH, pageBarH);
            obj.Layout.ContentArea = [0, effTimeH, ...
                1, 1 - obj.BannerHeight - effToolbarH - effPageBarH - effTimeH];
            obj.Layout.DetachCallback = @(w) obj.detachWidget(w);
            % Create viewport once up front — additive allocatePanels calls below
            % will reuse it rather than destroying and recreating it each time.
            obj.Layout.ensureViewport(obj.hFigure, themeStruct);
            obj.Layout.allocatePanels(obj.hFigure, obj.activePageWidgets(), themeStruct);
            obj.Layout.OnScrollCallback = @(r1, r2) obj.onScrollRealize(r1, r2);

            % Progress-bar accounting covers only the active page — hidden
            % pages keep their lazy-realization contract (realized on switch).
            totalWidgets = numel(obj.activePageWidgets());
            totalPages   = max(1, numel(obj.Pages));
            obj.Progress_ = DashboardProgress(obj.Name, totalWidgets, totalPages, obj.ProgressMode);

            obj.realizeBatch(5);

            obj.Progress_.finish();
            obj.Progress_ = [];

            % Pre-allocate panels for non-active pages (hidden) so switchPage is O(1) visibility toggle.
            % Widgets stay unrealized until the user switches to the page.
            if numel(obj.Pages) > 1
                for pgIdx = 1:numel(obj.Pages)
                    if pgIdx == obj.ActivePage
                        continue;
                    end
                    pgWidgets = obj.Pages{pgIdx}.Widgets;
                    obj.Layout.allocatePanels(obj.hFigure, pgWidgets, themeStruct);
                    % Hide panels for non-active pages. allocatePanels has
                    % only just assigned the cell panel to widget.hPanel
                    % (hCellPanel is still empty until realizeWidget fires
                    % on tab-switch), so toggling hPanel here hides the
                    % cell — correct.
                    for wi = 1:numel(pgWidgets)
                        if ~isempty(pgWidgets{wi}.hPanel) && ishandle(pgWidgets{wi}.hPanel)
                            set(pgWidgets{wi}.hPanel, 'Visible', 'off');
                        end
                    end
                end
            end

            % Auto-detect time range from data
            obj.updateGlobalTimeRange();
        end

        function startLive(obj)
            if obj.IsLive
                return;
            end
            obj.IsLive = true;
            % Baseline per-widget tMax so the first tick has a reference.
            obj.LastTMaxPerWidget_ = containers.Map( ...
                'KeyType', 'char', 'ValueType', 'double');
            ws = obj.activePageWidgets();
            for i = 1:numel(ws)
                [~, tMax] = ws{i}.getTimeRange();
                if ~isfinite(tMax), continue; end
                if ~isempty(ws{i}.Title)
                    key = ws{i}.Title;
                else
                    key = sprintf('Widget %d', i);
                end
                obj.LastTMaxPerWidget_(key) = tMax;
            end
            obj.StaleBannerDismissed_ = false;
            obj.hideStaleBanner();
            obj.LiveTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', obj.LiveInterval, ...
                'Tag', 'DashboardEngine', ...
                'TimerFcn', @(~,~) obj.onLiveTick(), ...
                'ErrorFcn', @(t, e) obj.onLiveTimerError(t, e));
            start(obj.LiveTimer);
        end

        function stopLive(obj)
            % Clear IsLive FIRST so any in-flight onLiveTimerError callback
            % does not re-`start(obj.LiveTimer)` on the timer we are about to
            % delete (observed on CI as a runaway 500k+ stderr loop in
            % testTimerContinuesAfterError). Then stop/delete the timer with
            % isvalid + try/catch guards, matching LiveTagPipeline.stop().
            obj.IsLive = false;
            obj.hideStaleBanner();
            obj.LastTMaxPerWidget_ = [];
            obj.StaleBannerDismissed_ = false;
            if ~isempty(obj.LiveTimer)
                try
                    if isvalid(obj.LiveTimer)
                        stop(obj.LiveTimer);
                        delete(obj.LiveTimer);
                    end
                catch
                    % best-effort teardown
                end
                obj.LiveTimer = [];
            end
            if ~isempty(obj.SliderDebounceTimer)
                try stop(obj.SliderDebounceTimer); catch, end
                try delete(obj.SliderDebounceTimer); catch, end
                obj.SliderDebounceTimer = [];
            end
        end

        function save(obj, filepath)
            [~, ~, ext] = fileparts(filepath);
            isMultiPage = numel(obj.Pages) > 1;
            isSingleImplicitPage = numel(obj.Pages) == 1 && strcmp(obj.Pages{1}.Name, 'Default');

            if isMultiPage
                activePageName = obj.Pages{obj.ActivePage}.Name;
                cfg = DashboardSerializer.widgetsPagesToConfig( ...
                    obj.Name, obj.Theme, obj.LiveInterval, obj.Pages, activePageName, obj.InfoFile);
                if strcmp(ext, '.json')
                    DashboardSerializer.saveJSON(cfg, filepath);
                else
                    DashboardSerializer.exportScriptPages(cfg, filepath);
                end
            else
                if isSingleImplicitPage
                    cfg = DashboardSerializer.widgetsToConfig( ...
                        obj.Name, obj.Theme, obj.LiveInterval, obj.Pages{1}.Widgets, obj.InfoFile);
                else
                    cfg = DashboardSerializer.widgetsToConfig( ...
                        obj.Name, obj.Theme, obj.LiveInterval, obj.Widgets, obj.InfoFile);
                end
                if strcmp(ext, '.json')
                    DashboardSerializer.saveJSON(cfg, filepath);
                else
                    DashboardSerializer.save(cfg, filepath);
                end
            end
            obj.FilePath = filepath;
        end

        function exportScript(obj, filepath)
            if numel(obj.Pages) > 1
                % Multi-page: emit addPage() calls before each page's widgets
                activePageName = obj.Pages{obj.ActivePage}.Name;
                cfg = DashboardSerializer.widgetsPagesToConfig( ...
                    obj.Name, obj.Theme, obj.LiveInterval, obj.Pages, activePageName, obj.InfoFile);
                DashboardSerializer.exportScriptPages(cfg, filepath);
            elseif numel(obj.Pages) == 1 && strcmp(obj.Pages{1}.Name, 'Default')
                cfg = DashboardSerializer.widgetsToConfig( ...
                    obj.Name, obj.Theme, obj.LiveInterval, obj.Pages{1}.Widgets, obj.InfoFile);
                DashboardSerializer.exportScript(cfg, filepath);
            else
                cfg = DashboardSerializer.widgetsToConfig( ...
                    obj.Name, obj.Theme, obj.LiveInterval, obj.Widgets, obj.InfoFile);
                DashboardSerializer.exportScript(cfg, filepath);
            end
        end

        function exportImage(obj, filepath, format)
        %EXPORTIMAGE Save the rendered dashboard figure as PNG or JPEG at 150 DPI.
        %   d.exportImage('out.png')           % format inferred from extension
        %   d.exportImage('out.png', 'png')
        %   d.exportImage('out.jpg', 'jpeg')
        %
        %   Requires render() to have been called (raises
        %   DashboardEngine:notRendered otherwise). Captures the entire figure
        %   via print(); on Octave the print() builtin does NOT include
        %   uicontrols (documented limitation), so the toolbar, page-bar and
        %   time-panel buttons will not appear in the exported image on Octave.
        %   MATLAB captures uicontrols normally.
        %
        %   Multi-page dashboards capture the active page only because
        %   non-active pages use Visible='off'.
        %
        %   Inputs:
        %     filepath - destination path. Parent directory must exist.
        %     format   - 'png' or 'jpeg' (alias 'jpg'). Optional; inferred
        %                from file extension if omitted (defaults to 'png').
        %
        %   Errors:
        %     DashboardEngine:notRendered       - render() has not been called
        %     DashboardEngine:unknownImageFormat - format is not png/jpeg/jpg
        %     DashboardEngine:imageWriteFailed  - export backend raised any error

            if nargin < 3 || isempty(format)
                [~, ~, ext] = fileparts(filepath);
                if strcmpi(ext, '.jpg') || strcmpi(ext, '.jpeg')
                    format = 'jpeg';
                else
                    format = 'png';
                end
            end

            if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
                error('DashboardEngine:notRendered', ...
                    'exportImage requires render() to have been called first.');
            end

            switch lower(format)
                case 'png'
                    devFlag = '-dpng';
                case {'jpeg', 'jpg'}
                    devFlag = '-djpeg';
                otherwise
                    error('DashboardEngine:unknownImageFormat', ...
                        'Unknown image format ''%s''. Use ''png'' or ''jpeg''.', format);
            end

            % Choose backend per platform/version (Phase 1006 MATLABFIX-F):
            %   * MATLAB R2024a+       : exportapp() — print() in R2025b refuses
            %     figures containing UI components and instructs the user to use
            %     exportapp. exportapp handles uipanels/uicontrols correctly.
            %     Resolution is implicit (figure pixel size + screen DPI).
            %   * MATLAB R2020a-R2023b : exportgraphics() — explicitly supports
            %     -nodisplay CI (unlike print). ContentType 'image' + Resolution
            %     150 match the legacy -r150 print path for visual parity.
            %     Available since R2020a, predates our R2020b pin target.
            %   * All Octave           : print() + stub axes (existing behaviour
            %     preserved). Octave's print() requires at least one axes object
            %     DIRECTLY under the figure (it does not recurse into uipanels),
            %     so we insert a hidden 1px stub axes when none exists and remove
            %     it after the call. Octave CI uses xvfb-run (unchanged).
            % Detection: exist() returns non-zero for both exportapp (P-file in
            % MATLAB R2024a+) and exportgraphics (M-file in MATLAB R2020a+).
            isOctave          = exist('OCTAVE_VERSION', 'builtin') ~= 0;
            useExportApp      = ~isOctave && exist('exportapp') ~= 0;       %#ok<EXIST>
            useExportGraphics = ~isOctave && exist('exportgraphics') ~= 0;  %#ok<EXIST>

            % Both exportgraphics (MATLAB) and print (Octave) only find
            % axes DIRECTLY under the figure — they do not recurse into
            % uipanels. Widgets live inside uipanels, so insert a hidden
            % 1px stub axes when none exists. exportapp handles uipanels
            % on its own and does not need the stub.
            stubAxes = [];
            if ~useExportApp
                topLevelChildren = get(obj.hFigure, 'children');
                hasTopAxes = false;
                for k = 1:numel(topLevelChildren)
                    if strcmp(get(topLevelChildren(k), 'type'), 'axes')
                        hasTopAxes = true;
                        break;
                    end
                end
                if ~hasTopAxes
                    stubAxes = axes('Parent', obj.hFigure, ...
                        'Units', 'pixels', 'Position', [0 0 1 1], ...
                        'Visible', 'off', 'HitTest', 'off');
                end
            end

            % Some MATLAB builds (notably R2020b headless) refuse to
            % export an invisible figure with the opaque error
            % "Specified handle is not valid for export" even when
            % exportgraphics/print are used with a stub axes. Temporarily
            % flip Visible='on' around the export call and restore it.
            origVisible = get(obj.hFigure, 'Visible');
            needsVisibilityToggle = ~useExportApp && strcmp(origVisible, 'off');
            if needsVisibilityToggle
                try set(obj.hFigure, 'Visible', 'on'); catch, end
            end
            try
                if useExportApp
                    % exportapp signature is exportapp(fig, filename) only
                    % (introduced R2024a). Resolution is implicit. Trade-off:
                    % we lose explicit 150 DPI on R2024a+ but gain working
                    % export of UI-component figures.
                    exportapp(obj.hFigure, filepath);
                elseif useExportGraphics
                    % MATLAB R2020a-R2023b headless path. Three-tier
                    % fallback: exportgraphics -> print -> getframe.
                    % R2020b headless CI rejects the first two with
                    % "Specified handle is not valid for export" on
                    % uipanel-only figures even with a stub axes; the
                    % getframe+imwrite path always works when the
                    % figure has rendered at least once.
                    wrote = false;
                    try
                        exportgraphics(obj.hFigure, filepath, ...
                            'ContentType', 'image', 'Resolution', 150);
                        wrote = true;
                    catch
                    end
                    if ~wrote
                        try
                            print(obj.hFigure, devFlag, '-r150', filepath);
                            wrote = true;
                        catch
                        end
                    end
                    if ~wrote
                        frame = getframe(obj.hFigure);
                        imwrite(frame.cdata, filepath);
                    end
                else
                    % Octave path (print) — stub axes already inserted above.
                    print(obj.hFigure, devFlag, '-r150', filepath);
                end
                if ~isempty(stubAxes) && ishandle(stubAxes); delete(stubAxes); end
                if needsVisibilityToggle
                    try set(obj.hFigure, 'Visible', origVisible); catch, end
                end
            catch ME
                if ~isempty(stubAxes) && ishandle(stubAxes); delete(stubAxes); end
                if needsVisibilityToggle
                    try set(obj.hFigure, 'Visible', origVisible); catch, end
                end
                error('DashboardEngine:imageWriteFailed', ...
                    'Failed to write image ''%s'': %s', filepath, ME.message);
            end
        end

        function preview(obj, varargin)
        %PREVIEW Print ASCII representation of the dashboard to console.
        %   d.preview()              % default 120 chars wide
        %   d.preview('Width', 120)  % custom width
            width = 120;
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'Width')
                    width = varargin{k+1};
                end
            end

            % Enforce minimum width
            if width < 48
                warning('DashboardEngine:previewWidth', ...
                    'Width %d too small, clamping to 48.', width);
                width = 48;
            end

            nWidgets = numel(obj.Widgets);

            % Empty dashboard
            if nWidgets == 0
                fprintf('  %s (empty -- no widgets)\n', obj.Name);
                return;
            end

            % Grid dimensions
            cols = obj.Layout.Columns;
            maxRow = 1;
            for i = 1:nWidgets
                p = obj.Widgets{i}.Position;
                bottomRow = p(2) + p(4) - 1;
                if bottomRow > maxRow
                    maxRow = bottomRow;
                end
            end

            % Character sizing
            colW = floor(width / cols);
            linesPerRow = 4;
            bufW = cols * colW;
            bufH = maxRow * linesPerRow;

            % Create character buffer (space-filled)
            buf = repmat(' ', bufH, bufW);

            % Render each widget
            for i = 1:nWidgets
                w = obj.Widgets{i};
                p = w.Position;  % [col, row, wCols, hRows]

                % Character coordinates (1-based)
                x1 = (p(1) - 1) * colW + 1;
                y1 = (p(2) - 1) * linesPerRow + 1;
                cw = p(3) * colW;
                ch = p(4) * linesPerRow;

                % Clamp to buffer bounds
                x2 = min(x1 + cw - 1, bufW);
                y2 = min(y1 + ch - 1, bufH);
                cw = x2 - x1 + 1;
                ch = y2 - y1 + 1;

                if cw < 3 || ch < 3
                    continue;
                end

                % Draw box border
                topBorder = [char(9484), repmat(char(9472), 1, cw - 2), char(9488)];
                bottomBorder = [char(9492), repmat(char(9472), 1, cw - 2), char(9496)];
                buf(y1, x1:x2) = topBorder;
                buf(y2, x1:x2) = bottomBorder;
                for row = y1+1:y2-1
                    buf(row, x1) = char(9474);
                    buf(row, x2) = char(9474);
                end

                % Get widget ASCII content
                innerW = cw - 4;
                innerH = ch - 2;
                if innerW > 0 && innerH > 0
                    lines = w.asciiRender(innerW, innerH);

                    % Pad/truncate to innerH lines
                    blank = repmat(' ', 1, innerW);
                    if numel(lines) < innerH
                        for li = numel(lines)+1:innerH
                            lines{li} = blank;
                        end
                    elseif numel(lines) > innerH
                        lines = lines(1:innerH);
                    end

                    % Ensure each line is exactly innerW chars
                    for li = 1:numel(lines)
                        ln = lines{li};
                        if numel(ln) < innerW
                            ln = [ln, repmat(' ', 1, innerW - numel(ln))];
                        elseif numel(ln) > innerW
                            ln = ln(1:innerW);
                        end
                        buf(y1 + li, x1+2:x1+1+innerW) = ln;
                    end
                end
            end

            % Print header
            fprintf('\n  %s (%d widgets, %dx%d grid)\n', ...
                obj.Name, nWidgets, cols, maxRow);

            % Print buffer
            for row = 1:bufH
                fprintf('%s\n', buf(row, :));
            end
            fprintf('\n');
        end

        function showInfo(obj)
        %SHOWINFO Display the linked Markdown info file in a browser.
        %   When InfoFile is empty, displays a built-in placeholder page
        %   describing how to attach a custom info file.
            if isempty(obj.InfoFile)
                mdText = obj.buildPlaceholderInfoMarkdown();
                mdDir = pwd;
                html = MarkdownRenderer.render(mdText, obj.Theme, mdDir);
                obj.writeAndOpenInfoHtml(html);
                return;
            end

            % Resolve file path — pure string check (Octave-compatible)
            isAbsPath = (numel(obj.InfoFile) > 0 && obj.InfoFile(1) == '/') || ...
                (numel(obj.InfoFile) > 1 && obj.InfoFile(2) == ':');
            if isAbsPath
                mdPath = obj.InfoFile;
            else
                if ~isempty(obj.FilePath)
                    baseDir = fileparts(obj.FilePath);
                else
                    baseDir = pwd;
                end
                mdPath = fullfile(baseDir, obj.InfoFile);
            end

            % Check file exists
            if ~exist(mdPath, 'file')
                warning('DashboardEngine:infoFileNotFound', ...
                    'Info file not found: %s', mdPath);
                return;
            end

            % Read file with safe fclose on both paths
            fid = fopen(mdPath, 'r');
            if fid == -1
                warning('DashboardEngine:infoReadError', ...
                    'Cannot open info file: %s', mdPath);
                return;
            end
            try
                mdText = fread(fid, '*char')';
                fclose(fid);
            catch ME
                fclose(fid);
                warning('DashboardEngine:infoReadError', ...
                    'Failed to read info file: %s', ME.message);
                return;
            end

            % Convert to HTML with base path for relative image/link resolution
            mdDir = fileparts(mdPath);
            html = MarkdownRenderer.render(mdText, obj.Theme, mdDir);

            obj.writeAndOpenInfoHtml(html);
        end

        function writeAndOpenInfoHtml(obj, html)
        %WRITEANDOPENINFOHTML Write rendered HTML to the cached temp file and open it.
            if isempty(obj.InfoTempFile)
                obj.InfoTempFile = [tempname '.html'];
            end
            fid = fopen(obj.InfoTempFile, 'w');
            if fid == -1
                warning('DashboardEngine:infoWriteError', ...
                    'Cannot write temp file: %s', obj.InfoTempFile);
                return;
            end
            fwrite(fid, html);
            fclose(fid);

            if exist('OCTAVE_VERSION', 'builtin')
                if ismac
                    system(['open "' obj.InfoTempFile '"']);
                elseif ispc
                    system(['cmd /c start "" "' obj.InfoTempFile '"']);
                else
                    system(['xdg-open "' obj.InfoTempFile '"']);
                end
            else
                % Only render the in-app modal when running in an interactive
                % desktop MATLAB session. Skip on -batch / -nodisplay so CI
                % does not block on a uifigure that no one will ever close
                % (and avoids the JVM segfault history that the older web()
                % path was designed to dodge — see TestDashboardInfo failure,
                % GitHub Actions run 25550691546).
                % The temp HTML file is already on disk above, which is what
                % the TestDashboardInfo suite verifies for headless runs.
                interactive = usejava('desktop');
                if interactive && exist('batchStartupOptionUsed', 'builtin') && ...
                        batchStartupOptionUsed()
                    interactive = false;
                end
                if interactive
                    obj.showInfoModal_(html);
                end
            end
        end

        function showInfoModal_(obj, html)
        %SHOWINFOMODAL_ Render the info HTML in an in-app modal uifigure (260508-n8h).
        %   Replaces the previous browser handoff via web(). Reuses an
        %   existing modal if still open so repeated Info-button clicks
        %   refocus rather than stack windows. Falls back silently on
        %   uifigure construction errors (older MATLAB releases without
        %   uihtml support keep the temp HTML file as the user-facing
        %   artifact).
            if ~isempty(obj.InfoModalFigure_) && ishandle(obj.InfoModalFigure_)
                try
                    set(obj.InfoModalFigure_, 'Name', ['Info — ' obj.Name]);
                    htmlChild = findobj(obj.InfoModalFigure_, '-depth', 1, ...
                        'Type', 'uihtml');
                    if ~isempty(htmlChild)
                        set(htmlChild(1), 'HTMLSource', html);
                    end
                    figure(obj.InfoModalFigure_);  % bring to front
                    return;
                catch
                    obj.InfoModalFigure_ = [];
                end
            end

            try
                fig = uifigure('Name', ['Info — ' obj.Name], ...
                    'Position', [100 100 800 600], ...
                    'WindowStyle', 'modal', ...
                    'Visible', 'on');
                movegui(fig, 'center');
                hHtml = uihtml(fig, ...
                    'Position', [0 0 800 600], ...
                    'HTMLSource', html);
                % Anchor the uihtml to fill the figure on resize.
                set(fig, 'AutoResizeChildren', 'off');
                set(fig, 'SizeChangedFcn', @(src, ~) obj.onInfoModalResize_(src, hHtml));
                set(fig, 'CloseRequestFcn', @(src, ~) obj.onInfoModalClose_(src));
                obj.InfoModalFigure_ = fig;
            catch ME
                warning('DashboardEngine:infoModalCreateError', ...
                    'Failed to open info modal: %s', ME.message);
                obj.InfoModalFigure_ = [];
            end
        end

        function onInfoModalResize_(~, src, hHtml)
        %ONINFOMODALRESIZE_ Keep the uihtml panel filling the modal figure.
            try
                pos = get(src, 'Position');
                set(hHtml, 'Position', [0 0 pos(3) pos(4)]);
            catch
                % Resize before children built — ignore.
            end
        end

        function onInfoModalClose_(obj, src)
        %ONINFOMODALCLOSE_ Clear the cached modal handle and dispose the figure.
            try delete(src); catch, end
            obj.InfoModalFigure_ = [];
        end

        function md = buildPlaceholderInfoMarkdown(obj)
        %BUILDPLACEHOLDERINFOMARKDOWN Default info page shown when no InfoFile is set.
            name = obj.Name;
            if isempty(name)
                name = 'Dashboard';
            end
            md = sprintf([ ...
                '# %s\n\n' ...
                'No info page has been configured for this dashboard.\n\n' ...
                '## Add your own info page\n\n' ...
                'Attach a Markdown file at construction:\n\n' ...
                '```matlab\n' ...
                'd = DashboardEngine(''%s'', ''InfoFile'', ''notes.md'');\n' ...
                '```\n\n' ...
                'Or set it after construction:\n\n' ...
                '```matlab\n' ...
                'd.InfoFile = ''notes.md'';\n' ...
                '```\n\n' ...
                'Relative paths resolve against the loaded dashboard JSON ' ...
                'directory (or `pwd` for unsaved dashboards).\n'], ...
                name, name);
        end

        function cleanupInfoTempFile(obj)
        %CLEANUPINFOTEMPFILE Delete the temporary HTML file if it exists.
            if ~isempty(obj.InfoTempFile) && exist(obj.InfoTempFile, 'file')
                delete(obj.InfoTempFile);
                obj.InfoTempFile = '';
            end
        end

        function removeWidget(obj, idx)
        %REMOVEWIDGET Remove widget at given index and re-layout.
            if ~isempty(obj.Pages)
                widgets = obj.Pages{obj.ActivePage}.Widgets;
                if idx >= 1 && idx <= numel(widgets)
                    w = widgets{idx};
                    obj.Pages{obj.ActivePage}.Widgets(idx) = [];
                    delete(w);
                    if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                        obj.rerenderWidgets();
                    end
                end
            else
                if idx >= 1 && idx <= numel(obj.Widgets)
                    w = obj.Widgets{idx};
                    obj.Widgets(idx) = [];
                    delete(w);
                    if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                        obj.rerenderWidgets();
                    end
                end
            end
        end

        function setWidgetPosition(obj, idx, pos)
        %SETWIDGETPOSITION Set the grid position of a widget by index.
        %   Clamps width to grid columns and resolves overlaps with other
        %   widgets.
            if idx < 1 || idx > numel(obj.Widgets)
                error('DashboardEngine:invalidIndex', ...
                    'Widget index %d out of range [1, %d].', idx, numel(obj.Widgets));
            end
            % Clamp to grid bounds
            cols = obj.Layout.Columns;
            pos(1) = max(1, min(pos(1), cols));
            pos(3) = max(1, min(pos(3), cols - pos(1) + 1));
            pos(2) = max(1, pos(2));
            pos(4) = max(1, pos(4));
            % Resolve overlaps against other widgets
            existingPositions = cell(1, numel(obj.Widgets) - 1);
            k = 0;
            for i = 1:numel(obj.Widgets)
                if i ~= idx
                    k = k + 1;
                    existingPositions{k} = obj.Widgets{i}.Position;
                end
            end
            pos = obj.Layout.resolveOverlap(pos, existingPositions);
            obj.Widgets{idx}.Position = pos;
        end

        function w = getWidgetByTitle(obj, title)
        %GETWIDGETBYTITLE Find a widget by its Title property.
        %   Returns the widget object, or empty if not found.
            w = [];
            for i = 1:numel(obj.Widgets)
                if strcmp(obj.Widgets{i}.Title, title)
                    w = obj.Widgets{i};
                    return;
                end
            end
        end

        function detachWidget(obj, widget)
        %DETACHWIDGET Pop a widget out as a standalone figure window.
        %
        %   Creates a DetachedMirror for the given widget and adds it to
        %   DetachedMirrors. The mirror's figure is driven by the engine's
        %   existing LiveTimer via the onLiveTick() mirror loop.
        %
        %   The removeCallback uses a containers.Map (a handle object) as an
        %   indirect reference so the mirror identity can be captured after
        %   construction — MATLAB closures capture values, but containers.Map
        %   is a handle class, so mutations to it are visible through all
        %   references.

            themeStruct = obj.getCachedTheme();
            % containers.Map is a handle object — mutations after closure creation
            % are visible through the captured reference (unlike cells/structs).
            mirrorHolder = containers.Map({'mirror'}, {[]});
            removeCallback = @() obj.removeDetachedByRef(mirrorHolder);
            mirror = DetachedMirror(widget, themeStruct, removeCallback);
            mirrorHolder('mirror') = mirror;
            obj.DetachedMirrors{end+1} = mirror;
        end

        function removeDetached(obj)
        %REMOVEDETACHED Remove stale mirrors from the registry.
        %
        %   Scans DetachedMirrors and removes any entries where isStale() is
        %   true (figure closed or handle deleted). Called from test code to
        %   explicitly prune stale mirrors. onLiveTick() performs the same
        %   scan inline each tick.

            keep = true(1, numel(obj.DetachedMirrors));
            for i = 1:numel(obj.DetachedMirrors)
                if obj.DetachedMirrors{i}.isStale()
                    keep(i) = false;
                end
            end
            obj.DetachedMirrors = obj.DetachedMirrors(keep);
        end

        function setContentArea(obj, contentArea)
        %SETCONTENTAREA Update the Layout content area.
        %   Provided so that DashboardBuilder can modify the layout
        %   without direct write-access to the Layout property (required
        %   for Octave compatibility).
            obj.Layout.ContentArea = contentArea;
        end

        function [effToolbarH, effPageBarH, effTimeH] = applyChromeVisibility(obj, toolbarH, pageBarH)
        %APPLYCHROMEVISIBILITY Set chrome Visible state + return effective heights.
        %   Respects ShowToolbar and ShowTimePanel flags. Returns the heights
        %   that should be used for the content-area calculation (0 when the
        %   corresponding chrome element is hidden).
            if nargin < 2 || isempty(toolbarH)
                if ~isempty(obj.Toolbar), toolbarH = obj.Toolbar.Height; else, toolbarH = 0; end
            end
            if nargin < 3 || isempty(pageBarH)
                if numel(obj.Pages) > 1, pageBarH = obj.PageBarHeight; else, pageBarH = 0; end
            end
            timeH = obj.TimePanelHeight;

            effToolbarH = toolbarH;  % toolbar is always visible (config lives there)
            if obj.ShowTimePanel
                tpVis = 'on';  effTimeH = timeH;
            else
                tpVis = 'off'; effTimeH = 0;
            end
            effPageBarH = pageBarH;  % page bar follows multi-page state, not a flag

            if ~isempty(obj.hTimePanel) && ishandle(obj.hTimePanel)
                set(obj.hTimePanel, 'Visible', tpVis);
            end
        end

        function applyVisibilityAndRelayout(obj)
        %APPLYVISIBILITYANDRELAYOUT Re-apply ShowToolbar/ShowTimePanel + re-layout widgets.
            if isempty(obj.hFigure) || ~ishandle(obj.hFigure) || isempty(obj.Layout)
                return;
            end
            [effToolbarH, effPageBarH, effTimeH] = obj.applyChromeVisibility();
            % BannerHeight is reserved at the top — content area never extends
            % into the banner strip (260508-jyh).
            obj.Layout.ContentArea = [0, effTimeH, ...
                1, 1 - obj.BannerHeight - effToolbarH - effPageBarH - effTimeH];
            % Reposition the banner so it stays parked in the reserved strip
            % even after a re-layout. Body is geometry-stable now (constant
            % Y), but the call is preserved as defence-in-depth.
            obj.repositionStaleBanner_();
            try
                obj.rerenderWidgets();
            catch
                % best-effort: layout requires active widgets
            end
        end

        function applyThemeToChrome(obj)
        %APPLYTHEMETOCHROME Restyle figure + non-widget chrome using the current Theme.
        %   Widget panels are NOT touched here — call rerenderWidgets() after
        %   this method to recreate widget content with the new theme.
            if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
                return;
            end
            theme = obj.getCachedTheme();

            set(obj.hFigure, 'Color', theme.DashboardBackground);

            % Content-area viewport + canvas
            if ~isempty(obj.Layout) && ~isempty(obj.Layout.hViewport) && ...
                    ishandle(obj.Layout.hViewport)
                set(obj.Layout.hViewport, ...
                    'BackgroundColor', theme.DashboardBackground);
            end
            if ~isempty(obj.Layout) && ~isempty(obj.Layout.hCanvas) && ...
                    ishandle(obj.Layout.hCanvas)
                set(obj.Layout.hCanvas, ...
                    'BackgroundColor', theme.DashboardBackground);
            end

            % Toolbar panel + title + last-update label
            if ~isempty(obj.Toolbar)
                tb = obj.Toolbar;
                if ~isempty(tb.hPanel) && ishandle(tb.hPanel)
                    set(tb.hPanel, 'BackgroundColor', theme.ToolbarBackground);
                end
                if ~isempty(tb.hTitleText) && ishandle(tb.hTitleText)
                    set(tb.hTitleText, ...
                        'BackgroundColor', theme.ToolbarBackground, ...
                        'ForegroundColor', theme.ToolbarFontColor);
                end
                if ~isempty(tb.hLastUpdate) && ishandle(tb.hLastUpdate)
                    fadedFg = theme.ToolbarFontColor * 0.6 + ...
                        theme.ToolbarBackground * 0.4;
                    set(tb.hLastUpdate, ...
                        'BackgroundColor', theme.ToolbarBackground, ...
                        'ForegroundColor', fadedFg);
                end
                if ~isempty(tb.hLivePanel) && ishandle(tb.hLivePanel)
                    set(tb.hLivePanel, 'BackgroundColor', theme.ToolbarBackground);
                    % Preserve blue accent when live is active; otherwise blend in.
                    if obj.IsLive
                        set(tb.hLivePanel, 'HighlightColor', theme.InfoColor);
                    else
                        set(tb.hLivePanel, 'HighlightColor', theme.ToolbarBackground);
                    end
                end
            end

            % Time control panel + its labels
            if ~isempty(obj.hTimePanel) && ishandle(obj.hTimePanel)
                set(obj.hTimePanel, ...
                    'BackgroundColor', theme.ToolbarBackground, ...
                    'ForegroundColor', theme.WidgetBorderColor);
            end
            for h = [obj.hTimeStart, obj.hTimeEnd]
                if ~isempty(h) && ishandle(h)
                    set(h, ...
                        'BackgroundColor', theme.ToolbarBackground, ...
                        'ForegroundColor', theme.ToolbarFontColor);
                end
            end
            % Reset button shares the time panel's background/foreground.
            if ~isempty(obj.hTimeResetBtn) && ishandle(obj.hTimeResetBtn)
                set(obj.hTimeResetBtn, ...
                    'BackgroundColor', theme.ToolbarBackground, ...
                    'ForegroundColor', theme.ToolbarFontColor);
            end

            % Page bar (visible or placeholder)
            if ~isempty(obj.hPageBar) && ishandle(obj.hPageBar)
                set(obj.hPageBar, 'BackgroundColor', theme.ToolbarBackground);
            end
        end

        function rerenderWidgets(obj)
        %RERENDERWIDGETS Delete all widget panels and recreate them.
            % Mark in-flight so the SizeChangedFcn that fires during
            % panel teardown/recreate doesn't schedule new resize-debounce
            % timers — that would cause a recursive rerender cascade.
            % Also cancel any timers that ARE currently scheduled — they
            % are about to be invalidated by this rerender anyway.
            % (260513-q7w fu2)
            obj.IsRerendering_ = true;
            obj.cancelResizeTimers_();
            rerenderCleanup = onCleanup(@() obj.clearRerenderFlag_());
            theme = obj.getCachedTheme();
            ws = obj.activePageWidgets();
            for i = 1:numel(ws)
                w = ws{i};
                w.markUnrealized();
                % Delete the OUTER cell panel. After realization,
                % w.hPanel was reassigned to the INNER content panel
                % (line 356 of DashboardLayout.realizeWidget), so
                % deleting only w.hPanel leaves the outer cell —
                % which still owns the WidgetButtonBar — alive on
                % the canvas as a ZOMBIE. Stacked across multiple
                % rerenders these zombies covered the canvas at
                % overlapping z-positions and painted over freshly
                % switched-to pages (visible symptom: a tab change
                % shows panels with chrome i/^ buttons but blank
                % white content). hCellPanel is the outer handle
                % when set; falls back to hPanel for pre-realization
                % widgets where hPanel IS the outer cell.
                % (260513-q7w fu4)
                outer = w.hCellPanel;
                if isempty(outer) || ~ishandle(outer)
                    outer = w.hPanel;
                end
                if ~isempty(outer) && ishandle(outer)
                    delete(outer);
                end
                w.hPanel = [];
                w.hCellPanel = [];
            end
            % Reinstall TimeRangeSelector callbacks NOW — with a clean WBM root
            % — BEFORE new HoverCrosshairs install on top in Layout.realizeWidget
            % below. Each new HC's constructor saves the figure's CURRENT WBM as
            % its PrevWBMFcn_ and replaces WBM with its own onFigureMove_. If we
            % reinstall AFTER the realizeWidget loop (as 260512-egv did) we
            % wipe out the newly-installed HC chain and break per-widget
            % HoverCrosshair. Reinstalling HERE makes WBM = trs.onButtonMotion_
            % so new HCs save the clean trs handler as PrevWBMFcn_ and chain
            % on top — final chain: newHcN → ... → newHc1 → trs.onButtonMotion_.
            % Both slider drag (forwards down chain) and HoverCrosshair (each
            % HC's onFigureMove_ on the chain) work. (260512-eu2; supersedes
            % the end-of-method placement from 260512-egv.)
            if ~isempty(obj.TimeRangeSelector_) && ...
                    isa(obj.TimeRangeSelector_, 'TimeRangeSelector')
                try
                    obj.TimeRangeSelector_.reinstallCallbacks();
                catch err
                    warning('DashboardEngine:trsReinstallFailed', ...
                        'TimeRangeSelector.reinstallCallbacks failed: %s', err.message);
                end
            end
            totalPages = max(1, numel(obj.Pages));
            obj.Progress_ = DashboardProgress(obj.Name, numel(ws), totalPages, obj.ProgressMode);
            [pgIdx, pgName] = obj.activePageLabel();
            obj.Layout.allocatePanels(obj.hFigure, ws, theme);
            for i = 1:numel(ws)
                obj.Layout.realizeWidget(ws{i});
                obj.Progress_.tick(ws{i}, pgIdx, pgName);
            end
            obj.Progress_.finish();
            obj.Progress_ = [];
            % Re-wire detach callback after panel recreation (Pitfall 3 in RESEARCH.md)
            obj.Layout.DetachCallback = @(w) obj.detachWidget(w);
        end

        function updateGlobalTimeRange(obj)
        %UPDATEGLOBALTIMERANGE Scan all widgets for data time bounds.
            tMin = inf; tMax = -inf;
            ws = obj.activePageWidgets();
            for i = 1:numel(ws)
                [wMin, wMax] = ws{i}.getTimeRange();
                if wMin < tMin, tMin = wMin; end
                if wMax > tMax, tMax = wMax; end
            end
            if isinf(tMin) || isinf(tMax)
                tMin = 0; tMax = 1;
            end
            obj.DataTimeRange = [tMin, tMax];

            % Reset selection to full range via the selector.
            % Guard on type (not ishandle) — hTimeSliderL now points at a
            % TimeRangeSelector which ishandle() returns false for under
            % stock Octave 7.
            if ~isempty(obj.TimeRangeSelector_) && ...
                    isa(obj.TimeRangeSelector_, 'TimeRangeSelector')
                obj.TimeRangeSelector_.setDataRange(tMin, tMax);
            end

            obj.updateTimeLabels(tMin, tMax);
            % Refresh the preview envelope after DataTimeRange change (D-07).
            try obj.computePreviewEnvelope(); catch err
                if obj.DebugPreview_, warning('DashboardEngine:previewFailed', 'computePreviewEnvelope: %s', err.message); end
            end
            try obj.computeEventMarkers();    catch err
                if obj.DebugPreview_, warning('DashboardEngine:eventMarkersFailed', 'computeEventMarkers: %s', err.message); end
            end
            % Phase 1031 PLOG-VIZ-01/08: refresh plant-log slider markers too.
            try obj.computePlantLogMarkers(); catch err
                if obj.DebugPreview_, warning('DashboardEngine:plantLogMarkersFailed', 'computePlantLogMarkers: %s', err.message); end
            end
        end

        function updateLiveTimeRange(obj)
        %UPDATELIVETIMERANGE Update DataTimeRange without resetting sliders.
        %   Called during live mode to expand the time range as data grows.
            tMin = inf; tMax = -inf;
            ws = obj.activePageWidgets();
            for i = 1:numel(ws)
                [wMin, wMax] = ws{i}.getTimeRange();
                if wMin < tMin, tMin = wMin; end
                if wMax > tMax, tMax = wMax; end
            end
            if isinf(tMin) || isinf(tMax)
                return;  % no widgets report time data
            end
            obj.DataTimeRange = [tMin, tMax];
        end

        function newTMax = updateLiveTimeRangeFrom(obj, ws)
        %UPDATELIVETIMERANGEFROM Update DataTimeRange from pre-fetched widget list.
        %   Like updateLiveTimeRange but accepts ws to avoid re-fetching activePageWidgets().
        %   Returns the new tMax (or NaN when no widget has finite time data).
            tMin = inf; tMax = -inf;
            for i = 1:numel(ws)
                [wMin, wMax] = ws{i}.getTimeRange();
                if wMin < tMin, tMin = wMin; end
                if wMax > tMax, tMax = wMax; end
            end
            if isinf(tMin) || isinf(tMax)
                newTMax = NaN;
                return;
            end
            obj.DataTimeRange = [tMin, tMax];
            newTMax = tMax;
        end

        function createStaleBanner(obj, theme, toolbarH) %#ok<INUSD>
        %CREATESTALEBANNER Create the hidden stale-data warning banner.
        %   Permanent reserved strip at the very TOP of the figure.
        %   Toolbar, page tabs, and content area all sit BELOW this strip —
        %   the banner is never an overlay (260508-jyh). Hidden by default;
        %   shown when staleness is detected and not previously dismissed
        %   by the user. toolbarH is retained for signature compat; banner
        %   now lives in the reserved top strip independent of chrome
        %   heights.
            if ~isempty(obj.hStaleBanner) && ishandle(obj.hStaleBanner)
                return;
            end
            bannerH = obj.BannerHeight;
            warnColor = theme.StatusWarnColor;
            fgColor   = [0.15 0.10 0.02];

            bannerY = 1 - bannerH;  % Reserved strip at the very top of the figure

            obj.hStaleBanner = uipanel('Parent', obj.hFigure, ...
                'Units', 'normalized', ...
                'Position', [0, bannerY, 1, bannerH], ...
                'BorderType', 'none', ...
                'BackgroundColor', warnColor, ...
                'Visible', 'off');

            obj.hStaleBannerText = uicontrol('Parent', obj.hStaleBanner, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.01, 0.1, 0.94, 0.8], ...
                'String', '', ...
                'FontWeight', 'bold', ...
                'FontSize', 10, ...
                'HorizontalAlignment', 'left', ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', warnColor);

            obj.hStaleBannerClose = uicontrol('Parent', obj.hStaleBanner, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [0.96, 0.15, 0.03, 0.7], ...
                'String', 'X', ...
                'FontWeight', 'bold', ...
                'TooltipString', 'Dismiss this warning (reappears when data resumes then stops again)', ...
                'Callback', @(~,~) obj.onStaleBannerClose());
        end

        function repositionStaleBanner_(obj)
        %REPOSITIONSTALEBANNER_ Park banner in the reserved top strip.
        %   Banner now lives in a permanent strip at the figure top; no
        %   chrome-height dependence (260508-jyh). Safe to call before
        %   render or after teardown — no-ops when the handle is
        %   empty/invalid.
            if isempty(obj.hStaleBanner) || ~ishandle(obj.hStaleBanner)
                return;
            end
            set(obj.hStaleBanner, 'Position', ...
                [0, 1 - obj.BannerHeight, 1, obj.BannerHeight]);
        end

        function showStaleBanner(obj, staleTitles)
        %SHOWSTALEBANNER Display the warning listing the widgets without new data.
        %   staleTitles is a cell array of widget Title strings whose tMax
        %   did not advance on the last live tick.
            if isempty(obj.hStaleBanner) || ~ishandle(obj.hStaleBanner)
                return;
            end
            secs = obj.LiveInterval;
            if secs >= 10
                intervalStr = sprintf('%.0fs', secs);
            else
                intervalStr = sprintf('%.1fs', secs);
            end
            msg = obj.buildStaleMessage(staleTitles, intervalStr);
            set(obj.hStaleBannerText, 'String', msg);
            % Only raise to front on first show (when transitioning from hidden
            % to visible). Calling uistack on every tick is expensive (~10 ms
            % in uifigure due to WebComponentController updates) and unnecessary
            % once the banner is already visible and at the top.
            wasHidden = strcmp(get(obj.hStaleBanner, 'Visible'), 'off');
            set(obj.hStaleBanner, 'Visible', 'on');
            if wasHidden
                try
                    uistack(obj.hStaleBanner, 'top');
                catch
                    % uistack is MATLAB-only; Octave's renderer handles z-order differently.
                end
            end
        end

        function hideStaleBanner(obj)
        %HIDESTALEBANNER Clear the stale-data warning overlay.
            if isempty(obj.hStaleBanner) || ~ishandle(obj.hStaleBanner)
                return;
            end
            set(obj.hStaleBanner, 'Visible', 'off');
        end

        function onStaleBannerClose(obj)
        %ONSTALEBANNERCLOSE User dismissed the warning; stay hidden until data resumes.
            obj.StaleBannerDismissed_ = true;
            obj.hideStaleBanner();
        end

        function msg = buildStaleMessage(obj, staleTitles, intervalStr) %#ok<INUSL>
        %BUILDSTALEMESSAGE Compose the banner text listing stale widgets.
            if exist('OCTAVE_VERSION', 'builtin')
                % Octave's default char() range is 8-bit; use an ASCII marker
                % to avoid the "range error for conversion" warning.
                warnChar = '[!]';
            else
                warnChar = char(hex2dec('26A0'));
            end
            n = numel(staleTitles);
            if n == 0
                msg = sprintf('%s  No new data in the last %s', warnChar, intervalStr);
                return;
            end
            shownMax = 3;
            if n <= shownMax
                listStr = strjoin(staleTitles, ', ');
            else
                head = strjoin(staleTitles(1:shownMax), ', ');
                listStr = sprintf('%s (+%d more)', head, n - shownMax);
            end
            if n == 1
                msg = sprintf('%s  No new data (%s) from: %s', ...
                    warnChar, intervalStr, listStr);
            else
                msg = sprintf('%s  %d widgets have no new data (%s): %s', ...
                    warnChar, n, intervalStr, listStr);
            end
        end

        function staleTitles = detectStaleWidgets(obj, ws)
        %DETECTSTALEWIDGETS Return titles of widgets whose tMax did not advance.
        %   Updates LastTMaxPerWidget_ with the current observation.
            staleTitles = {};
            if isempty(obj.LastTMaxPerWidget_)
                obj.LastTMaxPerWidget_ = containers.Map('KeyType', 'char', 'ValueType', 'double');
            end
            for i = 1:numel(ws)
                w = ws{i};
                [~, tMax] = w.getTimeRange();
                if ~isfinite(tMax)
                    continue;  % no time-series data to compare
                end
                if ~isempty(w.Title)
                    key = w.Title;
                else
                    key = sprintf('Widget %d', i);
                end
                if obj.LastTMaxPerWidget_.isKey(key)
                    if tMax <= obj.LastTMaxPerWidget_(key)
                        staleTitles{end+1} = key; %#ok<AGROW>
                    end
                end
                obj.LastTMaxPerWidget_(key) = tMax;
            end
        end

        function broadcastTimeRange(obj, tStart, tEnd)
        %BROADCASTTIMERANGE Push time range to widgets across ALL pages (not just active).
        %   Time sync is a dashboard-wide control: dragging the slider, clicking
        %   "Sync all", or calling broadcastTimeRangeNow updates every page's
        %   widgets so switching tabs preserves the synced window. Per-widget
        %   UseGlobalTime=false (manually zoomed) widgets opt out via their own
        %   setTimeRange guard. (260508-llw — was activePageWidgets, caused a
        %   per-tab desync bug.)
            obj.LastSyncedTimeRange_ = [tStart tEnd];
            ws = obj.allPageWidgets();
            for i = 1:numel(ws)
                try
                    ws{i}.setTimeRange(tStart, tEnd);
                catch ME
                    warning('DashboardEngine:timeRangeError', ...
                        'Widget "%s" setTimeRange failed: %s', ...
                        ws{i}.Title, ME.message);
                end
            end
        end

        function resetGlobalTime(obj)
        %RESETGLOBALTIME Re-attach all widgets across ALL pages to global time and apply.
        %   (260508-llw — was activePageWidgets, leaving widgets on inactive
        %   pages still detached after a "Reset" toolbar action.)
            ws = obj.allPageWidgets();
            for i = 1:numel(ws)
                ws{i}.UseGlobalTime = true;
            end
            obj.onTimeSlidersChanged();
        end

        function realizeBatch(obj, batchSize)
        %REALIZEBATCH Render widgets in batches with drawnow between.
            if nargin < 2, batchSize = 5; end
            ws = obj.activePageWidgets();
            visible = [];
            offscreen = [];
            for i = 1:numel(ws)
                if ~ws{i}.Realized
                    if obj.Layout.isWidgetVisible(ws{i}.Position)
                        visible(end+1) = i; %#ok<AGROW>
                    else
                        offscreen(end+1) = i; %#ok<AGROW>
                    end
                end
            end
            order = [visible, offscreen];
            [activePgIdx, activePgName] = obj.activePageLabel();
            for b = 1:batchSize:numel(order)
                bEnd = min(b + batchSize - 1, numel(order));
                for i = b:bEnd
                    obj.Layout.realizeWidget(ws{order(i)});
                    if ~isempty(obj.Progress_)
                        obj.Progress_.tick(ws{order(i)}, activePgIdx, activePgName);
                    end
                end
                drawnow;
            end
        end

        function [idx, name] = activePageLabel(obj)
        %ACTIVEPAGELABEL Index and name of the active page, or (1, '') if single-page.
            if isempty(obj.Pages) || obj.ActivePage < 1
                idx = 1; name = '';
                return;
            end
            idx = obj.ActivePage;
            name = obj.Pages{idx}.Name;
        end

        function onScrollRealize(obj, topRow, bottomRow)
        %ONSCROLLREALIZE Realize widgets that scroll into view.
            ws = obj.activePageWidgets();
            for i = 1:numel(ws)
                w = ws{i};
                if ~w.Realized && obj.Layout.isWidgetVisible(w.Position)
                    obj.Layout.realizeWidget(w);
                end
            end
            drawnow;
        end

        function onLiveTick(obj)
            if ~obj.isObjValid_()
                return;  % live timer fired after engine was deleted
            end
            if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
                return;
            end

            % Fetch active page widgets ONCE
            ws = obj.activePageWidgets();

            % Update global time range from pre-fetched list
            obj.updateLiveTimeRangeFrom(ws);

            % Per-widget staleness detection — which widgets' tMax did not advance?
            staleTitles = obj.detectStaleWidgets(ws);
            if isempty(staleTitles)
                % Fresh data somewhere → reset the user's dismissal so the
                % banner can re-appear next time things go stale.
                obj.StaleBannerDismissed_ = false;
                obj.hideStaleBanner();
            elseif ~obj.StaleBannerDismissed_
                obj.showStaleBanner(staleTitles);
            end

            % Single pass: mark sensor-bound or Tag-bound widgets dirty, then refresh
            % if dirty+realized+visible. Base-class Tag property ensures all widgets
            % expose w.Tag (Plan 1009-02); no isprop guard needed.
            % (PostSet listeners on Sensor.X/Y do not fire reliably in Octave for indexed assignment)
            for i = 1:numel(ws)
                w = ws{i};
                % Mark every widget dirty on every live tick. The previous
                % guard (`~isempty(w.Sensor) || ~isempty(w.Tag)`) skipped
                % Threshold-bound widgets (MonitorTag-backed StatusWidget /
                % IconCardWidget), Sensors-plural MultiStatusWidget,
                % ChipBarWidget (per-chip StatusFcn), and any widget using
                % StatusFcn / ValueFcn / DataFcn — so their dots / labels
                % never moved once the initial render was done. Tick
                % everything; the widget-local refresh() decides whether
                % anything actually needs redrawing.
                w.markDirty();
                % Dead-handle recovery: panel was destroyed (e.g. by a layout bug or
                % figure-close race). Drop Realized so the next scroll-realize pass
                % can rebuild it, and skip this tick.
                if ~isempty(w.hPanel) && ~ishandle(w.hPanel)
                    w.markUnrealized();
                    continue;
                end
                if w.Dirty && w.Realized && ~isempty(w.hPanel) && ishandle(w.hPanel) && ...
                        obj.Layout.isWidgetVisible(w.Position)
                    try
                        if isa(w, 'FastSenseWidget')
                            w.update();
                        else
                            w.refresh();
                        end
                    catch ME
                        warning('DashboardEngine:refreshError', ...
                            'Widget "%s" refresh failed: %s', w.Title, ME.message);
                    end
                end
            end

            % Tick detached mirrors; clean stale handles (DETACH-03, DETACH-04, DETACH-06)
            staleIdx = [];
            for i = 1:numel(obj.DetachedMirrors)
                m = obj.DetachedMirrors{i};
                if m.isStale()
                    staleIdx(end+1) = i; %#ok<AGROW>
                    continue;
                end
                m.tick();
            end
            if ~isempty(staleIdx)
                obj.DetachedMirrors(staleIdx) = [];
            end

            obj.LastUpdateTime = now;
            if ~isempty(obj.Toolbar)
                obj.Toolbar.setLastUpdateTime(obj.LastUpdateTime);
            end

            % Re-apply current selection to the updated data range (D-06).
            % Use isa(...) guard, not ishandle() — hTimeSliderL now points
            % at a TimeRangeSelector which ishandle() returns false for
            % under stock Octave 7. Broadcast is direct (not debounced)
            % since the live tick is already rate-limited.
            if ~isempty(obj.TimeRangeSelector_) && ...
                    isa(obj.TimeRangeSelector_, 'TimeRangeSelector')
                obj.TimeRangeSelector_.setDataRange( ...
                    obj.DataTimeRange(1), obj.DataTimeRange(2));
                [tStart, tEnd] = obj.TimeRangeSelector_.getSelection();
                % broadcastTimeRange(tStart, tEnd) removed (260513-ovt):
                % live ticks must not silently push the slider selection
                % onto every widget's XLim — that resets the user's X
                % view every tick. User-driven broadcast paths
                % (slider drag debounce timer, broadcastTimeRangeNow
                % public API, "Sync all" button) remain wired up.
                % Refresh BOTH label rows (in-axes selection labels +
                % below-slider edge labels) with the current selection.
                % Usually no-op because the preserve-selection fix keeps
                % Selection unchanged across live ticks; defensive against
                % programmatic re-selection (range contraction etc.).
                % (260512-hrn-followup)
                obj.updateTimeLabels(tStart, tEnd);
            end

            % Clear dirty flags AFTER slider broadcast to avoid re-dirtying
            for i = 1:numel(ws)
                ws{i}.Dirty = false;
            end
            % Refresh the preview envelope on every live tick (D-07).
            try obj.computePreviewEnvelope(); catch err
                if obj.DebugPreview_, warning('DashboardEngine:previewFailed', 'computePreviewEnvelope: %s', err.message); end
            end
            try obj.computeEventMarkers();    catch err
                if obj.DebugPreview_, warning('DashboardEngine:eventMarkersFailed', 'computeEventMarkers: %s', err.message); end
            end
            % Phase 1031 PLOG-VIZ-01/08: refresh plant-log slider markers too.
            try obj.computePlantLogMarkers(); catch err
                if obj.DebugPreview_, warning('DashboardEngine:plantLogMarkersFailed', 'computePlantLogMarkers: %s', err.message); end
            end
        end

        function markAllDirty(obj)
        %MARKALLDIRTY Flag all widgets as needing refresh.
        %   Called on theme change, figure resize, or other global state changes.
            for i = 1:numel(obj.Widgets)
                obj.Widgets{i}.markDirty();
            end
        end

        function onResize(obj)
        %ONRESIZE Handle figure resize: reposition all widget panels.
            if ~obj.isObjValid_()
                return;  % SizeChangedFcn fired after engine was deleted
            end
            % If a rerenderWidgets is currently in flight, the panel
            % teardown + recreate cascade fires its own SizeChangedFcn
            % events. Scheduling new debounce timers from inside that
            % cascade leads to recursive rerenders. Skip the entire
            % onResize body — the in-progress rerenderWidgets will leave
            % the layout consistent. (260513-q7w fu2)
            if obj.IsRerendering_
                return;
            end
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                obj.repositionPanels();
                obj.repositionStaleBanner_();
                % Invalidate the cached nBuckets so the next preview computation
                % re-derives it from the new figure pixel width.
                obj.PreviewNBuckets_ = 0;
                % Invalidate slider overlay caches: nBuckets is derived from
                % figure width, so a resize changes the bucket count and both
                % preview lines and (potentially) event markers must refresh.
                % (260508-slider-stuck)
                obj.EventMarkerTimesCache_  = [];
                obj.EventMarkerColorsCache_ = [];
                obj.PreviewLinesCache_      = {};
                % Schedule a debounced data-refresh sweep across active-page
                % widgets so any FastSenseWidget that lost its line data to a
                % resize-race ends up redrawing without the user having to
                % press the toolbar's Reset button. (260513-q7w)
                obj.scheduleResizeRefresh_();
                % Schedule a separate longer-period backstop that fires
                % unconditionally — equivalent to the user pressing Reset
                % once they have clearly stopped resizing. Catches failure
                % modes the cheap update pass doesn't (degenerate axes
                % after long holds at very small window sizes, destroyed
                % line handles, etc.). (260513-q7w fu)
                obj.scheduleResizeFinalRedraw_();
            end
        end

        function clearRerenderFlag_(obj)
        %CLEARRERENDERFLAG_ Reset IsRerendering_ via onCleanup so it
        %   always lands false even if rerenderWidgets throws.
        %   (260513-q7w fu2)
            try
                if isvalid(obj)
                    obj.IsRerendering_ = false;
                end
            catch
            end
        end

        function cancelResizeTimers_(obj)
        %CANCELRESIZETIMERS_ Stop + delete both resize-related debounce
        %   timers. Called from switchPage so a stale backstop scheduled
        %   for the previous page doesn't fire after the user has moved
        %   to a different tab; also called from rerenderWidgets so the
        %   spurious SizeChangedFcn that fires during panel teardown
        %   doesn't reschedule us into a cascade.
        %   (260513-q7w fu2)
            if ~isempty(obj.ResizeDebounceTimer)
                try
                    if isvalid(obj.ResizeDebounceTimer)
                        stop(obj.ResizeDebounceTimer);
                        delete(obj.ResizeDebounceTimer);
                    end
                catch
                end
                obj.ResizeDebounceTimer = [];
            end
            if ~isempty(obj.ResizeFinalRedrawTimer)
                try
                    if isvalid(obj.ResizeFinalRedrawTimer)
                        stop(obj.ResizeFinalRedrawTimer);
                        delete(obj.ResizeFinalRedrawTimer);
                    end
                catch
                end
                obj.ResizeFinalRedrawTimer = [];
            end
        end

        function scheduleResizeRefresh_(obj)
        %SCHEDULERESIZEREFRESH_ Coalesce rapid resize events into a single
        %   deferred refresh, mirroring the SliderDebounceTimer pattern.
        %   Drag-resize on macOS fires many SizeChangedFcn events per
        %   second; doing a full widget refresh on each would be expensive
        %   and visibly stutter. Instead, restart a 300 ms one-shot timer
        %   on every resize event — once the user stops dragging, the
        %   timer fires and refreshes all active-page widgets one time.
        %   (260513-q7w)
            if ~isempty(obj.ResizeDebounceTimer)
                try
                    if isvalid(obj.ResizeDebounceTimer)
                        stop(obj.ResizeDebounceTimer);
                        delete(obj.ResizeDebounceTimer);
                    end
                catch
                end
                obj.ResizeDebounceTimer = [];
            end
            try
                obj.ResizeDebounceTimer = timer( ...
                    'ExecutionMode', 'singleShot', ...
                    'StartDelay',    0.3, ...
                    'Tag',           'DashboardEngineResizeDebounce', ...
                    'TimerFcn',      @(~,~) obj.refreshActivePageWidgetsAfterResize_());
                start(obj.ResizeDebounceTimer);
            catch err
                % Timer creation can fail (e.g. headless / -batch / Octave).
                % Fall back to an immediate refresh in that case — better
                % to do the work synchronously than to skip it entirely.
                if obj.DebugPreview_
                    warning('DashboardEngine:resizeDebounceTimerFailed', ...
                        'scheduleResizeRefresh_: timer failed (%s), running inline.', err.message);
                end
                obj.refreshActivePageWidgetsAfterResize_();
            end
        end

        function scheduleResizeFinalRedraw_(obj)
        %SCHEDULERESIZEFINALREDRAW_ Longer-period backstop debouncer that
        %   fires once the user has clearly stopped resizing for
        %   ~1.2 seconds, and unconditionally calls rerenderWidgets() —
        %   the same operation the user would have invoked manually via
        %   the toolbar's Reset button. Runs IN PARALLEL with the cheap
        %   scheduleResizeRefresh_ (300 ms): both timers restart on every
        %   resize event, so during continuous drag neither fires; the
        %   moment dragging stops, the 300 ms cheap pass runs first and
        %   handles most cases, then this 1.2 s backstop catches any
        %   residual failure mode (degenerate axes after holding at very
        %   small sizes, destroyed line handles, etc.).
        %   (260513-q7w fu)
            if ~isempty(obj.ResizeFinalRedrawTimer)
                try
                    if isvalid(obj.ResizeFinalRedrawTimer)
                        stop(obj.ResizeFinalRedrawTimer);
                        delete(obj.ResizeFinalRedrawTimer);
                    end
                catch
                end
                obj.ResizeFinalRedrawTimer = [];
            end
            try
                obj.ResizeFinalRedrawTimer = timer( ...
                    'ExecutionMode', 'singleShot', ...
                    'StartDelay',    1.2, ...
                    'Tag',           'DashboardEngineResizeFinalRedraw', ...
                    'TimerFcn',      @(~,~) obj.finalRedrawAfterResize_());
                start(obj.ResizeFinalRedrawTimer);
            catch err
                % Timer creation failure (headless / -batch / Octave):
                % fall back to immediate execution.
                if obj.DebugPreview_
                    warning('DashboardEngine:resizeFinalRedrawTimerFailed', ...
                        'scheduleResizeFinalRedraw_: timer failed (%s), running inline.', err.message);
                end
                obj.finalRedrawAfterResize_();
            end
        end

        function finalRedrawAfterResize_(obj)
        %FINALREDRAWAFTERRESIZE_ Unconditional full rebuild of all panels
        %   on the active page after resize fully settles. Equivalent to
        %   the user pressing the toolbar's Reset button. Bulletproof
        %   catch-all for any failure mode the cheap two-pass refresh
        %   missed. (260513-q7w fu)
            if ~obj.isObjValid_()
                return;
            end
            if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
                return;
            end
            % Re-entrancy guard: if a render is currently in flight
            % (Progress_ non-empty), or rerenderWidgets is mid-flight,
            % bail entirely — the in-progress operation will leave the
            % layout consistent. Self-rescheduling here was the original
            % design but interacted badly with switchPage: the deferred
            % backstop kept landing AFTER the user navigated, on the
            % wrong page. (260513-q7w fu2)
            if ~isempty(obj.Progress_) || obj.IsRerendering_
                return;
            end
            try
                obj.rerenderWidgets();
            catch err
                if obj.DebugPreview_
                    warning('DashboardEngine:finalRedrawFailed', ...
                        'finalRedrawAfterResize_ rerenderWidgets failed: %s', err.message);
                end
            end
            try drawnow; catch, end
        end

        function refreshActivePageWidgetsAfterResize_(obj)
        %REFRESHACTIVEPAGEWIDGETSAFTERRESIZE_ Re-push data through every
        %   realized widget on the active page after a resize, so any
        %   widget whose line data was wiped by a resize-race recovers
        %   without the user having to press Reset. (260513-q7w)
        %
        %   Two-pass design:
        %     1. Cheap pass — call update()/refresh() on each widget.
        %        For most cases this re-pushes data through updateLines
        %        and restores the line.
        %     2. Detection + escalation — re-check each FastSenseWidget's
        %        first line. If XData is still empty (e.g. the user
        %        shrunk the window so small that the axes XLim got
        %        clobbered, so lineVisibleData returns empty), fall
        %        back to per-widget refresh() (rebuildForTag_); if that
        %        still doesn't fix it, escalate the whole active page
        %        to rerenderWidgets() — the same heavy hammer the user
        %        would have pressed manually via the toolbar's Reset
        %        button.
            if ~obj.isObjValid_()
                return;
            end
            if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
                return;
            end
            ws = obj.activePageWidgets();
            % --- Pass 1: cheap data re-push ---
            for i = 1:numel(ws)
                w = ws{i};
                if isempty(w) || ~isvalid(w)
                    continue;
                end
                if ~w.Realized || isempty(w.hPanel) || ~ishandle(w.hPanel)
                    continue;
                end
                try
                    if isa(w, 'FastSenseWidget')
                        w.update();
                    else
                        w.refresh();
                    end
                catch err
                    if obj.DebugPreview_
                        warning('DashboardEngine:postResizeRefreshFailed', ...
                            'post-resize refresh failed for "%s": %s', w.Title, err.message);
                    end
                end
            end
            % --- Pass 2: detect any still-white FastSenseWidget and escalate ---
            stillWhite = false;
            for i = 1:numel(ws)
                w = ws{i};
                if isempty(w) || ~isvalid(w) || ~isa(w, 'FastSenseWidget')
                    continue;
                end
                if isempty(w.FastSenseObj) || ~isvalid(w.FastSenseObj) || ~w.FastSenseObj.IsRendered
                    continue;
                end
                if ~obj.isWidgetLineWhite_(w)
                    continue;
                end
                % Try per-widget refresh() (full rebuildForTag_) first
                try
                    w.refresh();
                catch
                end
                if obj.isWidgetLineWhite_(w)
                    stillWhite = true;
                    break;  % one is enough to justify escalation
                end
            end
            if stillWhite
                % Heavy hammer — equivalent to the user pressing Reset.
                try
                    obj.rerenderWidgets();
                catch err
                    if obj.DebugPreview_
                        warning('DashboardEngine:postResizeRerenderFailed', ...
                            'post-resize rerenderWidgets failed: %s', err.message);
                    end
                end
            end
            try drawnow; catch, end
        end

        function tf = isWidgetLineWhite_(~, w)
        %ISWIDGETLINEWHITE_ True if the FastSenseWidget's first line has
        %   no XData but its bound Tag clearly does — the visible
        %   manifestation of the resize-race bug. Defensive: any
        %   missing-handle / invalid-object case returns false to avoid
        %   false-positive escalations.
            tf = false;
            try
                if isempty(w) || ~isvalid(w) || ~isa(w, 'FastSenseWidget'); return; end
                if isempty(w.FastSenseObj) || ~isvalid(w.FastSenseObj); return; end
                fp = w.FastSenseObj;
                if ~fp.IsRendered || isempty(fp.Lines); return; end
                hL = fp.Lines(1).hLine;
                if ~ishandle(hL); return; end
                xd = get(hL, 'XData');
                if ~isempty(xd); return; end
                % Line is empty; only flag as "white" if the source Tag
                % actually has samples to display. Tag-less widgets or
                % truly empty sensors should not trigger an escalation.
                if isempty(w.Tag); return; end
                try
                    [tx, ~] = w.Tag.getXY();
                    tf = ~isempty(tx);
                catch
                end
            catch
            end
        end

        function delete(obj)
            % Remove the figure-destroyed safety-net listener BEFORE any
            % other teardown so it cannot fire on a partially-destroyed
            % obj during MATLAB GC. Prevents R2021b segfault when the
            % engine handle is collected before its hFigure (260511-n1r).
            if ~isempty(obj.FigureDestroyedListener_)
                try delete(obj.FigureDestroyedListener_); catch, end
                obj.FigureDestroyedListener_ = [];
            end
            % Phase 1031 PLOG-VIZ-06: tear down hover BEFORE the selector.
            % Hover saved the selector's chained WindowButtonMotionFcn at
            % construction; restoring it must happen while the selector is
            % still alive (otherwise the restored callback handle refers to
            % a deleted TimeRangeSelector and the figure ends up with a
            % stale closure). teardownPlantLogSliderHover_ is idempotent
            % (safe to call again at the end of delete()).
            obj.teardownPlantLogSliderHover_();
            % Tear down the selector first so its figure-level callback
            % restore happens before the figure/panel potentially go away.
            if ~isempty(obj.TimeRangeSelector_) && ...
                    isa(obj.TimeRangeSelector_, 'TimeRangeSelector')
                try delete(obj.TimeRangeSelector_); catch, end
                obj.TimeRangeSelector_ = [];
            end
            % Clear the shim references so downstream cleanup doesn't try
            % to set() anything on a now-deleted selector handle.
            obj.hTimeSliderL = [];
            obj.hTimeSliderR = [];
            if ~isempty(obj.SliderDebounceTimer)
                try stop(obj.SliderDebounceTimer); catch, end
                try delete(obj.SliderDebounceTimer); catch, end
                obj.SliderDebounceTimer = [];
            end
            if ~isempty(obj.ResizeDebounceTimer)
                try stop(obj.ResizeDebounceTimer); catch, end
                try delete(obj.ResizeDebounceTimer); catch, end
                obj.ResizeDebounceTimer = [];
            end
            if ~isempty(obj.ResizeFinalRedrawTimer)
                try stop(obj.ResizeFinalRedrawTimer); catch, end
                try delete(obj.ResizeFinalRedrawTimer); catch, end
                obj.ResizeFinalRedrawTimer = [];
            end
            obj.stopLive();
            % Explicitly delete all widgets in every page so that
            % FastSenseWidget.delete() fires and cleans up FastSense timers
            % (hRefineTimer, DeferredTimer, LiveTimer) before MATLAB's GC
            % might delay their destruction. Without this, errored singleShot
            % timers can survive past teardownDemo's timerfindall() measurement.
            for pgIdx = 1:numel(obj.Pages)
                pgWidgets = obj.Pages{pgIdx}.Widgets;
                for wi = 1:numel(pgWidgets)
                    try delete(pgWidgets{wi}); catch, end
                end
            end
            obj.cleanupInfoTempFile();
            % 260508-n8h — close the in-app info modal if still open so the
            % engine never leaves orphan uifigures behind.
            if ~isempty(obj.InfoModalFigure_) && ishandle(obj.InfoModalFigure_)
                try delete(obj.InfoModalFigure_); catch, end
            end
            obj.InfoModalFigure_ = [];
            % Phase 1031 PLOG-VIZ-08: tear down plant-log live-tail listener.
            try
                if ~isempty(obj.PlantLogTickListener_) && isvalid(obj.PlantLogTickListener_)
                    delete(obj.PlantLogTickListener_);
                end
            catch
            end
            obj.PlantLogTickListener_ = [];
            % Phase 1031 PLOG-VIZ-06: tear down plant-log slider hover.
            % delete() restores prior WindowButtonMotionFcn unconditionally.
            obj.teardownPlantLogSliderHover_();
        end
    end

    methods (Hidden)
        function triggerTimeSlidersChangedForTest(obj)
        %TRIGGERTIMESLIDERSCHANGEDFORTEST Test-only hook to invoke the slider
        %   callback without going through UI events. Exposes the private
        %   onTimeSlidersChanged() debounce path to tests.
        %   (Hidden, not the narrower Access = {?matlab.unittest.TestCase},
        %   so Octave parsing survives — Octave has no matlab.unittest.)
            obj.onTimeSlidersChanged();
        end

        function broadcastTimeRangeNow(obj, tStart, tEnd)
        %BROADCASTTIMERANGENOW Test-only synchronous broadcast bypassing the
        %   SliderDebounceTimer. Stock Octave 7 batch mode has unreliable
        %   timer scheduling; tests should use this entry point to drive
        %   the broadcast deterministically. Also updates the time labels
        %   (skipping the debounced onRangeSelectorChanged path).
            obj.updateTimeLabels(tStart, tEnd);
            obj.broadcastTimeRange(tStart, tEnd);
        end

        function env = computePreviewEnvelopeForTest(obj, nBuckets)
        %COMPUTEPREVIEWENVELOPEFORTEST Test-only wrapper around the
        %   private computePreviewEnvelopeReturning_. Runs the real
        %   aggregation and returns the envelope struct so tests can
        %   assert shape/monotonicity without scraping the selector's
        %   patch handles. When nBuckets is omitted, uses the method's
        %   own width-derived default.
            if nargin < 2, nBuckets = []; end
            env = obj.computePreviewEnvelopeReturning_(nBuckets);
        end

        function setPlantLogStoreForTest_(obj, store)
        %SETPLANTLOGSTOREFORTEST_ Phase 1031 test seam — replaced by attachPlantLog in Phase 1033.
        %   Inject a PlantLogStore (or [] to detach) and immediately recompute
        %   plant-log slider markers so callers can assert on the slider state
        %   right after attach without waiting for a refresh hook.
        %
        %   Phase 1031 PLOG-VIZ-06: every store change ALWAYS tears down +
        %   (re-)builds the PlantLogSliderHover_ helper. Tearing down first
        %   ensures stale closures (capturing an old store handle) cannot
        %   survive a store swap; rebuilding requires a non-empty store AND
        %   a rendered TimeRangeSelector_. The hover closure goes through
        %   obj.lookupPlantLogEntries_ (NOT a captured-by-value store ref),
        %   so subsequent store swaps reflect immediately even if the
        %   rebuild branch is bypassed.
            if ~isempty(store) && ~isa(store, 'PlantLogStore')
                error('DashboardEngine:invalidPlantLogStore', ...
                    'store must be empty or a PlantLogStore; got %s.', class(store));
            end
            obj.PlantLogStoreInternal_ = store;
            obj.computePlantLogMarkers();
            % Phase 1031 PLOG-VIZ-06: always tear down any prior hover so
            % closures capturing the previous store handle cannot survive.
            obj.teardownPlantLogSliderHover_();
            if ~isempty(store) ...
                    && ~isempty(obj.TimeRangeSelector_) ...
                    && isa(obj.TimeRangeSelector_, 'TimeRangeSelector')
                % Lazy-construct hover when the slider is rendered AND a
                % store is attached. The lookup goes through the engine's
                % helper (indirect indirection) so future store swaps are
                % picked up without needing to rebuild the closure.
                try
                    ax = obj.TimeRangeSelector_.hAxes;
                    fig = ancestor(ax, 'figure');
                    if ~isempty(fig) && ishandle(fig)
                        obj.PlantLogSliderHover_ = PlantLogSliderHover( ...
                            fig, ax, ...
                            @(t0, t1) obj.lookupPlantLogEntries_(t0, t1));
                    end
                catch err
                    if obj.DebugPreview_
                        warning('DashboardEngine:plantLogHoverFailed', ...
                            'PlantLogSliderHover construction failed: %s', err.message);
                    end
                end
            end
        end

        function setPlantLogLiveTailForTest_(obj, tail)
        %SETPLANTLOGLIVETAILFORTEST_ Phase 1031 test seam — wires PlantLogTailTick to refresh.
        %   Inject a PlantLogLiveTail (or [] to detach + tear down listener).
        %   When non-empty, installs an addlistener that calls
        %   computePlantLogMarkers on every PlantLogTailTick so the slider
        %   refreshes without a full dashboard re-render (PLOG-VIZ-08).
            if ~isempty(tail) && ~isa(tail, 'PlantLogLiveTail')
                error('DashboardEngine:invalidPlantLogLiveTail', ...
                    'tail must be empty or a PlantLogLiveTail; got %s.', class(tail));
            end
            try
                if ~isempty(obj.PlantLogTickListener_) && isvalid(obj.PlantLogTickListener_)
                    delete(obj.PlantLogTickListener_);
                end
            catch
            end
            obj.PlantLogTickListener_ = [];
            obj.PlantLogLiveTailInternal_ = tail;
            if ~isempty(tail)
                % Phase 1032 PLOG-VIZ-08: route ticks through
                % onPlantLogTailTick_ so slider AND per-widget overlays
                % refresh on every tail tick (fan-out covers Pages,
                % single-page Widgets, and DetachedMirrors).
                obj.PlantLogTickListener_ = addlistener(tail, 'PlantLogTailTick', ...
                    @(~,~) obj.onPlantLogTailTick_());
            end
        end

        function refreshPlantLogOverlayForWidgetForTest_(obj, widget)
        %REFRESHPLANTLOGOVERLAYFORWIDGETFORTEST_ Phase 1032 test seam.
        %   Routes to refreshPlantLogOverlayForWidget_ from function-style
        %   tests (which can't satisfy the {?FastSenseWidget, ?matlab.unittest.TestCase}
        %   access list). Hidden so it doesn't show up in methods(obj).
            obj.refreshPlantLogOverlayForWidget_(widget);
        end

        function clearPlantLogOverlaysOnAllWidgetsForTest_(obj)
        %CLEARPLANTLOGOVERLAYSONALLWIDGETSFORTEST_ Phase 1032 test seam.
        %   Routes to clearPlantLogOverlaysOnAllWidgets_ from function-style
        %   tests. Hidden test seam mirroring the Phase 1031 idiom.
            obj.clearPlantLogOverlaysOnAllWidgets_();
        end

        function attachPlantLogXLimListenerForTest_(obj, widget)
        %ATTACHPLANTLOGXLIMLISTENERFORTEST_ Phase 1032 test seam.
        %   Routes to attachPlantLogXLimListener_ from function-style tests.
            obj.attachPlantLogXLimListener_(widget);
        end

        function setTimeRangeSelectorForTest_(obj, sel)
        %SETTIMERANGESELECTORFORTEST_ Phase 1031 test seam — inject a
        %   TimeRangeSelector handle without going through render(). Used by
        %   TestPlantLogSliderOverlay to assert hPlantLogMarkers state without
        %   paying full-dashboard render cost. The TimeRangeSelector_ property
        %   is Access = private, so direct assignment from a test is impossible
        %   — this hidden setter is the documented seam. Phase 1033's review
        %   may remove it once render() pathways cover the new test cases.
            if ~isempty(sel) && ~isa(sel, 'TimeRangeSelector')
                error('DashboardEngine:invalidTimeRangeSelector', ...
                    'sel must be empty or a TimeRangeSelector; got %s.', class(sel));
            end
            obj.TimeRangeSelector_ = sel;
        end
    end

    % Public page/widget accessors — moved out of the private block in
    % 260513-ovt so DashboardToolbar (and other peers) can iterate
    % widgets across all pages without triggering MethodRestricted
    % errors. (Was the root cause of "Follow toggle doesn't work" on
    % multi-page dashboards: the toolbar's try/catch silently
    % swallowed the access error.)
    methods (Access = public)
        function ws = activePageWidgets(obj)
        %ACTIVEPAGEWIDGETS Return the widget list for the currently active page.
        %   Returns obj.Pages{obj.ActivePage}.Widgets in multi-page mode,
        %   or obj.Widgets in single-page mode.
            if ~isempty(obj.Pages) && obj.ActivePage >= 1
                ws = obj.Pages{obj.ActivePage}.Widgets;
            else
                ws = obj.Widgets;
            end
        end

        function ws = allPageWidgets(obj)
        %ALLPAGEWIDGETS Return concatenation of all pages' Widgets.
        %   Used for ReflowCallback injection and Follow toggle sweep.
        %   When Pages is empty, returns obj.Widgets.
            if isempty(obj.Pages)
                ws = obj.Widgets;
                return;
            end
            ws = {};
            for i = 1:numel(obj.Pages)
                ws = [ws, obj.Pages{i}.Widgets]; %#ok<AGROW>
            end
        end
    end

    % Phase 1032 PLOG-VIZ-03 + PLOG-VIZ-04: per-widget plant-log overlay
    % helpers. Access restricted to FastSenseWidget so the widget's
    % setShowPlantLog setter can call these without exposing them as
    % public API. matlab.unittest.TestCase is included so class-based
    % suite tests can call these directly without going through the
    % public surface; function-style tests route through the public
    % FastSenseWidget.setShowPlantLog setter instead.
    %
    % The engine itself can still invoke them via obj.method_().
    % Octave parsing note: this access spec works on MATLAB R2020b+; the
    % class-based suite is MATLAB-only (function-style test SKIPs Octave
    % entirely, so the parse-time check on matlab.unittest is moot).
    methods (Access = {?FastSenseWidget, ?matlab.unittest.TestCase})

        function refreshPlantLogOverlayForWidget_(obj, widget)
        %REFRESHPLANTLOGOVERLAYFORWIDGET_ Recompute plant-log overlay for one widget (Phase 1032 PLOG-VIZ-04 + PLOG-VIZ-08).
        %   Idempotent: safe to call when widget.ShowPlantLog=false (clears
        %   markers), when the engine has no store (clears markers), or
        %   when the widget's FastSenseObj is not rendered (no-op).
        %
        %   1. Validate widget and inner FastSense are rendered.
        %   2. Clear all WidgetPlantLogMarker handles on the widget's axes.
        %   3. Early return when ShowPlantLog=false (clear-only path).
        %   4. Early return when store is empty / not a PlantLogStore.
        %   5. Read XLim from the widget's axes.
        %   6. getEntriesInRange(t0, t1) from PlantLogStoreInternal_.
        %   7. Sub-pixel coalesce: bucket entries by
        %      floor(t * pixelsPerDataUnit) and keep one entry per
        %      unique bucket (stable). pixelsPerDataUnit derived from
        %      getpixelposition(ax, true).
        %   8. setPlantLogMarkers(coalescedTimes, coalescedEntries).
        %
        %   On failure, fires DashboardEngine:plantLogOverlayFailed warning.
            try
                if isempty(widget) || ~isa(widget, 'FastSenseWidget'), return; end
                if isempty(widget.FastSenseObj) || ...
                        ~isa(widget.FastSenseObj, 'FastSense') || ...
                        ~widget.FastSenseObj.IsRendered
                    return;
                end
                ax = widget.FastSenseObj.hAxes;
                if isempty(ax) || ~ishandle(ax), return; end
                % Clear stale markers first (idempotent).
                delete(findobj(ax, 'Tag', 'WidgetPlantLogMarker'));
                if ~widget.ShowPlantLog, return; end
                if isempty(obj.PlantLogStoreInternal_) || ...
                        ~isa(obj.PlantLogStoreInternal_, 'PlantLogStore')
                    return;
                end
                xl = get(ax, 'XLim');
                t0 = xl(1);
                t1 = xl(2);
                entries = obj.PlantLogStoreInternal_.getEntriesInRange(t0, t1);
                if isempty(entries), return; end
                times = [entries.Timestamp];
                % Sub-pixel coalesce (decision D): bucket entries by their
                % floored pixel index so two timestamps that land in the
                % same screen pixel render a single line. Hover lookup
                % uses the full store, not these coalesced timestamps.
                try
                    axPosPx = getpixelposition(ax, true);
                    ax_width_px = max(axPosPx(3), 1);
                catch
                    ax_width_px = 600;  % conservative default
                end
                pixelsPerDataUnit = ax_width_px / max(t1 - t0, eps);
                buckets = floor(double(times) * pixelsPerDataUnit);
                [~, ia] = unique(buckets, 'stable');
                coalescedTimes = times(ia);
                coalescedEntries = entries(ia);
                widget.setPlantLogMarkers(coalescedTimes, coalescedEntries);
            catch err
                warning('DashboardEngine:plantLogOverlayFailed', ...
                    'refreshPlantLogOverlayForWidget_ failed: %s', err.message);
            end
        end

        function clearPlantLogOverlaysOnAllWidgets_(obj)
        %CLEARPLANTLOGOVERLAYSONALLWIDGETS_ Wipe markers on every widget + every detached mirror (Phase 1032).
        %   Does NOT flip ShowPlantLog on any widget — user state is
        %   preserved for re-attach. Called from Phase 1033's
        %   detachPlantLog() entry point and from store swaps that need
        %   to nuke stale per-widget markers.
            ws = obj.allPageWidgets();
            for i = 1:numel(ws)
                w = ws{i};
                if isa(w, 'FastSenseWidget') && ~isempty(w.FastSenseObj) && ...
                        isa(w.FastSenseObj, 'FastSense') && w.FastSenseObj.IsRendered
                    ax = w.FastSenseObj.hAxes;
                    if ~isempty(ax) && ishandle(ax)
                        try delete(findobj(ax, 'Tag', 'WidgetPlantLogMarker')); catch, end
                    end
                end
            end
            for k = 1:numel(obj.DetachedMirrors)
                m = obj.DetachedMirrors{k};
                if isempty(m) || ~isvalid(m), continue; end
                w = m.Widget;
                if isa(w, 'FastSenseWidget') && ~isempty(w.FastSenseObj) && ...
                        isa(w.FastSenseObj, 'FastSense') && w.FastSenseObj.IsRendered
                    ax = w.FastSenseObj.hAxes;
                    if ~isempty(ax) && ishandle(ax)
                        try delete(findobj(ax, 'Tag', 'WidgetPlantLogMarker')); catch, end
                    end
                end
            end
        end

        function attachPlantLogXLimListener_(obj, widget)
        %ATTACHPLANTLOGXLIMLISTENER_ Wire an XLim PostSet listener on the widget's axes (Phase 1032).
        %   Stored in widget.PlantLogXLimListener_; deleted by
        %   setShowPlantLog(false) AND by widget.delete(). Idempotent:
        %   replaces any prior listener.
            if isempty(widget) || ~isa(widget, 'FastSenseWidget'), return; end
            if ~isempty(widget.PlantLogXLimListener_)
                try delete(widget.PlantLogXLimListener_); catch, end
                widget.PlantLogXLimListener_ = [];
            end
            if isempty(widget.FastSenseObj) || ~widget.FastSenseObj.IsRendered
                return;
            end
            ax = widget.FastSenseObj.hAxes;
            if isempty(ax) || ~ishandle(ax), return; end
            try
                widget.PlantLogXLimListener_ = addlistener(ax, 'XLim', 'PostSet', ...
                    @(~,~) obj.refreshPlantLogOverlayForWidget_(widget));
            catch err
                warning('DashboardEngine:plantLogOverlayFailed', ...
                    'attachPlantLogXLimListener_ failed: %s', err.message);
            end
        end

    end

    methods (Access = private)

        function tf = isObjValid_(obj)
        %ISOBJVALID_ Cross-platform "is this handle still alive?" check.
        %   MATLAB: delegates to builtin isvalid().
        %   Octave 7+: isvalid() is not implemented for classdef handles,
        %   so the call itself throws; fall through to a property-access
        %   probe — accessing a property of a deleted handle throws on
        %   both runtimes, so the inner try/catch is the portable test.
            try
                tf = isvalid(obj);
                return;
            catch
                % Octave: isvalid undefined for classdef handles.
            end
            try
                obj.hFigure; %#ok<VUNUS>
                tf = true;
            catch
                tf = false;
            end
        end

        function repositionPanels(obj)
        %REPOSITIONPANELS Reposition existing widget panels in-place after resize.
        %   Updates panel positions based on current figure size without destroying
        %   or recreating panels. Falls back to rerenderWidgets if any panel is missing.
            ws = obj.activePageWidgets();
            % Check all panels exist; if any is missing, fall back to full rebuild
            for i = 1:numel(ws)
                if isempty(ws{i}.hPanel) || ~ishandle(ws{i}.hPanel)
                    obj.rerenderWidgets();
                    return;
                end
            end
            % Update viewport position from current ContentArea
            if ~isempty(obj.Layout.hViewport) && ishandle(obj.Layout.hViewport)
                set(obj.Layout.hViewport, 'Position', obj.Layout.ContentArea);
            end
            % Reposition each panel — no dirty marking needed since position change does not require data refresh
            for i = 1:numel(ws)
                w = ws{i};
                newPos = obj.Layout.computePosition(w.Position);
                set(w.hPanel, 'Position', newPos);
            end
        end

        function wireListeners(obj, w)
        %WIRELISTENERS Wire sensor data-change listeners to mark widget dirty.
        %   Called for both single-page and multi-page addWidget paths so
        %   sensor data-change events mark widgets dirty regardless of page
        %   routing. Uses Tag's 'DataChanged' event (fired from updateData);
        %   falls back to PostSet on X/Y for legacy Sensor-class bindings
        %   that still expose settable X/Y properties.
            if isempty(w.Sensor), return; end
            try
                addlistener(w.Sensor, 'DataChanged', @(~,~) w.markDirty());
            catch
                % Legacy fallback: PostSet on X/Y. Won't fire for Dependent
                % properties (Tag.X/Y) but kept for Sensor-class bindings.
                if isprop(w.Sensor, 'X')
                    try
                        addlistener(w.Sensor, 'X', 'PostSet', @(~,~) w.markDirty());
                    catch
                    end
                    try
                        addlistener(w.Sensor, 'Y', 'PostSet', @(~,~) w.markDirty());
                    catch
                    end
                end
            end
        end

        function removeDetachedByRef(obj, mirrorHolder)
        %REMOVEDETACHEDBYREF Remove a specific mirror from the registry by indirect reference.
        %
        %   mirrorHolder is a containers.Map (handle object) with key 'mirror'
        %   holding the DetachedMirror handle. Using a handle-class container
        %   ensures the closure captures the live reference rather than a frozen
        %   copy (MATLAB closures capture value-class variables by value).

            if ~isKey(mirrorHolder, 'mirror')
                return;
            end
            target = mirrorHolder('mirror');
            if isempty(target)
                return;
            end
            keep = true(1, numel(obj.DetachedMirrors));
            for i = 1:numel(obj.DetachedMirrors)
                if obj.DetachedMirrors{i} == target
                    keep(i) = false;
                end
            end
            obj.DetachedMirrors = obj.DetachedMirrors(keep);
        end

        function flat = flattenWidgetsForPreview_(obj, widgets, depth)
        %FLATTENWIDGETSFORPREVIEW_ Depth-first flatten of a widget list.
        %   Unwraps any container widget that returns a non-empty
        %   getNestedWidgets() cell. Used by computePreviewEnvelopeReturning_
        %   and computeEventMarkers so nested FastSenseWidgets inside a
        %   GroupWidget contribute to the slider preview / marker overlay
        %   (260508-l2k).
        %
        %   Order: input order, with each container's leaves spliced in
        %   at the container's position. Defensive depth cap of 10 stops
        %   pathological recursion (GroupWidget enforces maxDepth=2 at
        %   addChild, but the flatten is engine-level and should not
        %   assume well-formedness). getNestedWidgets() failures fall
        %   back to leaf treatment via try/catch — matches the engine's
        %   existing per-widget defensive iteration pattern.
            if nargin < 3, depth = 0; end
            flat = {};
            if depth >= 10
                flat = widgets;
                return;
            end
            for i = 1:numel(widgets)
                w = widgets{i};
                nested = {};
                try
                    nested = w.getNestedWidgets();
                catch
                    nested = {};
                end
                if isempty(nested)
                    flat = [flat, {w}]; %#ok<AGROW>
                else
                    flat = [flat, obj.flattenWidgetsForPreview_(nested, depth + 1)]; %#ok<AGROW>
                end
            end
        end

        function renderPageBar(obj, themeStruct)
        %RENDERPAGEBAR Create the PageBar uipanel with one button per page.
        %   Called from render() when numel(Pages) > 1. Y accounts for the
        %   reserved banner strip at the figure top (260508-jyh).
            toolbarH = obj.Toolbar.Height;
            hPageBar = uipanel('Parent', obj.hFigure, ...
                'Units', 'normalized', ...
                'Position', [0, 1 - obj.BannerHeight - toolbarH - obj.PageBarHeight, 1, obj.PageBarHeight], ...
                'BorderType', 'none', ...
                'BackgroundColor', themeStruct.ToolbarBackground, ...
                'Visible', 'on');
            obj.hPageButtons = {};
            nPages = numel(obj.Pages);
            for i = 1:nPages
                btnW = min(0.15, 0.9 / nPages);
                btnX = 0.05 + (i - 1) * btnW;
                if i == obj.ActivePage
                    bgColor = themeStruct.TabActiveBg;
                    fgColor = themeStruct.GroupHeaderFg;
                else
                    bgColor = themeStruct.TabInactiveBg;
                    fgColor = themeStruct.ToolbarFontColor;
                end
                hBtn = uicontrol('Parent', hPageBar, ...
                    'Style', 'pushbutton', ...
                    'Units', 'normalized', ...
                    'Position', [btnX, 0.1, btnW, 0.8], ...
                    'String', obj.Pages{i}.Name, ...
                    'BackgroundColor', bgColor, ...
                    'ForegroundColor', fgColor, ...
                    'Callback', @(~,~) obj.switchPage(i));
                obj.hPageButtons{i} = hBtn;
            end
            obj.hPageBar = hPageBar;
        end

        function createTimePanel(obj, theme)
            tH = obj.TimePanelHeight;

            % Bottom time panel now hosts a single TimeRangeSelector with a
            % data-preview envelope behind a draggable selection rectangle
            % (phase 1016, D-01/D-02). The legacy dual uicontrol sliders
            % have been replaced; hTimeSliderL / hTimeSliderR survive as
            % shims pointing at the selector handle (D-10).
            obj.hTimePanel = uipanel('Parent', obj.hFigure, ...
                'Units', 'normalized', ...
                'Position', [0, 0, 1, tH], ...
                'BorderType', 'line', ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'ForegroundColor', theme.WidgetBorderColor);

            % Time labels are rendered INSIDE the selector as text objects
            % that track the selection edges — set via updateTimeLabels ->
            % TimeRangeSelector.setLabels. No uicontrol text fields needed.
            obj.hTimeStart = [];
            obj.hTimeEnd   = [];

            % Reset button on the far left of the time panel — restores
            % the selection to the full DataTimeRange. Double-clicking the
            % selection patch does the same, but a visible button is more
            % discoverable.
            obj.hTimeResetBtn = uicontrol('Parent', obj.hTimePanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [0.003 0.15 0.035 0.7], ...
                'String', 'Reset', ...
                'FontSize', 9, ...
                'TooltipString', 'Reset the time window to the full data range', ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'Callback', @(~, ~) obj.resetTimeRange());

            % Single TimeRangeSelector replaces the two uicontrol sliders.
            % Guard on Octave: patch() with FaceAlpha + NaN vertex data crashes
            % Octave's xvfb/FLTK rendering backend (segfault in Dashboard
            % benchmarks). All callers of TimeRangeSelector_ check ~isempty(),
            % so leaving it empty on Octave is safe. The two Octave tests that
            % exercise this path (test_dashboard_preview_envelope,
            % test_dashboard_range_selector_integration) skip their
            % TimeRangeSelector-dependent assertions on Octave.
            if exist('OCTAVE_VERSION', 'builtin') == 0
                obj.TimeRangeSelector_ = TimeRangeSelector(obj.hTimePanel, ...
                    'OnRangeChanged', @(a, b) obj.onRangeSelectorChanged(a, b), ...
                    'Theme', theme);

                % Legacy shims (D-10): tests still read these handles; wire
                % them to the selector so existing `set(..., 'Value', ...)`
                % call-sites at least find a live handle. The shim itself is
                % not expected to accept slider-style Value writes — those
                % tests are documented as out-of-scope for this phase.
                obj.hTimeSliderL = obj.TimeRangeSelector_;
                obj.hTimeSliderR = obj.TimeRangeSelector_;
            end
        end

        function resetTimeRange(obj)
        %RESETTIMERANGE Restore the selection to the full DataTimeRange.
        %   Wired to the "Reset" button on the time panel; also reachable
        %   via double-click on the selection patch inside the selector.
            if isempty(obj.TimeRangeSelector_) || ...
                    ~isa(obj.TimeRangeSelector_, 'TimeRangeSelector')
                return;
            end
            tr = obj.DataTimeRange;
            obj.TimeRangeSelector_.setSelection(tr(1), tr(2));
            % setSelection fires OnRangeChanged, which debounces through
            % SliderDebounceTimer into broadcastTimeRange — restoring xlim
            % on every widget. No extra plumbing needed.
        end

        function onTimeSlidersChanged(obj)
        %ONTIMESLIDERSCHANGED Legacy test entry point (D-10).
        %   Reads the current selection from the TimeRangeSelector and
        %   routes it through onRangeSelectorChanged so tests see the
        %   same 100 ms-debounced broadcast pipeline as live drag events.
            if isempty(obj.TimeRangeSelector_) || ...
                    ~isa(obj.TimeRangeSelector_, 'TimeRangeSelector')
                return;
            end
            [tStart, tEnd] = obj.TimeRangeSelector_.getSelection();
            obj.onRangeSelectorChanged(tStart, tEnd);
        end

        function onRangeSelectorChanged(obj, tStart, tEnd)
        %ONRANGESELECTORCHANGED Callback from TimeRangeSelector.OnRangeChanged.
        %   Plugs into the same broadcast pipeline as the legacy slider
        %   callback, including the 100 ms SliderDebounceTimer coalescing (D-06).
            obj.updateTimeLabels(tStart, tEnd);
            if ~isempty(obj.SliderDebounceTimer)
                try stop(obj.SliderDebounceTimer); catch, end
                try delete(obj.SliderDebounceTimer); catch, end
                obj.SliderDebounceTimer = [];
            end
            obj.SliderDebounceTimer = timer('ExecutionMode', 'singleShot', ...
                'StartDelay', 0.1, ...
                'Tag', 'DashboardEngine', ...
                'TimerFcn', @(~,~) obj.broadcastTimeRange(tStart, tEnd));
            start(obj.SliderDebounceTimer);
        end

        function updateTimeLabels(obj, tStart, tEnd)
            %UPDATETIMELABELS Push the slider selection-edge timestamps and duration.
            %   Updates the three uicontrol text labels BELOW the slider:
            %     LEFT   — slider's LEFT selection-edge time
            %     MIDDLE — selection duration (e.g. "7d", "3h 25m", "45 s")
            %     RIGHT  — slider's RIGHT selection-edge time
            %   The in-axes selection labels were removed in 260512-hrn-followup;
            %   all time information now lives in the panel below the slider
            %   strip so it stays readable regardless of selection width.
            if isempty(obj.TimeRangeSelector_) || ...
                    ~isa(obj.TimeRangeSelector_, 'TimeRangeSelector')
                return;
            end
            leftStr   = obj.formatTimeVal(tStart);
            rightStr  = obj.formatTimeVal(tEnd);
            middleStr = obj.formatDuration_(tEnd - tStart);
            obj.TimeRangeSelector_.setRangeLabels(leftStr, rightStr, middleStr);
        end

        function s = formatDuration_(~, durDays)
            %FORMATDURATION_ Render a datenum-day span as a full "Xd Yh Zm Ws" string.
            %   Always shows all four units (days, hours, minutes,
            %   seconds) so the user sees the complete granularity of
            %   the selected window at a glance. Sub-second spans fall
            %   back to a single "N.NN s" reading.
            %   (260512-hrn-followup)
            if ~isfinite(durDays) || durDays < 0
                s = '';
                return;
            end
            durSec = durDays * 86400;
            if durSec < 1
                s = sprintf('%.2f s', durSec);
                return;
            end
            totalSec = round(durSec);
            d = floor(totalSec / 86400);
            r = mod(totalSec, 86400);
            h = floor(r / 3600);
            r = mod(r, 3600);
            m = floor(r / 60);
            ss = mod(r, 60);
            s = sprintf('%dd %dh %dm %ds', d, h, m, ss);
        end

        function computePreviewEnvelope(obj, nBuckets)
        %COMPUTEPREVIEWENVELOPE Aggregate per-bucket min/max across the
        %   currently active page's widgets (including nested GroupWidget
        %   children) and push the result onto the selector's envelope
        %   patch (D-07, D-08). Multi-page dashboards therefore reflect
        %   only the active tab — switchPage() recomputes the envelope so
        %   navigation stays in sync. nBuckets optional; when omitted,
        %   defaults to ~200 based on panel axes pixel width, clamped to
        %   [50, 400]. Silently no-ops when no selector is wired yet
        %   (e.g. before render()).
            if nargin < 2, nBuckets = []; end
            obj.computePreviewEnvelopeReturning_(nBuckets);
        end

        function env = computePreviewEnvelopeReturning_(obj, nBuckets)
        %COMPUTEPREVIEWENVELOPERETURNING_ computePreviewEnvelope + return.
        %   Same side-effects as computePreviewEnvelope, but additionally
        %   returns the aggregate envelope struct (xCenters, yMin, yMax)
        %   so Hidden test accessors can verify shape/monotonicity without
        %   scraping the selector's patch XData/YData.
            env = [];
            if isempty(obj.TimeRangeSelector_) || ...
                    ~isa(obj.TimeRangeSelector_, 'TimeRangeSelector')
                return;
            end
            if isempty(nBuckets)
                % Derive nBuckets from figure pixel width; clamp to [50, 400].
                % Cache the computed value so we avoid get/set Units on every
                % live tick (figure size rarely changes between ticks).
                if obj.PreviewNBuckets_ > 0
                    nBuckets = obj.PreviewNBuckets_;
                else
                    nBuckets = 200;
                    try
                        oldU = get(obj.hFigure, 'Units');
                        set(obj.hFigure, 'Units', 'pixels');
                        figPx = get(obj.hFigure, 'Position');
                        set(obj.hFigure, 'Units', oldU);
                        axWpx = figPx(3) * 0.94;
                        nBuckets = max(50, min(400, floor(axWpx / 2)));
                    catch
                    end
                    obj.PreviewNBuckets_ = nBuckets;
                end
            end
            ws = obj.flattenWidgetsForPreview_(obj.activePageWidgets());
            if isempty(ws)
                obj.TimeRangeSelector_.setPreviewLines({});
                env = struct('xCenters', [], 'yMin', [], 'yMax', []);
                return;
            end
            % 260508-das: widgets may return adaptive bucket counts that
            % differ from nBuckets (e.g., a 50-sample widget returns 25
            % buckets even when the caller asks for 200). We collect each
            % series as-is and only build the legacy aggregate envelope
            % from series that match the requested nBuckets — the
            % aggregate is read by computePreviewEnvelopeForTest tests
            % and must stay shape-stable, but the UI lines (linesList)
            % accept any non-empty series.
            aggMin = inf(1, nBuckets);
            aggMax = -inf(1, nBuckets);
            xCenters = [];
            haveAggSeries = false;
            linesList = {};
            for i = 1:numel(ws)
                try
                    s = ws{i}.getPreviewSeries(nBuckets);
                catch
                    s = [];
                end
                if isempty(s) || ~isstruct(s), continue; end
                if ~isfield(s, 'xCenters') || ~isfield(s, 'yMin') || ~isfield(s, 'yMax')
                    continue;
                end
                if isempty(s.xCenters) || isempty(s.yMin) || isempty(s.yMax)
                    continue;
                end
                if numel(s.xCenters) ~= numel(s.yMin) || numel(s.yMin) ~= numel(s.yMax)
                    continue;
                end
                % Per-widget line: midpoint of bucket, already normalized
                % to [0,1] by the widget (D-08). Accepted at any bucket
                % count >= 1.
                yMid = (s.yMin + s.yMax) / 2;
                linesList{end + 1} = struct('x', s.xCenters, 'y', yMid); %#ok<AGROW>
                % Legacy aggregate envelope: only fold in series that
                % match nBuckets exactly. Existing test_dashboard_preview_envelope
                % expects a fixed-shape envelope when widgets honour
                % the requested bucket count.
                if numel(s.yMin) == nBuckets && numel(s.yMax) == nBuckets
                    if ~haveAggSeries
                        xCenters = s.xCenters;
                        haveAggSeries = true;
                    end
                    aggMin = min(aggMin, s.yMin);
                    aggMax = max(aggMax, s.yMax);
                end
            end
            if isempty(linesList)
                % Cache check for the empty case.
                if isempty(obj.PreviewLinesCache_)
                    env = struct('xCenters', [], 'yMin', [], 'yMax', []);
                    return;
                end
                obj.PreviewLinesCache_ = {};
                obj.TimeRangeSelector_.setPreviewLines({});
                env = struct('xCenters', [], 'yMin', [], 'yMax', []);
                return;
            end
            % Cache check: if linesList is identical to the previous call
            % (cache hits in every FastSenseWidget.getPreviewSeries return
            % the same struct — isequal compares N*200 doubles, which is fast
            % and avoids the expensive delete/recreate of N line handles per
            % tick when data hasn't changed). (260508-slider-stuck)
            if isequal(linesList, obj.PreviewLinesCache_)
                % Preview lines unchanged — skip the delete/recreate cycle.
            else
                obj.PreviewLinesCache_ = linesList;
                obj.TimeRangeSelector_.setPreviewLines(linesList);
            end
            if ~haveAggSeries
                % No widget produced exactly nBuckets buckets — return an
                % empty envelope but keep the per-widget lines we drew.
                env = struct('xCenters', [], 'yMin', [], 'yMax', []);
                return;
            end
            aggMin(~isfinite(aggMin)) = 0;
            aggMax(~isfinite(aggMax)) = 0;
            % setPreviewLines already called above with the full linesList.
            env = struct('xCenters', xCenters, 'yMin', aggMin, 'yMax', aggMax);
        end

        function computeEventMarkers(obj)
        %COMPUTEEVENTMARKERS Aggregate event markers across the currently
        %   active page's widgets (including nested GroupWidget children)
        %   and push them onto the TimeRangeSelector's marker overlay.
        %   Multi-page dashboards therefore reflect only the active tab —
        %   switchPage() recomputes the marker overlay so navigation stays
        %   in sync.
        %
        %   Mirrors computePreviewEnvelope's guard + iteration pattern:
        %   no-op before render or when no widgets expose events. A failing
        %   widget does not block siblings (each call is wrapped in
        %   try/catch).
        %
        %   For each widget we prefer the modern getEventMarkers() shape
        %   (struct array with Time/Severity/Color fields) — it lets us
        %   color each slider marker by event severity. Widgets that
        %   predate the per-severity-color contract still expose only
        %   getEventTimes() and are folded in with default OK-severity
        %   color via the severityColor helper.
        %
        %   Tiebreaker on duplicate event Times across widgets: KEEP THE
        %   ROW WITH THE HIGHEST SEVERITY. So if widget A reports
        %   Severity=1 at t=50 and widget B reports Severity=3 at t=50,
        %   the slider draws a single alarm-red marker at t=50.
            % Guard mirrors computePreviewEnvelopeReturning_ for parity.
            % We deliberately do NOT use isvalid() here because Octave 7+11
            % does not implement isvalid() for non-timer handle objects;
            % adding it would silently drop markers via the outer try/catch.
            if isempty(obj.TimeRangeSelector_) || ...
                    ~isa(obj.TimeRangeSelector_, 'TimeRangeSelector')
                return;
            end
            % Honor the global Events toggle: when off, clear any existing
            % slider markers and bail before doing the per-widget aggregation.
            % Also reset the marker cache so re-enabling the toggle forces a
            % full redraw on the next call (260508-slider-stuck).
            if ~obj.EventMarkersVisible
                obj.EventMarkerTimesCache_  = [];
                obj.EventMarkerColorsCache_ = [];
                obj.TimeRangeSelector_.setEventMarkers([]);
                return;
            end
            ws = obj.flattenWidgetsForPreview_(obj.activePageWidgets());

            % Accumulators (parallel arrays — keep allocation-free until
            % the dedup pass at the end). Severity defaults to 1 (OK) for
            % legacy getEventTimes()-only widgets so the dedup tiebreaker
            % cleanly prefers any explicitly-tagged sev>=2 widget.
            allTimes  = [];
            allSev    = [];
            allColors = zeros(0, 3);

            % Resolve the *struct* theme — obj.Theme is a preset string
            % (e.g. 'light'/'dark'); severityColor wants a struct, so go
            % through the cached resolver. Tolerate failure (helper is
            % defensive and accepts []).
            themeStruct = [];
            try
                themeStruct = obj.getCachedTheme();
            catch
                themeStruct = [];
            end
            okColor = severityColor(themeStruct, 1);  % cached for legacy fallback

            for i = 1:numel(ws)
                w = ws{i};

                % Prefer the modern colored-marker shape when the widget
                % advertises it. ismethod works on classdef objects in
                % both MATLAB and Octave 7+.
                useMarkers = false;
                try
                    useMarkers = ismethod(w, 'getEventMarkers');
                catch
                    useMarkers = false;
                end

                if useMarkers
                    ms = struct('Time', {}, 'Severity', {}, 'Color', {});
                    try
                        ms = w.getEventMarkers();
                    catch err
                        warning('DashboardEngine:getEventMarkersFailed', ...
                            'Widget %d getEventMarkers failed: %s', i, err.message);
                        ms = struct('Time', {}, 'Severity', {}, 'Color', {});
                    end
                    for k = 1:numel(ms)
                        t = ms(k).Time;
                        if ~isnumeric(t) || ~isfinite(t)
                            continue;
                        end
                        sev = 1;
                        if isfield(ms, 'Severity') && isnumeric(ms(k).Severity) && ...
                                ~isempty(ms(k).Severity) && isfinite(ms(k).Severity(1))
                            sev = ms(k).Severity(1);
                        end
                        c = okColor;
                        if isfield(ms, 'Color') && isnumeric(ms(k).Color) && ...
                                numel(ms(k).Color) == 3
                            c = ms(k).Color(:).';
                        end
                        allTimes(end + 1)  = t;          %#ok<AGROW>
                        allSev(end + 1)    = sev;        %#ok<AGROW>
                        allColors(end + 1, :) = c;       %#ok<AGROW>
                    end
                else
                    % Legacy widgets — synthesize default-severity markers.
                    tVec = [];
                    try
                        tVec = w.getEventTimes();
                    catch err
                        warning('DashboardEngine:getEventTimesFailed', ...
                            'Widget %d getEventTimes failed: %s', i, err.message);
                        tVec = [];
                    end
                    if isempty(tVec), continue; end
                    tVec = tVec(:).';
                    tVec = tVec(isfinite(tVec));
                    for k = 1:numel(tVec)
                        allTimes(end + 1)  = tVec(k);   %#ok<AGROW>
                        allSev(end + 1)    = 1;          %#ok<AGROW>
                        allColors(end + 1, :) = okColor; %#ok<AGROW>
                    end
                end
            end

            if isempty(allTimes)
                % Cache check for the empty case.
                if isempty(obj.EventMarkerTimesCache_)
                    return;  % already empty — no need to clear markers again
                end
                obj.EventMarkerTimesCache_  = [];
                obj.EventMarkerColorsCache_ = [];
                obj.TimeRangeSelector_.setEventMarkers([]);
                return;
            end

            % Dedup pass with max-severity-wins tiebreaker.
            % unique() returns a sorted ascending row in both MATLAB and
            % Octave 7+; idx maps each input row to its bucket in uTimes.
            [uTimes, ~, idx] = unique(allTimes);
            uColors = zeros(numel(uTimes), 3);
            for k = 1:numel(uTimes)
                rows = find(idx == k);
                if numel(rows) == 1
                    uColors(k, :) = allColors(rows, :);
                else
                    [~, pickRel] = max(allSev(rows));
                    uColors(k, :) = allColors(rows(pickRel), :);
                end
            end

            % Cache check: skip the expensive delete/recreate cycle in
            % setEventMarkers when the marker set hasn't changed since the
            % last tick. Historical events are stable between ticks; only new
            % live events would invalidate the cache. isequal is fast on small
            % numeric arrays (129 events = 129 doubles + 129x3 RGB matrix).
            % (260508-slider-stuck: creating 129+ line handles every 1-second
            % tick blocked the MATLAB event loop long enough to cause null drags.)
            if isequal(uTimes, obj.EventMarkerTimesCache_) && ...
                    isequal(uColors, obj.EventMarkerColorsCache_)
                return;  % marker set unchanged — no need to redraw
            end
            obj.EventMarkerTimesCache_  = uTimes;
            obj.EventMarkerColorsCache_ = uColors;
            obj.TimeRangeSelector_.setEventMarkers(uTimes, uColors);
        end

        function computePlantLogMarkers(obj)
        %COMPUTEPLANTLOGMARKERS Push current plant-log entry timestamps onto the slider.
        %   Phase 1031 PLOG-VIZ-01..02 + 08: plant-log overlay on TimeRangeSelector.
        %   Mirrors computeEventMarkers' guard pattern (no-op before render or when
        %   no store is attached). When PlantLogStoreInternal_ is empty the markers
        %   are explicitly cleared so detach takes effect immediately.
        %
        %   Called at the same hook sites as computeEventMarkers (addPage,
        %   setEventMarkersVisible, rerenderWidgets, both live-tick paths) plus
        %   from setPlantLogStoreForTest_ and from the PlantLogTickListener_
        %   callback installed by setPlantLogLiveTailForTest_.
            if isempty(obj.TimeRangeSelector_) || ...
                    ~isa(obj.TimeRangeSelector_, 'TimeRangeSelector')
                return;
            end
            if isempty(obj.PlantLogStoreInternal_) || ...
                    ~isa(obj.PlantLogStoreInternal_, 'PlantLogStore')
                try
                    obj.TimeRangeSelector_.setPlantLogMarkers([]);
                catch
                end
                return;
            end
            try
                t0 = obj.TimeRangeSelector_.DataRange(1);
                t1 = obj.TimeRangeSelector_.DataRange(2);
                entries = obj.PlantLogStoreInternal_.getEntriesInRange(t0, t1);
                if isempty(entries)
                    obj.TimeRangeSelector_.setPlantLogMarkers([]);
                    return;
                end
                times = [entries.Timestamp];
                obj.TimeRangeSelector_.setPlantLogMarkers(times);
            catch err
                fprintf('[ENGINE WARN] computePlantLogMarkers: %s\n', err.message);
            end
        end

        function onPlantLogTailTick_(obj)
        %ONPLANTLOGTAILTICK_ PlantLogTailTick callback — fan out slider + widgets + mirrors (Phase 1032 PLOG-VIZ-08).
        %   Wraps the existing computePlantLogMarkers (slider path) and
        %   adds the per-widget refresh fan-out for every ShowPlantLog=true
        %   widget across pages AND every DetachedMirror (decision G —
        %   full parity).
            try
                obj.computePlantLogMarkers();
            catch err
                warning('DashboardEngine:plantLogOverlayFailed', ...
                    'computePlantLogMarkers (tick): %s', err.message);
            end
            % Fan out to attached widgets.
            ws = obj.allPageWidgets();
            for i = 1:numel(ws)
                w = ws{i};
                if isa(w, 'FastSenseWidget') && w.ShowPlantLog
                    try obj.refreshPlantLogOverlayForWidget_(w); catch, end
                end
            end
            % Fan out to detached mirrors (decision G — full parity).
            for k = 1:numel(obj.DetachedMirrors)
                m = obj.DetachedMirrors{k};
                if isempty(m) || ~isvalid(m), continue; end
                w = m.Widget;
                if isa(w, 'FastSenseWidget') && w.ShowPlantLog
                    try obj.refreshPlantLogOverlayForWidget_(w); catch, end
                end
            end
        end

        function entries = lookupPlantLogEntries_(obj, t0, t1)
        %LOOKUPPLANTLOGENTRIES_ Phase 1031 PLOG-VIZ-06 indirect store lookup.
        %   Helper consumed by the PlantLogSliderHover closure. Re-reads
        %   obj.PlantLogStoreInternal_ AT CALL TIME so subsequent store swaps
        %   (via setPlantLogStoreForTest_(other)) are reflected immediately
        %   without rebuilding the hover closure. Returns [] when no store
        %   is attached or when the lookup throws.
            entries = [];
            if isempty(obj.PlantLogStoreInternal_) ...
                    || ~isa(obj.PlantLogStoreInternal_, 'PlantLogStore')
                return;
            end
            try
                entries = obj.PlantLogStoreInternal_.getEntriesInRange(t0, t1);
            catch
                entries = [];
            end
        end

        function teardownPlantLogSliderHover_(obj)
        %TEARDOWNPLANTLOGSLIDERHOVER_ Phase 1031 PLOG-VIZ-06 hover teardown.
        %   Idempotent: safe to call when PlantLogSliderHover_ is empty,
        %   already-deleted, or constructed but never installed. delete()
        %   restores the prior WindowButtonMotionFcn.
            try
                if ~isempty(obj.PlantLogSliderHover_) ...
                        && isvalid(obj.PlantLogSliderHover_)
                    delete(obj.PlantLogSliderHover_);
                end
            catch
            end
            obj.PlantLogSliderHover_ = [];
        end

    end

    methods (Access = public)

        function str = formatTimeVal(~, t)
        %FORMATTIMEVAL Format a numeric time value as a human-readable string.
        %   Supports three numeric ranges:
        %     posix epoch seconds (9e8 < t < 5e9) — fast arithmetic via datevec
        %     MATLAB datenum (t > 700000, not posix) — fast via datevec
        %     raw numeric (t <= 700000) — formats as s/m/h/d suffix via sprintf
        %
        %   Hot-path note: this is called twice per live tick. Uses datevec
        %   (no string format parsing) instead of datestr (which invokes
        %   timefun/private/dateformverify on every call) to avoid ~7 ms
        %   per-call overhead. datetime constructor is also slow (~16 ms) so
        %   datevec is preferred here too.
        %
        %   The posix bracket is evaluated BEFORE the datenum bracket because
        %   posix seconds for modern dates (year 2001-2128) are also > 700000
        %   and would be wrongly interpreted as datenums without this ordering.
            % Order matters: posix epoch seconds (year 2000-2128) are > 700000,
            % so the posix bracket must be evaluated BEFORE the datenum bracket.
            if t > 9e8 && t < 5e9
                % Posix epoch seconds (year ~2000 - 2128).
                % Add posix offset (days from year 0 to 1970-01-01) and convert
                % via datevec, which is faster than datestr (no format parsing).
                % Seconds included so live ticks are visible in slider labels.
                % (260512-hrn-followup)
                try
                    dv = datevec(datenum(1970, 1, 1) + t / 86400);
                    str = sprintf('%04d-%02d-%02d %02d:%02d:%02d', ...
                        dv(1), dv(2), dv(3), dv(4), dv(5), floor(dv(6)));
                catch
                    % Fallback for Octave or edge inputs.
                    str = datestr(datenum(1970, 1, 1, 0, 0, 0) + t / 86400, ...
                                  'yyyy-mm-dd HH:MM:SS');
                end
            elseif t > 700000
                % MATLAB datenum (days since year 0000).
                % Seconds included for live-tick visibility (260512-hrn-followup).
                try
                    dv = datevec(t);
                    if t > 730000
                        str = sprintf('%04d-%02d-%02d %02d:%02d:%02d', ...
                            dv(1), dv(2), dv(3), dv(4), dv(5), floor(dv(6)));
                    else
                        str = sprintf('%02d:%02d:%02d', dv(4), dv(5), floor(dv(6)));
                    end
                catch
                    % Fallback for Octave or edge inputs.
                    if t > 730000
                        str = datestr(t, 'yyyy-mm-dd HH:MM:SS');
                    else
                        str = datestr(t, 'HH:MM:SS');
                    end
                end
            else
                % Raw numeric (seconds, samples, etc.)
                if abs(t) >= 86400
                    str = sprintf('%.1f d', t / 86400);
                elseif abs(t) >= 3600
                    str = sprintf('%.1f h', t / 3600);
                elseif abs(t) >= 60
                    str = sprintf('%.1f m', t / 60);
                else
                    str = sprintf('%.1f s', t);
                end
            end
        end

    end

    methods (Access = private)

        function onLiveTimerError(obj, ~, eventData)
        %ONLIVETIMERROR Handle errors that escape onLiveTick.
        %   Logs the error via warning and restarts the timer if the engine
        %   is still live. Keeps the dashboard refreshing despite transient
        %   widget errors.
            msg = '';
            if isstruct(eventData) && isfield(eventData, 'Data') && ...
                    isfield(eventData.Data, 'message')
                msg = eventData.Data.message;
            end
            warning('DashboardEngine:timerError', ...
                '[DashboardEngine] Live timer error: %s', msg);
            if obj.IsLive && ~isempty(obj.LiveTimer) && isvalid(obj.LiveTimer)
                try
                    start(obj.LiveTimer);
                catch restartErr
                    warning('DashboardEngine:timerRestartFailed', ...
                        '[DashboardEngine] Timer restart failed: %s', restartErr.message);
                end
            end
        end

        function onClose(obj)
            obj.stopLive();
            hf = obj.hFigure;
            obj.hFigure = [];
            if ~isempty(hf) && ishandle(hf)
                delete(hf);
            end
        end

        function reflowAfterCollapse(obj)
        %REFLOWAFTERCOLLAPSE Recompute grid layout after GroupWidget height change.
            if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
                return;
            end
            obj.rerenderWidgets();
        end

        function onFigureDestroyed_(obj)
        %ONFIGUREDESTROYED_ Safety-net handler invoked when hFigure is destroyed.
        %   Fires for ANY destruction path (delete(hf), close all force, parent
        %   teardown). The normal close-via-X path goes through CloseRequestFcn
        %   -> onClose(), which has already called stopLive() and cleared
        %   hFigure by the time we get here — both operations below are
        %   idempotent and benign in that case. Listener MUST NOT throw, so
        %   every operation is wrapped in try/catch (260511-mjb).
            try
                obj.stopLive();
            catch
                % best-effort: stopLive is already try/catch internally
            end
            try
                obj.hFigure = [];
            catch
            end
        end

    end

    methods (Static)
        function types = widgetTypes()
            %WIDGETTYPES List supported widget type strings.
            types = {
                'fastsense',    'Time-series plot (FastSenseWidget)'
                'number',      'Single numeric value with trend (NumberWidget)'
                'status',      'Status indicator with dot and label (StatusWidget)'
                'gauge',       'Gauge display in arc/donut/bar/thermometer style (GaugeWidget)'
                'table',       'Data table from sensor (TableWidget)'
                'text',        'Static text block (TextWidget)'
                'timeline',    'Event timeline display (EventTimelineWidget)'
                'rawaxes',     'Raw MATLAB axes for custom plotting (RawAxesWidget)'
                'group',       'Widget container with panel/collapsible/tabbed modes (GroupWidget)'
                'heatmap',     'Heatmap color grid (HeatmapWidget)'
                'barchart',    'Bar chart for categories (BarChartWidget)'
                'histogram',   'Value distribution histogram (HistogramWidget)'
                'scatter',     'X vs Y scatter plot (ScatterWidget)'
                'image',       'Static image display (ImageWidget)'
                'multistatus', 'Multi-sensor status grid (MultiStatusWidget)'
                'divider',     'Horizontal divider line (DividerWidget)'
            };
        end

        function obj = load(filepath, varargin)
            resolver = [];
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'SensorResolver')
                    resolver = varargin{k+1};
                end
            end

            [~, ~, ext] = fileparts(filepath);

            if strcmp(ext, '.m')
                % .m function file returns a DashboardEngine directly
                [fdir, funcname] = fileparts(filepath);
                addpath(fdir);
                cleanupPath = onCleanup(@() rmpath(fdir));
                obj = feval(funcname);
                obj.FilePath = filepath;
            else
                % JSON path
                config = DashboardSerializer.load(filepath);
                obj = DashboardEngine(config.name);
                if isfield(config, 'theme')
                    obj.Theme = config.theme;
                end
                if isfield(config, 'liveInterval')
                    obj.LiveInterval = config.liveInterval;
                end
                obj.FilePath = filepath;
                if isfield(config, 'infoFile')
                    obj.InfoFile = config.infoFile;
                end

                if isfield(config, 'pages') && ~isempty(config.pages)
                    % Multi-page JSON: reconstruct DashboardPage objects
                    for i = 1:numel(config.pages)
                        pg = DashboardPage(config.pages{i}.name);
                        pgWidgets = config.pages{i}.widgets;
                        if ~iscell(pgWidgets), pgWidgets = {}; end
                        for j = 1:numel(pgWidgets)
                            w = DashboardSerializer.createWidgetFromStruct(pgWidgets{j});
                            if ~isempty(w), pg.addWidget(w); end
                        end
                        obj.Pages{end+1} = pg;
                    end
                    % Set ActivePage to 1 so multi-page mode is enabled
                    obj.ActivePage = 1;
                    % Restore active page by name
                    if isfield(config, 'activePage') && ~isempty(config.activePage)
                        for i = 1:numel(obj.Pages)
                            if strcmp(obj.Pages{i}.Name, config.activePage)
                                obj.ActivePage = i;
                                break;
                            end
                        end
                    end
                    if obj.ActivePage == 0, obj.ActivePage = 1; end

                    % Inject ReflowCallback into all collapsible GroupWidgets on all pages
                    ws = obj.allPageWidgets();
                    for i = 1:numel(ws)
                        wi = ws{i};
                        if isa(wi, 'GroupWidget') && strcmp(wi.Mode, 'collapsible')
                            wi.ReflowCallback = @() obj.reflowAfterCollapse();
                        end
                    end
                else
                    % Legacy single-page flat widgets path
                    widgets = DashboardSerializer.configToWidgets(config, resolver);
                    for i = 1:numel(widgets)
                        w = widgets{i};
                        existingPositions = cell(1, numel(obj.Widgets));
                        for j = 1:numel(obj.Widgets)
                            existingPositions{j} = obj.Widgets{j}.Position;
                        end
                        w.Position = obj.Layout.resolveOverlap(w.Position, existingPositions);
                        obj.Widgets{end+1} = w;
                    end

                    % Inject ReflowCallback into collapsible GroupWidgets loaded from JSON
                    for i = 1:numel(obj.Widgets)
                        wi = obj.Widgets{i};
                        if isa(wi, 'GroupWidget') && strcmp(wi.Mode, 'collapsible')
                            wi.ReflowCallback = @() obj.reflowAfterCollapse();
                        end
                    end
                end
            end
        end
    end
end
