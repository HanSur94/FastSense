function test_demo_industrial_plant_smoke()
%TEST_DEMO_INDUSTRIAL_PLANT_SMOKE Octave-compatible headless full-dashboard smoke.
%
%   Mirrors the five assertions of
%   tests/suite/TestDemoIndustrialPlantHeadless.m but in a function-based
%   style auto-discovered by tests/run_all_tests.m under both MATLAB and
%   Octave. Ships with `defaultfigurevisible='off'` around the whole run so
%   CI never pops a window.
%
%   Assertions:
%     1. run_demo() returns a ctx with populated engine / pipeline / store
%     2. Widgets across all engine.Pages are Realized and >=25 in count
%     3. Anomaly injection triggers a reactor.pressure.critical event
%     4. plant.health CompositeTag resolves to a finite numeric scalar
%     5. teardownDemo leaves timerfindall count unchanged
%
%   Implementation notes:
%     - Widget iteration uses the publicly-readable `engine.Pages{i}.Widgets`
%       cell (allPageWidgets() is PRIVATE in DashboardEngine, line 1034+).
%       The grep-based acceptance check in the plan was adjusted from
%       `allPageWidgets` to `ctx.engine.Pages` to reflect this.
%     - Event lookup uses `getEventsForTag` (plan's `eventsForTag` is a typo).
%     - Time arithmetic uses `now*86400`-style epoch seconds, not posixtime,
%       for Octave 7+ compatibility.
%     - Pure function-based style (no TestCase class) -> runs natively
%       under Octave's function-based discovery.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    % Octave lacks the MATLAB `timer` primitive so makeDataGenerator and
    % LiveTagPipeline cannot run here. Skip cleanly so CI stays green
    % (mirrors the pattern established by test_demo_industrial_plant.m).
    if exist('OCTAVE_VERSION', 'builtin')
        if exist('timer', 'file') ~= 2 && exist('timer', 'builtin') ~= 5
            fprintf('    Skipped (Octave lacks MATLAB timer primitive).\n');
            return;
        end
    end

    fprintf('test_demo_industrial_plant_smoke:\n');

    oldVis = get(0, 'defaultfigurevisible');
    set(0, 'defaultfigurevisible', 'off');

    sweepDemoTimers_();
    beforeTimers = numel(timerfindall());
    ctx = [];

    try
        % --- Assertion 1: headless boot returns populated ctx ---
        ctx = run_demo();
        assert(isstruct(ctx), 'run_demo must return a struct');
        assert(isfield(ctx, 'engine')   && ~isempty(ctx.engine), ...
            'ctx.engine should be populated by plan 02 buildDashboard');
        assert(isfield(ctx, 'pipeline') && ~isempty(ctx.pipeline), ...
            'ctx.pipeline empty');
        assert(isfield(ctx, 'store')    && ~isempty(ctx.store), ...
            'ctx.store empty');
        assert(~isempty(ctx.engine.hFigure) && ishandle(ctx.engine.hFigure), ...
            'engine.hFigure not a valid handle after render');

        % --- Assertion 2: widgets rendered across all pages ---
        % Iterate engine.Pages{i}.Widgets directly (allPageWidgets is private).
        ws = {};
        for p = 1:numel(ctx.engine.Pages)
            pw = ctx.engine.Pages{p}.Widgets;
            for q = 1:numel(pw)
                ws{end+1} = pw{q}; %#ok<AGROW>
            end
        end
        nW = numel(ws);
        assert(nW >= 25, sprintf('expected >=25 widgets, got %d', nW));
        for i = 1:nW
            assert(ws{i}.Realized == true, ...
                sprintf('widget %d (%s) not Realized', i, class(ws{i})));
        end

        % --- Assertion 3: anomaly injection fires MonitorTag event ---
        % Stop writer so tail isn't overwritten; inject rising edge > 18.
        stop(ctx.writerTimer);
        pause(0.05);
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
        monitor = TagRegistry.get('reactor.pressure.critical');
        [~, ~] = monitor.getXY();
        pause(4);

        evs = ctx.store.getEventsForTag('reactor.pressure.critical');
        if isempty(evs)
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
                evs = allEv(keep);
            end
        end
        assert(numel(evs) >= 1, ...
            'expected >=1 reactor.pressure.critical event after injection');

        % --- Assertion 4: composite plant.health resolves to finite scalar ---
        tNow = (now() - datenum(1970,1,1,0,0,0)) * 86400;
        h = TagRegistry.get(ctx.plantHealthKey);
        v = h.valueAt(tNow);
        assert(isnumeric(v) && isscalar(v), ...
            'plant.health.valueAt must return numeric scalar');
        assert(~isnan(v), 'plant.health unresolved (NaN)');

        fprintf('    Boot + widgets + event + composite: all 4 passed.\n');
    catch ERR
        try, teardownDemo(ctx); catch, end
        set(0, 'defaultfigurevisible', oldVis);
        rethrow(ERR);
    end

    % --- Assertion 5: teardown leaves no dangling timers ---
    teardownDemo(ctx);
    set(0, 'defaultfigurevisible', oldVis);
    afterTimers = numel(timerfindall());
    assert(afterTimers == beforeTimers, ...
        sprintf('dangling timers: before=%d after=%d', ...
            beforeTimers, afterTimers));
    assert(numel(timerfindall('Name', 'IndustrialPlantDataGen')) == 0, ...
        'dangling IndustrialPlantDataGen timer');

    fprintf('    Teardown clean.\n');
    fprintf('    All 5 assertions passed.\n');
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
    try
        ts = timerfindall('Tag', 'DashboardEngine');
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
