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

    % Phase 1017: register the EventStore as the registry default. Every
    % MonitorTag constructed below picks this up via the constructor
    % fallback, and every dashboard widget (FastSense, FastSenseWidget,
    % EventTimelineWidget, TableWidget) auto-discovers it on render.
    TagRegistry.setEventStore(store);

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
            'Labels',    {canonicalSubsystem_(key, cfg.Subsystems)}, ...
            'RawSource', rs);
        TagRegistry.register(key, s);
    end

    % ---- StateTags (inlined for acceptance visibility) ----
    % Labels carries the SUBSYSTEM classification (used by the tag catalog tree
    % for grouping). The state-value vocabulary lives in the Y data / ZOH lookup;
    % it is no longer stored in Labels. cfg.Labels still holds the vocab for the
    % data generator (makeDataGenerator reads cfg.Labels, not the tag object).
    valveState = StateTag('feedline.valve_state', ...
        'Name',      'Feedline Valve State', ...
        'Labels',    {'FeedLine'}, ...
        'RawSource', struct( ...
            'file',   fullfile(rawDir, 'feedline.valve_state.dat'), ...
            'column', 'value', ...
            'format', ''));
    TagRegistry.register('feedline.valve_state', valveState);

    reactorMode = StateTag('reactor.mode', ...
        'Name',      'Reactor Mode', ...
        'Labels',    {'Reactor'}, ...
        'RawSource', struct( ...
            'file',   fullfile(rawDir, 'reactor.mode.dat'), ...
            'column', 'value', ...
            'format', ''));
    TagRegistry.register('reactor.mode', reactorMode);

    % ---- MonitorTags (inlined; cfg.MonitorDefs is the source of truth
    % for thresholds / hysteresis / debounce; the inline unrolling below
    % just wires each rule into TagRegistry with a readable call site) ----

    mDefs = cfg.MonitorDefs;  % expects 4 entries in fixed order, see plantConfig

    % MinDurationSeconds carries debounce in human-readable seconds;
    % cfg.MonitorMinDurationFor converts to the parent-X native unit
    % (datenum days in this demo). See plantConfig.mkDef_ docstring.
    toMinDuration = cfg.MonitorMinDurationFor;

    % Labels carries the subsystem classification so the tag catalog groups
    % monitors under their subsystem (e.g. 'FeedLine', 'Reactor', 'Cooling').
    % mDefs(k).Subsystem holds the canonical subsystem string from plantConfig.
    mFeedlinePressureHigh = MonitorTag(mDefs(1).Key, ...
        TagRegistry.get(mDefs(1).ParentKey), mDefs(1).ConditionFn, ...
        'AlarmOffConditionFn', mDefs(1).AlarmOffFn, ...
        'MinDuration',         toMinDuration(mDefs(1).MinDurationSeconds), ...
        'Criticality',         mDefs(1).Criticality, ...
        'Labels',              {mDefs(1).Subsystem}, ...
        'Name',                prettyName_(mDefs(1).Key));
    TagRegistry.register(mDefs(1).Key, mFeedlinePressureHigh);

    mReactorPressureCritical = MonitorTag(mDefs(2).Key, ...
        TagRegistry.get(mDefs(2).ParentKey), mDefs(2).ConditionFn, ...
        'AlarmOffConditionFn', mDefs(2).AlarmOffFn, ...
        'MinDuration',         toMinDuration(mDefs(2).MinDurationSeconds), ...
        'Criticality',         mDefs(2).Criticality, ...
        'Labels',              {mDefs(2).Subsystem}, ...
        'Name',                prettyName_(mDefs(2).Key));
    TagRegistry.register(mDefs(2).Key, mReactorPressureCritical);

    mReactorTemperatureHigh = MonitorTag(mDefs(3).Key, ...
        TagRegistry.get(mDefs(3).ParentKey), mDefs(3).ConditionFn, ...
        'AlarmOffConditionFn', mDefs(3).AlarmOffFn, ...
        'MinDuration',         toMinDuration(mDefs(3).MinDurationSeconds), ...
        'Criticality',         mDefs(3).Criticality, ...
        'Labels',              {mDefs(3).Subsystem}, ...
        'Name',                prettyName_(mDefs(3).Key));
    TagRegistry.register(mDefs(3).Key, mReactorTemperatureHigh);

    mCoolingFlowLow = MonitorTag(mDefs(4).Key, ...
        TagRegistry.get(mDefs(4).ParentKey), mDefs(4).ConditionFn, ...
        'AlarmOffConditionFn', mDefs(4).AlarmOffFn, ...
        'MinDuration',         toMinDuration(mDefs(4).MinDurationSeconds), ...
        'Criticality',         mDefs(4).Criticality, ...
        'Labels',              {mDefs(4).Subsystem}, ...
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

function sub = canonicalSubsystem_(key, subsystems)
    %CANONICALSUBSYSTEM_ Return the canonical subsystem string for a tag key.
    %   Extracts the first dot-separated token from key, then matches it
    %   case-insensitively against the subsystems cell-array.  When a match
    %   is found the canonical casing from subsystems is returned (e.g.
    %   'feedline' matches 'FeedLine' -> returns 'FeedLine').  If no match
    %   is found the token is title-cased (upper first char, lower rest).
    parts = strsplit(key, '.');
    if isempty(parts) || isempty(parts{1})
        sub = '';
        return;
    end
    token = parts{1};
    for k = 1:numel(subsystems)
        if strcmpi(token, subsystems{k})
            sub = subsystems{k};
            return;
        end
    end
    % Fallback: title-case the token
    sub = [upper(token(1)), lower(token(2:end))];
end
