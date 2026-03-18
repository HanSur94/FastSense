classdef TestMksqliteTypes < matlab.unittest.TestCase
%TestMksqliteTypes Tests for mksqlite typed BLOB support across all types.
%   Covers: char, multi-row char, logical, cell of strings, cell of mixed
%   types, struct (categorical), all numeric types, and DataStore extra
%   columns (addColumn / getColumnRange / getColumnSlice / listColumns).

    properties
        db
        dbPath
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        %% Part 1: mksqlite typed BLOB round-trips

        function testCharVector(testCase)
            testCase.openDb();
            testCase.addTeardown(@() testCase.closeDb());
            ch = 'Hello World';
            mksqlite(testCase.db, 'INSERT INTO t VALUES (?, ?)', 1, ch);
            res = mksqlite(testCase.db, 'SELECT data FROM t WHERE id=1');
            testCase.verifyTrue(ischar(res.data), 'char: class lost');
            testCase.verifyEqual(ch, res.data, 'char: value mismatch');
        end

        function testCharMatrix(testCase)
            testCase.openDb();
            testCase.addTeardown(@() testCase.closeDb());
            cm = ['abc'; 'def'; 'ghi'];
            mksqlite(testCase.db, 'INSERT INTO t VALUES (?, ?)', 2, cm);
            res = mksqlite(testCase.db, 'SELECT data FROM t WHERE id=2');
            testCase.verifyTrue(ischar(res.data), 'char matrix: class lost');
            testCase.verifyEqual(size(cm), size(res.data), 'char matrix: size mismatch');
            testCase.verifyEqual(cm, res.data, 'char matrix: value mismatch');
        end

        function testLogicalArray(testCase)
            testCase.openDb();
            testCase.addTeardown(@() testCase.closeDb());
            lg = logical([1 0 1 1 0 0 1]);
            mksqlite(testCase.db, 'INSERT INTO t VALUES (?, ?)', 3, lg);
            res = mksqlite(testCase.db, 'SELECT data FROM t WHERE id=3');
            testCase.verifyTrue(islogical(res.data), 'logical: class lost');
            testCase.verifyEqual(lg, res.data, 'logical: value mismatch');
        end

        function testCellArrayOfStrings(testCase)
            testCase.openDb();
            testCase.addTeardown(@() testCase.closeDb());
            cs = {'apple', 'banana', 'cherry', 'date'};
            mksqlite(testCase.db, 'INSERT INTO t VALUES (?, ?)', 4, cs);
            res = mksqlite(testCase.db, 'SELECT data FROM t WHERE id=4');
            testCase.verifyTrue(iscell(res.data), 'cell strings: class lost');
            testCase.verifyEqual(cs, res.data, 'cell strings: value mismatch');
        end

        function testCellArrayOfMixedTypes(testCase)
            testCase.openDb();
            testCase.addTeardown(@() testCase.closeDb());
            mx = {42, 'hello', [1 2 3], logical([0 1]), int32(7)};
            mksqlite(testCase.db, 'INSERT INTO t VALUES (?, ?)', 5, mx);
            res = mksqlite(testCase.db, 'SELECT data FROM t WHERE id=5');
            testCase.verifyTrue(iscell(res.data), 'cell mixed: class lost');
            testCase.verifyEqual(res.data{1}, 42, 'cell mixed: numeric');
            testCase.verifyEqual(res.data{2}, 'hello', 'cell mixed: char');
            testCase.verifyEqual(res.data{3}, [1 2 3], 'cell mixed: array');
            testCase.verifyTrue(islogical(res.data{4}), 'cell mixed: logical class');
            testCase.verifyEqual(res.data{4}, logical([0 1]), 'cell mixed: logical val');
            testCase.verifyTrue(isa(res.data{5}, 'int32'), 'cell mixed: int32 class');
            testCase.verifyEqual(res.data{5}, int32(7), 'cell mixed: int32 val');
        end

        function testStructCategorical(testCase)
            testCase.openDb();
            testCase.addTeardown(@() testCase.closeDb());
            cat.codes = uint32([1 2 3 1 2 3]);
            cat.categories = {'low', 'medium', 'high'};
            mksqlite(testCase.db, 'INSERT INTO t VALUES (?, ?)', 6, cat);
            res = mksqlite(testCase.db, 'SELECT data FROM t WHERE id=6');
            testCase.verifyTrue(isstruct(res.data), 'struct: class lost');
            testCase.verifyEqual(res.data.codes, cat.codes, 'struct: codes mismatch');
            testCase.verifyEqual(res.data.categories, cat.categories, 'struct: categories mismatch');
        end

        function testAllNumericTypes(testCase)
            testCase.openDb();
            testCase.addTeardown(@() testCase.closeDb());
            numTypes = {'double','single','int8','uint8','int16','uint16', ...
                        'int32','uint32','int64','uint64'};
            for t = 1:numel(numTypes)
                tp = numTypes{t};
                val = cast([10 20 30 40 50], tp);
                tid = 100 + t;
                mksqlite(testCase.db, 'INSERT INTO t VALUES (?, ?)', tid, val);
                res = mksqlite(testCase.db, 'SELECT data FROM t WHERE id=?', tid);
                testCase.verifyEqual(class(res.data), tp, sprintf('%s: class lost', tp));
                testCase.verifyEqual(res.data, val, sprintf('%s: value mismatch', tp));
            end
        end

        function testLogicalMatrix(testCase)
            testCase.openDb();
            testCase.addTeardown(@() testCase.closeDb());
            lm = logical([1 0 1; 0 1 0]);
            mksqlite(testCase.db, 'INSERT INTO t VALUES (?, ?)', 200, lm);
            res = mksqlite(testCase.db, 'SELECT data FROM t WHERE id=200');
            testCase.verifyTrue(islogical(res.data), 'logical matrix: class lost');
            testCase.verifyEqual(size(lm), size(res.data), 'logical matrix: size mismatch');
            testCase.verifyEqual(lm, res.data, 'logical matrix: value mismatch');
        end

        function testNestedCellArrays(testCase)
            testCase.openDb();
            testCase.addTeardown(@() testCase.closeDb());
            nested = {{'a', 'b'}, {1, 2, 3}, 'flat'};
            mksqlite(testCase.db, 'INSERT INTO t VALUES (?, ?)', 201, nested);
            res = mksqlite(testCase.db, 'SELECT data FROM t WHERE id=201');
            testCase.verifyTrue(iscell(res.data), 'nested cell: class lost');
            testCase.verifyTrue(iscell(res.data{1}), 'nested cell: inner cell 1');
            testCase.verifyEqual(res.data{1}, {'a', 'b'}, 'nested cell: inner values 1');
            testCase.verifyTrue(iscell(res.data{2}), 'nested cell: inner cell 2');
            testCase.verifyEqual(res.data{3}, 'flat', 'nested cell: flat string');
        end

        %% Part 2: DataStore extra columns

        function testAddColumnCellStrings(testCase)
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            labels = cell(1, n);
            for i = 1:n
                labels{i} = sprintf('pt_%d', i);
            end
            ds.addColumn('labels', labels);
            testCase.verifyTrue(any(strcmp('labels', ds.listColumns())), ...
                'addColumn: labels not in listColumns');
        end

        function testAddColumnLogical(testCase)
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            labels = cell(1, n);
            for i = 1:n
                labels{i} = sprintf('pt_%d', i);
            end
            ds.addColumn('labels', labels);

            flags = logical(mod(1:n, 2));  % alternating true/false
            ds.addColumn('flags', flags);
            testCase.verifyEqual(numel(ds.listColumns()), 2, 'addColumn: should have 2 columns');
        end

        function testAddColumnCategoricalStruct(testCase)
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            labels = cell(1, n);
            for i = 1:n; labels{i} = sprintf('pt_%d', i); end
            ds.addColumn('labels', labels);
            flags = logical(mod(1:n, 2));
            ds.addColumn('flags', flags);

            catData.codes = uint32(mod(0:n-1, 3) + 1);
            catData.categories = {'low', 'medium', 'high'};
            ds.addColumn('severity', catData);
            testCase.verifyEqual(numel(ds.listColumns()), 3, 'addColumn: should have 3 columns');
        end

        function testAddColumnChar(testCase)
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            charData = char(mod(0:n-1, 26) + 65);  % A-Z repeating
            ds.addColumn('letters', charData);
            testCase.verifyTrue(any(strcmp('letters', ds.listColumns())), ...
                'addColumn: letters not in listColumns');
        end

        function testGetColumnSliceLabels(testCase)
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            labels = cell(1, n);
            for i = 1:n; labels{i} = sprintf('pt_%d', i); end
            ds.addColumn('labels', labels);

            slice = ds.getColumnSlice('labels', 1, 5);
            testCase.verifyTrue(iscell(slice), 'getColumnSlice: should return cell');
            testCase.verifyEqual(numel(slice), 5, 'getColumnSlice: wrong count');
            testCase.verifyEqual(slice{1}, 'pt_1', 'getColumnSlice: first label');
            testCase.verifyEqual(slice{5}, 'pt_5', 'getColumnSlice: fifth label');
        end

        function testGetColumnSliceLogical(testCase)
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            flags = logical(mod(1:n, 2));
            ds.addColumn('flags', flags);

            fslice = ds.getColumnSlice('flags', 1, 10);
            testCase.verifyTrue(islogical(fslice), 'getColumnSlice flags: should be logical');
            testCase.verifyEqual(numel(fslice), 10, 'getColumnSlice flags: wrong count');
            testCase.verifyEqual(fslice(1), true, 'getColumnSlice flags: first');
            testCase.verifyEqual(fslice(2), false, 'getColumnSlice flags: second');
        end

        function testGetColumnSliceCategorical(testCase)
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            labels = cell(1, n);
            for i = 1:n; labels{i} = sprintf('pt_%d', i); end
            ds.addColumn('labels', labels);
            flags = logical(mod(1:n, 2));
            ds.addColumn('flags', flags);
            catData.codes = uint32(mod(0:n-1, 3) + 1);
            catData.categories = {'low', 'medium', 'high'};
            ds.addColumn('severity', catData);

            cslice = ds.getColumnSlice('severity', 1, 6);
            testCase.verifyTrue(isstruct(cslice), 'getColumnSlice severity: should be struct');
            testCase.verifyEqual(cslice.codes, uint32([1 2 3 1 2 3]), ...
                'getColumnSlice severity: codes');
            testCase.verifyEqual(cslice.categories, {'low', 'medium', 'high'}, ...
                'getColumnSlice severity: categories');
        end

        function testGetColumnSliceChar(testCase)
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            charData = char(mod(0:n-1, 26) + 65);
            ds.addColumn('letters', charData);

            cchar = ds.getColumnSlice('letters', 1, 3);
            testCase.verifyTrue(ischar(cchar), 'getColumnSlice letters: should be char');
            testCase.verifyEqual(cchar(1), 'A', 'getColumnSlice letters: first');
            testCase.verifyEqual(cchar(3), 'C', 'getColumnSlice letters: third');
        end

        function testGetColumnRangeLabels(testCase)
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            labels = cell(1, n);
            for i = 1:n; labels{i} = sprintf('pt_%d', i); end
            ds.addColumn('labels', labels);

            rng_labels = ds.getColumnRange('labels', 50, 50.01);
            testCase.verifyTrue(iscell(rng_labels), 'getColumnRange: should return cell');
            testCase.verifyNotEmpty(rng_labels, 'getColumnRange: should have results');
        end

        function testGetColumnRangeFlags(testCase)
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            flags = logical(mod(1:n, 2));
            ds.addColumn('flags', flags);

            rng_flags = ds.getColumnRange('flags', 0, 0.01);
            testCase.verifyTrue(islogical(rng_flags), 'getColumnRange flags: should be logical');
        end

        function testListColumns(testCase)
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            labels = cell(1, n);
            for i = 1:n; labels{i} = sprintf('pt_%d', i); end
            ds.addColumn('labels', labels);
            flags = logical(mod(1:n, 2));
            ds.addColumn('flags', flags);
            catData.codes = uint32(mod(0:n-1, 3) + 1);
            catData.categories = {'low', 'medium', 'high'};
            ds.addColumn('severity', catData);
            charData = char(mod(0:n-1, 26) + 65);
            ds.addColumn('letters', charData);

            cols = ds.listColumns();
            testCase.verifyEqual(numel(cols), 4, 'listColumns: expected 4');
            testCase.verifyTrue(all(ismember({'labels','flags','severity','letters'}, cols)), ...
                'listColumns: missing names');
        end

        function testAddColumnDuplicateRejection(testCase)
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            labels = cell(1, n);
            for i = 1:n; labels{i} = sprintf('pt_%d', i); end
            ds.addColumn('labels', labels);

            threw = false;
            try
                ds.addColumn('labels', labels);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'addColumn duplicate: should throw');
        end

        function testAddColumnSizeMismatchRejection(testCase)
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            threw = false;
            try
                ds.addColumn('bad', {'too', 'short'});
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'addColumn size mismatch: should throw');
        end

        %% Part 3: Categorical and string convenience methods

        function testToCategoricalRoundTrip(testCase)
            n2 = 1000;
            x2 = linspace(0, 100, n2);
            y2 = sin(x2);
            ds2 = FastSenseDataStore(x2, y2);
            testCase.addTeardown(@() ds2.cleanup());

            catData2.codes = uint32(mod(0:n2-1, 3) + 1);
            catData2.categories = {'low', 'medium', 'high'};
            ds2.addColumn('cat_struct', catData2);
            slice = ds2.getColumnSlice('cat_struct', 1, 6);
            labels_back = FastSenseDataStore.toCategorical(slice);
            if exist('categorical', 'class')
                testCase.verifyTrue(isa(labels_back, 'categorical'), ...
                    'toCategorical: should return categorical in MATLAB');
            else
                testCase.verifyTrue(iscell(labels_back), ...
                    'toCategorical: should return cell in Octave');
            end
            expected_labels = {'low','medium','high','low','medium','high'};
            if iscell(labels_back)
                for li = 1:6
                    testCase.verifyEqual(labels_back{li}, expected_labels{li}, ...
                        sprintf('toCategorical: label %d mismatch', li));
                end
            end
        end

        function testToCategoricalBadInput(testCase)
            threw = false;
            try
                FastSenseDataStore.toCategorical('not_a_struct');
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'toCategorical bad input: should throw');
        end

        function testAutoConvertCategorical(testCase)
            if ~exist('categorical', 'class')
                return;
            end
            n2 = 1000;
            x2 = linspace(0, 100, n2);
            y2 = sin(x2);
            ds2 = FastSenseDataStore(x2, y2);
            testCase.addTeardown(@() ds2.cleanup());

            c_native = categorical({'a','b','c','a','b'}, {'a','b','c'});
            c_native = repmat(c_native, 1, n2/5);
            ds2.addColumn('cat_native', c_native);
            sliceN = ds2.getColumnSlice('cat_native', 1, 5);
            testCase.verifyTrue(isstruct(sliceN) && isfield(sliceN, 'codes'), ...
                'auto-convert categorical: should be stored as struct');
            labelsN = FastSenseDataStore.toCategorical(sliceN);
            testCase.verifyTrue(isa(labelsN, 'categorical'), ...
                'auto-convert categorical: toCategorical should return categorical');
        end

        function testFromCategorical(testCase)
            if ~exist('categorical', 'class')
                return;
            end
            c_test = categorical({'x','y','z','x'}, {'x','y','z'});
            s_test = FastSenseDataStore.fromCategorical(c_test);
            testCase.verifyEqual(s_test.codes, uint32([1 2 3 1]), ...
                'fromCategorical: codes mismatch');
            testCase.verifyEqual(s_test.categories, {'x','y','z'}, ...
                'fromCategorical: categories mismatch');
        end

        function testAutoConvertStringArray(testCase)
            if ~exist('string', 'class')
                return;
            end
            n2 = 1000;
            x2 = linspace(0, 100, n2);
            y2 = sin(x2);
            ds2 = FastSenseDataStore(x2, y2);
            testCase.addTeardown(@() ds2.cleanup());

            labels = cell(1, n2);
            for i = 1:n2; labels{i} = sprintf('pt_%d', i); end
            strData = string(labels);
            ds2.addColumn('str_col', strData);
            sliceS = ds2.getColumnSlice('str_col', 1, 3);
            testCase.verifyTrue(iscell(sliceS), 'auto-convert string: should be stored as cell');
        end
    end

    methods (Access = private)
        function openDb(testCase)
            testCase.dbPath = [tempname, '.db'];
            testCase.db = mksqlite('open', testCase.dbPath);
            mksqlite(testCase.db, 'typedBLOBs', 2);
            mksqlite(testCase.db, 'CREATE TABLE t (id INTEGER PRIMARY KEY, data BLOB)');
        end

        function closeDb(testCase)
            try
                mksqlite(testCase.db, 'close');
            catch
            end
            if exist(testCase.dbPath, 'file')
                delete(testCase.dbPath);
            end
        end
    end
end
