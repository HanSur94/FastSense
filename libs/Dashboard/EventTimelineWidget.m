classdef EventTimelineWidget < DashboardWidget
%EVENTTIMELINEWIDGET Displays events as colored bars on a timeline.
%
%   Preferred: bind to an EventStore from the event detection system:
%     w = EventTimelineWidget('Title', 'Events', 'EventStoreObj', store);
%
%   Legacy (still supported for backwards compatibility):
%     w = EventTimelineWidget('Title', 'Events', 'EventFcn', @() getEvents());
%     w = EventTimelineWidget('Title', 'Events', 'Events', eventArray);
%
%   Events must be a struct array with fields:
%     startTime, endTime, label, color (optional)

    properties (Access = public)
        EventStoreObj = []  % EventStore handle — primary data source
        Events    = []      % struct array of events (legacy)
        EventFcn  = []      % function_handle returning events (legacy)
        FilterSensors = {}   % Cell array of Sensor names to filter
        FilterTagKey  = ''   % Tag-key filter (MONITOR-05 carrier: SensorName OR ThresholdLabel match)
        ColorSource = 'event' % 'event' or 'theme'
    end

    properties (SetAccess = private)
        hAxes     = []
        hBars     = {}
        IsSettingTime = false  % guard for programmatic vs user xlim change
    end

    methods
        function obj = EventTimelineWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 24 2];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.06 0.15 0.9 0.7], ...
                'FontName', fontName, ...
                'FontSize', theme.WidgetTitleFontSize - 1, ...
                'XColor', fgColor, ...
                'YColor', fgColor, ...
                'Color', theme.AxesColor, ...
                'YDir', 'reverse');
            hold(obj.hAxes, 'on');

            if ~isempty(obj.Title)
                title(obj.hAxes, obj.Title, ...
                    'Color', fgColor, ...
                    'FontSize', theme.WidgetTitleFontSize);
            end

            obj.refresh();

            % Listen for manual zoom/pan to detach from global time
            try
                addlistener(obj.hAxes, 'XLim', 'PostSet', @(~,~) obj.onXLimChanged());
            catch
            end
        end

        function setTimeRange(obj, tStart, tEnd)
            if ~obj.UseGlobalTime
                return;
            end
            if ~isempty(obj.hAxes) && ishandle(obj.hAxes)
                obj.IsSettingTime = true;
                xlim(obj.hAxes, [tStart tEnd]);
                obj.IsSettingTime = false;
            end
        end

        function [tMin, tMax] = getTimeRange(obj)
            tMin = inf; tMax = -inf;
            evts = obj.resolveEvents();
            if ~isempty(evts)
                for i = 1:numel(evts)
                    if evts(i).startTime < tMin, tMin = evts(i).startTime; end
                    if evts(i).endTime > tMax, tMax = evts(i).endTime; end
                end
            end
        end

        function t = getEventTimes(obj)
        %GETEVENTTIMES Event start times from resolveEvents (override).
        %   Mirrors the same filtering pipeline the widget uses to draw
        %   bars, so the time-slider overlay always matches what the
        %   widget itself renders.
            t = [];
            evts = obj.resolveEvents();
            if isempty(evts), return; end
            raw = [evts.startTime];           % resolveEvents emits lowercase
            if isempty(raw), return; end
            raw = raw(isfinite(raw));
            t = raw(:).';
        end

        function refresh(obj)
            events = obj.resolveEvents();

            if isempty(events) || isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            % Clear old bars
            for i = 1:numel(obj.hBars)
                if ishandle(obj.hBars{i})
                    delete(obj.hBars{i});
                end
            end
            obj.hBars = {};

            theme = obj.getTheme();
            defaultColors = [theme.StatusOkColor; theme.StatusWarnColor; theme.StatusAlarmColor];

            % Get unique labels for y-axis lanes
            labels = {};
            for i = 1:numel(events)
                if isfield(events(i), 'label') && ~isempty(events(i).label)
                    if ~any(strcmp(labels, events(i).label))
                        labels{end+1} = events(i).label;
                    end
                end
            end
            if isempty(labels)
                labels = {'Events'};
            end

            barHeight = 0.6;
            for i = 1:numel(events)
                ev = events(i);
                x = ev.startTime;
                w = ev.endTime - ev.startTime;
                if w <= 0
                    w = 1;
                end

                % Find lane
                lane = 1;
                if isfield(ev, 'label') && ~isempty(ev.label)
                    lane = find(strcmp(labels, ev.label), 1);
                    if isempty(lane)
                        lane = 1;
                    end
                end

                y = lane - barHeight/2;

                % Color
                if strcmp(obj.ColorSource, 'event') && isfield(ev, 'color') && ~isempty(ev.color)
                    c = ev.color;
                else
                    c = defaultColors(mod(i-1, size(defaultColors,1)) + 1, :);
                end

                hBar = fill(obj.hAxes, ...
                    [x, x+w, x+w, x], ...
                    [y, y, y+barHeight, y+barHeight], ...
                    c, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
                obj.hBars{end+1} = hBar;
            end

            set(obj.hAxes, 'YTick', 1:numel(labels), 'YTickLabel', labels);
            set(obj.hAxes, 'YLim', [0.3, numel(labels) + 0.7]);

            % Reformat time-axis ticks to HH:MM:SS / MM:SS for readability.
            obj.formatTimeAxis_(obj.hAxes);
        end

        function t = getType(~)
            t = 'timeline';
        end

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                nEvents = 0;
                if ~isempty(obj.Events)
                    nEvents = numel(obj.Events);
                elseif ~isempty(obj.EventStoreObj)
                    try nEvents = numel(obj.EventStoreObj.Events); catch, end
                end
                if nEvents > 0
                    info = sprintf('%d events', nEvents);
                else
                    info = '[-- timeline --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.filterSensors = obj.FilterSensors;
            s.colorSource = obj.ColorSource;
            if ~isempty(obj.FilterTagKey)
                s.filterTagKey = obj.FilterTagKey;
            end
            if ~isempty(obj.EventStoreObj)
                s.source = struct('type', 'eventstore', ...
                    'path', obj.EventStoreObj.FilePath);
            elseif ~isempty(obj.EventFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.EventFcn));
            elseif ~isempty(obj.Events)
                s.source = struct('type', 'static', 'events', obj.Events);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = EventTimelineWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'description')
                obj.Description = s.description;
            end
            if isfield(s, 'filterSensors')
                obj.FilterSensors = s.filterSensors;
            end
            if isfield(s, 'filterTagKey')
                obj.FilterTagKey = s.filterTagKey;
            end
            if isfield(s, 'colorSource')
                obj.ColorSource = s.colorSource;
            end
            if isfield(s, 'source')
                if strcmp(s.source.type, 'eventstore') && isfield(s.source, 'path')
                    obj.EventStoreObj = EventStore(s.source.path);
                elseif strcmp(s.source.type, 'callback')
                    obj.EventFcn = str2func(s.source.function);
                elseif strcmp(s.source.type, 'static') && isfield(s.source, 'events')
                    obj.Events = s.source.events;
                end
            end
        end
    end

    methods (Access = private)
        function evts = resolveEvents(obj)
        %RESOLVEEVENTS Get events from the best available source.
        %   Priority: EventStoreObj > EventFcn > Events (static/Event objects).
        %   When FilterTagKey is set AND an EventStore is bound, events are
        %   pulled via EventStore.getEventsForTag(tagKey) using the
        %   MONITOR-05 carrier pattern (SensorName OR ThresholdLabel match).
        %   Phase 1010 (EVENT-01) may migrate to Event.TagKeys.
            evts = [];
            if ~isempty(obj.EventStoreObj)
                if ~isempty(obj.FilterTagKey)
                    raw = obj.EventStoreObj.getEventsForTag(obj.FilterTagKey);
                    evts = obj.eventObjectsToStructs(raw);
                else
                    evts = obj.eventStoreToStructs();
                end
            elseif ~isempty(obj.EventFcn)
                evts = obj.EventFcn();
            elseif ~isempty(obj.Events)
                % Accept both Event objects and plain structs
                if isa(obj.Events, 'Event') || ...
                        (isstruct(obj.Events) && isfield(obj.Events, 'StartTime'))
                    evts = obj.eventObjectsToStructs(obj.Events);
                else
                    evts = obj.Events;
                end
            end
            % Filter by sensor name if FilterSensors is set
            if ~isempty(obj.FilterSensors) && ~isempty(evts)
                mask = false(1, numel(evts));
                for i = 1:numel(evts)
                    for j = 1:numel(obj.FilterSensors)
                        if ~isempty(strfind(evts(i).label, obj.FilterSensors{j}))
                            mask(i) = true;
                            break;
                        end
                    end
                end
                evts = evts(mask);
            end
        end

        function evts = eventStoreToStructs(obj)
        %EVENTSTORETOSTRUCTS Convert Event objects from EventStore to
        %   the struct format used for rendering (startTime, endTime, label, color).
            evts = struct('startTime', {}, 'endTime', {}, 'label', {}, 'color', {});
            raw = obj.EventStoreObj.getEvents();
            if isempty(raw), return; end

            theme = obj.getTheme();
            alarmColor = theme.StatusAlarmColor;
            warnColor  = theme.StatusWarnColor;

            for i = 1:numel(raw)
                ev = raw(i);
                lbl = ev.SensorName;
                if ~isempty(ev.ThresholdLabel)
                    lbl = [ev.SensorName ' — ' ev.ThresholdLabel];
                end
                % Colour routing is driven by the numeric Severity field
                % (1=ok/info, 2=warn, 3=alarm; see Event.m EVENT-04) with
                % a ThresholdLabel keyword fallback for events authored
                % before Severity existed.
                clr = warnColor;
                if isfield(ev, 'Severity') && ~isempty(ev.Severity) && ev.Severity >= 3
                    clr = alarmColor;
                elseif ~isfield(ev, 'Severity') && ~isempty(ev.ThresholdLabel) && ...
                        ~isempty(strfind(lower(ev.ThresholdLabel), 'alarm'))
                    clr = alarmColor;
                end
                evts(end+1) = struct('startTime', ev.StartTime, ...
                    'endTime', ev.EndTime, 'label', lbl, 'color', clr); %#ok<AGROW>
            end
        end

        function evts = eventObjectsToStructs(obj, eventObjs)
        %EVENTOBJECTSTOSTRUCTS Convert Event objects to rendering structs.
        %   Accepts an array of Event objects (or structs with StartTime/
        %   EndTime fields) and converts them to the struct format used
        %   for rendering: startTime, endTime, label, color.
            evts = struct('startTime', {}, 'endTime', {}, 'label', {}, 'color', {});
            if isempty(eventObjs), return; end

            theme = obj.getTheme();
            alarmColor = theme.StatusAlarmColor;
            warnColor  = theme.StatusWarnColor;

            for i = 1:numel(eventObjs)
                ev = eventObjs(i);
                if isa(ev, 'Event')
                    lbl = ev.SensorName;
                    if ~isempty(ev.ThresholdLabel)
                        lbl = [ev.SensorName ' — ' ev.ThresholdLabel];
                    end
                    if ~isempty(strfind(lower(ev.ThresholdLabel), 'alarm'))
                        clr = alarmColor;
                    else
                        clr = warnColor;
                    end
                    evts(end+1) = struct('startTime', ev.StartTime, ...
                        'endTime', ev.EndTime, 'label', lbl, 'color', clr); %#ok<AGROW>
                else
                    % Struct with StartTime/EndTime (PascalCase)
                    lbl = '';
                    if isfield(ev, 'SensorName'), lbl = ev.SensorName; end
                    if isfield(ev, 'ThresholdLabel') && ~isempty(ev.ThresholdLabel)
                        lbl = [lbl ' — ' ev.ThresholdLabel];
                    end
                    clr = warnColor;
                    if isfield(ev, 'ThresholdLabel') && ~isempty(strfind(lower(ev.ThresholdLabel), 'alarm'))
                        clr = alarmColor;
                    end
                    evts(end+1) = struct('startTime', ev.StartTime, ...
                        'endTime', ev.EndTime, 'label', lbl, 'color', clr); %#ok<AGROW>
                end
            end
        end

        function onXLimChanged(obj)
            if ~obj.IsSettingTime
                obj.UseGlobalTime = false;
            end
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

    end
end
