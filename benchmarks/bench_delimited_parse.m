function bench_delimited_parse()
%BENCH_DELIMITED_PARSE Isolated microbenchmark of the CSV-ingestion hot path.
%
%   The Tag pipeline ingests raw sensor data from delimited text (CSV/TSV)
%   files. dispatchDelimitedParse_ is the parse entry point: it prefers the
%   compiled delimited_parse_mex kernel and falls back to the pure
%   MATLAB/Octave textscan-based readRawDelimited_ when the binary is absent.
%   Per the in-repo note (Phase 1028), the MEX is ~10-40x faster than the
%   fallback at harness scale — yet BatchTagPipeline / delimited ingestion has
%   no benchmark at all. This is the front door for getting data into
%   FastSense, and slow parsing directly inflates load time for large logs.
%
%   This benchmark generates deterministic multi-column CSV files of growing
%   row count, times dispatchDelimitedParse_ on each (the whichever-is-active
%   path — MEX or fallback, reported), and reports parse latency plus row and
%   byte throughput. File generation is done once per size and is NOT timed.
%
%   Gate (machine-independent): delimited parsing is an O(rows) sweep, so the
%   empirical log-log scaling exponent over the large-N portion must stay
%   sub-quadratic (<= 1.3). Super-linear creep — e.g. an accidental O(rows^2)
%   reallocation in the fallback, or per-row overhead growth — trips the gate
%   regardless of host speed.
%
%   Warmup parse dissolves first-call/JIT overhead; small files are parsed
%   over an inner repeat loop so sub-millisecond parses stay measurable;
%   median of nRuns defuses one-off spikes. Temp files are always deleted.
%
%   Run:
%     octave --no-gui --eval "install(); bench_delimited_parse();"
%
%   Exits 0 with "PASS: ..." on success; raises assert() (non-zero exit) if
%   parse time scales super-linearly with row count.
%
%   See also dispatchDelimitedParse_, readRawDelimited_, delimited_parse_mex,
%            BatchTagPipeline, bench_datastore_range.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    install();
    % dispatchDelimitedParse_ / delimited_parse_mex / readRawDelimited_ live in
    % SensorThreshold's private/ folder, which cannot be put on the path. The
    % current working folder is always searched regardless of its name, so
    % cd-ing into private makes them directly callable in both MATLAB and
    % Octave (and makes the exist() MEX check accurate). onCleanup restores the
    % original folder even if an assert below trips.
    privDir = fullfile(here, '..', 'libs', 'SensorThreshold', 'private');
    origDir = pwd;
    restoreDir = onCleanup(@() cd(origDir)); %#ok<NASGU>
    cd(privDir);

    rows   = [1e3, 1e4, 1e5, 5e5];
    labels = {'1K', '10K', '100K', '500K'};
    nCols  = 4;          % time + 3 value columns (a modest "wide" sensor CSV)

    nRuns      = 5;      % median of nRuns per size
    targetRows = 2e5;    % inner-loop repeats sized to parse ~this many rows

    % Deterministic seed — works in both MATLAB and Octave
    if exist('rng', 'file') == 2
        rng(0);
    else
        rand('state', 0); randn('state', 0); %#ok<RAND>
    end

    useMex = (exist('delimited_parse_mex', 'file') == 3);

    nSizes  = numel(rows);
    tParse  = zeros(1, nSizes);   % per-parse seconds
    fileMB  = zeros(1, nSizes);

    % Track temp files so they are always cleaned up, even on a gate failure.
    tmpFiles = {};
    cleanupTmp = onCleanup(@() deleteFiles_(tmpFiles)); %#ok<NASGU>

    fprintf('\n=== Delimited-parse (CSV ingestion) microbenchmark ===\n');
    fprintf('  delimited_parse_mex: %s\n', tf_(useMex));
    fprintf('  %d columns (time + %d values), median of %d runs\n', nCols, nCols - 1, nRuns);
    fprintf('  %s\n', repmat('-', 1, 72));
    fprintf('  %-6s | %-9s | %-13s %-12s %-10s\n', ...
        'rows', 'file MB', 'parse (ms)', 'rows/s (M)', 'MB/s');
    fprintf('  %s\n', repmat('-', 1, 72));

    for c = 1:nSizes
        n = rows(c);
        path = [tempname, '.csv'];
        tmpFiles{end+1} = path; %#ok<AGROW>
        writeCsv_(path, n, nCols);
        d = dir(path);
        fileMB(c) = d.bytes / 1e6;

        nInner = max(1, ceil(targetRows / n));
        tParse(c) = timeParse_(path, nInner, nRuns);

        fprintf('  %-6s | %8.2f  | %11.4f   %10.2f   %8.1f\n', ...
            labels{c}, fileMB(c), ...
            tParse(c) * 1000, n / tParse(c) / 1e6, fileMB(c) / tParse(c));

        delete(path);                 % free disk eagerly between sizes
        tmpFiles{c} = '';             % already gone — don't double-delete
    end
    fprintf('  %s\n', repmat('-', 1, 72));

    % ---- Scaling gate: fit exponent over the large-N portion (>= 1e4) ----
    fitMask = rows >= 1e4;
    slope = scalingExponent_(rows(fitMask), tParse(fitMask));

    gate = 1.3;
    fprintf('  Scaling exponent (large-N fit, ideal ~1.0): %.2f   (gate: <= %.1f)\n', slope, gate);
    fprintf('  %s\n', repmat('-', 1, 72));

    assert(slope <= gate, ...
        sprintf(['FAIL: delimited parse scaling exponent %.2f exceeds %.1f — ' ...
                 'super-linear creep in the CSV-ingestion path.'], slope, gate));
    fprintf('  PASS: parsing scales near-linearly (gate: exponent <= %.1f).\n\n', gate);
end

function writeCsv_(path, n, nCols)
    %WRITECSV_ Write a deterministic n-row, nCols-column CSV with a header.
    %   Column 1 is a monotonic time axis; remaining columns are smooth
    %   signals plus light noise. Generation is intentionally outside the
    %   timed region.
    x = linspace(0, 1000, n);
    M = zeros(n, nCols);
    M(:, 1) = x(:);
    for k = 2:nCols
        M(:, k) = sin(x(:) / (10 * k)) + 0.1 * randn(n, 1);
    end

    fid = fopen(path, 'w');
    if fid == -1
        error('bench:fileOpen', 'Cannot open temp file for writing: %s', path);
    end
    closer = onCleanup(@() fclose(fid)); %#ok<NASGU>

    hdr = 't';
    for k = 2:nCols
        hdr = [hdr, sprintf(',c%d', k - 1)]; %#ok<AGROW>
    end
    fprintf(fid, '%s\n', hdr);

    rowFmt = ['%.6g', repmat(',%.6g', 1, nCols - 1), '\n'];
    fprintf(fid, rowFmt, M.');   % transpose: fprintf consumes column-major
end

function t = timeParse_(path, nInner, nRuns)
    %TIMEPARSE_ Median-of-nRuns per-parse time of dispatchDelimitedParse_.
    dispatchDelimitedParse_(path); % warmup (also primes OS file cache)
    runTimes = zeros(1, nRuns);
    for r = 1:nRuns
        t0 = tic;
        for i = 1:nInner
            dispatchDelimitedParse_(path);
        end
        runTimes(r) = toc(t0);
    end
    t = median(runTimes) / nInner;
end

function slope = scalingExponent_(ns, times)
    %SCALINGEXPONENT_ Log-log slope of per-parse time vs row count.
    times = max(times, eps);
    p = polyfit(log10(ns(:)), log10(times(:)), 1);
    slope = p(1);
end

function deleteFiles_(files)
    %DELETEFILES_ Best-effort cleanup of any temp files still present.
    for i = 1:numel(files)
        f = files{i};
        if ~isempty(f) && exist(f, 'file')
            delete(f);
        end
    end
end

function s = tf_(b)
    if b
        s = 'active';
    else
        s = 'fallback (pure MATLAB/Octave)';
    end
end
