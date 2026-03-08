classdef FastPlot < handle
    %FASTPLOT Ultra-fast time series plotting with dynamic downsampling.
    %   FastPlot renders 1K to 100M data points with fluid zoom/pan by
    %   dynamically downsampling data to screen resolution using MinMax or
    %   LTTB algorithms. A multi-level pyramid cache provides instant
    %   re-downsample on zoom without touching raw data.
    %
    %   Features:
    %     - Automatic MinMax/LTTB downsampling to pixel resolution
    %     - Pyramid-based zoom for O(1) re-downsample on pan/zoom
    %     - Linked zoom/pan across multiple plots via LinkGroup
    %     - Threshold lines with automatic violation markers
    %     - Horizontal bands, shaded regions, and area fills
    %     - Live mode: poll a .mat file and auto-refresh on change
    %     - Metadata attachment and forward-fill lookup by X value
    %     - Datetime X-axis support with auto-formatting
    %     - Theme-based styling via FastPlotTheme
    %
    %   Usage:
    %     fp = FastPlot();
    %     fp.addLine(x, y, 'DisplayName', 'Sensor1');
    %     fp.addThreshold(4.5, 'Direction', 'upper', 'ShowViolations', true);
    %     fp.render();
    %
    %   Constructor options (name-value):
    %     'Parent'        — axes handle (default: create new figure)
    %     'LinkGroup'     — string ID for linked zoom/pan across plots
    %     'Theme'         — theme preset name, struct, or FastPlotTheme
    %     'Verbose'       — logical, print diagnostics (default: false)
    %     'MinPointsForDownsample' — threshold for raw vs downsampled
    %     'DownsampleFactor'       — points per pixel (default: 2)
    %     'PyramidReduction'       — compression per pyramid level
    %     'DefaultDownsampleMethod' — 'minmax' or 'lttb'
    %     'LiveInterval'  — poll interval in seconds (default: 2.0)
    %
    %   Example — linked zoom across two plots:
    %     fp1 = FastPlot('LinkGroup', 'group1');
    %     fp1.addLine(x, y1, 'DisplayName', 'Temp');
    %     fp1.render();
    %     fp2 = FastPlot('LinkGroup', 'group1');
    %     fp2.addLine(x, y2, 'DisplayName', 'Pressure');
    %     fp2.render();
    %
    %   Example — live mode:
    %     fp = FastPlot(); fp.addLine(x, y); fp.render();
    %     fp.startLive('data.mat', @(fp, s) fp.updateData(1, s.x, s.y));
    %
    %   See also FastPlotFigure, FastPlotDock, FastPlotTheme, FastPlotToolbar.

    % ========================= PUBLIC PROPERTIES =========================
    % User-configurable settings. Set before calling render().
    properties (Access = public)
        ParentAxes = []       % axes handle, empty = create new
        LinkGroup  = ''       % string ID for linked zoom/pan
        Theme      = []       % theme struct (from FastPlotTheme)
        Verbose    = false       % print diagnostics to console
        LiveViewMode = ''  % 'preserve' | 'follow' | 'reset' (empty = no view mode applied)
        LiveFile       = ''        % path to .mat file for live mode
        LiveUpdateFcn  = []        % @(fp, data) callback for live updates
        LiveIsActive   = false     % whether live polling is running
        LiveInterval   = 2.0       % poll interval in seconds
        MetadataFile      = ''        % path to separate .mat file for metadata
        MetadataVars      = {}        % cell array of variable names to extract
        MetadataLineIndex = 1         % which line index to attach metadata to
        DeferDraw = false             % skip drawnow during batch render
    end

    % ====================== INTERNAL DATA STORAGE ========================
    % Struct arrays holding line data, annotations, and graphics handles.
    % SetAccess = private prevents external modification of plot state.
    properties (SetAccess = private)
        Lines      = struct('X', {}, 'Y', {}, 'Options', {}, ...
                            'DownsampleMethod', {}, 'hLine', {}, ...
                            'Pyramid', {}, 'HasNaN', {}, 'Metadata', {})
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
        IsDatetime    = false % true if X data was datetime (converted to datenum)
    end

    % ======================== PRIVATE STATE ==============================
    % Internal bookkeeping: listeners, caches, timers, and flags.
    properties (Access = private)
        Listeners     = []    % event listeners (XLim, resize)
        CachedXLim    = []    % for lazy recomputation
        FullXLim      = []    % full data range for Home button restore
        FullYLim      = []    % full data Y range for Home button restore
        PixelWidth    = 1920  % cached axes width in pixels
        IsPropagating = false % guard against re-entrant link propagation
        HasLimitRate  = []    % cached: does drawnow support 'limitrate'?
        DeferredTimer = []    % timer for deferred Home button re-downsample
        ColorIndex    = 0     % tracks auto color cycling position
        LiveTimer      = []        % timer object for live polling
        LiveFileDate   = 0         % last known file modification datenum
        MetadataFileDate  = 0         % last known metadata file datenum
    end

    % ===================== PERFORMANCE TUNING ============================
    % Configurable performance parameters. Override via constructor or
    % set before calling render().
    properties (Access = public)
        MinPointsForDownsample = 5000  % below this, plot raw data
        DownsampleFactor = 2           % points per pixel (min + max)
        PyramidReduction = 100         % reduction factor per pyramid level
        DefaultDownsampleMethod = 'minmax'  % 'minmax' or 'lttb'
    end

    methods (Access = public)
        function obj = FastPlot(varargin)
            %FASTPLOT Construct a FastPlot instance.
            %   fp = FastPlot()
            %   fp = FastPlot('Parent', ax, 'Theme', 'dark')
            %   fp = FastPlot('LinkGroup', 'g1', 'Verbose', true)
            %
            %   All options are name-value pairs. Defaults are loaded from
            %   FastPlotDefaults and can be overridden per-instance.
            cfg = getDefaults();
            defaults.Parent = [];
            defaults.LinkGroup = '';
            defaults.Theme = [];
            defaults.Verbose = cfg.Verbose;
            defaults.MinPointsForDownsample = cfg.MinPointsForDownsample;
            defaults.DownsampleFactor = cfg.DownsampleFactor;
            defaults.PyramidReduction = cfg.PyramidReduction;
            defaults.DefaultDownsampleMethod = cfg.DefaultDownsampleMethod;
            defaults.LiveInterval = cfg.LiveInterval;
            [opts, ~] = parseOpts(defaults, varargin);

            obj.ParentAxes = opts.Parent;
            obj.LinkGroup = opts.LinkGroup;
            obj.Verbose = opts.Verbose;
            obj.MinPointsForDownsample = opts.MinPointsForDownsample;
            obj.DownsampleFactor = opts.DownsampleFactor;
            obj.PyramidReduction = opts.PyramidReduction;
            obj.DefaultDownsampleMethod = opts.DefaultDownsampleMethod;
            obj.LiveInterval = opts.LiveInterval;
            obj.Theme = resolveTheme(opts.Theme, cfg.Theme);
        end

        function resetColorIndex(obj)
            %RESETCOLORINDEX Reset the auto color cycling counter.
            %   fp.resetColorIndex()
            %   Next addLine() call without explicit Color will use the first
            %   color from the theme palette.
            obj.ColorIndex = 0;
        end

        function reapplyTheme(obj)
            %REAPPLYTHEME Re-apply the current Theme to axes and figure.
            %   Use after changing fp.Theme to update existing visuals.
            if ~obj.IsRendered; return; end
            obj.applyTheme();
            % Update existing line widths
            for i = 1:numel(obj.Lines)
                if ~isempty(obj.Lines(i).hLine) && ishandle(obj.Lines(i).hLine)
                    set(obj.Lines(i).hLine, 'LineWidth', obj.Theme.LineWidth);
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

            % Convert datetime X to datenum for internal use
            try
                if isdatetime(x)
                    x = datenum(x);
                    obj.IsDatetime = true;
                end
            catch
                % Octave: isdatetime may not exist — skip gracefully
            end

            % Force row vectors (avoid copy if already row)
            if ~isrow(x); x = x(:)'; end
            if ~isrow(y); y = y(:)'; end

            % Validate sizes match
            if numel(x) ~= numel(y)
                error('FastPlot:sizeMismatch', ...
                    'X and Y must have the same number of elements.');
            end

            % Parse name-value pairs via shared helper
            knownDefaults.DownsampleMethod = obj.DefaultDownsampleMethod;
            knownDefaults.Metadata = [];
            knownDefaults.AssumeSorted = false;
            knownDefaults.HasNaN = [];
            [known, passthrough] = parseOpts(knownDefaults, varargin, obj.Verbose);

            dsMethod = known.DownsampleMethod;
            meta = known.Metadata;
            assumeSorted = known.AssumeSorted;
            hasNaNOverride = known.HasNaN;
            opts = passthrough;

            % Monotonicity check (chunked vectorized — limits peak memory)
            if ~assumeSorted
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
            if ~isempty(hasNaNOverride)
                lineStruct.HasNaN = hasNaNOverride;
            else
                lineStruct.HasNaN = any(isnan(y));
            end
            lineStruct.Metadata = meta;

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

            defaults.Direction = 'upper';
            defaults.ShowViolations = false;
            defaults.Color = obj.Theme.ThresholdColor;
            defaults.LineStyle = obj.Theme.ThresholdStyle;
            defaults.Label = '';
            [parsed, ~] = parseOpts(defaults, varargin, obj.Verbose);

            t.Value          = value;
            t.Direction      = parsed.Direction;
            t.ShowViolations = parsed.ShowViolations;
            t.Color          = parsed.Color;
            t.LineStyle      = parsed.LineStyle;
            t.Label          = parsed.Label;
            t.hLine          = [];
            t.hMarkers       = [];

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

            defaults.FaceColor = obj.Theme.ThresholdColor;
            defaults.FaceAlpha = obj.Theme.BandAlpha;
            defaults.EdgeColor = 'none';
            defaults.Label = '';
            [parsed, ~] = parseOpts(defaults, varargin, obj.Verbose);

            b.YLow      = yLow;
            b.YHigh     = yHigh;
            b.FaceColor = parsed.FaceColor;
            b.FaceAlpha = parsed.FaceAlpha;
            b.EdgeColor = parsed.EdgeColor;
            b.Label     = parsed.Label;
            b.hPatch    = [];

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

            defaults.Marker = 'o';
            defaults.MarkerSize = 6;
            defaults.Color = obj.Theme.ThresholdColor;
            defaults.Label = '';
            [parsed, ~] = parseOpts(defaults, varargin, obj.Verbose);

            m.X          = x;
            m.Y          = y;
            m.Marker     = parsed.Marker;
            m.MarkerSize = parsed.MarkerSize;
            m.Color      = parsed.Color;
            m.Label      = parsed.Label;
            m.hLine      = [];

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

            defaults.FaceColor = [0 0.45 0.74];
            defaults.FaceAlpha = 0.15;
            defaults.EdgeColor = 'none';
            defaults.DisplayName = '';
            [parsed, ~] = parseOpts(defaults, varargin, obj.Verbose);

            s.X           = x;
            s.Y1          = y1;
            s.Y2          = y2;
            s.FaceColor   = parsed.FaceColor;
            s.FaceAlpha   = parsed.FaceAlpha;
            s.EdgeColor   = parsed.EdgeColor;
            s.DisplayName = parsed.DisplayName;
            s.hPatch      = [];
            s.CacheX      = [];
            s.CacheY1     = [];
            s.CacheY2     = [];

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

            % Convert datetime X to datenum
            try
                if isdatetime(x)
                    x = datenum(x);
                    obj.IsDatetime = true;
                end
            catch
            end

            fillDefaults.Baseline = 0;
            [fillOpts, shadedArgs] = parseOpts(fillDefaults, varargin, obj.Verbose);

            if ~isrow(x); x = x(:)'; end
            if ~isrow(y); y = y(:)'; end
            y2 = ones(size(x)) * fillOpts.Baseline;
            shadedNV = struct2nvpairs(shadedArgs);
            obj.addShaded(x, y, y2, shadedNV{:});
        end

        function render(obj)
            %RENDER Create the plot with all configured lines and annotations.
            %   fp.render()
            %
            %   Finalizes the plot: creates axes (if needed), applies the
            %   theme, downsamples all lines to screen resolution, draws
            %   bands/shadings/thresholds/markers, sets axis limits, and
            %   installs zoom/pan listeners. Can only be called once.
            %
            %   After render(), use updateData() for live updates and
            %   addLine()/addThreshold() will error.

            if obj.Verbose; renderTic = tic; end

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
                elseif numel(S.X) > obj.MinPointsForDownsample
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
                if numel(L.X) > obj.MinPointsForDownsample
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

                % Apply user options (batch — single graphics update)
                if ~isempty(fieldnames(L.Options))
                    try
                        set(h, L.Options);
                    catch
                        % Octave fallback: struct form not supported
                        fnames = fieldnames(L.Options);
                        for f = 1:numel(fnames)
                            set(h, fnames{f}, L.Options.(fnames{f}));
                        end
                    end
                end

                % Tag with UserData
                displayName = '';
                if isfield(L.Options, 'DisplayName')
                    displayName = L.Options.DisplayName;
                end
                ud.FastPlot = struct( ...
                    'Type', 'data_line', ...
                    'Name', displayName, ...
                    'LineIndex', i, ...
                    'ThresholdValue', []);
                ud.FastPlotInstance = obj;
                set(h, 'UserData', ud);

                obj.Lines(i).hLine = h;

                if obj.Verbose
                    fprintf('[FastPlot] render: line %d: %d pts -> %d displayed (pw=%d)\n', ...
                        i, numel(L.X), numel(xd), obj.PixelWidth);
                end
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

                    if obj.Verbose
                        fprintf('[FastPlot] render: threshold %.4g: %d violation markers\n', ...
                            T.Value, numel(vxAll));
                    end
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

            obj.FullXLim = [xmin, xmax];
            obj.FullYLim = [ymin - yPad, ymax + yPad];
            obj.CachedXLim = get(obj.hAxes, 'XLim');

            % Auto-format datetime axis if any line was added with datetime X
            if obj.IsDatetime
                try
                    datetick(obj.hAxes, 'x', 'keeplimits');
                catch
                end
            end

            % Box on by default
            set(obj.hAxes, 'Box', 'on');

            % Legend: show only when multiple data lines
            if numel(obj.Lines) > 1
                legend(obj.hAxes, 'show', 'Location', 'best');
            end

            % Invisible anchor line spanning full X range.
            % Ensures MATLAB auto-XLim computation covers full data even
            % when visible lines are downsampled to a zoomed sub-range.
            line(obj.hAxes, [xmin xmax], [NaN NaN], ...
                'HandleVisibility', 'off', 'Visible', 'off', ...
                'Tag', 'FastPlotAnchor', ...
                'XLimInclude', 'on', 'YLimInclude', 'off');

            % --- Install listeners ---
            % XLim PostSet: primary listener for zoom/pan (R2025b+)
            % Fallback: undocumented 'xlim' event (R2020b-R2024b)
            try
                addlistener(obj.hAxes, 'XLim', 'PostSet', @(s,e) obj.onXLimChanged(s,e));
            catch
                try
                    addlistener(obj.hAxes, 'xlim', @(s,e) obj.onXLimChanged(s,e));
                catch
                end
            end
            % XLimMode PostSet: catches resetplotview (Home button) and
            % XLimMode='auto'. Both bypass XLim PostSet but DO fire
            % XLimMode PostSet — and XLim is already updated at that point.
            try
                addlistener(obj.hAxes, 'XLimMode', 'PostSet', @(s,e) obj.onXLimModeChanged());
            catch
            end
            % Store initial view so Home button has correct XLim target
            try
                resetplotview(obj.hAxes, 'SaveCurrentView');
            catch
            end
            % Only set figure-level callbacks when we own the figure
            if isempty(obj.ParentAxes)
                set(obj.hFigure, 'ResizeFcn', @(s,e) obj.onResize(s,e));
                zoom(obj.hFigure, 'on');
            end

            obj.IsRendered = true;

            if obj.Verbose
                totalPts = 0;
                for i = 1:numel(obj.Lines); totalPts = totalPts + numel(obj.Lines(i).X); end
                fprintf('[FastPlot] render complete: %d total pts, pw=%d, %.3fs\n', ...
                    totalPts, obj.PixelWidth, toc(renderTic));
            end

            % Register in link group
            if ~isempty(obj.LinkGroup)
                FastPlot.getLinkRegistry('register', obj.LinkGroup, obj);
            end

            hold(obj.hAxes, 'off');

            % Show figure and flush — unless deferred (dashboard batch render)
            if ~obj.DeferDraw
                if isempty(obj.ParentAxes)
                    set(obj.hFigure, 'Visible', 'on');
                end
                drawnow;
            end
        end

        function result = lookupMetadata(obj, lineIdx, xValue)
            %LOOKUPMETADATA Get active metadata at a given X value (forward-fill).
            %   result = fp.lookupMetadata(lineIdx, xValue)
            %   Returns struct with one value per metadata field, or [] if none.

            result = [];
            if lineIdx < 1 || lineIdx > numel(obj.Lines)
                return;
            end
            meta = obj.Lines(lineIdx).Metadata;
            if isempty(meta)
                return;
            end

            % Binary search for largest datenum <= xValue
            timestamps = meta.datenum;
            idx = binary_search(timestamps, xValue, 'left');
            idx = min(idx, numel(timestamps));

            % Ensure we have the largest value <= xValue
            if timestamps(idx) > xValue
                idx = idx - 1;
            end
            if idx < 1
                return;
            end

            % Build result struct with all non-datenum fields
            fields = fieldnames(meta);
            result = struct();
            for i = 1:numel(fields)
                f = fields{i};
                if strcmp(f, 'datenum')
                    continue;
                end
                val = meta.(f);
                if iscell(val)
                    result.(f) = val{idx};
                else
                    result.(f) = val(idx);
                end
            end
        end

        function updateData(obj, lineIdx, newX, newY, varargin)
            %UPDATEDATA Replace data for a line and re-downsample.
            %   fp.updateData(lineIdx, newX, newY)
            %   fp.updateData(lineIdx, newX, newY, 'Metadata', meta)
            %   fp.updateData(lineIdx, newX, newY, 'SkipViewMode', true)
            %
            %   Replaces the raw X/Y data for lineIdx, clears its pyramid
            %   cache, applies the current LiveViewMode, and re-downsamples
            %   all lines, shadings, and violation markers to the display.

            if ~obj.IsRendered
                error('FastPlot:notRendered', ...
                    'Cannot update data before render() has been called.');
            end
            if lineIdx < 1 || lineIdx > numel(obj.Lines)
                error('FastPlot:indexOutOfRange', ...
                    'Line index %d is out of range (1-%d).', lineIdx, numel(obj.Lines));
            end

            % Force row vectors
            if ~isrow(newX); newX = newX(:)'; end
            if ~isrow(newY); newY = newY(:)'; end

            if numel(newX) ~= numel(newY)
                error('FastPlot:sizeMismatch', ...
                    'X and Y must have the same number of elements.');
            end

            % Parse optional name-value pairs
            % Handle legacy positional boolean argument
            skipViewMode = false;
            newMeta = [];
            hasMeta = false;
            if ~isempty(varargin) && (islogical(varargin{1}) || isnumeric(varargin{1}))
                skipViewMode = varargin{1};
            else
                updateDefaults.Metadata = [];
                updateDefaults.SkipViewMode = false;
                [updateOpts, ~] = parseOpts(updateDefaults, varargin, obj.Verbose);
                skipViewMode = updateOpts.SkipViewMode;
                newMeta = updateOpts.Metadata;
                hasMeta = ~isempty(newMeta);
            end

            % Replace raw data
            obj.Lines(lineIdx).X = newX;
            obj.Lines(lineIdx).Y = newY;
            obj.Lines(lineIdx).HasNaN = any(isnan(newY));

            % Clear pyramid cache (will rebuild lazily)
            obj.Lines(lineIdx).Pyramid = {};

            % Update metadata if provided
            if hasMeta
                obj.Lines(lineIdx).Metadata = newMeta;
            end

            % Apply view mode before re-downsample
            if ~skipViewMode
                obj.applyViewMode(newX);
            end

            % Re-downsample and update display
            obj.updateLines();
            obj.updateShadings();
            obj.updateViolations();

            obj.drawnowLimitRate();
        end

        function startLive(obj, filepath, updateFcn, varargin)
            %STARTLIVE Start live mode — poll a .mat file for changes.
            %   fp.startLive(filepath, updateFcn)
            %   fp.startLive(filepath, updateFcn, 'Interval', 2)
            %   fp.startLive(filepath, updateFcn, 'ViewMode', 'follow')
            %
            %   Starts a timer that polls filepath for modification. When
            %   the file changes, it loads the .mat and calls:
            %     updateFcn(fp, data)
            %   where data is the loaded struct.
            %
            %   Options (name-value):
            %     'Interval'          — poll period in seconds (default: 2)
            %     'ViewMode'          — 'preserve'|'follow'|'reset'
            %     'MetadataFile'      — path to metadata .mat file
            %     'MetadataVars'      — cell array of variable names
            %     'MetadataLineIndex' — which line receives metadata

            if ~obj.IsRendered
                error('FastPlot:notRendered', ...
                    'Cannot start live mode before render() has been called.');
            end

            % Stop existing live mode if active
            if obj.LiveIsActive
                obj.stopLive();
            end

            obj.LiveFile = filepath;
            obj.LiveUpdateFcn = updateFcn;

            % Parse options
            liveDefaults.Interval = obj.LiveInterval;
            liveDefaults.ViewMode = '';
            liveDefaults.MetadataFile = obj.MetadataFile;
            liveDefaults.MetadataVars = obj.MetadataVars;
            liveDefaults.MetadataLineIndex = obj.MetadataLineIndex;
            [liveOpts, ~] = parseOpts(liveDefaults, varargin, obj.Verbose);
            obj.LiveInterval = liveOpts.Interval;
            obj.LiveViewMode = liveOpts.ViewMode;
            obj.MetadataFile = liveOpts.MetadataFile;
            obj.MetadataVars = liveOpts.MetadataVars;
            obj.MetadataLineIndex = liveOpts.MetadataLineIndex;

            % Default view mode if not set
            if isempty(obj.LiveViewMode)
                obj.LiveViewMode = 'preserve';
            end

            % Record current file date
            if exist(obj.LiveFile, 'file')
                d = dir(obj.LiveFile);
                obj.LiveFileDate = d.datenum;
            end

            % Record metadata file date and do initial load
            if ~isempty(obj.MetadataFile) && exist(obj.MetadataFile, 'file')
                d = dir(obj.MetadataFile);
                obj.MetadataFileDate = d.datenum;
                obj.loadMetadataFile();
            end

            % Create and start timer (MATLAB only; Octave lacks timer)
            try
                obj.LiveTimer = timer( ...
                    'ExecutionMode', 'fixedSpacing', ...
                    'Period', obj.LiveInterval, ...
                    'TimerFcn', @(~,~) obj.onLiveTimer(), ...
                    'ErrorFcn', @(~,~) []);
                start(obj.LiveTimer);
            catch
                % Octave: no timer — use runLive() for blocking poll loop
            end

            obj.LiveIsActive = true;

            % Install cleanup on figure close
            existingDeleteFcn = get(obj.hFigure, 'DeleteFcn');
            set(obj.hFigure, 'DeleteFcn', @(s,e) obj.onFigureCloseLive(existingDeleteFcn, s, e));

            if obj.Verbose
                fprintf('[FastPlot] live mode started: %s (%.1fs interval, %s mode)\n', ...
                    filepath, obj.LiveInterval, obj.LiveViewMode);
            end
        end

        function stopLive(obj)
            %STOPLIVE Stop live mode polling.
            if ~isempty(obj.LiveTimer)
                try
                    stop(obj.LiveTimer);
                    delete(obj.LiveTimer);
                catch
                end
            end
            obj.LiveTimer = [];
            obj.LiveIsActive = false;
            if ~isempty(obj.DeferredTimer)
                try stop(obj.DeferredTimer); delete(obj.DeferredTimer); catch; end
                obj.DeferredTimer = [];
            end

            if obj.Verbose
                fprintf('[FastPlot] live mode stopped\n');
            end
        end

        function refresh(obj)
            %REFRESH Manual one-shot reload from LiveFile.
            if isempty(obj.LiveFile) || isempty(obj.LiveUpdateFcn)
                error('FastPlot:noLiveSource', ...
                    'No live source configured. Call startLive() first or set LiveFile and LiveUpdateFcn.');
            end
            if ~exist(obj.LiveFile, 'file')
                warning('FastPlot:fileNotFound', 'Live file not found: %s', obj.LiveFile);
                return;
            end

            try
                data = load(obj.LiveFile);
                obj.LiveUpdateFcn(obj, data);
            catch e
                if obj.Verbose
                    fprintf('[FastPlot] refresh error: %s\n', e.message);
                end
            end

            d = dir(obj.LiveFile);
            obj.LiveFileDate = d.datenum;

            % Load metadata file if configured
            obj.loadMetadataFile();
            if ~isempty(obj.MetadataFile) && exist(obj.MetadataFile, 'file')
                dm = dir(obj.MetadataFile);
                obj.MetadataFileDate = dm.datenum;
            end
        end

        function setViewMode(obj, mode)
            %SETVIEWMODE Change the live view mode at runtime.
            obj.LiveViewMode = mode;
        end

        function runLive(obj)
            %RUNLIVE Blocking poll loop for live mode (Octave compatibility).
            %   On MATLAB, this is a no-op (timer handles polling).
            %   On Octave, blocks until figure is closed or Ctrl+C.
            %
            %   Usage:
            %     fp.startLive('data.mat', @updateFcn);
            %     fp.runLive();  % blocks on Octave, no-op on MATLAB

            if ~obj.LiveIsActive
                return;
            end

            % On MATLAB, the timer is already running — nothing to do
            if ~isempty(obj.LiveTimer) && ~isstruct(obj.LiveTimer)
                return;
            end

            % Octave: blocking poll loop
            cleanupObj = onCleanup(@() obj.stopLive());

            if obj.Verbose
                fprintf('[FastPlot] runLive: entering poll loop (%.1fs interval)\n', obj.LiveInterval);
            end

            while obj.LiveIsActive && ishandle(obj.hFigure)
                try
                    if exist(obj.LiveFile, 'file')
                        d = dir(obj.LiveFile);
                        if d.datenum > obj.LiveFileDate
                            obj.LiveFileDate = d.datenum;
                            data = load(obj.LiveFile);
                            obj.LiveUpdateFcn(obj, data);
                            if obj.Verbose
                                fprintf('[FastPlot] live update: %s\n', datestr(now, 'HH:MM:SS'));
                            end
                        end
                    end
                catch e
                    if obj.Verbose
                        fprintf('[FastPlot] runLive error: %s\n', e.message);
                    end
                end
                drawnow;
                pause(obj.LiveInterval);
            end

            if obj.Verbose
                fprintf('[FastPlot] runLive: exited poll loop\n');
            end
        end

        function onLiveTimerPublic(obj)
            %ONLIVETIMERPUBLIC Public wrapper for testing live timer callback.
            obj.onLiveTimer();
        end

        function setLineMetadata(obj, lineIdx, meta)
            %SETLINEMETADATA Set metadata on a line (used by FastPlotFigure).
            if lineIdx >= 1 && lineIdx <= numel(obj.Lines)
                obj.Lines(lineIdx).Metadata = meta;
            end
        end
    end

    % ======================== PRIVATE METHODS ============================
    % Internal helpers: timer callbacks, view mode, theme, listeners,
    % downsampling pipeline, pyramid management, and link propagation.
    methods (Access = private)
        function onLiveTimer(obj)
            %ONLIVETIMER Timer callback — check file and refresh if changed.
            if ~exist(obj.LiveFile, 'file')
                return;
            end
            try
                d = dir(obj.LiveFile);
                if d.datenum > obj.LiveFileDate
                    obj.LiveFileDate = d.datenum;
                    data = load(obj.LiveFile);
                    obj.LiveUpdateFcn(obj, data);
                    obj.drawnowLimitRate();
                    if obj.Verbose
                        fprintf('[FastPlot] live update: %s\n', datestr(now, 'HH:MM:SS'));
                    end
                end
            catch e
                if obj.Verbose
                    fprintf('[FastPlot] live timer error: %s\n', e.message);
                end
            end

            % Check metadata file
            if ~isempty(obj.MetadataFile) && exist(obj.MetadataFile, 'file')
                try
                    dm = dir(obj.MetadataFile);
                    if dm.datenum > obj.MetadataFileDate
                        obj.MetadataFileDate = dm.datenum;
                        obj.loadMetadataFile();
                    end
                catch
                end
            end
        end

        function loadMetadataFile(obj)
            %LOADMETADATAFILE Load metadata from the metadata file.
            meta = loadMetaStruct(obj.MetadataFile, obj.MetadataVars);
            if ~isempty(meta)
                idx = obj.MetadataLineIndex;
                if idx >= 1 && idx <= numel(obj.Lines)
                    obj.Lines(idx).Metadata = meta;
                end
            end
        end

        function onFigureCloseLive(obj, existingDeleteFcn, src, evt)
            %ONFIGURECLOSELIVE Cleanup timer when figure closes.
            obj.stopLive();
            if ~isempty(existingDeleteFcn)
                if isa(existingDeleteFcn, 'function_handle')
                    existingDeleteFcn(src, evt);
                end
            end
        end

        function applyViewMode(obj, newX)
            %APPLYVIEWMODE Adjust axes limits based on LiveViewMode.
            if isempty(obj.LiveViewMode)
                return;
            end

            switch obj.LiveViewMode
                case 'preserve'
                    % Do nothing — keep current zoom
                    return;

                case 'follow'
                    currentXLim = get(obj.hAxes, 'XLim');
                    windowWidth = currentXLim(2) - currentXLim(1);
                    newXMax = newX(end);
                    newXLim = [newXMax - windowWidth, newXMax];
                    set(obj.hAxes, 'XLim', newXLim);
                    obj.CachedXLim = newXLim;

                case 'reset'
                    newXLim = [newX(1), newX(end)];
                    set(obj.hAxes, 'XLim', newXLim);
                    obj.CachedXLim = newXLim;
            end
        end

        function applyTheme(obj)
            %APPLYTHEME Apply the current Theme struct to axes and figure.
            %   Sets background, foreground, grid, and font properties.
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

            if obj.Verbose
                fprintf('[FastPlot] onXLimChanged: range=[%.4g, %.4g]\n', newXLim(1), newXLim(2));
            end

            obj.updateLines();
            obj.updateShadings();
            obj.updateViolations();

            % Propagate to linked axes
            if ~isempty(obj.LinkGroup)
                obj.propagateXLim(newXLim);
            end

            obj.drawnowLimitRate();
            if obj.Verbose; fflush(stdout); end
        end

        function onXLimModeChanged(obj)
            %ONXLIMMODECHANGED Catch XLim changes that bypass XLim PostSet.
            %   resetplotview (Home) and XLimMode='auto' fire XLimMode PostSet
            %   but NOT XLim PostSet. resetplotview defers XLim change until
            %   after callbacks return, so we schedule a deferred check.
            if ~obj.IsRendered || ~ishandle(obj.hAxes) || obj.IsPropagating
                return;
            end

            % XLimMode='auto': handle immediately (XLim auto-computed from
            % anchor line spans full range, but we want exact FullXLim)
            if strcmp(get(obj.hAxes, 'XLimMode'), 'auto') && ~isempty(obj.FullXLim)
                obj.IsPropagating = true;
                try
                    set(obj.hAxes, 'XLim', obj.FullXLim);
                    set(obj.hAxes, 'XLimMode', 'manual');
                    if ~isempty(obj.FullYLim)
                        set(obj.hAxes, 'YLim', obj.FullYLim);
                        set(obj.hAxes, 'YLimMode', 'manual');
                    end
                    obj.CachedXLim = obj.FullXLim;
                    obj.updateLines();
                    obj.updateShadings();
                    obj.updateViolations();
                catch
                end
                obj.IsPropagating = false;
                return;
            end

            % resetplotview path: XLim hasn't changed yet at this point
            % (deferred by MATLAB). Schedule a check on next event loop.
            obj.scheduleDeferredXLimCheck();
        end

        function scheduleDeferredXLimCheck(obj)
            %SCHEDULEDEFERREDXLIMCHECK One-shot timer to catch deferred XLim changes.
            if ~isempty(obj.DeferredTimer) && isvalid(obj.DeferredTimer)
                stop(obj.DeferredTimer);
                delete(obj.DeferredTimer);
            end
            obj.DeferredTimer = timer('ExecutionMode', 'singleShot', ...
                'StartDelay', 0.01, ...
                'TimerFcn', @(~,~) obj.deferredXLimCheck());
            start(obj.DeferredTimer);
        end

        function deferredXLimCheck(obj)
            %DEFERREDXLIMCHECK Check if XLim changed after resetplotview.
            if ~ishandle(obj.hAxes) || obj.IsPropagating
                return;
            end
            newXLim = get(obj.hAxes, 'XLim');
            if ~isempty(obj.CachedXLim) && all(abs(newXLim - obj.CachedXLim) < eps)
                return;
            end
            obj.CachedXLim = newXLim;
            obj.updateLines();
            obj.updateShadings();
            obj.updateViolations();
            drawnow;
        end

        function onResize(obj, ~, ~)
            if ~obj.IsRendered || ~ishandle(obj.hAxes)
                return;
            end
            newPW = obj.getAxesPixelWidth();
            if newPW ~= obj.PixelWidth
                if obj.Verbose
                    fprintf('[FastPlot] onResize: pw %d -> %d\n', obj.PixelWidth, newPW);
                end
                obj.PixelWidth = newPW;
                obj.updateLines();
                obj.updateShadings();
                obj.drawnowLimitRate();
                if obj.Verbose; fflush(stdout); end
            end
        end

        function updateShadings(obj)
            %UPDATESHADINGS Re-downsample shaded regions for current view.
            %   Uses pre-computed cache when available (large datasets),
            %   otherwise downsamples directly from raw data.
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

                if nVis > obj.MinPointsForDownsample
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
            %UPDATELINES Re-downsample all lines for the current view.
            %   Uses pyramid levels when available for fast zoom. Selects
            %   the coarsest pyramid level with enough resolution, then
            %   downsamples the visible slice to screen pixel width.
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

                if nVis <= obj.MinPointsForDownsample
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
                    if numel(xVis) > obj.MinPointsForDownsample
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

                if obj.Verbose
                    if exist('lvl', 'var') && lvl > 0
                        pyrStr = sprintf('pyramid L%d', lvl);
                    else
                        pyrStr = 'raw';
                    end
                    fprintf('[FastPlot]   line %d: %d visible -> %d displayed (%s, pw=%d)\n', ...
                        i, nVis, numel(xd), pyrStr, pw);
                end
            end
        end

        function lvl = selectPyramidLevel(obj, lineIdx, nVis, nTotal, target)
            %SELECTPYRAMIDLEVEL Pick the smallest pyramid level with enough
            %   resolution for the visible range. Builds levels lazily.
            visFrac = nVis / nTotal;
            R = obj.PyramidReduction;

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
            R = obj.PyramidReduction;

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
            %UPDATEVIOLATIONS Recompute violation markers from displayed data.
            %   Uses the already-downsampled line data to find threshold
            %   violations, avoiding re-scanning the full raw dataset.
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
                    if obj.Verbose
                        fprintf('[FastPlot]   violations T%d (%.4g): %d markers\n', ...
                            t, obj.Thresholds(t).Value, numel(vxAll)-1);
                    end
                else
                    set(obj.Thresholds(t).hMarkers, 'XData', NaN, 'YData', NaN);
                    if obj.Verbose
                        fprintf('[FastPlot]   violations T%d (%.4g): 0 markers\n', ...
                            t, obj.Thresholds(t).Value);
                    end
                end
            end
        end

        function drawnowLimitRate(obj)
            %DRAWNOWLIMITRATE Flush graphics with rate limiting when available.
            %   Uses drawnow('limitrate') on MATLAB for 60fps cap.
            %   Falls back to plain drawnow on Octave.
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
            %GETAXESPIXELWIDTH Return the axes width in pixels.
            %   Temporarily switches to pixel units, reads Position(3),
            %   then restores original units. Minimum returned: 100.
            oldUnits = get(obj.hAxes, 'Units');
            set(obj.hAxes, 'Units', 'pixels');
            pos = get(obj.hAxes, 'Position');
            set(obj.hAxes, 'Units', oldUnits);
            pw = max(100, floor(pos(3)));
        end

        function propagateXLim(obj, newXLim)
            %PROPAGATEXLIM Sync XLim to all members of the link group.
            %   Sets IsPropagating guard to prevent re-entrant callbacks.
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

    % ======================== STATIC HELPERS =============================
    % Persistent registry for linked FastPlot groups.
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

    % ======================== PUBLIC STATIC ==============================
    methods (Static)
        function resetDefaults()
            %RESETDEFAULTS Force reload of FastPlotDefaults on next use.
            clearDefaultsCache();
        end
    end
end
