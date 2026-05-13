function test_plant_log_import_dialog()
%TEST_PLANT_LOG_IMPORT_DIALOG Function-style tests for PlantLogImportDialog.
%   MATLAB-only -- Octave's uifigure support varies by version, and the
%   dialog uses MATLAB R2020b+ idioms. On Octave this test skips cleanly
%   with an informational print.
%
%   Tests programmatically drive the dialog by invoking ButtonPushedFcn /
%   ValueChangedFcn callbacks directly -- no actual user click simulation.

    add_plant_log_path();

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP plant_log_import_dialog tests (Octave -- MATLAB-only).\n');
        return;
    end
    if ~uifigureAvailable_()
        fprintf('    SKIP plant_log_import_dialog tests (uifigure unavailable).\n');
        return;
    end

    test_constructor_valid_auto_mapping();
    test_constructor_empty_timestamp_column();
    test_constructor_invalid_raw_table_throws();
    test_confirm_returns_current_mapping();
    test_cancel_returns_empty();
    test_close_request_behaves_like_cancel();
    test_dropdown_change_revalidates();
    test_explicit_format_revalidates();
    test_delete_cleans_up_figure();

    fprintf('    All 9 plant_log_import_dialog tests passed.\n');
end

function add_plant_log_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    install();
end

function tf = uifigureAvailable_()
    tf = exist('uifigure', 'file') == 2 || exist('uifigure', 'builtin') == 5;
end

function T = make_iso_table_()
    T = table( ...
        ["2025-01-15 12:00:00"; "2025-01-15 12:05:00"; "2025-01-15 12:10:00"], ...
        ["Pump A on"; "Pump A off"; "Pump B on"], ...
        ["M1"; "M1"; "M2"], ...
        'VariableNames', {'Time', 'Description', 'Machine'});
end

function T = make_unparseable_ts_table_()
    T = table( ...
        ["apple"; "banana"; "cherry"], ...
        ["red"; "yellow"; "red"], ...
        'VariableNames', {'Fruit', 'Color'});
end

function autoMap = make_auto_mapping_(tsCol, msgCol)
    autoMap = struct( ...
        'TimestampColumn', tsCol, ...
        'MessageColumn',   msgCol, ...
        'TimestampFormat', '');
end

function test_constructor_valid_auto_mapping()
    T = make_iso_table_();
    am = make_auto_mapping_('Time', 'Description');
    dlg = PlantLogImportDialog('test.csv', T, am);
    cleanup = onCleanup(@() try_delete_(dlg));

    fig = getPrivate_(dlg, 'hFigure_');
    assert(~isempty(fig) && isvalid(fig), 'ctor: figure created');
    assert(strcmpi(fig.WindowStyle, 'modal'), 'ctor: modal style');

    tsDD = getPrivate_(dlg, 'hTsDropdown_');
    msgDD = getPrivate_(dlg, 'hMsgDropdown_');
    confirmBtn = getPrivate_(dlg, 'hConfirmBtn_');

    assert(strcmp(tsDD.Value, 'Time'), 'ctor: ts dropdown pre-selected');
    assert(strcmp(msgDD.Value, 'Description'), 'ctor: msg dropdown pre-selected');
    assert(strcmpi(confirmBtn.Enable, 'on'), 'ctor: confirm enabled');
    fprintf('  PASS: test_constructor_valid_auto_mapping\n');
    clear cleanup;
end

function test_constructor_empty_timestamp_column()
    T = make_unparseable_ts_table_();
    am = make_auto_mapping_('', '');   % auto-detect failed
    dlg = PlantLogImportDialog('test.csv', T, am);
    cleanup = onCleanup(@() try_delete_(dlg));

    confirmBtn = getPrivate_(dlg, 'hConfirmBtn_');
    errLabel = getPrivate_(dlg, 'hErrorLabel_');

    assert(strcmpi(confirmBtn.Enable, 'off'), 'empty mapping: confirm disabled');
    assert(strcmpi(errLabel.Visible, 'on'), 'empty mapping: error label visible');
    assert(~isempty(errLabel.Text), 'empty mapping: error text non-empty');
    fprintf('  PASS: test_constructor_empty_timestamp_column\n');
    clear cleanup;
end

function test_constructor_invalid_raw_table_throws()
    am = make_auto_mapping_('Time', 'Msg');
    threw = false;
    try
        PlantLogImportDialog('test.csv', 'not-a-table', am);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogImportDialog:invalidInput'), 'invalid: id');
    end
    assert(threw, 'invalid table: should throw');
    fprintf('  PASS: test_constructor_invalid_raw_table_throws\n');
end

function test_confirm_returns_current_mapping()
    T = make_iso_table_();
    am = make_auto_mapping_('Time', 'Description');
    dlg = PlantLogImportDialog('test.csv', T, am);
    cleanup = onCleanup(@() try_delete_(dlg));

    % Invoke Confirm callback directly
    confirmBtn = getPrivate_(dlg, 'hConfirmBtn_');
    confirmBtn.ButtonPushedFcn([], []);

    final = getPrivate_(dlg, 'FinalMapping_');
    assert(isstruct(final), 'confirm: returned struct');
    assert(strcmp(final.TimestampColumn, 'Time'), 'confirm: ts col');
    assert(strcmp(final.MessageColumn, 'Description'), 'confirm: msg col');
    assert(strcmp(final.TimestampFormat, ''), 'confirm: format empty');
    fprintf('  PASS: test_confirm_returns_current_mapping\n');
    clear cleanup;
end

function test_cancel_returns_empty()
    T = make_iso_table_();
    am = make_auto_mapping_('Time', 'Description');
    dlg = PlantLogImportDialog('test.csv', T, am);
    cleanup = onCleanup(@() try_delete_(dlg));

    cancelBtn = getPrivate_(dlg, 'hCancelBtn_');
    cancelBtn.ButtonPushedFcn([], []);

    final = getPrivate_(dlg, 'FinalMapping_');
    assert(isempty(final), 'cancel: empty result');
    fprintf('  PASS: test_cancel_returns_empty\n');
    clear cleanup;
end

function test_close_request_behaves_like_cancel()
    T = make_iso_table_();
    am = make_auto_mapping_('Time', 'Description');
    dlg = PlantLogImportDialog('test.csv', T, am);
    cleanup = onCleanup(@() try_delete_(dlg));

    fig = getPrivate_(dlg, 'hFigure_');
    fig.CloseRequestFcn([], []);

    final = getPrivate_(dlg, 'FinalMapping_');
    assert(isempty(final), 'close: empty result like cancel');
    fprintf('  PASS: test_close_request_behaves_like_cancel\n');
    clear cleanup;
end

function test_dropdown_change_revalidates()
    T = make_iso_table_();
    am = make_auto_mapping_('Time', 'Description');
    dlg = PlantLogImportDialog('test.csv', T, am);
    cleanup = onCleanup(@() try_delete_(dlg));

    tsDD = getPrivate_(dlg, 'hTsDropdown_');
    confirmBtn = getPrivate_(dlg, 'hConfirmBtn_');

    % Change to Machine column (text, won't parse) -- Confirm must disable
    tsDD.Value = 'Machine';
    tsDD.ValueChangedFcn([], struct('Value', 'Machine'));

    assert(strcmpi(confirmBtn.Enable, 'off'), 'unparseable col: confirm disabled');

    % Change back to Time -- Confirm must re-enable
    tsDD.Value = 'Time';
    tsDD.ValueChangedFcn([], struct('Value', 'Time'));

    assert(strcmpi(confirmBtn.Enable, 'on'), 'parseable col: confirm enabled');
    fprintf('  PASS: test_dropdown_change_revalidates\n');
    clear cleanup;
end

function test_explicit_format_revalidates()
    % Table with a column that needs an explicit format hint to parse.
    % "20250115" is rejected by all 7 ladder formats AND by the numeric
    % branch (string array, not numeric, so the > 1e5 datenum-sanity gate
    % isn't reached). The yyyyMMdd explicit hint parses it cleanly.
    T = table( ...
        ["20250115"; "20250116"; "20250117"], ...
        ["msg1"; "msg2"; "msg3"], ...
        'VariableNames', {'When', 'What'});
    am = make_auto_mapping_('', 'What');   % no ts auto-detected
    dlg = PlantLogImportDialog('test.csv', T, am);
    cleanup = onCleanup(@() try_delete_(dlg));

    confirmBtn = getPrivate_(dlg, 'hConfirmBtn_');
    tsDD = getPrivate_(dlg, 'hTsDropdown_');
    fmtEdit = getPrivate_(dlg, 'hFmtEdit_');

    % Pre-select the When column (dialog defaulted to varNames{1} = 'When')
    tsDD.Value = 'When';
    tsDD.ValueChangedFcn([], struct('Value', 'When'));
    assert(strcmpi(confirmBtn.Enable, 'off'), 'no-hint: confirm disabled');

    % Supply the explicit format
    fmtEdit.Value = 'yyyyMMdd';
    fmtEdit.ValueChangedFcn([], struct('Value', 'yyyyMMdd'));
    assert(strcmpi(confirmBtn.Enable, 'on'), 'with-hint: confirm enabled');
    fprintf('  PASS: test_explicit_format_revalidates\n');
    clear cleanup;
end

function test_delete_cleans_up_figure()
    T = make_iso_table_();
    am = make_auto_mapping_('Time', 'Description');
    dlg = PlantLogImportDialog('test.csv', T, am);

    fig = getPrivate_(dlg, 'hFigure_');
    assert(isvalid(fig), 'pre-delete: figure valid');

    delete(dlg);
    assert(~isvalid(fig), 'post-delete: figure destroyed');
    fprintf('  PASS: test_delete_cleans_up_figure\n');
end

function v = getPrivate_(obj, name)
%GETPRIVATE_ Read a private property by reaching through metaclass.
%   PlantLogImportDialog deliberately keeps UI handles private -- for
%   testing we use struct(obj) (silencing MATLAB:structOnObject).
    w = warning('off', 'MATLAB:structOnObject');
    cleanupW = onCleanup(@() warning(w));
    s = struct(obj);
    if isfield(s, name)
        v = s.(name);
    else
        v = [];
    end
    clear cleanupW;
end

function try_delete_(h)
%TRY_DELETE_ Best-effort delete used in onCleanup.
%   Anonymous functions cannot wrap try/catch, so wrap it in a named
%   helper. Mirrors the try_delete pattern in tests/test_plant_log_reader.m
%   (Plan 1030-01).
    try
        if isvalid(h)
            delete(h);
        end
    catch
    end
end
