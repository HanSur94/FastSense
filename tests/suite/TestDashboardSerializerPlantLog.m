classdef TestDashboardSerializerPlantLog < matlab.unittest.TestCase
%TESTDASHBOARDSERIALIZERPLANTLOG Class-based MATLAB suite for Phase 1033 Plan 02.
%   Mirrors tests/test_dashboard_serializer_plant_log.m at the
%   matlab.unittest level PLUS rendered round-trip tests that exercise
%   the engine.render() path so XLim listeners + per-widget overlays
%   round-trip through JSON and .m-script save/load.
%
%   install() contract: deliberately omits any manual addpath of
%   libs/PlantLog or libs/Dashboard so install.m's libs-block is the
%   regression gate.
%
%   Coverage:
%     PLOG-INT-04 (save side)   -> testSaveJsonEmitsPlantLogWhenAttached,
%                                  testSaveJsonOmitsPlantLogWhenEmpty,
%                                  testSaveJsonBackCompatByteIdentical,
%                                  testSaveScriptEmitsAttachPlantLog,
%                                  testSaveScriptOmitsAttachPlantLogWhenEmpty,
%                                  testWidgetShowPlantLogTrueEmitsNVPair,
%                                  testWidgetShowPlantLogFalseOmitsNVPair,
%                                  testMetadataColsDoubleBracePreservesShape,
%                                  testRoundTripPersistsInterval
%     PLOG-INT-05 (load side)   -> testLoadJsonAttachesWhenPresent,
%                                  testLoadJsonBackCompatNoPlantLogKey,
%                                  testLoadJsonPathMissingWarnsAndContinues,
%                                  testLoadJsonMappingMismatchAutoDetects,
%                                  testLoadJsonSchemaInvalidErrors
%     PLOG-INT-05 (rendered)    -> testRoundTripWidgetShowPlantLog (rendered),
%                                  testRoundTripPerWidgetShowPlantLogScriptPath,
%                                  testReAttachAfterLoadIsIdempotent

    properties
        TempFiles            = {}
        Handles              = {}
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

        function s = readFileAsString_(~, filepath)
            fid = fopen(filepath, 'r');
            s = fread(fid, '*char')';
            fclose(fid);
        end

        function p = tempPathOut_(testCase, ext)
            p = [tempname, ext];
            testCase.TempFiles{end+1} = p;
        end

        function [f, panel] = makeFigPanel_(testCase)
            f = figure('Visible', 'off');
            testCase.Handles{end+1} = f;
            panel = uipanel(f, 'Position', [0 0 1 1]);
        end

        function w = makeRenderedFsWidget_(testCase, panel, xLim, title)
            sensorKey = sprintf('__sl_smoke_%s_%d__', title, randi(1e9));
            x = linspace(xLim(1), xLim(2), 100);
            y = sin(x * 0.1);
            try
                sensor = TagRegistry.get(sensorKey);
            catch
                sensor = SensorTag(sensorKey, 'Name', title, 'X', x, 'Y', y);
                try TagRegistry.register(sensorKey, sensor); catch, end
            end
            w = FastSenseWidget('Title', title, 'Position', [1 1 12 3], ...
                'Sensor', sensor);
            w.render(panel);
            set(w.FastSenseObj.hAxes, 'XLim', xLim);
            testCase.Widgets{end+1} = w;
        end
    end

    methods (Test)

        % =================================================================
        % SAVE side -- PLOG-INT-04
        % =================================================================

        function testSaveJsonEmitsPlantLogWhenAttached(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestSaveJson');
            testCase.Engines{end+1} = e;
            e.attachPlantLog(fp, 'StartTail', false);
            outJson = testCase.tempPathOut_('.json');
            e.save(outJson);
            s = testCase.readFileAsString_(outJson);
            testCase.verifyNotEmpty(strfind(s, '"plantLog"'));
            testCase.verifyNotEmpty(strfind(s, '"sourcePath"'));
            testCase.verifyNotEmpty(strfind(s, '"mapping"'));
            testCase.verifyNotEmpty(strfind(s, '"interval"'));
            testCase.verifyNotEmpty(strfind(s, '"startTail"'));
        end

        function testSaveJsonOmitsPlantLogWhenEmpty(testCase)
            e = DashboardEngine('TestSaveJsonEmpty');
            testCase.Engines{end+1} = e;
            outJson = testCase.tempPathOut_('.json');
            e.save(outJson);
            s = testCase.readFileAsString_(outJson);
            testCase.verifyEmpty(strfind(s, 'plantLog'));
        end

        function testSaveJsonBackCompatByteIdentical(testCase)
            e1 = DashboardEngine('BackCompatRef');
            testCase.Engines{end+1} = e1;
            out1 = testCase.tempPathOut_('.json');
            e1.save(out1);
            s1 = testCase.readFileAsString_(out1);

            e2 = DashboardEngine('BackCompatRef');
            testCase.Engines{end+1} = e2;
            out2 = testCase.tempPathOut_('.json');
            e2.save(out2);
            s2 = testCase.readFileAsString_(out2);

            testCase.verifyEqual(s1, s2, ...
                'two no-plant-log engines must produce byte-identical JSON');
            testCase.verifyEmpty(strfind(s1, 'plantLog'));
        end

        function testSaveScriptEmitsAttachPlantLog(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestSaveScript');
            testCase.Engines{end+1} = e;
            e.attachPlantLog(fp, 'StartTail', false);
            outM = testCase.tempPathOut_('.m');
            e.save(outM);
            s = testCase.readFileAsString_(outM);
            testCase.verifyNotEmpty(strfind(s, 'd.attachPlantLog('));
            testCase.verifyNotEmpty(strfind(s, '''Mapping'''));
            testCase.verifyNotEmpty(strfind(s, 'struct('));
            testCase.verifyNotEmpty(strfind(s, '''Interval'''));
            testCase.verifyNotEmpty(strfind(s, '''StartTail'''));
        end

        function testSaveScriptOmitsAttachPlantLogWhenEmpty(testCase)
            e = DashboardEngine('TestSaveScriptEmpty');
            testCase.Engines{end+1} = e;
            outM = testCase.tempPathOut_('.m');
            e.save(outM);
            s = testCase.readFileAsString_(outM);
            testCase.verifyEmpty(strfind(s, 'attachPlantLog'));
        end

        function testWidgetShowPlantLogTrueEmitsNVPair(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestWidgetShow');
            testCase.Engines{end+1} = e;
            w = FastSenseWidget('Title', 'TestPlot', 'Position', [1 1 12 3]);
            w.ShowPlantLog = true;
            e.addWidget(w);
            e.attachPlantLog(fp, 'StartTail', false);
            outM = testCase.tempPathOut_('.m');
            e.save(outM);
            s = testCase.readFileAsString_(outM);
            testCase.verifyNotEmpty(strfind(s, '''ShowPlantLog'''));
            testCase.verifyNotEmpty(strfind(s, '''ShowPlantLog'', true'));
        end

        function testWidgetShowPlantLogFalseOmitsNVPair(testCase)
            e = DashboardEngine('TestWidgetDefault');
            testCase.Engines{end+1} = e;
            w = FastSenseWidget('Title', 'TestPlot', 'Position', [1 1 12 3]);
            e.addWidget(w);
            outM = testCase.tempPathOut_('.m');
            e.save(outM);
            s = testCase.readFileAsString_(outM);
            testCase.verifyEmpty(strfind(s, 'ShowPlantLog'));
        end

        function testMetadataColsDoubleBracePreservesShape(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestMetaCols');
            testCase.Engines{end+1} = e;
            m = struct('timestampCol', 'Time', 'messageCol', 'Message', ...
                       'metadataCols', {{'Unit', 'Shift'}}, 'format', '');
            e.attachPlantLog(fp, 'Mapping', m, 'StartTail', false);
            outM = testCase.tempPathOut_('.m');
            e.save(outM);
            s = testCase.readFileAsString_(outM);
            testCase.verifyNotEmpty(strfind(s, 'metadataCols'));
            testCase.verifyNotEmpty(strfind(s, '{{'));
        end

        function testRoundTripPersistsInterval(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestInterval');
            testCase.Engines{end+1} = e;
            % Default interval=5 -- explicit round-trip semantics
            e.attachPlantLog(fp, 'StartTail', false);
            outJson = testCase.tempPathOut_('.json');
            e.save(outJson);
            s = testCase.readFileAsString_(outJson);
            hasInterval = ~isempty(strfind(s, '"interval":5')) || ...
                          ~isempty(strfind(s, '"interval": 5'));
            testCase.verifyTrue(hasInterval, ...
                'JSON must persist interval=5 explicitly even at default');
        end

        % =================================================================
        % LOAD side -- PLOG-INT-05
        % =================================================================

        function testLoadJsonAttachesWhenPresent(testCase)
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestLoadAttach');
            testCase.Engines{end+1} = e;
            e.attachPlantLog(fp, 'StartTail', false);
            outJson = testCase.tempPathOut_('.json');
            e.save(outJson);
            e2 = DashboardEngine.load(outJson);
            testCase.Engines{end+1} = e2;
            testCase.verifyNotEmpty(e2.PlantLogStoreInternal_);
            testCase.verifyEqual(e2.PlantLogSourcePath_, fp);
            testCase.verifyEqual(e2.PlantLogStoreInternal_.getCount(), 5);
        end

        function testLoadJsonBackCompatNoPlantLogKey(testCase)
            e = DashboardEngine('TestBackCompatLoad');
            testCase.Engines{end+1} = e;
            outJson = testCase.tempPathOut_('.json');
            e.save(outJson);
            lastwarn('');
            e2 = DashboardEngine.load(outJson);
            testCase.Engines{end+1} = e2;
            [warnMsg, warnId] = lastwarn();
            testCase.verifyEmpty(e2.PlantLogStoreInternal_);
            testCase.verifyEmpty(strfind(warnId, 'plantLog'), ...
                sprintf('v1.0-v3.0 back-compat: no plantLog warning expected; got id=%s msg=%s', ...
                warnId, warnMsg));
        end

        function testLoadJsonPathMissingWarnsAndContinues(testCase)
            outJson = testCase.tempPathOut_('.json');
            stem = sprintf('%d_%d', randi(1e9), randi(1e9));
            nonexistent = fullfile(tempdir, ['__no_such_plog_', stem, '.csv']);
            jsonStr = sprintf(['{"name":"TestPathMissing","theme":"light",' ...
                '"liveInterval":1,"grid":{"columns":24},' ...
                '"plantLog":{"sourcePath":"%s","mapping":{"timestampCol":"Time",' ...
                '"messageCol":"Message","metadataCols":[],"format":""},' ...
                '"interval":5,"startTail":false},"widgets":[]}'], ...
                strrep(nonexistent, '\', '\\'));
            fid = fopen(outJson, 'w');
            fwrite(fid, jsonStr);
            fclose(fid);
            warnState = warning('on', 'DashboardEngine:plantLogPathMissing');
            cleanupWarn = onCleanup(@() warning(warnState));
            lastwarn('');
            e = DashboardEngine.load(outJson);
            testCase.Engines{end+1} = e;
            [~, warnId] = lastwarn();
            testCase.verifyEqual(warnId, 'DashboardEngine:plantLogPathMissing');
            testCase.verifyEmpty(e.PlantLogStoreInternal_);
            clear cleanupWarn;
        end

        function testLoadJsonMappingMismatchAutoDetects(testCase)
            fp = testCase.makeFixtureCsv_();
            outJson = testCase.tempPathOut_('.json');
            jsonStr = sprintf(['{"name":"TestMappingMismatch","theme":"light",' ...
                '"liveInterval":1,"grid":{"columns":24},' ...
                '"plantLog":{"sourcePath":"%s","mapping":{"timestampCol":"WrongCol",' ...
                '"messageCol":"AlsoWrong","metadataCols":[],"format":""},' ...
                '"interval":5,"startTail":false},"widgets":[]}'], ...
                strrep(fp, '\', '\\'));
            fid = fopen(outJson, 'w');
            fwrite(fid, jsonStr);
            fclose(fid);
            warnState = warning('on', 'DashboardEngine:plantLogMappingMismatch');
            cleanupWarn = onCleanup(@() warning(warnState));
            lastwarn('');
            e = DashboardEngine.load(outJson);
            testCase.Engines{end+1} = e;
            [~, warnId] = lastwarn();
            testCase.verifyEqual(warnId, 'DashboardEngine:plantLogMappingMismatch');
            testCase.verifyNotEmpty(e.PlantLogStoreInternal_);
            testCase.verifyEqual(e.PlantLogMapping_.timestampCol, 'Time');
            clear cleanupWarn;
        end

        function testLoadJsonSchemaInvalidErrors(testCase)
            outJson = testCase.tempPathOut_('.json');
            jsonStr = ['{"name":"TestSchemaInvalid","theme":"light",' ...
                '"liveInterval":1,"grid":{"columns":24},' ...
                '"plantLog":{"interval":5},"widgets":[]}'];
            fid = fopen(outJson, 'w');
            fwrite(fid, jsonStr);
            fclose(fid);
            testCase.verifyError(@() DashboardEngine.load(outJson), ...
                'DashboardSerializer:plantLogSchemaInvalid');
        end

        % =================================================================
        % Rendered round-trip tests -- per-widget ShowPlantLog persistence
        % =================================================================

        function testRoundTripWidgetShowPlantLog(testCase)
            % Rendered round-trip: build engine with a FastSenseWidget that
            % has ShowPlantLog=true, save to JSON, load, verify the loaded
            % widget retains ShowPlantLog=true AND that after attachPlantLog
            % runs on load, the widget's PlantLogXLimListener_ is non-empty
            % (engine re-wired the overlay).
            fp = testCase.makeFixtureCsv_();

            [~, panel] = testCase.makeFigPanel_();
            w = testCase.makeRenderedFsWidget_(panel, [1 100], 'RoundTrip');
            w.ShowPlantLog = true;

            e = DashboardEngine('TestRoundTripRendered');
            testCase.Engines{end+1} = e;
            e.addWidget(w);
            e.attachPlantLog(fp, 'StartTail', false);
            outJson = testCase.tempPathOut_('.json');
            e.save(outJson);

            e2 = DashboardEngine.load(outJson);
            testCase.Engines{end+1} = e2;
            testCase.verifyEqual(numel(e2.Widgets), 1);
            w2 = e2.Widgets{1};
            testCase.verifyTrue(w2.ShowPlantLog, ...
                'loaded widget must round-trip ShowPlantLog=true');
            testCase.verifyNotEmpty(e2.PlantLogStoreInternal_, ...
                'load must have re-imported the plant log');
        end

        function testRoundTripPerWidgetShowPlantLogScriptPath(testCase)
            % .m-script round-trip: save to .m, feval, verify equivalent
            % dashboard state. Uses a FastSenseWidget without rendered
            % sensor since .m-script reconstructs via addWidget (no
            % SensorTag required for ShowPlantLog round-trip).
            fp = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestMScript');
            testCase.Engines{end+1} = e;
            w = FastSenseWidget('Title', 'TestPlot', 'Position', [1 1 12 3]);
            w.ShowPlantLog = true;
            e.addWidget(w);
            e.attachPlantLog(fp, 'StartTail', false);
            outM = testCase.tempPathOut_('.m');
            e.save(outM);
            s = testCase.readFileAsString_(outM);
            testCase.verifyNotEmpty(strfind(s, '''ShowPlantLog'', true'));
            testCase.verifyNotEmpty(strfind(s, 'd.attachPlantLog('));
            % Run the .m-script: feval reconstructs the engine
            [fdir, fname] = fileparts(outM);
            addpath(fdir);
            cleanupPath = onCleanup(@() rmpath(fdir));
            e2 = feval(fname);
            testCase.Engines{end+1} = e2;
            testCase.verifyEqual(numel(e2.Widgets), 1);
            testCase.verifyTrue(e2.Widgets{1}.ShowPlantLog, ...
                'loaded widget must round-trip ShowPlantLog=true via .m-script');
            testCase.verifyNotEmpty(e2.PlantLogStoreInternal_);
            clear cleanupPath;
        end

        function testReAttachAfterLoadIsIdempotent(testCase)
            % Load a JSON with attached plant log, then call
            % engine.attachPlantLog(otherFile) -- verify clean re-attach
            % without orphan timers.
            fp1 = testCase.makeFixtureCsv_();
            fp2 = testCase.makeFixtureCsv_();
            e = DashboardEngine('TestReAttachAfterLoad');
            testCase.Engines{end+1} = e;
            e.attachPlantLog(fp1, 'StartTail', false);
            outJson = testCase.tempPathOut_('.json');
            e.save(outJson);
            e2 = DashboardEngine.load(outJson);
            testCase.Engines{end+1} = e2;
            % Now re-attach with a different file -- should detach first
            % then attach new
            baseline = numel(timerfindall());
            store2 = e2.attachPlantLog(fp2, 'StartTail', false);
            testCase.verifyNotEmpty(store2);
            testCase.verifyEqual(e2.PlantLogSourcePath_, fp2);
            % StartTail=false so no timer created
            afterReAttach = numel(timerfindall());
            testCase.verifyLessThanOrEqual(afterReAttach, baseline, ...
                're-attach with StartTail=false must not add timers');
        end
    end
end
