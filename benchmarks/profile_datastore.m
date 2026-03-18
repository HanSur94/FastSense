function profile_datastore()
%PROFILE_DATASTORE Profile FastSenseDataStore and disk-backed rendering.
%   Uses MATLAB's profiler to identify bottlenecks in:
%     1. DataStore creation (chunked write)
%     2. Range queries (zoom simulation)
%     3. Full render with disk-backed lines
%     4. Zoom/pan re-downsample cycle

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));install();

    n = 5e6;  % 5M points — enough to see bottlenecks, fast enough to iterate
    fprintf('Generating %dM points...\n', n/1e6);
    x = linspace(0, 1000, n);
    y = sin(x / 50) + 0.1 * randn(1, n);

    %% 1. Profile DataStore creation
    fprintf('\n=== Profiling DataStore creation (%dM pts) ===\n', n/1e6);
    profile on;
    ds = FastSenseDataStore(x, y);
    profile off;
    printTopFunctions('DataStore creation');
    ds.cleanup();

    %% 2. Profile range queries
    fprintf('\n=== Profiling 50 range queries ===\n');
    ds = FastSenseDataStore(x, y);
    profile on;
    for i = 1:50
        xCenter = rand * 800 + 100;
        [xr, yr] = ds.getRange(xCenter - 5, xCenter + 5);
    end
    profile off;
    printTopFunctions('Range queries (50x)');
    ds.cleanup();

    %% 3. Profile slice reads
    fprintf('\n=== Profiling 50 slice reads ===\n');
    ds = FastSenseDataStore(x, y);
    profile on;
    for i = 1:50
        startIdx = randi(n - 10000);
        [xs, ys] = ds.readSlice(startIdx, startIdx + 9999);
    end
    profile off;
    printTopFunctions('Slice reads (50x)');
    ds.cleanup();

    %% 4. Profile full render with disk-backed line
    fprintf('\n=== Profiling render (disk-backed, %dM pts) ===\n', n/1e6);
    fp = FastSense('StorageMode', 'disk');
    fp.addLine(x, y, 'DisplayName', 'Profile Test');
    profile on;
    fp.render();
    profile off;
    printTopFunctions('Render (disk)');

    %% 5. Profile zoom/pan cycle
    fprintf('\n=== Profiling 10 zoom/pan cycles ===\n');
    profile on;
    for i = 1:10
        xCenter = rand * 800 + 100;
        span = 10 + rand * 100;
        set(fp.hAxes, 'XLim', [xCenter - span/2, xCenter + span/2]);
        drawnow;
    end
    profile off;
    printTopFunctions('Zoom/pan (10x)');
    close(fp.hFigure);

    %% 6. Profile render with memory-backed line (for comparison)
    fprintf('\n=== Profiling render (memory-backed, %dM pts) ===\n', n/1e6);
    fp2 = FastSense('StorageMode', 'memory');
    fp2.addLine(x, y, 'DisplayName', 'Memory Test');
    profile on;
    fp2.render();
    profile off;
    printTopFunctions('Render (memory)');
    close(fp2.hFigure);

    %% 7. Profile DataStore creation at larger scale
    clear x y;
    nLarge = 50e6;
    fprintf('\n=== Profiling DataStore creation (%dM pts) ===\n', nLarge/1e6);
    x = linspace(0, 1000, nLarge);
    y = sin(x / 50);
    % Add noise in chunks to avoid doubling memory
    for c = 1:5e6:nLarge
        ce = min(c + 5e6 - 1, nLarge);
        y(c:ce) = y(c:ce) + 0.1 * randn(1, ce - c + 1);
    end
    profile on;
    ds = FastSenseDataStore(x, y);
    profile off;
    printTopFunctions('DataStore creation (50M)');
    clear x y;

    %% 8. Profile range query on 50M dataset
    fprintf('\n=== Profiling range queries on 50M dataset ===\n');
    profile on;
    for i = 1:20
        xCenter = rand * 800 + 100;
        [xr, yr] = ds.getRange(xCenter - 5, xCenter + 5);
    end
    profile off;
    printTopFunctions('Range queries 50M (20x)');
    ds.cleanup();

    fprintf('\n=== Profiling complete ===\n');
    fprintf('Run "profile viewer" to inspect detailed call trees.\n');
end


function printTopFunctions(label)
%PRINTTOPFUNCTIONS Print top 15 functions by total time from profiler.
    stats = profile('info');
    ft = stats.FunctionTable;
    if isempty(ft); return; end

    times = [ft.TotalTime];
    [~, order] = sort(times, 'descend');

    fprintf('\n  Top functions — %s:\n', label);
    fprintf('  %-50s %10s %8s %10s\n', 'Function', 'Total (s)', 'Calls', 'Self (s)');
    fprintf('  %s\n', repmat('-', 1, 82));

    nShow = min(15, numel(order));
    for k = 1:nShow
        idx = order(k);
        fname = ft(idx).FunctionName;
        if numel(fname) > 50; fname = [fname(1:47) '...']; end
        fprintf('  %-50s %10.4f %8d %10.4f\n', ...
            fname, ft(idx).TotalTime, ft(idx).NumCalls, ...
            ft(idx).TotalTime - sum([ft(idx).Children.TotalTime]));
    end
end
