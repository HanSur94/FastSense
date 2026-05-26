classdef TestPlantLogSliderOverlay < matlab.unittest.TestCase
%TESTPLANTLOGSLIDEROVERLAY Class-based suite for Phase 1031 Plan 02 slider integration (MATLAB only).
%   Coverage: PLOG-VIZ-01 (slider draws plant-log lines via setPlantLogMarkers),
%             PLOG-VIZ-02 (independent storage from sev1/2/3 event markers),
%             PLOG-VIZ-08 (PlantLogTailTick listener triggers slider refresh
%                          without a full dashboard re-render),
%             PLOG-VIZ-09 (MarkerPlantLog theme token + override).
%
%   Uifigure-heavy tests use offscreen figures (Visible='off') to avoid
%   flicker. All graphics handles, engines, tails, and temp files are
%   tracked on testCase properties and torn down in TestMethodTeardown
%   via named try_delete_* helpers (no inline try/catch in anonymous fns).

    properties
        TempFiles = {}
        Handles   = {}
        Tails     = {}
        Engines   = {}
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            thisDir = fileparts(mfilename('fullpath'));
            repoRoot = fileparts(fileparts(thisDir));
            addpath(repoRoot);
            install();
        end
    end

    methods (TestMethodTeardown)
        function cleanupAll(testCase)
            for k = 1:numel(testCase.Tails)
                try
                    if ~isempty(testCase.Tails{k}) && isvalid(testCase.Tails{k})
                        delete(testCase.Tails{k});
                    end
                catch
                end
            end
            for k = 1:numel(testCase.Engines)
                try
                    if ~isempty(testCase.Engines{k}) && isvalid(testCase.Engines{k})
                        delete(testCase.Engines{k});
                    end
                catch
                end
            end
            for k = 1:numel(testCase.Handles)
                try
                    if ishandle(testCase.Handles{k})
                        delete(testCase.Handles{k});
                    end
                catch
                end
            end
            for k = 1:numel(testCase.TempFiles)
                try
                    p = testCase.TempFiles{k};
                    if exist(p, 'file') == 2
                        delete(p);
                    end
                catch
                end
            end
            testCase.Tails     = {};
            testCase.Engines   = {};
            testCase.Handles   = {};
            testCase.TempFiles = {};
        end
    end

    methods (Test)

        % ----- Theme tests (PLOG-VIZ-09) -----

        function testThemeMarkerPlantLogDarkAndLight(testCase)
            testCase.verifyEqual(DashboardTheme('dark').MarkerPlantLog,  [0 0 0]);
            testCase.verifyEqual(DashboardTheme('light').MarkerPlantLog, [0 0 0]);
        end

        function testThemeMarkerPlantLogOverride(testCase)
            t = DashboardTheme('dark', 'MarkerPlantLog', [0.2 0.2 0.2]);
            testCase.verifyEqual(t.MarkerPlantLog, [0.2 0.2 0.2]);
        end

        % ----- Engine guard + test-seam validation -----

        function testEngineGuardsNoStore(testCase)
            e = DashboardEngine('TestNoStore');
            testCase.Engines{end+1} = e;
            % setPlantLogStoreForTest_([]) internally invokes computePlantLogMarkers,
            % which must early-exit cleanly when TimeRangeSelector_ is empty
            % (no figure has been rendered yet).
            e.setPlantLogStoreForTest_([]);   % no throw expected
        end

        function testEngineTestSeamValidatesStore(testCase)
            e = DashboardEngine('TestValidStore');
            testCase.Engines{end+1} = e;
            testCase.verifyError(@() e.setPlantLogStoreForTest_('bogus'), ...
                'DashboardEngine:invalidPlantLogStore');
        end

        function testEngineTestSeamValidatesTail(testCase)
            e = DashboardEngine('TestValidTail');
            testCase.Engines{end+1} = e;
            testCase.verifyError(@() e.setPlantLogLiveTailForTest_('bogus'), ...
                'DashboardEngine:invalidPlantLogLiveTail');
        end

        % ----- Selector graphics tests (PLOG-VIZ-01/02) -----

        function testSelectorPlantLogIndependentStorage(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            p = uipanel(f);
            s = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
            s.setDataRange(0, 100);
            s.setEventMarkers([10 20 30]);
            s.setPlantLogMarkers([15 25]);
            testCase.verifyNotEmpty(s.hEventMarkers,    'event markers must remain after setPlantLogMarkers');
            testCase.verifyNotEmpty(s.hPlantLogMarkers, 'plant-log markers must be created');
        end

        function testSelectorPlantLogClears(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            p = uipanel(f);
            s = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
            s.setDataRange(0, 100);
            s.setEventMarkers([10 20]);
            s.setPlantLogMarkers([15 25]);
            s.setPlantLogMarkers([]);
            testCase.verifyNotEmpty(s.hEventMarkers, 'event markers must remain after setPlantLogMarkers([])');
            testCase.verifyEmpty(s.hPlantLogMarkers, 'plant-log markers must clear');
        end

        function testSelectorPlantLogDropsNonFinite(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            p = uipanel(f);
            s = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
            s.setDataRange(0, 100);
            s.setPlantLogMarkers([10 NaN Inf -Inf 20]);
            % After NaN/Inf drop, two finite times remain. The NaN-separator
            % polyline strategy creates ONE line handle for any non-empty
            % times vector, so verify the handle is non-empty.
            testCase.verifyNotEmpty(s.hPlantLogMarkers, 'plant-log markers must be created from finite-only subset');
        end

        % ----- Engine + selector integration (PLOG-VIZ-01) -----

        function testEngineSliderIntegrationViaTestSeam(testCase)
            % Build an offscreen TimeRangeSelector + DashboardEngine, inject
            % the selector into the engine via the documented hidden seam,
            % then attach a populated PlantLogStore. After
            % setPlantLogStoreForTest_(store) returns, the engine has
            % already invoked computePlantLogMarkers internally; the
            % selector's hPlantLogMarkers should be populated.
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            p = uipanel(f);
            s = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
            s.setDataRange(0, 100);
            e = DashboardEngine('TestIntegration');
            testCase.Engines{end+1} = e;
            e.setTimeRangeSelectorForTest_(s);

            store = PlantLogStore('synthetic.csv');
            store.addEntries([ ...
                PlantLogEntry('Timestamp', 25, 'Message', 'a', 'Metadata', struct()), ...
                PlantLogEntry('Timestamp', 50, 'Message', 'b', 'Metadata', struct()), ...
                PlantLogEntry('Timestamp', 75, 'Message', 'c', 'Metadata', struct())]);
            e.setPlantLogStoreForTest_(store);

            testCase.verifyNotEmpty(s.hPlantLogMarkers, ...
                'After attaching store, computePlantLogMarkers must populate selector.hPlantLogMarkers');
        end

        % ----- Live-tail integration (PLOG-VIZ-08) -----

        function testLiveTailRefreshTriggersComputePlantLogMarkers(testCase)
            % End-to-end: construct PlantLogStore + PlantLogReader-friendly CSV
            % + PlantLogLiveTail; attach store and tail to engine via the
            % hidden seams; drive one synchronous tick via tail.tick_();
            % verify the store ingested rows AND the slider's plant-log
            % markers are populated. Then detach the tail cleanly to ensure
            % the listener handle is torn down before TestMethodTeardown.
            csvPath = [tempname '.csv'];
            testCase.TempFiles{end+1} = csvPath;
            testCase.writeCsv_(csvPath, { ...
                {'2025-01-15 10:00:00', 'pump on'}, ...
                {'2025-01-15 10:05:00', 'pump off'}, ...
                {'2025-01-15 10:10:00', 'valve open'}});

            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            p = uipanel(f);
            s = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
            tsLow  = datenum('2025-01-15 09:00:00');
            tsHigh = datenum('2025-01-15 11:00:00');
            s.setDataRange(tsLow, tsHigh);

            store = PlantLogStore(csvPath);
            m = struct('TimestampColumn', 'timestamp', ...
                       'MessageColumn',   'message', ...
                       'TimestampFormat', '');
            tail = PlantLogLiveTail(store, csvPath, m);
            testCase.Tails{end+1} = tail;

            e = DashboardEngine('TestLive');
            testCase.Engines{end+1} = e;
            e.setTimeRangeSelectorForTest_(s);
            e.setPlantLogStoreForTest_(store);
            e.setPlantLogLiveTailForTest_(tail);

            tail.tick_();   % synchronous tick — drives reader + addEntries + notify

            testCase.verifyEqual(store.getCount(), 3, ...
                'tick_() must ingest the 3 CSV rows into the store');
            testCase.verifyNotEmpty(s.hPlantLogMarkers, ...
                'PlantLogTailTick listener must trigger computePlantLogMarkers and populate selector handles');

            % Detach the listener cleanly before teardown.
            e.setPlantLogLiveTailForTest_([]);
        end

    end

    methods (Access = private)

        function writeCsv_(testCase, path, rows) %#ok<INUSL>
            fid = fopen(path, 'w');
            fprintf(fid, 'timestamp,message\n');
            for k = 1:numel(rows)
                fprintf(fid, '%s,%s\n', rows{k}{1}, rows{k}{2});
            end
            fclose(fid);
        end

    end
end
