function seedHistory(store, cfg)
%SEEDHISTORY Preload 7 days of synthetic sensor + state history + events.
%   seedHistory(store, cfg) preloads the TagRegistry and the shared
%   EventStore with one week of historical data:
%
%     1) For each SensorTag in cfg.SensorKeys, generate 1 Hz historical
%        samples from now-7d through now (synthetic sine + noise + the
%        deterministic excursion schedule for monitored sensors), then
%        push via tag.updateData(...).
%     2) Build a 7-day daily-cycle schedule
%        (idle/heating/running/cooldown/idle) via buildStateHistory and
%        assign it to the two known StateTags (`feedline.valve_state`,
%        `reactor.mode`). buildStateHistory is hard-wired to those two
%        keys; if plantConfig adds a new StateTag it will be silently
%        skipped here until both this dispatch and buildStateHistory
%        are extended.
%     3) Trigger each MonitorTag's detector by reading getXY() so it
%        emits real Event objects into `store` for every actual
%        threshold violation in the historical samples.
%     4) Map event.Severity from each firing monitor's Criticality
%        (low->1, medium->2, high->3, safety->3) so the EventViewer
%        table reflects what the monitor's Criticality says.
%     5) Persist the store atomically.
%
%   The function reseeds RNG to 1015 at entry and restores the previous
%   RNG state at exit, so live mode's randn() calls continue with fresh
%   state.
%
%   Caller contract:
%     - registerPlantTags(rawDir) must have run already (TagRegistry is
%       populated and `store` is the EventStore wired into every
%       MonitorTag).
%     - The writer timer must NOT have started yet — its first tick
%       should land strictly after the historical window.
%
%   See also: run_demo, registerPlantTags, buildSensorExcursions,
%             buildStateHistory.

    if ~isa(store, 'EventStore')
        error('IndustrialPlant:invalidStore', ...
            'store must be an EventStore.');
    end
    if ~isstruct(cfg)
        error('IndustrialPlant:invalidCfg', ...
            'cfg must be a struct (plantConfig() output).');
    end

    % --- Seed RNG, restore on exit -------------------------------------
    prevRng = rng(1015, 'twister');
    cleanup = onCleanup(@() rng(prevRng)); %#ok<NASGU>

    % --- Time vector ---------------------------------------------------
    nowRef = now();
    nDays  = 7;
    tHist  = (nowRef - nDays : 1/86400 : nowRef)';

    % --- 1) Sensor history --------------------------------------------
    for i = 1:numel(cfg.SensorKeys)
        key   = cfg.SensorKeys{i};
        try
            tag = TagRegistry.get(key);
        catch
            continue;     % unregistered: skip silently
        end
        if ~isa(tag, 'SensorTag')
            continue;
        end
        y = buildSensorExcursions(cfg, key, tHist);
        tag.updateData(tHist, y);
    end

    % --- 2) State history ---------------------------------------------
    [xValve, yValve, xMode, yMode] = buildStateHistory(cfg, nowRef - nDays, nDays);
    try
        valveTag = TagRegistry.get('feedline.valve_state');
        valveTag.X = xValve;
        valveTag.Y = yValve;
    catch
    end
    try
        modeTag = TagRegistry.get('reactor.mode');
        modeTag.X = xMode;
        modeTag.Y = yMode;
    catch
    end

    % --- 3) Trigger MonitorTag detection ------------------------------
    for k = 1:numel(cfg.MonitorDefs)
        mKey = cfg.MonitorDefs(k).Key;
        try
            mon = TagRegistry.get(mKey);
            [~, ~] = mon.getXY();   % drives recompute_ -> emits events
        catch
        end
    end

    % --- 4) Map Event.Severity from monitor.Criticality ---------------
    evs = store.getEvents();
    for k = 1:numel(evs)
        ev = evs(k);
        try
            mon = TagRegistry.get(ev.ThresholdLabel);
            ev.Severity = critToNumeric_(mon.Criticality);
        catch
        end
    end

    % --- 5) Persist ---------------------------------------------------
    store.save();
end

function n = critToNumeric_(crit)
    %CRITTONUMERIC_ Map Tag.Criticality enum to Event.Severity numeric.
    %   Event.Severity contract: 1=ok/info, 2=warn, 3=alarm.
    switch lower(char(crit))
        case 'low'
            n = 1;
        case 'medium'
            n = 2;
        case {'high', 'safety'}
            n = 3;
        otherwise
            n = 1;
    end
end
