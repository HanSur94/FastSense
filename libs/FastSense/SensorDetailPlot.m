classdef SensorDetailPlot < handle
    % SensorDetailPlot  Two-panel sensor overview+detail plot with interactive navigator.
    %
    %   sdp = SensorDetailPlot(tag)
    %   sdp = SensorDetailPlot(tag, Name, Value, ...)
    %
    %   Name-Value Options:
    %     'Theme'              - FastSense theme (default: 'default')
    %     'NavigatorHeight'    - Fraction 0-1 for navigator (default: 0.20)
    %     'ShowThresholds'     - Show thresholds in main plot (default: true)
    %     'ShowThresholdBands' - Show threshold bands in navigator (default: true)
    %     'Events'             - EventStore or Event array (default: [])
    %     'ShowEventLabels'    - Reserved, no effect (default: false)
    %     'Parent'             - uipanel handle for embedding (default: [])
    %     'Title'              - Plot title (default: tag.Name)
    %     'XType'              - 'numeric' or 'datenum' (default: 'numeric')

    properties (SetAccess = private)
        TagRef              % Tag handle (v2.0 path)
        MainPlot            % FastSense instance for upper panel
        NavigatorPlot       % FastSense instance for lower panel
        NavigatorOverlayObj % NavigatorOverlay instance
    end

    properties (SetAccess = private, GetAccess = public)
        NavigatorHeight     % Fraction of total height for navigator
        ShowThresholds      % Show thresholds in main plot
        ShowThresholdBands  % Show threshold bands in navigator
        Events              % Event array (resolved from EventStore or direct)
        ShowEventLabels     % Reserved, no effect
        Theme               % Theme string or struct
        Title               % Plot title
        XType               % 'numeric' or 'datenum'
        IsRendered          % Whether render() has been called
    end

    properties (Access = private)
        ParentPanel         % External uipanel (if embedded)
        hFig                % Figure handle (if standalone)
        hMainAxes           % Axes for main plot
        hNavAxes            % Axes for navigator
        IsPropagating       % Guard against infinite sync loops
        XLimListener        % Listener for main axes XLim changes
        OwnsFigure          % True if we created the figure
    end

    methods
        function obj = SensorDetailPlot(tag, varargin)
            % Accept Tag (v2.0) only.
            % Tag class is the abstract base — uses isa(x, 'Tag'), NOT
            % isa-on-subclass-name (Pitfall 1).
            if ~isa(tag, 'Tag')
                error('SensorDetailPlot:invalidInput', ...
                    'First argument must be a Tag object; got %s.', ...
                    class(tag));
            end
            obj.TagRef = tag;
            % Soft validation: warn on empty data instead of hard error.
            try
                [xChk, ~] = tag.getXY();
                if isempty(xChk)
                    warning('SensorDetailPlot:emptyTag', ...
                        'Tag ''%s'' returned empty X — plot will render with no data.', ...
                        tag.Key);
                end
            catch ex
                warning('SensorDetailPlot:tagGetXYFailed', ...
                    'Tag ''%s'' getXY threw: %s', tag.Key, ex.message);
            end

            obj.IsRendered = false;
            obj.IsPropagating = false;
            obj.OwnsFigure = false;

            % Load cached defaults (same pattern as FastSense / FastSenseGrid)
            cfg = getDefaults();

            % Parse options via standard parseOpts
            conDefaults.Theme = [];
            conDefaults.NavigatorHeight = cfg.NavigatorHeight;
            conDefaults.ShowThresholds = true;
            conDefaults.ShowThresholdBands = true;
            conDefaults.Events = [];
            conDefaults.ShowEventLabels = false;
            conDefaults.Parent = [];
            % Title default: Tag.Name/Key.
            conDefaults.Title = obj.TagRef.Name;
            if isempty(conDefaults.Title), conDefaults.Title = obj.TagRef.Key; end
            conDefaults.XType = 'numeric';
            [opts, ~] = parseOpts(conDefaults, varargin);

            % Inherit theme from parent panel (set by FastSenseGrid.tilePanel)
            % when no explicit Theme was given.
            if isempty(opts.Theme) && ~isempty(opts.Parent)
                try
                    ud = get(opts.Parent, 'UserData');
                    if isstruct(ud) && isfield(ud, 'FastSenseTheme')
                        opts.Theme = ud.FastSenseTheme;
                    end
                catch
                end
            end
            obj.Theme = resolveTheme(opts.Theme, cfg.Theme);
            obj.NavigatorHeight = opts.NavigatorHeight;
            obj.ShowThresholds = opts.ShowThresholds;
            obj.ShowThresholdBands = opts.ShowThresholdBands;
            obj.ShowEventLabels = opts.ShowEventLabels;
            obj.ParentPanel = opts.Parent;
            obj.Title = opts.Title;
            obj.XType = opts.XType;

            % Resolve events
            obj.Events = obj.resolveEvents(opts.Events);
        end

        function render(obj)
            if obj.IsRendered
                error('SensorDetailPlot:alreadyRendered', ...
                    'SensorDetailPlot has already been rendered.');
            end

            % Create layout
            obj.createLayout();

            % Resolve the (X, Y) vectors + display name from Tag.
            [xVec, yVec] = obj.TagRef.getXY();
            displayName = obj.TagRef.Name;
            if isempty(displayName); displayName = obj.TagRef.Key; end

            % Create main FastSense
            obj.MainPlot = FastSense('Parent', obj.hMainAxes, 'Theme', obj.Theme);
            obj.MainPlot.addLine(xVec, yVec, ...
                'DisplayName', displayName, 'XType', obj.XType);

            % Render main plot
            obj.MainPlot.render();

            % Hide main plot x-tick labels — navigator provides the shared x-axis
            set(obj.hMainAxes, 'XTickLabel', []);
            xlabel(obj.hMainAxes, '');

            % Set title with theme formatting (matches FastSenseGrid.setTileTitle)
            if ~isempty(obj.Title)
                title(obj.hMainAxes, obj.Title, ...
                    'FontSize', obj.Theme.TitleFontSize, ...
                    'Color', obj.Theme.ForegroundColor);
            end

            % Create navigator FastSense — uses the same (X, Y) vectors
            % resolved above via Tag.getXY().
            obj.NavigatorPlot = FastSense('Parent', obj.hNavAxes, 'Theme', obj.Theme);
            obj.NavigatorPlot.addLine(xVec, yVec, ...
                'DisplayName', displayName, 'XType', obj.XType);

            % Add threshold bands to navigator (reserved for future).
            if obj.ShowThresholdBands
                obj.addNavigatorThresholdBands();
            end

            % Render navigator
            obj.NavigatorPlot.render();

            % Strip navigator decoration — it's a minimal overview strip
            set(obj.hNavAxes, 'YTickLabel', []);
            ylabel(obj.hNavAxes, '');
            title(obj.hNavAxes, '');

            % Fix navigator axes limits (uses mode-independent xVec/yVec).
            xFull = [min(xVec), max(xVec)];
            yRange = [min(yVec), max(yVec)];
            yPad = (yRange(2) - yRange(1)) * 0.05;
            if yPad == 0; yPad = 1; end
            set(obj.hNavAxes, 'XLim', xFull, 'YLim', [yRange(1)-yPad, yRange(2)+yPad]);
            set(obj.hNavAxes, 'XLimMode', 'manual', 'YLimMode', 'manual');

            % Disable all interactive tools on navigator
            disableDefaultInteractivity(obj.hNavAxes);
            obj.hNavAxes.Interactions = [];
            obj.hNavAxes.Toolbar = [];
            zoom(obj.hNavAxes, 'off');
            pan(obj.hNavAxes, 'off');
            rotate3d(obj.hNavAxes, 'off');

            % Re-apply datetime tick formatting after all nav axes
            % modifications to guarantee it matches normal FastSense tiles.
            % Sync main axes XTick to match, keeping labels suppressed.
            if strcmp(obj.XType, 'datenum')
                obj.formatDatetimeTicks(obj.hNavAxes);
                set(obj.hMainAxes, 'XTick', get(obj.hNavAxes, 'XTick'));
                set(obj.hMainAxes, 'XTickLabel', []);
            end

            % Add event overlays
            if ~isempty(obj.Events)
                obj.addEventShading();
                obj.addEventVerticalLines();
            end

            % Create navigator overlay
            obj.NavigatorOverlayObj = NavigatorOverlay(obj.hNavAxes);
            initRange = get(obj.hMainAxes, 'XLim');
            obj.NavigatorOverlayObj.setRange(initRange(1), initRange(2));

            % Wire bidirectional sync
            obj.NavigatorOverlayObj.OnRangeChanged = @(xMin, xMax) obj.onNavigatorRangeChanged(xMin, xMax);

            % Wire sync: main axes → navigator overlay
            % Use multiple mechanisms for reliable interactive feedback:

            % 1. Ruler LimitsChangedFcn (R2021a+) — fires on zoom, pan, restore view
            try
                obj.hMainAxes.XAxis.LimitsChangedFcn = @(~,~) obj.onMainXLimChanged();
            catch
            end

            % 2. Zoom/Pan ActionPostCallback — backup for interactive actions
            hFigForSync = ancestor(obj.hMainAxes, 'figure');
            if ~isempty(hFigForSync)
                try
                    set(zoom(hFigForSync), 'ActionPostCallback', ...
                        @(~, evd) obj.onFigureZoomPan(evd));
                    set(pan(hFigForSync), 'ActionPostCallback', ...
                        @(~, evd) obj.onFigureZoomPan(evd));
                catch
                end
            end

            % 3. XLim PostSet listener — fires on programmatic XLim changes
            try
                obj.XLimListener = addlistener(obj.hMainAxes, 'XLim', 'PostSet', ...
                    @(s,e) obj.onMainXLimChanged());
            catch
            end

            % Deferred tick refresh: datetick was called during render()
            % before the dock layout finalized axes pixel widths, causing
            % wrong tick density. A one-shot timer re-applies datetick
            % after the layout settles.
            if strcmp(obj.XType, 'datenum')
                start(timer('TimerFcn', @(~,~) obj.refreshDatetimeTicks(), ...
                    'StartDelay', 0.1, 'ExecutionMode', 'singleShot', ...
                    'Tag', 'SDP_TickRefresh'));
            end

            % Set figure visible if standalone
            if obj.OwnsFigure
                set(obj.hFig, 'Visible', 'on');
                set(obj.hFig, 'CloseRequestFcn', @(~,~) obj.onFigureClose());
            end

            obj.IsRendered = true;
        end

        function setZoomRange(obj, xMin, xMax)
            if ~obj.IsRendered; return; end
            obj.IsPropagating = true;
            set(obj.hMainAxes, 'XLim', [xMin, xMax]);
            obj.NavigatorOverlayObj.setRange(xMin, xMax);
            obj.IsPropagating = false;
        end

        function [xMin, xMax] = getZoomRange(obj)
            if ~obj.IsRendered
                xMin = []; xMax = [];
                return;
            end
            lim = get(obj.hMainAxes, 'XLim');
            xMin = lim(1);
            xMax = lim(2);
        end

        function delete(obj)
            % Clear LimitsChangedFcn
            if ~isempty(obj.hMainAxes) && ishandle(obj.hMainAxes)
                try
                    obj.hMainAxes.XAxis.LimitsChangedFcn = '';
                catch
                end
            end

            % Remove XLim listener
            if ~isempty(obj.XLimListener) && isvalid(obj.XLimListener)
                delete(obj.XLimListener);
            end

            % Delete navigator overlay
            if ~isempty(obj.NavigatorOverlayObj) && isvalid(obj.NavigatorOverlayObj)
                delete(obj.NavigatorOverlayObj);
            end

            % Close figure if we own it (guard against double-delete
            % when triggered from CloseRequestFcn)
            if obj.OwnsFigure && ~isempty(obj.hFig) && ishandle(obj.hFig)
                set(obj.hFig, 'CloseRequestFcn', 'closereq');
                delete(obj.hFig);
                obj.hFig = [];
            end
        end
    end

    methods (Access = private)
        function createLayout(obj)
            if ~isempty(obj.ParentPanel)
                % Embedded mode: inherit parent's background (set by tilePanel)
                container = obj.ParentPanel;
                obj.OwnsFigure = false;
            else
                % Standalone mode: create figure
                obj.hFig = figure('Visible', 'off', 'Name', obj.Title, ...
                    'NumberTitle', 'off', 'Position', [100 100 900 600], ...
                    'Color', obj.Theme.Background);
                container = obj.hFig;
                obj.OwnsFigure = true;
            end

            % Use Position + innerposition for both modes so the plot
            % area width matches normal FastSense tiles exactly.
            % In embedded mode add vertical margins inside the panel for
            % the title (top) and navigator X-tick labels (bottom).
            navFrac = obj.NavigatorHeight;

            if ~isempty(obj.ParentPanel)
                % Vertical margins inside the panel so the title and
                % navigator X-tick labels are not clipped.
                topM = 0.06;   % room for title above main axes
                botM = 0.10;   % room for nav X-tick labels below
            else
                topM = 0;
                botM = 0;
            end

            innerH = 1 - topM - botM;
            navH   = navFrac * innerH;
            mainH  = innerH - navH;

            % Main axes: full width, top portion
            obj.hMainAxes = axes('Parent', container, ...
                'Units', 'normalized', ...
                'Position', [0, botM + navH, 1, mainH], ...
                'Color', obj.Theme.AxesColor);
            try
                set(obj.hMainAxes, 'PositionConstraint', 'innerposition');
            catch
                set(obj.hMainAxes, 'ActivePositionProperty', 'position');
            end

            % Navigator axes: full width, bottom strip
            obj.hNavAxes = axes('Parent', container, ...
                'Units', 'normalized', ...
                'Position', [0, botM, 1, navH], ...
                'Color', obj.Theme.AxesColor);
            try
                set(obj.hNavAxes, 'PositionConstraint', 'innerposition');
            catch
                set(obj.hNavAxes, 'ActivePositionProperty', 'position');
            end
        end

        function events = resolveEvents(~, eventsInput)
            if isempty(eventsInput)
                events = [];
                return;
            end

            if isa(eventsInput, 'EventStore')
                events = eventsInput.getEvents();
            elseif isa(eventsInput, 'Event')
                events = eventsInput;
            else
                error('SensorDetailPlot:invalidEvents', ...
                    'Events must be an EventStore or Event array.');
            end
        end

        function addNavigatorThresholdBands(~)
            % Navigator threshold bands are not yet supported for Tag-bound
            % plots. Reserved for future enhancement.
        end

        function addEventShading(obj)
            % Add event shaded regions to main plot
            if isempty(obj.Events); return; end

            % Filter events for this sensor
            sensorEvents = obj.filterEventsForTag(obj.Events);
            if isempty(sensorEvents); return; end

            yLim = get(obj.hMainAxes, 'YLim');
            wasHeld = ishold(obj.hMainAxes);
            hold(obj.hMainAxes, 'on');

            for i = 1:numel(sensorEvents)
                ev = sensorEvents(i);
                [color, alpha] = obj.eventColor(ev);

                % Create shaded patch
                xVerts = [ev.StartTime ev.StartTime ev.EndTime ev.EndTime];
                yVerts = [yLim(1) yLim(2) yLim(2) yLim(1)];

                hPatch = patch(obj.hMainAxes, xVerts, yVerts, color, ...
                    'FaceAlpha', alpha, 'EdgeColor', 'none', ...
                    'HandleVisibility', 'off');

                % Attach metadata to UserData
                ud = struct();
                ud.ThresholdLabel = ev.ThresholdLabel;
                ud.Direction = ev.Direction;
                ud.Duration = ev.Duration;
                ud.PeakValue = ev.PeakValue;
                ud.MeanValue = ev.MeanValue;
                ud.MinValue = ev.MinValue;
                ud.MaxValue = ev.MaxValue;
                ud.RmsValue = ev.RmsValue;
                ud.StdValue = ev.StdValue;
                ud.NumPoints = ev.NumPoints;
                set(hPatch, 'UserData', ud);
            end

            % Restore hold state
            if ~wasHeld; hold(obj.hMainAxes, 'off'); end
        end

        function addEventVerticalLines(obj)
            % Add event vertical lines to navigator
            if isempty(obj.Events); return; end

            sensorEvents = obj.filterEventsForTag(obj.Events);
            if isempty(sensorEvents); return; end

            yLim = get(obj.hNavAxes, 'YLim');
            hold(obj.hNavAxes, 'on');

            for i = 1:numel(sensorEvents)
                ev = sensorEvents(i);
                [color, ~] = obj.eventColor(ev);

                line(obj.hNavAxes, [ev.StartTime ev.StartTime], yLim, ...
                    'Color', color, 'LineWidth', 1, ...
                    'HandleVisibility', 'off');
            end

            hold(obj.hNavAxes, 'off');
        end

        function filtered = filterEventsForTag(obj, events)
            if isempty(events)
                filtered = events;
                return;
            end
            key = obj.TagRef.Key;
            mask = strcmp({events.SensorName}, key);
            filtered = events(mask);
        end

        function [color, alpha] = eventColor(~, ev)
            label = ev.ThresholdLabel;
            isEscalated = ~isempty(regexpi(label, '(HH|LL)', 'once'));

            if strcmp(ev.Direction, 'upper')
                if isEscalated
                    color = [0.9 0.1 0.1];   % red
                    alpha = 0.15;
                else
                    color = [1 0.6 0.2];     % orange
                    alpha = 0.12;
                end
            elseif strcmp(ev.Direction, 'lower')
                if isEscalated
                    color = [0.1 0.1 0.7];   % dark blue
                    alpha = 0.15;
                else
                    color = [0.4 0.6 1];     % light blue
                    alpha = 0.12;
                end
            else
                color = [0.5 0.5 0.5];       % fallback gray
                alpha = 0.10;
            end
        end

        function onNavigatorRangeChanged(obj, xMin, xMax)
            if obj.IsPropagating; return; end
            obj.IsPropagating = true;
            if ishandle(obj.hMainAxes)
                set(obj.hMainAxes, 'XLim', [xMin, xMax]);
            end
            obj.IsPropagating = false;
        end

        function onFigureZoomPan(obj, evd)
            % Zoom/Pan ActionPostCallback handler — filter by axes
            if obj.IsPropagating; return; end
            try
                if evd.Axes == obj.hMainAxes
                    obj.onMainXLimChanged();
                end
            catch
            end
        end

        function onMainXLimChanged(obj)
            if obj.IsPropagating; return; end
            if ~ishandle(obj.hMainAxes); return; end
            obj.IsPropagating = true;
            lim = get(obj.hMainAxes, 'XLim');
            if ~isempty(obj.NavigatorOverlayObj) && isvalid(obj.NavigatorOverlayObj)
                obj.NavigatorOverlayObj.setRange(lim(1), lim(2));
            end

            % Re-apply correct tick density and suppress labels after
            % FastSense's onXLimChanged calls datetick (which re-sets
            % XTick and XTickLabel with wrong density).
            if strcmp(obj.XType, 'datenum')
                obj.formatDatetimeTicks(obj.hMainAxes);
            end
            set(obj.hMainAxes, 'XTickLabel', []);

            obj.IsPropagating = false;
        end

        function onFigureClose(obj)
            delete(obj);
        end

        function refreshDatetimeTicks(obj)
            %REFRESHDATETIMETICKS Re-apply datetime ticks after layout settles.
            %   Called by a one-shot timer to fix tick density once the
            %   axes have their final pixel widths.
            try
                if ~obj.IsRendered; return; end
                % Force layout computation so axes have correct pixel sizes
                drawnow;
                if ishandle(obj.hNavAxes)
                    obj.formatDatetimeTicks(obj.hNavAxes);
                end
                % Sync main axes XTick to navigator and suppress labels
                if ishandle(obj.hMainAxes) && ishandle(obj.hNavAxes)
                    set(obj.hMainAxes, 'XTick', get(obj.hNavAxes, 'XTick'));
                    set(obj.hMainAxes, 'XTickLabel', []);
                end
            catch
            end
        end

        function formatDatetimeTicks(~, ax)
            %FORMATEDATETIMETICKS Apply datetime tick formatting matching FastSense.
            %   Computes nice datetime tick positions and labels directly,
            %   matching the format selection in FastSense.updateDatetimeTicks.
            %   Avoids datetick() which produces inconsistent tick density
            %   for axes embedded in uipanels.
            if ~ishandle(ax); return; end
            try
                xl = get(ax, 'XLim');
                span = diff(xl);  % in days (datenum units)

                % Choose interval and format based on span (same thresholds
                % as FastSense.updateDatetimeTicks)
                if span > 365
                    fmt = 'yyyy mmm dd HH:MM';
                    % Round to months
                    step = 30;
                elseif span > 30
                    fmt = 'yyyy mmm dd HH:MM';
                    step = 7;
                elseif span > 1
                    fmt = 'yyyy mmm dd HH:MM';
                    step = max(1, round(span / 8));
                elseif span > 1/24
                    fmt = 'HH:MM';
                    % Pick nice hour-fraction intervals: target 6-12 ticks
                    nTicks = round(span * 24 * 2);  % 30-min ticks
                    if nTicks > 12
                        step = 1/24;      % 1 hour
                    elseif nTicks > 6
                        step = 1/48;      % 30 min
                    else
                        step = 1/96;      % 15 min
                    end
                elseif span > 1/1440
                    fmt = 'HH:MM';
                    mins = span * 1440;
                    if mins > 30
                        step = 10/1440;   % 10 min
                    elseif mins > 10
                        step = 5/1440;    % 5 min
                    else
                        step = 1/1440;    % 1 min
                    end
                else
                    fmt = 'HH:MM:SS';
                    step = max(span / 8, 1/86400);  % target ~8 ticks
                end

                % Compute tick positions snapped to interval
                t0 = ceil(xl(1) / step) * step;
                t1 = xl(2);
                ticks = t0:step:t1;

                % Ensure we have at least 2 ticks
                if numel(ticks) < 2
                    ticks = linspace(xl(1), xl(2), 5);
                end

                % Format labels
                labels = datestr(ticks, fmt); %#ok<DATST>

                set(ax, 'XTick', ticks, 'XTickLabel', labels, ...
                    'XTickMode', 'manual', 'XTickLabelMode', 'manual');
            catch
                % Fallback to datetick
                try
                    datetick(ax, 'x', 'keeplimits');
                catch
                end
            end
        end

    end
end
