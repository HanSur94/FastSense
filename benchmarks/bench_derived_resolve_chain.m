function result = bench_derived_resolve_chain()
%BENCH_DERIVED_RESOLVE_CHAIN Recompute cost of a DerivedTag dependency chain.
%
%   Measures the resolve fan-out cost of DerivedTag — the lazy-memoized
%   derived/composite tag whose getXY() recomputes from its parents on
%   demand. When a base sensor updates in live mode, the invalidation
%   cascades down every derived tag that depends on it, and the next refresh
%   recomputes the whole chain. That full-chain recompute is the live cost of
%   derived tags, and no benchmark exercised it: bench_compositetag_merge.m
%   covers the CompositeTag k-way merge specifically, bench_tag_pipeline_1k.m
%   measures aggregate pipeline tickOnce throughput, and bench_dashboard_load.m
%   times getXY on a populated dashboard — none isolate how resolve cost
%   scales with dependency-chain DEPTH.
%
%   Topology: a base SensorTag T0 feeds a linear chain
%       T0 (sensor) -> T1=f(T0) -> T2=f(T1) -> ... -> TD=f(T(D-1))
%   where each f is a cheap O(N) elementwise transform. Resolving the leaf TD
%   after invalidating the chain recomputes all D nodes top-to-bottom.
%
%   What it measures (deterministic, no RNG; no figures):
%     - COLD getXY: invalidate every node, then time leaf getXY() — the full
%       D-node recompute (the live-refresh cost).
%     - WARM getXY: time leaf getXY() again with nothing dirty — returns the
%       memoized cache (shows the lazy-memo payoff).
%     - "us per node" for the cold path — flat => recompute is linear in chain
%       depth; a rise would signal super-linear fan-out overhead.
%
%   Throughput bench, not a pass/fail gate: it PRINTS results and a soft
%   scaling advisory. The next /bench-guard (or /perf-watch) run baselines the
%   numbers.
%
%   Run:
%     octave --no-gui --eval "install(); bench_derived_resolve_chain();"
%     % or in MATLAB:
%     bench_derived_resolve_chain
%
%   Returns a struct (depths, cold/warm ms, us/node, scaling drift) for baselining.
%
%   See also DerivedTag, CompositeTag, bench_compositetag_merge,
%   bench_tag_pipeline_1k, bench_dashboard_load.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    install();

    % ---- Configuration ----
    depths = [1, 2, 4, 8, 16, 32];
    nPts   = 1e6;       % points in the base sensor (flows through every node).
                        % Sized so each node's O(N) recompute dominates timer
                        % noise — at 1e5 the per-node cost was sub-0.1 ms and
                        % the sweep was noise-bound.
    nWarm  = 2;
    nReps  = 10;        % cold recompute allocates a fresh array per node, so
                        % deep chains see bursty GC; MIN over reps is the
                        % GC-robust compute-time estimator (standard for CPU
                        % microbenchmarks) and keeps the sweep monotonic.

    baseX = linspace(0, 1000, nPts);
    baseY = sin(baseX / 7) + 0.2 * sin(baseX * 1.3);

    fprintf('\n================================================================\n');
    fprintf('  FastSense DerivedTag Resolve-Chain Benchmark\n');
    fprintf('  Full-chain recompute cost vs dependency depth (live resolve)\n');
    fprintf('================================================================\n');
    fprintf('  points = %d (flows through every node)   warmup = %d   reps = %d (min)\n', ...
        nPts, nWarm, nReps);
    fprintf('  %s\n', repmat('-', 1, 72));
    fprintf('  %-6s | %-9s | %-13s | %-10s | %-13s\n', ...
        'depth', 'nodes', 'cold ms', 'us/node', 'warm (cached) ms');
    fprintf('  %s\n', repmat('-', 1, 72));

    nD = numel(depths);
    coldMs   = zeros(1, nD);
    warmMs   = zeros(1, nD);
    usPerNode = zeros(1, nD);

    for c = 1:nD
        D = depths(c);

        % Build the chain: sensor T0, then D derived tags each transforming
        % its single parent. @chainStep_ is shared by every node.
        t0 = SensorTag('chain-src', 'X', baseX, 'Y', baseY);
        dt = cell(1, D);
        prev = t0;
        for i = 1:D
            dt{i} = DerivedTag(sprintf('chain-d%d', i), {prev}, @chainStep_);
            prev = dt{i};
        end
        leaf = dt{D};

        % Warmup (populate caches, dissolve JIT).
        for w = 1:nWarm
            invalidateChain_(dt);
            leaf.getXY();
        end

        % COLD: invalidate every node, then time the full-chain recompute.
        cold = zeros(1, nReps);
        for r = 1:nReps
            invalidateChain_(dt);
            tic;
            [xo, ~] = leaf.getXY(); %#ok<ASGLU>
            cold(r) = toc;
        end
        coldMs(c)   = min(cold) * 1000;   % GC-robust compute-time estimate
        usPerNode(c) = (coldMs(c) * 1000) / D;

        % WARM: nothing dirty -> returns memoized cache.
        warm = zeros(1, nReps);
        for r = 1:nReps
            tic;
            leaf.getXY();
            warm(r) = toc;
        end
        warmMs(c) = min(warm) * 1000;

        % Correctness touch: leaf length must match the source.
        assert(numel(xo) == nPts, 'bench_derived_resolve_chain:badOutput', ...
            'leaf getXY returned %d points, expected %d', numel(xo), nPts);

        fprintf('  %-6d | %-9d | %13.3f | %10.1f | %13.4f\n', ...
            D, D, coldMs(c), usPerNode(c), warmMs(c));
    end

    fprintf('  %s\n', repmat('-', 1, 72));

    % ---- Soft scaling advisory ----
    % Each node does O(N) work, so the cold recompute should be ~linear in
    % depth => us/node flat. Compare us/node at the deepest chain against the
    % shallowest; a large rise means super-linear fan-out overhead.
    perNodeDrift = usPerNode(end) / usPerNode(1);

    fprintf('  Scaling (depth %d -> %d):\n', depths(1), depths(end));
    fprintf('    cold us/node : %.1f -> %.1f  (%.2fx)  %s\n', ...
        usPerNode(1), usPerNode(end), perNodeDrift, perNodeLabel_(perNodeDrift));
    fprintf('    warm cache hit stays ~flat: %.4f -> %.4f ms\n', warmMs(1), warmMs(end));
    fprintf('  %s\n', repmat('-', 1, 72));
    fprintf('  Note: throughput bench (no time gate). /bench-guard baselines these numbers.\n\n');

    result = struct( ...
        'depths',       depths, ...
        'nPts',         nPts, ...
        'coldMs',       coldMs, ...
        'warmMs',       warmMs, ...
        'usPerNode',    usPerNode, ...
        'perNodeDrift', perNodeDrift);
end

function [x, y] = chainStep_(parents)
    %CHAINSTEP_ One derived node: pull the single parent's (X,Y) and apply a
    %   cheap O(N) elementwise transform. Deterministic, no RNG.
    [x, y] = parents{1}.getXY();
    y = y * 0.999 + 0.001;
end

function invalidateChain_(dt)
    %INVALIDATECHAIN_ Mark every node dirty so the next leaf getXY recomputes
    %   the full chain (not just the leaf).
    for i = 1:numel(dt)
        dt{i}.invalidate();
    end
end

function s = perNodeLabel_(drift)
    %PERNODELABEL_ Soft verdict on per-node recompute growth.
    if drift > 2.0
        s = '<< WATCH: super-linear fan-out cost';
    elseif drift > 1.5
        s = '(mild per-node rise)';
    else
        s = '(linear in depth — O(depth * N))';
    end
end
