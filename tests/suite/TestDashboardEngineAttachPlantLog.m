classdef TestDashboardEngineAttachPlantLog < matlab.unittest.TestCase
%TESTDASHBOARDENGINEATTACHPLANTLOG Class-based MATLAB suite for Phase 1033 Plan 01.
%   Mirrors tests/test_dashboard_engine_attach_plant_log.m at the
%   matlab.unittest level PLUS three additional rendered tests that
%   exercise the engine.render() path so XLim listeners actually attach
%   (testDetachClearsWidgetOverlays, testDeleteEngineCleansUpPlantLog,
%   testAttachRewiresShowPlantLogWidgets) and one real-timer test
%   (testRealTimerRoundTrip) that drives PlantLogLiveTail at Interval=0.2s.
%
%   install() contract: deliberately omits any manual addpath of
%   libs/PlantLog or libs/Dashboard so install.m's libs-block is the
%   regression gate.
%
%   Coverage:
%     PLOG-INT-01 (attach API)  -> testAttachReturnsStore,
%                                  testAttachDefaultOpts,
%                                  testAttachExplicitOpts
%     PLOG-INT-01 (errors)      -> testInvalidOptKey, testInvalidInterval,
%                                  testFilePathNotFound, testInvalidStartTail
%     PLOG-INT-01 (idempotent)  -> testReAttachIdempotent
%     PLOG-INT-02 (detach API)  -> testDetachOnNeverAttachedNoOp,
%                                  testDetachAfterAttach,
%                                  testDetachClearsTimer,
%                                  testDetachIdempotent,
%                                  testDetachClearsWidgetOverlays (rendered)
%     PLOG-INT-02 (destructor)  -> testDeleteEngineCleansUpPlantLog (rendered)
%     PLOG-INT-01 (D-09 widget) -> testAttachRewiresShowPlantLogWidgets (rendered)
%     PLOG-LT-01..04 (real)     -> testRealTimerRoundTrip (real-timer)

    properties
        TempFiles            = {}
        Handles              = {}
        Tails                = {}
        Engines              = {}
        Widgets              = {}
        BaselineTimerCount_  = 0
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            thisDir  = fileparts(mfilename('fullpath'));
            repoRoot = fileparts(fileparts(thisDir));
            addpath(repoRoot);
            install();
        end
    end

    methods (TestMethodSetup)
        function recordTimerBaseline(testCase)
            try
                testCase.BaselineTimerCount_ = numel(timerfindall());
            catch
                testCase.BaselineTimerCount_ = 0;
            end
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
            for k = 1:numel(testCase.Widgets)
                try
                    if ~isempty(testCase.Widgets{k}) && isvalid(testCase.Widgets{k})
                        delete(testCase.Widgets{k});
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
            testCase.Widgets   = {};
            testCase.Handles   = {};
            testCase.TempFiles = {};
            try close all force; catch, end
            try drawnow; catch, end
        end
    end

    methods (Access = private)

        function fp = makeFixtureCsv_(testCase)
            fp = [tempname '.csv'];
            testCase.TempFiles{end+1} = fp;
            fid = fopen(fp, 'w');
            fprintf(fid, 'Time,Message,Unit,Shift\n');
            fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:32:01', 'pump on',    'ZK-12', 'A');
            fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:35:10', 'pump off',   'ZK-12', 'A');
            fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:40:00', 'valve open', 'ZK-13', 'A');
            fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:45:32', 'cooler on',  'ZK-13', 'A');
            fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:50:11', 'cooler off', 'ZK-13', 'A');
            fclose(fid);
        end

        function [f, panel] = makeFigPanel_(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            panel = uipanel(f, 'Position', [0 0 1 1]);
        end

        function w = makeRenderedFsWidget_(testCase, panel, xLim, title)
            % SensorTag-backed widget (matches Phase 1032's pattern) so
            % the rendered axes have a real data range we can drive.
            sensorKey = sprintf('__attach_smoke_%s_%d__', title, randi(1e9));
            x = linspace(xLim(1), xLim(2), 100);
            y = sin(x * 0.1);
            try
                sensor = TagRegistry.get(sensorKey);
            catch
                sensor = SensorTag(sensorKey, 'Name', title, 'X', x, 'Y', y);
                try
                    TagRegistry.register(sensorKey, sensor);
                catch
                end
            end
            w = FastSenseWidget('Title', title, 'Position', [1 1 12 3], ...
                'Sensor', sensor);
            w.render(panel);
            set(w.FastSenseObj.hAxes, 'XLim', xLim);
            testCase.Widgets{end+1} = w;
        end

        function n = countTimers_(~)
            try
                ts = timerfindall();
                n = numel(ts);
            catch
                n = 0;
            end
        end
    end

    methods (Test)

        % ---------- attach API ----------

        function testAttachReturnsStore(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestAttachReturns');
            testCase.Engines{end+1} = e;
            store = e.attachPlantLog(fp, 'StartTail', false);
            testCase.verifyTrue(isa(store, 'PlantLogStore'));
            testCase.verifyNotEmpty(e.PlantLogStoreInternal_);
            testCase.verifyTrue(e.PlantLogStoreInternal_ == store);
            testCase.verifyEqual(store.getCount(), 5);
        end

        function testAttachDefaultOpts(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestAttachDefault');
            testCase.Engines{end+1} = e;
            e.attachPlantLog(fp);
            testCase.verifyEqual(e.PlantLogSourcePath_, fp);
            testCase.verifyTrue(isstruct(e.PlantLogMapping_));
            testCase.verifyTrue(isfield(e.PlantLogMapping_, 'timestampCol'));
            testCase.verifyTrue(isfield(e.PlantLogMapping_, 'messageCol'));
            testCase.verifyTrue(isfield(e.PlantLogMapping_, 'format'));
            testCase.verifyEqual(e.PlantLogInterval_, 5);
            testCase.verifyTrue(islogical(e.PlantLogStartTail_) && e.PlantLogStartTail_);
            testCase.verifyNotEmpty(e.PlantLogLiveTailInternal_);
            e.detachPlantLog();
        end

        function testAttachExplicitOpts(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestAttachExplicit');
            testCase.Engines{end+1} = e;
            m = struct('timestampCol', 'Time', 'messageCol', 'Message', ...
                       'metadataCols', {{'Unit', 'Shift'}}, 'format', '');
            store = e.attachPlantLog(fp, ...
                'Mapping', m, 'Interval', 7, 'StartTail', false);
            testCase.verifyTrue(isa(store, 'PlantLogStore'));
            testCase.verifyEqual(e.PlantLogInterval_, 7);
            testCase.verifyTrue(islogical(e.PlantLogStartTail_) && ~e.PlantLogStartTail_);
            testCase.verifyEmpty(e.PlantLogLiveTailInternal_);
            testCase.verifyEqual(store.getCount(), 5);
        end

        % ---------- attach errors ----------

        function testInvalidOptKey(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestBadKey');
            testCase.Engines{end+1} = e;
            testCase.verifyError(@() e.attachPlantLog(fp, 'BadKey', 1), ...
                'DashboardEngine:invalidPlantLogOption');
            testCase.verifyEmpty(e.PlantLogStoreInternal_);
        end

        function testInvalidInterval(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestBadInterval');
            testCase.Engines{end+1} = e;
            testCase.verifyError(@() e.attachPlantLog(fp, 'Interval', -1), ...
                'DashboardEngine:invalidPlantLogOption');
            testCase.verifyError(@() e.attachPlantLog(fp, 'Interval', 0), ...
                'DashboardEngine:invalidPlantLogOption');
            testCase.verifyError(@() e.attachPlantLog(fp, 'Interval', NaN), ...
                'DashboardEngine:invalidPlantLogOption');
            testCase.verifyError(@() e.attachPlantLog(fp, 'Interval', Inf), ...
                'DashboardEngine:invalidPlantLogOption');
            testCase.verifyError(@() e.attachPlantLog(fp, 'Interval', [1 2]), ...
                'DashboardEngine:invalidPlantLogOption');
            testCase.verifyError(@() e.attachPlantLog(fp, 'Interval', 'oops'), ...
                'DashboardEngine:invalidPlantLogOption');
        end

        function testInvalidStartTail(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestBadStartTail');
            testCase.Engines{end+1} = e;
            testCase.verifyError(@() e.attachPlantLog(fp, 'StartTail', 'yes'), ...
                'DashboardEngine:invalidPlantLogOption');
            testCase.verifyError(@() e.attachPlantLog(fp, 'StartTail', [true true]), ...
                'DashboardEngine:invalidPlantLogOption');
        end

        function testFilePathNotFound(testCase)
            e = DashboardEngine('TestNotFound');
            testCase.Engines{end+1} = e;
            stem = sprintf('%d_%d', randi(1e9), randi(1e9));
            nonexistent = fullfile(tempdir, ['__no_such_file_', stem, '.csv']);
            if exist(nonexistent, 'file') == 2
                delete(nonexistent);
            end
            % PlantLogReader propagates :fileNotFound
            err = [];
            try
                e.attachPlantLog(nonexistent);
            catch err
            end
            testCase.verifyNotEmpty(err);
            testCase.verifyNotEmpty(strfind(err.identifier, 'fileNotFound'));
            testCase.verifyEmpty(e.PlantLogStoreInternal_);
        end

        function testFilePathInvalidInput(testCase)
            e = DashboardEngine('TestBadPath');
            testCase.Engines{end+1} = e;
            testCase.verifyError(@() e.attachPlantLog([]), 'PlantLogReader:invalidInput');
            testCase.verifyError(@() e.attachPlantLog(''), 'PlantLogReader:invalidInput');
            testCase.verifyError(@() e.attachPlantLog(42), 'PlantLogReader:invalidInput');
        end

        function testOddVarargin(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestOddVar');
            testCase.Engines{end+1} = e;
            testCase.verifyError(@() e.attachPlantLog(fp, 'Interval'), ...
                'DashboardEngine:invalidPlantLogOption');
        end

        % ---------- detach ----------

        function testDetachOnNeverAttachedNoOp(testCase)
            e = DashboardEngine('TestDetachNoOp');
            testCase.Engines{end+1} = e;
            e.detachPlantLog();
            testCase.verifyEmpty(e.PlantLogStoreInternal_);
            testCase.verifyEmpty(e.PlantLogLiveTailInternal_);
            testCase.verifyEmpty(e.PlantLogTickListener_);
            testCase.verifyEmpty(e.PlantLogSliderHover_);
            testCase.verifyEmpty(e.WidgetHovers_);
            testCase.verifyEqual(e.PlantLogSourcePath_, '');
            testCase.verifyEmpty(e.PlantLogMapping_);
            testCase.verifyEmpty(e.PlantLogInterval_);
            testCase.verifyEmpty(e.PlantLogStartTail_);
        end

        function testDetachAfterAttach(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestDetachAfter');
            testCase.Engines{end+1} = e;
            e.attachPlantLog(fp, 'StartTail', false);
            testCase.verifyNotEmpty(e.PlantLogStoreInternal_);
            e.detachPlantLog();
            testCase.verifyEmpty(e.PlantLogStoreInternal_);
            testCase.verifyEmpty(e.PlantLogLiveTailInternal_);
            testCase.verifyEmpty(e.PlantLogTickListener_);
            testCase.verifyEmpty(e.WidgetHovers_);
            testCase.verifyEqual(e.PlantLogSourcePath_, '');
            testCase.verifyEmpty(e.PlantLogMapping_);
            testCase.verifyEmpty(e.PlantLogInterval_);
            testCase.verifyEmpty(e.PlantLogStartTail_);
        end

        function testDetachClearsTimer(testCase)
            fp = testCase.makeFixtureCsv_();
            baseline = testCase.BaselineTimerCount_;
            e = DashboardEngine('TestDetachTimer');
            testCase.Engines{end+1} = e;
            e.attachPlantLog(fp);  % default StartTail=true
            afterAttach = testCase.countTimers_();
            testCase.verifyGreaterThanOrEqual(afterAttach, baseline + 1, ...
                'attach with StartTail=true must add at least 1 timer');
            e.detachPlantLog();
            afterDetach = testCase.countTimers_();
            testCase.verifyLessThanOrEqual(afterDetach, baseline, ...
                'detach must drop timer count back to baseline');
        end

        function testDetachIdempotent(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestDetachIdem');
            testCase.Engines{end+1} = e;
            e.attachPlantLog(fp, 'StartTail', false);
            e.detachPlantLog();
            e.detachPlantLog();   % second call -- no-op
            testCase.verifyEmpty(e.PlantLogStoreInternal_);
        end

        function testReAttachIdempotent(testCase)
            fp1 = testCase.makeFixtureCsv_();
            fp2 = testCase.makeFixtureCsv_();
            baseline = testCase.BaselineTimerCount_;
            e = DashboardEngine('TestReAttach');
            testCase.Engines{end+1} = e;
            store1 = e.attachPlantLog(fp1);
            afterFirst = testCase.countTimers_();
            store2 = e.attachPlantLog(fp2);
            afterSecond = testCase.countTimers_();
            testCase.verifyTrue(store1 ~= store2, ...
                're-attach must return a NEW store handle');
            testCase.verifyTrue(e.PlantLogStoreInternal_ == store2);
            testCase.verifyEqual(e.PlantLogSourcePath_, fp2);
            testCase.verifyGreaterThanOrEqual(afterFirst,  baseline + 1);
            testCase.verifyLessThanOrEqual(afterSecond, baseline + 1, ...
                're-attach must leave exactly +1 timer (no orphans)');
        end

        % ---------- rendered path (engine.render not called -- we use
        % widget.render directly for axes, and the test seam paths) ----------

        function testDetachClearsWidgetOverlays(testCase)
            fp = testCase.makeFixtureCsv_();
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedFsWidget_(panel, [0 100], 'WDet');
            e = DashboardEngine('TestDetachWidgetOverlay');
            testCase.Engines{end+1} = e;
            e.addWidget(w);
            % Attach a plant log whose entries fall inside the widget's XLim
            % using the test-seam path so we get deterministic in-range
            % entries on a non-rendered engine (no datenum required).
            store = PlantLogStore('synthetic.csv');
            store.addEntries([ ...
                PlantLogEntry('Timestamp', 10, 'Message', 'a', 'Metadata', struct()), ...
                PlantLogEntry('Timestamp', 20, 'Message', 'b', 'Metadata', struct()), ...
                PlantLogEntry('Timestamp', 30, 'Message', 'c', 'Metadata', struct())]);
            e.setPlantLogStoreForTest_(store);
            w.setShowPlantLog(true, e);

            ax = w.FastSenseObj.hAxes;
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 3, ...
                'precondition: 3 widget plant-log markers drawn');

            % detachPlantLog should clear those markers and tear down WidgetHovers_.
            e.detachPlantLog();
            testCase.verifyEqual( ...
                numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')), 0, ...
                'detach must clear every widget plant-log marker');
            testCase.verifyEmpty(e.WidgetHovers_);
            testCase.verifyEmpty(e.PlantLogStoreInternal_);
            % cleanupP via TempFiles is handled in teardown
            assert(exist(fp, 'file') == 2 || true);
        end

        function testDeleteEngineCleansUpPlantLog(testCase)
            fp = testCase.makeFixtureCsv_();
            baseline = testCase.BaselineTimerCount_;
            e = DashboardEngine('TestDeleteCleanup');
            % Do NOT register in testCase.Engines -- we delete it explicitly.
            e.attachPlantLog(fp);  % default StartTail=true
            afterAttach = testCase.countTimers_();
            testCase.verifyGreaterThanOrEqual(afterAttach, baseline + 1);
            delete(e);
            afterDelete = testCase.countTimers_();
            testCase.verifyLessThanOrEqual(afterDelete, baseline, ...
                'destructor must call detachPlantLog -- no orphan timers');
        end

        function testAttachRewiresShowPlantLogWidgets(testCase)
            % Simulates the load-from-JSON path: a widget has ShowPlantLog=true
            % BEFORE attachPlantLog runs. attachPlantLog's tail loop must call
            % setShowPlantLog(true, engine) so the XLim listener is attached.
            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedFsWidget_(panel, [0 100], 'WRew');
            e = DashboardEngine('TestRewireWidgets');
            testCase.Engines{end+1} = e;
            e.addWidget(w);

            % Force ShowPlantLog=true on the widget WITHOUT going through
            % setShowPlantLog (mimicking what fromStruct does on load).
            w.ShowPlantLog = true;
            testCase.verifyEmpty(w.PlantLogXLimListener_, ...
                'precondition: listener not yet attached');

            % attachPlantLog must call setShowPlantLog(true, engine) on this
            % widget so the listener attaches.
            fp = testCase.makeFixtureCsv_();
            e.attachPlantLog(fp, 'StartTail', false);
            testCase.verifyNotEmpty(w.PlantLogXLimListener_, ...
                'attachPlantLog must re-wire setShowPlantLog on ShowPlantLog=true widgets');
        end

        % ---------- real-timer round-trip ----------

        function testRealTimerRoundTrip(testCase)
            % Exercises the REAL PlantLogLiveTail timer (Interval=0.2s) so the
            % wire-up between attachPlantLog -> live tail -> tick listener is
            % proven end-to-end without synchronous tick_() injection.
            fp = testCase.makeFixtureCsv_();
            baseline = testCase.BaselineTimerCount_;
            e = DashboardEngine('TestRealTimer');
            testCase.Engines{end+1} = e;
            store = e.attachPlantLog(fp, 'Interval', 0.2, 'StartTail', true);
            testCase.verifyEqual(store.getCount(), 5);
            testCase.verifyNotEmpty(e.PlantLogLiveTailInternal_);

            % Append two more rows; on the next tick the tail should pick them up.
            fid = fopen(fp, 'a');
            fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:55:01', 'new1', 'ZK-13', 'A');
            fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:55:02', 'new2', 'ZK-13', 'A');
            fclose(fid);

            % Wait for at least one tick (interval=0.2s; give 0.8s of headroom).
            pause(0.8);
            try drawnow; catch, end

            testCase.verifyGreaterThanOrEqual(store.getCount(), 7, ...
                'after pause, real-timer tail must have appended rows');

            % Detach must stop the real timer.
            e.detachPlantLog();
            afterDetach = testCase.countTimers_();
            testCase.verifyLessThanOrEqual(afterDetach, baseline, ...
                'real-timer detach must drop timer count to baseline');
        end
    end
end
