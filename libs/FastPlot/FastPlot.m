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
    %     - Logarithmic axis support (X, Y, or both)
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
    %     'XScale'        — 'linear' or 'log' (default: 'linear')
    %     'YScale'        — 'linear' or 'log' (default: 'linear')
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
    %   Example — logarithmic Y axis:
    %     fp = FastPlot('YScale', 'log');
    %     fp.addLine(1:1000, logspace(-1, 3, 1000));
    %     fp.render();
    %
    %   Example — live mode:
    %     fp = FastPlot(); fp.addLine(x, y); fp.render();
    %     fp.startLive('data.mat', @(fp, s) fp.updateData(1, s.x, s.y));
    %
    %   Example — distribute figures on screen (bundled in vendor/):
    %     FastPlot.distFig()                         % auto-arrange all figures
    %     FastPlot.distFig('Rows', 2, 'Cols', 3)     % 2x3 grid
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
        ShowProgress = true           % show console progress bar during render
        XScale = 'linear'             % 'linear' or 'log' — X axis scale
        YScale = 'linear'             % 'linear' or 'log' — Y axis scale
        ViolationsVisible = true      % global toggle for violation markers
    end

    % ====================== INTERNAL DATA STORAGE ========================
    % Struct arrays holding line data, annotations, and graphics handles.
    % SetAccess = private prevents external modification of plot state.
    properties (SetAccess = private)
        Lines      = struct('X', {}, 'Y', {}, 'Options', {}, ...
                            'DownsampleMethod', {}, 'hLine', {}, ...
                            'Pyramid', {}, 'HasNaN', {}, 'Metadata', {})
        Thresholds = struct('Value', {}, 'X', {}, 'Y', {}, ...
                            'Direction', {}, ...
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
        XType         = 'numeric' % 'numeric' or 'datenum'
        IsDatetime    = false % true if X data was datetime (converted to datenum)
    end

    % ======================== PRIVATE STATE ==============================
    % Internal bookkeeping: listeners, caches, timers, and flags.
    properties (Access = private)
        Listeners     = []    % event listeners (XLim, resize)
        hRefineTimer  = []    % one-shot timer for deferred minmax refinement
        IsRefined     = true  % false while showing coarse stride preview
        CachedXLim    = []    % for lazy recomputation
        CachedViolationLim = []    % [xmin xmax ymin ymax pw] for violation skip
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
            %   fp = FASTPLOT() creates a new FastPlot with default settings.
            %   fp = FASTPLOT('Parent', ax, 'Theme', 'dark') creates a plot
            %   inside existing axes ax with the 'dark' theme.
            %   fp = FASTPLOT('LinkGroup', 'g1', 'Verbose', true) creates a
            %   plot that shares zoom/pan with other plots in group 'g1'.
            %
            %   All options are name-value pairs. Defaults are loaded from
            %   FastPlotDefaults (via getDefaults) and can be overridden
            %   per-instance.
            %
            %   Inputs (name-value pairs):
            %     'Parent'        — axes handle; empty = create new figure
            %     'LinkGroup'     — string ID for linked zoom/pan
            %     'Theme'         — theme name, struct, or FastPlotTheme object
            %     'Verbose'       — logical, print diagnostics (default: false)
            %     'MinPointsForDownsample' — skip downsampling below this count
            %     'DownsampleFactor'       — points per pixel (default: 2)
            %     'PyramidReduction'       — compression per pyramid level
            %     'DefaultDownsampleMethod' — 'minmax' or 'lttb'
            %     'LiveInterval'  — poll interval in seconds (default: 2.0)
            %     'XScale'        — 'linear' or 'log' (default: 'linear')
            %     'YScale'        — 'linear' or 'log' (default: 'linear')
            %
            %   Output:
            %     obj — new FastPlot handle object
            %
            %   Example:
            %     fp = FastPlot('Theme', 'dark', 'Verbose', true);
            %     fp.addLine(1:1e6, randn(1,1e6));
            %     fp.render();
            %
            %   See also addLine, render, FastPlotTheme, FastPlotDefaults.
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
            defaults.XScale = cfg.XScale;
            defaults.YScale = cfg.YScale;
            [opts, ~] = parseOpts(defaults, varargin);

            obj.ParentAxes = opts.Parent;
            obj.LinkGroup = opts.LinkGroup;
            obj.Verbose = opts.Verbose;
            obj.MinPointsForDownsample = opts.MinPointsForDownsample;
            obj.DownsampleFactor = opts.DownsampleFactor;
            obj.PyramidReduction = opts.PyramidReduction;
            obj.DefaultDownsampleMethod = opts.DefaultDownsampleMethod;
            obj.LiveInterval = opts.LiveInterval;
            obj.XScale = opts.XScale;
            obj.YScale = opts.YScale;
            obj.Theme = resolveTheme(opts.Theme, cfg.Theme);
        end

        function resetColorIndex(obj)
            %RESETCOLORINDEX Reset the auto color cycling counter.
            %   fp.RESETCOLORINDEX() resets the internal color counter to zero.
            %   The next addLine() call without an explicit 'Color' option
            %   will use the first color from the theme palette.
            %
            %   Use this when replacing all lines (via updateData) and you
            %   want the color sequence to restart from the beginning.
            %
            %   Example:
            %     fp.resetColorIndex();
            %     fp.addLine(x, y);  % uses first palette color
            %
            %   See also addLine, reapplyTheme.
            obj.ColorIndex = 0;
        end

        function reapplyTheme(obj)
            %REAPPLYTHEME Re-apply the current Theme to axes and figure.
            %   fp.REAPPLYTHEME() refreshes all visual properties (background,
            %   foreground, grid, font, line widths) from the current Theme
            %   struct. Call this after changing fp.Theme on an already-rendered
            %   plot to update the display without re-rendering.
            %
            %   Has no effect before render() has been called.
            %
            %   Example:
            %     fp.Theme = FastPlotTheme('dark');
            %     fp.reapplyTheme();
            %
            %   See also applyTheme, FastPlotTheme.
            if ~obj.IsRendered; return; end
            obj.applyTheme();
            % Update existing line widths
            for i = 1:numel(obj.Lines)
                if ~isempty(obj.Lines(i).hLine) && ishandle(obj.Lines(i).hLine)
                    set(obj.Lines(i).hLine, 'LineWidth', obj.Theme.LineWidth);
                end
            end
        end

        function setScale(obj, varargin)
            %SETSCALE Set axis scale (linear or log) for X and/or Y.
            %   fp.SETSCALE('YScale', 'log') switches Y axis to logarithmic.
            %   fp.SETSCALE('XScale', 'log', 'YScale', 'linear') sets both.
            %
            %   Can be called before or after render(). After render(), the
            %   method applies the new scale to the axes, invalidates
            %   affected pyramid caches, and re-downsamples all lines,
            %   shadings, and violation markers.
            %
            %   When XScale changes, all pyramid caches are invalidated
            %   because log-space bucketing differs from linear. When only
            %   YScale changes, only LTTB pyramids are invalidated (minmax
            %   is order-invariant along Y).
            %
            %   Inputs (name-value pairs):
            %     'XScale' — 'linear' or 'log' (default: current value)
            %     'YScale' — 'linear' or 'log' (default: current value)
            %
            %   Example:
            %     fp.setScale('YScale', 'log');
            %     fp.setScale('XScale', 'log', 'YScale', 'log');
            %
            %   See also render, updateLines.

            p = struct('XScale', obj.XScale, 'YScale', obj.YScale);
            [opts, ~] = parseOpts(p, varargin);

            % Validate
            validScales = {'linear', 'log'};
            if ~ismember(opts.XScale, validScales)
                error('FastPlot:invalidScale', 'XScale must be ''linear'' or ''log''.');
            end
            if ~ismember(opts.YScale, validScales)
                error('FastPlot:invalidScale', 'YScale must be ''linear'' or ''log''.');
            end

            xChanged = ~strcmp(opts.XScale, obj.XScale);
            yChanged = ~strcmp(opts.YScale, obj.YScale);

            obj.XScale = opts.XScale;
            obj.YScale = opts.YScale;

            if ~obj.IsRendered
                return;
            end

            % Apply to axes
            set(obj.hAxes, 'XScale', obj.XScale);
            set(obj.hAxes, 'YScale', obj.YScale);

            % Invalidate pyramid caches where needed
            if xChanged
                % Log X changes bucketing — invalidate all pyramids
                for i = 1:numel(obj.Lines)
                    obj.Lines(i).Pyramid = {};
                end
            elseif yChanged
                % Log Y only affects LTTB pyramids (minmax is order-invariant)
                for i = 1:numel(obj.Lines)
                    if strcmp(obj.Lines(i).DownsampleMethod, 'lttb')
                        obj.Lines(i).Pyramid = {};
                    end
                end
            end

            % Re-downsample
            obj.updateLines();
            obj.updateShadings();
            obj.CachedViolationLim = [];
            obj.updateViolations();
            obj.drawnowLimitRate();
        end

        function addLine(obj, x, y, varargin)
            %ADDLINE Add a data line to the plot.
            %   fp.ADDLINE(x, y) adds a line with auto-assigned color.
            %   fp.ADDLINE(x, y, 'Color', 'r', 'DisplayName', 'Sensor1')
            %   adds a red line labeled 'Sensor1' in the legend.
            %   fp.ADDLINE(x, y, 'DownsampleMethod', 'lttb') uses the
            %   Largest-Triangle-Three-Buckets algorithm instead of MinMax.
            %
            %   X must be monotonically increasing. Datetime X values are
            %   automatically converted to datenum for internal storage.
            %   Both X and Y are forced to row vectors if not already.
            %
            %   Must be called BEFORE render(). Errors if render() was
            %   already called.
            %
            %   Inputs:
            %     x        — 1-by-N numeric or datetime array (monotonic)
            %     y        — 1-by-N numeric array (same length as x)
            %     varargin — name-value pairs:
            %       'DownsampleMethod' — 'minmax' (default) or 'lttb'
            %       'Metadata'         — struct with a .datenum field for
            %                            forward-fill lookup (see lookupMetadata)
            %       'AssumeSorted'     — logical; skip monotonicity check
            %       'HasNaN'           — logical override; auto-detected if empty
            %       'XType'            — 'numeric' or 'datenum'
            %       'Color','LineStyle','DisplayName',... — passed to line()
            %
            %   Example:
            %     fp = FastPlot();
            %     fp.addLine(1:1e6, cumsum(randn(1,1e6)), 'DisplayName', 'Walk');
            %     fp.render();
            %
            %   See also addThreshold, addShaded, render, updateData.

            if obj.IsRendered
                error('FastPlot:alreadyRendered', ...
                    'Cannot add lines after render() has been called.');
            end

            % Convert datetime X to datenum for internal use
            try
                if isdatetime(x)
                    x = datenum(x);
                    obj.IsDatetime = true;
                    obj.XType = 'datenum';
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
            knownDefaults.XType = 'numeric';
            [known, passthrough] = parseOpts(knownDefaults, varargin, obj.Verbose);

            % Set XType if explicitly provided
            if strcmp(known.XType, 'datenum')
                obj.XType = 'datenum';
                obj.IsDatetime = true;
            end

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
            lineStruct.IsStatic = (numel(x) <= obj.MinPointsForDownsample);

            % Append
            if isempty(obj.Lines)
                obj.Lines = lineStruct;
            else
                obj.Lines(end+1) = lineStruct;
            end
        end

        function addSensor(obj, sensor, varargin)
            %ADDSENSOR Add a resolved Sensor's data and thresholds to the plot.
            %   fp.ADDSENSOR(s) adds the sensor's X/Y data as a line and
            %   all resolved thresholds with violation markers enabled.
            %   fp.ADDSENSOR(s, 'ShowThresholds', false) adds only the data
            %   line, suppressing threshold overlay.
            %
            %   The sensor's Name (or Key as fallback) is used as the
            %   DisplayName for the line legend entry. Each threshold in
            %   sensor.ResolvedThresholds is added via addThreshold() with
            %   its resolved color, line style, direction, and label.
            %
            %   Must be called BEFORE render().
            %
            %   Inputs:
            %     sensor   — a Sensor object with fields X, Y, Name, Key,
            %                and ResolvedThresholds
            %     varargin — name-value pairs:
            %       'ShowThresholds' — logical (default: true)
            %
            %   Example:
            %     s = sensorLib.resolve('temperature');
            %     fp.addSensor(s);
            %     fp.render();
            %
            %   See also addLine, addThreshold.

            if obj.IsRendered
                error('FastPlot:alreadyRendered', ...
                    'Cannot add sensors after render() has been called.');
            end

            showThresholds = true;
            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'showthresholds'
                        showThresholds = varargin{k+1};
                end
            end

            displayName = sensor.Name;
            if isempty(displayName)
                displayName = sensor.Key;
            end

            obj.addLine(sensor.X, sensor.Y, 'DisplayName', displayName);

            if showThresholds && ~isempty(sensor.ResolvedThresholds)
                resolvedTh = sensor.ResolvedThresholds;
                for i = 1:numel(resolvedTh)
                    th = resolvedTh(i);
                    thLabel = th.Label;
                    if isempty(thLabel)
                        thLabel = sprintf('Threshold %d', i);
                    end
                    [thColor, thStyle] = obj.resolveThresholdStyle(th.Color, th.LineStyle);
                    obj.addThreshold(th.X, th.Y, ...
                        'Direction', th.Direction, ...
                        'ShowViolations', true, ...
                        'Label', thLabel, ...
                        'Color', thColor, ...
                        'LineStyle', thStyle);
                end
            end
        end

        function addThreshold(obj, varargin)
            %ADDTHRESHOLD Add a threshold line (scalar or time-varying).
            %   fp.ADDTHRESHOLD(value) adds a constant horizontal threshold.
            %   fp.ADDTHRESHOLD(value, 'Direction', 'upper', 'ShowViolations', true)
            %   adds an upper threshold with violation markers at crossings.
            %   fp.ADDTHRESHOLD(thX, thY, 'Direction', 'upper', 'ShowViolations', true)
            %   adds a time-varying (step-function) threshold.
            %
            %   Scalar thresholds draw a horizontal line across the full X
            %   range. Time-varying thresholds accept X/Y vectors that define
            %   a piecewise-constant or piecewise-linear limit. The calling
            %   convention is auto-detected: if the first two arguments are
            %   both numeric and the first has more than one element, the
            %   call is treated as time-varying.
            %
            %   Must be called BEFORE render().
            %
            %   Inputs:
            %     varargin{1}   — scalar threshold value, or thX vector
            %     varargin{2}   — thY vector (time-varying only)
            %     Name-value pairs:
            %       'Direction'      — 'upper' or 'lower' (default: 'upper')
            %       'ShowViolations' — logical (default: false)
            %       'Color'          — RGB triplet or color string
            %       'LineStyle'      — line style string (e.g. '--')
            %       'Label'          — text label for threshold
            %
            %   Example:
            %     fp.addThreshold(4.5, 'Direction', 'upper', ...
            %         'ShowViolations', true, 'Label', 'Max Temp');
            %
            %   See also addLine, addBand, updateViolations.

            if obj.IsRendered
                error('FastPlot:alreadyRendered', ...
                    'Cannot add thresholds after render() has been called.');
            end

            % Detect scalar vs time-varying
            if nargin >= 3 && isnumeric(varargin{1}) && isnumeric(varargin{2}) && numel(varargin{1}) > 1
                % Time-varying: addThreshold(thX, thY, ...)
                thX = varargin{1};
                thY = varargin{2};
                if ~isrow(thX); thX = thX(:)'; end
                if ~isrow(thY); thY = thY(:)'; end
                nvPairs = varargin(3:end);
                isTimeVarying = true;
            else
                % Scalar: addThreshold(value, ...)
                thX = [];
                thY = [];
                nvPairs = varargin(2:end);
                isTimeVarying = false;
            end

            defaults.Direction = 'upper';
            defaults.ShowViolations = false;
            defaults.Color = obj.Theme.ThresholdColor;
            defaults.LineStyle = obj.Theme.ThresholdStyle;
            defaults.Label = '';
            [parsed, ~] = parseOpts(defaults, nvPairs, obj.Verbose);

            t.Value          = [];
            t.X              = [];
            t.Y              = [];
            if isTimeVarying
                t.X = thX;
                t.Y = thY;
            else
                t.Value = varargin{1};
            end
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
            %   fp.ADDBAND(yLow, yHigh) adds a shaded horizontal band
            %   spanning the full X range between yLow and yHigh, using
            %   theme defaults for color and alpha.
            %   fp.ADDBAND(yLow, yHigh, 'FaceColor', [1 0.9 0.9], 'FaceAlpha', 0.3)
            %   uses custom color and transparency.
            %
            %   Bands are rendered as patches behind data lines. They span
            %   the full X range and are not re-downsampled on zoom.
            %
            %   Must be called BEFORE render().
            %
            %   Inputs:
            %     yLow     — lower Y bound of the band
            %     yHigh    — upper Y bound of the band
            %     varargin — name-value pairs:
            %       'FaceColor' — RGB triplet (default: Theme.ThresholdColor)
            %       'FaceAlpha' — scalar 0-1 (default: Theme.BandAlpha)
            %       'EdgeColor' — edge color (default: 'none')
            %       'Label'     — text label for the band
            %
            %   Example:
            %     fp.addBand(3.5, 4.5, 'FaceColor', [1 0.9 0.9], ...
            %         'FaceAlpha', 0.2, 'Label', 'Warning zone');
            %
            %   See also addThreshold, addShaded.

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
            %   fp.ADDMARKER(x, y) plots marker symbols at the given (x,y)
            %   positions using theme defaults.
            %   fp.ADDMARKER(x, y, 'Marker', 'v', 'MarkerSize', 8, 'Color', [1 0 0])
            %   plots red downward-pointing triangles of size 8.
            %
            %   Markers are drawn as a line object with no connecting line
            %   (LineStyle='none'), rendered in front of data lines. They
            %   are not downsampled — provide only the points you want drawn.
            %
            %   Must be called BEFORE render().
            %
            %   Inputs:
            %     x        — 1-by-N numeric X positions
            %     y        — 1-by-N numeric Y positions
            %     varargin — name-value pairs:
            %       'Marker'     — marker symbol (default: 'o')
            %       'MarkerSize' — marker size in points (default: 6)
            %       'Color'      — RGB triplet (default: Theme.ThresholdColor)
            %       'Label'      — text label for the marker group
            %
            %   Example:
            %     events_x = [100 500 900];
            %     events_y = [2.1 3.5 1.8];
            %     fp.addMarker(events_x, events_y, 'Marker', 'd', ...
            %         'Color', [1 0 0], 'Label', 'Events');
            %
            %   See also addLine, addThreshold.

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
            %   fp.ADDSHADED(x, y_upper, y_lower) fills the area between
            %   y_upper and y_lower over the common X axis.
            %   fp.ADDSHADED(x, y1, y2, 'FaceColor', [0 0 1], 'FaceAlpha', 0.2)
            %   fills with blue at 20% opacity.
            %
            %   The shaded region is drawn as a patch and is dynamically
            %   re-downsampled on zoom/pan. For large datasets (>20k points),
            %   a pre-downsampled cache is built at render time to speed up
            %   subsequent zoom updates.
            %
            %   X must be monotonically increasing. All three arrays must
            %   have the same number of elements.
            %
            %   Must be called BEFORE render().
            %
            %   Inputs:
            %     x        — 1-by-N numeric X positions (monotonic)
            %     y1       — 1-by-N numeric upper boundary
            %     y2       — 1-by-N numeric lower boundary
            %     varargin — name-value pairs:
            %       'FaceColor'   — RGB triplet (default: [0 0.45 0.74])
            %       'FaceAlpha'   — scalar 0-1 (default: 0.15)
            %       'EdgeColor'   — edge color (default: 'none')
            %       'DisplayName' — legend entry text
            %
            %   Example:
            %     x = linspace(0, 10, 1e5);
            %     fp.addShaded(x, sin(x)+0.5, sin(x)-0.5, ...
            %         'FaceColor', [0 0.5 1], 'DisplayName', 'Envelope');
            %
            %   See also addFill, addBand.

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
            %   fp.ADDFILL(x, y) fills the area between y and a baseline
            %   of zero using default shading colors.
            %   fp.ADDFILL(x, y, 'Baseline', -1, 'FaceColor', [0 0.5 1])
            %   fills between y and y=-1 with a custom color.
            %
            %   This is a convenience wrapper around addShaded(). It creates
            %   a shaded region between the supplied y curve and a constant
            %   baseline value. Datetime X values are auto-converted to
            %   datenum.
            %
            %   Must be called BEFORE render().
            %
            %   Inputs:
            %     x        — 1-by-N numeric or datetime X positions
            %     y        — 1-by-N numeric Y values
            %     varargin — name-value pairs:
            %       'Baseline'    — constant Y baseline (default: 0)
            %       Additional pairs passed through to addShaded:
            %       'FaceColor', 'FaceAlpha', 'EdgeColor', 'DisplayName'
            %
            %   Example:
            %     x = linspace(0, 2*pi, 1000);
            %     fp.addFill(x, sin(x), 'Baseline', 0, ...
            %         'FaceColor', [0.2 0.6 1], 'FaceAlpha', 0.3);
            %
            %   See also addShaded, addBand.

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

        function render(obj, progressBar)
            %RENDER Create the plot with all configured lines and annotations.
            %   fp.RENDER() finalizes the plot and displays it. This method:
            %     1. Creates a figure and axes (or uses ParentAxes)
            %     2. Applies the Theme (background, grid, font)
            %     3. Renders bands and shaded regions (back layer)
            %     4. Downsamples all lines to screen pixel resolution
            %     5. Draws threshold lines and violation markers
            %     6. Draws custom markers (front layer)
            %     7. Sets axis limits with 5% padding
            %     8. Installs XLim/resize listeners for dynamic re-downsample
            %     9. Schedules async refinement for large datasets
            %     10. Registers in LinkGroup for synchronized zoom/pan
            %
            %   fp.RENDER(progressBar) uses an existing ConsoleProgressBar
            %   for progress reporting (used by FastPlotFigure for batch
            %   rendering of multiple tiles).
            %
            %   Can only be called once per FastPlot instance. After render(),
            %   addLine()/addThreshold()/addBand() will error. Use
            %   updateData() for live data updates.
            %
            %   Inputs:
            %     progressBar — (optional) ConsoleProgressBar handle; if
            %                   empty and ShowProgress is true, creates one
            %
            %   Example:
            %     fp = FastPlot();
            %     fp.addLine(x, y, 'DisplayName', 'Signal');
            %     fp.addThreshold(4.5, 'ShowViolations', true);
            %     fp.render();
            %
            %   See also addLine, updateData, startLive, FastPlotFigure.

            if nargin < 2; progressBar = []; end

            % Create local progress bar for standalone render
            ownProgressBar = false;
            if isempty(progressBar) && obj.ShowProgress && numel(obj.Lines) > 0
                progressBar = ConsoleProgressBar(0);
                progressBar.update(0, numel(obj.Lines), 'Rendering');
                progressBar.start();
                ownProgressBar = true;
            end

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
            % Lock axes to its assigned position (prevent MATLAB padding)
            try
                set(obj.hAxes, 'PositionConstraint', 'innerposition');
            catch
                set(obj.hAxes, 'ActivePositionProperty', 'position');
            end

            hold(obj.hAxes, 'on');
            obj.PixelWidth = obj.getAxesPixelWidth();
            obj.applyTheme();

            % Apply axis scale (linear or log)
            set(obj.hAxes, 'XScale', obj.XScale);
            set(obj.hAxes, 'YScale', obj.YScale);

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

                % Downsample for display
                logXFlag = strcmp(obj.XScale, 'log');
                logYFlag = strcmp(obj.YScale, 'log');
                if numel(L.X) > obj.MinPointsForDownsample
                    if obj.DeferDraw
                        % Synchronous downsample for batched render (no preview visible)
                        if strcmp(L.DownsampleMethod, 'lttb')
                            [xd, yd] = lttb_downsample(L.X, L.Y, numBuckets, logXFlag, logYFlag);
                        else
                            [xd, yd] = minmax_downsample(L.X, L.Y, numBuckets, L.HasNaN, logXFlag);
                        end
                    else
                        % Fast stride preview: every K-th point for instant
                        % figure display; refineLines() replaces this with
                        % proper MinMax/LTTB asynchronously via timer
                        K = max(1, floor(numel(L.X) / (2 * numBuckets)));
                        xd = L.X(1:K:end);
                        yd = L.Y(1:K:end);
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
                if ~isempty(progressBar)
                    progressBar.update(i, numel(obj.Lines));
                end
            end

            if obj.Verbose && strcmp(obj.YScale, 'log')
                for i = 1:numel(obj.Lines)
                    nNonPos = sum(obj.Lines(i).Y <= 0);
                    if nNonPos > 0
                        fprintf('[FastPlot] warning: line %d has %d non-positive values (clipped on log scale)\n', i, nNonPos);
                    end
                end
            end

            % --- Render threshold lines and violation markers (per threshold) ---
            for t = 1:numel(obj.Thresholds)
                T = obj.Thresholds(t);

                % Threshold line
                if isempty(T.X)
                    % Scalar threshold — horizontal line
                    hT = line([xmin, xmax], [T.Value, T.Value], 'Parent', obj.hAxes, ...
                        'Color', T.Color, ...
                        'LineStyle', T.LineStyle, ...
                        'LineWidth', 1.5, ...
                        'HandleVisibility', 'off');
                else
                    % Time-varying threshold — step-function line
                    hT = line(T.X, T.Y, 'Parent', obj.hAxes, ...
                        'Color', T.Color, ...
                        'LineStyle', T.LineStyle, ...
                        'LineWidth', 1.5, ...
                        'HandleVisibility', 'off');
                end
                udT.FastPlot = struct( ...
                    'Type', 'threshold', ...
                    'Name', T.Label, ...
                    'LineIndex', [], ...
                    'ThresholdValue', T.Value);
                set(hT, 'UserData', udT);
                obj.Thresholds(t).hLine = hT;

                % Violation markers (fused: detect + cull in one pass).
                % violation_cull finds threshold crossings and culls
                % overlapping markers to one per pixel for performance.
                if T.ShowViolations && obj.ViolationsVisible
                    nLines = numel(obj.Lines);
                    vxCell = cell(1, nLines);  % pre-allocate per-line results
                    vyCell = cell(1, nLines);
                    nViols = 0;
                    xl = get(obj.hAxes, 'XLim');
                    pw = diff(xl) / obj.PixelWidth;  % X units per pixel
                    for i = 1:nLines
                        % Use displayed (downsampled) data, not raw
                        xd = get(obj.Lines(i).hLine, 'XData');
                        yd = get(obj.Lines(i).hLine, 'YData');
                        if isempty(T.X)
                            % Scalar threshold — pass 0 for thX sentinel
                            [vx, vy] = violation_cull(xd, yd, 0, T.Value, T.Direction, pw, xl(1));
                        else
                            % Time-varying threshold
                            [vx, vy] = violation_cull(xd, yd, T.X, T.Y, T.Direction, pw, xl(1));
                        end
                        if ~isempty(vx)
                            nViols = nViols + 1;
                            vxCell{nViols} = vx;
                            vyCell{nViols} = vy;
                        end
                    end
                    % Concatenate all violations into single marker arrays
                    if nViols > 0
                        vxAll = [vxCell{1:nViols}];
                        vyAll = [vyCell{1:nViols}];
                    else
                        % NaN placeholder keeps the line object valid
                        vxAll = NaN;
                        vyAll = NaN;
                    end
                    hM = line(vxAll, vyAll, 'Parent', obj.hAxes, ...
                        'LineStyle', 'none', 'Marker', '.', ...
                        'MarkerSize', 6, 'Color', T.Color, ...
                        'HandleVisibility', 'off');
                    udM.FastPlot = struct( ...
                        'Type', 'violation_marker', ...
                        'Name', T.Label, ...
                        'LineIndex', [], ...
                        'ThresholdValue', T.Value);
                    set(hM, 'UserData', udM);
                    obj.Thresholds(t).hMarkers = hM;

                    if obj.Verbose
                        if isempty(T.X)
                            fprintf('[FastPlot] render: threshold %.4g: %d violation markers\n', ...
                                T.Value, numel(vxAll));
                        else
                            fprintf('[FastPlot] render: time-varying threshold "%s": %d violation markers\n', ...
                                T.Label, numel(vxAll));
                        end
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
            if strcmp(obj.YScale, 'log')
                % Log Y: exclude non-positive, use multiplicative padding
                ymin = Inf; ymax = -Inf;
                for i = 1:numel(obj.Lines)
                    yd = get(obj.Lines(i).hLine, 'YData');
                    yd = yd(yd > 0 & ~isnan(yd));
                    if ~isempty(yd)
                        yiMin = min(yd);
                        yiMax = max(yd);
                        if yiMin < ymin; ymin = yiMin; end
                        if yiMax > ymax; ymax = yiMax; end
                    end
                end
                if isinf(ymin)
                    ymin = 0.1; ymax = 1;
                end
                yPadFactor = 1.1;
                yLimLow = ymin / yPadFactor;
                yLimHigh = ymax * yPadFactor;
            else
                % Linear Y: find global min/max across all displayed lines
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
                % 5% additive padding; 1 unit fallback for flat data
                yPad = (ymax - ymin) * 0.05;
                if yPad == 0; yPad = 1; end
                yLimLow = ymin - yPad;
                yLimHigh = ymax + yPad;
            end

            set(obj.hAxes, 'XLim', [xmin, xmax]);
            set(obj.hAxes, 'YLim', [yLimLow, yLimHigh]);
            % Manual mode prevents MATLAB from auto-adjusting during zoom
            set(obj.hAxes, 'XLimMode', 'manual');
            set(obj.hAxes, 'YLimMode', 'manual');

            % Store full-range limits for Home button (resetplotview) restore
            obj.FullXLim = [xmin, xmax];
            obj.FullYLim = [yLimLow, yLimHigh];
            obj.CachedXLim = get(obj.hAxes, 'XLim');

            % Auto-format datetime axis
            if strcmp(obj.XType, 'datenum')
                obj.updateDatetimeTicks();
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
            % Loupe: double-click to open standalone enlarged view (all modes)
            loupeCb = @(s,e) obj.onAxesDoubleClick(e);
            set(obj.hAxes, 'ButtonDownFcn', loupeCb);
            % Also install on all children (lines, patches) so clicks on
            % data reach the callback even when HitTest is on
            ch = get(obj.hAxes, 'Children');
            for ci = 1:numel(ch)
                try set(ch(ci), 'ButtonDownFcn', loupeCb); catch; end
            end

            % Only set figure-level callbacks when we own the figure
            if isempty(obj.ParentAxes)
                set(obj.hFigure, 'ResizeFcn', @(s,e) obj.onResize(s,e));
                try
                    hZoom = zoom(obj.hFigure);
                    set(hZoom, 'ButtonDownFilter', ...
                        @(src,evt) obj.loupeButtonFilter());
                    set(hZoom, 'Enable', 'on');
                catch
                    % Octave / headless: zoom() doesn't return an object
                    try zoom(obj.hFigure, 'on'); catch; end
                end
            end

            obj.IsRendered = true;

            % Start async refinement if any line used stride preview
            hasLargeLines = false;
            for i = 1:numel(obj.Lines)
                if numel(obj.Lines(i).X) > obj.MinPointsForDownsample
                    hasLargeLines = true;
                    break;
                end
            end
            if hasLargeLines && ~obj.DeferDraw
                % Schedule async refinement: the stride preview is visible
                % immediately; after 10ms, refineLines replaces it with a
                % proper MinMax/LTTB downsample for pixel-accurate display
                obj.IsRefined = false;
                try
                    obj.hRefineTimer = timer('ExecutionMode', 'singleShot', ...
                        'StartDelay', 0.01, ...
                        'TimerFcn', @(~,~) obj.refineLines());
                    start(obj.hRefineTimer);
                catch
                    % Octave or timer unavailable: refine synchronously
                    obj.refineLines();
                end
            end

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

            % Finish standalone progress bar
            if ownProgressBar
                progressBar.finish();
            elseif ~isempty(progressBar)
                progressBar.freeze();
            end

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
            %   result = fp.LOOKUPMETADATA(lineIdx, xValue) returns a struct
            %   containing the metadata values that were active at xValue,
            %   using forward-fill (last-observation-carried-forward) logic.
            %
            %   Metadata must have been attached to the line via addLine()
            %   with the 'Metadata' option or via setLineMetadata(). The
            %   metadata struct must contain a .datenum field with sorted
            %   timestamps; all other fields are returned at the matching
            %   index.
            %
            %   Returns [] if lineIdx is out of range, no metadata is
            %   attached, or xValue precedes all metadata timestamps.
            %
            %   Inputs:
            %     lineIdx — integer index of the data line (1-based)
            %     xValue  — scalar X position (datenum or numeric)
            %
            %   Output:
            %     result  — struct with one value per metadata field, or []
            %
            %   Example:
            %     meta = struct('datenum', [1 5 10], 'operator', {{'A','B','C'}});
            %     fp.addLine(1:20, randn(1,20), 'Metadata', meta);
            %     fp.render();
            %     info = fp.lookupMetadata(1, 7);  % returns operator='B'
            %
            %   See also setLineMetadata, addLine.

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
            %   fp.UPDATEDATA(lineIdx, newX, newY) replaces the raw X/Y
            %   data for the specified line and refreshes the display.
            %   fp.UPDATEDATA(lineIdx, newX, newY, 'Metadata', meta)
            %   also replaces the line's metadata struct.
            %   fp.UPDATEDATA(lineIdx, newX, newY, 'SkipViewMode', true)
            %   replaces data without applying LiveViewMode adjustments.
            %
            %   This is the primary method for live data updates. It:
            %     1. Replaces raw X/Y and resets the pyramid cache
            %     2. Updates HasNaN and IsStatic flags
            %     3. Applies LiveViewMode (follow/preserve/reset)
            %     4. Re-downsamples all lines, shadings, and violations
            %     5. Flushes the display via drawnow limitrate
            %
            %   Also accepts a legacy positional boolean as the 5th argument
            %   (equivalent to 'SkipViewMode', true) for backward compat.
            %
            %   Inputs:
            %     lineIdx  — integer index of the data line (1-based)
            %     newX     — 1-by-N numeric X data (monotonic)
            %     newY     — 1-by-N numeric Y data (same length as newX)
            %     varargin — name-value pairs:
            %       'Metadata'     — struct to replace line metadata
            %       'SkipViewMode' — logical (default: false)
            %
            %   Example:
            %     fp.updateData(1, newX, newY);
            %     fp.updateData(1, newX, newY, 'Metadata', newMeta);
            %
            %   See also startLive, render, addLine.

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
            obj.Lines(lineIdx).IsStatic = (numel(newX) <= obj.MinPointsForDownsample);

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
            obj.CachedViolationLim = [];
            obj.updateViolations();

            obj.drawnowLimitRate();
        end

        function startLive(obj, filepath, updateFcn, varargin)
            %STARTLIVE Start live mode — poll a .mat file for changes.
            %   fp.STARTLIVE(filepath, updateFcn) begins polling filepath
            %   at the default interval. When the file's modification date
            %   changes, it loads the .mat and calls updateFcn(fp, data).
            %   fp.STARTLIVE(filepath, updateFcn, 'Interval', 2)
            %   fp.STARTLIVE(filepath, updateFcn, 'ViewMode', 'follow')
            %
            %   Uses a MATLAB timer for non-blocking polling. On Octave
            %   (where timer is unavailable), call runLive() after this
            %   method for a blocking poll loop.
            %
            %   A cleanup callback is installed on the figure's DeleteFcn
            %   so the timer stops when the figure is closed.
            %
            %   Must be called AFTER render().
            %
            %   Inputs:
            %     filepath  — path to a .mat file to watch for changes
            %     updateFcn — function handle @(fp, data) called on change
            %     varargin  — name-value pairs:
            %       'Interval'          — poll period in seconds (default: 2)
            %       'ViewMode'          — 'preserve'|'follow'|'reset'
            %       'MetadataFile'      — path to a separate metadata .mat
            %       'MetadataVars'      — cell array of variable names
            %       'MetadataLineIndex' — which line receives metadata
            %
            %   Example:
            %     fp.render();
            %     fp.startLive('data.mat', @(fp, d) fp.updateData(1, d.x, d.y), ...
            %         'Interval', 1, 'ViewMode', 'follow');
            %
            %   See also stopLive, runLive, updateData, refresh.

            obj.stopRefineTimer();

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
            %   fp.STOPLIVE() stops the live timer, cleans up the deferred
            %   timer, and sets LiveIsActive to false. Safe to call even if
            %   live mode is not active. Also stops the refinement timer.
            %
            %   Example:
            %     fp.stopLive();
            %
            %   See also startLive, delete.
            obj.stopRefineTimer();
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

        function delete(obj)
            %DELETE Clean up timers and release resources.
            %   Called automatically when the FastPlot object is destroyed
            %   (e.g., cleared from workspace or figure closed). Stops the
            %   refinement timer and live polling timer to prevent dangling
            %   timer callbacks referencing deleted objects.
            %
            %   See also stopLive, stopRefineTimer.
            obj.stopRefineTimer();
            try obj.stopLive(); catch; end
        end

        function refresh(obj)
            %REFRESH Manual one-shot reload from LiveFile.
            %   fp.REFRESH() loads the current LiveFile, calls LiveUpdateFcn,
            %   and updates the LiveFileDate timestamp. Also reloads the
            %   MetadataFile if configured. Useful for triggering a manual
            %   update without waiting for the live timer.
            %
            %   Errors if LiveFile or LiveUpdateFcn have not been set (call
            %   startLive() first). Warns if the file does not exist.
            %
            %   Example:
            %     fp.startLive('data.mat', @myUpdate);
            %     fp.refresh();  % force immediate reload
            %
            %   See also startLive, onLiveTimer.
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
            %   fp.SETVIEWMODE(mode) sets the LiveViewMode property, which
            %   controls how the X-axis adjusts when new data arrives.
            %
            %   Inputs:
            %     mode — string: 'preserve' (keep current zoom), 'follow'
            %            (scroll to track latest data), or 'reset' (fit
            %            full X range)
            %
            %   Example:
            %     fp.setViewMode('follow');
            %
            %   See also startLive, applyViewMode.
            obj.LiveViewMode = mode;
        end

        function runLive(obj)
            %RUNLIVE Blocking poll loop for live mode (Octave compatibility).
            %   fp.RUNLIVE() enters a blocking loop that polls LiveFile for
            %   changes at LiveInterval. This is required on Octave where
            %   MATLAB timer objects are not available.
            %
            %   On MATLAB, this is a no-op because startLive() already
            %   installed a non-blocking timer. On Octave, it blocks until
            %   the figure is closed or the user presses Ctrl+C. An
            %   onCleanup guard ensures stopLive() is called.
            %
            %   Example:
            %     fp.startLive('data.mat', @updateFcn);
            %     fp.runLive();  % blocks on Octave, no-op on MATLAB
            %
            %   See also startLive, stopLive, onLiveTimer.

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
            %   fp.ONLIVETIMERPUBLIC() delegates to the private onLiveTimer
            %   method. Exists solely to allow unit tests to invoke the
            %   timer callback directly without relying on real timers.
            %
            %   See also onLiveTimer.
            obj.onLiveTimer();
        end

        function setLineMetadata(obj, lineIdx, meta)
            %SETLINEMETADATA Set metadata on a line after construction.
            %   fp.SETLINEMETADATA(lineIdx, meta) attaches or replaces the
            %   metadata struct on the specified line. Primarily used by
            %   FastPlotFigure to attach metadata loaded from a separate
            %   file after the plot has been rendered.
            %
            %   The metadata struct should contain a .datenum field with
            %   sorted timestamps for forward-fill lookup via lookupMetadata.
            %
            %   Inputs:
            %     lineIdx — integer index of the data line (1-based)
            %     meta    — struct with metadata fields (must include .datenum)
            %
            %   Example:
            %     meta = struct('datenum', [1 5], 'batch', {{'A','B'}});
            %     fp.setLineMetadata(1, meta);
            %
            %   See also lookupMetadata, addLine, FastPlotFigure.
            if lineIdx >= 1 && lineIdx <= numel(obj.Lines)
                obj.Lines(lineIdx).Metadata = meta;
            end
        end

        function setViolationsVisible(obj, on)
            %SETVIOLATIONSVISIBLE Show or hide all violation markers.
            %   fp.SETVIOLATIONSVISIBLE(true) shows violation markers on all
            %   thresholds that have ShowViolations enabled, forcing a
            %   recomputation from the currently displayed line data.
            %   fp.SETVIOLATIONSVISIBLE(false) hides all violation markers
            %   without recomputing them.
            %
            %   This toggles the global ViolationsVisible flag. Individual
            %   thresholds still control whether they participate via their
            %   own ShowViolations property.
            %
            %   Inputs:
            %     on — logical: true to show, false to hide
            %
            %   Example:
            %     fp.setViolationsVisible(false);  % hide all markers
            %     fp.setViolationsVisible(true);   % show and recompute
            %
            %   See also updateViolations, addThreshold, FastPlotToolbar.
            obj.ViolationsVisible = on;
            if on
                obj.CachedViolationLim = [];   % force recompute
                if obj.IsRendered
                    obj.updateViolations();
                end
                % Set visible only for thresholds that have ShowViolations
                for t = 1:numel(obj.Thresholds)
                    if ~isempty(obj.Thresholds(t).hMarkers) && ishandle(obj.Thresholds(t).hMarkers) ...
                            && obj.Thresholds(t).ShowViolations
                        set(obj.Thresholds(t).hMarkers, 'Visible', 'on');
                    end
                end
            else
                for t = 1:numel(obj.Thresholds)
                    if ~isempty(obj.Thresholds(t).hMarkers) && ishandle(obj.Thresholds(t).hMarkers)
                        set(obj.Thresholds(t).hMarkers, 'Visible', 'off');
                    end
                end
            end
        end

        function openLoupe(obj)
            %OPENLOUPE Open a standalone enlarged copy of this tile.
            %   fp.OPENLOUPE() creates a new FastPlot in a separate figure
            %   containing deep copies of all lines, thresholds, bands,
            %   shadings, and markers from the current plot. The new figure
            %   preserves the current zoom state (XLim/YLim), is offset
            %   by [+30, -30] pixels from the source figure, and receives
            %   its own FastPlotToolbar.
            %
            %   The loupe uses DeferDraw=true during render so the figure
            %   appears once with correct zoom rather than flashing at
            %   full range first.
            %
            %   Datetime data is converted back from datenum to datetime
            %   before adding to the new plot, so axis formatting is
            %   preserved.
            %
            %   Example:
            %     fp.openLoupe();  % or double-click on the axes
            %
            %   See also onAxesDoubleClick, loupeButtonFilter, FastPlotToolbar.
            % Use the source tile's title as the loupe figure name
            title_str = get(get(obj.hAxes, 'Title'), 'String');
            if isempty(title_str); title_str = 'FastPlot'; end

            % Deep-copy all data into a fresh FastPlot instance
            fp = FastPlot();
            fp.Theme = obj.Theme;

            % Copy lines (converting datenum back to datetime if needed)
            for i = 1:numel(obj.Lines)
                L = obj.Lines(i);
                x = L.X; y = L.Y;
                if obj.IsDatetime
                    x = datetime(x, 'ConvertFrom', 'datenum');
                end
                nvp = struct2nvpairs(L.Options);
                if ~isempty(L.Metadata)
                    nvp = [nvp, {'Metadata', L.Metadata}];
                end
                if ~strcmp(L.DownsampleMethod, 'minmax')
                    nvp = [nvp, {'DownsampleMethod', L.DownsampleMethod}];
                end
                fp.addLine(x, y, nvp{:});
            end
            % Copy thresholds (scalar and time-varying)
            for i = 1:numel(obj.Thresholds)
                T = obj.Thresholds(i);
                if ~isempty(T.X)
                    fp.addThreshold(T.X, T.Y, 'Direction', T.Direction, ...
                        'ShowViolations', T.ShowViolations, ...
                        'Color', T.Color, 'LineStyle', T.LineStyle, ...
                        'Label', T.Label);
                else
                    fp.addThreshold(T.Value, 'Direction', T.Direction, ...
                        'ShowViolations', T.ShowViolations, ...
                        'Color', T.Color, 'LineStyle', T.LineStyle, ...
                        'Label', T.Label);
                end
            end
            % Copy bands
            for i = 1:numel(obj.Bands)
                B = obj.Bands(i);
                fp.addBand(B.YLow, B.YHigh, 'FaceColor', B.FaceColor, ...
                    'FaceAlpha', B.FaceAlpha, 'Label', B.Label);
            end
            % Copy shadings
            for i = 1:numel(obj.Shadings)
                S = obj.Shadings(i);
                x = S.X; y1 = S.Y1; y2 = S.Y2;
                if obj.IsDatetime
                    x = datetime(x, 'ConvertFrom', 'datenum');
                end
                fp.addShaded(x, y1, y2, 'FaceColor', S.FaceColor, ...
                    'FaceAlpha', S.FaceAlpha, 'DisplayName', S.DisplayName);
            end
            % Copy markers
            for i = 1:numel(obj.Markers)
                M = obj.Markers(i);
                x = M.X; y = M.Y;
                if obj.IsDatetime
                    x = datetime(x, 'ConvertFrom', 'datenum');
                end
                fp.addMarker(x, y, 'Marker', M.Marker, ...
                    'MarkerSize', M.MarkerSize, 'Color', M.Color, ...
                    'Label', M.Label);
            end
            fp.ViolationsVisible = obj.ViolationsVisible;
            % Defer drawnow so the figure appears once at the correct zoom
            fp.DeferDraw = true;
            fp.render();
            fp.DeferDraw = false;
            set(fp.hFigure, 'Name', title_str);

            % Preserve zoom state from source tile
            set(fp.hAxes, 'XLim', get(obj.hAxes, 'XLim'), ...
                           'YLim', get(obj.hAxes, 'YLim'));

            % Size loupe to match source figure, offset so it doesn't overlap
            srcPos = get(ancestor(obj.hAxes, 'figure'), 'Position');
            set(fp.hFigure, 'Position', srcPos + [30 -30 0 0]);

            tb = FastPlotToolbar(fp);
            setappdata(fp.hFigure, 'FastPlotToolbar', tb);

            set(fp.hFigure, 'Visible', 'on');
            drawnow;
        end
    end

    % ======================== PRIVATE METHODS ============================
    % Internal helpers: timer callbacks, view mode, theme, listeners,
    % downsampling pipeline, pyramid management, and link propagation.
    methods (Access = private)
        function [color, style] = resolveThresholdStyle(obj, color, style)
            %RESOLVETHRESHOLDSTYLE Apply theme defaults for empty color/style.
            %   [color, style] = RESOLVETHRESHOLDSTYLE(obj, color, style)
            %   fills in empty color or style with Theme.ThresholdColor and
            %   Theme.ThresholdStyle respectively. Used by addSensor to
            %   resolve sensor-defined threshold visuals against the theme.
            %
            %   Inputs:
            %     color — RGB triplet or empty
            %     style — line style string or empty
            %
            %   Outputs:
            %     color — resolved RGB triplet
            %     style — resolved line style string
            %
            %   See also addSensor, addThreshold.
            if isempty(color)
                color = obj.Theme.ThresholdColor;
            end
            if isempty(style)
                style = obj.Theme.ThresholdStyle;
            end
        end

        function onLiveTimer(obj)
            %ONLIVETIMER Timer callback — check file and refresh if changed.
            %   ONLIVETIMER(obj) is invoked by the live polling timer at
            %   each interval. Compares the file's datenum to LiveFileDate;
            %   if newer, loads the file and calls LiveUpdateFcn(obj, data).
            %   Also checks MetadataFile for changes and reloads if needed.
            %   Errors are caught and logged when Verbose is true.
            %
            %   See also startLive, onLiveTimerPublic, loadMetadataFile.
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
            %   LOADMETADATAFILE(obj) loads the .mat file specified by
            %   MetadataFile, extracts the variables listed in MetadataVars
            %   via loadMetaStruct(), and attaches the resulting struct to
            %   the line at index MetadataLineIndex.
            %
            %   Called during startLive() for initial load, and by
            %   onLiveTimer() when the metadata file changes.
            %
            %   See also startLive, onLiveTimer, setLineMetadata.
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
            %   ONFIGURECLOSELIVE(obj, existingDeleteFcn, src, evt) is
            %   installed as the figure's DeleteFcn by startLive(). It
            %   stops the live timer via stopLive(), then chains to any
            %   previously installed DeleteFcn so other cleanup code still
            %   runs.
            %
            %   Inputs:
            %     existingDeleteFcn — previous DeleteFcn handle (or empty)
            %     src               — source figure handle
            %     evt               — event data
            %
            %   See also startLive, stopLive.
            obj.stopLive();
            if ~isempty(existingDeleteFcn)
                if isa(existingDeleteFcn, 'function_handle')
                    existingDeleteFcn(src, evt);
                end
            end
        end

        function applyViewMode(obj, newX)
            %APPLYVIEWMODE Adjust axes limits based on LiveViewMode.
            %   APPLYVIEWMODE(obj, newX) modifies the X-axis limits
            %   according to the current LiveViewMode setting:
            %     'preserve' — no change (keep current zoom/pan)
            %     'follow'   — slide the window so the right edge tracks
            %                  the latest data point, keeping window width
            %     'reset'    — set XLim to span the full new X range
            %
            %   Called by updateData() before re-downsample.
            %
            %   Inputs:
            %     newX — the new X data vector (used to determine latest X)
            %
            %   See also updateData, setViewMode, startLive.
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
            %   APPLYTHEME(obj) configures the figure background (only when
            %   FastPlot owns the figure), axes background, foreground
            %   colors, font name/size, and grid style from the Theme
            %   struct. Called during render() and by reapplyTheme().
            %
            %   See also reapplyTheme, render, FastPlotTheme.
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

        function refineLines(obj)
            %REFINELINES Replace stride preview with proper downsampled data.
            %   REFINELINES(obj) is called asynchronously via a one-shot
            %   timer after render(). During render(), large lines are
            %   displayed with a fast stride-based preview (every K-th
            %   point). This method replaces that preview with a proper
            %   MinMax or LTTB downsample at screen pixel resolution, then
            %   updates violation markers and flushes the display.
            %
            %   Only processes lines with more points than
            %   MinPointsForDownsample. Sets IsRefined=true and stops the
            %   refine timer when done.
            %
            %   See also render, stopRefineTimer, updateLines.
            if ~obj.IsRendered || ~ishandle(obj.hAxes)
                return;
            end

            pw = obj.getAxesPixelWidth();
            logXFlag = strcmp(obj.XScale, 'log');
            logYFlag = strcmp(obj.YScale, 'log');
            for i = 1:numel(obj.Lines)
                L = obj.Lines(i);
                if numel(L.X) <= obj.MinPointsForDownsample
                    continue;
                end
                if ~ishandle(L.hLine)
                    continue;
                end

                if strcmp(L.DownsampleMethod, 'lttb')
                    [xd, yd] = lttb_downsample(L.X, L.Y, pw, logXFlag, logYFlag);
                else
                    [xd, yd] = minmax_downsample(L.X, L.Y, pw, L.HasNaN, logXFlag);
                end
                set(L.hLine, 'XData', xd, 'YData', yd);

                if obj.Verbose
                    fprintf('[FastPlot] refine: line %d: %d pts -> %d displayed\n', ...
                        i, numel(L.X), numel(xd));
                end
            end

            obj.IsRefined = true;
            obj.stopRefineTimer();
            obj.updateViolations();
            if ~obj.DeferDraw
                drawnow;
            end
        end

        function stopRefineTimer(obj)
            %STOPREFINETIMER Stop and delete the refinement timer.
            %   STOPREFINETIMER(obj) safely stops and deletes hRefineTimer
            %   if it exists. Called before zoom/pan updates (to cancel
            %   pending refinement), during stopLive(), and in delete().
            %
            %   See also refineLines, delete, stopLive.
            if ~isempty(obj.hRefineTimer)
                try
                    stop(obj.hRefineTimer);
                    delete(obj.hRefineTimer);
                catch
                end
                obj.hRefineTimer = [];
            end
        end

        function onAxesDoubleClick(obj, ~)
            %ONAXESDOUBLECLICK Open loupe on double-click.
            %   ONAXESDOUBLECLICK(obj, evt) is the ButtonDownFcn callback
            %   installed on the axes and its children during render().
            %   Checks if SelectionType is 'open' (double-click); if so,
            %   calls openLoupe() to create an enlarged standalone copy.
            %
            %   See also openLoupe, loupeButtonFilter, render.
            if ~strcmp(get(ancestor(obj.hAxes, 'figure'), 'SelectionType'), 'open')
                return;
            end
            obj.openLoupe();
        end

        function flag = loupeButtonFilter(obj)
            %LOUPEBUTTONFILTER Intercept double-clicks before zoom handles them.
            %   flag = LOUPEBUTTONFILTER(obj) is installed as the zoom
            %   tool's ButtonDownFilter during render(). When the user
            %   double-clicks, it opens a loupe and returns true to prevent
            %   the zoom tool from processing the click. Single clicks
            %   return false, allowing normal zoom behavior.
            %
            %   Output:
            %     flag — true to block zoom (loupe opened), false to allow
            %
            %   See also onAxesDoubleClick, openLoupe, render.
            if strcmp(get(obj.hFigure, 'SelectionType'), 'open')
                obj.openLoupe();
                flag = true;
            else
                flag = false;
            end
        end

        function onXLimChanged(obj, ~, ~)
            %ONXLIMCHANGED Respond to zoom/pan by re-downsampling visible data.
            %   ONXLIMCHANGED(obj, src, evt) is the XLim PostSet listener
            %   callback installed during render(). Fires whenever the user
            %   zooms or pans. Re-downsamples all lines and shadings to the
            %   new visible range, updates violation markers, refreshes
            %   datetime tick formatting, propagates the new limits to
            %   linked plots, and flushes the display.
            %
            %   Guards against re-entrant calls via IsPropagating and
            %   skips processing if XLim hasn't actually changed (via
            %   CachedXLim comparison).
            %
            %   See also onXLimModeChanged, updateLines, propagateXLim.

            if ~obj.IsRendered || ~ishandle(obj.hAxes) || obj.IsPropagating
                return;
            end

            % Cancel pending refinement — zoom/pan triggers proper downsample
            if ~obj.IsRefined
                obj.stopRefineTimer();
                obj.IsRefined = true;
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

            % Update datetime tick labels for new zoom level
            if strcmp(obj.XType, 'datenum')
                obj.updateDatetimeTicks();
            end

            % Propagate to linked axes
            if ~isempty(obj.LinkGroup)
                obj.propagateXLim(newXLim);
            end

            obj.drawnowLimitRate();
            if obj.Verbose; fflush(stdout); end
        end

        function onXLimModeChanged(obj)
            %ONXLIMMODECHANGED Catch XLim changes that bypass XLim PostSet.
            %   ONXLIMMODECHANGED(obj) is the XLimMode PostSet listener
            %   callback. Two MATLAB features change XLim without firing
            %   the XLim PostSet event:
            %     1. resetplotview() (Home button) — defers the XLim change
            %        until after callbacks return, so we schedule a deferred
            %        check via scheduleDeferredXLimCheck().
            %     2. XLimMode='auto' — XLim is already auto-computed at
            %        callback time, so we immediately restore FullXLim and
            %        re-downsample.
            %
            %   See also onXLimChanged, scheduleDeferredXLimCheck.
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
            %   SCHEDULEDEFERREDXLIMCHECK(obj) creates a 10ms one-shot
            %   timer that calls deferredXLimCheck(). This allows MATLAB's
            %   resetplotview to complete its deferred XLim update before
            %   we read the new value. Cancels any previously scheduled
            %   timer to avoid stacking.
            %
            %   See also onXLimModeChanged, deferredXLimCheck.
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
            %   DEFERREDXLIMCHECK(obj) reads the current XLim and, if it
            %   differs from CachedXLim, re-downsamples all lines, shadings,
            %   and violations. Called by the one-shot timer from
            %   scheduleDeferredXLimCheck after resetplotview has completed.
            %
            %   See also scheduleDeferredXLimCheck, onXLimModeChanged.
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
            %ONRESIZE Re-downsample all data when the figure is resized.
            %   ONRESIZE(obj, src, evt) is the figure ResizeFcn callback
            %   installed during render() (only when FastPlot owns the
            %   figure). Reads the new axes pixel width; if it changed,
            %   re-downsamples all lines, shadings, and violations at the
            %   new resolution and flushes the display.
            %
            %   See also render, getAxesPixelWidth, updateLines.

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
                obj.updateViolations();
                obj.drawnowLimitRate();
                if obj.Verbose; fflush(stdout); end
            end
        end

        function updateShadings(obj)
            %UPDATESHADINGS Re-downsample shaded regions for current view.
            %   UPDATESHADINGS(obj) iterates over all shaded regions and
            %   re-downsamples their patch vertices for the current XLim.
            %   Uses the pre-downsampled cache (CacheX/CacheY1/CacheY2)
            %   when available (built during render for datasets >20k pts),
            %   otherwise works from raw data.
            %
            %   For each shading, binary-searches the source X to find the
            %   visible slice, then MinMax-downsamples to screen pixel
            %   width before updating the patch's XData/YData.
            %
            %   See also addShaded, render, updateLines.
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
            %   UPDATELINES(obj) is the core zoom/pan handler. For each
            %   non-static line, it:
            %     1. Binary-searches raw X for the visible index range
            %     2. If the visible slice is small enough, plots raw data
            %     3. Otherwise, selects the coarsest pyramid level with
            %        enough resolution (via selectPyramidLevel)
            %     4. Downsamples the visible slice from that level to
            %        screen pixel width using MinMax or LTTB
            %     5. Updates the line's XData/YData
            %
            %   Static lines (those with fewer points than
            %   MinPointsForDownsample, flagged at addLine time) are
            %   skipped entirely since they already display all points.
            %
            %   See also selectPyramidLevel, buildPyramidLevel, onXLimChanged.
            pw = obj.PixelWidth;
            xlims = get(obj.hAxes, 'XLim');
            target = 2 * pw;
            logXFlag = strcmp(obj.XScale, 'log');
            logYFlag = strcmp(obj.YScale, 'log');

            for i = 1:numel(obj.Lines)
                % Static lines (threshold steps, small overlays): already
                % rendered with all points — skip on zoom/pan updates.
                if obj.Lines(i).IsStatic
                    continue;
                end

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
                            [xd, yd] = lttb_downsample(xVis, yVis, pw, logXFlag, logYFlag);
                        else
                            [xd, yd] = minmax_downsample(xVis, yVis, pw, obj.Lines(i).HasNaN, logXFlag);
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
            %SELECTPYRAMIDLEVEL Pick the coarsest pyramid level with enough resolution.
            %   lvl = SELECTPYRAMIDLEVEL(obj, lineIdx, nVis, nTotal, target)
            %   scans from the coarsest (highest) level down to level 1,
            %   returning the first level whose estimated visible point
            %   count meets or exceeds target. Builds missing levels lazily
            %   via buildPyramidLevel. Returns 0 if no pyramid level has
            %   enough resolution (caller should use raw data).
            %
            %   Inputs:
            %     lineIdx — index of the line in obj.Lines
            %     nVis    — number of raw points in the visible range
            %     nTotal  — total number of raw points in the line
            %     target  — minimum number of points needed (2 * pixelWidth)
            %
            %   Output:
            %     lvl — pyramid level index (1-based), or 0 for raw data
            %
            %   See also buildPyramidLevel, updateLines.
            visFrac = nVis / nTotal;  % fraction of data currently visible
            R = obj.PyramidReduction;

            % Determine how many pyramid levels could exist given the data
            % size: each level reduces by R, stop when level size < target
            maxLevels = 0;
            sz = nTotal;
            while sz / R > target
                maxLevels = maxLevels + 1;
                sz = sz / R;
            end

            % Try from coarsest (highest level) to finest — first level
            % whose estimated visible count >= target is used
            lvl = 0;
            for k = maxLevels:-1:1
                levelSize = nTotal / (R ^ k);      % total points at this level
                levelVisible = levelSize * visFrac; % estimated visible points
                if levelVisible >= target
                    % This level has enough resolution — build lazily
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
            %   BUILDPYRAMIDLEVEL(obj, lineIdx, level) constructs a
            %   MinMax-downsampled version of the line data at the given
            %   pyramid level. Level 1 downsamples from raw data; higher
            %   levels downsample from the previous level (building it
            %   recursively if needed). Each level reduces by
            %   PyramidReduction (default: 100x).
            %
            %   The result is stored as a struct with fields .X and .Y in
            %   obj.Lines(lineIdx).Pyramid{level}.
            %
            %   Inputs:
            %     lineIdx — index of the line in obj.Lines
            %     level   — pyramid level to build (1-based)
            %
            %   See also selectPyramidLevel, updateLines.
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
            logXFlag = strcmp(obj.XScale, 'log');
            [px, py] = minmax_downsample(srcX, srcY, numBuckets, false, logXFlag);
            obj.Lines(lineIdx).Pyramid{level} = struct('X', px, 'Y', py);
        end

        function updateViolations(obj)
            %UPDATEVIOLATIONS Recompute violation markers from displayed data.
            %   UPDATEVIOLATIONS(obj) iterates over all thresholds with
            %   ShowViolations=true and recomputes marker positions using
            %   the already-downsampled line data (avoiding full raw scan).
            %
            %   Uses a dirty-flag (CachedViolationLim) to skip recomputation
            %   when the view (XLim, YLim, PixelWidth) has not changed.
            %   For each threshold, calls violation_cull() against each
            %   non-static line's displayed XData/YData. Creates marker
            %   handles lazily if they don't exist yet (e.g. if the plot
            %   was rendered with ViolationsVisible=false).
            %
            %   See also setViolationsVisible, addThreshold, violation_cull.

            if ~obj.ViolationsVisible
                return;
            end

            % Dirty-flag: skip if view is unchanged since last violation update
            if ~isempty(obj.Thresholds) && ishandle(obj.hAxes)
                xl = get(obj.hAxes, 'XLim');
                yl = get(obj.hAxes, 'YLim');
                currentLim = [xl, yl, obj.PixelWidth];
                if ~isempty(obj.CachedViolationLim) && isequal(currentLim, obj.CachedViolationLim)
                    return;
                end
                obj.CachedViolationLim = currentLim;
            end

            for t = 1:numel(obj.Thresholds)
                if ~obj.Thresholds(t).ShowViolations
                    continue;
                end
                % Create marker handle if it was never built (e.g. rendered
                % while ViolationsVisible was false)
                if isempty(obj.Thresholds(t).hMarkers) || ~ishandle(obj.Thresholds(t).hMarkers)
                    T = obj.Thresholds(t);
                    hM = line(NaN, NaN, 'Parent', obj.hAxes, ...
                        'LineStyle', 'none', 'Marker', '.', ...
                        'MarkerSize', 6, 'Color', T.Color, ...
                        'HandleVisibility', 'off');
                    udM.FastPlot = struct( ...
                        'Type', 'violation_marker', ...
                        'Name', T.Label, ...
                        'LineIndex', [], ...
                        'ThresholdValue', T.Value);
                    set(hM, 'UserData', udM);
                    obj.Thresholds(t).hMarkers = hM;
                end

                nLines = numel(obj.Lines);
                vxCell = cell(1, nLines);
                vyCell = cell(1, nLines);
                nViols = 0;
                pw = diff(xl) / obj.PixelWidth;
                for i = 1:nLines
                    if obj.Lines(i).IsStatic; continue; end
                    xd = get(obj.Lines(i).hLine, 'XData');
                    yd = get(obj.Lines(i).hLine, 'YData');
                    if isempty(obj.Thresholds(t).X)
                        [vx, vy] = violation_cull(xd, yd, 0, obj.Thresholds(t).Value, ...
                            obj.Thresholds(t).Direction, pw, xl(1));
                    else
                        [vx, vy] = violation_cull(xd, yd, obj.Thresholds(t).X, obj.Thresholds(t).Y, ...
                            obj.Thresholds(t).Direction, pw, xl(1));
                    end
                    if ~isempty(vx)
                        nViols = nViols + 1;
                        vxCell{nViols} = vx;
                        vyCell{nViols} = vy;
                    end
                end

                if nViols > 0
                    vxAll = [vxCell{1:nViols}];
                    vyAll = [vyCell{1:nViols}];
                    set(obj.Thresholds(t).hMarkers, 'XData', vxAll, 'YData', vyAll);
                    if obj.Verbose
                        fprintf('[FastPlot]   violations T%d: %d markers\n', ...
                            t, numel(vxAll));
                    end
                else
                    set(obj.Thresholds(t).hMarkers, 'XData', NaN, 'YData', NaN);
                    if obj.Verbose
                        fprintf('[FastPlot]   violations T%d: 0 markers\n', t);
                    end
                end
            end
        end

        function updateDatetimeTicks(obj)
            %UPDATEDATETIMETICKS Format X tick labels based on visible range.
            %   UPDATEDATETIMETICKS(obj) calls datetick() with a format
            %   string selected based on the visible X span (in datenum
            %   days):
            %     > 1 day:   'mmm dd HH:MM'
            %     1h - 1d:   'HH:MM'
            %     1m - 1h:   'HH:MM'
            %     < 1 min:   'HH:MM:SS'
            %
            %   Called during render() and on every XLim change when the
            %   X axis uses datenum values. Falls back gracefully if
            %   datetick is unavailable.
            %
            %   See also render, onXLimChanged.
            if ~ishandle(obj.hAxes); return; end
            try
                xl = get(obj.hAxes, 'XLim');
                span = diff(xl);  % in days (datenum units)
                if span > 1
                    fmt = 'mmm dd HH:MM';
                elseif span > 1/24  % > 1 hour
                    fmt = 'HH:MM';
                elseif span > 1/1440  % > 1 minute
                    fmt = 'HH:MM';
                else
                    fmt = 'HH:MM:SS';
                end
                datetick(obj.hAxes, 'x', fmt, 'keeplimits');
            catch
                % Fallback: plain datetick
                try
                    datetick(obj.hAxes, 'x', 'keeplimits');
                catch
                end
            end
        end

        function drawnowLimitRate(obj)
            %DRAWNOWLIMITRATE Flush graphics with rate limiting when available.
            %   DRAWNOWLIMITRATE(obj) calls drawnow('limitrate') on MATLAB
            %   to cap rendering at ~60fps during rapid zoom/pan, preventing
            %   UI thread stalls. On Octave (where 'limitrate' is not
            %   supported), falls back to plain drawnow.
            %
            %   The MATLAB/Octave check is cached in HasLimitRate on first
            %   call to avoid repeated exist() lookups.
            %
            %   See also onXLimChanged, updateData.
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
            %   pw = GETAXESPIXELWIDTH(obj) temporarily switches the axes
            %   Units to 'pixels', reads Position(3), then restores the
            %   original units. Returns a minimum of 100 to prevent
            %   degenerate downsampling when axes are very narrow or not
            %   yet laid out.
            %
            %   Output:
            %     pw — axes width in pixels (integer, >= 100)
            %
            %   See also onResize, render, updateLines.
            oldUnits = get(obj.hAxes, 'Units');
            set(obj.hAxes, 'Units', 'pixels');
            pos = get(obj.hAxes, 'Position');
            set(obj.hAxes, 'Units', oldUnits);
            pw = max(100, floor(pos(3)));
        end

        function propagateXLim(obj, newXLim)
            %PROPAGATEXLIM Sync XLim to all members of the link group.
            %   PROPAGATEXLIM(obj, newXLim) retrieves all FastPlot instances
            %   registered in the same LinkGroup, then sets each one's XLim
            %   to newXLim and re-downsamples its lines, shadings, and
            %   violations. Each member's IsPropagating flag is set to true
            %   while updating to prevent re-entrant XLim listener calls.
            %
            %   Inputs:
            %     newXLim — 1-by-2 vector [xmin xmax] to apply
            %
            %   See also onXLimChanged, getLinkRegistry.
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
            %   registry = GETLINKREGISTRY(action, group, obj) manages a
            %   persistent struct that maps group names to cell arrays of
            %   FastPlot handles. Group names are sanitized via
            %   matlab.lang.makeValidName.
            %
            %   Actions:
            %     'register' — append obj to the group's cell array
            %     'get'      — return the cell array for the group
            %     'cleanup'  — remove dead handles (ishandle check)
            %
            %   Inputs:
            %     action — 'register', 'get', or 'cleanup'
            %     group  — string group name (from LinkGroup property)
            %     obj    — FastPlot instance (used for 'register' only)
            %
            %   Output:
            %     registry — cell array of FastPlot handles (for 'get'),
            %                or [] for other actions
            %
            %   See also propagateXLim, render.
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
            %   FastPlot.RESETDEFAULTS() clears the cached defaults struct
            %   so the next FastPlot constructor will re-read
            %   FastPlotDefaults.m. Useful after editing the defaults file
            %   in a running session.
            %
            %   Example:
            %     FastPlot.resetDefaults();
            %     fp = FastPlot();  % picks up new defaults
            %
            %   See also FastPlot, getDefaults, clearDefaultsCache.
            clearDefaultsCache();
        end

        function distFig(varargin)
            %DISTFIG Distribute figure windows across the screen.
            %   FastPlot.DISTFIG() auto-arranges all open figure windows
            %   in a grid that fills the screen. Figures are sorted by
            %   number and tiled left-to-right, top-to-bottom.
            %   FastPlot.DISTFIG('Rows', 2, 'Cols', 3) uses a 2-by-3 grid.
            %
            %   Delegates to the vendored distFig function (in vendor/).
            %   Adds the vendor path automatically if not already on path.
            %
            %   Inputs:
            %     varargin — name-value pairs forwarded to distFig:
            %       'Rows' — number of grid rows
            %       'Cols' — number of grid columns
            %
            %   Example:
            %     FastPlot.distFig();
            %     FastPlot.distFig('Rows', 2, 'Cols', 3);
            %
            %   See also FastPlotDock.
            vendorDir = fullfile(fileparts(mfilename('fullpath')), 'vendor', 'distFig');
            if ~exist('distFig', 'file')
                addpath(vendorDir);
            end
            distFig(varargin{:});
        end
    end
end
