function ctx = run_demo(varargin)
%RUN_DEMO Industrial plant live demo entry point (plan-01 scaffold).
%   ctx = run_demo() bootstraps the synthetic data generator, the live
%   TagRegistry wiring, and the LiveTagPipeline -- the non-UI plumbing
%   for the Phase 1015 demo. Plan 02 extends this entry point to build
%   the multi-page dashboard; for now the returned ctx carries all the
%   handles a caller (or a test) needs to observe the pipeline.
%
%   Options (name-value pairs):
%     'Companion' (logical, default true) -- when true, run_demo also
%       constructs a FastSenseCompanion window over the demo's
%       DashboardEngine + populated TagRegistry. Pass false to suppress
%       (e.g., for headless tests that only need the dashboard).
%
%   Returns:
%     ctx - struct with fields:
%       writerTimer    - IndustrialPlantDataGen MATLAB timer (running)
%       pipeline       - LiveTagPipeline (running)
%       engine         - DashboardEngine handle (live, populated by buildDashboard)
%       companion      - FastSenseCompanion handle (or [] when 'Companion'=false)
%       store          - EventStore wired into every MonitorTag
%       plantHealthKey - 'plant.health' (top-level rollup)
%       rawDir         - absolute path to demo/industrial_plant/data/raw
%       tagsDir        - absolute path to demo/industrial_plant/data/tags
%       plantLogPath   - absolute path to the generated plant_log.csv (or
%                        '' if seeding/attaching failed; see warning
%                        run_demo:plantLogAttachFailed)
%
%   Teardown:
%     teardownDemo(ctx);
%
%   Example:
%     install();
%     ctx = run_demo();
%     pause(5);
%     [x, y] = TagRegistry.get('reactor.pressure').getXY();
%     teardownDemo(ctx);
%
%     % Suppress the companion window (dashboard only):
%     ctx = run_demo('Companion', false);
%
%     % Tear down both windows when done:
%     teardownDemo(ctx);
%
%   See also: plantConfig, registerPlantTags, makeDataGenerator,
%             startLivePipeline, seedPlantLog, teardownDemo,
%             TagRegistry, LiveTagPipeline.

    here    = fileparts(mfilename('fullpath'));

    % Parse name-value options (matches FastSenseCompanion's varargin parser convention).
    useCompanion = true;
    stressMode   = 'off';   % off | small | medium | large -- see stressFleets()
    for k = 1:2:numel(varargin)
        key = varargin{k};
        switch key
            case 'Companion'
                useCompanion = logical(varargin{k+1});
            case 'StressMode'
                stressMode = varargin{k+1};
            otherwise
                error('run_demo:unknownOption', ...
                    'Unknown option ''%s''. Valid options: Companion, StressMode.', key);
        end
    end

    rawDir  = fullfile(here, 'data', 'raw');
    tagsDir = fullfile(here, 'data', 'tags');

    % Clean-start on every run (D-02).
    if exist(rawDir, 'dir')
        rmdir(rawDir, 's');
    end
    mkdir(rawDir);

    % Populate TagRegistry first so the generator's pushToSensorTag_ calls
    % find a target on the very first tick.
    [store, plantHealthKey] = registerPlantTags(rawDir);

    % Stress fleets (opt-in): register extra synthetic SensorTags backed by
    % shared multi-column .dat files so LiveTagPipeline can be exercised at
    % scale (K << N case where K=files, N=tags). No-op for default 'off'.
    fleets = stressFleets(stressMode);
    fleetTagKeys = registerStressFleetTags(rawDir, fleets);

    % Preload one week of synthetic 1 Hz history into every SensorTag /
    % StateTag, drive the MonitorTag detector over that history so the
    % EventStore is populated with real (not injected) events, and
    % persist the store. seedHistory must run BEFORE the writer timer
    % starts so the first live tick lands strictly after the historical
    % window. Deterministic under rng(1015); restored on exit.
    seedHistory(store, plantConfig());

    % Build the writer timer (unstarted), then the pipeline, then start both.
    writerTimer = makeDataGenerator(rawDir, 'Fleets', fleets);
    start(writerTimer);
    pipeline = startLivePipeline(rawDir, tagsDir);

    % Wait for the first writer tick so Tag X/Y have >=1 sample before
    % buildDashboard() calls engine.render(). FastSense's XLim set step
    % requires xmin<xmax; rendering with zero samples throws. Poll up to
    % ~2.5s for at least 2 samples on the canonical SensorTag.
    waitForFirstSample_('reactor.pressure', 2.5);

    ctx = struct( ...
        'writerTimer',    writerTimer, ...
        'pipeline',       pipeline, ...
        'engine',         [], ...
        'companion',      [], ...
        'store',          store, ...
        'plantHealthKey', plantHealthKey, ...
        'rawDir',         rawDir, ...
        'tagsDir',        tagsDir, ...
        'plantLogPath',   '', ...
        'stressMode',     stressMode, ...
        'fleetTagKeys',   {fleetTagKeys});

    % Plan 02 hook: build the full dashboard on top of the plumbing.
    % buildDashboard creates the DashboardEngine, renders the figure,
    % starts the live timer, and wires a CloseRequestFcn that calls
    % teardownDemo(ctx).
    ctx.engine = buildDashboard(ctx);

    % Phase 1023 -- opt-in companion window (built AFTER buildDashboard so
    % ctx.engine is a live handle the companion can wrap).
    if useCompanion
        ctx.companion = buildCompanion(ctx);
    else
        ctx.companion = [];
    end

    % Phase 1033 / milestone v3.1 -- seed a synthetic plant log and
    % attach it to the dashboard so the slider preview + per-widget
    % overlay are exercised end-to-end. Best-effort: a failure here
    % must not crash the demo bootstrap (dashboard + writer + pipeline
    % keep running so the rest of the demo stays usable).
    try
        ctx.plantLogPath = seedPlantLog(rawDir, plantConfig());
        if ~isempty(ctx.engine) && isvalid(ctx.engine)
            ctx.engine.attachPlantLog(ctx.plantLogPath);
        end
    catch err
        warning('run_demo:plantLogAttachFailed', ...
            'Seed/attach plant log failed: %s (demo continues without plant log)', ...
            err.message);
        ctx.plantLogPath = '';
    end

    % Phase 1023.1 cross-phase fix: re-bind the dashboard figure's
    % CloseRequestFcn with the now-complete ctx. buildDashboard set the
    % callback when ctx.companion was still [], so the closure captured
    % an empty companion handle. Re-set here with the populated ctx so
    % demoClose_ can read ctx.companion correctly.
    if ~isempty(ctx.engine) && ~isempty(ctx.engine.hFigure) && ishandle(ctx.engine.hFigure)
        set(ctx.engine.hFigure, 'CloseRequestFcn', @(src, ~) demoClose_(src, ctx));
    end
end

function demoClose_(fig, ctx)
%DEMOCLOSE_ Re-exposed from buildDashboard for run_demo's CloseRequestFcn rebind.
%   Independent lifecycles: closing the dashboard does NOT close the
%   companion. If the companion is alive, only the dashboard is torn
%   down (writer + pipeline keep running so the companion's catalog
%   stays live). If the companion is already closed or absent, a full
%   teardownDemo runs so the writer + pipeline don't leak.
    companionAlive = isfield(ctx, 'companion') && ~isempty(ctx.companion) ...
        && isvalid(ctx.companion) && ctx.companion.IsOpen;
    if companionAlive
        try
            if ~isempty(ctx.engine) && isvalid(ctx.engine) ...
                    && ismethod(ctx.engine, 'stopLive')
                ctx.engine.stopLive();
            end
        catch
            % Best-effort.
        end
    else
        try
            teardownDemo(ctx);
        catch
        end
    end
    try
        delete(fig);
    catch
    end
end

function waitForFirstSample_(tagKey, maxSeconds)
%WAITFORFIRSTSAMPLE_ Poll TagRegistry until tagKey has >=2 X samples.
%   FastSense.render requires xmin<xmax; with 0 or 1 sample set(Axes,'XLim')
%   throws. The writer timer is fixedRate Period=1.0, so the first tick
%   lands ~T+1s. Poll in 100ms increments up to maxSeconds.
    deadline = cputime() + maxSeconds;
    while cputime() < deadline
        try
            tag = TagRegistry.get(tagKey);
            [x, ~] = tag.getXY();
            if numel(x) >= 2
                return;
            end
        catch
        end
        pause(0.1);
    end
end

