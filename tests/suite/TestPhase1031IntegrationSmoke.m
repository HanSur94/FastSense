classdef TestPhase1031IntegrationSmoke < matlab.unittest.TestCase
%TESTPHASE1031INTEGRATIONSMOKE Class-based MATLAB-only end-to-end Phase 1031 smoke.
%   Mirrors tests/test_phase_1031_integration_smoke.m at the class-based level
%   plus one additional method that exercises the REAL timer path (Interval
%   = 0.2s + pause(0.6) so the timer fires in real time and the listener
%   round-trip is exercised end-to-end).
%
%   install() contract: deliberately omits any manual `addpath` of
%   libs/PlantLog or libs/Dashboard.
%
%   Coverage (see test_phase_1031_integration_smoke for the requirement
%   cross-reference table):
%     - testPathPickup                              (cross-runtime baseline)
%     - testFullLifecycle                           (PLOG-LT-01/02)
%     - testEngineSliderIntegration                 (PLOG-VIZ-01/02/06)
%     - testLiveTailRefreshesSlider                 (PLOG-VIZ-08)
%     - testHoverFindsEntry                         (PLOG-VIZ-06)
%     - testFullPipelineCleanup                     (PLOG-LT-04 + WBM)
%     - testRealTimerTickRoundTrip                  (extra: real timer fires)

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

        function testPathPickup(testCase)
            testCase.verifyNotEmpty(which('PlantLogLiveTail'));
            testCase.verifyNotEmpty(which('PlantLogSliderHover'));
            testCase.verifyNotEmpty(which('PlantLogStore'));
            testCase.verifyNotEmpty(which('PlantLogReader'));
            testCase.verifyNotEmpty(which('DashboardEngine'));
            testCase.verifyNotEmpty(which('TimeRangeSelector'));
        end

        function testFullLifecycle(testCase)
            csvPath = [tempname '.csv'];
            testCase.TempFiles{end+1} = csvPath;
            writeInitialCsv_(csvPath);
            store = PlantLogStore(csvPath);
            m = struct( ...
                'TimestampColumn', 'timestamp', ...
                'MessageColumn',   'message', ...
                'TimestampFormat', '');
            entries = PlantLogReader.openInteractive(csvPath, ...
                'Headless', true, 'Mapping', m);
            store.addEntries(entries);
            testCase.verifyEqual(store.getCount(), 3);
            tail = PlantLogLiveTail(store, csvPath, m);
            testCase.Tails{end+1} = tail;
            tail.tick_();
            testCase.verifyEqual(store.getCount(), 3, 'tick_ on unchanged file must not duplicate');
            appendRowsToCsv_(csvPath, { ...
                {'2025-01-15 10:15:00', 'pump on again'}, ...
                {'2025-01-15 10:20:00', 'pump off again'}});
            tail.tick_();
            testCase.verifyEqual(store.getCount(), 5, 'tick_ after append must yield 5 entries');
        end

        function testEngineSliderIntegration(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            p = uipanel(f);
            sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
            tsLow  = datenum('2025-01-15 09:00:00'); %#ok<DATNM>
            tsHigh = datenum('2025-01-15 11:00:00'); %#ok<DATNM>
            sel.setDataRange(tsLow, tsHigh);

            e = DashboardEngine('TestSliderInt');
            testCase.Engines{end+1} = e;
            e.setTimeRangeSelectorForTest_(sel);

            store = PlantLogStore('synthetic.csv');
            ts1 = datenum('2025-01-15 10:00:00'); %#ok<DATNM>
            ts2 = datenum('2025-01-15 10:05:00'); %#ok<DATNM>
            store.addEntries([ ...
                PlantLogEntry('Timestamp', ts1, 'Message', 'a', 'Metadata', struct()), ...
                PlantLogEntry('Timestamp', ts2, 'Message', 'b', 'Metadata', struct())]);
            e.setPlantLogStoreForTest_(store);

            testCase.verifyNotEmpty(sel.hPlantLogMarkers, ...
                'after store attach, selector.hPlantLogMarkers must be populated');
            testCase.verifyNotEmpty(e.PlantLogSliderHover_, ...
                'after store attach with rendered selector, hover must be lazily constructed');
        end

        function testLiveTailRefreshesSlider(testCase)
            csvPath = [tempname '.csv'];
            testCase.TempFiles{end+1} = csvPath;
            writeInitialCsv_(csvPath);

            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            p = uipanel(f);
            sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
            tsLow  = datenum('2025-01-15 09:00:00'); %#ok<DATNM>
            tsHigh = datenum('2025-01-15 11:00:00'); %#ok<DATNM>
            sel.setDataRange(tsLow, tsHigh);

            store = PlantLogStore(csvPath);
            m = struct('TimestampColumn', 'timestamp', ...
                'MessageColumn', 'message', 'TimestampFormat', '');
            tail = PlantLogLiveTail(store, csvPath, m);
            testCase.Tails{end+1} = tail;

            e = DashboardEngine('TestLiveRefresh');
            testCase.Engines{end+1} = e;
            e.setTimeRangeSelectorForTest_(sel);
            e.setPlantLogStoreForTest_(store);
            e.setPlantLogLiveTailForTest_(tail);

            tail.tick_();
            testCase.verifyEqual(store.getCount(), 3);
            testCase.verifyNotEmpty(sel.hPlantLogMarkers, ...
                'after tick_, listener must populate slider markers (PLOG-VIZ-08)');

            appendRowsToCsv_(csvPath, { ...
                {'2025-01-15 10:15:00', 'cooler on'}, ...
                {'2025-01-15 10:20:00', 'cooler off'}});
            tail.tick_();
            testCase.verifyEqual(store.getCount(), 5);

            e.setPlantLogLiveTailForTest_([]);   % clean detach before teardown
        end

        function testHoverFindsEntry(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            p = uipanel(f);
            sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
            ts1 = datenum('2025-01-15 10:00:00'); %#ok<DATNM>
            ts2 = datenum('2025-01-15 10:05:00'); %#ok<DATNM>
            sel.setDataRange(ts1 - 1, ts2 + 1);

            e = DashboardEngine('TestHoverFind');
            testCase.Engines{end+1} = e;
            e.setTimeRangeSelectorForTest_(sel);

            store = PlantLogStore('synthetic.csv');
            store.addEntries([ ...
                PlantLogEntry('Timestamp', ts1, 'Message', 'first',  'Metadata', struct()), ...
                PlantLogEntry('Timestamp', ts2, 'Message', 'second', 'Metadata', struct())]);
            e.setPlantLogStoreForTest_(store);

            testCase.verifyNotEmpty(e.PlantLogSliderHover_);
            pick = e.PlantLogSliderHover_.simulateHoverAt_(ts2);
            testCase.verifyNotEmpty(pick, 'hover lookup at ts2 must find an entry');
            testCase.verifyEqual(pick.Message, 'second');
        end

        function testFullPipelineCleanup(testCase)
            csvPath = [tempname '.csv'];
            testCase.TempFiles{end+1} = csvPath;
            writeInitialCsv_(csvPath);

            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            p = uipanel(f);
            sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
            tsLow  = datenum('2025-01-15 09:00:00'); %#ok<DATNM>
            tsHigh = datenum('2025-01-15 11:00:00'); %#ok<DATNM>
            sel.setDataRange(tsLow, tsHigh);

            baselineTimers = numel(timerfindall());

            store = PlantLogStore(csvPath);
            m = struct('TimestampColumn', 'timestamp', ...
                'MessageColumn', 'message', 'TimestampFormat', '');
            tail = PlantLogLiveTail(store, csvPath, m);
            e = DashboardEngine('TestFullCleanup');
            e.setTimeRangeSelectorForTest_(sel);
            e.setPlantLogStoreForTest_(store);
            e.setPlantLogLiveTailForTest_(tail);

            delete(e);
            delete(tail);

            afterTimers = numel(timerfindall());
            testCase.verifyTrue(afterTimers <= baselineTimers, ...
                sprintf('timerfindall must not exceed baseline; got %d > %d', ...
                    afterTimers, baselineTimers));

            afterWBM = get(f, 'WindowButtonMotionFcn');
            if isa(afterWBM, 'function_handle')
                wbmStr = func2str(afterWBM);
                testCase.verifyTrue(isempty(strfind(wbmStr, 'onFigureMove_')), ...
                    sprintf('WBMFcn must NOT reference hover''s closure; got %s', wbmStr)); %#ok<STREMP>
            end
        end

        function testRealTimerTickRoundTrip(testCase)
            % Real timer end-to-end: Interval=0.2s, StartImmediately=true,
            % pause(0.6) -> at least one tick fires, listener triggers
            % computePlantLogMarkers, slider markers populate WITHOUT
            % engine.render(). This is the strongest end-to-end proof
            % short of driving real mouse motion.
            csvPath = [tempname '.csv'];
            testCase.TempFiles{end+1} = csvPath;
            writeInitialCsv_(csvPath);

            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            p = uipanel(f);
            sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
            tsLow  = datenum('2025-01-15 09:00:00'); %#ok<DATNM>
            tsHigh = datenum('2025-01-15 11:00:00'); %#ok<DATNM>
            sel.setDataRange(tsLow, tsHigh);

            store = PlantLogStore(csvPath);
            m = struct('TimestampColumn', 'timestamp', ...
                'MessageColumn', 'message', 'TimestampFormat', '');
            tail = PlantLogLiveTail(store, csvPath, m, ...
                'Interval', 0.2, 'StartImmediately', true);
            testCase.Tails{end+1} = tail;

            e = DashboardEngine('TestRealTimer');
            testCase.Engines{end+1} = e;
            e.setTimeRangeSelectorForTest_(sel);
            e.setPlantLogStoreForTest_(store);
            e.setPlantLogLiveTailForTest_(tail);

            pause(0.6);   % allow at least one timer fire

            testCase.verifyEqual(store.getCount(), 3, ...
                'real timer tick must populate the store within 0.6s');
            testCase.verifyNotEmpty(sel.hPlantLogMarkers, ...
                'real timer tick must populate slider markers via listener');

            tail.stop();   % deterministic stop before teardown
            e.setPlantLogLiveTailForTest_([]);
        end

    end
end

% =========================================================================
% LOCAL HELPER FUNCTIONS
% =========================================================================

function writeInitialCsv_(path)
    fid = fopen(path, 'w');
    fprintf(fid, 'timestamp,message\n');
    fprintf(fid, '%s,%s\n', '2025-01-15 10:00:00', 'pump on');
    fprintf(fid, '%s,%s\n', '2025-01-15 10:05:00', 'pump off');
    fprintf(fid, '%s,%s\n', '2025-01-15 10:10:00', 'valve open');
    fclose(fid);
end

function appendRowsToCsv_(path, rows)
    fid = fopen(path, 'a');
    for k = 1:numel(rows)
        fprintf(fid, '%s,%s\n', rows{k}{1}, rows{k}{2});
    end
    fclose(fid);
end
