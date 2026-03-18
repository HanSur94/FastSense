%% FastSense Zoom & Pan Latency Benchmark
% Measures per-frame latency for individual zoom and pan operations.
% Forces GPU flush with getframe() to get true frame delivery time.

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));install();
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'libs', 'FastSense', 'private'));

sizes = [1e5, 1e6, 10e6, 50e6];
labels = {'100K', '1M', '10M', '50M'};

% Zoom levels: what fraction of total X range is visible
zoom_levels = [1.0, 0.5, 0.1, 0.01, 0.001];
zoom_labels = {'100%', '50%', '10%', '1%', '0.1%'};

n_pan_steps = 20; % pan operations per zoom level

fprintf('================================================================\n');
fprintf('  FastSense Zoom & Pan Latency Benchmark\n');
fprintf('  Per-frame timing with forced GPU flush (getframe)\n');
fprintf('================================================================\n\n');

for c = 1:numel(sizes)
    n = sizes(c);
    fprintf('====== %s points ======\n\n', labels{c});

    x = linspace(0, 100, n);
    y = sin(x * 2*pi / 10) + 0.5 * randn(1, n);

    % --- Standard plot() ---
    fig_std = figure('Visible', 'off', 'Position', [100 100 800 400]);
    ax_std = axes('Parent', fig_std);
    plot(ax_std, x, y);
    drawnow;

    fprintf('  %-6s | %-22s | %-22s\n', 'Zoom', 'plot() per-frame (ms)', 'FastSense per-frame (ms)');
    fprintf('  %-6s-+-%-22s-+-%-22s\n', '------', '----------------------', '----------------------');

    std_zoom_times = {};

    for zl = 1:numel(zoom_levels)
        frac = zoom_levels(zl);
        width = 100 * frac;

        % Pan across the data at this zoom level
        pan_starts = linspace(5, 95 - width, n_pan_steps);
        frame_times = zeros(1, n_pan_steps);

        for p = 1:n_pan_steps
            x0 = pan_starts(p);
            tic;
            set(ax_std, 'XLim', [x0, x0 + width]);
            drawnow;
            getframe(fig_std); % force GPU flush
            frame_times(p) = toc;
        end

        std_zoom_times{zl} = frame_times * 1000; % ms
    end

    close(fig_std);

    % --- FastSense ---
    fp = FastSense();
    fp.addLine(x, y, 'DisplayName', 'Signal');
    fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
    fp.addThreshold(-1.5, 'Direction', 'lower', 'ShowViolations', true, 'Color', 'r');
    fp.render();

    fp_zoom_times = {};

    for zl = 1:numel(zoom_levels)
        frac = zoom_levels(zl);
        width = 100 * frac;

        pan_starts = linspace(5, 95 - width, n_pan_steps);
        frame_times = zeros(1, n_pan_steps);

        for p = 1:n_pan_steps
            x0 = pan_starts(p);
            tic;
            set(fp.hAxes, 'XLim', [x0, x0 + width]);
            drawnow;
            getframe(fp.hFigure); % force GPU flush
            frame_times(p) = toc;
        end

        fp_zoom_times{zl} = frame_times * 1000; % ms
    end

    close(fp.hFigure);

    % Print results
    for zl = 1:numel(zoom_levels)
        st = std_zoom_times{zl};
        ft = fp_zoom_times{zl};
        fprintf('  %-6s | avg=%5.1f  p95=%5.1f     | avg=%5.1f  p95=%5.1f\n', ...
            zoom_labels{zl}, mean(st), prctile(st, 95), mean(ft), prctile(ft, 95));
    end
    fprintf('\n');

    % --- Pan stress test: continuous pan at deepest zoom ---
    fprintf('  Pan stress (0.1%% zoom, %d frames):\n', n_pan_steps);
    width = 100 * 0.001;

    % Standard
    fig_std = figure('Visible', 'off', 'Position', [100 100 800 400]);
    ax_std = axes('Parent', fig_std);
    plot(ax_std, x, y);
    drawnow;

    pan_starts = linspace(10, 80, n_pan_steps);
    std_pan = zeros(1, n_pan_steps);
    for p = 1:n_pan_steps
        x0 = pan_starts(p);
        tic;
        set(ax_std, 'XLim', [x0, x0 + width]);
        drawnow;
        getframe(fig_std);
        std_pan(p) = toc * 1000;
    end
    close(fig_std);

    % FastSense
    fp = FastSense();
    fp.addLine(x, y, 'DisplayName', 'Signal');
    fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
    fp.addThreshold(-1.5, 'Direction', 'lower', 'ShowViolations', true, 'Color', 'r');
    fp.render();

    fp_pan = zeros(1, n_pan_steps);
    for p = 1:n_pan_steps
        x0 = pan_starts(p);
        tic;
        set(fp.hAxes, 'XLim', [x0, x0 + width]);
        drawnow;
        getframe(fp.hFigure);
        fp_pan(p) = toc * 1000;
    end
    close(fp.hFigure);

    fprintf('    plot():    avg=%5.1f ms  p95=%5.1f ms  max=%5.1f ms\n', ...
        mean(std_pan), prctile(std_pan, 95), max(std_pan));
    fprintf('    FastSense:  avg=%5.1f ms  p95=%5.1f ms  max=%5.1f ms\n', ...
        mean(fp_pan), prctile(fp_pan, 95), max(fp_pan));

    std_fps = 1000 / mean(std_pan);
    fp_fps = 1000 / mean(fp_pan);
    fprintf('    Effective FPS:  plot()=%.0f  FastSense=%.0f\n', std_fps, fp_fps);
    fprintf('\n');

    clear x y fp;
end

fprintf('================================================================\n');
fprintf('  Notes\n');
fprintf('================================================================\n');
fprintf('  - getframe() forces GPU pipeline flush (true frame delivery).\n');
fprintf('  - At deep zoom (0.1%%), FastSense only processes ~0.1%% of data\n');
fprintf('    via binary search, while plot() still has all points in GPU.\n');
fprintf('  - "p95" = 95th percentile latency (worst-case interactive feel).\n');
fprintf('  - Target for smooth interaction: <33 ms (30 fps) per frame.\n');
fprintf('\n');
