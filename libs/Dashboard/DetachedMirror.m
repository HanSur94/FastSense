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
                otherwise
                    error('DetachedMirror:unknownType', ...
                        'Unknown widget type: %s', s.type);
            end

            % Restore live Sensor reference for FastSenseWidget.
            % toStruct serializes the sensor by key; fromStruct calls SensorRegistry.get()
            % which may return the same live Sensor — but we copy the reference directly
            % to guarantee binding even on a registry miss.
            if isa(w, 'FastSenseWidget') && ~isempty(original.Sensor)
                w.Sensor = original.Sensor;
                % Force independent time axis zoom/pan (DETACH-05)
                w.UseGlobalTime = false;
            end

            % Restore function handle references for RawAxesWidget.
            % func2str/str2func loses closure-captured variables; copy directly
            % (safe here because this is an in-memory clone, not a disk round-trip).
            if isa(w, 'RawAxesWidget') && ~isempty(original.PlotFcn)
                w.PlotFcn = original.PlotFcn;
                w.DataRangeFcn = original.DataRangeFcn;
            end
        end

    end

end
