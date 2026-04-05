%% FastSense Disk Storage Example — SQLite-backed large datasets
% Demonstrates how to use disk-backed storage to plot datasets that
% exceed available RAM. Data is stored in a temporary SQLite database
% and only the visible slice is loaded into memory on zoom/pan.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Automatic disk offload (default behaviour)
% In 'auto' mode (the default), FastSense stores data on disk when it
% exceeds MemoryLimit (default 500 MB = ~31M double-precision points).

fprintf('=== Auto mode: small data stays in memory ===\n');
n_small = 1e6;
x = linspace(0, 100, n_small);
y = sin(x) + 0.3 * randn(1, n_small);

fp1 = FastSense();  % StorageMode='auto', MemoryLimit=500e6
fp1.addLine(x, y, 'DisplayName', '1M pts (in memory)');
fp1.render();
title(fp1.hAxes, 'Auto Mode — 1M Points (in memory)');
fprintf('  1M points: stored in memory (%.1f MB < 500 MB limit)\n', ...
    n_small * 16 / 1e6);

%% 2. Force disk storage for any dataset size
fprintf('\n=== Disk mode: all data goes to SQLite ===\n');
n_medium = 5e6;
x = linspace(0, 500, n_medium);
y = sin(x / 20) .* cos(x / 7) + 0.2 * randn(1, n_medium);

tic;
fp2 = FastSense('StorageMode', 'disk');
fp2.addLine(x, y, 'DisplayName', '5M pts (disk)', 'Color', [0.8 0.2 0.1]);
fp2.addThreshold(1.0, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', 'r', 'LineStyle', '--', 'Label', 'Upper Limit');
fp2.addThreshold(-1.0, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', 'r', 'LineStyle', '--', 'Label', 'Lower Limit');
fp2.render();
fprintf('  5M points on disk: rendered in %.3f s\n', toc);
title(fp2.hAxes, 'Disk Mode — 5M Points (SQLite)');
clear x y;  % source arrays can be freed — data lives on disk

%% 3. Custom memory limit
fprintf('\n=== Custom MemoryLimit: offload above 10 MB ===\n');
n_mid = 2e6;
x = linspace(0, 200, n_mid);
y = cumsum(randn(1, n_mid)) / sqrt(n_mid);

fp3 = FastSense('MemoryLimit', 10e6);  % 10 MB threshold
fp3.addLine(x, y, 'DisplayName', '2M pts (auto-offloaded)', ...
    'Color', [0.1 0.6 0.3]);
fp3.render();
fprintf('  2M points (%.1f MB) > 10 MB limit => stored on disk\n', ...
    n_mid * 16 / 1e6);
title(fp3.hAxes, 'Custom MemoryLimit — 2M Points (auto-offloaded)');
clear x y;

%% 4. Direct DataStore usage for advanced workflows
fprintf('\n=== Direct FastSenseDataStore API ===\n');
n_large = 10e6;
x = linspace(0, 1000, n_large);
y = sin(x / 50) + 0.1 * randn(1, n_large);

fprintf('  Creating DataStore with %dM points...\n', n_large / 1e6);
tic;
ds = FastSenseDataStore(x, y);
fprintf('  Created in %.3f s\n', toc);
clear x y;

% Range query — fetch only data in [400, 410]
tic;
[xr, yr] = ds.getRange(400, 410);
fprintf('  getRange(400, 410): %d points in %.4f s\n', numel(xr), toc);

% Slice query — fetch points 5,000,000 to 5,010,000
tic;
[xs, ys] = ds.readSlice(5e6, 5e6 + 10000);
fprintf('  readSlice(5M, 5M+10K): %d points in %.4f s\n', numel(xs), toc);

% Extra columns (labels, flags, etc.)
labels = repmat({'normal'}, 1, n_large);
labels(abs(yr) > 1.5) = {'alert'};  % mark visible-range outliers
fprintf('  Adding extra column "status"...\n');
statusCol = repmat({'ok'}, 1, n_large);
ds.addColumn('status', statusCol);
vals = ds.getColumnSlice('status', 1, 5);
fprintf('  First 5 status values: %s\n', strjoin(vals, ', '));
fprintf('  Available columns: %s\n', strjoin(ds.listColumns(), ', '));

% findViolations — find threshold violations directly on disk-backed data.
% Skips chunks whose y_min/y_max can't contain violations, avoiding full reads.
tic;
[vx, vy] = ds.findViolations(1, n_large, 1.0, true);  % upper threshold at 1.0
fprintf('  findViolations(upper > 1.0): %d violations in %.4f s\n', numel(vx), toc);

ds.cleanup();  % explicit cleanup (also happens automatically on delete)
fprintf('  DataStore cleaned up.\n');

%% 5. Large dataset with zoom simulation
fprintf('\n=== Zoom simulation on 50M points ===\n');
n_zoom = 50e6;
x = linspace(0, 1000, n_zoom);
% Generate in chunks to avoid peak memory doubling
y = sin(x / 30);
chunkSz = 5e6;
for c = 1:chunkSz:n_zoom
    ce = min(c + chunkSz - 1, n_zoom);
    y(c:ce) = y(c:ce) + 0.2 * randn(1, ce - c + 1);
end

tic;
fp5 = FastSense('StorageMode', 'disk');
fp5.addLine(x, y, 'DisplayName', '50M pts (disk)', 'Color', [0.2 0.3 0.8]);
fp5.render();
tRender = toc;
clear x y;

fprintf('  50M points: rendered in %.3f s\n', tRender);
fprintf('  Memory footprint: only the visible slice (~4K points) is in RAM.\n');
fprintf('  Try zooming in — each pan/zoom fetches only the needed chunks.\n');
title(fp5.hAxes, sprintf('Disk Storage — 50M Points (rendered in %.2fs)', tRender));

fprintf('\nDone! All figures are interactive — zoom and pan to explore.\n');
