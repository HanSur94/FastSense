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
        Theme      = []       % theme struct (from FastPlotTheme)
        XType      = 'numeric'   % 'numeric' or 'datenum'
    end

    properties (SetAccess = private)
        Lines      = struct('X', {}, 'Y', {}, 'Options', {}, ...
                            'DownsampleMethod', {}, 'hLine', {}, ...
                            'Pyramid', {}, 'HasNaN', {})
        Thresholds = struct('Value', {}, 'Direction', {}, ...
                            'ShowViolations', {}, 'Color', {}, ...
                            'LineStyle', {}, 'Label', {}, ...
                            'hLine', {}, 'hMarkers', {})
        Bands      = struct('YLow', {}, 'YHigh', {}, 'FaceColor', {}, ...
                            'FaceAlpha', {}, 'EdgeColor', {}, 'Label', {}, ...
                            'hPatch', {})
        Markers    = struct('X', {}, 'Y', {}, 'Marker', {}, ...
                            'MarkerSize', {}, 'Color', {}, 'Label', {}, ...
                            'hLine', {})
        Shadings   = struct('X', {}, 'Y1', {}, 'Y2', {}, ...
                            'FaceColor', {}, 'FaceAlpha', {}, ...
                            'EdgeColor', {}, 'DisplayName', {}, ...
                            'hPatch', {}, ...
                            'CacheX', {}, 'CacheY1', {}, 'CacheY2', {})
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
        ColorIndex    = 0     % tracks auto color cycling position
    end

    properties (Constant, Access = private)
        MIN_POINTS_FOR_DOWNSAMPLE = 5000  % below this, plot raw data
        DOWNSAMPLE_FACTOR = 2             % points per pixel (min + max)
        PYRAMID_REDUCTION = 100           % reduction factor per pyramid level
    end

    methods (Access = public)
        function obj = FastPlot(varargin)
            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'parent'
                        obj.ParentAxes = varargin{k+1};
                    case 'linkgroup'
                        obj.LinkGroup = varargin{k+1};
                    case 'theme'
                        val = varargin{k+1};
                        if ischar(val) || isstruct(val)
                            obj.Theme = FastPlotTheme(val);
                        else
                            obj.Theme = val;
                        end
                end
            end
            % Default theme if none set
            if isempty(obj.Theme)
                obj.Theme = FastPlotTheme('default');
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

            % Detect and convert datetime input
            if isa(x, 'datetime')
                x = datenum(x);
                if strcmp(obj.XType, 'numeric')
                    obj.XType = 'datenum';
                end
            end

            % Validate sizes match
            if numel(x) ~= numel(y)
                error('FastPlot:sizeMismatch', ...
                    'X and Y must have the same number of elements.');
            end

            % Monotonicity check (chunked vectorized — limits peak memory)
            chunkSize = 1000000;
            nX = numel(x);
            for ci = 1:chunkSize:nX-1
                ce = min(ci + chunkSize, nX);
                dx = diff(x(ci:ce));
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
                elseif strcmpi(key, 'XType')
                    if strcmp(obj.XType, 'numeric') || strcmp(obj.XType, val)
                        obj.XType = val;
                    else
                        error('FastPlot:mixedXType', ...
                            'All lines must use the same XType.');
                    end
                else
                    opts.(key) = val;
                end
                k = k + 2;
            end

            % Auto-assign color from theme palette if not explicitly set
            if ~isfield(opts, 'Color')
                obj.ColorIndex = obj.ColorIndex + 1;
                palette = obj.Theme.LineColorOrder;
                idx = mod(obj.ColorIndex - 1, size(palette, 1)) + 1;
                opts.Color = palette(idx, :);
            end

            % Build line struct
            lineStruct.X = x;
            lineStruct.Y = y;
            lineStruct.DownsampleMethod = dsMethod;
            lineStruct.Options = opts;
            lineStruct.hLine = [];
            lineStruct.Pyramid = {};
            lineStruct.HasNaN = any(isnan(y));

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
            t.Color          = obj.Theme.ThresholdColor;
            t.LineStyle      = obj.Theme.ThresholdStyle;
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

        function addBand(obj, yLow, yHigh, varargin)
            %ADDBAND Add a horizontal band fill (constant y bounds).
            %   fp.addBand(yLow, yHigh)
            %   fp.addBand(yLow, yHigh, 'FaceColor', [1 0.9 0.9], 'FaceAlpha', 0.3)

            if obj.IsRendered
                error('FastPlot:alreadyRendered', ...
                    'Cannot add bands after render() has been called.');
            end

            b.YLow      = yLow;
            b.YHigh     = yHigh;
            b.FaceColor = obj.Theme.ThresholdColor;
            b.FaceAlpha = obj.Theme.BandAlpha;
            b.EdgeColor = 'none';
            b.Label     = '';
            b.hPatch    = [];

            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'facecolor'
                        b.FaceColor = varargin{k+1};
                    case 'facealpha'
                        b.FaceAlpha = varargin{k+1};
                    case 'edgecolor'
                        b.EdgeColor = varargin{k+1};
                    case 'label'
                        b.Label = varargin{k+1};
                end
            end

            if isempty(obj.Bands)
                obj.Bands = b;
            else
                obj.Bands(end+1) = b;
            end
        end

        function addMarker(obj, x, y, varargin)
            %ADDMARKER Add custom event markers at specific positions.
            %   fp.addMarker(x, y)
            %   fp.addMarker(x, y, 'Marker', 'v', 'MarkerSize', 8, 'Color', [1 0 0])

            if obj.IsRendered
                error('FastPlot:alreadyRendered', ...
                    'Cannot add markers after render() has been called.');
            end

            if ~isrow(x); x = x(:)'; end
            if ~isrow(y); y = y(:)'; end

            m.X          = x;
            m.Y          = y;
            m.Marker     = 'o';
            m.MarkerSize = 6;
            m.Color      = obj.Theme.ThresholdColor;
            m.Label      = '';
            m.hLine      = [];

            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'marker'
                        m.Marker = varargin{k+1};
                    case 'markersize'
                        m.MarkerSize = varargin{k+1};
                    case 'color'
                        m.Color = varargin{k+1};
                    case 'label'
                        m.Label = varargin{k+1};
                end
            end

            if isempty(obj.Markers)
                obj.Markers = m;
            else
                obj.Markers(end+1) = m;
            end
        end

        function addShaded(obj, x, y1, y2, varargin)
            %ADDSHADED Add a shaded region between two curves.
            %   fp.addShaded(x, y_upper, y_lower)
            %   fp.addShaded(x, y1, y2, 'FaceColor', [0 0 1], 'FaceAlpha', 0.2)

            if obj.IsRendered
                error('FastPlot:alreadyRendered', ...
                    'Cannot add shaded regions after render() has been called.');
            end

            if ~isrow(x); x = x(:)'; end
            if ~isrow(y1); y1 = y1(:)'; end
            if ~isrow(y2); y2 = y2(:)'; end

            if numel(x) ~= numel(y1) || numel(x) ~= numel(y2)
                error('FastPlot:sizeMismatch', ...
                    'X, Y1, and Y2 must have the same number of elements.');
            end

            chunkSize = 1000000;
            nX = numel(x);
            for ci = 1:chunkSize:nX-1
                ce = min(ci + chunkSize, nX);
                dx = diff(x(ci:ce));
                if any(dx(~isnan(dx)) < 0)
                    error('FastPlot:nonMonotonicX', ...
                        'X must be monotonically increasing.');
                end
            end

            s.X           = x;
            s.Y1          = y1;
            s.Y2          = y2;
            s.FaceColor   = [0 0.45 0.74];
            s.FaceAlpha   = 0.15;
            s.EdgeColor   = 'none';
            s.DisplayName = '';
            s.hPatch      = [];
            s.CacheX      = [];
            s.CacheY1     = [];
            s.CacheY2     = [];

            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'facecolor'
                        s.FaceColor = varargin{k+1};
                    case 'facealpha'
                        s.FaceAlpha = varargin{k+1};
                    case 'edgecolor'
                        s.EdgeColor = varargin{k+1};
                    case 'displayname'
                        s.DisplayName = varargin{k+1};
                end
            end

            if isempty(obj.Shadings)
                obj.Shadings = s;
            else
                obj.Shadings(end+1) = s;
            end
        end

        function addFill(obj, x, y, varargin)
            %ADDFILL Add an area fill from a line to a baseline.
            %   fp.addFill(x, y)
            %   fp.addFill(x, y, 'Baseline', -1, 'FaceColor', [0 0.5 1])

            baseline = 0;
            filteredArgs = {};
            k = 1;
            while k <= numel(varargin)
                if strcmpi(varargin{k}, 'Baseline')
                    baseline = varargin{k+1};
                    k = k + 2;
                else
                    filteredArgs{end+1} = varargin{k};   %#ok<AGROW>
                    filteredArgs{end+1} = varargin{k+1};  %#ok<AGROW>
                    k = k + 2;
                end
            end

            if ~isrow(x); x = x(:)'; end
            if ~isrow(y); y = y(:)'; end
            y2 = ones(size(x)) * baseline;
            obj.addShaded(x, y, y2, filteredArgs{:});
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
            obj.applyTheme();

            % --- Compute full X range (X is sorted, just check endpoints) ---
            xmin = Inf; xmax = -Inf;
            for i = 1:numel(obj.Lines)
                xi = obj.Lines(i).X;
                if xi(1) < xmin; xmin = xi(1); end
                if xi(end) > xmax; xmax = xi(end); end
            end

            % --- Render bands (constant y, full x span, back layer) ---
            for i = 1:numel(obj.Bands)
                B = obj.Bands(i);
                patchX = [xmin, xmax, xmax, xmin];
                patchY = [B.YLow, B.YLow, B.YHigh, B.YHigh];
                hP = patch(patchX, patchY, B.FaceColor, ...
                    'Parent', obj.hAxes, ...
                    'FaceAlpha', B.FaceAlpha, ...
                    'EdgeColor', B.EdgeColor, ...
                    'HandleVisibility', 'off');
                udB.FastPlot = struct( ...
                    'Type', 'band', ...
                    'Name', B.Label, ...
                    'LineIndex', [], ...
                    'ThresholdValue', []);
                set(hP, 'UserData', udB);
                obj.Bands(i).hPatch = hP;
            end

            % --- Render shaded regions (downsample for initial render) ---
            shadingCacheSize = 10000; % pre-downsample cache for fast zoom
            for i = 1:numel(obj.Shadings)
                S = obj.Shadings(i);
                if numel(S.X) > shadingCacheSize * 2
                    % Build cache from raw, then render from cache
                    [cx, cy1] = minmax_downsample(S.X, S.Y1, shadingCacheSize);
                    [~,  cy2] = minmax_downsample(S.X, S.Y2, shadingCacheSize);
                    obj.Shadings(i).CacheX  = cx;
                    obj.Shadings(i).CacheY1 = cy1;
                    obj.Shadings(i).CacheY2 = cy2;
                    % Downsample cache to screen resolution
                    [xd, y1d] = minmax_downsample(cx, cy1, obj.PixelWidth);
                    [~,  y2d] = minmax_downsample(cx, cy2, obj.PixelWidth);
                    patchX = [xd, fliplr(xd)];
                    patchY = [y1d, fliplr(y2d)];
                elseif numel(S.X) > obj.MIN_POINTS_FOR_DOWNSAMPLE
                    [xd, y1d] = minmax_downsample(S.X, S.Y1, obj.PixelWidth);
                    [~,  y2d] = minmax_downsample(S.X, S.Y2, obj.PixelWidth);
                    patchX = [xd, fliplr(xd)];
                    patchY = [y1d, fliplr(y2d)];
                else
                    patchX = [S.X, fliplr(S.X)];
                    patchY = [S.Y1, fliplr(S.Y2)];
                end
                hP = patch(patchX, patchY, S.FaceColor, ...
                    'Parent', obj.hAxes, ...
                    'FaceAlpha', S.FaceAlpha, ...
                    'EdgeColor', S.EdgeColor, ...
                    'HandleVisibility', 'off');
                udS.FastPlot = struct( ...
                    'Type', 'shaded', ...
                    'Name', S.DisplayName, ...
                    'LineIndex', [], ...
                    'ThresholdValue', []);
                set(hP, 'UserData', udS);
                obj.Shadings(i).hPatch = hP;
            end

            % --- Render data lines ---
            for i = 1:numel(obj.Lines)
                L = obj.Lines(i);
                numBuckets = obj.PixelWidth;

                % Downsample
                if numel(L.X) > obj.MIN_POINTS_FOR_DOWNSAMPLE
                    if strcmp(L.DownsampleMethod, 'lttb')
                        [xd, yd] = lttb_downsample(L.X, L.Y, numBuckets);
                    else
                        [xd, yd] = minmax_downsample(L.X, L.Y, numBuckets, L.HasNaN);
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
                    nLines = numel(obj.Lines);
                    vxCell = cell(1, nLines);
                    vyCell = cell(1, nLines);
                    nViols = 0;
                    for i = 1:nLines
                        xd = get(obj.Lines(i).hLine, 'XData');
                        yd = get(obj.Lines(i).hLine, 'YData');
                        [vx, vy] = compute_violations( ...
                            xd, yd, T.Value, T.Direction);
                        if ~isempty(vx)
                            nViols = nViols + 1;
                            vxCell{nViols} = [vx, NaN];
                            vyCell{nViols} = [vy, NaN];
                        end
                    end
                    if nViols > 0
                        vxAll = [vxCell{1:nViols}];
                        vyAll = [vyCell{1:nViols}];
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

            % --- Render custom markers (front layer) ---
            for i = 1:numel(obj.Markers)
                M = obj.Markers(i);
                hM = line(M.X, M.Y, 'Parent', obj.hAxes, ...
                    'LineStyle', 'none', ...
                    'Marker', M.Marker, ...
                    'MarkerSize', M.MarkerSize, ...
                    'Color', M.Color, ...
                    'HandleVisibility', 'off');
                udM.FastPlot = struct( ...
                    'Type', 'marker', ...
                    'Name', M.Label, ...
                    'LineIndex', [], ...
                    'ThresholdValue', []);
                set(hM, 'UserData', udM);
                obj.Markers(i).hLine = hM;
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
        function applyTheme(obj)
            t = obj.Theme;

            % Figure background (only if we own the figure)
            if isempty(obj.ParentAxes)
                set(obj.hFigure, 'Color', t.Background);
            end

            % Axes
            set(obj.hAxes, 'Color', t.AxesColor);
            set(obj.hAxes, 'XColor', t.ForegroundColor);
            set(obj.hAxes, 'YColor', t.ForegroundColor);
            set(obj.hAxes, 'FontName', t.FontName);
            set(obj.hAxes, 'FontSize', t.FontSize);

            % Grid
            if strcmp(t.GridStyle, 'none') || t.GridAlpha == 0
                grid(obj.hAxes, 'off');
            else
                grid(obj.hAxes, 'on');
                set(obj.hAxes, 'GridColor', t.GridColor);
                set(obj.hAxes, 'GridAlpha', t.GridAlpha);
                set(obj.hAxes, 'GridLineStyle', t.GridStyle);
            end
        end

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
            obj.updateShadings();
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
                obj.updateShadings();
                obj.drawnowLimitRate();
            end
        end

        function updateShadings(obj)
            pw = obj.PixelWidth;
            xlims = get(obj.hAxes, 'XLim');

            for i = 1:numel(obj.Shadings)
                S = obj.Shadings(i);
                if isempty(S.hPatch) || ~ishandle(S.hPatch)
                    continue;
                end

                % Use pre-downsampled cache if available (much faster for large data)
                if ~isempty(S.CacheX)
                    srcX  = S.CacheX;
                    srcY1 = S.CacheY1;
                    srcY2 = S.CacheY2;
                else
                    srcX  = S.X;
                    srcY1 = S.Y1;
                    srcY2 = S.Y2;
                end

                nTotal = numel(srcX);
                idxStart = binary_search(srcX, xlims(1), 'left');
                idxEnd   = binary_search(srcX, xlims(2), 'right');
                idxStart = max(1, idxStart - 1);
                idxEnd   = min(nTotal, idxEnd + 1);
                nVis = idxEnd - idxStart + 1;

                xVis  = srcX(idxStart:idxEnd);
                y1Vis = srcY1(idxStart:idxEnd);
                y2Vis = srcY2(idxStart:idxEnd);

                if nVis > obj.MIN_POINTS_FOR_DOWNSAMPLE
                    [xd, y1d] = minmax_downsample(xVis, y1Vis, pw);
                    [~, y2d]  = minmax_downsample(xVis, y2Vis, pw);
                    patchX = [xd, fliplr(xd)];
                    patchY = [y1d, fliplr(y2d)];
                else
                    patchX = [xVis, fliplr(xVis)];
                    patchY = [y1Vis, fliplr(y2Vis)];
                end

                set(S.hPatch, 'XData', patchX, 'YData', patchY);
            end
        end

        function updateLines(obj)
            pw = obj.PixelWidth;
            xlims = get(obj.hAxes, 'XLim');
            target = 2 * pw;

            for i = 1:numel(obj.Lines)
                nTotal = numel(obj.Lines(i).X);

                % Binary search on raw X for visible range
                idxStart = binary_search(obj.Lines(i).X, xlims(1), 'left');
                idxEnd   = binary_search(obj.Lines(i).X, xlims(2), 'right');
                idxStart = max(1, idxStart - 1);
                idxEnd   = min(nTotal, idxEnd + 1);
                nVis = idxEnd - idxStart + 1;

                if nVis <= obj.MIN_POINTS_FOR_DOWNSAMPLE
                    % Small enough to plot raw
                    xd = obj.Lines(i).X(idxStart:idxEnd);
                    yd = obj.Lines(i).Y(idxStart:idxEnd);
                else
                    % Select best pyramid level
                    lvl = obj.selectPyramidLevel(i, nVis, nTotal, target);

                    if lvl == 0
                        % Use raw data
                        xVis = obj.Lines(i).X(idxStart:idxEnd);
                        yVis = obj.Lines(i).Y(idxStart:idxEnd);
                    else
                        % Query pyramid level
                        P = obj.Lines(i).Pyramid{lvl};
                        pStart = binary_search(P.X, xlims(1), 'left');
                        pEnd   = binary_search(P.X, xlims(2), 'right');
                        pStart = max(1, pStart - 1);
                        pEnd   = min(numel(P.X), pEnd + 1);
                        xVis = P.X(pStart:pEnd);
                        yVis = P.Y(pStart:pEnd);
                    end

                    % Downsample visible slice to screen resolution
                    if numel(xVis) > obj.MIN_POINTS_FOR_DOWNSAMPLE
                        if strcmp(obj.Lines(i).DownsampleMethod, 'lttb')
                            [xd, yd] = lttb_downsample(xVis, yVis, pw);
                        else
                            [xd, yd] = minmax_downsample(xVis, yVis, pw, obj.Lines(i).HasNaN);
                        end
                    else
                        xd = xVis;
                        yd = yVis;
                    end
                end

                set(obj.Lines(i).hLine, 'XData', xd, 'YData', yd);
            end
        end

        function lvl = selectPyramidLevel(obj, lineIdx, nVis, nTotal, target)
            %SELECTPYRAMIDLEVEL Pick the smallest pyramid level with enough
            %   resolution for the visible range. Builds levels lazily.
            visFrac = nVis / nTotal;
            R = obj.PYRAMID_REDUCTION;

            % How many levels could exist?
            maxLevels = 0;
            sz = nTotal;
            while sz / R > target
                maxLevels = maxLevels + 1;
                sz = sz / R;
            end

            % Try from coarsest (highest level) to finest
            lvl = 0;
            for k = maxLevels:-1:1
                levelSize = nTotal / (R ^ k);
                levelVisible = levelSize * visFrac;
                if levelVisible >= target
                    % This level has enough resolution
                    % Build if needed
                    if numel(obj.Lines(lineIdx).Pyramid) < k || isempty(obj.Lines(lineIdx).Pyramid{k})
                        obj.buildPyramidLevel(lineIdx, k);
                    end
                    lvl = k;
                    return;
                end
            end
        end

        function buildPyramidLevel(obj, lineIdx, level)
            %BUILDPYRAMIDLEVEL Build a pyramid level from the nearest source.
            R = obj.PYRAMID_REDUCTION;

            % Ensure cell array is large enough
            if numel(obj.Lines(lineIdx).Pyramid) < level
                obj.Lines(lineIdx).Pyramid{level} = [];
            end

            % Build from previous level if available, otherwise raw
            if level == 1
                srcX = obj.Lines(lineIdx).X;
                srcY = obj.Lines(lineIdx).Y;
            else
                % Ensure previous level exists
                if numel(obj.Lines(lineIdx).Pyramid) < level - 1 || isempty(obj.Lines(lineIdx).Pyramid{level - 1})
                    obj.buildPyramidLevel(lineIdx, level - 1);
                end
                srcX = obj.Lines(lineIdx).Pyramid{level - 1}.X;
                srcY = obj.Lines(lineIdx).Pyramid{level - 1}.Y;
            end

            numBuckets = max(1, round(numel(srcX) / R));
            [px, py] = minmax_downsample(srcX, srcY, numBuckets);
            obj.Lines(lineIdx).Pyramid{level} = struct('X', px, 'Y', py);
        end

        function updateViolations(obj)
            for t = 1:numel(obj.Thresholds)
                if ~obj.Thresholds(t).ShowViolations || isempty(obj.Thresholds(t).hMarkers)
                    continue;
                end
                if ~ishandle(obj.Thresholds(t).hMarkers)
                    continue;
                end

                nLines = numel(obj.Lines);
                vxCell = cell(1, nLines);
                vyCell = cell(1, nLines);
                nViols = 0;
                for i = 1:nLines
                    % Use already-downsampled data from the line handle
                    xd = get(obj.Lines(i).hLine, 'XData');
                    yd = get(obj.Lines(i).hLine, 'YData');

                    [vx, vy] = compute_violations(xd, yd, ...
                        obj.Thresholds(t).Value, obj.Thresholds(t).Direction);
                    if ~isempty(vx)
                        nViols = nViols + 1;
                        vxCell{nViols} = [vx, NaN];
                        vyCell{nViols} = [vy, NaN];
                    end
                end

                if nViols > 0
                    vxAll = [vxCell{1:nViols}];
                    vyAll = [vyCell{1:nViols}];
                    % Remove trailing NaN
                    set(obj.Thresholds(t).hMarkers, 'XData', vxAll(1:end-1), 'YData', vyAll(1:end-1));
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
                    other.updateShadings();
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
