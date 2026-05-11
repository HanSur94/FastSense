classdef CompanionEventViewer < handle
%COMPANIONEVENTVIEWER Pop-out uifigure viewer: tag-aware Gantt + table of EventStore events.
%
%   v = CompanionEventViewer(store, registry, companion)
%     store      — EventStore handle (required)
%     registry   — TagRegistry handle/class (required, for tag-key search)
%     companion  — FastSenseCompanion handle (required, for theme + LiveModeChanged)
%
%   Layout:
%     Left column  — Gantt/Table view-mode uiswitch + TagCatalogPane
%                    (tag search, kind/criticality pills, multi-select listbox).
%                    Selecting tags filters the Gantt and Table.
%     Right column — filter bar (presets, From/To, severity, Open only,
%                    Refresh, Auto, interval), Gantt axes (with crosshair
%                    + dark gridlines) OR uitable (Plot Selected → multi-
%                    event drill-down dashboard), and a TimeRangeSelector
%                    slider with start/span/end readouts.
%
%   Public:
%     v.refresh()                    — pull from store, redraw Gantt + Table + slider
%     v.setTimeRange(tStart, tEnd)   — programmatic; sets mode to 'custom'
%     v.setTagFilter(keysCell)       — {} / '' means "all tags" (one-way:
%                                      does NOT push back into the catalog UI)
%     v.LeftPaneWidth                — settable (>= 80 px); propagates to grid
%     v.ViewMode                     — 'gantt' | 'table' (settable; toggles via
%                                      the left-header uiswitch)
%     v.bringToFront()               — figure(hFigure)
%     v.close()                      — idempotent teardown
%
%   Click behavior on Gantt bars:
%     Single-click → debounced (300 ms) "Event Info" uifigure with
%                    editable Notes (cancelled by a follow-up double-click)
%     Double-click → brand-new DashboardEngine with one FastSenseWidget
%                    for the event's sensor, X zoomed to the event window
%
%   Click behavior on Table rows:
%     Multi-row select → "Plot Selected (N)" button enables; click opens
%                        a single dashboard with N stacked FastSenseWidgets
%                        (one per selected event)
%     Double-click row → same dashboard drill-down as Gantt double-click
%
%   See also EventGanttCanvas, FastSenseCompanion, TagCatalogPane,
%            TimeRangeSelector, DashboardEngine.

    properties (SetAccess = private)
        hFigure
        SelectedTagKeys = {}
        SeverityMask    = [true true true]
        OpenOnly        = false
        TimeRange       = [0 1]
        TimePresetMode  = 'snapshot'   % 'roll' | 'snapshot' | 'custom'
        IsLive          = false
    end

    properties (Access = public, AbortSet = true)
        LeftPaneWidth = 260       % Width of the tag-catalog pane in pixels.
        ViewMode      = 'gantt'   % 'gantt' | 'table' — which view is visible.
    end

    methods
        function set.LeftPaneWidth(obj, val)
            if ~isnumeric(val) || ~isscalar(val) || ~isfinite(val) || val < 80
                error('CompanionEventViewer:invalidLeftPaneWidth', ...
                    'LeftPaneWidth must be a numeric scalar >= 80 pixels.');
            end
            obj.LeftPaneWidth = val;
            if ~isempty(obj.RootGrid_) && isvalid(obj.RootGrid_)
                cw = obj.RootGrid_.ColumnWidth;
                cw{1} = val;
                obj.RootGrid_.ColumnWidth = cw;
            end
        end

        function set.ViewMode(obj, val)
            if ~ischar(val) && ~(isstring(val) && isscalar(val))
                error('CompanionEventViewer:invalidViewMode', ...
                    'ViewMode must be ''gantt'' or ''table''.');
            end
            val = char(val);
            if ~any(strcmp(val, {'gantt', 'table'}))
                error('CompanionEventViewer:invalidViewMode', ...
                    'ViewMode must be ''gantt'' or ''table'' (got ''%s'').', val);
            end
            obj.ViewMode = val;
            obj.applyViewMode_();
        end
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
        RootGrid_     = []   % 1x2 uigridlayout: [left pane | right column]
        RightGrid_    = []   % 3x1 uigridlayout: [filter bar; view; slider]
        LeftPanel_    = []   % uipanel hosting the left-column contents
        LeftHeaderPanel_  = []   % Thin uipanel above the catalog hosting the view-mode switch
        LeftCatalogPanel_ = []   % uipanel that the TagCatalogPane attaches into
        CatalogPane_  = []   % TagCatalogPane reused from main companion app
        TablePanel_   = []   % uipanel hosting the uitable view
        Table_        = []   % uitable handle
        ViewSwitch_   = []   % uiswitch handle
        SliderInnerPanel_   = []   % uipanel hosting the TimeRangeSelector itself (row 1 of SliderPanel_)
        SliderReadoutGrid_  = []   % uigridlayout hosting the 3 readout labels (row 2 of SliderPanel_)
        SliderReadoutStart_ = []   % uilabel showing selection start time (left)
        SliderReadoutSpan_  = []   % uilabel showing selection span (middle)
        SliderReadoutEnd_   = []   % uilabel showing selection end time (right)
        SingleClickTimer_   = []   % Pending single-click info modal timer (cancelled by double-click)
        TableToolbarPanel_   = []   % uipanel above the uitable hosting the multi-select toolbar
        PlotSelectedBtn_     = []   % uibutton 'Plot Selected (N)'
        SelectedTableRows_   = []   % sorted unique vector of currently-highlighted table row indices
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

            % Default to "All" so the viewer opens showing every event in the
            % store. Users can narrow with presets, From/To, or the slider.
            try
                obj.applyPreset_('all');
            catch
                % Empty store or other edge — leave the default range alone.
            end
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
            obj.updateSliderReadouts_();
        end

        function setTagFilter(obj, keysCell)
        %SETTAGFILTER Set the tag key filter. {} / '' means "all tags".
        %
        %   This is a ONE-WAY set: the viewer's internal SelectedTagKeys is
        %   updated and a subsequent refresh() will apply the filter, but the
        %   left-column TagCatalogPane UI is NOT updated to mirror it. Use
        %   companion.refreshUI() or set the catalog pane's selection directly
        %   if you need the UI to reflect the programmatic filter.
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
        %REFRESH Pull from store, apply filters, redraw Gantt + table + slider. No-op if figure gone.
            if isempty(obj.hFigure) || ~isgraphics(obj.hFigure); return; end
            evs = obj.Store_.getEvents();
            if isempty(evs); evs = Event.empty; end
            filtered = CompanionEventViewer.applyFilters( ...
                evs, obj.SelectedTagKeys, obj.SeverityMask, obj.OpenOnly, obj.TimeRange);
            obj.Canvas_.draw(filtered, obj.Theme_);
            obj.updateTableData_(filtered);
            obj.updateSliderPreview_(evs);
            obj.updateSliderReadouts_();
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

        function p = getAxesPanelForTest_(obj)
        %GETAXESPANELFORTEST_ Test-only accessor for the Gantt axes panel.
            p = obj.AxesPanel_;
        end

        function p = getTablePanelForTest_(obj)
        %GETTABLEPANELFORTEST_ Test-only accessor for the table panel.
            p = obj.TablePanel_;
        end

        function t = getTableForTest_(obj)
        %GETTABLEFORTEST_ Test-only accessor for the uitable.
            t = obj.Table_;
        end

        function injectCatalogSelectionForTest_(obj, keysCell)
        %INJECTCATALOGSELECTIONFORTEST_ Test-only: simulate the catalog firing
        %   TagSelectionChanged with a given key set. Bypasses the listbox UI.
            obj.SelectedTagKeys = keysCell;
            obj.refresh();
        end

        function injectTableSelectionForTest_(obj, rows)
        %INJECTTABLESELECTIONFORTEST_ Test-only: simulate a multi-row table
        %   selection by feeding a synthetic Indices struct into the
        %   selection-changed handler. Bypasses the uitable UI.
            indices = [rows(:), ones(numel(rows), 1)];   % col 1 by convention
            obj.onTableRowSelectionChanged_(struct('Indices', indices));
        end

        function onPlotSelectedClickedForTest_(obj)
        %ONPLOTSELECTEDCLICKEDFORTEST_ Test-only shim that calls the private
        %   onPlotSelectedClicked_ without exposing the method publicly.
            obj.onPlotSelectedClicked_();
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
            try
                if ~isempty(obj.SingleClickTimer_) && isvalid(obj.SingleClickTimer_)
                    if strcmp(obj.SingleClickTimer_.Running, 'on'); stop(obj.SingleClickTimer_); end
                    delete(obj.SingleClickTimer_);
                end
            catch
            end
            obj.SingleClickTimer_ = [];
            for i = 1:numel(obj.Listeners_)
                try; delete(obj.Listeners_{i}); catch; end
            end
            obj.Listeners_ = {};
            try
                if ~isempty(obj.Canvas_) && isvalid(obj.Canvas_)
                    obj.Canvas_.uninstallCrosshair();
                end
            catch
            end
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
            obj.SliderReadoutStart_ = [];
            obj.SliderReadoutSpan_  = [];
            obj.SliderReadoutEnd_   = [];
            obj.SliderReadoutGrid_  = [];
            obj.SliderInnerPanel_   = [];
            try
                if ~isempty(obj.CatalogPane_)
                    obj.CatalogPane_.detach();
                end
            catch
            end
            obj.CatalogPane_ = [];
            try; if ~isempty(obj.Table_) && isvalid(obj.Table_); delete(obj.Table_); end; catch; end
            obj.Table_             = [];
            obj.PlotSelectedBtn_   = [];
            obj.TableToolbarPanel_ = [];
            obj.SelectedTableRows_ = [];
            obj.ViewSwitch_        = [];
            obj.TablePanel_        = [];
            obj.LeftHeaderPanel_   = [];
            obj.LeftCatalogPanel_  = [];
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
            obj.updateSliderReadouts_();
        end

        function buildFigure_(obj)
        %BUILDFIGURE_ Create the uifigure with three uipanels + Gantt axes.
            t = obj.Theme_;
            obj.hFigure = uifigure( ...
                'Name',            'FastSense — Event Viewer', ...
                'Color',           t.DashboardBackground, ...
                'Position',        [120 120 1400 600], ...
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

            % Split LeftPanel_ into [header | catalog] so the Gantt/Table
            % switch sits directly above the catalog's tag-search bar.
            hLeftGrid = uigridlayout(obj.LeftPanel_, [2 1]);
            hLeftGrid.RowHeight     = {36, '1x'};
            hLeftGrid.ColumnWidth   = {'1x'};
            hLeftGrid.Padding       = [0 0 0 0];
            hLeftGrid.RowSpacing    = 0;
            hLeftGrid.BackgroundColor = t.WidgetBackground;

            obj.LeftHeaderPanel_ = uipanel(hLeftGrid);
            obj.LeftHeaderPanel_.Layout.Row    = 1;
            obj.LeftHeaderPanel_.Layout.Column = 1;
            obj.LeftHeaderPanel_.BackgroundColor = t.WidgetBackground;
            obj.LeftHeaderPanel_.BorderType      = 'none';

            obj.LeftCatalogPanel_ = uipanel(hLeftGrid);
            obj.LeftCatalogPanel_.Layout.Row    = 2;
            obj.LeftCatalogPanel_.Layout.Column = 1;
            obj.LeftCatalogPanel_.BackgroundColor = t.WidgetBackground;
            obj.LeftCatalogPanel_.BorderType      = 'none';

            % --- View-mode switch in the left header (above the catalog) ---
            hLeftHeaderGrid = uigridlayout(obj.LeftHeaderPanel_, [1 3]);
            hLeftHeaderGrid.RowHeight       = {'1x'};
            hLeftHeaderGrid.ColumnWidth     = {8, '1x', 8};   % small pad | switch fills | small pad
            hLeftHeaderGrid.Padding         = [0 4 0 4];
            hLeftHeaderGrid.BackgroundColor = t.WidgetBackground;

            obj.ViewSwitch_ = uiswitch(hLeftHeaderGrid, 'slider');
            obj.ViewSwitch_.Layout.Row      = 1;
            obj.ViewSwitch_.Layout.Column   = 2;
            obj.ViewSwitch_.Items           = {'Gantt', 'Table'};
            obj.ViewSwitch_.Value           = 'Gantt';
            obj.ViewSwitch_.Tag             = 'ViewModeSwitch';
            obj.ViewSwitch_.FontColor       = t.ForegroundColor;
            obj.ViewSwitch_.ValueChangedFcn = @(src, ~) obj.onViewSwitchChanged_(src.Value);

            % Right column: 3-row nested grid (filter bar | view | slider).
            obj.RightGrid_ = uigridlayout(obj.RootGrid_, [3 1]);
            obj.RightGrid_.Layout.Row    = 1;
            obj.RightGrid_.Layout.Column = 2;
            obj.RightGrid_.RowHeight     = {60, '1x', 110};
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

            % TablePanel_ overlays the same grid cell as AxesPanel_; visibility
            % toggled by ViewMode.
            obj.TablePanel_ = uipanel(obj.RightGrid_);
            obj.TablePanel_.Layout.Row      = 2;
            obj.TablePanel_.Layout.Column   = 1;
            obj.TablePanel_.BackgroundColor = t.WidgetBackground;
            obj.TablePanel_.BorderType      = 'none';
            obj.TablePanel_.Visible         = 'off';

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
            % Host the slider in row 1 of a 2-row grid; readout labels go in row 2.
            hSliderGrid = uigridlayout(obj.SliderPanel_, [2 1]);
            hSliderGrid.RowHeight     = {'1x', 28};
            hSliderGrid.ColumnWidth   = {'1x'};
            hSliderGrid.Padding       = [0 0 0 0];
            hSliderGrid.RowSpacing    = 2;
            hSliderGrid.BackgroundColor = t.WidgetBackground;

            obj.SliderInnerPanel_ = uipanel(hSliderGrid);
            obj.SliderInnerPanel_.Layout.Row    = 1;
            obj.SliderInnerPanel_.Layout.Column = 1;
            obj.SliderInnerPanel_.BackgroundColor = t.WidgetBackground;
            obj.SliderInnerPanel_.BorderType      = 'none';

            obj.Selector_ = TimeRangeSelector(obj.SliderInnerPanel_, ...
                'OnRangeChanged', @(t1, t2) obj.onSliderRangeChanged_(t1, t2), ...
                'Theme',          t);

            % Readout strip: [start | span | end] under the slider.
            obj.SliderReadoutGrid_ = uigridlayout(hSliderGrid, [1 3]);
            obj.SliderReadoutGrid_.Layout.Row    = 2;
            obj.SliderReadoutGrid_.Layout.Column = 1;
            obj.SliderReadoutGrid_.RowHeight     = {'1x'};
            obj.SliderReadoutGrid_.ColumnWidth   = {'1x', '1x', '1x'};
            obj.SliderReadoutGrid_.Padding       = [8 0 8 0];
            obj.SliderReadoutGrid_.ColumnSpacing = 8;
            obj.SliderReadoutGrid_.BackgroundColor = t.WidgetBackground;

            obj.SliderReadoutStart_ = uilabel(obj.SliderReadoutGrid_);
            obj.SliderReadoutStart_.Layout.Row    = 1;
            obj.SliderReadoutStart_.Layout.Column = 1;
            obj.SliderReadoutStart_.Text          = char(8212);
            obj.SliderReadoutStart_.Tag           = 'SliderReadoutStart';
            obj.SliderReadoutStart_.HorizontalAlignment = 'left';
            obj.SliderReadoutStart_.FontColor     = t.ForegroundColor;
            obj.SliderReadoutStart_.BackgroundColor = t.WidgetBackground;
            obj.SliderReadoutStart_.FontSize      = 11;

            obj.SliderReadoutSpan_ = uilabel(obj.SliderReadoutGrid_);
            obj.SliderReadoutSpan_.Layout.Row    = 1;
            obj.SliderReadoutSpan_.Layout.Column = 2;
            obj.SliderReadoutSpan_.Text          = char(8212);
            obj.SliderReadoutSpan_.Tag           = 'SliderReadoutSpan';
            obj.SliderReadoutSpan_.HorizontalAlignment = 'center';
            obj.SliderReadoutSpan_.FontColor     = t.ForegroundColor;
            obj.SliderReadoutSpan_.BackgroundColor = t.WidgetBackground;
            obj.SliderReadoutSpan_.FontSize      = 11;
            obj.SliderReadoutSpan_.FontWeight    = 'bold';

            obj.SliderReadoutEnd_ = uilabel(obj.SliderReadoutGrid_);
            obj.SliderReadoutEnd_.Layout.Row    = 1;
            obj.SliderReadoutEnd_.Layout.Column = 3;
            obj.SliderReadoutEnd_.Text          = char(8212);
            obj.SliderReadoutEnd_.Tag           = 'SliderReadoutEnd';
            obj.SliderReadoutEnd_.HorizontalAlignment = 'right';
            obj.SliderReadoutEnd_.FontColor     = t.ForegroundColor;
            obj.SliderReadoutEnd_.BackgroundColor = t.WidgetBackground;
            obj.SliderReadoutEnd_.FontSize      = 11;

            % --- Event table view (overlays the Gantt's grid cell) -----
            % Two-row layout: thin toolbar on top with the multi-select
            % "Plot Selected" button, table below.
            hTableGrid = uigridlayout(obj.TablePanel_, [2 1]);
            hTableGrid.RowHeight     = {32, '1x'};
            hTableGrid.ColumnWidth   = {'1x'};
            hTableGrid.Padding       = [0 0 0 0];
            hTableGrid.RowSpacing    = 4;
            hTableGrid.BackgroundColor = t.WidgetBackground;

            obj.TableToolbarPanel_ = uipanel(hTableGrid);
            obj.TableToolbarPanel_.Layout.Row    = 1;
            obj.TableToolbarPanel_.Layout.Column = 1;
            obj.TableToolbarPanel_.BackgroundColor = t.WidgetBackground;
            obj.TableToolbarPanel_.BorderType      = 'none';

            hToolbarRowGrid = uigridlayout(obj.TableToolbarPanel_, [1 2]);
            hToolbarRowGrid.RowHeight     = {'1x'};
            hToolbarRowGrid.ColumnWidth   = {'1x', 160};
            hToolbarRowGrid.Padding       = [8 4 8 4];
            hToolbarRowGrid.BackgroundColor = t.WidgetBackground;

            obj.PlotSelectedBtn_ = uibutton(hToolbarRowGrid, 'push');
            obj.PlotSelectedBtn_.Layout.Row    = 1;
            obj.PlotSelectedBtn_.Layout.Column = 2;
            obj.PlotSelectedBtn_.Text          = 'Plot Selected';
            obj.PlotSelectedBtn_.Tag           = 'PlotSelectedEventsBtn';
            obj.PlotSelectedBtn_.Tooltip       = 'Open a new dashboard with one FastSense plot per selected event';
            obj.PlotSelectedBtn_.Enable        = 'off';
            obj.PlotSelectedBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.PlotSelectedBtn_.FontColor       = t.ForegroundColor;
            obj.PlotSelectedBtn_.ButtonPushedFcn = @(~, ~) obj.onPlotSelectedClicked_();

            obj.Table_ = uitable(hTableGrid);
            obj.Table_.Layout.Row    = 2;
            obj.Table_.Layout.Column = 1;
            obj.Table_.ColumnName  = ...
                {'Start'; 'End'; 'Sensor'; 'Threshold'; 'Severity'; 'Duration'; 'Open'; 'Notes'};
            obj.Table_.ColumnEditable = [false false false false false false false true];
            obj.Table_.ColumnSortable = [true  true  true  true  true  true  true  false];
            obj.Table_.RowName        = {};
            obj.Table_.BackgroundColor = t.WidgetBackground;
            obj.Table_.ForegroundColor = t.ForegroundColor;
            % Row-level multi-select (Cmd-click / Shift-click). On R2023a+
            % use the modern SelectionType + SelectionChangedFcn + Selection
            % property which gives us a clean vector of row indices. Fall
            % back to CellSelectionCallback on older releases (the per-cell
            % flow still works, just without proper row highlighting).
            try
                obj.Table_.SelectionType    = 'row';
                obj.Table_.Multiselect      = 'on';
                obj.Table_.SelectionChangedFcn = @(src, ~) obj.onTableRowSelectionChanged_(src);
            catch
                obj.Table_.CellSelectionCallback = @(~, ev) obj.onTableRowSelectionChanged_(ev);
            end
            try
                obj.Table_.DoubleClickedFcn = @(~, ev) obj.onTableDoubleClicked_(ev);
            catch
                % DoubleClickedFcn requires R2022a+; older releases silently skip.
            end
            try
                obj.Table_.CellEditCallback = @(~, ev) obj.onTableCellEdit_(ev);
            catch
            end

            % Apply initial ViewMode visibility (Gantt by default).
            obj.applyViewMode_();

            % Wire the Gantt crosshair (vertical line tracking cursor X with
            % datetime readout). Chains onto the slider's existing Motion handler.
            obj.Canvas_.installCrosshair(obj.hFigure);

            % --- Tag catalog pane (left column) ----------------------
            obj.CatalogPane_ = TagCatalogPane();
            obj.CatalogPane_.attach(obj.LeftCatalogPanel_, obj.hFigure, obj.Registry_, t);
            obj.Listeners_{end+1} = addlistener(obj.CatalogPane_, 'TagSelectionChanged', ...
                @(~, ~) obj.onCatalogTagSelectionChanged_());

            % Live-mode coupling.
            obj.Listeners_{end+1} = addlistener(obj.Companion_, 'LiveModeChanged', ...
                @(s, ~) obj.onCompanionLiveChanged_(s.IsLive));
            obj.onCompanionLiveChanged_(obj.Companion_.IsLive);  % initial sync

            obj.updateSliderReadouts_();
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
                    obj.updateSliderReadouts_();
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
            obj.updateSliderReadouts_();
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
                obj.Selector_.setEventBands(times, ends, colors);
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
        %ONEVENTSINGLECLICK_ Defer the info modal so a follow-up double-click
        %   can cancel it. Without the deferral the FIRST click of a double-
        %   click sequence would already have opened the info modal before the
        %   double-click handler runs — leaving two windows open per drill-in.
        %   Single-click info modal is Gantt-only; the Table view does not
        %   wire a CellSelectionCallback (it would conflict with column sorting).
            try
                if ~isempty(obj.SingleClickTimer_) && isvalid(obj.SingleClickTimer_)
                    if strcmp(obj.SingleClickTimer_.Running, 'on'); stop(obj.SingleClickTimer_); end
                    delete(obj.SingleClickTimer_);
                end
                obj.SingleClickTimer_ = timer( ...
                    'ExecutionMode', 'singleShot', ...
                    'StartDelay',    0.30, ...
                    'TimerFcn',      @(~,~) obj.openEventInfoModal_(ev), ...
                    'ErrorFcn',      @(~,~) []);
                start(obj.SingleClickTimer_);
            catch
                % Timer failures must never crash the viewer; fall back to
                % opening the modal immediately.
                try; obj.openEventInfoModal_(ev); catch; end
            end
        end

        function onEventDoubleClick_(obj, ev)
        %ONEVENTDOUBLECLICK_ Open a brand-new DashboardEngine with one FastSenseWidget
        %   for the event's sensor tag, X range zoomed to the event window.
        %   The Table view's DoubleClickedFcn also routes here (Task 8.6).
            % Cancel any pending single-click info modal so the user gets ONE
            % drill-in window (the dashboard), not info modal + dashboard.
            try
                if ~isempty(obj.SingleClickTimer_) && isvalid(obj.SingleClickTimer_)
                    if strcmp(obj.SingleClickTimer_.Running, 'on'); stop(obj.SingleClickTimer_); end
                    delete(obj.SingleClickTimer_);
                    obj.SingleClickTimer_ = [];
                end
            catch
            end
            try
                obj.openEventDashboard_(ev);
            catch
                % Drill-down failures must never crash the viewer.
            end
        end

        function openEventInfoModal_(obj, ev)
        %OPENEVENTINFOMODAL_ Open a uifigure showing event details with editable Notes.
        %   Card-style layout of labelled fields (Sensor, Threshold, Severity,
        %   Start, End, Duration, Peak) plus a textarea for Notes and Save/Close
        %   buttons. Edited Notes are persisted via EventStore.save() on Save.
        %   Single-click info modal is Gantt-bar only; Table CellSelectionCallback
        %   is intentionally not wired to avoid conflicting with column sorting.
            t = obj.Theme_;
            fig = uifigure( ...
                'Name',        sprintf('Event Info — %s', ev.SensorName), ...
                'Position',    [220 220 460 460], ...
                'Color',       t.WidgetBackground, ...
                'Resize',      'off');
            % Note: NOT WindowStyle='modal'. The Gantt fires the single-click
            % handler on the FIRST click of a double-click sequence (before
            % the OnDoubleClick path runs), so a modal info window would block
            % input to the dashboard that opens on the second click — leaving
            % every MATLAB window unresponsive until the user finds and
            % dismisses the modal. Keep this window non-blocking.

            grid = uigridlayout(fig, [10 2]);
            grid.RowHeight      = {28, 28, 28, 28, 28, 28, 28, 16, '1x', 36};
            grid.ColumnWidth    = {110, '1x'};
            grid.Padding        = [16 16 16 16];
            grid.RowSpacing     = 6;
            grid.ColumnSpacing  = 8;
            grid.BackgroundColor = t.WidgetBackground;

            evEnd = EventGanttCanvas.eventEndOrNow(ev, now);
            rows = { ...
                'Sensor',    ev.SensorName; ...
                'Threshold', sprintf('%s (%s @ %g)', ev.ThresholdLabel, ev.Direction, ev.ThresholdValue); ...
                'Severity',  obj.severityText_(ev.Severity); ...
                'Start',     obj.formatTime_(ev.StartTime); ...
                'End',       obj.formatTime_(ev.EndTime); ...
                'Duration',  obj.formatSliderSpan_(ev.StartTime, evEnd); ...
                'Peak',      sprintf('%g', obj.scalarOrNaN_(ev.PeakValue))};

            for r = 1:size(rows, 1)
                lblL = uilabel(grid);
                lblL.Layout.Row          = r;
                lblL.Layout.Column       = 1;
                lblL.Text                = [rows{r, 1}, ':'];
                lblL.FontColor           = t.PlaceholderTextColor;
                lblL.FontWeight          = 'bold';
                lblL.HorizontalAlignment = 'right';

                lblR = uilabel(grid);
                lblR.Layout.Row    = r;
                lblR.Layout.Column = 2;
                lblR.Text          = rows{r, 2};
                lblR.FontColor     = t.ForegroundColor;
            end

            % Notes section header (row 8 — narrower).
            notesLbl = uilabel(grid);
            notesLbl.Layout.Row    = 8;
            notesLbl.Layout.Column = [1 2];
            notesLbl.Text          = 'Notes:';
            notesLbl.FontColor     = t.PlaceholderTextColor;
            notesLbl.FontWeight    = 'bold';

            % Notes textarea (row 9 — flex).
            notesArea = uitextarea(grid);
            notesArea.Layout.Row      = 9;
            notesArea.Layout.Column   = [1 2];
            notesArea.Value           = ev.Notes;
            notesArea.Tag             = 'EventInfoNotes';
            notesArea.FontColor       = t.ForegroundColor;
            notesArea.BackgroundColor = t.WidgetBackground;

            % Button row (row 10).
            btnGrid = uigridlayout(grid, [1 3]);
            btnGrid.Layout.Row      = 10;
            btnGrid.Layout.Column   = [1 2];
            btnGrid.RowHeight       = {'1x'};
            btnGrid.ColumnWidth     = {'1x', 90, 90};
            btnGrid.Padding         = [0 0 0 0];
            btnGrid.ColumnSpacing   = 8;
            btnGrid.BackgroundColor = t.WidgetBackground;

            btnSave = uibutton(btnGrid, 'push');
            btnSave.Layout.Row      = 1;
            btnSave.Layout.Column   = 2;
            btnSave.Text            = 'Save';
            btnSave.BackgroundColor = t.WidgetBorderColor;
            btnSave.FontColor       = t.ForegroundColor;
            btnSave.ButtonPushedFcn = @(~, ~) obj.onEventInfoSave_(fig, ev, notesArea);

            btnClose = uibutton(btnGrid, 'push');
            btnClose.Layout.Row      = 1;
            btnClose.Layout.Column   = 3;
            btnClose.Text            = 'Close';
            btnClose.BackgroundColor = t.WidgetBackground;
            btnClose.FontColor       = t.ForegroundColor;
            btnClose.ButtonPushedFcn = @(~, ~) close(fig);
        end

        function onEventInfoSave_(obj, fig, ev, notesArea)
        %ONEVENTINFOSAVE_ Persist the edited Notes back to the EventStore.
            try
                ev.Notes = strjoin(cellstr(notesArea.Value), newline);
                try; obj.Store_.save(); catch; end
            catch
            end
            try; close(fig); catch; end
        end

        function s = severityText_(~, sev)
        %SEVERITYTEXT_ Format severity as 'N (Info|Warning|Alarm)'.
            switch double(sev)
                case 1, s = '1 (Info)';
                case 2, s = '2 (Warning)';
                case 3, s = '3 (Alarm)';
                otherwise, s = sprintf('%g', sev);
            end
        end

        function openEventDashboard_(obj, ev)
        %OPENEVENTDASHBOARD_ Spin up a new DashboardEngine showing the event's sensor.
        %   Resolves the event's tag, builds a single-widget DashboardEngine,
        %   renders it, and zooms the inner FastSense to the event window with
        %   10% padding either side. The new dashboard is fully independent from
        %   the viewer — closing it does not affect the viewer.
            tagKey = '';
            if ~isempty(ev.TagKeys); tagKey = ev.TagKeys{1}; end
            if isempty(tagKey); tagKey = ev.SensorName; end
            tag = [];
            try; tag = TagRegistry.get(tagKey); catch; end
            if isempty(tag) || ~isa(tag, 'Tag'); return; end

            evEnd = EventGanttCanvas.eventEndOrNow(ev, now);
            % 5% padding either side — gives the user a tiny breathing room
            % around the event without showing days of unrelated trace. The
            % previous max(..., 1) clamp gave open / very short events a
            % full day of padding regardless, which defeated the zoom.
            evDur = max(evEnd - ev.StartTime, 1/86400);   % at least 1 second wide
            pad   = 0.05 * evDur;
            xLim  = [ev.StartTime - pad, evEnd + pad];

            d = DashboardEngine(sprintf('Event — %s', ev.SensorName));
            % Position [1 1 24 12] = full 24-col × 12-row grid. This is the
            % same magic number openAdHocPlot uses for the companion's
            % "plot tag in detail" button — the auto-square-cell RowHeight
            % calculation lands at the right size to fill the canvas.
            d.addWidget('fastsense', ...
                'Title',            sprintf('%s @ %s', ev.SensorName, obj.formatTime_(ev.StartTime)), ...
                'Tag',              tag, ...
                'Position',         [1 1 24 12], ...
                'EventStore',       obj.Store_, ...
                'ShowEventMarkers', true);
            d.render();

            % Zoom the widget's X range to the event window. Use the widget
            % API rather than raw XLim — it sets IsSettingTime so the inner
            % FastSense's xlim-changed listener doesn't disable global-time
            % tracking. Fall back to direct XLim if the widget's API is
            % unavailable.
            try
                if ~isempty(d.Widgets)
                    w = d.Widgets{1};
                    if ismethod(w, 'setTimeRange')
                        w.setTimeRange(xLim(1), xLim(2));
                    elseif ~isempty(w.FastSenseObj)
                        fp = w.FastSenseObj;
                        if ~isempty(fp.hAxes) && isgraphics(fp.hAxes)
                            xlim(fp.hAxes, xLim);
                        end
                    end
                end
            catch
                % Zoom is nice-to-have; failure must not suppress the dashboard.
            end

            obj.bringFigureToFront_(d.hFigure);
        end

        function onTableRowSelectionChanged_(obj, evt)
        %ONTABLEROWSELECTIONCHANGED_ Track selected rows and update Plot Selected button.
        %   Accepts EITHER a struct with .Indices (legacy CellSelectionCallback)
        %   OR the uitable handle itself (modern SelectionChangedFcn — read
        %   t.Selection directly, which is a vector of row indices when
        %   SelectionType='row').
            try
                rows = [];
                if isa(evt, 'matlab.ui.control.Table')
                    rows = unique(evt.Selection);
                elseif isstruct(evt) && isfield(evt, 'Indices') && ~isempty(evt.Indices)
                    rows = unique(evt.Indices(:, 1));
                elseif ~isempty(obj.Table_) && isvalid(obj.Table_) && ...
                        isprop(obj.Table_, 'Selection') && ~isempty(obj.Table_.Selection)
                    rows = unique(obj.Table_.Selection);
                end
                obj.SelectedTableRows_ = rows(:)';
                n = numel(obj.SelectedTableRows_);
                if isempty(obj.PlotSelectedBtn_) || ~isvalid(obj.PlotSelectedBtn_); return; end
                if n == 0
                    obj.PlotSelectedBtn_.Text   = 'Plot Selected';
                    obj.PlotSelectedBtn_.Enable = 'off';
                else
                    obj.PlotSelectedBtn_.Text   = sprintf('Plot Selected (%d)', n);
                    obj.PlotSelectedBtn_.Enable = 'on';
                end
            catch
                % Selection tracking must never crash the viewer.
            end
        end

        function onPlotSelectedClicked_(obj)
        %ONPLOTSELECTEDCLICKED_ Open the multi-event dashboard for the selected rows.
            try
                if isempty(obj.SelectedTableRows_); return; end
                evs = obj.Table_.UserData;   % filtered Event array
                if isempty(evs); return; end
                rows = obj.SelectedTableRows_(obj.SelectedTableRows_ >= 1 & ...
                                              obj.SelectedTableRows_ <= numel(evs));
                if isempty(rows); return; end
                obj.openMultiEventDashboard_(evs(rows));
            catch
                % Drill-down failures must never crash the viewer.
            end
        end

        function openMultiEventDashboard_(obj, events)
        %OPENMULTIEVENTDASHBOARD_ Build a single dashboard with one FastSenseWidget per event.
        %   Each widget shows the event's sensor data zoomed to its own
        %   event window (with 5% padding either side). Widgets are stacked
        %   vertically in a single column, filling the canvas evenly.
            n = numel(events);
            if n == 0; return; end

            % Resolve all tags up front; skip events whose tag can't be found.
            tags  = cell(1, n);
            xLims = cell(1, n);
            keep  = false(1, n);
            for i = 1:n
                ev = events(i);
                tagKey = '';
                if ~isempty(ev.TagKeys); tagKey = ev.TagKeys{1}; end
                if isempty(tagKey); tagKey = ev.SensorName; end
                t = [];
                try; t = TagRegistry.get(tagKey); catch; end
                if isempty(t) || ~isa(t, 'Tag'); continue; end
                evEnd = EventGanttCanvas.eventEndOrNow(ev, now);
                evDur = max(evEnd - ev.StartTime, 1/86400);
                pad   = 0.05 * evDur;
                tags{i}  = t;
                xLims{i} = [ev.StartTime - pad, evEnd + pad];
                keep(i)  = true;
            end
            events = events(keep);
            tags   = tags(keep);
            xLims  = xLims(keep);
            n = numel(events);
            if n == 0; return; end

            d = DashboardEngine(sprintf('%d Events', n));
            % Tile N widgets into the 24-col × 12-row grid (same scheme as
            % openAdHocPlot). Single column, equal rows per widget; the last
            % widget absorbs any remainder so the bottom row of the grid is
            % filled.
            unitH = max(1, floor(12 / n));
            for i = 1:n
                ev = events(i);
                rowStart = (i - 1) * unitH + 1;
                if i == n
                    h = 12 - rowStart + 1;   % absorb remainder
                else
                    h = unitH;
                end
                d.addWidget('fastsense', ...
                    'Title',            sprintf('%s @ %s', ev.SensorName, obj.formatTime_(ev.StartTime)), ...
                    'Tag',              tags{i}, ...
                    'Position',         [1 rowStart 24 h], ...
                    'EventStore',       obj.Store_, ...
                    'ShowEventMarkers', true);
            end
            d.render();

            % Zoom each widget to its event window.
            try
                for i = 1:n
                    w = d.Widgets{i};
                    if ismethod(w, 'setTimeRange')
                        w.setTimeRange(xLims{i}(1), xLims{i}(2));
                    end
                end
            catch
                % Zoom is nice-to-have; failure must not suppress the dashboard.
            end

            obj.bringFigureToFront_(d.hFigure);
        end

        function bringFigureToFront_(~, hFig)
        %BRINGFIGURETOFRONT_ macOS focus workaround for figures spawned from a uifigure.
        %   On macOS, opening a classic figure from a uifigure callback can
        %   leave the new window behind without input focus, so clicks fall
        %   through OR don't register. Force the figure to the foreground via
        %   shg + figure(), then flush twice with a short pause to let the
        %   window-server finish raising the window before the next user
        %   click arrives. No-op if hFig is empty or non-graphics.
            try
                if ~isempty(hFig) && isgraphics(hFig)
                    set(hFig, 'WindowStyle', 'normal');
                    set(hFig, 'Visible',     'on');
                    drawnow;
                    figure(hFig);
                    shg;
                    pause(0.15);
                    figure(hFig);
                    drawnow;
                end
            catch
                % Foreground raise is best-effort; never let it crash the caller.
            end
        end

        function applyViewMode_(obj)
        %APPLYVIEWMODE_ Show/hide AxesPanel_/TablePanel_ based on obj.ViewMode.
            if isempty(obj.AxesPanel_) || isempty(obj.TablePanel_); return; end
            if strcmp(obj.ViewMode, 'gantt')
                obj.AxesPanel_.Visible  = 'on';
                obj.TablePanel_.Visible = 'off';
            else
                obj.AxesPanel_.Visible  = 'off';
                obj.TablePanel_.Visible = 'on';
            end
            % Keep the toolbar switch in sync (no-op if already matches).
            if ~isempty(obj.ViewSwitch_) && isvalid(obj.ViewSwitch_)
                want = 'Gantt';
                if strcmp(obj.ViewMode, 'table'); want = 'Table'; end
                if ~strcmp(obj.ViewSwitch_.Value, want)
                    obj.ViewSwitch_.Value = want;
                end
            end
        end

        function onViewSwitchChanged_(obj, sel)
        %ONVIEWSWITCHCHANGED_ React to user toggling the Gantt/Table switch.
            if strcmpi(sel, 'Table')
                obj.ViewMode = 'table';
            else
                obj.ViewMode = 'gantt';
            end
        end

        function updateTableData_(obj, events)
        %UPDATETABLEDATA_ Populate the uitable from a (filtered) Event array.
            if isempty(obj.Table_) || ~isvalid(obj.Table_); return; end
            if isempty(events)
                obj.Table_.Data = cell(0, 8);
                return;
            end
            n = numel(events);
            data = cell(n, 8);
            for i = 1:n
                ev = events(i);
                data{i, 1} = obj.formatTime_(ev.StartTime);
                data{i, 2} = obj.formatTime_(ev.EndTime);
                data{i, 3} = ev.SensorName;
                data{i, 4} = ev.ThresholdLabel;
                data{i, 5} = double(ev.Severity);
                if isnan(ev.EndTime)
                    data{i, 6} = NaN;
                else
                    data{i, 6} = ev.EndTime - ev.StartTime;
                end
                data{i, 7} = logical(ev.IsOpen);
                data{i, 8} = ev.Notes;
            end
            obj.Table_.Data     = data;
            obj.Table_.UserData = events;   % retain Event refs for click handlers
        end

        function onTableDoubleClicked_(obj, ev)
        %ONTABLEDOUBLECLICKED_ Drill down to SensorDetailPlot for the clicked row.
            try
                idx = [];
                if isstruct(ev) && isfield(ev, 'InteractionInformation')
                    info = ev.InteractionInformation;
                    if isstruct(info) && isfield(info, 'Row') && ~isempty(info.Row)
                        idx = info.Row(1);
                    end
                elseif isobject(ev) && isprop(ev, 'InteractionInformation')
                    info = ev.InteractionInformation;
                    if ~isempty(info) && isprop(info, 'Row')
                        idx = info.Row;
                        if ~isempty(idx); idx = idx(1); end
                    end
                end
                if isempty(idx) || idx < 1; return; end
                evs = obj.Table_.UserData;
                if isempty(evs) || idx > numel(evs); return; end
                obj.onEventDoubleClick_(evs(idx));
            catch
                % Drill-down must never crash the viewer.
            end
        end

        function onTableCellEdit_(obj, ev)
        %ONTABLECELLEDIT_ Persist Notes edits made in the uitable.
            try
                if ~isstruct(ev) || ~isfield(ev, 'Indices') || numel(ev.Indices) < 2; return; end
                row = ev.Indices(1); col = ev.Indices(2);
                if col ~= 8; return; end   % only Notes is editable
                evs = obj.Table_.UserData;
                if isempty(evs) || row > numel(evs); return; end
                evs(row).Notes = char(ev.NewData);
                try; obj.Store_.save(); catch; end
            catch
            end
        end

        function updateSliderReadouts_(obj)
        %UPDATESLIDERREADOUTS_ Refresh the [start | span | end] labels under the slider.
        %   Reads obj.TimeRange and writes formatted strings into the three
        %   uilabels. No-op if the labels haven't been built yet (i.e., during
        %   the part of buildFigure_ that runs before they exist).
            if isempty(obj.SliderReadoutStart_) || ~isvalid(obj.SliderReadoutStart_); return; end
            t1 = obj.TimeRange(1);
            t2 = obj.TimeRange(2);
            obj.SliderReadoutStart_.Text = obj.formatSliderTime_(t1);
            obj.SliderReadoutEnd_.Text   = obj.formatSliderTime_(t2);
            obj.SliderReadoutSpan_.Text  = obj.formatSliderSpan_(t1, t2);
        end

        function s = formatSliderTime_(~, t)
        %FORMATSLIDERTIME_ Format a datenum as 'yyyy-mm-dd HH:MM:SS' or char(8212) on bad input.
            if ~isfinite(t); s = char(8212); return; end
            try
                s = datestr(t, 'yyyy-mm-dd HH:MM:SS');
            catch
                s = sprintf('%g', t);
            end
        end

        function s = formatSliderSpan_(~, t1, t2)
        %FORMATSLIDERSPAN_ Humanize a time span (in datenum days) for display.
            if ~isfinite(t1) || ~isfinite(t2) || t2 <= t1
                s = char(8212); return;
            end
            spanDays = t2 - t1;
            if spanDays >= 1
                s = sprintf('%.1f days', spanDays);
            elseif spanDays >= 1/24
                s = sprintf('%.1f h', spanDays * 24);
            elseif spanDays >= 1/1440
                s = sprintf('%.1f min', spanDays * 1440);
            else
                s = sprintf('%.1f s', spanDays * 86400);
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
