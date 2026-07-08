function bench_datastore_range()
%BENCH_DATASTORE_RANGE Isolated gate for the disk-backed range-query hot path.
%
%   FastSenseDataStore is FastSense's out-of-core backend: datasets too large
%   for RAM live in a chunked SQLite store, and every zoom/pan on a
%   disk-backed line issues a range query (getRange) to pull just the visible
%   window before downsampling. This is the large-data story's hot read path
%   (resolve_disk_mex + chunked SQLite reads, WAL mode for live use).
%
%   Today the store has only EXPLORATORY coverage: benchmark_datastore.m
%   (a .mat-vs-SQLite size sweep, and Linux-only — it shells out to `free`)
%   and profile_datastore.m (a MATLAB-profiler bottleneck script). Neither is
%   a focused, deterministic regression GATE. This benchmark fills that gap.
%
%   The key property a chunked, indexed store must preserve: for a FIXED-size
%   view window, query latency should stay roughly CONSTANT as the total
%   dataset grows — the store seeks to the window (≈ O(log N) index/chunk
%   lookup) and reads only the window's points, never the whole dataset. To
%   hold the returned point count constant across sizes, the window width is
%   scaled inversely with dataset density (each query returns ~targetPts
%   points regardless of N).
%
%   Gate (machine-independent): the log-log exponent of per-query time vs
%   TOTAL dataset size must stay near zero (<= 0.5). A full-scan regression —
%   where query cost grows with the whole dataset rather than the window —
%   drives the exponent toward 1.0 and trips the gate, regardless of host
%   speed or which backend (SQLite vs binary fallback) is active.
%
%   Store creation time (inherently O(N) chunked write) is reported for
%   context but NOT gated.
%
%   Run:
%     octave --no-gui --eval "install(); bench_datastore_range();"
%
%   Exits 0 with "PASS: ..." on success; raises assert() (non-zero exit) if
%   range-query latency scales with total dataset size.
%
%   See also FastSenseDataStore, benchmark_datastore, profile_datastore,
%            bench_binary_search.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    install();

    sizes  = [1e5, 5e5, 1e6, 5e6];
    labels = {'100K', '500K', '1M', '5M'};

    targetPts = 10000;   % each range query returns ~this many points
    nQueries  = 30;      % random view windows per measurement
    nRuns     = 3;       % median of nRuns

    xSpan = 1000;        % data spans X in [0, xSpan]

    % Deterministic seed — works in both MATLAB and Octave
    if exist('rng', 'file') == 2
        rng(0);
    else
        rand('state', 0); randn('state', 0); %#ok<RAND>
    end

    hasSqlite = (exist('mksqlite', 'file') == 3);

    % Warmup: absorb one-time SQLite/MEX/file-creation init on a throwaway
    % store so the first sized store below isn't penalised (which would bias
    % the scaling fit negative and inflate its create time).
    wx = linspace(0, xSpan, 1000);
    wds = FastSenseDataStore(wx, sin(wx / 50));
    wds.getRange(0, xSpan / 10);
    wds.cleanup();
    clear wx wds;

    nSizes  = numel(sizes);
    tQuery  = zeros(1, nSizes);   % per-query seconds
    tCreate = zeros(1, nSizes);   % store creation seconds
    avgPts  = zeros(1, nSizes);   % avg points returned per query

    fprintf('\n=== FastSenseDataStore range-query microbenchmark ===\n');
    fprintf('  backend: %s\n', backend_(hasSqlite));
    fprintf('  fixed view window ~%d pts, %d queries x median of %d runs\n', ...
        targetPts, nQueries, nRuns);
    fprintf('  %s\n', repmat('-', 1, 76));
    fprintf('  %-6s | %-12s | %-14s %-12s | %-10s\n', ...
        'N', 'create (s)', 'query (ms)', 'queries/s', 'pts/query');
    fprintf('  %s\n', repmat('-', 1, 76));

    for c = 1:nSizes
        n = sizes(c);
        x = linspace(0, xSpan, n);
        y = sin(x / 50) + 0.1 * randn(1, n);

        % Window width that returns ~targetPts points at this density
        w = max(xSpan * targetPts / n, eps);
        centers = (w / 2) + (xSpan - w) * rand(1, nQueries);

        t0 = tic;
        ds = FastSenseDataStore(x, y);
        tCreate(c) = toc(t0);
        clear x y;

        try
            % Warmup + measure average returned point count
            [wx, ~] = ds.getRange(centers(1) - w/2, centers(1) + w/2);
            ds.getRange(centers(2) - w/2, centers(2) + w/2);
            avgPts(c) = numel(wx);

            runTimes = zeros(1, nRuns);
            for r = 1:nRuns
                tq = tic;
                for q = 1:nQueries
                    ds.getRange(centers(q) - w/2, centers(q) + w/2);
                end
                runTimes(r) = toc(tq);
            end
            tQuery(c) = median(runTimes) / nQueries;
        catch err
            ds.cleanup();   % never leak the temp store on failure
            rethrow(err);
        end
        ds.cleanup();       % release SQLite handle + temp file before next size

        fprintf('  %-6s | %10.3f   | %12.4f   %10.1f   | %9.0f\n', ...
            labels{c}, tCreate(c), tQuery(c) * 1000, 1 / tQuery(c), avgPts(c));
    end
    fprintf('  %s\n', repmat('-', 1, 76));

    % ---- Gate: fixed-window query time must NOT scale with total dataset ----
    slope = scalingExponent_(sizes, tQuery);
    growth = tQuery(end) / max(tQuery(1), eps);

    gate = 0.5;
    fprintf('  Query-time vs total-N exponent (indexed read ~0, full scan ~1.0):\n');
    fprintf('    exponent : %.2f   (gate: <= %.1f)\n', slope, gate);
    fprintf('    100K->5M query-time growth: %.2fx (50x more data)\n', growth);
    fprintf('  %s\n', repmat('-', 1, 76));

    assert(slope <= gate, ...
        sprintf(['FAIL: getRange per-query time scales with total dataset size ' ...
                 '(exponent %.2f > %.1f) — fixed-window queries should be ~constant; ' ...
                 'full-scan / unindexed-read regression suspected.'], slope, gate));
    fprintf('  PASS: fixed-window range queries stay ~constant vs dataset size (exponent <= %.1f).\n\n', gate);
end

function slope = scalingExponent_(ns, times)
    %SCALINGEXPONENT_ Log-log slope of per-query time vs total dataset size.
    %   slope -> 0 indicates the indexed store reads only the window;
    %   slope -> 1 indicates cost grows with the whole dataset (full scan).
    times = max(times, eps);
    p = polyfit(log10(ns(:)), log10(times(:)), 1);
    slope = p(1);
end

function s = backend_(hasSqlite)
    if hasSqlite
        s = 'mksqlite/SQLite (chunked)';
    else
        s = 'binary fallback (mksqlite absent)';
    end
end
