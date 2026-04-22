function [store, plantHealthKey] = registerPlantTags(rawDir)
%REGISTERPLANTTAGS Populate TagRegistry with the full plant taxonomy.
%   [store, plantHealthKey] = registerPlantTags(rawDir) clears TagRegistry,
%   constructs SensorTag/StateTag/MonitorTag/CompositeTag objects from
%   plantConfig(), and registers them. The rawDir parameter is used to
%   build RawSource.file paths for the SensorTag/StateTag objects so the
%   LiveTagPipeline can ingest each tag's .dat file.
%
%   Returns:
%     store          - EventStore instance wired into every MonitorTag
%                      (events surface in Phase 1015 Plan 02 dashboard)
%     plantHealthKey - char, top-level CompositeTag key ('plant.health')
%
%   Tag inventory (per plantConfig):
%     8 SensorTag:
%       feedline.pressure, feedline.flow,
%       reactor.pressure, reactor.temperature, reactor.rpm,
%       cooling.in_temp, cooling.out_temp, cooling.flow
%     2 StateTag:
%       feedline.valve_state, reactor.mode
%     4 MonitorTag (with debounce + hysteresis):
%       feedline.pressure.high, reactor.pressure.critical,
%       reactor.temperature.high, cooling.flow.low
%     4 CompositeTag:
%       feedline.health, reactor.health, cooling.health, plant.health
%
%   See also: plantConfig, startLivePipeline, run_demo.

    if ~ischar(rawDir) || isempty(rawDir)
        error('IndustrialPlant:invalidRawDir', ...
            'rawDir must be a non-empty char.');
    end

    % Clean-start registry (D-02): wipe any stale demo state.
    TagRegistry.clear();

    cfg = plantConfig();

    % EventStore needs a file path (atomic save); demo uses a tempname so
    % nothing persists between runs (D-02 clean-start).
    % Use an Octave-safe pid getter (feature('getpid') is MATLAB-only).
    pid = 0;
    try
        if exist('OCTAVE_VERSION', 'builtin')
            pid = double(getpid());
        else
            pid = double(feature('getpid'));
        end
    catch
        pid = 0;
    end
    eventFile = fullfile(tempdir(), sprintf('industrial_plant_events_%d.mat', pid));
    store = EventStore(eventFile);

    % ---- SensorTags ----
    for i = 1:numel(cfg.SensorKeys)
        key    = cfg.SensorKeys{i};
        field  = keyToField(key);
        units  = cfg.Units.(field);
        rs     = struct( ...
            'file',   fullfile(rawDir, [key '.dat']), ...
            'column', 'value', ...
            'format', '');
        s = SensorTag(key, ...
            'Name',      prettyName_(key), ...
            'Units',     units, ...
            'Labels',    {subsystemOf_(key)}, ...
            'RawSource', rs);
        TagRegistry.register(key, s);
    end

    % ---- StateTags (inlined for acceptance visibility) ----
    valveState = StateTag('feedline.valve_state', ...
        'Name',      'Feedline Valve State', ...
        'Labels',    cfg.Labels.('feedline_valve_state'), ...
        'RawSource', struct( ...
            'file',   fullfile(rawDir, 'feedline.valve_state.dat'), ...
            'column', 'value', ...
            'format', ''));
    TagRegistry.register('feedline.valve_state', valveState);

    reactorMode = StateTag('reactor.mode', ...
        'Name',      'Reactor Mode', ...
        'Labels',    cfg.Labels.('reactor_mode'), ...
        'RawSource', struct( ...
            'file',   fullfile(rawDir, 'reactor.mode.dat'), ...
            'column', 'value', ...
            'format', ''));
    TagRegistry.register('reactor.mode', reactorMode);

    % ---- MonitorTags (inlined; cfg.MonitorDefs is the source of truth
    % for thresholds / hysteresis / debounce; the inline unrolling below
    % just wires each rule into TagRegistry with a readable call site) ----

    mDefs = cfg.MonitorDefs;  % expects 4 entries in fixed order, see plantConfig

    mFeedlinePressureHigh = MonitorTag(mDefs(1).Key, ...
        TagRegistry.get(mDefs(1).ParentKey), mDefs(1).ConditionFn, ...
        'AlarmOffConditionFn', mDefs(1).AlarmOffFn, ...
        'MinDuration',         mDefs(1).MinDuration, ...
        'Criticality',         mDefs(1).Criticality, ...
        'EventStore',          store, ...
        'Name',                prettyName_(mDefs(1).Key));
    TagRegistry.register(mDefs(1).Key, mFeedlinePressureHigh);

    mReactorPressureCritical = MonitorTag(mDefs(2).Key, ...
        TagRegistry.get(mDefs(2).ParentKey), mDefs(2).ConditionFn, ...
        'AlarmOffConditionFn', mDefs(2).AlarmOffFn, ...
        'MinDuration',         mDefs(2).MinDuration, ...
        'Criticality',         mDefs(2).Criticality, ...
        'EventStore',          store, ...
        'Name',                prettyName_(mDefs(2).Key));
    TagRegistry.register(mDefs(2).Key, mReactorPressureCritical);

    mReactorTemperatureHigh = MonitorTag(mDefs(3).Key, ...
        TagRegistry.get(mDefs(3).ParentKey), mDefs(3).ConditionFn, ...
        'AlarmOffConditionFn', mDefs(3).AlarmOffFn, ...
        'MinDuration',         mDefs(3).MinDuration, ...
        'Criticality',         mDefs(3).Criticality, ...
        'EventStore',          store, ...
        'Name',                prettyName_(mDefs(3).Key));
    TagRegistry.register(mDefs(3).Key, mReactorTemperatureHigh);

    mCoolingFlowLow = MonitorTag(mDefs(4).Key, ...
        TagRegistry.get(mDefs(4).ParentKey), mDefs(4).ConditionFn, ...
        'AlarmOffConditionFn', mDefs(4).AlarmOffFn, ...
        'MinDuration',         mDefs(4).MinDuration, ...
        'Criticality',         mDefs(4).Criticality, ...
        'EventStore',          store, ...
        'Name',                prettyName_(mDefs(4).Key));
    TagRegistry.register(mDefs(4).Key, mCoolingFlowLow);

    % ---- Subsystem CompositeTags (OR rollup per subsystem) ----
    feedlineHealth = CompositeTag('feedline.health', 'or', ...
        'Name', 'FeedLine Health', 'Labels', {'FeedLine'});
    feedlineHealth.addChild(mFeedlinePressureHigh);
    TagRegistry.register('feedline.health', feedlineHealth);

    reactorHealth = CompositeTag('reactor.health', 'or', ...
        'Name', 'Reactor Health', 'Labels', {'Reactor'});
    reactorHealth.addChild(mReactorPressureCritical);
    reactorHealth.addChild(mReactorTemperatureHigh);
    TagRegistry.register('reactor.health', reactorHealth);

    coolingHealth = CompositeTag('cooling.health', 'or', ...
        'Name', 'Cooling Health', 'Labels', {'Cooling'});
    coolingHealth.addChild(mCoolingFlowLow);
    TagRegistry.register('cooling.health', coolingHealth);

    % ---- Top-level plant.health CompositeTag ----
    plantHealthKey = cfg.CompositeKey;
    plantHealth = CompositeTag(plantHealthKey, 'or', ...
        'Name', 'Plant Health', 'Labels', {'rollup'});
    plantHealth.addChild(feedlineHealth);
    plantHealth.addChild(reactorHealth);
    plantHealth.addChild(coolingHealth);
    TagRegistry.register(plantHealthKey, plantHealth);
end

function name = prettyName_(key)
    %PRETTYNAME_ Convert 'reactor.pressure' to 'Reactor Pressure'.
    parts = strsplit(key, '.');
    for i = 1:numel(parts)
        p = parts{i};
        if ~isempty(p)
            parts{i} = [upper(p(1)) p(2:end)];
        end
    end
    name = strrep(strjoin(parts, ' '), '_', ' ');
end

function sub = subsystemOf_(key)
    %SUBSYSTEMOF_ Extract the subsystem prefix from a dotted tag key.
    parts = strsplit(key, '.');
    if isempty(parts)
        sub = '';
        return;
    end
    p = parts{1};
    if ~isempty(p)
        sub = [upper(p(1)) p(2:end)];
    else
        sub = '';
    end
end
