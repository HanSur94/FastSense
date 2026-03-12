function test_mksqlite_types()
%TEST_MKSQLITE_TYPES Tests for mksqlite typed BLOB support across all types.
%   Covers: char, multi-row char, logical, cell of strings, cell of mixed
%   types, struct (categorical), all numeric types, and DataStore extra
%   columns (addColumn / getColumnRange / getColumnSlice / listColumns).

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    setup();

    if ~(exist('mksqlite', 'file') == 3)
        fprintf('    SKIPPED: mksqlite MEX not available.\n');
        return;
    end

    % =====================================================================
    %  Part 1: mksqlite typed BLOB round-trips
    % =====================================================================
    fprintf('  --- mksqlite typed BLOB round-trips ---\n');

    dbPath = [tempname, '.db'];
    db = mksqlite('open', dbPath);
    mksqlite(db, 'typedBLOBs', 2);
    mksqlite(db, 'CREATE TABLE t (id INTEGER PRIMARY KEY, data BLOB)');

    % 1. Char vector
    ch = 'Hello World';
    mksqlite(db, 'INSERT INTO t VALUES (?, ?)', 1, ch);
    res = mksqlite(db, 'SELECT data FROM t WHERE id=1');
    assert(ischar(res.data), 'char: class lost');
    assert(strcmp(ch, res.data), 'char: value mismatch');
    fprintf('    char vector: PASS\n');

    % 2. Multi-row char matrix
    cm = ['abc'; 'def'; 'ghi'];
    mksqlite(db, 'INSERT INTO t VALUES (?, ?)', 2, cm);
    res = mksqlite(db, 'SELECT data FROM t WHERE id=2');
    assert(ischar(res.data), 'char matrix: class lost');
    assert(isequal(size(cm), size(res.data)), 'char matrix: size mismatch');
    assert(isequal(cm, res.data), 'char matrix: value mismatch');
    fprintf('    char matrix: PASS\n');

    % 3. Logical array
    lg = logical([1 0 1 1 0 0 1]);
    mksqlite(db, 'INSERT INTO t VALUES (?, ?)', 3, lg);
    res = mksqlite(db, 'SELECT data FROM t WHERE id=3');
    assert(islogical(res.data), 'logical: class lost');
    assert(isequal(lg, res.data), 'logical: value mismatch');
    fprintf('    logical array: PASS\n');

    % 4. Cell array of strings
    cs = {'apple', 'banana', 'cherry', 'date'};
    mksqlite(db, 'INSERT INTO t VALUES (?, ?)', 4, cs);
    res = mksqlite(db, 'SELECT data FROM t WHERE id=4');
    assert(iscell(res.data), 'cell strings: class lost');
    assert(isequal(cs, res.data), 'cell strings: value mismatch');
    fprintf('    cell of strings: PASS\n');

    % 5. Cell array of mixed types
    mx = {42, 'hello', [1 2 3], logical([0 1]), int32(7)};
    mksqlite(db, 'INSERT INTO t VALUES (?, ?)', 5, mx);
    res = mksqlite(db, 'SELECT data FROM t WHERE id=5');
    assert(iscell(res.data), 'cell mixed: class lost');
    assert(res.data{1} == 42, 'cell mixed: numeric');
    assert(strcmp(res.data{2}, 'hello'), 'cell mixed: char');
    assert(isequal(res.data{3}, [1 2 3]), 'cell mixed: array');
    assert(islogical(res.data{4}), 'cell mixed: logical class');
    assert(isequal(res.data{4}, logical([0 1])), 'cell mixed: logical val');
    assert(isa(res.data{5}, 'int32'), 'cell mixed: int32 class');
    assert(res.data{5} == 7, 'cell mixed: int32 val');
    fprintf('    cell of mixed types: PASS\n');

    % 6. Struct (categorical representation)
    cat.codes = uint32([1 2 3 1 2 3]);
    cat.categories = {'low', 'medium', 'high'};
    mksqlite(db, 'INSERT INTO t VALUES (?, ?)', 6, cat);
    res = mksqlite(db, 'SELECT data FROM t WHERE id=6');
    assert(isstruct(res.data), 'struct: class lost');
    assert(isequal(res.data.codes, cat.codes), 'struct: codes mismatch');
    assert(isequal(res.data.categories, cat.categories), 'struct: categories mismatch');
    fprintf('    struct (categorical): PASS\n');

    % 7. All numeric types
    numTypes = {'double','single','int8','uint8','int16','uint16', ...
                'int32','uint32','int64','uint64'};
    for t = 1:numel(numTypes)
        tp = numTypes{t};
        val = cast([10 20 30 40 50], tp);
        tid = 100 + t;
        mksqlite(db, 'INSERT INTO t VALUES (?, ?)', tid, val);
        res = mksqlite(db, 'SELECT data FROM t WHERE id=?', tid);
        assert(strcmp(class(res.data), tp), sprintf('%s: class lost', tp));
        assert(isequal(res.data, val), sprintf('%s: value mismatch', tp));
    end
    fprintf('    all 10 numeric types: PASS\n');

    % 8. Logical matrix (2D)
    lm = logical([1 0 1; 0 1 0]);
    mksqlite(db, 'INSERT INTO t VALUES (?, ?)', 200, lm);
    res = mksqlite(db, 'SELECT data FROM t WHERE id=200');
    assert(islogical(res.data), 'logical matrix: class lost');
    assert(isequal(size(lm), size(res.data)), 'logical matrix: size mismatch');
    assert(isequal(lm, res.data), 'logical matrix: value mismatch');
    fprintf('    logical matrix: PASS\n');

    % 9. Nested cell arrays
    nested = {{'a', 'b'}, {1, 2, 3}, 'flat'};
    mksqlite(db, 'INSERT INTO t VALUES (?, ?)', 201, nested);
    res = mksqlite(db, 'SELECT data FROM t WHERE id=201');
    assert(iscell(res.data), 'nested cell: class lost');
    assert(iscell(res.data{1}), 'nested cell: inner cell 1');
    assert(isequal(res.data{1}, {'a', 'b'}), 'nested cell: inner values 1');
    assert(iscell(res.data{2}), 'nested cell: inner cell 2');
    assert(strcmp(res.data{3}, 'flat'), 'nested cell: flat string');
    fprintf('    nested cell arrays: PASS\n');

    mksqlite(db, 'close');
    delete(dbPath);

    % =====================================================================
    %  Part 2: DataStore extra columns
    % =====================================================================
    fprintf('\n  --- DataStore extra columns ---\n');

    n = 50000;
    x = linspace(0, 100, n);
    y = sin(x);
    ds = FastPlotDataStore(x, y);

    % 10. addColumn with cell of strings
    labels = cell(1, n);
    for i = 1:n
        labels{i} = sprintf('pt_%d', i);
    end
    ds.addColumn('labels', labels);
    assert(any(strcmp('labels', ds.listColumns())), ...
        'addColumn: labels not in listColumns');
    fprintf('    addColumn cell strings: PASS\n');

    % 11. addColumn with logical
    flags = logical(mod(1:n, 2));  % alternating true/false
    ds.addColumn('flags', flags);
    assert(numel(ds.listColumns()) == 2, 'addColumn: should have 2 columns');
    fprintf('    addColumn logical: PASS\n');

    % 12. addColumn with categorical struct
    catData.codes = uint32(mod(0:n-1, 3) + 1);
    catData.categories = {'low', 'medium', 'high'};
    ds.addColumn('severity', catData);
    assert(numel(ds.listColumns()) == 3, 'addColumn: should have 3 columns');
    fprintf('    addColumn categorical struct: PASS\n');

    % 13. addColumn with char vector
    charData = char(mod(0:n-1, 26) + 65);  % A-Z repeating
    ds.addColumn('letters', charData);
    fprintf('    addColumn char: PASS\n');

    % 14. getColumnSlice — labels
    slice = ds.getColumnSlice('labels', 1, 5);
    assert(iscell(slice), 'getColumnSlice: should return cell');
    assert(numel(slice) == 5, 'getColumnSlice: wrong count');
    assert(strcmp(slice{1}, 'pt_1'), 'getColumnSlice: first label');
    assert(strcmp(slice{5}, 'pt_5'), 'getColumnSlice: fifth label');
    fprintf('    getColumnSlice labels: PASS\n');

    % 15. getColumnSlice — logical
    fslice = ds.getColumnSlice('flags', 1, 10);
    assert(islogical(fslice), 'getColumnSlice flags: should be logical');
    assert(numel(fslice) == 10, 'getColumnSlice flags: wrong count');
    assert(fslice(1) == true, 'getColumnSlice flags: first');
    assert(fslice(2) == false, 'getColumnSlice flags: second');
    fprintf('    getColumnSlice logical: PASS\n');

    % 16. getColumnSlice — categorical
    cslice = ds.getColumnSlice('severity', 1, 6);
    assert(isstruct(cslice), 'getColumnSlice severity: should be struct');
    assert(isequal(cslice.codes, uint32([1 2 3 1 2 3])), ...
        'getColumnSlice severity: codes');
    assert(isequal(cslice.categories, {'low', 'medium', 'high'}), ...
        'getColumnSlice severity: categories');
    fprintf('    getColumnSlice categorical: PASS\n');

    % 17. getColumnSlice — char
    cchar = ds.getColumnSlice('letters', 1, 3);
    assert(ischar(cchar), 'getColumnSlice letters: should be char');
    assert(cchar(1) == 'A', 'getColumnSlice letters: first');
    assert(cchar(3) == 'C', 'getColumnSlice letters: third');
    fprintf('    getColumnSlice char: PASS\n');

    % 18. getColumnRange — labels within X range
    rng_labels = ds.getColumnRange('labels', 50, 50.01);
    assert(iscell(rng_labels), 'getColumnRange: should return cell');
    assert(numel(rng_labels) > 0, 'getColumnRange: should have results');
    fprintf('    getColumnRange labels: PASS\n');

    % 19. getColumnRange — flags
    rng_flags = ds.getColumnRange('flags', 0, 0.01);
    assert(islogical(rng_flags), 'getColumnRange flags: should be logical');
    fprintf('    getColumnRange flags: PASS\n');

    % 20. listColumns
    cols = ds.listColumns();
    assert(numel(cols) == 4, 'listColumns: expected 4');
    assert(all(ismember({'labels','flags','severity','letters'}, cols)), ...
        'listColumns: missing names');
    fprintf('    listColumns: PASS\n');

    % 21. duplicate column name should error
    threw = false;
    try
        ds.addColumn('labels', labels);
    catch
        threw = true;
    end
    assert(threw, 'addColumn duplicate: should throw');
    fprintf('    addColumn duplicate rejection: PASS\n');

    % 22. size mismatch should error
    threw = false;
    try
        ds.addColumn('bad', {'too', 'short'});
    catch
        threw = true;
    end
    assert(threw, 'addColumn size mismatch: should throw');
    fprintf('    addColumn size mismatch rejection: PASS\n');

    ds.cleanup();

    % =====================================================================
    %  Part 3: Verify existing DataStore tests still pass
    % =====================================================================
    fprintf('\n  --- Regression check ---\n');
    run('test_datastore.m');

    fprintf('\n    All mksqlite types and DataStore column tests passed.\n');
end
