%% FastSense Benchmark — Compare FastSense vs standard plot()
% Measures render time, zoom stress, point reduction, and memory footprint.
%
% NOTE: Octave's Qt/OpenGL backend clips lines in hardware, making raw
% plot() very fast even with millions of points. FastSense's interpreted
% downsampling adds overhead in Octave. The primary wins are:
%   1. Point reduction (99%+ fewer points in the pipeline)
%   2. Lower GPU memory usage (critical when datasets exceed VRAM)
%   3. Threshold + violation markers (not available with standard plot)
%   4. Linked axes with automatic re-downsample
% In MATLAB (with JIT compilation), the downsampling cost is much lower.

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'libs', 'FastSense', 'private'));

sizes = [1e4, 1e5, 1e6, 5e6, 10e6, 50e6];
labels = {'10K', '100K', '1M', '5M', '10M', '50M'};
n_zooms = 20;

n_cases = numel(sizes);
t_std_init    = NaN(1, n_cases); % figure + axes + plot() call
t_std_render  = NaN(1, n_cases); % drawnow after plot()
t_fp_init     = NaN(1, n_cases); % FastSense() + addLine + addThreshold
t_fp_render   = NaN(1, n_cases); % render() + drawnow
t_std_zoom    = NaN(1, n_cases);
t_fp_zoom     = NaN(1, n_cases);
pts_std       = NaN(1, n_cases);
pts_fp        = NaN(1, n_cases);
mem_std_MB    = NaN(1, n_cases);
mem_fp_MB     = NaN(1, n_cases);
t_fp_ds       = NaN(1, n_cases); % downsampling time only

fprintf('================================================================\n');
fprintf('  FastSense Benchmark\n');
fprintf('  Initial render + %d zoom ops + point reduction + memory\n', n_zooms);
fprintf('================================================================\n\n');

for c = 1:n_cases
    n = sizes(c);
    fprintf('--- %s points ---\n', labels{c});

    x = linspace(0, 100, n);
    y = sin(x * 2*pi / 10) + 0.5 * randn(1, n);
    data_MB = n * 8 * 2 / 1e6; % X + Y, 8 bytes each

    % Random zoom windows
    zoom_centers = 10 + 80 * rand(1, n_zooms);
    zoom_widths  = 1 + 20 * rand(1, n_zooms);

    % ======== Standard plot() ========
    tic;
    fig_std = figure('Visible', 'off');
    ax_std = axes('Parent', fig_std);
    h_std = plot(ax_std, x, y);
    t_std_init(c) = toc;

    tic;
    drawnow;
    t_std_render(c) = toc;
    pts_std(c) = numel(get(h_std, 'XData'));
    mem_std_MB(c) = pts_std(c) * 8 * 2 / 1e6; % XData + YData in GPU

    tic;
    for z = 1:n_zooms
        zc = zoom_centers(z);
        zw = zoom_widths(z);
        set(ax_std, 'XLim', [zc - zw/2, zc + zw/2]);
        drawnow;
    end
    t_std_zoom(c) = toc;
    close(fig_std);

    % ======== Downsampling cost only (no rendering) ========
    tic;
    [~, ~] = minmax_downsample(x, y, 1000);
    t_fp_ds(c) = toc;

    % ======== FastSense ========
    tic;
    fp = FastSense();
    fp.addLine(x, y, 'DisplayName', 'Signal');
    fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
    fp.addThreshold(-1.5, 'Direction', 'lower', 'ShowViolations', true, 'Color', 'r');
    t_fp_init(c) = toc;

    tic;
    fp.render();
    t_fp_render(c) = toc;
    pts_fp(c) = numel(get(fp.Lines(1).hLine, 'XData'));
    mem_fp_MB(c) = pts_fp(c) * 8 * 2 / 1e6;

    tic;
    for z = 1:n_zooms
        zc = zoom_centers(z);
        zw = zoom_widths(z);
        set(fp.hAxes, 'XLim', [zc - zw/2, zc + zw/2]);
        drawnow;
    end
    t_fp_zoom(c) = toc;
    close(fp.hFigure);

    reduction = (1 - pts_fp(c)/pts_std(c)) * 100;
    fprintf('  Init:         plot()=%7.3fs  FastSense=%7.3fs\n', t_std_init(c), t_fp_init(c));
    fprintf('  Render:       plot()=%7.3fs  FastSense=%7.3fs\n', t_std_render(c), t_fp_render(c));
    fprintf('  Total:        plot()=%7.3fs  FastSense=%7.3fs\n', t_std_init(c)+t_std_render(c), t_fp_init(c)+t_fp_render(c));
    fprintf('  %2d zooms:     plot()=%7.3fs  FastSense=%7.3fs\n', n_zooms, t_std_zoom(c), t_fp_zoom(c));
    fprintf('  Downsample:   %.3fs (pure computation, no rendering)\n', t_fp_ds(c));
    fprintf('  GPU points:   plot()=%-10d  FastSense=%-6d  (%.1f%% reduction)\n', pts_std(c), pts_fp(c), reduction);
    fprintf('  GPU memory:   plot()=%7.1f MB  FastSense=%7.3f MB\n', mem_std_MB(c), mem_fp_MB(c));
    fprintf('\n');

    clear x y fp;
end

% ---- Summary table ----
fprintf('================================================================\n');
fprintf('  Summary Table\n');
fprintf('================================================================\n\n');

fprintf('%-6s | %-9s | %-9s | %-9s | %-9s | %-9s | %-9s | %-11s | %-11s | %-6s\n', ...
    'Size', 'Std Init', 'FP Init', 'Std Rndr', 'FP Rndr', 'Std Zoom', 'FP Zoom', 'Std GPU MB', 'FP GPU MB', 'Reduc.');
fprintf('%-6s-+-%-9s-+-%-9s-+-%-9s-+-%-9s-+-%-9s-+-%-9s-+-%-11s-+-%-11s-+-%-6s\n', ...
    '------', '---------', '---------', '---------', '---------', '---------', '---------', '-----------', '-----------', '------');
for c = 1:n_cases
    reduction = (1 - pts_fp(c)/pts_std(c)) * 100;
    fprintf('%-6s | %7.3f s | %7.3f s | %7.3f s | %7.3f s | %7.3f s | %7.3f s | %9.1f MB | %9.3f MB | %4.1f%%\n', ...
        labels{c}, t_std_init(c), t_fp_init(c), t_std_render(c), t_fp_render(c), ...
        t_std_zoom(c), t_fp_zoom(c), mem_std_MB(c), mem_fp_MB(c), reduction);
end

fprintf('\n');
fprintf('Key takeaways:\n');
fprintf('  - FastSense reduces GPU pipeline data by 91-100%%\n');
fprintf('  - At 50M points: %.1f MB in pipeline vs %.3f MB (%.0fx reduction)\n', ...
    mem_std_MB(end), mem_fp_MB(end), mem_std_MB(end)/mem_fp_MB(end));
fprintf('  - FastSense adds threshold lines + color-coded violation markers\n');
fprintf('  - Octave Qt/OpenGL backend clips efficiently in hardware,\n');
fprintf('    so raw plot() zoom appears fast despite pushing all points.\n');
fprintf('  - In MATLAB (JIT-compiled), downsampling overhead is much lower.\n');
fprintf('\n');

% ---- Plot results ----
fig = figure('Name', 'FastSense Benchmark', 'Position', [100 100 1800 800]);

subplot(2,3,1);
loglog(sizes, t_std_init, 'ro-', 'LineWidth', 2, 'DisplayName', 'plot()');
hold on;
loglog(sizes, t_fp_init, 'bs-', 'LineWidth', 2, 'DisplayName', 'FastSense');
xlabel('Data points');
ylabel('Time (s)');
title('Instantiation Time');
legend('Location', 'northwest');
grid on;

subplot(2,3,2);
loglog(sizes, t_std_render, 'ro-', 'LineWidth', 2, 'DisplayName', 'plot()');
hold on;
loglog(sizes, t_fp_render, 'bs-', 'LineWidth', 2, 'DisplayName', 'FastSense');
xlabel('Data points');
ylabel('Time (s)');
title('Render Time (drawnow)');
legend('Location', 'northwest');
grid on;

subplot(2,3,3);
loglog(sizes, t_std_init + t_std_render, 'ro-', 'LineWidth', 2, 'DisplayName', 'plot()');
hold on;
loglog(sizes, t_fp_init + t_fp_render, 'bs-', 'LineWidth', 2, 'DisplayName', 'FastSense');
xlabel('Data points');
ylabel('Time (s)');
title('Total Time (Init + Render)');
legend('Location', 'northwest');
grid on;

subplot(2,3,4);
loglog(sizes, t_std_zoom, 'ro-', 'LineWidth', 2, 'DisplayName', 'plot()');
hold on;
loglog(sizes, t_fp_zoom, 'bs-', 'LineWidth', 2, 'DisplayName', 'FastSense');
loglog(sizes, t_fp_ds, 'g^--', 'LineWidth', 1.5, 'DisplayName', 'Downsample only');
xlabel('Data points');
ylabel('Time (s)');
title(sprintf('%d Zoom Operations', n_zooms));
legend('Location', 'northwest');
grid on;

subplot(2,3,5);
loglog(sizes, mem_std_MB, 'ro-', 'LineWidth', 2, 'DisplayName', 'plot()');
hold on;
loglog(sizes, mem_fp_MB, 'bs-', 'LineWidth', 2, 'DisplayName', 'FastSense');
xlabel('Data points');
ylabel('GPU Memory (MB)');
title('GPU Pipeline Memory');
legend('Location', 'northwest');
grid on;

subplot(2,3,6);
reduction_pct = (1 - pts_fp ./ pts_std) * 100;
semilogx(sizes, reduction_pct, 'ks-', 'LineWidth', 2, 'MarkerFaceColor', 'k');
xlabel('Data points');
ylabel('Reduction (%)');
title('Point Reduction');
ylim([0 100]);
grid on;

fprintf('Benchmark complete.\n');
