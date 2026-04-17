classdef DetachedMirror < handle
%DETACHEDMIRROR Standalone live-mirrored widget window for DashboardEngine.
%
%   DetachedMirror wraps a cloned DashboardWidget in a standalone MATLAB
%   figure window. The clone is produced via toStruct/fromStruct with post-
%   clone live-reference restoration for FastSenseWidget and RawAxesWidget.
%
%   The mirror is NOT a DashboardWidget subclass — it wraps one. It belongs
%   to DashboardEngine.DetachedMirrors and is ticked by the engine's existing
%   LiveTimer via the engine's onLiveTick() loop.
%
%   Usage (called internally by DashboardEngine.detachWidget()):
%     theme = DashboardTheme(obj.Theme);
%     cb    = @() obj.removeDetached(mirror);
%     mirror = DetachedMirror(originalWidget, theme, cb);
%
%   Properties (SetAccess = private):
%     hFigure        — standalone MATLAB figure window handle
%     hPanel         — full-figure uipanel that hosts the cloned widget
%     Widget         — cloned DashboardWidget instance
%     RemoveCallback — @() called by onFigureClose() before delete(hFigure)
%
%   Public methods:
%     tick()         — refresh cloned widget; guards on stale handle
%     isStale()      — true when hFigure is empty or no longer a valid handle
%
%   See also: DashboardEngine, DashboardWidget, FastSenseWidget, RawAxesWidget

    properties (SetAccess = private)
        hFigure        = []   % Standalone figure window for this detached widget
        hPanel         = []   % Full-figure uipanel hosting the cloned widget
        Widget         = []   % Cloned DashboardWidget instance
        RemoveCallback = []   % @() — called before figure delete on close
    end

    methods (Access = public)

        function obj = DetachedMirror(originalWidget, themeStruct, removeCallback)
        %DETACHEDMIRROR Create a detached live-mirror window for originalWidget.
        %
        %   obj = DetachedMirror(originalWidget, themeStruct, removeCallback)
        %
        %   Inputs:
        %     originalWidget  — DashboardWidget to clone
        %     themeStruct     — struct from DashboardTheme(preset)
        %     removeCallback  — @() function called when figure is closed

            % 1. Clone widget via static helper (toStruct + fromStruct + live ref restore)
            cloned = DetachedMirror.cloneWidget(originalWidget);

            % 2. Create standalone figure window
            figTitle = sprintf('%s \x2014 Live', originalWidget.Title);
            obj.hFigure = figure( ...
                'Name',         figTitle, ...
                'NumberTitle',  'off', ...
                'Color',        themeStruct.DashboardBackground, ...
                'CloseRequestFcn', @(~,~) obj.onFigureClose());

            % 3. Full-figure panel (fills the figure, no visible border)
            obj.hPanel = uipanel( ...
                'Parent',          obj.hFigure, ...
                'Units',           'normalized', ...
                'Position',        [0 0 1 1], ...
                'BorderType',      'none', ...
                'BackgroundColor', themeStruct.DashboardBackground);

            % 4. Apply theme to cloned widget and render it into the panel
            cloned.ParentTheme = themeStruct;
            cloned.render(obj.hPanel);

            % 5. Store references
            obj.Widget         = cloned;
            obj.RemoveCallback = removeCallback;
        end

        function tick(obj)
        %TICK Refresh the cloned widget; no-op if figure is stale.
        %
        %   Follows the same try/catch + warning pattern as DashboardEngine.onLiveTick.
        %   Does NOT call drawnow (MATLAB processes redraws from its event queue).

            if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
                return;
            end

            try
                if isa(obj.Widget, 'FastSenseWidget')
                    obj.Widget.update();
                else
                    obj.Widget.refresh();
                end
            catch ME
                warning('DetachedMirror:refreshError', '%s', ME.message);
            end
        end

        function result = isStale(obj)
        %ISSTALE Return true when the mirror's figure has been closed or destroyed.

            result = isempty(obj.hFigure) || ~ishandle(obj.hFigure);
        end

    end

    methods (Access = private)

        function onFigureClose(obj)
        %ONFIGURECLOSE Handle figure close request.
        %
        %   Calls RemoveCallback() first (bookkeeping in DashboardEngine), then
        %   deletes the figure. Order matters: callback must run before the figure
        %   handle is invalidated (Pitfall 2 from RESEARCH.md).

            if ~isempty(obj.RemoveCallback)
                try
                    obj.RemoveCallback();
                catch
                    % Ignore errors during removal (e.g. engine already deleted)
                end
            end

            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                delete(obj.hFigure);
            end
        end

    end

    methods (Static, Access = private)

        function w = cloneWidget(original)
        %CLONEWIDGET Clone a DashboardWidget via toStruct/fromStruct round-trip.
        %
        %   Dispatch is explicit to ensure all 15 widget types are handled.
        %   After fromStruct, live references lost by serialization are restored:
        %     - FastSenseWidget: Sensor reference + UseGlobalTime = false (DETACH-05)
        %     - RawAxesWidget:   PlotFcn and DataRangeFcn function handles

            s = original.toStruct();

            % Remove source references so fromStruct doesn't call
            % TagRegistry.get() (which throws when tags aren't registered).
            % restoreLiveRefs copies live Tag references directly afterward.
            s = DetachedMirror.stripSensorRefs(s);

            switch s.type
                case 'fastsense'
                    w = FastSenseWidget.fromStruct(s);
                case 'number'
                    w = NumberWidget.fromStruct(s);
                case 'status'
                    w = StatusWidget.fromStruct(s);
                case 'text'
                    w = TextWidget.fromStruct(s);
                case 'gauge'
                    w = GaugeWidget.fromStruct(s);
                case 'table'
                    w = TableWidget.fromStruct(s);
                case 'rawaxes'
                    w = RawAxesWidget.fromStruct(s);
                case 'timeline'
                    w = EventTimelineWidget.fromStruct(s);
                case 'group'
                    w = GroupWidget.fromStruct(s);
                case 'heatmap'
                    w = HeatmapWidget.fromStruct(s);
                case 'barchart'
                    w = BarChartWidget.fromStruct(s);
                case 'histogram'
                    w = HistogramWidget.fromStruct(s);
                case 'scatter'
                    w = ScatterWidget.fromStruct(s);
                case 'image'
                    w = ImageWidget.fromStruct(s);
                case 'multistatus'
                    w = MultiStatusWidget.fromStruct(s);
                case 'divider'
                    w = DividerWidget.fromStruct(s);
                case 'iconcard'
                    w = IconCardWidget.fromStruct(s);
                case 'chipbar'
                    w = ChipBarWidget.fromStruct(s);
                case 'sparkline'
                    w = SparklineCardWidget.fromStruct(s);
                otherwise
                    error('DetachedMirror:unknownType', ...
                        'Unknown widget type: %s', s.type);
            end

            % Restore live references lost during serialization round-trip
            DetachedMirror.restoreLiveRefs(w, original);

            % GroupWidget: restore live refs on each child/tab widget
            if isa(w, 'GroupWidget')
                origChildren = original.Children;
                for i = 1:min(numel(w.Children), numel(origChildren))
                    DetachedMirror.restoreLiveRefs(w.Children{i}, origChildren{i});
                end
                for ti = 1:min(numel(w.Tabs), numel(original.Tabs))
                    origTab = original.Tabs{ti};
                    clonedTab = w.Tabs{ti};
                    for j = 1:min(numel(clonedTab.widgets), numel(origTab.widgets))
                        DetachedMirror.restoreLiveRefs(clonedTab.widgets{j}, origTab.widgets{j});
                    end
                end
            end
        end

        function restoreLiveRefs(cloned, original)
        %RESTORELIVEREFS Copy non-serializable live references from original to cloned widget.
            % Sensor reference (FastSenseWidget, NumberWidget, StatusWidget, GaugeWidget, etc.)
            if isprop(cloned, 'Sensor') && ~isempty(original.Sensor)
                cloned.Sensor = original.Sensor;
            end
            if isa(cloned, 'FastSenseWidget') && ~isempty(original.Sensor)
                cloned.UseGlobalTime = false;
            end
            % Function handles (RawAxesWidget, HeatmapWidget, BarChartWidget, ImageWidget, TableWidget)
            if isprop(cloned, 'PlotFcn') && ~isempty(original.PlotFcn)
                cloned.PlotFcn = original.PlotFcn;
            end
            if isprop(cloned, 'DataRangeFcn') && ~isempty(original.DataRangeFcn)
                cloned.DataRangeFcn = original.DataRangeFcn;
            end
            if isprop(cloned, 'DataFcn') && ~isempty(original.DataFcn)
                cloned.DataFcn = original.DataFcn;
            end
            if isprop(cloned, 'ImageFcn') && ~isempty(original.ImageFcn)
                cloned.ImageFcn = original.ImageFcn;
            end
            if isprop(cloned, 'StatusFcn') && ~isempty(original.StatusFcn)
                cloned.StatusFcn = original.StatusFcn;
            end
            if isprop(cloned, 'ValueFcn') && ~isempty(original.ValueFcn)
                cloned.ValueFcn = original.ValueFcn;
            end
            % Static data (TableWidget Data, EventTimelineWidget Events)
            if isprop(cloned, 'Data') && ~isempty(original.Data)
                cloned.Data = original.Data;
            end
            if isprop(cloned, 'Events') && ~isempty(original.Events)
                cloned.Events = original.Events;
            end
            % Scatter sensor pairs
            if isprop(cloned, 'SensorX') && ~isempty(original.SensorX)
                cloned.SensorX = original.SensorX;
            end
            if isprop(cloned, 'SensorY') && ~isempty(original.SensorY)
                cloned.SensorY = original.SensorY;
            end
            if isprop(cloned, 'SensorColor') && ~isempty(original.SensorColor)
                cloned.SensorColor = original.SensorColor;
            end
            % MultiStatus sensors
            if isprop(cloned, 'Sensors') && ~isempty(original.Sensors)
                cloned.Sensors = original.Sensors;
            end
            % Histogram sensor
            if isprop(cloned, 'EventStoreObj') && ~isempty(original.EventStoreObj)
                cloned.EventStoreObj = original.EventStoreObj;
            end
        end

        function s = stripSensorRefs(s)
        %STRIPSENSORREFS Remove source fields from a widget struct.
        %   Prevents fromStruct from calling TagRegistry.get() which may throw.
            sensorFields = {'source', 'sourceX', 'sourceY', 'sourceColor', 'sources'};
            for k = 1:numel(sensorFields)
                if isfield(s, sensorFields{k})
                    s = rmfield(s, sensorFields{k});
                end
            end
            % Recurse into GroupWidget children
            if isfield(s, 'children') && ~isempty(s.children)
                if iscell(s.children)
                    for i = 1:numel(s.children)
                        s.children{i} = DetachedMirror.stripSensorRefs(s.children{i});
                    end
                elseif isstruct(s.children)
                    for i = 1:numel(s.children)
                        s.children(i) = DetachedMirror.stripSensorRefs(s.children(i));
                    end
                end
            end
            % Recurse into GroupWidget tabs
            if isfield(s, 'tabs') && ~isempty(s.tabs)
                tabs = s.tabs;
                if iscell(tabs)
                    for ti = 1:numel(tabs)
                        t = tabs{ti};
                        if isfield(t, 'widgets')
                            ws = t.widgets;
                            if iscell(ws)
                                for j = 1:numel(ws)
                                    ws{j} = DetachedMirror.stripSensorRefs(ws{j});
                                end
                            elseif isstruct(ws)
                                for j = 1:numel(ws)
                                    ws(j) = DetachedMirror.stripSensorRefs(ws(j));
                                end
                            end
                            t.widgets = ws;
                        end
                        tabs{ti} = t;
                    end
                end
                s.tabs = tabs;
            end
        end
    end

end
