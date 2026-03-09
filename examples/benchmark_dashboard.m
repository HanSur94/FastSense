%% FastPlot Dashboard Benchmark — Figure/Dashboard creation time
% Compares FastPlotFigure dashboard creation vs standard subplot() approach.
% Tests single-plot, 2x2, and 3x3 layouts at multiple data sizes.

run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'libs', 'FastPlot', 'private'));

sizes  = [1e4, 1e5, 1e6, 5e6, 10e6];
labels = {'10K', '100K', '1M', '5M', '10M'};

layouts = {
    [1 1], '1x1 (single)';
    [2 2], '2x2 (4 tiles)';
    [3 3], '3x3 (9 tiles)';
};

n_sizes   = numel(sizes);
n_layouts = size(layouts, 1);
n_warmup  = 1;
n_reps    = 3;

% Result arrays: [layout x size]
t_std_create = NaN(n_layouts, n_sizes);
t_std_render = NaN(n_layouts, n_sizes);
t_fp_create  = NaN(n_layouts, n_sizes);
t_fp_render  = NaN(n_layouts, n_sizes);
pts_std      = NaN(n_layouts, n_sizes);
pts_fp       = NaN(n_layouts, n_sizes);

fprintf('================================================================\n');
fprintf('  FastPlot Dashboard Benchmark\n');
fprintf('  Figure/dashboard creation time: FastPlotFigure vs subplot()\n');
fprintf('  %d warmup + %d timed reps per config\n', n_warmup, n_reps);
fprintf('================================================================\n\n');

for L = 1:n_layouts
    grid_rc = layouts{L, 1};
    rows = grid_rc(1);
    cols = grid_rc(2);
    nTiles = rows * cols;
    layout_name = layouts{L, 2};

    fprintf('===== Layout: %s =====\n\n', layout_name);

    for S = 1:n_sizes
        n = sizes(S);
        fprintf('--- %s points per tile (%d tiles, %.1fM total) ---\n', ...
            labels{S}, nTiles, nTiles * n / 1e6);

        % Pre-generate data for all tiles
        x = linspace(0, 100, n);
        Y = cell(1, nTiles);
        for t = 1:nTiles
            Y{t} = sin(x * 2*pi / (8 + t)) + 0.5 * randn(1, n);
        end

        % ======== Standard subplot() ========
        times_std = NaN(1, n_warmup + n_reps);
        for rep = 1:(n_warmup + n_reps)
            tic;
            fig_std = figure('Visible', 'off');
            h_lines = cell(1, nTiles);
            for t = 1:nTiles
                ax = subplot(rows, cols, t, 'Parent', fig_std);
                h_lines{t} = plot(ax, x, Y{t});
                title(ax, sprintf('Channel %d', t));
                if t > nTiles - cols
                    xlabel(ax, 'Time (s)');
                end
            end
            t_create = toc;

            tic;
            drawnow;
            t_render = toc;

            times_std(rep) = t_create + t_render;
            if rep == n_warmup + n_reps
                total_pts = 0;
                for t = 1:nTiles
                    total_pts = total_pts + numel(get(h_lines{t}, 'XData'));
                end
                pts_std(L, S) = total_pts;
            end
            close(fig_std);
        end
        t_std_create(L, S) = mean(times_std(n_warmup+1:end));

        % ======== FastPlotFigure ========
        times_fp = NaN(1, n_warmup + n_reps);
        for rep = 1:(n_warmup + n_reps)
            tic;
            fig_fp = FastPlotFigure(rows, cols, 'Theme', 'dark');
            for t = 1:nTiles
                fp = fig_fp.tile(t);
                fp.addLine(x, Y{t}, 'DisplayName', sprintf('Ch%d', t));
                fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true);
                fp.addThreshold(-1.5, 'Direction', 'lower', 'ShowViolations', true);
            end
            t_create = toc;

            tic;
            fig_fp.renderAll();
            t_render = toc;

            times_fp(rep) = t_create + t_render;
            if rep == n_warmup + n_reps
                total_pts = 0;
                for t = 1:nTiles
                    tile_fp = fig_fp.Tiles{t};
                    total_pts = total_pts + numel(get(tile_fp.Lines(1).hLine, 'XData'));
                end
                pts_fp(L, S) = total_pts;
            end
            close(fig_fp.hFigure);
        end
        t_fp_create(L, S) = mean(times_fp(n_warmup+1:end));

        reduction = (1 - pts_fp(L,S) / pts_std(L,S)) * 100;
        speedup = t_std_create(L,S) / t_fp_create(L,S);
        fprintf('  subplot():        %7.3f s  (%d pts total)\n', t_std_create(L,S), pts_std(L,S));
        fprintf('  FastPlotFigure:   %7.3f s  (%d pts total, %.1f%% reduction)\n', ...
            t_fp_create(L,S), pts_fp(L,S), reduction);
        if speedup >= 1
            fprintf('  FastPlot is %.1fx FASTER\n', speedup);
        else
            fprintf('  FastPlot is %.1fx slower (threshold+downsample overhead)\n', 1/speedup);
        end
        fprintf('\n');

        clear Y;
    end
end

% ---- Summary tables per layout ----
fprintf('================================================================\n');
fprintf('  Summary Tables\n');
fprintf('================================================================\n\n');

for L = 1:n_layouts
    layout_name = layouts{L, 2};
    fprintf('--- %s ---\n', layout_name);
    fprintf('%-6s | %11s | %11s | %8s | %9s\n', ...
        'Size', 'subplot()', 'FastPlotFig', 'Speedup', 'Pt Reduc.');
    fprintf('%-6s-+-%-11s-+-%-11s-+-%-8s-+-%-9s\n', ...
        '------', '-----------', '-----------', '--------', '---------');
    for S = 1:n_sizes
        speedup = t_std_create(L,S) / t_fp_create(L,S);
        reduction = (1 - pts_fp(L,S) / pts_std(L,S)) * 100;
        if speedup >= 1
            sp_str = sprintf('%.1fx', speedup);
        else
            sp_str = sprintf('%.1fx slow', 1/speedup);
        end
        fprintf('%-6s | %9.3f s | %9.3f s | %8s | %7.1f%%\n', ...
            labels{S}, t_std_create(L,S), t_fp_create(L,S), sp_str, reduction);
    end
    fprintf('\n');
end

% ---- Plot results ----
fig = figure('Name', 'Dashboard Benchmark', 'Position', [100 100 1600 500]);

for L = 1:n_layouts
    subplot(1, n_layouts, L);
    loglog(sizes, t_std_create(L,:), 'ro-', 'LineWidth', 2, 'DisplayName', 'subplot()');
    hold on;
    loglog(sizes, t_fp_create(L,:), 'bs-', 'LineWidth', 2, 'DisplayName', 'FastPlotFigure');
    xlabel('Points per tile');
    ylabel('Total creation time (s)');
    title(layouts{L, 2});
    legend('Location', 'northwest');
    grid on;
end

fprintf('Dashboard benchmark complete.\n');
