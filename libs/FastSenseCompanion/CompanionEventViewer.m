classdef CompanionEventViewer < handle
%COMPANIONEVENTVIEWER Pop-out classic-figure viewer: tag-aware, time-filtered Gantt of EventStore events.
%
%   v = CompanionEventViewer(store, registry, companion)
%     store      — EventStore handle (required)
%     registry   — TagRegistry handle/class (required, for tag-key search)
%     companion  — FastSenseCompanion handle (required, for theme + LiveModeChanged)
%
%   Public:
%     v.refresh()                    — pull from store, redraw Gantt (Task 9)
%     v.setTimeRange(tStart, tEnd)   — programmatic; sets mode to 'custom' (Task 8)
%     v.setTagFilter(keysCell)       — {} / '' means "all tags" (Task 8)
%     v.bringToFront()               — figure(hFigure)
%     v.close()                      — idempotent teardown
%
%   See also EventGanttCanvas, FastSenseCompanion.

    properties (SetAccess = private)
        hFigure
        SelectedTagKeys = {}
        SeverityMask    = [true true true]
        OpenOnly        = false
        TimeRange       = [0 1]
        TimePresetMode  = 'snapshot'   % 'roll' | 'snapshot' | 'custom'
        IsLive          = false
    end

    properties (Access = public)
        LeftPaneWidth = 260   % Width of the tag-catalog pane in pixels.
    end

    properties (Access = private)
        Store_       = []
        Registry_    = []
        Companion_   = []
        Theme_       = []
        Canvas_      = []
        Selector_    = []
        FilterPanel_ = []
        AxesPanel_   = []
        SliderPanel_ = []
        AutoTimer_   = []
        AutoPeriod_  = 1.0
        AutoEnabled_ = true
        Listeners_   = {}
        RootGrid_    = []   % 1x2 uigridlayout: [left pane | right column]
        RightGrid_   = []   % 3x1 uigridlayout: [filter bar; gantt; slider]
        LeftPanel_   = []   % uipanel hosting the TagCatalogPane
    end

    methods
        function obj = CompanionEventViewer(store, registry, companion)
        %COMPANIONEVENTVIEWER Construct the viewer window.
        %   store      — EventStore handle (required)
        %   registry   — TagRegistry handle/class (required)
        %   companion  — FastSenseCompanion handle (required)
            if isempty(store) || ~isa(store, 'EventStore')
                error('CompanionEventViewer:invalidStore', ...
                    'store must be an EventStore handle.');
            end
            if isempty(registry)
                error('CompanionEventViewer:invalidRegistry', ...
                    'registry must be a TagRegistry handle.');
            end
            if isempty(companion) || ~isa(companion, 'FastSenseCompanion')
                error('CompanionEventViewer:invalidCompanion', ...
                    'companion must be a FastSenseCompanion handle.');
            end
            obj.Store_      = store;
            obj.Registry_   = registry;
            obj.Companion_  = companion;
            obj.Theme_      = CompanionTheme.get(companion.Theme);
            obj.IsLive      = companion.IsLive;
            obj.AutoPeriod_ = companion.LivePeriod;

            obj.buildFigure_();
        end

        function bringToFront(obj)
        %BRINGTTOFRONT Raise the viewer figure. No-op if figure is gone.
            if ~isempty(obj.hFigure) && isgraphics(obj.hFigure)
                figure(obj.hFigure);
            end
        end

        function setTimeRange(obj, tStart, tEnd)
        %SETTIMERANGE Set an explicit time range; switches mode to 'custom'.
        %   setTimeRange(tStart, tEnd) — both numeric scalars, tEnd > tStart.
            if ~isnumeric(tStart) || ~isnumeric(tEnd) || ~isscalar(tStart) || ~isscalar(tEnd)
                error('CompanionEventViewer:invalidTimeRange', ...
                    'setTimeRange requires two numeric scalars.');
            end
            if ~(tEnd > tStart)
                error('CompanionEventViewer:invalidTimeRange', ...
                    'setTimeRange requires tEnd > tStart (got [%g %g]).', tStart, tEnd);
            end
            obj.TimeRange      = [tStart tEnd];
            obj.TimePresetMode = 'custom';
        end

        function setTagFilter(obj, keysCell)
        %SETTAGFILTER Set the tag key filter. {} / '' means "all tags".
            if isempty(keysCell)
                obj.SelectedTagKeys = {};
                return;
            end
            if ~iscellstr(keysCell) %#ok<ISCLSTR>
                if ischar(keysCell)
                    keysCell = {keysCell};
                else
                    error('CompanionEventViewer:invalidTagFilter', ...
                        'setTagFilter requires cellstr or char.');
                end
            end
            obj.SelectedTagKeys = keysCell(:)';
        end

        function applyPreset_internalForTest(obj, name)
        %APPLYPRESET_INTERNALFORTEST Test-only proxy for the preset handler.
            obj.applyPreset_(name);
        end

        function refresh(obj)
        %REFRESH Pull from store, apply filters, redraw Gantt + slider. No-op if figure gone.
            if isempty(obj.hFigure) || ~isgraphics(obj.hFigure); return; end
            evs = obj.Store_.getEvents();
            if isempty(evs); evs = Event.empty; end
            filtered = CompanionEventViewer.applyFilters( ...
                evs, obj.SelectedTagKeys, obj.SeverityMask, obj.OpenOnly, obj.TimeRange);
            obj.Canvas_.draw(filtered, obj.Theme_);
            obj.updateSliderPreview_(evs);
        end

        function c = getCanvasForTest_(obj)
        %GETCANVASFORTEST_ Test-only accessor for the canvas helper.
            c = obj.Canvas_;
        end

        function setSingleClickHandlerForTest_(obj, fn)
        %SETSINGLECLICKHANDLERFORTEST_ Override OnSingleClick for testing.
            obj.Canvas_.OnSingleClick = fn;
        end

        function setDoubleClickHandlerForTest_(obj, fn)
        %SETDOUBLECLICKHANDLERFORTEST_ Override OnDoubleClick for testing.
            obj.Canvas_.OnDoubleClick = fn;
        end

        function fireBarClickForTest_(obj, idx, selType)
        %FIREBARCLICKFORTEST_ Simulate a bar click without GUI.
            ev = obj.Canvas_.BarEvents(idx);
            if strcmp(selType, 'open')
                if ~isempty(obj.Canvas_.OnDoubleClick)
                    obj.Canvas_.OnDoubleClick(ev);
                end
            else
                if ~isempty(obj.Canvas_.OnSingleClick)
                    obj.Canvas_.OnSingleClick(ev);
                end
            end
        end

        function tf = isAutoTimerRunning_(obj)
        %ISAUTOTIMERRUNNING_ Test accessor: true if the auto-refresh timer is running.
            tf = ~isempty(obj.AutoTimer_) && isvalid(obj.AutoTimer_) && ...
                strcmp(obj.AutoTimer_.Running, 'on');
        end

        function t = getAutoTimerForTest_(obj)
        %GETAUTOTIMERFORTEST_ Test accessor: return AutoTimer_ handle (may be []).
            t = obj.AutoTimer_;
        end

        function s = getSliderForTest_(obj)
        %GETSLIDERFORTEST_ Test accessor: return Selector_ handle.
            s = obj.Selector_;
        end

        function onSliderRangeChanged_internalForTest(obj, t1, t2)
        %ONSLIDERRANGECHANGED_INTERNALFORTEST Test-only proxy for the slider callback.
            obj.onSliderRangeChanged_(t1, t2);
        end

        function close(obj)
        %CLOSE Idempotent teardown: timer, listeners, canvas, figure.
            if isempty(obj.hFigure) || ~isgraphics(obj.hFigure)
                obj.hFigure = [];
                return;
            end
            try
                if ~isempty(obj.AutoTimer_) && isvalid(obj.AutoTimer_)
                    if strcmp(obj.AutoTimer_.Running, 'on'); stop(obj.AutoTimer_); end
                    delete(obj.AutoTimer_);
                end
            catch
            end
            obj.AutoTimer_ = [];
            for i = 1:numel(obj.Listeners_)
                try; delete(obj.Listeners_{i}); catch; end
            end
            obj.Listeners_ = {};
            try
                if ~isempty(obj.Canvas_) && isvalid(obj.Canvas_)
                    delete(obj.Canvas_);
                end
            catch
            end
            obj.Canvas_ = [];
            try
                if ~isempty(obj.Selector_) && isvalid(obj.Selector_)
                    delete(obj.Selector_);
                end
            catch
            end
            obj.Selector_ = [];
            try; delete(obj.hFigure); catch; end
            obj.hFigure = [];
        end
    end

    methods (Static)
        function out = applyFilters(events, tagKeys, sevMask, openOnly, timeRange)
        %APPLYFILTERS Pure filter pipeline. Inputs:
        %   events    — Event row vector
        %   tagKeys   — cellstr, {} means "all"
        %   sevMask   — 1x3 logical [info warn alarm]
        %   openOnly  — logical scalar
        %   timeRange — 1x2 [tStart tEnd]; tEnd=Inf is acceptable
        %
        %   Open events (IsOpen=true) treat EndTime as Inf for overlap.
            if isempty(events)
                out = Event.empty; return;
            end
            keep = true(1, numel(events));
            nowRef = now;
            for i = 1:numel(events)
                ev = events(i);
                if ~isempty(tagKeys)
                    if ~any(ismember(ev.TagKeys, tagKeys))
                        keep(i) = false; continue;
                    end
                end
                sev = double(ev.Severity);
                if sev < 1 || sev > numel(sevMask) || ~sevMask(sev)
                    keep(i) = false; continue;
                end
                if openOnly && ~ev.IsOpen
                    keep(i) = false; continue;
                end
                evEnd = ev.EndTime;
                if isnan(evEnd) || ev.IsOpen
                    evEnd = max(nowRef, ev.StartTime);
                end
                if evEnd < timeRange(1) || ev.StartTime > timeRange(2)
                    keep(i) = false; continue;
                end
            end
            out = events(keep);
        end
    end

    methods (Access = private)
        function applyPreset_(obj, name)
        %APPLYPRESET_ Set TimeRange + TimePresetMode for a named preset.
        %   Presets: '1h', '24h', '7d', 'all'.
        %   'all' resolves min-start to max-end across the store events.
            switch name
                case '1h',           span = 1/24;
                case '24h',          span = 1;
                case '7d',           span = 7;
                case {'all', 'All'}, span = [];   % full extent — resolved below
                otherwise
                    error('CompanionEventViewer:unknownPreset', ...
                        'Unknown preset ''%s''.', name);
            end
            if isempty(span)
                evs = obj.Store_.getEvents();
                if isempty(evs)
                    obj.TimeRange = [now-1, now];
                else
                    starts = arrayfun(@(e) e.StartTime, evs);
                    nowRef = now;
                    ends   = arrayfun(@(e) EventGanttCanvas.eventEndOrNow(e, nowRef), evs);
                    obj.TimeRange = [min(starts), max(nowRef, max(ends))];
                end
            else
                obj.TimeRange = [now - span, now];
            end
            if obj.IsLive
                obj.TimePresetMode = 'roll';
            else
                obj.TimePresetMode = 'snapshot';
            end
            obj.refresh();
        end

        function buildFigure_(obj)
        %BUILDFIGURE_ Create the uifigure with three uipanels + Gantt axes.
            t = obj.Theme_;
            obj.hFigure = uifigure( ...
                'Name',            'FastSense — Event Viewer', ...
                'Color',           t.DashboardBackground, ...
                'Position',        [120 120 1100 600], ...
                'CloseRequestFcn', @(~,~) obj.close(), ...
                'Visible',         'on');

            % Root layout: 1x2 (left tag pane | right column).
            obj.RootGrid_ = uigridlayout(obj.hFigure, [1 2]);
            obj.RootGrid_.ColumnWidth     = {obj.LeftPaneWidth, '1x'};
            obj.RootGrid_.RowHeight       = {'1x'};
            obj.RootGrid_.Padding         = [0 0 0 0];
            obj.RootGrid_.ColumnSpacing   = 0;
            obj.RootGrid_.BackgroundColor = t.DashboardBackground;

            % Left column: uipanel host for TagCatalogPane (attached in Task 5).
            obj.LeftPanel_ = uipanel(obj.RootGrid_);
            obj.LeftPanel_.Layout.Row    = 1;
            obj.LeftPanel_.Layout.Column = 1;
            obj.LeftPanel_.BackgroundColor = t.WidgetBackground;
            obj.LeftPanel_.BorderType      = 'none';

            % Right column: 3-row nested grid (filter bar | gantt | slider).
            obj.RightGrid_ = uigridlayout(obj.RootGrid_, [3 1]);
            obj.RightGrid_.Layout.Row    = 1;
            obj.RightGrid_.Layout.Column = 2;
            obj.RightGrid_.RowHeight     = {60, '1x', 80};
            obj.RightGrid_.ColumnWidth   = {'1x'};
            obj.RightGrid_.Padding       = [0 0 0 0];
            obj.RightGrid_.RowSpacing    = 0;
            obj.RightGrid_.BackgroundColor = t.DashboardBackground;

            obj.FilterPanel_ = uipanel(obj.RightGrid_);
            obj.FilterPanel_.Layout.Row      = 1;
            obj.FilterPanel_.Layout.Column   = 1;
            obj.FilterPanel_.BackgroundColor = t.WidgetBackground;
            obj.FilterPanel_.BorderType      = 'none';

            obj.AxesPanel_ = uipanel(obj.RightGrid_);
            obj.AxesPanel_.Layout.Row      = 2;
            obj.AxesPanel_.Layout.Column   = 1;
            obj.AxesPanel_.BackgroundColor = t.WidgetBackground;
            obj.AxesPanel_.BorderType      = 'none';

            obj.SliderPanel_ = uipanel(obj.RightGrid_);
            obj.SliderPanel_.Layout.Row      = 3;
            obj.SliderPanel_.Layout.Column   = 1;
            obj.SliderPanel_.BackgroundColor = t.WidgetBackground;
            obj.SliderPanel_.BorderType      = 'none';

            % Wider left margin so long tag keys (e.g. feedline.pressure.high) fit.
            ax = axes('Parent', obj.AxesPanel_, ...
                'Units',    'normalized', ...
                'Position', [0.18 0.10 0.78 0.85], ...
                'Color',    t.WidgetBackground, ...
                'XColor',   t.ForegroundColor, ...
                'YColor',   t.ForegroundColor);
            obj.Canvas_ = EventGanttCanvas(ax, t);
            obj.Canvas_.OnSingleClick = @(ev) obj.onEventSingleClick_(ev);
            obj.Canvas_.OnDoubleClick = @(ev) obj.onEventDoubleClick_(ev);

            % --- Filter bar contents -----------------------------------
            % Preset buttons row.
            presets       = {'1h', '24h', '7d', 'All'};
            presetTooltips = { ...
                'Show events from the last hour', ...
                'Show events from the last 24 hours', ...
                'Show events from the last 7 days', ...
                'Show all events on record'};
            for i = 1:numel(presets)
                uicontrol('Parent', obj.FilterPanel_, ...
                    'Style', 'pushbutton', 'String', presets{i}, ...
                    'Tag', 'PresetBtn', ...
                    'Units', 'normalized', ...
                    'Position', [0.02 + (i-1)*0.05, 0.55, 0.045, 0.35], ...
                    'BackgroundColor', t.WidgetBorderColor, ...
                    'ForegroundColor', t.ForegroundColor, ...
                    'TooltipString', presetTooltips{i}, ...
                    'Callback', @(src, ~) obj.applyPreset_(get(src, 'String')));
            end

            % From / To datetime edits.
            uicontrol('Parent', obj.FilterPanel_, 'Style', 'text', 'String', 'From:', ...
                'Units', 'normalized', 'Position', [0.25 0.55 0.04 0.35], ...
                'BackgroundColor', t.WidgetBackground, 'ForegroundColor', t.ForegroundColor, ...
                'HorizontalAlignment', 'right');
            uicontrol('Parent', obj.FilterPanel_, 'Style', 'edit', 'Tag', 'FromEdit', ...
                'Units', 'normalized', 'Position', [0.30 0.55 0.10 0.35], ...
                'String', '', ...
                'TooltipString', 'Custom start time (e.g. 2026-05-08 14:30:00)', ...
                'Callback', @(src, ~) obj.onFromToEdited_());
            uicontrol('Parent', obj.FilterPanel_, 'Style', 'text', 'String', 'To:', ...
                'Units', 'normalized', 'Position', [0.40 0.55 0.03 0.35], ...
                'BackgroundColor', t.WidgetBackground, 'ForegroundColor', t.ForegroundColor, ...
                'HorizontalAlignment', 'right');
            uicontrol('Parent', obj.FilterPanel_, 'Style', 'edit', 'Tag', 'ToEdit', ...
                'Units', 'normalized', 'Position', [0.43 0.55 0.10 0.35], ...
                'String', '', ...
                'TooltipString', 'Custom end time (e.g. 2026-05-08 15:30:00)', ...
                'Callback', @(src, ~) obj.onFromToEdited_());

            % Severity toggles.
            sevLabels   = {'I', 'W', 'A'};
            sevTooltips = { ...
                'Show info events (severity 1)', ...
                'Show warning events (severity 2)', ...
                'Show alarm events (severity 3)'};
            for i = 1:3
                uicontrol('Parent', obj.FilterPanel_, 'Style', 'togglebutton', ...
                    'String', sevLabels{i}, 'Tag', sprintf('SevBtn%d', i), ...
                    'Value', 1, ...
                    'Units', 'normalized', ...
                    'Position', [0.55 + (i-1)*0.03, 0.55, 0.025, 0.35], ...
                    'BackgroundColor', t.WidgetBorderColor, ...
                    'ForegroundColor', t.ForegroundColor, ...
                    'TooltipString', sevTooltips{i}, ...
                    'Callback', @(src, ~) obj.onSevToggled_(i, get(src, 'Value')));
            end

            % Open-only checkbox.
            uicontrol('Parent', obj.FilterPanel_, 'Style', 'checkbox', ...
                'String', 'Open only', 'Tag', 'OpenOnlyChk', ...
                'Value', 0, ...
                'Units', 'normalized', 'Position', [0.65 0.55 0.07 0.35], ...
                'BackgroundColor', t.WidgetBackground, 'ForegroundColor', t.ForegroundColor, ...
                'TooltipString', 'Show only currently-open (still active) events', ...
                'Callback', @(src, ~) obj.setOpenOnly_(get(src, 'Value') == 1));

            % Tag search.
            uicontrol('Parent', obj.FilterPanel_, 'Style', 'edit', ...
                'Tag', 'TagSearch', 'String', '', ...
                'Units', 'normalized', 'Position', [0.02 0.10 0.20 0.35], ...
                'TooltipString', 'Substring filter on registered tag keys (empty = all tags)', ...
                'Callback', @(src, ~) obj.onTagSearchChanged_(get(src, 'String')));

            % Refresh + Auto + interval.
            uicontrol('Parent', obj.FilterPanel_, 'Style', 'pushbutton', 'String', 'Refresh', ...
                'Units', 'normalized', 'Position', [0.74 0.55 0.07 0.35], ...
                'TooltipString', 'Re-read events from the EventStore and redraw', ...
                'Callback', @(~, ~) obj.refresh());
            uicontrol('Parent', obj.FilterPanel_, 'Style', 'checkbox', 'String', 'Auto', ...
                'Tag', 'AutoChk', 'Value', 1, ...
                'Units', 'normalized', 'Position', [0.82 0.55 0.05 0.35], ...
                'BackgroundColor', t.WidgetBackground, 'ForegroundColor', t.ForegroundColor, ...
                'TooltipString', 'Auto-refresh while the companion is in Live mode', ...
                'Callback', @(src, ~) obj.setAutoEnabled_(get(src, 'Value') == 1));
            uicontrol('Parent', obj.FilterPanel_, 'Style', 'edit', 'Tag', 'IntervalEdit', ...
                'String', sprintf('%g', obj.AutoPeriod_), ...
                'Units', 'normalized', 'Position', [0.87 0.55 0.04 0.35], ...
                'TooltipString', 'Auto-refresh interval in seconds', ...
                'Callback', @(src, ~) obj.onIntervalEdited_(get(src, 'String')));

            % --- Slider in bottom panel --------------------------------
            obj.Selector_ = TimeRangeSelector(obj.SliderPanel_, ...
                'OnRangeChanged', @(t1, t2) obj.onSliderRangeChanged_(t1, t2), ...
                'Theme',          t);

            % Live-mode coupling.
            obj.Listeners_{end+1} = addlistener(obj.Companion_, 'LiveModeChanged', ...
                @(s, ~) obj.onCompanionLiveChanged_(s.IsLive));
            obj.onCompanionLiveChanged_(obj.Companion_.IsLive);  % initial sync
        end

        function onCompanionLiveChanged_(obj, isLive)
        %ONCOMPANIONLIVECHANGED_ React to companion LiveModeChanged event.
            obj.IsLive = logical(isLive);
            if obj.IsLive && obj.AutoEnabled_
                obj.startAutoTimer_();
                if strcmp(obj.TimePresetMode, 'snapshot')
                    obj.TimePresetMode = 'roll';
                end
            else
                obj.stopAutoTimer_();
                if strcmp(obj.TimePresetMode, 'roll')
                    obj.TimePresetMode = 'snapshot';
                end
            end
        end

        function startAutoTimer_(obj)
        %STARTAUTOTIMER_ Create and start the auto-refresh timer if not already running.
            try
                if isempty(obj.AutoTimer_) || ~isvalid(obj.AutoTimer_)
                    obj.AutoTimer_ = timer( ...
                        'ExecutionMode', 'fixedRate', ...
                        'Period',        obj.AutoPeriod_, ...
                        'BusyMode',      'drop', ...
                        'TimerFcn',      @(~,~) obj.onAutoTick_(), ...
                        'ErrorFcn',      @(~,~) []);
                end
                if strcmp(obj.AutoTimer_.Running, 'off')
                    start(obj.AutoTimer_);
                end
            catch
                % Auto-refresh failure must never crash the viewer.
            end
        end

        function stopAutoTimer_(obj)
        %STOPAUTOTIMER_ Stop the auto-refresh timer if running.
            try
                if ~isempty(obj.AutoTimer_) && isvalid(obj.AutoTimer_) && ...
                        strcmp(obj.AutoTimer_.Running, 'on')
                    stop(obj.AutoTimer_);
                end
            catch
            end
        end

        function onAutoTick_(obj)
        %ONAUTOTICK_ Timer callback: advance window if rolling, then refresh.
            try
                if isempty(obj.hFigure) || ~isgraphics(obj.hFigure)
                    obj.stopAutoTimer_(); return;
                end
                if strcmp(obj.TimePresetMode, 'roll')
                    span = obj.TimeRange(2) - obj.TimeRange(1);
                    obj.TimeRange = [now - span, now];
                end
                obj.refresh();
            catch
            end
        end

        function onSliderRangeChanged_(obj, t1, t2)
        %ONSLIDERRANGECHANGED_ React to slider drag: set custom time range.
            if t2 <= t1; return; end
            obj.TimeRange      = [t1 t2];
            obj.TimePresetMode = 'custom';
            obj.refresh();
        end

        function updateSliderPreview_(obj, allEvents)
        %UPDATESLIDERPREVIEW_ Feed event-marker dots into the TimeRangeSelector.
        %   allEvents — full unfiltered Event array (so the user sees the
        %               complete distribution while the Gantt above shows
        %               the filtered slice).
            if isempty(obj.Selector_) || ~isvalid(obj.Selector_); return; end
            try
                if isempty(allEvents)
                    obj.Selector_.setEventMarkers([]);
                    return;
                end
                nowRef = now;
                times  = arrayfun(@(e) e.StartTime, allEvents);
                ends   = arrayfun(@(e) EventGanttCanvas.eventEndOrNow(e, nowRef), allEvents);
                colors = zeros(numel(allEvents), 3);
                for k = 1:numel(allEvents)
                    colors(k, :) = EventGanttCanvas.severityColor(allEvents(k).Severity);
                end
                tMin = min(times);
                tMax = max(nowRef, max(ends));
                if isfinite(tMin) && isfinite(tMax) && tMax > tMin
                    obj.Selector_.setDataRange(tMin, tMax);
                    selStart = max(tMin, obj.TimeRange(1));
                    selEnd   = min(tMax, obj.TimeRange(2));
                    if selEnd > selStart
                        % Suppress the slider's OnRangeChanged callback while
                        % programmatically syncing — without this the chain
                        % refresh -> setSelection -> OnRangeChanged ->
                        % onSliderRangeChanged_ -> refresh recurses infinitely.
                        savedCb = obj.Selector_.OnRangeChanged;
                        obj.Selector_.OnRangeChanged = [];
                        try
                            obj.Selector_.setSelection(selStart, selEnd);
                        catch
                        end
                        obj.Selector_.OnRangeChanged = savedCb;
                    end
                end
                obj.Selector_.setEventMarkers(times, colors);
            catch
                % Slider preview is non-critical — never crash refresh.
            end
        end

        function onFromToEdited_(obj)
        %ONFROMTOEDITED_ Parse From/To edit fields and apply as custom range.
            fromCtl = findall(obj.hFigure, 'Tag', 'FromEdit');
            toCtl   = findall(obj.hFigure, 'Tag', 'ToEdit');
            sFrom = strtrim(get(fromCtl, 'String'));
            sTo   = strtrim(get(toCtl,   'String'));
            if isempty(sFrom) || isempty(sTo); return; end
            try
                t1 = datenum(sFrom);
                t2 = datenum(sTo);
                obj.setTimeRange(t1, t2);
                obj.refresh();
            catch
                % Bad input — ignore silently; user can correct it.
            end
        end

        function onSevToggled_(obj, idx, val)
        %ONSEVTOGGLED_ React to severity toggle button press.
            obj.SeverityMask(idx) = (val == 1);
            obj.refresh();
        end

        function setOpenOnly_(obj, tf)
        %SETOPENONLY_ Set open-only filter flag and refresh.
            obj.OpenOnly = logical(tf);
            obj.refresh();
        end

        function onTagSearchChanged_(obj, txt)
        %ONTAGSEARCHCHANGED_ Filter by tag keys matching search text.
            txt = strtrim(txt);
            if isempty(txt)
                obj.SelectedTagKeys = {};
            else
                allKeys = TagRegistry.keys();
                if isempty(allKeys)
                    obj.SelectedTagKeys = {};
                else
                    hit = allKeys(contains(allKeys, txt));
                    obj.SelectedTagKeys = hit(:)';
                end
            end
            obj.refresh();
        end

        function setAutoEnabled_(obj, tf)
        %SETAUTOENABLED_ Enable or disable the auto-refresh timer.
            obj.AutoEnabled_ = logical(tf);
            if obj.AutoEnabled_ && obj.IsLive
                obj.startAutoTimer_();
            else
                obj.stopAutoTimer_();
            end
        end

        function onIntervalEdited_(obj, txt)
        %ONINTERVALEDITED_ Update auto-refresh period from edit field.
            v = str2double(strtrim(txt));
            if ~isfinite(v) || v <= 0; return; end
            obj.AutoPeriod_ = v;
            if ~isempty(obj.AutoTimer_) && isvalid(obj.AutoTimer_)
                wasOn = strcmp(obj.AutoTimer_.Running, 'on');
                if wasOn; stop(obj.AutoTimer_); end
                obj.AutoTimer_.Period = v;
                if wasOn; start(obj.AutoTimer_); end
            end
        end

        function onEventSingleClick_(obj, ev)
        %ONEVENTSINGLECLICK_ Show a small details popup with editable Notes.
            try
                msg = sprintf( ...
                    ['Sensor:    %s\nThreshold: %s (%s @ %g)\n', ...
                     'Severity:  %d\nStart:     %s\nEnd:       %s\n', ...
                     'Duration:  %g\nPeak:      %g\nN points:  %d'], ...
                    ev.SensorName, ev.ThresholdLabel, ev.Direction, ev.ThresholdValue, ...
                    ev.Severity, ...
                    obj.formatTime_(ev.StartTime), ...
                    obj.formatTime_(ev.EndTime), ...
                    obj.eventDuration_(ev), ...
                    obj.scalarOrNaN_(ev.PeakValue), obj.scalarOrNaN_(ev.NumPoints));

                answer = inputdlg({sprintf('%s\n\nNotes:', msg)}, ...
                    sprintf('Event %s', ev.Id), [10 60], {ev.Notes});
                if ~isempty(answer)
                    ev.Notes = answer{1};
                    try; obj.Store_.save(); catch; end
                end
            catch
                % Popups must never crash the viewer.
            end
        end

        function onEventDoubleClick_(obj, ev)
        %ONEVENTDOUBLECLICK_ Open a SensorDetailPlot zoomed to the event window.
            try
                tagKey = '';
                if ~isempty(ev.TagKeys); tagKey = ev.TagKeys{1}; end
                if isempty(tagKey); tagKey = ev.SensorName; end
                tag = [];
                try; tag = TagRegistry.get(tagKey); catch; end
                if isempty(tag) || ~isa(tag, 'Tag'); return; end
                sdp = SensorDetailPlot(tag);
                evEnd = EventGanttCanvas.eventEndOrNow(ev, now);
                pad = 0.1 * max(evEnd - ev.StartTime, 1);
                try
                    set(sdp.hMainAxes, 'XLim', [ev.StartTime - pad, evEnd + pad]);
                catch
                end
            catch
            end
        end

        function s = formatTime_(~, t)
        %FORMATTIME_ Format a datenum time as readable string; NaN => '(open)'.
            if isnan(t); s = '(open)'; return; end
            try
                s = datestr(t, 'yyyy-mm-dd HH:MM:SS');
            catch
                s = sprintf('%g', t);
            end
        end

        function d = eventDuration_(~, ev)
        %EVENTDURATION_ Return EndTime-StartTime, or NaN for open events.
            if isnan(ev.EndTime); d = NaN; return; end
            d = ev.EndTime - ev.StartTime;
        end

        function v = scalarOrNaN_(~, x)
        %SCALARORNANNORM_ Return x(1) if numeric, else NaN.
            if isempty(x) || ~isnumeric(x); v = NaN; else; v = x(1); end
        end
    end
end
