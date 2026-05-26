classdef TestPlantLogImportSmoke < matlab.unittest.TestCase
%TESTPLANTLOGIMPORTSMOKE End-to-end suite for Phase 1030 import pipeline.
%
%   Mirrors tests/test_plant_log_import_smoke.m and adds MATLAB-only
%   coverage of the interactive path (dialog confirm/cancel) and the
%   XLSX happy-path (PLOG-IM-02). MATLAB-only -- Octave runs the
%   function-style smoke.
%
%   Contract: deliberately omits manual `addpath(fullfile( ..., 'libs',
%   'PlantLog'))` -- install.m's libs-block edit (Phase 1029 Plan 03)
%   handles it.

    properties (Access = private)
        TmpFiles = {}
        Dialogs  = {}
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            this_dir = fileparts(mfilename('fullpath'));
            tests_dir = fileparts(this_dir);
            repo_root = fileparts(tests_dir);
            addpath(repo_root);
            install();
        end
    end

    methods (TestMethodTeardown)
        function cleanupAll(testCase)
            for k = 1:numel(testCase.Dialogs)
                try
                    if isvalid(testCase.Dialogs{k})
                        delete(testCase.Dialogs{k});
                    end
                catch
                end
            end
            testCase.Dialogs = {};
            for k = 1:numel(testCase.TmpFiles)
                p = testCase.TmpFiles{k};
                try
                    if exist(p, 'file') == 2
                        delete(p);
                    end
                catch
                end
            end
            testCase.TmpFiles = {};
        end
    end

    methods (Test)

        function testPathPickupReader(testCase)
            testCase.verifyTrue(~isempty(which('PlantLogReader')));
        end

        function testPathPickupDialog(testCase)
            testCase.verifyTrue(~isempty(which('PlantLogImportDialog')));
        end

        function testHeadlessEndToEnd(testCase)
            p = testCase.writeCsv_({ ...
                {'2025-01-15 12:00:00', 'first',  'M1'}, ...
                {'2025-01-15 12:05:00', 'second', 'M2'}}, ...
                {'Time', 'Msg', 'Machine'});
            m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
            entries = PlantLogReader.openInteractive(p, 'Headless', true, 'Mapping', m);
            testCase.verifyEqual(numel(entries), 2);
            store = PlantLogStore(p);
            store.addEntries(entries);
            testCase.verifyEqual(store.getCount(), 2);
        end

        function testHeadlessWithoutMappingThrows(testCase)
            p = testCase.writeCsv_({{'2025-01-15 12:00:00', 'hi'}}, {'Time', 'Msg'});
            testCase.verifyError(@() PlantLogReader.openInteractive(p, 'Headless', true), ...
                'PlantLogReader:invalidInput');
        end

        function testHeadlessEmptyFileReturnsEmpty(testCase)
            p = [tempname() '.csv'];
            testCase.TmpFiles{end+1} = p;
            fid = fopen(p, 'w'); fprintf(fid, 'Time,Msg\n'); fclose(fid);
            m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
            entries = PlantLogReader.openInteractive(p, 'Headless', true, 'Mapping', m);
            testCase.verifyTrue(isempty(entries));
        end

        function testInteractiveConfirmReturnsEntries(testCase)
            % Interactive path: drive the dialog programmatically.
            % Pattern: spawn the dialog OURSELVES (skipping openInteractive's
            % runModal so we can inspect + drive it), then assert it
            % returns the right mapping; finally call readFile via the
            % public reader to validate the full pipe shape.
            p = testCase.writeCsv_({ ...
                {'2025-01-15 12:00:00', 'first',  'M1'}, ...
                {'2025-01-15 12:05:00', 'second', 'M2'}, ...
                {'2025-01-15 12:10:00', 'third',  'M3'}}, ...
                {'Time', 'Msg', 'Machine'});
            T = readtable(p);
            am = PlantLogReader.autoDetect(T);
            dlg = PlantLogImportDialog(p, T, am);
            testCase.Dialogs{end+1} = dlg;

            % Programmatic Confirm
            confirmBtn = testCase.getPrivate_(dlg, 'hConfirmBtn_');
            confirmBtn.ButtonPushedFcn([], []);

            mapping = testCase.getPrivate_(dlg, 'FinalMapping_');
            testCase.verifyClass(mapping, 'struct');

            % Now call readFile with that mapping (mimicking openInteractive's tail)
            entries = PlantLogReader.readFile(p, mapping);
            testCase.verifyEqual(numel(entries), 3);
        end

        function testInteractiveCancelReturnsEmpty(testCase)
            p = testCase.writeCsv_({ ...
                {'2025-01-15 12:00:00', 'a',  'M1'}, ...
                {'2025-01-15 12:05:00', 'b',  'M1'}}, ...
                {'Time', 'Msg', 'Machine'});
            T = readtable(p);
            am = PlantLogReader.autoDetect(T);
            dlg = PlantLogImportDialog(p, T, am);
            testCase.Dialogs{end+1} = dlg;

            cancelBtn = testCase.getPrivate_(dlg, 'hCancelBtn_');
            cancelBtn.ButtonPushedFcn([], []);

            mapping = testCase.getPrivate_(dlg, 'FinalMapping_');
            testCase.verifyTrue(isempty(mapping));
        end

        function testXlsxHappyPath(testCase)
            % PLOG-IM-02 runtime check: write an XLSX tempfile and
            % round-trip via openInteractive headless. MATLAB writetable
            % supports XLSX without a toolbox via the built-in Excel
            % writer. Skipped explicitly when writetable to .xlsx fails
            % (older MATLAB or Octave).
            p = [tempname() '.xlsx'];
            T = table( ...
                ["2025-01-15 12:00:00"; "2025-01-15 12:05:00"; "2025-01-15 12:10:00"], ...
                ["m1"; "m2"; "m3"], ...
                'VariableNames', {'Time', 'Msg'});
            try
                writetable(T, p);
            catch
                testCase.assumeFail('XLSX write not supported on this MATLAB');
                return;
            end
            testCase.TmpFiles{end+1} = p;
            m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
            entries = PlantLogReader.openInteractive(p, 'Headless', true, 'Mapping', m);
            testCase.verifyEqual(numel(entries), 3);
        end

    end

    methods (Access = private)

        function p = writeCsv_(testCase, rows, headers)
            p = [tempname() '.csv'];
            testCase.TmpFiles{end+1} = p;
            fid = fopen(p, 'w');
            cleanup = onCleanup(@() fclose(fid));
            fprintf(fid, '%s\n', strjoin(headers, ','));
            for r = 1:numel(rows)
                fprintf(fid, '%s\n', strjoin(rows{r}, ','));
            end
            clear cleanup;
        end

        function v = getPrivate_(testCase, obj, name) %#ok<INUSD>
            w = warning('off', 'MATLAB:structOnObject');
            cleanupW = onCleanup(@() warning(w));
            s = struct(obj);
            v = s.(name);
            clear cleanupW;
        end

    end
end
