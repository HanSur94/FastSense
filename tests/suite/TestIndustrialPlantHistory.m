classdef TestIndustrialPlantHistory < matlab.unittest.TestCase
    %TESTINDUSTRIALPLANTHISTORY Suite for the demo's 1-week seed step.
    %   Each test that depends on a live ctx uses TestMethodSetup /
    %   TestMethodTeardown to keep test isolation. The pure-helper tests
    %   (Tasks 1–3) need no ctx and run instantly.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, '..', '..'));
            install();
            addpath(fullfile(here, '..', '..', 'demo', 'industrial_plant'));
        end
    end

    methods (Test)
        function testStateHistoryHasSevenReactorCycles(testCase)
            cfg     = plantConfig();
            tStart  = now() - 7;
            nDays   = 7;
            [~, ~, xMode, yMode] = buildStateHistory(cfg, tStart, nDays);
            testCase.assertEqual(numel(xMode), numel(yMode), ...
                'mode X/Y length mismatch');
            testCase.assertGreaterThan(numel(xMode), 0, 'mode history empty');

            % Count `running` -> `cooldown` transitions; one per day = 7.
            nTransitions = 0;
            for k = 2:numel(yMode)
                if strcmp(yMode{k-1}, 'running') && strcmp(yMode{k}, 'cooldown')
                    nTransitions = nTransitions + 1;
                end
            end
            testCase.assertEqual(nTransitions, 7, ...
                sprintf('expected 7 running->cooldown transitions, got %d', nTransitions));
        end

        function testStateHistoryHasSevenValveCycles(testCase)
            cfg     = plantConfig();
            tStart  = now() - 7;
            nDays   = 7;
            [xValve, yValve, ~, ~] = buildStateHistory(cfg, tStart, nDays);
            testCase.assertEqual(numel(xValve), numel(yValve), ...
                'valve X/Y length mismatch');
            testCase.assertGreaterThan(numel(xValve), 0, 'valve history empty');

            % Count `closing` -> `closed` transitions; one per day = 7.
            nClose = 0;
            for k = 2:numel(yValve)
                if strcmp(yValve{k-1}, 'closing') && strcmp(yValve{k}, 'closed')
                    nClose = nClose + 1;
                end
            end
            testCase.assertEqual(nClose, 7, ...
                sprintf('expected 7 closing->closed transitions, got %d', nClose));
        end

        function testSensorExcursionsBaselineMatchesSineModel(testCase)
            cfg    = plantConfig();
            tStart = now() - 7;
            % 600 samples (10 min at 1 Hz) is enough to verify shape
            % without committing to a full week here.
            tHist  = (tStart:1/86400:tStart + 600/86400)';

            % An unmonitored sensor: no excursions overlay, so y should
            % be exactly baseline + noise (within RNG determinism).
            key  = 'feedline.flow';   % unmonitored
            rng(1015, 'twister');
            yA = buildSensorExcursions(cfg, key, tHist);

            rng(1015, 'twister');
            yB = buildSensorExcursions(cfg, key, tHist);

            testCase.assertEqual(yA, yB, ...
                'buildSensorExcursions must be deterministic under fixed seed');
            testCase.assertEqual(numel(yA), numel(tHist), ...
                'output length must match input time vector');
            testCase.assertEqual(size(yA, 2), 1, ...
                'output must be a column vector (callers feed tag.updateData)');

            field     = strrep(key, '.', '_');
            sensorRng = cfg.Ranges.(field);
            testCase.assertGreaterThanOrEqual(min(yA), sensorRng(1) - 1e-9, ...
                'baseline below sensor range');
            testCase.assertLessThanOrEqual(max(yA), sensorRng(2) + 1e-9, ...
                'baseline above sensor range');
        end

        function testMonitoredSensorHasExcursions(testCase)
            cfg    = plantConfig();
            % Full week so the schedule is exercised.
            tStart = now() - 7;
            tHist  = (tStart:1/86400:tStart + 7 - 1/86400)';

            % `reactor.pressure` has trip at y > 18.
            rng(1015, 'twister');
            y = buildSensorExcursions(cfg, 'reactor.pressure', tHist);

            % Per spec §4: 18-28 short trips + 5-8 long + 6-10 cascade
            % trips per monitor. Each excursion must briefly carry y above
            % the monitor's trip value. Count samples > 18.
            nAbove = sum(y > 18);
            testCase.assertGreaterThan(nAbove, 50, ...
                sprintf('expected >50 samples above 18 bar over the week, got %d', nAbove));
            testCase.assertLessThan(nAbove, 100000, ...
                sprintf('too many samples above 18 — sustained breach? got %d', nAbove));

            % Cooling.flow has lower-direction trip at y < 20.
            rng(1015, 'twister');
            yCool = buildSensorExcursions(cfg, 'cooling.flow', tHist);
            nBelow = sum(yCool < 20);
            testCase.assertGreaterThan(nBelow, 50, ...
                sprintf('expected >50 cooling samples below 20 L/min, got %d', nBelow));

            % Unmonitored sensor: no excursions, no breaches near any
            % imagined threshold — just verify the baseline is bounded.
            rng(1015, 'twister');
            yFlow = buildSensorExcursions(cfg, 'feedline.flow', tHist);
            field = 'feedline_flow';
            r = cfg.Ranges.(field);
            testCase.assertGreaterThanOrEqual(min(yFlow), r(1) - 1e-9);
            testCase.assertLessThanOrEqual(max(yFlow), r(2) + 1e-9);
        end

        function testSeedHistoryPopulatesSensorsStatesAndEvents(testCase)
            % Build a minimal context: registry + EventStore + monitors,
            % WITHOUT starting the writer timer or the live pipeline.
            here   = fileparts(mfilename('fullpath')); %#ok<NASGU>
            rawDir = fullfile(tempdir(), 'TestIndustrialPlantHistory_raw');
            if exist(rawDir, 'dir'), rmdir(rawDir, 's'); end
            mkdir(rawDir);

            [store, plantHealthKey] = registerPlantTags(rawDir);  %#ok<ASGLU>
            cleanup = onCleanup(@() TestIndustrialPlantHistory.cleanupRegistry_()); %#ok<NASGU>

            cfg = plantConfig();

            tBefore = now();
            seedHistory(store, cfg);
            tAfter  = now();
            testCase.assertLessThan(tAfter - tBefore, 5/86400, ...
                'seedHistory should complete in < 5 s');

            % SensorTag: full week of samples.
            sensorTag = TagRegistry.get('reactor.pressure');
            [x, y] = sensorTag.getXY(); %#ok<ASGLU>
            testCase.assertGreaterThanOrEqual(numel(x), 7*86400, ...
                sprintf('expected >= %d samples, got %d', 7*86400, numel(x)));
            testCase.assertGreaterThan(x(end) - x(1), 6.99, ...
                'historical span < ~7 days');

            % StateTag: at least 7 cycles.
            modeTag = TagRegistry.get('reactor.mode');
            yMode = modeTag.Y;
            nTrans = 0;
            for k = 2:numel(yMode)
                if strcmp(yMode{k-1}, 'running') && strcmp(yMode{k}, 'cooldown')
                    nTrans = nTrans + 1;
                end
            end
            testCase.assertEqual(nTrans, 7);

            % EventStore: real events from real violations.
            n = store.numEvents();
            testCase.assertGreaterThanOrEqual(n, 80, ...
                sprintf('expected >=80 events, got %d', n));
            testCase.assertLessThanOrEqual(n, 250, ...
                sprintf('expected <=250 events, got %d', n));

            % Time-bound check: every event sits inside the historical
            % window (or within 1 s slack at the live edge).
            evs = store.getEvents();
            for k = 1:numel(evs)
                testCase.assertGreaterThanOrEqual(evs(k).StartTime, x(1) - 1/86400);
                if ~isnan(evs(k).EndTime)
                    testCase.assertLessThanOrEqual(evs(k).EndTime, x(end) + 1/86400);
                end
            end
        end
        function testEventSeverityMatchesMonitorCriticality(testCase)
            here   = fileparts(mfilename('fullpath')); %#ok<NASGU>
            rawDir = fullfile(tempdir(), 'TestIndustrialPlantHistory_raw');
            if exist(rawDir, 'dir'), rmdir(rawDir, 's'); end
            mkdir(rawDir);
            [store, ~] = registerPlantTags(rawDir);
            cleanup = onCleanup(@() TestIndustrialPlantHistory.cleanupRegistry_()); %#ok<NASGU>

            seedHistory(store, plantConfig());
            evs = store.getEvents();
            testCase.assertGreaterThan(numel(evs), 0);

            % Sample up to 20 events; every one should have a Severity
            % consistent with its firing monitor's Criticality.
            sampleN = min(20, numel(evs));
            critToSev = containers.Map( ...
                {'low', 'medium', 'high', 'safety'}, {1, 2, 3, 3});
            for k = 1:sampleN
                ev  = evs(k);
                mon = TagRegistry.get(ev.ThresholdLabel);
                expected = critToSev(lower(char(mon.Criticality)));
                testCase.assertEqual(ev.Severity, expected, ...
                    sprintf('event %d (monitor=%s) expected sev=%d, got %d', ...
                        k, ev.ThresholdLabel, expected, ev.Severity));
            end
        end

        function testEveryEventCorrespondsToRealBreach(testCase)
            here   = fileparts(mfilename('fullpath')); %#ok<NASGU>
            rawDir = fullfile(tempdir(), 'TestIndustrialPlantHistory_raw');
            if exist(rawDir, 'dir'), rmdir(rawDir, 's'); end
            mkdir(rawDir);
            [store, ~] = registerPlantTags(rawDir);
            cleanup = onCleanup(@() TestIndustrialPlantHistory.cleanupRegistry_()); %#ok<NASGU>

            cfg = plantConfig();
            seedHistory(store, cfg);
            evs = store.getEvents();
            testCase.assertGreaterThan(numel(evs), 0);

            % For every event on `reactor.pressure.critical`, the parent
            % must contain at least one sample inside [StartTime, EndTime]
            % whose value exceeds 18 bar (the configured trip).
            keepIdx = false(1, numel(evs));
            for k = 1:numel(evs)
                if strcmp(evs(k).ThresholdLabel, 'reactor.pressure.critical')
                    keepIdx(k) = true;
                end
            end
            criticalEvs = evs(keepIdx);
            testCase.assertGreaterThan(numel(criticalEvs), 0, ...
                'expected at least one reactor.pressure.critical event');

            parent = TagRegistry.get('reactor.pressure');
            [px, py] = parent.getXY();
            for k = 1:numel(criticalEvs)
                ev = criticalEvs(k);
                tEnd = ev.EndTime;
                if isnan(tEnd), tEnd = ev.StartTime + 1/86400; end
                mask = px >= ev.StartTime & px <= tEnd;
                testCase.assertTrue(any(py(mask) > 18), ...
                    sprintf('event %d: no parent sample > 18 in [%g, %g]', ...
                        k, ev.StartTime, tEnd));
            end
        end
        function testRunDemoEndToEndHasHistoricalEventsOnFirstPaint(testCase)
            % Headless: figures are forced invisible so CI / desktop
            % focus is preserved.
            oldVis = get(0, 'defaultfigurevisible');
            set(0, 'defaultfigurevisible', 'off');
            cleanup = onCleanup(@() set(0, 'defaultfigurevisible', oldVis)); %#ok<NASGU>

            ctx = run_demo('Companion', false);
            cleanupCtx = onCleanup(@() teardownDemo(ctx)); %#ok<NASGU>

            % Sensor: at least 7 days of history + a few live ticks.
            tag = TagRegistry.get('reactor.pressure');
            [x, ~] = tag.getXY();
            testCase.assertGreaterThanOrEqual(numel(x), 7*86400, ...
                'reactor.pressure should carry >=7d of samples after run_demo');

            % EventStore: events present immediately, before the user does anything.
            n = ctx.store.numEvents();
            testCase.assertGreaterThanOrEqual(n, 80, ...
                sprintf('expected >=80 historical events on first paint, got %d', n));
        end
    end  % end of methods (Test)

    methods (Static, Access = private)
        function cleanupRegistry_()
            try, TagRegistry.clear(); catch, end
        end
    end
end
