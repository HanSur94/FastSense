function test_demo_industrial_plant()
%TEST_DEMO_INDUSTRIAL_PLANT Octave-compatible wrapper for the Phase 1015
%Plan 01 pipeline integration test. Mirrors the five scenarios in
%tests/suite/TestDemoIndustrialPlantPipeline.m but uses function-based
%assertions so it runs under Octave's subprocess-isolated runner (see
%tests/run_all_tests.m -> run_octave_tests).
%
%   - testRunDemoReturnsCtx
%   - testPipelineIngestsLiveData
%   - testMonitorEventFires
%   - testCompositeHealthResolves
%   - testTeardownLeavesNoDanglingTimers
%
%   Every test ends with teardownDemo + timerfindall('IndustrialPlantDataGen') == 0.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    % Octave lacks the MATLAB `timer` primitive so makeDataGenerator and
    % LiveTagPipeline cannot run here. Skip cleanly so CI stays green.
    if exist('OCTAVE_VERSION', 'builtin')
        if exist('timer', 'file') ~= 2 && exist('timer', 'builtin') ~= 5
            fprintf('    Skipped (Octave lacks MATLAB timer primitive).\n');
            return;
        end
    end

    t_run_demo_returns_ctx();
    t_pipeline_ingests_live_data();
    t_monitor_event_fires();
    t_composite_health_resolves();
    t_teardown_leaves_no_dangling_timers();

    fprintf('    All 5 tests passed.\n');
end

function t_run_demo_returns_ctx()
    sweepDemoTimers_();
    ctx = run_demo();
    try
        assert(isstruct(ctx), 'ctx must be a struct');
        assert(~isempty(ctx.writerTimer), 'writerTimer empty');
        assert(~isempty(ctx.pipeline), 'pipeline empty');
        assert(~isempty(ctx.store), 'store empty');
        assert(strcmp(ctx.plantHealthKey, 'plant.health'), 'plantHealthKey mismatch');
        assert(strcmp(ctx.writerTimer.Running, 'on'), 'writerTimer not running');
        assert(strcmp(ctx.pipeline.Status, 'running'), 'pipeline not running');
        teardownDemo(ctx);
        assert(numel(timerfindall('Name', 'IndustrialPlantDataGen')) == 0, ...
            'dangling IndustrialPlantDataGen timer');
    catch e
        try, teardownDemo(ctx); catch, end
        rethrow(e);
    end
end

function t_pipeline_ingests_live_data()
    sweepDemoTimers_();
    ctx = run_demo();
    try
        pause(4);
        tag = TagRegistry.get('reactor.pressure');
        [x, y] = tag.getXY();
        assert(numel(x) >= 2, 'expected >=2 samples after 4s');
        assert(numel(x) == numel(y), 'X/Y length mismatch');
        teardownDemo(ctx);
        assert(numel(timerfindall('Name', 'IndustrialPlantDataGen')) == 0, ...
            'dangling timer');
    catch e
        try, teardownDemo(ctx); catch, end
        rethrow(e);
    end
end

function t_monitor_event_fires()
    sweepDemoTimers_();
    ctx = run_demo();
    try
        stop(ctx.writerTimer);
        pause(0.05);

        parent = TagRegistry.get('reactor.pressure');
        [xPrior, yPrior] = parent.getXY();
        if isempty(xPrior)
            xPrior = [];
            yPrior = [];
            t0 = (now() - datenum(1970,1,1,0,0,0)) * 86400;
        else
            t0 = xPrior(end);
        end
        tailX = t0 + [1; 2; 3; 4; 5; 6];
        tailY = [12.0; 19.3; 19.5; 19.6; 19.1; 12.0];
        parent.updateData([xPrior(:); tailX], [yPrior(:); tailY]);

        monitor = TagRegistry.get('reactor.pressure.critical');
        [~, ~] = monitor.getXY();
        pause(0.2);

        events = ctx.store.getEventsForTag('reactor.pressure.critical');
        if isempty(events)
            allEv = ctx.store.getEvents();
            if ~isempty(allEv)
                keep = false(1, numel(allEv));
                for k = 1:numel(allEv)
                    nm = safeField_(allEv(k), 'SensorName');
                    if strcmp(nm, 'reactor.pressure') || ...
                       strcmp(nm, 'reactor.pressure.critical')
                        keep(k) = true;
                    end
                end
                events = allEv(keep);
            end
        end
        assert(numel(events) >= 1, ...
            'expected >=1 critical-pressure event after injection');

        teardownDemo(ctx);
        assert(numel(timerfindall('Name', 'IndustrialPlantDataGen')) == 0, ...
            'dangling timer');
    catch e
        try, teardownDemo(ctx); catch, end
        rethrow(e);
    end
end

function t_composite_health_resolves()
    sweepDemoTimers_();
    ctx = run_demo();
    try
        pause(3);
        tNow = (now() - datenum(1970,1,1,0,0,0)) * 86400;
        plant = TagRegistry.get('plant.health');
        v = plant.valueAt(tNow);
        assert(isnumeric(v) && isscalar(v), 'valueAt must return numeric scalar');
        assert(~isnan(v), 'plant.health.valueAt returned NaN');
        teardownDemo(ctx);
        assert(numel(timerfindall('Name', 'IndustrialPlantDataGen')) == 0, ...
            'dangling timer');
    catch e
        try, teardownDemo(ctx); catch, end
        rethrow(e);
    end
end

function t_teardown_leaves_no_dangling_timers()
    sweepDemoTimers_();
    before = numel(timerfindall());
    ctx = run_demo();
    try
        teardownDemo(ctx);
        after = numel(timerfindall());
        assert(after == before, 'timer count drift across run_demo cycle');
        assert(numel(timerfindall('Name', 'IndustrialPlantDataGen')) == 0, ...
            'dangling writer timer');
    catch e
        try, teardownDemo(ctx); catch, end
        rethrow(e);
    end
end

function sweepDemoTimers_()
    try
        ts = timerfindall('Name', 'IndustrialPlantDataGen');
        for i = 1:numel(ts)
            try, stop(ts(i)); catch, end
            try, delete(ts(i)); catch, end
        end
    catch
    end
    try, TagRegistry.clear(); catch, end
end

function v = safeField_(s, name)
    try
        v = s.(name);
    catch
        v = '';
    end
    if isempty(v), v = ''; end
end
