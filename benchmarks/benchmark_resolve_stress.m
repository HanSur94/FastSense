function benchmark_resolve_stress()
%BENCHMARK_RESOLVE_STRESS Stress test for Sensor.resolve() at 500M points.
%   Creates a realistic sensor with 500M datapoints and 4 thresholds,
%   each governed by different condition rules across 2 state channels
%   that change frequently (~5000 transitions each).
%
%   This exercises the full resolve pipeline:
%     - Segment boundary collection with ~10K unique boundaries
%     - Composite state evaluation at each boundary
%     - Condition matching & segment index mapping
%     - Batch violation detection (MEX or vectorized)
%     - Threshold merge & step-function conversion
%
%   Run:
%     >> benchmark_resolve_stress

    repo_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(repo_root);
    install();

    N = 500e6;

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('  Sensor.resolve() Stress Test — %.0fM datapoints\n', N / 1e6);
    fprintf('============================================================\n');
    fprintf('  Building sensor data... ');

    tBuild = tic;

    % ------------------------------------------------------------------
    % 1. Sensor data: 500M points of realistic process signal
    %    Base signal with multiple frequency components + noise + drift
    % ------------------------------------------------------------------
    x = linspace(0, 10000, N);

    % Layered signal: slow drift + medium oscillation + fast noise
    y = 50 ...
        + 10 * sin(2*pi*x / 3000) ...       % slow thermal drift
        + 8  * sin(2*pi*x / 200) ...         % process oscillation
        + 5  * randn(1, N);                  % measurement noise

    % Inject deliberate excursions to guarantee violations in every regime
    % High spikes in running states
    y(round(N*0.05):round(N*0.05)+2000) = 95 + 5*randn(1, 2001);
    y(round(N*0.35):round(N*0.35)+3000) = 90 + 5*randn(1, 3001);
    y(round(N*0.65):round(N*0.65)+1500) = 85 + 3*randn(1, 1501);
    % Low dips in evacuated states
    y(round(N*0.15):round(N*0.15)+2500) = 10 + 3*randn(1, 2501);
    y(round(N*0.55):round(N*0.55)+1000) = 5  + 2*randn(1, 1001);
    y(round(N*0.85):round(N*0.85)+2000) = 15 + 4*randn(1, 2001);

    fprintf('%.1f s\n', toc(tBuild));

    % ------------------------------------------------------------------
    % 2. State channels with many transitions (~5000 each)
    %    This creates ~10K segment boundaries — the core stress factor
    %    for the resolve pipeline beyond raw data size.
    % ------------------------------------------------------------------
    fprintf('  Building state channels... ');
    tState = tic;

    % Machine state: cycles through 0 (idle) → 1 (running) → 2 (evacuated)
    % with irregular interval lengths to create realistic patterns
    nMachineTransitions = 5000;
    rng(42);
    machineIntervals = 1.5 + 1.5 * rand(1, nMachineTransitions);
    machineX = [0, cumsum(machineIntervals)];
    % Scale to fit data range
    machineX = machineX / machineX(end) * x(end);
    % Cycle through states 0→1→2→1→0→1→2→...
    statePattern = [0 1 2 1];
    machineY = zeros(1, numel(machineX));
    for i = 1:numel(machineX)
        machineY(i) = statePattern(mod(i-1, numel(statePattern)) + 1);
    end

    scMachine = StateChannel('machine');
    scMachine.X = machineX;
    scMachine.Y = machineY;

    % Operating zone: string-valued, toggles between A/B/C
    % Different transition frequency than machine state → many unique combos
    nZoneTransitions = 4000;
    zoneIntervals = 2.0 + 2.0 * rand(1, nZoneTransitions);
    zoneX = [0, cumsum(zoneIntervals)];
    zoneX = zoneX / zoneX(end) * x(end);
    zonePattern = {'A', 'B', 'C'};
    zoneY = cell(1, numel(zoneX));
    for i = 1:numel(zoneX)
        zoneY{i} = zonePattern{mod(i-1, numel(zonePattern)) + 1};
    end

    scZone = StateChannel('zone');
    scZone.X = zoneX;
    scZone.Y = zoneY;

    fprintf('%.1f s\n', toc(tState));
    fprintf('  Machine transitions: %d\n', numel(machineX));
    fprintf('  Zone transitions:    %d\n', numel(zoneX));

    % ------------------------------------------------------------------
    % 3. Build sensor with 4 threshold rules (different conditions each)
    % ------------------------------------------------------------------
    fprintf('  Configuring sensor + thresholds...\n');

    s = Sensor('stress_test', 'Name', 'Process Stress Test', 'Units', 'bar');
    s.X = x;
    s.Y = y;
    s.addStateChannel(scMachine);
    s.addStateChannel(scZone);

    % Rule 1: Upper alarm when running (machine==1), any zone
    %   → Active in ~25% of timeline, single-condition
    s.addThresholdRule(struct('machine', 1), 75, ...
        'Direction', 'upper', 'Label', 'HH (running)', ...
        'Color', [0.9 0.1 0.1], 'LineStyle', '--');

    % Rule 2: Lower alarm when evacuated (machine==2), any zone
    %   → Active in ~25% of timeline, single-condition
    s.addThresholdRule(struct('machine', 2), 25, ...
        'Direction', 'lower', 'Label', 'LL (evacuated)', ...
        'Color', [0.1 0.1 0.9], 'LineStyle', '--');

    % Rule 3: Upper alarm when running AND zone B (two conditions)
    %   → Active in ~8% of timeline (intersection), stricter limit
    s.addThresholdRule(struct('machine', 1, 'zone', 'B'), 65, ...
        'Direction', 'upper', 'Label', 'HH (running+B)', ...
        'Color', [0.8 0.0 0.8], 'LineStyle', ':');

    % Rule 4: Lower alarm when idle AND zone C (two conditions)
    %   → Active in ~8% of timeline (intersection)
    s.addThresholdRule(struct('machine', 0, 'zone', 'C'), 30, ...
        'Direction', 'lower', 'Label', 'LL (idle+C)', ...
        'Color', [0.0 0.5 0.8], 'LineStyle', ':');

    fprintf('  Rules: %d (%d upper, %d lower)\n', ...
        numel(s.ThresholdRules), 2, 2);

    % ------------------------------------------------------------------
    % 4. MEX availability check
    % ------------------------------------------------------------------
    mexNames = {'compute_violations_mex', 'to_step_function_mex', 'binary_search_mex'};
    fprintf('\n  MEX status:\n');
    for i = 1:numel(mexNames)
        if exist(mexNames{i}, 'file') == 3
            fprintf('    %-30s  compiled\n', mexNames{i});
        else
            fprintf('    %-30s  NOT compiled (MATLAB fallback)\n', mexNames{i});
        end
    end

    % ------------------------------------------------------------------
    % 5. Run resolve() with timing
    % ------------------------------------------------------------------
    nRuns = 3;
    fprintf('\n  Resolving (%d runs)...\n', nRuns);

    times = zeros(1, nRuns);
    for r = 1:nRuns
        % Rebuild sensor each run to avoid cache effects
        sr = Sensor('stress_test');
        sr.X = x; sr.Y = y;
        sr.addStateChannel(scMachine);
        sr.addStateChannel(scZone);
        sr.addThresholdRule(struct('machine', 1), 75, ...
            'Direction', 'upper', 'Label', 'HH (running)');
        sr.addThresholdRule(struct('machine', 2), 25, ...
            'Direction', 'lower', 'Label', 'LL (evacuated)');
        sr.addThresholdRule(struct('machine', 1, 'zone', 'B'), 65, ...
            'Direction', 'upper', 'Label', 'HH (running+B)');
        sr.addThresholdRule(struct('machine', 0, 'zone', 'C'), 30, ...
            'Direction', 'lower', 'Label', 'LL (idle+C)');

        tic;
        sr.resolve();
        times(r) = toc;

        fprintf('    Run %d: %.3f s\n', r, times(r));
    end

    % Use the last run's sensor for result inspection
    s = sr;

    % ------------------------------------------------------------------
    % 6. Results summary
    % ------------------------------------------------------------------
    fprintf('\n============================================================\n');
    fprintf('  RESULTS\n');
    fprintf('============================================================\n');
    fprintf('  Data points:        %s\n', format_size(N));
    fprintf('  State transitions:  %d (machine) + %d (zone)\n', ...
        numel(machineX), numel(zoneX));
    fprintf('  Threshold rules:    %d\n', numel(s.ThresholdRules));
    fprintf('  Resolved lines:     %d\n', numel(s.ResolvedThresholds));

    totalViol = 0;
    for v = 1:numel(s.ResolvedViolations)
        nv = numel(s.ResolvedViolations(v).X);
        totalViol = totalViol + nv;
        fprintf('    [%s] %s: %s violations\n', ...
            s.ResolvedViolations(v).Direction, ...
            s.ResolvedViolations(v).Label, ...
            format_size(nv));
    end
    fprintf('  Total violations:   %s\n', format_size(totalViol));
    fprintf('\n');
    fprintf('  resolve() time:\n');
    fprintf('    median:  %.3f s\n', median(times));
    fprintf('    min:     %.3f s\n', min(times));
    fprintf('    max:     %.3f s\n', max(times));
    fprintf('    throughput: %.1f M pts/s\n', (N / 1e6) / median(times));

    % Memory estimate (approximate)
    memBytes = N * 8 * 2;  % X + Y arrays
    for v = 1:numel(s.ResolvedViolations)
        memBytes = memBytes + numel(s.ResolvedViolations(v).X) * 8 * 2;
    end
    for t = 1:numel(s.ResolvedThresholds)
        memBytes = memBytes + numel(s.ResolvedThresholds(t).X) * 8 * 2;
    end
    fprintf('    approx memory: %.1f GB (sensor) + %.1f MB (results)\n', ...
        N * 8 * 2 / 1e9, (memBytes - N*8*2) / 1e6);

    fprintf('\n============================================================\n');
    fprintf('  Done.\n');
    fprintf('============================================================\n');
end


function s = format_size(N)
    if N >= 1e9
        s = sprintf('%.1fB', N / 1e9);
    elseif N >= 1e6
        s = sprintf('%.1fM', N / 1e6);
    elseif N >= 1e3
        s = sprintf('%.1fK', N / 1e3);
    else
        s = sprintf('%d', N);
    end
end
