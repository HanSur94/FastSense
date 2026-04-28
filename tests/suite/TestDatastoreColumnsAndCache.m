classdef TestDatastoreColumnsAndCache < matlab.unittest.TestCase
%TESTDATASTORECOLUMNSANDCACHE Coverage for FastSenseDataStore extra-column,
%   resolved-cache, MonitorTag-cache, findIndex / findViolations and
%   pyramid-construction surfaces. Existing TestDatastore* suites cover
%   construction + getRange + readSlice + cleanup; this file fills the
%   remaining public API and the static type-conversion helpers.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (TestMethodSetup)
        function requireMksqlite(testCase)
            % Most of the surface under test is SQLite-only; binary-fallback
            % tests are tagged separately below. Skip-class strategy avoids
            % failing on bare runners. Match the existing TestDataStoreWAL
            % convention: `exist('mksqlite') == 3` returns 3 for MEX files,
            % whereas `exist('mksqlite', 'file')` returns 2 for any file
            % (would silently filter every test).
            testCase.assumeTrue(exist('mksqlite') == 3, ...
                'mksqlite MEX not available; skipping SQLite-only tests.'); %#ok<EXIST>
        end
    end

    methods (Test)
        % ------------------------------------------------------------- %
        %  addColumn / listColumns / getColumnSlice / getColumnRange
        % ------------------------------------------------------------- %

        function testAddNumericColumnRoundtrip(testCase)
            ds = FastSenseDataStore(1:1000, rand(1, 1000));
            testCase.addTeardown(@() ds.cleanup());

            labels = (1:1000) * 7;
            ds.addColumn('weights', labels);

            testCase.verifyEqual(ds.listColumns(), {'weights'}, ...
                'addColumn: listColumns reflects added column');

            slice = ds.getColumnSlice('weights', 100, 199);
            testCase.verifyEqual(numel(slice), 100, 'getColumnSlice: count');
            testCase.verifyEqual(slice(1), 7 * 100, 'getColumnSlice: first value');
            testCase.verifyEqual(slice(end), 7 * 199, 'getColumnSlice: last value');
        end

        function testAddCellColumn(testCase)
            n = 200;
            ds = FastSenseDataStore(1:n, rand(1, n));
            testCase.addTeardown(@() ds.cleanup());

            tags = arrayfun(@(k) sprintf('row_%d', k), 1:n, 'UniformOutput', false);
            ds.addColumn('tags', tags);

            slice = ds.getColumnSlice('tags', 5, 10);
            testCase.verifyEqual(numel(slice), 6, 'cellColumn: slice count');
            testCase.verifyEqual(slice{1}, 'row_5', 'cellColumn: first');
            testCase.verifyEqual(slice{end}, 'row_10', 'cellColumn: last');
        end

        function testAddCategoricalColumn(testCase)
            % Octave lacks the `categorical` class. Skip on Octave runners.
            testCase.assumeTrue(exist('categorical', 'class') == 8, ...
                'categorical class not available (Octave?); skipping.'); %#ok<EXIST>

            n = 100;
            ds = FastSenseDataStore(1:n, rand(1, n));
            testCase.addTeardown(@() ds.cleanup());

            cats = repmat({'A', 'B', 'C'}, 1, n);
            cats = cats(1:n);
            data = categorical(cats, {'A', 'B', 'C'});
            ds.addColumn('cat', data);

            slice = ds.getColumnSlice('cat', 1, 6);
            % Roundtripped via codes + categories struct
            roundTripped = FastSenseDataStore.toCategorical(slice);
            testCase.verifyTrue(isa(roundTripped, 'categorical'), ...
                'categoricalColumn: roundtrip class');
            testCase.verifyEqual(string(roundTripped(1)), "A", ...
                'categoricalColumn: first value');
        end

        function testAddColumnSizeMismatchThrows(testCase)
            ds = FastSenseDataStore(1:100, rand(1, 100));
            testCase.addTeardown(@() ds.cleanup());

            testCase.verifyError(@() ds.addColumn('bad', 1:50), ...
                'FastSenseDataStore:sizeMismatch');
        end

        function testAddColumnDuplicateThrows(testCase)
            ds = FastSenseDataStore(1:100, rand(1, 100));
            testCase.addTeardown(@() ds.cleanup());

            ds.addColumn('label', 1:100);
            testCase.verifyError(@() ds.addColumn('label', 1:100), ...
                'FastSenseDataStore:duplicateColumn');
        end

        function testListColumnsEmptyByDefault(testCase)
            ds = FastSenseDataStore(1:50, rand(1, 50));
            testCase.addTeardown(@() ds.cleanup());
            testCase.verifyEmpty(ds.listColumns(), 'listColumns: empty initially');
        end

        function testGetColumnSliceClampsBounds(testCase)
            ds = FastSenseDataStore(1:100, rand(1, 100));
            testCase.addTeardown(@() ds.cleanup());
            ds.addColumn('vals', (1:100) * 2);

            % Negative start, oversized end → clamped to [1, 100]
            slice = ds.getColumnSlice('vals', -5, 200);
            testCase.verifyEqual(numel(slice), 100, 'colSlice: clamped to full range');
        end

        function testGetColumnRangeNonexistentAfterAdd(testCase)
            % After at least one column has been added, querying a
            % nonexistent column name returns empty (the SELECT just finds
            % no rows). Pre-add the table is missing entirely, which is
            % a separate code path callers must not rely on.
            ds = FastSenseDataStore(1:100, rand(1, 100));
            testCase.addTeardown(@() ds.cleanup());

            ds.addColumn('present', 1:100);
            data = ds.getColumnRange('does_not_exist', 10, 20);
            testCase.verifyEmpty(data, 'colRange: missing column → empty');
        end

        function testGetColumnRangeBasicQuery(testCase)
            % Range queries are chunk-aligned with one neighbour-chunk
            % padding, so the slice may be wider than the requested X
            % window. Just verify the function returns rows and the
            % returned values are a contiguous subset of the column.
            ds = FastSenseDataStore(1:1000, rand(1, 1000));
            testCase.addTeardown(@() ds.cleanup());
            ds.addColumn('vals', (1:1000) * 3);

            data = ds.getColumnRange('vals', 100, 200);
            testCase.verifyNotEmpty(data, 'colRange: should return rows');
            % Verify values are a subset of the original (column = 3*[1..1000])
            testCase.verifyTrue(all(mod(data, 3) == 0), ...
                'colRange: values divisible by 3 (column = 3*idx)');
            testCase.verifyTrue(all(data >= 3 & data <= 3000), ...
                'colRange: values inside column domain');
        end

        % ------------------------------------------------------------- %
        %  findIndex (sqlite path)
        % ------------------------------------------------------------- %

        function testFindIndexLeftSqlite(testCase)
            x = 1:1000;
            ds = FastSenseDataStore(x, x);
            testCase.addTeardown(@() ds.cleanup());

            testCase.verifyEqual(ds.findIndex(500, 'left'), 500, 'findIndex left exact');
            testCase.verifyEqual(ds.findIndex(500.5, 'left'), 501, 'findIndex left between');
            % Below first value
            testCase.verifyEqual(ds.findIndex(-1, 'left'), 1, 'findIndex left below');
        end

        function testFindIndexRightSqlite(testCase)
            x = 1:1000;
            ds = FastSenseDataStore(x, x);
            testCase.addTeardown(@() ds.cleanup());

            testCase.verifyEqual(ds.findIndex(500, 'right'), 500, 'findIndex right exact');
            testCase.verifyEqual(ds.findIndex(500.5, 'right'), 500, 'findIndex right between');
            % Above last value → fallback to last index
            testCase.verifyEqual(ds.findIndex(1e6, 'right'), 1000, 'findIndex right above');
        end

        function testFindIndexEmpty(testCase)
            ds = FastSenseDataStore();
            testCase.addTeardown(@() ds.cleanup());
            % Empty store always returns 1 (documented behavior)
            testCase.verifyEqual(ds.findIndex(42, 'left'), 1, 'findIndex empty store');
        end

        % ------------------------------------------------------------- %
        %  findViolations
        % ------------------------------------------------------------- %

        function testFindViolationsUpper(testCase)
            x = 1:100;
            y = ones(1, 100);
            y([10, 20, 50]) = 5;  % three violations of upper threshold = 2
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            [vx, vy] = ds.findViolations(1, 100, 2, true);
            testCase.verifyEqual(numel(vx), 3, 'findViolations upper: count');
            testCase.verifyTrue(all(vy > 2), 'findViolations upper: all > thresh');
            testCase.verifyEqual(sort(vx), [10, 20, 50], ...
                'findViolations upper: positions');
        end

        function testFindViolationsLower(testCase)
            x = 1:100;
            y = ones(1, 100) * 5;
            y([15, 25, 80]) = -3;  % three lower violations vs. threshold = 0
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            [vx, vy] = ds.findViolations(1, 100, 0, false);
            testCase.verifyEqual(numel(vx), 3, 'findViolations lower: count');
            testCase.verifyTrue(all(vy < 0), 'findViolations lower: all < thresh');
            testCase.verifyEqual(sort(vx), [15, 25, 80], ...
                'findViolations lower: positions');
        end

        function testFindViolationsNoneInRange(testCase)
            x = 1:100;
            y = zeros(1, 100);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            [vx, vy] = ds.findViolations(1, 100, 10, true);
            testCase.verifyEmpty(vx, 'findViolations: no violations → empty');
            testCase.verifyEmpty(vy, 'findViolations: no violations → empty Y');
        end

        function testFindViolationsSubrange(testCase)
            x = 1:200;
            y = zeros(1, 200);
            y([10, 50, 150]) = 99;  % violations spread across range
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            % Only ask for [1, 100] — should miss the violation at 150
            [vx, ~] = ds.findViolations(1, 100, 10, true);
            testCase.verifyEqual(sort(vx), [10, 50], ...
                'findViolations subrange: only in-range hits');
        end

        % ------------------------------------------------------------- %
        %  Resolved threshold/violation cache
        % ------------------------------------------------------------- %

        function testStoreLoadResolvedRoundtrip(testCase)
            ds = FastSenseDataStore(1:100, rand(1, 100));
            testCase.addTeardown(@() ds.cleanup());

            th = struct('X', 1:5, 'Y', (1:5)*2, ...
                'Direction', 'upper', 'Label', 'warn', ...
                'Color', [1 0 0], 'LineStyle', '--', 'Value', 10);
            v = struct('X', [3 4], 'Y', [22 23], ...
                'Direction', 'upper', 'Label', 'warn');

            ds.storeResolved(th, v);
            [thOut, vOut] = ds.loadResolved();

            testCase.verifyNotEmpty(thOut, 'loadResolved: thresholds non-empty');
            testCase.verifyEqual(thOut(1).Direction, 'upper', 'th Direction');
            testCase.verifyEqual(thOut(1).Label, 'warn', 'th Label');
            testCase.verifyEqual(thOut(1).Value, 10, 'th Value');
            testCase.verifyEqual(thOut(1).Color, [1 0 0], 'th Color');

            testCase.verifyNotEmpty(vOut, 'loadResolved: violations non-empty');
            testCase.verifyEqual(vOut(1).Direction, 'upper', 'v Direction');
            testCase.verifyEqual(vOut(1).Label, 'warn', 'v Label');
        end

        function testLoadResolvedEmptyByDefault(testCase)
            ds = FastSenseDataStore(1:100, rand(1, 100));
            testCase.addTeardown(@() ds.cleanup());

            [thOut, vOut] = ds.loadResolved();
            testCase.verifyEmpty(thOut, 'loadResolved fresh store: thresholds empty');
            testCase.verifyEmpty(vOut, 'loadResolved fresh store: violations empty');
        end

        function testClearResolved(testCase)
            ds = FastSenseDataStore(1:100, rand(1, 100));
            testCase.addTeardown(@() ds.cleanup());

            th = struct('X', 1:3, 'Y', 1:3, 'Direction', 'lower', ...
                'Label', 'lo', 'Color', [0 0 1], 'LineStyle', '-', 'Value', 0);
            v = struct('X', [], 'Y', [], 'Direction', 'lower', 'Label', 'lo');
            ds.storeResolved(th, v);

            ds.clearResolved();
            [thOut, vOut] = ds.loadResolved();
            testCase.verifyEmpty(thOut, 'clearResolved: thresholds gone');
            testCase.verifyEmpty(vOut, 'clearResolved: violations gone');
        end

        % ------------------------------------------------------------- %
        %  Monitor cache (MONITOR-09)
        % ------------------------------------------------------------- %

        function testStoreLoadMonitorRoundtrip(testCase)
            ds = FastSenseDataStore(1:100, rand(1, 100));
            testCase.addTeardown(@() ds.cleanup());

            X = (1:50) * 1.5;
            Y = sin(X);
            ds.storeMonitor('mon_a', X, Y, 'parent_p', 100, 1, 100);

            [Xout, Yout, meta] = ds.loadMonitor('mon_a');

            tol = 1e-12;
            testCase.verifyLessThan(max(abs(Xout - X)), tol, 'loadMonitor X drift');
            testCase.verifyLessThan(max(abs(Yout - Y)), tol, 'loadMonitor Y drift');
            testCase.verifyEqual(meta.parent_key, 'parent_p', 'meta parent_key');
            testCase.verifyEqual(meta.num_points, 100, 'meta num_points');
            testCase.verifyEqual(meta.parent_xmin, 1, 'meta parent_xmin');
            testCase.verifyEqual(meta.parent_xmax, 100, 'meta parent_xmax');
        end

        function testLoadMonitorMissReturnsEmpty(testCase)
            ds = FastSenseDataStore(1:100, rand(1, 100));
            testCase.addTeardown(@() ds.cleanup());

            [X, Y, meta] = ds.loadMonitor('not_there');
            testCase.verifyEmpty(X, 'loadMonitor miss: X empty');
            testCase.verifyEmpty(Y, 'loadMonitor miss: Y empty');
            testCase.verifyTrue(isstruct(meta), 'loadMonitor miss: meta is struct');
        end

        function testStoreMonitorReplacesExisting(testCase)
            ds = FastSenseDataStore(1:100, rand(1, 100));
            testCase.addTeardown(@() ds.cleanup());

            ds.storeMonitor('mon', [1 2 3], [10 20 30], 'p', 3, 1, 3);
            ds.storeMonitor('mon', [4 5], [40 50], 'p2', 5, 4, 5);  % replace

            [Xout, Yout, meta] = ds.loadMonitor('mon');
            testCase.verifyEqual(numel(Xout), 2, 'storeMonitor REPLACE: new X count');
            testCase.verifyEqual(Yout(1), 40, 'storeMonitor REPLACE: new Y[0]');
            testCase.verifyEqual(meta.parent_key, 'p2', 'storeMonitor REPLACE: parent_key');
            testCase.verifyEqual(meta.num_points, 5, 'storeMonitor REPLACE: num_points');
        end

        function testClearMonitor(testCase)
            ds = FastSenseDataStore(1:100, rand(1, 100));
            testCase.addTeardown(@() ds.cleanup());

            ds.storeMonitor('mon', [1 2], [10 20], 'p', 2, 1, 2);
            ds.clearMonitor('mon');

            [X, ~, ~] = ds.loadMonitor('mon');
            testCase.verifyEmpty(X, 'clearMonitor: row removed');
        end

        % ------------------------------------------------------------- %
        %  Pyramid pre-computation
        % ------------------------------------------------------------- %

        function testPyramidPopulatedForLargeData(testCase)
            n = 5000;
            x = linspace(0, 1, n);
            y = sin(x * 100);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());

            testCase.verifyNotEmpty(ds.PyramidX, 'pyramid: X not empty');
            testCase.verifyNotEmpty(ds.PyramidY, 'pyramid: Y not empty');
            % Reduction factor 100 → ~50 buckets → ~100 minmax points
            testCase.verifyTrue(numel(ds.PyramidX) < n / 10, ...
                'pyramid: should be downsampled');
        end

        function testPyramidRawForTinyData(testCase)
            % buildPyramidFromMemory: when n <= 2*nb the pyramid is the
            % raw arrays. With R=100, nb=max(1, round(n/100)). For n=2
            % nb=1 → 2 <= 2 → raw passthrough.
            ds = FastSenseDataStore([1, 2], [10, 20]);
            testCase.addTeardown(@() ds.cleanup());

            testCase.verifyEqual(numel(ds.PyramidX), 2, 'pyramid tiny: raw count');
            testCase.verifyEqual(ds.PyramidX(1), 1, 'pyramid tiny: first X');
            testCase.verifyEqual(ds.PyramidY(2), 20, 'pyramid tiny: last Y');
        end

        % ------------------------------------------------------------- %
        %  Static type-conversion helpers
        % ------------------------------------------------------------- %

        function testFromCategoricalRoundtrip(testCase)
            testCase.assumeTrue(exist('categorical', 'class') == 8, ...
                'categorical class not available; skipping.'); %#ok<EXIST>

            data = categorical({'red', 'green', 'red', 'blue'}, ...
                {'red', 'green', 'blue'});
            s = FastSenseDataStore.fromCategorical(data);
            testCase.verifyTrue(isfield(s, 'codes') && isfield(s, 'categories'), ...
                'fromCategorical: struct shape');
            testCase.verifyEqual(numel(s.codes), 4, 'fromCategorical: codes len');
            testCase.verifyEqual(numel(s.categories), 3, 'fromCategorical: cats len');
        end

        function testFromCategoricalRejectsNonCategorical(testCase)
            testCase.verifyError( ...
                @() FastSenseDataStore.fromCategorical([1 2 3]), ...
                'FastSenseDataStore:badInput');
        end

        function testToCategoricalRoundtrip(testCase)
            testCase.assumeTrue(exist('categorical', 'class') == 8, ...
                'categorical class not available; skipping.'); %#ok<EXIST>

            s = struct('codes', uint32([1 2 1 3]), ...
                       'categories', {{'A', 'B', 'C'}});
            c = FastSenseDataStore.toCategorical(s);
            testCase.verifyTrue(isa(c, 'categorical'), 'toCategorical: class');
            testCase.verifyEqual(string(c(1)), "A", 'toCategorical: first');
            testCase.verifyEqual(string(c(4)), "C", 'toCategorical: last');
        end

        function testToCategoricalRejectsNonStruct(testCase)
            testCase.verifyError( ...
                @() FastSenseDataStore.toCategorical(struct('foo', 1)), ...
                'FastSenseDataStore:badInput');
        end

        % ------------------------------------------------------------- %
        %  Connection lifecycle (closeDb / ensureOpen via WAL toggle)
        % ------------------------------------------------------------- %

        function testRangeWorksAfterCleanupSafe(testCase)
            % After cleanup, IsValid is false → getRange returns empty cleanly.
            ds = FastSenseDataStore(1:100, rand(1, 100));
            ds.cleanup();
            [xr, yr] = ds.getRange(10, 20);
            testCase.verifyEmpty(xr, 'after cleanup: getRange empty X');
            testCase.verifyEmpty(yr, 'after cleanup: getRange empty Y');

            [xs, ys] = ds.readSlice(1, 10);
            testCase.verifyEmpty(xs, 'after cleanup: readSlice empty X');
            testCase.verifyEmpty(ys, 'after cleanup: readSlice empty Y');
        end
    end
end
