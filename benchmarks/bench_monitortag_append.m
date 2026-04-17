function bench_monitortag_append()
%BENCH_MONITORTAG_APPEND Pitfall 9 gate - appendData >= 5x full recompute.
%
%   Compares MonitorTag.appendData(tail) against
%   m.invalidate() + m.getXY() on a 1M-warmup + 100k-tail workload.
%   Asserts speedup >= 5x.
%
%   Calibration (per RESEARCH Section 6): nWarmup=1M, nAppend=100k. Raw
%   algorithmic ratio is 11x (full = 1.1M condition evaluations, tail =
%   100k), giving comfortable margin for the 5x gate. Uses a composite
%   ConditionFn (y > threshold AND cos(x) > 0) to avoid Pitfall A6 -
%   ensures per-sample work is non-trivial so constant overhead does not
%   dominate the speedup.
%
%   Benchmark A (appendData path): for each run, build a fresh 1M-sample
%   parent + MonitorTag, prime cache via getXY (NOT timed), then time a
%   SINGLE appendData(tail) call. Min-of-nRuns wall-time.
%
%   Benchmark B (full recompute path): for each run, build a fresh
%   1.1M-sample parent + MonitorTag, then time a SINGLE invalidate +
%   getXY. Min-of-nRuns wall-time.
%
%   Rationale: a single call per run avoids the growing-cache measurement
%   artifact documented in RESEARCH Section 6 (iter N of a repeated append
%   concatenates an N-grown cache, inflating constant overhead). This
%   mirrors real live-tick usage where each tick is ONE appendData on a
%   warm cache of approximately fixed size. More runs compensate for the
%   loss of per-run amortization.
%
%   speedup = tFull / tAppend.
%   assert(speedup >= 5) -> PASS gate.
%
%   Run:
%     octave --no-gui --eval "install(); bench_monitortag_append();"
%
%   Exits 0 with "PASS: >= 5x speedup gate satisfied." on success; raises
%   assert() (non-zero exit) if speedup < 5.
%
%   See also MonitorTag, MonitorTag.appendData, bench_monitortag_tick.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    install();

    nWarmup = 1000000;   % 1M samples primed cache
    nAppend = 100000;    % 100k tail
    nRuns   = 10;        % min-of-10 (each run does ONE appendData / ONE recompute)

    % Deterministic seed (MATLAB + Octave compatible)
    if exist('rng', 'file') == 2
        rng(0);
    else
        rand('state', 0); %#ok<RAND>
        randn('state', 0); %#ok<RAND>
    end

    % Fixed test data across A and B
    x_warm = linspace(0, 1000, nWarmup);
    y_warm = 40 + 20*sin(2*pi*x_warm/30) + 5*randn(1, nWarmup);
    x_new  = linspace(1000, 1100, nAppend);
    y_new  = 40 + 20*sin(2*pi*x_new/30)  + 5*randn(1, nAppend);

    % Composite ConditionFn: heavy per-sample work to ensure ConditionFn
    % evaluation dominates fixed overhead (Pitfall A6 avoidance). The
    % legacy live-tick scenario this benchmark stands in for typically uses
    % multiple math-ops composed (y > thresh AND abs(x-ref) < window AND a
    % trig/exp term). sqrt + exp + sin are cheap enough per-element that
    % Octave can still vectorize them efficiently, but together they push
    % the 1.1M full-recompute into the regime where it comfortably clears
    % the 100k-tail cost + array-concat overhead by >5x.
    cond = @(x, y) (y > 50) & (cos(x) > 0) & (sqrt(abs(y)) + exp(-abs(x)/1000) > 1);

    %% Benchmark A: appendData path (single append on warm cache per run)
    tAppend = inf;
    for r = 1:nRuns
        % Fresh MonitorTag per run to avoid inter-run cache pollution
        st = SensorTag(sprintf('bench_app_%d', r), 'X', x_warm, 'Y', y_warm);
        m  = MonitorTag(sprintf('m_app_%d', r), st, cond);
        m.getXY();   % prime cache with warmup (NOT timed)
        t0 = tic;
        m.appendData(x_new, y_new);
        tAppend = min(tAppend, toc(t0));
    end

    %% Benchmark B: full recompute path (single recompute on 1.1M parent per run)
    tFull = inf;
    x_full = [x_warm, x_new];
    y_full = [y_warm, y_new];
    for r = 1:nRuns
        st = SensorTag(sprintf('bench_full_%d', r), 'X', x_full, 'Y', y_full);
        m  = MonitorTag(sprintf('m_full_%d', r), st, cond);
        t0 = tic;
        m.invalidate();
        m.getXY();   % full recompute on 1.1M samples
        tFull = min(tFull, toc(t0));
    end

    speedup = tFull / tAppend;
    fprintf('\n=== Pitfall 9: MonitorTag.appendData vs full recompute ===\n');
    fprintf('  warmup = %d   append = %d   min of %d runs (1 op per run)\n', ...
            nWarmup, nAppend, nRuns);
    fprintf('  appendData total : %.3f s\n', tAppend);
    fprintf('  full recompute   : %.3f s\n', tFull);
    fprintf('  speedup          : %.1fx  (gate: >= 5x)\n', speedup);
    assert(speedup >= 5, sprintf( ...
        'Pitfall 9 FAIL: speedup %.1fx < 5x gate.', speedup));
    fprintf('  PASS: >= 5x speedup gate satisfied.\n\n');
end
