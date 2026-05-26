classdef TestPlantLogImportDialog < matlab.unittest.TestCase
%TESTPLANTLOGIMPORTDIALOG MATLAB class-based suite for PlantLogImportDialog.
%
%   Mirrors tests/test_plant_log_import_dialog.m. MATLAB-only (Octave
%   does not run matlab.unittest suites). Programmatically drives the
%   dialog by invoking callbacks directly -- uifigure stays modal but no
%   user interaction is needed.

    properties (Access = private)
        Dialogs = {}
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
        function tearDownDialogs(testCase)
            for k = 1:numel(testCase.Dialogs)
                try
                    delete(testCase.Dialogs{k});
                catch
                end
            end
            testCase.Dialogs = {};
        end
    end

    methods (Test)

        function testConstructorValidAutoMapping(testCase)
            T = testCase.makeIsoTable_();
            am = testCase.makeAutoMapping_('Time', 'Description');
            dlg = PlantLogImportDialog('test.csv', T, am);
            testCase.Dialogs{end+1} = dlg;

            fig = testCase.getPrivate_(dlg, 'hFigure_');
            testCase.verifyTrue(isvalid(fig));
            testCase.verifyEqual(lower(char(fig.WindowStyle)), 'modal');

            confirmBtn = testCase.getPrivate_(dlg, 'hConfirmBtn_');
            testCase.verifyEqual(lower(char(confirmBtn.Enable)), 'on');
        end

        function testConstructorEmptyTimestampColumn(testCase)
            T = testCase.makeUnparseableTable_();
            am = testCase.makeAutoMapping_('', '');
            dlg = PlantLogImportDialog('test.csv', T, am);
            testCase.Dialogs{end+1} = dlg;

            confirmBtn = testCase.getPrivate_(dlg, 'hConfirmBtn_');
            errLabel = testCase.getPrivate_(dlg, 'hErrorLabel_');
            testCase.verifyEqual(lower(char(confirmBtn.Enable)), 'off');
            testCase.verifyEqual(lower(char(errLabel.Visible)), 'on');
            testCase.verifyTrue(~isempty(errLabel.Text));
        end

        function testConstructorInvalidTableThrows(testCase)
            am = testCase.makeAutoMapping_('Time', 'Msg');
            testCase.verifyError(@() PlantLogImportDialog('test.csv', 'not-a-table', am), ...
                'PlantLogImportDialog:invalidInput');
        end

        function testConfirmReturnsMapping(testCase)
            T = testCase.makeIsoTable_();
            am = testCase.makeAutoMapping_('Time', 'Description');
            dlg = PlantLogImportDialog('test.csv', T, am);
            testCase.Dialogs{end+1} = dlg;

            confirmBtn = testCase.getPrivate_(dlg, 'hConfirmBtn_');
            confirmBtn.ButtonPushedFcn([], []);

            final = testCase.getPrivate_(dlg, 'FinalMapping_');
            testCase.verifyClass(final, 'struct');
            testCase.verifyEqual(final.TimestampColumn, 'Time');
            testCase.verifyEqual(final.MessageColumn, 'Description');
        end

        function testCancelReturnsEmpty(testCase)
            T = testCase.makeIsoTable_();
            am = testCase.makeAutoMapping_('Time', 'Description');
            dlg = PlantLogImportDialog('test.csv', T, am);
            testCase.Dialogs{end+1} = dlg;

            cancelBtn = testCase.getPrivate_(dlg, 'hCancelBtn_');
            cancelBtn.ButtonPushedFcn([], []);

            final = testCase.getPrivate_(dlg, 'FinalMapping_');
            testCase.verifyTrue(isempty(final));
        end

        function testCloseRequestBehavesLikeCancel(testCase)
            T = testCase.makeIsoTable_();
            am = testCase.makeAutoMapping_('Time', 'Description');
            dlg = PlantLogImportDialog('test.csv', T, am);
            testCase.Dialogs{end+1} = dlg;

            fig = testCase.getPrivate_(dlg, 'hFigure_');
            fig.CloseRequestFcn([], []);

            final = testCase.getPrivate_(dlg, 'FinalMapping_');
            testCase.verifyTrue(isempty(final));
        end

        function testDropdownChangeRevalidates(testCase)
            T = testCase.makeIsoTable_();
            am = testCase.makeAutoMapping_('Time', 'Description');
            dlg = PlantLogImportDialog('test.csv', T, am);
            testCase.Dialogs{end+1} = dlg;

            tsDD = testCase.getPrivate_(dlg, 'hTsDropdown_');
            confirmBtn = testCase.getPrivate_(dlg, 'hConfirmBtn_');

            tsDD.Value = 'Machine';
            tsDD.ValueChangedFcn([], struct('Value', 'Machine'));
            testCase.verifyEqual(lower(char(confirmBtn.Enable)), 'off');

            tsDD.Value = 'Time';
            tsDD.ValueChangedFcn([], struct('Value', 'Time'));
            testCase.verifyEqual(lower(char(confirmBtn.Enable)), 'on');
        end

        function testExplicitFormatRevalidates(testCase)
            % "20250115" rejected by every ladder format (no separators
            % match); yyyyMMdd hint parses cleanly. See the matching note
            % in tests/test_plant_log_import_dialog.m.
            T = table( ...
                ["20250115"; "20250116"; "20250117"], ...
                ["m1"; "m2"; "m3"], ...
                'VariableNames', {'When', 'What'});
            am = testCase.makeAutoMapping_('', 'What');
            dlg = PlantLogImportDialog('test.csv', T, am);
            testCase.Dialogs{end+1} = dlg;

            tsDD = testCase.getPrivate_(dlg, 'hTsDropdown_');
            fmtEdit = testCase.getPrivate_(dlg, 'hFmtEdit_');
            confirmBtn = testCase.getPrivate_(dlg, 'hConfirmBtn_');

            tsDD.Value = 'When';
            tsDD.ValueChangedFcn([], struct('Value', 'When'));
            testCase.verifyEqual(lower(char(confirmBtn.Enable)), 'off');

            fmtEdit.Value = 'yyyyMMdd';
            fmtEdit.ValueChangedFcn([], struct('Value', 'yyyyMMdd'));
            testCase.verifyEqual(lower(char(confirmBtn.Enable)), 'on');
        end

        function testDeleteCleansUp(testCase)
            T = testCase.makeIsoTable_();
            am = testCase.makeAutoMapping_('Time', 'Description');
            dlg = PlantLogImportDialog('test.csv', T, am);

            fig = testCase.getPrivate_(dlg, 'hFigure_');
            testCase.verifyTrue(isvalid(fig));

            delete(dlg);
            testCase.verifyFalse(isvalid(fig));
        end

    end

    methods (Access = private)

        function T = makeIsoTable_(testCase) %#ok<MANU>
            T = table( ...
                ["2025-01-15 12:00:00"; "2025-01-15 12:05:00"; "2025-01-15 12:10:00"], ...
                ["Pump A on"; "Pump A off"; "Pump B on"], ...
                ["M1"; "M1"; "M2"], ...
                'VariableNames', {'Time', 'Description', 'Machine'});
        end

        function T = makeUnparseableTable_(testCase) %#ok<MANU>
            T = table( ...
                ["apple"; "banana"; "cherry"], ...
                ["red"; "yellow"; "red"], ...
                'VariableNames', {'Fruit', 'Color'});
        end

        function am = makeAutoMapping_(testCase, tsCol, msgCol) %#ok<INUSL>
            am = struct( ...
                'TimestampColumn', tsCol, ...
                'MessageColumn',   msgCol, ...
                'TimestampFormat', '');
        end

        function v = getPrivate_(testCase, obj, name) %#ok<INUSL>
            w = warning('off', 'MATLAB:structOnObject');
            s = struct(obj);
            warning(w);
            v = s.(name);
        end

    end
end
