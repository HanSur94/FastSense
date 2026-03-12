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

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();

    fprintf('=== FastPlot Memory Benchmark ===\n\n');

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
        s = Sensor('bench');
        s.X = linspace(0, 1000, n);
        s.Y = sin(s.X / 50);
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
        s = Sensor('timing');
        s.X = linspace(0, 1000, n);
        s.Y = sin(s.X / 50);

        tic; s.toDisk(); tTo = toc;
        tic; s.toMemory(); tFrom = toc;

        fprintf('  %-10s %10.3f   %10.3f\n', formatPoints(n), tTo, tFrom);
    end

    %% 4. resolve() timing: memory vs disk
    fprintf('\n--- resolve() timing: memory vs disk ---\n');
    fprintf('  %-10s %12s %12s\n', 'Points', 'Memory (s)', 'Disk (s)');
    fprintf('  %s\n', repmat('-', 1, 36));

    resolveSizes = [1e5, 5e5, 1e6, 2e6];
    for i = 1:numel(resolveSizes)
        n = resolveSizes(i);

        % Memory resolve
        s = Sensor('res');
        s.X = linspace(0, 100, n);
        s.Y = 40 + 20 * sin(2 * pi * s.X / 30);
        sc = StateChannel('machine');
        sc.X = [0, 25, 50, 75];
        sc.Y = [0, 1, 2, 1];
        s.addStateChannel(sc);
        s.addThresholdRule(struct('machine', 1), 55, ...
            'Direction', 'upper', 'Label', 'HH');
        tic; s.resolve(); tMem = toc;

        % Disk resolve (re-create to avoid cached results)
        s2 = Sensor('res_d');
        s2.X = linspace(0, 100, n);
        s2.Y = 40 + 20 * sin(2 * pi * s2.X / 30);
        s2.addStateChannel(sc);
        s2.addThresholdRule(struct('machine', 1), 55, ...
            'Direction', 'upper', 'Label', 'HH');
        s2.toDisk();
        tic; s2.resolve(); tDisk = toc;
        s2.DataStore.cleanup();

        fprintf('  %-10s %10.3f   %10.3f\n', formatPoints(n), tMem, tDisk);
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
