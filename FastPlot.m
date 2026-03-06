classdef FastPlot < handle
    %FASTPLOT Ultra-fast time series plotting with dynamic downsampling.
    %   Handles 1K to 100M data points with fluid zoom/pan.
    %   Uses MinMax downsampling to reduce data to screen resolution.
    %
    %   Usage:
    %     fp = FastPlot();
    %     fp.addLine(x, y, 'DisplayName', 'Sensor1');
    %     fp.addThreshold(4.5, 'Direction', 'upper', 'ShowViolations', true);
    %     fp.render();

    properties (Access = public)
        ParentAxes = []       % axes handle, empty = create new
        LinkGroup  = ''       % string ID for linked zoom/pan
    end

    properties (SetAccess = private)
        Lines      = struct('X', {}, 'Y', {}, 'Options', {}, ...
                            'DownsampleMethod', {}, 'hLine', {})
        Thresholds = struct('Value', {}, 'Direction', {}, ...
                            'ShowViolations', {}, 'Color', {}, ...
                            'LineStyle', {}, 'Label', {}, ...
                            'hLine', {}, 'hMarkers', {})
        IsRendered    = false
        hFigure       = []
        hAxes         = []
    end

    properties (Access = private)
        Listeners     = []    % event listeners (XLim, resize)
        CachedXLim    = []    % for lazy recomputation
        PixelWidth    = 1920  % cached axes width in pixels
        IsPropagating = false % guard against re-entrant link propagation
        HasLimitRate  = []    % cached: does drawnow support 'limitrate'?
    end

    properties (Constant, Access = private)
        MIN_POINTS_FOR_DOWNSAMPLE = 5000  % below this, plot raw data
        DOWNSAMPLE_FACTOR = 2             % points per pixel (min + max)
    end

    methods (Access = public)
        function obj = FastPlot(varargin)
            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'parent'
                        obj.ParentAxes = varargin{k+1};
                    case 'linkgroup'
                        obj.LinkGroup = varargin{k+1};
                end
            end
        end

        function addLine(obj, x, y, varargin)
            %ADDLINE Add a data line to the plot.
            %   fp.addLine(x, y)
            %   fp.addLine(x, y, 'Color', 'r', 'DisplayName', 'Sensor1')
            %   fp.addLine(x, y, 'DownsampleMethod', 'lttb')

            if obj.IsRendered
                error('FastPlot:alreadyRendered', ...
                    'Cannot add lines after render() has been called.');
            end

            % Force row vectors (avoid copy if already row)
            if ~isrow(x); x = x(:)'; end
            if ~isrow(y); y = y(:)'; end

            % Validate sizes match
            if numel(x) ~= numel(y)
                error('FastPlot:sizeMismatch', ...
                    'X and Y must have the same number of elements.');
            end

            % Fast monotonicity check (vectorized)
            if numel(x) > 1
                dx = diff(x);
                % NaN diffs (NaN neighbors) are fine — only check real decreases
                if any(dx(~isnan(dx)) < 0)
                    error('FastPlot:nonMonotonicX', ...
                        'X must be monotonically increasing.');
                end
            end

            % Parse name-value pairs manually (avoid inputParser overhead)
            dsMethod = 'minmax';
            opts = struct();
            k = 1;
            while k <= numel(varargin)
                key = varargin{k};
                val = varargin{k+1};
                if strcmpi(key, 'DownsampleMethod')
                    dsMethod = val;
                else
                    opts.(key) = val;
                end
                k = k + 2;
            end

            % Build line struct
            lineStruct.X = x;
            lineStruct.Y = y;
            lineStruct.DownsampleMethod = dsMethod;
            lineStruct.Options = opts;
            lineStruct.hLine = [];

            % Append
            if isempty(obj.Lines)
                obj.Lines = lineStruct;
            else
                obj.Lines(end+1) = lineStruct;
            end
        end

        function addThreshold(obj, value, varargin)
            %ADDTHRESHOLD Add a horizontal threshold line.
            %   fp.addThreshold(4.5)
            %   fp.addThreshold(4.5, 'Direction', 'upper', 'ShowViolations', true)

            if obj.IsRendered
                error('FastPlot:alreadyRendered', ...
                    'Cannot add thresholds after render() has been called.');
            end

            % Defaults
            t.Value          = value;
            t.Direction      = 'upper';
            t.ShowViolations = false;
            t.Color          = [0.8 0 0];
            t.LineStyle      = '--';
            t.Label          = '';
            t.hLine          = [];
            t.hMarkers       = [];

            % Manual name-value parsing (avoid inputParser overhead)
            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'direction'
                        t.Direction = varargin{k+1};
                    case 'showviolations'
                        t.ShowViolations = varargin{k+1};
                    case 'color'
                        t.Color = varargin{k+1};
                    case 'linestyle'
                        t.LineStyle = varargin{k+1};
                    case 'label'
                        t.Label = varargin{k+1};
                end
            end

            if isempty(obj.Thresholds)
                obj.Thresholds = t;
            else
                obj.Thresholds(end+1) = t;
            end
        end

        function render(obj)
            %RENDER Create the plot with all configured lines and thresholds.

            if obj.IsRendered
                error('FastPlot:alreadyRendered', ...
                    'render() has already been called on this FastPlot.');
            end
            if isempty(obj.Lines)
                error('FastPlot:noLines', 'Add at least one line before render().');
            end

            % Create or use axes
            if isempty(obj.ParentAxes)
                obj.hFigure = figure('Visible', 'off');
                obj.hAxes = axes('Parent', obj.hFigure);
            else
                obj.hAxes = obj.ParentAxes;
                obj.hFigure = ancestor(obj.hAxes, 'figure');
            end

            hold(obj.hAxes, 'on');
            obj.PixelWidth = obj.getAxesPixelWidth();

            % --- Render data lines ---
            for i = 1:numel(obj.Lines)
                L = obj.Lines(i);
                numBuckets = obj.PixelWidth;

                % Downsample
                if numel(L.X) > obj.MIN_POINTS_FOR_DOWNSAMPLE
                    if strcmp(L.DownsampleMethod, 'lttb')
                        [xd, yd] = lttb_downsample(L.X, L.Y, numBuckets);
                    else
                        [xd, yd] = minmax_downsample(L.X, L.Y, numBuckets);
                    end
                else
                    xd = L.X;
                    yd = L.Y;
                end

                % Create line object
                h = line(xd, yd, 'Parent', obj.hAxes);

                % Apply user options
                opts = L.Options;
                fnames = fieldnames(opts);
                for f = 1:numel(fnames)
                    set(h, fnames{f}, opts.(fnames{f}));
                end

                % Tag with UserData
                displayName = '';
                if isfield(opts, 'DisplayName')
                    displayName = opts.DisplayName;
                end
                ud.FastPlot = struct( ...
                    'Type', 'data_line', ...
                    'Name', displayName, ...
                    'LineIndex', i, ...
                    'ThresholdValue', []);
                set(h, 'UserData', ud);

                obj.Lines(i).hLine = h;
            end

            % --- Compute full X range (X is sorted, just check endpoints) ---
            xmin = Inf; xmax = -Inf;
            for i = 1:numel(obj.Lines)
                xi = obj.Lines(i).X;
                if xi(1) < xmin; xmin = xi(1); end
                if xi(end) > xmax; xmax = xi(end); end
            end

            % --- Render threshold lines and violation markers (per threshold) ---
            for t = 1:numel(obj.Thresholds)
                T = obj.Thresholds(t);

                % Threshold line
                hT = line([xmin, xmax], [T.Value, T.Value], 'Parent', obj.hAxes, ...
                    'Color', T.Color, ...
                    'LineStyle', T.LineStyle, ...
                    'HandleVisibility', 'off');
                udT.FastPlot = struct( ...
                    'Type', 'threshold', ...
                    'Name', T.Label, ...
                    'LineIndex', [], ...
                    'ThresholdValue', T.Value);
                set(hT, 'UserData', udT);
                obj.Thresholds(t).hLine = hT;

                % Violation markers (use already-downsampled data)
                if T.ShowViolations
                    vxAll = [];
                    vyAll = [];
                    for i = 1:numel(obj.Lines)
                        xd = get(obj.Lines(i).hLine, 'XData');
                        yd = get(obj.Lines(i).hLine, 'YData');
                        [vx, vy] = compute_violations( ...
                            xd, yd, T.Value, T.Direction);
                        if ~isempty(vx)
                            vxAll = [vxAll, vx, NaN]; %#ok<AGROW>
                            vyAll = [vyAll, vy, NaN]; %#ok<AGROW>
                        end
                    end
                    if ~isempty(vxAll)
                        vxAll = vxAll(1:end-1);
                        vyAll = vyAll(1:end-1);
                    else
                        vxAll = NaN;
                        vyAll = NaN;
                    end
                    hM = line(vxAll, vyAll, 'Parent', obj.hAxes, ...
                        'LineStyle', 'none', 'Marker', 'o', ...
                        'MarkerSize', 4, 'Color', T.Color, ...
                        'HandleVisibility', 'off');
                    udM.FastPlot = struct( ...
                        'Type', 'violation_marker', ...
                        'Name', T.Label, ...
                        'LineIndex', [], ...
                        'ThresholdValue', T.Value);
                    set(hM, 'UserData', udM);
                    obj.Thresholds(t).hMarkers = hM;
                end
            end

            % --- Set static axis limits (use downsampled data, not full raw) ---
            ymin = Inf; ymax = -Inf;
            for i = 1:numel(obj.Lines)
                yd = get(obj.Lines(i).hLine, 'YData');
                yiMin = min(yd);
                yiMax = max(yd);
                if ~isnan(yiMin)
                    if yiMin < ymin; ymin = yiMin; end
                    if yiMax > ymax; ymax = yiMax; end
                end
            end
            yPad = (ymax - ymin) * 0.05;
            if yPad == 0; yPad = 1; end

            set(obj.hAxes, 'XLim', [xmin, xmax]);
            set(obj.hAxes, 'YLim', [ymin - yPad, ymax + yPad]);
            set(obj.hAxes, 'XLimMode', 'manual');
            set(obj.hAxes, 'YLimMode', 'manual');

            obj.CachedXLim = get(obj.hAxes, 'XLim');

            % --- Install listeners ---
            addlistener(obj.hAxes, 'xlim', @(s,e) obj.onXLimChanged(s,e));
            set(obj.hFigure, 'ResizeFcn', @(s,e) obj.onResize(s,e));

            % Enable zoom and pan
            zoom(obj.hFigure, 'on');

            obj.IsRendered = true;

            % Register in link group
            if ~isempty(obj.LinkGroup)
                FastPlot.getLinkRegistry('register', obj.LinkGroup, obj);
            end

            hold(obj.hAxes, 'off');

            % Show figure now that setup is complete
            if isempty(obj.ParentAxes)
                set(obj.hFigure, 'Visible', 'on');
            end
            drawnow;
        end
    end

    methods (Access = private)
        function onXLimChanged(obj, ~, ~)
            if ~obj.IsRendered || ~ishandle(obj.hAxes) || obj.IsPropagating
                return;
            end

            newXLim = get(obj.hAxes, 'XLim');

            % Lazy: skip if unchanged
            if ~isempty(obj.CachedXLim) && all(abs(newXLim - obj.CachedXLim) < eps)
                return;
            end
            obj.CachedXLim = newXLim;

            obj.updateLines();
            obj.updateViolations();

            % Propagate to linked axes
            if ~isempty(obj.LinkGroup)
                obj.propagateXLim(newXLim);
            end

            obj.drawnowLimitRate();
        end

        function onResize(obj, ~, ~)
            if ~obj.IsRendered || ~ishandle(obj.hAxes)
                return;
            end
            newPW = obj.getAxesPixelWidth();
            if newPW ~= obj.PixelWidth
                obj.PixelWidth = newPW;
                obj.updateLines();
                obj.drawnowLimitRate();
            end
        end

        function updateLines(obj)
            pw = obj.PixelWidth;
            xlims = get(obj.hAxes, 'XLim');

            for i = 1:numel(obj.Lines)
                L = obj.Lines(i);

                % Binary search for visible range
                idxStart = binary_search(L.X, xlims(1), 'left');
                idxEnd   = binary_search(L.X, xlims(2), 'right');

                % Pad by 1 on each side for line continuity at edges
                idxStart = max(1, idxStart - 1);
                idxEnd   = min(numel(L.X), idxEnd + 1);

                xVis = L.X(idxStart:idxEnd);
                yVis = L.Y(idxStart:idxEnd);

                % Downsample if needed
                nVis = idxEnd - idxStart + 1;
                if nVis > obj.MIN_POINTS_FOR_DOWNSAMPLE
                    if strcmp(L.DownsampleMethod, 'lttb')
                        [xd, yd] = lttb_downsample(xVis, yVis, pw);
                    else
                        [xd, yd] = minmax_downsample(xVis, yVis, pw);
                    end
                else
                    xd = xVis;
                    yd = yVis;
                end

                % Update line (no recreation)
                set(L.hLine, 'XData', xd, 'YData', yd);
            end
        end

        function updateViolations(obj)
            for t = 1:numel(obj.Thresholds)
                if ~obj.Thresholds(t).ShowViolations || isempty(obj.Thresholds(t).hMarkers)
                    continue;
                end
                if ~ishandle(obj.Thresholds(t).hMarkers)
                    continue;
                end

                vxAll = [];
                vyAll = [];
                for i = 1:numel(obj.Lines)
                    % Use already-downsampled data from the line handle
                    xd = get(obj.Lines(i).hLine, 'XData');
                    yd = get(obj.Lines(i).hLine, 'YData');

                    [vx, vy] = compute_violations(xd, yd, ...
                        obj.Thresholds(t).Value, obj.Thresholds(t).Direction);
                    if ~isempty(vx)
                        vxAll = [vxAll, vx, NaN]; %#ok<AGROW>
                        vyAll = [vyAll, vy, NaN]; %#ok<AGROW>
                    end
                end

                if ~isempty(vxAll)
                    vxAll = vxAll(1:end-1);
                    vyAll = vyAll(1:end-1);
                    set(obj.Thresholds(t).hMarkers, 'XData', vxAll, 'YData', vyAll);
                else
                    set(obj.Thresholds(t).hMarkers, 'XData', NaN, 'YData', NaN);
                end
            end
        end

        function drawnowLimitRate(obj)
            if isempty(obj.HasLimitRate)
                obj.HasLimitRate = exist('OCTAVE_VERSION', 'builtin') == 0;
            end
            if obj.HasLimitRate
                drawnow limitrate;
            else
                drawnow;
            end
        end

        function pw = getAxesPixelWidth(obj)
            oldUnits = get(obj.hAxes, 'Units');
            set(obj.hAxes, 'Units', 'pixels');
            pos = get(obj.hAxes, 'Position');
            set(obj.hAxes, 'Units', oldUnits);
            pw = max(100, floor(pos(3)));
        end

        function propagateXLim(obj, newXLim)
            members = FastPlot.getLinkRegistry('get', obj.LinkGroup, []);
            for i = 1:numel(members)
                other = members{i};
                if other.hAxes ~= obj.hAxes && ishandle(other.hAxes)
                    other.IsPropagating = true;
                    other.CachedXLim = newXLim;
                    set(other.hAxes, 'XLim', newXLim);
                    other.updateLines();
                    other.updateViolations();
                    other.IsPropagating = false;
                end
            end
        end
    end

    methods (Static, Access = private)
        function registry = getLinkRegistry(action, group, obj)
            %GETLINKREGISTRY Persistent registry for linked FastPlot instances.
            persistent reg;
            if isempty(reg)
                reg = struct();
            end

            switch action
                case 'register'
                    safeGroup = matlab.lang.makeValidName(group);
                    if ~isfield(reg, safeGroup)
                        reg.(safeGroup) = {};
                    end
                    reg.(safeGroup){end+1} = obj;

                case 'get'
                    safeGroup = matlab.lang.makeValidName(group);
                    if isfield(reg, safeGroup)
                        registry = reg.(safeGroup);
                    else
                        registry = {};
                    end
                    return;

                case 'cleanup'
                    safeGroup = matlab.lang.makeValidName(group);
                    if isfield(reg, safeGroup)
                        alive = cellfun(@(o) ishandle(o.hAxes), reg.(safeGroup));
                        reg.(safeGroup) = reg.(safeGroup)(alive);
                    end
            end
            registry = [];
        end
    end
end
