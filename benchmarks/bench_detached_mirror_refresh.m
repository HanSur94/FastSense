function result = bench_detached_mirror_refresh()
%BENCH_DETACHED_MIRROR_REFRESH Refresh-rate cost of detached live mirrors.
%
%   Directly exercises the project's headline performance constraint:
%   "detached live-mirrored widgets must not degrade dashboard refresh rate."
%   No committed benchmark covered it — bench_dashboard_live.m times
%   onLiveTick() for a fixed all-in-grid dashboard, never with a detached
%   mirror attached.
%
%   DashboardEngine.detachWidget() pops a widget into a standalone figure as
%   a DetachedMirror, and onLiveTick() ticks every mirror in-line on the same
%   refresh path (DashboardEngine.onLiveTick -> the DetachedMirrors loop ->
%   DetachedMirror.tick). So a mirror's per-tick cost is paid by the live
%   dashboard tick itself — this bench measures and baselines that cost.
%
%   Experiment design (isolates the mirror variable):
%     - Fixed total widget count N. Each scenario detaches K of them
%       (K = 0,1,2,4) and re-measures active refresh latency.
%     - A detached widget leaves the grid but its mirror still ticks, so
%       TOTAL widgets serviced per tick is constant; only how many are
%       mirrored changes. Rising refresh time => mirrors add cost.
%     - Per-tag data size is held CONSTANT every tick (fresh Y on a fixed X,
%       no array growth) so data volume is not a confound.
%
%   Measurement method (learned from the data, not assumed):
%     - The path needs a LONG warmup: per-tick cost decays over ~15-20 ticks
%       (JIT + render-data caches). A large GLOBAL warmup precedes all
%       measurement so scenario ordering cannot bias the result.
%     - onLiveTick() time is BIMODAL because drawnow('limitrate') throttles
%       figure flushes — some ticks flush (expensive), some are coalesced
%       (cheap). A per-tick median is unstable on bimodal data, so this bench
%       reports the AMORTIZED average over a fixed tick batch (total / nTicks)
%       — which is exactly the effective refresh rate and is stable. (Same
%       amortization bench_dashboard_live.m uses.)
%
%   What it measures (deterministic, no RNG; headless):
%     - amortized active refresh time (ms/tick) per mirror count.
%     - effective refresh rate (Hz) and overhead vs the 0-mirror baseline.
%
%   Throughput bench, not a pass/fail gate: it PRINTS results and a soft
%   advisory. The next /bench-guard (or /perf-watch) run baselines the
%   numbers and — most importantly — flags if the per-mirror overhead GROWS
%   over time. Complements the /refresh-budget watchdog with a committed,
%   baseline-able file.
%
%   Run (MATLAB only — see note):
%     bench_detached_mirror_refresh
%
%   Note: the DetachedMirror path is currently MATLAB-only — under Octave,
%   DetachedMirror.cloneWidget calls feval('FastSenseWidget.fromStruct', ...)
%   and Octave does not resolve that dotted-static-method feval form
%   ("function 'FastSenseWidget.fromStruct' not found"). This bench detects
%   Octave and skips cleanly so CI/watchdog sweeps do not crash. (The Octave
%   gap is a library-side compat issue worth flagging to maintainers.)
%
%   Returns a struct (mirror counts, amortized ms, Hz, overhead %) for baselining.
%
%   See also DashboardEngine.detachWidget, DashboardEngine.onLiveTick,
%   DetachedMirror, bench_dashboard_live, bench_fastsense_multiline.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    install();

    % DetachedMirror.cloneWidget uses feval('FastSenseWidget.fromStruct', ...),
    % which Octave does not resolve. Skip cleanly rather than crash a sweep.
    if exist('OCTAVE_VERSION', 'builtin') ~= 0
        fprintf('\n[bench_detached_mirror_refresh] SKIPPED on Octave: the DetachedMirror\n');
        fprintf('  path requires MATLAB (feval ''FastSenseWidget.fromStruct'' unsupported).\n\n');
        result = struct('skipped', true, 'reason', 'octave-detach-unsupported');
        return;
    end

    % ---- Configuration ----
    N_WIDGETS    = 8;
    N_PTS        = 2e4;          % points per tag (held constant every tick)
    N_GLOBAL_WARM = 20;          % global warmup — path settles over ~15-20 ticks
    N_WARM       = 12;           % per-scenario settle (new mirror figures need
                                 % several flushes before their cost stabilizes)
    N_TICKS      = 30;           % amortized batch per scenario (total / N_TICKS)
    detachCounts = [0, 1, 2, 4];

    baseX = linspace(0, 1000, N_PTS);

    % ---- Build N Tag-bound FastSense widgets (deterministic data) ----
    tags = cell(1, N_WIDGETS);
    for i = 1:N_WIDGETS
        yi = sin(baseX / 7 + i) + 0.2 * sin(baseX * 1.3 + i);
        tags{i} = SensorTag(sprintf('mir-tag-%d', i), 'X', baseX, 'Y', yi);
    end

    d = DashboardEngine('BenchMirror');
    for i = 1:N_WIDGETS
        col = mod(i - 1, 2) * 12 + 1;
        row = ceil(i / 2);
        d.addWidget('fastsense', ...
            'Title', sprintf('Tag %d', i), ...
            'Position', [col, row, 12, 2], ...
            'Tag', tags{i});
    end

    % Render headless; mute warnings only around render (e.g. legend caps).
    wsR = warning('off', 'all');
    d.render();
    warning(wsR);

    widgets = d.activePageWidgets();   % capture handles in order (pre-detach)

    % ---- Global warmup so scenario ordering cannot bias the baseline ----
    phase = 0;
    for w = 1:N_GLOBAL_WARM
        phase = phase + 0.01;
        doTick_(d, tags, baseX, phase);
    end

    fprintf('\n================================================================\n');
    fprintf('  FastSense Detached-Mirror Refresh Benchmark\n');
    fprintf('  Constraint: detaching a live mirror must NOT degrade refresh\n');
    fprintf('================================================================\n');
    fprintf('  widgets = %d   points/tag = %d (constant/tick)   amortized over %d ticks\n', ...
        N_WIDGETS, N_PTS, N_TICKS);
    fprintf('  global warmup = %d ticks   (onLiveTick is bimodal; amortized avg is the stable metric)\n', ...
        N_GLOBAL_WARM);
    fprintf('  %s\n', repmat('-', 1, 72));
    fprintf('  %-8s | %-7s | %-7s | %-13s | %-9s | %-10s\n', ...
        'mirrors', 'in-grid', 'total', 'refresh ms', 'refresh', 'vs base');
    fprintf('  %s\n', repmat('-', 1, 72));

    nC = numel(detachCounts);
    tickMs    = zeros(1, nC);
    refreshHz = zeros(1, nC);
    overhead  = zeros(1, nC);
    detachedSoFar = 0;

    for c = 1:nC
        target = detachCounts(c);

        % Detach progressively up to the target count.
        while detachedSoFar < target
            detachedSoFar = detachedSoFar + 1;
            wsD = warning('off', 'all');
            d.detachWidget(widgets{detachedSoFar});
            warning(wsD);
        end

        % Per-scenario settle (mirror figures need a first flush after detach).
        for w = 1:N_WARM
            phase = phase + 0.01;
            doTick_(d, tags, baseX, phase);
        end

        % Amortized active refresh: total wall time over N_TICKS / N_TICKS.
        % Amortization absorbs the bimodal drawnow-limitrate flush pattern.
        tBatch = tic;
        for k = 1:N_TICKS
            phase = phase + 0.01;
            doTick_(d, tags, baseX, phase);
        end
        tickMs(c)    = toc(tBatch) * 1000 / N_TICKS;
        refreshHz(c) = 1000 / tickMs(c);
        overhead(c)  = (tickMs(c) / tickMs(1) - 1) * 100;

        fprintf('  %-8d | %-7d | %-7d | %13.3f | %6.0fHz | %+9.1f%%\n', ...
            target, N_WIDGETS - target, N_WIDGETS, tickMs(c), refreshHz(c), overhead(c));
    end

    fprintf('  %s\n', repmat('-', 1, 72));

    maxOver = max(overhead);
    fprintf('  Baseline (0 mirrors): %.3f ms (%.0f Hz)\n', tickMs(1), refreshHz(1));
    fprintf('  Refresh overhead from mirrors (max): %+.1f%%  %s\n', ...
        maxOver, constraintLabel_(maxOver));
    fprintf('  %s\n', repmat('-', 1, 72));
    fprintf('  Note: composite bench (no time gate). /bench-guard baselines these + watches for growth.\n\n');

    % ---- Cleanup: close mirror figures + dashboard ----
    try
        for i = 1:numel(d.DetachedMirrors)
            try, delete(d.DetachedMirrors{i}); catch, end
        end
        close(d.hFigure);
    catch
    end

    result = struct( ...
        'detachCounts', detachCounts, ...
        'nWidgets',     N_WIDGETS, ...
        'nPts',         N_PTS, ...
        'tickMs',       tickMs, ...
        'refreshHz',    refreshHz, ...
        'overheadPct',  overhead, ...
        'maxOverheadPct', maxOver);
end

function doTick_(d, tags, baseX, phase)
    %DOTICK_ Replace every tag's data (fixed size, fresh Y) then run one
    %   onLiveTick(). Constant per-tag size isolates mirror overhead from data
    %   volume. The whole call is timed in batch by the caller (amortized).
    for i = 1:numel(tags)
        newY = sin(baseX / 7 + i + phase) + 0.2 * sin(baseX * 1.3 + i + phase);
        tags{i}.updateData(baseX, newY);
    end
    d.onLiveTick();
end

function s = constraintLabel_(maxOverPct)
    %CONSTRAINTLABEL_ Soft verdict on the mirror refresh overhead.
    %   Mirrors necessarily add draw work to the shared tick, so some overhead
    %   is expected; the point is to baseline it and catch regressions.
    if maxOverPct > 150
        s = '<< notable: mirrors add heavy refresh cost — baseline + watch';
    elseif maxOverPct > 50
        s = '(mirrors add meaningful refresh cost — expected; watch for growth)';
    else
        s = '(refresh largely preserved)';
    end
end
