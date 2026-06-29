function bench_downsample_kernels()
%BENCH_DOWNSAMPLE_KERNELS Isolated microbenchmark of the downsampling hot path.
%
%   Downsampling is the single most performance-critical computation in
%   FastSense: minmax_downsample / lttb_downsample run on every render and
%   on every zoom/pan, over the full dataset (up to tens of millions of
%   points). They are the reason the library exists. Yet the only existing
%   coverage is a single minmax_downsample(x, y, 1000) call buried inside
%   the render-heavy benchmark.m — mixed with figure creation and drawnow,
%   never isolated, and LTTB is not benchmarked anywhere at all.
%
%   This benchmark times BOTH downsamplers as PURE computation (no figure,
%   no rendering) across a size sweep, reporting per-call latency and
%   throughput (Mpts/s). With the MEX kernels compiled it exercises
%   minmax_core_mex / lttb_core_mex (the production path); without them it
%   transparently times the pure-MATLAB fallbacks (a flag reports which).
%
%   Both methods are driven to the same output budget (~2000 points, a
%   realistic display width) so their throughput is directly comparable.
%
%   Gate (machine-independent): downsampling is an O(N) sweep, so per-call
%   time must scale near-linearly with N. The benchmark fits the empirical
%   scaling exponent over the large-N portion of the sweep (where O(N)
%   dominates measurement noise) and asserts it stays sub-linear-ish
%   (exponent <= 1.3). Super-linear creep — the classic downsampling
%   regression — trips this gate regardless of absolute machine speed.
%
%   Warmup passes dissolve JIT first-call overhead; small sizes are timed
%   over an inner repeat loop so sub-millisecond calls stay measurable;
%   median of nRuns defuses one-off spikes.
%
%   Run:
%     octave --no-gui --eval "install(); bench_downsample_kernels();"
%
%   Exits 0 with "PASS: ..." on success; raises assert() (non-zero exit) if
%   either kernel's empirical scaling exponent exceeds the gate.
%
%   See also minmax_downsample, lttb_downsample, benchmark, benchmark_zoom.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    install();
    % minmax_downsample / lttb_downsample live in FastSense's private/ folder.
    % A private/ folder cannot be put on the path (Octave permits it but
    % MATLAB rejects it), so the wrappers are not callable from here. The
    % current working folder is ALWAYS searched regardless of its name,
    % however, so cd-ing into the private folder makes them directly callable
    % in both MATLAB and Octave — no path manipulation, no touching libs/.
    % onCleanup restores the original folder even if an assert below trips.
    privDir = fullfile(here, '..', 'libs', 'FastSense', 'private');
    origDir = pwd;
    restoreDir = onCleanup(@() cd(origDir)); %#ok<NASGU>
    cd(privDir);

    sizes  = [1e4, 1e5, 1e6, 5e6, 1e7];
    labels = {'10K', '100K', '1M', '5M', '10M'};

    % Equal output budget so the two methods are directly comparable:
    %   minmax emits ~2*numBuckets points -> numBuckets = 1000 -> ~2000 pts
    %   lttb   emits numOut points          -> numOut     = 2000 -> 2000 pts
    minmaxBuckets = 1000;
    lttbOut       = 2000;

    nRuns       = 5;     % median of nRuns per (method, size)
    targetWork  = 2e6;   % inner-loop repeats sized to process ~this many pts

    % Deterministic seed — works in both MATLAB and Octave
    if exist('rng', 'file') == 2
        rng(0);
    else
        rand('state', 0); randn('state', 0); %#ok<RAND>
    end

    mexMinmax = (exist('minmax_core_mex', 'file') == 3);
    mexLttb   = (exist('lttb_core_mex',   'file') == 3);

    nSizes = numel(sizes);
    tMinmax = zeros(1, nSizes);   % per-call seconds
    tLttb   = zeros(1, nSizes);

    fprintf('\n=== Downsampling kernel microbenchmark (pure computation) ===\n');
    fprintf('  MinMax MEX: %s   |   LTTB MEX: %s\n', tf_(mexMinmax), tf_(mexLttb));
    fprintf('  Output budget: minmax numBuckets=%d (~%d pts)  lttb numOut=%d\n', ...
        minmaxBuckets, 2 * minmaxBuckets, lttbOut);
    fprintf('  %s\n', repmat('-', 1, 74));
    fprintf('  %-6s | %-13s %-12s | %-13s %-12s\n', ...
        'N', 'MinMax (ms)', 'MinMax Mpts/s', 'LTTB (ms)', 'LTTB Mpts/s');
    fprintf('  %s\n', repmat('-', 1, 74));

    for c = 1:nSizes
        n = sizes(c);
        x = linspace(0, 100, n);
        y = sin(x * 2 * pi / 10) + 0.5 * randn(1, n);

        nInner = max(1, ceil(targetWork / n));

        tMinmax(c) = timeCall_(@() minmax_downsample(x, y, minmaxBuckets), nInner, nRuns);
        tLttb(c)   = timeCall_(@() lttb_downsample(x, y, lttbOut),         nInner, nRuns);

        fprintf('  %-6s | %11.3f   %10.1f   | %11.3f   %10.1f\n', ...
            labels{c}, ...
            tMinmax(c) * 1000, n / tMinmax(c) / 1e6, ...
            tLttb(c)   * 1000, n / tLttb(c)   / 1e6);

        clear x y;
    end
    fprintf('  %s\n', repmat('-', 1, 74));

    % ---- Scaling gate: fit exponent over the large-N portion (>= 1e5) ----
    % Small N is dominated by fixed dispatch/allocation overhead and would
    % bias the slope; restrict the fit to where the O(N) sweep dominates.
    fitMask = sizes >= 1e5;
    slopeMinmax = scalingExponent_(sizes(fitMask), tMinmax(fitMask));
    slopeLttb   = scalingExponent_(sizes(fitMask), tLttb(fitMask));

    gate = 1.3;
    fprintf('  Scaling exponent (large-N fit, ideal ~1.0):\n');
    fprintf('    MinMax : %.2f   (gate: <= %.1f)\n', slopeMinmax, gate);
    fprintf('    LTTB   : %.2f   (gate: <= %.1f)\n', slopeLttb, gate);
    fprintf('  %s\n', repmat('-', 1, 74));

    assert(slopeMinmax <= gate, ...
        sprintf(['FAIL: minmax_downsample scaling exponent %.2f exceeds %.1f — ' ...
                 'super-linear creep in the downsampling hot path.'], slopeMinmax, gate));
    assert(slopeLttb <= gate, ...
        sprintf(['FAIL: lttb_downsample scaling exponent %.2f exceeds %.1f — ' ...
                 'super-linear creep in the downsampling hot path.'], slopeLttb, gate));
    fprintf('  PASS: both kernels scale near-linearly (gate: exponent <= %.1f).\n\n', gate);
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
    %   Guards against a degenerate fit when timings are too small to resolve.
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
