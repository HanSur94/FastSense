function bench_binary_search()
%BENCH_BINARY_SEARCH Isolated microbenchmark of the range-lookup hot path.
%
%   binary_search is the gateway to every range query in FastSense. On each
%   zoom/pan and render it locates the visible index window in a raw, sorted,
%   full-length X array — FastSense.m (resolve/zoom window, timestamp lookup),
%   FastSenseToolbar.m (click-to-point, range select) and SensorTag.m (tag
%   range resolve) all call it, against arrays up to tens of millions of
%   points. It is MEX-accelerated (binary_search_mex) with a pure-MATLAB
%   fallback, yet has no benchmark anywhere.
%
%   The cost of any single call is tiny (O(log N) comparisons), so absolute
%   throughput is not the point. The point is the GATE: binary search must
%   stay logarithmic. If the MEX silently stops loading, or a change turns
%   the search into a linear scan, large-data zoom/pan responsiveness
%   collapses — and nothing else in the suite would catch it. This benchmark
%   times many scalar lookups (both 'left' and 'right') across a wide size
%   sweep and asserts the per-query time scales sub-linearly with N.
%
%   Per-query time grows only weakly with N (a mix of ~log2(N) comparisons
%   and cache-miss penalty as the array spills out of cache), so the
%   empirical log-log exponent stays well below the linear-scan exponent of
%   ~1.0. The gate (exponent <= 0.6) cleanly separates the two regimes and
%   is machine-independent.
%
%   Warmup dissolves first-call/JIT overhead; each measurement loops over a
%   fixed query batch so per-call dispatch stays representative of production
%   (binary_search is always called scalar); median of nRuns defuses spikes.
%
%   Run:
%     octave --no-gui --eval "install(); bench_binary_search();"
%
%   Exits 0 with "PASS: ..." on success; raises assert() (non-zero exit) if
%   either direction's per-query scaling exponent exceeds the gate.
%
%   See also binary_search, binary_search_mex, bench_downsample_kernels.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    install();
    % binary_search lives in libs/FastSense/ (not a private/ folder), so
    % install() puts it on the path and it is directly callable here.

    sizes  = [1e4, 1e5, 1e6, 1e7, 5e7];
    labels = {'10K', '100K', '1M', '10M', '50M'};

    nQueries = 20000;   % scalar lookups timed per (size, direction, run)
    nRuns    = 5;       % median of nRuns

    % Deterministic seed — works in both MATLAB and Octave
    if exist('rng', 'file') == 2
        rng(0);
    else
        rand('state', 0); %#ok<RAND>
    end

    % binary_search_mex lives in libs/FastSense/private. It is visible to
    % binary_search.m (its parent folder) and is what the wrapper actually
    % dispatches to — but it is NOT visible from this benchmark's context,
    % so a plain exist('binary_search_mex','file') here would misreport as a
    % fallback. Detect the built binary for THIS platform on disk instead.
    mexPath = fullfile(here, '..', 'libs', 'FastSense', 'private', ...
        ['binary_search_mex.' mexext]);
    useMex = (exist(mexPath, 'file') ~= 0);

    nSizes = numel(sizes);
    tLeft  = zeros(1, nSizes);   % per-query seconds, 'left'
    tRight = zeros(1, nSizes);   % per-query seconds, 'right'

    fprintf('\n=== binary_search range-lookup microbenchmark ===\n');
    fprintf('  binary_search_mex: %s\n', tf_(useMex));
    fprintf('  %d scalar lookups per measurement, median of %d runs\n', nQueries, nRuns);
    fprintf('  %s\n', repmat('-', 1, 74));
    fprintf('  %-6s | %-14s %-12s | %-14s %-12s\n', ...
        'N', 'left (us/q)', 'left Mq/s', 'right (us/q)', 'right Mq/s');
    fprintf('  %s\n', repmat('-', 1, 74));

    for c = 1:nSizes
        n = sizes(c);
        x = linspace(0, 100, n);          % sorted ascending (binary_search contract)
        vals = 100 * rand(1, nQueries);   % query targets within range (not timed)

        tLeft(c)  = timeSearch_(x, vals, 'left',  nRuns);
        tRight(c) = timeSearch_(x, vals, 'right', nRuns);

        fprintf('  %-6s | %12.4f   %10.2f   | %12.4f   %10.2f\n', ...
            labels{c}, ...
            tLeft(c)  * 1e6, 1 / tLeft(c)  / 1e6, ...
            tRight(c) * 1e6, 1 / tRight(c) / 1e6);

        clear x vals;
    end
    fprintf('  %s\n', repmat('-', 1, 74));

    % ---- Scaling gate: per-query time must stay sub-linear in N ----
    % Fit over N >= 1e5 (small N is dominated by fixed call/dispatch overhead
    % and would flatten the slope). O(log N) + cache effects keep the exponent
    % well under 1.0; a linear-scan regression drives it toward 1.0.
    fitMask = sizes >= 1e5;
    slopeLeft  = scalingExponent_(sizes(fitMask), tLeft(fitMask));
    slopeRight = scalingExponent_(sizes(fitMask), tRight(fitMask));
    growthLeft = tLeft(end) / max(tLeft(1), eps);

    gate = 0.6;
    fprintf('  Per-query scaling exponent (large-N fit, linear-scan ~1.0):\n');
    fprintf('    left  : %.2f   (gate: <= %.1f)\n', slopeLeft, gate);
    fprintf('    right : %.2f   (gate: <= %.1f)\n', slopeRight, gate);
    fprintf('    per-query growth 10K->50M (left): %.1fx\n', growthLeft);
    fprintf('  %s\n', repmat('-', 1, 74));

    assert(slopeLeft <= gate, ...
        sprintf(['FAIL: binary_search ''left'' per-query exponent %.2f exceeds %.1f — ' ...
                 'search is no longer logarithmic (linear-scan regression?).'], slopeLeft, gate));
    assert(slopeRight <= gate, ...
        sprintf(['FAIL: binary_search ''right'' per-query exponent %.2f exceeds %.1f — ' ...
                 'search is no longer logarithmic (linear-scan regression?).'], slopeRight, gate));
    fprintf('  PASS: lookups stay sub-linear (gate: exponent <= %.1f).\n\n', gate);
end

function t = timeSearch_(x, vals, dir, nRuns)
    %TIMESEARCH_ Median-of-nRuns per-query time of binary_search over a batch.
    %   Warms up first, then times nQueries back-to-back scalar lookups per
    %   run and returns the median run divided by nQueries.
    nq = numel(vals);
    binary_search(x, vals(1),   dir); %#ok<*NASGU> % warmup
    binary_search(x, vals(end), dir);
    runTimes = zeros(1, nRuns);
    for r = 1:nRuns
        t0 = tic;
        for q = 1:nq
            binary_search(x, vals(q), dir);
        end
        runTimes(r) = toc(t0);
    end
    t = median(runTimes) / nq;
end

function slope = scalingExponent_(ns, times)
    %SCALINGEXPONENT_ Log-log slope of per-query time vs N (the growth exponent).
    %   slope -> 0 indicates flat/logarithmic scaling; -> 1 indicates linear.
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
