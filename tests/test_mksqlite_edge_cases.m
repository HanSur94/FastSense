function test_mksqlite_edge_cases()
%TEST_MKSQLITE_EDGE_CASES Edge-case tests for mksqlite typed BLOB round-trips.
%   Covers: empty arrays, special float values, single-element arrays,
%   empty strings, large arrays, empty cells, struct edge cases, and
%   multi-row matrices.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();

    if ~(exist('mksqlite', 'file') == 3)
        fprintf('    SKIPPED: mksqlite MEX not available.\n');
        return;
    end

    fprintf('  --- mksqlite edge cases ---\n');

    dbPath = [tempname, '.db'];
    db = mksqlite('open', dbPath);
    mksqlite(db, 'typedBLOBs', 2);
    mksqlite(db, 'CREATE TABLE t (id INTEGER PRIMARY KEY, data BLOB)');
    nextId = 1;

    % Helper to insert and retrieve
    function out = roundtrip(val)
        mksqlite(db, 'INSERT INTO t VALUES (?, ?)', nextId, val);
        res = mksqlite(db, 'SELECT data FROM t WHERE id=?', nextId);
        out = res.data;
        nextId = nextId + 1;
    end

    % 1. Empty double array
    v = double([]);
    out = roundtrip(v);
    assert(isempty(out), 'emptyDouble: should be empty');
    assert(isa(out, 'double'), 'emptyDouble: class preserved');
    fprintf('    empty double array: PASS\n');

    % 2. Empty single array
    v = single([]);
    out = roundtrip(v);
    assert(isempty(out), 'emptySingle: should be empty');
    fprintf('    empty single array: PASS\n');

    % 3. Scalar double
    out = roundtrip(42.5);
    assert(out == 42.5, 'scalarDouble: value');
    fprintf('    scalar double: PASS\n');

    % 4. Scalar int32 — mksqlite binds scalars as native SQLite types,
    %    so int32 round-trips as double. Test value, not class.
    out = roundtrip(int32(7));
    assert(out == 7, 'scalarInt32: value');
    fprintf('    scalar int32: PASS\n');

    % 5. Inf and -Inf in double array
    v = [1, Inf, -Inf, 0, NaN];
    out = roundtrip(v);
    assert(out(1) == 1, 'infArray: normal');
    assert(isinf(out(2)) && out(2) > 0, 'infArray: +Inf');
    assert(isinf(out(3)) && out(3) < 0, 'infArray: -Inf');
    assert(out(4) == 0, 'infArray: zero');
    assert(isnan(out(5)), 'infArray: NaN');
    fprintf('    Inf/-Inf/NaN in doubles: PASS\n');

    % 6. NaN in single array
    v = single([NaN 1.5 Inf]);
    out = roundtrip(v);
    assert(isa(out, 'single'), 'singleNaN: class');
    assert(isnan(out(1)), 'singleNaN: NaN');
    assert(out(2) == single(1.5), 'singleNaN: value');
    assert(isinf(out(3)), 'singleNaN: Inf');
    fprintf('    NaN/Inf in singles: PASS\n');

    % 7. Empty char ''
    out = roundtrip('');
    assert(ischar(out), 'emptyChar: class');
    assert(isempty(out), 'emptyChar: empty');
    fprintf('    empty char: PASS\n');

    % 8. Single character
    out = roundtrip('X');
    assert(ischar(out) && strcmp(out, 'X'), 'singleChar: value');
    fprintf('    single character: PASS\n');

    % 9. Empty logical — mksqlite may return empty double for zero-length
    %    typed BLOBs. Verify emptiness (class may not survive).
    v = logical([]);
    out = roundtrip(v);
    assert(isempty(out), 'emptyLogical: empty');
    fprintf('    empty logical: PASS\n');

    % 10. Scalar logical true/false
    out = roundtrip(true);
    assert(islogical(out) && out == true, 'scalarTrue: value');
    out = roundtrip(false);
    assert(islogical(out) && out == false, 'scalarFalse: value');
    fprintf('    scalar logical true/false: PASS\n');

    % 11. All-true and all-false logical
    out = roundtrip(true(1, 10));
    assert(all(out), 'allTrue: all true');
    out = roundtrip(false(1, 10));
    assert(~any(out), 'allFalse: all false');
    fprintf('    all-true/all-false logical: PASS\n');

    % 12. Empty cell — mksqlite may not preserve cell class for empty
    v = {};
    out = roundtrip(v);
    assert(isempty(out), 'emptyCell: empty');
    fprintf('    empty cell array: PASS\n');

    % 13. Cell with single element
    out = roundtrip({'solo'});
    assert(iscell(out) && numel(out) == 1, 'singleCell: size');
    assert(strcmp(out{1}, 'solo'), 'singleCell: value');
    fprintf('    single-element cell: PASS\n');

    % 14. Cell containing empty strings
    v = {'', 'hello', '', 'world', ''};
    out = roundtrip(v);
    assert(strcmp(out{1}, ''), 'cellEmptyStr: first empty');
    assert(strcmp(out{2}, 'hello'), 'cellEmptyStr: hello');
    assert(strcmp(out{3}, ''), 'cellEmptyStr: middle empty');
    fprintf('    cell with empty strings: PASS\n');

    % 15. Deeply nested cell (3 levels)
    v = {{{'deep'}, 42}, 'flat'};
    out = roundtrip(v);
    assert(iscell(out{1}), 'deepNest: level 1');
    assert(iscell(out{1}{1}), 'deepNest: level 2');
    assert(strcmp(out{1}{1}{1}, 'deep'), 'deepNest: value');
    assert(out{1}{2} == 42, 'deepNest: numeric');
    fprintf('    deeply nested cell (3 levels): PASS\n');

    % 16. 2D double matrix
    v = [1 2 3; 4 5 6; 7 8 9];
    out = roundtrip(v);
    assert(isequal(size(out), [3 3]), 'matrix3x3: size');
    assert(isequal(out, v), 'matrix3x3: values');
    fprintf('    2D double matrix: PASS\n');

    % 17. Column vector
    v = (1:10)';
    out = roundtrip(v);
    assert(isequal(size(out), [10 1]), 'colVec: shape');
    assert(isequal(out, v), 'colVec: values');
    fprintf('    column vector: PASS\n');

    % 18. Row vector
    v = 1:10;
    out = roundtrip(v);
    assert(isequal(size(out), [1 10]), 'rowVec: shape');
    assert(isequal(out, v), 'rowVec: values');
    fprintf('    row vector: PASS\n');

    % 19. Large array (100K elements)
    v = randn(1, 100000);
    out = roundtrip(v);
    assert(numel(out) == 100000, 'largeArray: size');
    assert(max(abs(out - v)) < 1e-12, 'largeArray: precision');
    fprintf('    100K element array: PASS\n');

    % 20. Struct with single field
    s1 = struct();
    s1.onlyField = [1 2 3];
    out = roundtrip(s1);
    assert(isstruct(out), 'singleFieldStruct: class');
    assert(isfield(out, 'onlyField'), 'singleFieldStruct: field exists');
    assert(isequal(out.onlyField, [1 2 3]), 'singleFieldStruct: values');
    fprintf('    struct with single field: PASS\n');

    % 21. Struct with multiple fields of different types
    s2 = struct();
    s2.name = 'test';
    s2.values = [1.5 2.5 3.5];
    s2.flags = logical([1 0 1]);
    s2.count = int32(42);
    out = roundtrip(s2);
    assert(strcmp(out.name, 'test'), 'multiFieldStruct: name');
    assert(isequal(out.values, [1.5 2.5 3.5]), 'multiFieldStruct: values');
    assert(islogical(out.flags), 'multiFieldStruct: flags class');
    assert(isequal(out.flags, logical([1 0 1])), 'multiFieldStruct: flags');
    fprintf('    struct with mixed-type fields: PASS\n');

    % 22. uint8 array (common for image data)
    v = uint8(0:255);
    out = roundtrip(v);
    assert(isa(out, 'uint8'), 'uint8range: class');
    assert(isequal(out, v), 'uint8range: full range preserved');
    fprintf('    uint8 full range (0-255): PASS\n');

    % 23. int64 extreme values
    v = int64([intmin('int64'), 0, intmax('int64')]);
    out = roundtrip(v);
    assert(isa(out, 'int64'), 'int64extremes: class');
    assert(isequal(out, v), 'int64extremes: values');
    fprintf('    int64 extreme values: PASS\n');

    % 24. Multiple queries returning results
    mksqlite(db, 'CREATE TABLE multi (id INTEGER, val BLOB)');
    for i = 1:5
        mksqlite(db, 'INSERT INTO multi VALUES (?, ?)', i, int32(i * 10));
    end
    res = mksqlite(db, 'SELECT val FROM multi WHERE id > 2 ORDER BY id');
    assert(numel(res) == 3, 'multiRow: 3 results');
    assert(res(1).val == int32(30), 'multiRow: first');
    assert(res(3).val == int32(50), 'multiRow: last');
    fprintf('    multi-row query results: PASS\n');

    % 25. Query returning zero rows
    res = mksqlite(db, 'SELECT val FROM multi WHERE id > 100');
    assert(isempty(res), 'emptyResult: should be empty');
    fprintf('    zero-row query: PASS\n');

    % 26. Re-open same database
    mksqlite(db, 'close');
    db2 = mksqlite('open', dbPath);
    mksqlite(db2, 'typedBLOBs', 2);
    res = mksqlite(db2, 'SELECT val FROM multi WHERE id=1');
    assert(res.val == int32(10), 'reopen: data persists');
    mksqlite(db2, 'close');
    fprintf('    re-open database: PASS\n');

    delete(dbPath);

    fprintf('\n    All 26 mksqlite edge-case tests passed.\n');
end
