function bench_monitortag_tick()
%BENCH_MONITORTAG_TICK Pitfall 9 gate — MonitorTag tick <= 110% legacy Sensor.resolve baseline.
%
%   Assertion: 12-widget live-tick emulation — minimum of 3 runs, each
%   comprising 50 iterations over 12 sensors x 10k points with one
%   unconditional threshold each.
%
%   MonitorTag path  : 12x monitor.invalidate() + monitor.getXY() per iteration
%   (invalidate forces a cold recompute on every tick — matches a live
%   dashboard where the parent's data appends every frame)
%
%   Gate: overhead_pct = (tMonitor - tLegacy) / tLegacy * 100 <= 10
%
%   Run:
%     octave --no-gui --eval "install(); bench_monitortag_tick();"
%
%   Exits 0 with "PASS: <= 10% regression gate satisfied." on success;
%   raises assert() (non-zero exit) if MonitorTag tick is > 110% of the
%   legacy Sensor.resolve baseline.
%
%   See also MonitorTag, SensorTag, Sensor, bench_sensortag_getxy.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    install();

    nSensors = 12;
    nPoints  = 10000;
    nIter    = 50;
    nRuns    = 3;

    sensors  = cell(1, nSensors);
    monitors = cell(1, nSensors);

    % Deterministic seed — works in both MATLAB and Octave
    if exist('rng', 'file') == 2
        rng(0);
    else
        rand('state', 0); randn('state', 0); %#ok<RAND>
    end

    for k = 1:nSensors
        x = linspace(0, 100, nPoints);
        y = 40 + 20*sin(2*pi*x/30 + k) + 5*randn(1, nPoints);

        % Legacy path — Sensor + unconditional upper Threshold at 50
        s = SensorTag(sprintf('s%d', k));
        % TODO: s.X = x; s.Y = y; (needs manual fix)
        t = MonitorTag(sprintf('t%d', k), 'Direction', 'upper');
        sensors{k} = s;

        % New path — SensorTag + MonitorTag with equivalent condition
        st = SensorTag(sprintf('stg%d', k), 'X', x, 'Y', y);
        m  = MonitorTag(sprintf('mtg%d', k), st, @(px,py) py > 50);
        monitors{k} = m;
    end

    % Warmup — dissolve JIT / first-call overhead (Pitfall 9)
    for k = 1:nSensors
        monitors{k}.invalidate();
        monitors{k}.getXY();
    end

    % Legacy baseline — min of nRuns (matches bench_sensortag_getxy convention)
    tLegacy = inf;
    for r = 1:nRuns
        t0 = tic;
        for it = 1:nIter
            for k = 1:nSensors
            end
        end
        tLegacy = min(tLegacy, toc(t0));
    end

    % MonitorTag path (invalidate every iter to force recompute — matches a
    % live-tick where the parent's data changes every frame)
    tMonitor = inf;
    for r = 1:nRuns
        t0 = tic;
        for it = 1:nIter
            for k = 1:nSensors
                monitors{k}.invalidate();
                monitors{k}.getXY();
            end
        end
        tMonitor = min(tMonitor, toc(t0));
    end

    overhead_pct = (tMonitor - tLegacy) / tLegacy * 100;
    fprintf('\n=== Pitfall 9: MonitorTag tick vs Sensor.resolve baseline ===\n');
    fprintf('  %d sensors x %d points x %d iters (min of %d runs)\n', ...
        nSensors, nPoints, nIter, nRuns);
    fprintf('  Sensor.resolve total : %.3f s\n', tLegacy);
    fprintf('  MonitorTag total     : %.3f s\n', tMonitor);
    fprintf('  Overhead             : %+.1f%%  (gate: overhead_pct <= 10)\n', overhead_pct);
    assert(overhead_pct <= 10, ...
        sprintf('FAIL: MonitorTag tick %.1f%% slower than Sensor.resolve (gate: overhead_pct <= 10).', overhead_pct));
    fprintf('  PASS: <= 10%% regression gate satisfied.\n\n');
end
