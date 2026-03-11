classdef SensorDetailPlot < handle
    % SensorDetailPlot  Two-panel sensor overview+detail plot with interactive navigator.
    %
    %   sdp = SensorDetailPlot(sensor)
    %   sdp = SensorDetailPlot(sensor, Name, Value, ...)
    %
    %   Name-Value Options:
    %     'Theme'              - FastPlot theme (default: 'default')
    %     'NavigatorHeight'    - Fraction 0-1 for navigator (default: 0.20)
    %     'ShowThresholds'     - Show thresholds in main plot (default: true)
    %     'ShowThresholdBands' - Show threshold bands in navigator (default: true)
    %     'Events'             - EventStore or Event array (default: [])
    %     'ShowEventLabels'    - Reserved, no effect (default: false)
    %     'Parent'             - uipanel handle for embedding (default: [])
    %     'Title'              - Plot title (default: sensor.Name)

    properties (SetAccess = private)
        Sensor              % Sensor object
        MainPlot            % FastPlot instance for upper panel
        NavigatorPlot       % FastPlot instance for lower panel
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
        IsRendered          % Whether render() has been called
    end

    properties (Access = private)
        ParentPanel         % External uipanel (if embedded)
        hFig                % Figure handle (if standalone)
        hMainPanel          % uipanel for main plot
        hNavPanel           % uipanel for navigator
        hMainAxes           % Axes in main panel
        hNavAxes            % Axes in navigator panel
        IsPropagating       % Guard against infinite sync loops
        XLimListener        % Listener for main axes XLim changes
        OwnsFigure          % True if we created the figure
    end

    methods
        function obj = SensorDetailPlot(sensor, varargin)
            % Validate sensor
            assert(isa(sensor, 'Sensor'), 'SensorDetailPlot:invalidInput', ...
                'First argument must be a Sensor object.');

            obj.Sensor = sensor;
            obj.IsRendered = false;
            obj.IsPropagating = false;
            obj.OwnsFigure = false;

            % Parse options
            p = inputParser;
            p.addParameter('Theme', 'default');
            p.addParameter('NavigatorHeight', 0.20);
            p.addParameter('ShowThresholds', true);
            p.addParameter('ShowThresholdBands', true);
            p.addParameter('Events', []);
            p.addParameter('ShowEventLabels', false);
            p.addParameter('Parent', []);
            p.addParameter('Title', sensor.Name);
            p.parse(varargin{:});
            opts = p.Results;

            obj.Theme = opts.Theme;
            obj.NavigatorHeight = opts.NavigatorHeight;
            obj.ShowThresholds = opts.ShowThresholds;
            obj.ShowThresholdBands = opts.ShowThresholdBands;
            obj.ShowEventLabels = opts.ShowEventLabels;
            obj.ParentPanel = opts.Parent;
            obj.Title = opts.Title;

            % Resolve events
            obj.Events = obj.resolveEvents(opts.Events);
        end

        function render(obj)
            if obj.IsRendered
                error('SensorDetailPlot:alreadyRendered', ...
                    'SensorDetailPlot has already been rendered.');
            end

            % Auto-resolve sensor if not yet resolved (avoids struct()
            % default in ResolvedThresholds crashing FastPlot.addSensor)
            if isstruct(obj.Sensor.ResolvedThresholds) && isempty(fieldnames(obj.Sensor.ResolvedThresholds))
                obj.Sensor.resolve();
            end

            % Create layout
            obj.createLayout();

            % Create main FastPlot
            obj.MainPlot = FastPlot('Parent', obj.hMainAxes, 'Theme', obj.Theme);
            obj.MainPlot.addSensor(obj.Sensor, 'ShowThresholds', obj.ShowThresholds);

            % Render main plot
            obj.MainPlot.render();

            % Set title
            if ~isempty(obj.Title)
                title(obj.hMainAxes, obj.Title);
            end

            % Create navigator FastPlot
            obj.NavigatorPlot = FastPlot('Parent', obj.hNavAxes, 'Theme', obj.Theme);
            obj.NavigatorPlot.addLine(obj.Sensor.X, obj.Sensor.Y, ...
                'DisplayName', obj.Sensor.Name);

            % Add threshold bands to navigator
            if obj.ShowThresholdBands
                obj.addNavigatorThresholdBands();
            end

            % Render navigator
            obj.NavigatorPlot.render();

            % Fix navigator axes limits
            xFull = [min(obj.Sensor.X), max(obj.Sensor.X)];
            yRange = [min(obj.Sensor.Y), max(obj.Sensor.Y)];
            yPad = (yRange(2) - yRange(1)) * 0.05;
            if yPad == 0; yPad = 1; end
            set(obj.hNavAxes, 'XLim', xFull, 'YLim', [yRange(1)-yPad, yRange(2)+yPad]);
            set(obj.hNavAxes, 'XLimMode', 'manual', 'YLimMode', 'manual');

            % Disable zoom/pan on navigator
            zoom(obj.hNavAxes, 'off');
            pan(obj.hNavAxes, 'off');

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

            try
                obj.XLimListener = addlistener(obj.hMainAxes, 'XLim', 'PostSet', ...
                    @(s,e) obj.onMainXLimChanged());
            catch
                % Fallback for older MATLAB
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
            mainHeight = 1 - obj.NavigatorHeight;

            if ~isempty(obj.ParentPanel)
                % Embedded mode: create sub-panels inside parent
                container = obj.ParentPanel;
                obj.OwnsFigure = false;
            else
                % Standalone mode: create figure
                obj.hFig = figure('Visible', 'off', 'Name', obj.Title, ...
                    'NumberTitle', 'off', 'Position', [100 100 900 600]);
                container = obj.hFig;
                obj.OwnsFigure = true;
            end

            % Main panel (upper)
            obj.hMainPanel = uipanel('Parent', container, ...
                'Units', 'normalized', ...
                'Position', [0, obj.NavigatorHeight, 1, mainHeight], ...
                'BorderType', 'none');

            % Navigator panel (lower)
            obj.hNavPanel = uipanel('Parent', container, ...
                'Units', 'normalized', ...
                'Position', [0, 0, 1, obj.NavigatorHeight], ...
                'BorderType', 'none');

            % Create axes in each panel
            obj.hMainAxes = axes('Parent', obj.hMainPanel, ...
                'Units', 'normalized', 'Position', [0.08 0.12 0.88 0.82]);
            obj.hNavAxes = axes('Parent', obj.hNavPanel, ...
                'Units', 'normalized', 'Position', [0.08 0.15 0.88 0.75]);
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

        function addNavigatorThresholdBands(obj)
            if isempty(obj.Sensor.ResolvedThresholds)
                return;
            end

            for i = 1:numel(obj.Sensor.ResolvedThresholds)
                th = obj.Sensor.ResolvedThresholds(i);

                % Determine color
                if ~isempty(th.Color)
                    bandColor = th.Color;
                elseif strcmp(th.Direction, 'upper')
                    bandColor = [1 0.2 0.2]; % red
                else
                    bandColor = [0.2 0.2 1]; % blue
                end

                thVal = mean(th.Y, 'omitnan');
                if isnan(thVal); continue; end

                if strcmp(th.Direction, 'upper')
                    yHigh = max(obj.Sensor.Y) + (max(obj.Sensor.Y) - min(obj.Sensor.Y)) * 0.05;
                    obj.NavigatorPlot.addBand(thVal, yHigh, ...
                        'FaceColor', bandColor, 'FaceAlpha', 0.10, ...
                        'EdgeColor', 'none', 'Label', th.Label);
                else
                    yLow = min(obj.Sensor.Y) - (max(obj.Sensor.Y) - min(obj.Sensor.Y)) * 0.05;
                    obj.NavigatorPlot.addBand(yLow, thVal, ...
                        'FaceColor', bandColor, 'FaceAlpha', 0.10, ...
                        'EdgeColor', 'none', 'Label', th.Label);
                end
            end
        end

        function addEventShading(obj)
            % Add event shaded regions to main plot
            if isempty(obj.Events); return; end

            % Filter events for this sensor
            sensorEvents = obj.filterEventsForSensor(obj.Events);
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

            sensorEvents = obj.filterEventsForSensor(obj.Events);
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

        function filtered = filterEventsForSensor(obj, events)
            if isempty(events)
                filtered = events;
                return;
            end
            mask = strcmp({events.SensorName}, obj.Sensor.Key);
            filtered = events(mask);
        end

        function [color, alpha] = eventColor(~, ev)
            label = ev.ThresholdLabel;
            isEscalated = ~isempty(regexpi(label, '(HH|LL)', 'once'));

            if strcmp(ev.Direction, 'high')
                if isEscalated
                    color = [0.9 0.1 0.1];   % red
                    alpha = 0.15;
                else
                    color = [1 0.6 0.2];     % orange
                    alpha = 0.12;
                end
            elseif strcmp(ev.Direction, 'low')
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

        function onMainXLimChanged(obj)
            if obj.IsPropagating; return; end
            if ~ishandle(obj.hMainAxes); return; end
            obj.IsPropagating = true;
            lim = get(obj.hMainAxes, 'XLim');
            if ~isempty(obj.NavigatorOverlayObj) && isvalid(obj.NavigatorOverlayObj)
                obj.NavigatorOverlayObj.setRange(lim(1), lim(2));
            end
            obj.IsPropagating = false;
        end

        function onFigureClose(obj)
            delete(obj);
        end
    end
end
