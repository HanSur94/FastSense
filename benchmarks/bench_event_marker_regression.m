function bench_event_marker_regression
    %BENCH_EVENT_MARKER_REGRESSION Phase 1012 Pitfall-10 gate.
    %   12-line FastSense plot, 0 events attached, median over 20 runs.
    %   Three configurations:
    %     (a) no EventStore attached
    %     (b) empty EventStore attached
    %     (c) EventStore populated for OTHER tags (so getEventsForTag returns [])
    %   Pass criteria:
    %     - (b) within 5% of (a)
    %     - (c) within 5% of (a)
    %     - all three within 5% of Phase-1010 baseline (see printed median)
    addpath(fileparts(fileparts(mfilename('fullpath'))));
    install();

    N_PTS   = 100000;
    N_LINES = 12;
    N_ITERS = 20;

    rng(42);
    x = linspace(0, 100, N_PTS);
    yAll = randn(N_LINES, N_PTS);

    tA = runConfig(x, yAll, 'none');
    tB = runConfig(x, yAll, 'empty');
    tC = runConfig(x, yAll, 'otherTags');

    fprintf('Config A (no store)     median: %8.2f ms\n', tA * 1000);
    fprintf('Config B (empty store)  median: %8.2f ms\n', tB * 1000);
    fprintf('Config C (other tags)   median: %8.2f ms\n', tC * 1000);

    baseline = tA;
    relB = (tB - baseline) / baseline;
    relC = (tC - baseline) / baseline;
    fprintf('B vs A: %+6.2f%%  (gate: +/-5%%)\n', relB * 100);
    fprintf('C vs A: %+6.2f%%  (gate: +/-5%%)\n', relC * 100);

    if abs(relB) > 0.05 || abs(relC) > 0.05
        error('bench:regression', ...
            'Pitfall-10 regression: A=%.2fms B=%.2fms (%+.1f%%) C=%.2fms (%+.1f%%)', ...
            tA*1000, tB*1000, relB*100, tC*1000, relC*100);
    end
    fprintf('PASS: all configs within 5%% of baseline A.\n');
end

function t = runConfig(x, yAll, mode)
    N_ITERS = 20;
    elapsed = zeros(1, N_ITERS);
    for it = 1:N_ITERS
        f = figure('Visible', 'off');
        ax = axes('Parent', f);
        fp = FastSense('Parent', ax);
        for i = 1:size(yAll, 1)
            fp.addLine(x, yAll(i, :));
        end
        switch mode
            case 'none'
                % no event store
            case 'empty'
                fp.EventStore = EventStore('');
            case 'otherTags'
                es = EventStore('');
                ev = Event(0, 1, 'other_tag', 'x', 0, 'upper');
                es.append(ev);
                fp.EventStore = es;
        end
        t0 = tic;
        fp.render();
        elapsed(it) = toc(t0);
        close(f);
    end
    t = median(elapsed);
end
