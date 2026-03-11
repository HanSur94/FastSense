%% FastPlot Feature Benchmark — Theme, Band, Shaded, Fill, Marker, Dashboard
% Measures overhead of each new feature vs baseline FastPlot rendering.
%
% Tests:
%   1. FastPlotTheme creation overhead
%   2. addBand rendering cost (constant-y fill — trivial geometry)
%   3. addShaded rendering + zoom cost (data-driven fill — downsampled)
%   4. addFill rendering + zoom cost (area under curve)
%   5. addMarker rendering cost
%   6. FastPlotFigure tiled dashboard overhead
%   7. Combined: all features together vs baseline

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'libs', 'FastPlot', 'private'));

sizes  = [1e4, 1e5, 1e6, 5e6, 10e6];
labels = {'10K', '100K', '1M', '5M', '10M'};
n_zooms = 20;

n_cases = numel(sizes);

% Timing arrays
t_theme_create = NaN(1, 5);   % theme creation (5 presets)
t_baseline     = NaN(1, n_cases);  % FastPlot + addLine + render
t_band         = NaN(1, n_cases);  % + 4 bands
t_shaded       = NaN(1, n_cases);  % + shaded region
t_fill         = NaN(1, n_cases);  % + fill region
t_marker       = NaN(1, n_cases);  % + markers
t_combined     = NaN(1, n_cases);  % all features together
t_dashboard    = NaN(1, n_cases);  % 2x2 dashboard with all features

t_baseline_zoom = NaN(1, n_cases);
t_shaded_zoom   = NaN(1, n_cases);
t_combined_zoom = NaN(1, n_cases);

fprintf('================================================================\n');
fprintf('  FastPlot Feature Benchmark\n');
fprintf('  Render + %d zoom ops per size\n', n_zooms);
fprintf('================================================================\n\n');

% ---- Test 1: Theme creation overhead ----
fprintf('--- Theme Creation ---\n');
presets = {'default', 'dark', 'light', 'industrial', 'scientific'};
for i = 1:5
    tic;
    for rep = 1:10000
        t = FastPlotTheme(presets{i});
    end
    t_theme_create(i) = toc / 10000;
end
fprintf('  10K calls each: default=%.1f us, dark=%.1f us, light=%.1f us, industrial=%.1f us, scientific=%.1f us\n', ...
    t_theme_create * 1e6);
fprintf('  Theme creation is negligible (~%.0f us per call)\n\n', mean(t_theme_create) * 1e6);

% ---- Tests 2-7: Feature benchmarks at each data size ----
for c = 1:n_cases
    n = sizes(c);
    fprintf('--- %s points ---\n', labels{c});

    x = linspace(0, 100, n);
    y = sin(x * 2*pi / 10) + 0.5 * randn(1, n);
    envelope_hi = sin(x * 2*pi / 10) + 0.8;
    envelope_lo = sin(x * 2*pi / 10) - 0.8;

    % Random zoom windows
    zoom_centers = 10 + 80 * rand(1, n_zooms);
    zoom_widths  = 1 + 20 * rand(1, n_zooms);

    % Event markers (fixed count, independent of data size)
    event_x = linspace(5, 95, 50);
    event_y = interp1(x, y, event_x);

    % ---- Baseline: addLine only ----
    tic;
    fp = FastPlot();
    fp.addLine(x, y, 'DisplayName', 'Signal');
    fp.render();
    t_baseline(c) = toc;

    tic;
    for z = 1:n_zooms
        zc = zoom_centers(z); zw = zoom_widths(z);
        set(fp.hAxes, 'XLim', [zc - zw/2, zc + zw/2]);
        drawnow;
    end
    t_baseline_zoom(c) = toc;
    close(fp.hFigure);

    % ---- addBand: 4 bands (trivial geometry) ----
    tic;
    fp = FastPlot();
    fp.addLine(x, y, 'DisplayName', 'Signal');
    fp.addBand(60, 65, 'FaceColor', [1 0.8 0.3], 'FaceAlpha', 0.2, 'Label', 'Warning');
    fp.addBand(65, 75, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.2, 'Label', 'Alarm');
    fp.addBand(35, 40, 'FaceColor', [1 0.8 0.3], 'FaceAlpha', 0.2, 'Label', 'Low Warn');
    fp.addBand(25, 35, 'FaceColor', [0.3 0.3 1], 'FaceAlpha', 0.2, 'Label', 'Low Alarm');
    fp.render();
    t_band(c) = toc;
    close(fp.hFigure);

    % ---- addShaded: confidence envelope ----
    tic;
    fp = FastPlot();
    fp.addLine(x, y, 'DisplayName', 'Signal');
    fp.addShaded(x, envelope_hi, envelope_lo, 'FaceColor', [0.2 0.5 0.9], 'FaceAlpha', 0.15);
    fp.render();
    t_shaded(c) = toc;

    tic;
    for z = 1:n_zooms
        zc = zoom_centers(z); zw = zoom_widths(z);
        set(fp.hAxes, 'XLim', [zc - zw/2, zc + zw/2]);
        drawnow;
    end
    t_shaded_zoom(c) = toc;
    close(fp.hFigure);

    % ---- addFill: area under curve ----
    y_abs = abs(y);
    tic;
    fp = FastPlot();
    fp.addLine(x, y_abs, 'DisplayName', 'Signal');
    fp.addFill(x, y_abs, 'FaceColor', [0.2 0.7 0.3], 'FaceAlpha', 0.3);
    fp.render();
    t_fill(c) = toc;
    close(fp.hFigure);

    % ---- addMarker: 50 event markers ----
    tic;
    fp = FastPlot();
    fp.addLine(x, y, 'DisplayName', 'Signal');
    fp.addMarker(event_x, event_y, 'Marker', 'v', 'MarkerSize', 10, ...
        'Color', [0.9 0.2 0.2], 'Label', 'Anomaly');
    fp.render();
    t_marker(c) = toc;
    close(fp.hFigure);

    % ---- Combined: all features together ----
    tic;
    fp = FastPlot('Theme', 'light');
    fp.addLine(x, y, 'DisplayName', 'Signal');
    fp.addBand(60, 65, 'FaceColor', [1 0.8 0.3], 'FaceAlpha', 0.2);
    fp.addBand(65, 75, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.2);
    fp.addShaded(x, envelope_hi, envelope_lo, 'FaceColor', [0.2 0.5 0.9], 'FaceAlpha', 0.15);
    fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true);
    fp.addMarker(event_x, event_y, 'Marker', 'v', 'MarkerSize', 10, 'Color', [1 0.3 0.3]);
    fp.render();
    t_combined(c) = toc;

    tic;
    for z = 1:n_zooms
        zc = zoom_centers(z); zw = zoom_widths(z);
        set(fp.hAxes, 'XLim', [zc - zw/2, zc + zw/2]);
        drawnow;
    end
    t_combined_zoom(c) = toc;
    close(fp.hFigure);

    % ---- Dashboard: 2x2 with all features ----
    tic;
    fig = FastPlotFigure(2, 2, 'Theme', 'light', 'Name', 'Bench');
    fp1 = fig.tile(1); fp1.addLine(x, y); fp1.addBand(60, 65, 'FaceColor', [1 0.8 0.3]);
    fp2 = fig.tile(2); fp2.addLine(x, y); fp2.addShaded(x, envelope_hi, envelope_lo);
    fp3 = fig.tile(3); fp3.addLine(x, y_abs); fp3.addFill(x, y_abs, 'FaceColor', [0.2 0.7 0.3]);
    fp4 = fig.tile(4); fp4.addLine(x, y); fp4.addMarker(event_x, event_y, 'Marker', 'v', 'Color', [1 0 0]);
    fig.renderAll();
    t_dashboard(c) = toc;
    close(fig.hFigure);

    % Report
    overhead_band     = (t_band(c) / t_baseline(c) - 1) * 100;
    overhead_shaded   = (t_shaded(c) / t_baseline(c) - 1) * 100;
    overhead_fill     = (t_fill(c) / t_baseline(c) - 1) * 100;
    overhead_marker   = (t_marker(c) / t_baseline(c) - 1) * 100;
    overhead_combined = (t_combined(c) / t_baseline(c) - 1) * 100;

    fprintf('  Baseline (line only):     %7.3f s\n', t_baseline(c));
    fprintf('  + 4 Bands:                %7.3f s  (%+.1f%%)\n', t_band(c), overhead_band);
    fprintf('  + Shaded region:          %7.3f s  (%+.1f%%)\n', t_shaded(c), overhead_shaded);
    fprintf('  + Fill:                   %7.3f s  (%+.1f%%)\n', t_fill(c), overhead_fill);
    fprintf('  + 50 Markers:             %7.3f s  (%+.1f%%)\n', t_marker(c), overhead_marker);
    fprintf('  Combined (all features):  %7.3f s  (%+.1f%%)\n', t_combined(c), overhead_combined);
    fprintf('  Dashboard (2x2, 4 tiles): %7.3f s\n', t_dashboard(c));
    fprintf('  Zoom %2dx: baseline=%7.3f s  shaded=%7.3f s  combined=%7.3f s\n', ...
        n_zooms, t_baseline_zoom(c), t_shaded_zoom(c), t_combined_zoom(c));
    fprintf('\n');

    clear x y envelope_hi envelope_lo y_abs fp fig;
end

% ---- Summary tables ----
fprintf('================================================================\n');
fprintf('  Render Time Summary (seconds)\n');
fprintf('================================================================\n\n');

fprintf('%-6s | %-9s | %-9s | %-9s | %-9s | %-9s | %-9s | %-9s\n', ...
    'Size', 'Baseline', '+Bands', '+Shaded', '+Fill', '+Markers', 'Combined', 'Dashboard');
fprintf('%-6s-+-%-9s-+-%-9s-+-%-9s-+-%-9s-+-%-9s-+-%-9s-+-%-9s\n', ...
    '------', '---------', '---------', '---------', '---------', '---------', '---------', '---------');
for c = 1:n_cases
    fprintf('%-6s | %7.3f s | %7.3f s | %7.3f s | %7.3f s | %7.3f s | %7.3f s | %7.3f s\n', ...
        labels{c}, t_baseline(c), t_band(c), t_shaded(c), t_fill(c), ...
        t_marker(c), t_combined(c), t_dashboard(c));
end

fprintf('\n');
fprintf('================================================================\n');
fprintf('  Zoom Time Summary (%d ops, seconds)\n', n_zooms);
fprintf('================================================================\n\n');

fprintf('%-6s | %-9s | %-9s | %-9s\n', 'Size', 'Baseline', '+Shaded', 'Combined');
fprintf('%-6s-+-%-9s-+-%-9s-+-%-9s\n', '------', '---------', '---------', '---------');
for c = 1:n_cases
    fprintf('%-6s | %7.3f s | %7.3f s | %7.3f s\n', ...
        labels{c}, t_baseline_zoom(c), t_shaded_zoom(c), t_combined_zoom(c));
end

fprintf('\n');
fprintf('================================================================\n');
fprintf('  Feature Overhead Summary (%% over baseline)\n');
fprintf('================================================================\n\n');

fprintf('%-6s | %-9s | %-9s | %-9s | %-9s | %-9s\n', ...
    'Size', 'Bands', 'Shaded', 'Fill', 'Markers', 'Combined');
fprintf('%-6s-+-%-9s-+-%-9s-+-%-9s-+-%-9s-+-%-9s\n', ...
    '------', '---------', '---------', '---------', '---------', '---------');
for c = 1:n_cases
    fprintf('%-6s | %+7.1f %% | %+7.1f %% | %+7.1f %% | %+7.1f %% | %+7.1f %%\n', ...
        labels{c}, ...
        (t_band(c)/t_baseline(c) - 1)*100, ...
        (t_shaded(c)/t_baseline(c) - 1)*100, ...
        (t_fill(c)/t_baseline(c) - 1)*100, ...
        (t_marker(c)/t_baseline(c) - 1)*100, ...
        (t_combined(c)/t_baseline(c) - 1)*100);
end

fprintf('\nBenchmark complete.\n');
