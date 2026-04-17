function benchmark_memory()
%BENCHMARK_MEMORY Compare RAM usage between memory and disk-backed sensors.
%   Profiles memory consumption for:
%     1. Scaling comparison across dataset sizes (100K to 5M points)
%     2. Multi-sensor dashboard memory footprint
%     3. toDisk/toMemory timing
%
%   In-memory sensors hold X and Y arrays (16 bytes/point).
%   Disk-backed sensors hold only the pre-computed pyramid (~2% of raw).
%
%   Example:
%     benchmark_memory();

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));install();

    fprintf('=== FastSense Memory Benchmark ===\n\n');

    %% 1. Scaling: memory vs disk across sizes
    sizes = [1e5, 5e5, 1e6, 2e6, 5e6, 10e6];

    fprintf('--- RAM usage: in-memory vs toDisk ---\n');
    fprintf('  %-10s %12s %12s %10s\n', 'Points', 'Memory (MB)', 'Disk (MB)', 'Saved');
    fprintf('  %s\n', repmat('-', 1, 48));

    for i = 1:numel(sizes)
        n = sizes(i);
        rawMB = n * 16 / 1e6;  % 8 bytes/double x 2 arrays (X + Y)

        % In-memory: X + Y stay in Sensor properties
        memMB = rawMB;

        % Disk: X/Y offloaded, only pyramid (~2*n/100 points) stays in RAM
        s = SensorTag('bench');
        s.updateData(linspace(0, 1000, n), sin(s.X / 50));
        s.toDisk();
        pyrMB = numel(s.DataStore.PyramidX) * 16 / 1e6;
        diskMB = pyrMB;
        s.DataStore.cleanup();

        fprintf('  %-10s %10.1f   %10.1f   %7.0f%%\n', ...
            formatPoints(n), memMB, diskMB, (memMB - diskMB) / memMB * 100);
    end

    %% 2. Dashboard scenarios
    fprintf('\n--- Dashboard: 4 sensors ---\n');
    fprintf('  %-12s %12s %12s %10s\n', 'Scenario', 'Memory (MB)', 'Disk (MB)', 'Saved');
    fprintf('  %s\n', repmat('-', 1, 50));

    dashSizes = [1e6, 2e6, 5e6, 10e6];
    for j = 1:numel(dashSizes)
        n = dashSizes(j);
        memTotal = 4 * n * 16 / 1e6;
        pyrPts = max(1, round(n / 100)) * 2;
        diskTotal = 4 * pyrPts * 16 / 1e6;
        fprintf('  %-12s %10.1f   %10.1f   %7.0f%%\n', ...
            sprintf('4x%s', formatPoints(n)), memTotal, diskTotal, ...
            (memTotal - diskTotal) / memTotal * 100);
    end

    %% 3. toDisk / toMemory timing
    fprintf('\n--- toDisk / toMemory timing ---\n');
    fprintf('  %-10s %12s %12s\n', 'Points', 'toDisk (s)', 'toMemory (s)');
    fprintf('  %s\n', repmat('-', 1, 36));

    for i = 1:numel(sizes)
        n = sizes(i);
        s = SensorTag('timing');
        s.updateData(linspace(0, 1000, n), sin(s.X / 50));

        tic; s.toDisk(); tTo = toc;
        tic; s.toMemory(); tFrom = toc;

        fprintf('  %-10s %10.3f   %10.3f\n', formatPoints(n), tTo, tFrom);
    end

    %% 4. resolve() timing: memory vs disk-MEX vs pre-computed
    fprintf('\n--- resolve() timing: memory vs disk-MEX vs pre-computed ---\n');
    fprintf('  %-10s %12s %14s %14s\n', ...
        'Points', 'Memory (s)', 'Disk-MEX (s)', 'Cached (s)');
    fprintf('  %s\n', repmat('-', 1, 54));

    resolveSizes = [1e5, 5e5, 1e6, 2e6, 5e6];
    for i = 1:numel(resolveSizes)
        n = resolveSizes(i);

        % Shared state channel
        sc = StateTag('machine');
        sc.X = [0, 25, 50, 75];
        sc.Y = [0, 1, 2, 1];

        % Memory resolve
        s = SensorTag('res');
        s.updateData(linspace(0, 100, n), 40 + 20 * sin(2 * pi * s.X / 30));
        tHH = MonitorTag('hh', 'Name', 'HH', 'Direction', 'upper');

        % Disk resolve — MEX path (clear cache to force recompute)
        clear compute_violations_disk;
        s2 = SensorTag('res_mex');
        s2.updateData(linspace(0, 100, n), 40 + 20 * sin(2 * pi * s2.X / 30));
        tHH2 = MonitorTag('hh', 'Name', 'HH', 'Direction', 'upper');
        s2.toDisk();  % pre-computes + caches
        s2.DataStore.clearResolved();  % clear cache to force disk scan
        s2.DataStore.cleanup();

        % Pre-computed resolve — toDisk pre-computes, resolve loads cache
        s3 = SensorTag('res_cached');
        s3.updateData(linspace(0, 100, n), 40 + 20 * sin(2 * pi * s3.X / 30));
        tHH3 = MonitorTag('hh', 'Name', 'HH', 'Direction', 'upper');
        s3.toDisk();  % pre-computes + caches
        s3.DataStore.cleanup();

        fprintf('  %-10s %10.3f   %12.3f   %12.4f\n', ...
            formatPoints(n), tMem, tDiskMex, tCached);
    end

    %% 5. resolve() peak memory: old vs new
    fprintf('\n--- resolve() peak memory estimate ---\n');
    fprintf('  %-10s %15s %15s %10s\n', ...
        'Points', 'Old (full load)', 'New (segments)', 'Saved');
    fprintf('  %s\n', repmat('-', 1, 54));

    for n = [1e6, 2e6, 5e6, 10e6]
        oldMB = n * 16 / 1e6;              % old: loaded entire X+Y
        newMB = (n / 4) * 16 / 1e6;        % new: only active segments (~25%)
        fprintf('  %-10s %12.1f MB  %12.1f MB  %7.0f%%\n', ...
            formatPoints(n), oldMB, newMB, (oldMB - newMB) / oldMB * 100);
    end

    fprintf('\n=== Benchmark complete ===\n');
end


function s = formatPoints(n)
%FORMATPOINTS Format point count as human-readable string.
    if n >= 1e6
        s = sprintf('%.0fM', n / 1e6);
    elseif n >= 1e3
        s = sprintf('%.0fK', n / 1e3);
    else
        s = sprintf('%.0f', n);
    end
end
