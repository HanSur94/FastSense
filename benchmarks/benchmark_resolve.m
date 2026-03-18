function benchmark_resolve()
%BENCHMARK_RESOLVE Compare segment-based vs naive resolve() performance.
%   Runs at 10K to 100M points with 2 state channels, 4 rules.
%   Compares: naive O(N*R) loop vs segment-based vectorized (+ MEX).
%   Naive is skipped above 1M points (too slow).

    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    install();

    sizes = [1e4, 1e5, 1e6, 1e7, 1e8];
    naiveMaxN = Inf;  % run naive for all sizes
    nRuns = 5;

    % Check MEX availability
    mexPath = fullfile(repo_root, 'libs', 'SensorThreshold', 'private', 'compute_violations_mex');
    mexExts = {'.mex', '.mexa64', '.mexmaci64', '.mexmaca64', '.mexw64'};
    hasMex = false;
    for e = 1:numel(mexExts)
        if exist([mexPath mexExts{e}], 'file')
            hasMex = true;
            break;
        end
    end

    fprintf('\n=== Sensor.resolve() Benchmark ===\n');
    fprintf('  %d state channels, 4 rules, median of %d runs\n', 2, nRuns);
    if hasMex
        fprintf('  MEX: compiled (compute_violations_mex)\n\n');
    else
        fprintf('  MEX: not compiled (run build_mex to enable)\n\n');
    end

    fprintf('%-10s  %12s  %12s  %10s  %10s\n', ...
        'Size', 'Naive [ms]', 'Segment [ms]', 'Speedup', 'Violations');
    fprintf('%s\n', repmat('-', 1, 62));

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

        % --- Naive O(N*R): point-by-point with aligned state lookup ---
        runNaive = (N <= naiveMaxN);
        if runNaive
            naiveTimes = zeros(1, nRuns);
            for r = 1:nRuns
                naiveTimes(r) = bench_naive(x, y, sc1, sc2) * 1000;
            end
            naiveMs = median(naiveTimes);
        end

        % --- Segment-based (current resolve) ---
        segTimes = zeros(1, nRuns);
        nViol = 0;
        for r = 1:nRuns
            s = Sensor('bench');
            s.X = x; s.Y = y;
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
            segTimes(r) = toc * 1000;

            if r == 1
                for v = 1:numel(s.ResolvedViolations)
                    nViol = nViol + numel(s.ResolvedViolations(v).X);
                end
            end
        end

        segMs = median(segTimes);
        sizeStr = format_size(N);

        if runNaive
            speedup = naiveMs / segMs;
            fprintf('%-10s  %9.1f ms  %9.1f ms  %9.1fx  %10d\n', ...
                sizeStr, naiveMs, segMs, speedup, nViol);
        else
            fprintf('%-10s  %10s  %9.1f ms  %10s  %10d\n', ...
                sizeStr, '—', segMs, '—', nViol);
        end
    end

    fprintf('\nDone.\n');
end


function elapsed = bench_naive(x, y, sc1, sc2)
%BENCH_NAIVE Simulate the old O(N*R) resolve: per-point state eval + comparison.
    n = numel(x);

    % Align states to sensor timestamps (same as old resolve)
    state1 = align_state(sc1.X, sc1.Y, x);
    state2 = align_state(sc2.X, sc2.Y, x);

    % 4 rules: machine==1 upper 80, machine==1 lower 20,
    %          machine==1&vacuum==1 upper 90, machine==1&vacuum==1 lower 10
    rules = [1 NaN 80 1; 1 NaN 20 0; 1 1 90 1; 1 1 10 0];
    % columns: reqMachine, reqVacuum (NaN=any), threshold, isUpper

    tic;
    for r = 1:size(rules, 1)
        reqM = rules(r, 1);
        reqV = rules(r, 2);
        thVal = rules(r, 3);
        isUpper = rules(r, 4);

        vX = [];
        vY = [];
        for k = 1:n
            % Check condition
            if state1(k) ~= reqM; continue; end
            if ~isnan(reqV) && state2(k) ~= reqV; continue; end
            % Check violation
            if isUpper && y(k) > thVal
                vX(end+1) = x(k); %#ok<AGROW>
                vY(end+1) = y(k); %#ok<AGROW>
            elseif ~isUpper && y(k) < thVal
                vX(end+1) = x(k); %#ok<AGROW>
                vY(end+1) = y(k); %#ok<AGROW>
            end
        end
    end
    elapsed = toc;
end


function aligned = align_state(stateX, stateY, sensorX)
%ALIGN_STATE Zero-order hold alignment of state to sensor timestamps.
    aligned = zeros(size(sensorX));
    nStates = numel(stateX);
    for i = 1:numel(sensorX)
        t = sensorX(i);
        val = stateY(1);
        for s = nStates:-1:1
            if t >= stateX(s)
                val = stateY(s);
                break;
            end
        end
        aligned(i) = val;
    end
end


function s = format_size(N)
    if N >= 1e6
        s = sprintf('%.0fM', N / 1e6);
    elseif N >= 1e3
        s = sprintf('%.0fK', N / 1e3);
    else
        s = sprintf('%.0f', N);
    end
end
