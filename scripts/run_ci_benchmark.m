function run_ci_benchmark()
%RUN_CI_BENCHMARK Performance benchmark for CI with statistical analysis.
%   Runs multiple iterations across multiple dataset sizes to produce
%   mean, std, and RMS for each metric. Outputs results as JSON for
%   github-action-benchmark (customSmallerIsBetter format).
%
%   Metrics measured:
%     - Instantiation: FastSense() + addLine + addThreshold
%     - Render: render() + drawnow
%     - Zoom cycle: set XLim + drawnow (interactive responsiveness)
%     - Downsample: minmax_downsample kernel
%
%   Dataset sizes: 1M, 5M, 10M, 50M, 100M, 500M points
%   Iterations: scaled per size to keep CI runtime reasonable

    % Support both FastSense and FastSense directory names
    if exist(fullfile(pwd, 'libs', 'FastSense', 'private'), 'dir')
        addpath(fullfile(pwd, 'libs', 'FastSense', 'private'));
    else
        addpath(fullfile(pwd, 'libs', 'FastSense', 'private'));
    end

    % Load Dashboard classes (and all lib paths) if not already on path
    if ~exist('DashboardEngine', 'class')
        install();
    end

    sizes  = [1e6, 5e6, 10e6, 50e6, 100e6, 500e6];
    labels = {'1M', '5M', '10M', '50M', '100M', '500M'};

    % Scale iterations down for larger sizes to keep CI runtime reasonable
    N_DS_base   = 20;   % downsample iterations (base for 1M)
    N_ZOOM      = 20;   % zoom cycles per run
    N_RUNS_base = 10;   % runs for zoom/downsample stats (base for 1M)
    N_INIT_base = 5;    % runs for instantiation/render (base for 1M)

    results = {};

    for s = 1:numel(sizes)
        n = sizes(s);
        lbl = labels{s};
        fprintf('\n========== %s points ==========\n', lbl);

        % Scale iterations for larger sizes to keep total runtime manageable
        % ~15 min budget for full suite on CI
        if n <= 1e6
            N_DS = N_DS_base; N_RUNS = N_RUNS_base; N_INIT = N_INIT_base;
        elseif n <= 10e6
            N_DS = 10; N_RUNS = 5; N_INIT = 3;
        elseif n <= 100e6
            N_DS = 5; N_RUNS = 3; N_INIT = 3;
        else
            N_DS = 3; N_RUNS = 3; N_INIT = 3;
        end

        fprintf('  Generating %s data points...\n', lbl);
        x = linspace(0, 100, n);
        y = sin(x * 2*pi / 10) + 0.5 * randn(1, n);
        fprintf('  Data ready (%.0f MB)\n', n * 16 / 1e6);

        % --- Downsample benchmark ---
        t_ds = zeros(1, N_RUNS);
        for r = 1:N_RUNS
            tic;
            for k = 1:N_DS
                minmax_downsample(x, y, 2000);
            end
            t_ds(r) = toc / N_DS;
        end
        results = add_result(results, sprintf('Downsample mean (%s)', lbl), 'ms', t_ds * 1000);

        % --- Instantiation benchmark ---
        t_init = zeros(1, N_INIT);
        for r = 1:N_INIT
            tic;
            fp = FastSense();
            fp.addLine(x, y, 'DisplayName', 'Sensor');
            fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true);
            fp.addThreshold(-1.5, 'Direction', 'lower', 'ShowViolations', true);
            t_init(r) = toc;
            close all force;
        end
        results = add_result(results, sprintf('Instantiation mean (%s)', lbl), 'ms', t_init * 1000);

        % --- Render benchmark ---
        t_render = zeros(1, N_INIT);
        for r = 1:N_INIT
            fp = FastSense();
            fp.addLine(x, y, 'DisplayName', 'Sensor');
            fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true);
            fp.addThreshold(-1.5, 'Direction', 'lower', 'ShowViolations', true);
            tic;
            fp.render();
            drawnow;
            t_render(r) = toc;
            close all force;
        end
        results = add_result(results, sprintf('Render mean (%s)', lbl), 'ms', t_render * 1000);

        % --- Zoom cycle benchmark ---
        fp = FastSense();
        fp.addLine(x, y, 'DisplayName', 'Sensor');
        fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true);
        fp.addThreshold(-1.5, 'Direction', 'lower', 'ShowViolations', true);
        fp.render();
        drawnow;

        % Warmup
        for k = 1:5
            set(fp.hAxes, 'XLim', [20 80]);
            drawnow;
        end

        t_zoom = zeros(1, N_RUNS);
        for r = 1:N_RUNS
            centers = 10 + 80 * rand(1, N_ZOOM);
            widths  = 1 + 20 * rand(1, N_ZOOM);
            tic;
            for k = 1:N_ZOOM
                set(fp.hAxes, 'XLim', [centers(k)-widths(k)/2, centers(k)+widths(k)/2]);
                drawnow;
            end
            t_zoom(r) = toc / N_ZOOM;
        end
        close all force;

        results = add_result(results, sprintf('Zoom cycle mean (%s)', lbl), 'ms', t_zoom * 1000);

        % Free memory before next size (critical for 100M+ datasets)
        clear x y fp;
    end

    % --- Dashboard benchmarks ---
    fprintf('\n========== Dashboard benchmarks ==========\n');
    N_INIT = 3;

    % a. Dashboard creation + render
    t_dash = zeros(1, N_INIT);
    for r = 1:N_INIT
        [d_tmp, ~, ~] = build_bench_dashboard_();
        tic;
        d_tmp.render();
        drawnow;
        t_dash(r) = toc;
        close all force;
        clear d_tmp;
    end
    results = add_result(results, 'Dashboard create+render mean', 'ms', t_dash * 1000);

    % b. Live tick
    [d_live, ~, ~] = build_bench_dashboard_();
    d_live.render(); drawnow;
    for k = 1:2, d_live.onLiveTick(); end
    t_tick = zeros(1, N_INIT);
    for r = 1:N_INIT
        tic; d_live.onLiveTick(); t_tick(r) = toc;
    end
    results = add_result(results, 'Dashboard live tick mean', 'ms', t_tick * 1000);
    close all force; clear d_live;

    % c. Page switch
    [d_page, ~, ~] = build_bench_dashboard_();
    d_page.render(); drawnow;
    for k = 1:2, d_page.switchPage(2); d_page.switchPage(1); end
    t_sw = zeros(1, N_INIT);
    for r = 1:N_INIT
        tic; d_page.switchPage(2); d_page.switchPage(1); t_sw(r) = toc / 2;
    end
    results = add_result(results, 'Dashboard page switch mean', 'ms', t_sw * 1000);
    close all force; clear d_page;

    % d. Time slider broadcast
    [d_br, x100k, ~] = build_bench_dashboard_();
    d_br.render(); drawnow;
    tMax = x100k(end);
    for k = 1:2, d_br.broadcastTimeRange(0, tMax * 0.5); end
    t_br = zeros(1, N_INIT);
    for r = 1:N_INIT
        tStart = tMax * rand();
        tic; d_br.broadcastTimeRange(tStart, tStart + tMax * 0.1); t_br(r) = toc;
    end
    results = add_result(results, 'Dashboard broadcastTimeRange mean', 'ms', t_br * 1000);
    close all force; clear d_br;

    % --- Write JSON ---
    fid = fopen('benchmark-results.json', 'w');
    fprintf(fid, '[\n');
    for i = 1:numel(results)
        r = results{i};
        comma = ',';
        if i == numel(results), comma = ''; end
        fprintf(fid, '  {"name": "%s", "unit": "%s", "value": %.3f}%s\n', ...
            r.name, r.unit, r.value, comma);
    end
    fprintf(fid, ']\n');
    fclose(fid);

    fprintf('\n=== Benchmark complete — %d metrics written to benchmark-results.json ===\n', numel(results));
end

function [d, x100k, y100k] = build_bench_dashboard_()
%BUILD_BENCH_DASHBOARD_ Build a representative 20-widget, 2-page dashboard for CI benchmarking.
%   Returns [d, x100k, y100k] where d is a rendered-ready DashboardEngine,
%   x100k and y100k are the 100K-point sinusoidal dataset used by fastsense widgets.
    x100k = linspace(0, 10, 100000);
    y100k = sin(x100k * 2 * pi) + 0.1 * randn(1, 100000);

    d = DashboardEngine('CIBench');

    % 6x fastsense widgets — rows 1-3, 2 per row, 12 cols each
    for i = 1:6
        col = mod(i - 1, 2) * 12 + 1;
        row = ceil(i / 2);
        d.addWidget('fastsense', ...
            'Title', sprintf('Signal %d', i), ...
            'Position', [col, row, 12, 1], ...
            'XData', x100k, 'YData', y100k);
    end

    % 4x number widgets — row 4, 6 cols each
    for i = 1:4
        col = (i - 1) * 6 + 1;
        d.addWidget('number', ...
            'Title', sprintf('Count %d', i), ...
            'Position', [col, 4, 6, 1], ...
            'ValueFcn', @() rand());
    end

    % 4x status widgets — row 5, 6 cols each
    for i = 1:4
        col = (i - 1) * 6 + 1;
        d.addWidget('status', ...
            'Title', sprintf('Status %d', i), ...
            'Position', [col, 5, 6, 1], ...
            'ValueFcn', @() 'OK');
    end

    % 2x text widgets — row 6, 12 cols each
    d.addWidget('text', ...
        'Title', 'Info A', ...
        'Position', [1, 6, 12, 1], ...
        'Content', 'Dashboard CI benchmark — panel A');
    d.addWidget('text', ...
        'Title', 'Info B', ...
        'Position', [13, 6, 12, 1], ...
        'Content', 'Dashboard CI benchmark — panel B');

    % 1x barchart widget — row 7, full width
    d.addWidget('barchart', ...
        'Title', 'Metrics', ...
        'Position', [1, 7, 24, 1]);

    % Page 2 — one number widget for page switch benchmark
    d.addPage('Page2');
    d.switchPage(2);
    d.addWidget('number', ...
        'Title', 'Page2 Count', ...
        'Position', [1, 1, 6, 1], ...
        'ValueFcn', @() rand());

    % Reset to page 1 before caller calls render()
    d.switchPage(1);
end

function results = add_result(results, name, unit, samples)
%ADD_RESULT Compute stats and add to results list.
    m   = mean(samples);
    s   = std(samples);
    rms = sqrt(mean(samples.^2));

    fprintf('  %-30s  mean=%.2f %s  std=%.2f %s  rms=%.2f %s  (n=%d)\n', ...
        name, m, unit, s, unit, rms, unit, numel(samples));

    % Report mean as the tracked value (for regression detection)
    results{end+1} = struct('name', name, 'unit', unit, 'value', m);
    % Also report std as a separate metric
    results{end+1} = struct('name', [name(1:end-5) ' std' name(end-3:end)], ...
        'unit', unit, 'value', s);
end
