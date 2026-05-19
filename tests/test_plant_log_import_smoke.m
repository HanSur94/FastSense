function test_plant_log_import_smoke()
%TEST_PLANT_LOG_IMPORT_SMOKE End-to-end smoke for Phase 1030 import pipeline.
%
%   Cross-runtime function-style smoke covering the headless path of
%   PlantLogReader.openInteractive (no uifigure required). The
%   interactive path is exercised by tests/suite/TestPlantLogImportSmoke.m
%   on MATLAB only.
%
%   Contract: this file deliberately omits any manual
%   `addpath(fullfile(..., 'libs', 'PlantLog'))` call. install.m's
%   libs-block edit (Phase 1029 Plan 03) is what puts libs/PlantLog/ on
%   the path; if that ever regresses, the very first which() check
%   fails fast.

    add_paths_via_install_only();

    test_path_pickup_reader();
    test_path_pickup_dialog();

    % Octave gate: every test below exercises PlantLogReader →
    % `readtable` (MATLAB-only). Skip cleanly when unavailable.
    if exist('OCTAVE_VERSION', 'builtin') && isempty(which('readtable'))
        fprintf('SKIPPED rest of suite — readtable unavailable on this Octave.\n');
        return;
    end

    test_headless_end_to_end();
    test_headless_without_mapping_throws();
    test_headless_missing_file_throws();
    test_headless_unsupported_format_throws();
    test_headless_empty_file_returns_empty();
    test_headless_dedup_via_store();

    fprintf('    All 8 plant_log_import_smoke assertions passed.\n');
end

function add_paths_via_install_only()
    % NOTE: deliberately no manual addpath(fullfile(..., 'libs', 'PlantLog')).
    % install.m's libs-block edit (Phase 1029 Plan 03) handles it.
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    install();
end

function test_path_pickup_reader()
    w = which('PlantLogReader');
    assert(~isempty(w), 'path: PlantLogReader on path');
    assert(~isempty(strfind(w, fullfile('libs', 'PlantLog'))), ...
        'path: resolves under libs/PlantLog'); %#ok<STREMP>
    fprintf('  PASS: test_path_pickup_reader\n');
end

function test_path_pickup_dialog()
    w = which('PlantLogImportDialog');
    assert(~isempty(w), 'path: PlantLogImportDialog on path');
    assert(~isempty(strfind(w, fullfile('libs', 'PlantLog'))), ...
        'path: dialog resolves under libs/PlantLog'); %#ok<STREMP>
    fprintf('  PASS: test_path_pickup_dialog\n');
end

function test_headless_end_to_end()
    p = write_csv_({ ...
        {'2025-01-15 12:00:00', 'first',  'M1'}, ...
        {'2025-01-15 12:05:00', 'second', 'M2'}, ...
        {'2025-01-15 12:10:00', 'third',  'M3'}}, ...
        {'Time', 'Msg', 'Machine'});
    cleanup = onCleanup(@() try_delete(p));
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
    entries = PlantLogReader.openInteractive(p, 'Headless', true, 'Mapping', m);
    assert(numel(entries) == 3, 'headless: 3 entries');
    assert(isa(entries, 'PlantLogEntry'), 'headless: PlantLogEntry array');
    store = PlantLogStore(p);
    store.addEntries(entries);
    assert(store.getCount() == 3, 'headless: store has 3 after add');
    fprintf('  PASS: test_headless_end_to_end\n');
    clear cleanup;
end

function test_headless_without_mapping_throws()
    p = write_csv_({{'2025-01-15 12:00:00', 'hi'}}, {'Time', 'Msg'});
    cleanup = onCleanup(@() try_delete(p));
    threw = false;
    try
        PlantLogReader.openInteractive(p, 'Headless', true);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogReader:invalidInput'), 'headless no map: id');
    end
    assert(threw, 'headless without mapping: should throw');
    fprintf('  PASS: test_headless_without_mapping_throws\n');
    clear cleanup;
end

function test_headless_missing_file_throws()
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
    threw = false;
    try
        PlantLogReader.openInteractive('/nonexistent/path/to/nothing.csv', ...
            'Headless', true, 'Mapping', m);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogReader:fileNotFound'), 'missing: id');
    end
    assert(threw, 'missing file: should throw');
    fprintf('  PASS: test_headless_missing_file_throws\n');
end

function test_headless_unsupported_format_throws()
    p = [tempname() '.json'];
    fid = fopen(p, 'w'); fprintf(fid, '{}\n'); fclose(fid);
    cleanup = onCleanup(@() try_delete(p));
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
    threw = false;
    try
        PlantLogReader.openInteractive(p, 'Headless', true, 'Mapping', m);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogReader:unsupportedFormat'), 'unsupported: id');
    end
    assert(threw, 'unsupported format: should throw');
    fprintf('  PASS: test_headless_unsupported_format_throws\n');
    clear cleanup;
end

function test_headless_empty_file_returns_empty()
    p = [tempname() '.csv'];
    fid = fopen(p, 'w'); fprintf(fid, 'Time,Msg\n'); fclose(fid);   % header only
    cleanup = onCleanup(@() try_delete(p));
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
    entries = PlantLogReader.openInteractive(p, 'Headless', true, 'Mapping', m);
    assert(isempty(entries), 'empty file headless: returns []');
    fprintf('  PASS: test_headless_empty_file_returns_empty\n');
    clear cleanup;
end

function test_headless_dedup_via_store()
    p = write_csv_({ ...
        {'2025-01-15 12:00:00', 'first',  'M1'}, ...
        {'2025-01-15 12:05:00', 'second', 'M2'}}, ...
        {'Time', 'Msg', 'Machine'});
    cleanup = onCleanup(@() try_delete(p));
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
    entries = PlantLogReader.openInteractive(p, 'Headless', true, 'Mapping', m);
    store = PlantLogStore(p);
    store.addEntries(entries);
    store.addEntries(entries);  % re-add: dedup must hold
    assert(store.getCount() == numel(entries), 'dedup: re-add stays at 2');
    fprintf('  PASS: test_headless_dedup_via_store\n');
    clear cleanup;
end

function p = write_csv_(rows, headers)
    p = [tempname() '.csv'];
    fid = fopen(p, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', strjoin(headers, ','));
    for r = 1:numel(rows)
        fprintf(fid, '%s\n', strjoin(rows{r}, ','));
    end
    clear cleanup;
end

function try_delete(p)
    try
        if exist(p, 'file') == 2
            delete(p);
        end
    catch
    end
end
