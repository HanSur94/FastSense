function run_ci_benchmark()
%RUN_CI_BENCHMARK Performance benchmark for CI with statistical analysis.
%   Runs multiple iterations across multiple dataset sizes to produce
%   mean, std, and RMS for each metric. Outputs results as JSON for
%   github-action-benchmark (customSmallerIsBetter format).
%
%   Metrics measured:
%     - Instantiation: FastPlot() + addLine + addThreshold
%     - Render: render() + drawnow
%     - Zoom cycle: set XLim + drawnow (interactive responsiveness)
%     - Downsample: minmax_downsample kernel
%
%   Dataset sizes: 1M, 5M, 10M, 50M, 100M, 500M points
%   Iterations: scaled per size to keep CI runtime reasonable

    addpath(fullfile(pwd, 'libs', 'FastPlot', 'private'));

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
            fp = FastPlot();
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
            fp = FastPlot();
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
        fp = FastPlot();
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
