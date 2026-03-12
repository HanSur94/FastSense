function benchmark_datastore()
%BENCHMARK_DATASTORE Compare raw .mat loading vs SQLite-backed DataStore.
%   Measures: write time, range query time, slice read time, memory usage,
%   and disk footprint across multiple dataset sizes.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    setup();

    sizes = [1e4, 1e5, 1e6, 5e6, 10e6, 20e6];
    labels = {'10K', '100K', '1M', '5M', '10M', '20M'};

    fprintf('\n============================================================\n');
    fprintf('  FastPlot DataStore Benchmark: .mat vs SQLite vs Binary\n');
    fprintf('============================================================\n\n');

    hasSqlite = (exist('mksqlite', 'file') == 3);
    if hasSqlite
        fprintf('  mksqlite: AVAILABLE (SQLite backend will be used)\n');
    else
        fprintf('  mksqlite: NOT FOUND (binary fallback will be used)\n');
    end
    fprintf('  Octave %s on %s\n\n', version(), computer());

    % Header
    fprintf('%-6s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s\n', ...
        'Size', 'MAT Save', 'MAT Load', 'DS Create', 'DS Range', 'DS Slice', 'MAT Disk', 'DS Disk');
    fprintf('%s\n', repmat('-', 1, 95));

    for i = 1:numel(sizes)
        n = sizes(i);
        label = labels{i};

        % Generate test data
        x = linspace(0, 1000, n);
        y = sin(x / 50) + 0.1 * randn(1, n);

        matFile = [tempname, '.mat'];
        rawBytes = n * 8 * 2;  % X + Y as doubles

        % --- .mat save ---
        tic;
        save(matFile, 'x', 'y', '-v7');
        tMatSave = toc;

        matDisk = dir(matFile);
        matDiskMB = matDisk.bytes / 1e6;

        % --- .mat load ---
        clear xLoaded yLoaded;
        tic;
        loaded = load(matFile);
        tMatLoad = toc;
        xLoaded = loaded.x;
        yLoaded = loaded.y;
        clear loaded;

        % --- DataStore create (SQLite or binary) ---
        tic;
        ds = FastPlotDataStore(x, y);
        tDsCreate = toc;

        % DataStore disk size
        if ~isempty(ds.DbPath) && exist(ds.DbPath, 'file')
            dsDisk = dir(ds.DbPath);
            dsDiskMB = dsDisk.bytes / 1e6;
        elseif ~isempty(ds.BinPath) && exist(ds.BinPath, 'file')
            dsDisk = dir(ds.BinPath);
            dsDiskMB = dsDisk.bytes / 1e6;
        else
            dsDiskMB = 0;
        end

        % --- DataStore range query (simulate zoom to 1% of data) ---
        xMid = 500;
        xSpan = 5;  % 0.5% of total range
        nRangeRuns = 5;
        tic;
        for r = 1:nRangeRuns
            [xr, yr] = ds.getRange(xMid - xSpan, xMid + xSpan);
        end
        tDsRange = toc / nRangeRuns;

        % --- DataStore slice read (read 10K points) ---
        sliceSize = min(10000, n);
        sliceStart = max(1, floor(n/2) - floor(sliceSize/2));
        sliceEnd = sliceStart + sliceSize - 1;
        nSliceRuns = 5;
        tic;
        for r = 1:nSliceRuns
            [xs, ys] = ds.readSlice(sliceStart, sliceEnd);
        end
        tDsSlice = toc / nSliceRuns;

        % Cleanup
        ds.cleanup();
        delete(matFile);
        clear x y xLoaded yLoaded xr yr xs ys;

        % Print results
        fprintf('%-6s | %8.3f s | %8.3f s | %8.3f s | %8.4f s | %8.4f s | %7.1f MB | %7.1f MB\n', ...
            label, tMatSave, tMatLoad, tDsCreate, tDsRange, tDsSlice, matDiskMB, dsDiskMB);
    end

    fprintf('\n');
    fprintf('Legend:\n');
    fprintf('  MAT Save   = time to save x,y to .mat file\n');
    fprintf('  MAT Load   = time to load x,y from .mat file (full into memory)\n');
    fprintf('  DS Create  = time to create DataStore (chunked write to SQLite/binary)\n');
    fprintf('  DS Range   = avg time for a narrow range query (zoom to ~1%% of data)\n');
    fprintf('  DS Slice   = avg time to read a 10K-point slice by index\n');
    fprintf('  MAT Disk   = .mat file size on disk\n');
    fprintf('  DS Disk    = DataStore temp file size on disk\n');
    fprintf('\n');

    % --- Memory comparison ---
    fprintf('============================================================\n');
    fprintf('  Memory Comparison (estimated)\n');
    fprintf('============================================================\n\n');
    fprintf('%-6s | %-14s | %-14s | %-10s\n', ...
        'Size', 'In-Memory (MB)', 'DS Resident', 'Savings');
    fprintf('%s\n', repmat('-', 1, 55));

    for i = 1:numel(sizes)
        n = sizes(i);
        label = labels{i};
        rawMB = n * 8 * 2 / 1e6;

        % DS resident = just metadata + visible slice (~4000 pts for screen)
        visiblePts = min(4000, n);
        dsMB = visiblePts * 8 * 2 / 1e6 + 0.1;  % + overhead

        if rawMB > 0
            pctSaved = (1 - dsMB / rawMB) * 100;
        else
            pctSaved = 0;
        end

        fprintf('%-6s | %11.1f MB | %11.1f MB | %7.1f %%\n', ...
            label, rawMB, dsMB, pctSaved);
    end

    fprintf('\n');

    % --- Zoom simulation benchmark ---
    fprintf('============================================================\n');
    fprintf('  Zoom Simulation: 20 successive zooms on 10M points\n');
    fprintf('============================================================\n\n');

    n = 10e6;
    x = linspace(0, 1000, n);
    y = sin(x / 50) + 0.1 * randn(1, n);
    ds = FastPlotDataStore(x, y);

    % Simulate 20 zoom levels from full view down to 0.01% of data
    zoomLevels = logspace(log10(1000), log10(0.1), 20);
    fprintf('%-5s | %-12s | %-10s | %-12s\n', 'Zoom', 'X Range', 'Points', 'Query Time');
    fprintf('%s\n', repmat('-', 1, 50));

    for z = 1:numel(zoomLevels)
        span = zoomLevels(z);
        xCenter = 500;
        xLo = xCenter - span/2;
        xHi = xCenter + span/2;

        tic;
        [xr, yr] = ds.getRange(xLo, xHi);
        tq = toc;

        fprintf('%5.1fx | [%6.1f,%6.1f] | %8d | %9.4f s\n', ...
            1000/span, xLo, xHi, numel(xr), tq);
    end

    ds.cleanup();
    clear x y;

    fprintf('\nBenchmark complete.\n');
end
