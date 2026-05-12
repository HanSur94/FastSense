function y = buildSensorExcursions(cfg, key, tHist)
%BUILDSENSOREXCURSIONS Build the historical y(t) for one sensor.
%   y = buildSensorExcursions(cfg, key, tHist) returns the synthetic
%   1 Hz historical signal for SensorTag `key` over the time vector
%   `tHist` (column of MATLAB datenums). The signal is:
%       y(t) = baseline(t) + sum(excursions(t))
%   then clamped to cfg.Ranges.<field>.
%
%   For sensors with no monitor (cfg.MonitorDefs lookup misses) the
%   excursion overlay is empty and y is the bare sine + noise baseline.
%   Monitored sensors get a deterministic excursion schedule (Task 3).
%
%   The caller is responsible for seeding the RNG before calling this
%   function. Inside this function we only use randn() / rand() — no
%   reseeding — so multiple sensor calls in the same `seedHistory` run
%   produce a coherent, reproducible record.
%
%   See also: seedHistory, plantConfig.

    field = strrep(key, '.', '_');
    assert(isfield(cfg.Baselines, field), ...
        sprintf('plantConfig().Baselines.%s missing for key=%s', field, key));
    assert(isfield(cfg.Ranges, field), ...
        sprintf('plantConfig().Ranges.%s missing for key=%s', field, key));

    b         = cfg.Baselines.(field);
    sensorRng = cfg.Ranges.(field);

    tHist = tHist(:);
    tRel  = (tHist - tHist(1)) * 86400;   % seconds since first sample

    % Baseline: sine + Gaussian noise (matches makeDataGenerator's model).
    y = b.mean + b.amp * sin(2*pi*tRel/b.period + b.phase) ...
          + b.noise * randn(size(tRel));

    % Excursion overlay (monitored sensors only). Task 3 fills this in;
    % for now this is a no-op.
    y = applyExcursions_(cfg, key, tHist, tRel, y);

    % Clamp to physical range so the signal stays plausible.
    y = max(sensorRng(1), min(sensorRng(2), y));
end

function y = applyExcursions_(cfg, key, tHist, tRel, y) %#ok<INUSL>
    %APPLYEXCURSIONS_ Overlay the monitored sensor's excursion schedule.
    %   For sensors with no MonitorDef this is a silent no-op. Otherwise
    %   we draw a deterministic schedule of (tStart, duration, deltaPeak)
    %   tuples from the seeded RNG and add a triangular-ramp perturbation
    %   on the baseline for each tuple.

    monIdx = findMonitorByParent_(cfg, key);
    if isempty(monIdx)
        return;
    end
    mDef = cfg.MonitorDefs(monIdx);

    % Identify trip threshold + direction by inspecting the canonical
    % display threshold for this parent (single source of truth, set
    % alongside the monitor in plantConfig.mkDisplayThresholds_).
    field = strrep(key, '.', '_');
    if ~isfield(cfg.DisplayThresholds, field) || isempty(cfg.DisplayThresholds.(field))
        return;
    end
    th        = cfg.DisplayThresholds.(field){1};
    tripVal   = th.Value;
    direction = th.Direction;   % 'upper' or 'lower'

    % Hysteresis band: distance from trip to release. Used to size the
    % peak overshoot in the excursion model so trips reliably fire.
    hystBand = estimateHystBand_(mDef, tripVal);

    % Schedule: 18-28 short trips + 5-8 long breaches + 1-2 cascade
    % windows (each containing 3-5 short trips). All times are in
    % seconds since tHist(1); converted to indices into tRel below.
    excursions = struct('tStart', {}, 'duration', {}, 'deltaPeak', {});

    nShort = randi([18, 28]);
    nLong  = randi([5, 8]);
    nCasc  = randi([1, 2]);

    secsTotal = tRel(end);

    for k = 1:nShort
        e.tStart    = rand() * secsTotal;
        e.duration  = 5 + rand() * 25;                    % 5-30 s
        e.deltaPeak = (1.1 + rand()*0.2) * hystBand;      % 1.1-1.3x band
        excursions(end+1) = e; %#ok<AGROW>
    end

    for k = 1:nLong %#ok<FXUP>
        e.tStart    = rand() * (secsTotal - 30*60);
        e.duration  = 5*60 + rand() * (25*60);            % 5-30 min
        e.deltaPeak = (0.5 + rand()*0.5) * hystBand;      % 0.5-1.0x band
        excursions(end+1) = e; %#ok<AGROW>
    end

    for k = 1:nCasc %#ok<FXUP>
        windowStart = rand() * (secsTotal - 10*60);
        nTrips = randi([3, 5]);
        for j = 1:nTrips
            e.tStart    = windowStart + rand() * 10*60;
            e.duration  = 5 + rand() * 25;
            e.deltaPeak = (1.1 + rand()*0.2) * hystBand;
            excursions(end+1) = e; %#ok<AGROW>
        end
    end

    % Apply each excursion as a triangular ramp on the baseline.
    % NB: don't name a local `sign` — it shadows MATLAB's built-in sign().
    dirSign = +1;
    if strcmp(direction, 'lower')
        dirSign = -1;
    end
    % Snapshot the baseline so each excursion is sized against the
    % CLEAN baseline mean. Without this, sequential overlapping
    % excursions would compute mean(y(idx)) on a signal already
    % perturbed by an earlier excursion and amplify the breach.
    yBase = y;
    for i = 1:numel(excursions)
        e = excursions(i);
        idx = (tRel >= e.tStart) & (tRel <= e.tStart + e.duration);
        if ~any(idx)
            continue;
        end
        u = (tRel(idx) - e.tStart) / max(e.duration, eps);
        ramp = 1 - 2 * abs(u - 0.5);                     % triangle 0->1->0
        % Push baseline past the trip by deltaPeak in the trip direction.
        y(idx) = y(idx) + dirSign * (abs(tripVal - mean(yBase(idx))) + e.deltaPeak) .* ramp;
    end
end

function idx = findMonitorByParent_(cfg, parentKey)
    %FINDMONITORBYPARENT_ Return index into cfg.MonitorDefs whose ParentKey
    %   matches parentKey, or [] if none.
    idx = [];
    for k = 1:numel(cfg.MonitorDefs)
        if strcmp(cfg.MonitorDefs(k).ParentKey, parentKey)
            idx = k;
            return;
        end
    end
end

function band = estimateHystBand_(mDef, tripVal)
    %ESTIMATEHYSTBAND_ Probe AlarmOffFn to estimate the hysteresis band.
    %   Try a sweep of values bracketing tripVal; the band is the gap
    %   between the trip and the nearest value where AlarmOffFn is true.
    if isempty(mDef.AlarmOffFn)
        band = max(1.0, abs(tripVal) * 0.05);    % 5% fallback
        return;
    end
    % Sweep [tripVal - 50%, tripVal + 60%] of tripVal — asymmetric upper
    % bound so a strict `> tripVal*1.5` lower-direction release condition
    % (e.g. cooling.flow's `y > 30` with tripVal = 20) finds candidates
    % rather than falling through to the 5% fallback.
    candidates = tripVal + linspace(-tripVal*0.5, tripVal*0.6, 401);
    offMask = false(size(candidates));
    for k = 1:numel(candidates)
        try
            offMask(k) = logical(mDef.AlarmOffFn(0, candidates(k)));
        catch
            offMask(k) = false;
        end
    end
    if ~any(offMask)
        band = max(1.0, abs(tripVal) * 0.05);
        return;
    end
    % Distance from trip to the nearest "release" candidate.
    diffs = abs(candidates(offMask) - tripVal);
    band  = max(min(diffs), 0.5);
end
