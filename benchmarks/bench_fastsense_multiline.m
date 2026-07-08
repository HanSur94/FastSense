function result = bench_fastsense_multiline()
%BENCH_FASTSENSE_MULTILINE Live-update scaling vs line count on one axes.
%
%   Measures how the live refresh path scales as a SINGLE FastSense axes
%   accumulates lines — the multi-sensor overlay case. The focus is
%   updateData(), the live hot path: per its own contract it re-downsamples
%   *all* lines on every call, so a one-line live update costs O(lineCount).
%   That per-call cost is what the project's refresh-rate constraint rides
%   on, so the headline metric is the achievable refresh rate (Hz) as line
%   count grows.
%
%   Why this is the gap: the kernel microbenches (bench_downsample_kernels,
%   bench_violation_cull, bench_binary_search) now cover every MEX kernel
%   actually wired into production. What was NOT covered is the COMPOSITE
%   scaling — how the whole update path grows with line count on one axes.
%   benchmark.m and benchmark_zoom.m use a single line; the dashboard benches
%   vary widget count, not lines-per-axes. This bench isolates that axis.
%
%   What it measures (deterministic, no RNG; headless invisible figure):
%     - updateData() wall time (median, SkipViewMode to isolate the
%       re-downsample cost from view-mode / xlim adjustment).
%     - "us per line" — if it stays flat the live cost is linear in line
%       count; if it FALLS, a fixed per-call overhead is amortizing (good);
%       a sharp RISE would signal super-linear per-line overhead.
%     - effective refresh rate (Hz = 1000 / updateData ms).
%     - one-time render() setup cost (single sample, figure-realization
%       dominated — reported for context, not a clean scaling signal).
%
%   The setup render is run with ShowProgress disabled so the console
%   progress bar does not pollute the timing or the output.
%
%   Throughput bench, not a pass/fail gate: it PRINTS results and a soft
%   scaling advisory. The next /bench-guard (or /perf-watch) run baselines
%   the absolute numbers.
%
%   Run:
%     octave --no-gui --eval "install(); bench_fastsense_multiline();"
%     % or in MATLAB:
%     bench_fastsense_multiline
%
%   Returns a struct (line counts, update ms, us/line, Hz, setup ms,
%   scaling drift) for programmatic baselining.
%
%   See also FastSense, FastSense.updateData, FastSense.render,
%   bench_downsample_kernels, bench_dashboard_live.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    install();

    % ---- Configuration ----
    lineCounts = [1, 4, 16, 64];
    nPerLine   = 1e5;       % points per line (fixed — isolates line-count axis)
    nWarm      = 2;         % updateData warmups
    nUpdateRep = 7;         % updateData measurements (median)

    fprintf('\n================================================================\n');
    fprintf('  FastSense Multi-Line Live-Update Scaling Benchmark\n');
    fprintf('  updateData() re-downsamples all lines -> refresh cost vs lines\n');
    fprintf('================================================================\n');
    fprintf('  points/line = %d   update reps = %d (median)   SkipViewMode = true\n', ...
        nPerLine, nUpdateRep);
    fprintf('  %s\n', repmat('-', 1, 76));
    fprintf('  %-6s | %-9s | %-11s | %-13s | %-9s | %-8s\n', ...
        'lines', 'total pts', 'setup ms', 'updateData ms', 'us/line', 'refresh');
    fprintf('  %s\n', repmat('-', 1, 76));

    nL = numel(lineCounts);
    setupMs   = zeros(1, nL);
    updateMs  = zeros(1, nL);
    usPerLine = zeros(1, nL);
    refreshHz = zeros(1, nL);

    for c = 1:nL
        L = lineCounts(c);

        % Deterministic per-line data: distinct phase per line, no RNG.
        x = linspace(0, nPerLine / 100, nPerLine);
        Y = zeros(L, nPerLine);
        for k = 1:L
            Y(k, :) = sin(x * 0.1 + k) + 0.3 * sin(x * 1.7 + k) + 0.2 * sin(x * 13.0 + k);
        end

        % Build headless instance and render once (silently) for setup.
        % Warnings muted only around the one-time setup render (e.g. MATLAB
        % caps the auto-legend at 50 entries for high line counts) — restored
        % immediately so the measured update path is unaffected.
        [fp, fig] = buildFS_(x, Y);
        ws = warning('off', 'all');
        tic;
        fp.render();
        setupMs(c) = toc * 1000;
        warning(ws);

        % updateData timing: update line 1 with fresh data each call; this
        % re-downsamples ALL lines. SkipViewMode isolates the re-downsample
        % cost from xlim / view-mode logic.
        for w = 1:nWarm
            fp.updateData(1, x, Y(1, :) + 0.01 * w, 'SkipViewMode', true);
        end
        uTimes = zeros(1, nUpdateRep);
        for u = 1:nUpdateRep
            ynew = Y(1, :) + 0.001 * u;   % force a genuine data replace each rep
            tic;
            fp.updateData(1, x, ynew, 'SkipViewMode', true);
            uTimes(u) = toc;
        end
        updateMs(c)  = median(uTimes) * 1000;
        usPerLine(c) = (updateMs(c) * 1000) / L;
        refreshHz(c) = 1000 / updateMs(c);

        close(fig);

        fprintf('  %-6d | %9s | %11.1f | %13.3f | %9.1f | %6.0fHz\n', ...
            L, humanCount_(L * nPerLine), setupMs(c), updateMs(c), usPerLine(c), refreshHz(c));
    end

    fprintf('  %s\n', repmat('-', 1, 76));

    % ---- Soft scaling advisory ----
    % updateData re-downsamples every line, so its TOTAL cost grows with line
    % count, but a fixed per-call overhead (drawnow, dispatch) amortizes — so
    % us/line should be flat or FALLING. A sharp rise means super-linear
    % per-line overhead crept in. Advisory only, not a gate.
    perLineDrift = usPerLine(end) / usPerLine(1);

    fprintf('  Scaling (%d -> %d lines):\n', lineCounts(1), lineCounts(end));
    fprintf('    updateData us/line : %.1f -> %.1f  (%.2fx)  %s\n', ...
        usPerLine(1), usPerLine(end), perLineDrift, perLineLabel_(perLineDrift));
    fprintf('    refresh rate       : %.0f Hz (1 line) -> %.0f Hz (%d lines)\n', ...
        refreshHz(1), refreshHz(end), lineCounts(end));
    fprintf('  %s\n', repmat('-', 1, 76));
    fprintf('  Note: composite bench (no time gate). /bench-guard baselines these numbers.\n\n');

    result = struct( ...
        'lineCounts',   lineCounts, ...
        'nPerLine',     nPerLine, ...
        'setupMs',      setupMs, ...
        'updateMs',     updateMs, ...
        'usPerLine',    usPerLine, ...
        'refreshHz',    refreshHz, ...
        'perLineDrift', perLineDrift);
end

function [fp, fig] = buildFS_(x, Y)
    %BUILDFS_ Headless FastSense with size(Y,1) lines on an invisible figure.
    %   ShowProgress disabled so the console progress bar does not pollute
    %   timing or output.
    fig = figure('Visible', 'off', 'Position', [100 100 800 400]);
    ax = axes('Parent', fig);
    fp = FastSense('Parent', ax);
    fp.ShowProgress = false;
    L = size(Y, 1);
    for k = 1:L
        fp.addLine(x, Y(k, :), 'DisplayName', sprintf('line %d', k));
    end
end

function s = humanCount_(n)
    %HUMANCOUNT_ Compact count label (e.g. 6.4M).
    if n >= 1e6
        s = sprintf('%.1fM', n / 1e6);
    elseif n >= 1e3
        s = sprintf('%.0fK', n / 1e3);
    else
        s = sprintf('%d', n);
    end
end

function s = perLineLabel_(drift)
    %PERLINELABEL_ Soft verdict on per-line update cost growth.
    if drift > 2.0
        s = '<< WATCH: super-linear per-line update cost';
    elseif drift > 1.5
        s = '(mild per-line rise)';
    elseif drift >= 0.8
        s = '(~linear in line count)';
    else
        s = '(sublinear — fixed overhead amortizes)';
    end
end
