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
        DetachedMirrors = {}   % Cell array of DetachedMirror objects
        % Theme caching
        ThemeCache_        = []  % Cached DashboardTheme struct; lazy-computed by getCachedTheme()
        ThemeCachePreset_  = ''  % Theme preset string that ThemeCache_ was built for
        % Widget dispatch table
        WidgetTypeMap_     = []  % containers.Map: type string -> constructor function handle
        % Time control
        TimePanelHeight = 0.06
        DataTimeRange   = [0 1]    % [tMin tMax] across all widget data
        hTimePanel      = []
        hTimeSliderL    = []       % Shim handle — points at TimeRangeSelector_ (D-10)
        hTimeSliderR    = []       % Shim handle — points at TimeRangeSelector_ (D-10)
        hTimeStart      = []
        hTimeEnd        = []
        SliderDebounceTimer = []   % MATLAB timer for coalescing rapid slider events
        TimeRangeSelector_  = []   % TimeRangeSelector handle (replaces dual sliders)
        Progress_           = []   % DashboardProgress instance (active during render)
        % Stale-data banner (shown during live mode when a widget's tMax stops advancing)
        hStaleBanner         = []  % uipanel overlay; hidden unless live+stale+!dismissed
        hStaleBannerText     = []  % uicontrol text child of hStaleBanner
        hStaleBannerClose    = []  % uicontrol 'X' pushbutton child of hStaleBanner
        LastTMaxPerWidget_   = []  % containers.Map: widget title -> last observed tMax
        StaleBannerDismissed_ = false  % true after user clicks X; reset when data flows again
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
            try obj.computePreviewEnvelope(); catch, end
        end

        function switchPage(obj, pageIdx)
        %SWITCHPAGE Switch the active page using panel visibility toggling.
        %   d.switchPage(2) sets ActivePage = 2 and toggles panel visibility.
            if pageIdx < 1 || pageIdx > numel(obj.Pages)
                return;
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
                        if ~isempty(pgWidgets{wi}.hPanel) && ishandle(pgWidgets{wi}.hPanel)
                            if pgIdx == obj.ActivePage
                                set(pgWidgets{wi}.hPanel, 'Visible', 'on');
                            else
                                set(pgWidgets{wi}.hPanel, 'Visible', 'off');
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
            % Refresh the preview envelope on the newly active page (D-07).
            try obj.computePreviewEnvelope(); catch, end
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
            set(obj.hFigure, 'ResizeFcn', @(~,~) obj.onResize());

            obj.Toolbar = DashboardToolbar(obj, obj.hFigure, themeStruct);

            % Create PageBar for multi-page dashboards
            toolbarH = obj.Toolbar.Height;
            if numel(obj.Pages) > 1
                obj.renderPageBar(themeStruct);
                pageBarH = obj.PageBarHeight;
            else
                % Create hidden PageBar placeholder so hPageBar is always valid
                obj.hPageBar = uipanel('Parent', obj.hFigure, ...
                    'Units', 'normalized', ...
                    'Position', [0, 1 - toolbarH - obj.PageBarHeight, 1, obj.PageBarHeight], ...
                    'BorderType', 'none', ...
                    'BackgroundColor', themeStruct.ToolbarBackground, ...
                    'Visible', 'off');
                pageBarH = 0;
            end

            % Create time control panel at bottom
            obj.createTimePanel(themeStruct);

            % Create the stale-data banner (hidden by default; toggled by live tick)
            obj.createStaleBanner(themeStruct, toolbarH);

            % Apply visibility flags + compute content area based on effective heights
            [effToolbarH, effPageBarH, effTimeH] = obj.applyChromeVisibility(toolbarH, pageBarH);
            obj.Layout.ContentArea = [0, effTimeH, ...
                1, 1 - effToolbarH - effPageBarH - effTimeH];
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
                    % Hide panels for non-active pages
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
                web(obj.InfoTempFile, '-new');
            end
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
            obj.Layout.ContentArea = [0, effTimeH, ...
                1, 1 - effToolbarH - effPageBarH - effTimeH];
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

            % Page bar (visible or placeholder)
            if ~isempty(obj.hPageBar) && ishandle(obj.hPageBar)
                set(obj.hPageBar, 'BackgroundColor', theme.ToolbarBackground);
            end
        end

        function rerenderWidgets(obj)
        %RERENDERWIDGETS Delete all widget panels and recreate them.
            theme = obj.getCachedTheme();
            ws = obj.activePageWidgets();
            for i = 1:numel(ws)
                w = ws{i};
                w.markUnrealized();
                if ~isempty(w.hPanel) && ishandle(w.hPanel)
                    delete(w.hPanel);
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
            try obj.computePreviewEnvelope(); catch, end
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

        function createStaleBanner(obj, theme, toolbarH)
        %CREATESTALEBANNER Create the hidden stale-data warning banner overlay.
        %   A uipanel strip below the toolbar containing a message label and
        %   a close button. Hidden by default; shown when staleness is detected
        %   and not previously dismissed by the user.
            if ~isempty(obj.hStaleBanner) && ishandle(obj.hStaleBanner)
                return;
            end
            bannerH = 0.035;
            warnColor = theme.StatusWarnColor;
            fgColor   = [0.15 0.10 0.02];

            obj.hStaleBanner = uipanel('Parent', obj.hFigure, ...
                'Units', 'normalized', ...
                'Position', [0, 1 - toolbarH - bannerH, 1, bannerH], ...
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
            set(obj.hStaleBanner, 'Visible', 'on');
            % Widget panels are created after the banner, so they render on top
            % by default. Raise the banner to the front so it is actually seen.
            try
                uistack(obj.hStaleBanner, 'top');
            catch
                % uistack is MATLAB-only; Octave's renderer handles z-order differently.
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
        %BROADCASTTIMERANGE Push time range to widgets using global time.
            ws = obj.activePageWidgets();
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
        %RESETGLOBALTIME Re-attach all widgets to global time and apply.
            ws = obj.activePageWidgets();
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
                obj.broadcastTimeRange(tStart, tEnd);
            end

            % Clear dirty flags AFTER slider broadcast to avoid re-dirtying
            for i = 1:numel(ws)
                ws{i}.Dirty = false;
            end
            % Refresh the preview envelope on every live tick (D-07).
            try obj.computePreviewEnvelope(); catch, end
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
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                obj.repositionPanels();
            end
        end

        function delete(obj)
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
            obj.stopLive();
            obj.cleanupInfoTempFile();
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
    end

    methods (Access = private)

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
        %   Used for ReflowCallback injection. When Pages is empty, returns obj.Widgets.
            if isempty(obj.Pages)
                ws = obj.Widgets;
                return;
            end
            ws = {};
            for i = 1:numel(obj.Pages)
                ws = [ws, obj.Pages{i}.Widgets]; %#ok<AGROW>
            end
        end

        function renderPageBar(obj, themeStruct)
        %RENDERPAGEBAR Create the PageBar uipanel with one button per page.
        %   Called from render() when numel(Pages) > 1.
            toolbarH = obj.Toolbar.Height;
            hPageBar = uipanel('Parent', obj.hFigure, ...
                'Units', 'normalized', ...
                'Position', [0, 1 - toolbarH - obj.PageBarHeight, 1, obj.PageBarHeight], ...
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
            uicontrol('Parent', obj.hTimePanel, ...
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
                'TimerFcn', @(~,~) obj.broadcastTimeRange(tStart, tEnd));
            start(obj.SliderDebounceTimer);
        end

        function updateTimeLabels(obj, tStart, tEnd)
            if isempty(obj.TimeRangeSelector_) || ...
                    ~isa(obj.TimeRangeSelector_, 'TimeRangeSelector')
                return;
            end
            obj.TimeRangeSelector_.setLabels( ...
                obj.formatTimeVal(tStart), ...
                obj.formatTimeVal(tEnd));
        end

        function computePreviewEnvelope(obj, nBuckets)
        %COMPUTEPREVIEWENVELOPE Aggregate per-bucket min/max across
        %   active-page widgets and push the result onto the selector's
        %   envelope patch (D-07, D-08). nBuckets optional; when omitted,
        %   defaults to ~200 based on panel axes pixel width, clamped to
        %   [50, 400]. Silently no-ops when no selector is wired yet (e.g.
        %   before render()).
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
            end
            ws = obj.activePageWidgets();
            if isempty(ws)
                obj.TimeRangeSelector_.setPreviewLines({});
                env = struct('xCenters', [], 'yMin', [], 'yMax', []);
                return;
            end
            aggMin = inf(1, nBuckets);
            aggMax = -inf(1, nBuckets);
            xCenters = [];
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
                if numel(s.yMin) ~= nBuckets || numel(s.yMax) ~= nBuckets
                    continue;
                end
                if isempty(xCenters), xCenters = s.xCenters; end
                % Aggregate min/max kept so computePreviewEnvelopeForTest
                % can still return an envelope struct for existing tests.
                aggMin = min(aggMin, s.yMin);
                aggMax = max(aggMax, s.yMax);
                % Per-widget line: midpoint of bucket, already normalized
                % to [0,1] by the widget (D-08).
                yMid = (s.yMin + s.yMax) / 2;
                linesList{end + 1} = struct('x', s.xCenters, 'y', yMid); %#ok<AGROW>
            end
            if isempty(xCenters) || ~any(isfinite(aggMin))
                obj.TimeRangeSelector_.setPreviewLines({});
                env = struct('xCenters', [], 'yMin', [], 'yMax', []);
                return;
            end
            aggMin(~isfinite(aggMin)) = 0;
            aggMax(~isfinite(aggMax)) = 0;
            obj.TimeRangeSelector_.setPreviewLines(linesList);
            env = struct('xCenters', xCenters, 'yMin', aggMin, 'yMax', aggMax);
        end

    end

    methods (Access = public)

        function str = formatTimeVal(~, t)
        %FORMATTIMEVAL Format a numeric time value as a human-readable string.
        %   Supports three numeric ranges:
        %     posix epoch seconds (9e8 < t < 5e9) — converts via datenum(1970,...)+t/86400
        %     MATLAB datenum (t > 700000, not posix) — uses datestr directly
        %     raw numeric (t <= 700000) — formats as s/m/h/d suffix
        %
        %   The posix bracket is evaluated BEFORE the datenum bracket because
        %   posix seconds for modern dates (year 2001-2128) are also > 700000
        %   and would be wrongly interpreted as datenums without this ordering.
            % Order matters: posix epoch seconds (year 2000-2128) are > 700000,
            % so the posix bracket must be evaluated BEFORE the datenum bracket.
            if t > 9e8 && t < 5e9
                % Posix epoch seconds (year ~2000 - 2128)
                str = datestr(datenum(1970, 1, 1, 0, 0, 0) + t / 86400, ...
                              'yyyy-mm-dd HH:MM');
            elseif t > 700000
                % MATLAB datenum (days since year 0000)
                if t > 730000
                    str = datestr(t, 'yyyy-mm-dd HH:MM');
                else
                    str = datestr(t, 'HH:MM:SS');
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
