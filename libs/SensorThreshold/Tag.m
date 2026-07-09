classdef Tag < handle
    %TAG Abstract base for the unified Tag domain model.
    %   Tag is the root of the v2.0 domain hierarchy.  Subclasses
    %   (SensorTag, StateTag, MonitorTag, CompositeTag) provide concrete
    %   implementations of the six abstract-by-convention methods.
    %
    %   Tag uses the Octave-safe "throw-from-base" abstract pattern:
    %   the base class provides stub methods that raise a notImplemented
    %   error, and subclasses override with concrete implementations.
    %   Do NOT use the Abstract-methods block pattern here — it has
    %   divergent semantics between MATLAB and Octave (see DataSource.m
    %   for the proven pattern used here).
    %
    %   Tag Properties (public):
    %     Key         — char: unique identifier (required, non-empty)
    %     Name        — char: human-readable name (defaults to Key)
    %     Units       — char: measurement unit
    %     Description — char: free-text description
    %     Labels      — cellstr: cross-cutting classification (META-01)
    %     Metadata    — struct: open key-value bag (META-03)
    %     Criticality — char enum: 'low'|'medium'|'high'|'safety' (META-04)
    %     SourceRef   — char: optional provenance string
    %
    %   Tag Methods (abstract-by-convention — subclass must implement):
    %     getXY               — return [X, Y] data vectors
    %     valueAt(t)          — return scalar value at time t
    %     getTimeRange        — return [tMin, tMax]
    %     getKind             — return kind string ('sensor'|'state'|'monitor'|'composite'|'mock')
    %     toStruct            — return serializable struct
    %     fromStruct (Static) — reconstruct from struct
    %
    %   Tag Methods (default hooks — override when needed):
    %     resolveRefs(registry) — Pass-2 deserialization hook; default no-op
    %
    %   Example (subclass):
    %     classdef SensorTag < Tag
    %         methods
    %             function obj = SensorTag(key, varargin)
    %                 obj@Tag(key, varargin{:});
    %             end
    %             function [X, Y] = getXY(obj)
    %                 X = obj.X_;
    %                 Y = obj.Y_;
    %             end
    %             % ... other abstracts ...
    %         end
    %     end
    %
    %   See also TagRegistry, MockTag, DataSource.

    properties
        Key          = ''       % char: unique identifier
        Name         = ''       % char: human-readable name
        Units        = ''       % char: measurement unit
        Description  = ''       % char: free-text description
        Labels       = {}       % cellstr: cross-cutting classification
        Metadata     = struct() % struct: open key-value bag
        Criticality  = 'medium' % char enum: 'low'|'medium'|'high'|'safety'
        SourceRef    = ''       % char: optional provenance string
        EventStore   = []       % EventStore handle; [] disables event convenience methods
    end

    events
        DataChanged             % Fired when underlying (X, Y) data is mutated.
    end

    methods
        function obj = Tag(key, varargin)
            %TAG Construct a Tag with required key and optional name-value pairs.
            %
            %   t = Tag(key) creates a Tag with the given key; Name defaults to key.
            %
            %   t = Tag(key, 'Name', n, 'Labels', {...}, 'Criticality', 'safety', ...)
            %   sets optional properties.
            %
            %   Valid name-value keys: Name, Units, Description, Labels,
            %   Metadata, Criticality, SourceRef.
            %
            %   Error IDs raised:
            %     invalidKey         — key is empty or not char
            %     unknownOption      — name-value key not recognized
            %     invalidCriticality — Criticality not in valid set

            if nargin < 1 || isempty(key) || ~ischar(key)
                error('Tag:invalidKey', 'Key must be a non-empty char.');
            end
            obj.Key  = key;
            obj.Name = key;  % default Name = Key

            validKeys = {'Name', 'Units', 'Description', 'Labels', ...
                         'Metadata', 'Criticality', 'SourceRef'};
            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Name',        obj.Name        = varargin{i+1};
                    case 'Units',       obj.Units       = varargin{i+1};
                    case 'Description', obj.Description = varargin{i+1};
                    case 'Labels',      obj.Labels      = varargin{i+1};
                    case 'Metadata',    obj.Metadata    = varargin{i+1};
                    case 'Criticality', obj.Criticality = varargin{i+1};
                    case 'SourceRef',   obj.SourceRef   = varargin{i+1};
                    otherwise
                        error('Tag:unknownOption', ...
                            'Unknown option ''%s''. Valid options: %s.', ...
                            varargin{i}, strjoin(validKeys, ', '));
                end
            end
        end

        function set.Criticality(obj, v)
            %SET.CRITICALITY Validate enum before assigning.
            valid = {'low', 'medium', 'high', 'safety'};
            if ~ischar(v) || ~any(strcmp(v, valid))
                error('Tag:invalidCriticality', ...
                    'Criticality must be one of: %s. Got: ''%s''.', ...
                    strjoin(valid, ', '), char(v));
            end
            obj.Criticality = v;
        end

        % ---- Abstract-by-convention (throw-from-base) ----
        % Pitfall 1 budget: EXACTLY 5 instance abstracts + 1 static = 6 total.

        function [X, Y] = getXY(obj) %#ok<STOUT,MANU>
            %GETXY Return [X, Y] data vectors.  Subclass must override.
            error('Tag:notImplemented', 'Subclass must implement getXY().');
        end

        function [X, Y] = getXYRange(obj, tStart, tEnd)
            %GETXYRANGE Return X, Y sliced to the window [tStart, tEnd].
            %   Default implementation: call getXY() then binary-search-slice.
            %   Empty/[] bounds return the full series (delegates to getXY()).
            %   SensorTag overrides this for disk-backed efficiency.
            if nargin < 3 || isempty(tStart) || isempty(tEnd)
                [X, Y] = obj.getXY();
                return;
            end
            [X, Y] = obj.getXY();
            if isempty(X)
                return;
            end
            if tStart > tEnd
                X = []; Y = [];
                return;
            end
            if tEnd < X(1) || tStart > X(end)
                % Window lies entirely outside the data extent -> empty.
                % (Without this guard the one-point padding below would pull
                % in a boundary sample for a non-overlapping window.)
                X = []; Y = [];
                return;
            end
            iLo = binary_search(X, tStart, 'left');
            iHi = binary_search(X, tEnd,   'right');
            iLo = max(1, iLo - 1);           % one-point padding (matches DataStore.getRange)
            iHi = min(numel(X), iHi + 1);
            if iLo > iHi
                X = []; Y = [];
                return;
            end
            X = X(iLo:iHi);
            Y = Y(iLo:iHi);
        end

        function s = getStats(obj, tStart, tEnd)
            %GETSTATS One-call statistics summary over the series or a time window.
            %   s = tag.getStats() summarizes the whole resolved series.
            %   s = tag.getStats(tStart, tEnd) restricts the reduction to the
            %   windowed slice (via getXYRange, so every Tag subclass inherits
            %   this with zero overrides).
            %
            %   Returns a struct with fields, in order:
            %     N         - count of non-NaN numeric samples in the window
            %     Min       - minimum          (NaNs excluded)
            %     Max       - maximum          (NaNs excluded)
            %     Mean      - mean             (NaNs excluded)
            %     Rms       - sqrt(mean(y.^2)) (NaNs excluded)
            %     Std       - standard deviation (NaNs excluded)
            %     First     - first sample of the windowed series (raw; may be NaN)
            %     Last      - last  sample of the windowed series (raw; may be NaN)
            %     TimeStart - X(1)   of the window
            %     TimeEnd   - X(end) of the window
            %
            %   The numeric reductions (Min/Max/Mean/Rms/Std) are numeric-only:
            %   for a non-numeric (cellstr) StateTag series they return NaN while
            %   N and the time bounds are still reported.
            %
            %   Toolbox-free and Octave-safe: NaNs are stripped by masking, not
            %   via the 'omitnan' flag.
            %
            %   See also getXYRange, getXY.
            if nargin < 3
                tStart = [];
                tEnd = [];
            end
            [x, y] = obj.getXYRange(tStart, tEnd);
            x = x(:);
            y = y(:);
            if islogical(y)
                y = double(y);
            end

            s = struct('N', 0, 'Min', NaN, 'Max', NaN, 'Mean', NaN, ...
                       'Rms', NaN, 'Std', NaN, 'First', NaN, 'Last', NaN, ...
                       'TimeStart', NaN, 'TimeEnd', NaN);

            if isempty(x)
                return;
            end
            s.TimeStart = x(1);
            s.TimeEnd   = x(end);

            if ~isnumeric(y)
                % Non-numeric (e.g. cellstr StateTag) series: report the sample
                % count and time bounds only; numeric reductions are undefined.
                s.N = numel(x);
                return;
            end

            s.First = y(1);
            s.Last  = y(end);

            yv = y(~isnan(y));
            s.N = numel(yv);
            if s.N == 0
                return;
            end
            s.Min  = min(yv);
            s.Max  = max(yv);
            s.Mean = mean(yv);
            s.Rms  = sqrt(mean(yv.^2));
            s.Std  = std(yv);
        end

        function pv = percentile(obj, levels, tStart, tEnd)
            %PERCENTILE Order-statistic percentile value(s) of the series (#339).
            %   pv = tag.percentile(95)            % scalar level  -> scalar value
            %   pv = tag.percentile([5 50 95])     % vector levels -> vector values
            %   pv = tag.percentile([5 95], t0, t1)% over a window (mirrors getStats)
            %
            %   Returns the percentile *values* of the resolved numeric series
            %   using toolbox-free linear interpolation between order statistics:
            %   for a level p over n sorted samples the fractional 1-based
            %   position is i = p/100*(n-1) + 1, interpolated between
            %   Ys(floor(i)) and Ys(ceil(i)). Inherited by every Tag subclass
            %   via getXYRange, so it needs no per-kind override.
            %
            %   Inputs:
            %     levels        - numeric scalar or array of percentile levels,
            %                     each in [0, 100]. Output matches its shape.
            %     tStart, tEnd  - optional window bounds (empty / omitted =>
            %                     full series, same contract as getStats).
            %
            %   Output:
            %     pv - percentile value(s), same shape as levels. NaN (matching
            %          shape) when the window has no non-NaN samples.
            %
            %   NaN-robust and Octave-safe: NaNs are masked out before sorting.
            %
            %   Errors:
            %     Tag:invalidPercentile - levels missing / non-numeric / outside [0,100]
            %     Tag:notNumeric        - series Y is non-numeric (e.g. cellstr StateTag)
            %
            %   See also getStats, median, iqr, getXYRange.
            if nargin < 3, tStart = []; end
            if nargin < 4, tEnd   = []; end
            if nargin < 2 || isempty(levels) || ~isnumeric(levels) || ...
                    any(~isfinite(levels(:))) || any(levels(:) < 0 | levels(:) > 100)
                error('Tag:invalidPercentile', ...
                    'Percentile levels must be numeric and in [0, 100].');
            end

            [~, y] = obj.getXYRange(tStart, tEnd);
            y = y(:);
            if islogical(y), y = double(y); end
            if ~isnumeric(y)
                error('Tag:notNumeric', ...
                    'percentile requires a numeric series; this tag''s Y is non-numeric.');
            end

            yv = sort(y(~isnan(y)));
            n  = numel(yv);
            pv = nan(size(levels));
            if n == 0
                return;                     % empty / all-NaN -> NaN(s), matching shape
            end
            if n == 1
                pv(:) = yv(1);              % single sample -> that value at every level
                return;
            end

            idx  = double(levels(:)) / 100 * (n - 1) + 1;   % 1-based fractional position
            lo   = floor(idx);
            hi   = ceil(idx);
            frac = idx - lo;
            vals = yv(lo) + frac .* (yv(hi) - yv(lo));
            pv   = reshape(vals, size(levels));
        end

        function m = median(obj, tStart, tEnd)
            %MEDIAN Robust central tendency == percentile(50) (#339).
            %   m = tag.median() over the full series; m = tag.median(t0, t1)
            %   over a window. Convenience wrapper over percentile.
            %
            %   See also percentile, iqr, getStats.
            if nargin < 2, tStart = []; end
            if nargin < 3, tEnd   = []; end
            m = obj.percentile(50, tStart, tEnd);
        end

        function r = iqr(obj, tStart, tEnd)
            %IQR Interquartile range == percentile(75) - percentile(25) (#339).
            %   r = tag.iqr() over the full series; r = tag.iqr(t0, t1) over a
            %   window. Robust spread, insensitive to outliers.
            %
            %   See also percentile, median, getStats.
            if nargin < 2, tStart = []; end
            if nargin < 3, tEnd   = []; end
            q = obj.percentile([25 75], tStart, tEnd);
            r = q(2) - q(1);
        end

        function [Xu, Yu] = resampleUniform(obj, dt, varargin)
            %RESAMPLEUNIFORM Resample the series onto a uniform time grid (#308).
            %   [Xu, Yu] = tag.resampleUniform(dt) returns the series on a
            %   uniform grid of spacing dt over the tag's time range.
            %   [Xu, Yu] = tag.resampleUniform(dt, 'Range', [t0 t1]) grids only
            %   the given window. 'Method' overrides the interpolation method;
            %   'MaxGap' (default Inf) NaN-fills grid points that fall inside an
            %   original sample gap wider than MaxGap so data is not invented
            %   across dropouts.
            %
            %   Kind-aware default interpolation: continuous tags use 'linear';
            %   discrete tags (state/monitor) use 'previous' (zero-order hold),
            %   honouring the ZOH-only invariant for state/monitor channels.
            %
            %   Toolbox-free (interp1 linear/previous is core MATLAB/Octave).
            %
            %   See also getXY, getKind.
            if nargin < 2 || ~isnumeric(dt) || ~isscalar(dt) || ~(dt > 0)
                error('Tag:resampleUniformBadDt', 'dt must be a positive scalar.');
            end
            [rangeVal, method, maxGap] = obj.parseResampleOpts_(varargin{:});
            if isempty(rangeVal)
                [X, Y] = obj.getXY();
            else
                [X, Y] = obj.getXYRange(rangeVal(1), rangeVal(2));
            end
            X = X(:);
            Y = Y(:);
            if isempty(method)
                if obj.isDiscreteKind_()
                    method = 'previous';
                else
                    method = 'linear';
                end
            end
            if numel(X) < 2
                Xu = X.';
                Yu = Y.';
                return;
            end
            % Grid spans the requested window (clipped to data extent); the
            % padded slice above still bounds the grid edges for interpolation.
            if isempty(rangeVal)
                gStart = X(1);
                gEnd = X(end);
            else
                gStart = max(X(1), rangeVal(1));
                gEnd = min(X(end), rangeVal(2));
            end
            Xu = gStart:dt:gEnd;
            Yu = interp1(X, Y, Xu, method);
            if isfinite(maxGap)
                gapIdx = find(diff(X) > maxGap);
                for g = gapIdx(:).'
                    inGap = Xu > X(g) & Xu < X(g + 1);
                    Yu(inGap) = NaN;
                end
            end
        end

        function varargout = derivative(obj, varargin)
            %DERIVATIVE Kind-aware rate-of-change series dY/dX (#326).
            %   [t, dydt] = tag.derivative() returns central-difference rate of
            %   change (correct on non-uniform spacing).
            %   [t, dydt] = tag.derivative('Method', m) where m is 'central'
            %   (default), 'forward', or 'backward'.
            %   [t, dydt] = tag.derivative('Range', [t0 t1]) restricts the window.
            %
            %   NaN-safe: the rate is NaN wherever a contributing neighbour is
            %   NaN. Intended for continuous numeric tags; on a discrete tag it
            %   warns Tag:derivativeOnDiscrete (a step channel's slope is
            %   ill-defined) but still computes.
            %
            %   Toolbox-free (gradient / diff are core MATLAB/Octave).
            %
            %   See also cumulativeIntegral, movingStat, getXY.
            [rangeVal, method] = obj.parseMethodRangeOpts_('central', ...
                {'central', 'forward', 'backward'}, 'derivative', varargin{:});
            [X, Y] = obj.getSeries_(rangeVal);
            if obj.isDiscreteKind_()
                warning('Tag:derivativeOnDiscrete', ...
                    'derivative() on a discrete (%s) tag: the slope of a step channel is ill-defined.', ...
                    obj.getKind());
            end
            n = numel(X);
            dydt = nan(size(Y));
            if n >= 2
                switch method
                    case 'forward'
                        dydt(1:n-1) = (Y(2:n) - Y(1:n-1)) ./ (X(2:n) - X(1:n-1));
                        dydt(n) = dydt(n-1);
                    case 'backward'
                        dydt(2:n) = (Y(2:n) - Y(1:n-1)) ./ (X(2:n) - X(1:n-1));
                        dydt(1) = dydt(2);
                    otherwise  % central
                        dydt = gradient(Y(:)) ./ gradient(X(:));
                        dydt = reshape(dydt, size(Y));
                end
            end
            varargout = {X, dydt};
            varargout = varargout(1:max(1, nargout));
        end

        function varargout = cumulativeIntegral(obj, varargin)
            %CUMULATIVEINTEGRAL Running trapezoidal integral of Y w.r.t. X.
            %
            %   cum        = obj.cumulativeIntegral()              % grand total (scalar)
            %   cum        = obj.cumulativeIntegral('Range',[t0 t1])  % total over window
            %   [X, cum]   = obj.cumulativeIntegral(...)           % running series
            %
            %   Description:
            %     Computes the running trapezoidal (area-under-curve) integral using
            %     per-segment areas so that an interior NaN Y-value contributes zero
            %     area instead of poisoning the entire tail.  The algorithm is
            %     equivalent to cumtrapz(X,Y) when no NaNs are present; cum(1) is
            %     always 0 (zero area at the first sample).
            %
            %   Empty-data policy:
            %     When the tag returns no data (isempty(X)), the 1-out form
            %     returns the scalar 0 ("empty series integrates to 0") and the
            %     2-out form returns X=[], cum=[].
            %
            %   NaN-gap policy:
            %     A trapezoid segment [i, i+1] whose either endpoint is NaN or
            %     non-finite contributes ZERO area.  A single interior NaN does
            %     NOT turn the running tail into all-NaN.
            %
            %   Discrete-channel warning:
            %     If obj.getKind() == 'state', a Tag:integralOnDiscrete warning
            %     is emitted because the area under a discrete/step channel is
            %     rarely the intended computation.  The value is still returned.
            %
            %   Options (name-value):
            %     'Range', [t0 t1] — restrict integration window to [t0, t1]
            %                        using getXYRange().  Default: full series.
            %
            %   Error IDs:
            %     Tag:unknownOption — unrecognized name-value key

            % --- Parse the optional 'Range' name-value pair ---
            t0 = [];
            t1 = [];
            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Range'
                        rng = varargin{i+1};
                        t0  = rng(1);
                        t1  = rng(2);
                    otherwise
                        error('Tag:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end

            % --- Warn for discrete/step-function channels ---
            if strcmp(obj.getKind(), 'state')
                warning('Tag:integralOnDiscrete', ...
                    ['cumulativeIntegral on a ''state'' (discrete/ZOH) channel ' ...
                     'produces area-under-staircase which is rarely intended.']);
            end

            % --- Fetch data ---
            if ~isempty(t0) && ~isempty(t1)
                [X, Y] = obj.getXYRange(t0, t1);
            else
                [X, Y] = obj.getXY();
            end

            % --- Ensure row vectors for consistent output shape ---
            X = X(:)';
            Y = Y(:)';

            % --- Empty-data guard ---
            if isempty(X)
                if nargout <= 1
                    varargout{1} = 0;
                else
                    varargout{1} = [];
                    varargout{2} = [];
                end
                return;
            end

            % --- Single-sample guard (no interval = no area) ---
            if numel(X) == 1
                cum = 0;
                if nargout <= 1
                    varargout{1} = cum;
                else
                    varargout{1} = X;
                    varargout{2} = cum;
                end
                return;
            end

            % --- Gap-robust trapezoidal accumulation ---
            %   Per-segment area:  0.5 * dt * (Y_i + Y_{i+1})
            %   Non-finite segments (any NaN/Inf endpoint) -> 0 area (gap).
            %   This is algebraically identical to cumtrapz(X,Y) when no
            %   NaNs are present (cum(1)=0, cumulative from the left).
            dt   = diff(X);
            area = 0.5 .* dt .* (Y(1:end-1) + Y(2:end));
            area(~isfinite(area)) = 0;
            cum = [0, cumsum(area)];

            % --- Output dispatch ---
            if nargout <= 1
                varargout{1} = cum(end);
            else
                varargout{1} = X;
                varargout{2} = cum;
            end
        end

        function v = integral(obj, t0, t1)
            %INTEGRAL Scalar definite integral (area under the curve) over a window.
            %   v = tag.integral(t0, t1)  integrates Y w.r.t. time over [t0, t1].
            %   v = tag.integral()        integrates the full series.
            %   v = tag.integral([], [])  same as integral() — empty bounds
            %                             integrate the full series (mirrors the
            %                             empty-bounds contract of getXYRange).
            %
            %   Returns the single number a sensor engineer reports over a
            %   window: energy = int power dt, dose = int concentration dt,
            %   consumed volume = int flow dt, throughput/total over a shift.
            %
            %   This is the bounded-window end value of cumulativeIntegral, to
            %   which it delegates — so it inherits the same toolbox-free,
            %   gap-robust trapezoidal core and edge policy: an empty or
            %   single-sample (degenerate) window integrates to 0, and interior
            %   NaN/Inf segments contribute zero area rather than poisoning the
            %   total.
            %
            %   Inputs:
            %     t0, t1 — optional window bounds. Omit both (or pass []) to
            %              integrate the full series.
            %
            %   Output:
            %     v — scalar area under Y over the window.
            %
            %   Discrete channels:
            %     For a 'state' (discrete/ZOH) channel a Tag:integralOnDiscrete
            %     warning is emitted (area-under-staircase is rarely intended);
            %     the value is still returned. Consistent with cumulativeIntegral.
            %
            %   See also cumulativeIntegral, getXYRange, getStats.
            if nargin < 2, t0 = []; end
            if nargin < 3, t1 = []; end
            if ~isempty(t0) && ~isempty(t1)
                v = obj.cumulativeIntegral('Range', [t0 t1]);
            else
                v = obj.cumulativeIntegral();
            end
        end

        function [X, Ys] = movingStat(obj, window, type)
            %MOVINGSTAT Rolling-window statistic series (#312).
            %   [X, Ys] = tag.movingStat(window) rolling mean over a centered
            %   window of `window` samples (shrinking at the edges).
            %   [X, Ys] = tag.movingStat(window, type) where type is one of
            %   'mean' (default), 'std', 'max', 'min', 'rms', 'median'.
            %
            %   Continuous numeric tags only: a discrete (state/monitor) tag
            %   raises Tag:movingStatNotContinuous (a rolling mean of a step
            %   channel is meaningless). NaNs within a window are excluded; a
            %   fully-NaN window yields NaN.
            %
            %   Toolbox-free / Octave-safe: computed with a hand-rolled window
            %   loop (no movmean/movstd dependency).
            %
            %   See also getStats, resampleUniform, getXY.
            if nargin < 3 || isempty(type)
                type = 'mean';
            end
            if nargin < 2 || ~isnumeric(window) || ~isscalar(window) || window < 1 || mod(window, 1) ~= 0
                error('Tag:movingStatBadWindow', 'window must be a positive integer number of samples.');
            end
            if obj.isDiscreteKind_()
                error('Tag:movingStatNotContinuous', ...
                    'movingStat() requires a continuous tag; %s is discrete.', obj.getKind());
            end
            [X, Y] = obj.getXY();
            X = X(:);
            Y = Y(:);
            n = numel(Y);
            Ys = nan(n, 1);
            half = floor((window - 1) / 2);
            for i = 1:n
                lo = max(1, i - half);
                hi = min(n, i + (window - 1 - half));
                w = Y(lo:hi);
                w = w(~isnan(w));
                if isempty(w)
                    continue;
                end
                switch type
                    case 'mean',   Ys(i) = mean(w);
                    case 'std',    Ys(i) = std(w);
                    case 'max',    Ys(i) = max(w);
                    case 'min',    Ys(i) = min(w);
                    case 'rms',    Ys(i) = sqrt(mean(w.^2));
                    case 'median', Ys(i) = median(w);
                    otherwise
                        error('Tag:movingStatBadType', ...
                            'Unknown type "%s". Use mean|std|max|min|rms|median.', type);
                end
            end
            X = X.';
            Ys = Ys.';
        end

        function varargout = crossings(obj, level, varargin)
            %CROSSINGS Level-crossing times and directions (#328).
            %   c = tag.crossings(level) returns a struct with fields:
            %     times     - interpolated crossing instants (row)
            %     direction - +1 rising / -1 falling, same length
            %     count     - numel(times)
            %     periods   - diff of successive same-direction crossings
            %   c = tag.crossings(level, 'Direction', d) with d 'both' (default),
            %     'rising', or 'falling'.
            %   c = tag.crossings(level, 'Range', [t0 t1]) restricts the window.
            %   [t, dir] = tag.crossings(level) returns times + directions directly.
            %
            %   Continuous tags interpolate the exact crossing instant; a discrete
            %   tag uses the transition sample (ZOH) and warns Tag:crossingsOnDiscrete.
            %   A segment bounded by a NaN yields no crossing.
            %
            %   Toolbox-free (sign/find/diff + linear interpolation).
            %
            %   See also exceedance, derivative, getXY.
            if nargin < 2 || ~isnumeric(level) || ~isscalar(level)
                error('Tag:crossingsBadLevel', 'level must be a numeric scalar.');
            end
            [rangeVal, dirn] = obj.parseDirectionRangeOpts_('both', ...
                {'both', 'rising', 'falling'}, varargin{:});
            [X, Y] = obj.getSeries_(rangeVal);
            discrete = obj.isDiscreteKind_();
            if discrete
                warning('Tag:crossingsOnDiscrete', ...
                    'crossings() on a discrete (%s) tag uses the transition sample (ZOH), not interpolation.', ...
                    obj.getKind());
            end
            times = [];
            direction = [];
            n = numel(X);
            for i = 1:n-1
                y0 = Y(i);
                y1 = Y(i+1);
                if isnan(y0) || isnan(y1)
                    continue;                 % gap
                end
                s0 = y0 - level;
                s1 = y1 - level;
                if s0 == 0 && s1 == 0
                    continue;                 % plateau exactly at level: no crossing
                end
                if s0 * s1 < 0 || (s0 == 0 && s1 ~= 0)
                    % A crossing occurs entering this interval.
                    d = sign(s1 - s0);
                    if discrete || (y1 == y0)
                        tc = X(i+1);          % ZOH: transition at the next sample
                    else
                        tc = X(i) + (level - y0) / (y1 - y0) * (X(i+1) - X(i));
                    end
                    times(end+1) = tc;        %#ok<AGROW>
                    direction(end+1) = d;     %#ok<AGROW>
                end
            end
            keep = true(1, numel(times));
            if strcmp(dirn, 'rising')
                keep = direction > 0;
            elseif strcmp(dirn, 'falling')
                keep = direction < 0;
            end
            times = times(keep);
            direction = direction(keep);
            if nargout >= 2
                varargout = {times, direction};
                return;
            end
            c = struct();
            c.times = times;
            c.direction = direction;
            c.count = numel(times);
            c.periods = diff(times);
            varargout = {c};
        end

        function varargout = findPeaks(obj, varargin)
            %FINDPEAKS Local maxima/minima with prominence — toolbox-free (#329).
            %   p = tag.findPeaks()                     all local maxima
            %   p = tag.findPeaks('MinProminence', 2)   reject peaks < 2 above baseline
            %   p = tag.findPeaks('MinSeparation', 0.5) merge peaks closer than 0.5 (x-units)
            %   p = tag.findPeaks('Polarity', 'min')    troughs instead of peaks
            %   p = tag.findPeaks('Polarity', 'both')   peaks and troughs
            %   p = tag.findPeaks('Range', [t0 t1])     within a time window
            %   [t, v] = tag.findPeaks()                2-out: peak times + values
            %
            %   Output struct p (all row vectors, sorted by time):
            %     times       - peak/trough instants (tag X units)
            %     values      - Y at each extremum
            %     prominences - height above baseline (descend-to-higher-ground rule);
            %                   for troughs this is the positive depth below baseline
            %     polarity    - +1 for a maximum, -1 for a minimum
            %     count       - numel(times)
            %     intervals   - diff(times), for immediate cycle/frequency analysis
            %
            %   Detection: a maximum is a strict rise into, then strict fall out of,
            %   a sample (or a flat top plateau, which reports one peak). Prominence
            %   walks left/right to the nearest strictly-higher sample (or the series
            %   edge) and subtracts the higher of the two intervening valley minima.
            %   Minima are the maxima of -Y. MinSeparation greedily keeps the most
            %   prominent peak in each neighborhood.
            %
            %   NaN policy: NaNs split the series into segments; extrema are found
            %   within segments only (consistent with derivative/crossings). A
            %   discrete StateTag warns Tag:findPeaksOnDiscrete.
            %
            %   Toolbox-free — NOT the Signal Processing Toolbox findpeaks.
            %
            %   Errors:
            %     Tag:findPeaksBadOption - bad MinProminence/MinSeparation/Polarity
            %     Tag:unknownOption      - unrecognized option key
            %     Tag:notNumeric         - non-numeric (cellstr) series
            %
            %   See also crossings, derivative, movingStat, getXY.
            minProm  = 0;
            minSep   = 0;
            polarity = 'max';
            rangeVal = [];
            k = 1;
            while k <= numel(varargin)
                key = varargin{k};
                if k + 1 > numel(varargin)
                    error('Tag:danglingOption', 'findPeaks: option "%s" has no value.', char(string(key)));
                end
                val = varargin{k + 1};
                if strcmpi(key, 'MinProminence')
                    if ~(isnumeric(val) && isscalar(val) && val >= 0)
                        error('Tag:findPeaksBadOption', 'MinProminence must be a nonnegative scalar.');
                    end
                    minProm = val;
                elseif strcmpi(key, 'MinSeparation')
                    if ~(isnumeric(val) && isscalar(val) && val >= 0)
                        error('Tag:findPeaksBadOption', 'MinSeparation must be a nonnegative scalar.');
                    end
                    minSep = val;
                elseif strcmpi(key, 'Polarity')
                    if ~any(strcmpi(val, {'max', 'min', 'both'}))
                        error('Tag:findPeaksBadOption', 'Polarity must be max, min, or both.');
                    end
                    polarity = lower(val);
                elseif strcmpi(key, 'Range')
                    rangeVal = obj.parseRange_(val);
                else
                    error('Tag:unknownOption', 'findPeaks: unknown option "%s".', char(string(key)));
                end
                k = k + 2;
            end

            [X, Y] = obj.getSeries_(rangeVal);
            if islogical(Y), Y = double(Y); end
            if ~isnumeric(Y)
                error('Tag:notNumeric', ...
                    'findPeaks requires a numeric series; this tag''s Y is non-numeric.');
            end
            if obj.isDiscreteKind_()
                warning('Tag:findPeaksOnDiscrete', ...
                    'findPeaks() on a discrete (%s) tag treats step transitions as extrema.', ...
                    obj.getKind());
            end

            times = []; values = []; proms = []; polv = [];
            if any(strcmp(polarity, {'max', 'both'}))
                [tM, vM, pM] = Tag.detectExtrema_(X, Y, minProm, minSep);
                times = [times, tM]; values = [values, vM]; proms = [proms, pM];
                polv  = [polv, ones(1, numel(tM))];
            end
            if any(strcmp(polarity, {'min', 'both'}))
                [tN, vN, pN] = Tag.detectExtrema_(X, -Y, minProm, minSep);
                times = [times, tN]; values = [values, -vN]; proms = [proms, pN];
                polv  = [polv, -ones(1, numel(tN))];
            end
            [times, srt] = sort(times);
            values = values(srt); proms = proms(srt); polv = polv(srt);

            if nargout >= 2
                varargout = {times, values};
                return;
            end
            p = struct();
            p.times       = times;
            p.values      = values;
            p.prominences = proms;
            p.polarity    = polv;
            p.count       = numel(times);
            p.intervals   = diff(times);
            varargout = {p};
        end

        function s = exceedance(obj, level, varargin)
            %EXCEEDANCE Time-above/below-threshold analysis (#316).
            %   s = tag.exceedance(level) analyses time where Y > level.
            %   s = tag.exceedance(level, 'Direction', 'below') uses Y < level.
            %   s = tag.exceedance(level, 'Range', [t0 t1]) restricts the window.
            %
            %   Returns a struct:
            %     totalTime - total time the condition holds (tag X units)
            %     fraction  - totalTime / (X(end)-X(1)) over the window
            %     count     - number of separate excursions
            %     longest   - longest single excursion duration
            %     peak      - extreme value reached while exceeding
            %
            %   Continuous tags interpolate the exact crossing at each excursion
            %   boundary; discrete tags (state/monitor) use zero-order hold.
            %   NaN-bounded segments are treated as gaps.
            %
            %   Toolbox-free. See also crossings, getStats, getXY.
            if nargin < 2 || ~isnumeric(level) || ~isscalar(level)
                error('Tag:exceedanceBadLevel', 'level must be a numeric scalar.');
            end
            [rangeVal, dirn] = obj.parseDirectionRangeOpts_('above', ...
                {'above', 'below'}, varargin{:});
            [X, Y] = obj.getSeries_(rangeVal);
            above = strcmp(dirn, 'above');
            discrete = obj.isDiscreteKind_();

            s = struct('totalTime', 0, 'fraction', 0, 'count', 0, ...
                       'longest', 0, 'peak', NaN);
            n = numel(X);
            if n == 0
                s.peak = NaN;
                return;
            end
            span = X(end) - X(1);

            condFn = @(v) (above && v > level) || (~above && v < level);
            total = 0;
            count = 0;
            longest = 0;
            runDur = 0;
            inRun = false;
            peak = NaN;

            for i = 1:n-1
                x0 = X(i); x1 = X(i+1);
                y0 = Y(i); y1 = Y(i+1);
                dx = x1 - x0;
                if isnan(y0) || isnan(y1) || dx <= 0
                    if inRun, longest = max(longest, runDur); end
                    inRun = false; runDur = 0;
                    continue;
                end
                if discrete
                    % ZOH: y0 holds across the whole interval.
                    if condFn(y0)
                        total = total + dx;
                        if ~inRun, count = count + 1; inRun = true; runDur = 0; end
                        runDur = runDur + dx;
                        peak = obj.peakUpdate_(peak, y0, above);
                    else
                        if inRun, longest = max(longest, runDur); end
                        inRun = false; runDur = 0;
                    end
                else
                    c0 = condFn(y0);
                    c1 = condFn(y1);
                    % exceeding sub-interval [a, b] within [x0, x1]
                    a = []; b = [];
                    if c0 && c1
                        a = x0; b = x1;
                    elseif c0 && ~c1
                        a = x0; b = x0 + (level - y0) / (y1 - y0) * dx;
                    elseif ~c0 && c1
                        a = x0 + (level - y0) / (y1 - y0) * dx; b = x1;
                    end
                    if isempty(a)
                        if inRun, longest = max(longest, runDur); end
                        inRun = false; runDur = 0;
                    else
                        total = total + (b - a);
                        startsAtLeft = (a <= x0 + eps) && c0;
                        if inRun && startsAtLeft
                            runDur = runDur + (b - a);
                        else
                            if inRun, longest = max(longest, runDur); end
                            count = count + 1; runDur = (b - a); inRun = true;
                        end
                        if c0, peak = obj.peakUpdate_(peak, y0, above); end
                        if c1, peak = obj.peakUpdate_(peak, y1, above); end
                        if b < x1 - eps || ~c1
                            longest = max(longest, runDur);
                            inRun = false; runDur = 0;
                        end
                    end
                end
            end
            if inRun, longest = max(longest, runDur); end

            s.totalTime = total;
            if span > 0
                s.fraction = total / span;
            end
            s.count = count;
            s.longest = longest;
            s.peak = peak;
        end

        function v = valueAt(obj, t) %#ok<STOUT,INUSD>
            %VALUEAT Return scalar value at time t.  Subclass must override.
            error('Tag:notImplemented', 'Subclass must implement valueAt(t).');
        end

        function [tMin, tMax] = getTimeRange(obj) %#ok<STOUT,MANU>
            %GETTIMERANGE Return [tMin, tMax] time bounds.  Subclass must override.
            error('Tag:notImplemented', 'Subclass must implement getTimeRange().');
        end

        function k = getKind(obj) %#ok<STOUT,MANU>
            %GETKIND Return kind string.  Subclass must override.
            error('Tag:notImplemented', 'Subclass must implement getKind().');
        end

        function s = toStruct(obj) %#ok<STOUT,MANU>
            %TOSTRUCT Return serializable struct.  Subclass must override.
            error('Tag:notImplemented', 'Subclass must implement toStruct().');
        end

        % ---- Default serialization hook (NOT abstract) ----

        function resolveRefs(obj, registry) %#ok<INUSD>
            %RESOLVEREFS Pass-2 hook for two-phase deserialization.
            %   Default: no-op.  CompositeTag (Phase 1008) will override to
            %   wire up children by key.  Leaf tags (Sensor/State/Monitor)
            %   do not need references resolved.
        end

        function addManualEvent(obj, tStart, tEnd, label, message) %#ok<INUSD>
            %ADDMANUALEVENT Create a manual annotation event bound to this tag.
            %   tag.addManualEvent(tStart, tEnd, label, message) creates an Event
            %   with Category = 'manual_annotation' and TagKeys = {obj.Key},
            %   appends to the bound EventStore, and registers in EventBinding.
            %
            %   Errors: Tag:noEventStore if EventStore is not bound.
            if isempty(obj.EventStore)
                error('Tag:noEventStore', 'Bind an EventStore before adding events.');
            end
            ev = Event(tStart, tEnd, char(obj.Key), label, NaN, 'upper');
            ev.Category = 'manual_annotation';
            obj.EventStore.append(ev);
            ev.TagKeys = {char(obj.Key)};
            EventBinding.attach(ev.Id, char(obj.Key));
        end

        function events = eventsAttached(obj)
            %EVENTSATTACHED Query events bound to this tag via EventBinding.
            %   Returns Event array (possibly empty). This is a query, NOT a
            %   stored property -- no Event handles on Tag (Pitfall 4).
            if isempty(obj.EventStore)
                events = [];
                return;
            end
            events = obj.EventStore.getEventsForTag(char(obj.Key));
        end
    end

    methods (Static)
        function obj = fromStruct(s) %#ok<STOUT,INUSD>
            %FROMSTRUCT Reconstruct a Tag from a struct.  Subclass must override.
            error('Tag:notImplemented', ...
                'fromStruct must be provided by a concrete Tag subclass.');
        end

        function invalidateBatch_(tagSet)
            %INVALIDATEBATCH_ Coalesced invalidation across many tags (Phase 1028 plan 05).
            %
            %   Phase 1028 A1+A2 internal seam: walks the UNION of unique
            %   listeners across `tagSet` and calls `invalidate()` on each
            %   exactly once, rather than firing each tag's
            %   `notifyListeners_()` cascade independently. Same listeners
            %   notified — only WHEN (end-of-tick batch vs per-tag) changes.
            %
            %   tagSet : cell array of Tag handles. Empty -> no-op.
            %
            %   Semantics:
            %     - Public `tag.invalidate()` is unchanged; this is the
            %       INTERNAL seam used by `LiveTagPipeline.onTick_` at
            %       end-of-tick to amortize per-tag cascade overhead when
            %       many sensors have updated in the same tick.
            %     - Each unique listener has its `invalidate()` method
            %       called exactly once per batch (deduplicates duplicate
            %       handles, deduplicates listeners shared by multiple
            %       parents in `tagSet`).
            %     - Subclasses expose their internal listener cell via the
            %       Hidden `getListeners_()` accessor (SensorTag, StateTag,
            %       MonitorTag, CompositeTag, DerivedTag). The Tag base
            %       returns an empty cell (no listeners).
            %     - Idempotent: `invalidateBatch_(tagSet)` followed by any
            %       per-tag `tag.invalidate()` produces the same end state
            %       as the per-tag-only path (every dirty_ flag is true;
            %       cache_ is empty).
            %
            %   This method is `Static` because it operates over a
            %   heterogeneous set of Tag-subclass handles. Marked Hidden
            %   via the trailing-underscore name convention (D-10: not part
            %   of the public surface). Callers outside the SensorThreshold
            %   library MUST NOT depend on this method's existence or
            %   signature; the public observer interface remains
            %   `tag.invalidate()` and `tag.addListener()`.
            %
            %   See also Tag.invalidate, SensorTag.getListeners_,
            %   MonitorTag.getListeners_, CompositeTag.getListeners_,
            %   LiveTagPipeline.onTick_.

            if nargin < 1 || isempty(tagSet)
                return;
            end
            if ~iscell(tagSet)
                error('Tag:invalidBatchInput', ...
                    'invalidateBatch_ requires a cell array of Tag handles.');
            end

            % Collect unique listener handles across all tags in tagSet.
            % Dedup strategy:
            %   - On MATLAB: `handle == handle` is well-defined for
            %     user-defined handle classes (via the implicit `eq`
            %     method on `handle`).
            %   - On Octave: `eq` is NOT implemented for user-defined
            %     handle classes ("eq method not defined for ClassName").
            %     Fall back to deduping by the listener's `Key` property
            %     (every Tag subclass has a unique Key by construction).
            %
            % `isvalid` is MATLAB-only; on Octave it is not implemented for
            % user-defined handle classes, so the guard reduces to an
            % isempty + isa check (handle deletion is not part of the
            % SensorThreshold lifecycle — TagRegistry holds strong refs).
            isMatlab = (exist('OCTAVE_VERSION', 'builtin') == 0);
            uniqueListeners = {};
            seenKeys = {};
            for i = 1:numel(tagSet)
                t = tagSet{i};
                if isempty(t) || ~isa(t, 'Tag')
                    continue;
                end
                if isMatlab && ~isvalid(t)
                    continue;
                end
                ll = t.getListeners_();
                for j = 1:numel(ll)
                    lh = ll{j};
                    if isempty(lh)
                        continue;
                    end
                    if isMatlab && ~isvalid(lh)
                        continue;
                    end
                    isDup = false;
                    if isMatlab
                        for k = 1:numel(uniqueListeners)
                            if uniqueListeners{k} == lh
                                isDup = true;
                                break;
                            end
                        end
                    else
                        % Octave fallback: dedup by Key. All listeners
                        % inherit from Tag (which guarantees Key) so this
                        % is well-defined within the SensorThreshold model.
                        if isa(lh, 'Tag')
                            lhKey = lh.Key;
                            for k = 1:numel(seenKeys)
                                if strcmp(seenKeys{k}, lhKey)
                                    isDup = true;
                                    break;
                                end
                            end
                            if ~isDup
                                seenKeys{end+1} = lhKey;   %#ok<AGROW>
                            end
                        end
                    end
                    if ~isDup
                        uniqueListeners{end+1} = lh;   %#ok<AGROW>
                    end
                end
            end

            % Walk unique listeners exactly once.
            for k = 1:numel(uniqueListeners)
                lh = uniqueListeners{k};
                if isMatlab && ~isvalid(lh)
                    continue;
                end
                if ismethod(lh, 'invalidate')
                    lh.invalidate();
                end
            end
        end
    end

    methods (Access = private)
        % ---- Analysis-toolkit helpers (Phase 999.2) ----

        function tf = isDiscreteKind_(obj)
            %ISDISCRETEKIND_ True for state/monitor (ZOH-only) tags.
            tf = any(strcmp(obj.getKind(), {'state', 'monitor'}));
        end

        function [X, Y] = getSeries_(obj, rangeVal)
            %GETSERIES_ Column [X,Y] for the full series or a [t0 t1] window.
            %   The base getXYRange pads by one sample each side; clip strictly
            %   to [t0,t1] so a Range option means exactly the requested window.
            if nargin < 2 || isempty(rangeVal)
                [X, Y] = obj.getXY();
                X = X(:);
                Y = Y(:);
                return;
            end
            [X, Y] = obj.getXYRange(rangeVal(1), rangeVal(2));
            X = X(:);
            Y = Y(:);
            keep = X >= rangeVal(1) & X <= rangeVal(2);
            X = X(keep);
            Y = Y(keep);
        end

        function p = peakUpdate_(~, p, v, above)
            %PEAKUPDATE_ Running max (above) / min (below), NaN-seeded.
            if above
                if isnan(p) || v > p, p = v; end
            else
                if isnan(p) || v < p, p = v; end
            end
        end

        function rangeVal = parseRange_(~, val)
            %PARSERANGE_ Validate a [t0 t1] Range value.
            if ~(isnumeric(val) && numel(val) == 2)
                error('Tag:badRange', 'Range must be a 2-element [t0 t1] vector.');
            end
            rangeVal = [val(1), val(2)];
        end

        function [rangeVal, method] = parseMethodRangeOpts_(obj, defMethod, allowed, fnName, varargin)
            %PARSEMETHODRANGEOPTS_ Parse optional 'Method' / 'Range' name-values.
            rangeVal = [];
            method = defMethod;
            k = 1;
            while k <= numel(varargin)
                key = varargin{k};
                if k + 1 > numel(varargin)
                    error('Tag:danglingOption', '%s: option "%s" has no value.', fnName, char(string(key)));
                end
                val = varargin{k + 1};
                if strcmpi(key, 'Range')
                    rangeVal = obj.parseRange_(val);
                elseif strcmpi(key, 'Method') && ~isempty(allowed)
                    if ~any(strcmpi(val, allowed))
                        error('Tag:badMethod', '%s: Method must be one of: %s.', fnName, strjoin(allowed, ', '));
                    end
                    method = lower(val);
                else
                    error('Tag:unknownOption', '%s: unknown option "%s".', fnName, char(string(key)));
                end
                k = k + 2;
            end
        end

        function [rangeVal, dirn] = parseDirectionRangeOpts_(obj, defDir, allowed, varargin)
            %PARSEDIRECTIONRANGEOPTS_ Parse optional 'Direction' / 'Range' name-values.
            rangeVal = [];
            dirn = defDir;
            k = 1;
            while k <= numel(varargin)
                key = varargin{k};
                if k + 1 > numel(varargin)
                    error('Tag:danglingOption', 'Option "%s" has no value.', char(string(key)));
                end
                val = varargin{k + 1};
                if strcmpi(key, 'Range')
                    rangeVal = obj.parseRange_(val);
                elseif strcmpi(key, 'Direction')
                    if ~any(strcmpi(val, allowed))
                        error('Tag:badDirection', 'Direction must be one of: %s.', strjoin(allowed, ', '));
                    end
                    dirn = lower(val);
                else
                    error('Tag:unknownOption', 'unknown option "%s".', char(string(key)));
                end
                k = k + 2;
            end
        end

        function [rangeVal, method, maxGap] = parseResampleOpts_(obj, varargin)
            %PARSERESAMPLEOPTS_ Parse 'Range' / 'Method' / 'MaxGap' for resampleUniform.
            rangeVal = [];
            method = '';
            maxGap = Inf;
            k = 1;
            while k <= numel(varargin)
                key = varargin{k};
                if k + 1 > numel(varargin)
                    error('Tag:danglingOption', 'resampleUniform: option "%s" has no value.', char(string(key)));
                end
                val = varargin{k + 1};
                if strcmpi(key, 'Range')
                    rangeVal = obj.parseRange_(val);
                elseif strcmpi(key, 'Method')
                    if ~any(strcmpi(val, {'linear', 'previous', 'nearest', 'next', 'spline', 'pchip'}))
                        error('Tag:badMethod', 'resampleUniform: unsupported Method "%s".', char(string(val)));
                    end
                    method = lower(val);
                elseif strcmpi(key, 'MaxGap')
                    if ~(isnumeric(val) && isscalar(val) && val > 0)
                        error('Tag:badMaxGap', 'MaxGap must be a positive scalar.');
                    end
                    maxGap = val;
                else
                    error('Tag:unknownOption', 'resampleUniform: unknown option "%s".', char(string(key)));
                end
                k = k + 2;
            end
        end
    end

    methods (Static, Access = private)

        function [times, values, proms] = detectExtrema_(X, Y, minProm, minSep)
            %DETECTEXTREMA_ Local maxima of Y over X — toolbox-free (#329 helper).
            %   NaNs split (X,Y) into maximal segments; within each segment a
            %   maximum is a strict rise into, then strict fall out of, a sample
            %   or flat-top plateau (one peak per plateau, reported at its
            %   representative sample). Prominence = value - max(leftValleyMin,
            %   rightValleyMin), where each side descends to the nearest strictly
            %   higher sample or the series edge. Then applies MinProminence and a
            %   greedy MinSeparation merge (keep the most prominent). Returns row
            %   vectors. Call with (X, -Y, ...) to obtain minima.
            times = []; values = []; proms = [];
            n = numel(Y);
            valid = ~isnan(Y);
            k = 1;
            while k <= n
                if ~valid(k)
                    k = k + 1;
                    continue;
                end
                j = k;
                while j < n && valid(j + 1)
                    j = j + 1;
                end
                Xs = X(k:j);
                Ys = Y(k:j);
                m = numel(Ys);
                i = 2;
                while i <= m - 1
                    if Ys(i) > Ys(i - 1)
                        jj = i;
                        while jj < m && Ys(jj + 1) == Ys(i)
                            jj = jj + 1;
                        end
                        if jj < m && Ys(jj + 1) < Ys(i)
                            rep = i + floor((jj - i) / 2);
                            vp  = Ys(i);
                            L = rep;
                            while L > 1 && Ys(L - 1) <= vp
                                L = L - 1;
                            end
                            R = rep;
                            while R < m && Ys(R + 1) <= vp
                                R = R + 1;
                            end
                            base = max(min(Ys(L:rep)), min(Ys(rep:R)));
                            times(end + 1)  = Xs(rep);   %#ok<AGROW>
                            values(end + 1) = vp;        %#ok<AGROW>
                            proms(end + 1)  = vp - base; %#ok<AGROW>
                            i = jj + 1;
                            continue;
                        else
                            i = jj + 1;
                            continue;
                        end
                    end
                    i = i + 1;
                end
                k = j + 1;
            end

            if minProm > 0 && ~isempty(proms)
                keep = proms >= minProm;
                times = times(keep); values = values(keep); proms = proms(keep);
            end

            if minSep > 0 && numel(times) > 1
                [~, order] = sort(proms, 'descend');
                keptMask  = false(1, numel(times));
                keptTimes = [];
                for idx = order
                    if isempty(keptTimes) || all(abs(keptTimes - times(idx)) >= minSep)
                        keptMask(idx)      = true;
                        keptTimes(end + 1) = times(idx); %#ok<AGROW>
                    end
                end
                times = times(keptMask); values = values(keptMask); proms = proms(keptMask);
                [times, srt] = sort(times);
                values = values(srt); proms = proms(srt);
            end
        end

    end

    methods (Hidden)
        function ll = getListeners_(obj) %#ok<MANU>
            %GETLISTENERS_ Default accessor returning empty cell (Phase 1028 plan 05).
            %   Subclasses that maintain a listener cell (SensorTag,
            %   StateTag, MonitorTag, CompositeTag, DerivedTag) override
            %   this to expose their private `listeners_` property for
            %   `Tag.invalidateBatch_` to walk. The Tag base returns {} —
            %   abstract Tag has no listeners.
            %
            %   Hidden (D-10: internal-only seam). Mirrors the convention
            %   used by `LiveTagPipeline.setWriteFnForTesting_` and
            %   `setCacheActiveForTesting_`.
            ll = {};
        end
    end
end
