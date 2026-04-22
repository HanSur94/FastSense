function ctx = run_demo()
%RUN_DEMO Industrial plant live demo entry point (plan-01 scaffold).
%   ctx = run_demo() bootstraps the synthetic data generator, the live
%   TagRegistry wiring, and the LiveTagPipeline -- the non-UI plumbing
%   for the Phase 1015 demo. Plan 02 extends this entry point to build
%   the multi-page dashboard; for now the returned ctx carries all the
%   handles a caller (or a test) needs to observe the pipeline.
%
%   Returns:
%     ctx - struct with fields:
%       writerTimer    - IndustrialPlantDataGen MATLAB timer (running)
%       pipeline       - LiveTagPipeline (running)
%       engine         - [] (plan 02 populates this with a DashboardEngine)
%       store          - EventStore wired into every MonitorTag
%       plantHealthKey - 'plant.health' (top-level rollup)
%       rawDir         - absolute path to demo/industrial_plant/data/raw
%       tagsDir        - absolute path to demo/industrial_plant/data/tags
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
%   See also: plantConfig, registerPlantTags, makeDataGenerator,
%             startLivePipeline, teardownDemo, TagRegistry, LiveTagPipeline.

    here    = fileparts(mfilename('fullpath'));
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

    % Build the writer timer (unstarted), then the pipeline, then start both.
    writerTimer = makeDataGenerator(rawDir);
    start(writerTimer);
    pipeline = startLivePipeline(rawDir, tagsDir);

    ctx = struct( ...
        'writerTimer',    writerTimer, ...
        'pipeline',       pipeline, ...
        'engine',         [], ...
        'store',          store, ...
        'plantHealthKey', plantHealthKey, ...
        'rawDir',         rawDir, ...
        'tagsDir',        tagsDir);

    % Plan 02 hook: build the full dashboard on top of the plumbing.
    % buildDashboard creates the DashboardEngine, renders the figure,
    % pre-detaches the main reactor pressure plot, starts the live timer,
    % and wires a CloseRequestFcn that calls teardownDemo(ctx).
    ctx.engine = buildDashboard(ctx);
end
