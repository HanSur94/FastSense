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
        hFigure        = []
        Layout         = []
        Toolbar        = []
        LiveTimer      = []
        IsLive         = false
        LastUpdateTime = []
        FilePath       = ''
        InfoTempFile   = ''
        % Time control
        TimePanelHeight = 0.06
        DataTimeRange   = [0 1]    % [tMin tMax] across all widget data
        hTimePanel      = []
        hTimeSliderL    = []       % Left (start) slider
        hTimeSliderR    = []       % Right (end) slider
        hTimeStart      = []
        hTimeEnd        = []
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
        end

        function addWidget(obj, type, varargin)
            switch type
                case 'fastsense'
                    w = FastSenseWidget(varargin{:});
                case 'number'
                    w = NumberWidget(varargin{:});
                case 'kpi'
                    warning('DashboardEngine:deprecated', ...
                        '''kpi'' type is deprecated, use ''number'' instead.');
                    w = NumberWidget(varargin{:});
                case 'status'
                    w = StatusWidget(varargin{:});
                case 'text'
                    w = TextWidget(varargin{:});
                case 'gauge'
                    w = GaugeWidget(varargin{:});
                case 'table'
                    w = TableWidget(varargin{:});
                case 'rawaxes'
                    w = RawAxesWidget(varargin{:});
                case 'timeline'
                    w = EventTimelineWidget(varargin{:});
                    if isempty(w.EventStoreObj) && isempty(w.EventFcn) && isempty(w.Events)
                        warning('DashboardEngine:timelineNoStore', ...
                            'Timeline widget "%s" has no data source. Bind via EventStoreObj.', ...
                            w.Title);
                    end
                otherwise
                    error('DashboardEngine:unknownType', ...
                        'Unknown widget type: %s', type);
            end

            existingPositions = cell(1, numel(obj.Widgets));
            for i = 1:numel(obj.Widgets)
                existingPositions{i} = obj.Widgets{i}.Position;
            end
            w.Position = obj.Layout.resolveOverlap(w.Position, existingPositions);

            obj.Widgets{end+1} = w;
        end

        function render(obj)
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                return;
            end

            themeStruct = DashboardTheme(obj.Theme);

            obj.hFigure = figure('Name', obj.Name, ...
                'NumberTitle', 'off', ...
                'Color', themeStruct.DashboardBackground, ...
                'Units', 'normalized', ...
                'OuterPosition', [0.05 0.05 0.9 0.9], ...
                'CloseRequestFcn', @(~,~) obj.onClose());

            obj.Toolbar = DashboardToolbar(obj, obj.hFigure, themeStruct);

            % Create time control panel at bottom
            obj.createTimePanel(themeStruct);

            % Content area between toolbar and time panel
            toolbarH = obj.Toolbar.Height;
            obj.Layout.ContentArea = [0, obj.TimePanelHeight, ...
                1, 1 - toolbarH - obj.TimePanelHeight];
            obj.Layout.createPanels(obj.hFigure, obj.Widgets, themeStruct);

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
                'TimerFcn', @(~,~) obj.onLiveTick());
            start(obj.LiveTimer);
        end

        function stopLive(obj)
            if ~isempty(obj.LiveTimer)
                stop(obj.LiveTimer);
                delete(obj.LiveTimer);
                obj.LiveTimer = [];
            end
            obj.IsLive = false;
        end

        function save(obj, filepath)
            config = DashboardSerializer.widgetsToConfig( ...
                obj.Name, obj.Theme, obj.LiveInterval, obj.Widgets, obj.InfoFile);
            DashboardSerializer.save(config, filepath);
            obj.FilePath = filepath;
        end

        function exportScript(obj, filepath)
            config = DashboardSerializer.widgetsToConfig( ...
                obj.Name, obj.Theme, obj.LiveInterval, obj.Widgets, obj.InfoFile);
            DashboardSerializer.exportScript(config, filepath);
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
            if idx >= 1 && idx <= numel(obj.Widgets)
                w = obj.Widgets{idx};
                obj.Widgets(idx) = [];
                delete(w);
                if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                    obj.rerenderWidgets();
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

        function setContentArea(obj, contentArea)
        %SETCONTENTAREA Update the Layout content area.
        %   Provided so that DashboardBuilder can modify the layout
        %   without direct write-access to the Layout property (required
        %   for Octave compatibility).
            obj.Layout.ContentArea = contentArea;
        end

        function rerenderWidgets(obj)
        %RERENDERWIDGETS Delete all widget panels and recreate them.
            theme = DashboardTheme(obj.Theme);
            for i = 1:numel(obj.Widgets)
                w = obj.Widgets{i};
                if ~isempty(w.hPanel) && ishandle(w.hPanel)
                    delete(w.hPanel);
                end
            end
            obj.Layout.createPanels(obj.hFigure, obj.Widgets, theme);
        end

        function updateGlobalTimeRange(obj)
        %UPDATEGLOBALTIMERANGE Scan all widgets for data time bounds.
            tMin = inf; tMax = -inf;
            for i = 1:numel(obj.Widgets)
                [wMin, wMax] = obj.Widgets{i}.getTimeRange();
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
            for i = 1:numel(obj.Widgets)
                [wMin, wMax] = obj.Widgets{i}.getTimeRange();
                if wMin < tMin, tMin = wMin; end
                if wMax > tMax, tMax = wMax; end
            end
            if isinf(tMin) || isinf(tMax)
                return;  % no widgets report time data
            end
            obj.DataTimeRange = [tMin, tMax];
        end

        function broadcastTimeRange(obj, tStart, tEnd)
        %BROADCASTTIMERANGE Push time range to widgets using global time.
            for i = 1:numel(obj.Widgets)
                try
                    obj.Widgets{i}.setTimeRange(tStart, tEnd);
                catch ME
                    warning('DashboardEngine:timeRangeError', ...
                        'Widget "%s" setTimeRange failed: %s', ...
                        obj.Widgets{i}.Title, ME.message);
                end
            end
        end

        function resetGlobalTime(obj)
        %RESETGLOBALTIME Re-attach all widgets to global time and apply.
            for i = 1:numel(obj.Widgets)
                obj.Widgets{i}.UseGlobalTime = true;
            end
            obj.onTimeSlidersChanged();
        end

        function delete(obj)
            obj.stopLive();
            obj.cleanupInfoTempFile();
        end
    end

    methods (Access = private)
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

            obj.broadcastTimeRange(tStart, tEnd);
            obj.updateTimeLabels(tStart, tEnd);
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

        function onClose(obj)
            obj.stopLive();
            hf = obj.hFigure;
            obj.hFigure = [];
            if ~isempty(hf) && ishandle(hf)
                delete(hf);
            end
        end

        function onLiveTick(obj)
            if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
                return;
            end

            % Update global time range from live data
            obj.updateLiveTimeRange();

            for i = 1:numel(obj.Widgets)
                try
                    obj.Widgets{i}.refresh();
                catch ME
                    warning('DashboardEngine:refreshError', ...
                        'Widget "%s" refresh failed: %s', ...
                        obj.Widgets{i}.Title, ME.message);
                end
            end
            obj.LastUpdateTime = now;
            if ~isempty(obj.Toolbar)
                obj.Toolbar.setLastUpdateTime(obj.LastUpdateTime);
            end

            % Re-apply current slider positions to the updated time range
            if ~isempty(obj.hTimeSliderL) && ishandle(obj.hTimeSliderL)
                obj.onTimeSlidersChanged();
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
            };
        end

        function obj = load(filepath, varargin)
            resolver = [];
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'SensorResolver')
                    resolver = varargin{k+1};
                end
            end

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
        end
    end
end
