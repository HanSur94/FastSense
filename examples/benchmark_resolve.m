function benchmark_resolve()
%BENCHMARK_RESOLVE Compare old vs new Sensor.resolve() performance.
%   Runs at 10K, 100K, 1M, 10M points with 2 state channels, 4 rules.

    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));

    sizes = [1e4, 1e5, 1e6, 1e7];
    nRuns = 5;

    fprintf('\n=== Sensor.resolve() Benchmark ===\n\n');
    fprintf('%-12s  %-14s  %-14s  %-10s\n', ...
        'Data Size', 'resolve() [ms]', 'MEX avail?', 'Violations');
    fprintf('%s\n', repmat('-', 1, 60));

    % Check MEX availability in private dir where it's actually used
    mexPath = fullfile(repo_root, 'libs', 'SensorThreshold', 'private', 'compute_violations_mex');
    mexExts = {'.mex', '.mexa64', '.mexmaci64', '.mexmaca64', '.mexw64'};
    hasMex = false;
    for e = 1:numel(mexExts)
        if exist([mexPath mexExts{e}], 'file')
            hasMex = true;
            break;
        end
    end
    mexStr = 'no';
    if hasMex; mexStr = 'yes'; end

    for si = 1:numel(sizes)
        N = sizes(si);

        % Create sensor with realistic data
        x = linspace(0, 1000, N);
        y = sin(x * 0.01) * 40 + 50 + randn(1, N) * 5;

        % Two state channels with transitions
        sc1 = StateChannel('machine');
        sc1.X = [0, 200, 400, 600, 800];
        sc1.Y = [0, 1, 2, 1, 0];

        sc2 = StateChannel('vacuum');
        sc2.X = [0, 300, 700];
        sc2.Y = [0, 1, 0];

        % 4 threshold rules (warn/alarm upper/lower)
        % Batched: first two share condition, second two share condition
        times = zeros(1, nRuns);
        nViol = 0;

        for run = 1:nRuns
            s = Sensor('bench');
            s.X = x;
            s.Y = y;
            s.addStateChannel(sc1);
            s.addStateChannel(sc2);

            s.addThresholdRule(struct('machine', 1), 80, ...
                'Direction', 'upper', 'Label', 'Warn Hi');
            s.addThresholdRule(struct('machine', 1), 20, ...
                'Direction', 'lower', 'Label', 'Warn Lo');
            s.addThresholdRule(struct('machine', 1, 'vacuum', 1), 90, ...
                'Direction', 'upper', 'Label', 'Alarm Hi');
            s.addThresholdRule(struct('machine', 1, 'vacuum', 1), 10, ...
                'Direction', 'lower', 'Label', 'Alarm Lo');

            tic;
            s.resolve();
            times(run) = toc * 1000;

            if run == 1
                for v = 1:numel(s.ResolvedViolations)
                    nViol = nViol + numel(s.ResolvedViolations(v).X);
                end
            end
        end

        medTime = median(times);

        if N >= 1e6
            sizeStr = sprintf('%.0fM', N / 1e6);
        elseif N >= 1e3
            sizeStr = sprintf('%.0fK', N / 1e3);
        else
            sizeStr = sprintf('%.0f', N);
        end

        fprintf('%-12s  %10.2f ms   %-14s  %d\n', ...
            sizeStr, medTime, mexStr, nViol);
    end

    fprintf('\nDone.\n');
end
