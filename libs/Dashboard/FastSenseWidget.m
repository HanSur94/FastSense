classdef FastSenseWidget < DashboardWidget
%FASTSENSEWIDGET Dashboard widget wrapping a FastSense instance.
%
%   Supports data binding modes:
%     Tag:       w = FastSenseWidget('Tag', tagObj)
%     DataStore: w = FastSenseWidget('DataStore', dsObj)
%     Inline:    w = FastSenseWidget('XData', x, 'YData', y)
%     File:      w = FastSenseWidget('File', 'path.mat', 'XVar', 'x', 'YVar', 'y')

    properties (Access = public)
        DataStoreObj = []
        XData        = []
        YData        = []
        File         = ''
        XVar         = ''
        YVar         = ''
        Thresholds   = 'auto'
        XLabel       = ''    % X-axis label (auto-set from Sensor if empty)
        YLabel       = ''    % Y-axis label (auto-set from Sensor if empty)
        YLimits             = []    % Fixed Y-axis range [min max]; empty = auto-scale
        ShowThresholdLabels = false % show inline name labels on threshold lines
    end
    %   (Tag property now lives on the DashboardWidget base class — Plan 1009-02.)

    properties (SetAccess = private)
        FastSenseObj  = []
        IsSettingTime = false  % guard to distinguish programmatic vs user xlim change
        CachedXMin    = inf    % cached minimum of X data for O(1) getTimeRange()
        CachedXMax    = -inf   % cached maximum of X data for O(1) getTimeRange()
        LastTagRef    = []     % Tag handle snapshot for cache-invalidation
    end

    methods
        function obj = FastSenseWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 12 3];
            end

            % Tag cascade (v2.0 Tag API).
            if ~isempty(obj.Tag)
                if ~isa(obj.Tag, 'Tag')
                    error('FastSenseWidget:invalidTag', ...
                        'Tag must be a Tag subclass; got %s.', class(obj.Tag));
                end
                if isempty(obj.XLabel), obj.XLabel = 'Time'; end
                if isempty(obj.YLabel)
                    if isprop(obj.Tag, 'Units') && ~isempty(obj.Tag.Units)
                        obj.YLabel = obj.Tag.Units;
                    elseif ~isempty(obj.Tag.Name)
                        obj.YLabel = obj.Tag.Name;
                    else
                        obj.YLabel = obj.Tag.Key;
                    end
                end
                obj.LastTagRef = obj.Tag;
                obj.updateTimeRangeCache();
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;

            % Create axes inside the panel
            ax = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.08 0.12 0.88 0.78]);

            % Create FastSense on this axes
            fp = FastSense('Parent', ax);
            obj.FastSenseObj = fp;
            fp.ShowThresholdLabels = obj.ShowThresholdLabels;

            % Slide the X window as new samples arrive on updateData(). The
            % default empty LiveViewMode leaves the window frozen at the
            % initial render's data range, so later samples appear off the
            % right edge of live widgets. 'reset' grows the window to cover
            % the full current X range each tick — appropriate for
            % dashboard use where users expect to see all data since the
            % live pipeline started.
            fp.LiveViewMode = 'reset';

            % Bind data — Tag-first dispatch (v2.0).
            if ~isempty(obj.Tag)
                fp.addTag(obj.Tag);
            elseif ~isempty(obj.DataStoreObj)
                fp.addLine([], [], 'DataStore', obj.DataStoreObj);
            elseif ~isempty(obj.File)
                data = load(obj.File);
                x = data.(obj.XVar);
                y = data.(obj.YVar);
                fp.addLine(x, y);
            elseif ~isempty(obj.XData) && ~isempty(obj.YData)
                fp.addLine(obj.XData, obj.YData);
            end

            % Datenum auto-promotion happens inside FastSense.addLine when
            % the probed X values sit in the MATLAB datenum range
            % (697000..769000 ≈ 1910-2100). No explicit XType handoff
            % needed here.

            % Apply thresholds — must be BEFORE fp.render() (FastSense
            % rejects addThreshold calls after render). Accepted forms:
            %   'auto'                     — no-op (default)
            %   numeric scalar/vector      — one upper threshold per value
            %   cell of structs            — {struct('Value',..,'Direction',..,'Label',..), ...}
            applyThresholds_(fp, obj.Thresholds);

            % Set title and axis labels
            if ~isempty(obj.Title)
                title(ax, obj.Title, 'Color', get(ax, 'XColor'));
            end
            if ~isempty(obj.XLabel)
                xlabel(ax, obj.XLabel, 'Color', get(ax, 'XColor'));
            end
            if ~isempty(obj.YLabel)
                ylabel(ax, obj.YLabel, 'Color', get(ax, 'XColor'));
            end

            fp.render();

            % Apply fixed Y-axis limits if configured; otherwise expand the
            % auto-computed range so threshold lines stay visible even when
            % the initial data range is narrower than the threshold value.
            if ~isempty(obj.YLimits) && numel(obj.YLimits) == 2
                ylim(ax, obj.YLimits);
            else
                yInit = [];
                try
                    if ~isempty(obj.Tag)
                        [~, yInit] = obj.Tag.getXY();
                    elseif ~isempty(obj.YData)
                        yInit = obj.YData;
                    end
                catch
                end
                if ~isempty(yInit)
                    obj.autoScaleY_(yInit);
                end
            end

            % Update time range cache and data-source identity snapshots
            obj.LastTagRef = obj.Tag;
            obj.updateTimeRangeCache();

            % Listen for manual zoom/pan to disable global time for this widget
            try
                addlistener(ax, 'XLim', 'PostSet', @(~,~) obj.onXLimChanged());
            catch
            end
        end

        function refresh(obj)
            % Re-render Tag-bound widgets so updated data shows.
            % Uses incremental updateData() path when tag identity is unchanged
            % (PERF2-01); falls back to full teardown/rebuild on first render,
            % tag swap, or error.  Zoom state (xlim) is preserved in both paths.

            if isempty(obj.Tag), return; end
            if isempty(obj.hPanel) || ~ishandle(obj.hPanel), return; end
            tagUnchanged = ~isempty(obj.LastTagRef) && obj.Tag == obj.LastTagRef;
            fpValid = ~isempty(obj.FastSenseObj) && ...
                      obj.FastSenseObj.IsRendered && ...
                      ~isempty(obj.FastSenseObj.hAxes) && ...
                      ishandle(obj.FastSenseObj.hAxes);
            if tagUnchanged && fpValid
                try
                    [x, y] = obj.Tag.getXY();
                    obj.FastSenseObj.updateData(1, x, y);
                    obj.autoScaleY_(y);
                    obj.updateTimeRangeCache();
                    return;
                catch
                    % fall through to full teardown/rebuild
                end
            end
            obj.rebuildForTag_();
        end

        function update(obj)
        %UPDATE Incrementally update Tag data without full axes rebuild.
        %   Uses FastSenseObj.updateData() to replace data and re-downsample,
        %   avoiding the expensive delete/recreate cycle of refresh().
        %   Falls back to refresh() if FastSenseObj is not in a renderable state.

            if isempty(obj.Tag), return; end
            if isempty(obj.hPanel) || ~ishandle(obj.hPanel), return; end
            if ~isempty(obj.FastSenseObj) && obj.FastSenseObj.IsRendered
                try
                    [x, y] = obj.Tag.getXY();
                    obj.FastSenseObj.updateData(1, x, y);
                    obj.autoScaleY_(y);
                    obj.updateTimeRangeCache();
                    return;
                catch
                    % fall through to refresh()
                end
            end
            obj.refresh();
        end

        function autoScaleY_(obj, y)
        %AUTOSCALEY_ Rescale the Y axis to cover current data + thresholds.
        %   FastSense locks YLim to manual mode at first render, so new
        %   samples outside the initial range would fall off the chart.
        %   This helper recomputes the Y extent every tick (including any
        %   threshold values so MonitorTag lines stay visible) and updates
        %   the axes. Skipped when the widget has a user-pinned YLimits.
            if ~isempty(obj.YLimits)
                return;
            end
            if isempty(obj.FastSenseObj) || ~obj.FastSenseObj.IsRendered
                return;
            end
            ax = obj.FastSenseObj.hAxes;
            if isempty(ax) || ~ishandle(ax)
                return;
            end
            if isempty(y)
                return;
            end
            yMin = min(y(:));
            yMax = max(y(:));
            if iscell(obj.Thresholds)
                for i = 1:numel(obj.Thresholds)
                    e = obj.Thresholds{i};
                    if isstruct(e) && isfield(e, 'Value') && isfinite(e.Value)
                        yMin = min(yMin, e.Value);
                        yMax = max(yMax, e.Value);
                    end
                end
            elseif isnumeric(obj.Thresholds) && ~isempty(obj.Thresholds)
                yMin = min(yMin, min(obj.Thresholds(:)));
                yMax = max(yMax, max(obj.Thresholds(:)));
            end
            if ~isfinite(yMin) || ~isfinite(yMax)
                return;
            end
            if yMax > yMin
                pad = (yMax - yMin) * 0.08;
            else
                pad = max(abs(yMax) * 0.1, 1);
            end
            set(ax, 'YLim', [yMin - pad, yMax + pad]);
        end

        function setTimeRange(obj, tStart, tEnd)
            if ~obj.UseGlobalTime
                return;  % widget has its own zoom, skip global time
            end
            if ~isempty(obj.FastSenseObj)
                try
                    ax = obj.FastSenseObj.hAxes;
                    if ~isempty(ax) && ishandle(ax)
                        obj.IsSettingTime = true;
                        xlim(ax, [tStart tEnd]);
                        obj.IsSettingTime = false;
                    end
                catch
                    obj.IsSettingTime = false;
                end
            end
        end

        function onXLimChanged(obj)
            % If xlim changed by user zoom/pan (not by setTimeRange),
            % detach this widget from global time.
            if ~obj.IsSettingTime
                obj.UseGlobalTime = false;
            end
        end

        function [tMin, tMax] = getTimeRange(obj)
            % Return cached min/max in O(1). Cache is kept up to date by
            % updateTimeRangeCache() which is called from render/refresh/update.
            tMin = obj.CachedXMin;
            tMax = obj.CachedXMax;
            if isinf(tMin) || isinf(tMax)
                tMin = inf; tMax = -inf;
            end
        end

        function t = getType(~)
            t = 'fastsense';
        end

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            yData = [];
            if ~isempty(obj.Tag)
                try
                    [~, yData] = obj.Tag.getXY();
                catch
                    yData = [];
                end
            elseif ~isempty(obj.YData)
                yData = obj.YData;
            end

            if ~isempty(yData) && height >= 2
                bars = char(9601):char(9608);
                nBars = numel(bars);
                yMin = min(yData); yMax = max(yData);
                if yMax == yMin, yMax = yMin + 1; end
                nPts = min(numel(yData), width);
                idx = round(linspace(1, numel(yData), nPts));
                sampled = yData(idx);
                spark = blanks(nPts);
                for si = 1:nPts
                    level = round((sampled(si) - yMin) / (yMax - yMin) * (nBars - 1)) + 1;
                    level = max(1, min(nBars, level));
                    spark(si) = bars(level);
                end
                if numel(spark) < width
                    spark = [spark, repmat(' ', 1, width - numel(spark))];
                end
                lines{2} = spark(1:width);
            elseif height >= 2
                ph = '[~~ fastsense ~~]';
                if numel(ph) > width, ph = ph(1:width); end
                lines{2} = [ph, repmat(' ', 1, width - numel(ph))];
            end
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.XLabel), s.xLabel = obj.XLabel; end
            if ~isempty(obj.YLabel), s.yLabel = obj.YLabel; end
            if ~isempty(obj.YLimits), s.yLimits = obj.YLimits; end
            if obj.ShowThresholdLabels, s.showThresholdLabels = true; end

            if ~isempty(obj.Tag) && ~isempty(obj.Tag.Key)
                s.source = struct('type', 'tag', 'key', obj.Tag.Key);
                s.thresholds = obj.Thresholds;
            elseif ~isempty(obj.File)
                s.source = struct('type', 'file', 'path', obj.File, ...
                                  'xVar', obj.XVar, 'yVar', obj.YVar);
            elseif ~isempty(obj.XData)
                s.source = struct('type', 'data', 'x', obj.XData, 'y', obj.YData);
            end
        end
    end

    methods (Access = private)
        function updateTimeRangeCache(obj)
        %UPDATETIMERANGECACHE Maintain CachedXMin/CachedXMax incrementally.
        %   For sorted time arrays (the common case) the last element is the
        %   max candidate and the first is the min candidate, so this avoids
        %   a full-array scan on every live tick.
            if ~isempty(obj.Tag)
                try
                    [x, ~] = obj.Tag.getXY();
                    n = numel(x);
                    if n == 0
                        obj.CachedXMin = inf;
                        obj.CachedXMax = -inf;
                        return;
                    end
                    obj.CachedXMax = x(n);
                    if isinf(obj.CachedXMin)
                        obj.CachedXMin = x(1);
                    end
                catch
                    obj.CachedXMin = inf;
                    obj.CachedXMax = -inf;
                end
                return;
            end
            if ~isempty(obj.XData)
                obj.CachedXMin = min(obj.XData);
                obj.CachedXMax = max(obj.XData);
            else
                obj.CachedXMin = inf;
                obj.CachedXMax = -inf;
            end
        end

        function rebuildForTag_(obj)
        %REBUILDFORTAG_ Full teardown + rebuild FastSense from obj.Tag.
        %   Preserves zoom state (xlim) across the rebuild.
            % Save zoom state before teardown
            savedXLim = [];
            if ~isempty(obj.FastSenseObj) && ~isempty(obj.FastSenseObj.hAxes) && ...
                    ishandle(obj.FastSenseObj.hAxes)
                savedXLim = get(obj.FastSenseObj.hAxes, 'XLim');
            end

            % Delete old FastSense + leftover axes in the panel
            if ~isempty(obj.FastSenseObj)
                try delete(obj.FastSenseObj); catch, end
                obj.FastSenseObj = [];
            end
            ch = findobj(obj.hPanel, 'Type', 'axes');
            delete(ch);

            ax = axes('Parent', obj.hPanel, ...
                'Units', 'normalized', ...
                'Position', [0.08 0.12 0.88 0.78]);

            fp = FastSense('Parent', ax);
            obj.FastSenseObj = fp;
            fp.ShowThresholdLabels = obj.ShowThresholdLabels;
            fp.addTag(obj.Tag);

            if ~isempty(obj.Title)
                title(ax, obj.Title, 'Color', get(ax, 'XColor'));
            end
            if ~isempty(obj.XLabel)
                xlabel(ax, obj.XLabel, 'Color', get(ax, 'XColor'));
            end
            if ~isempty(obj.YLabel)
                ylabel(ax, obj.YLabel, 'Color', get(ax, 'XColor'));
            end

            fp.render();

            if ~isempty(obj.YLimits) && numel(obj.YLimits) == 2
                ylim(ax, obj.YLimits);
            end

            obj.LastTagRef = obj.Tag;
            obj.updateTimeRangeCache();

            if ~isempty(savedXLim)
                obj.IsSettingTime = true;
                xlim(ax, savedXLim);
                obj.IsSettingTime = false;
            end

            try
                addlistener(ax, 'XLim', 'PostSet', @(~,~) obj.onXLimChanged());
            catch
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = FastSenseWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];

            if isfield(s, 'description')
                obj.Description = s.description;
            end

            if isfield(s, 'source')
                switch s.source.type
                    case 'tag'
                        if exist('TagRegistry', 'class')
                            try
                                obj.Tag = TagRegistry.get(s.source.key);
                            catch
                                warning('FastSenseWidget:tagNotFound', ...
                                    'TagRegistry key ''%s'' not found.', s.source.key);
                            end
                        end
                    case 'sensor'
                        % Backward compat: old JSON with type='sensor' resolves via TagRegistry.
                        if exist('TagRegistry', 'class')
                            try
                                obj.Tag = TagRegistry.get(s.source.name);
                            catch
                                % Tag not in registry; resolver will
                                % bind it in configToWidgets if provided.
                            end
                        end
                    case 'file'
                        obj.File = s.source.path;
                        obj.XVar = s.source.xVar;
                        obj.YVar = s.source.yVar;
                    case 'data'
                        obj.XData = s.source.x;
                        obj.YData = s.source.y;
                end
            end

            if isfield(s, 'thresholds')
                obj.Thresholds = s.thresholds;
            end
            if isfield(s, 'xLabel')
                obj.XLabel = s.xLabel;
            end
            if isfield(s, 'yLabel')
                obj.YLabel = s.yLabel;
            end
            if isfield(s, 'yLimits')
                obj.YLimits = s.yLimits;
            end
            if isfield(s, 'showThresholdLabels')
                obj.ShowThresholdLabels = s.showThresholdLabels;
            end
        end
    end
end

function applyThresholds_(fp, spec)
    %APPLYTHRESHOLDS_ Push a Thresholds spec into a FastSense instance.
    %   Accepts 'auto' / [] (no-op), numeric scalar/vector (upper lines),
    %   or a cell of structs with fields Value / Direction / Label.
    if isempty(spec)
        return;
    end
    if ischar(spec) || (isstring(spec) && isscalar(spec))
        % 'auto' (or any other string) means "no thresholds wired".
        return;
    end
    if isnumeric(spec)
        for i = 1:numel(spec)
            fp.addThreshold(spec(i), 'Direction', 'upper');
        end
        return;
    end
    if iscell(spec)
        for i = 1:numel(spec)
            e = spec{i};
            if ~isstruct(e) || ~isfield(e, 'Value')
                continue;
            end
            dir = 'upper';
            if isfield(e, 'Direction') && ~isempty(e.Direction)
                dir = e.Direction;
            end
            lbl = '';
            if isfield(e, 'Label') && ~isempty(e.Label)
                lbl = e.Label;
            end
            if isempty(lbl)
                fp.addThreshold(e.Value, 'Direction', dir);
            else
                fp.addThreshold(e.Value, 'Direction', dir, 'Label', lbl);
            end
        end
    end
end
