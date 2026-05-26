function test_plant_log_reader()
%TEST_PLANT_LOG_READER Function-style coverage for PlantLogReader (MATLAB + Octave).
%   Mirrors tests/suite/TestPlantLogReader.m. Covers autoDetect on ISO,
%   EU, US, and no-timestamp tables; readFile happy path + error paths;
%   integration with PlantLogStore.addEntries. XLSX path is gated and
%   skipped cleanly on Octave runtimes that lack JVM/xlsread.

    add_plant_log_path();

    % Octave gate: every test below uses `readtable` (MATLAB-only;
    % Octave needs the `io` package). Skip cleanly when unavailable.
    if exist('OCTAVE_VERSION', 'builtin') && isempty(which('readtable'))
        fprintf('SKIPPED — readtable unavailable on this Octave (install `io` package to enable).\n');
        return;
    end

    test_auto_detect_iso();
    test_auto_detect_eu();
    test_auto_detect_us();
    test_auto_detect_no_timestamp_column();
    test_auto_detect_picks_message_column();
    test_read_file_basic();
    test_read_file_empty();
    test_read_file_unknown_timestamp_column();
    test_read_file_unknown_message_column();
    test_read_file_not_found();
    test_read_file_unsupported_format();
    test_read_file_explicit_format_hint();
    test_read_file_sets_source_file();
    test_read_file_metadata_sanitized();
    test_read_file_flows_into_store();

    fprintf('    All 15 plant_log_reader tests passed.\n');
end

function add_plant_log_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    install();
    % install.m wires libs/PlantLog/ since Phase 1029 Plan 03
end

function p = write_csv_(rows, headers)
%WRITE_CSV_ Write a CSV to a tempfile, return its path.
%   rows is a cell-of-cells: each inner cell is one row.
    p = [tempname() '.csv'];
    fid = fopen(p, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', strjoin(headers, ','));
    for r = 1:numel(rows)
        fprintf(fid, '%s\n', strjoin(rows{r}, ','));
    end
end

function test_auto_detect_iso()
    p = write_csv_({ ...
        {'2025-01-15 12:00:00', 'Pump A on', 'M1'}, ...
        {'2025-01-15 12:05:00', 'Pump A off', 'M1'}, ...
        {'2025-01-15 12:10:00', 'Pump B on', 'M2'}}, ...
        {'Time', 'Description', 'Machine'});
    cleanup = onCleanup(@() try_delete(p));
    T = readtable(p);
    m = PlantLogReader.autoDetect(T);
    assert(strcmp(m.TimestampColumn, 'Time'), 'autoDetect ISO: Time column');
    assert(strcmp(m.TimestampFormat, ''), 'autoDetect ISO: format empty');
    fprintf('  PASS: test_auto_detect_iso\n');
end

function test_auto_detect_eu()
    p = write_csv_({ ...
        {'15.01.2025 12:00:00', 'msg1'}, ...
        {'15.01.2025 12:05:00', 'msg2'}, ...
        {'15.01.2025 12:10:00', 'msg3'}}, ...
        {'Zeit', 'Text'});
    cleanup = onCleanup(@() try_delete(p));
    T = readtable(p);
    m = PlantLogReader.autoDetect(T);
    assert(strcmp(m.TimestampColumn, 'Zeit'), 'autoDetect EU: Zeit column');
    fprintf('  PASS: test_auto_detect_eu\n');
end

function test_auto_detect_us()
    p = write_csv_({ ...
        {'01/15/2025', 'first msg'}, ...
        {'01/16/2025', 'second msg'}, ...
        {'01/17/2025', 'third msg'}}, ...
        {'Date', 'Note'});
    cleanup = onCleanup(@() try_delete(p));
    T = readtable(p);
    m = PlantLogReader.autoDetect(T);
    assert(strcmp(m.TimestampColumn, 'Date'), 'autoDetect US: Date column');
    fprintf('  PASS: test_auto_detect_us\n');
end

function test_auto_detect_no_timestamp_column()
    p = write_csv_({ ...
        {'apple',  'red',   '10'}, ...
        {'banana', 'yellow', '20'}, ...
        {'cherry', 'red',   '30'}}, ...
        {'Fruit', 'Color', 'Count'});
    cleanup = onCleanup(@() try_delete(p));
    T = readtable(p);
    m = PlantLogReader.autoDetect(T);
    assert(strcmp(m.TimestampColumn, ''), 'autoDetect none: TimestampColumn empty');
    fprintf('  PASS: test_auto_detect_no_timestamp_column\n');
end

function test_auto_detect_picks_message_column()
    p = write_csv_({ ...
        {'2025-01-15 12:00:00', 'M1', 'Pump A started'}, ...
        {'2025-01-15 12:05:00', 'M1', 'Pump A stopped'}, ...
        {'2025-01-15 12:10:00', 'M2', 'Pump B started'}}, ...
        {'Time', 'Machine', 'Description'});
    cleanup = onCleanup(@() try_delete(p));
    T = readtable(p);
    m = PlantLogReader.autoDetect(T);
    assert(strcmp(m.TimestampColumn, 'Time'), 'autoDetect msg: ts is Time');
    assert(strcmp(m.MessageColumn, 'Machine') || strcmp(m.MessageColumn, 'Description'), ...
        'autoDetect msg: picks a non-ts text column');
    fprintf('  PASS: test_auto_detect_picks_message_column\n');
end

function test_read_file_basic()
    p = write_csv_({ ...
        {'2025-01-15 12:00:00', 'Pump A on', 'M1'}, ...
        {'2025-01-15 12:05:00', 'Pump A off', 'M1'}, ...
        {'2025-01-15 12:10:00', 'Pump B on', 'M2'}}, ...
        {'Time', 'Description', 'Machine'});
    cleanup = onCleanup(@() try_delete(p));
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Description', 'TimestampFormat', '');
    entries = PlantLogReader.readFile(p, m);
    assert(numel(entries) == 3, 'readFile basic: 3 entries');
    assert(isa(entries, 'PlantLogEntry'), 'readFile basic: PlantLogEntry array');
    assert(strcmp(entries(1).Message, 'Pump A on'), 'readFile basic: first message');
    assert(isfield(entries(1).Metadata, 'Machine'), 'readFile basic: Machine metadata field');
    assert(strcmp(entries(1).Metadata.Machine, 'M1'), 'readFile basic: machine value');
    assert(entries(1).Timestamp < entries(2).Timestamp, 'readFile basic: timestamps ascending');
    fprintf('  PASS: test_read_file_basic\n');
end

function test_read_file_empty()
    p = [tempname() '.csv'];
    fid = fopen(p, 'w');
    fprintf(fid, 'Time,Msg\n');  % header only, no rows
    fclose(fid);
    cleanup = onCleanup(@() try_delete(p));
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
    entries = PlantLogReader.readFile(p, m);
    assert(isempty(entries), 'readFile empty: returns []');
    fprintf('  PASS: test_read_file_empty\n');
end

function test_read_file_unknown_timestamp_column()
    p = write_csv_({{'2025-01-15 12:00:00', 'hi'}}, {'Time', 'Msg'});
    cleanup = onCleanup(@() try_delete(p));
    m = struct('TimestampColumn', 'NoSuchColumn', 'MessageColumn', 'Msg', 'TimestampFormat', '');
    threw = false;
    try
        PlantLogReader.readFile(p, m);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogReader:unknownColumn'), 'unknown ts col: id');
    end
    assert(threw, 'unknown ts col: should throw');
    fprintf('  PASS: test_read_file_unknown_timestamp_column\n');
end

function test_read_file_unknown_message_column()
    p = write_csv_({{'2025-01-15 12:00:00', 'hi'}}, {'Time', 'Msg'});
    cleanup = onCleanup(@() try_delete(p));
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'NoSuchColumn', 'TimestampFormat', '');
    threw = false;
    try
        PlantLogReader.readFile(p, m);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogReader:unknownColumn'), 'unknown msg col: id');
    end
    assert(threw, 'unknown msg col: should throw');
    fprintf('  PASS: test_read_file_unknown_message_column\n');
end

function test_read_file_not_found()
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
    threw = false;
    try
        PlantLogReader.readFile('/nonexistent/path/to/nothing.csv', m);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogReader:fileNotFound'), 'not found: id');
    end
    assert(threw, 'not found: should throw');
    fprintf('  PASS: test_read_file_not_found\n');
end

function test_read_file_unsupported_format()
    p = [tempname() '.json'];
    fid = fopen(p, 'w'); fprintf(fid, '{}\n'); fclose(fid);
    cleanup = onCleanup(@() try_delete(p));
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
    threw = false;
    try
        PlantLogReader.readFile(p, m);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogReader:unsupportedFormat'), 'unsupported: id');
    end
    assert(threw, 'unsupported format: should throw');
    fprintf('  PASS: test_read_file_unsupported_format\n');
end

function test_read_file_explicit_format_hint()
    % 'yyyy/MM/dd' is NOT in the ladder; only succeeds with the hint.
    % Quote the timestamp values so readtable preserves them as strings
    % (unquoted '2025/01/15' would be auto-parsed as numeric '2025/1/15').
    p = write_csv_({ ...
        {'"2025/01/15"', 'msg1'}, ...
        {'"2025/01/16"', 'msg2'}}, ...
        {'When', 'What'});
    cleanup = onCleanup(@() try_delete(p));
    m = struct('TimestampColumn', 'When', 'MessageColumn', 'What', 'TimestampFormat', 'yyyy/MM/dd');
    entries = PlantLogReader.readFile(p, m);
    assert(numel(entries) == 2, 'format hint: 2 entries parsed');
    assert(isfinite(entries(1).Timestamp), 'format hint: ts finite');
    fprintf('  PASS: test_read_file_explicit_format_hint\n');
end

function test_read_file_sets_source_file()
    p = write_csv_({{'2025-01-15 12:00:00', 'hi'}}, {'Time', 'Msg'});
    cleanup = onCleanup(@() try_delete(p));
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
    entries = PlantLogReader.readFile(p, m);
    assert(strcmp(entries(1).SourceFile, p), 'SourceFile: set to file path');
    fprintf('  PASS: test_read_file_sets_source_file\n');
end

function test_read_file_metadata_sanitized()
    p = write_csv_({{'2025-01-15 12:00:00', 'hi', 'M1'}}, {'Time', 'Msg', 'Machine ID'});
    cleanup = onCleanup(@() try_delete(p));
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
    entries = PlantLogReader.readFile(p, m);
    fn = fieldnames(entries(1).Metadata);
    % readtable may auto-sanitize column names too; both sanitized variants must contain MachineID
    sanitized = any(strcmp(fn, 'MachineID')) || any(strcmp(fn, 'Machine_ID'));
    assert(sanitized, 'metadata: sanitized field name present');
    fprintf('  PASS: test_read_file_metadata_sanitized\n');
end

function test_read_file_flows_into_store()
    p = write_csv_({ ...
        {'2025-01-15 12:00:00', 'first',  'M1'}, ...
        {'2025-01-15 12:05:00', 'second', 'M1'}, ...
        {'2025-01-15 12:10:00', 'third',  'M2'}}, ...
        {'Time', 'Msg', 'Machine'});
    cleanup = onCleanup(@() try_delete(p));
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Msg', 'TimestampFormat', '');
    entries = PlantLogReader.readFile(p, m);
    store = PlantLogStore(p);
    store.addEntries(entries);
    assert(store.getCount() == numel(entries), 'store: all entries accepted');
    fprintf('  PASS: test_read_file_flows_into_store\n');
end

function try_delete(p)
    try
        if exist(p, 'file') == 2
            delete(p);
        end
    catch
    end
end
