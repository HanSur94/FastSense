%% benchmark_20_dashboards.m — Create 20 dashboards with 3x3 tiles
%
% Each dashboard has 9 tiles with 500K points per tile (4.5M total per
% dashboard, 90M points across all 20). Tests rendering speed and
% downsampling performance at scale.
%
% Usage:
%   >> cd /path/to/FastPlot
%   >> run examples/benchmark_20_dashboards.m

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

nDashboards = 20;
nPointsPerTile = 10000000;
nTiles = 9;
totalPtsPerDash = nTiles * nPointsPerTile;

fprintf('\n================================================================\n');
fprintf('  FastPlot Benchmark: %d Dashboards x 3x3 tiles\n', nDashboards);
fprintf('  %.0fM points per tile, %.0fM per dashboard, %.0fM total\n', ...
    nPointsPerTile/1e6, totalPtsPerDash/1e6, nDashboards*totalPtsPerDash/1e6);
fprintf('================================================================\n\n');

% Signal configs: name, frequency multiplier, offset, noise scale
signals = {
    'Temperature',   10,   72,  1.5;
    'Pressure',      20,  101,  3.0;
    'Flow Rate',     15,   45,  2.5;
    'Motor Current',  8,    3,  0.8;
    'Vibration',     50,    0,  0.4;
    'Humidity',      30,   55,  5.0;
    'RPM',           12, 1500, 50.0;
    'Oxygen',        25,   20,  1.5;
    'Power',         18,  220,  8.0;
};

colors = [
    0.3 0.7 1.0;
    1.0 0.5 0.3;
    0.3 0.9 0.4;
    0.9 0.6 0.1;
    0.8 0.3 0.8;
    0.2 0.8 0.8;
    1.0 0.8 0.2;
    0.5 0.9 0.5;
    0.6 0.3 0.9;
];

times_create = zeros(1, nDashboards);
times_render = zeros(1, nDashboards);
pts_rendered = zeros(1, nDashboards);

x = linspace(0, 3600, nPointsPerTile);

for d = 1:nDashboards
    % --- Create dashboard and add data ---
    tic;
    fig = FastPlotFigure(3, 3, 'Theme', 'dark', ...
        'Name', sprintf('Dashboard %d/%d', d, nDashboards));

    for t = 1:nTiles
        fp = fig.tile(t);
        freq = signals{t, 2};
        offset = signals{t, 3};
        noise = signals{t, 4};
        % Vary signal slightly per dashboard
        phase = d * 0.3;
        y = offset + (noise*3)*sin(x*2*pi/freq + phase) + noise*randn(1, nPointsPerTile);

        fp.addLine(x, y, 'DisplayName', signals{t,1}, 'Color', colors(t,:));
        fp.addThreshold(offset + noise*6, 'Direction', 'upper', 'ShowViolations', true);
    end
    t_create = toc;

    % --- Render ---
    tic;
    fig.renderAll();
    drawnow;
    t_render = toc;

    % Count rendered points
    total_pts = 0;
    for t = 1:nTiles
        tile_fp = fig.Tiles{t};
        total_pts = total_pts + numel(get(tile_fp.Lines(1).hLine, 'XData'));
    end
    pts_rendered(d) = total_pts;

    times_create(d) = t_create;
    times_render(d) = t_render;
    t_total = t_create + t_render;

    reduction = (1 - total_pts / totalPtsPerDash) * 100;
    fprintf('  Dashboard %2d/%d: create %.3fs + render %.3fs = %.3fs  (%d pts rendered, %.1f%% reduction)\n', ...
        d, nDashboards, t_create, t_render, t_total, total_pts, reduction);

    close(fig.hFigure);
end

% --- Summary ---
fprintf('\n================================================================\n');
fprintf('  Summary\n');
fprintf('================================================================\n\n');

avg_create = mean(times_create);
avg_render = mean(times_render);
avg_total  = avg_create + avg_render;
avg_pts    = mean(pts_rendered);
avg_reduction = (1 - avg_pts / totalPtsPerDash) * 100;

fprintf('  Dashboards:        %d\n', nDashboards);
fprintf('  Tiles per dash:    %d (3x3)\n', nTiles);
fprintf('  Points per tile:   %.0fM\n', nPointsPerTile/1e6);
fprintf('  Total points:      %.0fM\n', nDashboards * totalPtsPerDash / 1e6);
fprintf('\n');
fprintf('  Avg create time:   %.3f s\n', avg_create);
fprintf('  Avg render time:   %.3f s\n', avg_render);
fprintf('  Avg total time:    %.3f s\n', avg_total);
fprintf('  Min total time:    %.3f s\n', min(times_create + times_render));
fprintf('  Max total time:    %.3f s\n', max(times_create + times_render));
fprintf('\n');
fprintf('  Avg pts rendered:  %d / %d (%.1f%% reduction)\n', ...
    round(avg_pts), totalPtsPerDash, avg_reduction);
fprintf('  Throughput:        %.1f dashboards/s\n', 1/avg_total);
fprintf('  Throughput:        %.1fM pts/s\n', totalPtsPerDash/1e6/avg_total);
fprintf('\n');
fprintf('  Total wall time:   %.1f s for %d dashboards\n', ...
    sum(times_create + times_render), nDashboards);
fprintf('\n================================================================\n');
