function bench_violation_cull()
%BENCH_VIOLATION_CULL Isolated microbenchmark of the threshold-marker hot path.
%
%   violation_cull is the fused detect-and-cull kernel behind threshold
%   violation markers. On every render and every zoom/pan, FastSense calls it
%   once per (threshold x line) for each threshold with ShowViolations: it
%   finds the points that cross the threshold and culls them to one marker per
%   pixel column in a single pass (FastSense.m:1368/1371, 4468/4471). It is
%   MEX-accelerated (violation_cull_mex) with a pure-MATLAB fallback, and
%   handles both constant thresholds and time-varying (step-function)
%   thresholds — the latter a recent feature (per-widget time-varying spec).
%   No benchmark exercises it directly; only bench_event_marker_regression
%   touches a neighbouring render path (getEventsForTag).
%
%   This benchmark times BOTH threshold branches as pure computation (no
%   figure, no rendering): a constant threshold (thX = 0 sentinel) and a
%   multi-knot step-function threshold, across an input-size sweep, reporting
%   per-call latency and throughput (input Mpts/s).
%
%   In production the input is the line's DISPLAYED (downsampled) data —
%   typically a few thousand points (~2 x pixel width). The lower sizes here
%   bracket that realistic range; the larger sizes exist to verify the kernel
%   scales linearly with input length (the regression we actually guard).
%
%   Gate (machine-independent): detection + culling is an O(N) sweep, so the
%   empirical log-log scaling exponent over the large-N portion must stay
%   sub-quadratic (<= 1.3). Super-linear creep trips the gate regardless of
%   absolute host speed.
%
%   Warmup dissolves JIT first-call overhead; small sizes are timed over an
%   inner repeat loop so sub-millisecond calls stay measurable; median of
%   nRuns defuses one-off spikes.
%
%   Run:
%     octave --no-gui --eval "install(); bench_violation_cull();"
%
%   Exits 0 with "PASS: ..." on success; raises assert() (non-zero exit) if
%   either branch's scaling exponent exceeds the gate.
%
%   See also violation_cull, compute_violations, compute_violations_dynamic,
%            downsample_violations, bench_downsample_kernels.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    install();
    % violation_cull (and violation_cull_mex) live in FastSense's private/
    % folder, which cannot be put on the path. The current working folder is
    % always searched regardless of its name, so cd-ing into private makes the
    % wrapper directly callable in both MATLAB and Octave. onCleanup restores
    % the original folder even if an assert below trips.
    privDir = fullfile(here, '..', 'libs', 'FastSense', 'private');
    origDir = pwd;
    restoreDir = onCleanup(@() cd(origDir)); %#ok<NASGU>
    cd(privDir);

    sizes  = [1e3, 1e4, 1e5, 1e6];
    labels = {'1K', '10K', '100K', '1M'};

    nRuns      = 5;     % median of nRuns per (branch, size)
    targetWork = 2e6;   % inner-loop repeats sized to process ~this many pts

    % Deterministic seed — works in both MATLAB and Octave
    if exist('rng', 'file') == 2
        rng(0);
    else
        rand('state', 0); randn('state', 0); %#ok<RAND>
    end

    useMex = (exist('violation_cull_mex', 'file') == 3);

    % Threshold configuration. Signal oscillates ~[-1.5, 1.5]; an upper
    % threshold at 0.5 yields a healthy fraction of violations so the culling
    % stage does real work. The step-function branch uses 5 knots across the
    % X range to exercise the piecewise-constant interpolation path.
    direction  = 'upper';
    constLevel = 0.5;
    PixelWidth = 1000;                       % nominal axis width in pixels
    stepKnotsN = 5;

    nSizes = numel(sizes);
    tConst = zeros(1, nSizes);   % per-call seconds, constant threshold
    tStep  = zeros(1, nSizes);   % per-call seconds, step-function threshold

    fprintf('\n=== violation_cull threshold-marker microbenchmark (pure computation) ===\n');
    fprintf('  violation_cull_mex: %s\n', tf_(useMex));
    fprintf('  direction=%s  constLevel=%.2f  stepKnots=%d  pixelWidth=%d\n', ...
        direction, constLevel, stepKnotsN, PixelWidth);
    fprintf('  (production input = displayed/downsampled data, ~few thousand pts)\n');
    fprintf('  %s\n', repmat('-', 1, 74));
    fprintf('  %-6s | %-13s %-12s | %-13s %-12s\n', ...
        'N', 'const (ms)', 'const Mpts/s', 'step (ms)', 'step Mpts/s');
    fprintf('  %s\n', repmat('-', 1, 74));

    for c = 1:nSizes
        n = sizes(c);
        x = linspace(0, 100, n);                       % sorted ascending
        y = sin(x * 2 * pi / 10) + 0.5 * randn(1, n);  % ~[-1.5, 1.5]

        pw   = (x(end) - x(1)) / PixelWidth;           % X units per pixel
        xmin = x(1);

        % Step-function threshold: knots across the X range, varying levels
        thX = linspace(x(1), x(end), stepKnotsN);
        thY = constLevel + 0.2 * sin(1:stepKnotsN);

        nInner = max(1, ceil(targetWork / n));

        % Constant threshold uses the thX = 0 sentinel (matches FastSense.m)
        tConst(c) = timeCall_(@() violation_cull(x, y, 0, constLevel, direction, pw, xmin), ...
            nInner, nRuns);
        tStep(c)  = timeCall_(@() violation_cull(x, y, thX, thY, direction, pw, xmin), ...
            nInner, nRuns);

        fprintf('  %-6s | %11.4f   %10.1f   | %11.4f   %10.1f\n', ...
            labels{c}, ...
            tConst(c) * 1000, n / tConst(c) / 1e6, ...
            tStep(c)  * 1000, n / tStep(c)  / 1e6);

        clear x y;
    end
    fprintf('  %s\n', repmat('-', 1, 74));

    % ---- Scaling gate: fit exponent over the large-N portion (>= 1e4) ----
    fitMask = sizes >= 1e4;
    slopeConst = scalingExponent_(sizes(fitMask), tConst(fitMask));
    slopeStep  = scalingExponent_(sizes(fitMask), tStep(fitMask));

    gate = 1.3;
    fprintf('  Scaling exponent (large-N fit, ideal ~1.0):\n');
    fprintf('    constant : %.2f   (gate: <= %.1f)\n', slopeConst, gate);
    fprintf('    step     : %.2f   (gate: <= %.1f)\n', slopeStep, gate);
    fprintf('  %s\n', repmat('-', 1, 74));

    assert(slopeConst <= gate, ...
        sprintf(['FAIL: violation_cull (constant) scaling exponent %.2f exceeds %.1f — ' ...
                 'super-linear creep in the threshold-marker path.'], slopeConst, gate));
    assert(slopeStep <= gate, ...
        sprintf(['FAIL: violation_cull (step) scaling exponent %.2f exceeds %.1f — ' ...
                 'super-linear creep in the threshold-marker path.'], slopeStep, gate));
    fprintf('  PASS: both branches scale near-linearly (gate: exponent <= %.1f).\n\n', gate);
end

function t = timeCall_(fn, nInner, nRuns)
    %TIMECALL_ Median-of-nRuns per-call time of fn, averaged over nInner reps.
    %   Warms up first to dissolve JIT/first-call overhead, then times nInner
    %   back-to-back calls per run and returns the median run divided by
    %   nInner — a robust per-call estimate that keeps sub-ms calls measurable.
    fn(); fn(); % warmup
    runTimes = zeros(1, nRuns);
    for r = 1:nRuns
        t0 = tic;
        for i = 1:nInner
            fn();
        end
        runTimes(r) = toc(t0);
    end
    t = median(runTimes) / nInner;
end

function slope = scalingExponent_(ns, times)
    %SCALINGEXPONENT_ Log-log slope of per-call time vs N (the O(N) exponent).
    %   slope ~ 1.0 indicates linear scaling; > 1 indicates super-linear creep.
    times = max(times, eps);
    p = polyfit(log10(ns(:)), log10(times(:)), 1);
    slope = p(1);
end

function s = tf_(b)
    if b
        s = 'active';
    else
        s = 'fallback (pure MATLAB)';
    end
end
