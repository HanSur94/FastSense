classdef TestMksqliteEdgeCases < matlab.unittest.TestCase
%TestMksqliteEdgeCases Edge-case tests for mksqlite typed BLOB round-trips.
%   Covers: empty arrays, special float values, single-element arrays,
%   empty strings, large arrays, empty cells, struct edge cases, and
%   multi-row matrices.

    properties
        db
        dbPath
        nextId
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (TestMethodSetup)
        function setupDatabase(testCase)
            testCase.dbPath = [tempname, '.db'];
            testCase.db = mksqlite('open', testCase.dbPath);
            mksqlite(testCase.db, 'typedBLOBs', 2);
            mksqlite(testCase.db, 'CREATE TABLE t (id INTEGER PRIMARY KEY, data BLOB)');
            testCase.nextId = 1;
        end
    end

    methods (TestMethodTeardown)
        function teardownDatabase(testCase)
            try
                mksqlite(testCase.db, 'close');
            catch
            end
            if exist(testCase.dbPath, 'file')
                delete(testCase.dbPath);
            end
        end
    end

    methods (Access = private)
        function out = roundtrip(testCase, val)
            mksqlite(testCase.db, 'INSERT INTO t VALUES (?, ?)', testCase.nextId, val);
            res = mksqlite(testCase.db, 'SELECT data FROM t WHERE id=?', testCase.nextId);
            out = res.data;
            testCase.nextId = testCase.nextId + 1;
        end
    end

    methods (Test)
        function testEmptyDoubleArray(testCase)
            v = double([]);
            out = testCase.roundtrip(v);
            testCase.verifyEmpty(out, 'emptyDouble: should be empty');
            testCase.verifyTrue(isa(out, 'double'), 'emptyDouble: class preserved');
        end

        function testEmptySingleArray(testCase)
            v = single([]);
            out = testCase.roundtrip(v);
            testCase.verifyEmpty(out, 'emptySingle: should be empty');
        end

        function testScalarDouble(testCase)
            out = testCase.roundtrip(42.5);
            testCase.verifyEqual(out, 42.5, 'scalarDouble: value');
        end

        function testScalarInt32(testCase)
            % mksqlite binds scalars as native SQLite types,
            % so int32 round-trips as double. Test value, not class.
            out = testCase.roundtrip(int32(7));
            testCase.verifyEqual(out, 7, 'scalarInt32: value');
        end

        function testInfAndNaNInDoubleArray(testCase)
            v = [1, Inf, -Inf, 0, NaN];
            out = testCase.roundtrip(v);
            testCase.verifyEqual(out(1), 1, 'infArray: normal');
            testCase.verifyTrue(isinf(out(2)) && out(2) > 0, 'infArray: +Inf');
            testCase.verifyTrue(isinf(out(3)) && out(3) < 0, 'infArray: -Inf');
            testCase.verifyEqual(out(4), 0, 'infArray: zero');
            testCase.verifyTrue(isnan(out(5)), 'infArray: NaN');
        end

        function testNaNInSingleArray(testCase)
            v = single([NaN 1.5 Inf]);
            out = testCase.roundtrip(v);
            testCase.verifyTrue(isa(out, 'single'), 'singleNaN: class');
            testCase.verifyTrue(isnan(out(1)), 'singleNaN: NaN');
            testCase.verifyEqual(out(2), single(1.5), 'singleNaN: value');
            testCase.verifyTrue(isinf(out(3)), 'singleNaN: Inf');
        end

        function testEmptyChar(testCase)
            out = testCase.roundtrip('');
            testCase.verifyTrue(ischar(out), 'emptyChar: class');
            testCase.verifyEmpty(out, 'emptyChar: empty');
        end

        function testSingleCharacter(testCase)
            out = testCase.roundtrip('X');
            testCase.verifyTrue(ischar(out) && strcmp(out, 'X'), 'singleChar: value');
        end

        function testEmptyLogical(testCase)
            % mksqlite may return empty double for zero-length
            % typed BLOBs. Verify emptiness (class may not survive).
            v = logical([]);
            out = testCase.roundtrip(v);
            testCase.verifyEmpty(out, 'emptyLogical: empty');
        end

        function testScalarLogicalTrueFalse(testCase)
            out = testCase.roundtrip(true);
            testCase.verifyTrue(islogical(out) && out == true, 'scalarTrue: value');
            out = testCase.roundtrip(false);
            testCase.verifyTrue(islogical(out) && out == false, 'scalarFalse: value');
        end

        function testAllTrueAllFalseLogical(testCase)
            out = testCase.roundtrip(true(1, 10));
            testCase.verifyTrue(all(out), 'allTrue: all true');
            out = testCase.roundtrip(false(1, 10));
            testCase.verifyTrue(~any(out), 'allFalse: all false');
        end

        function testEmptyCellArray(testCase)
            % mksqlite may not preserve cell class for empty
            v = {};
            out = testCase.roundtrip(v);
            testCase.verifyEmpty(out, 'emptyCell: empty');
        end

        function testSingleElementCell(testCase)
            out = testCase.roundtrip({'solo'});
            testCase.verifyTrue(iscell(out) && numel(out) == 1, 'singleCell: size');
            testCase.verifyEqual(out{1}, 'solo', 'singleCell: value');
        end

        function testCellWithEmptyStrings(testCase)
            v = {'', 'hello', '', 'world', ''};
            out = testCase.roundtrip(v);
            testCase.verifyEqual(out{1}, '', 'cellEmptyStr: first empty');
            testCase.verifyEqual(out{2}, 'hello', 'cellEmptyStr: hello');
            testCase.verifyEqual(out{3}, '', 'cellEmptyStr: middle empty');
        end

        function testDeeplyNestedCell(testCase)
            v = {{{'deep'}, 42}, 'flat'};
            out = testCase.roundtrip(v);
            testCase.verifyTrue(iscell(out{1}), 'deepNest: level 1');
            testCase.verifyTrue(iscell(out{1}{1}), 'deepNest: level 2');
            testCase.verifyEqual(out{1}{1}{1}, 'deep', 'deepNest: value');
            testCase.verifyEqual(out{1}{2}, 42, 'deepNest: numeric');
        end

        function test2DDoubleMatrix(testCase)
            v = [1 2 3; 4 5 6; 7 8 9];
            out = testCase.roundtrip(v);
            testCase.verifyEqual(size(out), [3 3], 'matrix3x3: size');
            testCase.verifyEqual(out, v, 'matrix3x3: values');
        end

        function testColumnVector(testCase)
            v = (1:10)';
            out = testCase.roundtrip(v);
            testCase.verifyEqual(size(out), [10 1], 'colVec: shape');
            testCase.verifyEqual(out, v, 'colVec: values');
        end

        function testRowVector(testCase)
            v = 1:10;
            out = testCase.roundtrip(v);
            testCase.verifyEqual(size(out), [1 10], 'rowVec: shape');
            testCase.verifyEqual(out, v, 'rowVec: values');
        end

        function testLargeArray(testCase)
            v = randn(1, 100000);
            out = testCase.roundtrip(v);
            testCase.verifyEqual(numel(out), 100000, 'largeArray: size');
            testCase.verifyLessThan(max(abs(out - v)), 1e-12, 'largeArray: precision');
        end

        function testStructWithSingleField(testCase)
            s1 = struct();
            s1.onlyField = [1 2 3];
            out = testCase.roundtrip(s1);
            testCase.verifyTrue(isstruct(out), 'singleFieldStruct: class');
            testCase.verifyTrue(isfield(out, 'onlyField'), 'singleFieldStruct: field exists');
            testCase.verifyEqual(out.onlyField, [1 2 3], 'singleFieldStruct: values');
        end

        function testStructWithMultipleFields(testCase)
            s2 = struct();
            s2.name = 'test';
            s2.values = [1.5 2.5 3.5];
            s2.flags = logical([1 0 1]);
            s2.count = int32(42);
            out = testCase.roundtrip(s2);
            testCase.verifyEqual(out.name, 'test', 'multiFieldStruct: name');
            testCase.verifyEqual(out.values, [1.5 2.5 3.5], 'multiFieldStruct: values');
            testCase.verifyTrue(islogical(out.flags), 'multiFieldStruct: flags class');
            testCase.verifyEqual(out.flags, logical([1 0 1]), 'multiFieldStruct: flags');
        end

        function testUint8FullRange(testCase)
            v = uint8(0:255);
            out = testCase.roundtrip(v);
            testCase.verifyTrue(isa(out, 'uint8'), 'uint8range: class');
            testCase.verifyEqual(out, v, 'uint8range: full range preserved');
        end

        function testInt64ExtremeValues(testCase)
            v = int64([intmin('int64'), 0, intmax('int64')]);
            out = testCase.roundtrip(v);
            testCase.verifyTrue(isa(out, 'int64'), 'int64extremes: class');
            testCase.verifyEqual(out, v, 'int64extremes: values');
        end

        function testMultiRowQueryResults(testCase)
            mksqlite(testCase.db, 'CREATE TABLE multi (id INTEGER, val BLOB)');
            for i = 1:5
                mksqlite(testCase.db, 'INSERT INTO multi VALUES (?, ?)', i, int32(i * 10));
            end
            res = mksqlite(testCase.db, 'SELECT val FROM multi WHERE id > 2 ORDER BY id');
            testCase.verifyEqual(numel(res), 3, 'multiRow: 3 results');
            % mksqlite binds scalar numerics as SQLite REAL, so int32
            % round-trips as double.  Compare values, not class.
            testCase.verifyEqual(res(1).val, 30, 'multiRow: first');
            testCase.verifyEqual(res(3).val, 50, 'multiRow: last');
        end

        function testZeroRowQuery(testCase)
            mksqlite(testCase.db, 'CREATE TABLE multi2 (id INTEGER, val BLOB)');
            for i = 1:5
                mksqlite(testCase.db, 'INSERT INTO multi2 VALUES (?, ?)', i, int32(i * 10));
            end
            res = mksqlite(testCase.db, 'SELECT val FROM multi2 WHERE id > 100');
            testCase.verifyEmpty(res, 'emptyResult: should be empty');
        end

        function testReopenDatabase(testCase)
            mksqlite(testCase.db, 'CREATE TABLE multi3 (id INTEGER, val BLOB)');
            for i = 1:5
                mksqlite(testCase.db, 'INSERT INTO multi3 VALUES (?, ?)', i, int32(i * 10));
            end
            mksqlite(testCase.db, 'close');
            db2 = mksqlite('open', testCase.dbPath);
            mksqlite(db2, 'typedBLOBs', 2);
            res = mksqlite(db2, 'SELECT val FROM multi3 WHERE id=1');
            % Scalar int32 round-trips as double (see testScalarInt32).
            testCase.verifyEqual(res.val, 10, 'reopen: data persists');
            mksqlite(db2, 'close');
            % Re-open for teardown
            testCase.db = mksqlite('open', testCase.dbPath);
        end
    end
end
