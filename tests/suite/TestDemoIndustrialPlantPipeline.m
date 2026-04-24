classdef TestDemoIndustrialPlantPipeline < matlab.unittest.TestCase
    %TESTDEMOINDUSTRIALPLANTPIPELINE Headless test for Phase 1015 Plan 01.
    %
    %   Verifies the non-UI half of the demo: data generator + LiveTagPipeline
    %   + TagRegistry population + MonitorTag event emission + clean teardown.
    %   Opens no figures. Dual-style (MATLAB class tests + Octave compatible
    %   via matlab.unittest.TestCase availability) -- Octave users invoke via
    %   the flat `test_demo_industrial_plant` wrapper.
    %
    %   Coverage:
    %     - testRunDemoReturnsCtx            ctx struct populated; timers running
    %     - testPipelineIngestsLiveData      in-memory Tag X/Y grows over ticks
    %     - testMonitorEventFires            MonitorTag rising edge -> EventStore
    %     - testCompositeHealthResolves      plant.health.valueAt returns finite
    %     - testTeardownLeavesNoDanglingTimers   timerfindall delta = 0

    methods (TestClassSetup)
        function addPaths(~)
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function cleanState(~)
            try
                TagRegistry.clear();
            catch
            end
            sweepDemoTimers_();
        end
    end

    methods (Test)

        function testRunDemoReturnsCtx(testCase)
            ctx = run_demo();
            cleanup = onCleanup(@() safeTeardown_(ctx)); %#ok<NASGU>

            testCase.verifyTrue(isstruct(ctx));
            testCase.verifyTrue(isfield(ctx, 'writerTimer') && ~isempty(ctx.writerTimer));
            testCase.verifyTrue(isfield(ctx, 'pipeline')    && ~isempty(ctx.pipeline));
            testCase.verifyTrue(isfield(ctx, 'store')       && ~isempty(ctx.store));
            testCase.verifyTrue(isfield(ctx, 'plantHealthKey'));
            testCase.verifyEqual(ctx.plantHealthKey, 'plant.health');

            testCase.verifyEqual(ctx.writerTimer.Running, 'on');
            testCase.verifyEqual(ctx.pipeline.Status, 'running');

            teardownDemo(ctx);
            testCase.verifyEqual( ...
                numel(timerfindall('Name', 'IndustrialPlantDataGen')), 0);
        end

        function testPipelineIngestsLiveData(testCase)
            ctx = run_demo();
            cleanup = onCleanup(@() safeTeardown_(ctx)); %#ok<NASGU>

            % Wait for a handful of timer ticks to produce real samples.
            pause(4);

            tag = TagRegistry.get('reactor.pressure');
            [x, y] = tag.getXY();
            testCase.verifyGreaterThanOrEqual(numel(x), 2);
            testCase.verifyEqual(numel(x), numel(y));

            teardownDemo(ctx);
            testCase.verifyEqual( ...
                numel(timerfindall('Name', 'IndustrialPlantDataGen')), 0);
        end

        function testMonitorEventFires(testCase)
            ctx = run_demo();
            cleanup = onCleanup(@() safeTeardown_(ctx)); %#ok<NASGU>

            % Stop the writer timer first so it cannot overwrite our
            % injected data on its next tick (the generator pushes its
            % accumulated X/Y to the tag every second via updateData).
            stop(ctx.writerTimer);
            pause(0.05);

            % Inject rows that exceed reactor.pressure.critical's
            % ConditionFn (>18) for MinDuration=1 second to force a rising
            % edge through MonitorTag's debounced event emission, without
            % waiting for the deterministic t>=15 anomaly schedule.
            parent = TagRegistry.get('reactor.pressure');
            [xPrior, yPrior] = parent.getXY();
            % Anchor the injected tail on the parent's existing timeline so
            % MonitorTag's ZOH cache sees a monotonic X. Use big gap to
            % ensure MinDuration=1 threshold is easily exceeded.
            if isempty(xPrior)
                t0 = (now() - datenum(1970,1,1,0,0,0)) * 86400;
                xPrior = [];
                yPrior = [];
            else
                t0 = xPrior(end);
            end
            tailX = t0 + [1; 2; 3; 4; 5; 6];
            tailY = [12.0; 19.3; 19.5; 19.6; 19.1; 12.0];  % rising edge then fall
            parent.updateData([xPrior(:); tailX], [yPrior(:); tailY]);

            % Force the MonitorTag to recompute + emit events.
            monitor = TagRegistry.get('reactor.pressure.critical');
            [~, ~] = monitor.getXY();

            pause(0.2);

            events = ctx.store.getEventsForTag('reactor.pressure.critical');
            if isempty(events)
                % Some MonitorTag implementations emit via SensorName carrier;
                % fall back to reading all events and filtering by parent key.
                allEv = ctx.store.getEvents();
                if ~isempty(allEv)
                    names = cell(1, numel(allEv));
                    for k = 1:numel(allEv)
                        names{k} = safeField_(allEv(k), 'SensorName');
                    end
                    matches = strcmp(names, 'reactor.pressure') | ...
                              strcmp(names, 'reactor.pressure.critical');
                    events = allEv(matches);
                end
            end

            testCase.verifyGreaterThanOrEqual(numel(events), 1, ...
                'Expected at least one critical-pressure event after injection.');

            teardownDemo(ctx);
            testCase.verifyEqual( ...
                numel(timerfindall('Name', 'IndustrialPlantDataGen')), 0);
        end

        function testCompositeHealthResolves(testCase)
            ctx = run_demo();
            cleanup = onCleanup(@() safeTeardown_(ctx)); %#ok<NASGU>

            pause(3);

            tNow = (now() - datenum(1970,1,1,0,0,0)) * 86400;
            plant = TagRegistry.get('plant.health');
            v = plant.valueAt(tNow);

            testCase.verifyTrue(isnumeric(v));
            testCase.verifyTrue(isscalar(v));
            testCase.verifyFalse(isnan(v), ...
                'plant.health.valueAt returned NaN after 3 pipeline ticks');

            teardownDemo(ctx);
            testCase.verifyEqual( ...
                numel(timerfindall('Name', 'IndustrialPlantDataGen')), 0);
        end

        function testTeardownLeavesNoDanglingTimers(testCase)
            before = numel(timerfindall());
            ctx = run_demo();
            % pipeline adds its own timer -- that's fine; we only care that
            % teardown restores the count to before (pipeline timer is deleted
            % by pipeline.stop(), writer timer is deleted by teardownDemo).
            teardownDemo(ctx);
            after = numel(timerfindall());

            testCase.verifyEqual(after, before, ...
                'Timer count changed across run_demo+teardownDemo cycle.');
            testCase.verifyEqual( ...
                numel(timerfindall('Name', 'IndustrialPlantDataGen')), 0);
        end

    end

end

function safeTeardown_(ctx)
    %SAFETEARDOWN_ Teardown wrapper tolerating double-call.
    try
        teardownDemo(ctx);
    catch
    end
    sweepDemoTimers_();
end

function sweepDemoTimers_()
    %SWEEPDEMOTIMERS_ Best-effort purge of demo writer timers between runs.
    try
        ts = timerfindall('Name', 'IndustrialPlantDataGen');
        for i = 1:numel(ts)
            try, stop(ts(i)); catch, end
            try, delete(ts(i)); catch, end
        end
    catch
    end
end

function v = safeField_(s, name)
    %SAFEFIELD_ Read struct/object field with empty fallback.
    try
        v = s.(name);
    catch
        v = '';
    end
    if isempty(v), v = ''; end
end
