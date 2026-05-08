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
        %REFRESH Pull from store, apply filters, redraw Gantt. No-op if figure gone.
            if isempty(obj.hFigure) || ~isgraphics(obj.hFigure); return; end
            evs = obj.Store_.getEvents();
            if isempty(evs); evs = Event.empty; end
            filtered = CompanionEventViewer.applyFilters( ...
                evs, obj.SelectedTagKeys, obj.SeverityMask, obj.OpenOnly, obj.TimeRange);
            obj.Canvas_.draw(filtered, obj.Theme_);
        end

        function c = getCanvasForTest_(obj)
        %GETCANVASFORTEST_ Test-only accessor for the canvas helper.
            c = obj.Canvas_;
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
                case '1h',  span = 1/24;
                case '24h', span = 1;
                case '7d',  span = 7;
                case 'all', span = [];   % full extent — resolved below
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
        end

        function buildFigure_(obj)
        %BUILDFIGURE_ Create the classic figure with three uipanels + Gantt axes.
            t = obj.Theme_;
            obj.hFigure = figure( ...
                'Name',            'FastSense — Event Viewer', ...
                'NumberTitle',     'off', ...
                'Color',           t.DashboardBackground, ...
                'Position',        [120 120 1100 600], ...
                'CloseRequestFcn', @(~,~) obj.close(), ...
                'Visible',         'on');

            obj.FilterPanel_ = uipanel('Parent', obj.hFigure, ...
                'Units',           'normalized', ...
                'Position',        [0 0.85 1 0.15], ...
                'BackgroundColor', t.WidgetBackground, ...
                'BorderType',      'none');
            obj.AxesPanel_ = uipanel('Parent', obj.hFigure, ...
                'Units',           'normalized', ...
                'Position',        [0 0.20 1 0.65], ...
                'BackgroundColor', t.WidgetBackground, ...
                'BorderType',      'none');
            obj.SliderPanel_ = uipanel('Parent', obj.hFigure, ...
                'Units',           'normalized', ...
                'Position',        [0 0 1 0.20], ...
                'BackgroundColor', t.WidgetBackground, ...
                'BorderType',      'none');

            ax = axes('Parent', obj.AxesPanel_, ...
                'Units',    'normalized', ...
                'Position', [0.10 0.10 0.85 0.85], ...
                'Color',    t.WidgetBackground, ...
                'XColor',   t.ForegroundColor, ...
                'YColor',   t.ForegroundColor);
            obj.Canvas_ = EventGanttCanvas(ax, t);
        end
    end
end
