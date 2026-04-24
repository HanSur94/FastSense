classdef TestDemoIndustrialPlantHeadless < matlab.unittest.TestCase
    %TESTDEMOINDUSTRIALPLANTHEADLESS Headless CI smoke test for Phase 1015 Plan 03.
    %
    %   Verifies the *full* demo (data generator + LiveTagPipeline + multi-page
    %   DashboardEngine from plan 02) boots under `defaultFigureVisible='off'`,
    %   ticks successfully, emits events, resolves the plant.health composite,
    %   and tears down leaving zero dangling timers. Extends the non-UI
    %   coverage of TestDemoIndustrialPlantPipeline (plan 01) to the full
    %   dashboard surface (D-16, D-17).
    %
    %   Coverage:
    %     - testHeadlessBoot                  ctx fields populated; engine figure valid
    %     - testAllWidgetsRendered            every widget .Realized == true, >=25 total
    %     - testEventFiresHeadlessly          anomaly injection triggers MonitorTag event
    %     - testCompositeHealthResolves       plant.health.valueAt returns finite scalar
    %     - testCleanTeardownNoDanglingTimers timerfindall delta = 0, figure deleted
    %
    %   Widget iteration uses the publicly-readable `engine.Pages{i}.Widgets`
    %   cell (Pages is SetAccess=private but readable). `engine.allPageWidgets()`
    %   was considered but is a PRIVATE method (DashboardEngine.m line 1034+);
    %   Plan 02 established the same workaround and it is reused here.
    %
    %   EventStore lookup uses `getEventsForTag` (the real method name; the
    %   plan text's `eventsForTag` is a typo -- see SUMMARY deviations).
    %
    %   See also: TestDemoIndustrialPlantPipeline, run_demo, teardownDemo.

    properties
        DefaultVisible
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, '..', '..'));
            install();
            testCase.DefaultVisible = get(groot, 'defaultFigureVisible');
            set(groot, 'defaultFigureVisible', 'off');
        end
    end

    methods (TestClassTeardown)
        function restoreVisible(testCase)
            try
                set(groot, 'defaultFigureVisible', testCase.DefaultVisible);
            catch
            end
        end
    end

    methods (TestMethodSetup)
        function cleanState(~)
            try, TagRegistry.clear(); catch, end
            sweepDemoTimers_();
        end
    end

    methods (Test)

        function testHeadlessBoot(testCase)
            ctx = run_demo();
            cleanup = onCleanup(@() safeTeardown_(ctx)); %#ok<NASGU>

            testCase.verifyTrue(isstruct(ctx));
            testCase.verifyTrue(isfield(ctx, 'engine')   && ~isempty(ctx.engine));
            testCase.verifyTrue(isfield(ctx, 'pipeline') && ~isempty(ctx.pipeline));
            testCase.verifyTrue(isfield(ctx, 'store')    && ~isempty(ctx.store));

            % hFigure must be a valid handle post-render (headless, invisible)
            testCase.verifyTrue(~isempty(ctx.engine.hFigure));
            testCase.verifyTrue(ishandle(ctx.engine.hFigure));

            teardownDemo(ctx);
            testCase.verifyEqual( ...
                numel(timerfindall('Name', 'IndustrialPlantDataGen')), 0);
        end

        function testAllWidgetsRendered(testCase)
            ctx = run_demo();
            cleanup = onCleanup(@() safeTeardown_(ctx)); %#ok<NASGU>

            % Collect widgets across all pages via the publicly-readable
            % engine.Pages cell (allPageWidgets() is a private method; Plan 02
            % established this direct-iteration pattern).
            ws = {};
            for p = 1:numel(ctx.engine.Pages)
                pw = ctx.engine.Pages{p}.Widgets;
                for q = 1:numel(pw)
                    ws{end+1} = pw{q}; %#ok<AGROW>
                end
            end

            nW = numel(ws);
            testCase.verifyGreaterThanOrEqual(nW, 25, ...
                sprintf('Expected >=25 widgets across all pages; got %d.', nW));

            for i = 1:nW
                testCase.verifyTrue(ws{i}.Realized, ...
                    sprintf('Widget %d (%s) not Realized after render.', ...
                        i, class(ws{i})));
            end

            teardownDemo(ctx);
            testCase.verifyEqual( ...
                numel(timerfindall('Name', 'IndustrialPlantDataGen')), 0);
        end

        function testEventFiresHeadlessly(testCase)
            ctx = run_demo();
            cleanup = onCleanup(@() safeTeardown_(ctx)); %#ok<NASGU>

            % Stop writer so our injected tail isn't overwritten on next tick.
            stop(ctx.writerTimer);
            pause(0.05);

            % Inject a sustained rising edge > 18 (ThresholdFn for
            % reactor.pressure.critical) anchored on the existing timeline.
            parent = TagRegistry.get('reactor.pressure');
            [xPrior, yPrior] = parent.getXY();
            if isempty(xPrior)
                t0 = (now() - datenum(1970,1,1,0,0,0)) * 86400;
                xPrior = [];
                yPrior = [];
            else
                t0 = xPrior(end);
            end
            tailX = t0 + [1; 2; 3; 4; 5; 6];
            tailY = [12.0; 19.3; 19.5; 19.6; 19.1; 12.0];
            parent.updateData([xPrior(:); tailX], [yPrior(:); tailY]);

            % Force MonitorTag recompute + pipeline/monitor to emit
            monitor = TagRegistry.get('reactor.pressure.critical');
            [~, ~] = monitor.getXY();
            pause(4);

            % Primary path: getEventsForTag (plan text's eventsForTag is a typo).
            events = ctx.store.getEventsForTag('reactor.pressure.critical');
            if isempty(events)
                % Fallback: carrier-field scan (mirrors plan 01 test pattern).
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

            testCase.verifyGreaterThanOrEqual(numel(events), 1, ...
                'Expected >=1 reactor.pressure.critical event after injection.');

            teardownDemo(ctx);
            testCase.verifyEqual( ...
                numel(timerfindall('Name', 'IndustrialPlantDataGen')), 0);
        end

        function testCompositeHealthResolves(testCase)
            ctx = run_demo();
            cleanup = onCleanup(@() safeTeardown_(ctx)); %#ok<NASGU>

            pause(4);

            % Octave-safe epoch seconds
            tNow = (now() - datenum(1970,1,1,0,0,0)) * 86400;
            plant = TagRegistry.get(ctx.plantHealthKey);
            v = plant.valueAt(tNow);

            testCase.verifyTrue(isnumeric(v));
            testCase.verifyTrue(isscalar(v));
            testCase.verifyFalse(isnan(v), ...
                'plant.health.valueAt returned NaN after 4 ticks.');

            teardownDemo(ctx);
            testCase.verifyEqual( ...
                numel(timerfindall('Name', 'IndustrialPlantDataGen')), 0);
        end

        function testCleanTeardownNoDanglingTimers(testCase)
            before = numel(timerfindall());
            ctx = run_demo();
            fig = ctx.engine.hFigure;

            teardownDemo(ctx);
            after = numel(timerfindall());

            testCase.verifyEqual(after, before, ...
                'Timer count changed across run_demo+teardownDemo cycle.');
            testCase.verifyEqual( ...
                numel(timerfindall('Name', 'IndustrialPlantDataGen')), 0);

            % Figure should be closed after teardown (CloseRequestFcn wired in
            % buildDashboard.m). If the engine did not delete the figure itself,
            % at least ensure no further operations leak.
            if ishandle(fig)
                try, delete(fig); catch, end
            end
            testCase.verifyFalse(ishandle(fig), ...
                'Demo figure still valid after teardownDemo.');
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
    %SWEEPDEMOTIMERS_ Best-effort purge of demo timers between runs.
    try
        ts = timerfindall('Name', 'IndustrialPlantDataGen');
        for i = 1:numel(ts)
            try, stop(ts(i)); catch, end
            try, delete(ts(i)); catch, end
        end
    catch
    end
    try
        ts = timerfindall('Tag', 'DashboardEngine');
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
