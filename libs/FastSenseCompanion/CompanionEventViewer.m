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
        CatalogPane_ = []   % TagCatalogPane reused from main companion app
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

        function p = getCatalogPaneForTest_(obj)
        %GETCATALOGPANEFORTEST_ Test-only accessor for the catalog pane.
            p = obj.CatalogPane_;
        end

        function injectCatalogSelectionForTest_(obj, keysCell)
        %INJECTCATALOGSELECTIONFORTEST_ Test-only: simulate the catalog firing
        %   TagSelectionChanged with a given key set. Bypasses the listbox UI.
            obj.SelectedTagKeys = keysCell;
            obj.refresh();
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
            try
                if ~isempty(obj.CatalogPane_)
                    obj.CatalogPane_.detach();
                end
            catch
            end
            obj.CatalogPane_ = [];
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

            % --- Filter bar contents (uifigure widgets) ---------------
            % Single-row grid with explicit pixel widths; '1x' between groups
            % keeps everything aligned regardless of window width.
            hFilterGrid = uigridlayout(obj.FilterPanel_, [1 17]);
            hFilterGrid.RowHeight     = {'1x'};
            hFilterGrid.ColumnWidth   = { ...
                40, 40, 40, 40, ...                  % cols 1-4: presets
                40, 110, 30, 110, ...                % cols 5-8: From label, edit, To label, edit
                30, 30, 30, ...                      % cols 9-11: severity I/W/A
                90, ...                              % col 12: Open only
                '1x', ...                            % col 13: spacer
                70, ...                              % col 14: Refresh
                60, 50, '1x'};                       % cols 15-17: Auto, interval, trailing spacer
            hFilterGrid.Padding       = [8 8 8 8];
            hFilterGrid.ColumnSpacing = 4;
            hFilterGrid.BackgroundColor = t.WidgetBackground;

            % Preset buttons (cols 1-4).
            presets        = {'1h', '24h', '7d', 'All'};
            presetTooltips = { ...
                'Show events from the last hour', ...
                'Show events from the last 24 hours', ...
                'Show events from the last 7 days', ...
                'Show all events on record'};
            for i = 1:numel(presets)
                btn = uibutton(hFilterGrid, 'push');
                btn.Layout.Row    = 1;
                btn.Layout.Column = i;
                btn.Text          = presets{i};
                btn.Tag           = 'PresetBtn';
                btn.Tooltip       = presetTooltips{i};
                btn.BackgroundColor = t.WidgetBorderColor;
                btn.FontColor       = t.ForegroundColor;
                btn.ButtonPushedFcn = @(src, ~) obj.applyPreset_(src.Text);
            end

            % From label + edit (cols 5-6).
            lblFrom = uilabel(hFilterGrid);
            lblFrom.Layout.Row    = 1;
            lblFrom.Layout.Column = 5;
            lblFrom.Text          = 'From:';
            lblFrom.FontColor     = t.ForegroundColor;
            lblFrom.BackgroundColor = t.WidgetBackground;
            lblFrom.HorizontalAlignment = 'right';

            edFrom = uieditfield(hFilterGrid, 'text');
            edFrom.Layout.Row    = 1;
            edFrom.Layout.Column = 6;
            edFrom.Tag           = 'FromEdit';
            edFrom.Tooltip       = 'Custom start time (e.g. 2026-05-08 14:30:00)';
            edFrom.FontColor       = t.ForegroundColor;
            edFrom.BackgroundColor = t.WidgetBackground;
            edFrom.ValueChangedFcn = @(~, ~) obj.onFromToEdited_();

            % To label + edit (cols 7-8).
            lblTo = uilabel(hFilterGrid);
            lblTo.Layout.Row    = 1;
            lblTo.Layout.Column = 7;
            lblTo.Text          = 'To:';
            lblTo.FontColor     = t.ForegroundColor;
            lblTo.BackgroundColor = t.WidgetBackground;
            lblTo.HorizontalAlignment = 'right';

            edTo = uieditfield(hFilterGrid, 'text');
            edTo.Layout.Row    = 1;
            edTo.Layout.Column = 8;
            edTo.Tag           = 'ToEdit';
            edTo.Tooltip       = 'Custom end time (e.g. 2026-05-08 15:30:00)';
            edTo.FontColor       = t.ForegroundColor;
            edTo.BackgroundColor = t.WidgetBackground;
            edTo.ValueChangedFcn = @(~, ~) obj.onFromToEdited_();

            % Severity toggles (cols 9-11).
            sevLabels   = {'I', 'W', 'A'};
            sevTooltips = { ...
                'Show info events (severity 1)', ...
                'Show warning events (severity 2)', ...
                'Show alarm events (severity 3)'};
            for i = 1:3
                stBtn = uibutton(hFilterGrid, 'state');
                stBtn.Layout.Row    = 1;
                stBtn.Layout.Column = 8 + i;
                stBtn.Text          = sevLabels{i};
                stBtn.Tag           = sprintf('SevBtn%d', i);
                stBtn.Value         = true;
                stBtn.Tooltip       = sevTooltips{i};
                stBtn.BackgroundColor = t.WidgetBorderColor;
                stBtn.FontColor       = t.ForegroundColor;
                stBtn.ValueChangedFcn = @(src, ~) obj.onSevToggled_(i, src.Value);
            end

            % Open-only checkbox (col 12).
            chkOpen = uicheckbox(hFilterGrid);
            chkOpen.Layout.Row    = 1;
            chkOpen.Layout.Column = 12;
            chkOpen.Text          = 'Open only';
            chkOpen.Tag           = 'OpenOnlyChk';
            chkOpen.Value         = false;
            chkOpen.Tooltip       = 'Show only currently-open (still active) events';
            chkOpen.FontColor     = t.ForegroundColor;
            chkOpen.ValueChangedFcn = @(src, ~) obj.setOpenOnly_(src.Value);

            % Spacer at col 13.

            % Refresh button (col 14).
            btnRefresh = uibutton(hFilterGrid, 'push');
            btnRefresh.Layout.Row    = 1;
            btnRefresh.Layout.Column = 14;
            btnRefresh.Text          = 'Refresh';
            btnRefresh.Tooltip       = 'Re-read events from the EventStore and redraw';
            btnRefresh.BackgroundColor = t.WidgetBorderColor;
            btnRefresh.FontColor       = t.ForegroundColor;
            btnRefresh.ButtonPushedFcn = @(~, ~) obj.refresh();

            % Auto checkbox (col 15).
            chkAuto = uicheckbox(hFilterGrid);
            chkAuto.Layout.Row    = 1;
            chkAuto.Layout.Column = 15;
            chkAuto.Text          = 'Auto';
            chkAuto.Tag           = 'AutoChk';
            chkAuto.Value         = true;
            chkAuto.Tooltip       = 'Auto-refresh while the companion is in Live mode';
            chkAuto.FontColor     = t.ForegroundColor;
            chkAuto.ValueChangedFcn = @(src, ~) obj.setAutoEnabled_(src.Value);

            % Interval edit (col 16).
            edInterval = uieditfield(hFilterGrid, 'text');
            edInterval.Layout.Row    = 1;
            edInterval.Layout.Column = 16;
            edInterval.Tag           = 'IntervalEdit';
            edInterval.Value         = sprintf('%g', obj.AutoPeriod_);
            edInterval.Tooltip       = 'Auto-refresh interval in seconds';
            edInterval.FontColor       = t.ForegroundColor;
            edInterval.BackgroundColor = t.WidgetBackground;
            edInterval.ValueChangedFcn = @(src, ~) obj.onIntervalEdited_(src.Value);

            % Trailing spacer at col 17.

            % --- Slider in bottom panel --------------------------------
            obj.Selector_ = TimeRangeSelector(obj.SliderPanel_, ...
                'OnRangeChanged', @(t1, t2) obj.onSliderRangeChanged_(t1, t2), ...
                'Theme',          t);

            % --- Tag catalog pane (left column) ----------------------
            obj.CatalogPane_ = TagCatalogPane();
            obj.CatalogPane_.attach(obj.LeftPanel_, obj.hFigure, obj.Registry_, t);
            obj.Listeners_{end+1} = addlistener(obj.CatalogPane_, 'TagSelectionChanged', ...
                @(~, ~) obj.onCatalogTagSelectionChanged_());

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

        function onCatalogTagSelectionChanged_(obj)
        %ONCATALOGTAGSELECTIONCHANGED_ React to the catalog pane's selection event.
            try
                obj.SelectedTagKeys = obj.CatalogPane_.getSelectedKeys();
                obj.refresh();
            catch
                % Selection routing must never crash the viewer.
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
            if isempty(fromCtl) || isempty(toCtl); return; end
            sFrom = strtrim(fromCtl.Value);
            sTo   = strtrim(toCtl.Value);
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
