function benchmark_datastore()
%BENCHMARK_DATASTORE Compare raw .mat loading vs SQLite-backed DataStore.
%   Measures: write time, range query time, slice read time, memory usage,
%   and disk footprint across multiple dataset sizes up to 500M points.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    setup();

    sizes = [1e4, 1e5, 1e6, 5e6, 10e6, 50e6, 100e6, 200e6, 500e6];
    labels = {'10K', '100K', '1M', '5M', '10M', '50M', '100M', '200M', '500M'};

    % Skip .mat save/load for very large sizes (would OOM or take too long)
    matMaxSize = 50e6;

    fprintf('\n============================================================\n');
    fprintf('  FastSense DataStore Benchmark: .mat vs SQLite\n');
    fprintf('============================================================\n\n');

    hasSqlite = (exist('mksqlite', 'file') == 3);
    if hasSqlite
        fprintf('  mksqlite: AVAILABLE (SQLite backend will be used)\n');
    else
        fprintf('  mksqlite: NOT FOUND (binary fallback will be used)\n');
    end
    fprintf('  Octave %s on %s\n', version(), computer());
    [~, meminfo] = system('free -h | head -2');
    fprintf('  %s\n', strtrim(meminfo));

    % Header
    fprintf('\n%-6s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s\n', ...
        'Size', 'MAT Save', 'MAT Load', 'DS Create', 'DS Range', 'DS Slice', 'MAT Disk', 'DS Disk');
    fprintf('%s\n', repmat('-', 1, 95));

    for i = 1:numel(sizes)
        n = sizes(i);
        label = labels{i};
        doMat = (n <= matMaxSize);

        % --- Generate data in a memory-efficient way ---
        % For very large arrays, build x with linspace (efficient) and
        % generate y in-place without intermediate arrays
        x = linspace(0, 1000, n);
        y = sin(x / 50);
        % Add noise in chunks to avoid doubling memory with randn
        chunkSz = min(n, 10e6);
        for c = 1:chunkSz:n
            ce = min(c + chunkSz - 1, n);
            y(c:ce) = y(c:ce) + 0.1 * randn(1, ce - c + 1);
        end

        matFile = [tempname, '.mat'];
        tMatSave = NaN;
        tMatLoad = NaN;
        matDiskMB = NaN;

        if doMat
            % --- .mat save ---
            tic;
            save(matFile, 'x', 'y', '-v7');
            tMatSave = toc;

            matDisk = dir(matFile);
            matDiskMB = matDisk.bytes / 1e6;

            % --- .mat load ---
            tic;
            loaded = load(matFile);
            tMatLoad = toc;
            clear loaded;
            delete(matFile);
        end

        % --- DataStore create (SQLite or binary) ---
        tic;
        ds = FastSenseDataStore(x, y);
        tDsCreate = toc;

        % Free source data immediately to reclaim memory
        clear x y;

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

        % --- DataStore range query (simulate zoom to ~0.5% of data) ---
        xMid = 500;
        xSpan = 5;
        nRangeRuns = 5;
        tic;
        for r = 1:nRangeRuns
            [xr, yr] = ds.getRange(xMid - xSpan, xMid + xSpan);
        end
        tDsRange = toc / nRangeRuns;
        clear xr yr;

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
        clear xs ys;

        % Cleanup
        ds.cleanup();

        % Print results
        if doMat
            fprintf('%-6s | %8.3f s | %8.3f s | %8.3f s | %8.4f s | %8.4f s | %7.1f MB | %7.1f MB\n', ...
                label, tMatSave, tMatLoad, tDsCreate, tDsRange, tDsSlice, matDiskMB, dsDiskMB);
        else
            fprintf('%-6s | %10s | %10s | %8.3f s | %8.4f s | %8.4f s | %10s | %7.1f MB\n', ...
                label, 'N/A (OOM)', 'N/A (OOM)', tDsCreate, tDsRange, tDsSlice, 'N/A', dsDiskMB);
        end
    end

    fprintf('\n');
    fprintf('Legend:\n');
    fprintf('  MAT Save   = time to save x,y to .mat file\n');
    fprintf('  MAT Load   = time to load x,y from .mat file (full into memory)\n');
    fprintf('  DS Create  = time to create DataStore (chunked write to SQLite/binary)\n');
    fprintf('  DS Range   = avg time for a narrow range query (zoom to ~0.5%% of data)\n');
    fprintf('  DS Slice   = avg time to read a 10K-point slice by index\n');
    fprintf('  MAT Disk   = .mat file size on disk\n');
    fprintf('  DS Disk    = DataStore temp file size on disk\n');
    fprintf('  N/A (OOM)  = skipped; would require loading full data into memory twice\n');
    fprintf('\n');

    % --- Memory comparison ---
    fprintf('============================================================\n');
    fprintf('  Memory Comparison (estimated)\n');
    fprintf('============================================================\n\n');
    fprintf('%-6s | %-14s | %-14s | %-10s\n', ...
        'Size', 'In-Memory', 'DS Resident', 'Savings');
    fprintf('%s\n', repmat('-', 1, 55));

    for i = 1:numel(sizes)
        n = sizes(i);
        label = labels{i};
        rawMB = n * 8 * 2 / 1e6;

        % DS resident = just metadata + visible slice (~4000 pts for screen)
        visiblePts = min(4000, n);
        dsMB = visiblePts * 8 * 2 / 1e6 + 0.1;  % + overhead

        pctSaved = (1 - dsMB / rawMB) * 100;

        if rawMB >= 1000
            rawStr = sprintf('%7.1f GB', rawMB / 1000);
        else
            rawStr = sprintf('%7.1f MB', rawMB);
        end

        fprintf('%-6s | %11s | %11.1f MB | %7.1f %%\n', ...
            label, rawStr, dsMB, pctSaved);
    end

    fprintf('\n');

    % --- Zoom simulation on largest feasible dataset ---
    zoomN = min(500e6, 100e6);  % Use 100M for zoom sim to keep runtime reasonable
    fprintf('============================================================\n');
    fprintf('  Zoom Simulation: 20 successive zooms on %dM points\n', zoomN / 1e6);
    fprintf('============================================================\n\n');

    x = linspace(0, 1000, zoomN);
    y = sin(x / 50);
    chunkSz = min(zoomN, 10e6);
    for c = 1:chunkSz:zoomN
        ce = min(c + chunkSz - 1, zoomN);
        y(c:ce) = y(c:ce) + 0.1 * randn(1, ce - c + 1);
    end
    ds = FastSenseDataStore(x, y);
    clear x y;

    % Simulate 20 zoom levels from full view down to 0.01% of data
    zoomLevels = logspace(log10(1000), log10(0.1), 20);
    fprintf('%-8s | %-15s | %-10s | %-12s\n', 'Zoom', 'X Range', 'Points', 'Query Time');
    fprintf('%s\n', repmat('-', 1, 55));

    for z = 1:numel(zoomLevels)
        span = zoomLevels(z);
        xCenter = 500;
        xLo = xCenter - span/2;
        xHi = xCenter + span/2;

        tic;
        [xr, yr] = ds.getRange(xLo, xHi);
        tq = toc;

        fprintf('%7.1fx | [%6.1f, %6.1f] | %10d | %9.4f s\n', ...
            1000/span, xLo, xHi, numel(xr), tq);
        clear xr yr;
    end

    ds.cleanup();

    fprintf('\nBenchmark complete.\n');
end
