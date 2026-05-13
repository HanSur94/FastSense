function test_plant_log_store()
%TEST_PLANT_LOG_STORE Function-style coverage of PlantLogStore (MATLAB + Octave).
%   Mirrors tests/suite/TestPlantLogStore.m. Both suites cover constructor,
%   addEntries (class array, struct array, empty, type mismatch, missing
%   timestamp), dedup (identical readd, same-ts different-content),
%   getEntriesInRange (basic, boundary, empty store, no match, invalid
%   args), getCount, mergeEntries (success, type mismatch), clear (count
%   reset + id reset), static computeEntryHash, and independence from
%   EventStore (PLOG-ST-01).

    add_plant_log_path();

    test_constructor_default();
    test_constructor_invalid_input();
    test_constructor_unknown_option();
    test_add_entries_class_array();
    test_add_entries_struct_array();
    test_add_entries_empty();
    test_add_entries_type_mismatch();
    test_add_entries_missing_timestamp();
    test_dedup_identical_readd();
    test_dedup_same_timestamp_different_content();
    test_get_entries_in_range_basic();
    test_get_entries_in_range_boundary();
    test_get_entries_in_range_empty_store();
    test_get_entries_in_range_no_match();
    test_get_entries_in_range_invalid();
    test_get_count();
    test_merge_entries();
    test_merge_entries_type_mismatch();
    test_clear();
    test_compute_entry_hash_static();
    test_independence_from_event_store();

    fprintf('    All 21 plant_log_store tests passed.\n');
end

function add_plant_log_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    install();
    addpath(fullfile(repo_root, 'libs', 'PlantLog'));   % until Plan 03 wires install.m
end

function test_constructor_default()
    s = PlantLogStore('plant.csv');
    assert(strcmp(s.SourceFile, 'plant.csv'), 'constructor: SourceFile stored');
    assert(s.getCount() == 0, 'constructor: empty store has count 0');
    fprintf('  PASS: test_constructor_default\n');
end

function test_constructor_invalid_input()
    threw = false;
    try
        PlantLogStore(42);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogStore:invalidInput'), 'ctor: bad id');
    end
    assert(threw, 'ctor: numeric sourceFile should throw');
    fprintf('  PASS: test_constructor_invalid_input\n');
end

function test_constructor_unknown_option()
    threw = false;
    try
        PlantLogStore('plant.csv', 'Bogus', 5);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogStore:unknownOption'), 'ctor: bad opt id');
    end
    assert(threw, 'ctor: unknown option should throw');
    fprintf('  PASS: test_constructor_unknown_option\n');
end

function test_add_entries_class_array()
    s = PlantLogStore('x.csv');
    e1 = PlantLogEntry('Timestamp', 10, 'Message', 'a', 'Metadata', struct());
    e2 = PlantLogEntry('Timestamp', 20, 'Message', 'b', 'Metadata', struct());
    e3 = PlantLogEntry('Timestamp', 15, 'Message', 'c', 'Metadata', struct());
    s.addEntries([e1, e2, e3]);
    assert(s.getCount() == 3, 'add class arr: count');
    all_entries = s.getEntries();
    % Sorted ascending by Timestamp
    assert(all_entries(1).Timestamp == 10, 'sorted: first by ts');
    assert(all_entries(2).Timestamp == 15, 'sorted: middle by ts');
    assert(all_entries(3).Timestamp == 20, 'sorted: last by ts');
    % Ids assigned in input order, NOT sort order
    assert(strcmp(all_entries(1).Id, 'plog_1'), 'id: ts=10 was e1 -> plog_1');
    assert(strcmp(all_entries(2).Id, 'plog_3'), 'id: ts=15 was e3 -> plog_3');
    assert(strcmp(all_entries(3).Id, 'plog_2'), 'id: ts=20 was e2 -> plog_2');
    fprintf('  PASS: test_add_entries_class_array\n');
end

function test_add_entries_struct_array()
    s = PlantLogStore('x.csv');
    ss(1) = struct('Timestamp', 1, 'Message', 'a', 'Metadata', struct('K','v'), 'SourceFile', 'x.csv', 'Id', '', 'RowHash', '');
    ss(2) = struct('Timestamp', 2, 'Message', 'b', 'Metadata', struct('K','w'), 'SourceFile', 'x.csv', 'Id', '', 'RowHash', '');
    s.addEntries(ss);
    assert(s.getCount() == 2, 'struct add: count');
    all_entries = s.getEntries();
    assert(strcmp(all_entries(1).Message, 'a'), 'struct add: Message preserved');
    assert(strcmp(all_entries(1).Id, 'plog_1'), 'struct add: id 1');
    assert(strcmp(all_entries(2).Id, 'plog_2'), 'struct add: id 2');
    assert(numel(all_entries(1).RowHash) == 16, 'struct add: RowHash auto-computed');
    fprintf('  PASS: test_add_entries_struct_array\n');
end

function test_add_entries_empty()
    s = PlantLogStore('x.csv');
    s.addEntries([]);
    assert(s.getCount() == 0, 'empty add: count unchanged');
    % Then a real add should still start at plog_1
    e = PlantLogEntry('Timestamp', 1, 'Message', 'a', 'Metadata', struct());
    s.addEntries(e);
    assert(strcmp(s.getEntries().Id, 'plog_1'), 'empty add: id counter not advanced by [] add');
    fprintf('  PASS: test_add_entries_empty\n');
end

function test_add_entries_type_mismatch()
    s = PlantLogStore('x.csv');
    threw = false;
    try
        s.addEntries('not-an-array');
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogStore:typeMismatch'), 'type mismatch id');
    end
    assert(threw, 'string addEntries should throw');
    fprintf('  PASS: test_add_entries_type_mismatch\n');
end

function test_add_entries_missing_timestamp()
    s = PlantLogStore('x.csv');
    bad = struct('Message', 'no ts');
    threw = false;
    try
        s.addEntries(bad);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogStore:emptyEntry'), 'empty entry id');
    end
    assert(threw, 'missing-ts struct should throw');
    fprintf('  PASS: test_add_entries_missing_timestamp\n');
end

function test_dedup_identical_readd()
    s = PlantLogStore('x.csv');
    e1 = PlantLogEntry('Timestamp', 1, 'Message', 'a', 'Metadata', struct('K','v'));
    e2 = PlantLogEntry('Timestamp', 2, 'Message', 'b', 'Metadata', struct('K','w'));
    e3 = PlantLogEntry('Timestamp', 3, 'Message', 'c', 'Metadata', struct('K','x'));
    arr = [e1, e2, e3];
    s.addEntries(arr);
    s.addEntries(arr);   % readd — must be silent no-op
    assert(s.getCount() == 3, 'dedup: count stable after readd');
    all_entries = s.getEntries();
    assert(strcmp(all_entries(end).Id, 'plog_3'), 'dedup: no new ids consumed by readd');
    fprintf('  PASS: test_dedup_identical_readd\n');
end

function test_dedup_same_timestamp_different_content()
    s = PlantLogStore('x.csv');
    e1 = PlantLogEntry('Timestamp', 5, 'Message', 'a', 'Metadata', struct());
    e2 = PlantLogEntry('Timestamp', 5, 'Message', 'b', 'Metadata', struct());  % different content -> different hash
    s.addEntries([e1, e2]);
    assert(s.getCount() == 2, 'same-ts diff-content: both stored');
    fprintf('  PASS: test_dedup_same_timestamp_different_content\n');
end

function test_get_entries_in_range_basic()
    s = PlantLogStore('x.csv');
    ts = [1, 5, 10, 15, 20];
    for k = 1:numel(ts)
        s.addEntries(PlantLogEntry('Timestamp', ts(k), 'Message', sprintf('e%d', k), 'Metadata', struct()));
    end
    out = s.getEntriesInRange(5, 15);
    assert(numel(out) == 3, 'range basic: 3 entries in [5,15]');
    assert(out(1).Timestamp == 5,  'range basic: first ts 5');
    assert(out(end).Timestamp == 15, 'range basic: last ts 15');
    fprintf('  PASS: test_get_entries_in_range_basic\n');
end

function test_get_entries_in_range_boundary()
    s = PlantLogStore('x.csv');
    s.addEntries(PlantLogEntry('Timestamp', 10, 'Message', 'a', 'Metadata', struct()));
    out_in  = s.getEntriesInRange(10, 10);
    assert(isscalar(out_in), 'boundary: single-point range includes the entry');
    out_in2 = s.getEntriesInRange(10, 20);
    assert(isscalar(out_in2), 'boundary: t0=entry is inclusive');
    out_in3 = s.getEntriesInRange(0, 10);
    assert(isscalar(out_in3), 'boundary: t1=entry is inclusive');
    fprintf('  PASS: test_get_entries_in_range_boundary\n');
end

function test_get_entries_in_range_empty_store()
    s = PlantLogStore('x.csv');
    out = s.getEntriesInRange(0, 100);
    assert(isempty(out), 'range empty store: returns empty');
    fprintf('  PASS: test_get_entries_in_range_empty_store\n');
end

function test_get_entries_in_range_no_match()
    s = PlantLogStore('x.csv');
    for k = 1:5
        s.addEntries(PlantLogEntry('Timestamp', k, 'Message', 'a', 'Metadata', struct('K', k)));
    end
    out = s.getEntriesInRange(100, 200);
    assert(isempty(out), 'range no match: returns empty');
    fprintf('  PASS: test_get_entries_in_range_no_match\n');
end

function test_get_entries_in_range_invalid()
    s = PlantLogStore('x.csv');
    threw = false;
    try
        s.getEntriesInRange(10, 5);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogStore:invalidInput'), 't0>t1 id');
    end
    assert(threw, 't0>t1 should throw');
    threw = false;
    try
        s.getEntriesInRange('a', 5);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogStore:invalidInput'), 'non-numeric id');
    end
    assert(threw, 'non-numeric should throw');
    fprintf('  PASS: test_get_entries_in_range_invalid\n');
end

function test_get_count()
    s = PlantLogStore('x.csv');
    assert(s.getCount() == 0, 'count: 0 empty');
    s.addEntries(PlantLogEntry('Timestamp', 1, 'Message', 'a', 'Metadata', struct()));
    assert(s.getCount() == 1, 'count: 1 after one add');
    s.addEntries(PlantLogEntry('Timestamp', 2, 'Message', 'b', 'Metadata', struct()));
    assert(s.getCount() == 2, 'count: 2 after two unique adds');
    fprintf('  PASS: test_get_count\n');
end

function test_merge_entries()
    a = PlantLogStore('a.csv');
    b = PlantLogStore('b.csv');
    e1 = PlantLogEntry('Timestamp', 1, 'Message', 'common', 'Metadata', struct());
    e2 = PlantLogEntry('Timestamp', 2, 'Message', 'a-only', 'Metadata', struct());
    e3 = PlantLogEntry('Timestamp', 3, 'Message', 'b-only-1', 'Metadata', struct());
    e4 = PlantLogEntry('Timestamp', 4, 'Message', 'b-only-2', 'Metadata', struct());
    a.addEntries([e1, e2]);              % a: 2 entries
    b.addEntries([e1, e3, e4]);          % b: 3 entries, one dupes a's e1
    a.mergeEntries(b);                   % a now: e1 (kept), e2, e3, e4 = 4 entries
    assert(a.getCount() == 4, 'merge: dedup of overlapping entry');
    fprintf('  PASS: test_merge_entries\n');
end

function test_merge_entries_type_mismatch()
    a = PlantLogStore('a.csv');
    threw = false;
    try
        a.mergeEntries('not-a-store');
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogStore:typeMismatch'), 'merge type id');
    end
    assert(threw, 'merge non-store should throw');
    fprintf('  PASS: test_merge_entries_type_mismatch\n');
end

function test_clear()
    s = PlantLogStore('x.csv');
    s.addEntries(PlantLogEntry('Timestamp', 1, 'Message', 'a', 'Metadata', struct()));
    s.addEntries(PlantLogEntry('Timestamp', 2, 'Message', 'b', 'Metadata', struct()));
    s.clear();
    assert(s.getCount() == 0, 'clear: count 0');
    % Counter reset
    s.addEntries(PlantLogEntry('Timestamp', 5, 'Message', 'c', 'Metadata', struct()));
    assert(strcmp(s.getEntries().Id, 'plog_1'), 'clear: id counter reset');
    fprintf('  PASS: test_clear\n');
end

function test_compute_entry_hash_static()
    h1 = PlantLogStore.computeEntryHash('foo', struct('A', 1));
    h2 = PlantLogStore.computeEntryHash('foo', struct('A', 1));
    h3 = PlantLogStore.computeEntryHash('foo', struct('A', 2));
    assert(strcmp(h1, h2), 'static hash: determinism');
    assert(~strcmp(h1, h3), 'static hash: sensitivity');
    assert(numel(h1) == 16, 'static hash: 16 chars');
    assert(~isempty(regexp(h1, '^[0-9a-f]{16}$', 'once')), 'static hash: lowercase hex');
    fprintf('  PASS: test_compute_entry_hash_static\n');
end

function test_independence_from_event_store()
    ps = PlantLogStore('x.csv');
    es = EventStore(tempname);   % does NOT save (no .save() call)
    ps.addEntries(PlantLogEntry('Timestamp', 1, 'Message', 'plant-log entry', 'Metadata', struct()));
    ps.addEntries(PlantLogEntry('Timestamp', 2, 'Message', 'another plant entry', 'Metadata', struct()));
    % Independence: EventStore must be empty
    assert(isempty(es.getEvents()) || numel(es.getEvents()) == 0, ...
        'independence: EventStore unaffected by PlantLogStore operations');
    % PlantLogStore was populated correctly
    assert(ps.getCount() == 2, 'independence: PlantLogStore populated independently');
    fprintf('  PASS: test_independence_from_event_store\n');
end
