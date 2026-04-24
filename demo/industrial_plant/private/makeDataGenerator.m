function t = makeDataGenerator(rawDir, varargin)
%MAKEDATAGENERATOR Build the synthetic industrial-plant writer timer.
%   t = makeDataGenerator(rawDir) returns an unstarted MATLAB timer that,
%   when started, appends one new row per configured tag to its own .dat
%   file under rawDir every second (Period=1.0, fixedRate).
%
%   t = makeDataGenerator(rawDir, 'Name', 'Val', ...) accepts optional
%   name-value overrides (currently 'Registry' to inject a config object;
%   intended for test isolation).
%
%   Row layout (per D-01 / D-12):
%     Sensor .dat lines: "<datenum>,<value>\n"   (%.9f,%.6f)
%     State  .dat lines: "<datenum>,<label>\n"   (%.9f,%s)
%
%   Time base: MATLAB serial date number (datenum). All X values fed to
%   TagRegistry / FastSense are datenum-style doubles so FastSense's
%   datetime-aware axis formatting kicks in automatically.
%
%   Signal model (per tag):
%     y(t) = mean + amp*sin(2*pi*t/period + phase) + noise*randn
%   Plus deliberate anomaly injections near t=15 and t=45 on
%   reactor.pressure and feedline.pressure so MonitorTag events fire
%   reliably in the downstream test (plan 01 test 3).
%
%   Timer UserData:
%     .cfg        - plantConfig() output
%     .rawDir     - char, writer root
%     .tStart     - scalar datenum captured at first tick
%     .step       - monotonically increasing tick counter (1..N)
%     .stateIdx   - struct: stateKey_field -> last-emitted label index
%
%   See also: plantConfig, registerPlantTags, run_demo, LiveTagPipeline.

    if ~ischar(rawDir) || isempty(rawDir)
        error('IndustrialPlant:invalidRawDir', ...
            'rawDir must be a non-empty char.');
    end
    if ~exist(rawDir, 'dir')
        [ok, msg] = mkdir(rawDir);
        if ~ok
            error('IndustrialPlant:cannotCreateRawDir', ...
                'Cannot create rawDir ''%s'': %s', rawDir, msg);
        end
    end

    cfg = plantConfig();

    ud = struct();
    ud.cfg      = cfg;
    ud.rawDir   = rawDir;
    ud.tStart   = [];
    ud.step     = 0;
    ud.stateIdx = struct();
    % Per-tag accumulators so we can push fresh X/Y into the registered
    % tag objects on every tick (the LiveTagPipeline handles .mat
    % persistence; the in-memory path is driven directly here).
    ud.sensorX = struct();
    ud.sensorY = struct();
    ud.stateX  = struct();
    ud.stateY  = struct();

    t = timer( ...
        'Name',          'IndustrialPlantDataGen', ...
        'ExecutionMode', 'fixedRate', ...
        'Period',        1.0, ...
        'BusyMode',      'drop', ...
        'UserData',      ud, ...
        'TimerFcn',      @industrialPlantTick_);

    % Note: varargin currently unused (reserved for future injection).
    %#ok<*INUSD>
end

function industrialPlantTick_(tObj, ~)
    %INDUSTRIALPLANTTICK_ One writer tick: append one row per tag.
    ud  = tObj.UserData;
    cfg = ud.cfg;

    nowTime = nowDatenum_();
    if isempty(ud.tStart)
        ud.tStart = nowTime;
    end
    ud.step = ud.step + 1;
    step    = ud.step;
    tRel    = double(step - 1);   % seconds since first tick (0-based)

    % ---- Continuous sensors ----
    for i = 1:numel(cfg.SensorKeys)
        key   = cfg.SensorKeys{i};
        field = keyToField(key);
        b     = cfg.Baselines.(field);
        rng   = cfg.Ranges.(field);

        y = b.mean + b.amp * sin(2*pi*tRel/b.period + b.phase) ...
              + b.noise * randn();

        % Inject deliberate anomalies for event demo (D-11 in CONTEXT).
        if strcmp(key, 'reactor.pressure')
            if tRel >= 15 && tRel <= 18
                y = 19.2 + 0.1 * randn();  % breaches >18 critical
            elseif tRel >= 45 && tRel <= 48
                y = 19.5 + 0.1 * randn();
            end
        elseif strcmp(key, 'feedline.pressure')
            if tRel >= 20 && tRel <= 25
                y = 8.6 + 0.05 * randn();  % breaches >8 warning
            elseif tRel >= 50 && tRel <= 55
                y = 8.8 + 0.05 * randn();
            end
        end

        % Clamp to physical range so the signal stays plausible.
        y = max(rng(1), min(rng(2), y));

        appendRow_(ud.rawDir, key, nowTime, y, 'sensor');

        % Update in-memory accumulators + push to the registered tag so
        % getXY() / valueAt() / MonitorTag listeners see fresh data
        % without waiting for a LiveTagPipeline round-trip.
        if ~isfield(ud.sensorX, field)
            ud.sensorX.(field) = [];
            ud.sensorY.(field) = [];
        end
        ud.sensorX.(field)(end+1) = nowTime; %#ok<AGROW>
        ud.sensorY.(field)(end+1) = y;        %#ok<AGROW>
        pushToSensorTag_(key, ud.sensorX.(field), ud.sensorY.(field));
    end

    % ---- Discrete states ----
    for i = 1:numel(cfg.StateKeys)
        key      = cfg.StateKeys{i};
        field    = keyToField(key);
        schedule = cfg.StateSchedule.(field);
        labels   = cfg.Labels.(field);

        idx = 1;
        for k = 1:numel(schedule)
            if tRel >= schedule(k).t
                idx = schedule(k).idx;
            end
        end
        % Only emit a row when the label index changes OR on the first tick.
        prevIdx = NaN;
        if isfield(ud.stateIdx, field)
            prevIdx = ud.stateIdx.(field);
        end
        if isnan(prevIdx) || prevIdx ~= idx
            appendRow_(ud.rawDir, key, nowTime, labels{idx}, 'state');
            ud.stateIdx.(field) = idx;
            if ~isfield(ud.stateX, field)
                ud.stateX.(field) = [];
                ud.stateY.(field) = {};
            end
            ud.stateX.(field)(end+1) = nowTime;     %#ok<AGROW>
            ud.stateY.(field){end+1} = labels{idx};  %#ok<AGROW>
            pushToStateTag_(key, ud.stateX.(field), ud.stateY.(field));
        end
    end

    tObj.UserData = ud;
end

function pushToSensorTag_(key, xAll, yAll)
    %PUSHTOSENSORTAG_ Replace the registered SensorTag's X/Y vector.
    %   Silent no-op when the tag is not registered (e.g. the timer was
    %   started before registerPlantTags or after teardown).
    try
        tag = TagRegistry.get(key);
    catch
        return;
    end
    if isa(tag, 'SensorTag')
        tag.updateData(xAll(:), yAll(:));
    end
end

function pushToStateTag_(key, xAll, yAll)
    %PUSHTOSTATETAG_ Replace the registered StateTag's X/Y vector.
    %   Y is kept as a cellstr to match StateTag's valueAt contract.
    try
        tag = TagRegistry.get(key);
    catch
        return;
    end
    if isa(tag, 'StateTag')
        tag.X = xAll(:);
        tag.Y = yAll(:);
    end
end

function appendRow_(rawDir, key, timeVal, value, kind)
    %APPENDROW_ Append a single row to <rawDir>/<key>.dat for the tag.
    %   timeVal is a MATLAB datenum (days since 0000-01-00).
    path = fullfile(rawDir, [key '.dat']);
    isNew = ~exist(path, 'file');
    fid = fopen(path, 'a');
    if fid == -1
        warning('IndustrialPlant:fopenFailed', ...
            'Could not open %s for append.', path);
        return;
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    if isNew
        % Header row so LiveTagPipeline's tall-file path picks up named
        % time+value columns cleanly.
        fprintf(fid, 'time,value\n');
    end

    switch kind
        case 'sensor'
            fprintf(fid, '%.9f,%.6f\n', timeVal, value);
        case 'state'
            fprintf(fid, '%.9f,%s\n', timeVal, value);
    end
end

function d = nowDatenum_()
    %NOWDATENUM_ Return the current time as a MATLAB serial date number.
    %   Octave-safe: now() returns a datenum in both MATLAB and Octave.
    d = now();
end
