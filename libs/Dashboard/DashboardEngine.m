classdef DashboardEngine < handle
%DASHBOARDENGINE Top-level dashboard orchestrator.
%
%   Usage:
%     d = DashboardEngine('My Dashboard');
%     d.Theme = 'light';
%     d.LiveInterval = 5;
%     d.addWidget('fastsense', 'Title', 'Temp', 'Position', [1 1 6 3], ...
%                 'Sensor', SensorRegistry.get('temperature'));
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
        Name         = ''
        Theme        = 'light'
        LiveInterval = 5
        InfoFile     = ''
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
        hTimeSliderL    = []       % Left (start) slider
        hTimeSliderR    = []       % Right (end) slider
        hTimeStart      = []
        hTimeEnd        = []
        SliderDebounceTimer = []   % MATLAB timer for coalescing rapid slider events
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

            % Content area between toolbar and time panel
            obj.Layout.ContentArea = [0, obj.TimePanelHeight, ...
                1, 1 - toolbarH - pageBarH - obj.TimePanelHeight];
            obj.Layout.DetachCallback = @(w) obj.detachWidget(w);
            obj.Layout.allocatePanels(obj.hFigure, obj.activePageWidgets(), themeStruct);
            obj.Layout.OnScrollCallback = @(r1, r2) obj.onScrollRealize(r1, r2);
            obj.realizeBatch(5);

            % Pre-allocate panels for non-active pages (hidden) so switchPage is O(1) visibility toggle
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
            obj.LiveTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', obj.LiveInterval, ...
                'TimerFcn', @(~,~) obj.onLiveTick(), ...
                'ErrorFcn', @(t, e) obj.onLiveTimerError(t, e));
            start(obj.LiveTimer);
        end

        function stopLive(obj)
            if ~isempty(obj.LiveTimer)
                stop(obj.LiveTimer);
                delete(obj.LiveTimer);
                obj.LiveTimer = [];
            end
            if ~isempty(obj.SliderDebounceTimer)
                try stop(obj.SliderDebounceTimer); catch, end
                try delete(obj.SliderDebounceTimer); catch, end
                obj.SliderDebounceTimer = [];
            end
            obj.IsLive = false;
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

            stubAxes = [];
            try
                if useExportApp
                    % exportapp signature is exportapp(fig, filename) only
                    % (introduced R2024a). Resolution is implicit. Trade-off:
                    % we lose explicit 150 DPI on R2024a+ but gain working
                    % export of UI-component figures.
                    exportapp(obj.hFigure, filepath);
                elseif useExportGraphics
                    % MATLAB R2020a-R2023b headless path. exportgraphics
                    % explicitly supports -nodisplay mode (unlike print).
                    % ContentType='image' forces raster output (PNG/JPEG).
                    % Resolution=150 matches the -r150 used by the legacy
                    % print() path for visual parity.
                    exportgraphics(obj.hFigure, filepath, ...
                        'ContentType', 'image', 'Resolution', 150);
                else
                    % Octave path — preserves stub-axes behaviour (Octave's
                    % print() does not recurse into uipanels).
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
                    print(obj.hFigure, devFlag, '-r150', filepath);
                end
                if ~isempty(stubAxes) && ishandle(stubAxes); delete(stubAxes); end
            catch ME
                if ~isempty(stubAxes) && ishandle(stubAxes); delete(stubAxes); end
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
            if isempty(obj.InfoFile)
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

            % Write temp file (reuse path)
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

            % Display
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
            obj.Layout.createPanels(obj.hFigure, ws, theme);
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

            % Reset sliders to full range
            if ~isempty(obj.hTimeSliderL) && ishandle(obj.hTimeSliderL)
                set(obj.hTimeSliderL, 'Value', 0);
                set(obj.hTimeSliderR, 'Value', 1);
            end

            obj.updateTimeLabels(tMin, tMax);
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

        function updateLiveTimeRangeFrom(obj, ws)
        %UPDATELIVETIMERANGEFROM Update DataTimeRange from pre-fetched widget list.
        %   Like updateLiveTimeRange but accepts ws to avoid re-fetching activePageWidgets().
            tMin = inf; tMax = -inf;
            for i = 1:numel(ws)
                [wMin, wMax] = ws{i}.getTimeRange();
                if wMin < tMin, tMin = wMin; end
                if wMax > tMax, tMax = wMax; end
            end
            if isinf(tMin) || isinf(tMax)
                return;
            end
            obj.DataTimeRange = [tMin, tMax];
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
            for b = 1:batchSize:numel(order)
                bEnd = min(b + batchSize - 1, numel(order));
                for i = b:bEnd
                    obj.Layout.realizeWidget(ws{order(i)});
                end
                drawnow;
            end
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

            % Single pass: mark sensor-bound dirty, then refresh if dirty+realized+visible
            % (PostSet listeners on Sensor.X/Y do not fire reliably in Octave for indexed assignment)
            for i = 1:numel(ws)
                w = ws{i};
                if ~isempty(w.Sensor)
                    w.markDirty();
                end
                if w.Dirty && w.Realized && obj.Layout.isWidgetVisible(w.Position)
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

            % Re-apply current slider positions to the updated time range
            % Use direct broadcastTimeRange (not debounced) since live tick is already rate-limited
            if ~isempty(obj.hTimeSliderL) && ishandle(obj.hTimeSliderL)
                valL = get(obj.hTimeSliderL, 'Value');
                valR = get(obj.hTimeSliderR, 'Value');
                tr = obj.DataTimeRange;
                span = tr(2) - tr(1);
                tStart = tr(1) + valL * span;
                tEnd   = tr(1) + valR * span;
                obj.broadcastTimeRange(tStart, tEnd);
            end

            % Clear dirty flags AFTER slider broadcast to avoid re-dirtying
            for i = 1:numel(ws)
                ws{i}.Dirty = false;
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
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                obj.repositionPanels();
            end
        end

        function delete(obj)
            if ~isempty(obj.SliderDebounceTimer)
                try stop(obj.SliderDebounceTimer); catch, end
                try delete(obj.SliderDebounceTimer); catch, end
                obj.SliderDebounceTimer = [];
            end
            obj.stopLive();
            obj.cleanupInfoTempFile();
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
        %   sensor PostSet events mark widgets dirty regardless of page routing.
            if ~isempty(w.Sensor) && isprop(w.Sensor, 'X')
                try
                    addlistener(w.Sensor, 'X', 'PostSet', @(~,~) w.markDirty());
                catch
                    % Octave may not support addlistener on all property types
                end
                try
                    addlistener(w.Sensor, 'Y', 'PostSet', @(~,~) w.markDirty());
                catch
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

            % Simple uipanel + dual sliders. NavigatorOverlay doesn't
            % work reliably in dashboard context (axes interaction
            % handlers, z-order, uipanel isolation). Sliders just work.
            obj.hTimePanel = uipanel('Parent', obj.hFigure, ...
                'Units', 'normalized', ...
                'Position', [0, 0, 1, tH], ...
                'BorderType', 'line', ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'ForegroundColor', theme.WidgetBorderColor);

            % Start time label
            obj.hTimeStart = uicontrol('Parent', obj.hTimePanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.005 0.55 0.12 0.4], ...
                'String', '', ...
                'FontSize', 9, ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left');

            % End time label
            obj.hTimeEnd = uicontrol('Parent', obj.hTimePanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.88 0.55 0.115 0.4], ...
                'String', '', ...
                'FontSize', 9, ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'right');

            % "From" / "To" labels
            uicontrol('Parent', obj.hTimePanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.005 0.05 0.04 0.45], ...
                'String', 'From:', ...
                'FontSize', 8, ...
                'ForegroundColor', theme.ToolbarFontColor * 0.7 + ...
                    theme.ToolbarBackground * 0.3, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left');

            uicontrol('Parent', obj.hTimePanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.50 0.05 0.03 0.45], ...
                'String', 'To:', ...
                'FontSize', 8, ...
                'ForegroundColor', theme.ToolbarFontColor * 0.7 + ...
                    theme.ToolbarBackground * 0.3, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left');

            % Left slider (range start): 0 = data start, 1 = data end
            obj.hTimeSliderL = uicontrol('Parent', obj.hTimePanel, ...
                'Style', 'slider', ...
                'Units', 'normalized', ...
                'Position', [0.045 0.1 0.45 0.42], ...
                'Min', 0, 'Max', 1, 'Value', 0, ...
                'SliderStep', [0.01 0.1], ...
                'Callback', @(src,~) obj.onTimeSlidersChanged());

            % Right slider (range end): 0 = data start, 1 = data end
            obj.hTimeSliderR = uicontrol('Parent', obj.hTimePanel, ...
                'Style', 'slider', ...
                'Units', 'normalized', ...
                'Position', [0.535 0.1 0.45 0.42], ...
                'Min', 0, 'Max', 1, 'Value', 1, ...
                'SliderStep', [0.01 0.1], ...
                'Callback', @(src,~) obj.onTimeSlidersChanged());
        end

        function onTimeSlidersChanged(obj)
            valL = get(obj.hTimeSliderL, 'Value');
            valR = get(obj.hTimeSliderR, 'Value');

            % Enforce left < right
            if valL >= valR
                valR = min(1, valL + 0.01);
                if valL >= valR
                    valL = valR - 0.01;
                    set(obj.hTimeSliderL, 'Value', valL);
                end
                set(obj.hTimeSliderR, 'Value', valR);
            end

            tr = obj.DataTimeRange;
            span = tr(2) - tr(1);
            tStart = tr(1) + valL * span;
            tEnd   = tr(1) + valR * span;

            % Update labels immediately for visual feedback
            obj.updateTimeLabels(tStart, tEnd);

            % Debounce the expensive broadcastTimeRange — coalesce rapid slider events
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
            if isempty(obj.hTimeStart), return; end
            set(obj.hTimeStart, 'String', obj.formatTimeVal(tStart));
            set(obj.hTimeEnd, 'String', obj.formatTimeVal(tEnd));
        end

        function str = formatTimeVal(~, t)
            % Detect datenum (modern dates are > 700000)
            if t > 700000
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
